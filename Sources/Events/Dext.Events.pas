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

/// <summary>
///   Facade unit for the Dext Event Bus.
///   Add this single unit to your uses clause to access the complete
///   event bus API: interfaces, built-in behaviors, DI extensions, and
///   application lifecycle events.
///
///   Quick-start example:
///
///   // 1. Define an event (record or class)
///   type
///     TOrderCreatedEvent = record
///       OrderId: Integer;
///       CustomerId: Integer;
///     end;
///
///   // 2. Implement a handler
///   type
///     TOrderCreatedHandler = class(TInterfacedObject,
///       IEventHandler&lt;TOrderCreatedEvent&gt;)
///     private
///       FMailer: IMailService;  // injected via constructor
///     public
///       constructor Create(const AMailer: IMailService);
///       procedure Handle(const AEvent: TOrderCreatedEvent);
///     end;
///
///   // 3. Register at startup
///   Services
///     .AddEventBus
///     .AddEventHandler&lt;TOrderCreatedEvent, TOrderCreatedHandler&gt;
///     .AddEventPublisher&lt;TOrderCreatedEvent&gt;       // typed publisher (preferred)
///     .AddEventBehavior&lt;TEventExceptionBehavior&gt;
///     .AddEventBehavior&lt;TEventLoggingBehavior&gt;;
///
///   // 4. Inject and publish (preferred - typed, ISP-compliant)
///   constructor TMyService.Create(
///     const APublisher: IEventPublisher&lt;TOrderCreatedEvent&gt;);
///   FPublisher.Publish(Event);
///
///   // Alternative: inject IEventBus for multi-event publishers
///   TEventBusExtensions.Publish&lt;TOrderCreatedEvent&gt;(FBus, Event);
/// </summary>
unit Dext.Events;

interface

uses
  // Public interfaces: IEventBus, IEventHandler<T>, IEventBehavior,
  // IEventPublisher<T>, TEventNextDelegate, TEventBusExtensions,
  // EEventBusException, EEventDispatchException, EEventDispatchAggregate
  Dext.Events.Interfaces,

  // Built-in behaviors: TEventLoggingBehavior (ILogger sink, production),
  // TEventTimingBehavior (OutputDebugString, dev-only),
  // TEventExceptionBehavior (structured error wrapping)
  Dext.Events.Behaviors,

  // Fluent DI extensions: TEventBusDIExtensions record helper on TDextServices
  // Adds: AddEventBus, AddScopedEventBus, AddEventHandler<TEvent,THandler>,
  //       AddEventBehavior<TBehavior>, AddEventBehaviorFor<TEvent,TBehavior>,
  //       AddEventPublisher<T>, AddEventBusLifecycle
  Dext.Events.Extensions,

  // Lifecycle bridge: TApplicationStartedEvent, TApplicationStoppingEvent,
  // TApplicationStoppedEvent, TEventBusLifecycleService
  Dext.Events.Lifecycle;

implementation

end.
