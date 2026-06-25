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
{  Created: 2025-12-21                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Hosting.AppState;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  System.SyncObjs,
  Dext.Events.Interfaces;

type
  /// <summary>Defines the high-level application lifecycle states.</summary>
  TApplicationState = (
    /// <summary>Application in startup phase and loading DI.</summary>
    asStarting,
    /// <summary>Executing pending database migrations.</summary>
    asMigrating,
    /// <summary>Populating initial data (seeding).</summary>
    asSeeding,
    /// <summary>Ready to process requests.</summary>
    asRunning,
    /// <summary>In process of graceful shutdown.</summary>
    asStopping,
    /// <summary>Application completely stopped.</summary>
    asStopped
  );

  /// <summary>
  ///   Event published via IEventBus on each application state transition.
  ///   Subscribe with IEventHandler<TAppStateChangedEvent> for decoupled monitoring.
  /// </summary>
  TAppStateChangedEvent = record
    /// <summary>The state before the transition.</summary>
    PreviousState: TApplicationState;
    /// <summary>The new state after the transition.</summary>
    NewState: TApplicationState;
    /// <summary>Timestamp of the transition (UTC).</summary>
    Timestamp: TDateTime;
  end;

  /// <summary>Read-only interface for observing current application state.</summary>
  IAppStateObserver = interface
    ['{8A9B1C2D-3E4F-5A6B-7C8D-9E0F1A2B3C4D}']
    function GetState: TApplicationState;
    /// <summary>Returns True if the application is in the asRunning state.</summary>
    function IsReady: Boolean;
    property State: TApplicationState read GetState;
  end;

  /// <summary>
  ///   Allows changing the application state.
  /// </summary>
  IAppStateControl = interface
    ['{1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']
    procedure SetState(AState: TApplicationState);
  end;

  /// <summary>
  ///   Singleton service that manages application state in a thread-safe way.
  /// </summary>
  TApplicationStateManager = class(TInterfacedObject, IAppStateObserver, IAppStateControl)
  private
    FState: TApplicationState;
    FLock: TCriticalSection;
    FEventBus: IEventBus;
    procedure PublishStateEvent(APrevious, ANew: TApplicationState);
  public
    constructor Create; overload;
    /// <summary>Creates the manager with an event bus for publishing state transitions.</summary>
    constructor Create(const AEventBus: IEventBus); overload;
    destructor Destroy; override;

    function GetState: TApplicationState;
    procedure SetState(AState: TApplicationState);
    function IsReady: Boolean;
  end;

implementation

uses
  System.DateUtils;

{ TApplicationStateManager }

constructor TApplicationStateManager.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
  FState := asStarting;
end;

constructor TApplicationStateManager.Create(const AEventBus: IEventBus);
begin
  Create;
  FEventBus := AEventBus;
end;

destructor TApplicationStateManager.Destroy;
begin
  FEventBus := nil;
  FLock.Free;
  inherited;
end;

function TApplicationStateManager.GetState: TApplicationState;
begin
  FLock.Enter;
  try
    Result := FState;
  finally
    FLock.Leave;
  end;
end;

function TApplicationStateManager.IsReady: Boolean;
begin
  Result := GetState = asRunning;
end;

procedure TApplicationStateManager.PublishStateEvent(APrevious, ANew: TApplicationState);
var
  Event: TAppStateChangedEvent;
  EventValue: TValue;
begin
  if not Assigned(FEventBus) then
    Exit;
  try
    Event.PreviousState := APrevious;
    Event.NewState := ANew;
    Event.Timestamp := TTimeZone.Local.ToUniversalTime(Now);
    TValue.Make(@Event, TypeInfo(TAppStateChangedEvent), EventValue);
    FEventBus.Dispatch(TypeInfo(TAppStateChangedEvent), EventValue);
  except
    // State events are best-effort - never block state transitions
  end;
end;

procedure TApplicationStateManager.SetState(AState: TApplicationState);
var
  Previous: TApplicationState;
begin
  FLock.Enter;
  try
    Previous := FState;
    FState := AState;
  finally
    FLock.Leave;
  end;

  // Publish outside lock to avoid deadlocks with event handlers
  if Previous <> AState then
    PublishStateEvent(Previous, AState);
end;

end.
