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
{    Core interfaces for Dext.Hubs - Real-Time Communication System.        }
{    Designed for SignalR protocol compatibility with pluggable transports. }
{                                                                           }
{  Design Philosophy:                                                       }
{    - SignalR-compatible API for familiarity                               }
{    - Transport-agnostic (SSE, Long-Polling, WebSocket)                    }
{    - Async-first (even if Delphi is sync, API is async-ready)             }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs.Interfaces;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  Dext.Auth.Identity,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Threading.CancellationToken;

type
  // Forward declarations
  IClientProxy = interface;
  IHubClients = interface;
  IGroupManager = interface;
  IHubCallerContext = interface;
  IHubConnection = interface;
  IConnectionManager = interface;
  IHubProtocol = interface;  /// <summary>
  /// Available transport types for Hub connections.
  /// Order indicates fallback priority (WebSocket ? SSE ? LongPolling).
  /// </summary>
  TTransportType = (
    /// <summary>Full-duplex WebSocket connection (RFC 6455)</summary>
    ttWebSockets,
    /// <summary>Server-Sent Events (unidirectional, HTTP-based)</summary>
    ttServerSentEvents,
    /// <summary>Long-Polling fallback for restricted environments</summary>
    ttLongPolling
  );
  
  TTransportTypes = set of TTransportType;
  
  /// <summary>
  /// Connection state enumeration
  /// </summary>
  TConnectionState = (
    csConnecting,
    csConnected,
    csReconnecting,
    csDisconnected
  );
  
  {$ENDREGION}  /// <summary>
  /// Proxy interface for sending messages to connected clients.
  /// This is the primary interface developers use to push data.
  /// </summary>
  /// <remarks>
  /// Compatible with SignalR's IClientProxy.
  /// Example: Clients.All.SendAsync('ReceiveMessage', ['Hello']);
  /// </remarks>
  IClientProxy = interface
    ['{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}']
    
    /// <summary>
    /// Sends a message to the client(s) represented by this proxy.
    /// </summary>
    /// <param name="Method">The name of the method to invoke on the client</param>
    /// <param name="Args">Arguments to pass to the client method</param>
    procedure SendAsync(const Method: string; const Args: TArray<TValue>); overload;
    
    /// <summary>
    /// Sends a message with no arguments.
    /// </summary>
    procedure SendAsync(const Method: string); overload;
    
    /// <summary>
    /// Sends a message with a single argument (convenience overload).
    /// </summary>
    procedure SendAsync(const Method: string; const Arg: TValue); overload;
  end;
  
  /// <summary>
  /// Provides access to client proxies for different client groups.
  /// </summary>
  /// <remarks>
  /// Compatible with SignalR's IHubClients.
  /// Access patterns:
  /// - Clients.All ? All connected clients
  /// - Clients.Client(id) ? Specific client
  /// - Clients.Group(name) ? All clients in a group
  /// - Clients.User(userId) ? All connections of a user
  /// </remarks>
  IHubClients = interface
    ['{B2C3D4E5-F6A7-4B5C-9D0E-1F2A3B4C5D6E}']
    
    /// <summary>Returns a proxy for all connected clients.</summary>
    function All: IClientProxy;
    
    /// <summary>Returns a proxy for a specific client by connection ID.</summary>
    function Client(const ConnectionId: string): IClientProxy;
    
    /// <summary>Returns a proxy for all clients in a group.</summary>
    function Group(const GroupName: string): IClientProxy;
    
    /// <summary>Returns a proxy for multiple groups.</summary>
    function Groups(const GroupNames: TArray<string>): IClientProxy;
    
    /// <summary>Returns a proxy for all connections of a specific user.</summary>
    function User(const UserId: string): IClientProxy;
    
    /// <summary>Returns a proxy for all connections of multiple users.</summary>
    function Users(const UserIds: TArray<string>): IClientProxy;
    
    /// <summary>Returns a proxy for all clients except specified ones.</summary>
    function AllExcept(const ExcludedConnectionIds: TArray<string>): IClientProxy;
    
    /// <summary>Returns a proxy for clients in a group except specified ones.</summary>
    function GroupExcept(const GroupName: string; const ExcludedConnectionIds: TArray<string>): IClientProxy;
    
    /// <summary>Gets the caller client (only valid during Hub method invocation).</summary>
    function Caller: IClientProxy;
    
    /// <summary>Gets all clients except the caller (only valid during Hub method invocation).</summary>
    function Others: IClientProxy;
    
    /// <summary>Gets all clients in caller's groups except the caller.</summary>
    function OthersInGroup(const GroupName: string): IClientProxy;
  end;

  {$ENDREGION}  /// <summary>
  /// Manages client groups for targeted message broadcast.
  /// </summary>
  IGroupManager = interface
    ['{C3D4E5F6-A7B8-4C5D-0E1F-2A3B4C5D6E7F}']
    
    /// <summary>Adds a connection to a group.</summary>
    procedure AddToGroupAsync(const ConnectionId, GroupName: string);
    
    /// <summary>Removes a connection from a group.</summary>
    procedure RemoveFromGroupAsync(const ConnectionId, GroupName: string);
    
    /// <summary>Removes a connection from all groups (called on disconnect).</summary>
    procedure RemoveFromAllGroupsAsync(const ConnectionId: string);
    
    /// <summary>Gets all groups a connection belongs to.</summary>
    function GetGroupsForConnection(const ConnectionId: string): TArray<string>;
    
    /// <summary>Checks if a connection is in a specific group.</summary>
    function IsInGroup(const ConnectionId, GroupName: string): Boolean;
  end;

  {$ENDREGION}  /// <summary>
  /// Provides information about the current Hub invocation context.
  /// Available within Hub methods during a client call.
  /// </summary>
  IHubCallerContext = interface
    ['{D4E5F6A7-B8C9-4D5E-1F2A-3B4C5D6E7F8A}']
    
    /// <summary>Gets the unique identifier for the current connection.</summary>
    function GetConnectionId: string;
    property ConnectionId: string read GetConnectionId;
    
    /// <summary>Gets the user identifier (from Claims, if authenticated).</summary>
    function GetUserIdentifier: string;
    property UserIdentifier: string read GetUserIdentifier;
    
    /// <summary>Gets the authenticated user's claims principal.</summary>
    function GetUser: IClaimsPrincipal;
    property User: IClaimsPrincipal read GetUser;
    
    /// <summary>Gets a key-value store for the connection lifetime.</summary>
    function GetItems: IDictionary<string, TValue>;
    property Items: IDictionary<string, TValue> read GetItems;
    
    /// <summary>Gets a token that signals when the connection is aborted.</summary>
    function GetConnectionAborted: ICancellationToken;
    property ConnectionAborted: ICancellationToken read GetConnectionAborted;
    
    /// <summary>Gets the transport type being used.</summary>
    function GetTransportType: TTransportType;
    property TransportType: TTransportType read GetTransportType;
    
    /// <summary>Aborts the connection immediately.</summary>
    procedure Abort;
  end;

  {$ENDREGION}  /// <summary>
  /// Provides access to Hub functionality from outside a Hub class.
  /// Inject this interface to send messages from anywhere in the application.
  /// </summary>
  /// <remarks>
  /// Use case: Background services, event handlers, or controllers
  /// that need to push real-time updates to connected clients.
  /// </remarks>
  IHubContext = interface
    ['{E5F6A7B8-C9D0-4E5F-2A3B-4C5D6E7F8A9B}']
    
    /// <summary>Gets access to client proxies.</summary>
    function GetClients: IHubClients;
    property Clients: IHubClients read GetClients;
    
    /// <summary>Gets access to group management.</summary>
    function GetGroups: IGroupManager;
    property Groups: IGroupManager read GetGroups;
  end;
  
  /// <summary>
  /// Generic Hub context for type-safe Hub access.
  /// Use IHubContext<TMyHub> in DI to access a specific Hub's clients.
  /// </summary>
  // Note: Generic interfaces require special handling in Delphi DI
  // Implementation will use TClass registration with type checking

  {$ENDREGION}  /// <summary>
  /// Represents an individual client connection to a Hub.
  /// </summary>
  IHubConnection = interface
    ['{F6A7B8C9-D0E1-4F5A-3B4C-5D6E7F8A9B0C}']
    
    /// <summary>Gets the unique connection identifier.</summary>
    function GetConnectionId: string;
    property ConnectionId: string read GetConnectionId;
    
    /// <summary>Gets the transport type for this connection.</summary>
    function GetTransportType: TTransportType;
    property TransportType: TTransportType read GetTransportType;
    
    /// <summary>Gets the current connection state.</summary>
    function GetState: TConnectionState;
    property State: TConnectionState read GetState;
    
    /// <summary>Gets the authenticated user (if any).</summary>
    function GetUser: IClaimsPrincipal;
    property User: IClaimsPrincipal read GetUser;
    
    /// <summary>Gets the user identifier from claims.</summary>
    function GetUserIdentifier: string;
    property UserIdentifier: string read GetUserIdentifier;
    
    /// <summary>Gets custom items dictionary for this connection.</summary>
    function GetItems: IDictionary<string, TValue>;
    property Items: IDictionary<string, TValue> read GetItems;
    
    /// <summary>Sends a raw message to this connection.</summary>
    procedure SendAsync(const Message: string);
    
    /// <summary>Closes the connection.</summary>
    procedure Close(const Reason: string = '');
    
    /// <summary>Gets the cancellation token for connection abort.</summary>
    function GetAbortToken: ICancellationToken;
    property AbortToken: ICancellationToken read GetAbortToken;
  end;
  
  /// <summary>
  /// Manages all active Hub connections.
  /// </summary>
  IConnectionManager = interface
    ['{A7B8C9D0-E1F2-4A5B-4C5D-6E7F8A9B0C1D}']
    
    /// <summary>Adds a new connection.</summary>
    procedure Add(const Connection: IHubConnection);
    
    /// <summary>Removes a connection by ID.</summary>
    procedure Remove(const ConnectionId: string);
    
    /// <summary>Tries to get a connection by ID.</summary>
    function TryGet(const ConnectionId: string; out Connection: IHubConnection): Boolean;
    
    /// <summary>Gets a connection by ID (raises if not found).</summary>
    function Get(const ConnectionId: string): IHubConnection;
    
    /// <summary>Gets all active connections.</summary>
    function GetAll: TArray<IHubConnection>;
    
    /// <summary>Gets all connections in a specific group.</summary>
    function GetByGroup(const GroupName: string): TArray<IHubConnection>;
    
    /// <summary>Gets all connections for a user.</summary>
    function GetByUser(const UserId: string): TArray<IHubConnection>;
    
    /// <summary>Gets the total count of active connections.</summary>
    function Count: Integer;
    
    /// <summary>Checks if a connection exists.</summary>
    function Contains(const ConnectionId: string): Boolean;
  end;

  {$ENDREGION}  /// <summary>
  /// Message type enumeration (SignalR-compatible).
  /// </summary>
  THubMessageType = (
    /// <summary>Method invocation (1)</summary>
    hmtInvocation = 1,
    /// <summary>Stream item (2)</summary>
    hmtStreamItem = 2,
    /// <summary>Invocation completion (3)</summary>
    hmtCompletion = 3,
    /// <summary>Stream invocation (4)</summary>
    hmtStreamInvocation = 4,
    /// <summary>Cancel stream (5)</summary>
    hmtCancelInvocation = 5,
    /// <summary>Ping/keep-alive (6)</summary>
    hmtPing = 6,
    /// <summary>Close connection (7)</summary>
    hmtClose = 7
  );
  
  /// <summary>
  /// Represents a Hub protocol message.
  /// </summary>
  THubMessage = record
    MessageType: THubMessageType;
    InvocationId: string;
    Target: string;
    Arguments: TArray<TValue>;
    Error: string;
    Result: TValue;
    
    class function Invocation(const Target: string; const Args: TArray<TValue>): THubMessage; static;
    class function Completion(const InvocationId: string; const AResult: TValue): THubMessage; static;
    class function CompletionError(const InvocationId, AError: string): THubMessage; static;
    class function Ping: THubMessage; static;
    class function Close(const Error: string = ''): THubMessage; static;
  end;
  
  /// <summary>
  /// Protocol serializer interface.
  /// Default: JSON. Future: MessagePack.
  /// </summary>
  IHubProtocol = interface
    ['{B8C9D0E1-F2A3-4B5C-5D6E-7F8A9B0C1D2E}']
    
    /// <summary>Gets the protocol name ('json' or 'messagepack').</summary>
    function GetName: string;
    property Name: string read GetName;
    
    /// <summary>Gets the protocol version.</summary>
    function GetVersion: Integer;
    property Version: Integer read GetVersion;
    
    /// <summary>Gets the transfer format ('Text' for JSON, 'Binary' for MessagePack).</summary>
    function GetTransferFormat: string;
    property TransferFormat: string read GetTransferFormat;
    
    /// <summary>Serializes a Hub message to string.</summary>
    function Serialize(const Message: THubMessage): string;
    
    /// <summary>Deserializes a string to Hub message.</summary>
    function Deserialize(const Data: string): THubMessage;

    /// <summary>Serializes a Hub message to its native wire representation.</summary>
    function SerializeBinary(const Message: THubMessage): TBytes;

    /// <summary>Deserializes one native wire message.</summary>
    function DeserializeBinary(const Data: TBytes; AOffset, ACount: Integer;
      out AConsumed: Integer): THubMessage;
    
    /// <summary>Checks if data is a complete message (for streaming).</summary>
    function IsCompleteMessage(const Data: string): Boolean;

    /// <summary>Checks if a complete native wire message is available.</summary>
    function IsCompleteBinary(const Data: TBytes; AOffset, ACount: Integer): Boolean;
  end;

  {$ENDREGION}  /// <summary>
  /// Event handler for when data is received from a connection.
  /// </summary>
  TOnMessageReceived = reference to procedure(const ConnectionId, Data: string);
  
  /// <summary>
  /// Event handler for connection lifecycle events.
  /// </summary>
  TOnConnectionEvent = reference to procedure(const ConnectionId: string);
  
  /// <summary>
  /// Base interface for Hub transports.
  /// </summary>
  IHubTransport = interface
    ['{C9D0E1F2-A3B4-4C5D-6E7F-8A9B0C1D2E3F}']
    
    /// <summary>Gets the transport type.</summary>
    function GetTransportType: TTransportType;
    property TransportType: TTransportType read GetTransportType;
    
    /// <summary>Checks if the transport is available/supported.</summary>
    function IsAvailable: Boolean;
    
    /// <summary>Sends data to a specific connection.</summary>
    procedure SendAsync(const ConnectionId, Data: string);
    
    /// <summary>Closes a connection.</summary>
    procedure CloseConnection(const ConnectionId: string; const Reason: string = '');
    
    /// <summary>Event when message received from client.</summary>
    procedure SetOnMessageReceived(const Handler: TOnMessageReceived);
    
    /// <summary>Event when client connects.</summary>
    procedure SetOnConnected(const Handler: TOnConnectionEvent);
    
    /// <summary>Event when client disconnects.</summary>
    procedure SetOnDisconnected(const Handler: TOnConnectionEvent);
  end;

  {$ENDREGION}  /// <summary>
  /// Interface for Hub lifecycle events.
  /// Implement in your Hub class.
  /// </summary>
  IHubLifecycle = interface
    ['{D0E1F2A3-B4C5-4D5E-7F8A-9B0C1D2E3F4A}']
    
    /// <summary>Called when a new client connects.</summary>
    procedure OnConnectedAsync;
    
    /// <summary>Called when a client disconnects.</summary>
    procedure OnDisconnectedAsync(const Exception: Exception);
  end;implementation

{ THubMessage }

class function THubMessage.Invocation(const Target: string; const Args: TArray<TValue>): THubMessage;
begin
  Result := Default(THubMessage);
  Result.MessageType := hmtInvocation;
  Result.Target := Target;
  Result.Arguments := Args;
end;

class function THubMessage.Completion(const InvocationId: string; const AResult: TValue): THubMessage;
begin
  Result := Default(THubMessage);
  Result.MessageType := hmtCompletion;
  Result.InvocationId := InvocationId;
  Result.Result := AResult;
end;

class function THubMessage.CompletionError(const InvocationId, AError: string): THubMessage;
begin
  Result := Default(THubMessage);
  Result.MessageType := hmtCompletion;
  Result.InvocationId := InvocationId;
  Result.Error := AError;
end;

class function THubMessage.Ping: THubMessage;
begin
  Result := Default(THubMessage);
  Result.MessageType := hmtPing;
end;

class function THubMessage.Close(const Error: string): THubMessage;
begin
  Result := Default(THubMessage);
  Result.MessageType := hmtClose;
  Result.Error := Error;
end;

end.
