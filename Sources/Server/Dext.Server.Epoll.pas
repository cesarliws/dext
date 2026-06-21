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
{  Created: 2026-06-17                                                      }
{                                                                           }
{  High-performance Linux epoll socket engine implementation.               }
{                                                                           }
{***************************************************************************}
unit Dext.Server.Epoll;

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  Dext.Server.Engine.Types,
  Dext.Server.Engine.Interfaces,
  Dext.Server.Iocp.HttpParser,
  Dext.Collections.Dict;

type
  {$IFDEF LINUX}
  TDextEpollEngine = class;

  /// <summary>
  ///   Raw connection implementation wrapper for epoll sockets.
  /// </summary>
  TDextEpollConnection = class(TInterfacedObject, IDextServerConnection)
  private
    FSocket: Integer;
    FConnectionId: UInt64;
  public
    /// <summary>Initializes a new epoll connection wrapper.</summary>
    /// <param name="ASocket">The raw socket descriptor.</param>
    constructor Create(ASocket: Integer);
    /// <summary>Cleans up the connection resources.</summary>
    destructor Destroy; override;
    
    /// <summary>Returns the unique connection identifier.</summary>
    function GetConnectionId: UInt64;
    /// <summary>Returns the remote client's IP address.</summary>
    function GetRemoteAddress: string;
    /// <summary>Returns the remote client's port.</summary>
    function GetRemotePort: Word;
    /// <summary>Returns the local listening port.</summary>
    function GetLocalPort: Word;
    /// <summary>Indicates if the connection is encrypted (SSL/TLS).</summary>
    function IsSecure: Boolean;
    /// <summary>Closes the connection.</summary>
    procedure Close;

    /// <summary>Checks if connection upgrade is supported.</summary>
    function SupportsUpgrade: Boolean;
    /// <summary>Upgrades the active connection to WebSockets.</summary>
    function UpgradeToWebSocket: IDextWebSocketConnection;
  end;

  /// <summary>
  ///   Raw request implementation wrapper for epoll socket connection.
  /// <summary>
  ///   Raw request implementation wrapper for epoll socket connection.
  /// </summary>
  TDextEpollRequest = class(TInterfacedObject, IDextRawRequest)
  private
    FMethod: string;
    FPath: string;
    FQuery: string;
    FHeaders: TDictionary<string, string>;
    FBodyStream: TMemoryStream;
    FContentLength: Int64;
    function GetMethod: string;
    function GetPath: string;
    function GetQueryString: string;
    function GetHeader(const AName: string): string;
    procedure PopulateHeaders(ADict: TDictionary<string, string>);
    function GetContentLength: Int64;
    function GetBodyStream: TStream;
  public
    /// <summary>Initializes the raw epoll request wrapper.</summary>
    /// <param name="AMethod">The HTTP method.</param>
    /// <param name="APath">The request path.</param>
    /// <param name="AQuery">The raw query string.</param>
    /// <param name="AHeaders">The headers dictionary.</param>
    /// <param name="ABody">The raw body buffer.</param>
    /// <param name="ABodyOffset">Offset in the buffer where the body starts.</param>
    /// <param name="ABodyLen">Length of the body data in the buffer.</param>
    /// <param name="AContentLength">The content length header value.</param>
    constructor Create(
      const AMethod, APath, AQuery: string;
      AHeaders: TDictionary<string, string>;
      ABody: TBytes;
      ABodyOffset, ABodyLen: Integer;
      AContentLength: Int64
    );
    /// <summary>Cleans up the request resources.</summary>
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Raw response implementation wrapper for epoll socket connection.
  /// </summary>
  TDextEpollResponse = class(TInterfacedObject, IDextRawResponse)
  private
    FSocket: Integer;
    FHeadersSent: Boolean;
    FStatusCode: Integer;
    FReason: string;
    FHeaders: TDictionary<string, string>;
  public
    /// <summary>Initializes a new epoll response wrapper.</summary>
    /// <param name="ASocket">The raw socket descriptor.</param>
    constructor Create(ASocket: Integer);
    /// <summary>Cleans up the response resources.</summary>
    destructor Destroy; override;

    /// <summary>Sets the HTTP status code and optional reason phrase.</summary>
    /// <param name="ACode">The HTTP status code (e.g., 200, 404).</param>
    /// <param name="AReason">Optional HTTP reason phrase.</param>
    procedure SetStatus(ACode: Integer; const AReason: string = '');
    /// <summary>Sets the value of a specific HTTP response header.</summary>
    /// <param name="AName">The name of the header.</param>
    /// <param name="AValue">The value of the header.</param>
    procedure SetHeader(const AName, AValue: string);
    /// <summary>Forces sending of response headers to the client.</summary>
    procedure SendHeaders;
    /// <summary>Writes raw bytes into the response body stream.</summary>
    /// <param name="ABuffer">The byte array buffer containing data to write.</param>
    /// <param name="AOffset">The zero-based byte offset in ABuffer from which to begin writing.</param>
    /// <param name="ACount">The number of bytes to write.</param>
    procedure Write(const ABuffer: TBytes; AOffset, ACount: Integer);
    /// <summary>Flushes any buffered response data to the network.</summary>
    procedure Flush;
    /// <summary>Closes the response stream and connection.</summary>
    procedure Close;
  end;

  /// <summary>
  ///   Worker thread running epoll_wait event loop.
  /// </summary>
  TDextEpollWorker = class(TThread)
  private
    FEngine: TDextEpollEngine;
    FEpollFd: Integer;
  protected
    procedure Execute; override;
  public
    /// <summary>Initializes the epoll worker thread.</summary>
    /// <param name="AEngine">The epoll engine instance.</param>
    /// <param name="AEpollFd">The epoll file descriptor.</param>
    constructor Create(AEngine: TDextEpollEngine; AEpollFd: Integer);
  end;

  /// <summary>
  ///   Native Linux raw epoll socket server engine.
  /// </summary>
  TDextEpollEngine = class(TInterfacedObject, IDextServerEngine)
  private
    FOptions: TServerEngineOptions;
    FListenSocket: Integer;
    FEpollFd: Integer;
    FPipeFds: array[0..1] of Integer;
    FRunning: Boolean;
    FListeningPort: Word;
    FAddress: string;

    FOnConnection: TConnectionEventHandler;
    FOnDisconnection: TConnectionEventHandler;
    FOnRequest: TRequestEventHandler;
    FOnUpgrade: TUpgradeEventHandler;

    FActiveConnections: Integer;
    FTotalRequests: Int64;

    FWorkers: TList;
  public
    /// <summary>Initializes a new epoll server engine.</summary>
    /// <param name="AOptions">The engine configuration options.</param>
    constructor Create(const AOptions: TServerEngineOptions);
    /// <summary>Destroys the engine and releases resources.</summary>
    destructor Destroy; override;

    /// <summary>Binds the engine to the specified address and port.</summary>
    /// <param name="AAddress">IP address to bind to.</param>
    /// <param name="APort">Port to listen on.</param>
    procedure Bind(const AAddress: string; APort: Word);
    /// <summary>Starts the epoll socket listener and worker threads.</summary>
    procedure Start;
    /// <summary>Stops the engine and socket listener.</summary>
    /// <param name="AGracefulTimeoutMs">Timeout in milliseconds for graceful shutdown.</param>
    procedure Stop(AGracefulTimeoutMs: Integer = 5000);
    
    /// <summary>Returns the port the engine is currently listening on.</summary>
    function GetListenPort: Word;
    /// <summary>Returns the count of active client connections.</summary>
    function GetActiveConnections: Integer;
    /// <summary>Returns the total number of processed requests.</summary>
    function GetTotalRequests: Int64;

    /// <summary>Sets the connection event handler.</summary>
    procedure SetOnConnection(const AHandler: TConnectionEventHandler);
    /// <summary>Sets the disconnection event handler.</summary>
    procedure SetOnDisconnection(const AHandler: TConnectionEventHandler);
    /// <summary>Sets the request event handler.</summary>
    procedure SetOnRequest(const AHandler: TRequestEventHandler);
    /// <summary>Sets the socket upgrade event handler.</summary>
    procedure SetOnUpgrade(const AHandler: TUpgradeEventHandler);
  end;

  {$ELSE}

  /// <summary>
  ///   Compilation stub of TDextEpollEngine for non-Linux platforms.
  /// </summary>
  TDextEpollEngine = class(TInterfacedObject, IDextServerEngine)
  public
    /// <summary>Stub constructor.</summary>
    constructor Create(const AOptions: TServerEngineOptions);
    /// <summary>Stub Bind implementation.</summary>
    procedure Bind(const AAddress: string; APort: Word);
    /// <summary>Stub Start implementation.</summary>
    procedure Start;
    /// <summary>Stub Stop implementation.</summary>
    procedure Stop(AGracefulTimeoutMs: Integer = 5000);
    /// <summary>Stub GetListenPort implementation.</summary>
    function GetListenPort: Word;
    /// <summary>Stub GetActiveConnections implementation.</summary>
    function GetActiveConnections: Integer;
    /// <summary>Stub GetTotalRequests implementation.</summary>
    function GetTotalRequests: Int64;
    /// <summary>Stub SetOnConnection implementation.</summary>
    procedure SetOnConnection(const AHandler: TConnectionEventHandler);
    /// <summary>Stub SetOnDisconnection implementation.</summary>
    procedure SetOnDisconnection(const AHandler: TConnectionEventHandler);
    /// <summary>Stub SetOnRequest implementation.</summary>
    procedure SetOnRequest(const AHandler: TRequestEventHandler);
    /// <summary>Stub SetOnUpgrade implementation.</summary>
    procedure SetOnUpgrade(const AHandler: TUpgradeEventHandler);
  end;
  {$ENDIF}

implementation

{$IFDEF LINUX}
uses
  Posix.Base,
  Posix.SysTypes,
  Posix.SysSocket,
  Posix.Unistd,
  Posix.Fcntl,
  Posix.ArpaInet,
  Posix.NetinetIn,
  Posix.Errno;

const
  EPOLLIN      = $00000001;
  EPOLLOUT     = $00000004;
  EPOLLERR     = $00000008;
  EPOLLHUP     = $00000010;
  EPOLLRDHUP   = $00002000;
  EPOLLET      = $80000000;
  EPOLLONESHOT = $40000000;

  EPOLL_CTL_ADD = 1;
  EPOLL_CTL_DEL = 2;
  EPOLL_CTL_MOD = 3;

type
  epoll_data = record
    case Integer of
      0: (ptr: Pointer);
      1: (fd: Integer);
      2: (u32: Cardinal);
      3: (u64: UInt64);
  end;

  epoll_event = packed record
    events: Cardinal;
    data: epoll_data;
  end;
  pepoll_event = ^epoll_event;

function epoll_create(size: Integer): Integer; cdecl; external libc name 'epoll_create';
function epoll_create1(flags: Integer): Integer; cdecl; external libc name 'epoll_create1';
function epoll_ctl(epfd: Integer; op: Integer; fd: Integer; event: pepoll_event): Integer; cdecl; external libc name 'epoll_ctl';
function epoll_wait(epfd: Integer; events: pepoll_event; maxevents: Integer; timeout: Integer): Integer; cdecl; external libc name 'epoll_wait';


{ TDextEpollConnection }

constructor TDextEpollConnection.Create(ASocket: Integer);
begin
  inherited Create;
  FSocket := ASocket;
  FConnectionId := UInt64(ASocket);
end;

destructor TDextEpollConnection.Destroy;
begin
  Close;
  inherited;
end;

procedure TDextEpollConnection.Close;
begin
  if FSocket >= 0 then
  begin
    __close(FSocket);
    FSocket := -1;
  end;
end;

function TDextEpollConnection.GetConnectionId: UInt64;
begin
  Result := FConnectionId;
end;

function TDextEpollConnection.GetLocalPort: Word;
var
  Addr: sockaddr_in;
  AddrLen: socklen_t;
begin
  AddrLen := SizeOf(Addr);
  if getsockname(FSocket, Psockaddr(@Addr)^, AddrLen) = 0 then
    Result := ntohs(Addr.sin_port)
  else
    Result := 0;
end;

function TDextEpollConnection.GetRemoteAddress: string;
var
  Addr: sockaddr_in;
  AddrLen: socklen_t;
begin
  AddrLen := SizeOf(Addr);
  if getpeername(FSocket, Psockaddr(@Addr)^, AddrLen) = 0 then
    Result := string(AnsiString(inet_ntoa(Addr.sin_addr)))
  else
    Result := '';
end;

function TDextEpollConnection.GetRemotePort: Word;
var
  Addr: sockaddr_in;
  AddrLen: socklen_t;
begin
  AddrLen := SizeOf(Addr);
  if getpeername(FSocket, Psockaddr(@Addr)^, AddrLen) = 0 then
    Result := ntohs(Addr.sin_port)
  else
    Result := 0;
end;

function TDextEpollConnection.IsSecure: Boolean;
begin
  Result := False;
end;

function TDextEpollConnection.SupportsUpgrade: Boolean;
begin
  Result := True;
end;

function TDextEpollConnection.UpgradeToWebSocket: IDextWebSocketConnection;
begin
  Result := nil;
end;

{ TDextEpollRequest }

constructor TDextEpollRequest.Create(
  const AMethod, APath, AQuery: string;
  AHeaders: TDictionary<string, string>;
  ABody: TBytes;
  ABodyOffset, ABodyLen: Integer;
  AContentLength: Int64
);
begin
  inherited Create;
  FMethod := AMethod;
  FPath := APath;
  FQuery := AQuery;
  FHeaders := AHeaders;
  FContentLength := AContentLength;
  FBodyStream := TMemoryStream.Create;
  if ABodyLen > 0 then
    FBodyStream.WriteBuffer(ABody[ABodyOffset], ABodyLen);
  FBodyStream.Position := 0;
end;

destructor TDextEpollRequest.Destroy;
begin
  FHeaders.Free;
  FBodyStream.Free;
  inherited;
end;

function TDextEpollRequest.GetBodyStream: TStream;
begin
  Result := FBodyStream;
end;

function TDextEpollRequest.GetContentLength: Int64;
begin
  Result := FContentLength;
end;

function TDextEpollRequest.GetHeader(const AName: string): string;
begin
  if not FHeaders.TryGetValue(AName, Result) then
    Result := '';
end;

procedure TDextEpollRequest.PopulateHeaders(ADict: TDictionary<string, string>);
var
  Pair: TPair<string, string>;
begin
  for Pair in FHeaders do
    ADict.AddOrSetValue(Pair.Key, Pair.Value);
end;

// Interface redirects
function TDextEpollRequest.GetMethod: string; begin Result := FMethod; end;
function TDextEpollRequest.GetPath: string; begin Result := FPath; end;
function TDextEpollRequest.GetQueryString: string; begin Result := FQuery; end;

{ TDextEpollResponse }

constructor TDextEpollResponse.Create(ASocket: Integer);
begin
  inherited Create;
  FSocket := ASocket;
  FHeadersSent := False;
  FStatusCode := 200;
  FReason := 'OK';
  FHeaders := TDictionary<string, string>.Create;
end;

destructor TDextEpollResponse.Destroy;
begin
  FHeaders.Free;
  inherited;
end;

procedure TDextEpollResponse.Close;
begin
  Flush;
end;

procedure TDextEpollResponse.Flush;
begin
  if not FHeadersSent then
    SendHeaders;
end;

procedure TDextEpollResponse.SendHeaders;
var
  HeaderStr: string;
  HeaderBytes: TBytes;
  Pair: TPair<string, string>;
begin
  if FHeadersSent then Exit;

  HeaderStr := Format('HTTP/1.1 %d %s'#13#10, [FStatusCode, FReason]);
  
  if not FHeaders.ContainsKey('Content-Type') then
    FHeaders.Add('Content-Type', 'text/plain');

  for Pair in FHeaders do
    HeaderStr := HeaderStr + Format('%s: %s'#13#10, [Pair.Key, Pair.Value]);

  HeaderStr := HeaderStr + #13#10;
  HeaderBytes := TEncoding.UTF8.GetBytes(HeaderStr);

  send(FSocket, HeaderBytes[0], Length(HeaderBytes), 0);
  FHeadersSent := True;
end;

procedure TDextEpollResponse.SetHeader(const AName, AValue: string);
begin
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');
  FHeaders.AddOrSetValue(AName, AValue);
end;

procedure TDextEpollResponse.SetStatus(ACode: Integer; const AReason: string);
begin
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');
  FStatusCode := ACode;
  if AReason <> '' then
    FReason := AReason
  else
    FReason := 'OK';
end;

procedure TDextEpollResponse.Write(const ABuffer: TBytes; AOffset, ACount: Integer);
begin
  if not FHeadersSent then
    SendHeaders;

  if ACount <= 0 then Exit;

  send(FSocket, ABuffer[AOffset], ACount, 0);
end;

{ TDextEpollWorker }

constructor TDextEpollWorker.Create(AEngine: TDextEpollEngine; AEpollFd: Integer);
begin
  inherited Create(True);
  FEngine := AEngine;
  FEpollFd := AEpollFd;
  FreeOnTerminate := False;
end;

procedure TDextEpollWorker.Execute;
var
  EventCount: Integer;
  I: Integer;
  Events: array[0..63] of epoll_event;
  Event: epoll_event;
  Fd: Integer;
  ClientFd: Integer;
  Addr: sockaddr_in;
  AddrLen: socklen_t;
begin
  while not Terminated and FEngine.FRunning do
  begin
    EventCount := epoll_wait(FEpollFd, @Events[0], Length(Events), 1000);
    if EventCount < 0 then
    begin
      if errno = EINTR then Continue;
      Break;
    end;

    for I := 0 to EventCount - 1 do
    begin
      Event := Events[I];
      Fd := Event.data.fd;

      if Fd = FEngine.FListenSocket then
      begin
        // Accept loop
        while True do
        begin
          AddrLen := SizeOf(Addr);
          ClientFd := accept(FEngine.FListenSocket, Psockaddr(@Addr)^, AddrLen);
          if ClientFd < 0 then
          begin
            if (errno = EAGAIN) or (errno = EWOULDBLOCK) then
              Break;
            Break;
          end;

          // Non-blocking
          fcntl(ClientFd, F_SETFL, O_NONBLOCK);

          // Edge Triggered + One Shot
          Event.events := EPOLLIN or EPOLLET or EPOLLONESHOT;
          Event.data.fd := ClientFd;
          epoll_ctl(FEpollFd, EPOLL_CTL_ADD, ClientFd, @Event);

          TInterlocked.Increment(FEngine.FActiveConnections);
        end;
      end
      else if Fd = FEngine.FPipeFds[0] then
      begin
        // Exit signal
        Exit;
      end;
    end;
  end;
end;

{ TDextEpollEngine }

constructor TDextEpollEngine.Create(const AOptions: TServerEngineOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FListenSocket := -1;
  FEpollFd := -1;
  FPipeFds[0] := -1;
  FPipeFds[1] := -1;
  FRunning := False;
  FWorkers := TList.Create;
end;

destructor TDextEpollEngine.Destroy;
begin
  Stop;
  FWorkers.Free;
  inherited;
end;

procedure TDextEpollEngine.Bind(const AAddress: string; APort: Word);
begin
  FAddress := AAddress;
  FListeningPort := APort;
end;

procedure TDextEpollEngine.Start;
var
  Addr: sockaddr_in;
  I: Integer;
  ThreadCount: Integer;
  Worker: TDextEpollWorker;
  Event: epoll_event;
  OptVal: Integer;
begin
  if FRunning then Exit;

  FEpollFd := epoll_create1(0);
  if FEpollFd < 0 then
    raise EOSError.Create('epoll_create1 failed');

  if pipe(@FPipeFds[0]) < 0 then
    raise EOSError.Create('pipe failed');

  // Set pipe to non-blocking
  fcntl(FPipeFds[0], F_SETFL, O_NONBLOCK);

  FListenSocket := socket(AF_INET, SOCK_STREAM, 0);
  if FListenSocket < 0 then
    raise EOSError.Create('socket creation failed');

  OptVal := 1;
  setsockopt(FListenSocket, SOL_SOCKET, SO_REUSEADDR, OptVal, SizeOf(OptVal));

  fcntl(FListenSocket, F_SETFL, O_NONBLOCK);

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(FListeningPort);
  if (FAddress = '') or (FAddress = '0.0.0.0') then
    Addr.sin_addr.s_addr := INADDR_ANY
  else
    Addr.sin_addr.s_addr := inet_addr(PAnsiChar(AnsiString(FAddress)));

  if Posix.SysSocket.bind(FListenSocket, Psockaddr(@Addr)^, SizeOf(Addr)) < 0 then
    raise EOSError.Create('bind failed');

  if listen(FListenSocket, SOMAXCONN) < 0 then
    raise EOSError.Create('listen failed');

  // Add listen socket to epoll
  Event.events := EPOLLIN or EPOLLET;
  Event.data.fd := FListenSocket;
  epoll_ctl(FEpollFd, EPOLL_CTL_ADD, FListenSocket, @Event);

  // Add pipe read end to epoll
  Event.events := EPOLLIN;
  Event.data.fd := FPipeFds[0];
  epoll_ctl(FEpollFd, EPOLL_CTL_ADD, FPipeFds[0], @Event);

  FRunning := True;

  ThreadCount := FOptions.IoThreadCount;
  if ThreadCount <= 0 then
    ThreadCount := CPUCount;

  for I := 1 to ThreadCount do
  begin
    Worker := TDextEpollWorker.Create(Self, FEpollFd);
    FWorkers.Add(Worker);
    Worker.Start;
  end;
end;

procedure TDextEpollEngine.Stop(AGracefulTimeoutMs: Integer);
var
  I: Integer;
  Worker: TDextEpollWorker;
  B: Byte;
begin
  if not FRunning then Exit;

  FRunning := False;

  if FPipeFds[1] >= 0 then
  begin
    B := 1;
    __write(FPipeFds[1], @B, 1);
  end;

  for I := 0 to FWorkers.Count - 1 do
  begin
    Worker := TDextEpollWorker(FWorkers[I]);
    Worker.Terminate;
  end;

  for I := 0 to FWorkers.Count - 1 do
  begin
    Worker := TDextEpollWorker(FWorkers[I]);
    Worker.WaitFor;
    Worker.Free;
  end;
  FWorkers.Clear;

  if FListenSocket >= 0 then
  begin
    __close(FListenSocket);
    FListenSocket := -1;
  end;

  if FPipeFds[0] >= 0 then
  begin
    __close(FPipeFds[0]);
    FPipeFds[0] := -1;
  end;

  if FPipeFds[1] >= 0 then
  begin
    __close(FPipeFds[1]);
    FPipeFds[1] := -1;
  end;

  if FEpollFd >= 0 then
  begin
    __close(FEpollFd);
    FEpollFd := -1;
  end;
end;

function TDextEpollEngine.GetActiveConnections: Integer;
begin
  Result := FActiveConnections;
end;

function TDextEpollEngine.GetListenPort: Word;
begin
  Result := FListeningPort;
end;

function TDextEpollEngine.GetTotalRequests: Int64;
begin
  Result := FTotalRequests;
end;

procedure TDextEpollEngine.SetOnConnection(const AHandler: TConnectionEventHandler);
begin
  FOnConnection := AHandler;
end;

procedure TDextEpollEngine.SetOnDisconnection(const AHandler: TConnectionEventHandler);
begin
  FOnDisconnection := AHandler;
end;

procedure TDextEpollEngine.SetOnRequest(const AHandler: TRequestEventHandler);
begin
  FOnRequest := AHandler;
end;

procedure TDextEpollEngine.SetOnUpgrade(const AHandler: TUpgradeEventHandler);
begin
  FOnUpgrade := AHandler;
end;

{$ELSE}

{ TDextEpollEngine - Stub }

constructor TDextEpollEngine.Create(const AOptions: TServerEngineOptions);
begin
  inherited Create;
end;

procedure TDextEpollEngine.Bind(const AAddress: string; APort: Word);
begin
end;

procedure TDextEpollEngine.Start;
begin
  raise ENotSupportedException.Create('Epoll engine is only supported on Linux.');
end;

procedure TDextEpollEngine.Stop(AGracefulTimeoutMs: Integer);
begin
end;

function TDextEpollEngine.GetActiveConnections: Integer;
begin
  Result := 0;
end;

function TDextEpollEngine.GetListenPort: Word;
begin
  Result := 0;
end;

function TDextEpollEngine.GetTotalRequests: Int64;
begin
  Result := 0;
end;

procedure TDextEpollEngine.SetOnConnection(const AHandler: TConnectionEventHandler);
begin
end;

procedure TDextEpollEngine.SetOnDisconnection(const AHandler: TConnectionEventHandler);
begin
end;

procedure TDextEpollEngine.SetOnRequest(const AHandler: TRequestEventHandler);
begin
end;

procedure TDextEpollEngine.SetOnUpgrade(const AHandler: TUpgradeEventHandler);
begin
end;
{$ENDIF}

end.
