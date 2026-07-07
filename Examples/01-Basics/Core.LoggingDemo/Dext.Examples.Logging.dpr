program Dext.Examples.Logging;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Threading,
  System.Diagnostics,
  System.Classes,
  Dext.Utils,
  Dext.Logging,
  Dext.Logging.Global,
  Dext.Logging.Async,
  Dext.Logging.Sinks;

procedure RunExample;
var
  SW: TStopwatch;
  Tasks: TArray<ITask>;
  i: Integer;
  Scope, Nested: IScope;
begin
  Writeln('Initializing Dext Logger...');
  
  // Custom initialization (optional, Log.Logger auto-inits, but here we show customization)
  // Or just use Log.Initialize
  Log.Initialize;
  
  Log.Info('Hello from Main Thread!', []);
  
  // 1. Stress Test - Multi-threaded logging
  Writeln('Starting Stress Test (4 Threads, 100k messages)...');
  SW := TStopwatch.StartNew;
  
  SetLength(Tasks, 4);
  
  for i := 0 to 3 do
  begin
    Tasks[i] := TTask.Run(procedure
      var
        TID: TThreadID;
        k: Integer;
      begin
        TID := TThread.CurrentThread.ThreadID;
        Log.Info('Thread %d started', [TID]);
        
        for k := 1 to 25000 do
        begin
          // Mix of log levels
          if k mod 1000 = 0 then
            Log.Debug('Thread %d progress: %d/25000', [TID, k])
          else
            Log.Info('Processing item %d on thread %d', [k, TID]);
        end;
        
        Log.Info('Thread %d finished', [TID]);
      end);
  end;
  
  TTask.WaitForAll(Tasks);
  SW.Stop;
  
  Writeln(Format('Finished 100k logs in %d ms (Producer Time)', [SW.ElapsedMilliseconds]));
  Writeln('Note: Consumer is likely still draining the RingBuffer in background.');
  
  // 2. Scope usage
  Log.Info('Testing Scopes...', []);
  Scope := Log.Logger.BeginScope('Transaction {Id}', ['TX-001']);
  try
    Log.Info('Inside Transaction Scope', []);
    
    // Nested
    Nested := Log.Logger.BeginScope('Operation {Op}', ['UpdateUser']);
    try
      Log.Warn('Cannot find user cache, fetching from DB...', []);
    finally
      Nested.Dispose;
    end;
    
  finally
    Scope.Dispose;
  end;
  
  Log.Info('Back to Global Scope', []);
  Writeln('Press Enter to flush and exit...');
end;

begin
  try
    SetConsoleCharSet(65001);
    RunExample;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ConsolePause;
end.
