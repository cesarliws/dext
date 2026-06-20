{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.WebApplication;
{$I Dext.inc}

interface

uses
  Dext.Configuration.Interfaces,
  Dext.DI.Interfaces,
  Dext.Json,
  Dext.Logging,
  Dext.Web.ControllerScanner,
  Dext.Web.Interfaces,
  Dext.Server.Engine.Types;

type
  /// <summary>
  ///   Central facade for creating and running web applications in the Dext Framework.
  ///   Coordinates configuration (appsettings), dependency injection, middleware pipeline,
  ///   and the execution of the server host (Indy/DCS).
  /// </summary>
  TWebApplication = class(TInterfacedObject, IWebApplication, IWebHost)
  private
    FServices: IServiceCollection;
    FServiceProvider: IServiceProvider;
    FAppBuilder: IApplicationBuilder;
    FScanner: IControllerScanner;
    FConfiguration: IConfiguration;
    FDefaultPort: Integer;
    FActiveHost: IWebHost; // ? Track active host
    FServerFactory: TServerFactory;

    procedure Setup(Port: Integer);
    procedure Teardown;
    procedure LogInfo(const AMsg: string);
    procedure LogWarn(const AMsg: string);
    procedure LogError(const AMsg: string);
    function ResolveLogger: ILogger;
    function GetServiceProvider: IServiceProvider;
  public
    constructor Create;
    destructor Destroy; override;

    // IWebApplication
    /// <summary>Accesses the request pipeline builder to register middlewares.</summary>
    function GetApplicationBuilder: IApplicationBuilder;
    /// <summary>Accesses the unified application configuration.</summary>
    function GetConfiguration: IConfiguration;
    /// <summary>Accesses the service collection for dependency registration.</summary>
    function GetServices: TDextServices;
    function GetBuilder: TAppBuilder;
    /// <summary>Builds the final ServiceProvider by integrating all registered dependencies.</summary>
    function BuildServices: IServiceProvider; // ?
    /// <summary>Registers a class-based middleware in the pipeline.</summary>
    function UseMiddleware(Middleware: TClass): IWebApplication;
    /// <summary>Applies a Startup class configured in the classic .NET pattern.</summary>
    function UseStartup(Startup: IStartup): IWebApplication; // ? Non-generic
    /// <summary>Allows swapping the server factory (e.g., Indy for CrossSockets).</summary>
    procedure UseServerFactory(const AFactory: TServerFactory);
    /// <summary>Configures the web application to use the native server engine (auto-detected).</summary>
    procedure UseNativeServer; overload;
    procedure UseNativeServer(const AOptions: TServerEngineOptions); overload;
    /// <summary>Scans the project for Controllers and registers their routes automatically.</summary>
    function MapControllers: IWebApplication;
    
    /// <summary>Starts the server in blocking mode on the default port.</summary>
    procedure Run; overload;
    /// <summary>Starts the server in blocking mode on the specified port.</summary>
    procedure Run(Port: Integer); overload;
    /// <summary>Starts the server in non-blocking mode (Background thread).</summary>
    procedure Start; overload;
    /// <summary>Starts the server in non-blocking mode on the specified port.</summary>
    procedure Start(Port: Integer); overload;
    /// <summary>Gracefully shuts down the server and releases resources.</summary>
    procedure Stop;
    /// <summary>Defines the default port if not provided in Run/Start.</summary>
    procedure SetDefaultPort(Port: Integer);

    function GetPort: Integer;
    property DefaultPort: Integer read FDefaultPort write FDefaultPort;
    property Port: Integer read GetPort;
  end;

  /// <deprecated>Use TWebApplication instead</deprecated>
  TDextApplication = TWebApplication;

implementation

uses
  System.SysUtils,
  Dext.Utils,
  Dext.DI.Core,
  Dext.Logging.Global,
  Dext.Hosting.BackgroundService,
  Dext.Web.Builder,
  Dext.Server.Engine.Interfaces,
  Dext.Server.Native,
  Dext.Web.Indy.Server,
  Dext.Web.Indy.SSL.Interfaces,
  Dext.Web.Indy.SSL.OpenSSL,
  Dext.Web.Indy.SSL.Taurus,
  Dext.Configuration.Core,
  Dext.Configuration.Json,
  Dext.Configuration.Yaml,
  Dext.Configuration.EnvironmentVariables,
  Dext.HealthChecks,
  Dext.Hosting.ApplicationLifetime,
  Dext.Hosting.AppState
  {$IFDEF DEXT_ENABLE_ENTITY},
  Dext.Entity.Core,
  Dext.Entity.Migrations.Runner,
  Dext.Entity.Drivers.FireDAC.Manager
  {$ENDIF};

{ TWebApplication }

constructor TWebApplication.Create;
var
  ConfigBuilder: IConfigurationBuilder;
  Env: string;
  LConfig: IConfiguration;
begin
  inherited Create;
  FDefaultPort := 8080;
  {$IF Defined(MSWINDOWS)}
  SetConsoleCharSet(CP_UTF8);
  SetTextCodePage(Output, CP_UTF8);
  {$ENDIF}

  // Initialize Configuration
  ConfigBuilder := TConfigurationBuilder.Create;
  
  // 1. Base appsettings
  ConfigBuilder.Add(TJsonConfigurationSource.Create('appsettings.json', True));
  ConfigBuilder.Add(TYamlConfigurationSource.Create('appsettings.yaml', True));
  ConfigBuilder.Add(TYamlConfigurationSource.Create('appsettings.yml', True));

  // 2. Environment specific appsettings.{Env}
  Env := GetEnvironmentVariable('DEXT_ENVIRONMENT');
  if Env = '' then Env := 'Production'; // Default to Production
  
  if Env <> '' then
  begin
    ConfigBuilder.Add(TJsonConfigurationSource.Create('appsettings.' + Env + '.json', True));
    ConfigBuilder.Add(TYamlConfigurationSource.Create('appsettings.' + Env + '.yaml', True));
    ConfigBuilder.Add(TYamlConfigurationSource.Create('appsettings.' + Env + '.yml', True));
  end;

  // 3. Environment Variables
  ConfigBuilder.Add(TEnvironmentVariablesConfigurationSource.Create);
    
  FConfiguration := ConfigBuilder.Build;
  
  FServices := TDextServiceCollection.Create;
  
  // Register Configuration
  LConfig := FConfiguration;
  FServices.AddSingleton(
    TServiceType.FromInterface(IConfiguration),
    TConfigurationRoot,
    function(Provider: IServiceProvider): TObject
    begin
      Result := LConfig as TObject;
    end
  );

  // Register Application Lifetime
  FServices.AddSingleton(
    TServiceType.FromInterface(IHostApplicationLifetime),
    THostApplicationLifetime
  );

  // Register Application State
  FServices.AddSingleton(
    TServiceType.FromInterface(IAppStateObserver),
    TApplicationStateManager
  );
  FServices.AddSingleton(
    TServiceType.FromInterface(IAppStateControl),
    TApplicationStateManager,
    function(Provider: IServiceProvider): TObject
    begin
      // Return the same instance as IAppStateObserver (Singleton)
      Result := Provider.GetService(TServiceType.FromInterface(IAppStateObserver));
    end
  );
  
  // Register default fallback ILogger (uses global Log.Logger)
  FServices.AddSingleton(
    TServiceType.FromInterface(TypeInfo(ILogger)),
    TClass(nil),
    function(Provider: IServiceProvider): TObject
    begin
      Result := Log.Logger as TObject;
    end
  );
  
  // Don't build ServiceProvider yet - will be built lazily after all services registered
  // This ensures services added via WebHostBuilder.AddRange are included
  FServiceProvider := nil;
  FAppBuilder := nil; // Will be created lazily when GetApplicationBuilder is called
  ConfigBuilder := nil;
end;

destructor TWebApplication.Destroy;
begin
  Stop; // Ensure cleanup via Teardown
  
  // Ensure ALL interface fields are niled even if Teardown was skipped or partial.
  // Teardown nils these too, but we must be defensive in the destructor.
  FActiveHost := nil;     // Releases TDextIndyWebServer ? pipeline closures ? middlewares
  FScanner := nil;        // Releases TControllerScanner ? FCtx (TRttiContext)
  FAppBuilder := nil;     // Releases TApplicationBuilder ? routes, middleware registrations
  FServiceProvider := nil; // Releases root DI provider ? singletons
  FServices := nil;       // Releases TDextServiceCollection ? descriptors
  FConfiguration := nil;  // Releases TConfigurationRoot ? ALL config providers
  inherited Destroy;
end;

function TWebApplication.GetApplicationBuilder: IApplicationBuilder;
begin
  // Lazy initialization: create ApplicationBuilder with nil ServiceProvider initially.
  // The ServiceProvider will be set/updated in Run() AFTER all services are registered.
  if FAppBuilder = nil then
    FAppBuilder := TApplicationBuilder.Create(nil); // Will be updated in Run()
  Result := FAppBuilder;
end;

function TWebApplication.GetConfiguration: IConfiguration;
begin
  Result := FConfiguration;
end;

function TWebApplication.GetServices: TDextServices;
begin
  Result := TDextServices.Create(FServices);
end;

function TWebApplication.GetBuilder: TAppBuilder;
begin
  Result := TAppBuilder.Create(GetApplicationBuilder);
end;

function TWebApplication.GetServiceProvider: IServiceProvider;
begin
  if FServiceProvider = nil then
    BuildServices;
  Result := FServiceProvider;
end;

function TWebApplication.BuildServices: IServiceProvider;
begin
  // Rebuild ServiceProvider to include all services registered after Create()
  FServiceProvider := nil; // Release old provider
  FServiceProvider := FServices.BuildServiceProvider;
  
  // Set as global default provider for record-based service resolution (TDextServices.GetService<T>)
  TDextServices.DefaultProvider := FServiceProvider;

  // Ensure AppBuilder is updated or created with the new provider
  GetApplicationBuilder.SetServiceProvider(FServiceProvider);
  // Force logger resolution to initialize Telemetry Bridge
  ResolveLogger;

  Result := FServiceProvider;
end;

function TWebApplication.MapControllers: IWebApplication;
var
  RouteCount: Integer;
begin
  // No need to rebuild usage provider here, scanning uses RTTI.
  // FServiceProvider will be rebuilt in Run() to include all services.
  
  FScanner := TControllerScanner.Create;
  RouteCount := FScanner.RegisterRoutes(GetApplicationBuilder);

  if RouteCount = 0 then
    LogWarn('No routes found!');

  Result := Self;
end;

function TWebApplication.ResolveLogger: ILogger;
begin
  Result := nil;
  if FServiceProvider <> nil then
    Result := FServiceProvider.GetServiceAsInterface(TypeInfo(ILogger)) as ILogger;
end;

procedure TWebApplication.LogInfo(const AMsg: string);
var
  LLogger: ILogger;
begin
  LLogger := ResolveLogger;
  if LLogger <> nil then
    LLogger.LogInformation(AMsg)
  else
    SafeWriteLn(AMsg);
end;

procedure TWebApplication.LogWarn(const AMsg: string);
var
  LLogger: ILogger;
begin
  LLogger := ResolveLogger;
  if LLogger <> nil then
    LLogger.LogWarning(AMsg)
  else
    SafeWriteLn('[WARN] ' + AMsg);
end;

procedure TWebApplication.LogError(const AMsg: string);
var
  LLogger: ILogger;
begin
  LLogger := ResolveLogger;
  if LLogger <> nil then
    LLogger.LogError(AMsg)
  else
    SafeWriteLn('? ' + AMsg);
end;

procedure TWebApplication.Setup(Port: Integer);
var
  RequestHandler: TRequestDelegate;
  HostedManager: IHostedServiceManager;
  SSLHandler: IIndySSLHandler;
  Lifetime: IHostApplicationLifetime;
  StateControl: IAppStateControl;
  LifetimeIntf: IInterface;
  StateIntf: IInterface;
  DbConfig: IConfigurationSection;
  DbContextIntf: IInterface;
  Migrator: TMigrator;
  ManagerIntf: IInterface;
  ServerSection: IConfigurationSection;
  CertFile: string;
  KeyFile: string;
  RootFile: string;
  ProviderName: string;
begin
  FDefaultPort := Port;
  
  // Build ServiceProvider now if not already built via BuildServices()
  // This is the correct place to do it, AFTER all services have been registered
  if FServiceProvider = nil then
    BuildServices;
  
  // Update ApplicationBuilder with the final ServiceProvider
  GetApplicationBuilder.SetServiceProvider(FServiceProvider);
  
  // Bridge ServiceProvider to JSON global settings for automated DI-driven deserialization
  TDextJson.SetDefaultSettings(TDextJson.GetDefaultSettings.ServiceProvider(FServiceProvider));
  
  // Get Lifetime & State Service
  LifetimeIntf := FServiceProvider.GetServiceAsInterface(TypeInfo(IHostApplicationLifetime));
  if LifetimeIntf <> nil then
    Lifetime := LifetimeIntf as IHostApplicationLifetime
  else
    Lifetime := nil;

  StateIntf := FServiceProvider.GetServiceAsInterface(TypeInfo(IAppStateControl));
  if StateIntf <> nil then
    StateControl := StateIntf as IAppStateControl
  else
    StateControl := nil;

  // Update State: Starting -> Migrating
  if StateControl <> nil then
    StateControl.SetState(asMigrating);

  {$IFDEF DEXT_ENABLE_ENTITY}
  // 🗄️ Run Migrations automatically if configured
  DbConfig := FConfiguration.GetSection('Database');
  if (DbConfig <> nil) and (SameText(DbConfig['AutoMigrate'], 'true')) then
  begin
    LogInfo('🗄️ AutoMigrate enabled. Checking database schema...');
    
    // Resolve DbContext
    DbContextIntf := FServiceProvider.GetServiceAsInterface(TServiceType.FromInterface(IDbContext));
    if DbContextIntf <> nil then
    begin
      Migrator := TMigrator.Create(DbContextIntf as IDbContext, ResolveLogger);
      try
        Migrator.Migrate;
      finally
        Migrator.Free;
      end;
    end;
  end;
  {$ENDIF}
  
  // Update State: Migrating -> Seeding
  if StateControl <> nil then
    StateControl.SetState(asSeeding);
    
  // TODO: Run Seeding automatically if configured

  // Update State: Seeding -> Running
  if StateControl <> nil then
    StateControl.SetState(asRunning);

  // Start Hosted Services
  HostedManager := nil;
  try
    // ⚙️ Resolve as INTERFACE (enables ARC management)
    ManagerIntf := FServiceProvider.GetServiceAsInterface(TServiceType.FromInterface(IHostedServiceManager));
    if ManagerIntf <> nil then
    begin
      HostedManager := ManagerIntf as IHostedServiceManager;
      HostedManager.StartAsync;
    end;
  except
    on E: Exception do
      LogError('Error starting hosted services: ' + E.Message);
  end;

  // Notify Started
  if (Lifetime <> nil) and (Lifetime is THostApplicationLifetime) then
    THostApplicationLifetime(Lifetime).NotifyStarted;

  // Build pipeline
  RequestHandler := GetApplicationBuilder.Build;

  // Create WebHost
  SSLHandler := nil;
  ServerSection := FConfiguration.GetSection('Server');
  if (ServerSection <> nil) and (SameText(ServerSection['UseHttps'], 'true')) then
  begin
    CertFile := ServerSection['SslCert'];
    KeyFile := ServerSection['SslKey'];
    RootFile := ServerSection['SslRootCert'];
    
    // Only enable SSL if certificate files exist
    if (CertFile <> '') and (KeyFile <> '') and 
       FileExists(CertFile) and FileExists(KeyFile) then
    begin
      ProviderName := ServerSection['SslProvider'];
      if SameText(ProviderName, 'Taurus') then
        SSLHandler := TDextIndyTaurusSSLHandler.Create(CertFile, KeyFile, RootFile)
      else
        SSLHandler := TDextIndyOpenSSLHandler.Create(CertFile, KeyFile, RootFile);
    end
    else if (CertFile <> '') or (KeyFile <> '') then
      LogWarn('HTTPS configured but certificate files not found. Using HTTP.');
  end;

  // Store active host
  if Assigned(FServerFactory) then
    FActiveHost := FServerFactory(Port, RequestHandler, FServiceProvider)
  else
    FActiveHost := TDextIndyWebServer.Create(Port, RequestHandler, FServiceProvider, SSLHandler);
end;

procedure TWebApplication.Teardown;
var
  StateControl: IAppStateControl;
  StateObserver: IAppStateObserver;
  HostedManager: IHostedServiceManager;
  Lifetime: IHostApplicationLifetime;
  StateControlIntf: IInterface;
  StateObserverIntf: IInterface;
  LifetimeIntf: IInterface;
  ManagerIntf: IInterface;
begin
  if FServiceProvider = nil then Exit;

  // Resolve services
  StateControlIntf := FServiceProvider.GetServiceAsInterface(TServiceType.FromInterface(IAppStateControl));
  if StateControlIntf <> nil then
    StateControl := StateControlIntf as IAppStateControl
  else
    StateControl := nil;

  StateObserverIntf := FServiceProvider.GetServiceAsInterface(TServiceType.FromInterface(IAppStateObserver));
  if StateObserverIntf <> nil then
    StateObserver := StateObserverIntf as IAppStateObserver
  else
    StateObserver := nil;
    
  // Idempotency check: If already stopped, exit
  if (StateObserver <> nil) and (StateObserver.State = asStopped) then Exit;

  LifetimeIntf := FServiceProvider.GetServiceAsInterface(TServiceType.FromInterface(IHostApplicationLifetime));
  if LifetimeIntf <> nil then
    Lifetime := LifetimeIntf as IHostApplicationLifetime
  else
    Lifetime := nil;
    
  ManagerIntf := FServiceProvider.GetServiceAsInterface(TServiceType.FromInterface(IHostedServiceManager));
  if ManagerIntf <> nil then
    HostedManager := ManagerIntf as IHostedServiceManager
  else
    HostedManager := nil;
    
  // Release active host reference
  FActiveHost := nil;
  FAppBuilder := nil;
  FScanner := nil;

  // Update State: Running -> Stopping
  if StateControl <> nil then
    StateControl.SetState(asStopping);

  // Notify Stopping
  if (Lifetime <> nil) and (Lifetime is THostApplicationLifetime) then
    THostApplicationLifetime(Lifetime).NotifyStopping;

  // Stop Hosted Services
  if HostedManager <> nil then
  begin
    HostedManager.StopAsync;
  end;
  
  // Update State: Stopping -> Stopped
  if StateControl <> nil then
    StateControl.SetState(asStopped);

  // Notify Stopped
  if (Lifetime <> nil) and (Lifetime is THostApplicationLifetime) then
    THostApplicationLifetime(Lifetime).NotifyStopped;
    
  // Clear the service provider reference stored in TDextJson to avoid leaking the container
  TDextJson.SetDefaultSettings(TDextJson.GetDefaultSettings.ServiceProvider(nil));

  // Clear global default provider in TDextServices
  TDextServices.DefaultProvider := nil;

  // Explicitly release provider reference to ensure cleanup
  FServiceProvider := nil;

  {$IFDEF DEXT_ENABLE_ENTITY}
  // 🔌 Finalize custom FireDAC Manager to drop pools before app shutdown audit
  TDextFireDACManager.Finalize;
  {$ENDIF}

  // ? Break circular references by niling interfaces that might be captured in closures
  FServices := nil;
  FConfiguration := nil;
end;

procedure TWebApplication.Run;
begin
  Run(FDefaultPort);
end;

procedure TWebApplication.Run(Port: Integer);
begin
  Setup(Port);
  try
    FActiveHost.Run;
  finally
    Teardown;
  end;
end;

procedure TWebApplication.Start;
begin
  Start(FDefaultPort);
end;

procedure TWebApplication.Start(Port: Integer);
begin
  Setup(Port);
  FActiveHost.Start;
end;

function TWebApplication.UseMiddleware(Middleware: TClass): IWebApplication;
begin
  GetApplicationBuilder.UseMiddleware(Middleware);
  Result := Self;
end;

function TWebApplication.UseStartup(Startup: IStartup): IWebApplication;
begin
  // 1. Configure Services
  Startup.ConfigureServices(TDextServices.Create(FServices), FConfiguration);
  
  // 2. Configure Pipeline
  Startup.Configure(Self);
  
  Result := Self;
end;

procedure TWebApplication.Stop;
var
  LifetimeIntf: IInterface;
begin
  if FServiceProvider <> nil then
  begin
    LifetimeIntf := FServiceProvider.GetServiceAsInterface(TServiceType.FromInterface(IHostApplicationLifetime));
    if LifetimeIntf <> nil then
      (LifetimeIntf as IHostApplicationLifetime).StopApplication;
  end;

  if FActiveHost <> nil then
  begin
    LogInfo('Stopping active host...');
    FActiveHost.Stop;
  end;
  
  Teardown;
end;

procedure TWebApplication.SetDefaultPort(Port: Integer);
begin
  FDefaultPort := Port;
end;

function TWebApplication.GetPort: Integer;
begin
  if FActiveHost <> nil then
    Result := FActiveHost.Port
  else
    Result := FDefaultPort;
end;

procedure TWebApplication.UseServerFactory(const AFactory: TServerFactory);
begin
  FServerFactory := AFactory;
end;

procedure TWebApplication.UseNativeServer;
begin
  UseNativeServer(TServerEngineOptions.Default);
end;

procedure TWebApplication.UseNativeServer(const AOptions: TServerEngineOptions);
begin
  FServerFactory := function(Port: Integer; Pipeline: TRequestDelegate; Services: IServiceProvider): IWebHost
    begin
      Result := TDextNativeWebServer.Create(Port, Pipeline, Services, AOptions);
    end;
end;

end.
