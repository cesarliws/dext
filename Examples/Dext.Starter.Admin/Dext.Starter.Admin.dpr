program Dext.Starter.Admin;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Dext.MM,
  System.SysUtils,
  Dext,
  Dext.Web,
  Dext.Utils,
  AppStartup in 'AppStartup.pas',
  Auth.Endpoints in 'Features\Auth\Auth.Endpoints.pas',
  Dashboard.Endpoints in 'Features\Dashboard\Dashboard.Endpoints.pas',
  Customer.Endpoints in 'Features\Customers\Customer.Endpoints.pas',
  Settings.Endpoints in 'Features\Settings\Settings.Endpoints.pas',
  User in 'Domain\Entities\User.pas',
  UserSettings in 'Domain\Entities\UserSettings.pas',
  Customer in 'Domain\Entities\Customer.pas',
  Order in 'Domain\Entities\Order.pas',
  DbContext in 'Domain\DbContext.pas',
  DbSeeder in 'Domain\DbSeeder.pas',
  Auth.Service in 'Features\Auth\Auth.Service.pas',
  Customer.Service in 'Features\Customers\Customer.Service.pas',
  Dashboard.Service in 'Features\Dashboard\Dashboard.Service.pas',
  Settings.Service in 'Features\Settings\Settings.Service.pas',
  Admin.Middleware in 'Features\Shared\Admin.Middleware.pas',
  Admin.Utils in 'Features\Shared\Admin.Utils.pas',
  Customer.Dto in 'Features\Customers\Customer.Dto.pas',
  Auth.Dto in 'Features\Auth\Auth.Dto.pas',
  Settings.Dto in 'Features\Settings\Settings.Dto.pas';

begin
  try
    SetConsoleCharSet;
    // 1. Initialize Application
    var App: IWebApplication := TDextApplication.Create;
    
    // 2. Configure Configuration Source
    // (Defaults handled by TDextApplication)

    // 3. Use Startup Class (Streamlined)
    App.UseStartup(TAppStartup.Create);
    
    // 4. Build ServiceProvider (needed before RunSeeder)
    // Get the IServiceProvider via IApplicationBuilder after building it from Services
    App.BuildServices; 

    // 5. Run DbSeeder (Sync via Startup Helper)
    TAppStartup.RunSeeder(App);

    Writeln('[*] Dext Admin Starter running at http://localhost:8080');
    App.Run(8080);

  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ReadLn;
    end;
  end;
end.
