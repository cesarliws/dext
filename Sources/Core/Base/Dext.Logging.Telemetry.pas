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
{  Created: 2026-04-14                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Logging.Telemetry;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  Dext.Collections,
  Dext.Logging,
  Dext.Telemetry.Context;

type
  /// <summary>
  ///   Represents a telemetry event payload.
  /// </summary>
  TTelemetryEvent = record
    Name: string;
    Timestamp: TDateTime;
    Data: TJSONObject;
    Category: string; // 'SQL', 'HTTP', 'AUTH', 'SYS'
    DurationMs: Int64;
    Status: string; // 'Success', 'Error'
    ErrorMessage: string;
    TraceId: string;
    SpanId: string;
    ParentId: string;
  end;

  /// <summary>
  ///   Interface for observing telemetry events.
  /// </summary>
  ITelemetryObserver = interface
    ['{30000000-0000-0000-0000-000000000001}']
    
    /// <summary>Called when a telemetry event is emitted.</summary>
    procedure OnEvent(const AEvent: TTelemetryEvent);
  end;

  /// <summary>
  ///   Bridge that routes telemetry events to the logging system.
  /// </summary>
  TLoggingTelemetryObserver = class(TInterfacedObject, ITelemetryObserver)
  private
    FLogger: ILogger;
  public
    /// <summary>Creates a new instance of the logging telemetry observer.</summary>
    constructor Create(const ALogger: ILogger);
    
    /// <summary>Handles the incoming telemetry event and logs it appropriately.</summary>
    procedure OnEvent(const AEvent: TTelemetryEvent);
  end;

  /// <summary>
  ///   Observer that aggregates telemetry events into system metrics.
  /// </summary>
  TMetricsTelemetryObserver = class(TInterfacedObject, ITelemetryObserver)
  public
    procedure OnEvent(const AEvent: TTelemetryEvent);
  end;



  /// <summary>
  ///   Centralized publisher for framework diagnostic events.
  ///   Inspired by .NET DiagnosticSource.
  /// </summary>
  TDiagnosticSource = class
  private
    class var FInstance: TDiagnosticSource;
  private
    FObservers: IList<ITelemetryObserver>;
    FEnabled: Boolean;
    constructor Create;
  public
    /// <summary>Destroys the diagnostic source instance.</summary>
    class destructor Destroy;
    
    /// <summary>Gets the singleton instance of the diagnostic source.</summary>
    class property Instance: TDiagnosticSource read FInstance;

    /// <summary>Subscribes an observer to receive telemetry events.</summary>
    procedure Subscribe(AObserver: ITelemetryObserver);
    
    /// <summary>Unsubscribes an observer from receiving telemetry events.</summary>
    procedure Unsubscribe(AObserver: ITelemetryObserver);
    
    /// <summary>Writes a new telemetry event to all subscribed observers.</summary>
    procedure Write(const AName: string; const AData: TJSONObject; const ACategory: string = 'SYS'; 
      const ADuration: Int64 = 0; const AStatus: string = 'Success'; const AError: string = '';
      const ATraceId: string = ''; const ASpanId: string = ''; const AParentId: string = '');
    
    /// <summary>Gets or sets whether the diagnostic source is enabled.</summary>
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

implementation

uses
  Dext.Telemetry.Metrics;

{ TMetricsTelemetryObserver }

procedure TMetricsTelemetryObserver.OnEvent(const AEvent: TTelemetryEvent);
var
  StatusCodeStr: string;
  LVal: TJSONValue;
begin
  if AEvent.Category = 'HTTP' then
  begin
    TMetrics.Increment('http.requests');
    TMetrics.Histogram('http.latency', AEvent.DurationMs);
    
    if AEvent.Data <> nil then
    begin
      LVal := AEvent.Data.GetValue('StatusCode');
      if LVal <> nil then
        StatusCodeStr := LVal.Value
      else
      begin
        LVal := AEvent.Data.GetValue('status');
        if LVal <> nil then
          StatusCodeStr := LVal.Value
        else
          StatusCodeStr := '';
      end;
      
      if StatusCodeStr.StartsWith('4') or StatusCodeStr.StartsWith('5') then
        TMetrics.Increment('http.errors');
    end;
  end
  else if AEvent.Category = 'SQL' then
  begin
    TMetrics.Increment('sql.queries');
    TMetrics.Histogram('sql.latency', AEvent.DurationMs);
    
    if AEvent.DurationMs > 100 then
      TMetrics.Increment('sql.slow_queries');
  end;
end;

{ TDiagnosticSource }

constructor TDiagnosticSource.Create;
begin
  FObservers := TCollections.CreateList<ITelemetryObserver>;
  FEnabled := True;
end;

class destructor TDiagnosticSource.Destroy;
begin
  FInstance.Free;
end;

procedure TDiagnosticSource.Subscribe(AObserver: ITelemetryObserver);
begin
  if not FObservers.Contains(AObserver) then
    FObservers.Add(AObserver);
end;

procedure TDiagnosticSource.Unsubscribe(AObserver: ITelemetryObserver);
begin
  FObservers.Remove(AObserver);
end;

procedure TDiagnosticSource.Write(const AName: string; const AData: TJSONObject;
  const ACategory: string; const ADuration: Int64; const AStatus, AError: string;
  const ATraceId, ASpanId, AParentId: string);
var
  Ev: TTelemetryEvent;
  Observer: ITelemetryObserver;
  Ctx: PScopeNode;
begin
  if not FEnabled or (FObservers.Count = 0) then
  begin
    if Assigned(AData) then AData.Free;
    Exit;
  end;

  Ctx := TraceContext.Current;

  Ev.Name := AName;
  Ev.Timestamp := Now;
  Ev.Data := AData;
  Ev.Category := ACategory;
  Ev.DurationMs := ADuration;
  Ev.Status := AStatus;
  Ev.ErrorMessage := AError;
  
  if ATraceId <> '' then Ev.TraceId := ATraceId else if Ctx <> nil then Ev.TraceId := Ctx.TraceId.ToString;
  if ASpanId <> '' then Ev.SpanId := ASpanId else if Ctx <> nil then Ev.SpanId := Ctx.SpanId.ToString;
  if AParentId <> '' then Ev.ParentId := AParentId else if (Ctx <> nil) and (Ctx.Parent <> nil) then Ev.ParentId := Ctx.Parent.SpanId.ToString;

  try
    for Observer in FObservers do
      Observer.OnEvent(Ev);
  finally
    if Assigned(Ev.Data) then Ev.Data.Free;
  end;
end;

{ TLoggingTelemetryObserver }

constructor TLoggingTelemetryObserver.Create(const ALogger: ILogger);
begin
  inherited Create;
  FLogger := ALogger;
end;

procedure TLoggingTelemetryObserver.OnEvent(const AEvent: TTelemetryEvent);
var
  SqlCmd: string;
  LVal, LMethodVal, LPathVal, LStatusVal, LPlanBuildVal, LHydrationLoopVal: TJSONValue;
  LMethod, LPath, LStatus: string;
begin
  if AEvent.Category = 'SQL' then
  begin
    LVal := AEvent.Data.GetValue('sql');
    if LVal <> nil then
      SqlCmd := LVal.Value
    else
      SqlCmd := AEvent.Name;
    
    LPlanBuildVal := AEvent.Data.GetValue('plan_build_ms');
    LHydrationLoopVal := AEvent.Data.GetValue('hydration_loop_ms');
    
    if (LPlanBuildVal <> nil) and (LHydrationLoopVal <> nil) then
    begin
      FLogger.Info( 
        Format('[SQL] Executed in %dms (%s) [Plan Build: %s ms, Hydration Loop: %s ms]: %s', [
          AEvent.DurationMs, 
          AEvent.Status,
          LPlanBuildVal.Value,
          LHydrationLoopVal.Value,
          SqlCmd
        ]));
    end
    else
    begin
      FLogger.Info( 
        Format('[SQL] Executed in %dms (%s affected): %s', [
          AEvent.DurationMs, 
          AEvent.Status,
          SqlCmd
        ]));
    end;
  end
  else if AEvent.Category = 'HTTP' then
  begin
    LMethodVal := AEvent.Data.GetValue('Method');
    LPathVal := AEvent.Data.GetValue('Path');
    LStatusVal := AEvent.Data.GetValue('StatusCode');
    
    LMethod := ''; if LMethodVal <> nil then LMethod := LMethodVal.Value;
    LPath := ''; if LPathVal <> nil then LPath := LPathVal.Value;
    LStatus := ''; if LStatusVal <> nil then LStatus := LStatusVal.Value;

    FLogger.Info(
      Format('[HTTP] %s %s - %s (%dms)', [
        LMethod,
        LPath,
        LStatus,
        AEvent.DurationMs
      ]));
  end
  else
  begin
    FLogger.Info(Format('[%s] %s', [AEvent.Category, AEvent.Name]));
  end;
end;

initialization
  TDiagnosticSource.FInstance := TDiagnosticSource.Create;

end.
