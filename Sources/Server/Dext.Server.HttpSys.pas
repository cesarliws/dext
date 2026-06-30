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
{  Windows HTTP Server (http.sys) driver implementation.                    }
{                                                                           }
unit Dext.Server.HttpSys;

interface

{$IFDEF MSWINDOWS}
uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  Dext.Collections.Dict,
  Winapi.Windows,
  Dext.Threading.ProcessorGroups,
  Dext.Server.Engine.Types,
  Dext.Server.Engine.Interfaces,
  Dext.Server.HttpSys.Api,
  Dext.Web.Interfaces,
  Dext.DI.Interfaces;


type
  TDextHttpSysEngine = class;

  /// <summary>
  ///   Thread-safe, zero-allocation memory stream pool for http.sys responses.
  /// </summary>
  TDextHttpSysBufferPool = class
  private
    FPool: TList;
    FLock: TSpinLock;
    FMaxPoolSize: Integer;
  public
    constructor Create(AMaxPoolSize: Integer = 64);
    destructor Destroy; override;
    function Acquire: TMemoryStream;
    procedure Release(ABuffer: TMemoryStream);
  end;

  /// <summary>
  ///   Raw request implementation wrapper for Windows http.sys.
  /// </summary>
  TDextHttpSysRequest = class(TInterfacedObject, IDextRawRequest)
  private
    FEngine: TDextHttpSysEngine;
    FRequest: PHTTP_REQUEST;
    FBodyStream: TCustomMemoryStream;
    FBodyRead: Boolean;
    function GetMethod: string;
    function GetPath: string;
    function GetQueryString: string;
    function GetHeader(const AName: string): string;
    procedure PopulateHeaders(ADict: TDictionary<string, string>);
    function GetContentLength: Int64;
    function GetBodyStream: TStream;
    function _Release: Integer; stdcall;
  public
    /// <summary>Initializes a raw http.sys request wrapper.</summary>
    /// <param name="ARequest">Pointer to the native HTTP_REQUEST structure.</param>
    constructor Create(ARequest: PHTTP_REQUEST);
    /// <summary>Cleans up the request resources.</summary>
    destructor Destroy; override;
    procedure Init(AEngine: TDextHttpSysEngine; ARequest: PHTTP_REQUEST);
  end;

  /// <summary>
  ///   Raw response implementation wrapper for Windows http.sys.
  /// </summary>
  TDextHttpSysResponse = class(TInterfacedObject, IDextRawResponse)
  private
    FEngine: TDextHttpSysEngine;
    FReqQueue: THandle;
    FRequestId: HTTP_REQUEST_ID;
    FHeadersSent: Boolean;
    FStatusCode: USHORT;
    FHeaderData: array[0..4095] of AnsiChar;
    FHeaderDataLen: Integer;
    FHeaderValues: array[0..29] of record
      Offset: Integer;
      Length: Integer;
    end;
    FReasonBuffer: array[0..127] of AnsiChar;
    FReasonLen: Integer;
    FBodyBuffer: TMemoryStream;
    procedure SendHeadersInternal(AMoreData: Boolean);
    function _Release: Integer; stdcall;
    procedure SetHeaderInt(AIndex: Integer; AValue: Int64);
  public
    /// <summary>Initializes a new http.sys response wrapper.</summary>
    /// <param name="AEngine">The http.sys engine reference.</param>
    /// <param name="AReqQueue">Handle to the request queue.</param>
    /// <param name="ARequestId">The unique ID of the request to respond to.</param>
    constructor Create(AEngine: TDextHttpSysEngine; AReqQueue: THandle; ARequestId: HTTP_REQUEST_ID);
    /// <summary>Cleans up the response resources.</summary>
    destructor Destroy; override;
    procedure Init(AEngine: TDextHttpSysEngine; AReqQueue: THandle; ARequestId: HTTP_REQUEST_ID);

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
  ///   Thread-safe, zero-allocation request pool for http.sys requests.
  /// </summary>
  TDextHttpSysRequestPool = class
  private
    FPool: TList;
    FLock: TSpinLock;
    FMaxPoolSize: Integer;
  public
    constructor Create(AMaxPoolSize: Integer = 64);
    destructor Destroy; override;
    function Acquire(AEngine: TDextHttpSysEngine; ARequest: PHTTP_REQUEST): TDextHttpSysRequest;
    procedure Release(ARequest: TDextHttpSysRequest);
  end;

  /// <summary>
  ///   Thread-safe, zero-allocation response pool for http.sys responses.
  /// </summary>
  TDextHttpSysResponsePool = class
  private
    FPool: TList;
    FLock: TSpinLock;
    FMaxPoolSize: Integer;
  public
    constructor Create(AMaxPoolSize: Integer = 64);
    destructor Destroy; override;
    function Acquire(AEngine: TDextHttpSysEngine; AReqQueue: THandle; ARequestId: HTTP_REQUEST_ID): TDextHttpSysResponse;
    procedure Release(AResponse: TDextHttpSysResponse);
  end;

  TDextHttpSysWebSocketConnection = class(TInterfacedObject, IDextWebSocketConnection)
  private
    FConnectionId: UInt64;
    FReqQueue: THandle;
    FRequestId: HTTP_REQUEST_ID;
    FClosed: Boolean;
  public
    constructor Create(AConnectionId: UInt64; AReqQueue: THandle; ARequestId: HTTP_REQUEST_ID; const ASecWebSocketKey: string);
    destructor Destroy; override;
    
    function GetConnectionId: UInt64;
    procedure SendText(const AText: string);
    procedure SendBinary(const AData: TBytes);
    procedure Close(AStatusCode: Word = 1000; const AReason: string = '');
    function Receive(var ABuffer: TBytes; AOffset, ACount: Integer): Integer;
  end;

  /// <summary>
  ///   Raw connection implementation wrapper for Windows http.sys.
  /// </summary>
  TDextHttpSysConnection = class(TInterfacedObject, IDextServerConnection)
  private
    FConnectionId: HTTP_CONNECTION_ID;
    FSecure: Boolean;
    FLocalPort: Word;
    FRemotePort: Word;
    FRemoteAddress: string;
    FReqQueue: THandle;
    FRequestId: HTTP_REQUEST_ID;
    FSecWebSocketKey: string;
  public
    /// <summary>Initializes a new http.sys connection wrapper.</summary>
    /// <param name="ARequest">The native HTTP_REQUEST structure of the connection.</param>
    constructor Create(const ARequest: HTTP_REQUEST; AReqQueue: THandle);
    
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
  ///   Worker thread for processing request queue events.
  /// </summary>
  TDextHttpSysWorker = class(TThread)
  private
    FEngine: TDextHttpSysEngine;
    FReqQueue: THandle;
    FAffinity: TDextProcessorGroupAffinity;
  protected
    procedure Execute; override;
  public
    /// <summary>Initializes the http.sys worker thread.</summary>
    /// <param name="AEngine">The http.sys engine instance.</param>
    /// <param name="AReqQueue">Handle to the request queue.</param>
    constructor Create(AEngine: TDextHttpSysEngine; AReqQueue: THandle; const AAffinity: TDextProcessorGroupAffinity);
  end;

  /// <summary>
  ///   Native Windows kernel-mode http.sys Dext server engine.
  /// </summary>
  TDextHttpSysEngine = class(TInterfacedObject, IDextServerEngine)
  private
    FOptions: TServerEngineOptions;
    FServerSessionId: HTTP_SERVER_SESSION_ID;
    FUrlGroupId: HTTP_URL_GROUP_ID;
    FReqQueue: THandle;
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
    FBufferPool: TDextHttpSysBufferPool;
    FRequestPool: TDextHttpSysRequestPool;
    FResponsePool: TDextHttpSysResponsePool;
    procedure InitializeHttpSys;
    procedure ConfigureTimeouts;
    procedure ConfigureLimits;
    procedure RecycleRequest(ARequest: TDextHttpSysRequest);
    procedure RecycleResponse(AResponse: TDextHttpSysResponse);
  public
    /// <summary>Initializes a new http.sys server engine.</summary>
    /// <param name="AOptions">The engine configuration options.</param>
    constructor Create(const AOptions: TServerEngineOptions);
    /// <summary>Destroys the engine and releases resources.</summary>
    destructor Destroy; override;

    /// <summary>Binds the engine to the specified address and port.</summary>
    /// <param name="AAddress">IP address to bind to.</param>
    /// <param name="APort">Port to listen on.</param>
    procedure Bind(const AAddress: string; APort: Word);
    /// <summary>Starts the http.sys request queue listener and worker threads.</summary>
    procedure Start;
    /// <summary>Stops the engine and closes the request queue.</summary>
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
    /// <summary>Sets the custom connection handler (unsupported for HTTP.sys).</summary>
    procedure SetConnectionHandler(const AHandler: IConnectionHandler);

    /// <summary>Static factory method for creating and registering the http.sys web host.</summary>
    class function Factory(Port: Integer; Pipeline: TRequestDelegate; Services: IServiceProvider): IWebHost; static;
    property BufferPool: TDextHttpSysBufferPool read FBufferPool;
  end;
{$ENDIF}

implementation

{$IFDEF MSWINDOWS}
uses
  System.SysConst,
  Dext.WebSocket.Handshake,
  Dext.WebSocket.Protocol;

var
  KnownRequestHeadersMapGlobal: TDictionary<string, Integer>;
  KnownResponseHeadersMapGlobal: TDictionary<string, Integer>;

{ TDextHttpSysBufferPool }

constructor TDextHttpSysBufferPool.Create(AMaxPoolSize: Integer);
begin
  inherited Create;
  FPool := TList.Create;
  FMaxPoolSize := AMaxPoolSize;
end;

destructor TDextHttpSysBufferPool.Destroy;
var
  Item: Pointer;
begin
  FLock.Enter;
  try
    for Item in FPool do
      TMemoryStream(Item).Free;
    FPool.Free;
  finally
    FLock.Exit;
  end;
  inherited;
end;

function TDextHttpSysBufferPool.Acquire: TMemoryStream;
begin
  Result := nil;
  FLock.Enter;
  try
    if FPool.Count > 0 then
    begin
      Result := TMemoryStream(FPool.Last);
      FPool.Delete(FPool.Count - 1);
    end;
  finally
    FLock.Exit;
  end;
  if Result = nil then
  begin
    Result := TMemoryStream.Create;
    Result.Size := 65536; // Pre-allocated 64KB initial buffer
    Result.Position := 0;
  end;
end;

procedure TDextHttpSysBufferPool.Release(ABuffer: TMemoryStream);
begin
  if ABuffer = nil then Exit;
  
  FLock.Enter;
  try
    if FPool.Count < FMaxPoolSize then
    begin
      ABuffer.Position := 0;
      if ABuffer.Size > 65536 then
        ABuffer.Size := 65536;
      FPool.Add(ABuffer);
    end
    else
    begin
      ABuffer.Free;
    end;
  finally
    FLock.Exit;
  end;
end;

{ TDextHttpSysRequest }

constructor TDextHttpSysRequest.Create(ARequest: PHTTP_REQUEST);
begin
  inherited Create;
  FRequest := ARequest;
  FBodyStream := nil;
  FEngine := nil;
  FBodyRead := False;
end;

destructor TDextHttpSysRequest.Destroy;
begin
  if Assigned(FBodyStream) then
    FBodyStream.Free;
  inherited;
end;

procedure TDextHttpSysRequest.Init(AEngine: TDextHttpSysEngine; ARequest: PHTTP_REQUEST);
begin
  FEngine := AEngine;
  FRequest := ARequest;
  FBodyRead := False;
  if Assigned(FBodyStream) then
  begin
    FBodyStream.Size := 0;
    FBodyStream.Position := 0;
  end;
end;

function TDextHttpSysRequest._Release: Integer;
begin
  Result := TInterlocked.Decrement(FRefCount);
  if Result = 0 then
  begin
    if Assigned(FEngine) then
      FEngine.RecycleRequest(Self)
    else
      Destroy;
  end;
end;

function TDextHttpSysRequest.GetBodyStream: TStream;
var
  PChunk: PHTTP_DATA_CHUNK_INMEMORY;
  I: Integer;
  BytesReceived: ULONG;
  Ret: ULONG;
  TempBuf: TBytes;
begin
  if FBodyStream = nil then
    FBodyStream := TMemoryStream.Create;

  if not FBodyRead then
  begin
    FBodyRead := True;
    
    // 1. Copy pre-allocated body chunks
    if (FRequest.EntityChunkCount > 0) and (FRequest.pEntityChunks <> nil) then
    begin
      PChunk := PHTTP_DATA_CHUNK_INMEMORY(FRequest.pEntityChunks);
      for I := 0 to FRequest.EntityChunkCount - 1 do
      begin
        if PChunk.DataChunkType = hctFromMemory then
        begin
          if (PChunk.pBuffer <> nil) and (PChunk.BufferLength > 0) then
            FBodyStream.WriteBuffer(PChunk.pBuffer^, PChunk.BufferLength);
        end;
        Inc(PChunk);
      end;
    end;
    
    // 2. Read remaining body chunks via HttpReceiveRequestEntityBody
    if (FRequest.Flags and HTTP_REQUEST_FLAG_MORE_ENTITY_BODY_EXISTS) <> 0 then
    begin
      SetLength(TempBuf, 32768);
      while True do
      begin
        BytesReceived := 0;
        Ret := HttpReceiveRequestEntityBody(
          FEngine.FReqQueue,
          FRequest.RequestId,
          0,
          @TempBuf[0],
          Length(TempBuf),
          BytesReceived,
          nil
        );
        
        if Ret = ERROR_SUCCESS then
        begin
          if BytesReceived > 0 then
            FBodyStream.WriteBuffer(TempBuf[0], BytesReceived)
          else
            Break;
        end
        else if Ret = ERROR_HANDLE_EOF then
        begin
          if BytesReceived > 0 then
            FBodyStream.WriteBuffer(TempBuf[0], BytesReceived);
          Break;
        end
        else
          Break;
      end;
    end;
    
    FBodyStream.Position := 0;
  end;
  Result := FBodyStream;
end;

function TDextHttpSysRequest.GetContentLength: Int64;
var
  LenStr: string;
begin
  LenStr := GetHeader('Content-Length');
  if LenStr <> '' then
    Result := StrToInt64Def(LenStr, 0)
  else
    Result := 0;
end;

const
  HTTP_KNOWN_REQUEST_HEADERS: array[0..40] of string = (
    'Cache-Control', 'Connection', 'Date', 'Keep-Alive', 'Pragma', 'Trailer',
    'Transfer-Encoding', 'Upgrade', 'Via', 'Warning', 'Allow', 'Content-Length',
    'Content-Type', 'Content-Encoding', 'Content-Language', 'Content-Location',
    'Content-MD5', 'Content-Range', 'Expires', 'Last-Modified', 'Accept',
    'Accept-Charset', 'Accept-Encoding', 'Accept-Language', 'Authorization',
    'Cookie', 'Expect', 'From', 'Host', 'If-Match', 'If-Modified-Since',
    'If-None-Match', 'If-Range', 'If-Unmodified-Since', 'Max-Forwards',
    'Proxy-Authorization', 'Referer', 'Range', 'TE', 'Translate', 'User-Agent'
  );

  HTTP_KNOWN_RESPONSE_HEADERS: array[0..29] of string = (
    'Cache-Control', 'Connection', 'Date', 'Keep-Alive', 'Pragma', 'Trailer',
    'Transfer-Encoding', 'Upgrade', 'Via', 'Warning', 'Allow', 'Content-Length',
    'Content-Type', 'Content-Encoding', 'Content-Language', 'Content-Location',
    'Content-MD5', 'Content-Range', 'Expires', 'Last-Modified', 'Accept-Ranges',
    'Age', 'ETag', 'Location', 'Proxy-Authenticate', 'Retry-After', 'Server',
    'Set-Cookie', 'Vary', 'Www-Authenticate'
  );

function TDextHttpSysRequest.GetHeader(const AName: string): string;
var
  Index: Integer;
  I: Integer;
  UnknownName: string;
begin
  Result := '';
  // Check known headers
  if KnownRequestHeadersMapGlobal.TryGetValue(AName, Index) then
  begin
    if FRequest.Headers.KnownHeaders[Index].RawValueLength > 0 then
    begin
      SetString(Result, PAnsiChar(FRequest.Headers.KnownHeaders[Index].pRawValue), FRequest.Headers.KnownHeaders[Index].RawValueLength);
      Exit;
    end;
  end;

  // Check unknown headers
  if (FRequest.Headers.UnknownHeaderCount > 0) and (FRequest.Headers.pUnknownHeaders <> nil) then
  begin
    for I := 0 to FRequest.Headers.UnknownHeaderCount - 1 do
    begin
      SetString(UnknownName, PAnsiChar(PHTTP_UNKNOWN_HEADER_ARRAY(FRequest.Headers.pUnknownHeaders)^[I].pName), PHTTP_UNKNOWN_HEADER_ARRAY(FRequest.Headers.pUnknownHeaders)^[I].NameLength);
      if SameText(UnknownName, AName) then
      begin
        SetString(Result, PAnsiChar(PHTTP_UNKNOWN_HEADER_ARRAY(FRequest.Headers.pUnknownHeaders)^[I].pRawValue), PHTTP_UNKNOWN_HEADER_ARRAY(FRequest.Headers.pUnknownHeaders)^[I].RawValueLength);
        Exit;
      end;
    end;
  end;
end;

procedure TDextHttpSysRequest.PopulateHeaders(ADict: TDictionary<string, string>);
var
  I: Integer;
  Val: string;
  UnknownName: string;
begin
  for I := 0 to 40 do
  begin
    if FRequest.Headers.KnownHeaders[I].RawValueLength > 0 then
    begin
      SetString(Val, PAnsiChar(FRequest.Headers.KnownHeaders[I].pRawValue), FRequest.Headers.KnownHeaders[I].RawValueLength);
      ADict.AddOrSetValue(HTTP_KNOWN_REQUEST_HEADERS[I], Val);
    end;
  end;

  if (FRequest.Headers.UnknownHeaderCount > 0) and (FRequest.Headers.pUnknownHeaders <> nil) then
  begin
    for I := 0 to FRequest.Headers.UnknownHeaderCount - 1 do
    begin
      SetString(UnknownName, PAnsiChar(PHTTP_UNKNOWN_HEADER_ARRAY(FRequest.Headers.pUnknownHeaders)^[I].pName), PHTTP_UNKNOWN_HEADER_ARRAY(FRequest.Headers.pUnknownHeaders)^[I].NameLength);
      SetString(Val, PAnsiChar(PHTTP_UNKNOWN_HEADER_ARRAY(FRequest.Headers.pUnknownHeaders)^[I].pRawValue), PHTTP_UNKNOWN_HEADER_ARRAY(FRequest.Headers.pUnknownHeaders)^[I].RawValueLength);
      ADict.AddOrSetValue(UnknownName, Val);
    end;
  end;
end;

function TDextHttpSysRequest.GetMethod: string;
begin
  case FRequest.Verb of
    HttpVerbGET: Result := 'GET';
    HttpVerbPOST: Result := 'POST';
    HttpVerbPUT: Result := 'PUT';
    HttpVerbDELETE: Result := 'DELETE';
    HttpVerbOPTIONS: Result := 'OPTIONS';
    HttpVerbHEAD: Result := 'HEAD';
    HttpVerbTRACE: Result := 'TRACE';
    HttpVerbCONNECT: Result := 'CONNECT';
  else
    if FRequest.pUnknownVerb <> nil then
      SetString(Result, PAnsiChar(FRequest.pUnknownVerb), FRequest.UnknownVerbLength)
    else
      Result := 'GET';
  end;
end;

function TDextHttpSysRequest.GetPath: string;
begin
  if FRequest.CookedUrl.pAbsPath <> nil then
    SetString(Result, FRequest.CookedUrl.pAbsPath, FRequest.CookedUrl.AbsPathLength div SizeOf(WideChar))
  else
    Result := '/';
end;

// Forward request implementation properties
function TDextHttpSysRequest.GetQueryString: string;
begin
  if FRequest.CookedUrl.pQueryString <> nil then
    SetString(Result, FRequest.CookedUrl.pQueryString, FRequest.CookedUrl.QueryStringLength div SizeOf(WideChar))
  else
    Result := '';
end;

{ TDextHttpSysResponse }

constructor TDextHttpSysResponse.Create(AEngine: TDextHttpSysEngine; AReqQueue: THandle; ARequestId: HTTP_REQUEST_ID);
begin
  inherited Create;
  FEngine := AEngine;
  FReqQueue := AReqQueue;
  FRequestId := ARequestId;
  FHeadersSent := False;
  FStatusCode := 200;

  FReasonBuffer[0] := 'O';
  FReasonBuffer[1] := 'K';
  FReasonBuffer[2] := #0;
  FReasonLen := 2;

  FHeaderDataLen := 0;
  FillChar(FHeaderValues, SizeOf(FHeaderValues), 0);

  if Assigned(FEngine) then
    FBodyBuffer := FEngine.BufferPool.Acquire
  else
    FBodyBuffer := nil;
end;

destructor TDextHttpSysResponse.Destroy;
begin
  if FBodyBuffer <> nil then
  begin
    if Assigned(FEngine) then
      FEngine.BufferPool.Release(FBodyBuffer)
    else
      FBodyBuffer.Free;
  end;
  inherited;
end;

procedure TDextHttpSysResponse.Init(AEngine: TDextHttpSysEngine; AReqQueue: THandle; ARequestId: HTTP_REQUEST_ID);
begin
  FEngine := AEngine;
  FReqQueue := AReqQueue;
  FRequestId := ARequestId;
  FHeadersSent := False;
  FStatusCode := 200;

  FReasonBuffer[0] := 'O';
  FReasonBuffer[1] := 'K';
  FReasonBuffer[2] := #0;
  FReasonLen := 2;

  FHeaderDataLen := 0;
  FillChar(FHeaderValues, SizeOf(FHeaderValues), 0);

  if FBodyBuffer = nil then
  begin
    if Assigned(FEngine) then
      FBodyBuffer := FEngine.BufferPool.Acquire;
  end
  else
  begin
    FBodyBuffer.Position := 0;
  end;
end;

function TDextHttpSysResponse._Release: Integer;
begin
  Result := TInterlocked.Decrement(FRefCount);
  if Result = 0 then
  begin
    if Assigned(FEngine) then
      FEngine.RecycleResponse(Self)
    else
      Destroy;
  end;
end;

procedure TDextHttpSysResponse.SetHeaderInt(AIndex: Integer; AValue: Int64);
var
  Temp: array[0..31] of AnsiChar;
  P: PAnsiChar;
  Val: Int64;
  Len: Integer;
begin
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');

  Val := AValue;
  P := @Temp[31];
  P^ := #0;
  Len := 0;
  if Val = 0 then
  begin
    Dec(P);
    P^ := '0';
    Inc(Len);
  end
  else
  begin
    while Val > 0 do
    begin
      Dec(P);
      P^ := AnsiChar(Ord('0') + (Val mod 10));
      Val := Val div 10;
      Inc(Len);
    end;
  end;

  if FHeaderDataLen + Len >= SizeOf(FHeaderData) then
    Exit;

  Move(P^, FHeaderData[FHeaderDataLen], Len);
  FHeaderData[FHeaderDataLen + Len] := #0;
  
  FHeaderValues[AIndex].Offset := FHeaderDataLen;
  FHeaderValues[AIndex].Length := Len;
  FHeaderDataLen := FHeaderDataLen + Len + 1;
end;

procedure TDextHttpSysResponse.Close;
var
  Response: HTTP_RESPONSE;
  Chunk: HTTP_DATA_CHUNK_INMEMORY;
  BytesSent: ULONG;
  Ret: ULONG;
  I: Integer;
begin
  if not FHeadersSent then
  begin
    FillChar(Response, SizeOf(Response), 0);
    Response.StatusCode := FStatusCode;
    Response.ReasonLength := FReasonLen;
    Response.pReason := @FReasonBuffer[0];
    Response.Version.MajorVersion := 1;
    Response.Version.MinorVersion := 1;

    if FHeaderValues[11].Length = 0 then
    begin
      if FBodyBuffer <> nil then
        SetHeaderInt(11, FBodyBuffer.Position)
      else
        SetHeaderInt(11, 0);
    end;

    for I := 0 to 29 do
    begin
      if FHeaderValues[I].Length > 0 then
      begin
        Response.Headers.KnownHeaders[I].pRawValue := @FHeaderData[FHeaderValues[I].Offset];
        Response.Headers.KnownHeaders[I].RawValueLength := FHeaderValues[I].Length;
      end;
    end;

    if (FBodyBuffer <> nil) and (FBodyBuffer.Position > 0) then
    begin
      FillChar(Chunk, SizeOf(Chunk), 0);
      Chunk.DataChunkType := hctFromMemory;
      Chunk.pBuffer := FBodyBuffer.Memory;
      Chunk.BufferLength := FBodyBuffer.Position;

      Response.EntityChunkCount := 1;
      Response.pEntityChunks := @Chunk;
    end;

    Ret := HttpSendHttpResponse(
      FReqQueue,
      FRequestId,
      0,
      @Response,
      nil,
      BytesSent,
      nil,
      0,
      nil,
      nil
    );
    if Ret <> ERROR_SUCCESS then
      raise EOSError.Create('HttpSendHttpResponse failed with error code: ' + IntToStr(Ret));

    FHeadersSent := True;
  end
  else
  begin
    if (FBodyBuffer <> nil) and (FBodyBuffer.Position > 0) then
    begin
      FillChar(Chunk, SizeOf(Chunk), 0);
      Chunk.DataChunkType := hctFromMemory;
      Chunk.pBuffer := FBodyBuffer.Memory;
      Chunk.BufferLength := FBodyBuffer.Position;

      Ret := HttpSendResponseEntityBody(
        FReqQueue,
        FRequestId,
        0,
        1,
        @Chunk,
        BytesSent,
        nil,
        nil,
        nil,
        nil
      );
    end
    else
    begin
      Ret := HttpSendResponseEntityBody(
        FReqQueue,
        FRequestId,
        0,
        0,
        nil,
        BytesSent,
        nil,
        nil,
        nil,
        nil
      );
    end;
    if Ret <> ERROR_SUCCESS then
      raise EOSError.Create('HttpSendResponseEntityBody (Finalize) failed with error code: ' + IntToStr(Ret));
  end;
end;

procedure TDextHttpSysResponse.Flush;
var
  Chunk: HTTP_DATA_CHUNK_INMEMORY;
  Response: HTTP_RESPONSE;
  BytesSent: ULONG;
  Ret: ULONG;
  I: Integer;
begin
  if FHeadersSent then Exit;

  FillChar(Response, SizeOf(Response), 0);
  Response.StatusCode := FStatusCode;
  Response.ReasonLength := FReasonLen;
  Response.pReason := @FReasonBuffer[0];
  Response.Version.MajorVersion := 1;
  Response.Version.MinorVersion := 1;

  for I := 0 to 29 do
  begin
    if FHeaderValues[I].Length > 0 then
    begin
      Response.Headers.KnownHeaders[I].pRawValue := @FHeaderData[FHeaderValues[I].Offset];
      Response.Headers.KnownHeaders[I].RawValueLength := FHeaderValues[I].Length;
    end;
  end;

  if (FBodyBuffer <> nil) and (FBodyBuffer.Position > 0) then
  begin
    FillChar(Chunk, SizeOf(Chunk), 0);
    Chunk.DataChunkType := hctFromMemory;
    Chunk.pBuffer := FBodyBuffer.Memory;
    Chunk.BufferLength := FBodyBuffer.Position;

    Response.EntityChunkCount := 1;
    Response.pEntityChunks := @Chunk;
  end;

  Ret := HttpSendHttpResponse(
    FReqQueue,
    FRequestId,
    HTTP_SEND_RESPONSE_FLAG_MORE_DATA,
    @Response,
    nil,
    BytesSent,
    nil,
    0,
    nil,
    nil
  );

  if Ret <> ERROR_SUCCESS then
    raise EOSError.Create('HttpSendHttpResponse failed with error code: ' + IntToStr(Ret));

  FHeadersSent := True;
  if FBodyBuffer <> nil then
    FBodyBuffer.Position := 0;
end;

procedure TDextHttpSysResponse.SendHeaders;
begin
  SendHeadersInternal(False);
end;

procedure TDextHttpSysResponse.SendHeadersInternal(AMoreData: Boolean);
var
  Response: HTTP_RESPONSE;
  BytesSent: ULONG;
  Ret: ULONG;
  Flags: ULONG;
  I: Integer;
begin
  if FHeadersSent then Exit;

  FillChar(Response, SizeOf(Response), 0);
  Response.StatusCode := FStatusCode;
  Response.ReasonLength := FReasonLen;
  Response.pReason := @FReasonBuffer[0];
  Response.Version.MajorVersion := 1;
  Response.Version.MinorVersion := 1;

  for I := 0 to 29 do
  begin
    if FHeaderValues[I].Length > 0 then
    begin
      Response.Headers.KnownHeaders[I].pRawValue := @FHeaderData[FHeaderValues[I].Offset];
      Response.Headers.KnownHeaders[I].RawValueLength := FHeaderValues[I].Length;
    end;
  end;

  if AMoreData then
    Flags := HTTP_SEND_RESPONSE_FLAG_MORE_DATA
  else
    Flags := 0;

  Ret := HttpSendHttpResponse(
    FReqQueue,
    FRequestId,
    Flags,
    @Response,
    nil,
    BytesSent,
    nil,
    0,
    nil,
    nil
  );

  if Ret <> ERROR_SUCCESS then
    raise EOSError.Create('HttpSendHttpResponse failed with error code: ' + IntToStr(Ret));

  FHeadersSent := True;
end;

procedure TDextHttpSysResponse.SetHeader(const AName, AValue: string);
var
  Index: Integer;
  Written: Integer;
begin
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');

  if KnownResponseHeadersMapGlobal.TryGetValue(AName, Index) then
  begin
    if FHeaderDataLen + Length(AValue) * 3 + 1 >= SizeOf(FHeaderData) then
      Exit;

    Written := WideCharToMultiByte(CP_UTF8, 0, PChar(AValue), Length(AValue), @FHeaderData[FHeaderDataLen], SizeOf(FHeaderData) - FHeaderDataLen - 1, nil, nil);
    if Written > 0 then
    begin
      FHeaderData[FHeaderDataLen + Written] := #0;
      FHeaderValues[Index].Offset := FHeaderDataLen;
      FHeaderValues[Index].Length := Written;
      FHeaderDataLen := FHeaderDataLen + Written + 1;
    end;
    Exit;
  end;
end;

procedure TDextHttpSysResponse.SetStatus(ACode: Integer; const AReason: string);
var
  ReasonStr: string;
begin
  if FHeadersSent then
    raise EInvalidOp.Create('Headers already sent');
  FStatusCode := ACode;
  if AReason <> '' then
    ReasonStr := AReason
  else
    ReasonStr := 'OK';

  FReasonLen := WideCharToMultiByte(CP_UTF8, 0, PChar(ReasonStr), Length(ReasonStr), @FReasonBuffer[0], SizeOf(FReasonBuffer) - 1, nil, nil);
  FReasonBuffer[FReasonLen] := #0;
end;

procedure TDextHttpSysResponse.Write(const ABuffer: TBytes; AOffset, ACount: Integer);
var
  Chunk: HTTP_DATA_CHUNK_INMEMORY;
  BytesSent: ULONG;
  Ret: ULONG;
begin
  if ACount <= 0 then Exit;

  if FHeadersSent then
  begin
    FillChar(Chunk, SizeOf(Chunk), 0);
    Chunk.DataChunkType := hctFromMemory;
    Chunk.pBuffer := @ABuffer[AOffset];
    Chunk.BufferLength := ACount;

    Ret := HttpSendResponseEntityBody(
      FReqQueue,
      FRequestId,
      HTTP_SEND_RESPONSE_FLAG_MORE_DATA,
      1,
      @Chunk,
      BytesSent,
      nil,
      nil,
      nil,
      nil
    );
    if Ret <> ERROR_SUCCESS then
      raise EOSError.Create('HttpSendResponseEntityBody failed with error code: ' + IntToStr(Ret));
  end
  else
  begin
    FBodyBuffer.WriteBuffer(ABuffer[AOffset], ACount);
  end;
end;

{ TDextHttpSysWebSocketConnection }

constructor TDextHttpSysWebSocketConnection.Create(AConnectionId: UInt64; AReqQueue: THandle; ARequestId: HTTP_REQUEST_ID; const ASecWebSocketKey: string);
var
  Response: HTTP_RESPONSE;
  AcceptKey: string;
  AcceptKeyAnsi: AnsiString;
  UpgradeAnsi: AnsiString;
  ConnectionAnsi: AnsiString;
  SecWebSocketAcceptNameAnsi: AnsiString;
  UnknownHeader: HTTP_UNKNOWN_HEADER;
  BytesSent: ULONG;
  Ret: ULONG;
  ReasonStrAnsi: AnsiString;
begin
  inherited Create;
  FConnectionId := AConnectionId;
  FReqQueue := AReqQueue;
  FRequestId := ARequestId;
  FClosed := False;

  if ASecWebSocketKey <> '' then
  begin
    AcceptKey := TWebSocketHandshake.ComputeAcceptKey(ASecWebSocketKey);
    AcceptKeyAnsi := AnsiString(AcceptKey);
    UpgradeAnsi := 'websocket';
    ConnectionAnsi := 'Upgrade';
    SecWebSocketAcceptNameAnsi := 'Sec-WebSocket-Accept';
    ReasonStrAnsi := 'Switching Protocols';

    FillChar(Response, SizeOf(Response), 0);
    Response.StatusCode := 101;
    Response.ReasonLength := Length(ReasonStrAnsi);
    Response.pReason := PAnsiChar(ReasonStrAnsi);
    Response.Version.MajorVersion := 1;
    Response.Version.MinorVersion := 1;

    // Set known header 'Upgrade' (index 7)
    Response.Headers.KnownHeaders[7].pRawValue := PAnsiChar(UpgradeAnsi);
    Response.Headers.KnownHeaders[7].RawValueLength := Length(UpgradeAnsi);

    // Set known header 'Connection' (index 1)
    Response.Headers.KnownHeaders[1].pRawValue := PAnsiChar(ConnectionAnsi);
    Response.Headers.KnownHeaders[1].RawValueLength := Length(ConnectionAnsi);

    // Set unknown header 'Sec-WebSocket-Accept'
    UnknownHeader.NameLength := Length(SecWebSocketAcceptNameAnsi);
    UnknownHeader.RawValueLength := Length(AcceptKeyAnsi);
    UnknownHeader.pName := PAnsiChar(SecWebSocketAcceptNameAnsi);
    UnknownHeader.pRawValue := PAnsiChar(AcceptKeyAnsi);

    Response.Headers.UnknownHeaderCount := 1;
    Response.Headers.pUnknownHeaders := @UnknownHeader;

    Ret := HttpSendHttpResponse(
      FReqQueue,
      FRequestId,
      HTTP_SEND_RESPONSE_FLAG_OPAQUE,
      @Response,
      nil,
      BytesSent,
      nil,
      0,
      nil,
      nil
    );
    if Ret <> ERROR_SUCCESS then
      raise EOSError.Create('HttpSendHttpResponse (Opaque Upgrade) failed with error: ' + IntToStr(Ret));
  end;
end;

destructor TDextHttpSysWebSocketConnection.Destroy;
begin
  Close(1000);
  inherited;
end;

function TDextHttpSysWebSocketConnection.GetConnectionId: UInt64;
begin
  Result := FConnectionId;
end;

procedure TDextHttpSysWebSocketConnection.SendText(const AText: string);
var
  FrameBytes: TBytes;
  Chunk: HTTP_DATA_CHUNK_INMEMORY;
  BytesSent: ULONG;
  Ret: ULONG;
begin
  if FClosed then Exit;
  FrameBytes := TWebSocketFrameCodec.EncodeText(AText);
  if Length(FrameBytes) = 0 then Exit;

  FillChar(Chunk, SizeOf(Chunk), 0);
  Chunk.DataChunkType := hctFromMemory;
  Chunk.pBuffer := @FrameBytes[0];
  Chunk.BufferLength := Length(FrameBytes);

  Ret := HttpSendResponseEntityBody(
    FReqQueue,
    FRequestId,
    HTTP_SEND_RESPONSE_FLAG_MORE_DATA,
    1,
    @Chunk,
    BytesSent,
    nil,
    nil,
    nil,
    nil
  );
  if Ret <> ERROR_SUCCESS then
    raise EOSError.Create('HttpSendResponseEntityBody failed with error: ' + IntToStr(Ret));
end;

procedure TDextHttpSysWebSocketConnection.SendBinary(const AData: TBytes);
var
  FrameBytes: TBytes;
  Chunk: HTTP_DATA_CHUNK_INMEMORY;
  BytesSent: ULONG;
  Ret: ULONG;
begin
  if FClosed then Exit;
  FrameBytes := TWebSocketFrameCodec.EncodeBinary(AData);
  if Length(FrameBytes) = 0 then Exit;

  FillChar(Chunk, SizeOf(Chunk), 0);
  Chunk.DataChunkType := hctFromMemory;
  Chunk.pBuffer := @FrameBytes[0];
  Chunk.BufferLength := Length(FrameBytes);

  Ret := HttpSendResponseEntityBody(
    FReqQueue,
    FRequestId,
    HTTP_SEND_RESPONSE_FLAG_MORE_DATA,
    1,
    @Chunk,
    BytesSent,
    nil,
    nil,
    nil,
    nil
  );
  if Ret <> ERROR_SUCCESS then
    raise EOSError.Create('HttpSendResponseEntityBody failed with error: ' + IntToStr(Ret));
end;

procedure TDextHttpSysWebSocketConnection.Close(AStatusCode: Word; const AReason: string);
var
  FrameBytes: TBytes;
  Chunk: HTTP_DATA_CHUNK_INMEMORY;
  BytesSent: ULONG;
begin
  if FClosed then Exit;
  FClosed := True;

  FrameBytes := TWebSocketFrameCodec.EncodeClose(AStatusCode, AReason);
  if Length(FrameBytes) > 0 then
  begin
    FillChar(Chunk, SizeOf(Chunk), 0);
    Chunk.DataChunkType := hctFromMemory;
    Chunk.pBuffer := @FrameBytes[0];
    Chunk.BufferLength := Length(FrameBytes);

    HttpSendResponseEntityBody(
      FReqQueue,
      FRequestId,
      HTTP_SEND_RESPONSE_FLAG_DISCONNECT,
      1,
      @Chunk,
      BytesSent,
      nil,
      nil,
      nil,
      nil
    );
  end;
end;

function TDextHttpSysWebSocketConnection.Receive(var ABuffer: TBytes; AOffset, ACount: Integer): Integer;
var
  BytesReceived: ULONG;
  Ret: ULONG;
begin
  if FClosed then Exit(0);
  
  BytesReceived := 0;
  Ret := HttpReceiveRequestEntityBody(
    FReqQueue,
    FRequestId,
    0,
    @ABuffer[AOffset],
    ACount,
    BytesReceived,
    nil
  );
  if Ret = ERROR_SUCCESS then
    Result := BytesReceived
  else if Ret = ERROR_HANDLE_EOF then
    Result := 0
  else
    Result := -1;
end;

{ TDextHttpSysConnection }

constructor TDextHttpSysConnection.Create(const ARequest: HTTP_REQUEST; AReqQueue: THandle);
var
  I: Integer;
  UnknownName: string;
begin
  inherited Create;
  FConnectionId := ARequest.ConnectionId;
  FSecure := ARequest.pSslInfo <> nil;
  FLocalPort := 80;
  FRemotePort := 0;
  FRemoteAddress := '';
  FReqQueue := AReqQueue;
  FRequestId := ARequest.RequestId;

  FSecWebSocketKey := '';
  if (ARequest.Headers.UnknownHeaderCount > 0) and (ARequest.Headers.pUnknownHeaders <> nil) then
  begin
    for I := 0 to ARequest.Headers.UnknownHeaderCount - 1 do
    begin
      SetString(UnknownName, PAnsiChar(PHTTP_UNKNOWN_HEADER_ARRAY(ARequest.Headers.pUnknownHeaders)^[I].pName), PHTTP_UNKNOWN_HEADER_ARRAY(ARequest.Headers.pUnknownHeaders)^[I].NameLength);
      if SameText(UnknownName, 'Sec-WebSocket-Key') then
      begin
        SetString(FSecWebSocketKey, PAnsiChar(PHTTP_UNKNOWN_HEADER_ARRAY(ARequest.Headers.pUnknownHeaders)^[I].pRawValue), PHTTP_UNKNOWN_HEADER_ARRAY(ARequest.Headers.pUnknownHeaders)^[I].RawValueLength);
        Break;
      end;
    end;
  end;
end;

procedure TDextHttpSysConnection.Close;
begin
  // Handled by request-level response close
end;

function TDextHttpSysConnection.GetConnectionId: UInt64;
begin
  Result := FConnectionId;
end;

function TDextHttpSysConnection.GetLocalPort: Word;
begin
  Result := FLocalPort;
end;

function TDextHttpSysConnection.GetRemoteAddress: string;
begin
  Result := FRemoteAddress;
end;

function TDextHttpSysConnection.GetRemotePort: Word;
begin
  Result := FRemotePort;
end;

function TDextHttpSysConnection.IsSecure: Boolean;
begin
  Result := FSecure;
end;

function TDextHttpSysConnection.SupportsUpgrade: Boolean;
begin
  Result := FSecWebSocketKey <> '';
end;

function TDextHttpSysConnection.UpgradeToWebSocket: IDextWebSocketConnection;
begin
  Result := TDextHttpSysWebSocketConnection.Create(FConnectionId, FReqQueue, FRequestId, FSecWebSocketKey);
end;

{ TDextHttpSysRequestPool }

constructor TDextHttpSysRequestPool.Create(AMaxPoolSize: Integer);
begin
  inherited Create;
  FPool := TList.Create;
  FMaxPoolSize := AMaxPoolSize;
end;

destructor TDextHttpSysRequestPool.Destroy;
var
  Item: Pointer;
begin
  FLock.Enter;
  try
    for Item in FPool do
    begin
      TDextHttpSysRequest(Item).FEngine := nil;
      TDextHttpSysRequest(Item).Free;
    end;
    FPool.Free;
  finally
    FLock.Exit;
  end;
  inherited;
end;

function TDextHttpSysRequestPool.Acquire(AEngine: TDextHttpSysEngine; ARequest: PHTTP_REQUEST): TDextHttpSysRequest;
begin
  Result := nil;
  FLock.Enter;
  try
    if FPool.Count > 0 then
    begin
      Result := TDextHttpSysRequest(FPool.Last);
      FPool.Delete(FPool.Count - 1);
    end;
  finally
    FLock.Exit;
  end;
  if Result = nil then
  begin
    Result := TDextHttpSysRequest.Create(ARequest);
    Result.FEngine := AEngine;
  end
  else
  begin
    Result.Init(AEngine, ARequest);
  end;
end;

procedure TDextHttpSysRequestPool.Release(ARequest: TDextHttpSysRequest);
begin
  if ARequest = nil then Exit;
  FLock.Enter;
  try
    if FPool.Count < FMaxPoolSize then
    begin
      FPool.Add(ARequest);
    end
    else
    begin
      ARequest.FEngine := nil;
      ARequest.Free;
    end;
  finally
    FLock.Exit;
  end;
end;

{ TDextHttpSysResponsePool }

constructor TDextHttpSysResponsePool.Create(AMaxPoolSize: Integer);
begin
  inherited Create;
  FPool := TList.Create;
  FMaxPoolSize := AMaxPoolSize;
end;

destructor TDextHttpSysResponsePool.Destroy;
var
  Item: Pointer;
begin
  FLock.Enter;
  try
    for Item in FPool do
    begin
      TDextHttpSysResponse(Item).FEngine := nil;
      TDextHttpSysResponse(Item).Free;
    end;
    FPool.Free;
  finally
    FLock.Exit;
  end;
  inherited;
end;

function TDextHttpSysResponsePool.Acquire(AEngine: TDextHttpSysEngine; AReqQueue: THandle; ARequestId: HTTP_REQUEST_ID): TDextHttpSysResponse;
begin
  Result := nil;
  FLock.Enter;
  try
    if FPool.Count > 0 then
    begin
      Result := TDextHttpSysResponse(FPool.Last);
      FPool.Delete(FPool.Count - 1);
    end;
  finally
    FLock.Exit;
  end;
  if Result = nil then
  begin
    Result := TDextHttpSysResponse.Create(AEngine, AReqQueue, ARequestId);
  end
  else
  begin
    Result.Init(AEngine, AReqQueue, ARequestId);
  end;
end;

procedure TDextHttpSysResponsePool.Release(AResponse: TDextHttpSysResponse);
begin
  if AResponse = nil then Exit;
  
  if AResponse.FBodyBuffer <> nil then
  begin
    AResponse.FBodyBuffer.Position := 0;
    if AResponse.FBodyBuffer.Size > 65536 then
      AResponse.FBodyBuffer.Size := 65536;
  end;

  FLock.Enter;
  try
    if FPool.Count < FMaxPoolSize then
    begin
      FPool.Add(AResponse);
    end
    else
    begin
      AResponse.FEngine := nil;
      AResponse.Free;
    end;
  finally
    FLock.Exit;
  end;
end;

{ TDextHttpSysWorker }

constructor TDextHttpSysWorker.Create(AEngine: TDextHttpSysEngine; AReqQueue: THandle; const AAffinity: TDextProcessorGroupAffinity);
begin
  inherited Create(True);
  FEngine := AEngine;
  FReqQueue := AReqQueue;
  FAffinity := AAffinity;
  FreeOnTerminate := False;
end;

procedure TDextHttpSysWorker.Execute;
var
  ReqBuffer: TBytes;
  Request: PHTTP_REQUEST;
  BytesReturned: ULONG;
  Ret: ULONG;
  RequestId: HTTP_REQUEST_ID;
  RawRequest: IDextRawRequest;
  RawResponse: IDextRawResponse;
  Connection: IDextServerConnection;
begin
  ApplyGroupAffinityToThread(GetCurrentThread, FAffinity);

  SetLength(ReqBuffer, 16384); // 16KB Request Buffer
  Request := PHTTP_REQUEST(@ReqBuffer[0]);
  RequestId := 0;

  while not Terminated and FEngine.FRunning do
  begin
    FillChar(Request^, SizeOf(HTTP_REQUEST), 0);
    BytesReturned := 0;

    Ret := HttpReceiveHttpRequest(
      FReqQueue,
      RequestId,
      HTTP_RECEIVE_REQUEST_FLAG_COPY_BODY,
      Request,
      Length(ReqBuffer),
      BytesReturned,
      nil
    );

    if Ret = ERROR_SUCCESS then
    begin
      TInterlocked.Increment(FEngine.FTotalRequests);
      TInterlocked.Increment(FEngine.FActiveConnections);

      // Create Request/Response abstractions using pools
      Connection := TDextHttpSysConnection.Create(Request^, FReqQueue);
      RawRequest := FEngine.FRequestPool.Acquire(FEngine, Request);
      RawResponse := FEngine.FResponsePool.Acquire(FEngine, FReqQueue, Request.RequestId);

      try
        if Assigned(FEngine.FOnRequest) then
          FEngine.FOnRequest(Connection, RawRequest, RawResponse);
      finally
        RawResponse.Close;
        RawResponse := nil;
        RawRequest := nil;
        Connection := nil;
        TInterlocked.Decrement(FEngine.FActiveConnections);
      end;

      RequestId := 0;
    end
    else if Ret = ERROR_MORE_DATA then
    begin
      // Grow buffer if headers are too large
      SetLength(ReqBuffer, BytesReturned);
      Request := PHTTP_REQUEST(@ReqBuffer[0]);
    end;
  end;
end;

{ TDextHttpSysEngine }

constructor TDextHttpSysEngine.Create(const AOptions: TServerEngineOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FServerSessionId := 0;
  FUrlGroupId := 0;
  FReqQueue := 0;
  FRunning := False;
  FWorkers := TList.Create;
  FBufferPool := TDextHttpSysBufferPool.Create(64);
  FRequestPool := TDextHttpSysRequestPool.Create(64);
  FResponsePool := TDextHttpSysResponsePool.Create(64);
  InitializeHttpSys;
end;

destructor TDextHttpSysEngine.Destroy;
begin
  Stop;
  FWorkers.Free;
  FRequestPool.Free;
  FResponsePool.Free;
  FBufferPool.Free;
  inherited;
end;

procedure TDextHttpSysEngine.RecycleRequest(ARequest: TDextHttpSysRequest);
begin
  if Assigned(FRequestPool) then
    FRequestPool.Release(ARequest)
  else
    ARequest.Free;
end;

procedure TDextHttpSysEngine.RecycleResponse(AResponse: TDextHttpSysResponse);
begin
  if Assigned(FResponsePool) then
    FResponsePool.Release(AResponse)
  else
    AResponse.Free;
end;

procedure TDextHttpSysEngine.Bind(const AAddress: string; APort: Word);
begin
  FAddress := AAddress;
  FListeningPort := APort;
end;

procedure TDextHttpSysEngine.InitializeHttpSys;
var
  Ret: ULONG;
begin
  Ret := HttpInitialize(HTTPAPI_VERSION_2, HTTP_INITIALIZE_SERVER, nil);
  if Ret <> ERROR_SUCCESS then
    raise EOSError.Create('HttpInitialize failed with error code: ' + IntToStr(Ret));

  Ret := HttpCreateServerSession(HTTPAPI_VERSION_2, FServerSessionId, 0);
  if Ret <> ERROR_SUCCESS then
    raise EOSError.Create('HttpCreateServerSession failed with error code: ' + IntToStr(Ret));

  Ret := HttpCreateUrlGroup(FServerSessionId, FUrlGroupId, 0);
  if Ret <> ERROR_SUCCESS then
    raise EOSError.Create('HttpCreateUrlGroup failed with error code: ' + IntToStr(Ret));

  Ret := HttpCreateRequestQueue(HTTPAPI_VERSION_2, nil, nil, 0, FReqQueue);
  if Ret <> ERROR_SUCCESS then
    raise EOSError.Create('HttpCreateRequestQueue failed with error code: ' + IntToStr(Ret));

  ConfigureTimeouts;
  ConfigureLimits;
end;

procedure TDextHttpSysEngine.ConfigureLimits;
var
  Binding: HTTP_BINDING_INFO;
  Ret: ULONG;
begin
  Binding.Flags := 1;
  Binding.RequestQueueHandle := FReqQueue;

  Ret := HttpSetUrlGroupProperty(
    FUrlGroupId,
    HttpServerBindingProperty,
    @Binding,
    SizeOf(Binding)
  );

  if Ret <> ERROR_SUCCESS then
    raise EOSError.Create('HttpSetUrlGroupProperty (Binding) failed with error code: ' + IntToStr(Ret));
end;

procedure TDextHttpSysEngine.ConfigureTimeouts;
begin
  // Set configuration timeouts if specified in Options
end;

procedure TDextHttpSysEngine.Start;
var
  UrlPrefix: string;
  Ret: ULONG;
  i: Integer;
  ThreadCount: Integer;
  Worker: TDextHttpSysWorker;
  Err: EOSError;
  Affinity: TDextProcessorGroupAffinity;
begin
  if FRunning then Exit;

  // Register prefix
  if (FAddress = '0.0.0.0') or (FAddress = '+') or (FAddress = '') then
    UrlPrefix := Format('http://+:%d/', [FListeningPort])
  else
    UrlPrefix := Format('http://%s:%d/', [FAddress, FListeningPort]);
    
  Ret := HttpAddUrlToUrlGroup(FUrlGroupId, PWideChar(WideString(UrlPrefix)), 0, 0);
  if Ret <> ERROR_SUCCESS then
  begin
    if Ret = 5 then // Access Denied
    begin
      Err := EOSError.Create(
        'HttpAddUrlToUrlGroup failed to register ' + UrlPrefix + ' (Access Denied).' + #13#10 +
        'This error occurs because registering URL prefixes on all interfaces (+ or 0.0.0.0) requires administrative privileges.' + #13#10 +
        'To resolve this:' + #13#10 +
        '1. Run your application as Administrator.' + #13#10 +
        '2. Or register this URL prefix using netsh in an elevated prompt:' + #13#10 +
        '   netsh http add urlacl url=' + UrlPrefix + ' user=Todos' + #13#10 +
        '3. Or configure the server BindAddress to "localhost" or "127.0.0.1" in TServerEngineOptions to run without elevation.'
      );
      Err.ErrorCode := Ret;
      raise Err;
    end
    else
    begin
      Err := EOSError.Create('HttpAddUrlToUrlGroup failed to register ' + UrlPrefix + ' with error code: ' + IntToStr(Ret));
      Err.ErrorCode := Ret;
      raise Err;
    end;
  end;

  FRunning := True;

  // Start Worker Threads
  ThreadCount := FOptions.IoThreadCount;
  if ThreadCount <= 0 then
  begin
    // Auto detect CPU count across all Windows processor groups.
    ThreadCount := GetSystemLogicalProcessorCount;
  end;

  for i := 0 to ThreadCount - 1 do
  begin
    GetProcessorGroupAffinityForWorker(i, Affinity);
    Worker := TDextHttpSysWorker.Create(Self, FReqQueue, Affinity);
    FWorkers.Add(Worker);
    Worker.Start;
  end;
end;

procedure TDextHttpSysEngine.Stop(AGracefulTimeoutMs: Integer);
var
  I: Integer;
  Worker: TDextHttpSysWorker;
begin
  if not FRunning then Exit;

  FRunning := False;

  // Signal and stop request queue
  if FReqQueue <> 0 then
    HttpCloseRequestQueue(FReqQueue);

  // Stop threads
  for I := 0 to FWorkers.Count - 1 do
  begin
    Worker := TDextHttpSysWorker(FWorkers[I]);
    Worker.Terminate;
  end;

  for I := 0 to FWorkers.Count - 1 do
  begin
    Worker := TDextHttpSysWorker(FWorkers[I]);
    Worker.WaitFor;
    Worker.Free;
  end;
  FWorkers.Clear;

  if FUrlGroupId <> 0 then
  begin
    HttpCloseUrlGroup(FUrlGroupId);
    FUrlGroupId := 0;
  end;

  if FServerSessionId <> 0 then
  begin
    HttpCloseServerSession(FServerSessionId);
    FServerSessionId := 0;
  end;

  HttpTerminate(HTTP_INITIALIZE_SERVER, nil);
  FReqQueue := 0;
end;

function TDextHttpSysEngine.GetActiveConnections: Integer;
begin
  Result := FActiveConnections;
end;

function TDextHttpSysEngine.GetListenPort: Word;
begin
  Result := FListeningPort;
end;

function TDextHttpSysEngine.GetTotalRequests: Int64;
begin
  Result := FTotalRequests;
end;

procedure TDextHttpSysEngine.SetOnConnection(const AHandler: TConnectionEventHandler);
begin
  FOnConnection := AHandler;
end;

procedure TDextHttpSysEngine.SetOnDisconnection(const AHandler: TConnectionEventHandler);
begin
  FOnDisconnection := AHandler;
end;

procedure TDextHttpSysEngine.SetOnRequest(const AHandler: TRequestEventHandler);
begin
  FOnRequest := AHandler;
end;

procedure TDextHttpSysEngine.SetOnUpgrade(const AHandler: TUpgradeEventHandler);
begin
  FOnUpgrade := AHandler;
end;

procedure TDextHttpSysEngine.SetConnectionHandler(const AHandler: IConnectionHandler);
begin
  // HTTP.sys is a kernel-mode HTTP listener and does not support raw connection handlers
end;

class function TDextHttpSysEngine.Factory(Port: Integer; Pipeline: TRequestDelegate; Services: IServiceProvider): IWebHost;
begin
  Result := nil;
end;
{$ENDIF}

procedure LoadKnownRequestHeadersMap;
{$IFDEF MSWINDOWS}
var
  i: Integer;
begin
  KnownRequestHeadersMapGlobal := TDictionary<string, Integer>.Create(True, False, 0);
  for i := 0 to 40 do
    KnownRequestHeadersMapGlobal.Add(HTTP_KNOWN_REQUEST_HEADERS[i], i);

  KnownResponseHeadersMapGlobal := TDictionary<string, Integer>.Create(True, False, 0);
  for i := 0 to 29 do
    KnownResponseHeadersMapGlobal.Add(HTTP_KNOWN_RESPONSE_HEADERS[i], i);
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure UnloadKnownRequestHeadersMap;
begin
{$IFDEF MSWINDOWS}
  KnownRequestHeadersMapGlobal.Free;
  KnownResponseHeadersMapGlobal.Free;
{$ENDIF}
end;

initialization
  LoadKnownRequestHeadersMap;

finalization
  UnloadKnownRequestHeadersMap;

end.
