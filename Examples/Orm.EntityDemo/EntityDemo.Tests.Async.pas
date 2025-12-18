unit EntityDemo.Tests.Async;

interface

uses
  System.SysUtils, 
  System.Classes,
  System.Threading, 
  EntityDemo.Tests.Base,
  Dext.Threading.Async,
  Dext.Core.CancellationToken;

type
  TAsyncTest = class(TBaseTest)
  public
    procedure Run; override;
    procedure TestSimpleAsync;
    procedure TestChainedAsync;
    procedure TestExceptionHandling;
    procedure TestProcedureAsync;
    procedure TestCancellation;
  end;

implementation

{ TAsyncTest }

procedure TAsyncTest.Run;
begin
  Log('?? Running Fluent Async Tests...');
  
  TestSimpleAsync;
  TestChainedAsync;
  TestExceptionHandling;
  TestProcedureAsync;
  TestCancellation;
end;

procedure TAsyncTest.TestSimpleAsync;
var
  Done: Boolean;
begin
  Log('Test 1: Simple Async Function');
  Done := False;
  
  TAsyncTask.Run<string>(
    function: string
    begin
      Sleep(100);
      Result := 'Hello Async';
    end)
  .OnComplete(
    procedure(Result: string)
    begin
      Log('Result: ' + Result);
      if Result = 'Hello Async' then
        Done := True;
    end)
  .Start;

  // Wait for the async task to complete
  // In a real GUI app we wouldn't block here, but for console test we must wait
  var CheckCount := 0;
  while not Done and (CheckCount < 50) do // Wait max 5 sec
  begin
    CheckSynchronize(100); // Allow TThread.Queue to process
    Inc(CheckCount);
  end;

  AssertTrue(Done, 'Async task completed successfully', 'Async task timed out or failed');
end;

procedure TAsyncTest.TestChainedAsync;
var
  FinalResult: Integer;
begin
  Log('Test 2: Chained Async (Then)');
  FinalResult := 0;

  TAsyncTask
   .Run<Integer>(
    function: Integer
    begin
      Result := 10;
    end)
  .ThenBy<Integer>(
    function(Input: Integer): Integer
    begin
      Result := Input * 2; // 20
    end)
  .ThenBy<string>(
    function(Input: Integer): string
    begin
      Result := 'Value: ' + Input.ToString; // "Value: 20"
    end)
  .OnComplete(
    procedure(Result: string)
    begin
      Log('Pipeline Result: ' + Result);
      if Result = 'Value: 20' then
        FinalResult := 20;
    end)
  .Start;

  var CheckCount := 0;
  while (FinalResult = 0) and (CheckCount < 50) do
  begin
    CheckSynchronize(100);
    Inc(CheckCount);
  end;

  AssertTrue(FinalResult = 20, 'Pipeline executed correctly', 'Pipeline failed');
end;

procedure TAsyncTest.TestExceptionHandling;
var
  ErrorCaught: Boolean;
  ErrorMsg: string;
begin
  Log('Test 3: Exception Handling');
  ErrorCaught := False;
  ErrorMsg := '';

  TAsyncTask.Run<Integer>(
    function: Integer
    begin
      raise Exception.Create('Something went wrong!');
    end)
  .ThenBy<string>(
    function(Input: Integer): string
    begin
      // Should not be executed
      Result := 'Should not reach here';
    end)
  .OnException(
    procedure(E: Exception)
    begin
      ErrorCaught := True;
      ErrorMsg := E.Message;
    end
  )
  .Start;

  var CheckCount := 0;
  while not ErrorCaught and (CheckCount < 50) do
  begin
    CheckSynchronize(100);
    Inc(CheckCount);
  end;

  AssertTrue(ErrorCaught, 'Exception caught', 'Exception NOT caught');
  AssertTrue(ErrorMsg = 'Something went wrong!', 'Correct error message', 'Wrong error message: ' + ErrorMsg);
end;

procedure TAsyncTest.TestProcedureAsync;
var
  SideEffect: Boolean;
begin
  Log('Test 4: Procedure Async (Void)');
  SideEffect := False;

  TAsyncTask.Run(
    procedure
    begin
      Sleep(50);
    end)
  .ThenBy(
    procedure(Success: Boolean)
    begin
      SideEffect := True;
    end)
  .Start;

  var CheckCount := 0;
  while not SideEffect and (CheckCount < 50) do
  begin
    CheckSynchronize(100);
    Inc(CheckCount);
  end;

  AssertTrue(SideEffect, 'Procedure chain executed', 'Procedure chain failed');
end;

procedure TAsyncTest.TestCancellation;
var
  CTS: TCancellationTokenSource;
  Cancelled: Boolean;
  Completed: Boolean;
begin
  Log('Test 5: Cancellation Support');
  CTS := TCancellationTokenSource.Create;
  Cancelled := False;
  Completed := False;

  try
    // Signal cancellation immediately
    CTS.Cancel;

    TAsyncTask.Run<Integer>(
      function: Integer
      begin
        // This simulates work, but should be checked before start or during execution
        Sleep(100); 
        Result := 42;
      end)
    .WithCancellation(CTS.Token)
    .OnComplete(
      procedure(Val: Integer)
      begin
        Completed := True;
        Log('Task COMPLETED (Unexpected)');
      end)
    .OnException(
      procedure(E: Exception)
      begin
        Log('Task FAILED: ' + E.Message);
        // We expect Operation Cancelled
        if E.Message.Contains('Operation cancelled') then
          Cancelled := True;
      end)
    .Start;
    
    // Wait for result
    var CheckCount := 0;
    while (not Cancelled) and (not Completed) and (CheckCount < 50) do
    begin
      CheckSynchronize(100);
      Inc(CheckCount);
    end;
    
    AssertTrue(Cancelled, 'Task was correctly cancelled', 'Task was NOT cancelled');
    AssertTrue(not Completed, 'Task should NOT complete', 'Task completed despite cancellation');
    
  finally
    CTS.Free;
  end;
end;

end.
