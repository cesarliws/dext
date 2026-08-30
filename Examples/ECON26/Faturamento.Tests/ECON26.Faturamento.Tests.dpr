program ECON26.Faturamento.Tests;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  Dext.Testing,
  Product in '..\Faturamento.Api\Product.pas',
  Order in '..\Faturamento.Api\Order.pas',
  AppDbContext in '..\Faturamento.Api\AppDbContext.pas',
  OrderService in '..\Faturamento.Api\OrderService.pas',
  PlaceOrderTests in 'PlaceOrderTests.pas';

begin
  SetConsoleCharSet();
  try
    SafeWriteLn;
    SafeWriteLn('ECON26 · Faturamento Tests');
    SafeWriteLn;

    RunTests(TTest
      .Configure
      .Verbose
      .RegisterFixtures([
        TPlaceOrderTests
      ]));
  except
    on E: Exception do
    begin
      SafeWriteLn('Test Error: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
