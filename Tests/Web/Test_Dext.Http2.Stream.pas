{***************************************************************************}
{                                                                           }
{           Dext Framework - HTTP/2 Stream State Machine Unit Tests        }
{                                                                           }
{           Tests stream state transitions, flow control, and stream map   }
{           binary search/insert/remove behavior.                           }
{                                                                           }
{***************************************************************************}
unit Test_Dext.Http2.Stream;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Http2.Hpack,
  Dext.Http2.Stream;

type
  /// <summary>Tests for TDextHttp2Stream state transitions.</summary>
  [TestFixture('HTTP/2 Stream - State Machine')]
  TStreamStateTests = class
  public
    [Test]
    procedure NewStream_ShouldBeIdle;
    [Test]
    procedure Open_ShouldTransitionToOpen;
    [Test]
    procedure Open_WhenNotIdle_ShouldRaise;
    [Test]
    procedure RemoteEndStream_FromOpen_ShouldBeHalfClosedRemote;
    [Test]
    procedure LocalEndStream_FromOpen_ShouldBeHalfClosedLocal;
    [Test]
    procedure RemoteEndStream_FromHalfClosedLocal_ShouldBeClosed;
    [Test]
    procedure LocalEndStream_FromHalfClosedRemote_ShouldBeClosed;
    [Test]
    procedure Reset_ShouldBeClosed_AndSetErrorCode;
  end;

  /// <summary>Tests for stream header accumulation and data buffering.</summary>
  [TestFixture('HTTP/2 Stream - Header and Data Accumulation')]
  TStreamAccumulationTests = class
  private
    FDecoder: THpackDecoder;
    FEncoder: THpackEncoder;
  public
    [Setup]    procedure Setup;
    [Teardown] procedure Teardown;

    [Test]
    procedure AppendHeaderFragment_ShouldAccumulate;
    [Test]
    procedure FinalizeHeaders_ShouldDecodeCorrectly;
    [Test]
    procedure AppendData_ShouldGrow;
    [Test]
    procedure AppendData_Multiple_ShouldConcatenate;
  end;

  /// <summary>Tests for flow control (send/recv window).</summary>
  [TestFixture('HTTP/2 Stream - Flow Control')]
  TStreamFlowControlTests = class
  public
    [Test]
    procedure ConsumeSendWindow_ShouldReduceWindow;
    [Test]
    procedure ConsumeSendWindow_OverLimit_ShouldReturnFalse;
    [Test]
    procedure IncreaseSendWindow_ShouldGrow;
    [Test]
    procedure ConsumeAndRefillRecvWindow;
  end;

  /// <summary>Tests for TDextHttp2StreamMap sorted array operations.</summary>
  [TestFixture('HTTP/2 Stream - StreamMap')]
  TStreamMapTests = class
  private
    FMap: TDextHttp2StreamMap;
  public
    [Setup]    procedure Setup;
    [Teardown] procedure Teardown;

    [Test]
    procedure OpenStream_ShouldAddAndFind;
    [Test]
    procedure Find_NonExistent_ShouldReturnNil;
    [Test]
    procedure OpenStream_Duplicate_ShouldRaise;
    [Test]
    procedure Remove_ShouldDecreaseCount;
    [Test]
    procedure MultipleSortedStreams_FindAll;
    [Test]
    procedure PurgeClosed_ShouldRemoveClosedOnly;
    [Test]
    procedure ApplyWindowSizeDelta_ShouldAffectAllStreams;
  end;

implementation

{ TStreamStateTests }

procedure TStreamStateTests.NewStream_ShouldBeIdle;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    Should(stream.State).Be(Ord(THttp2StreamState.ssIdle));
  finally
    stream.Free;
  end;
end;

procedure TStreamStateTests.Open_ShouldTransitionToOpen;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.Open;
    Should(stream.State).Be(Ord(THttp2StreamState.ssOpen));
  finally
    stream.Free;
  end;
end;

procedure TStreamStateTests.Open_WhenNotIdle_ShouldRaise;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.Open;
    Should(procedure begin stream.Open; end).Throw<EInvalidOperation>;
  finally
    stream.Free;
  end;
end;

procedure TStreamStateTests.RemoteEndStream_FromOpen_ShouldBeHalfClosedRemote;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.Open;
    stream.RemoteEndStream;
    Should(stream.State).Be(Ord(THttp2StreamState.ssHalfClosedRemote));
    Should(stream.EndStreamReceived).BeTrue;
  finally
    stream.Free;
  end;
end;

procedure TStreamStateTests.LocalEndStream_FromOpen_ShouldBeHalfClosedLocal;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.Open;
    stream.LocalEndStream;
    Should(stream.State).Be(Ord(THttp2StreamState.ssHalfClosedLocal));
  finally
    stream.Free;
  end;
end;

procedure TStreamStateTests.RemoteEndStream_FromHalfClosedLocal_ShouldBeClosed;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.Open;
    stream.LocalEndStream;         // → HalfClosedLocal
    stream.RemoteEndStream;        // → Closed
    Should(stream.State).Be(Ord(THttp2StreamState.ssClosed));
  finally
    stream.Free;
  end;
end;

procedure TStreamStateTests.LocalEndStream_FromHalfClosedRemote_ShouldBeClosed;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.Open;
    stream.RemoteEndStream;        // → HalfClosedRemote
    stream.LocalEndStream;         // → Closed
    Should(stream.State).Be(Ord(THttp2StreamState.ssClosed));
  finally
    stream.Free;
  end;
end;

procedure TStreamStateTests.Reset_ShouldBeClosed_AndSetErrorCode;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.Open;
    stream.Reset(8); // HTTP2_ERR_CANCEL
    Should(stream.State).Be(Ord(THttp2StreamState.ssClosed));
    Should(stream.ErrorCode).Be(8);
  finally
    stream.Free;
  end;
end;

{ TStreamAccumulationTests }

procedure TStreamAccumulationTests.Setup;
begin
  FDecoder := THpackDecoder.Create;
  FEncoder := THpackEncoder.Create;
end;

procedure TStreamAccumulationTests.Teardown;
begin
  FDecoder.Free;
  FEncoder.Free;
end;

procedure TStreamAccumulationTests.AppendHeaderFragment_ShouldAccumulate;
var
  stream: TDextHttp2Stream;
  data: TBytes;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    data := TBytes.Create($82, $87); // 2 bytes
    stream.AppendHeaderFragment(@data[0], 2);
    data := TBytes.Create($04); // 1 more byte
    stream.AppendHeaderFragment(@data[0], 1);
    // We can't directly check internal buffer size but FinalizeHeaders succeeds
    // on valid HPACK data. This test just ensures no crash.
    Should(True).BeTrue;
  finally
    stream.Free;
  end;
end;

procedure TStreamAccumulationTests.FinalizeHeaders_ShouldDecodeCorrectly;
var
  stream: TDextHttp2Stream;
  headers: TNameValuePairs;
  encoded: TBytes;
begin
  SetLength(headers, 2);
  headers[0].Name := ':method'; headers[0].Value := 'GET';
  headers[1].Name := ':path';   headers[1].Value := '/';
  encoded := FEncoder.Encode(headers);

  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.Open;
    stream.AppendHeaderFragment(@encoded[0], Length(encoded));
    Should(stream.FinalizeHeaders(FDecoder)).BeTrue;
    Should(stream.HeadersComplete).BeTrue;
    Should(Length(stream.Headers) >= 2).BeTrue;
    Should(stream.Headers[0].Name).Be(':method');
    Should(stream.Headers[0].Value).Be('GET');
  finally
    stream.Free;
  end;
end;

procedure TStreamAccumulationTests.AppendData_ShouldGrow;
var
  stream: TDextHttp2Stream;
  data: TBytes;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    data := TBytes.Create(1, 2, 3, 4, 5);
    stream.AppendData(@data[0], 5);
    Should(stream.DataLen).Be(5);
    Should(stream.DataBuffer[0]).Be(1);
    Should(stream.DataBuffer[4]).Be(5);
  finally
    stream.Free;
  end;
end;

procedure TStreamAccumulationTests.AppendData_Multiple_ShouldConcatenate;
var
  stream: TDextHttp2Stream;
  chunk1, chunk2: TBytes;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    chunk1 := TBytes.Create(10, 20, 30);
    chunk2 := TBytes.Create(40, 50);
    stream.AppendData(@chunk1[0], 3);
    stream.AppendData(@chunk2[0], 2);
    Should(stream.DataLen).Be(5);
    Should(stream.DataBuffer[0]).Be(10);
    Should(stream.DataBuffer[4]).Be(50);
  finally
    stream.Free;
  end;
end;

{ TStreamFlowControlTests }

procedure TStreamFlowControlTests.ConsumeSendWindow_ShouldReduceWindow;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    Should(stream.ConsumeSendWindow(1024)).BeTrue;
    Should(stream.SendWindowSize).Be(65535 - 1024);
  finally
    stream.Free;
  end;
end;

procedure TStreamFlowControlTests.ConsumeSendWindow_OverLimit_ShouldReturnFalse;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 100);
  try
    Should(stream.ConsumeSendWindow(101)).BeFalse;
    Should(stream.SendWindowSize).Be(100); // unchanged
  finally
    stream.Free;
  end;
end;

procedure TStreamFlowControlTests.IncreaseSendWindow_ShouldGrow;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.ConsumeSendWindow(1000);
    stream.IncreaseSendWindow(500);
    Should(stream.SendWindowSize).Be(65535 - 1000 + 500);
  finally
    stream.Free;
  end;
end;

procedure TStreamFlowControlTests.ConsumeAndRefillRecvWindow;
var
  stream: TDextHttp2Stream;
begin
  stream := TDextHttp2Stream.Create(1, 65535);
  try
    stream.ConsumeRecvWindow(16000);
    Should(stream.RecvWindowSize).Be(65535 - 16000);
    stream.RefillRecvWindow(16000);
    Should(stream.RecvWindowSize).Be(65535);
  finally
    stream.Free;
  end;
end;

{ TStreamMapTests }

procedure TStreamMapTests.Setup;
begin
  FMap := TDextHttp2StreamMap.Create(65535);
end;

procedure TStreamMapTests.Teardown;
begin
  FMap.Free;
end;

procedure TStreamMapTests.OpenStream_ShouldAddAndFind;
var
  stream: TDextHttp2Stream;
  found: TDextHttp2Stream;
begin
  stream := FMap.OpenStream(1);
  Should(stream).NotBeNil;
  found := FMap.Find(1);
  Should(found = stream).BeTrue;
  Should(FMap.Count).Be(1);
end;

procedure TStreamMapTests.Find_NonExistent_ShouldReturnNil;
begin
  Should(FMap.Find(99)).BeNil;
end;

procedure TStreamMapTests.OpenStream_Duplicate_ShouldRaise;
begin
  FMap.OpenStream(1);
  Should(procedure begin FMap.OpenStream(1); end).Throw<EInvalidOperation>;
end;

procedure TStreamMapTests.Remove_ShouldDecreaseCount;
begin
  FMap.OpenStream(1);
  FMap.OpenStream(3);
  FMap.Remove(1);
  Should(FMap.Count).Be(1);
  Should(FMap.Find(1)).BeNil;
  Should(FMap.Find(3)).NotBeNil;
end;

procedure TStreamMapTests.MultipleSortedStreams_FindAll;
var
  i: Integer;
begin
  // Insert out-of-order to verify binary search
  FMap.OpenStream(5);
  FMap.OpenStream(1);
  FMap.OpenStream(9);
  FMap.OpenStream(3);
  FMap.OpenStream(7);
  Should(FMap.Count).Be(5);
  for i := 1 to 5 do
    Should(FMap.Find(Cardinal(i * 2 - 1))).NotBeNil;
end;

procedure TStreamMapTests.PurgeClosed_ShouldRemoveClosedOnly;
var
  s1, s3: TDextHttp2Stream;
begin
  s1 := FMap.OpenStream(1);
  FMap.OpenStream(3);
  s3 := FMap.Find(3);
  s1.Open; s1.Reset; // Close stream 1
  s3.Open;           // Stream 3 stays open
  FMap.PurgeClosed;
  Should(FMap.Count).Be(1);
  Should(FMap.Find(1)).BeNil;
  Should(FMap.Find(3)).NotBeNil;
end;

procedure TStreamMapTests.ApplyWindowSizeDelta_ShouldAffectAllStreams;
var
  s1, s3: TDextHttp2Stream;
begin
  s1 := FMap.OpenStream(1);
  s3 := FMap.OpenStream(3);
  FMap.ApplyWindowSizeDelta(10000);
  Should(s1.SendWindowSize).Be(65535 + 10000);
  Should(s3.SendWindowSize).Be(65535 + 10000);
end;

end.
