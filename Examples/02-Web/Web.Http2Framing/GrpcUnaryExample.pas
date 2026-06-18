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
unit GrpcUnaryExample;

interface

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  Dext.Http2.Hpack,
  Dext.Http2.Framing,
  Dext.Http2.Connection;

type
  /// <summary>
  ///   Demonstrates how to parse and construct gRPC messages over HTTP/2 framing.
  ///   gRPC mandates HTTP/2 transport where requests and responses are framed as:
  ///     - Headers: HTTP/2 HEADERS frame (content-type = application/grpc)
  ///     - Body: HTTP/2 DATA frame(s) containing a 5-byte Length-Prefixed Message header
  ///       (1 byte compressed flag, 4 bytes big-endian length) followed by Protobuf payload.
  ///     - Trailers: HTTP/2 HEADERS frame containing status (grpc-status, grpc-message).
  /// </summary>
  TGrpcUnaryHelper = class
  public
    /// <summary>
    ///   Parses a gRPC request body (Length-Prefixed Message format).
    ///   Returns the raw serialized protobuf payload.
    /// </summary>
    class function UnpackMessage(const ABody: TBytes; out ACompressed: Boolean): TBytes; static;

    /// <summary>
    ///   Packs a serialized protobuf payload into a gRPC Length-Prefixed Message.
    /// </summary>
    class function PackMessage(const APayload: TBytes; ACompressed: Boolean = False): TBytes; static;

    /// <summary>
    ///   Processes a gRPC unary call: unpacks, invokes a simple mockup handler,
    ///   and writes the response using the connection.
    /// </summary>
    class procedure HandleGrpcCall(AConn: TDextHttp2Connection; AStreamId: Cardinal;
      const AHeaders: TNameValuePairs; const ABody: TBytes); static;
  end;

implementation

{ TGrpcUnaryHelper }

class function TGrpcUnaryHelper.UnpackMessage(const ABody: TBytes; out ACompressed: Boolean): TBytes;
var
  len: Integer;
  msgLen: Cardinal;
begin
  ACompressed := False;
  len := Length(ABody);
  if len < 5 then
    raise EInvalidOperation.Create('gRPC Error: Invalid frame size (must be at least 5 bytes)');

  // Byte 0: Compressed-Flag (0 = uncompressed, 1 = compressed)
  ACompressed := ABody[0] <> 0;

  // Bytes 1..4: Message length in Big-Endian
  msgLen := (Cardinal(ABody[1]) shl 24) or
            (Cardinal(ABody[2]) shl 16) or
            (Cardinal(ABody[3]) shl 8)  or
             Cardinal(ABody[4]);

  if len < 5 + Integer(msgLen) then
    raise EInvalidOperation.CreateFmt(
      'gRPC Error: Incomplete message body. Expected %d bytes, got %d',
      [5 + msgLen, len]);

  SetLength(Result, msgLen);
  if msgLen > 0 then
    Move(ABody[5], Result[0], msgLen);
end;

class function TGrpcUnaryHelper.PackMessage(const APayload: TBytes; ACompressed: Boolean): TBytes;
var
  msgLen: Cardinal;
begin
  msgLen := Length(APayload);
  SetLength(Result, 5 + msgLen);

  // Compressed-Flag
  if ACompressed then
    Result[0] := 1
  else
    Result[0] := 0;

  // Message length (Big-Endian)
  Result[1] := Byte(msgLen shr 24);
  Result[2] := Byte(msgLen shr 16);
  Result[3] := Byte(msgLen shr 8);
  Result[4] := Byte(msgLen);

  if msgLen > 0 then
    Move(APayload[0], Result[5], msgLen);
end;

class procedure TGrpcUnaryHelper.HandleGrpcCall(AConn: TDextHttp2Connection; AStreamId: Cardinal;
  const AHeaders: TNameValuePairs; const ABody: TBytes);
var
  i: Integer;
  contentType: string;
  isGrpc: Boolean;
  compressed: Boolean;
  reqPayload: TBytes;
  reqStr: string;
  resStr: string;
  resPayload: TBytes;
  resData: TBytes;
  resHeaders: TNameValuePairs;
  resTrailers: TNameValuePairs;
begin
  // 1. Verify content-type is application/grpc
  isGrpc := False;
  for i := 0 to High(AHeaders) do
  begin
    if SameText(AHeaders[i].Name, 'content-type') then
    begin
      contentType := AHeaders[i].Value;
      if StartsText('application/grpc', contentType) then
        isGrpc := True;
      Break;
    end;
  end;

  if not isGrpc then
  begin
    // Fallback/Reject non-gRPC request with HTTP 415 Unsupported Media Type
    SetLength(resHeaders, 2);
    resHeaders[0].Name := ':status';      resHeaders[0].Value := '415';
    resHeaders[1].Name := 'content-type'; resHeaders[1].Value := 'text/plain';
    resData := TEncoding.UTF8.GetBytes('Unsupported Media Type: Expected application/grpc');
    AConn.SendResponse(AStreamId, resHeaders, resData, True);
    Exit;
  end;

  try
    // 2. Unpack gRPC Length-Prefixed Message
    reqPayload := UnpackMessage(ABody, compressed);
    
    // In our placeholder example, we assume the protobuf payload is a plain UTF-8 string
    if Length(reqPayload) > 0 then
      reqStr := TEncoding.UTF8.GetString(reqPayload)
    else
      reqStr := 'World';

    WriteLn(Format('    [gRPC Unary] Request payload parsed: "%s"', [reqStr]));

    // 3. Process Request (Mock Handler)
    resStr := 'Hello, ' + reqStr + '! (Mock gRPC Response)';
    resPayload := TEncoding.UTF8.GetBytes(resStr);

    // Pack response into gRPC format
    resData := PackMessage(resPayload, False);

    // 4. Send Response Headers (Status 200)
    SetLength(resHeaders, 2);
    resHeaders[0].Name := ':status';      resHeaders[0].Value := '200';
    resHeaders[1].Name := 'content-type'; resHeaders[1].Value := 'application/grpc';

    // Send headers + message body (EndStream = False, trailers will follow)
    AConn.SendResponse(AStreamId, resHeaders, resData, False);

    // 5. Send gRPC Trailers (containing grpc-status = 0 [OK])
    SetLength(resTrailers, 2);
    resTrailers[0].Name := 'grpc-status';  resTrailers[0].Value := '0';
    resTrailers[1].Name := 'grpc-message'; resTrailers[1].Value := 'OK';

    // In HTTP/2, trailers are sent as a HEADERS frame with END_STREAM=True and no body
    AConn.SendResponse(AStreamId, resTrailers, nil, True);

    WriteLn('    [gRPC Unary] Response headers, body, and trailers sent successfully.');
  except
    on E: Exception do
    begin
      // Send error trailers with appropriate status
      SetLength(resHeaders, 2);
      resHeaders[0].Name := ':status';      resHeaders[0].Value := '200';
      resHeaders[1].Name := 'content-type'; resHeaders[1].Value := 'application/grpc';
      
      SetLength(resTrailers, 2);
      resTrailers[0].Name := 'grpc-status';  resTrailers[0].Value := '13'; // INTERNAL
      resTrailers[1].Name := 'grpc-message'; resTrailers[1].Value := E.Message;
      
      AConn.SendResponse(AStreamId, resHeaders, nil, False);
      AConn.SendResponse(AStreamId, resTrailers, nil, True);
      
      WriteLn(Format('    [gRPC Unary] Error encountered: %s', [E.Message]));
    end;
  end;
end;

end.
