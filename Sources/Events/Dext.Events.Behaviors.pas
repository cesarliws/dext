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
unit Dext.Events.Behaviors;

/// <summary>
///   Built-in pipeline behaviors for the Dext Event Bus.
///
///   Register individually as needed:
///     Services.AddEventBehavior<TEventLoggingBehavior>()    // production
///     Services.AddEventBehavior<TEventExceptionBehavior>()  // structured wrapping
///     Services.AddEventBehavior<TEventTimingBehavior>()     // debug-only (OutputDebugString)
///
///   Behaviors execute in registration order - first registered runs outermost.
///   Recommended order for production:
///     TEventExceptionBehavior (outer) → TEventLoggingBehavior (inner) → handler
/// </summary>

interface

uses
  System.SysUtils,
  System.Diagnostics,
  System.TypInfo,
  System.Rtti,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  Dext.Logging,
  Dext.Events.Interfaces;

type
  /// <summary>
  ///   Production-ready logging behavior for the Dext Event Bus.
  ///   Writes structured entries to Dext's ILogger on every handler dispatch.
  ///
  ///   Log levels:
  ///   - Debug  - "Handling {EventName}" before invoking the next step.
  ///   - Debug  - "Handled {EventName} in {N}ms" after successful dispatch.
  ///   - Error  - "{EventName} handler raised {ExceptionMessage}" on failure
  ///              (exception is re-raised so the pipeline can continue).
  ///
  ///   Registration (global - applies to every event type):
  ///   <code>
  ///     Services
  ///       .AddEventBus
  ///       .AddEventBehavior<TEventLoggingBehavior>
  ///       ...
  ///   </code>
  ///   TActivator resolves ILoggerFactory automatically from the DI container.
  /// </summary>
  TEventLoggingBehavior = class(TInterfacedObject, IEventBehavior)
  private
    FLogger: ILogger;
  public
    constructor Create(const ALoggerFactory: ILoggerFactory);
    procedure Intercept(AEventType: PTypeInfo; const AEvent: TValue;
      const ANext: TEventNextDelegate);
  end;

  /// <summary>
  ///   Records event dispatch timing to the debug output.
  ///   Writes the event type name and elapsed milliseconds after each handler call.
  ///   Replace with ILogger injection for production sinks (see remarks).
  /// </summary>
  /// <remarks>
  ///   To route output to a structured logger, subclass and override Handle:
  ///   <code>
  ///     TLoggingTimingBehavior = class(TEventTimingBehavior)
  ///       FLogger: ILogger;
  ///       constructor Create(const ALogger: ILogger);
  ///       // Override Handle to call FLogger instead of OutputDebugString
  ///     end;
  ///   </code>
  /// </remarks>
  TEventTimingBehavior = class(TInterfacedObject, IEventBehavior)
  public
    procedure Intercept(AEventType: PTypeInfo; const AEvent: TValue;
      const ANext: TEventNextDelegate);
  end;

  /// <summary>
  ///   Wraps each handler invocation in a structured try/except block.
  ///   Catches all exceptions, enriches them with event context, and re-raises
  ///   as EEventDispatchException so callers can distinguish event bus failures.
  ///   Already-wrapped EEventDispatchException instances are re-raised as-is
  ///   to preserve the original context through nested dispatch.
  /// </summary>
  TEventExceptionBehavior = class(TInterfacedObject, IEventBehavior)
  public
    procedure Intercept(AEventType: PTypeInfo; const AEvent: TValue;
      const ANext: TEventNextDelegate);
  end;

implementation

{ TEventLoggingBehavior }

constructor TEventLoggingBehavior.Create(const ALoggerFactory: ILoggerFactory);
begin
  inherited Create;
  FLogger := ALoggerFactory.CreateLogger('Dext.EventBus');
end;

procedure TEventLoggingBehavior.Intercept(AEventType: PTypeInfo;
  const AEvent: TValue; const ANext: TEventNextDelegate);
var
  EventName: string;
  Stopwatch: TStopwatch;
begin
  EventName := string(AEventType.Name);
  FLogger.Debug('Handling %s', [EventName]);
  Stopwatch := TStopwatch.StartNew;
  try
    ANext();
    Stopwatch.Stop;
    FLogger.Debug('Handled %s in %dms', [EventName, Stopwatch.ElapsedMilliseconds]);
  except
    on E: Exception do
    begin
      Stopwatch.Stop;
      FLogger.Error(E, '%s handler raised after %dms: %s',
        [EventName, Stopwatch.ElapsedMilliseconds, E.Message]);
      raise;
    end;
  end;
end;

{ TEventTimingBehavior }

procedure TEventTimingBehavior.Intercept(AEventType: PTypeInfo;
  const AEvent: TValue; const ANext: TEventNextDelegate);
var
  Stopwatch: TStopwatch;
begin
  Stopwatch := TStopwatch.StartNew;
  try
    ANext();
  finally
    Stopwatch.Stop;
    {$IFDEF MSWINDOWS}
    OutputDebugString(PChar(Format('[EventBus] %s dispatched in %dms',
      [string(AEventType.Name), Stopwatch.ElapsedMilliseconds])));
    {$ENDIF}
  end;
end;

{ TEventExceptionBehavior }

procedure TEventExceptionBehavior.Intercept(AEventType: PTypeInfo;
  const AEvent: TValue; const ANext: TEventNextDelegate);
var
  Wrapped: EEventDispatchException;
begin
  try
    ANext();
  except
    on E: EEventDispatchException do
      raise; // Already wrapped - preserve original context
    on E: Exception do
    begin
      Wrapped := EEventDispatchException.CreateFmt(
        'Event handler failed for "%s": %s', [string(AEventType.Name), E.Message]);
      Wrapped.EventTypeName := string(AEventType.Name);
      raise Wrapped;
    end;
  end;
end;

end.
