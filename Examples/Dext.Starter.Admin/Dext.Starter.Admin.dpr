program Dext.Starter.Admin;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  FastMM5,
  System.SysUtils,
  Dext,
  Dext.Web,
  Dext.Utils,
  AppStartup in 'AppStartup.pas',
  
  // Features
  Auth.Service in 'Features\Auth\Auth.Service.pas',
  Auth.Endpoints in 'Features\Auth\Auth.Endpoints.pas',
  Dashboard.Endpoints in 'Features\Dashboard\Dashboard.Endpoints.pas',
  Customer.Endpoints in 'Features\Customers\Customer.Endpoints.pas',
  Settings.Endpoints in 'Features\Settings\Settings.Endpoints.pas',
  
  // Domain
  User in 'Domain\Entities\User.pas',
  Customer in 'Domain\Entities\Customer.pas',
  Order in 'Domain\Entities\Order.pas',
  DbContext in 'Domain\DbContext.pas',
  DbSeeder in 'Domain\DbSeeder.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    SetConsoleCharSet;
    // 1. Initialize Application
    var App: IWebApplication := TDextApplication.Create;
    
    // 2. Configure Configuration Source
    // (Defaults handled by TDextApplication)

    // 3. Use Startup Class
    TAppStartup.ConfigureServices(App.Services, App.Configuration);
    TAppStartup.Configure(App);
    
    // 4. Build ServiceProvider (needed before RunSeeder)
    // Get the IServiceProvider via IApplicationBuilder after building it from Services
    var ServiceProvider := App.Services.BuildServiceProvider;
    App.GetApplicationBuilder.SetServiceProvider(ServiceProvider);
    
    // 5. Run DbSeeder (Sync via Startup Helper)
    TAppStartup.RunSeeder(App);

    Writeln('[*] Dext Admin Starter running at http://localhost:8080');
    App.Run(8080);
    
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
