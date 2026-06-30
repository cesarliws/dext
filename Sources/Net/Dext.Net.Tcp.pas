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
{  Author:  Cesar Romero & Antigravity AI                                   }
{  Created: 2026-06-29                                                      }
{                                                                           }
{  High-performance TCP server, client and connection implementations.       }
{                                                                           }
{***************************************************************************}
unit Dext.Net.Tcp;

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  Dext.Core.Span;

type
  {$IFDEF MSWINDOWS}
  TSocketHandle = NativeUInt;
  {$ELSE}
  TSocketHandle = Integer;
  {$ENDIF}

  EDextSocketError = class(Exception);

  ITcpConnection = interface
    ['{E3C2B6A1-9F0D-47C1-B6C2-EA15C3847BE2}']
    function GetConnectionId: UInt64;
    function GetRemoteAddress: string;
    function GetRemotePort: Word;
    procedure Send(const ABuffer: TBytes); overload;
    procedure Send(const ASpan: TByteSpan); overload;
    procedure Send(const AStream: TStream); overload;
    procedure Close;
    property ConnectionId: UInt64 read GetConnectionId;
    property RemoteAddress: string read GetRemoteAddress;
    property RemotePort: Word read GetRemotePort;
  end;

  TTcpConnectionEvent = reference to procedure(const AConnection: ITcpConnection);
  TTcpDataEvent = reference to procedure(const AConnection: ITcpConnection; const AData: TBytes);
  TTcpSpanDataEvent = reference to procedure(const AConnection: ITcpConnection; const AData: TByteSpan);
  TTcpErrorEvent = reference to procedure(const AConnection: ITcpConnection; AException: Exception);

  TDextTcpServer = class
  private
    FAddress: string;
    FListenPort: Word;
    FListenSocket: TSocketHandle;
    FRunning: Boolean;
    FAcceptThread: TThread;
    FOnConnect: TTcpConnectionEvent;
    FOnDisconnect: TTcpConnectionEvent;
    FOnData: TTcpDataEvent;
    FOnDataSpan: TTcpSpanDataEvent;
    FOnError: TTcpErrorEvent;
    procedure AcceptLoop;
    procedure CloseListenSocket;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Bind(const AAddress: string; APort: Word);
    procedure Start;
    procedure Stop;
    function GetListenPort: Word;
    property ListenPort: Word read GetListenPort;
    property OnConnect: TTcpConnectionEvent read FOnConnect write FOnConnect;
    property OnDisconnect: TTcpConnectionEvent read FOnDisconnect write FOnDisconnect;
    property OnData: TTcpDataEvent read FOnData write FOnData;
    property OnDataSpan: TTcpSpanDataEvent read FOnDataSpan write FOnDataSpan;
    property OnError: TTcpErrorEvent read FOnError write FOnError;
  end;

  TDextTcpClient = class
  private
    FSocket: TSocketHandle;
    FConnected: Boolean;
    FRemoteAddress: string;
    FRemotePort: Word;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Connect(const AAddress: string; APort: Word);
    procedure Disconnect;
    procedure Send(const ABuffer: TBytes); overload;
    procedure Send(const ASpan: TByteSpan); overload;
    function Receive(var ABuffer: TBytes; ATimeoutMs: Integer = 5000): Integer; overload;
    function Receive(const ASpan: TByteSpan; ATimeoutMs: Integer = 5000): Integer; overload;
    property Connected: Boolean read FConnected;
    property RemoteAddress: string read FRemoteAddress;
    property RemotePort: Word read FRemotePort;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows,
  Winapi.WinSock2;
{$ELSE}
uses
  Posix.ArpaInet,
  Posix.Errno,
  Posix.NetinetIn,
  Posix.SysSelect,
  Posix.SysSocket,
  Posix.SysTime,
  Posix.Unistd;
{$ENDIF}

const
  DEXT_TCP_RECV_BUFFER_SIZE = 65536;

{$IFDEF MSWINDOWS}
const
  DEXT_INVALID_SOCKET = TSocketHandle(INVALID_SOCKET);
  DEXT_SOCKET_ERROR = SOCKET_ERROR;
{$ELSE}
const
  DEXT_INVALID_SOCKET = -1;
  DEXT_SOCKET_ERROR = -1;
{$ENDIF}

type
  TDextTcpConnection = class(TInterfacedObject, ITcpConnection)
  private
    FConnectionId: UInt64;
    FSocket: TSocketHandle;
    FRemoteAddress: string;
    FRemotePort: Word;
    FLock: TCriticalSection;
  public
    constructor Create(ASocket: TSocketHandle; const ARemoteAddress: string; ARemotePort: Word);
    destructor Destroy; override;
    function GetConnectionId: UInt64;
    function GetRemoteAddress: string;
    function GetRemotePort: Word;
    procedure Send(const ABuffer: TBytes); overload;
    procedure Send(const ASpan: TByteSpan); overload;
    procedure Send(const AStream: TStream); overload;
    procedure Close;
  end;

  TDextTcpAcceptThread = class(TThread)
  private
    FServer: TDextTcpServer;
  protected
    procedure Execute; override;
  public
    constructor Create(AServer: TDextTcpServer);
  end;

  TDextTcpConnectionThread = class(TThread)
  private
    FServer: TDextTcpServer;
    FConnection: ITcpConnection;
    FSocket: TSocketHandle;
  protected
    procedure Execute; override;
  public
    constructor Create(AServer: TDextTcpServer; const AConnection: ITcpConnection; ASocket: TSocketHandle);
  end;

var
  WinsockLock: TCriticalSection;
  WinsockRefCount: Integer;

procedure EnsureSocketsStarted;
{$IFDEF MSWINDOWS}
var
  data: WSAData;
{$ENDIF}
begin
  WinsockLock.Acquire;
  try
    if WinsockRefCount = 0 then
    begin
      {$IFDEF MSWINDOWS}
      if WSAStartup($0202, data) <> 0 then
        raise EDextSocketError.Create('WSAStartup failed');
      {$ENDIF}
    end;
    Inc(WinsockRefCount);
  finally
    WinsockLock.Release;
  end;
end;

procedure ReleaseSockets;
begin
  WinsockLock.Acquire;
  try
    Dec(WinsockRefCount);
    if WinsockRefCount = 0 then
    begin
      {$IFDEF MSWINDOWS}
      WSACleanup;
      {$ENDIF}
    end;
  finally
    WinsockLock.Release;
  end;
end;

procedure CloseSocketHandle(var ASocket: TSocketHandle);
begin
  if ASocket = DEXT_INVALID_SOCKET then
    Exit;

  {$IFDEF MSWINDOWS}
  shutdown(ASocket, SD_BOTH);
  closesocket(ASocket);
  {$ELSE}
  shutdown(ASocket, SHUT_RDWR);
  __close(ASocket);
  {$ENDIF}
  ASocket := DEXT_INVALID_SOCKET;
end;

function SocketLastError: Integer;
begin
  {$IFDEF MSWINDOWS}
  Result := WSAGetLastError;
  {$ELSE}
  Result := errno;
  {$ENDIF}
end;

function IsWouldBlock(AError: Integer): Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := (AError = WSAEWOULDBLOCK) or (AError = WSAETIMEDOUT);
  {$ELSE}
  Result := (AError = EAGAIN) or (AError = EWOULDBLOCK) or (AError = ETIMEDOUT);
  {$ENDIF}
end;

function AddressToInAddr(const AAddress: string): Cardinal;
var
  text: AnsiString;
begin
  if AAddress = '' then
    text := '0.0.0.0'
  else
    text := AnsiString(AAddress);
  Result := inet_addr(PAnsiChar(text));
end;

function SockAddrToString(const AAddr: sockaddr_in): string;
var
  text: PAnsiChar;
begin
  text := inet_ntoa(AAddr.sin_addr);
  if text = nil then
    Result := ''
  else
    Result := string(AnsiString(text));
end;

function CreateTcpSocket: TSocketHandle;
begin
  Result := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if Result = DEXT_INVALID_SOCKET then
    raise EDextSocketError.CreateFmt('TCP socket failed: %d', [SocketLastError]);
end;

procedure SetRecvTimeout(ASocket: TSocketHandle; ATimeoutMs: Integer);
{$IFDEF MSWINDOWS}
var
  timeout: DWORD;
{$ELSE}
var
  timeout: timeval;
{$ENDIF}
begin
  if ATimeoutMs < 0 then
    Exit;

  {$IFDEF MSWINDOWS}
  timeout := DWORD(ATimeoutMs);
  setsockopt(ASocket, SOL_SOCKET, SO_RCVTIMEO, PAnsiChar(@timeout), SizeOf(timeout));
  {$ELSE}
  timeout.tv_sec := ATimeoutMs div 1000;
  timeout.tv_usec := (ATimeoutMs mod 1000) * 1000;
  setsockopt(ASocket, SOL_SOCKET, SO_RCVTIMEO, timeout, SizeOf(timeout));
  {$ENDIF}
end;

function SendSpanToSocket(ASocket: TSocketHandle; const ASpan: TByteSpan): Integer;
var
  sentTotal: Integer;
  sentNow: Integer;
begin
  sentTotal := 0;
  while sentTotal < ASpan.Length do
  begin
    sentNow := send(ASocket, PByte(ASpan.Data + sentTotal)^, ASpan.Length - sentTotal, 0);
    if sentNow = DEXT_SOCKET_ERROR then
      raise EDextSocketError.CreateFmt('TCP send failed: %d', [SocketLastError]);
    if sentNow = 0 then
      Break;
    Inc(sentTotal, sentNow);
  end;
  Result := sentTotal;
end;

function BindSocket(ASocket: TSocketHandle; const AAddr: sockaddr_in): Integer;
begin
  {$IFDEF MSWINDOWS}
  Result := Winapi.WinSock2.bind(ASocket, PSockAddr(@AAddr)^, SizeOf(AAddr));
  {$ELSE}
  Result := Posix.SysSocket.bind(ASocket, sockaddr(Pointer(@AAddr)^), SizeOf(AAddr));
  {$ENDIF}
end;

function ListenSocket(ASocket: TSocketHandle; ABacklog: Integer): Integer;
begin
  {$IFDEF MSWINDOWS}
  Result := Winapi.WinSock2.listen(ASocket, ABacklog);
  {$ELSE}
  Result := Posix.SysSocket.listen(ASocket, ABacklog);
  {$ENDIF}
end;

function GetSocketName(ASocket: TSocketHandle; var AAddr: sockaddr_in; var AAddrLen: Integer): Integer;
{$IFNDEF MSWINDOWS}
var
  len: socklen_t;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  Result := Winapi.WinSock2.getsockname(ASocket, PSockAddr(@AAddr)^, AAddrLen);
  {$ELSE}
  len := AAddrLen;
  Result := Posix.SysSocket.getsockname(ASocket, sockaddr(Pointer(@AAddr)^), len);
  AAddrLen := len;
  {$ENDIF}
end;

function ConnectSocket(ASocket: TSocketHandle; const AAddr: sockaddr_in): Integer;
begin
  {$IFDEF MSWINDOWS}
  Result := Winapi.WinSock2.connect(ASocket, PSockAddr(@AAddr)^, SizeOf(AAddr));
  {$ELSE}
  Result := Posix.SysSocket.connect(ASocket, sockaddr(Pointer(@AAddr)^), SizeOf(AAddr));
  {$ENDIF}
end;

{ TDextTcpConnection }

constructor TDextTcpConnection.Create(ASocket: TSocketHandle; const ARemoteAddress: string; ARemotePort: Word);
begin
  inherited Create;
  FSocket := ASocket;
  FRemoteAddress := ARemoteAddress;
  FRemotePort := ARemotePort;
  FConnectionId := UInt64(ASocket);
  FLock := TCriticalSection.Create;
end;

destructor TDextTcpConnection.Destroy;
begin
  Close;
  FLock.Free;
  inherited;
end;

procedure TDextTcpConnection.Close;
begin
  FLock.Acquire;
  try
    CloseSocketHandle(FSocket);
  finally
    FLock.Release;
  end;
end;

function TDextTcpConnection.GetConnectionId: UInt64;
begin
  Result := FConnectionId;
end;

function TDextTcpConnection.GetRemoteAddress: string;
begin
  Result := FRemoteAddress;
end;

function TDextTcpConnection.GetRemotePort: Word;
begin
  Result := FRemotePort;
end;

procedure TDextTcpConnection.Send(const ABuffer: TBytes);
var
  span: TByteSpan;
begin
  span := TByteSpan.FromBytes(ABuffer);
  Send(span);
end;

procedure TDextTcpConnection.Send(const ASpan: TByteSpan);
begin
  if ASpan.Length = 0 then
    Exit;

  FLock.Acquire;
  try
    if FSocket = DEXT_INVALID_SOCKET then
      raise EDextSocketError.Create('TCP connection is closed');
    SendSpanToSocket(FSocket, ASpan);
  finally
    FLock.Release;
  end;
end;

procedure TDextTcpConnection.Send(const AStream: TStream);
var
  buffer: array[0..16383] of Byte;
  span: TByteSpan;
  readCount: Integer;
begin
  if AStream = nil then
    Exit;

  repeat
    readCount := AStream.Read(buffer[0], SizeOf(buffer));
    if readCount > 0 then
    begin
      span := TByteSpan.Create(@buffer[0], readCount);
      Send(span);
    end;
  until readCount = 0;
end;

{ TDextTcpAcceptThread }

constructor TDextTcpAcceptThread.Create(AServer: TDextTcpServer);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FServer := AServer;
end;

procedure TDextTcpAcceptThread.Execute;
begin
  FServer.AcceptLoop;
end;

{ TDextTcpConnectionThread }

constructor TDextTcpConnectionThread.Create(AServer: TDextTcpServer; const AConnection: ITcpConnection; ASocket: TSocketHandle);
begin
  inherited Create(False);
  FreeOnTerminate := True;
  FServer := AServer;
  FConnection := AConnection;
  FSocket := ASocket;
end;

procedure TDextTcpConnectionThread.Execute;
var
  buffer: array[0..DEXT_TCP_RECV_BUFFER_SIZE - 1] of Byte;
  bytesRead: Integer;
  data: TBytes;
  span: TByteSpan;
begin
  try
    if Assigned(FServer.FOnConnect) then
      FServer.FOnConnect(FConnection);

    while not Terminated and FServer.FRunning do
    begin
      bytesRead := recv(FSocket, buffer[0], SizeOf(buffer), 0);
      if bytesRead <= 0 then
        Break;

      span := TByteSpan.Create(@buffer[0], bytesRead);
      if Assigned(FServer.FOnDataSpan) then
        FServer.FOnDataSpan(FConnection, span);

      if Assigned(FServer.FOnData) then
      begin
        SetLength(data, bytesRead);
        Move(buffer[0], data[0], bytesRead);
        FServer.FOnData(FConnection, data);
      end;
    end;
  except
    on error: Exception do
    begin
      if Assigned(FServer.FOnError) then
        FServer.FOnError(FConnection, error);
    end;
  end;

  if Assigned(FServer.FOnDisconnect) then
    FServer.FOnDisconnect(FConnection);
  FConnection.Close;
end;

{ TDextTcpServer }

constructor TDextTcpServer.Create;
begin
  inherited Create;
  EnsureSocketsStarted;
  FListenSocket := DEXT_INVALID_SOCKET;
  FAddress := '0.0.0.0';
end;

destructor TDextTcpServer.Destroy;
begin
  Stop;
  ReleaseSockets;
  inherited;
end;

procedure TDextTcpServer.AcceptLoop;
var
  clientSocket: TSocketHandle;
  remoteAddr: sockaddr_in;
  remoteLen: Integer;
  connection: ITcpConnection;
  remoteAddress: string;
  remotePort: Word;
  {$IFNDEF MSWINDOWS}
  len: socklen_t;
  tempAddr: sockaddr;
  {$ENDIF}
begin
  while FRunning do
  begin
    remoteLen := SizeOf(remoteAddr);
    {$IFDEF MSWINDOWS}
    clientSocket := accept(FListenSocket, PSockAddr(@remoteAddr), @remoteLen);
    {$ELSE}
    len := remoteLen;
    clientSocket := accept(FListenSocket, tempAddr, len);
    if clientSocket <> DEXT_INVALID_SOCKET then
    begin
      Move(tempAddr, remoteAddr, SizeOf(remoteAddr));
    end;
    {$ENDIF}
    if clientSocket = DEXT_INVALID_SOCKET then
    begin
      if FRunning then
        Sleep(1);
      Continue;
    end;

    remoteAddress := SockAddrToString(remoteAddr);
    remotePort := ntohs(remoteAddr.sin_port);
    connection := TDextTcpConnection.Create(clientSocket, remoteAddress, remotePort);
    TDextTcpConnectionThread.Create(Self, connection, clientSocket);
  end;
end;

procedure TDextTcpServer.Bind(const AAddress: string; APort: Word);
var
  addr: sockaddr_in;
  addrLen: Integer;
  yes: Integer;
begin
  if FRunning then
    raise EDextSocketError.Create('TCP server is running');
  if FListenSocket <> DEXT_INVALID_SOCKET then
    CloseListenSocket;

  FAddress := AAddress;
  FListenSocket := CreateTcpSocket;
  {$IFDEF MSWINDOWS}
  setsockopt(FListenSocket, SOL_SOCKET, SO_REUSEADDR, PAnsiChar(@yes), SizeOf(yes));
  {$ELSE}
  setsockopt(FListenSocket, SOL_SOCKET, SO_REUSEADDR, yes, SizeOf(yes));
  {$ENDIF}

  FillChar(addr, SizeOf(addr), 0);
  addr.sin_family := AF_INET;
  addr.sin_addr.s_addr := AddressToInAddr(AAddress);
  addr.sin_port := htons(APort);

  if BindSocket(FListenSocket, addr) = DEXT_SOCKET_ERROR then
    raise EDextSocketError.CreateFmt('TCP bind failed: %d', [SocketLastError]);

  if ListenSocket(FListenSocket, SOMAXCONN) = DEXT_SOCKET_ERROR then
    raise EDextSocketError.CreateFmt('TCP listen failed: %d', [SocketLastError]);

  addrLen := SizeOf(addr);
  if GetSocketName(FListenSocket, addr, addrLen) = 0 then
    FListenPort := ntohs(addr.sin_port)
  else
    FListenPort := APort;
end;

procedure TDextTcpServer.CloseListenSocket;
begin
  CloseSocketHandle(FListenSocket);
end;

function TDextTcpServer.GetListenPort: Word;
begin
  Result := FListenPort;
end;

procedure TDextTcpServer.Start;
begin
  if FListenSocket = DEXT_INVALID_SOCKET then
    Bind(FAddress, FListenPort);
  if FRunning then
    Exit;

  FRunning := True;
  FAcceptThread := TDextTcpAcceptThread.Create(Self);
end;

procedure TDextTcpServer.Stop;
begin
  if not FRunning and (FListenSocket = DEXT_INVALID_SOCKET) then
    Exit;

  FRunning := False;
  CloseListenSocket;

  if FAcceptThread <> nil then
  begin
    FAcceptThread.Terminate;
    FAcceptThread.WaitFor;
    FAcceptThread.Free;
    FAcceptThread := nil;
  end;
end;

{ TDextTcpClient }

constructor TDextTcpClient.Create;
begin
  inherited Create;
  EnsureSocketsStarted;
  FSocket := DEXT_INVALID_SOCKET;
end;

destructor TDextTcpClient.Destroy;
begin
  Disconnect;
  ReleaseSockets;
  inherited;
end;

procedure TDextTcpClient.Connect(const AAddress: string; APort: Word);
var
  addr: sockaddr_in;
begin
  if FConnected then
    Disconnect;

  FSocket := CreateTcpSocket;
  FillChar(addr, SizeOf(addr), 0);
  addr.sin_family := AF_INET;
  addr.sin_addr.s_addr := AddressToInAddr(AAddress);
  addr.sin_port := htons(APort);

  if ConnectSocket(FSocket, addr) = DEXT_SOCKET_ERROR then
    raise EDextSocketError.CreateFmt('TCP connect failed: %d', [SocketLastError]);

  FRemoteAddress := AAddress;
  FRemotePort := APort;
  FConnected := True;
end;

procedure TDextTcpClient.Disconnect;
begin
  CloseSocketHandle(FSocket);
  FConnected := False;
end;

function TDextTcpClient.Receive(var ABuffer: TBytes; ATimeoutMs: Integer): Integer;
var
  span: TByteSpan;
begin
  if Length(ABuffer) = 0 then
    SetLength(ABuffer, DEXT_TCP_RECV_BUFFER_SIZE);
  span := TByteSpan.FromBytes(ABuffer);
  Result := Receive(span, ATimeoutMs);
end;

function TDextTcpClient.Receive(const ASpan: TByteSpan; ATimeoutMs: Integer): Integer;
var
  error: Integer;
begin
  if not FConnected then
    raise EDextSocketError.Create('TCP client is not connected');
  if ASpan.Length = 0 then
    Exit(0);

  SetRecvTimeout(FSocket, ATimeoutMs);
  Result := recv(FSocket, ASpan.Data^, ASpan.Length, 0);
  if Result = DEXT_SOCKET_ERROR then
  begin
    error := SocketLastError;
    if IsWouldBlock(error) then
      Exit(0);
    raise EDextSocketError.CreateFmt('TCP receive failed: %d', [error]);
  end;
end;

procedure TDextTcpClient.Send(const ABuffer: TBytes);
var
  span: TByteSpan;
begin
  span := TByteSpan.FromBytes(ABuffer);
  Send(span);
end;

procedure TDextTcpClient.Send(const ASpan: TByteSpan);
begin
  if not FConnected then
    raise EDextSocketError.Create('TCP client is not connected');
  SendSpanToSocket(FSocket, ASpan);
end;

initialization
  WinsockLock := TCriticalSection.Create;

finalization
  WinsockLock.Free;

end.
