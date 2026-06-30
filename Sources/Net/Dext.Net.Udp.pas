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
{  High-performance UDP server and client implementations.                   }
{                                                                           }
{***************************************************************************}
unit Dext.Net.Udp;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Core.Span;

type
  {$IFDEF MSWINDOWS}
  TSocketHandle = NativeUInt;
  {$ELSE}
  TSocketHandle = Integer;
  {$ENDIF}

  EDextSocketError = class(Exception);

  TUdpPacket = record
    RemoteAddress: string;
    RemotePort: Word;
    Data: TBytes;
  end;

  TUdpSpanPacket = record
    RemoteAddress: string;
    RemotePort: Word;
    Data: TByteSpan;
  end;

  TUdpPacketEvent = reference to procedure(const APacket: TUdpPacket);
  TUdpSpanPacketEvent = reference to procedure(const APacket: TUdpSpanPacket);
  TUdpErrorEvent = reference to procedure(AException: Exception);

  TDextUdpServer = class
  private
    FAddress: string;
    FPort: Word;
    FSocket: TSocketHandle;
    FRunning: Boolean;
    FThread: TThread;
    FOnPacketReceived: TUdpPacketEvent;
    FOnPacketSpanReceived: TUdpSpanPacketEvent;
    FOnError: TUdpErrorEvent;
    procedure CloseSocket;
    procedure ReceiveLoop;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Bind(const AAddress: string; APort: Word);
    procedure Start;
    procedure Stop;
    procedure SendTo(const AAddress: string; APort: Word; const AData: TBytes); overload;
    procedure SendTo(const AAddress: string; APort: Word; const AData: TByteSpan); overload;
    function GetListenPort: Word;
    property ListenPort: Word read GetListenPort;
    property OnPacketReceived: TUdpPacketEvent read FOnPacketReceived write FOnPacketReceived;
    property OnPacketSpanReceived: TUdpSpanPacketEvent read FOnPacketSpanReceived write FOnPacketSpanReceived;
    property OnError: TUdpErrorEvent read FOnError write FOnError;
  end;

  TDextUdpClient = class
  private
    FSocket: TSocketHandle;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Send(const AAddress: string; APort: Word; const AData: TBytes); overload;
    procedure Send(const AAddress: string; APort: Word; const AData: TByteSpan); overload;
    function Receive(out APacket: TUdpPacket; ATimeoutMs: Integer = 5000): Boolean; overload;
    function Receive(var APacket: TUdpSpanPacket; ATimeoutMs: Integer = 5000): Boolean; overload;
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
  DEXT_UDP_RECV_BUFFER_SIZE = 65536;

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
  TDextUdpServerThread = class(TThread)
  private
    FServer: TDextUdpServer;
  protected
    procedure Execute; override;
  public
    constructor Create(AServer: TDextUdpServer);
  end;

var
  WinsockRefCount: Integer;

procedure EnsureSocketsStarted;
{$IFDEF MSWINDOWS}
var
  data: WSAData;
{$ENDIF}
begin
  if WinsockRefCount = 0 then
  begin
    {$IFDEF MSWINDOWS}
    if WSAStartup($0202, data) <> 0 then
      raise EDextSocketError.Create('WSAStartup failed');
    {$ENDIF}
  end;
  Inc(WinsockRefCount);
end;

procedure ReleaseSockets;
begin
  Dec(WinsockRefCount);
  if WinsockRefCount = 0 then
  begin
    {$IFDEF MSWINDOWS}
    WSACleanup;
    {$ENDIF}
  end;
end;

procedure CloseSocketHandle(var ASocket: TSocketHandle);
begin
  if ASocket = DEXT_INVALID_SOCKET then
    Exit;

  {$IFDEF MSWINDOWS}
  closesocket(ASocket);
  {$ELSE}
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

function CreateUdpSocket: TSocketHandle;
begin
  Result := socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if Result = DEXT_INVALID_SOCKET then
    raise EDextSocketError.CreateFmt('UDP socket failed: %d', [SocketLastError]);
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

procedure SendUdpSpan(ASocket: TSocketHandle; const AAddress: string; APort: Word; const AData: TByteSpan);
var
  addr: sockaddr_in;
  sent: Integer;
begin
  if AData.Length = 0 then
    Exit;

  FillChar(addr, SizeOf(addr), 0);
  addr.sin_family := AF_INET;
  addr.sin_addr.s_addr := AddressToInAddr(AAddress);
  addr.sin_port := htons(APort);

  {$IFDEF MSWINDOWS}
  sent := sendto(ASocket, AData.Data^, AData.Length, 0, PSockAddr(@addr), SizeOf(addr));
  {$ELSE}
  var
    tempAddr: sockaddr;
  begin
    Move(addr, tempAddr, SizeOf(addr));
    sent := Posix.SysSocket.sendto(ASocket, AData.Data^, AData.Length, 0, tempAddr, SizeOf(addr));
  end;
  {$ENDIF}
  if sent = DEXT_SOCKET_ERROR then
    raise EDextSocketError.CreateFmt('UDP sendto failed: %d', [SocketLastError]);
end;

function ReceiveUdpSpan(ASocket: TSocketHandle; var APacket: TUdpSpanPacket; ATimeoutMs: Integer): Boolean;
var
  addr: sockaddr_in;
  addrLen: Integer;
  bytesRead: Integer;
  error: Integer;
  {$IFNDEF MSWINDOWS}
  len: socklen_t;
  tempAddr: sockaddr;
  {$ENDIF}
begin
  Result := False;
  if APacket.Data.Length = 0 then
    Exit;

  SetRecvTimeout(ASocket, ATimeoutMs);
  addrLen := SizeOf(addr);
  {$IFDEF MSWINDOWS}
  bytesRead := recvfrom(ASocket, APacket.Data.Data^, APacket.Data.Length, 0, PSockAddr(@addr)^, addrLen);
  {$ELSE}
  len := addrLen;
  bytesRead := Posix.SysSocket.recvfrom(ASocket, APacket.Data.Data^, APacket.Data.Length, 0, tempAddr, len);
  if bytesRead <> DEXT_SOCKET_ERROR then
  begin
    Move(tempAddr, addr, SizeOf(addr));
  end;
  {$ENDIF}
  if bytesRead = DEXT_SOCKET_ERROR then
  begin
    error := SocketLastError;
    if IsWouldBlock(error) then
      Exit;
    raise EDextSocketError.CreateFmt('UDP recvfrom failed: %d', [error]);
  end;

  APacket.RemoteAddress := SockAddrToString(addr);
  APacket.RemotePort := ntohs(addr.sin_port);
  APacket.Data := APacket.Data.Slice(0, bytesRead);
  Result := True;
end;

function BindSocket(ASocket: TSocketHandle; const AAddr: sockaddr_in): Integer;
{$IFNDEF MSWINDOWS}
var
  tempAddr: sockaddr;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  Result := Winapi.WinSock2.bind(ASocket, PSockAddr(@AAddr)^, SizeOf(AAddr));
  {$ELSE}
  Move(AAddr, tempAddr, SizeOf(AAddr));
  Result := Posix.SysSocket.bind(ASocket, tempAddr, SizeOf(AAddr));
  {$ENDIF}
end;

function GetSocketName(ASocket: TSocketHandle; var AAddr: sockaddr_in; var AAddrLen: Integer): Integer;
{$IFNDEF MSWINDOWS}
var
  len: socklen_t;
  tempAddr: sockaddr;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  Result := Winapi.WinSock2.getsockname(ASocket, PSockAddr(@AAddr)^, AAddrLen);
  {$ELSE}
  len := AAddrLen;
  Result := Posix.SysSocket.getsockname(ASocket, tempAddr, len);
  if Result = 0 then
  begin
    Move(tempAddr, AAddr, SizeOf(AAddr));
    AAddrLen := len;
  end;
  {$ENDIF}
end;
{ TDextUdpServerThread }

constructor TDextUdpServerThread.Create(AServer: TDextUdpServer);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FServer := AServer;
end;

procedure TDextUdpServerThread.Execute;
begin
  FServer.ReceiveLoop;
end;

{ TDextUdpServer }

constructor TDextUdpServer.Create;
begin
  inherited Create;
  EnsureSocketsStarted;
  FSocket := DEXT_INVALID_SOCKET;
  FAddress := '0.0.0.0';
end;

destructor TDextUdpServer.Destroy;
begin
  Stop;
  ReleaseSockets;
  inherited;
end;

procedure TDextUdpServer.Bind(const AAddress: string; APort: Word);
var
  addr: sockaddr_in;
  addrLen: Integer;
  yes: Integer;
begin
  if FRunning then
    raise EDextSocketError.Create('UDP server is running');
  if FSocket <> DEXT_INVALID_SOCKET then
    CloseSocket;

  FAddress := AAddress;
  FSocket := CreateUdpSocket;
  yes := 1;
  {$IFDEF MSWINDOWS}
  setsockopt(FSocket, SOL_SOCKET, SO_REUSEADDR, PAnsiChar(@yes), SizeOf(yes));
  {$ELSE}
  setsockopt(FSocket, SOL_SOCKET, SO_REUSEADDR, yes, SizeOf(yes));
  {$ENDIF}

  FillChar(addr, SizeOf(addr), 0);
  addr.sin_family := AF_INET;
  addr.sin_addr.s_addr := AddressToInAddr(AAddress);
  addr.sin_port := htons(APort);

  if BindSocket(FSocket, addr) = DEXT_SOCKET_ERROR then
    raise EDextSocketError.CreateFmt('UDP bind failed: %d', [SocketLastError]);

  addrLen := SizeOf(addr);
  if GetSocketName(FSocket, addr, addrLen) = 0 then
    FPort := ntohs(addr.sin_port)
  else
    FPort := APort;
end;

procedure TDextUdpServer.CloseSocket;
begin
  CloseSocketHandle(FSocket);
end;

function TDextUdpServer.GetListenPort: Word;
begin
  Result := FPort;
end;

procedure TDextUdpServer.ReceiveLoop;
var
  buffer: array[0..DEXT_UDP_RECV_BUFFER_SIZE - 1] of Byte;
  spanPacket: TUdpSpanPacket;
  packet: TUdpPacket;
begin
  while FRunning do
  begin
    try
      spanPacket.Data := TByteSpan.Create(@buffer[0], SizeOf(buffer));
      if not ReceiveUdpSpan(FSocket, spanPacket, 250) then
        Continue;

      if Assigned(FOnPacketSpanReceived) then
        FOnPacketSpanReceived(spanPacket);

      if Assigned(FOnPacketReceived) then
      begin
        packet.RemoteAddress := spanPacket.RemoteAddress;
        packet.RemotePort := spanPacket.RemotePort;
        SetLength(packet.Data, spanPacket.Data.Length);
        Move(spanPacket.Data.Data^, packet.Data[0], spanPacket.Data.Length);
        FOnPacketReceived(packet);
      end;
    except
      on error: Exception do
      begin
        if FRunning and Assigned(FOnError) then
          FOnError(error);
      end;
    end;
  end;
end;

procedure TDextUdpServer.SendTo(const AAddress: string; APort: Word; const AData: TBytes);
var
  span: TByteSpan;
begin
  span := TByteSpan.FromBytes(AData);
  SendTo(AAddress, APort, span);
end;

procedure TDextUdpServer.SendTo(const AAddress: string; APort: Word; const AData: TByteSpan);
begin
  if FSocket = DEXT_INVALID_SOCKET then
    Bind(FAddress, FPort);
  SendUdpSpan(FSocket, AAddress, APort, AData);
end;

procedure TDextUdpServer.Start;
begin
  if FSocket = DEXT_INVALID_SOCKET then
    Bind(FAddress, FPort);
  if FRunning then
    Exit;

  FRunning := True;
  FThread := TDextUdpServerThread.Create(Self);
end;

procedure TDextUdpServer.Stop;
begin
  if not FRunning and (FSocket = DEXT_INVALID_SOCKET) then
    Exit;

  FRunning := False;
  CloseSocket;

  if FThread <> nil then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FThread.Free;
    FThread := nil;
  end;
end;

{ TDextUdpClient }

constructor TDextUdpClient.Create;
begin
  inherited Create;
  EnsureSocketsStarted;
  FSocket := CreateUdpSocket;
end;

destructor TDextUdpClient.Destroy;
begin
  CloseSocketHandle(FSocket);
  ReleaseSockets;
  inherited;
end;

function TDextUdpClient.Receive(out APacket: TUdpPacket; ATimeoutMs: Integer): Boolean;
var
  buffer: TBytes;
  spanPacket: TUdpSpanPacket;
begin
  SetLength(buffer, DEXT_UDP_RECV_BUFFER_SIZE);
  spanPacket.Data := TByteSpan.FromBytes(buffer);
  Result := Receive(spanPacket, ATimeoutMs);
  if Result then
  begin
    APacket.RemoteAddress := spanPacket.RemoteAddress;
    APacket.RemotePort := spanPacket.RemotePort;
    SetLength(APacket.Data, spanPacket.Data.Length);
    Move(spanPacket.Data.Data^, APacket.Data[0], spanPacket.Data.Length);
  end;
end;

function TDextUdpClient.Receive(var APacket: TUdpSpanPacket; ATimeoutMs: Integer): Boolean;
begin
  Result := ReceiveUdpSpan(FSocket, APacket, ATimeoutMs);
end;

procedure TDextUdpClient.Send(const AAddress: string; APort: Word; const AData: TBytes);
var
  span: TByteSpan;
begin
  span := TByteSpan.FromBytes(AData);
  Send(AAddress, APort, span);
end;

procedure TDextUdpClient.Send(const AAddress: string; APort: Word; const AData: TByteSpan);
begin
  SendUdpSpan(FSocket, AAddress, APort, AData);
end;

end.
