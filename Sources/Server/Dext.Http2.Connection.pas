{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2026-06-18                                                      }
{                                                                           }
{  HTTP/2 connection state machine (RFC 9113).                              }
{  Orchestrates: client preface validation, SETTINGS handshake,            }
{  frame demultiplexing, flow control, GOAWAY and graceful drain.           }
{                                                                           }
{***************************************************************************}
unit Dext.Http2.Connection;

{$I Dext.inc}
{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Dext.Http2.Hpack,
  Dext.Http2.Framing,
  Dext.Http2.Stream;

type
  /// <summary>Lifecycle phases of an HTTP/2 connection.</summary>
  THttp2ConnectionState = (
    csAwaitingPreface,   // Waiting for the 24-byte client preface
    csSettingsExchange,  // Preface received; SETTINGS handshake in progress
    csOpen,              // Fully established; processing frames
    csClosing,           // GOAWAY sent; draining existing streams
    csClosed             // Connection is terminated
  );

  TOutputProc = reference to procedure(AData: PByte; ALen: Integer);

  /// <summary>
  ///   Configuration options for a TDextHttp2Connection instance.
  ///   Populated from negotiated SETTINGS parameters.
  /// </summary>
  THttp2ConnectionOptions = record
    /// <summary>Maximum concurrent streams (SETTINGS_MAX_CONCURRENT_STREAMS). Default: 100.</summary>
    MaxConcurrentStreams: Cardinal;
    /// <summary>Initial flow-control window size for new streams. Default: 65535.</summary>
    InitialWindowSize: Integer;
    /// <summary>Maximum payload size per frame (SETTINGS_MAX_FRAME_SIZE). Default: 16384.</summary>
    MaxFrameSize: Cardinal;
    /// <summary>Maximum header list size (SETTINGS_MAX_HEADER_LIST_SIZE). Default: 65536.</summary>
    MaxHeaderListSize: Cardinal;
    /// <summary>HPACK dynamic table size (SETTINGS_HEADER_TABLE_SIZE). Default: 4096.</summary>
    HeaderTableSize: Cardinal;
    /// <summary>Returns a record with RFC-default values.</summary>
    class function Default: THttp2ConnectionOptions; static;
  end;

  /// <summary>
  ///   Event fired when a complete HTTP/2 request is assembled on a stream.
  ///   AStreamId identifies which stream the request arrived on.
  ///   AHeaders contains the decoded request pseudo-headers + headers.
  ///   ABody contains the full request body (may be empty for GET/HEAD).
  /// </summary>
  THttp2RequestHandler = reference to procedure(
    AConnection: TObject;
    AStreamId: Cardinal;
    const AHeaders: TNameValuePairs;
    const ABody: TBytes
  );

  /// <summary>
  ///   Event fired when the connection has been fully closed (after drain).
  /// </summary>
  THttp2CloseHandler = reference to procedure(AConnection: TObject);

  /// <summary>
  ///   Manages the complete lifecycle of a single HTTP/2 connection.
  ///
  ///   Usage:
  ///     conn := TDextHttp2Connection.Create(options);
  ///     conn.OnRequest := procedure(c, sid, hdrs, body) begin ... end;
  ///     // On each raw bytes received from socket:
  ///     conn.Feed(buffer, bytesReceived);
  ///     // To send a response:
  ///     conn.SendResponse(streamId, responseHeaders, responseBody, True);
  ///     // To close gracefully:
  ///     conn.SendGoaway(HTTP2_ERR_NO_ERROR, '');
  /// </summary>
  TDextHttp2Connection = class
  private
    FState: THttp2ConnectionState;
    FOptions: THttp2ConnectionOptions;

    // HPACK
    FDecoder: THpackDecoder;
    FEncoder: THpackEncoder;

    // Stream management
    FStreams: TDextHttp2StreamMap;
    FLastStreamId: Cardinal;

    // Receive buffer (accumulates partial frames)
    FRecvBuffer: TBytes;
    FRecvLen: Integer;

    // Flow control - connection-level
    FConnRecvWindow: Integer;
    FConnSendWindow: Integer;

    // SETTINGS state
    FPeerSettingsSynced: Boolean;  // True after receiving first SETTINGS ACK
    FLocalSettingsSent: Boolean;

    // Output buffer - all outgoing bytes queued here
    FOutputBuffer: TBytes;
    FOutputLen: Integer;

    // Continuation frame accumulation state
    FContinuationStreamId: Cardinal;  // 0 = not accumulating

    // Callbacks
    FOnRequest: THttp2RequestHandler;
    FOnClose: THttp2CloseHandler;
    FOnOutput: TOutputProc;

    // Internal frame handlers
    procedure HandleData(const AFrame: THttp2Frame);
    procedure HandleHeaders(const AFrame: THttp2Frame);
    procedure HandlePriority(const AFrame: THttp2Frame);
    procedure HandleRstStream(const AFrame: THttp2Frame);
    procedure HandleSettings(const AFrame: THttp2Frame);
    procedure HandlePing(const AFrame: THttp2Frame);
    procedure HandleGoaway(const AFrame: THttp2Frame);
    procedure HandleWindowUpdate(const AFrame: THttp2Frame);
    procedure HandleContinuation(const AFrame: THttp2Frame);

    // Internal helpers
    procedure SendProtocolError(const AMessage: string);
    procedure FlushOutput;
    procedure DispatchRequest(AStream: TDextHttp2Stream);
    procedure EnsureStream(AStreamId: Cardinal; out AStream: TDextHttp2Stream);
    function ValidatePreface: Boolean;
    procedure SendInitialSettings;
  public
    /// <summary>Creates a new HTTP/2 connection with the specified options.</summary>
    constructor Create(const AOptions: THttp2ConnectionOptions);
    /// <summary>Frees all resources held by this connection.</summary>
    destructor Destroy; override;

    // ------------------------------------------------------------------
    //  Data path
    // ------------------------------------------------------------------

    /// <summary>
    ///   Feeds raw bytes received from the socket into the connection state machine.
    ///   The connection will parse complete frames, update state, fire OnRequest
    ///   callbacks, and enqueue any response bytes into the output buffer.
    ///   Call FlushOutput (or set OnOutput) to retrieve generated bytes.
    /// </summary>
    /// <param name="AData">Pointer to received bytes.</param>
    /// <param name="ALen">Number of bytes received.</param>
    procedure Feed(AData: PByte; ALen: Integer); overload;

    /// <summary>Convenience overload that accepts a TBytes buffer with offset.</summary>
    procedure Feed(const ABuffer: TBytes; AOffset, ALen: Integer); overload;

    // ------------------------------------------------------------------
    //  Response path
    // ------------------------------------------------------------------

    /// <summary>
    ///   Sends a complete HTTP/2 response on the given stream.
    ///   AHeaders must include :status at index 0.
    ///   Set AEndStream=True when the response body is the final data (closes the stream).
    ///   If the body exceeds MaxFrameSize it is automatically split into multiple DATA frames.
    /// </summary>
    procedure SendResponse(AStreamId: Cardinal;
      const AHeaders: TNameValuePairs;
      const ABody: TBytes;
      AEndStream: Boolean = True);

    /// <summary>
    ///   Sends a GOAWAY frame and transitions the connection to Closing state.
    ///   Existing open streams will continue until they complete or time out.
    /// </summary>
    procedure SendGoaway(AErrorCode: Cardinal = HTTP2_ERR_NO_ERROR;
      const ADebugMessage: string = '');

    /// <summary>Sends a connection-level WINDOW_UPDATE to the peer.</summary>
    procedure SendWindowUpdate(AStreamId: Cardinal; AIncrement: Cardinal);

    // ------------------------------------------------------------------
    //  Properties & callbacks
    // ------------------------------------------------------------------

    /// <summary>Current connection state.</summary>
    property State: THttp2ConnectionState read FState;

    /// <summary>Last stream ID seen from the client (used in GOAWAY).</summary>
    property LastStreamId: Cardinal read FLastStreamId;

    /// <summary>
    ///   Fired when a complete request (all headers + all DATA) is received on a stream.
    ///   The handler should call SendResponse to reply.
    /// </summary>
    property OnRequest: THttp2RequestHandler read FOnRequest write FOnRequest;

    /// <summary>Fired when the connection is fully closed.</summary>
    property OnClose: THttp2CloseHandler read FOnClose write FOnClose;

    /// <summary>
    ///   Called whenever bytes are available to send to the peer.
    ///   If not assigned, callers must retrieve pending output via PendingOutput.
    ///   Signature: procedure(AData: PByte; ALen: Integer).
    /// </summary>
    property OnOutput: TOutputProc read FOnOutput write FOnOutput;

    /// <summary>Returns the number of pending output bytes (not yet flushed).</summary>
    function PendingOutputLen: Integer;

    /// <summary>Copies pending output bytes to ABuffer (up to AMaxLen) and drains the queue.</summary>
    function ReadOutput(ABuffer: PByte; AMaxLen: Integer): Integer;
  end;

implementation

{ THttp2ConnectionOptions }

class function THttp2ConnectionOptions.Default: THttp2ConnectionOptions;
begin
  Result.MaxConcurrentStreams := 100;
  Result.InitialWindowSize    := 65535;
  Result.MaxFrameSize         := HTTP2_DEFAULT_MAX_FRAME_SIZE;
  Result.MaxHeaderListSize    := 65536;
  Result.HeaderTableSize      := 4096;
end;

{ TDextHttp2Connection }

constructor TDextHttp2Connection.Create(const AOptions: THttp2ConnectionOptions);
begin
  inherited Create;
  FOptions  := AOptions;
  FState    := THttp2ConnectionState.csAwaitingPreface;
  FDecoder  := THpackDecoder.Create(AOptions.HeaderTableSize);
  FEncoder  := THpackEncoder.Create(AOptions.HeaderTableSize);
  FStreams  := TDextHttp2StreamMap.Create(AOptions.InitialWindowSize);

  FRecvLen              := 0;
  FOutputLen            := 0;
  FConnRecvWindow       := 65535;
  FConnSendWindow       := 65535;
  FLastStreamId         := 0;
  FPeerSettingsSynced   := False;
  FLocalSettingsSent    := False;
  FContinuationStreamId := 0;

  SetLength(FRecvBuffer, 65536);
  SetLength(FOutputBuffer, 4096);
end;

destructor TDextHttp2Connection.Destroy;
begin
  FDecoder.Free;
  FEncoder.Free;
  FStreams.Free;
  inherited;
end;



procedure TDextHttp2Connection.FlushOutput;
begin
  if (FOutputLen > 0) and Assigned(FOnOutput) then
  begin
    FOnOutput(@FOutputBuffer[0], FOutputLen);
    FOutputLen := 0;
  end;
end;

function TDextHttp2Connection.PendingOutputLen: Integer;
begin
  Result := FOutputLen;
end;

function TDextHttp2Connection.ReadOutput(ABuffer: PByte; AMaxLen: Integer): Integer;
begin
  Result := FOutputLen;
  if Result > AMaxLen then Result := AMaxLen;
  if Result > 0 then
  begin
    Move(FOutputBuffer[0], ABuffer^, Result);
    // Drain what was read
    if Result < FOutputLen then
      Move(FOutputBuffer[Result], FOutputBuffer[0], FOutputLen - Result);
    Dec(FOutputLen, Result);
  end;
end;

function TDextHttp2Connection.ValidatePreface: Boolean;
const
  PREFACE_LEN = 24;
var
  prefaceBytes: TBytes;
begin
  Result := False;
  if FRecvLen < PREFACE_LEN then Exit;
  prefaceBytes := TEncoding.ASCII.GetBytes(HTTP2_CLIENT_PREFACE);
  Result := CompareMem(@FRecvBuffer[0], @prefaceBytes[0], PREFACE_LEN);
end;

procedure TDextHttp2Connection.SendInitialSettings;
var
  settings: THttp2Settings;
  pos: Integer;
begin
  settings := DefaultServerSettings;
  pos := FOutputLen;
  TDextHttp2FrameCodec.WriteSettingsFrame(settings, False, FOutputBuffer, pos);
  FOutputLen := pos;
  FLocalSettingsSent := True;
end;

procedure TDextHttp2Connection.Feed(AData: PByte; ALen: Integer);
const
  PREFACE_LEN = 24;
var
  frame: THttp2Frame;
  consumed: Integer;
  ptr: PByte;
  avail: Integer;
begin
  if FState = THttp2ConnectionState.csClosed then Exit;

  // Append to internal receive buffer
  if FRecvLen + ALen > Length(FRecvBuffer) then
    SetLength(FRecvBuffer, FRecvLen + ALen + 4096);
  Move(AData^, FRecvBuffer[FRecvLen], ALen);
  Inc(FRecvLen, ALen);

  // --- Phase: Awaiting client preface ---
  if FState = THttp2ConnectionState.csAwaitingPreface then
  begin
    if FRecvLen < PREFACE_LEN then Exit; // need more data
    if not ValidatePreface then
    begin
      SendProtocolError('Invalid client preface');
      Exit;
    end;
    // Consume preface bytes
    Move(FRecvBuffer[PREFACE_LEN], FRecvBuffer[0], FRecvLen - PREFACE_LEN);
    Dec(FRecvLen, PREFACE_LEN);

    FState := THttp2ConnectionState.csSettingsExchange;
    // Send our SETTINGS immediately
    SendInitialSettings;
    FlushOutput;
  end;

  // --- Phase: Frame parsing loop ---
  ptr   := @FRecvBuffer[0];
  avail := FRecvLen;

  while avail > 0 do
  begin
    if not TDextHttp2FrameCodec.TryReadFrame(ptr, avail, FOptions.MaxFrameSize,
      frame, consumed) then
      Break; // need more data - leave bytes in buffer

    // Dispatch by frame type
    case THttp2FrameType(frame.FrameType) of
      THttp2FrameType.ftData:         HandleData(frame);
      THttp2FrameType.ftHeaders:      HandleHeaders(frame);
      THttp2FrameType.ftPriority:     HandlePriority(frame);
      THttp2FrameType.ftRstStream:    HandleRstStream(frame);
      THttp2FrameType.ftSettings:     HandleSettings(frame);
      THttp2FrameType.ftPing:         HandlePing(frame);
      THttp2FrameType.ftGoaway:       HandleGoaway(frame);
      THttp2FrameType.ftWindowUpdate: HandleWindowUpdate(frame);
      THttp2FrameType.ftContinuation: HandleContinuation(frame);
      // PUSH_PROMISE: clients don't send; ignore silently
    end;

    Inc(ptr, consumed);
    Dec(avail, consumed);

    if FState = THttp2ConnectionState.csClosed then Break;
  end;

  // Compact the receive buffer - move leftover bytes to front
  FRecvLen := avail;
  if (avail > 0) and (ptr <> @FRecvBuffer[0]) then
    Move(ptr^, FRecvBuffer[0], avail);

  FlushOutput;
end;

procedure TDextHttp2Connection.Feed(const ABuffer: TBytes; AOffset, ALen: Integer);
begin
  if ALen > 0 then
    Feed(@ABuffer[AOffset], ALen);
end;

procedure TDextHttp2Connection.EnsureStream(AStreamId: Cardinal; out AStream: TDextHttp2Stream);
begin
  AStream := FStreams.Find(AStreamId);
  if AStream = nil then
    AStream := FStreams.OpenStream(AStreamId);
end;

procedure TDextHttp2Connection.DispatchRequest(AStream: TDextHttp2Stream);
var
  body: TBytes;
begin
  if Assigned(FOnRequest) then
  begin
    SetLength(body, AStream.DataLen);
    if AStream.DataLen > 0 then
      Move(AStream.DataBuffer[0], body[0], AStream.DataLen);
    FOnRequest(Self, AStream.StreamId, AStream.Headers, body);
  end;
end;

procedure TDextHttp2Connection.HandleData(const AFrame: THttp2Frame);
var
  Stream: TDextHttp2Stream;
  DataPtr: PByte;
  DataLen: Integer;
  Increment: Integer;
  Pos: Integer;
begin
  if AFrame.StreamId = 0 then
  begin
    SendProtocolError('DATA on Stream 0');
    Exit;
  end;

  Stream := FStreams.Find(AFrame.StreamId);
  if Stream = nil then
  begin
    // Unknown Stream - send RST_STREAM
    Pos := FOutputLen;
    TDextHttp2FrameCodec.WriteRstStream(AFrame.StreamId, HTTP2_ERR_STREAM_CLOSED, FOutputBuffer, Pos);
    FOutputLen := Pos;
    Exit;
  end;

  if not TDextHttp2FrameCodec.GetDataPayload(AFrame, DataPtr, DataLen) then
  begin
    SendProtocolError('Invalid DATA frame');
    Exit;
  end;

  // Flow control accounting
  Dec(FConnRecvWindow, DataLen);
  Stream.ConsumeRecvWindow(DataLen);

  Stream.AppendData(DataPtr, DataLen);

  if TDextHttp2FrameCodec.HasEndStream(AFrame) then
  begin
    Stream.RemoteEndStream;
    if Stream.HeadersComplete then
      DispatchRequest(Stream);
  end;

  // Auto-refill connection window if running low
  if FConnRecvWindow < 32768 then
  begin
    Increment := 65535 - FConnRecvWindow;
    SendWindowUpdate(0, Increment);
    Inc(FConnRecvWindow, Increment);
  end;
end;

procedure TDextHttp2Connection.HandleHeaders(const AFrame: THttp2Frame);
var
  stream: TDextHttp2Stream;
  fragPtr: PByte;
  fragLen: Integer;
begin
  if AFrame.StreamId = 0 then
  begin
    SendProtocolError('HEADERS on stream 0');
    Exit;
  end;

  EnsureStream(AFrame.StreamId, stream);
  if stream.State = THttp2StreamState.ssIdle then
    stream.Open;

  if not TDextHttp2FrameCodec.GetHeaderBlockFragment(AFrame, fragPtr, fragLen) then
  begin
    SendProtocolError('Invalid HEADERS frame');
    Exit;
  end;

  stream.AppendHeaderFragment(fragPtr, fragLen);

  if AFrame.StreamId > FLastStreamId then
    FLastStreamId := AFrame.StreamId;

  if TDextHttp2FrameCodec.HasEndHeaders(AFrame) then
  begin
    if not stream.FinalizeHeaders(FDecoder) then
    begin
      SendProtocolError('HPACK decode error');
      Exit;
    end;
    FContinuationStreamId := 0;

    if TDextHttp2FrameCodec.HasEndStream(AFrame) then
    begin
      stream.RemoteEndStream;
      DispatchRequest(stream);
    end;
  end
  else
  begin
    // Expect CONTINUATION frames
    FContinuationStreamId := AFrame.StreamId;
  end;
end;

procedure TDextHttp2Connection.HandlePriority(const AFrame: THttp2Frame);
begin
  // PRIORITY is deprecated in RFC 9113 §5.3.2; parse and ignore
end;

procedure TDextHttp2Connection.HandleRstStream(const AFrame: THttp2Frame);
var
  stream: TDextHttp2Stream;
  errCode: Cardinal;
begin
  if AFrame.StreamId = 0 then
  begin
    SendProtocolError('RST_STREAM on stream 0');
    Exit;
  end;
  stream := FStreams.Find(AFrame.StreamId);
  if stream = nil then Exit;
  TDextHttp2FrameCodec.GetRstStreamError(AFrame, errCode);
  stream.Reset(errCode);
end;

procedure TDextHttp2Connection.HandleSettings(const AFrame: THttp2Frame);
var
  settings: THttp2Settings;
  i: Integer;
  oldWindowSize: Integer;
  delta: Integer;
  pos: Integer;
begin
  if TDextHttp2FrameCodec.HasAck(AFrame) then
  begin
    // Peer acknowledged our SETTINGS
    if FState = THttp2ConnectionState.csSettingsExchange then
    begin
      FState := THttp2ConnectionState.csOpen;
      FPeerSettingsSynced := True;
    end;
    Exit;
  end;

  if not TDextHttp2FrameCodec.GetSettings(AFrame, settings) then
  begin
    SendProtocolError('Invalid SETTINGS frame');
    Exit;
  end;

  oldWindowSize := FOptions.InitialWindowSize;

  for i := 0 to High(settings) do
  begin
    case settings[i].Id of
      HTTP2_SETTINGS_HEADER_TABLE_SIZE:
        begin
          FOptions.HeaderTableSize := settings[i].Value;
          FDecoder.SetMaxTableSize(FOptions.HeaderTableSize);
        end;
      HTTP2_SETTINGS_ENABLE_PUSH:
        ; // We don't push; ignore
      HTTP2_SETTINGS_MAX_CONCURRENT_STREAMS:
        FOptions.MaxConcurrentStreams := settings[i].Value;
      HTTP2_SETTINGS_INITIAL_WINDOW_SIZE:
        begin
          FOptions.InitialWindowSize := Integer(settings[i].Value);
          FStreams.SetInitialWindowSize(FOptions.InitialWindowSize);
          // Adjust existing stream windows
          delta := FOptions.InitialWindowSize - oldWindowSize;
          if delta <> 0 then
            FStreams.ApplyWindowSizeDelta(delta);
        end;
      HTTP2_SETTINGS_MAX_FRAME_SIZE:
        begin
          if (settings[i].Value < 16384) or (settings[i].Value > $FFFFFF) then
          begin
            SendProtocolError('Invalid SETTINGS_MAX_FRAME_SIZE');
            Exit;
          end;
          FOptions.MaxFrameSize := settings[i].Value;
        end;
      HTTP2_SETTINGS_MAX_HEADER_LIST_SIZE:
        FOptions.MaxHeaderListSize := settings[i].Value;
    end;
  end;

  // Send ACK
  pos := FOutputLen;
  TDextHttp2FrameCodec.WriteSettingsAck(FOutputBuffer, pos);
  FOutputLen := pos;

  // If this was the first SETTINGS from the peer and we're in exchange phase,
  // transition - but we still need to wait for OUR settings ACK
  // (see HandleSettings ACK branch above)
end;

procedure TDextHttp2Connection.HandlePing(const AFrame: THttp2Frame);
var
  pos: Integer;
begin
  if AFrame.StreamId <> 0 then
  begin
    SendProtocolError('PING on non-zero stream');
    Exit;
  end;
  if TDextHttp2FrameCodec.HasAck(AFrame) then
    Exit; // Ignore PING ACKs for now
  // Echo back as PING ACK
  pos := FOutputLen;
  TDextHttp2FrameCodec.WritePingAck(AFrame.PayloadPtr, FOutputBuffer, pos);
  FOutputLen := pos;
end;

procedure TDextHttp2Connection.HandleGoaway(const AFrame: THttp2Frame);
var
  lastSid, errCode: Cardinal;
  debugData: TBytes;
begin
  TDextHttp2FrameCodec.GetGoaway(AFrame, lastSid, errCode, debugData);
  FState := THttp2ConnectionState.csClosed;
  if Assigned(FOnClose) then
    FOnClose(Self);
end;

procedure TDextHttp2Connection.HandleWindowUpdate(const AFrame: THttp2Frame);
var
  Increment: Cardinal;
  Stream: TDextHttp2Stream;
  Pos: Integer;
begin
  if not TDextHttp2FrameCodec.GetWindowUpdateIncrement(AFrame, Increment) then
  begin
    SendProtocolError('Invalid WINDOW_UPDATE');
    Exit;
  end;
  if Increment = 0 then
  begin
    if AFrame.StreamId = 0 then
      SendProtocolError('WINDOW_UPDATE Increment 0 on connection')
    else
    begin
      // Stream-level PROTOCOL_ERROR
      Pos := FOutputLen;
      TDextHttp2FrameCodec.WriteRstStream(AFrame.StreamId, HTTP2_ERR_PROTOCOL_ERROR, FOutputBuffer, Pos);
      FOutputLen := Pos;
    end;
    Exit;
  end;
  if AFrame.StreamId = 0 then
    Inc(FConnSendWindow, Increment)
  else
  begin
    Stream := FStreams.Find(AFrame.StreamId);
    if Stream <> nil then
      Stream.IncreaseSendWindow(Increment);
  end;
end;

procedure TDextHttp2Connection.HandleContinuation(const AFrame: THttp2Frame);
var
  stream: TDextHttp2Stream;
  fragPtr: PByte;
  fragLen: Integer;
begin
  if AFrame.StreamId = 0 then
  begin
    SendProtocolError('CONTINUATION on stream 0');
    Exit;
  end;
  if AFrame.StreamId <> FContinuationStreamId then
  begin
    SendProtocolError('CONTINUATION on unexpected stream');
    Exit;
  end;

  stream := FStreams.Find(AFrame.StreamId);
  if stream = nil then Exit;

  fragPtr := AFrame.PayloadPtr;
  fragLen := Integer(AFrame.PayloadLength);
  stream.AppendHeaderFragment(fragPtr, fragLen);

  if TDextHttp2FrameCodec.HasEndHeaders(AFrame) then
  begin
    if not stream.FinalizeHeaders(FDecoder) then
    begin
      SendProtocolError('HPACK decode error in CONTINUATION');
      Exit;
    end;
    FContinuationStreamId := 0;
    if stream.EndStreamReceived then
      DispatchRequest(stream);
  end;
end;

procedure TDextHttp2Connection.SendProtocolError(const AMessage: string);
begin
  SendGoaway(HTTP2_ERR_PROTOCOL_ERROR, AMessage);
end;

procedure TDextHttp2Connection.SendResponse(AStreamId: Cardinal;
  const AHeaders: TNameValuePairs;
  const ABody: TBytes;
  AEndStream: Boolean);
var
  headerBlock: TBytes;
  pos: Integer;
  bodyEndStream: Boolean;
  offset: Integer;
  chunk: Integer;
  maxChunk: Integer;
  stream: TDextHttp2Stream;
begin
  headerBlock := FEncoder.Encode(AHeaders);
  pos := FOutputLen;

  // Determine if END_STREAM goes on HEADERS or DATA
  bodyEndStream := AEndStream and (Length(ABody) = 0);

  TDextHttp2FrameCodec.WriteHeadersFrame(AStreamId,
    @headerBlock[0], Length(headerBlock),
    bodyEndStream,
    True,   // always END_HEADERS in single HEADERS frame for responses
    FOutputBuffer, pos);

  if Length(ABody) > 0 then
  begin
    maxChunk := Integer(FOptions.MaxFrameSize);
    offset := 0;
    while offset < Length(ABody) do
    begin
      chunk := Length(ABody) - offset;
      if chunk > maxChunk then chunk := maxChunk;
      bodyEndStream := AEndStream and (offset + chunk >= Length(ABody));
      TDextHttp2FrameCodec.WriteDataFrame(AStreamId,
        @ABody[offset], chunk,
        bodyEndStream,
        FOutputBuffer, pos);
      Inc(offset, chunk);
    end;
  end;

  FOutputLen := pos;

  // Update stream state
  stream := FStreams.Find(AStreamId);
  if stream <> nil then
  begin
    if AEndStream then
    begin
      stream.LocalEndStream;
      if stream.State = THttp2StreamState.ssClosed then
        FStreams.Remove(AStreamId);
    end;
  end;

  FlushOutput;
end;

procedure TDextHttp2Connection.SendGoaway(AErrorCode: Cardinal;
  const ADebugMessage: string);
var
  pos: Integer;
begin
  if FState = THttp2ConnectionState.csClosed then Exit;
  pos := FOutputLen;
  TDextHttp2FrameCodec.WriteGoaway(FLastStreamId, AErrorCode, ADebugMessage, FOutputBuffer, pos);
  FOutputLen := pos;
  FState := THttp2ConnectionState.csClosing;
  FlushOutput;
end;

procedure TDextHttp2Connection.SendWindowUpdate(AStreamId: Cardinal; AIncrement: Cardinal);
var
  pos: Integer;
begin
  pos := FOutputLen;
  TDextHttp2FrameCodec.WriteWindowUpdate(AStreamId, AIncrement, FOutputBuffer, pos);
  FOutputLen := pos;
end;

end.
