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
{  High-performance Windows IOCP socket engine implementation.              }
{                                                                           }
{***************************************************************************}
unit Dext.Server.Iocp;

interface

{$IFDEF MSWINDOWS}
uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  Winapi.Windows,
  Winapi.WinSock2,
  Dext.Server.Engine.Types,
  Dext.Server.Engine.Interfaces,
  Dext.Server.Iocp.HttpParser,
  Dext.Collections.Dict;


type
  TDextIocpEngine = class;

  /// <summary>
  ///   Raw connection implementation wrapper for IOCP sockets.
  /// </summary>
  /// <summary>
  ///   Raw connection implementation wrapper for IOCP sockets.
  /// </summary>
  TDextIocpConnection = class(TInterfacedObject, IDextServerConnection)
  private
    FConnectionId: UInt64;
    FSocket: TSocket;
    FRemoteAddress: string;
    FRemotePort: Word;
    FLocalPort: Word;
  public
    /// <summary>Initializes a new IOCP connection wrapper.</summary>
    /// <param name="ASocket">The raw socket descriptor.</param>
    /// <param name="ARemoteAddress">The client IP address.</param>
    /// <param name="ARemotePort">The client port.</param>
    /// <param name="ALocalPort">The local server listening port.</param>
    constructor Create(ASocket: TSocket; const ARemoteAddress: string; ARemotePort, ALocalPort: Word);
    /// <summary>Cleans up connection resources.</summary>
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
  ///   Raw request implementation wrapper for IOCP socket connection.
  /// </summary>
  TDextIocpRequest = class(TInterfacedObject, IDextRawRequest)
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
    /// <summary>Initializes the raw IOCP request wrapper.</summary>
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
    /// <summary>Cleans up request resources.</summary>
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Raw response implementation wrapper for IOCP socket connection.
  /// </summary>
  TDextIocpResponse = class(TInterfacedObject, IDextRawResponse)
  private
    FSocket: TSocket;
    FHeadersSent: Boolean;
    FStatusCode: Integer;
    FReason: string;
    FHeaders: TDictionary<string, string>;
  public
    /// <summary>Initializes a new IOCP response wrapper.</summary>
    /// <param name="ASocket">The raw socket descriptor.</param>
    constructor Create(ASocket: TSocket);
    /// <summary>Cleans up response resources.</summary>
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
  ///   Winsock Extension functions types.
  /// </summary>
  TAcceptEx = function(sListenSocket, sAcceptSocket: TSocket; lpOutputBuffer: Pointer;
    dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD;
    var lpdwBytesReceived: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;

  TGetAcceptExSockaddrs = procedure(lpOutputBuffer: Pointer;
    dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD;
    var LocalSockaddr: PSockAddr; var LocalSockaddrLength: Integer;
    var RemoteSockaddr: PSockAddr; var RemoteSockaddrLength: Integer); stdcall;

  /// <summary>
  ///   IOCP overlapped operation key.
  /// </summary>
  TIocpOpType = (ioAccept, ioRead, ioWrite);

  PIocpOverlapped = ^TIocpOverlapped;
  TIocpOverlapped = record
    Overlapped: TOverlapped;
    OpType: TIocpOpType;
    Socket: TSocket;
    Buffer: array[0..16383] of Byte;
    BytesTransferred: DWORD;
  end;

  /// <summary>
  ///   Worker thread running GetQueuedCompletionStatus event loop.
  /// </summary>
  TDextIocpWorker = class(TThread)
  private
    FEngine: TDextIocpEngine;
    FIocp: THandle;
  protected
    procedure Execute; override;
  public
    /// <summary>Initializes a new IOCP worker thread.</summary>
    /// <param name="AEngine">The IOCP engine instance.</param>
    /// <param name="AIocp">The IOCP port handle.</param>
    constructor Create(AEngine: TDextIocpEngine; AIocp: THandle);
  end;

  /// <summary>
  ///   Native Windows raw IOCP socket server engine.
  /// </summary>
  TDextIocpEngine = class(TInterfacedObject, IDextServerEngine)
  private
    FOptions: TServerEngineOptions;
    FListenSocket: TSocket;
    FIocp: THandle;
    FRunning: Boolean;
    FListeningPort: Word;
    FAddress: string;
    
    FAcceptEx: TAcceptEx;
    FGetAcceptExSockaddrs: TGetAcceptExSockaddrs;

    FOnConnection: TConnectionEventHandler;
    FOnDisconnection: TConnectionEventHandler;
    FOnRequest: TRequestEventHandler;
    FOnUpgrade: TUpgradeEventHandler;

    FActiveConnections: Integer;
    FTotalRequests: Int64;

    FWorkers: TList;
    procedure LoadExtensions;
    procedure QueueAccept;
  public
    /// <summary>Initializes a new IOCP server engine.</summary>
    /// <param name="AOptions">The engine configuration options.</param>
    constructor Create(const AOptions: TServerEngineOptions);
    /// <summary>Destroys the engine and releases resources.</summary>
    destructor Destroy; override;

    /// <summary>Binds the engine to the specified address and port.</summary>
    /// <param name="AAddress">IP address to bind to.</param>
    /// <param name="APort">Port to listen on.</param>
    procedure Bind(const AAddress: string; APort: Word);
    /// <summary>Starts the IOCP listener port and worker threads loop.</summary>
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
{$ENDIF}

implementation

{$IFDEF MSWINDOWS}
const
  WSAID_ACCEPTEX: TGUID = '{b5367d37-239b-11d1-871c-0020afd6127f}';
  WSAID_GETACCEPTEXSOCKADDRS: TGUID = '{b5367d38-239b-11d1-871c-0020afd6127f}';
  SIO_GET_EXTENSION_FUNCTION_POINTER = $C8000006;

{ TDextIocpConnection }

constructor TDextIocpConnection.Create(ASocket: TSocket; const ARemoteAddress: string; ARemotePort, ALocalPort: Word);
begin
  inherited Create;
  FSocket := ASocket;
  FRemoteAddress := ARemoteAddress;
  FRemotePort := ARemotePort;
  FLocalPort := ALocalPort;
  FConnectionId := UInt64(ASocket);
end;

destructor TDextIocpConnection.Destroy;
begin
  Close;
  inherited;
end;

procedure TDextIocpConnection.Close;
begin
  if FSocket <> INVALID_SOCKET then
  begin
    closesocket(FSocket);
    FSocket := INVALID_SOCKET;
  end;
end;

function TDextIocpConnection.GetConnectionId: UInt64;
begin
  Result := FConnectionId;
end;

function TDextIocpConnection.GetLocalPort: Word;
begin
  Result := FLocalPort;
end;

function TDextIocpConnection.GetRemoteAddress: string;
begin
  Result := FRemoteAddress;
end;

function TDextIocpConnection.GetRemotePort: Word;
begin
  Result := FRemotePort;
end;

function TDextIocpConnection.IsSecure: Boolean;
begin
  Result := False; // Phase 1/3 does not implement SSL yet
end;

function TDextIocpConnection.SupportsUpgrade: Boolean;
begin
  Result := True;
end;

function TDextIocpConnection.UpgradeToWebSocket: IDextWebSocketConnection;
begin
  Result := nil; // WebSocket upgrade handled in S40
end;

{ TDextIocpRequest }

constructor TDextIocpRequest.Create(
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

destructor TDextIocpRequest.Destroy;
begin
  FHeaders.Free;
  FBodyStream.Free;
  inherited;
end;

function TDextIocpRequest.GetBodyStream: TStream;
begin
  Result := FBodyStream;
end;

function TDextIocpRequest.GetContentLength: Int64;
begin
  Result := FContentLength;
end;

function TDextIocpRequest.GetHeader(const AName: string): string;
begin
  if not FHeaders.TryGetValue(AName, Result) then
    Result := '';
end;

procedure TDextIocpRequest.PopulateHeaders(ADict: TDictionary<string, string>);
var
  Pair: TPair<string, string>;
begin
  for Pair in FHeaders do
    ADict.AddOrSetValue(Pair.Key, Pair.Value);
end;

function TDextIocpRequest.GetMethod: string;
begin
  Result := FMethod;
end;

function TDextIocpRequest.GetPath: string;
begin
  Result := FPath;
end;

function TDextIocpRequest.GetQueryString: string;
begin
  Result := FQuery;
end;

{ TDextIocpResponse }

constructor TDextIocpResponse.Create(ASocket: TSocket);
begin
  inherited Create;
  FSocket := ASocket;
  FHeadersSent := False;
  FStatusCode := 200;
  FReason := 'OK';
  FHeaders := TDictionary<string, string>.Create;
end;

destructor TDextIocpResponse.Destroy;
begin
  FHeaders.Free;
  inherited;
end;

procedure TDextIocpResponse.Close;
begin
  Flush;
end;

procedure TDextIocpResponse.Flush;
begin
  if not FHeadersSent then
    SendHeaders;
end;

procedure TDextIocpResponse.SendHeaders;
var
  HeaderStr: string;
  HeaderBytes: TBytes;
  Pair: TPair<string, string>;
  WsaBuf: TWsaBuf;
  BytesSent: DWORD;
begin
  if FHeadersSent then Exit;

  HeaderStr := Format('HTTP/1.1 %d %s'#13#10, [FStatusCode, FReason]);
  
  if not FHeaders.ContainsKey('Content-Type') then
    FHeaders.Add('Content-Type', 'text/plain');

  for Pair in FHeaders do
    HeaderStr := HeaderStr + Format('%s: %s'#13#10, [Pair.Key, Pair.Value]);

  HeaderStr := HeaderStr + #13#10;
  HeaderBytes := TEncoding.UTF8.GetBytes(HeaderStr);

  WsaBuf.len := Length(HeaderBytes);
  WsaBuf.buf := @HeaderBytes[0];

  WSASend(FSocket, @WsaBuf, 1, @BytesSent, 0, nil, nil);

  FHeadersSent := True;
end;

procedure TDextIocpResponse.SetHeader(const AName, AValue: string);
begin
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');
  FHeaders.AddOrSetValue(AName, AValue);
end;

procedure TDextIocpResponse.SetStatus(ACode: Integer; const AReason: string);
begin
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');
  FStatusCode := ACode;
  if AReason <> '' then
    FReason := AReason
  else
    FReason := 'OK';
end;

procedure TDextIocpResponse.Write(const ABuffer: TBytes; AOffset, ACount: Integer);
var
  WsaBuf: TWsaBuf;
  BytesSent: DWORD;
begin
  if not FHeadersSent then
    SendHeaders;

  if ACount <= 0 then Exit;

  WsaBuf.len := ACount;
  WsaBuf.buf := @ABuffer[AOffset];

  WSASend(FSocket, @WsaBuf, 1, @BytesSent, 0, nil, nil);
end;

{ TDextIocpWorker }

constructor TDextIocpWorker.Create(AEngine: TDextIocpEngine; AIocp: THandle);
begin
  inherited Create(True);
  FEngine := AEngine;
  FIocp := AIocp;
  FreeOnTerminate := False;
end;

procedure TDextIocpWorker.Execute;
var
  BytesTransferred: DWORD;
  CompletionKey: ULONG_PTR;
  IocpOverlapped: PIocpOverlapped;
  Ret: BOOL;
  RecvRet: Integer;
  LocalAddr, RemoteAddr: PSockAddr;
  LocalAddrLen, RemoteAddrLen: Integer;
  RemoteAddress: string;
  LocalPort, RemotePort: Word;
  Buffer: TBytes;
  Method, Path, Query, Version: string;
  Headers: TDictionary<string, string>;
  BodyOffset: Integer;
  ContentLength: Int64;
  Connection: IDextServerConnection;
  RawRequest: IDextRawRequest;
  RawResponse: IDextRawResponse;
begin
  IocpOverlapped := nil;

  while not Terminated and FEngine.FRunning do
  begin
    BytesTransferred := 0;
    CompletionKey := 0;
    
    Ret := GetQueuedCompletionStatus(
      FIocp,
      BytesTransferred,
      CompletionKey,
      POverlapped(IocpOverlapped),
      INFINITE
    );

    if (not Ret) or (IocpOverlapped = nil) then
    begin
      if IocpOverlapped <> nil then
      begin
        closesocket(IocpOverlapped.Socket);
        Dispose(IocpOverlapped);
      end;
      Continue;
    end;

    case IocpOverlapped.OpType of
      ioAccept:
      begin
        // Process new client socket accepted
        // Load local/remote address info
        FEngine.FGetAcceptExSockaddrs(
          @IocpOverlapped.Buffer[0],
          0,
          SizeOf(TSockAddrIn) + 16,
          SizeOf(TSockAddrIn) + 16,
          LocalAddr,
          LocalAddrLen,
          RemoteAddr,
          RemoteAddrLen
        );

        RemoteAddress := string(AnsiString(inet_ntoa(PSockAddrIn(RemoteAddr).sin_addr)));
        RemotePort := ntohs(PSockAddrIn(RemoteAddr).sin_port);
        LocalPort := ntohs(PSockAddrIn(LocalAddr).sin_port);

        // Associate socket with IOCP port
        CreateIoCompletionPort(IocpOverlapped.Socket, FIocp, CompletionKey, 0);

        // Post zero-byte read to notify worker of incoming data
        IocpOverlapped.OpType := ioRead;
        IocpOverlapped.BytesTransferred := 0;
        
        // Setup raw read request
        TInterlocked.Increment(FEngine.FActiveConnections);
        
        // Spawn next accept queue
        FEngine.QueueAccept;

        // Directly post read operation
        // For simplicity in Phase 3, we execute synchronous recv
        SetLength(Buffer, 8192);
        RecvRet := recv(IocpOverlapped.Socket, Buffer[0], Length(Buffer), 0);
        if RecvRet > 0 then
        begin
          if TDextIocpHttpParser.TryParseRequest(
            Buffer,
            RecvRet,
            Method,
            Path,
            Query,
            Version,
            Headers,
            BodyOffset,
            ContentLength
          ) then
          begin
            TInterlocked.Increment(FEngine.FTotalRequests);

            Connection := TDextIocpConnection.Create(IocpOverlapped.Socket, RemoteAddress, RemotePort, LocalPort);
            RawRequest := TDextIocpRequest.Create(Method, Path, Query, Headers, Buffer, BodyOffset, RecvRet - BodyOffset, ContentLength);
            RawResponse := TDextIocpResponse.Create(IocpOverlapped.Socket);

            try
              if Assigned(FEngine.FOnRequest) then
                FEngine.FOnRequest(Connection, RawRequest, RawResponse);
            finally
              RawResponse.Close;
              RawResponse := nil;
              RawRequest := nil;
              Connection := nil;
            end;
          end;
        end;

        closesocket(IocpOverlapped.Socket);
        TInterlocked.Decrement(FEngine.FActiveConnections);
        Dispose(IocpOverlapped);
      end;
    end;
  end;
end;

{ TDextIocpEngine }

constructor TDextIocpEngine.Create(const AOptions: TServerEngineOptions);
var
  WsaData: TWsaData;
begin
  inherited Create;
  FOptions := AOptions;
  FListenSocket := INVALID_SOCKET;
  FIocp := 0;
  FRunning := False;
  FWorkers := TList.Create;
  
  if WSAStartup($0202, WsaData) <> 0 then
    raise EOSError.Create('WSAStartup failed');
end;

destructor TDextIocpEngine.Destroy;
begin
  Stop;
  FWorkers.Free;
  WSACleanup;
  inherited;
end;

procedure TDextIocpEngine.Bind(const AAddress: string; APort: Word);
begin
  FAddress := AAddress;
  FListeningPort := APort;
end;

procedure TDextIocpEngine.LoadExtensions;
var
  Socket: TSocket;
  Bytes: DWORD;
  GuidAcceptEx: TGUID;
  GuidGetSockAddrs: TGUID;
begin
  Socket := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);
  if Socket = INVALID_SOCKET then
    raise EOSError.Create('Failed to create temporary socket');

  GuidAcceptEx := WSAID_ACCEPTEX;
  WSAIoctl(Socket, SIO_GET_EXTENSION_FUNCTION_POINTER, @GuidAcceptEx, SizeOf(GuidAcceptEx),
    @FAcceptEx, SizeOf(Pointer), Bytes, nil, nil);

  GuidGetSockAddrs := WSAID_GETACCEPTEXSOCKADDRS;
  WSAIoctl(Socket, SIO_GET_EXTENSION_FUNCTION_POINTER, @GuidGetSockAddrs, SizeOf(GuidGetSockAddrs),
    @FGetAcceptExSockaddrs, SizeOf(Pointer), Bytes, nil, nil);

  closesocket(Socket);

  if not Assigned(FAcceptEx) or not Assigned(FGetAcceptExSockaddrs) then
    raise EOSError.Create('Failed to load AcceptEx extension function pointers');
end;

procedure TDextIocpEngine.QueueAccept;
var
  AcceptSocket: TSocket;
  Overlapped: PIocpOverlapped;
  BytesReceived: DWORD;
begin
  AcceptSocket := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);
  if AcceptSocket = INVALID_SOCKET then Exit;

  New(Overlapped);
  FillChar(Overlapped^, SizeOf(TIocpOverlapped), 0);
  Overlapped.OpType := ioAccept;
  Overlapped.Socket := AcceptSocket;

  FAcceptEx(
    FListenSocket,
    AcceptSocket,
    @Overlapped.Buffer[0],
    0,
    SizeOf(TSockAddrIn) + 16,
    SizeOf(TSockAddrIn) + 16,
    BytesReceived,
    POverlapped(Overlapped)
  );
end;

procedure TDextIocpEngine.Start;
var
  Addr: TSockAddrIn;
  I: Integer;
  ThreadCount: Integer;
  Worker: TDextIocpWorker;
begin
  if FRunning then Exit;

  LoadExtensions;

  FIocp := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
  if FIocp = 0 then
    raise EOSError.Create('Failed to create completion port');

  FListenSocket := WSASocket(AF_INET, SOCK_STREAM, IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);
  if FListenSocket = INVALID_SOCKET then
    raise EOSError.Create('Failed to create listen socket');

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(FListeningPort);
  if (FAddress = '') or (FAddress = '0.0.0.0') then
    Addr.sin_addr.S_addr := INADDR_ANY
  else
    Addr.sin_addr.S_addr := inet_addr(PAnsiChar(AnsiString(FAddress)));

  if Winapi.WinSock2.bind(FListenSocket, PSockAddr(@Addr)^, SizeOf(Addr)) = SOCKET_ERROR then
    raise EOSError.Create('Socket bind failed');

  if listen(FListenSocket, SOMAXCONN) = SOCKET_ERROR then
    raise EOSError.Create('Socket listen failed');

  // Associate listen socket with IOCP
  CreateIoCompletionPort(FListenSocket, FIocp, 0, 0);

  FRunning := True;

  // Queue initial accept operations
  for I := 1 to 10 do
    QueueAccept;

  // Start Worker Threads
  ThreadCount := FOptions.IoThreadCount;
  if ThreadCount <= 0 then
    ThreadCount := CPUCount;

  for I := 1 to ThreadCount do
  begin
    Worker := TDextIocpWorker.Create(Self, FIocp);
    FWorkers.Add(Worker);
    Worker.Start;
  end;
end;

procedure TDextIocpEngine.Stop(AGracefulTimeoutMs: Integer);
var
  I: Integer;
  Worker: TDextIocpWorker;
begin
  if not FRunning then Exit;

  FRunning := False;

  if FListenSocket <> INVALID_SOCKET then
  begin
    closesocket(FListenSocket);
    FListenSocket := INVALID_SOCKET;
  end;

  if FIocp <> 0 then
  begin
    // Wake up all threads
    for I := 0 to FWorkers.Count - 1 do
      PostQueuedCompletionStatus(FIocp, 0, 0, nil);
  end;

  // Stop threads
  for I := 0 to FWorkers.Count - 1 do
  begin
    Worker := TDextIocpWorker(FWorkers[I]);
    Worker.Terminate;
  end;

  for I := 0 to FWorkers.Count - 1 do
  begin
    Worker := TDextIocpWorker(FWorkers[I]);
    Worker.WaitFor;
    Worker.Free;
  end;
  FWorkers.Clear;

  if FIocp <> 0 then
  begin
    CloseHandle(FIocp);
    FIocp := 0;
  end;
end;

function TDextIocpEngine.GetActiveConnections: Integer;
begin
  Result := FActiveConnections;
end;

function TDextIocpEngine.GetListenPort: Word;
begin
  Result := FListeningPort;
end;

function TDextIocpEngine.GetTotalRequests: Int64;
begin
  Result := FTotalRequests;
end;

procedure TDextIocpEngine.SetOnConnection(const AHandler: TConnectionEventHandler);
begin
  FOnConnection := AHandler;
end;

procedure TDextIocpEngine.SetOnDisconnection(const AHandler: TConnectionEventHandler);
begin
  FOnDisconnection := AHandler;
end;

procedure TDextIocpEngine.SetOnRequest(const AHandler: TRequestEventHandler);
begin
  FOnRequest := AHandler;
end;

procedure TDextIocpEngine.SetOnUpgrade(const AHandler: TUpgradeEventHandler);
begin
  FOnUpgrade := AHandler;
end;

{$ENDIF}

end.
