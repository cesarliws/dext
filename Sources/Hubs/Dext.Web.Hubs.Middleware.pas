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
{    Hub middleware for handling Hub endpoints and SSE connections.         }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs.Middleware;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.JSON,
  System.Rtti,
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.Web.Hubs.Clients,
  Dext.Web.Hubs.Connections,
  Dext.Web.Hubs.Context,
  Dext.Web.Hubs.Hub,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Protocol.Json,
  Dext.Web.Hubs.Transport.SSE,
  Dext.Web.Hubs.Transport.WebSocket,
  Dext.Web.Hubs.Types,
  Dext.Web.Interfaces,
  Dext.Core.Reflection;

type
  /// <summary>
  /// Hub endpoint configuration.
  /// </summary>
  THubEndpoint = record
    Path: string;
    HubClass: THubClass;
  end;
  
  /// <summary>
  /// Hub dispatcher that routes requests to Hub methods.
  /// </summary>
  THubDispatcher = class
  private
    FHubClass: THubClass;
    FConnectionManager: IConnectionManager;
    FGroupManager: IGroupManager;
    FSSETransport: TSSETransport;
    FProtocol: TJsonHubProtocol;
  public
    constructor Create(AHubClass: THubClass;
                       const AConnectionManager: IConnectionManager;
                       const AGroupManager: IGroupManager;
                       ASSETransport: TSSETransport);
    destructor Destroy; override;
    
    /// <summary>Invokes a method on the Hub</summary>
    function InvokeMethod(const ConnectionId, MethodName: string;
                          const Args: TArray<TValue>): TValue;
    
    /// <summary>Triggers OnConnectedAsync</summary>
    procedure OnConnected(const ConnectionId: string);
    
    /// <summary>Triggers OnDisconnectedAsync</summary>
    procedure OnDisconnected(const ConnectionId: string; const Error: Exception);
    
    property HubClass: THubClass read FHubClass;
    property ConnectionManager: IConnectionManager read FConnectionManager;
    property GroupManager: IGroupManager read FGroupManager;
    property SSETransport: TSSETransport read FSSETransport;
  end;
  
  /// <summary>
  /// Middleware that handles Hub HTTP endpoints.
  /// Endpoints:
  ///   POST /hubs/{hubName}/negotiate - Returns connectionId
  ///   GET  /hubs/{hubName} - SSE stream
  ///   POST /hubs/{hubName} - Invoke Hub method
  /// </summary>
  THubMiddleware = class
  private
    FHubs: IDictionary<string, THubDispatcher>;
    FConnectionManager: IConnectionManager;
    FGroupManager: IGroupManager;
    FSSETransport: TSSETransport;
    FWebSocketTransport: TWebSocketHubTransport;
    FConnectionDispatchers: IDictionary<string, THubDispatcher>;
    
    procedure HandleNegotiate(const HubPath: string; Ctx: IHttpContext);
    procedure HandleSSEStream(const HubPath: string; Ctx: IHttpContext; Dispatcher: THubDispatcher);
    procedure HandleInvoke(const HubPath: string; Ctx: IHttpContext; Dispatcher: THubDispatcher);
    procedure HandlePoll(const HubPath: string; Ctx: IHttpContext; Dispatcher: THubDispatcher);
    procedure HandleWebSocket(const HubPath: string; Ctx: IHttpContext; Dispatcher: THubDispatcher);
    
    function FindDispatcher(const Path: string; out HubPath: string): THubDispatcher;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Registers a Hub at the specified path</summary>
    procedure MapHub(const Path: string; HubClass: THubClass);
    
    /// <summary>Gets the Hub context for external use</summary>
    function GetHubContext: IHubContext;
    
    /// <summary>Middleware handler</summary>
    procedure Handle(Ctx: IHttpContext; Next: TRequestDelegate);
    
    /// <summary>Gracefully shuts down all SSE connections</summary>
    procedure Shutdown;
    
    property ConnectionManager: IConnectionManager read FConnectionManager;
    property GroupManager: IGroupManager read FGroupManager;
  end;

implementation

uses
  System.TypInfo,
  Dext.Utils;

function ReadStreamToString(AStream: TStream): string;
var
  SS: TStringStream;
begin
  if AStream = nil then
    Exit('');
  AStream.Position := 0;
  SS := TStringStream.Create('', TEncoding.UTF8);
  try
    SS.CopyFrom(AStream, AStream.Size);
    Result := SS.DataString;
  finally
    SS.Free;
  end;
end;

{ THubDispatcher }

constructor THubDispatcher.Create(AHubClass: THubClass;
  const AConnectionManager: IConnectionManager;
  const AGroupManager: IGroupManager;
  ASSETransport: TSSETransport);
begin
  inherited Create;
  FHubClass := AHubClass;
  FConnectionManager := AConnectionManager;
  FGroupManager := AGroupManager;
  FSSETransport := ASSETransport;
  FProtocol := TJsonHubProtocol.Create;
end;

destructor THubDispatcher.Destroy;
begin
  FProtocol.Free;
  inherited;
end;

function THubDispatcher.InvokeMethod(const ConnectionId, MethodName: string;
  const Args: TArray<TValue>): TValue;
var
  Hub: THub;
  RttiType: TRttiType;
  Method: TRttiMethod;
  CallerContext: IHubCallerContext;
  HubClients: IHubClients;
  Params: TArray<TValue>;
begin
  Result := TValue.Empty;
  
  // Create Hub instance
  Hub := FHubClass.Create;
  try
    // Setup context
    CallerContext := THubCallerContext.Create(ConnectionId, ttServerSentEvents);
    HubClients := THubClients.Create(FConnectionManager, ConnectionId);
    Hub.SetContext(CallerContext, HubClients, FGroupManager);
    
    // Find and invoke method
    RttiType := TReflection.Context.GetType(FHubClass);
    Method := RttiType.GetMethod(MethodName);
    
    if Method = nil then
      raise EHubMethodNotFoundException.CreateFmt('Method not found: %s', [MethodName]);
    
    // Convert args if needed
    Params := Args;
    Result := Method.Invoke(Hub, Params);
  finally
    Hub.Free;
  end;
end;

procedure THubDispatcher.OnConnected(const ConnectionId: string);
var
  Hub: THub;
  CallerContext: IHubCallerContext;
  HubClients: IHubClients;
begin
  Hub := FHubClass.Create;
  try
    CallerContext := THubCallerContext.Create(ConnectionId, ttServerSentEvents);
    HubClients := THubClients.Create(FConnectionManager, ConnectionId);
    Hub.SetContext(CallerContext, HubClients, FGroupManager);
    Hub.OnConnectedAsync;
  finally
    Hub.Free;
  end;
end;

procedure THubDispatcher.OnDisconnected(const ConnectionId: string; const Error: Exception);
var
  Hub: THub;
  CallerContext: IHubCallerContext;
  HubClients: IHubClients;
begin
  Hub := FHubClass.Create;
  try
    CallerContext := THubCallerContext.Create(ConnectionId, ttServerSentEvents);
    HubClients := THubClients.Create(FConnectionManager, ConnectionId);
    Hub.SetContext(CallerContext, HubClients, FGroupManager);
    Hub.OnDisconnectedAsync(Error);
  finally
    Hub.Free;
  end;
end;

{ THubMiddleware }

constructor THubMiddleware.Create;
var
  LConnectionManager: TConnectionManager;
begin
  inherited Create;
  FHubs := TCollections.CreateDictionary<string, THubDispatcher>;
  FGroupManager := TGroupManager.Create;
  LConnectionManager := TConnectionManager.Create;
  LConnectionManager.SetGroupManager(FGroupManager);
  FConnectionManager := LConnectionManager;
  FSSETransport := TSSETransport.Create;
  FWebSocketTransport := TWebSocketHubTransport.Create;
  FConnectionDispatchers := TCollections.CreateDictionary<string, THubDispatcher>;
  
  FWebSocketTransport.SetOnConnected(
    procedure(const ConnectionId: string)
    var
      Conn: TWebSocketHubConnection;
      Dispatcher: THubDispatcher;
    begin
      Conn := FWebSocketTransport.GetConnection(ConnectionId);
      if Conn <> nil then
        FConnectionManager.Add(Conn);
        
      if FConnectionDispatchers.TryGetValue(ConnectionId, Dispatcher) then
      begin
        try
          Dispatcher.OnConnected(ConnectionId);
        except
          // Log but don't fail
        end;
      end;
    end
  );
  
  FWebSocketTransport.SetOnDisconnected(
    procedure(const ConnectionId: string)
    var
      Dispatcher: THubDispatcher;
    begin
      FConnectionManager.Remove(ConnectionId);
      if FConnectionDispatchers.TryGetValue(ConnectionId, Dispatcher) then
      begin
        try
          Dispatcher.OnDisconnected(ConnectionId, nil);
        except
          // Log but don't fail
        end;
        FConnectionDispatchers.Remove(ConnectionId);
      end;
    end
  );
  
  FWebSocketTransport.SetOnMessageReceived(
    procedure(const ConnectionId, Data: string)
    var
      Dispatcher: THubDispatcher;
      Msg: THubMessage;
      Protocol: TJsonHubProtocol;
      ResultValue: TValue;
      ResponseMsg: THubMessage;
      ResponseStr: string;
    begin
      if FConnectionDispatchers.TryGetValue(ConnectionId, Dispatcher) then
      begin
        Protocol := TJsonHubProtocol.Create;
        try
          Msg := Protocol.Deserialize(Data);
          if Msg.MessageType = hmtInvocation then
          begin
            try
              ResultValue := Dispatcher.InvokeMethod(ConnectionId, Msg.Target, Msg.Arguments);
              ResponseMsg := THubMessage.Completion(Msg.InvocationId, ResultValue);
            except
              on E: Exception do
                ResponseMsg := THubMessage.CompletionError(Msg.InvocationId, E.Message);
            end;
            ResponseStr := Protocol.Serialize(ResponseMsg);
            FWebSocketTransport.SendAsync(ConnectionId, ResponseStr);
          end;
        finally
          Protocol.Free;
        end;
      end;
    end
  );
end;

destructor THubMiddleware.Destroy;
var
  Dispatcher: THubDispatcher;
begin
  Shutdown; // Close all connections first
  for Dispatcher in FHubs.Values do
    Dispatcher.Free;
  // FHubs is ARC
  FSSETransport.Free;
  FWebSocketTransport.Free;
  // Note: TConnectionManager and TGroupManager are interfaced, will be freed automatically
  inherited;
end;

procedure THubMiddleware.Shutdown;
begin
  if FSSETransport <> nil then
    FSSETransport.CloseAllConnections;
  if FWebSocketTransport <> nil then
    FWebSocketTransport.CloseAllConnections;
end;

procedure THubMiddleware.MapHub(const Path: string; HubClass: THubClass);
var
  Dispatcher: THubDispatcher;
  NormalizedPath: string;
begin
  NormalizedPath := Path.ToLower;
  if not NormalizedPath.StartsWith('/') then
    NormalizedPath := '/' + NormalizedPath;
    
  Dispatcher := THubDispatcher.Create(HubClass, FConnectionManager, FGroupManager, FSSETransport);
  FHubs.AddOrSetValue(NormalizedPath, Dispatcher);
end;

function THubMiddleware.GetHubContext: IHubContext;
begin
  Result := THubContext.Create(FConnectionManager, FGroupManager);
end;

function THubMiddleware.FindDispatcher(const Path: string; out HubPath: string): THubDispatcher;
var
  LowerPath: string;
  Key: string;
begin
  Result := nil;
  HubPath := '';
  LowerPath := Path.ToLower;
  
  for Key in FHubs.Keys do
  begin
    if LowerPath.StartsWith(Key) then
    begin
      HubPath := Key;
      Result := FHubs[Key];
      Exit;
    end;
  end;
end;

procedure THubMiddleware.Handle(Ctx: IHttpContext; Next: TRequestDelegate);
var
  Path, HubPath: string;
  Dispatcher: THubDispatcher;
begin
  Path := Ctx.Request.Path.ToLower;
  
  // Check if this is a hub request
  Dispatcher := FindDispatcher(Path, HubPath);
  
  if Dispatcher = nil then
  begin
    Next(Ctx);
    Exit;
  end;
  
  // Check for WebSocket upgrade request
  if SameText(Ctx.Request.Method, 'GET') and 
     SameText(Ctx.Request.GetHeader('Upgrade'), 'websocket') and
     Ctx.Connection.SupportsUpgrade then
  begin
    HandleWebSocket(HubPath, Ctx, Dispatcher);
    Exit;
  end;
  
  // Route to appropriate handler
  if Path.EndsWith('/negotiate') then
    HandleNegotiate(HubPath, Ctx)
  else if Path.EndsWith('/poll') then
    HandlePoll(HubPath, Ctx, Dispatcher)
  else if Ctx.Request.Method = 'GET' then
    HandleSSEStream(HubPath, Ctx, Dispatcher)
  else if Ctx.Request.Method = 'POST' then
    HandleInvoke(HubPath, Ctx, Dispatcher)
  else
    Next(Ctx);
end;

procedure THubMiddleware.HandleNegotiate(const HubPath: string; Ctx: IHttpContext);
var
  ConnectionId: string;
  Response: TNegotiateResponse;
begin
  // Generate unique connection ID
  ConnectionId := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '');
  
  // Build negotiate response
  Response := TNegotiateResponse.Create(ConnectionId);
  
  Ctx.Response.StatusCode := 200;
  Ctx.Response.SetContentType('application/json');
  Ctx.Response.Write(Response.ToJson);
  Writeln('Hub: Negotiate request on path ', HubPath, ' - generated ID: ', ConnectionId);
end;

procedure THubMiddleware.HandleSSEStream(const HubPath: string; Ctx: IHttpContext;
  Dispatcher: THubDispatcher);
var
  ConnectionId: string;
  Connection: TSSEConnection;
  Msg: string;
  KeepAliveCounter: Integer;
  HasMessages: Boolean;
begin
  // Get connection ID from query
  if not Ctx.Request.Query.TryGetValue('id', ConnectionId) then
    ConnectionId := '';
  if ConnectionId = '' then
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.Write('{"error": "Missing connection id"}');
    Exit;
  end;
  
  // Writeln('Hub: SSE stream requested for HubPath: ', HubPath, ', ConnectionId: ', ConnectionId);
  
  // Create SSE connection
  Connection := FSSETransport.CreateConnection(ConnectionId);
  Connection.SetConnected;
  
  // Add to connection manager (as interface)
  FConnectionManager.Add(Connection);
  // Writeln('Hub: Connection added to manager for ID: ', ConnectionId);
  
  // Configure SSE response
  TSSEWriter.ConfigureResponse(Ctx.Response);
  TSSEWriter.WriteRetry(Ctx.Response, 3000); // Retry after 3s on disconnect
  
  // Trigger OnConnected
  try
    Dispatcher.OnConnected(ConnectionId);
  except
    on E: Exception do
      // Writeln('Hub: Error invoking OnConnected: ', E.Message);
  end;
  
  // Send connected event
  TSSEWriter.WriteEvent(Ctx.Response, 'connected', '{"connectionId":"' + ConnectionId + '"}');
  Ctx.Response.Flush;
  // Writeln('Hub: Connected event sent to ID: ', ConnectionId);
  
  KeepAliveCounter := 0;
  
  // SSE loop - keep connection open
  // Check BOTH connection closed AND transport shutdown
  while (not Connection.Closed) and (not FSSETransport.IsShuttingDown) do
  begin
    // Check for pending messages
    HasMessages := False;
    while Connection.HasPendingMessages and (not FSSETransport.IsShuttingDown) do
    begin
      Msg := Connection.DequeueMessage;
      if Msg <> '' then
      begin
        // Writeln('Hub: Sending SSE payload to ID ', ConnectionId, ': ', Msg);
        TSSEWriter.WriteData(Ctx.Response, Msg);
        HasMessages := True;
      end;
    end;
    if HasMessages then
      Ctx.Response.Flush;
    
    // Send keep-alive comment every 15 seconds (150 * 100ms)
    Inc(KeepAliveCounter);
    if KeepAliveCounter >= 150 then
    begin
      TSSEWriter.WriteComment(Ctx.Response, 'ping');
      Ctx.Response.Flush;
      KeepAliveCounter := 0;
    end;
    
    Sleep(100);
  end;
  
  // Writeln('Hub: SSE Connection closed for ID: ', ConnectionId, ' (Connection.Closed=', Connection.Closed, ', FSSETransport.IsShuttingDown=', FSSETransport.IsShuttingDown, ')');
  
  // Cleanup
  FConnectionManager.Remove(ConnectionId);
  FSSETransport.RemoveConnection(ConnectionId);
  
  // Trigger OnDisconnected
  try
    Dispatcher.OnDisconnected(ConnectionId, nil);
  except
    on E: Exception do
      Writeln('Hub: Error invoking OnDisconnected: ', E.Message);
  end;
end;

procedure THubMiddleware.HandlePoll(const HubPath: string; Ctx: IHttpContext;
  Dispatcher: THubDispatcher);
var
  ConnectionId: string;
  Connection: TSSEConnection;
  Messages: TJSONArray;
  Msg: string;
begin
  if not Ctx.Request.Query.TryGetValue('id', ConnectionId) then
    ConnectionId := '';
  if ConnectionId = '' then
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.Write('{"error": "Missing connection id"}');
    Exit;
  end;
  
  // Get connection
  Connection := FSSETransport.GetConnection(ConnectionId);
  if Connection = nil then
  begin
    // No connection yet - create one
    Connection := FSSETransport.CreateConnection(ConnectionId);
    Connection.SetConnected;
    FConnectionManager.Add(Connection);
    
    // Trigger OnConnected
    try
      Dispatcher.OnConnected(ConnectionId);
    except
      // Log but don't fail
    end;
  end;
  
  // Collect pending messages
  Messages := TJSONArray.Create;
  try
    while Connection.HasPendingMessages do
    begin
      Msg := Connection.DequeueMessage;
      if Msg <> '' then
        Messages.Add(Msg);
    end;
    
    Ctx.Response.StatusCode := 200;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write(Messages.ToJSON);
  finally
    Messages.Free;
  end;
end;

procedure THubMiddleware.HandleInvoke(const HubPath: string; Ctx: IHttpContext;
  Dispatcher: THubDispatcher);
var
  Body: string;
  Request: TInvocationRequest;
  InvResult: TInvocationResult;
  Args: TArray<TValue>;
  I: Integer;
  ResultValue: TValue;
  ConnectionId: string;
begin
  if not Ctx.Request.Query.TryGetValue('id', ConnectionId) then
    ConnectionId := '';
  if ConnectionId = '' then
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.Write('{"error": "Missing connection id"}');
    Exit;
  end;
  
  // Read body
  Body := ReadStreamToString(Ctx.Request.Body);
  Writeln('Hub: Invoking method target on Path: ', HubPath, ', ConnectionId: ', ConnectionId, ', Body: ', Body);
  
  try
    // Parse invocation request
    Request := TInvocationRequest.FromJson(Body);
    
    // Convert JSON strings to TValues
    SetLength(Args, Length(Request.Arguments));
    for I := 0 to High(Request.Arguments) do
      Args[I] := TJsonHubProtocol.JsonToValue(
        TJSONObject.ParseJSONValue(Request.Arguments[I]), nil);
    
    // Invoke method
    ResultValue := Dispatcher.InvokeMethod(ConnectionId, Request.Target, Args);
    
    // Build response
    if ResultValue.IsEmpty then
      InvResult := TInvocationResult.Success(Request.InvocationId, 'null')
    else
      InvResult := TInvocationResult.Success(Request.InvocationId,
        TJsonHubProtocol.ValueToJson(ResultValue).ToJSON);
    
    Ctx.Response.StatusCode := 200;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write(InvResult.ToJson);
    
  except
    on E: EHubMethodNotFoundException do
    begin
      InvResult := TInvocationResult.Failure(Request.InvocationId, E.Message);
      Ctx.Response.StatusCode := 404;
      Ctx.Response.SetContentType('application/json');
      Ctx.Response.Write(InvResult.ToJson);
    end;
    on E: Exception do
    begin
      InvResult := TInvocationResult.Failure(Request.InvocationId, E.Message);
      Ctx.Response.StatusCode := 500;
      Ctx.Response.SetContentType('application/json');
      Ctx.Response.Write(InvResult.ToJson);
    end;
  end;
end;

procedure THubMiddleware.HandleWebSocket(const HubPath: string; Ctx: IHttpContext;
  Dispatcher: THubDispatcher);
var
  ConnectionId: string;
begin
  ConnectionId := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '');
  FConnectionDispatchers.Add(ConnectionId, Dispatcher);
  try
    FWebSocketTransport.ProcessConnection(Ctx, ConnectionId);
  except
    on E: Exception do
    begin
      FConnectionDispatchers.Remove(ConnectionId);
      raise;
    end;
  end;
end;

end.

