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
unit Dext.Web.Hubs.Transport.WebSocket;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.Rtti,
  System.SyncObjs,
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Auth.Identity,
  Dext.Threading.CancellationToken,
  Dext.Server.Engine.Interfaces,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Interfaces;

type
  /// <summary>
  /// WebSocket connection wrapping the raw server upgrade connection.
  /// </summary>
  TWebSocketHubConnection = class(TInterfacedObject, IHubConnection)
  private
    FConnectionId: string;
    FWSConnection: IDextWebSocketConnection;
    FState: TConnectionState;
    FUser: IClaimsPrincipal;
    FItems: IDictionary<string, TValue>;
    FAbortTokenSource: TCancellationTokenSource;
    FLock: TCriticalSection;
  public
    constructor Create(const AConnectionId: string;
      const AWSConnection: IDextWebSocketConnection;
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

    property ConnectionId: string read GetConnectionId;
    property State: TConnectionState read GetState;
  end;

  /// <summary>
  /// WebSocket Transport manager implementing IHubTransport.
  /// </summary>
  TWebSocketHubTransport = class(TInterfacedObject, IHubTransport)
  private
    FConnections: IDictionary<string, TWebSocketHubConnection>;
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

    // WebSocket-specific processing loop
    procedure ProcessConnection(const AContext: IHttpContext; var AConnectionId: string);
    procedure CloseAllConnections;
    function IsShuttingDown: Boolean;
    function GetConnection(const ConnectionId: string): TWebSocketHubConnection;
  end;

implementation

uses
  System.DateUtils,
  Dext.WebSocket.Protocol,
  Dext.WebSocket.Handshake;

{ TWebSocketHubConnection }

constructor TWebSocketHubConnection.Create(const AConnectionId: string;
  const AWSConnection: IDextWebSocketConnection;
  const AUser: IClaimsPrincipal);
begin
  inherited Create;
  FConnectionId := AConnectionId;
  FWSConnection := AWSConnection;
  FState := csConnected;
  FUser := AUser;
  FItems := TCollections.CreateDictionary<string, TValue>;
  FAbortTokenSource := TCancellationTokenSource.Create;
  FLock := TCriticalSection.Create;
end;

destructor TWebSocketHubConnection.Destroy;
begin
  FAbortTokenSource.Free;
  FItems := nil;
  FUser := nil;
  FWSConnection := nil;
  FLock.Free;
  inherited;
end;

function TWebSocketHubConnection.GetConnectionId: string;
begin
  Result := FConnectionId;
end;

function TWebSocketHubConnection.GetTransportType: TTransportType;
begin
  Result := ttWebSockets;
end;

function TWebSocketHubConnection.GetState: TConnectionState;
begin
  Result := FState;
end;

function TWebSocketHubConnection.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

function TWebSocketHubConnection.GetUserIdentifier: string;
begin
  if (FUser <> nil) and FUser.HasClaim('sub') then
    Result := FUser.FindClaim('sub').Value
  else
    Result := '';
end;

function TWebSocketHubConnection.GetItems: IDictionary<string, TValue>;
begin
  Result := FItems;
end;

function TWebSocketHubConnection.GetAbortToken: ICancellationToken;
begin
  Result := FAbortTokenSource.Token;
end;

procedure TWebSocketHubConnection.SendAsync(const Message: string);
begin
  FLock.Enter;
  try
    if FState = csConnected then
      FWSConnection.SendText(Message);
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketHubConnection.Close(const Reason: string);
begin
  FLock.Enter;
  try
    if FState = csConnected then
    begin
      FState := csDisconnected;
      FAbortTokenSource.Cancel;
      FWSConnection.Close(1000, Reason);
    end;
  finally
    FLock.Leave;
  end;
end;

{ TWebSocketHubTransport }

constructor TWebSocketHubTransport.Create;
begin
  inherited Create;
  FConnections := TCollections.CreateDictionary<string, TWebSocketHubConnection>;
  FLock := TCriticalSection.Create;
  FShuttingDown := False;
end;

destructor TWebSocketHubTransport.Destroy;
begin
  CloseAllConnections;
  FLock.Free;
  inherited;
end;

function TWebSocketHubTransport.GetTransportType: TTransportType;
begin
  Result := ttWebSockets;
end;

function TWebSocketHubTransport.IsAvailable: Boolean;
begin
  Result := True;
end;

procedure TWebSocketHubTransport.SendAsync(const ConnectionId, Data: string);
var
  Conn: TWebSocketHubConnection;
begin
  FLock.Enter;
  try
    if FConnections.TryGetValue(ConnectionId, Conn) then
      Conn.SendAsync(Data);
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketHubTransport.CloseConnection(const ConnectionId: string; const Reason: string);
var
  Conn: TWebSocketHubConnection;
begin
  FLock.Enter;
  try
    if FConnections.TryGetValue(ConnectionId, Conn) then
      Conn.Close(Reason);
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketHubTransport.SetOnMessageReceived(const Handler: TOnMessageReceived);
begin
  FOnMessageReceived := Handler;
end;

procedure TWebSocketHubTransport.SetOnConnected(const Handler: TOnConnectionEvent);
begin
  FOnConnected := Handler;
end;

procedure TWebSocketHubTransport.SetOnDisconnected(const Handler: TOnConnectionEvent);
begin
  FOnDisconnected := Handler;
end;

procedure TWebSocketHubTransport.CloseAllConnections;
var
  Conn: TWebSocketHubConnection;
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

function TWebSocketHubTransport.IsShuttingDown: Boolean;
begin
  Result := FShuttingDown;
end;

function TWebSocketHubTransport.GetConnection(const ConnectionId: string): TWebSocketHubConnection;
begin
  FLock.Enter;
  try
    if not FConnections.TryGetValue(ConnectionId, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketHubTransport.ProcessConnection(const AContext: IHttpContext; var AConnectionId: string);
var
  WSConn: IDextWebSocketConnection;
  ConnectionId: string;
  HubConnection: TWebSocketHubConnection;
  Buffer: TBytes;
  BufferOffset: Integer;
  BytesRead: Integer;
  Frame: TWebSocketFrame;
  BytesConsumed: Integer;
  PayloadStr: string;
  KeepAliveTimer: TDateTime;
begin
  WSConn := AContext.Connection.UpgradeToWebSocket;
  if WSConn = nil then
  begin
    AConnectionId := '';
    Exit;
  end;

  if AConnectionId = '' then
    ConnectionId := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '')
  else
    ConnectionId := AConnectionId;
    
  AConnectionId := ConnectionId;
  HubConnection := TWebSocketHubConnection.Create(ConnectionId, WSConn,
    AContext.User);

  FLock.Enter;
  try
    FConnections.Add(ConnectionId, HubConnection);
  finally
    FLock.Leave;
  end;

  if Assigned(FOnConnected) then
    FOnConnected(ConnectionId);

  SetLength(Buffer, 65536);
  BufferOffset := 0;
  KeepAliveTimer := Now;

  try
    while (not FShuttingDown) and (HubConnection.State = csConnected) do
    begin
      BytesRead := WSConn.Receive(Buffer, BufferOffset, Length(Buffer) - BufferOffset);
      if BytesRead <= 0 then
        Break;

      Inc(BufferOffset, BytesRead);

      while BufferOffset > 0 do
      begin
        BytesConsumed := 0;
        if TWebSocketFrameCodec.TryDecode(Buffer, 0, BufferOffset, Frame, BytesConsumed) then
        begin
          case Frame.Opcode of
            wsText:
            begin
              PayloadStr := TEncoding.UTF8.GetString(Frame.Payload);
              if Assigned(FOnMessageReceived) then
                FOnMessageReceived(ConnectionId, PayloadStr);
            end;
            wsBinary:
            begin
              // Binary not handled in Phase 1
            end;
            wsClose:
            begin
              HubConnection.Close;
              Break;
            end;
            wsPing:
            begin
              WSConn.SendBinary(TWebSocketFrameCodec.EncodePong(Frame.Payload));
            end;
            wsPong:
            begin
              // Keepalive confirmed
            end;
          end;

          if BytesConsumed > 0 then
          begin
            if BytesConsumed < BufferOffset then
              Move(Buffer[BytesConsumed], Buffer[0], BufferOffset - BytesConsumed);
            Dec(BufferOffset, BytesConsumed);
          end
          else
            Break;
        end
        else
          Break;
      end;

      if SecondsBetween(Now, KeepAliveTimer) >= 15 then
      begin
        WSConn.SendBinary(TWebSocketFrameCodec.EncodePing);
        KeepAliveTimer := Now;
      end;
    end;
  finally
    FLock.Enter;
    try
      FConnections.Remove(ConnectionId);
    finally
      FLock.Leave;
    end;

    if Assigned(FOnDisconnected) then
      FOnDisconnected(ConnectionId);

    WSConn.Close(1000);
  end;
end;

end.
