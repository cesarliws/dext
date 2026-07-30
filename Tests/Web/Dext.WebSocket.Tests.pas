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
unit Dext.WebSocket.Tests;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  Dext.Testing.Attributes,
  Dext.Testing.Fluent,
  Dext.Testing,
  Dext.WebSocket.Protocol,
  Dext.WebSocket.Handshake,
  Dext.WebSocket.Compression;

type
  [TestFixture]
  TWebSocketTests = class
  public
    [Test]
    procedure TestHandshakeVector;
    [Test]
    procedure TestTextFrameRoundtrip;
    [Test]
    procedure TestBinaryFrameRoundtrip;
    [Test]
    procedure TestMaskingRoundtrip;
    [Test]
    procedure TestCloseFrame;
    [Test]
    procedure TestPingPongFrames;
    [Test]
    procedure TestRejectsUnmaskedClientFrame;
    [Test]
    procedure TestRejectsReservedBitsAndOpcodes;
    [Test]
    procedure TestRejectsInvalidControlFrame;
    [Test]
    procedure TestEnforcesPayloadLimit;
    [Test]
    procedure TestPermessageDeflateRoundtrip;
    [Test]
    procedure TestPermessageDeflateOutputLimit;
    [Test]
    procedure TestRSV1Rules;
    [Test]
    procedure TestPermessageDeflateNegotiation;
  end;

implementation

{ TWebSocketTests }

procedure TWebSocketTests.TestHandshakeVector;
var
  Key: string;
  Accept: string;
begin
  // RFC 6455 §4.2.2 standard test vector
  Key := 'dGhlIHNhbXBsZSBub25jZQ==';
  Accept := TWebSocketHandshake.ComputeAcceptKey(Key);
  Should(Accept).Be('s3pPLMBiTxaQ9kYGzzhZRbK+xOo=');
end;

procedure TWebSocketTests.TestTextFrameRoundtrip;
var
  Encoded: TBytes;
  Frame: TWebSocketFrame;
  Consumed: Integer;
  DecodedText: string;
begin
  Encoded := TWebSocketFrameCodec.EncodeText('Hello, WebSocket!');
  
  Should(TWebSocketFrameCodec.TryDecode(Encoded, 0, Length(Encoded), Frame, Consumed)).BeTrue;
  Should(Consumed).Be(Length(Encoded));
  Should(Frame.FIN).BeTrue;
  Should(Ord(Frame.Opcode)).Be(Ord(wsText));
  Should(Frame.Masked).BeFalse;
  
  DecodedText := TEncoding.UTF8.GetString(Frame.Payload);
  Should(DecodedText).Be('Hello, WebSocket!');
end;

procedure TWebSocketTests.TestBinaryFrameRoundtrip;
var
  Data: TBytes;
  Encoded: TBytes;
  Frame: TWebSocketFrame;
  Consumed: Integer;
  I: Integer;
begin
  SetLength(Data, 256);
  for I := 0 to 255 do
    Data[I] := Byte(I);
    
  Encoded := TWebSocketFrameCodec.EncodeBinary(Data);
  
  Should(TWebSocketFrameCodec.TryDecode(Encoded, 0, Length(Encoded), Frame, Consumed)).BeTrue;
  Should(Consumed).Be(Length(Encoded));
  Should(Frame.FIN).BeTrue;
  Should(Ord(Frame.Opcode)).Be(Ord(wsBinary));
  Should(Length(Frame.Payload)).Be(256);
  
  for I := 0 to 255 do
    Should(Frame.Payload[I]).Be(Byte(I));
end;

procedure TWebSocketTests.TestMaskingRoundtrip;
var
  Frame: TWebSocketFrame;
  Encoded: TBytes;
  Decoded: TWebSocketFrame;
  Consumed: Integer;
begin
  Frame.FIN := True;
  Frame.Opcode := wsText;
  Frame.Masked := True;
  Frame.MaskKey[0] := $DE;
  Frame.MaskKey[1] := $AD;
  Frame.MaskKey[2] := $BE;
  Frame.MaskKey[3] := $EF;
  Frame.Payload := TEncoding.UTF8.GetBytes('Masked Payload');
  Frame.PayloadLength := Length(Frame.Payload);
  
  // Before encoding, client payload is masked in transit.
  // Our codec unmasks automatically upon decoding if TryDecode is used.
  Encoded := TWebSocketFrameCodec.Encode(Frame);
  
  Should(TWebSocketFrameCodec.TryDecode(Encoded, 0, Length(Encoded), Decoded, Consumed)).BeTrue;
  Should(Consumed).Be(Length(Encoded));
  Should(Decoded.Masked).BeTrue;
  Should(Ord(Decoded.Opcode)).Be(Ord(wsText));
  Should(TEncoding.UTF8.GetString(Decoded.Payload)).Be('Masked Payload');
end;

procedure TWebSocketTests.TestCloseFrame;
var
  Encoded: TBytes;
  Frame: TWebSocketFrame;
  Consumed: Integer;
  CloseCode: Word;
  Reason: string;
begin
  Encoded := TWebSocketFrameCodec.EncodeClose(1001, 'Going Away');
  
  Should(TWebSocketFrameCodec.TryDecode(Encoded, 0, Length(Encoded), Frame, Consumed)).BeTrue;
  Should(Consumed).Be(Length(Encoded));
  Should(Ord(Frame.Opcode)).Be(Ord(wsClose));
  
  CloseCode := (Frame.Payload[0] shl 8) or Frame.Payload[1];
  Reason := TEncoding.UTF8.GetString(Frame.Payload, 2, Length(Frame.Payload) - 2);
  
  Should(CloseCode).Be(1001);
  Should(Reason).Be('Going Away');
end;

procedure TWebSocketTests.TestPingPongFrames;
var
  PingBytes: TBytes;
  PongBytes: TBytes;
  Frame: TWebSocketFrame;
  Consumed: Integer;
  Payload: TBytes;
begin
  Payload := TEncoding.UTF8.GetBytes('ping-data');
  PingBytes := TWebSocketFrameCodec.EncodePing(Payload);
  
  Should(TWebSocketFrameCodec.TryDecode(PingBytes, 0, Length(PingBytes), Frame, Consumed)).BeTrue;
  Should(Ord(Frame.Opcode)).Be(Ord(wsPing));
  Should(TEncoding.UTF8.GetString(Frame.Payload)).Be('ping-data');
  
  PongBytes := TWebSocketFrameCodec.EncodePong(Payload);
  Should(TWebSocketFrameCodec.TryDecode(PongBytes, 0, Length(PongBytes), Frame, Consumed)).BeTrue;
  Should(Ord(Frame.Opcode)).Be(Ord(wsPong));
  Should(TEncoding.UTF8.GetString(Frame.Payload)).Be('ping-data');
end;

procedure TWebSocketTests.TestRejectsUnmaskedClientFrame;
var
  Encoded: TBytes;
  Frame: TWebSocketFrame;
  Consumed: Integer;
begin
  Encoded := TWebSocketFrameCodec.EncodeText('client');
  Should(Ord(TWebSocketFrameCodec.Decode(
    Encoded, 0, Length(Encoded), Frame, Consumed, True, 1024))).Be(
    Ord(wsDecodeProtocolError));
end;

procedure TWebSocketTests.TestRejectsReservedBitsAndOpcodes;
var
  Encoded: TBytes;
  Frame: TWebSocketFrame;
  Consumed: Integer;
begin
  SetLength(Encoded, 2);
  Encoded[0] := $C1;
  Encoded[1] := $80;
  Should(Ord(TWebSocketFrameCodec.Decode(
    Encoded, 0, Length(Encoded), Frame, Consumed, True, 1024))).Be(
    Ord(wsDecodeProtocolError));

  Encoded[0] := $83;
  Should(Ord(TWebSocketFrameCodec.Decode(
    Encoded, 0, Length(Encoded), Frame, Consumed, True, 1024))).Be(
    Ord(wsDecodeProtocolError));
end;

procedure TWebSocketTests.TestRejectsInvalidControlFrame;
var
  Encoded: TBytes;
  Frame: TWebSocketFrame;
  Consumed: Integer;
begin
  SetLength(Encoded, 6);
  Encoded[0] := $09;
  Encoded[1] := $80;
  FillChar(Encoded[2], 4, 0);
  Should(Ord(TWebSocketFrameCodec.Decode(
    Encoded, 0, Length(Encoded), Frame, Consumed, True, 1024))).Be(
    Ord(wsDecodeProtocolError));
end;

procedure TWebSocketTests.TestEnforcesPayloadLimit;
var
  Encoded: TBytes;
  Frame: TWebSocketFrame;
  Consumed: Integer;
begin
  Encoded := TWebSocketFrameCodec.EncodeText(
    'payload larger than configured limit');
  Should(Ord(TWebSocketFrameCodec.Decode(
    Encoded, 0, Length(Encoded), Frame, Consumed, False, 4))).Be(
    Ord(wsDecodeMessageTooBig));
end;

procedure TWebSocketTests.TestPermessageDeflateRoundtrip;
var
  Context: TWebSocketDeflateContext;
  Input, Compressed, Output: TBytes;
begin
  Context := TWebSocketDeflateContext.Create(True);
  try
    Input := TEncoding.UTF8.GetBytes(
      'repeated repeated repeated repeated repeated');
    Compressed := Context.Compress(Input);
    Output := Context.Decompress(Compressed);
    Should(TEncoding.UTF8.GetString(Output)).Be(
      'repeated repeated repeated repeated repeated');
    Should(Length(Compressed) < Length(Input)).BeTrue;
  finally
    Context.Free;
  end;
end;

procedure TWebSocketTests.TestPermessageDeflateOutputLimit;
var
  Compressor, LimitedInflater: TWebSocketDeflateContext;
  Compressed: TBytes;
  Raised: Boolean;
begin
  Compressor := TWebSocketDeflateContext.Create(True);
  LimitedInflater := TWebSocketDeflateContext.Create(True, 8);
  try
    Compressed := Compressor.Compress(
      TEncoding.UTF8.GetBytes('more than eight decompressed bytes'));
    Raised := False;
    try
      LimitedInflater.Decompress(Compressed);
    except
      on E: EWebSocketCompressionError do
        Raised := True;
    end;
    Should(Raised).BeTrue;
  finally
    LimitedInflater.Free;
    Compressor.Free;
  end;
end;

procedure TWebSocketTests.TestRSV1Rules;
var
  Frame: TWebSocketFrame;
  Encoded: TBytes;
  Decoded: TWebSocketFrame;
  Consumed: Integer;
begin
  Frame := Default(TWebSocketFrame);
  Frame.FIN := True;
  Frame.RSV1 := True;
  Frame.Opcode := wsText;
  Frame.Payload := TEncoding.UTF8.GetBytes('compressed');
  Encoded := TWebSocketFrameCodec.Encode(Frame);
  Should(Ord(TWebSocketFrameCodec.Decode(
    Encoded, 0, Length(Encoded), Decoded, Consumed, False, 1024, True))).Be(
    Ord(wsDecodeComplete));

  Frame.Opcode := wsContinuation;
  Encoded := TWebSocketFrameCodec.Encode(Frame);
  Should(Ord(TWebSocketFrameCodec.Decode(
    Encoded, 0, Length(Encoded), Decoded, Consumed, False, 1024, True))).Be(
    Ord(wsDecodeProtocolError));
end;

procedure TWebSocketTests.TestPermessageDeflateNegotiation;
var
  Response: string;
begin
  Should(TWebSocketHandshake.TryNegotiatePermessageDeflate(
    'permessage-deflate; client_max_window_bits',
    Response)).BeTrue;
  Should(Response).Be(
    'permessage-deflate; server_no_context_takeover; client_no_context_takeover');
  Should(TWebSocketHandshake.TryNegotiatePermessageDeflate(
    'x-test, permessage-deflate; server_max_window_bits=15',
    Response)).BeTrue;
  Should(TWebSocketHandshake.TryNegotiatePermessageDeflate(
    'permessage-deflate; unknown=value', Response)).BeFalse;
  Should(TWebSocketHandshake.TryNegotiatePermessageDeflate(
    'permessage-deflate; client_max_window_bits=7', Response)).BeFalse;
  Should(TWebSocketHandshake.TryNegotiatePermessageDeflate(
    'permessage-deflate; client_no_context_takeover; client_no_context_takeover',
    Response)).BeFalse;
end;

end.
