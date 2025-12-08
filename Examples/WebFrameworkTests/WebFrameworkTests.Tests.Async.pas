unit WebFrameworkTests.Tests.Async;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  WebFrameworkTests.Tests.Base,
  Dext.Threading.Async;

type
  TAsyncTest = class(TBaseTest)
  public
    procedure Run; override;
    procedure TestNoSync;
  end;

implementation

{ TAsyncTest }

procedure TAsyncTest.Run;
begin
  Log('Running Async Tests...');
  TestNoSync;
end;

procedure TAsyncTest.TestNoSync;
var
  MainThreadID: TThreadID;
  CompleteThreadID: TThreadID;
  ExceptionThreadID: TThreadID;
  Executed: Boolean;
  Handle: TEvent;
begin
  MainThreadID := TThread.CurrentThread.ThreadID;
  Executed := False;
  Handle := TEvent.Create;
  try
    Log('  Testing OnCompleteAsync (No Sync)...');
    
    // Test OnCompleteAsync
    TAsyncTask.Run<Integer>(function: Integer
      begin
        Result := 42;
      end)
      .OnCompleteAsync(procedure(Val: Integer)
      begin
        CompleteThreadID := TThread.CurrentThread.ThreadID;
        Executed := True;
        Handle.SetEvent;
      end)
      .Start;
      
    // Wait for completion
    Handle.WaitFor(5000);
    
    AssertTrue(Executed, 'Callback executed', 'Callback did not execute');
    AssertTrue(CompleteThreadID <> MainThreadID, 
      Format('Callback ran on background thread (Main: %d, Bg: %d)', [MainThreadID, CompleteThreadID]), 
      Format('Callback ran on MAIN thread (Main: %d, Bg: %d)', [MainThreadID, CompleteThreadID]));
      
      
    // Test OnExceptionAsync
    Log('  Testing OnExceptionAsync (No Sync)...');
    Handle.ResetEvent;
    Executed := False;

    TAsyncTask.Run<Integer>(function: Integer
      begin
        raise Exception.Create('Test Error');
      end)
      .OnExceptionAsync(procedure(Ex: Exception)
      begin
        ExceptionThreadID := TThread.CurrentThread.ThreadID;
        Executed := True;
        Handle.SetEvent;
      end)
      .Start;
      
    Handle.WaitFor(5000);
    
    AssertTrue(Executed, 'Exception Callback executed', 'Exception Callback did not execute');
    AssertTrue(ExceptionThreadID <> MainThreadID, 
      Format('Exception Callback ran on background thread (Main: %d, Bg: %d)', [MainThreadID, ExceptionThreadID]), 
      Format('Exception Callback ran on MAIN thread (Main: %d, Bg: %d)', [MainThreadID, ExceptionThreadID]));

  finally
    Handle.Free;
  end;
end;

end.
