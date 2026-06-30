unit AppStartup;

interface

uses
  System.SysUtils,
  Dext, Dext.DI.Interfaces,
  Dext.Json,
  Dext.Web,
  Dext.Entity,
  Dext.Logging.Global,
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
  private
    procedure ConfigureDatabase(Options: TDbContextOptions);
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
      ConfigureDatabase(Options);
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

procedure TAppStartup.ConfigureDatabase(Options: TDbContextOptions);
const
  // EASY SWITCH: Change this constant to switch database provider
  DB_PROVIDER = 'SQLITE'; // Options: SQLITE, POSTGRES
begin
  if DB_PROVIDER = 'POSTGRES' then
  begin
    // PostgreSQL Configuration (Production Ready)
    Options.UseDriver('PG');
    Options.ConnectionString := 
      'Server=localhost;' +
      'Port=5432;' +
      'Database=dext_admin;' +
      'User_Name=postgres;' +
      'Password=postgres;';
    
    // Enable Pooling for high concurrency
    Options.WithPooling(True, 50);
  end
  else // Default to SQLite
  begin
    // SQLite Configuration (Development)
    Options.UseSQLite('dext_admin.db');
    
    // SQLite Specific Optimizations for Concurrency
    Options.Params.AddOrSetValue('LockingMode', 'Normal');
    Options.Params.AddOrSetValue('JournalMode', 'WAL'); // Critical for concurrent reads/writes
    Options.Params.AddOrSetValue('Synchronous', 'Normal');
    Options.Params.AddOrSetValue('SharedCache', 'False'); // Prevent shared cache issues in threads
    
    // Enable Pooling (Requires WAL mode)
    Options.WithPooling(True, 20);

    // ADVANCED: You can also define a connection entirely by an INI-style string
    {
    Options.ConnectionDefName := 'DextAdminRuntimePool';
    Options.ConnectionDefString := 
      'DriverID=SQLite' + sLineBreak +
      'Database=dext_admin.db' + sLineBreak +
      'Pooled=True' + sLineBreak +
      'Pool_MaximumItems=50' + sLineBreak +
      'MonitorBy=FlatFile';
    }
  end;
end;

class procedure TAppStartup.RunSeeder(const App: IWebApplication);
var
  ServiceProvider: IServiceProvider;
  SeederObj: TObject;
  Seeder: TDbSeeder;
begin
  Log.Info('[*] Preparing to seed database...');
  ServiceProvider := App.GetApplicationBuilder.GetServiceProvider;
  if ServiceProvider = nil then
  begin
    Log.Error('[ERROR] ServiceProvider is nil');
    Exit;
  end;

  SeederObj := ServiceProvider.GetService(TServiceType.FromClass(TDbSeeder));
  if SeederObj <> nil then
  begin
    Seeder := SeederObj as TDbSeeder;
    try
      Seeder.Seed;
    finally
      Seeder.Free;
    end;
  end
  else
    Log.Warn('[WARN] TDbSeeder service not found.');
end;

procedure TAppStartup.Configure(const App: IWebApplication);
var
  WebApp: TAppBuilder;
begin
  WebApp := App.GetBuilder;

  // 0. Configure JSON settings globally (camelCase for JS compatibility, case-insensitive for parsing)
  JsonDefaultSettings(JsonSettings.Default.CamelCase.CaseInsensitive);

  // 1. Configure Views Path (using Admin.Utils to get correct path)
  Results.SetViewsPath(GetFilePath('wwwroot\views'));
  
  // 1. Serve Static Files (from wwwroot)
  WebApp.UseStaticFiles;

  // 2. Exception Handler (Global error handling)
  WebApp.UseExceptionHandler;
  WebApp.UseMiddleware(TRequestLoggingMiddleware);

  // 2.1 Response Compression (gzip/deflate)
  WebApp.UseMiddleware(TCompressionMiddleware);

  // 3. JWT Authentication Middleware
  WebApp.UseJwtAuthentication(
    TJwtOptions.Create('dext-admin-secret-key-change-in-production-2024')
  );

  // 4. Auth Guard Middleware (Custom)
  WebApp.UseMiddleware(TAdminAuthMiddleware);

  // 5. Map Features
  TAuthEndpoints.Map(WebApp);
  TDashboardEndpoints.Map(WebApp);
  TCustomerEndpoints.Map(WebApp);
  TSettingsEndpoints.Map(WebApp);

  // 6. Generate Swagger Documentation
  TSwaggerExtensions.UseSwagger(WebApp.Unwrap);
end;

end.
