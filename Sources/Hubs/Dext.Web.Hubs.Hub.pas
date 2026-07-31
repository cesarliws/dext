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
{    Base Hub class for real-time communication.                            }
{    Developers inherit from THub to create their own Hubs.                 }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs.Hub;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Web.Hubs.Interfaces;

type
  /// <summary>
  /// Base class for Hub implementations.
  /// Inherit from this class and annotate client-invokable methods with
  /// HubMethod. Other public methods remain server-side only.
  /// </summary>
  /// <example>
  /// <code>
  ///   TMyHub = class(THub)
  ///   public
  ///     [HubMethod]
  ///     procedure SendMessage(const User, Message: string);
  ///     [HubMethod]
  ///     procedure JoinGroup(const GroupName: string);
  ///   end;
  /// 
  ///   procedure TMyHub.SendMessage(const User, Message: string);
  ///   begin
  ///     // Broadcast to all clients
  ///     Clients.All.SendAsync('ReceiveMessage', [User, Message]);
  ///   end;
  /// 
  ///   procedure TMyHub.JoinGroup(const GroupName: string);
  ///   begin
  ///     Groups.AddToGroupAsync(Context.ConnectionId, GroupName);
  ///   end;
  /// </code>
  /// </example>
  THub = class(TInterfacedObject, IHubLifecycle)
  private
    FContext: IHubCallerContext;
    FClients: IHubClients;
    FGroups: IGroupManager;
  protected
    /// <summary>
    /// Gets the caller context with connection information.
    /// </summary>
    property Context: IHubCallerContext read FContext;
    
    /// <summary>
    /// Gets access to connected clients for sending messages.
    /// </summary>
    property Clients: IHubClients read FClients;
    
    /// <summary>
    /// Gets access to group management.
    /// </summary>
    property Groups: IGroupManager read FGroups;
  public
    /// <summary>
    /// Called when a client connects to this Hub.
    /// Override to implement custom connection logic.
    /// </summary>
    procedure OnConnectedAsync; virtual;
    
    /// <summary>
    /// Called when a client disconnects from this Hub.
    /// Override to implement custom disconnection logic.
    /// </summary>
    /// <param name="Exception">The exception that caused disconnect, if any.</param>
    procedure OnDisconnectedAsync(const Exception: Exception); virtual;
    
    /// <summary>
    /// Internal: Sets the Hub context. Called by the Hub dispatcher.
    /// </summary>
    procedure SetContext(const AContext: IHubCallerContext; 
                         const AClients: IHubClients;
                         const AGroups: IGroupManager);
  end;
  
  /// <summary>
  /// Hub class reference type for registration.
  /// </summary>
  THubClass = class of THub;

implementation

{ THub }

procedure THub.OnConnectedAsync;
begin
  // Default: no-op. Override in subclass if needed.
end;

procedure THub.OnDisconnectedAsync(const Exception: Exception);
begin
  // Default: no-op. Override in subclass if needed.
end;

procedure THub.SetContext(const AContext: IHubCallerContext;
  const AClients: IHubClients; const AGroups: IGroupManager);
begin
  FContext := AContext;
  FClients := AClients;
  FGroups := AGroups;
end;

end.
