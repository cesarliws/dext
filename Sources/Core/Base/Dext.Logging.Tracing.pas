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

unit Dext.Logging.Tracing;

interface

uses
  System.SysUtils,
  System.Diagnostics,
  System.JSON,
  Dext.Logging.Telemetry,
  Dext.Telemetry.Context,
  Dext.Types.UUID;

const
  tsSuccess = 'Success';
  tsError = 'Error';

type
  /// <summary>
  ///   Represents a single operation within a trace.
  /// </summary>
  ISpan = interface
    ['{4E17EC63-764F-48C9-B4C1-FC8343518C73}']
    procedure Finish;
    procedure SetStatus(const AStatus: string; const AErrorMessage: string = '');
    procedure SetAttribute(const AKey: string; const AValue: string); overload;
    procedure SetAttribute(const AKey: string; const AValue: Int64); overload;
    procedure SetAttribute(const AKey: string; const AValue: Boolean); overload;
    
    function GetTraceId: string;
    function GetSpanId: string;
  end;

  /// <summary>
  ///   Managed record that automatically finishes the span when it goes out of scope.
  /// </summary>
  TSpan = record
  private
    FSpan: ISpan;
  public
    constructor Create(const ASpan: ISpan);
    class operator Implicit(const ASpan: ISpan): TSpan;
    
    procedure Finish;
    procedure SetStatus(const AStatus: string; const AErrorMessage: string = '');
    procedure SetAttribute(const AKey: string; const AValue: string); overload;
    procedure SetAttribute(const AKey: string; const AValue: Int64); overload;
    procedure SetAttribute(const AKey: string; const AValue: Boolean); overload;

    function GetTraceId: string;
    function GetSpanId: string;

    property TraceId: string read GetTraceId;
    property SpanId: string read GetSpanId;
  end;

  /// <summary>
  ///   Static helper for creating spans.
  /// </summary>
  TTracer = class
  public
    /// <summary>Starts a new span. If a trace is already active, the new span will be a child of the current span.</summary>
    class function BeginSpan(const AName: string; const ACategory: string = 'SYS'): TSpan; static;
  end;

implementation

type
  TDefaultSpan = class(TInterfacedObject, ISpan)
  private
    FName: string;
    FCategory: string;
    FTraceId: string;
    FSpanId: string;
    FParentId: string;
    FStart: TStopwatch;
    FData: TJSONObject;
    FStatus: string;
    FError: string;
    FFinished: Boolean;
    FNode: PScopeNode;
  public
    constructor Create(const AName, ACategory, ATraceId, ASpanId, AParentId: string);
    destructor Destroy; override;
    
    procedure Finish;
    procedure SetStatus(const AStatus: string; const AErrorMessage: string = '');
    procedure SetAttribute(const AKey: string; const AValue: string); overload;
    procedure SetAttribute(const AKey: string; const AValue: Int64); overload;
    procedure SetAttribute(const AKey: string; const AValue: Boolean); overload;
    
    function GetTraceId: string;
    function GetSpanId: string;
  end;

{ TDefaultSpan }

constructor TDefaultSpan.Create(const AName, ACategory, ATraceId, ASpanId, AParentId: string);
begin
  inherited Create;
  FName := AName;
  FCategory := ACategory;
  FTraceId := ATraceId;
  FSpanId := ASpanId;
  FParentId := AParentId;
  FStatus := 'Success';
  FData := TJSONObject.Create;
  FStart := TStopwatch.StartNew;
  FFinished := False;
  
  // Push to context stack
  FNode := TraceContext.Push(FName, TUUID.FromString(FTraceId), TUUID.FromString(FSpanId));
end;

destructor TDefaultSpan.Destroy;
begin
  Finish;
  FData.Free;
  inherited;
end;

procedure TDefaultSpan.Finish;
begin
  if FFinished then Exit;
  FFinished := True;
  
  FStart.Stop;
  
  // Pop from context stack
  // Since we don't have the node here directly in Finish, 
  // but TDefaultSpan is an object, we should have stored the Node.
  // Actually, TraceContext.Pop takes a PScopeNode.
  // I will refactor TDefaultSpan to store the FNode.
  TraceContext.Pop(FNode);
  
  // Write to telemetry
  TDiagnosticSource.Instance.Write(
    FName, 
    FData.Clone as TJSONObject, 
    FCategory, 
    FStart.ElapsedMilliseconds,
    FStatus,
    FError,
    FTraceId,
    FSpanId,
    FParentId
  );
end;

function TDefaultSpan.GetSpanId: string;
begin
  Result := FSpanId;
end;

function TDefaultSpan.GetTraceId: string;
begin
  Result := FTraceId;
end;

procedure TDefaultSpan.SetAttribute(const AKey, AValue: string);
begin
  FData.AddPair(AKey, AValue);
end;

procedure TDefaultSpan.SetAttribute(const AKey: string; const AValue: Int64);
begin
  FData.AddPair(AKey, TJSONNumber.Create(AValue));
end;

procedure TDefaultSpan.SetAttribute(const AKey: string; const AValue: Boolean);
begin
  FData.AddPair(AKey, TJSONBool.Create(AValue));
end;

procedure TDefaultSpan.SetStatus(const AStatus, AErrorMessage: string);
begin
  FStatus := AStatus;
  FError := AErrorMessage;
end;

{ TSpan }

constructor TSpan.Create(const ASpan: ISpan);
begin
  FSpan := ASpan;
end;

procedure TSpan.Finish;
begin
  if Assigned(FSpan) then
    FSpan.Finish;
end;

function TSpan.GetSpanId: string;
begin
  if Assigned(FSpan) then
    Result := FSpan.GetSpanId
  else
    Result := '';
end;

function TSpan.GetTraceId: string;
begin
  if Assigned(FSpan) then
    Result := FSpan.GetTraceId
  else
    Result := '';
end;

class operator TSpan.Implicit(const ASpan: ISpan): TSpan;
begin
  Result.FSpan := ASpan;
end;

procedure TSpan.SetAttribute(const AKey, AValue: string);
begin
  if Assigned(FSpan) then FSpan.SetAttribute(AKey, AValue);
end;

procedure TSpan.SetAttribute(const AKey: string; const AValue: Int64);
begin
  if Assigned(FSpan) then FSpan.SetAttribute(AKey, AValue);
end;

procedure TSpan.SetAttribute(const AKey: string; const AValue: Boolean);
begin
  if Assigned(FSpan) then FSpan.SetAttribute(AKey, AValue);
end;

procedure TSpan.SetStatus(const AStatus, AErrorMessage: string);
begin
  if Assigned(FSpan) then FSpan.SetStatus(AStatus, AErrorMessage);
end;

{ TTracer }

class function TTracer.BeginSpan(const AName, ACategory: string): TSpan;
var
  NewTraceId, NewSpanId, ParentId: string;
begin
  if not TDiagnosticSource.Instance.IsActive then
    Exit(TSpan.Create(nil));

  if TraceContext.CurrentTraceId.IsEmpty then
    NewTraceId := TUUID.NewV7.ToString
  else
    NewTraceId := TraceContext.CurrentTraceId.ToString;
    
  NewSpanId := TUUID.NewV4.ToString;
  
  if TraceContext.Current <> nil then
    ParentId := TraceContext.Current.SpanId.ToString
  else
    ParentId := '';
  
  Result := TDefaultSpan.Create(AName, ACategory, NewTraceId, NewSpanId, ParentId);
end;

end.
