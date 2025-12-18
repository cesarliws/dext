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

interface

uses
  Dext.Web.ControllerScanner,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
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
    function BuildServices: IServiceProvider; // ?
    function UseMiddleware(Middleware: TClass): IWebApplication;
    function UseStartup(Startup: IStartup): IWebApplication; // ? Non-generic
    function MapControllers: IWebApplication;
    procedure Run(Port: Integer = 8080);
  end;

implementation

uses
  System.SysUtils,
  {$IF Defined(MSWINDOWS)}
 Dext.Utils,
  {$ENDIF}
  Dext.DI.Core,
  Dext.Web.Core,
  Dext.Web.Indy.Server,
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
  {$IF Defined(MSWINDOWS)}
  SetConsoleCharSet(CP_UTF8);
  SetTextCodePage(Output, CP_UTF8);
  {$ENDIF}

  // Initialize Configuration
  ConfigBuilder := TConfigurationBuilder.Create;
  
  // 1. Base appsettings.json
  ConfigBuilder.Add(TJsonConfigurationSource.Create('appsettings.json', True));

  // 2. Environment specific appsettings.{Env}.json
  var Env := GetEnvironmentVariable('DEXT_ENVIRONMENT');
  if Env = '' then Env := 'Production'; // Default to Production
  
  if Env <> '' then
    ConfigBuilder.Add(TJsonConfigurationSource.Create('appsettings.' + Env + '.json', True));

  // 3. Environment Variables
  ConfigBuilder.Add(TEnvironmentVariablesConfigurationSource.Create);
    
  FConfiguration := ConfigBuilder.Build;
  
  FServices := TDextServiceCollection.Create;
  
  // Register Configuration
  var LConfig := FConfiguration;
  FServices.AddSingleton(
    TServiceType.FromInterface(IConfiguration),
    TConfigurationRoot,
    function(Provider: IServiceProvider): TObject
    begin
      Result := LConfig as TConfigurationRoot;
    end
  );
  
  // ? Create a temporary provider for ApplicationBuilder
  // The real provider will be built in Run() after all services are registered
  FServiceProvider := FServices.BuildServiceProvider;
  FAppBuilder := TApplicationBuilder.Create(FServiceProvider);
  ConfigBuilder := nil;
end;

destructor TDextApplication.Destroy;
begin
  FAppBuilder := nil;
  FServiceProvider := nil;
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

function TDextApplication.BuildServices: IServiceProvider;
begin
  // ? REBUILD ServiceProvider to include all services registered after Create()
  FServiceProvider := nil; // Release old provider
  FServiceProvider := FServices.BuildServiceProvider;
  FAppBuilder.SetServiceProvider(FServiceProvider);
  Result := FServiceProvider;
end;

function TDextApplication.MapControllers: IWebApplication;
var
  RouteCount: Integer;
begin
  // No need to rebuild usage provider here, scanning uses RTTI.
  // FServiceProvider will be rebuilt in Run() to include all services.
  
  FScanner := TControllerScanner.Create;
  RouteCount := FScanner.RegisterRoutes(FAppBuilder);

  if RouteCount = 0 then
  begin
    Writeln('No routes found!')
  end;

  Result := Self;
end;

procedure TDextApplication.Run(Port: Integer);
var
  WebHost: IWebHost;
  RequestHandler: TRequestDelegate;
  HostedManager: THostedServiceManager;
begin
  // ? REBUILD ServiceProvider to include all services registered after Create()
  FServiceProvider := nil; // Release old provider
  FServiceProvider := FServices.BuildServiceProvider;
  FAppBuilder.SetServiceProvider(FServiceProvider);
  
  // Start Hosted Services
  HostedManager := nil;
  try
    // ? Resolve as INTERFACE (enables ARC management)
    var ManagerIntf := FServiceProvider.GetServiceAsInterface(TServiceType.FromInterface(IHostedServiceManager));
    if ManagerIntf <> nil then
    begin
      HostedManager := ManagerIntf as THostedServiceManager;
      HostedManager.StartAsync;
    end;
  except
    on E: Exception do
      { Failed to start hosted services };
  end;

  // Build pipeline
  RequestHandler := FAppBuilder.Build;

  // Create WebHost
  WebHost := TIndyWebServer.Create(Port, RequestHandler, FServiceProvider);

  try
    WebHost.Run;
  finally
    // Stop Hosted Services
    if HostedManager <> nil then
    begin
      HostedManager.StopAsync;
      // Do NOT Free HostedManager here if it is a Singleton managed by FServiceProvider
      // It will be freed when FServiceProvider is destroyed.
      // If it's transient, we might need to free it, but it's registered as singleton usually.
    end;
    
    // Explicitly release provider reference to ensure cleanup
    FServiceProvider := nil;
  end;

  end;

function TDextApplication.UseMiddleware(Middleware: TClass): IWebApplication;
begin
  FAppBuilder.UseMiddleware(Middleware);
  Result := Self;
end;

function TDextApplication.UseStartup(Startup: IStartup): IWebApplication;
begin
  // 1. Configure Services
  Startup.ConfigureServices(TDextServices.Create(FServices), FConfiguration);
  
  // 2. Configure Pipeline
  Startup.Configure(Self);
  
  Result := Self;
end;

end.


