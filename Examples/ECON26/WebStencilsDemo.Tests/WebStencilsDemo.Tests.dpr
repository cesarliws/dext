program WebStencilsDemo.Tests;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  Dext.Testing,
  Customer in '..\WebStencilsDemo\Models\Customer.pas',
  AppDbContext in '..\WebStencilsDemo\Models\AppDbContext.pas',
  CustomerSearch in '..\WebStencilsDemo\Models\CustomerSearch.pas',
  CustomerSearchTests in 'CustomerSearchTests.pas';

begin
  SetConsoleCharSet();
  try
    SafeWriteLn;
    SafeWriteLn('ECON26 · WebStencilsDemo Tests');
    SafeWriteLn;

    RunTests(TTest
      .Configure
      .Verbose
      .RegisterFixtures([
        TCustomerSearchTests
      ]));
  except
    on E: Exception do
    begin
      SafeWriteLn('Test Error: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
