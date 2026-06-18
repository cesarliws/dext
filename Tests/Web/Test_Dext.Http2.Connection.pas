{***************************************************************************}
{                                                                           }
{           Dext Framework — HTTP/2 Connection Unit Tests                  }
{                                                                           }
{           Tests connection preface validation, SETTINGS handshake,       }
{           request dispatch, PING/PONG, GOAWAY, and full request round-  }
{           trip against TDextHttp2Connection.                              }
{                                                                           }
{***************************************************************************}
unit Test_Dext.Http2.Connection;

interface

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Http2.Hpack,
  Dext.Http2.Framing,
  Dext.Http2.Stream,
  Dext.Http2.Connection;

type
  /// <summary>Tests for client preface validation.</summary>
  [TestFixture('HTTP/2 Connection — Preface')]
  TConnectionPrefaceTests = class
  private
    FConn: TDextHttp2Connection;
    FOutput: TBytes;
    FOutputLen: Integer;
    procedure OnOutput(AData: PByte; ALen: Integer);
  public
    [Setup]    procedure Setup;
    [Teardown] procedure Teardown;

    [Test]
    procedure ValidPreface_ShouldTransitionToSettingsExchange;
    [Test]
    procedure ValidPreface_ShouldSendOurSettings;
    [Test]
    procedure InvalidPreface_ShouldSendGoaway;
    [Test]
    procedure PartialPreface_ShouldNotAdvanceState;
  end;

  /// <summary>Tests for SETTINGS handshake.</summary>
  [TestFixture('HTTP/2 Connection — SETTINGS Handshake')]
  TConnectionSettingsTests = class
  private
    FConn: TDextHttp2Connection;
    FOutput: TBytes;
    FOutputLen: Integer;
    procedure OnOutput(AData: PByte; ALen: Integer);
    procedure FeedPreface;
  public
    [Setup]    procedure Setup;
    [Teardown] procedure Teardown;

    [Test]
    procedure ReceiveClientSettings_ShouldSendAck;
    [Test]
    procedure ReceiveSettingsAck_ShouldTransitionToOpen;
  end;

  /// <summary>Tests for PING handling.</summary>
  [TestFixture('HTTP/2 Connection — PING')]
  TConnectionPingTests = class
  private
    FConn: TDextHttp2Connection;
    FOutput: TBytes;
    FOutputLen: Integer;
    procedure OnOutput(AData: PByte; ALen: Integer);
    procedure FeedPreface;
    procedure FeedSettingsExchange;
  public
    [Setup]    procedure Setup;
    [Teardown] procedure Teardown;

    [Test]
    procedure ReceivePing_ShouldEchoAsPingAck;
  end;

  /// <summary>Tests for complete HTTP/2 request dispatch.</summary>
  [TestFixture('HTTP/2 Connection — Request Dispatch')]
  TConnectionRequestTests = class
  private
    FConn: TDextHttp2Connection;
    FOutput: TBytes;
    FOutputLen: Integer;
    FReceivedStreamId: Cardinal;
    FReceivedHeaders: TNameValuePairs;
    FReceivedBody: TBytes;
    procedure OnOutput(AData: PByte; ALen: Integer);
    procedure OnRequest(AConn: TObject; AStreamId: Cardinal;
      const AHeaders: TNameValuePairs; const ABody: TBytes);
    procedure FeedPreface;
    procedure FeedSettingsExchange;
    function BuildGetRequest(AStreamId: Cardinal): TBytes;
  public
    [Setup]    procedure Setup;
    [Teardown] procedure Teardown;

    [Test]
    procedure CompleteGetRequest_ShouldFireOnRequest;
    [Test]
    procedure OnRequest_ShouldReceiveCorrectStreamId;
    [Test]
    procedure SendResponse_ShouldProduceValidHeadersFrame;
    [Test]
    procedure SendGoaway_ShouldTransitionToClosing;
  end;

implementation

{ TConnectionPrefaceTests }

procedure TConnectionPrefaceTests.OnOutput(AData: PByte; ALen: Integer);
begin
  if FOutputLen + ALen > Length(FOutput) then
    SetLength(FOutput, FOutputLen + ALen + 256);
  if ALen > 0 then Move(AData^, FOutput[FOutputLen], ALen);
  Inc(FOutputLen, ALen);
end;

procedure TConnectionPrefaceTests.Setup;
begin
  FConn := TDextHttp2Connection.Create(THttp2ConnectionOptions.Default);
  FConn.OnOutput := OnOutput;
  FOutputLen := 0;
  SetLength(FOutput, 1024);
end;

procedure TConnectionPrefaceTests.Teardown;
begin
  FConn.Free;
end;

procedure TConnectionPrefaceTests.ValidPreface_ShouldTransitionToSettingsExchange;
var
  preface: TBytes;
begin
  preface := TEncoding.ASCII.GetBytes(HTTP2_CLIENT_PREFACE);
  FConn.Feed(@preface[0], Length(preface));
  Should(FConn.State).Be(Ord(THttp2ConnectionState.csSettingsExchange));
end;

procedure TConnectionPrefaceTests.ValidPreface_ShouldSendOurSettings;
var
  preface: TBytes;
begin
  preface := TEncoding.ASCII.GetBytes(HTTP2_CLIENT_PREFACE);
  FConn.Feed(@preface[0], Length(preface));
  // After preface we should have sent at least a SETTINGS frame (9 bytes min)
  Should(FOutputLen >= 9).BeTrue;
  // First frame should be SETTINGS
  Should(FOutput[3]).Be(Byte(THttp2FrameType.ftSettings));
end;

procedure TConnectionPrefaceTests.InvalidPreface_ShouldSendGoaway;
var
  garbage: TBytes;
begin
  garbage := TBytes.Create(
    $47, $45, $54, $20, $2F, $20, $48, $54, $54, $50, $2F, $31,
    $2E, $31, $0D, $0A, $48, $6F, $73, $74, $3A, $20, $61, $62
  ); // "GET / HTTP/1.1\r\nHost: ab"
  FConn.Feed(@garbage[0], Length(garbage));
  // Should have sent GOAWAY or closed
  Should((FConn.State = THttp2ConnectionState.csClosing) or
         (FConn.State = THttp2ConnectionState.csClosed)).BeTrue;
end;

procedure TConnectionPrefaceTests.PartialPreface_ShouldNotAdvanceState;
var
  partial: TBytes;
begin
  // Send only first 10 bytes of the 24-byte preface
  partial := TBytes.Create($50, $52, $49, $20, $2A, $20, $48, $54, $54, $50);
  FConn.Feed(@partial[0], Length(partial));
  Should(FConn.State).Be(Ord(THttp2ConnectionState.csAwaitingPreface));
end;

{ TConnectionSettingsTests }

procedure TConnectionSettingsTests.OnOutput(AData: PByte; ALen: Integer);
begin
  if FOutputLen + ALen > Length(FOutput) then
    SetLength(FOutput, FOutputLen + ALen + 256);
  if ALen > 0 then Move(AData^, FOutput[FOutputLen], ALen);
  Inc(FOutputLen, ALen);
end;

procedure TConnectionSettingsTests.FeedPreface;
var
  preface: TBytes;
begin
  preface := TEncoding.ASCII.GetBytes(HTTP2_CLIENT_PREFACE);
  FConn.Feed(@preface[0], Length(preface));
end;

procedure TConnectionSettingsTests.Setup;
begin
  FConn := TDextHttp2Connection.Create(THttp2ConnectionOptions.Default);
  FConn.OnOutput := OnOutput;
  FOutputLen := 0;
  SetLength(FOutput, 4096);
end;

procedure TConnectionSettingsTests.Teardown;
begin
  FConn.Free;
end;

procedure TConnectionSettingsTests.ReceiveClientSettings_ShouldSendAck;
var
  settingsBuf: TBytes;
  pos: Integer;
  prevOutputLen: Integer;
  frame: THttp2Frame;
  consumed: Integer;
  i: Integer;
begin
  FeedPreface;
  prevOutputLen := FOutputLen;

  // Build a client SETTINGS frame (empty = all defaults)
  SetLength(settingsBuf, 9);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsFrame(nil, False, settingsBuf, pos);
  SetLength(settingsBuf, pos);

  FConn.Feed(@settingsBuf[0], Length(settingsBuf));

  // Scan output for a SETTINGS ACK after prevOutputLen
  i := prevOutputLen;
  while i + 9 <= FOutputLen do
  begin
    if TDextHttp2FrameCodec.TryReadFrame(@FOutput[i], FOutputLen - i,
      HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed) then
    begin
      if (frame.FrameType = Byte(THttp2FrameType.ftSettings)) and
         TDextHttp2FrameCodec.HasAck(frame) then
      begin
        Should(True).BeTrue; // Found the ACK
        Exit;
      end;
      Inc(i, consumed);
    end
    else
      Break;
  end;
  Should(False).BeTrue; // Should not reach here
end;

procedure TConnectionSettingsTests.ReceiveSettingsAck_ShouldTransitionToOpen;
var
  clientSettings, settingsAck: TBytes;
  pos: Integer;
begin
  FeedPreface;
  // Send empty client SETTINGS
  SetLength(clientSettings, 32);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsFrame(nil, False, clientSettings, pos);
  FConn.Feed(@clientSettings[0], pos);
  // Send SETTINGS ACK (acknowledgement of our SETTINGS)
  SetLength(settingsAck, 16);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsAck(settingsAck, pos);
  FConn.Feed(@settingsAck[0], pos);
  Should(FConn.State).Be(Ord(THttp2ConnectionState.csOpen));
end;

{ TConnectionPingTests }

procedure TConnectionPingTests.OnOutput(AData: PByte; ALen: Integer);
begin
  if FOutputLen + ALen > Length(FOutput) then
    SetLength(FOutput, FOutputLen + ALen + 256);
  if ALen > 0 then Move(AData^, FOutput[FOutputLen], ALen);
  Inc(FOutputLen, ALen);
end;

procedure TConnectionPingTests.FeedPreface;
var
  preface: TBytes;
begin
  preface := TEncoding.ASCII.GetBytes(HTTP2_CLIENT_PREFACE);
  FConn.Feed(@preface[0], Length(preface));
end;

procedure TConnectionPingTests.FeedSettingsExchange;
var
  clientSettings, settingsAck: TBytes;
  pos: Integer;
begin
  SetLength(clientSettings, 32);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsFrame(nil, False, clientSettings, pos);
  FConn.Feed(@clientSettings[0], pos);
  SetLength(settingsAck, 16);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsAck(settingsAck, pos);
  FConn.Feed(@settingsAck[0], pos);
end;

procedure TConnectionPingTests.Setup;
begin
  FConn := TDextHttp2Connection.Create(THttp2ConnectionOptions.Default);
  FConn.OnOutput := OnOutput;
  FOutputLen := 0;
  SetLength(FOutput, 4096);
end;

procedure TConnectionPingTests.Teardown;
begin
  FConn.Free;
end;

procedure TConnectionPingTests.ReceivePing_ShouldEchoAsPingAck;
var
  pingBuf: TBytes;
  payload: array[0..7] of Byte;
  pos: Integer;
  prevOut: Integer;
  frame: THttp2Frame;
  consumed: Integer;
  i: Integer;
begin
  FeedPreface;
  FeedSettingsExchange;
  prevOut := FOutputLen;

  // Build PING frame with known 8-byte payload
  FillChar(payload[0], 8, $AB);
  SetLength(pingBuf, 32);
  pos := 0;
  TDextHttp2FrameCodec.WritePingAck(@payload[0], pingBuf, pos); // Note: WritePingAck writes ACK=1
  // We need a PING (not PING ACK) — build manually
  // length=8, type=6, flags=0, stream=0, payload=8x$AB
  SetLength(pingBuf, 17);
  pingBuf[0] := 0; pingBuf[1] := 0; pingBuf[2] := 8; // length
  pingBuf[3] := 6;  // PING
  pingBuf[4] := 0;  // flags = 0 (not ACK)
  pingBuf[5] := 0; pingBuf[6] := 0; pingBuf[7] := 0; pingBuf[8] := 0; // stream = 0
  FillChar(pingBuf[9], 8, $AB);

  FConn.Feed(@pingBuf[0], 17);

  // Look for PING ACK in output
  i := prevOut;
  while i + 9 <= FOutputLen do
  begin
    if TDextHttp2FrameCodec.TryReadFrame(@FOutput[i], FOutputLen - i,
      HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed) then
    begin
      if (frame.FrameType = Byte(THttp2FrameType.ftPing)) and
         TDextHttp2FrameCodec.HasAck(frame) then
      begin
        // Verify echo
        Should(frame.PayloadPtr[0]).Be($AB);
        Should(frame.PayloadPtr[7]).Be($AB);
        Exit;
      end;
      Inc(i, consumed);
    end
    else
      Break;
  end;
  Should(False).BeTrue; // Should not reach here: PING ACK not found
end;

{ TConnectionRequestTests }

procedure TConnectionRequestTests.OnOutput(AData: PByte; ALen: Integer);
begin
  if FOutputLen + ALen > Length(FOutput) then
    SetLength(FOutput, FOutputLen + ALen + 256);
  if ALen > 0 then Move(AData^, FOutput[FOutputLen], ALen);
  Inc(FOutputLen, ALen);
end;

procedure TConnectionRequestTests.OnRequest(AConn: TObject; AStreamId: Cardinal;
  const AHeaders: TNameValuePairs; const ABody: TBytes);
begin
  FReceivedStreamId := AStreamId;
  FReceivedHeaders  := AHeaders;
  FReceivedBody     := ABody;
end;

procedure TConnectionRequestTests.FeedPreface;
var
  preface: TBytes;
begin
  preface := TEncoding.ASCII.GetBytes(HTTP2_CLIENT_PREFACE);
  FConn.Feed(@preface[0], Length(preface));
end;

procedure TConnectionRequestTests.FeedSettingsExchange;
var
  clientSettings, settingsAck: TBytes;
  pos: Integer;
begin
  SetLength(clientSettings, 32);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsFrame(nil, False, clientSettings, pos);
  FConn.Feed(@clientSettings[0], pos);
  SetLength(settingsAck, 16);
  pos := 0;
  TDextHttp2FrameCodec.WriteSettingsAck(settingsAck, pos);
  FConn.Feed(@settingsAck[0], pos);
end;

function TConnectionRequestTests.BuildGetRequest(AStreamId: Cardinal): TBytes;
var
  enc: THpackEncoder;
  headers: TNameValuePairs;
  headerBlock: TBytes;
  pos: Integer;
begin
  enc := THpackEncoder.Create;
  try
    SetLength(headers, 4);
    headers[0].Name := ':method';    headers[0].Value := 'GET';
    headers[1].Name := ':path';      headers[1].Value := '/hello';
    headers[2].Name := ':scheme';    headers[2].Value := 'https';
    headers[3].Name := ':authority'; headers[3].Value := 'example.com';
    headerBlock := enc.Encode(headers);
  finally
    enc.Free;
  end;
  SetLength(Result, 9 + Length(headerBlock));
  pos := 0;
  TDextHttp2FrameCodec.WriteHeadersFrame(AStreamId,
    @headerBlock[0], Length(headerBlock),
    True,  // END_STREAM (no body on GET)
    True,  // END_HEADERS
    Result, pos);
  SetLength(Result, pos);
end;

procedure TConnectionRequestTests.Setup;
begin
  FConn := TDextHttp2Connection.Create(THttp2ConnectionOptions.Default);
  FConn.OnOutput := OnOutput;
  FConn.OnRequest := OnRequest;
  FOutputLen := 0;
  FReceivedStreamId := 0;
  SetLength(FOutput, 4096);
end;

procedure TConnectionRequestTests.Teardown;
begin
  FConn.Free;
end;

procedure TConnectionRequestTests.CompleteGetRequest_ShouldFireOnRequest;
var
  request: TBytes;
begin
  FeedPreface;
  FeedSettingsExchange;
  request := BuildGetRequest(1);
  FConn.Feed(@request[0], Length(request));
  Should(FReceivedStreamId).Be(1);
end;

procedure TConnectionRequestTests.OnRequest_ShouldReceiveCorrectStreamId;
var
  request: TBytes;
begin
  FeedPreface;
  FeedSettingsExchange;
  request := BuildGetRequest(5);
  FConn.Feed(@request[0], Length(request));
  Should(FReceivedStreamId).Be(5);
end;

procedure TConnectionRequestTests.SendResponse_ShouldProduceValidHeadersFrame;
var
  request: TBytes;
  responseHeaders: TNameValuePairs;
  prevOut: Integer;
  frame: THttp2Frame;
  consumed: Integer;
begin
  FeedPreface;
  FeedSettingsExchange;
  request := BuildGetRequest(1);
  FConn.Feed(@request[0], Length(request));

  prevOut := FOutputLen;
  SetLength(responseHeaders, 1);
  responseHeaders[0].Name := ':status';
  responseHeaders[0].Value := '200';
  FConn.SendResponse(1, responseHeaders, nil, True);

  // Output should contain a HEADERS frame
  Should(TDextHttp2FrameCodec.TryReadFrame(@FOutput[prevOut], FOutputLen - prevOut,
    HTTP2_DEFAULT_MAX_FRAME_SIZE, frame, consumed)).BeTrue;
  Should(frame.FrameType).Be(Byte(THttp2FrameType.ftHeaders));
end;

procedure TConnectionRequestTests.SendGoaway_ShouldTransitionToClosing;
begin
  FeedPreface;
  FeedSettingsExchange;
  FConn.SendGoaway(HTTP2_ERR_NO_ERROR, '');
  Should(FConn.State).Be(Ord(THttp2ConnectionState.csClosing));
end;

end.
