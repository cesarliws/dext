program Web.SalesSystem.Minimal;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  Dext.Utils,
  Dext.Web,
  Dext.DI.Interfaces,
  System.SysUtils,
  Sales.Startup in 'Sales.Startup.pas',
  Sales.Auth in 'Sales.Auth.pas',
  Sales.Endpoints in 'Sales.Endpoints.pas',
  Sales.Domain.Entities in '..\Domain\Sales.Domain.Entities.pas',
  Sales.Domain.Models in '..\Domain\Sales.Domain.Models.pas',
  Sales.Domain.Enums in '..\Domain\Sales.Domain.Enums.pas',
  Sales.Data.Context in '..\Data\Sales.Data.Context.pas',
  Sales.Data.Seeder in '..\Data\Sales.Data.Seeder.pas';

var
  App: IWebApplication;
  Provider: IServiceProvider;
begin
  SetConsoleCharSet;
  try
    WriteLn('🚀 Sales System Minimal API (CQRS Style)');
    WriteLn('========================================');

    App := WebApplication;

    // Register Startup Configuration
    App.UseStartup(TStartup.Create);

    // Build Services and Seed Database
    // This phase constructs the container and allows us to resolve the DbContext for migration/seeding
    // BEFORE the server starts accepting requests.
    try
      Provider := App.BuildServices;
      TDbSeeder.Seed(Provider);
    except
      on E: Exception do
        WriteLn('❌ Database Initialization failed: ' + E.Message);
    end;

    // Run Server
    App.Run; // Defaults to port 8080 or config

  except
    on E: Exception do
      WriteLn('Fatal Error: ', E.Message);
  end;
end.
