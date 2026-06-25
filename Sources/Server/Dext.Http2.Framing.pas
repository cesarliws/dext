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
{  HTTP/2 Frame encoding and decoding (RFC 9113).                           }
{  Provides zero-copy TryReadFrame (incremental parse from raw buffers)     }
{  and type-safe Write helpers for each of the 10 frame types.              }
{                                                                           }
{***************************************************************************}
unit Dext.Http2.Framing;

{$I Dext.inc}
{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.SysUtils;

const
  /// <summary>Minimum bytes to read before a frame header is complete (RFC 9113 §4.1).</summary>
  HTTP2_FRAME_HEADER_SIZE = 9;

  /// <summary>Default maximum payload size per frame (16 KB). May be increased via SETTINGS.</summary>
  HTTP2_DEFAULT_MAX_FRAME_SIZE = 16384;

  /// <summary>HTTP/2 client connection preface (RFC 9113 §3.4).</summary>
  HTTP2_CLIENT_PREFACE = 'PRI * HTTP/2.0'#13#10#13#10'SM'#13#10#13#10;

  // SETTINGS identifiers (RFC 9113 §6.5.2)
  HTTP2_SETTINGS_HEADER_TABLE_SIZE      = $1;
  HTTP2_SETTINGS_ENABLE_PUSH            = $2;
  HTTP2_SETTINGS_MAX_CONCURRENT_STREAMS = $3;
  HTTP2_SETTINGS_INITIAL_WINDOW_SIZE    = $4;
  HTTP2_SETTINGS_MAX_FRAME_SIZE         = $5;
  HTTP2_SETTINGS_MAX_HEADER_LIST_SIZE   = $6;

  // HTTP/2 error codes (RFC 9113 §7)
  HTTP2_ERR_NO_ERROR            = $0;
  HTTP2_ERR_PROTOCOL_ERROR      = $1;
  HTTP2_ERR_INTERNAL_ERROR      = $2;
  HTTP2_ERR_FLOW_CONTROL_ERROR  = $3;
  HTTP2_ERR_SETTINGS_TIMEOUT    = $4;
  HTTP2_ERR_STREAM_CLOSED       = $5;
  HTTP2_ERR_FRAME_SIZE_ERROR    = $6;
  HTTP2_ERR_REFUSED_STREAM      = $7;
  HTTP2_ERR_CANCEL              = $8;
  HTTP2_ERR_COMPRESSION_ERROR   = $9;
  HTTP2_ERR_CONNECT_ERROR       = $A;
  HTTP2_ERR_ENHANCE_YOUR_CALM   = $B;
  HTTP2_ERR_INADEQUATE_SECURITY = $C;
  HTTP2_ERR_HTTP_1_1_REQUIRED   = $D;

type
  /// <summary>HTTP/2 frame type identifiers (RFC 9113 §6).</summary>
  THttp2FrameType = (
    ftData         = $00,  // Request/response body
    ftHeaders      = $01,  // Header block (HPACK)
    ftPriority     = $02,  // Stream priority (deprecated)
    ftRstStream    = $03,  // Stream reset
    ftSettings     = $04,  // Connection configuration
    ftPushPromise  = $05,  // Server push (parse only - not generated)
    ftPing         = $06,  // Liveness check
    ftGoaway       = $07,  // Graceful shutdown
    ftWindowUpdate = $08,  // Flow control
    ftContinuation = $09   // Header block continuation
  );

  /// <summary>
  ///   Parsed representation of an HTTP/2 frame header + reference to the payload bytes.
  ///   The Payload field is a direct reference into the caller's buffer - zero copy.
  /// </summary>
  THttp2Frame = record
    /// <summary>Payload length in bytes (24-bit field from wire format).</summary>
    PayloadLength: Cardinal;
    /// <summary>Frame type byte (use THttp2FrameType enumeration).</summary>
    FrameType: Byte;
    /// <summary>Frame flags byte (meaning varies per frame type).</summary>
    Flags: Byte;
    /// <summary>Stream identifier (31-bit, bit 31 reserved/zero).</summary>
    StreamId: Cardinal;
    /// <summary>Pointer into the source buffer at the start of frame payload.</summary>
    PayloadPtr: PByte;
  end;

  /// <summary>A single SETTINGS parameter key/value pair.</summary>
  THttp2Setting = record
    Id: Word;
    Value: Cardinal;
  end;

  /// <summary>Array of SETTINGS parameters.</summary>
  THttp2Settings = array of THttp2Setting;

  /// <summary>
  ///   Provides zero-copy HTTP/2 frame parsing and type-safe write helpers.
  ///   All methods are class-level - no instance needed.
  /// </summary>
  TDextHttp2FrameCodec = class
  private
    class function Read3(P: PByte): Cardinal; static; inline;
    class function Read4(P: PByte): Cardinal; static; inline;
    class procedure AppendBytes(var AOutput: TBytes; var APos: Integer;
      AData: PByte; ALen: Integer); static;
    class procedure GrowIfNeeded(var AOutput: TBytes; APos, ANeeded: Integer); static; inline;
  public
    // ------------------------------------------------------------------
    //  Reader
    // ------------------------------------------------------------------

    /// <summary>
    ///   Attempts to parse a single HTTP/2 frame from the given byte buffer.
    ///   Returns False and sets ABytesConsumed to 0 if the buffer does not yet
    ///   hold a complete frame (incremental - safe for stream reassembly).
    /// </summary>
    /// <param name="ABuffer">Pointer to the start of the receive buffer.</param>
    /// <param name="AAvail">Number of bytes available in the buffer.</param>
    /// <param name="AMaxFrameSize">Maximum allowed payload size (from SETTINGS).</param>
    /// <param name="AFrame">Output frame header + payload pointer.</param>
    /// <param name="ABytesConsumed">Number of bytes consumed from the buffer (header + payload).</param>
    /// <returns>True if a complete frame was parsed; False if more data is needed.</returns>
    class function TryReadFrame(ABuffer: PByte; AAvail: Integer;
      AMaxFrameSize: Cardinal;
      out AFrame: THttp2Frame; out ABytesConsumed: Integer): Boolean; static;

    // ------------------------------------------------------------------
    //  Payload accessors (call after TryReadFrame succeeds)
    // ------------------------------------------------------------------

    /// <summary>Returns True if the END_STREAM flag is set in AFrame.</summary>
    class function HasEndStream(const AFrame: THttp2Frame): Boolean; static; inline;
    /// <summary>Returns True if the END_HEADERS flag is set in AFrame.</summary>
    class function HasEndHeaders(const AFrame: THttp2Frame): Boolean; static; inline;
    /// <summary>Returns True if the ACK flag is set (SETTINGS / PING).</summary>
    class function HasAck(const AFrame: THttp2Frame): Boolean; static; inline;
    /// <summary>Returns True if the PADDED flag is set.</summary>
    class function HasPadded(const AFrame: THttp2Frame): Boolean; static; inline;

    /// <summary>
    ///   Extracts the HEADERS payload: strips padding and PRIORITY prefix if present.
    ///   Returns a pointer and length into the original frame payload - zero copy.
    /// </summary>
    class function GetHeaderBlockFragment(const AFrame: THttp2Frame;
      out AData: PByte; out ALen: Integer): Boolean; static;

    /// <summary>
    ///   Extracts the DATA payload: strips the padding prefix/suffix if present.
    ///   Returns a pointer and length into the original frame payload - zero copy.
    /// </summary>
    class function GetDataPayload(const AFrame: THttp2Frame;
      out AData: PByte; out ALen: Integer): Boolean; static;

    /// <summary>Parses the RST_STREAM error code from the frame payload.</summary>
    class function GetRstStreamError(const AFrame: THttp2Frame;
      out AErrorCode: Cardinal): Boolean; static;

    /// <summary>Parses GOAWAY fields from the frame payload.</summary>
    class function GetGoaway(const AFrame: THttp2Frame;
      out ALastStreamId, AErrorCode: Cardinal;
      out ADebugData: TBytes): Boolean; static;

    /// <summary>Parses the WINDOW_UPDATE increment from the frame payload.</summary>
    class function GetWindowUpdateIncrement(const AFrame: THttp2Frame;
      out AIncrement: Cardinal): Boolean; static;

    /// <summary>Parses all SETTINGS parameters from a SETTINGS frame payload.</summary>
    class function GetSettings(const AFrame: THttp2Frame;
      out ASettings: THttp2Settings): Boolean; static;

    // ------------------------------------------------------------------
    //  Writers - append frame bytes to a caller-provided TBytes buffer
    // ------------------------------------------------------------------

    /// <summary>Appends a SETTINGS frame (with optional ACK flag) to AOutput.</summary>
    class procedure WriteSettingsFrame(const ASettings: THttp2Settings;
      AAck: Boolean; var AOutput: TBytes; var APos: Integer); static;

    /// <summary>Appends a SETTINGS ACK frame to AOutput.</summary>
    class procedure WriteSettingsAck(var AOutput: TBytes; var APos: Integer); static;

    /// <summary>Appends a PING ACK frame (echoing APayload) to AOutput.</summary>
    class procedure WritePingAck(APayload: PByte; var AOutput: TBytes; var APos: Integer); static;

    /// <summary>Appends a GOAWAY frame to AOutput.</summary>
    class procedure WriteGoaway(ALastStreamId, AErrorCode: Cardinal;
      const ADebugMessage: string; var AOutput: TBytes; var APos: Integer); static;

    /// <summary>Appends a WINDOW_UPDATE frame to AOutput.</summary>
    class procedure WriteWindowUpdate(AStreamId: Cardinal; AIncrement: Cardinal;
      var AOutput: TBytes; var APos: Integer); static;

    /// <summary>Appends a RST_STREAM frame to AOutput.</summary>
    class procedure WriteRstStream(AStreamId: Cardinal; AErrorCode: Cardinal;
      var AOutput: TBytes; var APos: Integer); static;

    /// <summary>
    ///   Appends a HEADERS frame to AOutput.
    ///   Set AEndStream=True for request-only (no DATA follows) or response trailers.
    /// </summary>
    class procedure WriteHeadersFrame(AStreamId: Cardinal;
      AHeaderBlock: PByte; AHeaderBlockLen: Integer;
      AEndStream, AEndHeaders: Boolean;
      var AOutput: TBytes; var APos: Integer); static;

    /// <summary>Appends a CONTINUATION frame to AOutput.</summary>
    class procedure WriteContinuationFrame(AStreamId: Cardinal;
      AHeaderBlock: PByte; AHeaderBlockLen: Integer;
      AEndHeaders: Boolean;
      var AOutput: TBytes; var APos: Integer); static;

    /// <summary>Appends a DATA frame to AOutput.</summary>
    class procedure WriteDataFrame(AStreamId: Cardinal;
      AData: PByte; ADataLen: Integer;
      AEndStream: Boolean;
      var AOutput: TBytes; var APos: Integer); static;
  end;

  /// <summary>
  ///   Default SETTINGS values for the Dext HTTP/2 server as per RFC 9113 §6.5.2.
  /// </summary>
  function DefaultServerSettings: THttp2Settings;

const
  FLAG_END_STREAM  = $01;
  FLAG_END_HEADERS = $04;
  FLAG_PADDED      = $08;
  FLAG_PRIORITY    = $20;
  FLAG_ACK         = $01;

implementation

// Frame flag constants (used internally)
function DefaultServerSettings: THttp2Settings;
begin
  SetLength(Result, 5);
  Result[0].Id := HTTP2_SETTINGS_HEADER_TABLE_SIZE;      Result[0].Value := 4096;
  Result[1].Id := HTTP2_SETTINGS_ENABLE_PUSH;            Result[1].Value := 0;
  Result[2].Id := HTTP2_SETTINGS_MAX_CONCURRENT_STREAMS; Result[2].Value := 100;
  Result[3].Id := HTTP2_SETTINGS_INITIAL_WINDOW_SIZE;    Result[3].Value := 65535;
  Result[4].Id := HTTP2_SETTINGS_MAX_FRAME_SIZE;         Result[4].Value := HTTP2_DEFAULT_MAX_FRAME_SIZE;
end;

{ TDextHttp2FrameCodec - private helpers }

class function TDextHttp2FrameCodec.Read3(P: PByte): Cardinal;
begin
  Result := (Cardinal(P[0]) shl 16) or (Cardinal(P[1]) shl 8) or P[2];
end;

class function TDextHttp2FrameCodec.Read4(P: PByte): Cardinal;
begin
  Result := (Cardinal(P[0]) shl 24) or (Cardinal(P[1]) shl 16) or
            (Cardinal(P[2]) shl 8)  or P[3];
end;



class procedure TDextHttp2FrameCodec.GrowIfNeeded(var AOutput: TBytes; APos, ANeeded: Integer);
begin
  if APos + ANeeded > Length(AOutput) then
    SetLength(AOutput, APos + ANeeded + 256);
end;

class procedure TDextHttp2FrameCodec.AppendBytes(var AOutput: TBytes; var APos: Integer;
  AData: PByte; ALen: Integer);
begin
  GrowIfNeeded(AOutput, APos, ALen);
  if ALen > 0 then
    Move(AData^, AOutput[APos], ALen);
  Inc(APos, ALen);
end;

{ TDextHttp2FrameCodec - Reader }

class function TDextHttp2FrameCodec.TryReadFrame(ABuffer: PByte; AAvail: Integer;
  AMaxFrameSize: Cardinal;
  out AFrame: THttp2Frame; out ABytesConsumed: Integer): Boolean;
begin
  Result := False;
  ABytesConsumed := 0;

  // Need at least 9 bytes for the frame header
  if AAvail < HTTP2_FRAME_HEADER_SIZE then Exit;

  AFrame.PayloadLength := Read3(ABuffer);
  AFrame.FrameType     := ABuffer[3];
  AFrame.Flags         := ABuffer[4];
  // Stream ID: clear reserved bit 31
  AFrame.StreamId      := Read4(ABuffer + 5) and $7FFFFFFF;

  // Reject oversized payloads (FRAME_SIZE_ERROR per RFC 9113 §4.2)
  if AFrame.PayloadLength > AMaxFrameSize then
    raise EInvalidOperation.CreateFmt(
      'HTTP/2 FRAME_SIZE_ERROR: frame payload %d exceeds max %d',
      [AFrame.PayloadLength, AMaxFrameSize]);

  // Check we have the full payload in the buffer
  if AAvail < HTTP2_FRAME_HEADER_SIZE + Integer(AFrame.PayloadLength) then Exit;

  AFrame.PayloadPtr := ABuffer + HTTP2_FRAME_HEADER_SIZE;
  ABytesConsumed    := HTTP2_FRAME_HEADER_SIZE + Integer(AFrame.PayloadLength);
  Result := True;
end;

{ TDextHttp2FrameCodec - Flag helpers }

class function TDextHttp2FrameCodec.HasEndStream(const AFrame: THttp2Frame): Boolean;
begin
  Result := (AFrame.Flags and FLAG_END_STREAM) <> 0;
end;

class function TDextHttp2FrameCodec.HasEndHeaders(const AFrame: THttp2Frame): Boolean;
begin
  Result := (AFrame.Flags and FLAG_END_HEADERS) <> 0;
end;

class function TDextHttp2FrameCodec.HasAck(const AFrame: THttp2Frame): Boolean;
begin
  Result := (AFrame.Flags and FLAG_ACK) <> 0;
end;

class function TDextHttp2FrameCodec.HasPadded(const AFrame: THttp2Frame): Boolean;
begin
  Result := (AFrame.Flags and FLAG_PADDED) <> 0;
end;

{ TDextHttp2FrameCodec - Payload accessors }

class function TDextHttp2FrameCodec.GetHeaderBlockFragment(const AFrame: THttp2Frame;
  out AData: PByte; out ALen: Integer): Boolean;
var
  payload: PByte;
  remaining: Integer;
  padLen: Byte;
begin
  Result := False;
  AData := nil;
  ALen := 0;
  payload := AFrame.PayloadPtr;
  remaining := Integer(AFrame.PayloadLength);

  padLen := 0;
  if HasPadded(AFrame) then
  begin
    if remaining < 1 then Exit;
    padLen := payload[0];
    Inc(payload);
    Dec(remaining);
  end;

  if (AFrame.Flags and FLAG_PRIORITY) <> 0 then
  begin
    // 4 bytes exclusive+stream dep + 1 byte weight
    if remaining < 5 then Exit;
    Inc(payload, 5);
    Dec(remaining, 5);
  end;

  if remaining < Integer(padLen) then Exit;
  AData := payload;
  ALen := remaining - Integer(padLen);
  Result := True;
end;

class function TDextHttp2FrameCodec.GetDataPayload(const AFrame: THttp2Frame;
  out AData: PByte; out ALen: Integer): Boolean;
var
  payload: PByte;
  remaining: Integer;
  padLen: Byte;
begin
  Result := False;
  AData := nil;
  ALen := 0;
  payload := AFrame.PayloadPtr;
  remaining := Integer(AFrame.PayloadLength);

  padLen := 0;
  if HasPadded(AFrame) then
  begin
    if remaining < 1 then Exit;
    padLen := payload[0];
    Inc(payload);
    Dec(remaining);
  end;

  if remaining < Integer(padLen) then Exit;
  AData := payload;
  ALen := remaining - Integer(padLen);
  Result := True;
end;

class function TDextHttp2FrameCodec.GetRstStreamError(const AFrame: THttp2Frame;
  out AErrorCode: Cardinal): Boolean;
begin
  Result := AFrame.PayloadLength >= 4;
  if Result then
    AErrorCode := Read4(AFrame.PayloadPtr);
end;

class function TDextHttp2FrameCodec.GetGoaway(const AFrame: THttp2Frame;
  out ALastStreamId, AErrorCode: Cardinal;
  out ADebugData: TBytes): Boolean;
var
  debugLen: Integer;
begin
  Result := False;
  if AFrame.PayloadLength < 8 then Exit;
  ALastStreamId := Read4(AFrame.PayloadPtr) and $7FFFFFFF;
  AErrorCode    := Read4(AFrame.PayloadPtr + 4);
  debugLen      := Integer(AFrame.PayloadLength) - 8;
  SetLength(ADebugData, debugLen);
  if debugLen > 0 then
    Move((AFrame.PayloadPtr + 8)^, ADebugData[0], debugLen);
  Result := True;
end;

class function TDextHttp2FrameCodec.GetWindowUpdateIncrement(const AFrame: THttp2Frame;
  out AIncrement: Cardinal): Boolean;
begin
  Result := AFrame.PayloadLength >= 4;
  if Result then
    AIncrement := Read4(AFrame.PayloadPtr) and $7FFFFFFF;
end;

class function TDextHttp2FrameCodec.GetSettings(const AFrame: THttp2Frame;
  out ASettings: THttp2Settings): Boolean;
var
  count: Integer;
  i: Integer;
  ptr: PByte;
begin
  Result := False;
  if (AFrame.PayloadLength mod 6) <> 0 then Exit;
  count := Integer(AFrame.PayloadLength) div 6;
  SetLength(ASettings, count);
  ptr := AFrame.PayloadPtr;
  for i := 0 to count - 1 do
  begin
    ASettings[i].Id    := (Word(ptr[0]) shl 8) or ptr[1];
    ASettings[i].Value := Read4(ptr + 2);
    Inc(ptr, 6);
  end;
  Result := True;
end;

{ TDextHttp2FrameCodec - Writers }

// Writes the 9-byte frame header directly into AOutput at APos
procedure WriteHeader(var AOutput: TBytes; var APos: Integer;
  APayloadLen: Cardinal; AFrameType: Byte; AFlags: Byte; AStreamId: Cardinal);
var
  p: PByte;
begin
  TDextHttp2FrameCodec.GrowIfNeeded(AOutput, APos, HTTP2_FRAME_HEADER_SIZE);
  p := @AOutput[APos];
  p[0] := Byte(APayloadLen shr 16);
  p[1] := Byte(APayloadLen shr 8);
  p[2] := Byte(APayloadLen);
  p[3] := AFrameType;
  p[4] := AFlags;
  p[5] := Byte((AStreamId shr 24) and $7F); // clear reserved bit
  p[6] := Byte(AStreamId shr 16);
  p[7] := Byte(AStreamId shr 8);
  p[8] := Byte(AStreamId);
  Inc(APos, HTTP2_FRAME_HEADER_SIZE);
end;

class procedure TDextHttp2FrameCodec.WriteSettingsFrame(const ASettings: THttp2Settings;
  AAck: Boolean; var AOutput: TBytes; var APos: Integer);
var
  payloadLen: Cardinal;
  flags: Byte;
  i: Integer;
  p: PByte;
begin
  if AAck then
  begin
    payloadLen := 0;
    flags := FLAG_ACK;
  end
  else
  begin
    payloadLen := Cardinal(Length(ASettings)) * 6;
    flags := 0;
  end;

  WriteHeader(AOutput, APos, payloadLen, Byte(THttp2FrameType.ftSettings), flags, 0);
  if not AAck then
  begin
    GrowIfNeeded(AOutput, APos, Integer(payloadLen));
    if payloadLen > 0 then
    begin
      p := @AOutput[APos];
      for i := 0 to High(ASettings) do
      begin
        p[0] := Byte(ASettings[i].Id shr 8);
        p[1] := Byte(ASettings[i].Id);
        p[2] := Byte(ASettings[i].Value shr 24);
        p[3] := Byte(ASettings[i].Value shr 16);
        p[4] := Byte(ASettings[i].Value shr 8);
        p[5] := Byte(ASettings[i].Value);
        Inc(p, 6);
      end;
    end;
    Inc(APos, Integer(payloadLen));
  end;
end;

class procedure TDextHttp2FrameCodec.WriteSettingsAck(var AOutput: TBytes; var APos: Integer);
begin
  WriteHeader(AOutput, APos, 0, Byte(THttp2FrameType.ftSettings), FLAG_ACK, 0);
end;

class procedure TDextHttp2FrameCodec.WritePingAck(APayload: PByte;
  var AOutput: TBytes; var APos: Integer);
begin
  WriteHeader(AOutput, APos, 8, Byte(THttp2FrameType.ftPing), FLAG_ACK, 0);
  GrowIfNeeded(AOutput, APos, 8);
  if APayload <> nil then
    Move(APayload^, AOutput[APos], 8)
  else
    FillChar(AOutput[APos], 8, 0);
  Inc(APos, 8);
end;

class procedure TDextHttp2FrameCodec.WriteGoaway(ALastStreamId, AErrorCode: Cardinal;
  const ADebugMessage: string; var AOutput: TBytes; var APos: Integer);
var
  debugBytes: TBytes;
  payloadLen: Cardinal;
  p: PByte;
begin
  debugBytes := TEncoding.UTF8.GetBytes(ADebugMessage);
  payloadLen := 8 + Cardinal(Length(debugBytes));
  WriteHeader(AOutput, APos, payloadLen, Byte(THttp2FrameType.ftGoaway), 0, 0);
  GrowIfNeeded(AOutput, APos, Integer(payloadLen));
  p := @AOutput[APos];
  p[0] := Byte((ALastStreamId shr 24) and $7F);
  p[1] := Byte(ALastStreamId shr 16);
  p[2] := Byte(ALastStreamId shr 8);
  p[3] := Byte(ALastStreamId);
  p[4] := Byte(AErrorCode shr 24);
  p[5] := Byte(AErrorCode shr 16);
  p[6] := Byte(AErrorCode shr 8);
  p[7] := Byte(AErrorCode);
  Inc(APos, 8);
  if Length(debugBytes) > 0 then
  begin
    Move(debugBytes[0], AOutput[APos], Length(debugBytes));
    Inc(APos, Length(debugBytes));
  end;
end;

class procedure TDextHttp2FrameCodec.WriteWindowUpdate(AStreamId: Cardinal;
  AIncrement: Cardinal; var AOutput: TBytes; var APos: Integer);
var
  p: PByte;
begin
  WriteHeader(AOutput, APos, 4, Byte(THttp2FrameType.ftWindowUpdate), 0, AStreamId);
  GrowIfNeeded(AOutput, APos, 4);
  p := @AOutput[APos];
  p[0] := Byte((AIncrement shr 24) and $7F); // clear reserved bit
  p[1] := Byte(AIncrement shr 16);
  p[2] := Byte(AIncrement shr 8);
  p[3] := Byte(AIncrement);
  Inc(APos, 4);
end;

class procedure TDextHttp2FrameCodec.WriteRstStream(AStreamId: Cardinal;
  AErrorCode: Cardinal; var AOutput: TBytes; var APos: Integer);
var
  p: PByte;
begin
  WriteHeader(AOutput, APos, 4, Byte(THttp2FrameType.ftRstStream), 0, AStreamId);
  GrowIfNeeded(AOutput, APos, 4);
  p := @AOutput[APos];
  p[0] := Byte(AErrorCode shr 24);
  p[1] := Byte(AErrorCode shr 16);
  p[2] := Byte(AErrorCode shr 8);
  p[3] := Byte(AErrorCode);
  Inc(APos, 4);
end;

class procedure TDextHttp2FrameCodec.WriteHeadersFrame(AStreamId: Cardinal;
  AHeaderBlock: PByte; AHeaderBlockLen: Integer;
  AEndStream, AEndHeaders: Boolean;
  var AOutput: TBytes; var APos: Integer);
var
  flags: Byte;
begin
  flags := 0;
  if AEndStream  then flags := flags or FLAG_END_STREAM;
  if AEndHeaders then flags := flags or FLAG_END_HEADERS;
  WriteHeader(AOutput, APos, AHeaderBlockLen, Byte(THttp2FrameType.ftHeaders), flags, AStreamId);
  AppendBytes(AOutput, APos, AHeaderBlock, AHeaderBlockLen);
end;

class procedure TDextHttp2FrameCodec.WriteContinuationFrame(AStreamId: Cardinal;
  AHeaderBlock: PByte; AHeaderBlockLen: Integer;
  AEndHeaders: Boolean;
  var AOutput: TBytes; var APos: Integer);
var
  flags: Byte;
begin
  flags := 0;
  if AEndHeaders then flags := FLAG_END_HEADERS;
  WriteHeader(AOutput, APos, AHeaderBlockLen, Byte(THttp2FrameType.ftContinuation), flags, AStreamId);
  AppendBytes(AOutput, APos, AHeaderBlock, AHeaderBlockLen);
end;

class procedure TDextHttp2FrameCodec.WriteDataFrame(AStreamId: Cardinal;
  AData: PByte; ADataLen: Integer;
  AEndStream: Boolean;
  var AOutput: TBytes; var APos: Integer);
var
  flags: Byte;
begin
  flags := 0;
  if AEndStream then flags := FLAG_END_STREAM;
  WriteHeader(AOutput, APos, ADataLen, Byte(THttp2FrameType.ftData), flags, AStreamId);
  AppendBytes(AOutput, APos, AData, ADataLen);
end;

end.
