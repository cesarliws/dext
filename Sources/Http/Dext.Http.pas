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
{  Created: 2025-12-10                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Http;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Auth.Attributes,
  Dext.Auth.Identity,
  Dext.Auth.JWT,
  Dext.Auth.Middleware,
  Dext.Configuration.Interfaces,
  Dext.Core.Controllers,
  Dext.Core.ControllerScanner,
  Dext.Core.ModelBinding,
  Dext.Core.Routing,
  Dext.Core.WebApplication,
  Dext.DI.Interfaces,
  Dext.Filters,
  Dext.Filters.BuiltIn,
  Dext.HealthChecks,
  Dext.Hosting.BackgroundService,
  Dext.Http.Core,
  Dext.Http.Cors,
  Dext.Http.Interfaces,
  Dext.Http.Middleware,
  Dext.Http.Middleware.Extensions,
  Dext.Http.Results,
  Dext.Http.StaticFiles,
  Dext.OpenAPI.Attributes,
  Dext.Options.Extensions,
  Dext.Web.Extensions;

type
  // ===========================================================================
  // 🏷️ Aliases for Common Web Types
  // ===========================================================================
  
  // Core Web Application
  IWebApplication = Dext.Http.Interfaces.IWebApplication;
  TDextApplication = Dext.Core.WebApplication.TDextApplication;
  
  // HTTP Context & Pipeline
  IHttpContext = Dext.Http.Interfaces.IHttpContext;
  IHttpRequest = Dext.Http.Interfaces.IHttpRequest;
  IHttpResponse = Dext.Http.Interfaces.IHttpResponse;
  IMiddleware = Dext.Http.Interfaces.IMiddleware;
  TRequestDelegate = Dext.Http.Interfaces.TRequestDelegate;
  TStaticHandler = Dext.Http.Interfaces.TStaticHandler;
  
  // Results
  IResult = Dext.Http.Interfaces.IResult;
  Results = Dext.Http.Results.Results;

  // Middleware Classes & Options
  THealthCheckMiddleware = Dext.HealthChecks.THealthCheckMiddleware;
  TExceptionHandlerMiddleware = Dext.Http.Middleware.TExceptionHandlerMiddleware;
  TExceptionHandlerOptions = Dext.Http.Middleware.TExceptionHandlerOptions;
  THttpLoggingMiddleware = Dext.Http.Middleware.THttpLoggingMiddleware;
  THttpLoggingOptions = Dext.Http.Middleware.THttpLoggingOptions;

  // Exceptions
  EHttpException = Dext.Http.Middleware.EHttpException;
  ENotFoundException = Dext.Http.Middleware.ENotFoundException;
  EUnauthorizedException = Dext.Http.Middleware.EUnauthorizedException;
  EForbiddenException = Dext.Http.Middleware.EForbiddenException;
  EValidationException = Dext.Http.Middleware.EValidationException;
  
  // CORS
  TCorsOptions = Dext.Http.Cors.TCorsOptions;
  TCorsBuilder = Dext.Http.Cors.TCorsBuilder;
  
  // Auth Options & Handlers
  TJwtOptions = Dext.Auth.JWT.TJwtOptions;
  TJwtOptionsBuilder = Dext.Auth.JWT.TJwtOptionsBuilder;
  TJwtAuthenticationMiddleware = Dext.Auth.Middleware.TJwtAuthenticationMiddleware;
  
  // Static Files
  TStaticFileOptions = Dext.Http.StaticFiles.TStaticFileOptions;

  // Routing Attributes
  DextControllerAttribute = Dext.Core.Routing.DextControllerAttribute;
  DextGetAttribute = Dext.Core.Routing.DextGetAttribute;
  DextPostAttribute = Dext.Core.Routing.DextPostAttribute;
  DextPutAttribute = Dext.Core.Routing.DextPutAttribute;
  DextDeleteAttribute = Dext.Core.Routing.DextDeleteAttribute;
  
  // Model Binding Attributes
  FromQueryAttribute = Dext.Core.ModelBinding.FromQueryAttribute;
  FromRouteAttribute = Dext.Core.ModelBinding.FromRouteAttribute;
  FromBodyAttribute = Dext.Core.ModelBinding.FromBodyAttribute;
  FromServicesAttribute = Dext.Core.ModelBinding.FromServicesAttribute;

  // OpenAPI
  SwaggerAuthorizeAttribute = Dext.OpenAPI.Attributes.SwaggerAuthorizeAttribute;
  
  // Auth
  AllowAnonymousAttribute = Dext.Auth.Attributes.AllowAnonymousAttribute;
  TJwtTokenHandler = Dext.Auth.JWT.TJwtTokenHandler;
  IJwtTokenHandler = Dext.Auth.JWT.IJwtTokenHandler;
  TClaim = Dext.Auth.JWT.TClaim;
  TClaimsBuilder = Dext.Auth.Identity.TClaimsBuilder;
  IClaimsBuilder = Dext.Auth.Identity.IClaimsBuilder;
  
  // Filters
  ActionFilterAttribute = Dext.Filters.ActionFilterAttribute;
  IActionExecutingContext = Dext.Filters.IActionExecutingContext;
  IActionExecutedContext = Dext.Filters.IActionExecutedContext;
  LogActionAttribute = Dext.Filters.BuiltIn.LogActionAttribute;
  RequireHeaderAttribute = Dext.Filters.BuiltIn.RequireHeaderAttribute;
  ResponseCacheAttribute = Dext.Filters.BuiltIn.ResponseCacheAttribute;
  ValidateModelAttribute = Dext.Filters.BuiltIn.ValidateModelAttribute;
  AddHeaderAttribute = Dext.Filters.BuiltIn.AddHeaderAttribute;

  // Health Checks
  IHealthCheck = Dext.HealthChecks.IHealthCheck;
  THealthCheckResult = Dext.HealthChecks.THealthCheckResult;
  THealthCheckBuilder = Dext.HealthChecks.THealthCheckBuilder;

  // Background Services
  TBackgroundServiceBuilder = Dext.Hosting.BackgroundService.TBackgroundServiceBuilder;

  // Web Extensions
  TWebDIHelpers = Dext.Web.Extensions.TWebDIHelpers;
  TWebRouteHelpers = Dext.Web.Extensions.TWebRouteHelpers;

  // ===========================================================================
  // 🛠️ Fluent Helpers & Wrappers
  // ===========================================================================

  /// <summary>
  ///   Helper for TDextServices to add web framework features.
  /// </summary>
  TDextHttpServicesHelper = record helper for TDextServices
  public
    /// <summary>
    ///   Scans the application for controllers (classes with [DextController]) and registers them in the DI container.
    /// </summary>
    function AddControllers: TDextServices;
    
    /// <summary>
    ///   Starts the Health Check builder chain.
    /// </summary>
    function AddHealthChecks: THealthCheckBuilder;
    
    /// <summary>
    ///   Starts the Background Service builder chain.
    /// </summary>
    function AddBackgroundServices: TBackgroundServiceBuilder;
    
    /// <summary>
    ///   Configures a settings class (IOptions&lt;T&gt;) from the root configuration.
    ///   (Re-exposed from Core for convenience)
    /// </summary>
    function Configure<T: class, constructor>(Configuration: IConfiguration): TDextServices; overload;
    
    /// <summary>
    ///   Configures a settings class (IOptions&lt;T&gt;) from a specific configuration section.
    ///   (Re-exposed from Core for convenience)
    /// </summary>
    function Configure<T: class, constructor>(Section: IConfigurationSection): TDextServices; overload;
  end;

  /// <summary>
  ///   Helper for TDextAppBuilder to provide factory methods and extensions for middleware configuration.
  /// </summary>
  TDextHttpAppBuilderHelper = record helper for TDextAppBuilder
  public
    // 🏭 Factory Methods
    
    /// <summary>
    ///   Creates a new instance of TCorsOptions with default settings.
    /// </summary>
    function CreateCorsOptions: TCorsOptions;
    
    /// <summary>
    ///   Creates a new instance of TJwtOptions with the specified secret key.
    /// </summary>
    function CreateJwtOptions(const Secret: string): TJwtOptions;
    
    /// <summary>
    ///   Creates a new instance of TStaticFileOptions with default settings.
    /// </summary>
    function CreateStaticFileOptions: TStaticFileOptions;
    
    // 🔌 Extensions
    
    /// <summary>
    ///   Adds CORS middleware to the pipeline using the provided options.
    /// </summary>
    function UseCors(const AOptions: TCorsOptions): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Adds CORS middleware to the pipeline using a configuration delegate.
    /// </summary>
    function UseCors(AConfigurator: TProc<TCorsBuilder>): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Adds JWT Authentication middleware to the pipeline using the provided options.
    /// </summary>
    function UseJwtAuthentication(const AOptions: TJwtOptions): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Adds JWT Authentication middleware to the pipeline using the provided options (Legacy overload).
    /// </summary>
    function UseJwtAuthentication(const ASecretKey: string; AConfigurator: TProc<TJwtOptionsBuilder>): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Adds Static Files middleware to the pipeline using the provided options.
    /// </summary>
    function UseStaticFiles(const AOptions: TStaticFileOptions): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Adds Static Files middleware to the pipeline serving from the specified root path.
    /// </summary>
    function UseStaticFiles(const ARootPath: string): TDextAppBuilder; overload;
    
    // 🧩 Core Forwarding
    
    /// <summary>
    ///   Adds a middleware class to the pipeline. The middleware must have a constructor accepting RequestDelegate (and optionally other services).
    /// </summary>
    function UseMiddleware(AMiddleware: TClass): TDextAppBuilder;
    
    /// <summary>
    ///   Maps a GET request to a static handler.
    /// </summary>
    function MapGet(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
    
    /// <summary>
    ///   Maps a POST request to a static handler.
    /// </summary>
    function MapPost(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
    
    /// <summary>
    ///   Maps a PUT request to a static handler.
    /// </summary>
    function MapPut(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
    
    /// <summary>
    ///   Maps a DELETE request to a static handler.
    /// </summary>
    function MapDelete(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
    
    /// <summary>
    ///   Builds the request pipeline and returns the main RequestDelegate.
    /// </summary>
    function Build: TRequestDelegate;
  end;

implementation

{ TDextHttpServicesHelper }

function TDextHttpServicesHelper.AddControllers: TDextServices;
var
  Scanner: IControllerScanner;
begin
  Scanner := TControllerScanner.Create;
  Scanner.RegisterServices(Self.Unwrap);
  Result := Self;
end;

function TDextHttpServicesHelper.AddHealthChecks: THealthCheckBuilder;
begin
  Result := THealthCheckBuilder.Create(Self.Unwrap);
end;

function TDextHttpServicesHelper.AddBackgroundServices: TBackgroundServiceBuilder;
begin
  Result := TBackgroundServiceBuilder.Create(Self.Unwrap);
end;

function TDextHttpServicesHelper.Configure<T>(Configuration: IConfiguration): TDextServices;
begin
  TOptionsServiceCollectionExtensions.Configure<T>(Self.Unwrap, Configuration);
  Result := Self;
end;

function TDextHttpServicesHelper.Configure<T>(Section: IConfigurationSection): TDextServices;
begin
  TOptionsServiceCollectionExtensions.Configure<T>(Self.Unwrap, Section);
  Result := Self;
end;

{ TDextHttpAppBuilderHelper }

function TDextHttpAppBuilderHelper.CreateCorsOptions: TCorsOptions;
begin
  Result := TCorsOptions.Create;
end;

function TDextHttpAppBuilderHelper.CreateJwtOptions(const Secret: string): TJwtOptions;
begin
  Result := TJwtOptions.Create(Secret);
end;

function TDextHttpAppBuilderHelper.CreateStaticFileOptions: TStaticFileOptions;
begin
  Result := TStaticFileOptions.Create;
end;

function TDextHttpAppBuilderHelper.UseCors(const AOptions: TCorsOptions): TDextAppBuilder;
begin
  TApplicationBuilderCorsExtensions.UseCors(Self.Unwrap, AOptions);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.UseCors(AConfigurator: TProc<TCorsBuilder>): TDextAppBuilder;
begin
  TApplicationBuilderCorsExtensions.UseCors(Self.Unwrap, AConfigurator);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.UseJwtAuthentication(const AOptions: TJwtOptions): TDextAppBuilder;
begin
  TApplicationBuilderJwtExtensions.UseJwtAuthentication(Self.Unwrap, AOptions);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.UseJwtAuthentication(const ASecretKey: string; AConfigurator: TProc<TJwtOptionsBuilder>): TDextAppBuilder;
begin
  TApplicationBuilderJwtExtensions.UseJwtAuthentication(Self.Unwrap, ASecretKey, AConfigurator);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.UseStaticFiles(const AOptions: TStaticFileOptions): TDextAppBuilder;
begin
  TApplicationBuilderStaticFilesExtensions.UseStaticFiles(Self.Unwrap, AOptions);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.UseStaticFiles(const ARootPath: string): TDextAppBuilder;
begin
  TApplicationBuilderStaticFilesExtensions.UseStaticFiles(Self.Unwrap, ARootPath);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.UseMiddleware(AMiddleware: TClass): TDextAppBuilder;
begin
  Self.Unwrap.UseMiddleware(AMiddleware);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapGet(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
begin
  Self.Unwrap.MapGet(Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPost(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
begin
  Self.Unwrap.MapPost(Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPut(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
begin
  Self.Unwrap.MapPut(Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapDelete(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
begin
  Self.Unwrap.MapDelete(Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.Build: TRequestDelegate;
begin
  Result := Self.Unwrap.Build;
end;

end.
