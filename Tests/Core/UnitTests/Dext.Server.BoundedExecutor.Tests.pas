{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}
unit Dext.Server.BoundedExecutor.Tests;

interface

uses
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Server.BoundedExecutor,
  System.SysUtils,
  System.Classes,
  System.SyncObjs;

type
  [TestFixture('Dext Bounded Executor')]
  TBoundedExecutorTests = class
  public
    [Test]
    procedure Test_Task_Execution;
    [Test]
    procedure Test_Queue_Capacity;
    [Test]
    procedure Test_Executor_Shutdown;
  end;

implementation

{ TBoundedExecutorTests }

procedure TBoundedExecutorTests.Test_Task_Execution;
var
  Executor: TDextBoundedExecutor;
  Counter: Integer;
  Done: TSimpleEvent;
begin
  Counter := 0;
  Done := TSimpleEvent.Create(nil, True, False, '');
  try
    Executor := TDextBoundedExecutor.Create(2, 10);
    try
      Executor.TryEnqueue(
        procedure
        begin
          TInterlocked.Increment(Counter);
          if Counter = 2 then
            Done.SetEvent;
        end);

      Executor.TryEnqueue(
        procedure
        begin
          TInterlocked.Increment(Counter);
          if Counter = 2 then
            Done.SetEvent;
        end);

      Should(Done.WaitFor(1000) = wrSignaled).BeTrue;
      Should(Counter).Be(2);
    finally
      Executor.Free;
    end;
  finally
    Done.Free;
  end;
end;

procedure TBoundedExecutorTests.Test_Queue_Capacity;
var
  Executor: TDextBoundedExecutor;
  Success: Boolean;
begin
  // 0 threads, capacity 2
  Executor := TDextBoundedExecutor.Create(0, 2);
  try
    // Enqueue 1st task
    Success := Executor.TryEnqueue(
      procedure
      begin
      end);
    Should(Success).BeTrue;

    // Enqueue 2nd task
    Success := Executor.TryEnqueue(
      procedure
      begin
      end);
    Should(Success).BeTrue;

    // Enqueue 3rd task: exceeds capacity! Should fail (return False)
    Success := Executor.TryEnqueue(
      procedure
      begin
      end);
    Should(Success).BeFalse;

    Should(Executor.QueueCount).Be(2);
  finally
    Executor.Free;
  end;
end;

procedure TBoundedExecutorTests.Test_Executor_Shutdown;
var
  Executor: TDextBoundedExecutor;
begin
  Executor := TDextBoundedExecutor.Create(2, 5);
  try
    Executor.Shutdown;
  finally
    Executor.Free;
  end;
end;

end.
