program Web.TicketSales;

{$APPTYPE CONSOLE}

{***************************************************************************}
{                                                                           }
{           Web.TicketSales - Entry Point                                   }
{                                                                           }
{           Ticket Sales Web API Example using Controllers                  }
{                                                                           }
{***************************************************************************}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  Dext,
  Dext.Web,
  TicketSales.Startup in 'TicketSales.Startup.pas',
  TicketSales.Controllers in 'TicketSales.Controllers.pas',
  TicketSales.Services in '..\Services\TicketSales.Services.pas',
  TicketSales.Data.Context in '..\Data\TicketSales.Data.Context.pas',
  TicketSales.Data.Seeder in '..\Data\TicketSales.Data.Seeder.pas',
  TicketSales.Domain.Entities in '..\Domain\TicketSales.Domain.Entities.pas',
  TicketSales.Domain.Enums in '..\Domain\TicketSales.Domain.Enums.pas',
  TicketSales.Domain.Models in '..\Domain\TicketSales.Domain.Models.pas';

const
  DEFAULT_PORT = 9000;

var
  App: IWebApplication;
  Provider: IServiceProvider;
begin
  SetConsoleCharSet;
  try
    WriteLn('');
    WriteLn('========================================');
    WriteLn('   🎫 Ticket Sales API v1.0');
    WriteLn('========================================');
    WriteLn('');

    // Create application with fluent startup
    App := TDextApplication.Create;
    App.UseStartup(TStartup.Create);

    // Build services and seed database BEFORE running
    WriteLn('🔧 Initializing services...');
    Provider := App.BuildServices;

    WriteLn('📦 Setting up database...');
    TDbSeeder.Seed(Provider);

    WriteLn('🚀 Server starting on http://localhost:' + IntToStr(DEFAULT_PORT));
    WriteLn('');
    WriteLn('📖 Swagger UI: http://localhost:' + IntToStr(DEFAULT_PORT) + '/swagger');
    WriteLn('');
    WriteLn('Endpoints:');
    WriteLn('  GET    /api/events             - List all events');
    WriteLn('  GET    /api/events/available   - List available events');
    WriteLn('  GET    /api/events/{id}        - Get event by ID');
    WriteLn('  POST   /api/events             - Create event (auth required)');
    WriteLn('  POST   /api/customers          - Register customer');
    WriteLn('  POST   /api/orders             - Create order');
    WriteLn('  POST   /api/orders/{id}/pay    - Pay for order');
    WriteLn('  POST   /api/tickets/validate   - Validate ticket');
    WriteLn('  GET    /api/health             - Health check');
    WriteLn('');
    WriteLn('Press Ctrl+C to stop the server...');
    WriteLn('');

    App.Run(DEFAULT_PORT);

  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('❌ Error: ' + E.ClassName + ': ' + E.Message);
      WriteLn('');
      ExitCode := 1;
    end;
  end;
  ConsolePause;
end.
