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
unit Dext.Events.Lifecycle;

/// <summary>
///   IHostApplicationLifetime bridge for the Dext Event Bus.
///
///   Publishes three lifecycle events as the application progresses:
///     TApplicationStartedEvent   - after the host finishes startup
///     TApplicationStoppingEvent  - when a graceful shutdown is requested
///     TApplicationStoppedEvent   - after all requests have drained
///
///   Registration:
///   <code>
///     Services
///       .AddEventBus
///       .AddEventHandler<TApplicationStartedEvent, TMyStartupHandler>
///       .AddEventBusLifecycle;   // must be called LAST
///   </code>
///
///   If your application also uses other background services, register the
///   lifecycle service inside your own TBackgroundServiceBuilder instead of
///   calling AddEventBusLifecycle:
///   <code>
///     Services
///       .AddEventBus
///       .AddEventHandler<TApplicationStartedEvent, TMyStartupHandler>;
///     Services.AddBackgroundServices
///       .AddHostedService<TMyWorker>
///       .Build;
///     // Then add the lifecycle service directly to the same builder, or
///     // register TEventBusLifecycleService via the class-singleton factory
///     // and include it in the background services builder above.
///   </code>
/// </summary>

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Dext.Threading.CancellationToken,
  Dext.Hosting.ApplicationLifetime,
  Dext.Hosting.BackgroundService,
  Dext.Hosting.Events,
  Dext.Events.Interfaces;

type
  // ---------------------------------------------------------------------------
  // Background service that bridges IHostApplicationLifetime → IEventBus
  // ---------------------------------------------------------------------------

  /// <summary>
  ///   Watches IHostApplicationLifetime tokens and publishes the corresponding
  ///   lifecycle events onto the IEventBus in order:
  ///   Started → Stopping → Stopped.
  ///
  ///   Runs on its own background thread via TBackgroundService so it never
  ///   blocks the main application thread. Each Publish call is synchronous
  ///   from the service's thread perspective, ensuring events are delivered in
  ///   the correct order.
  ///
  ///   Register via Services.AddEventBusLifecycle.
  /// </summary>
  TEventBusLifecycleService = class(TBackgroundService)
  private
    FEventBus: IEventBus;
    FLifetime: IHostApplicationLifetime;
  protected
    procedure Execute(Token: ICancellationToken); override;
  public
    constructor Create(const AEventBus: IEventBus;
      const ALifetime: IHostApplicationLifetime);
  end;

implementation

{ TEventBusLifecycleService }

constructor TEventBusLifecycleService.Create(const AEventBus: IEventBus;
  const ALifetime: IHostApplicationLifetime);
begin
  inherited Create;
  FEventBus := AEventBus;
  FLifetime := ALifetime;
end;

procedure TEventBusLifecycleService.Execute(Token: ICancellationToken);

  /// Waits for a lifetime token to fire (be "cancelled") while also checking
  /// the service's own cancellation token every 100 ms.
  function WaitForSignal(const ASignal: ICancellationToken): Boolean;
  var
    WR: TWaitResult;
  begin
    repeat
      WR := ASignal.WaitForCancellation(100);
    until (WR = wrSignaled) or Token.IsCancellationRequested;
    Result := not Token.IsCancellationRequested;
  end;

begin
  // --- ApplicationStarted ---
  if WaitForSignal(FLifetime.ApplicationStarted) then
  try
    TEventBusExtensions.Publish<TApplicationStartedEvent>(
      FEventBus, Default(TApplicationStartedEvent));
  except
    on E: EEventBusException do ; // handlers reported their own errors
  end;

  if Token.IsCancellationRequested then Exit;

  // --- ApplicationStopping ---
  if WaitForSignal(FLifetime.ApplicationStopping) then
  try
    TEventBusExtensions.Publish<TApplicationStoppingEvent>(
      FEventBus, Default(TApplicationStoppingEvent));
  except
    on E: EEventBusException do ;
  end;

  if Token.IsCancellationRequested then Exit;

  // --- ApplicationStopped ---
  if WaitForSignal(FLifetime.ApplicationStopped) then
  try
    TEventBusExtensions.Publish<TApplicationStoppedEvent>(
      FEventBus, Default(TApplicationStoppedEvent));
  except
    on E: EEventBusException do ;
  end;
end;

end.
