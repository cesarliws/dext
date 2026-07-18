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
{    IHubContext implementation for accessing Hubs from outside Hub class.  }
{    Register with DI to send messages from anywhere in the application.    }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs.Context;

{$I Dext.inc}

interface

uses
  System.Rtti,
  System.SysUtils,
  Dext.Auth.Identity,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Threading.CancellationToken,
  Dext.Web.Hubs.Clients,
  Dext.Web.Hubs.Connections,
  Dext.Web.Hubs.Interfaces;

type
  /// <summary>
  /// Default implementation of IHubContext.
  /// Provides access to Hub clients and groups from outside a Hub class.
  /// </summary>
  THubContext = class(TInterfacedObject, IHubContext)
  private
    FConnectionManager: IConnectionManager;
    FGroupManager: IGroupManager;
  public
    constructor Create(const AConnectionManager: IConnectionManager;
                       const AGroupManager: IGroupManager);
    
    function GetClients: IHubClients;
    function GetGroups: IGroupManager;
    
    property Clients: IHubClients read GetClients;
    property Groups: IGroupManager read GetGroups;
  end;
  
  /// <summary>
  /// Implementation of IHubCallerContext.
  /// Provides connection information during Hub method invocation.
  /// </summary>
  THubCallerContext = class(TInterfacedObject, IHubCallerContext)
  private
    FConnectionId: string;
    FUser: IClaimsPrincipal;
    FItems: IDictionary<string, TValue>;
    FAbortToken: ICancellationToken;
    FTransportType: TTransportType;
    FAbortHandler: TProc;
  public
    constructor Create(const AConnectionId: string;
                       ATransportType: TTransportType;
                       const AUser: IClaimsPrincipal = nil;
                       const AAbortToken: ICancellationToken = nil;
                       const AAbortHandler: TProc = nil);
    destructor Destroy; override;
    
    function GetConnectionId: string;
    function GetUserIdentifier: string;
    function GetUser: IClaimsPrincipal;
    function GetItems: IDictionary<string, TValue>;
    function GetConnectionAborted: ICancellationToken;
    function GetTransportType: TTransportType;
    procedure Abort;
    
    property ConnectionId: string read GetConnectionId;
    property UserIdentifier: string read GetUserIdentifier;
    property User: IClaimsPrincipal read GetUser;
    property Items: IDictionary<string, TValue> read GetItems;
    property ConnectionAborted: ICancellationToken read GetConnectionAborted;
    property TransportType: TTransportType read GetTransportType;
  end;

implementation

{ THubContext }

constructor THubContext.Create(const AConnectionManager: IConnectionManager;
  const AGroupManager: IGroupManager);
begin
  inherited Create;
  FConnectionManager := AConnectionManager;
  FGroupManager := AGroupManager;
end;

function THubContext.GetClients: IHubClients;
begin
  Result := THubClients.Create(FConnectionManager);
end;

function THubContext.GetGroups: IGroupManager;
begin
  Result := FGroupManager;
end;

{ THubCallerContext }

constructor THubCallerContext.Create(const AConnectionId: string;
  ATransportType: TTransportType; const AUser: IClaimsPrincipal;
  const AAbortToken: ICancellationToken; const AAbortHandler: TProc);
begin
  inherited Create;
  FConnectionId := AConnectionId;
  FTransportType := ATransportType;
  FUser := AUser;
  FAbortToken := AAbortToken;
  FAbortHandler := AAbortHandler;
  FItems := TCollections.CreateDictionary<string, TValue>;
end;

destructor THubCallerContext.Destroy;
begin
  // FItems is ARC
  inherited;
end;

function THubCallerContext.GetConnectionId: string;
begin
  Result := FConnectionId;
end;

function THubCallerContext.GetUserIdentifier: string;
begin
  if FUser <> nil then
    Result := FUser.FindClaim('sub').Value
  else
    Result := '';
end;

function THubCallerContext.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

function THubCallerContext.GetItems: IDictionary<string, TValue>;
begin
  Result := FItems;
end;

function THubCallerContext.GetConnectionAborted: ICancellationToken;
begin
  Result := FAbortToken;
end;

function THubCallerContext.GetTransportType: TTransportType;
begin
  Result := FTransportType;
end;

procedure THubCallerContext.Abort;
begin
  if Assigned(FAbortHandler) then
    FAbortHandler();
end;

end.
