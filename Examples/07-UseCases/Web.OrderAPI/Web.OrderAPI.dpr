program Web.OrderAPI;

{***************************************************************************}
{                                                                           }
{  Order API - Sistema de Comandas para Bares e Restaurantes                }
{                                                                           }
{  Exemplo de Referência para Migração DelphiMVC -> Dext                    }
{  Refatorado com padrão Startup (IStartup)                                 }
{                                                                           }
{***************************************************************************}

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Utils,
  Dext,
  Dext.Web,
  OrderAPI.Startup in 'OrderAPI.Startup.pas',
  OrderAPI.Entities in 'OrderAPI.Entities.pas',
  OrderAPI.Database in 'OrderAPI.Database.pas',
  OrderAPI.Services in 'OrderAPI.Services.pas',
  OrderAPI.Controllers in 'OrderAPI.Controllers.pas';

var
  App: IWebApplication;
begin
  try
    SetConsoleCharSet(65001);
    WriteLn('');
    WriteLn('==============================================');
    WriteLn('  ORDER API - Sistema de Comandas');
    WriteLn('  Exemplo de Referência: DMVC -> Dext');
    WriteLn('==============================================');
    WriteLn('');

    App := WebApplication;
    
    // 1. Configure Startup Class
    // The framework will call ConfigureServices and Configure automatically
    // during Build/Run, or we can trigger build manually.
    App.UseStartup(TStartup.Create);
    
    // 2. Build Services explicitly to enable Seeding before Run
    App.BuildServices;
    
    // 3. Seed Data
    TStartup.SeedDatabase(App);
    
    WriteLn('[*] Starting Server on http://localhost:5000');
    WriteLn('    Swagger UI: http://localhost:5000/api/swagger');
    
    App.Run(5000);
    
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ConsolePause;
end.
