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
  System.Generics.Defaults,
  Dext.Server.Engine.Types,
  Dext.Server.Engine.Interfaces,
  Dext.Server.Iocp.HttpParser,
  Dext.Collections.Dict,
  Dext.Core.Span;

type
  {$IFDEF LINUX}
  TDextEpollEngine = class;

  THeaderSegment = record
    KeyStart: Integer;
    KeyLen: Integer;
    ValueStart: Integer;
    ValueLen: Integer;
  end;

  THeaderSegments = TArray<THeaderSegment>;

  TDextEpollHttpParser = record
  private
    class function FindByte(const ABuffer: TBytes; AStart, AEnd: Integer; AByte: Byte): Integer; static; inline;
    class function FindCRLF(const ABuffer: TBytes; AStart, AEnd: Integer): Integer; static; inline;
    class function CompareBytesCI(const ABuffer: TBytes; AStart, ALen: Integer; const AStr: string): Boolean; static; inline;
    class function GetMethodString(const ABuffer: TBytes; AStart, ALen: Integer): string; static; inline;
  public
    class function TryParseRequest(
      const ABuffer: TBytes; 
      ALength: Integer;
      out AMethod: string;
      out APath: string;
      out AQuery: string;
      out AHeaderSegments: THeaderSegments;
      out ABodyOffset: Integer;
      out AContentLength: Int64
    ): Boolean; static;
  end;

  TDextEpollContext = class
  public
    FFd: Integer;
    FEpollFd: Integer;
    FReadBuffer: TBytes;
    FReadLen: Integer;
    
    // Escrita pendente
    FWriteBuffer: TBytes;
    FWriteOffset: Integer;
    FWriteLen: Integer;

    FConnection: IDextTransportConnection;
    
    constructor Create(AFd: Integer; AEpollFd: Integer);
  end;

  /// <summary>
  ///   Raw connection implementation wrapper for epoll sockets.
  /// </summary>
  TDextEpollConnection = class(TInterfacedObject, IDextServerConnection, IDextTransportConnection)
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
 
    /// <summary>Sends a byte array to the client.</summary>
    procedure Send(const ABuffer: TBytes); overload;
    /// <summary>Sends a span of bytes to the client.</summary>
    procedure Send(const ASpan: TByteSpan); overload;

    /// <summary>Checks if connection upgrade is supported.</summary>
    function SupportsUpgrade: Boolean;
    /// <summary>Upgrades the active connection to WebSockets.</summary>
    function UpgradeToWebSocket: IDextWebSocketConnection;
  end;
  TDextReadOnlyBytesStream = class(TCustomMemoryStream)
  public
    constructor Create(const ABytes: TBytes; AOffset, ALen: Integer);
  end;

  /// <summary>
  ///   Raw request implementation wrapper for epoll socket connection.
  /// </summary>
  TDextEpollRequest = class(TInterfacedObject, IDextRawRequest)
  private
    FMethod: string;
    FPath: string;
    FQuery: string;
    FBodyStream: TCustomMemoryStream;
    FContentLength: Int64;
    FBuffer: TBytes;
    FHeaderSegments: THeaderSegments;
    FResolvedHeaders: TDictionary<string, string>;
    function GetMethod: string;
    function GetPath: string;
    function GetQueryString: string;
    function GetHeader(const AName: string): string;
    procedure PopulateHeaders(ADict: TDictionary<string, string>);
    function GetContentLength: Int64;
    function GetBodyStream: TStream;
    function ResolveHeader(const AName: string): string;
  public
    /// <summary>Initializes the raw epoll request wrapper.</summary>
    constructor Create(
      const AMethod, APath, AQuery: string;
      const AHeaderSegments: THeaderSegments;
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
    FContext: TDextEpollContext;
    FHeadersSent: Boolean;
    FStatusCode: Integer;
    FReason: string;
    FHeaders: TDictionary<string, string>;
    FResponseBuffer: TBytes;
    FBodyBuffer: TBytes;
    FBodyLen: Integer;
  public
    /// <summary>Initializes a new epoll response wrapper.</summary>
    /// <param name="AContext">The connection context.</param>
    constructor Create(AContext: TDextEpollContext);
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
    FListenSocket: Integer;
    FPipeFds: array[0..1] of Integer;
    FReadBuffer: TBytes;
    procedure CreateLocalReactor;
    procedure CloseLocalReactor;
    procedure ProcessRequestAsync(
      AContext: TDextEpollContext;
      const AConnection: IDextServerConnection;
      const ARequest: IDextRawRequest;
      const AResponse: IDextRawResponse
    );
  protected
    procedure Execute; override;
  public
    /// <summary>Initializes the epoll worker thread.</summary>
    /// <param name="AEngine">The epoll engine instance.</param>
    constructor Create(AEngine: TDextEpollEngine);
    /// <summary>Cleans up resources.</summary>
    destructor Destroy; override;
    /// <summary>Sinaliza encerramento imediato.</summary>
    procedure TerminateWorker;
  end;

  /// <summary>
  ///   Native Linux raw epoll socket server engine.
  /// </summary>
  TDextEpollEngine = class(TInterfacedObject, IDextServerEngine)
  private
    FOptions: TServerEngineOptions;
    FRunning: Boolean;
    FListeningPort: Word;
    FAddress: string;

    FOnConnection: TConnectionEventHandler;
    FOnDisconnection: TConnectionEventHandler;
    FOnRequest: TRequestEventHandler;
    FOnUpgrade: TUpgradeEventHandler;
    FConnectionHandler: IConnectionHandler;

    FActiveConnections: Integer;
    FTotalRequests: Int64;

    FWorkers: TList;
  public
    /// <summary>Initializes a new epoll server engine.</summary>
    /// <param name="AOptions">The engine configuration options.</param>
    constructor Create(const AOptions: TServerEngineOptions);
    procedure DecActiveConnections;
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
    /// <summary>Sets the custom connection handler.</summary>
    procedure SetConnectionHandler(const AHandler: IConnectionHandler);
  end;

  {$ELSE}

  /// <summary>
  ///   Compilation stub of TDextEpollEngine for non-Linux platforms.
  /// </summary>
  TDextEpollEngine = class(TInterfacedObject, IDextServerEngine)
  public
    /// <summary>Stub constructor.</summary>
    constructor Create(const AOptions: TServerEngineOptions);
    procedure DecActiveConnections;
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
    /// <summary>Stub SetConnectionHandler implementation.</summary>
    procedure SetConnectionHandler(const AHandler: IConnectionHandler);
  end;
  {$ENDIF}

implementation

{$IFDEF LINUX}
uses
  System.Threading,
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

  iovec = record
    iov_base: Pointer;
    iov_len: NativeUInt;
  end;
  piovec = ^iovec;

function epoll_create(size: Integer): Integer; cdecl; external libc name 'epoll_create';
function epoll_create1(flags: Integer): Integer; cdecl; external libc name 'epoll_create1';
function epoll_ctl(epfd: Integer; op: Integer; fd: Integer; event: pepoll_event): Integer; cdecl; external libc name 'epoll_ctl';
function epoll_wait(epfd: Integer; events: pepoll_event; maxevents: Integer; timeout: Integer): Integer; cdecl; external libc name 'epoll_wait';
function writev(fd: Integer; iov: piovec; iovcnt: Integer): Integer; cdecl; external libc name 'writev';

{ TDextEpollContext }
 
constructor TDextEpollContext.Create(AFd: Integer; AEpollFd: Integer);
begin
  inherited Create;
  FFd := AFd;
  FEpollFd := AEpollFd;
  FReadLen := 0;
  SetLength(FReadBuffer, 4096);
  FWriteOffset := 0;
  FWriteLen := 0;
end;
 
{ TDextEpollHttpParser }

class function TDextEpollHttpParser.FindByte(const ABuffer: TBytes; AStart, AEnd: Integer; AByte: Byte): Integer;
var
  I: Integer;
begin
  for I := AStart to AEnd - 1 do
    if ABuffer[I] = AByte then
      Exit(I);
  Result := -1;
end;

class function TDextEpollHttpParser.FindCRLF(const ABuffer: TBytes; AStart, AEnd: Integer): Integer;
var
  I: Integer;
begin
  for I := AStart to AEnd - 2 do
    if (ABuffer[I] = 13) and (ABuffer[I+1] = 10) then
      Exit(I);
  Result := -1;
end;

class function TDextEpollHttpParser.CompareBytesCI(const ABuffer: TBytes; AStart, ALen: Integer; const AStr: string): Boolean;
var
  I: Integer;
  B1, B2: Byte;
begin
  if ALen <> Length(AStr) then Exit(False);
  for I := 0 to ALen - 1 do
  begin
    B1 := ABuffer[AStart + I];
    B2 := Ord(AStr[I + 1]);
    if (B1 >= 65) and (B1 <= 90) then B1 := B1 + 32;
    if (B2 >= 65) and (B2 <= 90) then B2 := B2 + 32;
    if B1 <> B2 then Exit(False);
  end;
  Result := True;
end;

class function TDextEpollHttpParser.GetMethodString(const ABuffer: TBytes; AStart, ALen: Integer): string;
begin
  case ALen of
    3:
      if (ABuffer[AStart] = 71) and (ABuffer[AStart+1] = 69) and (ABuffer[AStart+2] = 84) then
        Exit('GET')
      else if (ABuffer[AStart] = 80) and (ABuffer[AStart+1] = 85) and (ABuffer[AStart+2] = 84) then
        Exit('PUT');
    4:
      if (ABuffer[AStart] = 80) and (ABuffer[AStart+1] = 79) and (ABuffer[AStart+2] = 83) and (ABuffer[AStart+3] = 84) then
        Exit('POST')
      else if (ABuffer[AStart] = 72) and (ABuffer[AStart+1] = 69) and (ABuffer[AStart+2] = 65) and (ABuffer[AStart+3] = 68) then
        Exit('HEAD');
    5:
      if (ABuffer[AStart] = 80) and (ABuffer[AStart+1] = 65) and (ABuffer[AStart+2] = 84) and (ABuffer[AStart+3] = 67) and (ABuffer[AStart+4] = 72) then
        Exit('PATCH');
    6:
      if (ABuffer[AStart] = 68) and (ABuffer[AStart+1] = 69) and (ABuffer[AStart+2] = 76) and (ABuffer[AStart+3] = 69) and (ABuffer[AStart+4] = 84) and (ABuffer[AStart+5] = 69) then
        Exit('DELETE');
    7:
      if (ABuffer[AStart] = 79) and (ABuffer[AStart+1] = 80) and (ABuffer[AStart+2] = 84) and (ABuffer[AStart+3] = 73) and (ABuffer[AStart+4] = 79) and (ABuffer[AStart+5] = 78) and (ABuffer[AStart+6] = 83) then
        Exit('OPTIONS');
  end;
  Result := TEncoding.UTF8.GetString(ABuffer, AStart, ALen);
end;

class function TDextEpollHttpParser.TryParseRequest(
  const ABuffer: TBytes; 
  ALength: Integer;
  out AMethod: string;
  out APath: string;
  out AQuery: string;
  out AHeaderSegments: THeaderSegments;
  out ABodyOffset: Integer;
  out AContentLength: Int64
): Boolean;
var
  HeaderEnd: Integer;
  I: Integer;
  LineStart: Integer;
  LineEnd: Integer;
  Space1: Integer;
  Space2: Integer;
  UrlEnd: Integer;
  QueryStart: Integer;
  Colon: Integer;
  Seg: THeaderSegment;
  SegCount: Integer;
  PathStart, PathLen: Integer;
begin
  AMethod := '';
  APath := '';
  AQuery := '';
  ABodyOffset := -1;
  AContentLength := 0;
  SetLength(AHeaderSegments, 0);

  HeaderEnd := -1;
  for I := 0 to ALength - 4 do
  begin
    if (ABuffer[I] = 13) and (ABuffer[I+1] = 10) and (ABuffer[I+2] = 13) and (ABuffer[I+3] = 10) then
    begin
      HeaderEnd := I;
      Break;
    end;
  end;

  if HeaderEnd = -1 then Exit(False);

  LineEnd := FindCRLF(ABuffer, 0, HeaderEnd);
  if LineEnd = -1 then Exit(False);

  Space1 := FindByte(ABuffer, 0, LineEnd, 32);
  if Space1 = -1 then Exit(False);

  Space2 := FindByte(ABuffer, Space1 + 1, LineEnd, 32);
  if Space2 = -1 then Exit(False);

  // Method (cached)
  AMethod := GetMethodString(ABuffer, 0, Space1);

  UrlEnd := Space2;
  QueryStart := FindByte(ABuffer, Space1 + 1, Space2, 63);
  
  PathStart := Space1 + 1;
  if QueryStart <> -1 then
    PathLen := QueryStart - PathStart
  else
    PathLen := Space2 - PathStart;

  // Path raiz otimizado
  if (PathLen = 1) and (ABuffer[PathStart] = 47) then
    APath := '/'
  else
    APath := TEncoding.UTF8.GetString(ABuffer, PathStart, PathLen);

  if QueryStart <> -1 then
    AQuery := TEncoding.UTF8.GetString(ABuffer, QueryStart, Space2 - QueryStart)
  else
    AQuery := '';

  SegCount := 0;
  SetLength(AHeaderSegments, 16);

  LineStart := LineEnd + 2;
  while LineStart < HeaderEnd do
  begin
    LineEnd := FindCRLF(ABuffer, LineStart, HeaderEnd);
    if LineEnd = -1 then LineEnd := HeaderEnd;

    if LineEnd > LineStart then
    begin
      Colon := FindByte(ABuffer, LineStart, LineEnd, 58);
      if Colon <> -1 then
      begin
        Seg.KeyStart := LineStart;
        Seg.KeyLen := Colon - LineStart;
        Seg.ValueStart := Colon + 1;
        Seg.ValueLen := LineEnd - (Colon + 1);

        while (Seg.ValueLen > 0) and (ABuffer[Seg.ValueStart] = 32) do
        begin
          Inc(Seg.ValueStart);
          Dec(Seg.ValueLen);
        end;

        if SegCount >= Length(AHeaderSegments) then
          SetLength(AHeaderSegments, SegCount + 8);

        AHeaderSegments[SegCount] := Seg;
        Inc(SegCount);

        if CompareBytesCI(ABuffer, Seg.KeyStart, Seg.KeyLen, 'content-length') then
        begin
          AContentLength := 0;
          for I := 0 to Seg.ValueLen - 1 do
          begin
            if (ABuffer[Seg.ValueStart + I] >= 48) and (ABuffer[Seg.ValueStart + I] <= 57) then
              AContentLength := AContentLength * 10 + (ABuffer[Seg.ValueStart + I] - 48);
          end;
        end;
      end;
    end;

    LineStart := LineEnd + 2;
  end;

  SetLength(AHeaderSegments, SegCount);
  ABodyOffset := HeaderEnd + 4;
  Result := True;
end;


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

procedure TDextEpollConnection.Send(const ABuffer: TBytes);
begin
  if Length(ABuffer) > 0 then
    Posix.SysSocket.send(FSocket, ABuffer[0], Length(ABuffer), 0);
end;

procedure TDextEpollConnection.Send(const ASpan: TByteSpan);
begin
  if ASpan.Length > 0 then
    Posix.SysSocket.send(FSocket, ASpan.Data^, ASpan.Length, 0);
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

{ TDextReadOnlyBytesStream }

constructor TDextReadOnlyBytesStream.Create(const ABytes: TBytes; AOffset, ALen: Integer);
begin
  inherited Create;
  if ALen > 0 then
    SetPointer(@ABytes[AOffset], ALen)
  else
    SetPointer(nil, 0);
end;

{ TDextEpollRequest }

constructor TDextEpollRequest.Create(
  const AMethod, APath, AQuery: string;
  const AHeaderSegments: THeaderSegments;
  ABody: TBytes;
  ABodyOffset, ABodyLen: Integer;
  AContentLength: Int64
);
begin
  inherited Create;
  FMethod := AMethod;
  FPath := APath;
  FQuery := AQuery;
  FHeaderSegments := AHeaderSegments;
  FContentLength := AContentLength;

  // Cópia restrita aos bytes úteis do request para thread-safety no reactor desacoplado
  FBuffer := Copy(ABody, 0, ABodyOffset + ABodyLen);

  FResolvedHeaders := TDictionary<string, string>.Create(True, False, 0);

  // Stream que lê diretamente do buffer sem cópia adicional
  FBodyStream := TDextReadOnlyBytesStream.Create(FBuffer, ABodyOffset, ABodyLen);
end;

destructor TDextEpollRequest.Destroy;
begin
  FResolvedHeaders.Free;
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

function TDextEpollRequest.ResolveHeader(const AName: string): string;
var
  I: Integer;
  Seg: THeaderSegment;
begin
  if FResolvedHeaders.TryGetValue(AName, Result) then Exit;

  for I := 0 to Length(FHeaderSegments) - 1 do
  begin
    Seg := FHeaderSegments[I];
    if TDextEpollHttpParser.CompareBytesCI(FBuffer, Seg.KeyStart, Seg.KeyLen, AName) then
    begin
      Result := TEncoding.UTF8.GetString(FBuffer, Seg.ValueStart, Seg.ValueLen).Trim;
      FResolvedHeaders.Add(AName, Result);
      Exit;
    end;
  end;

  // Cacheia cabeçalhos não encontrados
  Result := '';
  FResolvedHeaders.Add(AName, '');
end;

function TDextEpollRequest.GetHeader(const AName: string): string;
begin
  Result := ResolveHeader(AName);
end;

procedure TDextEpollRequest.PopulateHeaders(ADict: TDictionary<string, string>);
var
  I: Integer;
  Seg: THeaderSegment;
  Key, Value: string;
begin
  for I := 0 to Length(FHeaderSegments) - 1 do
  begin
    Seg := FHeaderSegments[I];
    Key := TEncoding.UTF8.GetString(FBuffer, Seg.KeyStart, Seg.KeyLen).Trim.ToLower;
    Value := ResolveHeader(Key);
    ADict.AddOrSetValue(Key, Value);
  end;
end;

// Interface redirects
function TDextEpollRequest.GetMethod: string; begin Result := FMethod; end;
function TDextEpollRequest.GetPath: string; begin Result := FPath; end;
function TDextEpollRequest.GetQueryString: string; begin Result := FQuery; end;

{ TDextEpollResponse }

constructor TDextEpollResponse.Create(AContext: TDextEpollContext);
begin
  inherited Create;
  FContext := AContext;
  FSocket := AContext.FFd;
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
var
  Iov: array[0..1] of iovec;
  IovCnt: Integer;
  Res: Integer;
  TotalBytes: Integer;
  RemainderLen: Integer;
  DestPos: Integer;
  HeaderRem: Integer;
  BodySent: Integer;
  BodyRem: Integer;
  Event: epoll_event;
begin
  if not FHeadersSent then
    SendHeaders;

  IovCnt := 0;
  TotalBytes := 0;
  if Length(FResponseBuffer) > 0 then
  begin
    Iov[IovCnt].iov_base := @FResponseBuffer[0];
    Iov[IovCnt].iov_len := Length(FResponseBuffer);
    TotalBytes := TotalBytes + Length(FResponseBuffer);
    Inc(IovCnt);
  end;

  if FBodyLen > 0 then
  begin
    Iov[IovCnt].iov_base := @FBodyBuffer[0];
    Iov[IovCnt].iov_len := FBodyLen;
    TotalBytes := TotalBytes + FBodyLen;
    Inc(IovCnt);
  end;

  if IovCnt > 0 then
  begin
    Res := writev(FSocket, @Iov[0], IovCnt);
    if Res < 0 then
    begin
      if (errno = EAGAIN) or (errno = EWOULDBLOCK) then
        Res := 0
      else
        Res := -1;
    end;

    if (Res >= 0) and (Res < TotalBytes) then
    begin
      RemainderLen := TotalBytes - Res;
      SetLength(FContext.FWriteBuffer, RemainderLen);
      DestPos := 0;

      if Res < Length(FResponseBuffer) then
      begin
        HeaderRem := Length(FResponseBuffer) - Res;
        Move(FResponseBuffer[Res], FContext.FWriteBuffer[DestPos], HeaderRem);
        Inc(DestPos, HeaderRem);
        if FBodyLen > 0 then
          Move(FBodyBuffer[0], FContext.FWriteBuffer[DestPos], FBodyLen);
      end
      else
      begin
        BodySent := Res - Length(FResponseBuffer);
        BodyRem := FBodyLen - BodySent;
        if BodyRem > 0 then
          Move(FBodyBuffer[BodySent], FContext.FWriteBuffer[DestPos], BodyRem);
      end;

      FContext.FWriteOffset := 0;
      FContext.FWriteLen := RemainderLen;

      FillChar(Event, SizeOf(Event), 0);
      Event.events := EPOLLOUT or EPOLLET or EPOLLONESHOT;
      Event.data.ptr := FContext;
      epoll_ctl(FContext.FEpollFd, EPOLL_CTL_MOD, FSocket, @Event);
    end;

    SetLength(FResponseBuffer, 0);
    FBodyLen := 0;
    SetLength(FBodyBuffer, 0);
  end;
end;

procedure TDextEpollResponse.SendHeaders;
var
  SB: TStringBuilder;
  Pair: TPair<string, string>;
begin
  if FHeadersSent then Exit;

  SB := TStringBuilder.Create;
  try
    SB.Append('HTTP/1.1 ').Append(FStatusCode).Append(' ').Append(FReason).Append(#13#10);
    
    if not FHeaders.ContainsKey('Content-Type') then
      FHeaders.Add('Content-Type', 'text/plain');

    for Pair in FHeaders do
      SB.Append(Pair.Key).Append(': ').Append(Pair.Value).Append(#13#10);

    SB.Append(#13#10);
    FResponseBuffer := TEncoding.UTF8.GetBytes(SB.ToString);
  finally
    SB.Free;
  end;
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
var
  NewLen: Integer;
begin
  if ACount <= 0 then Exit;

  NewLen := FBodyLen + ACount;
  if Length(FBodyBuffer) < NewLen then
    SetLength(FBodyBuffer, NewLen);

  Move(ABuffer[AOffset], FBodyBuffer[FBodyLen], ACount);
  FBodyLen := NewLen;
end;

{ TDextEpollWorker }

constructor TDextEpollWorker.Create(AEngine: TDextEpollEngine);
begin
  inherited Create(True);
  FEngine := AEngine;
  FEpollFd := -1;
  FListenSocket := -1;
  FPipeFds[0] := -1;
  FPipeFds[1] := -1;
  FreeOnTerminate := False;
  SetLength(FReadBuffer, 8192);
end;

destructor TDextEpollWorker.Destroy;
begin
  CloseLocalReactor;
  inherited;
end;

procedure TDextEpollWorker.TerminateWorker;
var
  B: Byte;
begin
  Terminate;
  if FPipeFds[1] >= 0 then
  begin
    B := 1;
    __write(FPipeFds[1], @B, 1);
  end;
end;

procedure TDextEpollWorker.CreateLocalReactor;
var
  Addr: sockaddr_in;
  Event: epoll_event;
  OptVal: Integer;
begin
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

  // Enable SO_REUSEPORT (value 15 on Linux)
  OptVal := 1;
  setsockopt(FListenSocket, SOL_SOCKET, 15, OptVal, SizeOf(OptVal));

  fcntl(FListenSocket, F_SETFL, O_NONBLOCK);

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(FEngine.FListeningPort);
  if (FEngine.FAddress = '') or (FEngine.FAddress = '0.0.0.0') then
    Addr.sin_addr.s_addr := INADDR_ANY
  else
    Addr.sin_addr.s_addr := inet_addr(PAnsiChar(AnsiString(FEngine.FAddress)));

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
end;

procedure TDextEpollWorker.CloseLocalReactor;
begin
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

procedure TDextEpollWorker.ProcessRequestAsync(
  AContext: TDextEpollContext;
  const AConnection: IDextServerConnection;
  const ARequest: IDextRawRequest;
  const AResponse: IDextRawResponse
);
var
  LLocalEpollFd: Integer;
begin
  LLocalEpollFd := FEpollFd;
  TTask.Run(
    procedure
    var
      LConnection: IDextServerConnection;
      LRequest: IDextRawRequest;
      LResponse: IDextRawResponse;
      LContext: TDextEpollContext;
      LFd: Integer;
      HasPendingWrite: Boolean;
      LLocalEvent: epoll_event;
    begin
      LConnection := AConnection;
      LRequest := ARequest;
      LResponse := AResponse;
      LContext := AContext;
      LFd := LContext.FFd;
      try
        try
          if Assigned(FEngine.FOnRequest) then
            FEngine.FOnRequest(LConnection, LRequest, LResponse);
        finally
          LResponse.Close;
        end;
      finally
        HasPendingWrite := False;
        if LContext <> nil then
        begin
          if LContext.FWriteLen > 0 then
            HasPendingWrite := True;
        end;

        if not HasPendingWrite then
        begin
          shutdown(LFd, 1);
          if LContext <> nil then
          begin
            FillChar(LLocalEvent, SizeOf(LLocalEvent), 0);
            LLocalEvent.events := EPOLLIN or EPOLLET or EPOLLONESHOT;
            LLocalEvent.data.ptr := LContext;
            epoll_ctl(LLocalEpollFd, EPOLL_CTL_MOD, LFd, @LLocalEvent);
          end;
        end;
        LResponse := nil;
        LRequest := nil;
        LConnection := nil;
      end;
    end
  );
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
  RecvRet: Integer;
  Method, Path, Query: string;
  HeaderSegments: THeaderSegments;
  BodyOffset: Integer;
  ContentLength: Int64;
  Connection: IDextServerConnection;
  RawRequest: IDextRawRequest;
  RawResponse: IDextRawResponse;
  Context: TDextEpollContext;
  ReadFailedOrClosed: Boolean;
  SentBytes: Integer;
begin
  try
    CreateLocalReactor;
  except
    Exit;
  end;

  try
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

        if Fd = FListenSocket then
        begin
          // Accept loop
          while True do
          begin
            AddrLen := SizeOf(Addr);
            ClientFd := accept(FListenSocket, Psockaddr(@Addr)^, AddrLen);
            if ClientFd < 0 then
            begin
              if (errno = EAGAIN) or (errno = EWOULDBLOCK) then
                Break;
              Break;
            end;

            // Non-blocking
            fcntl(ClientFd, F_SETFL, O_NONBLOCK);

            // Cria o contexto da conexão
            Context := TDextEpollContext.Create(ClientFd, FEpollFd);

            if Assigned(FEngine.FConnectionHandler) then
            begin
              Context.FConnection := TDextEpollConnection.Create(ClientFd);
              try
                FEngine.FConnectionHandler.OnConnect(Context.FConnection);
              except
                on E: Exception do
                  FEngine.FConnectionHandler.OnError(Context.FConnection, E);
              end;
            end;

            // Edge Triggered + One Shot
            Event.events := EPOLLIN or EPOLLET or EPOLLONESHOT;
            Event.data.ptr := Context;
            epoll_ctl(FEpollFd, EPOLL_CTL_ADD, ClientFd, @Event);

            TInterlocked.Increment(FEngine.FActiveConnections);
          end;
        end
        else if Fd = FPipeFds[0] then
        begin
          // Exit signal
          Exit;
        end
        else
        begin
          Context := TDextEpollContext(Event.data.ptr);

          if (Event.events and EPOLLOUT) <> 0 then
          begin
            // Pronto para escrita! Terminar de enviar dados parciais.
            SentBytes := send(Context.FFd, Context.FWriteBuffer[Context.FWriteOffset], Context.FWriteLen, 0);
            if SentBytes > 0 then
            begin
              Context.FWriteOffset := Context.FWriteOffset + SentBytes;
              Context.FWriteLen := Context.FWriteLen - SentBytes;

              if Context.FWriteLen = 0 then
              begin
                // Escrita concluída com sucesso! Agora podemos fechar.
                __close(Context.FFd);
                Context.Free;
                TInterlocked.Decrement(FEngine.FActiveConnections);
                Continue;
              end;
            end
            else if (SentBytes < 0) and ((errno = EAGAIN) or (errno = EWOULDBLOCK)) then
            begin
              // Bloqueado novamente.
            end
            else
            begin
              // Erro ou desconexão.
              __close(Context.FFd);
              Context.Free;
              TInterlocked.Decrement(FEngine.FActiveConnections);
              Continue;
            end;

            // Se ainda tem dados a enviar, rearmamos em modo EPOLLOUT
            FillChar(Event, SizeOf(Event), 0);
            Event.events := EPOLLOUT or EPOLLET or EPOLLONESHOT;
            Event.data.ptr := Context;
            epoll_ctl(FEpollFd, EPOLL_CTL_MOD, Context.FFd, @Event);
            Continue;
          end;

          // Evento de Leitura (EPOLLIN)
          if Assigned(FEngine.FConnectionHandler) then
          begin
            ReadFailedOrClosed := False;
            while True do
            begin
              RecvRet := recv(Context.FFd, Context.FReadBuffer[0], Length(Context.FReadBuffer), 0);
              if RecvRet > 0 then
              begin
                try
                  FEngine.FConnectionHandler.OnData(Context.FConnection, TByteSpan.Create(@Context.FReadBuffer[0], RecvRet));
                except
                  on E: Exception do
                    FEngine.FConnectionHandler.OnError(Context.FConnection, E);
                end;
              end
              else if RecvRet = 0 then
              begin
                ReadFailedOrClosed := True;
                Break;
              end
              else
              begin
                if (errno = EAGAIN) or (errno = EWOULDBLOCK) then
                  Break;
                ReadFailedOrClosed := True;
                Break;
              end;
            end;

            if ReadFailedOrClosed then
            begin
              if Context.FConnection <> nil then
              begin
                try
                  FEngine.FConnectionHandler.OnDisconnect(Context.FConnection);
                except
                end;
              end;
              __close(Context.FFd);
              Context.Free;
              TInterlocked.Decrement(FEngine.FActiveConnections);
              Continue;
            end;

            // Se incompleto, rearma no Epoll para leitura
            FillChar(Event, SizeOf(Event), 0);
            Event.events := EPOLLIN or EPOLLET or EPOLLONESHOT;
            Event.data.ptr := Context;
            epoll_ctl(FEpollFd, EPOLL_CTL_MOD, Context.FFd, @Event);
            Continue;
          end;

          ReadFailedOrClosed := False;
          while True do
          begin
            if Context.FReadLen + 4096 > Length(Context.FReadBuffer) then
              SetLength(Context.FReadBuffer, Length(Context.FReadBuffer) + 4096);

            RecvRet := recv(Context.FFd, Context.FReadBuffer[Context.FReadLen], 4096, 0);
            if RecvRet > 0 then
            begin
              Context.FReadLen := Context.FReadLen + RecvRet;
            end
            else if RecvRet = 0 then
            begin
              ReadFailedOrClosed := True;
              Break;
            end
            else
            begin
              if (errno = EAGAIN) or (errno = EWOULDBLOCK) then
                Break;
              ReadFailedOrClosed := True;
              Break;
            end;
          end;

          if ReadFailedOrClosed then
          begin
            __close(Context.FFd);
            Context.Free;
            TInterlocked.Decrement(FEngine.FActiveConnections);
            Continue;
          end;

          if Context.FReadLen > 0 then
          begin
            if TDextEpollHttpParser.TryParseRequest(
              Context.FReadBuffer,
              Context.FReadLen,
              Method,
              Path,
              Query,
              HeaderSegments,
              BodyOffset,
              ContentLength
            ) then
            begin
              TInterlocked.Increment(FEngine.FTotalRequests);

              Connection := TDextEpollConnection.Create(Context.FFd);
              RawRequest := TDextEpollRequest.Create(Method, Path, Query, HeaderSegments, Context.FReadBuffer, BodyOffset, Context.FReadLen - BodyOffset, ContentLength);
              RawResponse := TDextEpollResponse.Create(Context);

              ProcessRequestAsync(Context, Connection, RawRequest, RawResponse);

              Connection := nil;
              RawRequest := nil;
              RawResponse := nil;
              Continue;
            end;

            // Proteção contra tamanho excessivo de cabeçalho
            if Context.FReadLen >= 8192 then
            begin
              __close(Context.FFd);
              Context.Free;
              TInterlocked.Decrement(FEngine.FActiveConnections);
              Continue;
            end;
          end;

          // Se incompleto, rearma no Epoll para leitura
          FillChar(Event, SizeOf(Event), 0);
          Event.events := EPOLLIN or EPOLLET or EPOLLONESHOT;
          Event.data.ptr := Context;
          epoll_ctl(FEpollFd, EPOLL_CTL_MOD, Context.FFd, @Event);
        end;
      end;
    end;
  finally
    CloseLocalReactor;
  end;
end;


{ TDextEpollEngine }

procedure TDextEpollEngine.DecActiveConnections;
begin
  TInterlocked.Decrement(FActiveConnections);
end;

constructor TDextEpollEngine.Create(const AOptions: TServerEngineOptions);
begin
  inherited Create;
  FOptions := AOptions;
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
  I: Integer;
  ThreadCount: Integer;
  Worker: TDextEpollWorker;
begin
  if FRunning then Exit;

  FRunning := True;

  ThreadCount := FOptions.IoThreadCount;
  if ThreadCount <= 0 then
    ThreadCount := CPUCount;

  for I := 1 to ThreadCount do
  begin
    Worker := TDextEpollWorker.Create(Self);
    FWorkers.Add(Worker);
    Worker.Start;
  end;
end;

procedure TDextEpollEngine.Stop(AGracefulTimeoutMs: Integer);
var
  I: Integer;
  Worker: TDextEpollWorker;
begin
  if not FRunning then Exit;

  FRunning := False;

  for I := 0 to FWorkers.Count - 1 do
  begin
    Worker := TDextEpollWorker(FWorkers[I]);
    Worker.TerminateWorker;
  end;

  for I := 0 to FWorkers.Count - 1 do
  begin
    Worker := TDextEpollWorker(FWorkers[I]);
    Worker.WaitFor;
    Worker.Free;
  end;
  FWorkers.Clear;
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

procedure TDextEpollEngine.SetConnectionHandler(const AHandler: IConnectionHandler);
begin
  FConnectionHandler := AHandler;
end;

{$ELSE}

{ TDextEpollEngine - Stub }

procedure TDextEpollEngine.DecActiveConnections;
begin
end;

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

procedure TDextEpollEngine.SetConnectionHandler(const AHandler: IConnectionHandler);
begin
end;
{$ENDIF}

end.
