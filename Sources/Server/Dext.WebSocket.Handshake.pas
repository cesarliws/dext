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
unit Dext.WebSocket.Handshake;

{$I Dext.inc}

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.Hash,
  System.NetEncoding,
  Dext.Server.Engine.Interfaces;

type
  TWebSocketHandshake = class
  public
    /// <summary>Validates if an incoming HTTP request is a WebSocket upgrade request.</summary>
    class function IsUpgradeRequest(const ARequest: IDextRawRequest): Boolean; static;

    /// <summary>Computes the Sec-WebSocket-Accept header value (RFC 6455 §4.2.2).</summary>
    class function ComputeAcceptKey(const ASecWebSocketKey: string): string; static;

    /// <summary>Builds the 101 Switching Protocols response message.</summary>
    class function BuildUpgradeResponse(const ASecWebSocketKey: string;
      const AProtocol: string = ''): string; static;
    class function TryNegotiatePermessageDeflate(const AExtensions: string;
      out AResponse: string): Boolean; static;
  end;

implementation

function ContainsTokenAsciiNoCase(const AValue, AToken: string): Boolean;
var
  i: Integer;
  j: Integer;
  C1: Char;
  C2: Char;
  Match: Boolean;
begin
  if (AValue = '') or (AToken = '') or (Length(AToken) > Length(AValue)) then
    Exit(False);

  for i := 1 to Length(AValue) - Length(AToken) + 1 do
  begin
    Match := True;
    for j := 1 to Length(AToken) do
    begin
      C1 := AValue[i + j - 1];
      C2 := AToken[j];
      if (C1 >= 'A') and (C1 <= 'Z') then
        C1 := Chr(Ord(C1) + 32);
      if (C2 >= 'A') and (C2 <= 'Z') then
        C2 := Chr(Ord(C2) + 32);
      if C1 <> C2 then
      begin
        Match := False;
        Break;
      end;
    end;
    if Match then
      Exit(True);
  end;

  Result := False;
end;

{ TWebSocketHandshake }

class function TWebSocketHandshake.IsUpgradeRequest(const ARequest: IDextRawRequest): Boolean;
var
  UpgradeHeader: string;
  ConnectionHeader: string;
  Method: string;
begin
  Result := False;
  if ARequest = nil then Exit;

  Method := ARequest.Method;
  if not SameText(Method, 'GET') then Exit;

  UpgradeHeader := ARequest.GetHeader('Upgrade');
  if not SameText(UpgradeHeader, 'websocket') then Exit;

  ConnectionHeader := ARequest.GetHeader('Connection');
  if not ContainsTokenAsciiNoCase(ConnectionHeader, 'upgrade') then Exit;

  if ARequest.GetHeader('Sec-WebSocket-Key') = '' then Exit;

  Result := True;
end;

class function TWebSocketHandshake.ComputeAcceptKey(const ASecWebSocketKey: string): string;
const
  WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
var
  KeyStart: Integer;
  KeyEnd: Integer;
  KeyLen: Integer;
  GuidLen: Integer;
  Bytes: TBytes;
  HashBytes: TBytes;
  SHA1: THashSHA1;
  i: Integer;
begin
  KeyStart := 1;
  KeyEnd := Length(ASecWebSocketKey);
  while (KeyStart <= KeyEnd) and (ASecWebSocketKey[KeyStart] <= ' ') do
    Inc(KeyStart);
  while (KeyEnd >= KeyStart) and (ASecWebSocketKey[KeyEnd] <= ' ') do
    Dec(KeyEnd);

  KeyLen := KeyEnd - KeyStart + 1;
  if KeyLen < 0 then
    KeyLen := 0;
  GuidLen := Length(WS_GUID);
  SetLength(Bytes, KeyLen + GuidLen);

  for i := 0 to KeyLen - 1 do
    Bytes[i] := Byte(Ord(ASecWebSocketKey[KeyStart + i]));
  for i := 1 to GuidLen do
    Bytes[KeyLen + i - 1] := Byte(Ord(WS_GUID[i]));

  SHA1 := THashSHA1.Create;
  if Length(Bytes) > 0 then
    SHA1.Update(Bytes);
  HashBytes := SHA1.HashAsBytes;
  Result := TNetEncoding.Base64.EncodeBytesToString(HashBytes).Trim;
  // Strip any newlines just in case
  Result := Result.Replace(#13, '').Replace(#10, '');
end;

class function TWebSocketHandshake.BuildUpgradeResponse(const ASecWebSocketKey: string; const AProtocol: string): string;
var
  AcceptKey: string;
begin
  AcceptKey := ComputeAcceptKey(ASecWebSocketKey);
  Result := 'HTTP/1.1 101 Switching Protocols' + #13#10 +
            'Upgrade: websocket' + #13#10 +
            'Connection: Upgrade' + #13#10 +
            'Sec-WebSocket-Accept: ' + AcceptKey + #13#10;
  if AProtocol <> '' then
    Result := Result + 'Sec-WebSocket-Protocol: ' + AProtocol + #13#10;
  Result := Result + #13#10;
end;

class function TWebSocketHandshake.TryNegotiatePermessageDeflate(
  const AExtensions: string; out AResponse: string): Boolean;
var
  Offers, Parts: TArray<string>;
  Offer, Part, Name, Value: string;
  Seen: TDictionary<string, Boolean>;
  Separator: Integer;
  Valid: Boolean;
  WindowBits: Integer;
begin
  Result := False;
  AResponse := '';
  Offers := AExtensions.Split([',']);
  for Offer in Offers do
  begin
    Parts := Offer.Split([';']);
    if (Length(Parts) = 0) or
       not SameText(Trim(Parts[0]), 'permessage-deflate') then
      Continue;
    Seen := TDictionary<string, Boolean>.Create;
    try
      Valid := True;
      for var I := 1 to High(Parts) do
      begin
        Part := Trim(Parts[I]);
        Separator := Pos('=', Part);
        if Separator > 0 then
        begin
          Name := LowerCase(Trim(Copy(Part, 1, Separator - 1)));
          Value := Trim(Copy(Part, Separator + 1, MaxInt)).Trim(['"']);
        end
        else
        begin
          Name := LowerCase(Part);
          Value := '';
        end;
        if (Name = '') or Seen.ContainsKey(Name) then
        begin
          Valid := False;
          Break;
        end;
        Seen.Add(Name, True);
        if (Name = 'client_no_context_takeover') or
           (Name = 'server_no_context_takeover') then
          Valid := Value = ''
        else if Name = 'client_max_window_bits' then
          Valid := (Value = '') or
            (TryStrToInt(Value, WindowBits) and
             (WindowBits >= 8) and (WindowBits <= 15))
        else if Name = 'server_max_window_bits' then
          Valid := TryStrToInt(Value, WindowBits) and
            (WindowBits >= 8) and (WindowBits <= 15)
        else
          Valid := False;
        if not Valid then Break;
      end;
      if Valid then
      begin
        AResponse :=
          'permessage-deflate; server_no_context_takeover; client_no_context_takeover';
        Exit(True);
      end;
    finally
      Seen.Free;
    end;
  end;
end;

end.
