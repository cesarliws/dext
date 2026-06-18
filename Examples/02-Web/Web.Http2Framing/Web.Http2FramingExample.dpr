{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
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
{  Demonstrates HTTP/2 framing using TDextHttp2Connection directly.         }
{                                                                           }
{  Architecture (S41):                                                      }
{    ┌─────────────────────────────────────────────────────────┐            }
{    │              TDextHttp2Connection (S41)                 │            }
{    │  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐   │            }
{    │  │THpackDecoder│  │FrameCodec    │  │StreamMap      │   │            }
{    │  │THpackEncoder│  │(TryReadFrame)│  │(binary search)│   │            }
{    │  └─────────────┘  └──────────────┘  └───────────────┘   │            }
{    └─────────────────────────────────────────────────────────┘            }
{         ▲ raw bytes                          ▼ parsed frames              }
{    Socket (Indy - included in Delphi, subject to future replacement)      }
{                                                                           }
{***************************************************************************}
program Web.Http2FramingExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Winapi.WinSock2,
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.StrUtils,
  Dext.Utils,
  Dext.Http2.Hpack,
  Dext.Http2.Framing,
  Dext.Http2.Stream,
  Dext.Http2.Connection,
  GrpcUnaryExample in 'GrpcUnaryExample.pas';

// ─────────────────────────────────────────────────────────────────────────────
// Simple single-connection HTTP/2 echo server built directly on top of
// TDextHttp2Connection (bypassing the Dext web host for clarity).
//
// Listens on TCP port 8443 (plain-text h2c, no TLS).
// Use curl with --http2-prior-knowledge to connect:
//   curl --http2-prior-knowledge http://localhost:8443/
//   curl --http2-prior-knowledge http://localhost:8443/echo -d "hello"
// ─────────────────────────────────────────────────────────────────────────────

const
  LISTEN_PORT = 8443;
  RECV_BUF_SIZE = 65536;

type
  /// <summary>Synchronous echo handler for one H2 connection.</summary>
  TH2EchoSession = class
  private
    FConn: TDextHttp2Connection;
    FSocket: TSocket;
    FSendBuf: TBytes;
    procedure HandleOutput(AData: PByte; ALen: Integer);
    procedure HandleRequest(AConn: TObject; AStreamId: Cardinal;
      const AHeaders: TNameValuePairs; const ABody: TBytes);
    function FindHeader(const AHeaders: TNameValuePairs;
      const AName: string): string;
  public
    constructor Create(ASocket: TSocket);
    destructor Destroy; override;
    procedure Run;
  end;

{ TH2EchoSession }

constructor TH2EchoSession.Create(ASocket: TSocket);
begin
  inherited Create;
  FSocket := ASocket;
  SetLength(FSendBuf, 0);
  FConn := TDextHttp2Connection.Create(THttp2ConnectionOptions.Default);
  FConn.OnOutput  := HandleOutput;
  FConn.OnRequest := HandleRequest;
end;

destructor TH2EchoSession.Destroy;
begin
  FConn.Free;
  closesocket(FSocket);
  inherited;
end;

// Write to socket (OnOutput callback)
procedure TH2EchoSession.HandleOutput(AData: PByte; ALen: Integer);
var
  sent: Integer;
begin
  if ALen = 0 then Exit;
  sent := send(FSocket, AData^, ALen, 0);
  if sent = SOCKET_ERROR then
    WriteLn('  [send error] ', WSAGetLastError);
end;

function TH2EchoSession.FindHeader(const AHeaders: TNameValuePairs;
  const AName: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(AHeaders) do
    if SameText(AHeaders[i].Name, AName) then
    begin
      Result := AHeaders[i].Value;
      Break;
    end;
end;

// HTTP/2 request handler
procedure TH2EchoSession.HandleRequest(AConn: TObject; AStreamId: Cardinal;
  const AHeaders: TNameValuePairs; const ABody: TBytes);
var
  method, path, status: string;
  body: string;
  responseHeaders: TNameValuePairs;
  responseBody: TBytes;
begin
  method := FindHeader(AHeaders, ':method');
  path   := FindHeader(AHeaders, ':path');

  WriteLn(Format('  [stream %d] %s %s  body=%d bytes',
    [AStreamId, method, path, Length(ABody)]));

  if StartsText('/grpc', path) then
  begin
    TGrpcUnaryHelper.HandleGrpcCall(FConn, AStreamId, AHeaders, ABody);
    Exit;
  end;

  // Routing
  if SameText(path, '/') then
  begin
    status := '200';
    body   := '{"message":"Welcome to Dext HTTP/2!","protocol":"h2"}';
  end
  else if SameText(path, '/echo') then
  begin
    status := '200';
    if Length(ABody) > 0 then
      body := TEncoding.UTF8.GetString(ABody)
    else
      body := '{"echo":"(empty body)"}';
  end
  else if SameText(path, '/health') then
  begin
    status := '200';
    body   := '{"status":"healthy","http2":true}';
  end
  else
  begin
    status := '404';
    body   := '{"error":"Not Found","path":"' + path + '"}';
  end;

  // Build response headers
  SetLength(responseHeaders, 2);
  responseHeaders[0].Name := ':status';      responseHeaders[0].Value := status;
  responseHeaders[1].Name := 'content-type'; responseHeaders[1].Value := 'application/json';

  responseBody := TEncoding.UTF8.GetBytes(body);
  FConn.SendResponse(AStreamId, responseHeaders, responseBody, True);
end;

procedure TH2EchoSession.Run;
var
  buf: TBytes;
  received: Integer;
begin
  SetLength(buf, RECV_BUF_SIZE);
  WriteLn('  [h2] connection open');
  while True do
  begin
    received := recv(FSocket, buf[0], RECV_BUF_SIZE, 0);
    if received <= 0 then Break;
    FConn.Feed(@buf[0], received);
    // If the connection sent GOAWAY, stop reading
    if FConn.State = THttp2ConnectionState.csClosed then Break;
  end;
  WriteLn('  [h2] connection closed');
end;

// ─────────────────────────────────────────────────────────────────────────────
// Main — listen for one connection at a time (demonstration only)
// ─────────────────────────────────────────────────────────────────────────────
var
  wsData: TWSAData;
  listenSock, clientSock: TSocket;
  addr: TSockAddrIn;
  addrLen: Integer;
  opt: Integer;
  session: TH2EchoSession;
begin
  SetConsoleCharSet(65001);
  WriteLn('╔══════════════════════════════════════════════╗');
  WriteLn('║   Dext HTTP/2 Framing Example (S41)          ║');
  WriteLn('╚══════════════════════════════════════════════╝');
  WriteLn;
  WriteLn(Format('Listening on h2c://localhost:%d (plain-text HTTP/2)', [LISTEN_PORT]));
  WriteLn;
  WriteLn('Test with:');
  WriteLn('  curl.exe --http2-prior-knowledge http://localhost:' + IntToStr(LISTEN_PORT) + '/');
  WriteLn('  curl.exe --http2-prior-knowledge http://localhost:' + IntToStr(LISTEN_PORT) + '/health');
  WriteLn('  curl.exe --http2-prior-knowledge -X POST http://localhost:' +
          IntToStr(LISTEN_PORT) + '/echo -d "{\"msg\":\"hello h2\"}"');
  WriteLn;

  // ── Winsock init ──────────────────────────────────────────────────────────
  if WSAStartup($0202, wsData) <> 0 then
  begin
    WriteLn('WSAStartup failed');
    Halt(1);
  end;

  try
    listenSock := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if listenSock = INVALID_SOCKET then
    begin
      WriteLn('socket() failed: ', WSAGetLastError);
      Halt(1);
    end;

    opt := 1;
    setsockopt(listenSock, SOL_SOCKET, SO_REUSEADDR, @opt, SizeOf(opt));

    FillChar(addr, SizeOf(addr), 0);
    addr.sin_family      := AF_INET;
    addr.sin_addr.S_addr := INADDR_ANY;
    addr.sin_port        := htons(LISTEN_PORT);

    if bind(listenSock, TSockAddr(addr), SizeOf(addr)) = SOCKET_ERROR then
    begin
      WriteLn('bind() failed: ', WSAGetLastError);
      closesocket(listenSock);
      Halt(1);
    end;

    if listen(listenSock, SOMAXCONN) = SOCKET_ERROR then
    begin
      WriteLn('listen() failed: ', WSAGetLastError);
      closesocket(listenSock);
      Halt(1);
    end;

    WriteLn('Waiting for connections... (Ctrl+C to stop)');
    WriteLn;

    // Accept loop (one connection at a time for simplicity)
    while True do
    begin
      addrLen    := SizeOf(addr);
      clientSock := accept(listenSock, @addr, @addrLen);
      if clientSock = INVALID_SOCKET then
      begin
        WriteLn('accept() failed: ', WSAGetLastError);
        Break;
      end;
      WriteLn(Format('[%s] New connection from %s',
        [FormatDateTime('hh:nn:ss', Now),
         string(inet_ntoa(addr.sin_addr))]));
      session := TH2EchoSession.Create(clientSock);
      try
        session.Run;
      finally
        session.Free;
      end;
    end;

    closesocket(listenSock);
  finally
    WSACleanup;
  end;

  ConsolePause;
end.
