{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}

unit Dext.Web.ResponseWriter.Tests;

interface

uses
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Core.Span,
  Dext.Web.ResponseWriter,
  System.SysUtils,
  System.Classes;

type
  [TestFixture('Dext Response Writer and Pools')]
  TResponseWriterTests = class
  private
    FReleasedCount: Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure Test_Pool_Rent_Release_Local;
    [Test]
    procedure Test_Pool_CrossThread_Release;
    [Test]
    procedure Test_Writer_BasicWrite;
    [Test]
    procedure Test_Writer_SegmentTransitions;
    [Test]
    procedure Test_Writer_Reserve;
    [Test]
    procedure Test_Writer_AddExternal;
  end;

implementation

var
  GReleasedCount: Integer;

function SpanToString(const ASpan: TByteSpan): string;
var
  Temp: RawByteString;
begin
  if ASpan.Length <= 0 then
    Exit('');
  SetString(Temp, PAnsiChar(ASpan.Data), ASpan.Length);
  SetCodePage(Temp, 65001, False);
  Result := string(Temp);
end;

procedure TestReleaseProc(AOwner: Pointer);
begin
  Inc(GReleasedCount);
end;

{ TResponseWriterTests }

procedure TResponseWriterTests.Setup;
begin
  TDextBufferPool.ResetPools;
  FReleasedCount := 0;
  GReleasedCount := 0;
end;

procedure TResponseWriterTests.TearDown;
begin
  TDextBufferPool.ResetPools;
end;

procedure TResponseWriterTests.Test_Pool_Rent_Release_Local;
var
  Ptr1, Ptr2: Pointer;
  RentedSize: Integer;
begin
  // Rent 3000 bytes (should map to 4KB size class)
  Ptr1 := TDextBufferPool.Rent(3000, RentedSize);
  Should(RentedSize).Be(4096);
  Should(Ptr1 <> nil).BeTrue;

  // Release it
  TDextBufferPool.Release(Ptr1);

  // Rent again, should return the exact same pointer (from local cache)
  Ptr2 := TDextBufferPool.Rent(3000, RentedSize);
  Should(Ptr2 = Ptr1).BeTrue;

  TDextBufferPool.Release(Ptr2);
end;

procedure TResponseWriterTests.Test_Pool_CrossThread_Release;
var
  Ptr1: Pointer;
  RentedSize: Integer;
  Th: TThread;
begin
  Ptr1 := TDextBufferPool.Rent(8000, RentedSize); // 8KB size class
  Should(RentedSize).Be(8192);

  // Release on another thread
  Th := TThread.CreateAnonymousThread(
    procedure
    begin
      TDextBufferPool.Release(Ptr1);
    end);
  Th.FreeOnTerminate := False;
  Th.Start;
  Th.WaitFor;
  Th.Free;

  // Verify we can reset the global pools cleanly without leak
  TDextBufferPool.ResetPools;
end;

procedure TResponseWriterTests.Test_Writer_BasicWrite;
var
  Writer: TDextResponseWriter;
  S: AnsiString;
  Span: TByteSpan;
  Seg: TDextBufferSegment;
begin
  Writer.Init;
  try
    S := 'Hello Segmented Writer';
    Span := TByteSpan.Create(PAnsiChar(S), Length(S));
    Writer.Write(Span);

    Should(Writer.SegmentCount).Be(1);
    Seg := Writer.Segments[0];
    Should(Seg.Length).Be(Length(S));

    // Verify written data
    Should(SpanToString(TByteSpan.Create(Seg.Data, Seg.Length)))
      .Be('Hello Segmented Writer');
  finally
    Writer.Clear;
  end;
end;

procedure TResponseWriterTests.Test_Writer_SegmentTransitions;
var
  Writer: TDextResponseWriter;
  LargeData: array[0..5000] of Byte;
  Span: TByteSpan;
  I: Integer;
begin
  for I := 0 to 5000 do
    LargeData[I] := 65; // 'A'

  Writer.Init;
  try
    Span := TByteSpan.Create(@LargeData[0], 5000);
    // Write 5000 bytes: should exceed 4KB and split into 2 segments
    Writer.Write(Span);

    Should(Writer.SegmentCount).Be(2);
    Should(Writer.Segments[0].Length).Be(4096);
    Should(Writer.Segments[1].Length).Be(904);

    Should(Writer.Segments[0].Length + Writer.Segments[1].Length).Be(5000);
  finally
    Writer.Clear;
  end;
end;

procedure TResponseWriterTests.Test_Writer_Reserve;
var
  Writer: TDextResponseWriter;
  Span: TByteSpan;
  S: AnsiString;
  Seg: TDextBufferSegment;
begin
  Writer.Init;
  try
    Span := Writer.Reserve(10);
    Should(Span.Length).Be(10);

    S := '0123456789';
    Move(PAnsiChar(S)^, Span.Data^, 10);

    Should(Writer.SegmentCount).Be(1);
    Seg := Writer.Segments[0];
    Should(Seg.Length).Be(10);
    Should(SpanToString(TByteSpan.Create(Seg.Data, Seg.Length)))
      .Be('0123456789');
  finally
    Writer.Clear;
  end;
end;

procedure TResponseWriterTests.Test_Writer_AddExternal;
var
  Writer: TDextResponseWriter;
  S1, S2: AnsiString;
  Span: TByteSpan;
begin
  Writer.Init;
  try
    S1 := 'Internal Segment ';
    Span := TByteSpan.Create(PAnsiChar(S1), Length(S1));
    Writer.Write(Span);

    S2 := 'External Zero Copy';
    Writer.AddExternal(PAnsiChar(S2), Length(S2), nil, TestReleaseProc);

    Should(Writer.SegmentCount).Be(2);
    Should(Writer.Segments[0].Length).Be(Length(S1));
    Should(Writer.Segments[1].Length).Be(Length(S2));
    Should(Pointer(Writer.Segments[1].Data) = PAnsiChar(S2)).BeTrue;

    // Reset should trigger custom release proc
    Should(GReleasedCount).Be(0);
    Writer.Reset;
    Should(GReleasedCount).Be(1);
  finally
    Writer.Clear;
  end;
end;

end.
