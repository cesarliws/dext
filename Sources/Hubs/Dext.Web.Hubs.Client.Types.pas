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
unit Dext.Web.Hubs.Client.Types;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Dext.Web.Hubs.Interfaces;

type
  /// <summary>
  /// Represents the connection state of the Hub Client.
  /// </summary>
  THubConnectionState = TConnectionState;

  /// <summary>
  /// Represents the transport protocol used by the Hub Client.
  /// </summary>
  TClientTransportType = (
    /// <summary>Full duplex WebSocket transport.</summary>
    ctWebSocket,
    /// <summary>Server-Sent Events transport.</summary>
    ctServerSentEvents
  );

  /// <summary>
  /// Callback interface for custom/dynamic server method invocations.
  /// </summary>
  IHubCallback = interface
    ['{8A5D6C7B-4E3D-2C1B-0A9F-8E7D6C5B4A30}']
    /// <summary>
    /// Executes the registered callback with arguments from the server.
    /// </summary>
    procedure Execute(const AArgs: TArray<TValue>);
  end;

  /// <summary>
  /// Callback event raised when the Hub Client connects successfully.
  /// </summary>
  TOnHubConnected = reference to procedure(const AConnectionId: string);

  /// <summary>
  /// Callback event raised when the Hub Client disconnects.
  /// </summary>
  TOnHubDisconnected = reference to procedure(const AError: Exception);
  
  /// <summary>
  /// Callback with a typed return value from a server invocation.
  /// </summary>
  TInvokeCallback<T> = reference to procedure(const AResult: T; const AError: Exception);

  /// <summary>
  /// Defines the client connection to a Hub server compatible with Dext Hubs and SignalR.
  /// </summary>
  IDextHubConnection = interface
    ['{A9B8C7D6-E5F4-3C2B-1A0F-9E8D7C6B5A40}']
    /// <summary>Gets the current state of the connection.</summary>
    function GetState: THubConnectionState;
    /// <summary>Gets the connection ID assigned by the server.</summary>
    function GetConnectionId: string;
    
    /// <summary>Starts the hub connection asynchronously.</summary>
    procedure Start;
    /// <summary>Stops the hub connection and tears down transports.</summary>
    procedure Stop;
    
    /// <summary>Subscribes to a server method invocation receiving one string argument.</summary>
    procedure On(const AEventName: string; const ACallback: TProc<string>); overload;
    /// <summary>Subscribes to a server method invocation receiving two string arguments.</summary>
    procedure On(const AEventName: string; const ACallback: TProc<string, string>); overload;
    /// <summary>Subscribes to a server method invocation using custom arguments types.</summary>
    procedure On(const AEventName: string; const AArgTypes: TArray<PTypeInfo>; const ACallbackRef: IHubCallback); overload;
    
    /// <summary>Binds a callback to be executed when the connection succeeds.</summary>
    procedure OnConnected(const ACallback: TOnHubConnected);
    /// <summary>Binds a callback to be executed when the connection disconnects.</summary>
    procedure OnDisconnected(const ACallback: TOnHubDisconnected);

    /// <summary>Sends a message to the server without expecting a response (fire-and-forget).</summary>
    procedure Send(const AMethodName: string; const AArgs: TArray<TValue>);
    
    /// <summary>Invokes a server method expecting a response (used by generic helper).</summary>
    procedure Invoke(const AMethodName: string; const AArgs: TArray<TValue>; 
      const AResultType: PTypeInfo; const ACallback: TValue);

    /// <summary>Gets the current state of the connection.</summary>
    property State: THubConnectionState read GetState;
    /// <summary>Gets the connection ID.</summary>
    property ConnectionId: string read GetConnectionId;
  end;

  /// <summary>
  /// Static generic helper to call generic methods on the IDextHubConnection interface.
  /// </summary>
  TConnectionHelper = class
  public
    /// <summary>Invokes a server method expecting a return value of type T.</summary>
    class procedure Invoke<T>(const AConnection: IDextHubConnection; const AMethodName: string;
      const AArgs: TArray<TValue>; const ACallback: TInvokeCallback<T>); static;
  end;

implementation

{ TConnectionHelper }

class procedure TConnectionHelper.Invoke<T>(const AConnection: IDextHubConnection;
  const AMethodName: string; const AArgs: TArray<TValue>; const ACallback: TInvokeCallback<T>);
begin
  if Assigned(AConnection) then
    AConnection.Invoke(AMethodName, AArgs, TypeInfo(T), TValue.From<TInvokeCallback<T>>(ACallback));
end;

end.
