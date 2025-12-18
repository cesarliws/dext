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
unit Dext.Web;

interface

uses
  System.SysUtils,
  Dext,
  Dext.Web.Extensions,
  Dext.Web.Formatters.Interfaces,
  // Added Units
  Dext.Auth.Attributes,
  Dext.Auth.Identity,
  Dext.Auth.JWT,
  Dext.Auth.Middleware,
  Dext.Caching,
  Dext.Caching.Redis,
  Dext.DI.Middleware,
  Dext.Filters,
  Dext.Filters.BuiltIn,
  Dext.HealthChecks,
  Dext.Hosting.CLI,
  Dext.OpenAPI.Attributes,
  Dext.OpenAPI.Extensions,
  Dext.OpenAPI.Generator,
  Dext.OpenAPI.Types,
  Dext.RateLimiting,
  Dext.RateLimiting.Core,
  Dext.RateLimiting.Limiters,
  Dext.RateLimiting.Policy,
  Dext.Swagger.Middleware,
  Dext.Web.Core,
  Dext.Web.Cors,
  Dext.Web.Formatters.Json,
  Dext.Web.Formatters.Selector,
  Dext.Web.Indy,
  Dext.Web.Indy.Server,
  Dext.Web.Injection,
  Dext.Web.Interfaces,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.Middleware.Extensions,
  Dext.Web.Middleware.Logging,
  Dext.Web.Middleware,
  Dext.Web.Pipeline,
  Dext.Web.Results,
  Dext.Web.Routing,
  Dext.Web.RoutingMiddleware,
  Dext.Web.StaticFiles,
  Dext.Web.Versioning,
  Dext.WebHost,
  Dext.Web.Controllers,
  Dext.Web.ControllerScanner,
  Dext.Web.HandlerInvoker,
  Dext.Web.ModelBinding.Extensions,
  Dext.Web.ModelBinding,
  Dext.Web.Routing.Attributes,
  Dext.Web.WebApplication,
  Dext.DI.Interfaces; // Added this unit

type
  // ===========================================================================
  // ??? Aliases for Common Web Types
  // ===========================================================================
  
  // Core Web Application
  IWebApplication = Dext.Web.Interfaces.IWebApplication;
  TDextApplication = Dext.Web.WebApplication.TDextApplication;
  IStartup = Dext.Web.Interfaces.IStartup;
  TDextServices = Dext.DI.Interfaces.TDextServices;

  IApplicationBuilder = Dext.Web.Interfaces.IApplicationBuilder;
  TDextAppBuilder = Dext.Web.Interfaces.TDextAppBuilder;
  TApplicationBuilderJwtExtensions = Dext.Auth.Middleware.TApplicationBuilderJwtExtensions;

  // HTTP Context & Pipeline
  IHttpContext = Dext.Web.Interfaces.IHttpContext;
  IHttpRequest = Dext.Web.Interfaces.IHttpRequest;
  IHttpResponse = Dext.Web.Interfaces.IHttpResponse;
  IMiddleware = Dext.Web.Interfaces.IMiddleware;
  TRequestDelegate = Dext.Web.Interfaces.TRequestDelegate;
  TStaticHandler = Dext.Web.Interfaces.TStaticHandler;

  // Results
  IResult = Dext.Web.Interfaces.IResult;

  Results = Dext.Web.Results.Results;
  IOutputFormatter = Dext.Web.Formatters.Interfaces.IOutputFormatter;
  IOutputFormatterContext = Dext.Web.Formatters.Interfaces.IOutputFormatterContext;
  IOutputFormatterSelector = Dext.Web.Formatters.Interfaces.IOutputFormatterSelector;
  IOutputFormatterRegistry = Dext.Web.Formatters.Interfaces.IOutputFormatterRegistry;

  // Controllers
  TController = Dext.Web.Controllers.TController;
  IBindingSourceProvider = Dext.Web.ModelBinding.IBindingSourceProvider;
  
  // Routing
  IRouteMatcher = Dext.Web.Routing.IRouteMatcher;
  TRouteMatcher = Dext.Web.Routing.TRouteMatcher;

  // Middleware Classes & Options
  THealthCheckMiddleware = Dext.HealthChecks.THealthCheckMiddleware;
  TExceptionHandlerMiddleware = Dext.Web.Middleware.TExceptionHandlerMiddleware;
  TExceptionHandlerOptions = Dext.Web.Middleware.TExceptionHandlerOptions;
  THttpLoggingMiddleware = Dext.Web.Middleware.THttpLoggingMiddleware;
  THttpLoggingOptions = Dext.Web.Middleware.THttpLoggingOptions;

  // Exceptions
  EHttpException = Dext.Web.Middleware.EHttpException;
  ENotFoundException = Dext.Web.Middleware.ENotFoundException;
  EUnauthorizedException = Dext.Web.Middleware.EUnauthorizedException;
  EForbiddenException = Dext.Web.Middleware.EForbiddenException;
  EValidationException = Dext.Web.Middleware.EValidationException;
  
  // CORS
  TCorsOptions = Dext.Web.Cors.TCorsOptions;
  TCorsBuilder = Dext.Web.Cors.TCorsBuilder;
  
  // Auth Options & Handlers
  TJwtOptions = Dext.Auth.JWT.TJwtOptions;
  TJwtOptionsBuilder = Dext.Auth.JWT.TJwtOptionsBuilder;
  TJwtAuthenticationMiddleware = Dext.Auth.Middleware.TJwtAuthenticationMiddleware;
  
  // Static Files
  TStaticFileOptions = Dext.Web.StaticFiles.TStaticFileOptions;

  // Routing Attributes
  DextControllerAttribute = Dext.Web.Routing.Attributes.DextControllerAttribute;
  DextGetAttribute = Dext.Web.Routing.Attributes.DextGetAttribute;
  DextPostAttribute = Dext.Web.Routing.Attributes.DextPostAttribute;
  DextPutAttribute = Dext.Web.Routing.Attributes.DextPutAttribute;
  DextDeleteAttribute = Dext.Web.Routing.Attributes.DextDeleteAttribute;
  
  // Model Binding Attributes
  FromQueryAttribute = Dext.Web.ModelBinding.FromQueryAttribute;
  FromRouteAttribute = Dext.Web.ModelBinding.FromRouteAttribute;
  FromBodyAttribute = Dext.Web.ModelBinding.FromBodyAttribute;
  FromServicesAttribute = Dext.Web.ModelBinding.FromServicesAttribute;

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

  // Web Extensions
  TWebDIHelpers = Dext.Web.Extensions.TWebDIHelpers;
  TWebRouteHelpers = Dext.Web.Extensions.TWebRouteHelpers;
  
  // CLI
  IConsoleCommand = Dext.Hosting.CLI.IConsoleCommand;
  TDextCLI = Dext.Hosting.CLI.TDextCLI;
  TMigrateUpCommand = Dext.Hosting.CLI.TMigrateUpCommand;
  TMigrateListCommand = Dext.Hosting.CLI.TMigrateListCommand;

  // Rate Limiting
  IRateLimiter = Dext.RateLimiting.Core.IRateLimiter;
  TRateLimitConfig = Dext.RateLimiting.Core.TRateLimitConfig;
  TFixedWindowLimiter = Dext.RateLimiting.Limiters.TFixedWindowLimiter;
  TSlidingWindowLimiter = Dext.RateLimiting.Limiters.TSlidingWindowLimiter;
  TTokenBucketLimiter = Dext.RateLimiting.Limiters.TTokenBucketLimiter;
  TConcurrencyLimiter = Dext.RateLimiting.Limiters.TConcurrencyLimiter;
  TRateLimitMiddleware = Dext.RateLimiting.TRateLimitMiddleware;
  TApplicationBuilderRateLimitExtensions = Dext.RateLimiting.TApplicationBuilderRateLimitExtensions;
  TRateLimitPolicy = Dext.RateLimiting.Policy.TRateLimitPolicy;

  // Caching
  ICacheStore = Dext.Caching.ICacheStore;
  TMemoryCacheStore = Dext.Caching.TMemoryCacheStore;
  TRedisCacheStore = Dext.Caching.Redis.TRedisCacheStore;
  TResponseCacheMiddleware = Dext.Caching.TResponseCacheMiddleware;
  TResponseCacheBuilder = Dext.Caching.TResponseCacheBuilder;
  TApplicationBuilderCacheExtensions = Dext.Caching.TApplicationBuilderCacheExtensions;

  // Swagger & OpenAPI
  TSwaggerMiddleware = Dext.Swagger.Middleware.TSwaggerMiddleware;
  TSwaggerExtensions = Dext.Swagger.Middleware.TSwaggerExtensions;
  TOpenAPIGenerator = Dext.OpenAPI.Generator.TOpenAPIGenerator;
  TOpenAPIDocument = Dext.OpenAPI.Types.TOpenAPIDocument;
  TOpenAPIInfo = Dext.OpenAPI.Types.TOpenAPIInfo;
  
  // OpenAPI Attributes
  SwaggerIgnoreAttribute = Dext.OpenAPI.Attributes.SwaggerIgnoreAttribute;
  SwaggerOperationAttribute = Dext.OpenAPI.Attributes.SwaggerOperationAttribute;
  SwaggerResponseAttribute = Dext.OpenAPI.Attributes.SwaggerResponseAttribute;
  SwaggerSchemaAttribute = Dext.OpenAPI.Attributes.SwaggerSchemaAttribute;
  
  // Web Core & Middleware
  TApplicationBuilder = Dext.Web.Core.TApplicationBuilder;
  TMiddleware = Dext.Web.Core.TMiddleware;
  TAnonymousMiddleware = Dext.Web.Core.TAnonymousMiddleware;
  TServiceScopeMiddleware = Dext.DI.Middleware.TServiceScopeMiddleware;
  TApplicationBuilderScopeExtensions = Dext.DI.Middleware.TApplicationBuilderScopeExtensions;
  TRequestLoggingMiddleware = Dext.Web.Middleware.Logging.TRequestLoggingMiddleware;
  TRoutingMiddleware = Dext.Web.RoutingMiddleware.TRoutingMiddleware;
  TStaticFileMiddleware = Dext.Web.StaticFiles.TStaticFileMiddleware;
  TApplicationBuilderStaticFilesExtensions = Dext.Web.StaticFiles.TApplicationBuilderStaticFilesExtensions;
  TApplicationBuilderExtensions = Dext.Web.ApplicationBuilder.Extensions.TApplicationBuilderExtensions; 
  TApplicationBuilderMiddlewareExtensions = Dext.Web.Middleware.Extensions.TApplicationBuilderMiddlewareExtensions;
  TApplicationBuilderCorsExtensions = Dext.Web.Cors.TApplicationBuilderCorsExtensions;
  
  // Pipeline
  IDextPipeline = Dext.Web.Pipeline.IDextPipeline;
  TDextPipeline = Dext.Web.Pipeline.TDextPipeline;
  
  // Results
  TResult = Dext.Web.Results.TResult;
  TJsonResult = Dext.Web.Results.TJsonResult;
  TStatusCodeResult = Dext.Web.Results.TStatusCodeResult;
  TContentResult = Dext.Web.Results.TContentResult;

  // Routing
  TRoutePattern = Dext.Web.Routing.TRoutePattern;
  TRouteDefinition = Dext.Web.Routing.TRouteDefinition;
  ERouteException = Dext.Web.Routing.ERouteException;

  // Versioning
  IApiVersionReader = Dext.Web.Versioning.IApiVersionReader;
  TQueryStringApiVersionReader = Dext.Web.Versioning.TQueryStringApiVersionReader;
  THeaderApiVersionReader = Dext.Web.Versioning.THeaderApiVersionReader;
  TCompositeApiVersionReader = Dext.Web.Versioning.TCompositeApiVersionReader;

  // Hosting
  IWebHostBuilder = Dext.Web.Interfaces.IWebHostBuilder;
  IWebHost = Dext.Web.Interfaces.IWebHost;
  TWebHostBuilder = Dext.WebHost.TWebHostBuilder;
  TDextWebHost = Dext.Web.Interfaces.TDextWebHost;

  // Indy
  TIndyWebServer = Dext.Web.Indy.Server.TIndyWebServer;
  TIndyHttpContext = Dext.Web.Indy.TIndyHttpContext;
  TIndyHttpRequest = Dext.Web.Indy.TIndyHttpRequest;
  TIndyHttpResponse = Dext.Web.Indy.TIndyHttpResponse;
  
  // MVC Internals
  IHttpHandler = Dext.Web.Controllers.IHttpHandler;
  IControllerScanner = Dext.Web.ControllerScanner.IControllerScanner;
  TControllerScanner = Dext.Web.ControllerScanner.TControllerScanner;
  THandlerInvoker = Dext.Web.HandlerInvoker.THandlerInvoker;
  THandlerInjector = Dext.Web.Injection.THandlerInjector;
  
  // Model Binding
  IModelBinder = Dext.Web.ModelBinding.IModelBinder;
  TModelBinder = Dext.Web.ModelBinding.TModelBinder;
  TModelBinderHelper = Dext.Web.ModelBinding.TModelBinderHelper;
  TBindingSourceProvider = Dext.Web.ModelBinding.TBindingSourceProvider;
  EBindingException = Dext.Web.ModelBinding.EBindingException;
  
  // Model Binding Extensions
  IApplicationBuilderWithModelBinding = Dext.Web.ModelBinding.Extensions.IApplicationBuilderWithModelBinding;
  TApplicationBuilderWithModelBinding = Dext.Web.ModelBinding.Extensions.TApplicationBuilderWithModelBinding;
  TApplicationBuilderModelBindingExtensions = Dext.Web.ModelBinding.Extensions.TApplicationBuilderModelBindingExtensions;

  // Formatters
  TJsonOutputFormatter = Dext.Web.Formatters.Json.TJsonOutputFormatter;
  TDefaultOutputFormatterSelector = Dext.Web.Formatters.Selector.TDefaultOutputFormatterSelector;
  TOutputFormatterRegistry = Dext.Web.Extensions.TOutputFormatterRegistry;

const
  // TBindingSource Constants
  bsBody = Dext.Web.ModelBinding.TBindingSource.bsBody;
  bsQuery = Dext.Web.ModelBinding.TBindingSource.bsQuery;
  bsRoute = Dext.Web.ModelBinding.TBindingSource.bsRoute;
  bsHeader = Dext.Web.ModelBinding.TBindingSource.bsHeader;
  bsServices = Dext.Web.ModelBinding.TBindingSource.bsServices;
  bsForm = Dext.Web.ModelBinding.TBindingSource.bsForm;

  // ===========================================================================
  // ??? Fluent Helpers & Wrappers
  // ===========================================================================

type
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
    // ?? Factory Methods
    
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
    
    // ?? Extensions
    
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
    
    // ?? Core Forwarding
    
    /// <summary>
    ///   Adds a middleware class to the pipeline. The middleware must have a constructor accepting RequestDelegate (and optionally other services).
    /// </summary>
    function UseMiddleware(AMiddleware: TClass): TDextAppBuilder;
    
    /// <summary>
    ///   Maps a GET request to a static handler.
    /// </summary>
    function MapGet(const Path: string; Handler: TStaticHandler): TDextAppBuilder; overload;

    /// <summary>
    ///   Maps a POST request to a static handler.
    /// </summary>
    function MapPost(const Path: string; Handler: TStaticHandler): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Maps a PUT request to a static handler.
    /// </summary>
    function MapPut(const Path: string; Handler: TStaticHandler): TDextAppBuilder; overload;

    /// <summary>
    ///   Maps a DELETE request to a static handler.
    /// </summary>
    function MapDelete(const Path: string; Handler: TStaticHandler): TDextAppBuilder; overload;

    /// <summary>
    ///   Builds the request pipeline and returns the main RequestDelegate.
    /// </summary>
    /// <summary>
    ///   Builds the request pipeline and returns the main RequestDelegate.
    /// </summary>
    function Build: TRequestDelegate;

    // -------------------------------------------------------------------------
    // ?? Middleware
    // -------------------------------------------------------------------------
    function UseStaticFiles: TDextAppBuilder; overload;

    // -------------------------------------------------------------------------
    // ??? Routing - POST
    // -------------------------------------------------------------------------
    
    /// <summary>
    ///   Maps a POST request to a handler with 1 injected parameter.
    /// </summary>
    function MapPost<T>(const Path: string; Handler: THandlerProc<T>): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Maps a POST request to a handler with 2 injected parameters.
    /// </summary>
    function MapPost<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Maps a POST request to a handler with 3 injected parameters.
    /// </summary>
    function MapPost<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TDextAppBuilder; overload;

    /// <summary>
    ///   Maps a POST request to a handler that returns a result.
    /// </summary>
    function MapPost<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TDextAppBuilder; overload;
    function MapPost<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TDextAppBuilder; overload;
    function MapPost<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TDextAppBuilder; overload;
    function MapPost<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TDextAppBuilder; overload;

    // -------------------------------------------------------------------------
    // ??? Routing - GET
    // -------------------------------------------------------------------------
    
    /// <summary>
    ///   Maps a GET request to a handler with 1 injected parameter.
    /// </summary>
    function MapGet<T>(const Path: string; Handler: THandlerProc<T>): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Maps a GET request to a handler with 2 injected parameters.
    /// </summary>
    function MapGet<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Maps a GET request to a handler with 3 injected parameters.
    /// </summary>
    function MapGet<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TDextAppBuilder; overload;

    /// <summary>
    ///   Maps a GET request to a handler that returns a result.
    /// </summary>
    function MapGet<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Maps a GET request to a handler with 1 parameter that returns a result.
    /// </summary>
    function MapGet<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Maps a GET request to a handler with 2 parameters that returns a result.
    /// </summary>
    function MapGet<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TDextAppBuilder; overload;
    
    /// <summary>
    ///   Maps a GET request to a handler with 3 parameters that returns a result.
    /// </summary>
    function MapGet<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TDextAppBuilder; overload;

    // -------------------------------------------------------------------------
    // ??? Routing - PUT
    // -------------------------------------------------------------------------
    function MapPut<T>(const Path: string; Handler: THandlerProc<T>): TDextAppBuilder; overload;
    function MapPut<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TDextAppBuilder; overload;
    function MapPut<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TDextAppBuilder; overload;

    function MapPut<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TDextAppBuilder; overload;
    function MapPut<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TDextAppBuilder; overload;
    function MapPut<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TDextAppBuilder; overload;

    // -------------------------------------------------------------------------
    // ??? Routing - DELETE
    // -------------------------------------------------------------------------
    function MapDelete<T>(const Path: string; Handler: THandlerProc<T>): TDextAppBuilder; overload;
    function MapDelete<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TDextAppBuilder; overload;
    function MapDelete<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TDextAppBuilder; overload;

    function MapDelete<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TDextAppBuilder; overload;
    function MapDelete<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TDextAppBuilder; overload;
    function MapDelete<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TDextAppBuilder; overload;
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

{ TDextHttpAppBuilderHelper }

function TDextHttpAppBuilderHelper.UseStaticFiles: TDextAppBuilder;
begin
  TApplicationBuilderStaticFilesExtensions.UseStaticFiles(Self.Unwrap);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPost<T>(const Path: string; Handler: THandlerProc<T>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<T>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPost<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<T1, T2>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPost<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<T1, T2, T3>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPost<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPost<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPost<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPost<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapGet<T>(const Path: string; Handler: THandlerProc<T>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<T>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapGet<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<T1, T2>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapGet<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<T1, T2, T3>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapGet<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapGet<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapGet<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapGet<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPut<T>(const Path: string; Handler: THandlerProc<T>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPut<T>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPut<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPut<T1, T2>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPut<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPut<T1, T2, T3>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPut<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPut<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPut<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPut<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapPut<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapPut<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapDelete<T>(const Path: string; Handler: THandlerProc<T>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapDelete<T>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapDelete<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapDelete<T1, T2>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapDelete<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapDelete<T1, T2, T3>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapDelete<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapDelete<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapDelete<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapDelete<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function TDextHttpAppBuilderHelper.MapDelete<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TDextAppBuilder;
begin
  TApplicationBuilderExtensions.MapDelete<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

end.

