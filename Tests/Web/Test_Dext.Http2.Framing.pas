{***************************************************************************}
{                                                                           }
{           Dext Framework — HTTP/2 Framing Unit Tests                     }
{                                                                           }
{           Tests frame parsing, write helpers, and payload accessors       }
{           (RFC 9113).                                                     }
{                                                                           }
{***************************************************************************}
unit Test_Dext.Http2.Framing;

interface

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Http2.Framing;

type
  /// <summary>Tests for TDextHttp2FrameCodec.TryReadFrame</summary>
  [TestFixture('HTTP/2 Framing — TryReadFrame')]
  TFrameReadTests = class
  public
    [Test]
    procedure Read_PartialHeader_ShouldReturnFalse;
    [Test]
    procedure Read_CompleteEmptyFrame_ShouldSucceed;
    [Test]
    procedure Read_FrameWithPayload_ShouldExposePayload;
    [Test]
    procedure Read_IncrementalBuffer_ShouldWaitForFullPayload;
    [Test]
    procedure Read_StreamIdReservedBitCleared;
  end;

  /// <summary>Tests for SETTINGS frame writer and parser.</summary>
  [TestFixture('HTTP/2 Framing — SETTINGS')]
  TFrameSettingsTests = class
  public
    [Test]
    procedure WriteSettings_ShouldProduceValidFrame;
    [Test]
    procedure WriteSettingsAck_ShouldHaveAckFlag;
    [Test]
    procedure ParseSettings_ShouldReturnAllParams;
    [Test]
    procedure WriteAndParseSettings_RoundTrip;
  end;

  /// <summary>Tests for PING frame writer.</summary>
  [TestFixture('HTTP/2 Framing — PING')]
  TFramePingTests = class
  public
    [Test]
    procedure WritePingAck_ShouldEchoPayload;
    [Test]
    procedure WritePingAck_PayloadLength_ShouldBe8;
  end;

  /// <summary>Tests for GOAWAY, RST_STREAM, WINDOW_UPDATE writers.</summary>
  [TestFixture('HTTP/2 Framing — Control Frames')]
  TFrameControlTests = class
  public
    [Test]
    procedure WriteGoaway_ShouldEncodeLastStreamAndError;
    [Test]
    procedure WriteRstStream_ShouldEncodeErrorCode;
    [Test]
    procedure WriteWindowUpdate_ShouldEncodeIncrement;
    [Test]
    procedure WriteWindowUpdate_StreamId_ShouldBeEncoded;
  end;

  /// <summary>Tests for HEADERS and DATA frame writers.</summary>
  [TestFixture('HTTP/2 Framing — HEADERS and DATA')]
  TFrameDataHeadersTests = class
  public
    [Test]
    procedure WriteHeaders_EndHeaders_ShouldSetFlag;
    [Test]
    procedure WriteHeaders_EndStream_ShouldSetFlag;
    [Test]
    procedure WriteData_EndStream_ShouldSetFlag;
    [Test]
    procedure WriteData_PayloadShouldMatchInput;
  end;

implementation

{ Helper: builds a frame into a TBytes and returns a THttp2Frame from parsing }
function ParseOnce(var buf: TBytes; out frame: THttp2Frame): Integer;
var
  consumed: Integer;
begin
  if TDextHttp2FrameCodec.TryReadFrame(@buf[0], Length(buf),
    HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed) then
    Result := consumed
  else
    Result := -1;
end;

{ TFrameReadTests }

procedure TFrameReadTests.Read_PartialHeader_ShouldReturnFalse;
var
  data: TBytes;
  frame: THttp2Frame;
  consumed: Integer;
begin
  // Only 5 bytes — not a full 9-byte header
  data := TBytes.Create($00, $00, $01, $04, $00);
  Should(TDextHttp2FrameCodec.TryReadFrame(@data[0], 5,
    HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed)).BeFalse;
  Should(consumed).Be(0);
end;

procedure TFrameReadTests.Read_CompleteEmptyFrame_ShouldSucceed;
var
  data: TBytes;
  frame: THttp2Frame;
  consumed: Integer;
begin
  // SETTINGS ACK: length=0, type=04, flags=01(ACK), stream=0
  data := TBytes.Create($00, $00, $00, $04, $01, $00, $00, $00, $00);
  Should(TDextHttp2FrameCodec.TryReadFrame(@data[0], 9,
    HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed)).BeTrue;
  Should(consumed).Be(9);
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftSettings));
  Should(frame.PayloadLength).Be(0);
  Should(TDextHttp2FrameCodec.HasAck(frame)).BeTrue;
end;

procedure TFrameReadTests.Read_FrameWithPayload_ShouldExposePayload;
var
  data: TBytes;
  frame: THttp2Frame;
  consumed: Integer;
begin
  // RST_STREAM: length=4, type=03, flags=0, stream=1, error=CANCEL(8)
  data := TBytes.Create(
    $00, $00, $04,  // length = 4
    $03,            // type = RST_STREAM
    $00,            // flags = 0
    $00, $00, $00, $01, // stream = 1
    $00, $00, $00, $08  // error = 8 (CANCEL)
  );
  Should(TDextHttp2FrameCodec.TryReadFrame(@data[0], Length(data),
    HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed)).BeTrue;
  Should(consumed).Be(13);
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftRstStream));
  Should(frame.StreamId).Be(1);
  var errCode: Cardinal;
  Should(TDextHttp2FrameCodec.GetRstStreamError(frame, errCode)).BeTrue;
  Should(errCode).Be(HTTP2_ERR_CANCEL);
end;

procedure TFrameReadTests.Read_IncrementalBuffer_ShouldWaitForFullPayload;
var
  data: TBytes;
  frame: THttp2Frame;
  consumed: Integer;
begin
  // Frame says payload = 8 bytes, but we only supply 5 bytes of payload
  data := TBytes.Create(
    $00, $00, $08,       // length = 8
    $06,                 // PING
    $00,                 // flags
    $00, $00, $00, $00, // stream = 0
    $01, $02, $03, $04, $05  // only 5 bytes of 8
  );
  Should(TDextHttp2FrameCodec.TryReadFrame(@data[0], Length(data),
    HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed)).BeFalse;
end;

procedure TFrameReadTests.Read_StreamIdReservedBitCleared;
var
  data: TBytes;
  frame: THttp2Frame;
  consumed: Integer;
begin
  // Stream id with reserved bit 31 set → should be cleared
  data := TBytes.Create(
    $00, $00, $00,   // length = 0
    $04,             // SETTINGS
    $01,             // ACK
    $80, $00, $00, $01  // stream = 0x80000001 → should parse as 1
  );
  TDextHttp2FrameCodec.TryReadFrame(@data[0], 9, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(frame.StreamId).Be(1);
end;

{ TFrameSettingsTests }

procedure TFrameSettingsTests.WriteSettings_ShouldProduceValidFrame;
var
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
begin
  SetLength(buf, 128);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsFrame(DefaultServerSettings, False, buf, pos);
  Should(TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos,
    HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed)).BeTrue;
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftSettings));
  Should(TDextHttp2FrameCodec.HasAck(frame)).BeFalse;
end;

procedure TFrameSettingsTests.WriteSettingsAck_ShouldHaveAckFlag;
var
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
begin
  SetLength(buf, 32);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsAck(buf, pos);
  Should(TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos,
    HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed)).BeTrue;
  Should(TDextHttp2FrameCodec.HasAck(frame)).BeTrue;
  Should(frame.PayloadLength).Be(0);
end;

procedure TFrameSettingsTests.ParseSettings_ShouldReturnAllParams;
var
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
  parsedSettings: THttp2Settings;
  defaults: THttp2Settings;
begin
  SetLength(buf, 128);
  pos := 0;
  defaults := DefaultServerSettings;
  TDextHttp2FrameCodec.WriteSettingsFrame(defaults, False, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(TDextHttp2FrameCodec.GetSettings(frame, parsedSettings)).BeTrue;
  Should(Length(parsedSettings)).Be(Length(defaults));
  Should(parsedSettings[0].Id).Be(HTTP2_SETTINGS_HEADER_TABLE_SIZE);
  Should(parsedSettings[0].Value).Be(4096);
end;

procedure TFrameSettingsTests.WriteAndParseSettings_RoundTrip;
var
  src, parsed: THttp2Settings;
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
  i: Integer;
begin
  SetLength(src, 3);
  src[0].Id := HTTP2_SETTINGS_INITIAL_WINDOW_SIZE; src[0].Value := 131072;
  src[1].Id := HTTP2_SETTINGS_MAX_FRAME_SIZE;      src[1].Value := 32768;
  src[2].Id := HTTP2_SETTINGS_ENABLE_PUSH;         src[2].Value := 0;
  SetLength(buf, 128);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsFrame(src, False, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  TDextHttp2FrameCodec.GetSettings(frame, parsed);
  Should(Length(parsed)).Be(3);
  for i := 0 to 2 do
  begin
    Should(parsed[i].Id).Be(src[i].Id);
    Should(parsed[i].Value).Be(src[i].Value);
  end;
end;

{ TFramePingTests }

procedure TFramePingTests.WritePingAck_ShouldEchoPayload;
var
  pingData: array[0..7] of Byte;
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
  i: Integer;
begin
  for i := 0 to 7 do pingData[i] := Byte(i + 1);
  SetLength(buf, 32);
  pos := 0;
  TDextHttp2FrameCodec.WritePingAck(@pingData[0], buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftPing));
  Should(TDextHttp2FrameCodec.HasAck(frame)).BeTrue;
  for i := 0 to 7 do
    Should(frame.PayloadPtr[i]).Be(Byte(i + 1));
end;

procedure TFramePingTests.WritePingAck_PayloadLength_ShouldBe8;
var
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
begin
  SetLength(buf, 32);
  pos := 0;
  TDextHttp2FrameCodec.WritePingAck(nil, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(frame.PayloadLength).Be(8);
end;

{ TFrameControlTests }

procedure TFrameControlTests.WriteGoaway_ShouldEncodeLastStreamAndError;
var
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
  lastSid, errCode: Cardinal;
  debugData: TBytes;
begin
  SetLength(buf, 64);
  pos := 0;
  TDextHttp2FrameCodec.WriteGoaway(7, HTTP2_ERR_PROTOCOL_ERROR, 'test', buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftGoaway));
  Should(TDextHttp2FrameCodec.GetGoaway(frame, lastSid, errCode, debugData)).BeTrue;
  Should(lastSid).Be(7);
  Should(errCode).Be(HTTP2_ERR_PROTOCOL_ERROR);
end;

procedure TFrameControlTests.WriteRstStream_ShouldEncodeErrorCode;
var
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
  errCode: Cardinal;
begin
  SetLength(buf, 32);
  pos := 0;
  TDextHttp2FrameCodec.WriteRstStream(3, HTTP2_ERR_CANCEL, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftRstStream));
  Should(frame.StreamId).Be(3);
  TDextHttp2FrameCodec.GetRstStreamError(frame, errCode);
  Should(errCode).Be(HTTP2_ERR_CANCEL);
end;

procedure TFrameControlTests.WriteWindowUpdate_ShouldEncodeIncrement;
var
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
  inc: Cardinal;
begin
  SetLength(buf, 32);
  pos := 0;
  TDextHttp2FrameCodec.WriteWindowUpdate(0, 65535, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftWindowUpdate));
  Should(TDextHttp2FrameCodec.GetWindowUpdateIncrement(frame, inc)).BeTrue;
  Should(inc).Be(65535);
end;

procedure TFrameControlTests.WriteWindowUpdate_StreamId_ShouldBeEncoded;
var
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
begin
  SetLength(buf, 32);
  pos := 0;
  TDextHttp2FrameCodec.WriteWindowUpdate(5, 32768, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(frame.StreamId).Be(5);
end;

{ TFrameDataHeadersTests }

procedure TFrameDataHeadersTests.WriteHeaders_EndHeaders_ShouldSetFlag;
var
  hdrBlock: TBytes;
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
begin
  hdrBlock := TBytes.Create($82, $87); // :method GET, :status 200
  SetLength(buf, 64);
  pos := 0;
  TDextHttp2FrameCodec.WriteHeadersFrame(1, @hdrBlock[0], 2, False, True, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftHeaders));
  Should(TDextHttp2FrameCodec.HasEndHeaders(frame)).BeTrue;
  Should(TDextHttp2FrameCodec.HasEndStream(frame)).BeFalse;
end;

procedure TFrameDataHeadersTests.WriteHeaders_EndStream_ShouldSetFlag;
var
  hdrBlock: TBytes;
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
begin
  hdrBlock := TBytes.Create($87); // :status 200
  SetLength(buf, 64);
  pos := 0;
  TDextHttp2FrameCodec.WriteHeadersFrame(1, @hdrBlock[0], 1, True, True, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(TDextHttp2FrameCodec.HasEndStream(frame)).BeTrue;
end;

procedure TFrameDataHeadersTests.WriteData_EndStream_ShouldSetFlag;
var
  payload: TBytes;
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
begin
  payload := TBytes.Create($68, $65, $6C, $6C, $6F); // "hello"
  SetLength(buf, 64);
  pos := 0;
  TDextHttp2FrameCodec.WriteDataFrame(1, @payload[0], 5, True, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftData));
  Should(TDextHttp2FrameCodec.HasEndStream(frame)).BeTrue;
end;

procedure TFrameDataHeadersTests.WriteData_PayloadShouldMatchInput;
var
  payload: TBytes;
  buf: TBytes;
  pos: Integer;
  frame: THttp2Frame;
  consumed: Integer;
  dataPtr: PByte;
  dataLen: Integer;
begin
  payload := TBytes.Create(1, 2, 3, 4, 5, 6, 7, 8);
  SetLength(buf, 64);
  pos := 0;
  TDextHttp2FrameCodec.WriteDataFrame(3, @payload[0], 8, False, buf, pos);
  TDextHttp2FrameCodec.TryReadFrame(@buf[0], pos, HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed);
  TDextHttp2FrameCodec.GetDataPayload(frame, dataPtr, dataLen);
  Should(dataLen).Be(8);
  Should(dataPtr[0]).Be(1);
  Should(dataPtr[7]).Be(8);
end;

end.
