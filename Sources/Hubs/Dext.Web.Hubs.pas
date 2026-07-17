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
{    Main Dext.Hubs unit - exports all Hub types for easy usage.            }
{                                                                           }
{  Usage:                                                                   }
{    uses Dext.Hubs;                                                        }
{                                                                           }
{    type                                                                   }
{      TMyHub = class(THub)                                                 }
{      public                                                               }
{        [HubMethod]                                                        }
{        procedure SendMessage(const Text: string);                         }
{      end;                                                                 }
{                                                                           }
{    // In configuration:                                                   }
{    App.MapHub<TMyHub>('/hubs/chat');                                      }
{                                                                           }
{    // Send from anywhere:                                                 }
{    Context := Services.GetService<IHubContext>;                           }
{    Context.Clients.All.SendAsync('Notify', ['Hello!']);                   }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs;

{$I Dext.inc}

interface

uses
  // Re-export all Hub types for easy access
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Types,
  Dext.Web.Hubs.Hub,
  Dext.Web.Hubs.Connections,
  Dext.Web.Hubs.Clients,
  Dext.Web.Hubs.Context,
  Dext.Web.Hubs.Protocol.Json,
  Dext.Web.Hubs.Extensions,
  Dext.Web.Hubs.Middleware,
  Dext.Web.Hubs.Transport.SSE;

type
  // Re-export commonly used types
  THub = Dext.Web.Hubs.Hub.THub;
  THubClass = Dext.Web.Hubs.Hub.THubClass;
  
  // Interfaces
  IClientProxy = Dext.Web.Hubs.Interfaces.IClientProxy;
  IHubClients = Dext.Web.Hubs.Interfaces.IHubClients;
  IGroupManager = Dext.Web.Hubs.Interfaces.IGroupManager;
  IHubCallerContext = Dext.Web.Hubs.Interfaces.IHubCallerContext;
  IHubContext = Dext.Web.Hubs.Interfaces.IHubContext;
  IHubConnection = Dext.Web.Hubs.Interfaces.IHubConnection;
  IConnectionManager = Dext.Web.Hubs.Interfaces.IConnectionManager;
  IHubProtocol = Dext.Web.Hubs.Interfaces.IHubProtocol;
  IHubTransport = Dext.Web.Hubs.Interfaces.IHubTransport;
  IHubLifecycle = Dext.Web.Hubs.Interfaces.IHubLifecycle;
  
  // Types
  TTransportType = Dext.Web.Hubs.Interfaces.TTransportType;
  TConnectionState = Dext.Web.Hubs.Interfaces.TConnectionState;
  THubMessageType = Dext.Web.Hubs.Interfaces.THubMessageType;
  THubMessage = Dext.Web.Hubs.Interfaces.THubMessage;
  THubOptions = Dext.Web.Hubs.Types.THubOptions;
  TNegotiateResponse = Dext.Web.Hubs.Types.TNegotiateResponse;
  HubMethodAttribute = Dext.Web.Hubs.Types.HubMethodAttribute;
  
  // Implementations
  THubConnection = Dext.Web.Hubs.Connections.THubConnection;
  TConnectionManager = Dext.Web.Hubs.Connections.TConnectionManager;
  TGroupManager = Dext.Web.Hubs.Connections.TGroupManager;
  THubClients = Dext.Web.Hubs.Clients.THubClients;
  TJsonHubProtocol = Dext.Web.Hubs.Protocol.Json.TJsonHubProtocol;
  
  // Exceptions
  EHubException = Dext.Web.Hubs.Types.EHubException;
  EConnectionNotFoundException = Dext.Web.Hubs.Types.EConnectionNotFoundException;
  EHubMethodNotFoundException = Dext.Web.Hubs.Types.EHubMethodNotFoundException;
  EHubInvocationException = Dext.Web.Hubs.Types.EHubInvocationException;
  EHubPayloadTooLargeException = Dext.Web.Hubs.Types.EHubPayloadTooLargeException;

implementation

end.
