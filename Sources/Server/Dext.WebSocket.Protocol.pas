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
unit Dext.WebSocket.Protocol;

{$I Dext.inc}

interface

uses
  System.SysUtils;

type
  TWebSocketOpcode = (
    wsContinuation = $0,
    wsText         = $1,
    wsBinary       = $2,
    wsClose        = $8,
    wsPing         = $9,
    wsPong         = $A
  );

  TWebSocketCloseCode = (
    wsCloseNormal              = 1000,
    wsCloseGoingAway           = 1001,
    wsCloseProtocolError       = 1002,
    wsCloseUnsupportedData     = 1003,
    wsCloseNoStatus            = 1005,
    wsCloseAbnormal            = 1006,
    wsCloseInvalidPayload      = 1007,
    wsClosePolicyViolation     = 1008,
    wsCloseMessageTooBig       = 1009,
    wsCloseMandatoryExtension  = 1010,
    wsCloseInternalServerError = 1011
  );

  TWebSocketFrame = record
    FIN: Boolean;
    RSV1: Boolean;
    Opcode: TWebSocketOpcode;
    Masked: Boolean;
    MaskKey: array[0..3] of Byte;
    PayloadLength: UInt64;
    Payload: TBytes;
  end;

  TWebSocketDecodeResult = (
    wsDecodeIncomplete,
    wsDecodeComplete,
    wsDecodeProtocolError,
    wsDecodeMessageTooBig
  );

  TWebSocketFrameCodec = class
  private
    class procedure WriteWordBE(var P: PByte; Val: Word); static; inline;
    class procedure WriteUInt64BE(var P: PByte; Val: UInt64); static; inline;
    class function ReadWordBE(const P: PByte): Word; static; inline;
    class function ReadUInt64BE(const P: PByte): UInt64; static; inline;
  public
    /// <summary>Encodes a frame to bytes (server -> client: no masking).</summary>
    class function Encode(const AFrame: TWebSocketFrame): TBytes; static;
    class function EncodeText(const AData: string; AFIN: Boolean = True): TBytes; static;
    class function EncodeBinary(const AData: TBytes; AFIN: Boolean = True): TBytes; static;
    class function EncodeClose(ACode: Word = 1000; const AReason: string = ''): TBytes; static;
    class function EncodePing(const AData: TBytes = nil): TBytes; static;
    class function EncodePong(const AData: TBytes = nil): TBytes; static;

    /// <summary>Decodes a frame from a byte buffer (incremental).</summary>
    class function TryDecode(const ABuffer: TBytes; AOffset: Integer;
      ALength: Integer; out AFrame: TWebSocketFrame;
      out ABytesConsumed: Integer): Boolean; static;
    class function Decode(const ABuffer: TBytes; AOffset, ALength: Integer;
      out AFrame: TWebSocketFrame; out ABytesConsumed: Integer;
      ARequireMask: Boolean; AMaxPayloadLength: UInt64;
      AAllowRSV1: Boolean = False): TWebSocketDecodeResult; static;

    /// <summary>Unmasks payload in-place.</summary>
    class procedure Unmask(var APayload: TBytes; const AMaskKey: array of Byte); static;
  end;

implementation

function Utf8ByteLenAsciiFast(const AValue: string; out AAscii: Boolean): Integer;
var
  i: Integer;
  C: Cardinal;
begin
  Result := 0;
  AAscii := True;
  i := 1;
  while i <= Length(AValue) do
  begin
    C := Ord(AValue[i]);
    if C < $80 then
      Inc(Result)
    else
    begin
      AAscii := False;
      if (C >= $D800) and (C <= $DBFF) and (i < Length(AValue)) then
      begin
        Inc(Result, 4);
        Inc(i);
      end
      else if C < $800 then
        Inc(Result, 2)
      else
        Inc(Result, 3);
    end;
    Inc(i);
  end;
end;

procedure WriteWebSocketHeader(var ADest: TBytes; AOpcode: TWebSocketOpcode; APayloadLen: UInt64);
var
  P: PByte;
  HeaderLen: Integer;
begin
  HeaderLen := 2;
  if APayloadLen > 65535 then
    HeaderLen := 10
  else if APayloadLen > 125 then
    HeaderLen := 4;

  SetLength(ADest, HeaderLen + Integer(APayloadLen));
  P := @ADest[0];
  P[0] := $80 or (Byte(AOpcode) and $0F);
  if APayloadLen > 65535 then
  begin
    P[1] := 127;
    Inc(P, 2);
    TWebSocketFrameCodec.WriteUInt64BE(P, APayloadLen);
  end
  else if APayloadLen > 125 then
  begin
    P[1] := 126;
    Inc(P, 2);
    TWebSocketFrameCodec.WriteWordBE(P, Word(APayloadLen));
  end
  else
    P[1] := Byte(APayloadLen);
end;

procedure WriteUtf8PayloadAsciiFast(const AValue: string; var ADest: TBytes; AOffset: Integer; AAscii: Boolean);
var
  i: Integer;
  Bytes: TBytes;
begin
  if AValue = '' then
    Exit;

  if AAscii then
  begin
    for i := 1 to Length(AValue) do
      ADest[AOffset + i - 1] := Byte(Ord(AValue[i]));
  end
  else
  begin
    Bytes := TEncoding.UTF8.GetBytes(AValue);
    if Length(Bytes) > 0 then
      Move(Bytes[0], ADest[AOffset], Length(Bytes));
  end;
end;

{ TWebSocketFrameCodec }

class function TWebSocketFrameCodec.ReadWordBE(const P: PByte): Word;
begin
  Result := (P[0] shl 8) or P[1];
end;

class function TWebSocketFrameCodec.ReadUInt64BE(const P: PByte): UInt64;
begin
  Result := (UInt64(P[0]) shl 56) or
            (UInt64(P[1]) shl 48) or
            (UInt64(P[2]) shl 40) or
            (UInt64(P[3]) shl 32) or
            (UInt64(P[4]) shl 24) or
            (UInt64(P[5]) shl 16) or
            (UInt64(P[6]) shl 8) or
            P[7];
end;

class procedure TWebSocketFrameCodec.WriteWordBE(var P: PByte; Val: Word);
begin
  P[0] := Byte(Val shr 8);
  P[1] := Byte(Val);
  Inc(P, 2);
end;

class procedure TWebSocketFrameCodec.WriteUInt64BE(var P: PByte; Val: UInt64);
begin
  P[0] := Byte(Val shr 56);
  P[1] := Byte(Val shr 48);
  P[2] := Byte(Val shr 40);
  P[3] := Byte(Val shr 32);
  P[4] := Byte(Val shr 24);
  P[5] := Byte(Val shr 16);
  P[6] := Byte(Val shr 8);
  P[7] := Byte(Val);
  Inc(P, 8);
end;

class function TWebSocketFrameCodec.Encode(const AFrame: TWebSocketFrame): TBytes;
var
  HeaderLen: Integer;
  TotalLen: Integer;
  P: PByte;
  B0, B1: Byte;
  I: Integer;
begin
  if AFrame.PayloadLength <> UInt64(Length(AFrame.Payload)) then
    raise EArgumentException.Create(
      'WebSocket payload length does not match payload buffer');
  if (Byte(AFrame.Opcode) >= $8) and
     ((not AFrame.FIN) or (AFrame.PayloadLength > 125)) then
    raise EArgumentException.Create(
      'WebSocket control frames must be final and at most 125 bytes');

  // Calculate header length
  HeaderLen := 2;
  if AFrame.PayloadLength > 65535 then
    HeaderLen := 10
  else if AFrame.PayloadLength > 125 then
    HeaderLen := 4;

  if AFrame.Masked then
    HeaderLen := HeaderLen + 4;

  TotalLen := HeaderLen + Length(AFrame.Payload);
  SetLength(Result, TotalLen);
  P := @Result[0];

  // Byte 0: FIN and Opcode
  B0 := Byte(AFrame.Opcode) and $0F;
  if AFrame.FIN then
    B0 := B0 or $80;
  if AFrame.RSV1 then
    B0 := B0 or $40;
  P[0] := B0;

  // Byte 1: Mask and initial Payload len
  B1 := 0;
  if AFrame.Masked then
    B1 := $80;

  if AFrame.PayloadLength > 65535 then
  begin
    P[1] := B1 or 127;
    Inc(P, 2);
    WriteUInt64BE(P, AFrame.PayloadLength);
  end
  else if AFrame.PayloadLength > 125 then
  begin
    P[1] := B1 or 126;
    Inc(P, 2);
    WriteWordBE(P, AFrame.PayloadLength);
  end
  else
  begin
    P[1] := B1 or Byte(AFrame.PayloadLength);
    Inc(P, 2);
  end;

  // Mask Key
  if AFrame.Masked then
  begin
    P[0] := AFrame.MaskKey[0];
    P[1] := AFrame.MaskKey[1];
    P[2] := AFrame.MaskKey[2];
    P[3] := AFrame.MaskKey[3];
    Inc(P, 4);
  end;

  // Payload Data
  if Length(AFrame.Payload) > 0 then
  begin
    Move(AFrame.Payload[0], P^, Length(AFrame.Payload));
    if AFrame.Masked then
    begin
      for I := 0 to Length(AFrame.Payload) - 1 do
        P[I] := P[I] xor AFrame.MaskKey[I mod 4];
    end;
  end;
end;

class function TWebSocketFrameCodec.EncodeText(const AData: string; AFIN: Boolean): TBytes;
var
  PayloadLen: Integer;
  HeaderLen: Integer;
  Ascii: Boolean;
  Frame: TWebSocketFrame;
begin
  if not AFIN then
  begin
    Frame := Default(TWebSocketFrame);
    Frame.FIN := AFIN;
    Frame.Opcode := wsText;
    Frame.Masked := False;
    Frame.Payload := TEncoding.UTF8.GetBytes(AData);
    Frame.PayloadLength := Length(Frame.Payload);
    Exit(Encode(Frame));
  end;

  PayloadLen := Utf8ByteLenAsciiFast(AData, Ascii);
  WriteWebSocketHeader(Result, wsText, PayloadLen);
  HeaderLen := Length(Result) - PayloadLen;
  WriteUtf8PayloadAsciiFast(AData, Result, HeaderLen, Ascii);
end;

class function TWebSocketFrameCodec.EncodeBinary(const AData: TBytes; AFIN: Boolean): TBytes;
var
  Frame: TWebSocketFrame;
begin
  Frame := Default(TWebSocketFrame);
  Frame.FIN := AFIN;
  Frame.Opcode := wsBinary;
  Frame.Masked := False;
  Frame.Payload := AData;
  Frame.PayloadLength := Length(AData);
  Result := Encode(Frame);
end;

class function TWebSocketFrameCodec.EncodeClose(ACode: Word; const AReason: string): TBytes;
var
  ReasonLen: Integer;
  HeaderLen: Integer;
  Ascii: Boolean;
begin
  ReasonLen := Utf8ByteLenAsciiFast(AReason, Ascii);
  WriteWebSocketHeader(Result, wsClose, 2 + ReasonLen);
  HeaderLen := Length(Result) - 2 - ReasonLen;
  Result[HeaderLen] := Byte(ACode shr 8);
  Result[HeaderLen + 1] := Byte(ACode);
  WriteUtf8PayloadAsciiFast(AReason, Result, HeaderLen + 2, Ascii);
end;

class function TWebSocketFrameCodec.EncodePing(const AData: TBytes): TBytes;
var
  Frame: TWebSocketFrame;
begin
  Frame := Default(TWebSocketFrame);
  Frame.FIN := True;
  Frame.Opcode := wsPing;
  Frame.Masked := False;
  Frame.Payload := AData;
  Frame.PayloadLength := Length(AData);
  Result := Encode(Frame);
end;

class function TWebSocketFrameCodec.EncodePong(const AData: TBytes): TBytes;
var
  Frame: TWebSocketFrame;
begin
  Frame := Default(TWebSocketFrame);
  Frame.FIN := True;
  Frame.Opcode := wsPong;
  Frame.Masked := False;
  Frame.Payload := AData;
  Frame.PayloadLength := Length(AData);
  Result := Encode(Frame);
end;

class function TWebSocketFrameCodec.TryDecode(const ABuffer: TBytes; AOffset, ALength: Integer; out AFrame: TWebSocketFrame; out ABytesConsumed: Integer): Boolean;
begin
  Result := Decode(ABuffer, AOffset, ALength, AFrame, ABytesConsumed,
    False, High(Integer), False) = wsDecodeComplete;
end;

class function TWebSocketFrameCodec.Decode(const ABuffer: TBytes;
  AOffset, ALength: Integer; out AFrame: TWebSocketFrame;
  out ABytesConsumed: Integer; ARequireMask: Boolean;
  AMaxPayloadLength: UInt64; AAllowRSV1: Boolean): TWebSocketDecodeResult;
var
  B0, B1: Byte;
  FIN: Boolean;
  RSV1: Boolean;
  Opcode: Byte;
  Masked: Boolean;
  LenCode: Byte;
  HeaderLen: Integer;
  PayloadLen: UInt64;
begin
  AFrame := Default(TWebSocketFrame);
  ABytesConsumed := 0;
  Result := wsDecodeIncomplete;
  if (AOffset < 0) or (ALength < 0) or
     (AOffset > Length(ABuffer)) or
     (ALength > Length(ABuffer) - AOffset) then
    Exit(wsDecodeProtocolError);
  if ALength < 2 then
    Exit;

  B0 := ABuffer[AOffset];
  B1 := ABuffer[AOffset + 1];

  FIN := (B0 and $80) <> 0;
  RSV1 := (B0 and $40) <> 0;
  Opcode := B0 and $0F;
  Masked := (B1 and $80) <> 0;
  LenCode := B1 and $7F;

  if ((B0 and $30) <> 0) or (RSV1 and not AAllowRSV1) then
    Exit(wsDecodeProtocolError);
  if not (Opcode in [$0, $1, $2, $8, $9, $A]) then
    Exit(wsDecodeProtocolError);
  if RSV1 and not (Opcode in [$1, $2]) then
    Exit(wsDecodeProtocolError);
  if ARequireMask and not Masked then
    Exit(wsDecodeProtocolError);
  if (Opcode >= $8) and (not FIN or (LenCode > 125)) then
    Exit(wsDecodeProtocolError);

  HeaderLen := 2;
  PayloadLen := LenCode;

  if LenCode = 126 then
  begin
    if ALength < 4 then
      Exit;
    PayloadLen := ReadWordBE(@ABuffer[AOffset + 2]);
    if PayloadLen < 126 then
      Exit(wsDecodeProtocolError);
    HeaderLen := 4;
  end
  else if LenCode = 127 then
  begin
    if ALength < 10 then
      Exit;
    PayloadLen := ReadUInt64BE(@ABuffer[AOffset + 2]);
    if (PayloadLen < 65536) or ((PayloadLen and (UInt64(1) shl 63)) <> 0) then
      Exit(wsDecodeProtocolError);
    HeaderLen := 10;
  end;

  if Masked then
  begin
    if ALength < HeaderLen + 4 then
      Exit;
    Move(ABuffer[AOffset + HeaderLen], AFrame.MaskKey[0], 4);
    HeaderLen := HeaderLen + 4;
  end;

  if PayloadLen > AMaxPayloadLength then
    Exit(wsDecodeMessageTooBig);
  if PayloadLen > UInt64(High(Integer) - HeaderLen) then
    Exit(wsDecodeMessageTooBig);
  if UInt64(ALength) < UInt64(HeaderLen) + PayloadLen then
    Exit;

  AFrame.FIN := FIN;
  AFrame.RSV1 := RSV1;
  AFrame.Opcode := TWebSocketOpcode(Opcode);
  AFrame.Masked := Masked;
  AFrame.PayloadLength := PayloadLen;

  SetLength(AFrame.Payload, PayloadLen);
  if PayloadLen > 0 then
  begin
    Move(ABuffer[AOffset + HeaderLen], AFrame.Payload[0], PayloadLen);
    if Masked then
      Unmask(AFrame.Payload, AFrame.MaskKey);
  end;

  ABytesConsumed := HeaderLen + Integer(PayloadLen);
  Result := wsDecodeComplete;
end;

class procedure TWebSocketFrameCodec.Unmask(var APayload: TBytes; const AMaskKey: array of Byte);
var
  I: Integer;
begin
  I := 0;
  while I + 4 <= Length(APayload) do
  begin
    APayload[I] := APayload[I] xor AMaskKey[0];
    APayload[I + 1] := APayload[I + 1] xor AMaskKey[1];
    APayload[I + 2] := APayload[I + 2] xor AMaskKey[2];
    APayload[I + 3] := APayload[I + 3] xor AMaskKey[3];
    Inc(I, 4);
  end;
  while I < Length(APayload) do
  begin
    APayload[I] := APayload[I] xor AMaskKey[I and 3];
    Inc(I);
  end;
end;

end.
