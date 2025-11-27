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
    function GetServices: IServiceCollection;
    function UseMiddleware(Middleware: TClass): IWebApplication;
    function MapControllers: IWebApplication;
    procedure Run(Port: Integer = 8080);
    // Fluent interface helpers
    function Services: IServiceCollection;
  end;

implementation

uses
  Dext.DI.Core, // ✅ Para TDextServiceCollection
  Dext.Http.Core,
  Dext.Http.Indy.Server, // ✅ Para TIndyWebServer
//  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.Configuration.Json,
  Dext.Configuration.EnvironmentVariables;

{ TDextApplication }

constructor TDextApplication.Create;
var
  ConfigBuilder: IConfigurationBuilder;
begin
  inherited Create;
  
  // Initialize Configuration
  ConfigBuilder := TConfigurationBuilder.Create;
  ConfigBuilder
    .Add(TJsonConfigurationSource.Create('appsettings.json', True)) // Optional
    .Add(TEnvironmentVariablesConfigurationSource.Create);
    
  FConfiguration := ConfigBuilder.Build;
  
  FServices := TDextServiceCollection.Create; // ✅ Corrigido
  
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

function TDextApplication.GetServices: IServiceCollection;
begin
  Result := FServices;
end;

function TDextApplication.MapControllers: IWebApplication;
var
  RouteCount: Integer;
begin
  WriteLn('🔍 Scanning for controllers...');

  // ✅ CRITICAL: Rebuild ServiceProvider to include controllers registered via AddControllers
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
  WebHost: IWebHost; // ✅ Usar IWebHost em vez de IHttpServer
  RequestHandler: TRequestDelegate;
begin
  // Construir pipeline
  RequestHandler := FAppBuilder.Build;

  // ✅ CORRETO: Criar TIndyWebServer que implementa IWebHost
  WebHost := TIndyWebServer.Create(Port, RequestHandler, FServiceProvider);

  WriteLn('🚀 Starting Dext HTTP Server on port ', Port);
  WriteLn('📡 Listening for requests...');

  WebHost.Run; // ✅ Chamar Run do IWebHost
end;

function TDextApplication.Services: IServiceCollection;
begin
  Result := FServices;
end;

function TDextApplication.UseMiddleware(Middleware: TClass): IWebApplication;
begin
  FAppBuilder.UseMiddleware(Middleware);
  Result := Self;
end;

end.
