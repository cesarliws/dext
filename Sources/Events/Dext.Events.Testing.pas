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
{  Created: 2026-03-19                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Events.Testing;

/// <summary>
///   Test utilities for the Dext Event Bus.
///
///   Usage:
///   <code>
///     var 
///       Tracker: TEventBusTracker;
///       All: TArray&lt;TOrderCreatedEvent&gt;;
///     begin
///     TEventBusTracker.Register(Services, Tracker)
///       .AddEventPublisher&lt;TOrderCreatedEvent&gt;
///       .AddTransient&lt;IMyService, TMyService&gt;;
///     // ... build provider and exercise code under test ...
///     CheckTrue(Tracker.HasPublished&lt;TOrderCreatedEvent&gt;);
///     CheckEquals(1, Tracker.PublishedCount&lt;TOrderCreatedEvent&gt;);
///     CheckEquals(42, Tracker.LastPublished&lt;TOrderCreatedEvent&gt;.OrderId);
///     All := Tracker.GetPublished&lt;TOrderCreatedEvent&gt;;
///   </code>
/// </summary>

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.TypInfo,
  System.Rtti,
  Dext.Collections,
  Dext,
  Dext.DI.Interfaces,
  Dext.Events.Interfaces;

type
  /// <summary>
  ///   Fake IEventBus for unit tests. Records every published event in an
  ///   IList<TValue> (TRawList backend) for deterministic assertions.
  ///   PublishBackground is synchronous - no sleep/wait needed in tests.
  ///   Thread-safe for tests that publish from multiple threads.
  /// </summary>
  TEventBusTracker = class(TInterfacedObject, IEventBus)
    // Interface method resolution - avoids conflict with TObject.Dispatch.
    function IEventBus.Dispatch           = TrackerDispatch;
    procedure IEventBus.DispatchBackground = TrackerDispatchBackground;
  private
    FEvents: IList<TValue>;
    FLock: TCriticalSection;
    // IEventBus implementation (bound via resolution clause above)
    function TrackerDispatch(AEventType: PTypeInfo;
      const AEvent: TValue): TPublishResult;
    procedure TrackerDispatchBackground(AEventType: PTypeInfo;
      const AEvent: TValue);
  public
    constructor Create;
    destructor Destroy; override;

    // --- Assertion helpers ---

    /// <summary>Returns True if at least one event of type T was published.</summary>
    function HasPublished<T>: Boolean;

    /// <summary>Returns the count of published events of type T.</summary>
    function PublishedCount<T>: Integer;

    /// <summary>
    ///   Returns all published events of type T in publication order.
    /// </summary>
    function GetPublished<T>: TArray<T>;

    /// <summary>
    ///   Returns the most recently published event of type T.
    ///   Raises EEventBusException if none were published.
    /// </summary>
    function LastPublished<T>: T;

    /// <summary>Clears all recorded events (useful between test cases).</summary>
    procedure Clear;

    /// <summary>
    ///   Registers a new TEventBusTracker as the IEventBus singleton on
    ///   AServices and outputs the instance via ATracker.
    ///   Call instead of AddEventBus in test setup.
    ///   Returns AServices so callers can chain AddEventPublisher / AddTransient.
    ///
    ///   Usage:
    ///   <code>
    ///     var Tracker: TEventBusTracker;
    ///     TEventBusTracker.Register(Services, Tracker)
    ///       .AddEventPublisher&lt;TOrderPlacedEvent&gt;
    ///       .AddTransient&lt;IOrderService, TOrderService&gt;;
    ///   </code>
    /// </summary>
    class function Register(const AServices: TDextServices;
      out ATracker: TEventBusTracker): TDextServices; static;
  end;

implementation

uses
  Dext.DI.Core; // for TServiceType

{ TEventBusTracker }

constructor TEventBusTracker.Create;
begin
  inherited Create;
  FEvents := TCollections.CreateList<TValue>;
  FLock   := TCriticalSection.Create;
end;

destructor TEventBusTracker.Destroy;
begin
  FLock.Free;
  FEvents := nil;
  inherited;
end;

function TEventBusTracker.TrackerDispatch(AEventType: PTypeInfo;
  const AEvent: TValue): TPublishResult;
begin
  FLock.Enter;
  try
    FEvents.Add(AEvent);
  finally
    FLock.Leave;
  end;
  Result.EventTypeName   := string(AEventType.Name);
  Result.HandlersInvoked := 0; // tracker has no real handlers
  Result.HandlersFailed  := 0;
end;

procedure TEventBusTracker.TrackerDispatchBackground(AEventType: PTypeInfo;
  const AEvent: TValue);
begin
  // Synchronous in the test double - avoids timing dependencies in assertions.
  TrackerDispatch(AEventType, AEvent);
end;

function TEventBusTracker.HasPublished<T>: Boolean;
var
  V: TValue;
  Expected: PTypeInfo;
begin
  Result := False;
  Expected := TypeInfo(T);
  FLock.Enter;
  try
    for V in FEvents do
      if V.TypeInfo = Expected then
        Exit(True);
  finally
    FLock.Leave;
  end;
end;

function TEventBusTracker.PublishedCount<T>: Integer;
var
  V: TValue;
  Expected: PTypeInfo;
begin
  Result := 0;
  Expected := TypeInfo(T);
  FLock.Enter;
  try
    for V in FEvents do
      if V.TypeInfo = Expected then
        Inc(Result);
  finally
    FLock.Leave;
  end;
end;

function TEventBusTracker.GetPublished<T>: TArray<T>;
var
  V: TValue;
  Expected: PTypeInfo;
  Matched: IList<T>;
begin
  Expected := TypeInfo(T);
  Matched := TCollections.CreateList<T>;
  FLock.Enter;
  try
    for V in FEvents do
      if V.TypeInfo = Expected then
        Matched.Add(V.AsType<T>);
  finally
    FLock.Leave;
  end;
  Result := Matched.ToArray;
end;

function TEventBusTracker.LastPublished<T>: T;
var
  V: TValue;
  Expected: PTypeInfo;
  Found: Boolean;
begin
  Result   := Default(T); // suppress W1035 - raise below ensures caller never sees this
  Expected := TypeInfo(T);
  Found := False;
  FLock.Enter;
  try
    for V in FEvents do
      if V.TypeInfo = Expected then
      begin
        Result := V.AsType<T>;
        Found := True;
      end;
  finally
    FLock.Leave;
  end;
  if not Found then
    raise EEventBusException.CreateFmt(
      'No event of type "%s" was published.', [string(Expected.Name)]);
end;

procedure TEventBusTracker.Clear;
begin
  FLock.Enter;
  try
    FEvents.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TEventBusTracker - static registration helper }

class function TEventBusTracker.Register(const AServices: TDextServices;
  out ATracker: TEventBusTracker): TDextServices;
var
  Tracker: TEventBusTracker;
begin
  Tracker := TEventBusTracker.Create;
  ATracker := Tracker;
  AServices.Unwrap.AddSingleton(
    TServiceType.FromInterface(TypeInfo(IEventBus)),
    Tracker as TObject
  );
  Result := AServices;
end;

end.
