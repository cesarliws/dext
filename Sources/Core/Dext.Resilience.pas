{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-06-05                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Resilience;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  System.Rtti;

type
  /// <summary>Base exception for resilience pipeline errors.</summary>
  EDextResilienceException = class(Exception);

  /// <summary>Exception thrown when a circuit breaker is open.</summary>
  ECircuitBrokenException = class(EDextResilienceException);

  /// <summary>Exception thrown when an operation times out.</summary>
  ETimeoutException = class(EDextResilienceException);

  /// <summary>Represents a single policy stage inside a resilience pipeline.</summary>
  IResiliencePolicy = interface
    ['{32F6E1B2-7482-491C-9E5C-D7E14022B801}']
    function Execute(const Action: TFunc<TValue>): TValue; overload;
    procedure Execute(const Action: TProc); overload;
  end;

  /// <summary>
  ///   Thread-safe, decoupled resilience pipeline for fault-handling.
  /// </summary>
  IResiliencePipeline = interface
    ['{532E9156-0ACC-4526-8ECA-72D32ADFD59D}']
    function AddRetry(AMaxRetries: Integer; ABackoffMs: Integer = 100): IResiliencePipeline;
    function AddCircuitBreaker(AFailureThreshold: Integer; ABreakDurationMs: Integer): IResiliencePipeline;
    function AddFallback(const AFallbackFunc: TFunc<TValue>): IResiliencePipeline; overload;
    function AddFallback(const AFallbackProc: TProc): IResiliencePipeline; overload;
    function AddTimeout(ATimeoutMs: Integer): IResiliencePipeline;

    function Execute(const Action: TFunc<TValue>): TValue; overload;
    procedure Execute(const Action: TProc); overload;
  end;

  /// <summary>Circuit breaker state representation.</summary>
  TCircuitBreakerState = (cbsClosed, cbsOpen, cbsHalfOpen);

  /// <summary>
  ///   Implementation of a Retry policy with constant delay or exponential backoff.
  /// </summary>
  TRetryPolicy = class(TInterfacedObject, IResiliencePolicy)
  private
    FMaxRetries: Integer;
    FDelayMs: Integer;
  public
    constructor Create(AMaxRetries: Integer; ADelayMs: Integer = 100);
    function Execute(const Action: TFunc<TValue>): TValue; overload;
    procedure Execute(const Action: TProc); overload;
  end;

  /// <summary>
  ///   Implementation of a Circuit Breaker policy.
  /// </summary>
  TCircuitBreakerPolicy = class(TInterfacedObject, IResiliencePolicy)
  private
    FFailureThreshold: Integer;
    FBreakDurationMs: Integer;
    FState: TCircuitBreakerState;
    FFailures: Integer;
    FLastStateChange: UInt64;
    FLock: TCriticalSection;
    procedure CheckState;
    procedure RecordSuccess;
    procedure RecordFailure;
  public
    constructor Create(AFailureThreshold: Integer; ABreakDurationMs: Integer);
    destructor Destroy; override;
    function Execute(const Action: TFunc<TValue>): TValue; overload;
    procedure Execute(const Action: TProc); overload;
  end;

  /// <summary>
  ///   Implementation of a Fallback policy.
  /// </summary>
  TFallbackPolicy = class(TInterfacedObject, IResiliencePolicy)
  private
    FFallbackFunc: TFunc<TValue>;
  public
    constructor Create(const AFallbackFunc: TFunc<TValue>);
    function Execute(const Action: TFunc<TValue>): TValue; overload;
    procedure Execute(const Action: TProc); overload;
  end;

  /// <summary>
  ///   Implementation of a Fallback policy for procedures.
  /// </summary>
  TFallbackProcPolicy = class(TInterfacedObject, IResiliencePolicy)
  private
    FFallbackProc: TProc;
  public
    constructor Create(const AFallbackProc: TProc);
    function Execute(const Action: TFunc<TValue>): TValue; overload;
    procedure Execute(const Action: TProc); overload;
  end;

  /// <summary>
  ///   Implementation of a Timeout policy.
  /// </summary>
  TTimeoutPolicy = class(TInterfacedObject, IResiliencePolicy)
  private
    FTimeoutMs: Integer;
  public
    constructor Create(ATimeoutMs: Integer);
    function Execute(const Action: TFunc<TValue>): TValue; overload;
    procedure Execute(const Action: TProc); overload;
  end;

  /// <summary>
  ///   Concrete builder and manager of IResiliencePipeline.
  /// </summary>
  TResiliencePipelineImpl = class(TInterfacedObject, IResiliencePipeline)
  private
    FPolicies: TList<IResiliencePolicy>;
    FLock: TCriticalSection;
    function ChainExecute(Index: Integer; const Action: TFunc<TValue>): TValue;
    procedure ChainExecuteProc(Index: Integer; const Action: TProc);
  public
    constructor Create;
    destructor Destroy; override;

    function AddRetry(AMaxRetries: Integer; ABackoffMs: Integer = 100): IResiliencePipeline;
    function AddCircuitBreaker(AFailureThreshold: Integer; ABreakDurationMs: Integer): IResiliencePipeline;
    function AddFallback(const AFallbackFunc: TFunc<TValue>): IResiliencePipeline; overload;
    function AddFallback(const AFallbackProc: TProc): IResiliencePipeline; overload;
    function AddTimeout(ATimeoutMs: Integer): IResiliencePipeline;

    function Execute(const Action: TFunc<TValue>): TValue; overload;
    procedure Execute(const Action: TProc); overload;
  end;

  /// <summary>
  ///   Fluent wrapper record supporting generic execution and nice configuration API.
  /// </summary>
  TResiliencePipeline = record
  private
    FInstance: IResiliencePipeline;
  public
    class function Create: TResiliencePipeline; static;

    function AddRetry(AMaxRetries: Integer; ABackoffMs: Integer = 100): TResiliencePipeline;
    function AddCircuitBreaker(AFailureThreshold: Integer; ABreakDurationMs: Integer): TResiliencePipeline;
    function AddFallback<T>(const AFallbackFunc: TFunc<T>): TResiliencePipeline; overload;
    function AddFallback(const AFallbackFunc: TFunc<TValue>): TResiliencePipeline; overload;
    function AddFallback(const AFallbackProc: TProc): TResiliencePipeline; overload;
    function AddTimeout(ATimeoutMs: Integer): TResiliencePipeline;

    function Execute<T>(const Action: TFunc<T>): T; overload;
    procedure Execute(const Action: TProc); overload;
    
    property Instance: IResiliencePipeline read FInstance;
  end;

function GetTickCount64: UInt64;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.Math,
  System.Threading,
  System.Diagnostics;

function GetTickCount64: UInt64;
begin
  {$IFDEF MSWINDOWS}
  Result := Winapi.Windows.GetTickCount64;
  {$ELSE}
    {$IF CompilerVersion >= 35.0}
    Result := TThread.GetTickCount64;
    {$ELSE}
    Result := TStopwatch.GetTimeStamp * 1000 div TStopwatch.Frequency;
    {$ENDIF}
  {$ENDIF}
end;

{ TRetryPolicy }

constructor TRetryPolicy.Create(AMaxRetries: Integer; ADelayMs: Integer);
begin
  inherited Create;
  FMaxRetries := AMaxRetries;
  FDelayMs := ADelayMs;
end;

function TRetryPolicy.Execute(const Action: TFunc<TValue>): TValue;
var
  Attempt: Integer;
begin
  Attempt := 0;
  while True do
  begin
    try
      Exit(Action());
    except
      on E: Exception do
      begin
        Inc(Attempt);
        if Attempt > FMaxRetries then
          raise;
        Sleep(Trunc(FDelayMs * Power(2, Attempt - 1)));
      end;
    end;
  end;
end;

procedure TRetryPolicy.Execute(const Action: TProc);
var
  Attempt: Integer;
begin
  Attempt := 0;
  while True do
  begin
    try
      Action();
      Exit;
    except
      on E: Exception do
      begin
        Inc(Attempt);
        if Attempt > FMaxRetries then
          raise;
        Sleep(Trunc(FDelayMs * Power(2, Attempt - 1)));
      end;
    end;
  end;
end;

{ TCircuitBreakerPolicy }

constructor TCircuitBreakerPolicy.Create(AFailureThreshold: Integer; ABreakDurationMs: Integer);
begin
  inherited Create;
  FFailureThreshold := AFailureThreshold;
  FBreakDurationMs := ABreakDurationMs;
  FState := cbsClosed;
  FFailures := 0;
  FLastStateChange := 0;
  FLock := TCriticalSection.Create;
end;

destructor TCircuitBreakerPolicy.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TCircuitBreakerPolicy.CheckState;
var
  Elapsed: Int64;
begin
  FLock.Enter;
  try
    if FState = cbsOpen then
    begin
      Elapsed := GetTickCount64 - FLastStateChange;
      if Elapsed >= FBreakDurationMs then
      begin
        FState := cbsHalfOpen;
        FFailures := 0;
      end
      else
      begin
        raise ECircuitBrokenException.CreateFmt(
          'Circuit is open. Re-trying blocked for another %d ms.',
          [FBreakDurationMs - Elapsed]
        );
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreakerPolicy.RecordSuccess;
begin
  FLock.Enter;
  try
    if FState = cbsHalfOpen then
    begin
      FState := cbsClosed;
      FFailures := 0;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreakerPolicy.RecordFailure;
begin
  FLock.Enter;
  try
    Inc(FFailures);
    if (FState = cbsHalfOpen) or (FFailures >= FFailureThreshold) then
    begin
      FState := cbsOpen;
      FLastStateChange := GetTickCount64;
    end;
  finally
    FLock.Leave;
  end;
end;

function TCircuitBreakerPolicy.Execute(const Action: TFunc<TValue>): TValue;
begin
  CheckState;
  try
    Result := Action();
    RecordSuccess;
  except
    on E: Exception do
    begin
      RecordFailure;
      raise;
    end;
  end;
end;

procedure TCircuitBreakerPolicy.Execute(const Action: TProc);
begin
  CheckState;
  try
    Action();
    RecordSuccess;
  except
    on E: Exception do
    begin
      RecordFailure;
      raise;
    end;
  end;
end;

{ TFallbackPolicy }

constructor TFallbackPolicy.Create(const AFallbackFunc: TFunc<TValue>);
begin
  inherited Create;
  FFallbackFunc := AFallbackFunc;
end;

function TFallbackPolicy.Execute(const Action: TFunc<TValue>): TValue;
begin
  try
    Result := Action();
  except
    on E: Exception do
    begin
      if Assigned(FFallbackFunc) then
        Result := FFallbackFunc()
      else
        raise;
    end;
  end;
end;

procedure TFallbackPolicy.Execute(const Action: TProc);
begin
  Action();
end;

{ TFallbackProcPolicy }

constructor TFallbackProcPolicy.Create(const AFallbackProc: TProc);
begin
  inherited Create;
  FFallbackProc := AFallbackProc;
end;

function TFallbackProcPolicy.Execute(const Action: TFunc<TValue>): TValue;
begin
  Result := Action();
end;

procedure TFallbackProcPolicy.Execute(const Action: TProc);
begin
  try
    Action();
  except
    on E: Exception do
    begin
      if Assigned(FFallbackProc) then
        FFallbackProc()
      else
        raise;
    end;
  end;
end;

{ TTimeoutPolicy }

constructor TTimeoutPolicy.Create(ATimeoutMs: Integer);
begin
  inherited Create;
  FTimeoutMs := ATimeoutMs;
end;

function TTimeoutPolicy.Execute(const Action: TFunc<TValue>): TValue;
var
  LFuture: IFuture<TValue>;
begin
  LFuture := TTask.Future<TValue>(
    function: TValue
    begin
      Result := Action();
    end
  );

  try
    if LFuture.Wait(FTimeoutMs) then
      Result := LFuture.Value
    else
      raise ETimeoutException.Create('Operation timed out.');
  except
    on E: EAggregateException do
    begin
      if Assigned(E.InnerException) then
        raise E.InnerException
      else
        raise;
    end;
  end;
end;

procedure TTimeoutPolicy.Execute(const Action: TProc);
var
  LTask: ITask;
  LException: Exception;
begin
  LException := nil;
  LTask := TTask.Run(
    procedure
    begin
      try
        Action();
      except
        on E: Exception do
        begin
          LException := AcquireExceptionObject as Exception;
          raise;
        end;
      end;
    end
  );
  
  try
    if LTask.Wait(FTimeoutMs) then
    begin
      if Assigned(LException) then
        raise LException;
    end
    else
    begin
      raise ETimeoutException.Create('Operation timed out.');
    end;
  except
    on E: EAggregateException do
    begin
      if Assigned(E.InnerException) then
        raise E.InnerException
      else
        raise;
    end;
  end;
end;

{ TResiliencePipelineImpl }

constructor TResiliencePipelineImpl.Create;
begin
  inherited Create;
  FPolicies := TList<IResiliencePolicy>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TResiliencePipelineImpl.Destroy;
begin
  FPolicies.Free;
  FLock.Free;
  inherited;
end;

function TResiliencePipelineImpl.AddRetry(AMaxRetries: Integer; ABackoffMs: Integer): IResiliencePipeline;
begin
  FLock.Enter;
  try
    FPolicies.Add(TRetryPolicy.Create(AMaxRetries, ABackoffMs));
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TResiliencePipelineImpl.AddCircuitBreaker(AFailureThreshold: Integer; ABreakDurationMs: Integer): IResiliencePipeline;
begin
  FLock.Enter;
  try
    FPolicies.Add(TCircuitBreakerPolicy.Create(AFailureThreshold, ABreakDurationMs));
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TResiliencePipelineImpl.AddFallback(const AFallbackFunc: TFunc<TValue>): IResiliencePipeline;
begin
  FLock.Enter;
  try
    FPolicies.Add(TFallbackPolicy.Create(AFallbackFunc));
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TResiliencePipelineImpl.AddFallback(const AFallbackProc: TProc): IResiliencePipeline;
begin
  FLock.Enter;
  try
    FPolicies.Add(TFallbackProcPolicy.Create(AFallbackProc));
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TResiliencePipelineImpl.AddTimeout(ATimeoutMs: Integer): IResiliencePipeline;
begin
  FLock.Enter;
  try
    FPolicies.Add(TTimeoutPolicy.Create(ATimeoutMs));
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TResiliencePipelineImpl.ChainExecute(Index: Integer; const Action: TFunc<TValue>): TValue;
begin
  if Index >= FPolicies.Count then
    Result := Action()
  else
    Result := FPolicies[Index].Execute(
      TFunc<TValue>(
        function: TValue
        begin
          Result := ChainExecute(Index + 1, Action);
        end
      )
    );
end;

procedure TResiliencePipelineImpl.ChainExecuteProc(Index: Integer; const Action: TProc);
begin
  if Index >= FPolicies.Count then
    Action()
  else
    FPolicies[Index].Execute(
      procedure
      begin
        ChainExecuteProc(Index + 1, Action);
      end
    );
end;

function TResiliencePipelineImpl.Execute(const Action: TFunc<TValue>): TValue;
begin
  FLock.Enter;
  try
    Result := ChainExecute(0, Action);
  finally
    FLock.Leave;
  end;
end;

procedure TResiliencePipelineImpl.Execute(const Action: TProc);
begin
  FLock.Enter;
  try
    ChainExecuteProc(0, Action);
  finally
    FLock.Leave;
  end;
end;

{ TResiliencePipeline }

class function TResiliencePipeline.Create: TResiliencePipeline;
begin
  Result.FInstance := TResiliencePipelineImpl.Create;
end;

function TResiliencePipeline.AddRetry(AMaxRetries: Integer; ABackoffMs: Integer): TResiliencePipeline;
begin
  FInstance.AddRetry(AMaxRetries, ABackoffMs);
  Result := Self;
end;

function TResiliencePipeline.AddCircuitBreaker(AFailureThreshold: Integer; ABreakDurationMs: Integer): TResiliencePipeline;
begin
  FInstance.AddCircuitBreaker(AFailureThreshold, ABreakDurationMs);
  Result := Self;
end;

function TResiliencePipeline.AddFallback<T>(const AFallbackFunc: TFunc<T>): TResiliencePipeline;
begin
  FInstance.AddFallback(
    TFunc<TValue>(
      function: TValue
      begin
        Result := TValue.From<T>(AFallbackFunc());
      end
    )
  );
  Result := Self;
end;

function TResiliencePipeline.AddFallback(const AFallbackFunc: TFunc<TValue>): TResiliencePipeline;
begin
  FInstance.AddFallback(AFallbackFunc);
  Result := Self;
end;

function TResiliencePipeline.AddFallback(const AFallbackProc: TProc): TResiliencePipeline;
begin
  FInstance.AddFallback(AFallbackProc);
  Result := Self;
end;

function TResiliencePipeline.AddTimeout(ATimeoutMs: Integer): TResiliencePipeline;
begin
  FInstance.AddTimeout(ATimeoutMs);
  Result := Self;
end;

function TResiliencePipeline.Execute<T>(const Action: TFunc<T>): T;
var
  LVal: TValue;
begin
  LVal := FInstance.Execute(
    TFunc<TValue>(
      function: TValue
      begin
        Result := TValue.From<T>(Action());
      end
    )
  );
  Result := LVal.AsType<T>;
end;

procedure TResiliencePipeline.Execute(const Action: TProc);
begin
  FInstance.Execute(Action);
end;

end.
