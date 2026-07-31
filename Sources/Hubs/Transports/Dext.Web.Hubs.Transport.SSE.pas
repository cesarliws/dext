{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025-2026 Cesar Romero & Dext Contributors        }
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
{  Created: 2026-01-06                                                      }
{                                                                           }
{  Description:                                                             }
{    Server-Sent Events (SSE) transport for Dext.Web.Hubs.                      }
{    Provides unidirectional server-to-client real-time communication.      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs.Transport.SSE;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.Rtti,
  System.SyncObjs,
  System.SysUtils,
  Dext.Auth.Identity,
  Dext.Collections,
  Dext.Collections.Queue,
  Dext.Collections.Dict,
  Dext.Threading.CancellationToken,
  Dext.Web.Hubs.Connections,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Protocol.Json,
  Dext.Web.Interfaces;

type
  /// <summary>
  /// SSE connection that wraps HTTP response for streaming.
  /// </summary>
  TSSEConnection = class(TInterfacedObject, IHubConnection)
  private
    FConnectionId: string;
    FState: TConnectionState;
    FUser: IClaimsPrincipal;
    FItems: IDictionary<string, TValue>;
    FAbortTokenSource: TCancellationTokenSource;
    FMessageQueue: IQueue<string>;
    FQueueLock: TCriticalSection;
    FClosed: Int64; // 0 = open, 1 = closed (using Integer for TInterlocked)
  public
    constructor Create(const AConnectionId: string;
      const AUser: IClaimsPrincipal = nil);
    destructor Destroy; override;
    
    // IHubConnection
    function GetConnectionId: string;
    function GetTransportType: TTransportType;
    function GetState: TConnectionState;
    function GetUser: IClaimsPrincipal;
    function GetUserIdentifier: string;
    function GetItems: IDictionary<string, TValue>;
    function GetAbortToken: ICancellationToken;
    
    procedure SendAsync(const Message: string);
    procedure Close(const Reason: string = '');
    function IsClosed: Boolean;
    
    // SSE-specific
    function HasPendingMessages: Boolean;
    function DequeueMessage: string;
    procedure SetConnected;
    
    property ConnectionId: string read GetConnectionId;
    property State: TConnectionState read GetState;
    property Closed: Boolean read IsClosed;
  end;
  
  /// <summary>
  /// SSE Transport manager.
  /// Handles SSE connections and message delivery.
  /// </summary>
  TSSETransport = class(TInterfacedObject, IHubTransport)
  private
    FConnections: IDictionary<string, TSSEConnection>;
    FLock: TCriticalSection;
    FOnMessageReceived: TOnMessageReceived;
    FOnConnected: TOnConnectionEvent;
    FOnDisconnected: TOnConnectionEvent;
    FShuttingDown: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    // IHubTransport
    function GetTransportType: TTransportType;
    function IsAvailable: Boolean;
    procedure SendAsync(const ConnectionId, Data: string);
    procedure CloseConnection(const ConnectionId: string; const Reason: string = '');
    procedure SetOnMessageReceived(const Handler: TOnMessageReceived);
    procedure SetOnConnected(const Handler: TOnConnectionEvent);
    procedure SetOnDisconnected(const Handler: TOnConnectionEvent);
    
    // Connection management
    function CreateConnection(const ConnectionId: string;
      const User: IClaimsPrincipal = nil): TSSEConnection;
    function GetConnection(const ConnectionId: string): TSSEConnection;
    procedure RemoveConnection(const ConnectionId: string);
    
    // Shutdown support
    procedure CloseAllConnections;
    function IsShuttingDown: Boolean;
    function GetActiveConnectionCount: Integer;
    
    // Event triggers
    procedure TriggerConnected(const ConnectionId: string);
    procedure TriggerDisconnected(const ConnectionId: string);
    procedure TriggerMessageReceived(const ConnectionId, Data: string);
  end;
  
  /// <summary>
  /// SSE Response Writer.
  /// Writes SSE-formatted events to HTTP response.
  /// </summary>
  TSSEWriter = class
  public
    /// <summary>Writes an SSE event line</summary>
    class procedure WriteEvent(const Response: IHttpResponse; const EventType, Data: string); overload;
    /// <summary>Writes an SSE data-only line</summary>
    class procedure WriteData(const Response: IHttpResponse; const Data: string);
    /// <summary>Writes an SSE comment (for keep-alive)</summary>
    class procedure WriteComment(const Response: IHttpResponse; const Comment: string);
    /// <summary>Writes SSE retry directive</summary>
    class procedure WriteRetry(const Response: IHttpResponse; const Milliseconds: Integer);
    /// <summary>Configures response headers for SSE</summary>
    class procedure ConfigureResponse(const Response: IHttpResponse);
  end;

implementation

{ TSSEConnection }

constructor TSSEConnection.Create(const AConnectionId: string;
  const AUser: IClaimsPrincipal);
begin
  inherited Create;
  FConnectionId := AConnectionId;
  FState := csConnecting;
  FUser := AUser;
  FItems := TCollections.CreateDictionary<string, TValue>;
  FAbortTokenSource := TCancellationTokenSource.Create;
  FMessageQueue := TCollections.CreateQueue<string>;
  FQueueLock := TCriticalSection.Create;
  FClosed := 0;
end;

destructor TSSEConnection.Destroy;
begin
  FAbortTokenSource.Free;
  FUser := nil;
  FQueueLock.Free;
  // FMessageQueue is ARC managed
  // FItems is ARC
  inherited;
end;

function TSSEConnection.GetConnectionId: string;
begin
  Result := FConnectionId;
end;

function TSSEConnection.GetTransportType: TTransportType;
begin
  Result := ttServerSentEvents;
end;

function TSSEConnection.GetState: TConnectionState;
begin
  Result := FState;
end;

function TSSEConnection.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

function TSSEConnection.GetUserIdentifier: string;
begin
  if FUser <> nil then
    Result := FUser.FindClaim('sub').Value // Standard claim for user ID
  else
    Result := '';
end;

function TSSEConnection.GetItems: IDictionary<string, TValue>;
begin
  Result := FItems;
end;

function TSSEConnection.GetAbortToken: ICancellationToken;
begin
  Result := FAbortTokenSource.Token;
end;

procedure TSSEConnection.SendAsync(const Message: string);
begin
  if FState <> csConnected then Exit;
  
  FQueueLock.Enter;
  try
    FMessageQueue.Enqueue(Message);
  finally
    FQueueLock.Leave;
  end;
end;

procedure TSSEConnection.Close(const Reason: string);
begin
  FState := csDisconnected;
  FAbortTokenSource.Cancel;
  TInterlocked.Exchange(FClosed, 1);
end;

function TSSEConnection.IsClosed: Boolean;
begin
  Result := TInterlocked.Read(FClosed) = 1;
end;

function TSSEConnection.HasPendingMessages: Boolean;
begin
  // Safety check: if closed, don't access the lock
  if TInterlocked.Read(FClosed) = 1 then
    Exit(False);
    
  FQueueLock.Enter;
  try
    Result := FMessageQueue.Count > 0;
  finally
    FQueueLock.Leave;
  end;
end;

function TSSEConnection.DequeueMessage: string;
begin
  // Safety check: if closed, don't access the lock
  if TInterlocked.Read(FClosed) = 1 then
    Exit('');
    
  FQueueLock.Enter;
  try
    if FMessageQueue.Count > 0 then
      Result := FMessageQueue.Dequeue
    else
      Result := '';
  finally
    FQueueLock.Leave;
  end;
end;

procedure TSSEConnection.SetConnected;
begin
  FState := csConnected;
end;

{ TSSETransport }

constructor TSSETransport.Create;
begin
  inherited Create;
  FConnections := TCollections.CreateDictionary<string, TSSEConnection>;
  FLock := TCriticalSection.Create;
  FShuttingDown := False;
end;

destructor TSSETransport.Destroy;
var
  WaitCount: Integer;
begin
  // Signal all connections to close
  CloseAllConnections;
  
  // Wait for SSE loops to exit and clean up connections (max 5 seconds)
  WaitCount := 0;
  while (GetActiveConnectionCount > 0) and (WaitCount < 50) do
  begin
    Sleep(100);
    Inc(WaitCount);
  end;
  
  // Now safe to free resources
  FLock.Enter;
  try
    // FConnections is ARC
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
end;

procedure TSSETransport.CloseAllConnections;
var
  Conn: TSSEConnection;
begin
  FShuttingDown := True;
  FLock.Enter;
  try
    for Conn in FConnections.Values do
      Conn.Close('Server shutting down');
  finally
    FLock.Leave;
  end;
end;

function TSSETransport.IsShuttingDown: Boolean;
begin
  Result := FShuttingDown;
end;

function TSSETransport.GetActiveConnectionCount: Integer;
begin
  FLock.Enter;
  try
    Result := FConnections.Count;
  finally
    FLock.Leave;
  end;
end;

function TSSETransport.GetTransportType: TTransportType;
begin
  Result := ttServerSentEvents;
end;

function TSSETransport.IsAvailable: Boolean;
begin
  Result := True; // SSE is always available with HTTP
end;

procedure TSSETransport.SendAsync(const ConnectionId, Data: string);
var
  Conn: TSSEConnection;
begin
  FLock.Enter;
  try
    if FConnections.TryGetValue(ConnectionId, Conn) then
      Conn.SendAsync(Data);
  finally
    FLock.Leave;
  end;
end;

procedure TSSETransport.CloseConnection(const ConnectionId: string; const Reason: string);
var
  Conn: TSSEConnection;
begin
  FLock.Enter;
  try
    if FConnections.TryGetValue(ConnectionId, Conn) then
      Conn.Close(Reason);
  finally
    FLock.Leave;
  end;
end;

procedure TSSETransport.SetOnMessageReceived(const Handler: TOnMessageReceived);
begin
  FOnMessageReceived := Handler;
end;

procedure TSSETransport.SetOnConnected(const Handler: TOnConnectionEvent);
begin
  FOnConnected := Handler;
end;

procedure TSSETransport.SetOnDisconnected(const Handler: TOnConnectionEvent);
begin
  FOnDisconnected := Handler;
end;

function TSSETransport.CreateConnection(const ConnectionId: string;
  const User: IClaimsPrincipal): TSSEConnection;
begin
  Result := TSSEConnection.Create(ConnectionId, User);
  
  FLock.Enter;
  try
    FConnections.AddOrSetValue(ConnectionId, Result);
  finally
    FLock.Leave;
  end;
end;

function TSSETransport.GetConnection(const ConnectionId: string): TSSEConnection;
begin
  FLock.Enter;
  try
    if not FConnections.TryGetValue(ConnectionId, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

procedure TSSETransport.RemoveConnection(const ConnectionId: string);
begin
  FLock.Enter;
  try
    FConnections.Remove(ConnectionId);
  finally
    FLock.Leave;
  end;
  
  TriggerDisconnected(ConnectionId);
end;

procedure TSSETransport.TriggerConnected(const ConnectionId: string);
begin
  if Assigned(FOnConnected) then
    FOnConnected(ConnectionId);
end;

procedure TSSETransport.TriggerDisconnected(const ConnectionId: string);
begin
  if Assigned(FOnDisconnected) then
    FOnDisconnected(ConnectionId);
end;

procedure TSSETransport.TriggerMessageReceived(const ConnectionId, Data: string);
begin
  if Assigned(FOnMessageReceived) then
    FOnMessageReceived(ConnectionId, Data);
end;

{ TSSEWriter }

class procedure TSSEWriter.ConfigureResponse(const Response: IHttpResponse);
begin
  { Per WHATWG / W3C Server-Sent Events spec, the event stream MUST be
    encoded as UTF-8. Browsers' EventSource rejects any response whose
    Content-Type charset parameter is anything other than utf-8. Without
    an explicit charset here, the Indy backend emits
    'text/event-stream; charset=ISO-8859-1' (inherited from the server's
    ANSI codepage default), and the browser aborts the connection with
    a console error:
      "EventSource's response has a charset ('iso-8859-1') that is not
       UTF-8. Aborting the connection."
    Set charset=utf-8 explicitly so every SSE endpoint using TSSEWriter
    is spec-compliant regardless of the server's locale. }
  Response.SetContentType('text/event-stream; charset=utf-8');
  Response.AddHeader('Cache-Control', 'no-cache');
  Response.AddHeader('Connection', 'keep-alive');
  Response.AddHeader('X-Accel-Buffering', 'no'); // Disable Nginx buffering
end;

class procedure TSSEWriter.WriteEvent(const Response: IHttpResponse;
  const EventType, Data: string);
begin
  Response.Write('event: ' + EventType + #10);
  Response.Write('data: ' + Data + #10#10);
end;

class procedure TSSEWriter.WriteData(const Response: IHttpResponse;
  const Data: string);
begin
  Response.Write('data: ' + Data + #10#10);
end;

class procedure TSSEWriter.WriteComment(const Response: IHttpResponse;
  const Comment: string);
begin
  Response.Write(': ' + Comment + #10#10);
end;

class procedure TSSEWriter.WriteRetry(const Response: IHttpResponse;
  const Milliseconds: Integer);
begin
  Response.Write('retry: ' + IntToStr(Milliseconds) + #10#10);
end;

end.
