program WebStencilsDemo;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext,
  Dext.Web,
  Dext.Web.Interfaces,
  Dext.Utils,
  Startup in 'Startup.pas',
  Customer in 'Models\Customer.pas',
  AppDbContext in 'Models\AppDbContext.pas',
  CustomerSearch in 'Models\CustomerSearch.pas';

var
  App: IWebApplication;
  Provider: IServiceProvider;
begin
  SetConsoleCharset;
  try
    App := WebApplication;
    App.UseStartup(TStartup.Create);

    Writeln('ECON26 · WebStencils + Dext');
    Writeln('Initializing services...');
    Provider := App.BuildServices;

    Writeln('Setting up database...');
    TStartup.SeedData(Provider);

    Writeln('http://localhost:5000');
    App.Run(5000);
  except
    on E: Exception do
    begin
      Writeln('Error: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
  ConsolePause;
end.
