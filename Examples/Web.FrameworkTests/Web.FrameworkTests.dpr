program Web.FrameworkTests;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  WebFrameworkTests.Tests.Base in 'WebFrameworkTests.Tests.Base.pas',
  WebFrameworkTests.Tests.Routing in 'WebFrameworkTests.Tests.Routing.pas',
  WebFrameworkTests.Tests.Async in 'WebFrameworkTests.Tests.Async.pas';

procedure RunTest(const TestClass: TBaseTestClass);
var
  Test: TBaseTest;
begin
  WriteLn('');
  WriteLn('----------------------------------------');
  WriteLn('Running Test Suite: ', TestClass.ClassName);
  WriteLn('----------------------------------------');
  try
    Test := TestClass.Create;
    try
      Test.Run;
    finally
      Test.Free;
    end;
  except
    on E: Exception do
      WriteLn('❌ Critical Error running test: ' + E.Message);
  end;
end;

begin
  
  try
    WriteLn('🌐 Dext Web Framework Stability Tests');
    WriteLn('=====================================');
    
    // Execute Tests
    RunTest(TRoutingTest);
    RunTest(TAsyncTest);
    
    WriteLn('');
    WriteLn('✨ All tests completed.');
  except
    on E: Exception do
      Writeln('❌ Critical Error: ', E.ClassName, ': ', E.Message);
  end;

  // Only pause if not running in automated mode
  if not FindCmdLineSwitch('no-wait', True) then
  begin
    WriteLn('Press Enter to exit...');
    ReadLn;
  end;
end.
