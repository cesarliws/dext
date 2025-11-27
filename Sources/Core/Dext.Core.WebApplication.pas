unit Dext.Core.WebApplication;

interface

uses
  Dext.Core.ControllerScanner,
  Dext.DI.Interfaces,
  Dext.Http.Interfaces,
  Dext.Configuration.Interfaces;

type
  TDextApplication = class(TInterfacedObject, IWebApplication)
  private
    FServices: IServiceCollection;
    FServiceProvider: IServiceProvider;
    FAppBuilder: IApplicationBuilder;
    FScanner: IControllerScanner;
    FConfiguration: IConfiguration;
  public
    constructor Create;
    destructor Destroy; override;

    // IWebApplication
    function GetApplicationBuilder: IApplicationBuilder;
    function GetConfiguration: IConfiguration;
    function GetServices: TDextServices;
    function GetBuilder: TDextAppBuilder;
    function UseMiddleware(Middleware: TClass): IWebApplication;
    function MapControllers: IWebApplication;
    procedure Run(Port: Integer = 8080);
  end;

implementation

uses
  System.SysUtils,
  Dext.DI.Core,
  Dext.Http.Core,
  Dext.Http.Indy.Server,
  Dext.Configuration.Core,
  Dext.Configuration.Json,
  Dext.Configuration.EnvironmentVariables,
  Dext.HealthChecks,
  Dext.Hosting.BackgroundService;

{ TDextApplication }

constructor TDextApplication.Create;
var
  ConfigBuilder: IConfigurationBuilder;
begin
  inherited Create;
  WriteLn('🏗️ TDextApplication.Create');
  
  // Initialize Configuration
  ConfigBuilder := TConfigurationBuilder.Create;
  
  // 1. Base appsettings.json
  ConfigBuilder.Add(TJsonConfigurationSource.Create('appsettings.json', True));

  // 2. Environment specific appsettings.{Env}.json
  var Env := GetEnvironmentVariable('DEXT_ENVIRONMENT');
  if Env = '' then Env := 'Production'; // Default to Production
  
  WriteLn('🌍 Environment: ' + Env);
  
  if Env <> '' then
    ConfigBuilder.Add(TJsonConfigurationSource.Create('appsettings.' + Env + '.json', True));

  // 3. Environment Variables
  ConfigBuilder.Add(TEnvironmentVariablesConfigurationSource.Create);
    
  FConfiguration := ConfigBuilder.Build;
  
  FServices := TDextServiceCollection.Create;
  
  // Register Configuration
  FServices.AddSingleton(
    TServiceType.FromInterface(IConfiguration),
    TConfigurationRoot,
    function(Provider: IServiceProvider): TObject
    begin
      Result := FConfiguration as TConfigurationRoot;
    end
  );
  
  FServiceProvider := FServices.BuildServiceProvider;
  FAppBuilder := TApplicationBuilder.Create(FServiceProvider);
end;

destructor TDextApplication.Destroy;
begin
  WriteLn('💥 TDextApplication.Destroy');
  inherited Destroy;
end;

function TDextApplication.GetApplicationBuilder: IApplicationBuilder;
begin
  Result := FAppBuilder;
end;

function TDextApplication.GetConfiguration: IConfiguration;
begin
  Result := FConfiguration;
end;

function TDextApplication.GetServices: TDextServices;
begin
  Result := TDextServices.Create(FServices);
end;

function TDextApplication.GetBuilder: TDextAppBuilder;
begin
  Result := TDextAppBuilder.Create(FAppBuilder);
end;

function TDextApplication.MapControllers: IWebApplication;
var
  RouteCount: Integer;
begin
  WriteLn('🔍 Scanning for controllers...');

  // Rebuild ServiceProvider to include controllers registered via AddControllers
  FServiceProvider := FServices.BuildServiceProvider;

  FScanner := TControllerScanner.Create(FServiceProvider);
  RouteCount := FScanner.RegisterRoutes(FAppBuilder);

  if RouteCount = 0 then
  begin
    WriteLn('⚠️  No controllers found with routing attributes - using manual fallback');
    FScanner.RegisterControllerManual(FAppBuilder);
  end
  else
    WriteLn('✅ Auto-mapped ', RouteCount, ' routes from controllers');

  Result := Self;
end;

procedure TDextApplication.Run(Port: Integer);
var
  WebHost: IWebHost;
  RequestHandler: TRequestDelegate;
  HostedManager: THostedServiceManager;
  Obj: TObject;
begin
  // Rebuild provider one last time to ensure all services (including hosted ones) are registered
  FServiceProvider := FServices.BuildServiceProvider;
  
  // Start Hosted Services
  HostedManager := nil;
  try
    Obj := FServiceProvider.GetService(TServiceType.FromClass(THostedServiceManager));
    if Obj <> nil then
    begin
      HostedManager := Obj as THostedServiceManager;
      HostedManager.StartAsync;
    end;
  except
    on E: Exception do
      WriteLn('⚠️ Failed to start hosted services: ' + E.Message);
  end;

  // Build pipeline
  RequestHandler := FAppBuilder.Build;

  // Create WebHost
  WebHost := TIndyWebServer.Create(Port, RequestHandler, FServiceProvider);

  WriteLn('🚀 Starting Dext HTTP Server on port ', Port);
  WriteLn('📡 Listening for requests...');

  try
    WebHost.Run;
  finally
    // Stop Hosted Services
    if HostedManager <> nil then
    begin
      HostedManager.StopAsync;
    end;
  end;
end;

function TDextApplication.UseMiddleware(Middleware: TClass): IWebApplication;
begin
  FAppBuilder.UseMiddleware(Middleware);
  Result := Self;
end;

end.
