program Web.FrameworkTests;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  WebFrameworkTests.Tests.Base in 'WebFrameworkTests.Tests.Base.pas',
  WebFrameworkTests.Tests.Routing in 'WebFrameworkTests.Tests.Routing.pas',
  WebFrameworkTests.Tests.Async in 'WebFrameworkTests.Tests.Async.pas',
  WebFrameworkTests.Tests.DataApi in 'WebFrameworkTests.Tests.DataApi.pas',
  WebFrameworkTests.Tests.QueryMethod in 'WebFrameworkTests.Tests.QueryMethod.pas';

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
  SetConsoleCharSet;
  try
    WriteLn('🌐 Dext Web Framework Stability Tests');
    WriteLn('=====================================');

    // Execute Tests
    RunTest(TRoutingTest);
    RunTest(TAsyncTest);
    RunTest(TDataApiTest);
    RunTest(TQueryMethodTest);

    WriteLn('');
    WriteLn('✨ All tests completed.');
  except
    on E: Exception do
      Writeln('❌ Critical Error: ', E.ClassName, ': ', E.Message);
  end;

  // Only pause if not running in automated mode
  ConsolePause;
end.
