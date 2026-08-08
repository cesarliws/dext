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
  System.Generics.Defaults,
  System.Math,
  System.SyncObjs,
  System.SysUtils,
  System.Types,
  Dext.Collections.Dict,
  Dext.Core.Span,
  Dext.Server.BoundedExecutor,
  Dext.Server.Engine.Interfaces,
  Dext.Server.Engine.Types,
  Dext.Server.Iocp.HttpParser,
  Dext.Net.Security,
  Dext.Net.Security.OpenSSL,
  Dext.Web.ResponseWriter;

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
    class function ExtractSliceString(const ABuffer: TBytes; AStart, ALen: Integer): string; static; inline;
  public
    class function TryParseRequest(
      const ABuffer: TBytes; 
      ALength: Integer;
      out AMethod: string;
      out APathOffset: Integer;
      out APathLength: Integer;
      out AQueryOffset: Integer;
      out AQueryLength: Integer;
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
    FGeneration: Cardinal;
    
    // Segmented write cursor
    FWriteSegments: TArray<TDextBufferSegment>;
    FWriteSegIndex: Integer;
    FWriteSegOffset: Integer;
    FWriteSegmentsCount: Integer;

    // Sendfile zero-copy
    FSendFileFd: Integer;
    FSendFileOffset: Int64;
    FSendFileLen: Int64;

    // Keep-alive activity
    FLastActive: Int64;

    FConnection: IDextTransportConnection;
    FEngine: TObject; // Ref to TDextEpollEngine
    FWakeupTime: Int64;
    FQueueStartTime: Int64;
    FHandlerEndTime: Int64;
    FKeepAlive: Boolean;
    FConsumedBytes: Integer;
    FTLS: IDextTLSEngine;
    FTLSNetworkBuffer: TBytes;
    FTLSOutputBuffer: TBytes;
    FTLSOutputStart: Integer;
    FTLSOutputEnd: Integer;
    FTLSHandshakeComplete: Boolean;
    procedure InitializeTLS(const AProvider: IDextTLSContextProvider);
    function FeedTLS(const ABuffer: Pointer; ACount: Integer): Integer;
    procedure DrainTLSOutput;
    procedure FlushTLSOutput;
    
    constructor Create(AFd: Integer; AEpollFd: Integer);
  end;

  TDextEpollTask = class
  public
    Context: TDextEpollContext;
    Generation: Cardinal;
    Connection: IDextServerConnection;
    Request: IDextRawRequest;
    Response: IDextRawResponse;
    OnRequest: TRequestEventHandler;
    Worker: TObject; // Ref to TDextEpollWorker
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
    FPathOffset: Integer;
    FPathLength: Integer;
    FQueryOffset: Integer;
    FQueryLength: Integer;
    FBodyStream: TCustomMemoryStream;
    FContentLength: Int64;
    FBuffer: TBytes;
    FHeaderSegments: THeaderSegments;
    FResolvedHeaders: TDictionary<string, string>;
    FHeaderCacheKeys: array[0..7] of string;
    FHeaderCacheValues: array[0..7] of string;
    FHeaderCacheCount: Integer;
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
      const AMethod: string;
      const AHeaderSegments: THeaderSegments;
      ABody: TBytes;
      ABodyOffset, ABodyLen: Integer;
      AContentLength: Int64;
      APathOffset, APathLength, AQueryOffset, AQueryLength: Integer
    );
    /// <summary>Cleans up the request resources.</summary>
    destructor Destroy; override;
  end;
 
  /// <summary>
  ///   Raw response implementation wrapper for epoll socket connection.
  /// </summary>
  TDextEpollResponse = class(TInterfacedObject, IDextRawResponse,
    IDextRawResponseSink)
  private
    FSocket: Integer;
    FContext: TDextEpollContext;
    FGeneration: Cardinal;
    FResponseWriter: TDextResponseWriter;
    FHeadersSent: Boolean;
    FStatusCode: Integer;
    FReason: string;
    FHeaders: TDictionary<string, string>;
    FSendFileFd: Integer;
    FSendFileOffset: Int64;
    FSendFileLen: Int64;
    // Separate buffer for HTTP response headers (must precede body on wire).
    // Never written to FResponseWriter to guarantee correct send order.
    FHeaderBuf: TBytes;
    FHeaderLen: Integer;
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
    /// <summary>Writes a raw byte span into response-owned segments.</summary>
    procedure WriteBytes(AData: Pointer; ALength: Integer);
    /// <summary>Writes a file directly to the response socket using zero-copy transmission.</summary>
    /// <param name="APath">The path to the file to serve.</param>
    /// <param name="AOffset">The byte offset from where to start reading the file.</param>
    /// <param name="ACount">The number of bytes to send. If <= 0, serves until the end of the file.</param>
    procedure WriteFile(const APath: string; AOffset, ACount: Int64);
    /// <summary>Flushes any buffered response data to the network.</summary>
    procedure Flush;
    /// <summary>Closes the response stream and connection.</summary>
    procedure Close;
  end;

  TDextEpollCompletion = record
    Context: TDextEpollContext;
    Generation: Cardinal;
    Response: IDextRawResponse;
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
    FCoreId: Integer;
    FContextPool: TList;
    FActiveContexts: TList;
    FLastSweepTick: Int64;
    FCompletionLock: TObject;
    FCompletions: TArray<TDextEpollCompletion>;
    FCompletionHead: Integer;
    FCompletionTail: Integer;
    FCompletionCount: Integer;
    FTaskPool: TList;
    FWorkerTotalQueueDelayTicks: Int64;
    FWorkerTotalHandlerTicks: Int64;
    FWorkerTotalReadParseTicks: Int64;
    FWorkerTotalSendTicks: Int64;
    FWorkerTotalSweepTicks: Int64;
    FWorkerSweepCount: Int64;
    FWorkerRequestCount: Int64;
    procedure RecycleTask(ATask: TDextEpollTask);
    function AcquireTask: TDextEpollTask;
    procedure ProcessBuffer(AContext: TDextEpollContext);
    procedure CreateLocalReactor;
    procedure CloseLocalReactor;
    procedure ReleaseContext(AContext: TDextEpollContext);
    procedure EnqueueCompletion(AContext: TDextEpollContext;
      AGeneration: Cardinal; const AResponse: IDextRawResponse);
    procedure DrainCompletions;
    procedure ProcessRequestAsync(
      AContext: TDextEpollContext;
      AConnection: IDextServerConnection;
      ARequest: IDextRawRequest;
      AResponse: IDextRawResponse
    );
  protected
    procedure Execute; override;
  public
    /// <summary>Initializes the epoll worker thread.</summary>
    /// <param name="AEngine">The epoll engine instance.</param>
    /// <param name="ACoreId">The CPU core ID to pin the thread to.</param>
    constructor Create(AEngine: TDextEpollEngine; ACoreId: Integer);
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
    FExecutor: TDextBoundedExecutor;
    FProfileEnabled: Boolean;
    FTotalQueueDelayTicks: Int64;
    FTotalHandlerTicks: Int64;
    FTotalReadParseTicks: Int64;
    FTotalSendTicks: Int64;
    FTotalSweepTicks: Int64;
    FSweepCount: Int64;
    FProfiledRequestCount: Int64;
    FTLSProvider: IDextTLSContextProvider;
  protected
    procedure ReportMetrics(const AContext: TDextEpollContext);
  public
    property Executor: TDextBoundedExecutor read FExecutor;

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
  System.Diagnostics,
  Dext.Resilience,
  Posix.Base,
  Posix.SysTypes,
  Posix.SysSocket,
  Posix.SysStat,
  Posix.Unistd,
  Posix.Fcntl,
  Posix.ArpaInet,
  Posix.NetinetIn,
  Posix.Errno,
  Posix.Dlfcn,
  Posix.Pthread;

const
  TCP_NODELAY  = 1;
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

  TCP_DEFER_ACCEPT = 9;
  TCP_FASTOPEN     = 23;
  TCP_KEEPIDLE     = 4;
  TCP_KEEPINTVL    = 5;
  TCP_KEEPCNT      = 6;

type
  cpu_set_t = record
    __bits: array[0..15] of NativeUInt;
  end;
  pcpu_set_t = ^cpu_set_t;

  TFnPthreadSetAffinity = function(
    thread: NativeUInt;
    cpusetsize: NativeUInt;
    cpuset: pcpu_set_t): Integer; cdecl;

function sendfile(out_fd: Integer; in_fd: Integer; offset: PInt64; count: NativeUInt): NativeInt; cdecl; external libc name 'sendfile';

procedure CPU_ZERO(var cpuset: cpu_set_t); inline;
begin
  FillChar(cpuset, SizeOf(cpuset), 0);
end;

procedure CPU_SET(cpu: Integer; var cpuset: cpu_set_t); inline;
begin
  cpuset.__bits[cpu div (SizeOf(NativeUInt) * 8)] :=
    cpuset.__bits[cpu div (SizeOf(NativeUInt) * 8)] or
    (NativeUInt(1) shl (cpu mod (SizeOf(NativeUInt) * 8)));
end;

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
  FGeneration := 1;
  FWriteSegments := nil;
  FWriteSegIndex := 0;
  FWriteSegOffset := 0;
  FWriteSegmentsCount := 0;
  FTLS := nil;
  SetLength(FTLSNetworkBuffer, 16 * 1024);
  FTLSOutputBuffer := nil;
  FTLSOutputStart := 0;
  FTLSOutputEnd := 0;
  FTLSHandshakeComplete := False;
  FSendFileFd := -1;
  FSendFileOffset := 0;
  FSendFileLen := 0;
  FLastActive := GetTickCount64;
end;

procedure TDextEpollContext.InitializeTLS(
  const AProvider: IDextTLSContextProvider);
begin
  if AProvider = nil then
    raise EInvalidOperation.Create('TLS provider is not configured for epoll');
  FTLS := AProvider.CreateEngine(tlsmServer);
  if FTLS = nil then
    raise EInvalidOperation.Create('TLS provider returned no epoll engine');
  FTLSHandshakeComplete := False;
end;

procedure TDextEpollContext.DrainTLSOutput;
var
  Temp: array[0..8191] of Byte;
  Written, OldLength: Integer;
begin
  if FTLS = nil then Exit;
  repeat
    Written := FTLS.EncryptedOutgoing(@Temp[0], Length(Temp));
    if Written <= 0 then Break;

    OldLength := FTLSOutputEnd - FTLSOutputStart;
    if (FTLSOutputStart > 0) and (OldLength > 0) then
      Move(FTLSOutputBuffer[FTLSOutputStart], FTLSOutputBuffer[0], OldLength);
    FTLSOutputStart := 0;
    FTLSOutputEnd := OldLength;
    SetLength(FTLSOutputBuffer, FTLSOutputEnd + Written);
    Move(Temp[0], FTLSOutputBuffer[FTLSOutputEnd], Written);
    Inc(FTLSOutputEnd, Written);
  until Written < Length(Temp);
end;

procedure TDextEpollContext.FlushTLSOutput;
var
  SentBytes: Integer;
begin
  while (FTLSOutputEnd > FTLSOutputStart) and (FFd >= 0) do
  begin
    SentBytes := Posix.SysSocket.send(FFd, FTLSOutputBuffer[FTLSOutputStart],
      FTLSOutputEnd - FTLSOutputStart, 0);
    if SentBytes > 0 then
      Inc(FTLSOutputStart, SentBytes)
    else
      Break;
  end;
  if FTLSOutputStart = FTLSOutputEnd then
  begin
    FTLSOutputBuffer := nil;
    FTLSOutputStart := 0;
    FTLSOutputEnd := 0;
  end;
end;

function TDextEpollContext.FeedTLS(const ABuffer: Pointer;
  ACount: Integer): Integer;
var
  Status: TDextTLSEngineStatus;
  ReadCount, Total: Integer;
begin
  Result := 0;
  if (FTLS = nil) or (ACount <= 0) then Exit;
  Result := FTLS.EncryptedIncoming(ABuffer, ACount);
  if Result < 0 then Exit;
  Status := FTLS.DoHandshake;
  DrainTLSOutput;
  FlushTLSOutput;
  if Status = tlsError then Exit(-1);
  FTLSHandshakeComplete := FTLS.IsHandshakeCompleted;
  if not FTLSHandshakeComplete then Exit;
  Total := 0;
  repeat
    if FReadLen >= Length(FReadBuffer) then
      SetLength(FReadBuffer, Length(FReadBuffer) * 2);
    ReadCount := FTLS.PlaintextRead(@FReadBuffer[FReadLen],
      Length(FReadBuffer) - FReadLen);
    if ReadCount > 0 then
      Inc(FReadLen, ReadCount);
    Inc(Total, Max(0, ReadCount));
  until ReadCount <= 0;
  Result := Total;
end;
 
{ TDextEpollHttpParser }

class function TDextEpollHttpParser.FindByte(const ABuffer: TBytes; AStart, AEnd: Integer; AByte: Byte): Integer;
begin
  Result := TDextHttpParserCommon.FindByte(ABuffer, AStart, AEnd, AByte);
end;

class function TDextEpollHttpParser.FindCRLF(const ABuffer: TBytes; AStart, AEnd: Integer): Integer;
begin
  Result := TDextHttpParserCommon.FindCRLF(ABuffer, AStart, AEnd);
end;

class function TDextEpollHttpParser.CompareBytesCI(const ABuffer: TBytes; AStart, ALen: Integer; const AStr: string): Boolean;
begin
  Result := TDextHttpParserCommon.CompareBytesCI(ABuffer, AStart, ALen, AStr);
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

class function TDextEpollHttpParser.ExtractSliceString(const ABuffer: TBytes; AStart, ALen: Integer): string;
begin
  if (AStart < 0) or (ALen <= 0) then
    Exit('');
  Result := TEncoding.UTF8.GetString(ABuffer, AStart, ALen);
end;

class function TDextEpollHttpParser.TryParseRequest(
  const ABuffer: TBytes; 
  ALength: Integer;
  out AMethod: string;
  out APathOffset: Integer;
  out APathLength: Integer;
  out AQueryOffset: Integer;
  out AQueryLength: Integer;
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
  QueryStart: Integer;
  Colon: Integer;
  Seg: THeaderSegment;
  SegCount: Integer;
  PathStart, PathLen: Integer;
begin
  AMethod := '';
  APathOffset := -1;
  APathLength := 0;
  AQueryOffset := -1;
  AQueryLength := 0;
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

  QueryStart := FindByte(ABuffer, Space1 + 1, Space2, 63);
  
  PathStart := Space1 + 1;
  if QueryStart <> -1 then
    PathLen := QueryStart - PathStart
  else
    PathLen := Space2 - PathStart;

  // Path raiz otimizado
  APathOffset := PathStart;
  APathLength := PathLen;

  if QueryStart <> -1 then
  begin
    AQueryOffset := QueryStart;
    AQueryLength := Space2 - QueryStart;
  end;

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
  const AMethod: string;
  const AHeaderSegments: THeaderSegments;
  ABody: TBytes;
  ABodyOffset, ABodyLen: Integer;
  AContentLength: Int64;
  APathOffset, APathLength, AQueryOffset, AQueryLength: Integer
);
begin
  inherited Create;
  FMethod := AMethod;
  FPath := '';
  FQuery := '';
  FPathOffset := APathOffset;
  FPathLength := APathLength;
  FQueryOffset := AQueryOffset;
  FQueryLength := AQueryLength;
  FHeaderSegments := AHeaderSegments;
  FContentLength := AContentLength;
  FHeaderCacheCount := 0;

  // O buffer permanece válido durante o processamento síncrono do request.
  // Compartilhamos o TBytes por referência contada para evitar uma cópia inteira do payload.
  FBuffer := ABody;

  // Stream que lê diretamente do buffer compartilhado sem cópia adicional
  FBodyStream := TDextReadOnlyBytesStream.Create(FBuffer, ABodyOffset, ABodyLen);
end;

destructor TDextEpollRequest.Destroy;
begin
  if Assigned(FResolvedHeaders) then
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
  i: Integer;
  Seg: THeaderSegment;
  ValStart: Integer;
  ValLen: Integer;
begin
  for i := 0 to FHeaderCacheCount - 1 do
  begin
    if FHeaderCacheKeys[i] = AName then
    begin
      Result := FHeaderCacheValues[i];
      Exit;
    end;
  end;

  for i := 0 to FHeaderCacheCount - 1 do
  begin
    if SameText(FHeaderCacheKeys[i], AName) then
    begin
      Result := FHeaderCacheValues[i];
      Exit;
    end;
  end;

  for i := 0 to Length(FHeaderSegments) - 1 do
  begin
    Seg := FHeaderSegments[i];
    if TDextEpollHttpParser.CompareBytesCI(FBuffer, Seg.KeyStart, Seg.KeyLen, AName) then
    begin
      ValStart := Seg.ValueStart;
      ValLen := Seg.ValueLen;
      while (ValLen > 0) and ((FBuffer[ValStart] = 32) or (FBuffer[ValStart] = 9)) do
      begin
        Inc(ValStart);
        Dec(ValLen);
      end;
      while (ValLen > 0) and ((FBuffer[ValStart + ValLen - 1] = 32) or (FBuffer[ValStart + ValLen - 1] = 9)) do
        Dec(ValLen);

      Result := TEncoding.UTF8.GetString(FBuffer, ValStart, ValLen);
      if FHeaderCacheCount < Length(FHeaderCacheKeys) then
      begin
        FHeaderCacheKeys[FHeaderCacheCount] := AName;
        FHeaderCacheValues[FHeaderCacheCount] := Result;
        Inc(FHeaderCacheCount);
      end;
      Exit;
    end;
  end;

  Result := '';
  if FHeaderCacheCount < Length(FHeaderCacheKeys) then
  begin
    FHeaderCacheKeys[FHeaderCacheCount] := AName;
    FHeaderCacheValues[FHeaderCacheCount] := '';
    Inc(FHeaderCacheCount);
  end;
end;

function TDextEpollRequest.GetHeader(const AName: string): string;
begin
  Result := ResolveHeader(AName);
end;

procedure TDextEpollRequest.PopulateHeaders(ADict: TDictionary<string, string>);
var
  i: Integer;
  Seg: THeaderSegment;
  Key, Value: string;
  KeyStart, KeyLen: Integer;
  ValStart, ValLen: Integer;
begin
  for i := 0 to Length(FHeaderSegments) - 1 do
  begin
    Seg := FHeaderSegments[i];

    KeyStart := Seg.KeyStart;
    KeyLen := Seg.KeyLen;
    while (KeyLen > 0) and ((FBuffer[KeyStart] = 32) or (FBuffer[KeyStart] = 9)) do
    begin
      Inc(KeyStart);
      Dec(KeyLen);
    end;
    while (KeyLen > 0) and ((FBuffer[KeyStart + KeyLen - 1] = 32) or (FBuffer[KeyStart + KeyLen - 1] = 9)) do
      Dec(KeyLen);

    ValStart := Seg.ValueStart;
    ValLen := Seg.ValueLen;
    while (ValLen > 0) and ((FBuffer[ValStart] = 32) or (FBuffer[ValStart] = 9)) do
    begin
      Inc(ValStart);
      Dec(ValLen);
    end;
    while (ValLen > 0) and ((FBuffer[ValStart + ValLen - 1] = 32) or (FBuffer[ValStart + ValLen - 1] = 9)) do
      Dec(ValLen);

    Key := TEncoding.UTF8.GetString(FBuffer, KeyStart, KeyLen);
    Value := TEncoding.UTF8.GetString(FBuffer, ValStart, ValLen);
    ADict.AddOrSetValue(Key, Value);
  end;
end;

function TDextEpollRequest.GetMethod: string; begin Result := FMethod; end;
function TDextEpollRequest.GetPath: string;
begin
  if FPath = '' then
    FPath := TDextEpollHttpParser.ExtractSliceString(FBuffer, FPathOffset, FPathLength);
  Result := FPath;
end;
function TDextEpollRequest.GetQueryString: string;
begin
  if FQuery = '' then
    FQuery := TDextEpollHttpParser.ExtractSliceString(FBuffer, FQueryOffset, FQueryLength);
  Result := FQuery;
end;

{ TDextEpollResponse }

constructor TDextEpollResponse.Create(AContext: TDextEpollContext);
begin
  inherited Create;
  FContext := AContext;
  FSocket := AContext.FFd;
  FGeneration := AContext.FGeneration;
  FResponseWriter.Init;
  FHeadersSent := False;
  FStatusCode := 200;
  FReason := 'OK';
  FHeaders := TDictionary<string, string>.Create;
  FSendFileFd := -1;
  FSendFileOffset := 0;
  FSendFileLen := 0;
end;

destructor TDextEpollResponse.Destroy;
begin
  if FSendFileFd >= 0 then
    __close(FSendFileFd);
  FResponseWriter.Clear;
  FHeaders.Free;
  inherited;
end;

procedure TDextEpollResponse.Close;
begin
  Flush;
end;

procedure TDextEpollResponse.Flush;
label
  SendFileCheck;
var
  Iov: array[0..127] of iovec;
  IovCnt: Integer;
  Res: Integer;
  TotalBytes: Integer;
  Event: epoll_event;
  SentFileBytes: NativeInt;
  SegCount: Integer;
  I: Integer;
  HasPendingWrite: Boolean;
  StartSend: Int64;
  Plaintext: TBytes;
  PlainLength: Integer;
  PlainOffset: Integer;
  WrittenPlain: Integer;
begin
  HasPendingWrite := False;
  if FContext.FGeneration <> FGeneration then Exit;
  if (FContext.FTLS <> nil) and (FSendFileFd >= 0) then
    raise EInvalidOp.Create('sendfile is not available over epoll OpenSSL TLS');
  if FSendFileFd >= 0 then
  begin
    FContext.FSendFileFd := FSendFileFd;
    FContext.FSendFileOffset := FSendFileOffset;
    FContext.FSendFileLen := FSendFileLen;
    FSendFileFd := -1;
    FSendFileOffset := 0;
    FSendFileLen := 0;
  end;
  StartSend := 0;
  if (FContext <> nil) and (FContext.FEngine <> nil) and
     TDextEpollEngine(FContext.FEngine).FProfileEnabled then
  begin
    StartSend := TStopwatch.GetTimeStamp;
  end;

  if not FHeadersSent then
    SendHeaders;

  if FContext.FTLS <> nil then
  begin
    SegCount := FResponseWriter.SegmentCount;
    // Headers must precede body in the plaintext stream for TLS.
    PlainLength := FHeaderLen;
    for I := 0 to SegCount - 1 do
      Inc(PlainLength, FResponseWriter.Segments[I].Length);
    if PlainLength > 0 then
    begin
      SetLength(Plaintext, PlainLength);
      PlainOffset := 0;
      if FHeaderLen > 0 then
      begin
        Move(FHeaderBuf[0], Plaintext[0], FHeaderLen);
        PlainOffset := FHeaderLen;
      end;
      for I := 0 to SegCount - 1 do
      begin
        Move(FResponseWriter.Segments[I].Data^, Plaintext[PlainOffset],
          FResponseWriter.Segments[I].Length);
        Inc(PlainOffset, FResponseWriter.Segments[I].Length);
        if Assigned(FResponseWriter.Segments[I].ReleaseProc) then
          FResponseWriter.Segments[I].ReleaseProc(
            FResponseWriter.Segments[I].Owner);
        FResponseWriter.DetachSegment(I);
      end;
      FResponseWriter.Reset;
      PlainOffset := 0;
      while PlainOffset < PlainLength do
      begin
        WrittenPlain := FContext.FTLS.PlaintextWrite(
          @Plaintext[PlainOffset], PlainLength - PlainOffset);
        if WrittenPlain <= 0 then
          raise EInOutError.Create('OpenSSL TLS failed to encrypt epoll response');
        Inc(PlainOffset, WrittenPlain);
        FContext.DrainTLSOutput;
      end;
      FContext.FlushTLSOutput;
    end;
    FillChar(Event, SizeOf(Event), 0);
    Event.events := EPOLLIN or EPOLLONESHOT;
    if FContext.FTLSOutputEnd > FContext.FTLSOutputStart then
      Event.events := Event.events or EPOLLOUT;
    Event.data.ptr := FContext;
    epoll_ctl(FContext.FEpollFd, EPOLL_CTL_MOD, FSocket, @Event);
    Exit;
  end;

  // Headers iovec MUST be first — placed before any body segments.
  IovCnt := 0;
  if FHeaderLen > 0 then
  begin
    Iov[0].iov_base := @FHeaderBuf[0];
    Iov[0].iov_len  := FHeaderLen;
    IovCnt := 1;
  end;

  SegCount := FResponseWriter.SegmentCount;
  TotalBytes := FHeaderLen;
  for I := 0 to SegCount - 1 do
    TotalBytes := TotalBytes + FResponseWriter.Segments[I].Length;

  if TotalBytes <= 0 then
    goto SendFileCheck;

  for I := 0 to SegCount - 1 do
  begin
    if IovCnt >= Length(Iov) then Break;
    Iov[IovCnt].iov_base := FResponseWriter.Segments[I].Data;
    Iov[IovCnt].iov_len  := FResponseWriter.Segments[I].Length;
    Inc(IovCnt);
  end;

  HasPendingWrite := False;
  Res := writev(FSocket, @Iov[0], IovCnt);
  if Res < 0 then
  begin
    if (errno = EAGAIN) or (errno = EWOULDBLOCK) then
      Res := 0
    else
      Res := -1;
  end;

  if Res >= 0 then
  begin
    if Res < TotalBytes then
    begin
      SetLength(FContext.FWriteSegments, SegCount);
      for I := 0 to SegCount - 1 do
        FContext.FWriteSegments[I] := FResponseWriter.Segments[I];
      FContext.FWriteSegmentsCount := SegCount;
      FContext.FWriteSegIndex := 0;
      FContext.FWriteSegOffset := 0;

      // Subtract bytes consumed by the header iovec (already sent)
      // before advancing through body segments.
      var BodyWritten := Res - Min(FHeaderLen, Res);
      TDextBufferCursor.Advance(@FContext.FWriteSegments[0], SegCount,
        BodyWritten,
        FContext.FWriteSegIndex, FContext.FWriteSegOffset);

      // Ownership of every segment is now represented by FWriteSegments.
      // Completed prefixes were released above; pending segments are released
      // by the EPOLLOUT cursor or context cleanup.
      for I := 0 to SegCount - 1 do
        FResponseWriter.DetachSegment(I);

      HasPendingWrite := True;

      FillChar(Event, SizeOf(Event), 0);
      Event.events := EPOLLOUT or EPOLLET or EPOLLONESHOT;
      Event.data.ptr := FContext;
      epoll_ctl(FContext.FEpollFd, EPOLL_CTL_MOD, FSocket, @Event);
    end
    else
    begin
      for I := 0 to SegCount - 1 do
      begin
        if Assigned(FResponseWriter.Segments[I].ReleaseProc) then
          FResponseWriter.Segments[I].ReleaseProc(FResponseWriter.Segments[I].Owner);
        FResponseWriter.DetachSegment(I);
      end;
    end;
  end;

  FResponseWriter.Reset;

SendFileCheck:
  if (not HasPendingWrite) and (FContext.FSendFileLen > 0)
    and (FContext.FSendFileFd >= 0) then
  begin
    SentFileBytes := sendfile(FSocket, FContext.FSendFileFd,
      @FContext.FSendFileOffset, FContext.FSendFileLen);
    if SentFileBytes >= 0 then
    begin
      FContext.FSendFileLen := FContext.FSendFileLen - SentFileBytes;
      if FContext.FSendFileLen = 0 then
      begin
        __close(FContext.FSendFileFd);
        FContext.FSendFileFd := -1;
      end;
    end
    else if (errno <> EAGAIN) and (errno <> EWOULDBLOCK) then
    begin
      __close(FContext.FSendFileFd);
      FContext.FSendFileFd := -1;
      FContext.FSendFileLen := 0;
    end;

    if FContext.FSendFileLen > 0 then
    begin
      FillChar(Event, SizeOf(Event), 0);
      Event.events := EPOLLOUT or EPOLLET or EPOLLONESHOT;
      Event.data.ptr := FContext;
      epoll_ctl(FContext.FEpollFd, EPOLL_CTL_MOD, FSocket, @Event);
    end;
  end;

  if (StartSend > 0) and (FContext <> nil) and
     (FContext.FEngine <> nil) then
  begin
    TInterlocked.Add(
      TDextEpollEngine(FContext.FEngine).FTotalSendTicks,
      TStopwatch.GetTimeStamp - StartSend);
  end;
end;

procedure TDextEpollResponse.SendHeaders;
  procedure AppendStr(const AStr: string; var ABuffer: array of Byte;
    var AOffset: Integer);
  var
    I, StrLen: Integer;
  begin
    StrLen := Length(AStr);
    if StrLen = 0 then Exit;
    for I := 1 to StrLen do
    begin
      ABuffer[AOffset] := Byte(AStr[I]);
      Inc(AOffset);
    end;
  end;
var
  TempBuf: array[0..2047] of Byte;
  BufferOffset: Integer;
  Pair: TPair<string, string>;
  SegCount, TotalBytes, I: Integer;
begin
  if FContext.FGeneration <> FGeneration then Exit;
  if FHeadersSent then Exit;

  BufferOffset := 0;

  if not FHeaders.ContainsKey('Content-Type') then
    FHeaders.Add('Content-Type', 'text/plain');

  if not FHeaders.ContainsKey('Content-Length') then
  begin
    if FContext.FSendFileLen > 0 then
      FHeaders.Add('Content-Length', IntToStr(FContext.FSendFileLen))
    else
    begin
      SegCount := FResponseWriter.SegmentCount;
      TotalBytes := 0;
      for I := 0 to SegCount - 1 do
        TotalBytes := TotalBytes + FResponseWriter.Segments[I].Length;
      FHeaders.Add('Content-Length', IntToStr(TotalBytes));
    end;
  end;

  if not FHeaders.ContainsKey('Connection') then
  begin
    if FContext.FKeepAlive then
      FHeaders.Add('Connection', 'keep-alive')
    else
      FHeaders.Add('Connection', 'close');
  end;

  AppendStr('HTTP/1.1 ', TempBuf, BufferOffset);
  AppendStr(IntToStr(FStatusCode), TempBuf, BufferOffset);
  AppendStr(' ', TempBuf, BufferOffset);
  AppendStr(FReason, TempBuf, BufferOffset);
  AppendStr(#13#10, TempBuf, BufferOffset);

  for Pair in FHeaders do
  begin
    AppendStr(Pair.Key, TempBuf, BufferOffset);
    AppendStr(': ', TempBuf, BufferOffset);
    AppendStr(Pair.Value, TempBuf, BufferOffset);
    AppendStr(#13#10, TempBuf, BufferOffset);
  end;

  AppendStr(#13#10, TempBuf, BufferOffset);

  // Store headers in a dedicated buffer — NOT in FResponseWriter —
  // so the Flush() writev places headers strictly before body segments.
  SetLength(FHeaderBuf, BufferOffset);
  Move(TempBuf[0], FHeaderBuf[0], BufferOffset);
  FHeaderLen := BufferOffset;
  FHeadersSent := True;
end;

procedure TDextEpollResponse.SetHeader(const AName, AValue: string);
begin
  if FContext.FGeneration <> FGeneration then Exit;
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');
  FHeaders.AddOrSetValue(AName, AValue);
end;

procedure TDextEpollResponse.SetStatus(ACode: Integer; const AReason: string);
begin
  if FContext.FGeneration <> FGeneration then Exit;
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');
  FStatusCode := ACode;
  if AReason <> '' then
    FReason := AReason
  else
    FReason := 'OK';
end;

procedure TDextEpollResponse.Write(
  const ABuffer: TBytes; AOffset, ACount: Integer);
begin
  if FContext.FGeneration <> FGeneration then Exit;
  if ACount <= 0 then Exit;
  // NOTE: Do NOT call SendHeaders here.
  // Content-Length is computed from all accumulated segments
  // in SendHeaders, which is called by Flush/Close once the
  // handler has finished writing the complete body.
  // Calling SendHeaders here would emit Content-Length: 0
  // because no segments exist yet at this point.
  FResponseWriter.Write(
    TByteSpan.Create(@ABuffer[AOffset], ACount));
end;

procedure TDextEpollResponse.WriteFile(const APath: string; AOffset, ACount: Int64);
var
  Fd: Integer;
  StatBuf: _stat;
begin
  if FContext.FGeneration <> FGeneration then Exit;
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');

  Fd := __open(PAnsiChar(AnsiString(APath)), O_RDONLY);
  if Fd < 0 then
    raise EOSError.Create('Failed to open file: ' + APath);

  if FSendFileFd >= 0 then
    __close(FSendFileFd);
  FSendFileFd := Fd;
  FSendFileOffset := AOffset;
  if ACount <= 0 then
  begin
    if fstat(Fd, StatBuf) = 0 then
      FSendFileLen := StatBuf.st_size - AOffset
    else
      FSendFileLen := 0;
  end
  else
    FSendFileLen := ACount;
end;

procedure TDextEpollResponse.WriteBytes(AData: Pointer; ALength: Integer);
begin
  if ALength <= 0 then
    Exit;
  // NOTE: Do NOT call SendHeaders here — same reason as Write().
  // Content-Length is computed in SendHeaders from all segments,
  // which is invoked by Flush/Close after the handler completes.
  FResponseWriter.Write(TByteSpan.Create(AData, ALength));
end;


{ TDextEpollWorker }

constructor TDextEpollWorker.Create(AEngine: TDextEpollEngine; ACoreId: Integer);
begin
  inherited Create(True);
  FEngine := AEngine;
  FCoreId := ACoreId;
  FEpollFd := -1;
  FListenSocket := -1;
  FPipeFds[0] := -1;
  FPipeFds[1] := -1;
  FreeOnTerminate := False;
  SetLength(FReadBuffer, 8192);
  FContextPool := TList.Create;
  FActiveContexts := TList.Create;
  FTaskPool := TList.Create;
  FCompletionLock := TObject.Create;
  SetLength(FCompletions, AEngine.FOptions.MaxQueueCapacity +
    AEngine.FOptions.MaxExecutorThreads + 16);
  if Length(FCompletions) < 64 then
    SetLength(FCompletions, 64);
  FCompletionHead := 0;
  FCompletionTail := 0;
  FCompletionCount := 0;
  FLastSweepTick := GetTickCount64;

  FWorkerTotalQueueDelayTicks := 0;
  FWorkerTotalHandlerTicks := 0;
  FWorkerTotalReadParseTicks := 0;
  FWorkerTotalSendTicks := 0;
  FWorkerTotalSweepTicks := 0;
  FWorkerSweepCount := 0;
  FWorkerRequestCount := 0;
end;

destructor TDextEpollWorker.Destroy;
var
  I: Integer;
  Context: TDextEpollContext;
begin
  CloseLocalReactor;
  while FActiveContexts.Count > 0 do
  begin
    Context := TDextEpollContext(FActiveContexts.Last);
    FActiveContexts.Delete(FActiveContexts.Count - 1);
    if Context.FFd >= 0 then
    begin
      __close(Context.FFd);
      Context.FFd := -1;
      TInterlocked.Decrement(FEngine.FActiveConnections);
    end;
    ReleaseContext(Context);
  end;
  for I := 0 to FContextPool.Count - 1 do
    TDextEpollContext(FContextPool[I]).Free;
  FContextPool.Free;
  FActiveContexts.Free;

  for I := 0 to FTaskPool.Count - 1 do
    TDextEpollTask(FTaskPool[I]).Free;
  FTaskPool.Free;

  FCompletions := nil;
  FCompletionLock.Free;
  inherited;
end;

procedure TDextEpollWorker.RecycleTask(ATask: TDextEpollTask);
begin
  if ATask <> nil then
  begin
    ATask.Context := nil;
    ATask.Connection := nil;
    ATask.Request := nil;
    ATask.Response := nil;
    ATask.OnRequest := nil;
    ATask.Worker := nil;
    if FTaskPool.Count < 256 then
      FTaskPool.Add(ATask)
    else
      ATask.Free;
  end;
end;

function TDextEpollWorker.AcquireTask: TDextEpollTask;
begin
  if FTaskPool.Count > 0 then
  begin
    Result := TDextEpollTask(FTaskPool.Last);
    FTaskPool.Delete(FTaskPool.Count - 1);
  end
  else
    Result := TDextEpollTask.Create;
end;

procedure TDextEpollWorker.EnqueueCompletion(AContext: TDextEpollContext;
  AGeneration: Cardinal; const AResponse: IDextRawResponse);
var
  B: Byte;
begin
  TMonitor.Enter(FCompletionLock);
  try
    if FCompletionCount >= Length(FCompletions) then
      raise EInvalidOp.Create('Epoll completion queue capacity exceeded');
    FCompletions[FCompletionTail].Context := AContext;
    FCompletions[FCompletionTail].Generation := AGeneration;
    FCompletions[FCompletionTail].Response := AResponse;
    Inc(FCompletionTail);
    if FCompletionTail = Length(FCompletions) then
      FCompletionTail := 0;
    Inc(FCompletionCount);
  finally
    TMonitor.Exit(FCompletionLock);
  end;

  if FPipeFds[1] >= 0 then
  begin
    B := 2;
    __write(FPipeFds[1], @B, 1);
  end;
end;

procedure TDextEpollWorker.DrainCompletions;
var
  Completion: TDextEpollCompletion;
  Context: TDextEpollContext;
  Event: epoll_event;
begin
  while True do
  begin
    Completion.Context := nil;
    Completion.Generation := 0;
    Completion.Response := nil;
    TMonitor.Enter(FCompletionLock);
    try
      if FCompletionCount = 0 then
        Exit;
      Completion := FCompletions[FCompletionHead];
      FCompletions[FCompletionHead].Context := nil;
      FCompletions[FCompletionHead].Generation := 0;
      FCompletions[FCompletionHead].Response := nil;
      Inc(FCompletionHead);
      if FCompletionHead = Length(FCompletions) then
        FCompletionHead := 0;
      Dec(FCompletionCount);
    finally
      TMonitor.Exit(FCompletionLock);
    end;

    Context := Completion.Context;
    if (Context = nil) or (Context.FGeneration <> Completion.Generation) then
      Continue;

    try
      Completion.Response.Close;
    except
      Context.FKeepAlive := False;
    end;

    if Context.FGeneration <> Completion.Generation then
      Continue;
    if Context.FWriteSegmentsCount > 0 then
      Continue;

    if Context.FKeepAlive then
    begin
      var Remaining: Integer;
      if (Context.FConsumedBytes > 0) and (Context.FConsumedBytes < Context.FReadLen) then
      begin
        Remaining := Context.FReadLen - Context.FConsumedBytes;
        Move(Context.FReadBuffer[Context.FConsumedBytes], Context.FReadBuffer[0], Remaining);
        Context.FReadLen := Remaining;
      end
      else
        Context.FReadLen := 0;
      Context.FConsumedBytes := 0;

      if FEngine.FProfileEnabled then
      begin
        Context.FHandlerEndTime := TStopwatch.GetTimeStamp;
        FWorkerTotalHandlerTicks := FWorkerTotalHandlerTicks +
          (Context.FHandlerEndTime - Context.FQueueStartTime);
      end;

      ProcessBuffer(Context);
    end
    else
    begin
      FillChar(Event, SizeOf(Event), 0);
      Event.data.ptr := Context;
      shutdown(Context.FFd, 1);
      Event.events := EPOLLIN or EPOLLET or EPOLLONESHOT;
      epoll_ctl(FEpollFd, EPOLL_CTL_MOD, Context.FFd, @Event);

      if FEngine.FProfileEnabled then
      begin
        Context.FHandlerEndTime := TStopwatch.GetTimeStamp;
        FWorkerTotalHandlerTicks := FWorkerTotalHandlerTicks +
          (Context.FHandlerEndTime - Context.FQueueStartTime);
      end;
    end;
  end;
end;

procedure TDextEpollWorker.ReleaseContext(AContext: TDextEpollContext);
var
  I: Integer;
begin
  Inc(AContext.FGeneration);
  if AContext.FGeneration = 0 then
    AContext.FGeneration := 1;
  if AContext.FSendFileFd >= 0 then
  begin
    __close(AContext.FSendFileFd);
    AContext.FSendFileFd := -1;
  end;

  if AContext.FWriteSegmentsCount > 0 then
  begin
    for I := AContext.FWriteSegIndex to AContext.FWriteSegmentsCount - 1 do
      if Assigned(AContext.FWriteSegments[I].ReleaseProc) then
        AContext.FWriteSegments[I].ReleaseProc(
          AContext.FWriteSegments[I].Owner);
    AContext.FWriteSegments := nil;
    AContext.FWriteSegmentsCount := 0;
  end;

  AContext.FTLS := nil;
  AContext.FTLSOutputBuffer := nil;
  AContext.FTLSOutputStart := 0;
  AContext.FTLSOutputEnd := 0;
  AContext.FTLSHandshakeComplete := False;

  if FContextPool.Count < 1024 then
    FContextPool.Add(AContext)
  else
    AContext.Free;
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

  // TCP_DEFER_ACCEPT removed to avoid 10-second epoll_wait connection notification delays

  // Enable TCP_FASTOPEN
  OptVal := SOMAXCONN;
  setsockopt(FListenSocket, IPPROTO_TCP, TCP_FASTOPEN, OptVal, SizeOf(OptVal));

  fcntl(FListenSocket, F_SETFL, O_NONBLOCK);

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(FEngine.FListeningPort);
  if (FEngine.FAddress = '') or (FEngine.FAddress = '0.0.0.0') then
    Addr.sin_addr.s_addr := INADDR_ANY
  else if SameText(FEngine.FAddress, 'localhost') or (FEngine.FAddress = '127.0.0.1') then
    Addr.sin_addr.s_addr := inet_addr('127.0.0.1')
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

procedure ExecuteTask(Data: Pointer);
var
  LTask: TDextEpollTask;
begin
  LTask := TDextEpollTask(Data);
  try
    if (LTask.Context.FGeneration = LTask.Generation) and
       Assigned(LTask.OnRequest) then
      LTask.OnRequest(LTask.Connection, LTask.Request, LTask.Response);
  finally
    TDextEpollWorker(LTask.Worker).EnqueueCompletion(LTask.Context, LTask.Generation, LTask.Response);
    LTask.Connection := nil;
    LTask.Request := nil;
    LTask.Response := nil;
    LTask.OnRequest := nil;
    TDextEpollWorker(LTask.Worker).RecycleTask(LTask);
  end;
end;

procedure TDextEpollWorker.ProcessRequestAsync(
  AContext: TDextEpollContext;
  AConnection: IDextServerConnection;
  ARequest: IDextRawRequest;
  AResponse: IDextRawResponse
);
var
  LFd: Integer;
  LEpollFd: Integer;
  LOnRequest: TRequestEventHandler;
  HasPendingWrite: Boolean;
  IsKeepAlive: Boolean;
  LTaskEvent: epoll_event;
  LTask: TDextEpollTask;
begin
  LFd := AContext.FFd;
  LEpollFd := FEpollFd;
  LOnRequest := FEngine.FOnRequest;

  IsKeepAlive := not SameText(ARequest.GetHeader('Connection'), 'close');
  if AContext <> nil then
    AContext.FKeepAlive := IsKeepAlive;

  if (AContext <> nil) and (AContext.FEngine <> nil) and
     TDextEpollEngine(AContext.FEngine).FProfileEnabled then
  begin
    AContext.FQueueStartTime := TStopwatch.GetTimeStamp;
    FWorkerTotalQueueDelayTicks := FWorkerTotalQueueDelayTicks +
      (AContext.FQueueStartTime - AContext.FWakeupTime);
  end;

  if Assigned(FEngine.Executor) then
  begin
    LTask := AcquireTask;
    LTask.Context := AContext;
    LTask.Generation := AContext.FGeneration;
    LTask.Connection := AConnection;
    LTask.Request := ARequest;
    LTask.Response := AResponse;
    LTask.OnRequest := LOnRequest;
    LTask.Worker := Self;

    if not FEngine.Executor.TryEnqueue(ExecuteTask, LTask) then
    begin
      // Queue is saturated: return 503 and close immediately
      try
        AResponse.SetStatus(503, 'Service Unavailable');
        AResponse.SetHeader('Content-Type', 'text/plain; charset=utf-8');
        AResponse.Write(
          TEncoding.UTF8.GetBytes('Service Unavailable (Queue Full)'),
          0, 32);
      finally
        AResponse.Close;
        shutdown(LFd, 1);
        if AContext <> nil then
        begin
          AContext.FKeepAlive := False;
          FillChar(LTaskEvent, SizeOf(LTaskEvent), 0);
          LTaskEvent.events := EPOLLIN or EPOLLET or EPOLLONESHOT;
          LTaskEvent.data.ptr := AContext;
          epoll_ctl(LEpollFd, EPOLL_CTL_MOD, LFd, @LTaskEvent);
        end;
        RecycleTask(LTask);
      end;
    end;
  end
  else
  begin
    // Inline execution
    try
      try
        if Assigned(LOnRequest) then
          LOnRequest(AConnection, ARequest, AResponse);
      finally
        AResponse.Close;
      end;
    finally
      HasPendingWrite := AContext.FWriteSegmentsCount > 0;
      if not HasPendingWrite then
      begin
        if not IsKeepAlive then
        begin
          shutdown(LFd, 1);
          FillChar(LTaskEvent, SizeOf(LTaskEvent), 0);
          LTaskEvent.events := EPOLLIN or EPOLLONESHOT;
          LTaskEvent.data.ptr := AContext;
          epoll_ctl(LEpollFd, EPOLL_CTL_MOD, LFd, @LTaskEvent);
        end
        else
        begin
          FillChar(LTaskEvent, SizeOf(LTaskEvent), 0);
          LTaskEvent.events := EPOLLIN or EPOLLONESHOT;
          LTaskEvent.data.ptr := AContext;
          epoll_ctl(LEpollFd, EPOLL_CTL_MOD, LFd, @LTaskEvent);

          if AContext.FReadLen > 0 then
            ProcessBuffer(AContext);
        end;
      end;

      if (AContext <> nil) and (AContext.FEngine <> nil) and
         TDextEpollEngine(AContext.FEngine).FProfileEnabled then
      begin
        AContext.FHandlerEndTime := TStopwatch.GetTimeStamp;
        FWorkerTotalHandlerTicks := FWorkerTotalHandlerTicks +
          (AContext.FHandlerEndTime - AContext.FQueueStartTime);
        FWorkerRequestCount := FWorkerRequestCount + 1;
        if FWorkerRequestCount mod 1000 = 0 then
        begin
          var Freq: Double := TStopwatch.Frequency;
          var AvgQueue: Double := (FWorkerTotalQueueDelayTicks / FWorkerRequestCount) / Freq * 1000.0;
          var AvgHandler: Double := (FWorkerTotalHandlerTicks / FWorkerRequestCount) / Freq * 1000.0;
          var AvgRead: Double := (FWorkerTotalReadParseTicks / FWorkerRequestCount) / Freq * 1000.0;
          var AvgSend: Double := (FWorkerTotalSendTicks / FWorkerRequestCount) / Freq * 1000.0;
          var AvgSweep: Double := 0.0;
          if FWorkerSweepCount > 0 then
            AvgSweep := (FWorkerTotalSweepTicks / FWorkerSweepCount) / Freq * 1000.0;
          Writeln(Format(
            '[Profile] Worker Core %d | Req: %d | QDelay: %.3fms | Hdlr: %.3fms | ' +
            'RP: %.3fms | Send: %.3fms | Sweep: %.3fms (%d)',
            [FCoreId, FWorkerRequestCount, AvgQueue, AvgHandler, AvgRead, AvgSend, AvgSweep,
             FWorkerSweepCount]));
        end;
      end;
    end;
  end;
end;

procedure TDextEpollWorker.ProcessBuffer(AContext: TDextEpollContext);
var
  Method: string;
  PathOffset: Integer;
  PathLen: Integer;
  QueryOffset: Integer;
  QueryLen: Integer;
  HeaderSegments: THeaderSegments;
  BodyOffset: Integer;
  ContentLength: Int64;
  Connection: IDextServerConnection;
  RawRequest: IDextRawRequest;
  RawResponse: IDextRawResponse;
  Event: epoll_event;
  Parsed: Boolean;
  StartParse: Int64;
begin
  if AContext.FReadLen > 0 then
  begin
    StartParse := 0;
    if FEngine.FOptions.MaxRequestHeaderSize <= 0 then
      FEngine.FOptions.MaxRequestHeaderSize := 8192;

    if FEngine.FProfileEnabled then
      StartParse := TStopwatch.GetTimeStamp;

    Parsed := TDextEpollHttpParser.TryParseRequest(
      AContext.FReadBuffer,
      AContext.FReadLen,
      Method,
      PathOffset,
      PathLen,
      QueryOffset,
      QueryLen,
      HeaderSegments,
      BodyOffset,
      ContentLength
    );

    if Parsed then
    begin
      TInterlocked.Increment(FEngine.FTotalRequests);
      AContext.FConsumedBytes := BodyOffset + ContentLength;

      Connection := TDextEpollConnection.Create(AContext.FFd);
      RawRequest := TDextEpollRequest.Create(
        Method,
        HeaderSegments,
        AContext.FReadBuffer,
        BodyOffset,
        Max(0, AContext.FReadLen - BodyOffset),
        ContentLength,
        PathOffset,
        PathLen,
        QueryOffset,
        QueryLen
      );
      RawResponse := TDextEpollResponse.Create(AContext);

      if (AContext.FConsumedBytes > 0) and (AContext.FConsumedBytes < AContext.FReadLen) then
      begin
        var Remaining: Integer := AContext.FReadLen - AContext.FConsumedBytes;
        Move(AContext.FReadBuffer[AContext.FConsumedBytes], AContext.FReadBuffer[0], Remaining);
        AContext.FReadLen := Remaining;
      end
      else
        AContext.FReadLen := 0;
      AContext.FConsumedBytes := 0;

      if FEngine.FProfileEnabled then
        FWorkerTotalReadParseTicks := FWorkerTotalReadParseTicks +
          (TStopwatch.GetTimeStamp - StartParse);

      ProcessRequestAsync(AContext, Connection, RawRequest, RawResponse);
      Exit;
    end;

    // Proteção contra tamanho excessivo de cabeçalho
    if AContext.FReadLen >= FEngine.FOptions.MaxRequestHeaderSize then
    begin
      __close(AContext.FFd);
      AContext.FFd := -1;
      FActiveContexts.Remove(AContext);
      ReleaseContext(AContext);
      TInterlocked.Decrement(FEngine.FActiveConnections);
      Exit;
    end;
  end;

  // Se incompleto, rearma no Epoll para leitura
  FillChar(Event, SizeOf(Event), 0);
  Event.events := EPOLLIN or EPOLLONESHOT;
  if AContext.FTLSOutputEnd > AContext.FTLSOutputStart then
    Event.events := Event.events or EPOLLOUT;
  Event.data.ptr := AContext;
  epoll_ctl(FEpollFd, EPOLL_CTL_MOD, AContext.FFd, @Event);
end;

procedure TDextEpollWorker.Execute;
var
  Addr: sockaddr_in;
  AddrLen: socklen_t;
  ClientFd: Integer;
  Context: TDextEpollContext;
  Ctx: TDextEpollContext;
  Event: epoll_event;
  EventCount: Integer;
  Events: array[0..63] of epoll_event;
  Fd: Integer;
  i: Integer;
  Iov: array[0..127] of iovec;
  IovCnt: Integer;
  j: Integer;
  k: Integer;
  LibHandle: NativeUInt;
  LingerOption: linger;
  Mask: cpu_set_t;
  NowTicks: Int64;
  OptVal: Integer;
  pthread_setaffinity_np: TFnPthreadSetAffinity;
  ReadByte: Byte;
  ReadFailedOrClosed: Boolean;
  RecvRet: Integer;
  RawRecvRet: Integer;
  SentBytes: Integer;
  SentFileBytes: NativeInt;
begin
  // CPU Pinning (resolved dynamically to avoid linker errors)
  LibHandle := dlopen(nil, RTLD_LAZY);
  if LibHandle <> 0 then
  begin
    pthread_setaffinity_np := TFnPthreadSetAffinity(
      dlsym(LibHandle, 'pthread_setaffinity_np'));
    if Assigned(pthread_setaffinity_np) then
    begin
      CPU_ZERO(Mask);
      CPU_SET(FCoreId, Mask);
      pthread_setaffinity_np(pthread_self, SizeOf(Mask), @Mask);
    end;
    dlclose(LibHandle);
  end;

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

      for i := 0 to EventCount - 1 do
      begin
        Event := Events[i];
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

            // TCP Keep-Alive options
            OptVal := 1;
            setsockopt(ClientFd, SOL_SOCKET, SO_KEEPALIVE, OptVal, SizeOf(OptVal));
            OptVal := 60; // 60s idle
            setsockopt(ClientFd, IPPROTO_TCP, TCP_KEEPIDLE, OptVal, SizeOf(OptVal));
            OptVal := 5; // 5s interval
            setsockopt(ClientFd, IPPROTO_TCP, TCP_KEEPINTVL, OptVal, SizeOf(OptVal));
            OptVal := 3; // 3 retries
            setsockopt(ClientFd, IPPROTO_TCP, TCP_KEEPCNT, OptVal, SizeOf(OptVal));

            // SO_LINGER for graceful close
            LingerOption.l_onoff := 1;
            LingerOption.l_linger := 5;
            setsockopt(ClientFd, SOL_SOCKET, SO_LINGER, LingerOption, SizeOf(LingerOption));

            // TCP_NODELAY to disable Nagle's algorithm
            OptVal := 1;
            setsockopt(
              ClientFd, IPPROTO_TCP, TCP_NODELAY, OptVal, SizeOf(OptVal));

            // Reuse context from pool or create new one
            if FContextPool.Count > 0 then
            begin
              Context := TDextEpollContext(FContextPool[FContextPool.Count - 1]);
              FContextPool.Delete(FContextPool.Count - 1);
              Context.FFd := ClientFd;
              Context.FEngine := FEngine;
              Context.FReadLen := 0;
              Inc(Context.FGeneration);
              Context.FWriteSegments := nil;
              Context.FWriteSegIndex := 0;
              Context.FWriteSegOffset := 0;
              Context.FWriteSegmentsCount := 0;
              Context.FSendFileFd := -1;
              Context.FSendFileOffset := 0;
              Context.FSendFileLen := 0;
              Context.FLastActive := GetTickCount64;
              Context.FTLS := nil;
              Context.FTLSOutputBuffer := nil;
              Context.FTLSOutputStart := 0;
              Context.FTLSOutputEnd := 0;
              Context.FTLSHandshakeComplete := False;
            end
            else
            begin
              Context := TDextEpollContext.Create(ClientFd, FEpollFd);
              Context.FEngine := FEngine;
            end;

            if FEngine.FTLSProvider <> nil then
              Context.InitializeTLS(FEngine.FTLSProvider);

            FActiveContexts.Add(Context);

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

            Event.events := EPOLLIN or EPOLLONESHOT;
            if Context.FTLSOutputEnd > Context.FTLSOutputStart then
              Event.events := Event.events or EPOLLOUT;
            Event.data.ptr := Context;
            epoll_ctl(FEpollFd, EPOLL_CTL_ADD, ClientFd, @Event);

            TInterlocked.Increment(FEngine.FActiveConnections);
          end;
        end
        else if Fd = FPipeFds[0] then
        begin
          while __read(FPipeFds[0], @ReadByte, 1) > 0 do
          begin
          end;
          DrainCompletions;
          if Terminated then
            Exit;
          Continue;
        end
        else
        begin
          Context := TDextEpollContext(Event.data.ptr);
          Context.FLastActive := GetTickCount64;
          if FEngine.FProfileEnabled then
            Context.FWakeupTime := TStopwatch.GetTimeStamp;

          if (Event.events and EPOLLOUT) <> 0 then
          begin
            var WriteWouldBlock: Boolean := False;
            while (Context.FTLSOutputEnd > Context.FTLSOutputStart) do
            begin
              Iov[0].iov_base := @Context.FTLSOutputBuffer[
                Context.FTLSOutputStart];
              Iov[0].iov_len := Context.FTLSOutputEnd -
                Context.FTLSOutputStart;
              SentBytes := writev(Context.FFd, @Iov[0], 1);
              if SentBytes > 0 then
                Inc(Context.FTLSOutputStart, SentBytes)
              else if (SentBytes < 0) and
                ((errno = EAGAIN) or (errno = EWOULDBLOCK)) then
              begin
                WriteWouldBlock := True;
                Break;
              end
              else
              begin
                WriteWouldBlock := True;
                Context.FFd := -1;
                Break;
              end;
            end;
            if Context.FTLSOutputStart = Context.FTLSOutputEnd then
            begin
              Context.FTLSOutputBuffer := nil;
              Context.FTLSOutputStart := 0;
              Context.FTLSOutputEnd := 0;
            end;
            while (not WriteWouldBlock) and ((Context.FWriteSegmentsCount > 0) or (Context.FSendFileLen > 0)) do
            begin
              if Context.FWriteSegmentsCount > 0 then
              begin
                IovCnt := 0;
                for k := Context.FWriteSegIndex to Context.FWriteSegmentsCount - 1 do
                begin
                  if IovCnt >= 128 then Break;
                  if k = Context.FWriteSegIndex then
                  begin
                    Iov[IovCnt].iov_base := PByte(Context.FWriteSegments[k].Data)
                      + Context.FWriteSegOffset;
                    Iov[IovCnt].iov_len := Context.FWriteSegments[k].Length
                      - Context.FWriteSegOffset;
                  end
                  else
                  begin
                    Iov[IovCnt].iov_base := Context.FWriteSegments[k].Data;
                    Iov[IovCnt].iov_len := Context.FWriteSegments[k].Length;
                  end;
                  Inc(IovCnt);
                end;

                SentBytes := writev(Context.FFd, @Iov[0], IovCnt);
                if SentBytes >= 0 then
                begin
                  TDextBufferCursor.Advance(@Context.FWriteSegments[0],
                    Context.FWriteSegmentsCount, SentBytes,
                    Context.FWriteSegIndex, Context.FWriteSegOffset);

                  if Context.FWriteSegIndex >= Context.FWriteSegmentsCount then
                  begin
                    Context.FWriteSegments := nil;
                    Context.FWriteSegmentsCount := 0;
                  end;
                end
                else if (errno = EAGAIN) or (errno = EWOULDBLOCK) then
                begin
                  WriteWouldBlock := True;
                end
                else
                begin
                  if Context.FSendFileFd >= 0 then
                  begin
                    __close(Context.FSendFileFd);
                    Context.FSendFileFd := -1;
                  end;
                  __close(Context.FFd);
                  Context.FFd := -1;
                  FActiveContexts.Remove(Context);
                  ReleaseContext(Context);
                  TInterlocked.Decrement(FEngine.FActiveConnections);
                  Break;
                end;
              end;

              if (not WriteWouldBlock) and (Context.FWriteSegmentsCount = 0) and
                 (Context.FSendFileLen > 0) and (Context.FSendFileFd >= 0) then
              begin
                SentFileBytes := sendfile(Context.FFd, Context.FSendFileFd,
                  @Context.FSendFileOffset, Context.FSendFileLen);
                if SentFileBytes >= 0 then
                begin
                  Context.FSendFileLen := Context.FSendFileLen - SentFileBytes;
                  if Context.FSendFileLen = 0 then
                  begin
                    __close(Context.FSendFileFd);
                    Context.FSendFileFd := -1;
                  end;
                end
                else if (errno = EAGAIN) or (errno = EWOULDBLOCK) then
                begin
                  WriteWouldBlock := True;
                end
                else
                begin
                  __close(Context.FSendFileFd);
                  Context.FSendFileFd := -1;
                  Context.FSendFileLen := 0;
                end;
              end;
            end;

            if Context.FFd < 0 then
              Continue;

            if (Context.FWriteSegmentsCount = 0) and (Context.FSendFileLen = 0) then
            begin
              if not Context.FKeepAlive then
              begin
                __close(Context.FFd);
                Context.FFd := -1;
                FActiveContexts.Remove(Context);
                ReleaseContext(Context);
                TInterlocked.Decrement(FEngine.FActiveConnections);
                Continue;
              end
              else
              begin
                Context.FReadLen := 0;
                FillChar(Event, SizeOf(Event), 0);
                Event.events := EPOLLIN or EPOLLONESHOT;
                Event.data.ptr := Context;
                epoll_ctl(FEpollFd, EPOLL_CTL_MOD, Context.FFd, @Event);
                Continue;
              end;
            end;

            FillChar(Event, SizeOf(Event), 0);
            Event.events := EPOLLOUT or EPOLLONESHOT;
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
              RawRecvRet := 0;
              if Context.FTLS <> nil then
              begin
                RawRecvRet := recv(Context.FFd, Context.FTLSNetworkBuffer[0],
                  Length(Context.FTLSNetworkBuffer), 0);
                RecvRet := RawRecvRet;
                if RawRecvRet > 0 then
                begin
                  RecvRet := Context.FeedTLS(
                    @Context.FTLSNetworkBuffer[0], RawRecvRet);
                  if RecvRet = 0 then
                    Continue;
                end;
              end
              else
                RecvRet := recv(Context.FFd, Context.FReadBuffer[0],
                  Length(Context.FReadBuffer), 0);
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
                if (Context.FTLS <> nil) and (RawRecvRet > 0) then
                  Continue;
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
              Context.FFd := -1;
              FActiveContexts.Remove(Context);
              ReleaseContext(Context);
              TInterlocked.Decrement(FEngine.FActiveConnections);
              Continue;
            end;

            // Se incompleto, rearma no Epoll para leitura
            FillChar(Event, SizeOf(Event), 0);
            Event.events := EPOLLIN or EPOLLONESHOT;
            if Context.FTLSOutputEnd > Context.FTLSOutputStart then
              Event.events := Event.events or EPOLLOUT;
            Event.data.ptr := Context;
            epoll_ctl(FEpollFd, EPOLL_CTL_MOD, Context.FFd, @Event);
            Continue;
          end;

          ReadFailedOrClosed := False;
          while True do
          begin
            RawRecvRet := 0;
            if Context.FReadLen + 4096 > Length(Context.FReadBuffer) then
              SetLength(Context.FReadBuffer, Length(Context.FReadBuffer) + 4096);

            if Context.FTLS <> nil then
            begin
              RawRecvRet := recv(Context.FFd, Context.FTLSNetworkBuffer[0],
                Length(Context.FTLSNetworkBuffer), 0);
              RecvRet := RawRecvRet;
              if RawRecvRet > 0 then
                RecvRet := Context.FeedTLS(
                  @Context.FTLSNetworkBuffer[0], RawRecvRet);
            end
            else
              RecvRet := recv(Context.FFd,
                Context.FReadBuffer[Context.FReadLen], 4096, 0);
            if RecvRet > 0 then
            begin
              if Context.FTLS = nil then
                Context.FReadLen := Context.FReadLen + RecvRet;
            end
            else if RecvRet = 0 then
            begin
              if (Context.FTLS <> nil) and (RawRecvRet > 0) then
                Continue;
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
            Context.FFd := -1;
            FActiveContexts.Remove(Context);
            ReleaseContext(Context);
            TInterlocked.Decrement(FEngine.FActiveConnections);
            Continue;
          end;

          ProcessBuffer(Context);
        end;
      end;

      // Keep-Alive connection timeout sweep (throttled to once per second)
      NowTicks := GetTickCount64;
      if NowTicks - FLastSweepTick > 1000 then
      begin
        FLastSweepTick := NowTicks;
        var StartSweep: Int64 := 0;
        if FEngine.FProfileEnabled then
          StartSweep := TStopwatch.GetTimeStamp;

        for j := FActiveContexts.Count - 1 downto 0 do
        begin
          Ctx := TDextEpollContext(FActiveContexts[j]);
          if NowTicks - Ctx.FLastActive > 15000 then
          begin
            __close(Ctx.FFd);
            FActiveContexts.Delete(j);
            ReleaseContext(Ctx);
            TInterlocked.Decrement(FEngine.FActiveConnections);
          end;
        end;

        if FEngine.FProfileEnabled then
        begin
          FWorkerTotalSweepTicks := FWorkerTotalSweepTicks +
            (TStopwatch.GetTimeStamp - StartSweep);
          FWorkerSweepCount := FWorkerSweepCount + 1;
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
var
  TLSOptions: TDextTLSOptions;
begin
  inherited Create;
  FOptions := AOptions;
  FRunning := False;
  FWorkers := TList.Create;
  FTLSProvider := nil;
  if FOptions.UseHttps then
  begin
    TLSOptions := TDextTLSOptions.DefaultServer(
      FOptions.SslCertFile, FOptions.SslKeyFile);
    TLSOptions.RootCertFile := FOptions.SslRootCertFile;
    TLSOptions.Provider := 'OpenSSL';
    TLSOptions.ALPNProtocols := ['h2', 'http/1.1'];
    FTLSProvider := TDextOpenSSLContextProvider.Create(TLSOptions);
  end;

  FProfileEnabled := SameText(
    GetEnvironmentVariable('DEXT_PROFILE_EPOLL'), 'true');
  if FOptions.MaxExecutorThreads > 0 then
    FExecutor := TDextBoundedExecutor.Create(
      FOptions.MaxExecutorThreads, FOptions.MaxQueueCapacity);
end;

destructor TDextEpollEngine.Destroy;
begin
  Stop;
  FWorkers.Free;
  FExecutor.Free;
  inherited;
end;

procedure TDextEpollEngine.ReportMetrics(const AContext: TDextEpollContext);
var
  ReqCount: Int64;
  Freq: Double;
  AvgQueue, AvgHandler, AvgRead, AvgSend, AvgSweep: Double;
begin
  ReqCount := TInterlocked.Increment(FProfiledRequestCount);
  if ReqCount mod 1000 = 0 then
  begin
    Freq := TStopwatch.Frequency;
    AvgQueue := (FTotalQueueDelayTicks / ReqCount) / Freq * 1000.0;
    AvgHandler := (FTotalHandlerTicks / ReqCount) / Freq * 1000.0;
    AvgRead := (FTotalReadParseTicks / ReqCount) / Freq * 1000.0;
    AvgSend := (FTotalSendTicks / ReqCount) / Freq * 1000.0;

    if FSweepCount > 0 then
      AvgSweep := (FTotalSweepTicks / FSweepCount) / Freq * 1000.0
    else
      AvgSweep := 0.0;

    Writeln(Format(
      '[Profile] Req: %d | QDelay: %.3fms | Hdlr: %.3fms | ' +
      'RP: %.3fms | Send: %.3fms | Sweep: %.3fms (%d)',
      [ReqCount, AvgQueue, AvgHandler, AvgRead, AvgSend, AvgSweep,
       FSweepCount]));
  end;
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
    Worker := TDextEpollWorker.Create(Self, I - 1);
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

  // Drain application work while reactor workers and their connection
  // contexts are still alive. This prevents executor completions from
  // accessing contexts after the owning worker has been destroyed.
  if Assigned(FExecutor) then
    FExecutor.Shutdown;

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
