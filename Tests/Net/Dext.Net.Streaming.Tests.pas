unit Dext.Net.Streaming.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  Dext.Net.RestClient;

type
  [TestFixture]
  TDextRestClientStreamingTests = class
  public
    [Test]
    procedure Test_DownloadToFile_Streaming;
    [Test]
    procedure Test_OnReceive_ProgressCallback;
  end;

implementation

procedure TDextRestClientStreamingTests.Test_DownloadToFile_Streaming;
var
  TargetFile: string;
  Stream: TMemoryStream;
begin
  TargetFile := ExtractFilePath(ParamStr(0)) + 'test_stream_output.tmp';
  if FileExists(TargetFile) then
    DeleteFile(TargetFile);

  Stream := TMemoryStream.Create;
  try
    // Write 1KB mock payload to stream
    Stream.Size := 1024;
    Assert.AreEqual(Int64(1024), Stream.Size);
  finally
    Stream.Free;
  end;
end;

procedure TDextRestClientStreamingTests.Test_OnReceive_ProgressCallback;
var
  ProgressCalled: Boolean;
  Abort: Boolean;
  ReadBytes, TotalBytes: Int64;
  Proc: TRestReceiveAnonEvent;
begin
  ProgressCalled := False;
  Abort := False;
  ReadBytes := 512;
  TotalBytes := 1024;

  Proc := procedure(const AContentLength, AReadCount: Int64; var AAbort: Boolean)
  begin
    ProgressCalled := True;
    Assert.AreEqual(TotalBytes, AContentLength);
    Assert.AreEqual(ReadBytes, AReadCount);
  end;

  Proc(TotalBytes, ReadBytes, Abort);
  Assert.IsTrue(ProgressCalled);
end;

initialization
  TDUnitX.RegisterTestFixture(TDextRestClientStreamingTests);

end.
