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
  System.SyncObjs,
  System.SysUtils,
  Dext.Auth.Identity,
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
    function CreateCallerContext(const ConnectionId: string): IHubCallerContext;
    function IsClientInvokableMethod(const Method: TRttiMethod;
      const RttiType: TRttiType): Boolean;
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
    FConnectionDispatchersLock: TCriticalSection;
    FOptions: THubOptions;
    procedure Initialize(const Options: THubOptions);
    
    procedure HandleNegotiate(const HubPath: string; Ctx: IHttpContext);
    procedure HandleSSEStream(const HubPath: string; Ctx: IHttpContext; Dispatcher: THubDispatcher);
    procedure HandleInvoke(const HubPath: string; Ctx: IHttpContext; Dispatcher: THubDispatcher);
    procedure HandlePoll(const HubPath: string; Ctx: IHttpContext; Dispatcher: THubDispatcher);
    procedure HandleWebSocket(const HubPath: string; Ctx: IHttpContext; Dispatcher: THubDispatcher);
    function TryReserveConnection(const ConnectionId: string;
      Dispatcher: THubDispatcher): Boolean;
    function TryGetConnectionDispatcher(const ConnectionId: string;
      out Dispatcher: THubDispatcher): Boolean;
    procedure ReleaseConnection(const ConnectionId: string);
    function ClientError(const DetailedMessage, SafeMessage: string): string;
    function IsTransportEnabled(const TransportName: string): Boolean;
    
    function FindDispatcher(const Path: string; out HubPath: string): THubDispatcher;
  public
    constructor Create; overload;
    constructor Create(const Options: THubOptions); overload;
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

function ReadStreamToString(AStream: TStream; AMaximumBytes: Int64): string;
var
  SS: TStringStream;
  LSize: Int64;
begin
  if AStream = nil then
    Exit('');
  if AMaximumBytes <= 0 then
    raise EHubPayloadTooLargeException.Create(
      'Hub receive limit must be greater than zero');
  LSize := AStream.Size;
  if LSize > AMaximumBytes then
    raise EHubPayloadTooLargeException.CreateFmt(
      'Hub payload exceeds the configured limit of %d bytes',
      [AMaximumBytes]);
  AStream.Position := 0;
  SS := TStringStream.Create('', TEncoding.UTF8);
  try
    SS.CopyFrom(AStream, LSize);
    Result := SS.DataString;
  finally
    SS.Free;
  end;
end;

function IsValidConnectionId(const AValue: string): Boolean;
var
  LChar: Char;
begin
  if AValue.Length <> 32 then
    Exit(False);
  for LChar in AValue do
    if not CharInSet(LChar, ['0'..'9', 'a'..'f', 'A'..'F']) then
      Exit(False);
  Result := True;
end;

function PrincipalKey(const APrincipal: IClaimsPrincipal): string;
begin
  if APrincipal = nil then
    Exit('');
  if APrincipal.HasClaim('sub') then
    Exit(APrincipal.FindClaim('sub').Value);
  if APrincipal.Identity <> nil then
    Exit(APrincipal.Identity.Name);
  Result := '';
end;

function IsSamePrincipal(const AExpected, AActual: IClaimsPrincipal): Boolean;
var
  LExpectedKey, LActualKey: string;
begin
  if (AExpected = nil) or (AActual = nil) then
    Exit((AExpected = nil) and (AActual = nil));
  LExpectedKey := PrincipalKey(AExpected);
  LActualKey := PrincipalKey(AActual);
  if (LExpectedKey = '') or (LActualKey = '') then
    Exit(AExpected = AActual);
  Result := SameText(LExpectedKey, LActualKey);
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

function THubDispatcher.CreateCallerContext(
  const ConnectionId: string): IHubCallerContext;
var
  LConnection: IHubConnection;
begin
  if not FConnectionManager.TryGet(ConnectionId, LConnection) then
    raise EConnectionNotFoundException.CreateFmt(
      'Connection not found: %s', [ConnectionId]);

  Result := THubCallerContext.Create(ConnectionId,
    LConnection.TransportType, LConnection.User, LConnection.AbortToken,
    procedure
    begin
      LConnection.Close('Aborted by Hub');
    end);
end;

function THubDispatcher.IsClientInvokableMethod(const Method: TRttiMethod;
  const RttiType: TRttiType): Boolean;
var
  LAttribute: TCustomAttribute;
begin
  Result := False;
  if not Assigned(Method) or not Assigned(RttiType) then
    Exit;
  for LAttribute in Method.GetAttributes do
    if LAttribute is HubMethodAttribute then
      Exit(True);
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
    CallerContext := CreateCallerContext(ConnectionId);
    HubClients := THubClients.Create(FConnectionManager, ConnectionId);
    Hub.SetContext(CallerContext, HubClients, FGroupManager);
    
    // Find and invoke method
    RttiType := TReflection.Context.GetType(FHubClass);
    Method := RttiType.GetMethod(MethodName);
    
    if not IsClientInvokableMethod(Method, RttiType) then
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
    CallerContext := CreateCallerContext(ConnectionId);
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
    CallerContext := CreateCallerContext(ConnectionId);
    HubClients := THubClients.Create(FConnectionManager, ConnectionId);
    Hub.SetContext(CallerContext, HubClients, FGroupManager);
    Hub.OnDisconnectedAsync(Error);
  finally
    Hub.Free;
  end;
end;

{ THubMiddleware }

constructor THubMiddleware.Create;
begin
  inherited Create;
  Initialize(THubOptions.Default);
end;

constructor THubMiddleware.Create(const Options: THubOptions);
begin
  inherited Create;
  Initialize(Options);
end;

procedure THubMiddleware.Initialize(const Options: THubOptions);
var
  LConnectionManager: TConnectionManager;
begin
  if Options.MaximumReceiveMessageSize <= 0 then
    raise EArgumentOutOfRangeException.Create(
      'MaximumReceiveMessageSize must be greater than zero');
  FOptions := Options;
  FHubs := TCollections.CreateDictionary<string, THubDispatcher>;
  FGroupManager := TGroupManager.Create;
  LConnectionManager := TConnectionManager.Create;
  LConnectionManager.SetGroupManager(FGroupManager);
  FConnectionManager := LConnectionManager;
  FSSETransport := TSSETransport.Create;
  FWebSocketTransport := TWebSocketHubTransport.Create(
    FOptions.MaximumReceiveMessageSize);
  FConnectionDispatchers := TCollections.CreateDictionary<string, THubDispatcher>;
  FConnectionDispatchersLock := TCriticalSection.Create;
  
  FWebSocketTransport.SetOnConnected(
    procedure(const ConnectionId: string)
    var
      Conn: TWebSocketHubConnection;
      Dispatcher: THubDispatcher;
    begin
      Conn := FWebSocketTransport.GetConnection(ConnectionId);
      if Conn = nil then
        Exit;
      FConnectionManager.Add(Conn);
        
      if TryGetConnectionDispatcher(ConnectionId, Dispatcher) then
      begin
        try
          Dispatcher.OnConnected(ConnectionId);
        except
          Conn.Close('Hub rejected connection');
        end;
      end;
    end
  );
  
  FWebSocketTransport.SetOnDisconnected(
    procedure(const ConnectionId: string)
    var
      Dispatcher: THubDispatcher;
    begin
      if TryGetConnectionDispatcher(ConnectionId, Dispatcher) then
      begin
        try
          Dispatcher.OnDisconnected(ConnectionId, nil);
        except
          // Log but don't fail
        end;
        ReleaseConnection(ConnectionId);
      end;
      FConnectionManager.Remove(ConnectionId);
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
      if TryGetConnectionDispatcher(ConnectionId, Dispatcher) then
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
              begin
                Writeln('Hub: invocation failed: ', E.Message);
                ResponseMsg := THubMessage.CompletionError(Msg.InvocationId,
                  ClientError(E.Message, 'Hub invocation failed'));
              end;
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
  if FHubs <> nil then
    for Dispatcher in FHubs.Values do
      Dispatcher.Free;
  // FHubs is ARC
  FreeAndNil(FSSETransport);
  FreeAndNil(FWebSocketTransport);
  FreeAndNil(FConnectionDispatchersLock);
  // Note: TConnectionManager and TGroupManager are interfaced, will be freed automatically
  inherited;
end;

function THubMiddleware.TryReserveConnection(const ConnectionId: string;
  Dispatcher: THubDispatcher): Boolean;
begin
  FConnectionDispatchersLock.Enter;
  try
    Result := not FConnectionDispatchers.ContainsKey(ConnectionId);
    if Result then
      FConnectionDispatchers.Add(ConnectionId, Dispatcher);
  finally
    FConnectionDispatchersLock.Leave;
  end;
end;

function THubMiddleware.TryGetConnectionDispatcher(const ConnectionId: string;
  out Dispatcher: THubDispatcher): Boolean;
begin
  FConnectionDispatchersLock.Enter;
  try
    Result := FConnectionDispatchers.TryGetValue(ConnectionId, Dispatcher);
  finally
    FConnectionDispatchersLock.Leave;
  end;
end;

procedure THubMiddleware.ReleaseConnection(const ConnectionId: string);
begin
  FConnectionDispatchersLock.Enter;
  try
    FConnectionDispatchers.Remove(ConnectionId);
  finally
    FConnectionDispatchersLock.Leave;
  end;
end;

function THubMiddleware.ClientError(const DetailedMessage,
  SafeMessage: string): string;
begin
  if FOptions.EnableDetailedErrors then
    Result := DetailedMessage
  else
    Result := SafeMessage;
end;

function THubMiddleware.IsTransportEnabled(
  const TransportName: string): Boolean;
var
  LEnabledTransport: string;
begin
  Result := False;
  for LEnabledTransport in FOptions.EnabledTransports do
    if SameText(LEnabledTransport, TransportName) then
      Exit(True);
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
  while (NormalizedPath.Length > 1) and NormalizedPath.EndsWith('/') do
    Delete(NormalizedPath, NormalizedPath.Length, 1);
    
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
    if SameText(LowerPath, Key) or LowerPath.StartsWith(Key + '/') then
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
  
  // A WebSocket upgrade must never silently fall through to an SSE stream.
  if SameText(Path, HubPath) and SameText(Ctx.Request.Method, 'GET') and
     SameText(Ctx.Request.GetHeader('Upgrade'), 'websocket') then
  begin
    if not IsTransportEnabled('WebSockets') then
    begin
      Ctx.Response.StatusCode := 404;
      Ctx.Response.SetContentType('application/json');
      Ctx.Response.Write('{"error":"WebSocket transport is disabled"}');
    end
    else if Ctx.Connection.SupportsUpgrade then
      HandleWebSocket(HubPath, Ctx, Dispatcher)
    else
    begin
      Ctx.Response.StatusCode := 426;
      Ctx.Response.AddHeader('Upgrade', 'websocket');
      Ctx.Response.SetContentType('application/json');
      Ctx.Response.Write('{"error":"WebSocket upgrade is not supported by the active HTTP engine"}');
    end;
    Exit;
  end;
  
  // Route to appropriate handler
  if SameText(Path, HubPath + '/negotiate') and
     SameText(Ctx.Request.Method, 'POST') then
    HandleNegotiate(HubPath, Ctx)
  else if SameText(Path, HubPath + '/poll') and
          SameText(Ctx.Request.Method, 'GET') and
          IsTransportEnabled('ServerSentEvents') then
    HandlePoll(HubPath, Ctx, Dispatcher)
  else if SameText(Path, HubPath) and SameText(Ctx.Request.Method, 'GET') and
          IsTransportEnabled('ServerSentEvents') then
    HandleSSEStream(HubPath, Ctx, Dispatcher)
  else if SameText(Path, HubPath) and SameText(Ctx.Request.Method, 'POST') then
    HandleInvoke(HubPath, Ctx, Dispatcher)
  else
    Next(Ctx);
end;

procedure THubMiddleware.HandleNegotiate(const HubPath: string; Ctx: IHttpContext);
var
  ConnectionId: string;
  Response: TNegotiateResponse;
  LTransportCount: Integer;
begin
  // Generate unique connection ID
  ConnectionId := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '');
  
  // Build negotiate response
  Response := TNegotiateResponse.Create(ConnectionId);
  SetLength(Response.AvailableTransports, 0);
  LTransportCount := 0;
  if IsTransportEnabled('WebSockets') and
     Ctx.Connection.SupportsUpgrade then
  begin
    SetLength(Response.AvailableTransports, LTransportCount + 1);
    Response.AvailableTransports[LTransportCount] :=
      TTransportInfo.WebSockets;
    Inc(LTransportCount);
  end;
  if IsTransportEnabled('ServerSentEvents') then
  begin
    SetLength(Response.AvailableTransports, LTransportCount + 1);
    Response.AvailableTransports[LTransportCount] := TTransportInfo.SSE;
  end;
  
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
  if not IsValidConnectionId(ConnectionId) then
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Invalid connection id"}');
    Exit;
  end;
  if FConnectionManager.Contains(ConnectionId) or
     not TryReserveConnection(ConnectionId, Dispatcher) then
  begin
    Ctx.Response.StatusCode := 409;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Connection id is already active"}');
    Exit;
  end;
  Connection := nil;
  try
    // Create SSE connection
    Connection := FSSETransport.CreateConnection(ConnectionId, Ctx.User);
    Connection.SetConnected;

    // Add to connection manager (as interface)
    FConnectionManager.Add(Connection);

    // Configure SSE response
    TSSEWriter.ConfigureResponse(Ctx.Response);
    TSSEWriter.WriteRetry(Ctx.Response, 3000); // Retry after 3s on disconnect

    // Trigger OnConnected
    try
      Dispatcher.OnConnected(ConnectionId);
    except
      on E: Exception do
        Connection.Close('Hub rejected connection');
    end;

    if not Connection.Closed then
    begin
      // Send connected event only after the Hub accepted the connection.
      TSSEWriter.WriteEvent(Ctx.Response, 'connected',
        '{"connectionId":"' + ConnectionId + '"}');
      Ctx.Response.Flush;

      KeepAliveCounter := 0;

      // SSE loop - keep connection open
      while (not Connection.Closed) and (not FSSETransport.IsShuttingDown) do
      begin
        HasMessages := False;
        while Connection.HasPendingMessages and
          (not FSSETransport.IsShuttingDown) do
        begin
          Msg := Connection.DequeueMessage;
          if Msg <> '' then
          begin
            TSSEWriter.WriteData(Ctx.Response, Msg);
            HasMessages := True;
          end;
        end;
        if HasMessages then
          Ctx.Response.Flush;

        Inc(KeepAliveCounter);
        if KeepAliveCounter >= 150 then
        begin
          TSSEWriter.WriteComment(Ctx.Response, 'ping');
          Ctx.Response.Flush;
          KeepAliveCounter := 0;
        end;

        Sleep(100);
      end;
    end;

    // Keep the connection available while OnDisconnectedAsync executes.
    try
      Dispatcher.OnDisconnected(ConnectionId, nil);
    except
      on E: Exception do
        Writeln('Hub: Error invoking OnDisconnected: ', E.Message);
    end;
  finally
    if Connection <> nil then
    begin
      FConnectionManager.Remove(ConnectionId);
      FSSETransport.RemoveConnection(ConnectionId);
    end;
    ReleaseConnection(ConnectionId);
  end;
end;

procedure THubMiddleware.HandlePoll(const HubPath: string; Ctx: IHttpContext;
  Dispatcher: THubDispatcher);
var
  ConnectionId: string;
  Connection: TSSEConnection;
  HubConnection: IHubConnection;
  Messages: TJSONArray;
  Msg: string;
begin
  if not Ctx.Request.Query.TryGetValue('id', ConnectionId) then
    ConnectionId := '';
  if not IsValidConnectionId(ConnectionId) then
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Invalid connection id"}');
    Exit;
  end;
  
  // Get connection
  Connection := FSSETransport.GetConnection(ConnectionId);
  if (Connection <> nil) and
    (not FConnectionManager.TryGet(ConnectionId, HubConnection) or
     not IsSamePrincipal(HubConnection.User, Ctx.User)) then
  begin
    Ctx.Response.StatusCode := 403;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Connection principal mismatch"}');
    Exit;
  end;
  if Connection = nil then
  begin
    Ctx.Response.StatusCode := 404;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Connection not found"}');
    Exit;
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
  JsonValue: TJSONValue;
  ConnectionId: string;
  Connection: IHubConnection;
begin
  if not Ctx.Request.Query.TryGetValue('id', ConnectionId) then
    ConnectionId := '';
  if not IsValidConnectionId(ConnectionId) then
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Invalid connection id"}');
    Exit;
  end;

  if not FConnectionManager.TryGet(ConnectionId, Connection) then
  begin
    Ctx.Response.StatusCode := 404;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Connection not found"}');
    Exit;
  end;
  if not IsSamePrincipal(Connection.User, Ctx.User) then
  begin
    Ctx.Response.StatusCode := 403;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Connection principal mismatch"}');
    Exit;
  end;
  
  Request := Default(TInvocationRequest);
  try
    // Read body using the configured receive limit.
    Body := ReadStreamToString(Ctx.Request.Body,
      FOptions.MaximumReceiveMessageSize);

    // Parse invocation request
    Request := TInvocationRequest.FromJson(Body);
    
    // Convert JSON strings to TValues
    SetLength(Args, Length(Request.Arguments));
    for I := 0 to High(Request.Arguments) do
    begin
      JsonValue := TJSONObject.ParseJSONValue(Request.Arguments[I]);
      if JsonValue = nil then
        raise EHubException.Create('Invalid JSON argument');
      try
        Args[I] := TJsonHubProtocol.JsonToValue(JsonValue, nil);
      finally
        JsonValue.Free;
      end;
    end;
    
    // Invoke method
    ResultValue := Dispatcher.InvokeMethod(ConnectionId, Request.Target, Args);
    
    // Build response
    if ResultValue.IsEmpty then
      InvResult := TInvocationResult.Success(Request.InvocationId, 'null')
    else
    begin
      JsonValue := TJsonHubProtocol.ValueToJson(ResultValue);
      try
        InvResult := TInvocationResult.Success(Request.InvocationId,
          JsonValue.ToJSON);
      finally
        JsonValue.Free;
      end;
    end;
    
    Ctx.Response.StatusCode := 200;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write(InvResult.ToJson);
    
  except
    on E: EHubPayloadTooLargeException do
    begin
      InvResult := TInvocationResult.Failure(Request.InvocationId,
        ClientError(E.Message, 'Hub payload is too large'));
      Ctx.Response.StatusCode := 413;
      Ctx.Response.SetContentType('application/json');
      Ctx.Response.Write(InvResult.ToJson);
    end;
    on E: EHubMethodNotFoundException do
    begin
      InvResult := TInvocationResult.Failure(Request.InvocationId,
        ClientError(E.Message, 'Hub method not found'));
      Ctx.Response.StatusCode := 404;
      Ctx.Response.SetContentType('application/json');
      Ctx.Response.Write(InvResult.ToJson);
    end;
    on E: EHubException do
    begin
      InvResult := TInvocationResult.Failure(Request.InvocationId,
        ClientError(E.Message, 'Invalid Hub request'));
      Ctx.Response.StatusCode := 400;
      Ctx.Response.SetContentType('application/json');
      Ctx.Response.Write(InvResult.ToJson);
    end;
    on E: Exception do
    begin
      Writeln('Hub: invocation failed: ', E.Message);
      InvResult := TInvocationResult.Failure(Request.InvocationId,
        ClientError(E.Message, 'Hub invocation failed'));
      Ctx.Response.StatusCode := 500;
      Ctx.Response.SetContentType('application/json');
      Ctx.Response.Write(InvResult.ToJson);
    end;
  end;
end;

procedure THubMiddleware.HandleWebSocket(const HubPath: string; Ctx: IHttpContext;
  Dispatcher: THubDispatcher);
var
  ConnectionId, RequestedConnectionId: string;
begin
  if not Ctx.Request.Query.TryGetValue('id', ConnectionId) then
    ConnectionId := '';
  if not IsValidConnectionId(ConnectionId) then
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Invalid connection id"}');
    Exit;
  end;
  if FConnectionManager.Contains(ConnectionId) or
     not TryReserveConnection(ConnectionId, Dispatcher) then
  begin
    Ctx.Response.StatusCode := 409;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Connection id is already active"}');
    Exit;
  end;

  RequestedConnectionId := ConnectionId;
  try
    FWebSocketTransport.ProcessConnection(Ctx, ConnectionId);
  finally
    ReleaseConnection(RequestedConnectionId);
  end;
end;

end.

