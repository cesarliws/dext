unit AppStartup;

interface

uses
  System.SysUtils,
  Dext,
  Dext.Web,
  Dext.Persistence,
  // Features
  Auth.Service,
  Auth.Endpoints,
  Dashboard.Endpoints,
  Customer.Endpoints,
  Customer.Service,
  Settings.Endpoints,
  Settings.Service,
  Dashboard.Service,
  // Shared
  Admin.Middleware,
  Admin.Utils,
  // Domain
  User,
  Customer,
  Order,
  DbContext,
  DbSeeder;

type
  TAppStartup = class(TInterfacedObject, IStartup)
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
    class procedure RunSeeder(const App: IWebApplication);
  end;

implementation

{ TAppStartup }

procedure TAppStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  // 1. Auth Service (Generic)
  Services.AddScoped<IAuthService, TAuthService>;

  // 2. Database (SQLite)
  Services.AddDbContext<TAppDbContext>(
    procedure(Options: TDbContextOptions)
    begin
      Options.UseSQLite('dext_admin.db');
      Options.Pooling := False;
      Options.PoolMax := 20;
    end);

  // 2.1 Feature Services
  Services.AddScoped<ICustomerService, TCustomerService>;
  Services.AddScoped<IDashboardService, TDashboardService>;
  Services.AddScoped<ISettingsService, TSettingsService>;

  // 3. Register DbSeeder
  Services.AddTransient(TDbSeeder, TDbSeeder,
    function(Provider: IServiceProvider): TObject
    begin
       Result := TDbSeeder.Create(Provider);
    end);

  // 4. Register JWT Token Handler
  Services.AddSingleton<IJwtTokenHandler, TJwtTokenHandler>(
    function(Provider: IServiceProvider): TObject
    begin
      Result := TJwtTokenHandler.Create(
        'dext-admin-secret-key-change-in-production-2024',
        'DextAdmin',
        'DextAdminUI',
        60);
    end);
end;

class procedure TAppStartup.RunSeeder(const App: IWebApplication);
begin
  Writeln('[*] Preparing to seed database...');
  var ServiceProvider := App.GetApplicationBuilder.GetServiceProvider;
  if ServiceProvider = nil then
  begin
    Writeln('[ERROR] ServiceProvider is nil');
    Exit;
  end;

  var SeederObj := ServiceProvider.GetService(TServiceType.FromClass(TDbSeeder));
  if SeederObj <> nil then
  begin
    var Seeder := SeederObj as TDbSeeder;
    try
      Seeder.Seed;
    finally
      Seeder.Free;
    end;
  end
  else
    Writeln('[WARN] TDbSeeder service not found.');
end;

procedure TAppStartup.Configure(const App: IWebApplication);
begin
  var WebApp := App.GetBuilder;

  // 0. Configure Views Path (using Admin.Utils to get correct path)
  Results.SetViewsPath(GetFilePath('wwwroot\views'));
  
  // 1. Serve Static Files (from wwwroot)
  WebApp.UseStaticFiles;

  // 2. JWT Authentication Middleware
  TApplicationBuilderJwtExtensions.UseJwtAuthentication(
    WebApp,
    TJwtOptions.Create('dext-admin-secret-key-change-in-production-2024')
  );

  // 3. Auth Guard Middleware (Custom)
  WebApp.UseMiddleware(TAdminAuthMiddleware);

  // 4. Generate Swagger Documentation
  TSwaggerExtensions.UseSwagger(WebApp.Unwrap);

  // 5. Map Features
  TAuthEndpoints.Map(WebApp);
  TDashboardEndpoints.Map(WebApp);
  TCustomerEndpoints.Map(WebApp);
  TSettingsEndpoints.Map(WebApp);
end;

end.
