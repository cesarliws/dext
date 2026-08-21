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

{$I Dext.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  Dext,
  Dext.DI.Interfaces,
  Dext.Collections.Pool,
  {$IFDEF DEXT_ENABLE_ENTITY}
  Dext.Entity,
  {$ENDIF}
  // {BEGIN_DEXT_USES}
  // Generated Uses
  Dext.Auth.Attributes,
  Dext.Auth.BasicAuth,
  Dext.Auth.Identity,
  Dext.Auth.JWT,
  Dext.Auth.Middleware,
  Dext.DI.Middleware,
  Dext.Filters.BuiltIn,
  Dext.Filters,
  Dext.HealthChecks,
  Dext.OpenAPI.Attributes,
  Dext.OpenAPI.Extensions,
  Dext.OpenAPI.Fluent,
  Dext.OpenAPI.Generator,
  Dext.OpenAPI.Types,
  Dext.RateLimiting.Core,
  Dext.RateLimiting.Limiters,
  Dext.RateLimiting,
  Dext.RateLimiting.Policy,
  Dext.Swagger.Middleware,
  Dext.Web.Builder,
  Dext.Web.Cors,
  {$IFDEF DEXT_ENABLE_ENTITY}
  Dext.Web.DataApi,
  {$ENDIF}
  Dext.Web.Extensions,
  Dext.Web.ForwardedHeaders,
  Dext.Web.Formatters.Interfaces,
  Dext.Web.Formatters.Json,
  Dext.Web.Formatters.Selector,
  Dext.Web.Indy,
  Dext.Web.Indy.Server,
  Dext.Web.Indy.Types,
  Dext.Web.Injection,
  Dext.Web.Interfaces,
  Dext.Web.Middleware.Extensions,
  Dext.Web.Middleware.Logging,
  Dext.Web.Middleware,
  Dext.Web.MultiTenancy,
  Dext.Web.Pipeline,
  Dext.Web.PathBase,
  Dext.Web.Results,
  Dext.Web.SecurityHeaders,
  Dext.Web.View,
  Dext.Web.View.Native,
  {$IFDEF DEXT_ENABLE_WEB_STENCILS}
  Dext.Web.View.WebStencils,
  {$ENDIF}
  Dext.Web.Routing,
  Dext.Web.Sessions.Streamable,
  Dext.Web.RoutingMiddleware,
  Dext.Web.StaticFiles,
  Dext.Http.StatusCodes,
  Dext.Web.Versioning,
  Dext.WebHost,
  Dext.Caching,
  Dext.Caching.Redis,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.WebApplication,
  Dext.Web.Indy.SSL.Interfaces,
  Dext.Web.Indy.SSL.OpenSSL,
  Dext.Web.Indy.SSL.Taurus,
  Dext.Web.Middleware.Compression,
  Dext.Web.Middleware.StartupLock,
  Dext.Web.Controllers,
  Dext.Web.ControllerScanner,
  Dext.Web.HandlerInvoker,
//{$WARN UNIT_DEPRECATED OFF}
//  Dext.Web.ModelBinding.Extensions,
//{$WARN UNIT_DEPRECATED ON}
  Dext.Web.ModelBinding,
  Dext.Web.Routing.Attributes,
  Dext.Hosting.ApplicationLifetime
  // {END_DEXT_USES}
  ;

type
  // ===========================================================================
  // 🌐 Aliases for Common Web Types
  // ===========================================================================
  
  // Dext.Web.PathBase
  /// <summary> Middleware that strips base path from requests. </summary>
  TDextPathBaseMiddleware = Dext.Web.PathBase.TDextPathBaseMiddleware;
  /// <summary> Type alias for TDextPathBaseMiddleware. </summary>
  TPathBaseMiddleware = Dext.Web.PathBase.TPathBaseMiddleware;

  // Dext.Auth.Attributes
  /// <summary> Attribute to require authentication or a specific policy. </summary>
  AuthorizeAttribute = Dext.Auth.Attributes.AuthorizeAttribute;
  /// <summary> Attribute to skip authentication for a controller or method. </summary>
  AllowAnonymousAttribute = Dext.Auth.Attributes.AllowAnonymousAttribute;

  // Dext.Auth.BasicAuth
  /// <summary> Options for configuring Basic Authentication. </summary>
  TBasicAuthOptions = Dext.Auth.BasicAuth.TBasicAuthOptions;
  TBasicAuthValidateFunc = Dext.Auth.BasicAuth.TBasicAuthValidateFunc;
  TBasicAuthValidateWithRolesFunc = Dext.Auth.BasicAuth.TBasicAuthValidateWithRolesFunc;
  TBasicAuthMiddleware = Dext.Auth.BasicAuth.TBasicAuthMiddleware;
  TApplicationBuilderBasicAuthExtensions = Dext.Auth.BasicAuth.TApplicationBuilderBasicAuthExtensions;

  // Dext.Auth.Identity
  /// <summary> Base interface for user identities. </summary>
  IIdentity = Dext.Auth.Identity.IIdentity;
  /// <summary> Principal containing user claims and identities. </summary>
  IClaimsPrincipal = Dext.Auth.Identity.IClaimsPrincipal;
  TClaimsIdentity = Dext.Auth.Identity.TClaimsIdentity;
  TClaimsPrincipal = Dext.Auth.Identity.TClaimsPrincipal;
  TClaimTypes = Dext.Auth.Identity.TClaimTypes;
  HttpStatus = Dext.Http.StatusCodes.HttpStatus;
  IClaimsBuilder = Dext.Auth.Identity.IClaimsBuilder;
  TClaimsBuilder = Dext.Auth.Identity.TClaimsBuilder;

  // Dext.Auth.JWT
  /// <summary> Represents an individual claim for a JWT token. </summary>
  TClaim = Dext.Auth.JWT.TClaim;
  TJwtValidationResult = Dext.Auth.JWT.TJwtValidationResult;
  IJwtTokenHandler = Dext.Auth.JWT.IJwtTokenHandler;
  /// <summary> Options for JWT token validation and generation. </summary>
  TJwtOptions = Dext.Auth.JWT.TJwtOptions;
  TJwtOptionsBuilder = Dext.Auth.JWT.TJwtOptionsBuilder;
  TJwtOptionsHelper = Dext.Auth.JWT.TJwtOptionsHelper;
  TJwtTokenHandler = Dext.Auth.JWT.TJwtTokenHandler;
  TJwtBuilderProc = Dext.Auth.JWT.TJwtBuilderProc;

  // Dext.Auth.Middleware
  TJwtAuthenticationMiddleware = Dext.Auth.Middleware.TJwtAuthenticationMiddleware;
  TApplicationBuilderJwtExtensions = Dext.Auth.Middleware.TApplicationBuilderJwtExtensions;

  // Dext.Caching
  /// <summary> Interface for cache providers (Memory, Redis, etc.). </summary>
  ICacheStore = Dext.Caching.ICacheStore;
  TCacheEntry = Dext.Caching.TCacheEntry;
  TMemoryCacheStore = Dext.Caching.TMemoryCacheStore;
  /// <summary> Options for HTTP response caching middleware. </summary>
  TResponseCacheOptions = Dext.Caching.TResponseCacheOptions;
  TResponseCaptureWrapper = Dext.Caching.TResponseCaptureWrapper;
  TResponseCacheMiddleware = Dext.Caching.TResponseCacheMiddleware;
  TResponseCacheBuilder = Dext.Caching.TResponseCacheBuilder;
  TApplicationBuilderCacheExtensions = Dext.Caching.TApplicationBuilderCacheExtensions;
  TResponseCacheOptionsHelper = Dext.Caching.TResponseCacheOptionsHelper;
  TResponseCacheBuilderProc = Dext.Caching.TResponseCacheBuilderProc;

  // Dext.Caching.Redis
  /// <summary> Distributed cache implementation using Redis. </summary>
  TRedisCacheStore = Dext.Caching.Redis.TRedisCacheStore;

  // Dext.DI.Middleware
  TServiceScopeMiddleware = Dext.DI.Middleware.TServiceScopeMiddleware;
  TApplicationBuilderScopeExtensions = Dext.DI.Middleware.TApplicationBuilderScopeExtensions;

  // Dext.Filters
  TActionDescriptor = Dext.Filters.TActionDescriptor;
  IActionExecutingContext = Dext.Filters.IActionExecutingContext;
  IActionExecutedContext = Dext.Filters.IActionExecutedContext;
  /// <summary> Base interface for Action Filters. </summary>
  IActionFilter = Dext.Filters.IActionFilter;
  ActionFilterAttribute = Dext.Filters.ActionFilterAttribute;
  TActionExecutingContext = Dext.Filters.TActionExecutingContext;
  TActionExecutedContext = Dext.Filters.TActionExecutedContext;

  // Dext.Filters.BuiltIn
  LogActionAttribute = Dext.Filters.BuiltIn.LogActionAttribute;
  RequireHeaderAttribute = Dext.Filters.BuiltIn.RequireHeaderAttribute;
  ResponseCacheAttribute = Dext.Filters.BuiltIn.ResponseCacheAttribute;
  /// <summary> Attribute that automatically validates the model before executing the action. </summary>
  ValidateModelAttribute = Dext.Filters.BuiltIn.ValidateModelAttribute;
  AddHeaderAttribute = Dext.Filters.BuiltIn.AddHeaderAttribute;

  // Dext.HealthChecks
  THealthStatus = Dext.HealthChecks.THealthStatus;
  THealthCheckResult = Dext.HealthChecks.THealthCheckResult;
  IHealthCheck = Dext.HealthChecks.IHealthCheck;
  IHealthCheckService = Dext.HealthChecks.IHealthCheckService;
  THealthCheckService = Dext.HealthChecks.THealthCheckService;
  THealthCheckMiddleware = Dext.HealthChecks.THealthCheckMiddleware;
  THealthCheckBuilder = Dext.HealthChecks.THealthCheckBuilder;

  // Dext.OpenAPI.Attributes
  /// <summary> Attribute to hide a controller or method from Swagger/OpenAPI. </summary>
  SwaggerIgnoreAttribute = Dext.OpenAPI.Attributes.SwaggerIgnoreAttribute;
  /// <summary> Attribute to define operation details (ID, Summary, Description). </summary>
  SwaggerOperationAttribute = Dext.OpenAPI.Attributes.SwaggerOperationAttribute;
  /// <summary> Attribute to document potential API responses. </summary>
  SwaggerResponseAttribute = Dext.OpenAPI.Attributes.SwaggerResponseAttribute;
  SwaggerSchemaAttribute = Dext.OpenAPI.Attributes.SwaggerSchemaAttribute;
  SwaggerIgnorePropertyAttribute = Dext.OpenAPI.Attributes.SwaggerIgnorePropertyAttribute;
  SwaggerPropertyAttribute = Dext.OpenAPI.Attributes.SwaggerPropertyAttribute;
  SwaggerRequiredAttribute = Dext.OpenAPI.Attributes.SwaggerRequiredAttribute;
  SwaggerExampleAttribute = Dext.OpenAPI.Attributes.SwaggerExampleAttribute;
  SwaggerFormatAttribute = Dext.OpenAPI.Attributes.SwaggerFormatAttribute;
  SwaggerTagAttribute = Dext.OpenAPI.Attributes.SwaggerTagAttribute;
  TSwaggerParamLocation = Dext.OpenAPI.Attributes.TSwaggerParamLocation;
  SwaggerParamAttribute = Dext.OpenAPI.Attributes.SwaggerParamAttribute;
  SwaggerAuthorizeAttribute = Dext.OpenAPI.Attributes.SwaggerAuthorizeAttribute;

  // Dext.OpenAPI.Extensions
  TEndpointMetadataExtensions = Dext.OpenAPI.Extensions.TEndpointMetadataExtensions;

  // Dext.OpenAPI.Fluent
  TEndpointBuilder = Dext.OpenAPI.Fluent.TEndpointBuilder;
  SwaggerEndpoint = Dext.OpenAPI.Fluent.SwaggerEndpoint;

  // Dext.OpenAPI.Generator
  TOpenAPIOptions = Dext.OpenAPI.Generator.TOpenAPIOptions;
  TOpenAPIGenerator = Dext.OpenAPI.Generator.TOpenAPIGenerator;

  // Dext.OpenAPI.Types
  TOpenAPIDataType = Dext.OpenAPI.Types.TOpenAPIDataType;
  TOpenAPISchema = Dext.OpenAPI.Types.TOpenAPISchema;
  TOpenAPIParameterLocation = Dext.OpenAPI.Types.TOpenAPIParameterLocation;
  TOpenAPIParameter = Dext.OpenAPI.Types.TOpenAPIParameter;
  TOpenAPIRequestBody = Dext.OpenAPI.Types.TOpenAPIRequestBody;
  TOpenAPIResponse = Dext.OpenAPI.Types.TOpenAPIResponse;
  TOpenAPIOperation = Dext.OpenAPI.Types.TOpenAPIOperation;
  TOpenAPIPathItem = Dext.OpenAPI.Types.TOpenAPIPathItem;
  TOpenAPIServer = Dext.OpenAPI.Types.TOpenAPIServer;
  TOpenAPIContact = Dext.OpenAPI.Types.TOpenAPIContact;
  TOpenAPILicense = Dext.OpenAPI.Types.TOpenAPILicense;
  TOpenAPIInfo = Dext.OpenAPI.Types.TOpenAPIInfo;
  TSecuritySchemeType = Dext.OpenAPI.Types.TSecuritySchemeType;
  TApiKeyLocation = Dext.OpenAPI.Types.TApiKeyLocation;
  TOpenAPISecurityScheme = Dext.OpenAPI.Types.TOpenAPISecurityScheme;
  TOpenAPIDocument = Dext.OpenAPI.Types.TOpenAPIDocument;

  // Dext.RateLimiting
  TRateLimitMiddleware = Dext.RateLimiting.TRateLimitMiddleware;
  TApplicationBuilderRateLimitExtensions = Dext.RateLimiting.TApplicationBuilderRateLimitExtensions;

  // Dext.RateLimiting.Core
  TPartitionKeyResolver = Dext.RateLimiting.Core.TPartitionKeyResolver;
  TRateLimiterType = Dext.RateLimiting.Core.TRateLimiterType;
  TPartitionStrategy = Dext.RateLimiting.Core.TPartitionStrategy;
  TRateLimitResult = Dext.RateLimiting.Core.TRateLimitResult;
  /// <summary> Interface for rate limiter implementations (FixedWindow, TokenBucket, etc.). </summary>
  IRateLimiter = Dext.RateLimiting.Core.IRateLimiter;
  /// <summary> Base configuration for Rate Limiting policies (limit rules). </summary>
  TRateLimitConfig = Dext.RateLimiting.Core.TRateLimitConfig;

  // Dext.RateLimiting.Limiters
  TFixedWindowLimiter = Dext.RateLimiting.Limiters.TFixedWindowLimiter;
  TSlidingWindowLimiter = Dext.RateLimiting.Limiters.TSlidingWindowLimiter;
  TTokenBucketLimiter = Dext.RateLimiting.Limiters.TTokenBucketLimiter;
  TConcurrencyLimiter = Dext.RateLimiting.Limiters.TConcurrencyLimiter;

  // Dext.RateLimiting.Policy
  TRateLimitPolicy = Dext.RateLimiting.Policy.TRateLimitPolicy;
  RateLimitPolicy = Dext.RateLimiting.Policy.TRateLimitPolicy;

  // Dext.Swagger.Middleware
  TSwaggerMiddleware = Dext.Swagger.Middleware.TSwaggerMiddleware;
  TSwaggerExtensions = Dext.Swagger.Middleware.TSwaggerExtensions;

  // Dext.Web.ApplicationBuilder.Extensions
  TApplicationBuilderExtensions = Dext.Web.ApplicationBuilder.Extensions.TApplicationBuilderExtensions;
  TAppBuilderHelper = Dext.Web.ApplicationBuilder.Extensions.TDextAppBuilderHelper;
  TDextAppBuilderHelper = TAppBuilderHelper; // deprecated

  // Dext.Web.Controllers
  IHttpHandler = Dext.Web.Controllers.IHttpHandler;
  TControllerClass = Dext.Web.Controllers.TControllerClass;
  TController = Dext.Web.Controllers.TController;

  // Dext.Web.ControllerScanner
  TControllerMethod = Dext.Web.ControllerScanner.TControllerMethod;
  TControllerInfo = Dext.Web.ControllerScanner.TControllerInfo;
  TCachedMethod = Dext.Web.ControllerScanner.TCachedMethod;
  IControllerScanner = Dext.Web.ControllerScanner.IControllerScanner;
  TControllerScanner = Dext.Web.ControllerScanner.TControllerScanner;

  // Dext.Web.Builder
  TMiddlewareRegistration = Dext.Web.Builder.TMiddlewareRegistration;
  TAnonymousMiddleware = Dext.Web.Builder.TAnonymousMiddleware;
  TApplicationBuilder = Dext.Web.Builder.TApplicationBuilder;
  TMiddleware = Dext.Web.Builder.TMiddleware;

  // Dext.Web.Cors
  /// <summary> Options for configuring Cross-Origin Resource Sharing (CORS). </summary>
  TCorsOptions = Dext.Web.Cors.TCorsOptions;
  TStringArrayHelper = Dext.Web.Cors.TStringArrayHelper;
  TCorsMiddleware = Dext.Web.Cors.TCorsMiddleware;
  TCorsBuilder = Dext.Web.Cors.TCorsBuilder;
  TApplicationBuilderCorsExtensions = Dext.Web.Cors.TApplicationBuilderCorsExtensions;
  TCorsOptionsHelper = Dext.Web.Cors.TCorsOptionsHelper;

  // Dext.Web.DataApi
  TApiMethod = Dext.Web.DataApi.TApiMethod;
  TApiMethods = Dext.Web.DataApi.TApiMethods;
  // TDataApiOptions<T> = Dext.Web.DataApi.TDataApiOptions<T>;
  // TDataApiHandler<T> = Dext.Web.DataApi.TDataApiHandler<T>;

  // Dext.Web.Extensions
  TWebDIHelpers = Dext.Web.Extensions.TWebDIHelpers;
  TWebRouteHelpers = Dext.Web.Extensions.TWebRouteHelpers;
  TServiceCollectionExtensions = Dext.Web.Extensions.TDextServiceCollectionExtensions;
  TDextServiceCollectionExtensions = TServiceCollectionExtensions; // deprecated
  TOutputFormatterRegistry = Dext.Web.Extensions.TOutputFormatterRegistry;

  // Dext.Web.Formatters.Interfaces
  IOutputFormatterContext = Dext.Web.Formatters.Interfaces.IOutputFormatterContext;
  IOutputFormatter = Dext.Web.Formatters.Interfaces.IOutputFormatter;
  IOutputFormatterSelector = Dext.Web.Formatters.Interfaces.IOutputFormatterSelector;
  IOutputFormatterRegistry = Dext.Web.Formatters.Interfaces.IOutputFormatterRegistry;

  // Dext.Web.Formatters.Json
  TJsonOutputFormatter = Dext.Web.Formatters.Json.TJsonOutputFormatter;

  // Dext.Web.Formatters.Selector
  TMediaTypeHeaderValue = Dext.Web.Formatters.Selector.TMediaTypeHeaderValue;
  TDefaultOutputFormatterSelector = Dext.Web.Formatters.Selector.TDefaultOutputFormatterSelector;

  // Dext.Web.HandlerInvoker
  THandlerInvoker = Dext.Web.HandlerInvoker.THandlerInvoker;
  // THandlerProc<T> = Dext.Web.HandlerInvoker.THandlerProc<T>;
  // THandlerProc<T> = Dext.Web.HandlerInvoker.THandlerProc<T>;
  // THandlerProc<T> = Dext.Web.HandlerInvoker.THandlerProc<T>;
  // THandlerResultFunc<T> = Dext.Web.HandlerInvoker.THandlerResultFunc<T>;
  // THandlerResultFunc<T> = Dext.Web.HandlerInvoker.THandlerResultFunc<T>;
  // THandlerResultFunc<T> = Dext.Web.HandlerInvoker.THandlerResultFunc<T>;
  // THandlerResultFunc<T> = Dext.Web.HandlerInvoker.THandlerResultFunc<T>;
  // THandlerFunc<T> = Dext.Web.HandlerInvoker.THandlerFunc<T>;
  // THandlerFunc<T> = Dext.Web.HandlerInvoker.THandlerFunc<T>;
  // THandlerFunc<T> = Dext.Web.HandlerInvoker.THandlerFunc<T>;
  // THandlerFunc<T> = Dext.Web.HandlerInvoker.THandlerFunc<T>;
  // THandlerProcWithContext<T> = Dext.Web.HandlerInvoker.THandlerProcWithContext<T>;
  // THandlerProcWithContext<T> = Dext.Web.HandlerInvoker.THandlerProcWithContext<T>;
  // THandlerFuncWithContext<T> = Dext.Web.HandlerInvoker.THandlerFuncWithContext<T>;

  // Dext.Web.Indy
  TDextIndyHttpResponse = Dext.Web.Indy.TDextIndyHttpResponse;
  TDextIndyHttpRequest = Dext.Web.Indy.TDextIndyHttpRequest;
  TDextIndyHttpContext = Dext.Web.Indy.TDextIndyHttpContext;

  // Dext.Web.Indy.Server
  TDextIndyWebServer = Dext.Web.Indy.Server.TDextIndyWebServer;

  // Dext.Web.Indy.SSL.Interfaces
  IIndySSLHandler = Dext.Web.Indy.SSL.Interfaces.IIndySSLHandler;

  // Dext.Web.Indy.SSL.OpenSSL
  TDextIndyOpenSSLHandler = Dext.Web.Indy.SSL.OpenSSL.TDextIndyOpenSSLHandler;

  // Dext.Web.Indy.SSL.Taurus
  TDextIndyTaurusSSLHandler = Dext.Web.Indy.SSL.Taurus.TDextIndyTaurusSSLHandler;

  // Dext.Web.Indy.Types
  TDextIndyFormFile = Dext.Web.Indy.Types.TDextIndyFormFile;

  // Dext.Web.Injection
  THandlerInjector = Dext.Web.Injection.THandlerInjector;

  // Dext.Web.Interfaces
  IHttpContext = Dext.Web.Interfaces.IHttpContext;
  IHttpRequest = Dext.Web.Interfaces.IHttpRequest;
  IHttpResponse = Dext.Web.Interfaces.IHttpResponse;
  IApplicationBuilder = Dext.Web.Interfaces.IApplicationBuilder;
  IWebHost = Dext.Web.Interfaces.IWebHost;
  IWebHostBuilder = Dext.Web.Interfaces.IWebHostBuilder;
  TRequestDelegate = Dext.Web.Interfaces.TRequestDelegate;
  TDextFastRouteHandler = Dext.Web.Interfaces.TDextFastRouteHandler;
  TStaticHandler = Dext.Web.Interfaces.TStaticHandler;
  TMiddlewareDelegate = Dext.Web.Interfaces.TMiddlewareDelegate;
  TOpenAPIResponseMetadata = Dext.Web.Interfaces.TOpenAPIResponseMetadata;
  TEndpointMetadata = Dext.Web.Interfaces.TEndpointMetadata;
  TCookieOptions = Dext.Web.Interfaces.TCookieOptions;
  IFormFile = Dext.Web.Interfaces.IFormFile;
  IFormFileCollection = Dext.Web.Interfaces.IFormFileCollection;
  IResult = Dext.Web.Interfaces.IResult;
  TAppBuilder = Dext.Web.Interfaces.TAppBuilder;
  AppBuilder = TAppBuilder;
  TDextAppBuilder = AppBuilder; // deprecated
  TWebHost = Dext.Web.Interfaces.TWebHost;
  WebHost = TWebHost;
  DextWebHost = WebHost; // deprecated
  // Dext.Web.View
  IViewEngine = Dext.Web.View.IViewEngine;
  IViewData = Dext.Web.View.IViewData;
  IViewResult = Dext.Web.View.IViewResult;
  TDextViewResult = Dext.Web.View.TDextViewResult;
  TViewOptions = Dext.Web.View.TViewOptions;

  IWebApplication = Dext.Web.Interfaces.IWebApplication;
  IStartup = Dext.Web.Interfaces.IStartup;
  TFormFileCollection = Dext.Web.Interfaces.TFormFileCollection;

  // Dext.Web.Middleware
  EHttpException = Dext.Web.Middleware.EHttpException;
  ENotFoundException = Dext.Web.Middleware.ENotFoundException;
  EUnauthorizedException = Dext.Web.Middleware.EUnauthorizedException;
  EForbiddenException = Dext.Web.Middleware.EForbiddenException;
  EValidationException = Dext.Web.Middleware.EValidationException;
  TExceptionHandlerOptions = Dext.Web.Middleware.TExceptionHandlerOptions;
  TExceptionHandlerBuilder = Dext.Web.Middleware.TExceptionHandlerBuilder;
  TProblemDetails = Dext.Web.Middleware.TProblemDetails;
  TExceptionHandlerMiddleware = Dext.Web.Middleware.TExceptionHandlerMiddleware;
  THttpLoggingOptions = Dext.Web.Middleware.THttpLoggingOptions;
  THttpLoggingBuilder = Dext.Web.Middleware.THttpLoggingBuilder;
  THttpLoggingMiddleware = Dext.Web.Middleware.THttpLoggingMiddleware;

  // Dext.Web.Middleware.Compression
  TCompressionOptions = Dext.Web.Middleware.Compression.TCompressionOptions;
  TCompressionBuilder = Dext.Web.Middleware.Compression.TCompressionBuilder;
  TCompressionMiddleware = Dext.Web.Middleware.Compression.TCompressionMiddleware;

  // Dext.Web.SecurityHeaders
  TSecurityHeadersOptions = Dext.Web.SecurityHeaders.TSecurityHeadersOptions;
  TSecurityHeadersBuilder = Dext.Web.SecurityHeaders.TSecurityHeadersBuilder;
  TSecurityHeadersMiddleware = Dext.Web.SecurityHeaders.TSecurityHeadersMiddleware;

  // Dext.Web.Middleware.Extensions
  TApplicationBuilderMiddlewareExtensions = Dext.Web.Middleware.Extensions.TApplicationBuilderMiddlewareExtensions;

  // Dext.Web.Middleware.Logging
  TRequestLoggingMiddleware = Dext.Web.Middleware.Logging.TRequestLoggingMiddleware;

  // Dext.Web.Middleware.StartupLock
  TStartupLockMiddleware = Dext.Web.Middleware.StartupLock.TStartupLockMiddleware;

  // Dext.Web.ModelBinding
  EBindingException = Dext.Web.ModelBinding.EBindingException;
  TBindingSource = Dext.Web.ModelBinding.TBindingSource;
  BindingAttribute = Dext.Web.ModelBinding.BindingAttribute;
  /// <summary> Defines that a parameter should be bound from the request body (JSON). </summary>
  FromBodyAttribute = Dext.Web.ModelBinding.FromBodyAttribute;
  /// <summary> Defines that a parameter should be bound from the query string. </summary>
  FromQueryAttribute = Dext.Web.ModelBinding.FromQueryAttribute;
  /// <summary> Defines that a parameter should be bound from the route (URL). </summary>
  FromRouteAttribute = Dext.Web.ModelBinding.FromRouteAttribute;
  FromHeaderAttribute = Dext.Web.ModelBinding.FromHeaderAttribute;
  FromServicesAttribute = Dext.Web.ModelBinding.FromServicesAttribute;
  IModelBinder = Dext.Web.ModelBinding.IModelBinder;
  TModelBinder = Dext.Web.ModelBinding.TModelBinder;
  TModelBinderHelper = Dext.Web.ModelBinding.TModelBinderHelper;
  IBindingSourceProvider = Dext.Web.ModelBinding.IBindingSourceProvider;
  TBindingSourceProvider = Dext.Web.ModelBinding.TBindingSourceProvider;

  // Dext.Web.ModelBinding.Extensions
//  IApplicationBuilderWithModelBinding = Dext.Web.ModelBinding.Extensions.IApplicationBuilderWithModelBinding;
//  TApplicationBuilderWithModelBinding = Dext.Web.ModelBinding.Extensions.TApplicationBuilderWithModelBinding;
//  TApplicationBuilderModelBindingExtensions = Dext.Web.ModelBinding.Extensions.TApplicationBuilderModelBindingExtensions;

  // Dext.Web.MultiTenancy
  ITenantResolutionStrategy = Dext.Web.MultiTenancy.ITenantResolutionStrategy;
  ITenantStore = Dext.Web.MultiTenancy.ITenantStore;
  TMultiTenancyMiddleware = Dext.Web.MultiTenancy.TMultiTenancyMiddleware;

  // Dext.Web.Pipeline
  IDextPipeline = Dext.Web.Pipeline.IDextPipeline;
  TDextPipeline = Dext.Web.Pipeline.TDextPipeline;

  // Dext.Web.Results
  TResult = Dext.Web.Results.TResult;
  TOutputFormatterContext = Dext.Web.Results.TOutputFormatterContext;
  TJsonResult = Dext.Web.Results.TJsonResult;
  TStatusCodeResult = Dext.Web.Results.TStatusCodeResult;
  TContentResult = Dext.Web.Results.TContentResult;
  TStreamResult = Dext.Web.Results.TStreamResult;
  TContextualResults = Dext.Web.Results.TContextualResults;
  Results = Dext.Web.Results.Results;
  // TObjectResult<T> = Dext.Web.Results.TObjectResult<T>;

  // Dext.Web.Routing
  TRoutePattern = Dext.Web.Routing.TRoutePattern;
  TRouteDefinition = Dext.Web.Routing.TRouteDefinition;
  IRouteMatcher = Dext.Web.Routing.IRouteMatcher;
  /// <summary> Heart of the Dext Web routing engine. </summary>
  TRouteMatcher = Dext.Web.Routing.TRouteMatcher;
  /// <summary> Exception thrown when a routing configuration or resolution error occurs. </summary>
  ERouteException = Dext.Web.Routing.ERouteException;

  // Dext.Web.Routing.Attributes - New Names (ASP.NET Core style)
  RouteAttribute = Dext.Web.Routing.Attributes.RouteAttribute;
  HttpGet = Dext.Web.Routing.Attributes.HttpGetAttribute;
  HttpPost = Dext.Web.Routing.Attributes.HttpPostAttribute;
  HttpPut = Dext.Web.Routing.Attributes.HttpPutAttribute;
  HttpDelete = Dext.Web.Routing.Attributes.HttpDeleteAttribute;
  HttpPatch = Dext.Web.Routing.Attributes.HttpPatchAttribute;
  HttpHead = Dext.Web.Routing.Attributes.HttpHeadAttribute;
  HttpOptions = Dext.Web.Routing.Attributes.HttpOptionsAttribute;
  ApiController = Dext.Web.Routing.Attributes.ApiControllerAttribute;
  HttpException = Dext.Web.Routing.Attributes.HttpException;

{$WARNINGS OFF}
  // Dext.Web.Routing.Attributes - Deprecated Aliases (backward compatibility)
  DextRouteAttribute = Dext.Web.Routing.Attributes.DextRouteAttribute;
  DextGetAttribute = Dext.Web.Routing.Attributes.DextGetAttribute;
  DextPostAttribute = Dext.Web.Routing.Attributes.DextPostAttribute;
  DextPutAttribute = Dext.Web.Routing.Attributes.DextPutAttribute;
  DextDeleteAttribute = Dext.Web.Routing.Attributes.DextDeleteAttribute;
  DextPatchAttribute = Dext.Web.Routing.Attributes.DextPatchAttribute;
  DextHeadAttribute = Dext.Web.Routing.Attributes.DextHeadAttribute;
  DextOptionsAttribute = Dext.Web.Routing.Attributes.DextOptionsAttribute;
  DextControllerAttribute = Dext.Web.Routing.Attributes.DextControllerAttribute;
  EDextHttpException = Dext.Web.Routing.Attributes.EDextHttpException;
{$WARNINGS ON}
  // Dext.Web.RoutingMiddleware
  TRoutingMiddleware = Dext.Web.RoutingMiddleware.TRoutingMiddleware;

  // Dext.Web.StaticFiles
  TContentTypeProvider = Dext.Web.StaticFiles.TContentTypeProvider;
  TStaticFileOptions = Dext.Web.StaticFiles.TStaticFileOptions;
  TStaticFileMiddleware = Dext.Web.StaticFiles.TStaticFileMiddleware;
  TApplicationBuilderStaticFilesExtensions = Dext.Web.StaticFiles.TApplicationBuilderStaticFilesExtensions;

  // Dext.Web.Versioning
  IApiVersionReader = Dext.Web.Versioning.IApiVersionReader;
  TQueryStringApiVersionReader = Dext.Web.Versioning.TQueryStringApiVersionReader;
  THeaderApiVersionReader = Dext.Web.Versioning.THeaderApiVersionReader;
  TPathApiVersionReader = Dext.Web.Versioning.TPathApiVersionReader;
  TCompositeApiVersionReader = Dext.Web.Versioning.TCompositeApiVersionReader;

  // Dext.Web.WebApplication
  TWebApplication = Dext.Web.WebApplication.TWebApplication;
  TDextApplication = TWebApplication; // deprecated

  // Dext.WebHost
  TWebHostBuilder = Dext.WebHost.TWebHostBuilder;

  {$IFDEF DEXT_ENABLE_ENTITY}
  // Dext.Web.DataApi
  TDataApiOptions = Dext.Web.DataApi.TDataApiOptions;
  TDataApiOptionsBuilder = Dext.Web.DataApi.TDataApiOptionsBuilder;
  TDataApi = Dext.Web.DataApi.TDataApi;
  {$ENDIF}

const
  // Dext.HealthChecks
  Healthy = Dext.HealthChecks.Healthy;
  Degraded = Dext.HealthChecks.Degraded;
  Unhealthy = Dext.HealthChecks.Unhealthy;
  // Dext.OpenAPI.Attributes
  Path = Dext.OpenAPI.Attributes.Path;
  Query = Dext.OpenAPI.Attributes.Query;
  Header = Dext.OpenAPI.Attributes.Header;
  Cookie = Dext.OpenAPI.Attributes.Cookie;
  // Dext.OpenAPI.Types
  odtString = Dext.OpenAPI.Types.odtString;
  odtNumber = Dext.OpenAPI.Types.odtNumber;
  odtInteger = Dext.OpenAPI.Types.odtInteger;
  odtBoolean = Dext.OpenAPI.Types.odtBoolean;
  odtArray = Dext.OpenAPI.Types.odtArray;
  odtObject = Dext.OpenAPI.Types.odtObject;
  oplQuery = Dext.OpenAPI.Types.oplQuery;
  oplPath = Dext.OpenAPI.Types.oplPath;
  oplHeader = Dext.OpenAPI.Types.oplHeader;
  oplCookie = Dext.OpenAPI.Types.oplCookie;
  sstApiKey = Dext.OpenAPI.Types.sstApiKey;
  sstHttp = Dext.OpenAPI.Types.sstHttp;
  sstOAuth2 = Dext.OpenAPI.Types.sstOAuth2;
  sstOpenIdConnect = Dext.OpenAPI.Types.sstOpenIdConnect;
  aklQuery = Dext.OpenAPI.Types.aklQuery;
  aklHeader = Dext.OpenAPI.Types.aklHeader;
  aklCookie = Dext.OpenAPI.Types.aklCookie;
  // Dext.RateLimiting.Core
  rltFixedWindow = Dext.RateLimiting.Core.rltFixedWindow;
  rltSlidingWindow = Dext.RateLimiting.Core.rltSlidingWindow;
  rltTokenBucket = Dext.RateLimiting.Core.rltTokenBucket;
  rltConcurrency = Dext.RateLimiting.Core.rltConcurrency;
  psIpAddress = Dext.RateLimiting.Core.psIpAddress;
  psHeader = Dext.RateLimiting.Core.psHeader;
  psRoute = Dext.RateLimiting.Core.psRoute;
  psCustom = Dext.RateLimiting.Core.psCustom;
  // Dext.Web.DataApi
  {$IFDEF DEXT_ENABLE_ENTITY}
  amGet = Dext.Web.DataApi.amGet;
  amGetList = Dext.Web.DataApi.amGetList;
  amPost = Dext.Web.DataApi.amPost;
  amPut = Dext.Web.DataApi.amPut;
  amDelete = Dext.Web.DataApi.amDelete;
  {$ENDIF}
  // Dext.Web.ModelBinding
  bsBody = Dext.Web.ModelBinding.bsBody;
  bsQuery = Dext.Web.ModelBinding.bsQuery;
  bsRoute = Dext.Web.ModelBinding.bsRoute;
  bsHeader = Dext.Web.ModelBinding.bsHeader;
  bsServices = Dext.Web.ModelBinding.bsServices;
  bsForm = Dext.Web.ModelBinding.bsForm;
  // {END_DEXT_ALIASES}

type
  {$IFDEF DEXT_ENABLE_ENTITY}
  // Dext.Entity type aliases for TWebServicesHelper
  TDbContext = Dext.Entity.TDbContext;
  TDbContextOptions = Dext.Entity.TDbContextOptions;
  TDbContextOptionsBuilder = Dext.Entity.TDbContextOptionsBuilder;
  {$ENDIF}

  /// <summary>
  ///   Class helper for TDextServices to add web framework features.
  /// </summary>
  TWebServicesHelper = record helper for TDextServices
  public
    {$IFDEF DEXT_ENABLE_ENTITY}
    /// <summary>
    ///   Registers a DbContext with the dependency injection container using an options instance.
    /// </summary>
    function AddDbContext<T: TDbContext>(const AOptions: TDbContextOptions): TDextServices; overload;

    /// <summary>
    ///   Registers a DbContext with the dependency injection container using a fluent options builder.
    /// </summary>
    function AddDbContext<T: TDbContext>(const ABuilder: TDbContextOptionsBuilder): TDextServices; overload;

    /// <summary>
    ///   Registers a DbContext with the dependency injection container using a fluent builder callback.
    /// </summary>
    function AddDbContext<T: TDbContext>(AConfigurator: TProc<TDbContextOptionsBuilder>): TDextServices; overload;

    /// <summary>
    ///   Registers a DbContext with the dependency injection container.
    /// </summary>
    function AddDbContext<T: TDbContext>(Config: TProc<TDbContextOptions>): TDextServices; overload;
    function AddDbContext<T: TDbContext>(const AConfig: IConfigurationSection): TDextServices; overload;
    {$ENDIF}

    /// <summary>
    ///   Scans the application for controllers (classes with [ApiController]) and registers them in the DI.
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
    ///   Adds logging services to the application.
    /// </summary>
    function AddLogging(const AConfigure: TProc<ILoggingBuilder> = nil): TDextServices;

    /// <summary>
    ///   Configures a settings class (IOptions&lt;T&gt;) from the root configuration.
    /// </summary>
    function Configure<T: class, constructor>(Configuration: IConfiguration): TDextServices; overload;
    
    /// <summary>
    ///   Configures a settings class (IOptions&lt;T&gt;) from a specific configuration section.
    /// </summary>
    function Configure<T: class, constructor>(Section: IConfigurationSection): TDextServices; overload;

    /// <summary>
    ///   Enables content negotiation and registers default formatters.
    /// </summary>
    function AddContentNegotiation: TDextServices;

    /// <summary>
    ///   Enables the native Dext Templating engine for server-side rendering (SSR).
    /// </summary>
    function AddDextTemplating: TDextServices; overload;
    function AddDextTemplating(AConfig: TProc<TViewOptions>): TDextServices; overload;
    function AddDextTemplating(const AOptions: TViewOptions): TDextServices; overload;
    function AddDextTemplating(const ABuilder: TViewOptionsBuilder): TDextServices; overload;

    {$IFDEF DEXT_ENABLE_WEB_STENCILS}
    /// <summary>
    ///  Enables Web Stencils view engine using default conventions (CoC):
    ///  - Template Root: 'wwwroot/views' (Full Path)
    ///  - Default Layout: '_Layout.html'
    ///  - Whitelist Entities: Enabled
    /// </summary>
    function AddWebStencils: TDextServices; overload;
    
    /// <summary>
    ///  Enables Web Stencils view engine with custom configuration.
    /// </summary>
    function AddWebStencils(AConfig: TProc<TViewOptions>): TDextServices; overload;

    /// <summary>
    ///   Registers the Web Stencils view engine using pre-configured options.
    /// </summary>
    function AddWebStencils(const AOptions: TViewOptions): TDextServices; overload;

    /// <summary>
    ///   Registers the Web Stencils view engine using a fluent builder configuration.
    /// </summary>
    function AddWebStencils(const ABuilder: TViewOptionsBuilder): TDextServices; overload;
    {$ENDIF}

    /// <summary>
    ///   Registers `TInMemoryStreamableSessionManager` as `IStreamableSessionManager` in DI.
    ///   Call once during service configuration. Use `App.UseStreamableSessions` to also
    ///   start the background scavenger thread for idle session cleanup.
    /// </summary>
    function AddStreamableSessions: TDextServices;
  end;

  TDextWebServicesHelper = TWebServicesHelper;
  TDextHttpServicesHelper = TWebServicesHelper;

  {$IFDEF DEXT_ENABLE_ENTITY}
  /// <summary>
  ///   Helper for TWebApplication to allow fluent MapFast routing with DbContext pooling.
  /// </summary>
  TWebApplicationHelper = class helper for TWebApplication
  public
    function MapFast<TDbContext: class, constructor>(const AMethod, APath: string; AHandler: TDextFastContextRouteHandler<TDbContext>): IWebApplication; overload;
    function MapFast<TDbContext: class, constructor>(const APath: string; AHandler: TDextFastContextRouteHandler<TDbContext>): IWebApplication; overload;
  end;
  {$ENDIF}

  /// <summary>
  ///   Helper for AppBuilder to provide factory methods and extensions for middleware configuration.
  /// </summary>
  THttpAppBuilderHelper = record helper for TAppBuilder
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
    
    // Extensions

    /// <summary>
    ///   Adds Forwarded Headers middleware to the pipeline with default Zero Trust options.
    /// </summary>
    function UseForwardedHeaders: TAppBuilder; overload;
    function UseForwardedHeaders(const AOptions: TForwardedHeadersOptions): TAppBuilder; overload;
    function UseForwardedHeaders(const AForwardedBuilder: TForwardedHeadersBuilder): TAppBuilder; overload;
    function UseForwardedHeaders(AConfigurator: TProc<TForwardedHeadersBuilder>): TAppBuilder; overload;

    /// <summary>
    ///   Adds CORS middleware to the pipeline.
    /// </summary>
    function UseCors: TAppBuilder; overload;
    function UseCors(const AOptions: TCorsOptions): TAppBuilder; overload;
    function UseCors(const ACorsBuilder: TCorsBuilder): TAppBuilder; overload;
    function UseCors(AConfigurator: TProc<TCorsBuilder>): TAppBuilder; overload;
    
    /// <summary>
    ///   Adds JWT Authentication middleware to the pipeline using the provided options.
    /// </summary>
    function UseJwtAuthentication(const AOptions: TJwtOptions): TAppBuilder; overload;
    
    /// <summary>
    ///   Adds JWT Authentication middleware to the pipeline using the provided options (Legacy overload).
    /// </summary>
    function UseJwtAuthentication(const ASecretKey: string; AConfigurator: TJwtBuilderProc): TAppBuilder; overload;
    function UseJwtAuthentication(const AJwtBuilder: TJwtOptionsBuilder): TAppBuilder; overload;
    
    /// <summary>
    ///   Adds Basic Authentication middleware with a simple validation function.
    /// </summary>
    function UseBasicAuthentication(const ARealm: string; AValidateFunc: TBasicAuthValidateFunc): TAppBuilder; overload;
    
    /// <summary>
    ///   Adds Basic Authentication middleware with role support.
    /// </summary>
    function UseBasicAuthentication(const ARealm: string; AValidateFunc: TBasicAuthValidateWithRolesFunc): TAppBuilder; overload;
    
    /// <summary>
    ///   Adds Basic Authentication middleware with custom options.
    /// </summary>
    function UseBasicAuthentication(const AOptions: TBasicAuthOptions; AValidateFunc: TBasicAuthValidateFunc): TAppBuilder; overload;
    
    /// <summary>
    ///   Adds Swagger middleware to the application pipeline using the provided options.
    /// </summary>
    function UseSwagger(const AOptions: TOpenAPIOptions): TAppBuilder; overload;

    /// <summary>
    ///   Adds Swagger middleware to the application pipeline with default options.
    /// </summary>
    function UseSwagger: TAppBuilder; overload;

    /// <summary>
    ///   Adds Static Files middleware to the pipeline using the provided options.
    /// </summary>
    function UseStaticFiles(const AOptions: TStaticFileOptions): TAppBuilder; overload;
    
    /// <summary>
    ///   Adds Static Files middleware to the pipeline serving from the specified root path.
    /// </summary>
    function UseStaticFiles(const ARootPath: string): TAppBuilder; overload;
    
    // ⏩ Core Forwarding
    
    /// <summary>
    ///   Adds a middleware class to the pipeline. The middleware must have a constructor accepting RequestDelegate (and optionally other services).
    /// </summary>
    function UseMiddleware(AMiddleware: TClass): TAppBuilder;
    
    /// <summary>
    ///   Maps a GET request to a static handler.
    /// </summary>
    function MapGet(const Path: string; Handler: TStaticHandler): TAppBuilder; overload;

    /// <summary>
    ///   Maps a POST request to a static handler.
    /// </summary>
    function MapPost(const Path: string; Handler: TStaticHandler): TAppBuilder; overload;
    
    /// <summary>
    ///   Maps a PUT request to a static handler.
    /// </summary>
    function MapPut(const Path: string; Handler: TStaticHandler): TAppBuilder; overload;

    /// <summary>
    ///   Maps a DELETE request to a static handler.
    /// </summary>
    function MapDelete(const Path: string; Handler: TStaticHandler): TAppBuilder; overload;

    /// <summary>
    ///   Maps a QUERY request to a static handler.
    /// </summary>
    function MapQuery(const Path: string; Handler: TStaticHandler): TAppBuilder; overload;

    function MapFast(const AMethod, APath: string; AHandler: TDextFastRouteHandler): TAppBuilder; overload;
    function MapFast(const APath: string; AHandler: TDextFastRouteHandler): TAppBuilder; overload;
    {$IFDEF DEXT_ENABLE_ENTITY}
    function MapFast<TDbContext: class, constructor>(const AMethod, APath: string; AHandler: TDextFastContextRouteHandler<TDbContext>): TAppBuilder; overload;
    function MapFast<TDbContext: class, constructor>(const APath: string; AHandler: TDextFastContextRouteHandler<TDbContext>): TAppBuilder; overload;
    {$ENDIF}

    /// <summary>
    ///   Builds the request pipeline and returns the main RequestDelegate.
    /// </summary>
    function Build: TRequestDelegate;

    /// <summary>
    ///   Enables Server-Side Surface Rendering (SSR) view support.
    /// </summary>
    function UseViewEngine: TAppBuilder;

    /// <summary>
    ///   Starts the Streamable Session Scavenger thread (background GC for idle sessions).
    ///   Requires `Services.AddStreamableSessions` to be called first.
    ///   Default: checks every 60s, evicts sessions idle for 30min.
    /// </summary>
    function UseStreamableSessions(AIntervalSeconds: Integer = 60;
      ATimeoutMinutes: Integer = 30): TAppBuilder;

    // -------------------------------------------------------------------------
    // ⛓️ Middleware
    // -------------------------------------------------------------------------
    /// <summary>Adds base path middleware to strip prefix and populate Request.PathBase.</summary>
    function UsePathBase(const APathBase: string): TAppBuilder;
    function UseStaticFiles: TAppBuilder; overload;
    function UseStartupLock: TAppBuilder;
    function UseExceptionHandler: TAppBuilder; overload;
    function UseExceptionHandler(const AOptions: TExceptionHandlerOptions): TAppBuilder; overload;
    function UseExceptionHandler(const AExceptionHandlerBuilder: TExceptionHandlerBuilder): TAppBuilder; overload;
    function UseExceptionHandler(AConfigurator: TProc<TExceptionHandlerBuilder>): TAppBuilder; overload;
    function UseDeveloperExceptionPage: TAppBuilder;
    function UseHttpLogging: TAppBuilder; overload;
    function UseHttpLogging(const AOptions: THttpLoggingOptions): TAppBuilder; overload;
    function UseHttpLogging(const AHttpLoggingBuilder: THttpLoggingBuilder): TAppBuilder; overload;
    function UseHttpLogging(AConfigurator: TProc<THttpLoggingBuilder>): TAppBuilder; overload;
    function UseCompression: TAppBuilder; overload;
    function UseCompression(const AOptions: TCompressionOptions): TAppBuilder; overload;
    function UseCompression(const ACompressionBuilder: TCompressionBuilder): TAppBuilder; overload;
    function UseCompression(AConfigurator: TProc<TCompressionBuilder>): TAppBuilder; overload;
    function UseSecurityHeaders: TAppBuilder; overload;
    function UseSecurityHeaders(const AOptions: TSecurityHeadersOptions): TAppBuilder; overload;
    function UseSecurityHeaders(const ASecurityHeadersBuilder: TSecurityHeadersBuilder): TAppBuilder; overload;
    function UseSecurityHeaders(AConfigurator: TProc<TSecurityHeadersBuilder>): TAppBuilder; overload;

    // -------------------------------------------------------------------------
    // 🚦 Rate Limiting
    // -------------------------------------------------------------------------
    function UseRateLimiting(const APolicy: TRateLimitPolicy): TAppBuilder; overload;

    // -------------------------------------------------------------------------
    // 💾 Response Caching
    // -------------------------------------------------------------------------
    function UseResponseCache(AConfigurator: TResponseCacheBuilderProc): TAppBuilder; overload;
    function UseResponseCache(const ACacheBuilder: TResponseCacheBuilder): TAppBuilder; overload;
    function UseResponseCaching(AConfigurator: TResponseCacheBuilderProc): TAppBuilder; overload;
    function UseResponseCaching(const ACacheBuilder: TResponseCacheBuilder): TAppBuilder; overload;

    function MapEndpoints(AMapper: TProc<TAppBuilder>): TAppBuilder;
    function MapDataApis: TAppBuilder;
    // -------------------------------------------------------------------------
    // 📬 Routing - POST
    // -------------------------------------------------------------------------
    
    /// <summary>
    ///   Maps a POST request to a handler with 1 injected parameter.
    /// </summary>
    function MapPost<T>(const Path: string; Handler: THandlerProc<T>): TAppBuilder; overload;
    
    /// <summary>
    ///   Maps a POST request to a handler with 2 injected parameters.
    /// </summary>
    function MapPost<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TAppBuilder; overload;
    
    /// <summary>
    ///   Maps a POST request to a handler with 3 injected parameters.
    /// </summary>
    function MapPost<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TAppBuilder; overload;

    /// <summary>
    ///   Maps a POST request to a handler that returns a result.
    /// </summary>
    function MapPost<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    function MapPost<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    function MapPost<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    function MapPost<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    function MapPostResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    function MapPostResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    function MapPostResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    function MapPostResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    // -------------------------------------------------------------------------
    // 📥 Routing - GET
    // -------------------------------------------------------------------------
    
    /// <summary>
    ///   Maps a GET request to a handler with 1 injected parameter.
    /// </summary>
    function MapGet<T>(const Path: string; Handler: THandlerProc<T>): TAppBuilder; overload;
    
    /// <summary>
    ///   Maps a GET request to a handler with 2 injected parameters.
    /// </summary>
    function MapGet<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TAppBuilder; overload;
    
    /// <summary>
    ///   Maps a GET request to a handler with 3 injected parameters.
    /// </summary>
    function MapGet<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TAppBuilder; overload;

    /// <summary>
    ///   Maps a GET request to a handler that returns a result.
    /// </summary>
    function MapGet<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    function MapGet<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    function MapGet<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    function MapGet<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    function MapGetResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    

    /// <summary>
    ///   Maps a GET request to a handler with 1 parameter that returns a result.
    /// </summary>
    function MapGetResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    
    /// <summary>
    ///   Maps a GET request to a handler with 2 parameters that returns a result.
    /// </summary>
    function MapGetResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    
    /// <summary>
    ///   Maps a GET request to a handler with 3 parameters that returns a result.
    /// </summary>
    function MapGetResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    // -------------------------------------------------------------------------
    // 📤 Routing - PUT
    // -------------------------------------------------------------------------
    function MapPut<T>(const Path: string; Handler: THandlerProc<T>): TAppBuilder; overload;
    function MapPut<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TAppBuilder; overload;
    function MapPut<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TAppBuilder; overload;

    function MapPut<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    function MapPut<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    function MapPut<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    function MapPut<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    function MapPutResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    function MapPutResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    function MapPutResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    function MapPutResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    // -------------------------------------------------------------------------
    // 🗑️ Routing - DELETE
    // -------------------------------------------------------------------------
    function MapDelete<T>(const Path: string; Handler: THandlerProc<T>): TAppBuilder; overload;
    function MapDelete<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TAppBuilder; overload;
    function MapDelete<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TAppBuilder; overload;

    function MapDelete<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    function MapDelete<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    function MapDelete<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    function MapDelete<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    function MapDeleteResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    function MapDeleteResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    function MapDeleteResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    function MapDeleteResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    // -------------------------------------------------------------------------
    // Routing - QUERY
    // -------------------------------------------------------------------------
    function MapQuery<T>(const Path: string; Handler: THandlerProc<T>): TAppBuilder; overload;
    function MapQuery<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): TAppBuilder; overload;
    function MapQuery<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): TAppBuilder; overload;

    function MapQuery<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    function MapQuery<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    function MapQuery<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    function MapQuery<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    function MapQueryResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): TAppBuilder; overload;
    function MapQueryResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): TAppBuilder; overload;
    function MapQueryResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): TAppBuilder; overload;
    function MapQueryResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): TAppBuilder; overload;

    // -------------------------------------------------------------------------
    // 📝 OpenAPI Metadata
    // -------------------------------------------------------------------------
    function WithSummary(const ASummary: string): AppBuilder;
    function WithDescription(const ADescription: string): AppBuilder;
    function WithTag(const ATag: string): AppBuilder;
    function WithTags(const ATags: array of string): AppBuilder;
    function WithMetadata(const ASummary, ADescription: string; const ATags: array of string): AppBuilder;
    function RequireAuthorization: AppBuilder; overload;
    function RequireAuthorization(const AScheme: string): AppBuilder; overload;
    function RequireAuthorization(const ASchemes: array of string): AppBuilder; overload;

    {$IFDEF DEXT_ENABLE_ENTITY}
    /// <summary>
    ///  Configures a Database as API endpoint for the specified entity type. 
    /// </summary>
    function MapDataApi<T: class, constructor>(const APath: string): AppBuilder; overload;
    function MapDataApi<T: class, constructor>(const APath: string; AOptions: TDataApiOptions): AppBuilder; overload;
    function MapDataApi(const AEntityClass: TClass; const APath: string; AOptions: TDataApiOptions = nil): AppBuilder; overload;
    /// <summary>
    /// Maps REST endpoints for remote TEntityDataSet tracking and sync.
    /// </summary>
    function MapEntityDataSet<T: class, constructor>(const APath: string; ADbContextClass: TClass): AppBuilder; overload;
    {$ENDIF}
  end;

// ===========================================================================
//  Global Response Helpers
// ===========================================================================

function WebApplication: IWebApplication;
function CorsOptions: TCorsBuilder;
function CompressionOptions: TCompressionBuilder;
function ExceptionHandlerOptions: TExceptionHandlerBuilder;
function HttpLoggingOptions: THttpLoggingBuilder;
function SecurityHeadersOptions: TSecurityHeadersBuilder;
function ResponseCacheOptions: TResponseCacheBuilder;
function SwaggerOptions: TOpenAPIBuilder;
function ViewOptions: TViewOptionsBuilder;
function JwtOptions(const ASecretKey: string = ''): TJwtOptionsBuilder;
{$IFDEF DEXT_ENABLE_ENTITY}
function DataApiOptions: TDataApiOptionsBuilder;
{$ENDIF}

implementation

uses
  Dext.Options.Extensions,
  Dext.Configuration.Binder,
  Dext.Web.EntityDataSetApi;

function WebApplication: IWebApplication;
begin
  Result := TWebApplication.Create;
end;

function CorsOptions: TCorsBuilder;
begin
  Result := TCorsBuilder.Create;
end;

function CompressionOptions: TCompressionBuilder;
begin
  Result := TCompressionBuilder.Create;
end;

function ExceptionHandlerOptions: TExceptionHandlerBuilder;
begin
  Result := TExceptionHandlerBuilder.Create;
end;

function HttpLoggingOptions: THttpLoggingBuilder;
begin
  Result := THttpLoggingBuilder.Create;
end;

function SecurityHeadersOptions: TSecurityHeadersBuilder;
begin
  Result := TSecurityHeadersBuilder.Create;
end;

function ResponseCacheOptions: TResponseCacheBuilder;
begin
  Result := TResponseCacheBuilder.Create;
end;

function SwaggerOptions: TOpenAPIBuilder;
begin
  Result := TOpenAPIBuilder.Create;
end;

function ViewOptions: TViewOptionsBuilder;
begin
  Result := TViewOptionsBuilder.Create;
end;

function JwtOptions(const ASecretKey: string = ''): TJwtOptionsBuilder;
begin
  Result := Dext.Auth.JWT.JwtOptions(ASecretKey);
end;

{$IFDEF DEXT_ENABLE_ENTITY}
function DataApiOptions: TDataApiOptionsBuilder;
begin
  Result := Dext.Web.DataApi.DataApiOptions;
end;
{$ENDIF}

{ TWebServicesHelper }

function TWebServicesHelper.AddControllers: TDextServices;
var
  Scanner: IControllerScanner;
begin
  Scanner := TControllerScanner.Create;
  Scanner.RegisterServices(Self.Unwrap);
  Result := Self;
end;

function TWebServicesHelper.AddHealthChecks: THealthCheckBuilder;
begin
  Result := THealthCheckBuilder.Create(Self.Unwrap);
end;

function TWebServicesHelper.AddBackgroundServices: TBackgroundServiceBuilder;
begin
  Result := TBackgroundServiceBuilder.Create(Self.Unwrap);
end;

function TWebServicesHelper.AddLogging(const AConfigure: TProc<ILoggingBuilder>): TDextServices;
begin
  TServiceCollectionLoggingExtensions.AddLogging(Self.Unwrap, AConfigure);
  Result := Self;
end;

function TWebServicesHelper.Configure<T>(Configuration: IConfiguration): TDextServices;
begin
  TOptionsServiceCollectionExtensions.Configure<T>(Self.Unwrap, Configuration);
  Result := Self;
end;

function TWebServicesHelper.Configure<T>(Section: IConfigurationSection): TDextServices;
begin
  TOptionsServiceCollectionExtensions.Configure<T>(Self.Unwrap, Section);
  Result := Self;
end;

function TWebServicesHelper.AddContentNegotiation: TDextServices;
begin
  TWebDIHelpers.AddContentNegotiation(Self.Unwrap);
  Result := Self;
end;


{ THttpAppBuilderHelper }

function THttpAppBuilderHelper.CreateCorsOptions: TCorsOptions;
begin
  Result := TCorsOptions.Create;
end;

function THttpAppBuilderHelper.CreateJwtOptions(const Secret: string): TJwtOptions;
begin
  Result := TJwtOptions.Create(Secret);
end;

function THttpAppBuilderHelper.CreateStaticFileOptions: TStaticFileOptions;
begin
  Result := TStaticFileOptions.Create;
end;

function THttpAppBuilderHelper.UseCors: TAppBuilder;
begin
  TApplicationBuilderCorsExtensions.UseCors(Self.Unwrap);
  Result := Self;
end;

function THttpAppBuilderHelper.UseCors(const AOptions: TCorsOptions): TAppBuilder;
begin
  TApplicationBuilderCorsExtensions.UseCors(Self.Unwrap, AOptions);
  Result := Self;
end;

function THttpAppBuilderHelper.UseCors(const ACorsBuilder: TCorsBuilder): TAppBuilder;
begin
  TApplicationBuilderCorsExtensions.UseCors(Self.Unwrap, ACorsBuilder);
  Result := Self;
end;

function THttpAppBuilderHelper.UseCors(AConfigurator: TProc<TCorsBuilder>): TAppBuilder;
begin
  TApplicationBuilderCorsExtensions.UseCors(Self.Unwrap, AConfigurator);
  Result := Self;
end;

function THttpAppBuilderHelper.UseStartupLock: TAppBuilder;
begin
  TApplicationBuilderMiddlewareExtensions.UseStartupLock(Self.Unwrap);
  Result := Self;
end;

function THttpAppBuilderHelper.UseExceptionHandler: TAppBuilder;
begin
  TApplicationBuilderMiddlewareExtensions.UseExceptionHandler(Self.Unwrap);
  Result := Self;
end;

function THttpAppBuilderHelper.UseExceptionHandler(const AOptions: TExceptionHandlerOptions): TAppBuilder;
begin
  TApplicationBuilderMiddlewareExtensions.UseExceptionHandler(Self.Unwrap, AOptions);
  Result := Self;
end;

function THttpAppBuilderHelper.UseExceptionHandler(const AExceptionHandlerBuilder: TExceptionHandlerBuilder): TAppBuilder;
begin
  Result := UseExceptionHandler(AExceptionHandlerBuilder.Build);
end;

function THttpAppBuilderHelper.UseExceptionHandler(AConfigurator: TProc<TExceptionHandlerBuilder>): TAppBuilder;
var
  Builder: TExceptionHandlerBuilder;
begin
  Builder := TExceptionHandlerBuilder.Create;
  if Assigned(AConfigurator) then
    AConfigurator(Builder);
  Result := UseExceptionHandler(Builder.Build);
end;

function THttpAppBuilderHelper.UseHttpLogging: TAppBuilder;
begin
  TApplicationBuilderMiddlewareExtensions.UseHttpLogging(Self.Unwrap);
  Result := Self;
end;

function THttpAppBuilderHelper.UseHttpLogging(const AOptions: THttpLoggingOptions): TAppBuilder;
begin
  TApplicationBuilderMiddlewareExtensions.UseHttpLogging(Self.Unwrap, AOptions);
  Result := Self;
end;

function THttpAppBuilderHelper.UseHttpLogging(const AHttpLoggingBuilder: THttpLoggingBuilder): TAppBuilder;
begin
  Result := UseHttpLogging(AHttpLoggingBuilder.Build);
end;

function THttpAppBuilderHelper.UseHttpLogging(AConfigurator: TProc<THttpLoggingBuilder>): TAppBuilder;
var
  Builder: THttpLoggingBuilder;
begin
  Builder := THttpLoggingBuilder.Create;
  if Assigned(AConfigurator) then
    AConfigurator(Builder);
  Result := UseHttpLogging(Builder.Build);
end;

function THttpAppBuilderHelper.UseCompression(const AOptions: TCompressionOptions): TAppBuilder;
begin
  Self.Unwrap.UseMiddleware(TCompressionMiddleware.Create(AOptions));
  Result := Self;
end;

function THttpAppBuilderHelper.UseCompression(const ACompressionBuilder: TCompressionBuilder): TAppBuilder;
begin
  Result := UseCompression(ACompressionBuilder.Build);
end;

function THttpAppBuilderHelper.UseCompression(AConfigurator: TProc<TCompressionBuilder>): TAppBuilder;
var
  Builder: TCompressionBuilder;
begin
  Builder := TCompressionBuilder.Create;
  if Assigned(AConfigurator) then
    AConfigurator(Builder);
  Result := UseCompression(Builder.Build);
end;

function THttpAppBuilderHelper.UseCompression: TAppBuilder;
begin
  Result := UseCompression(TCompressionOptions.Create);
end;

function THttpAppBuilderHelper.UseSecurityHeaders(const AOptions: TSecurityHeadersOptions): TAppBuilder;
begin
  Self.Unwrap.UseMiddleware(TSecurityHeadersMiddleware.Create(AOptions));
  Result := Self;
end;

function THttpAppBuilderHelper.UseSecurityHeaders(const ASecurityHeadersBuilder: TSecurityHeadersBuilder): TAppBuilder;
begin
  Result := UseSecurityHeaders(ASecurityHeadersBuilder.Build);
end;

function THttpAppBuilderHelper.UseSecurityHeaders(AConfigurator: TProc<TSecurityHeadersBuilder>): TAppBuilder;
var
  Builder: TSecurityHeadersBuilder;
begin
  Builder := TSecurityHeadersBuilder.Create;
  if Assigned(AConfigurator) then
    AConfigurator(Builder);
  Result := UseSecurityHeaders(Builder.Build);
end;

function THttpAppBuilderHelper.UseSecurityHeaders: TAppBuilder;
begin
  Result := UseSecurityHeaders(TSecurityHeadersOptions.Create);
end;

function THttpAppBuilderHelper.UseJwtAuthentication(const AOptions: TJwtOptions): TAppBuilder;
begin
  TApplicationBuilderJwtExtensions.UseJwtAuthentication(Self.Unwrap, AOptions);
  Result := Self;
end;

function THttpAppBuilderHelper.UseJwtAuthentication(const ASecretKey: string; AConfigurator: TJwtBuilderProc): TAppBuilder;
begin
  TApplicationBuilderJwtExtensions.UseJwtAuthentication(Self.Unwrap, ASecretKey, AConfigurator);
  Result := Self;
end;

function THttpAppBuilderHelper.UseJwtAuthentication(const AJwtBuilder: TJwtOptionsBuilder): TAppBuilder;
begin
  TApplicationBuilderJwtExtensions.UseJwtAuthentication(Self.Unwrap, AJwtBuilder);
  Result := Self;
end;

function THttpAppBuilderHelper.UseBasicAuthentication(const ARealm: string; AValidateFunc: TBasicAuthValidateFunc): TAppBuilder;
begin
  TApplicationBuilderBasicAuthExtensions.UseBasicAuthentication(Self.Unwrap, ARealm, AValidateFunc);
  Result := Self;
end;

function THttpAppBuilderHelper.UseBasicAuthentication(const ARealm: string; AValidateFunc: TBasicAuthValidateWithRolesFunc): TAppBuilder;
begin
  TApplicationBuilderBasicAuthExtensions.UseBasicAuthentication(Self.Unwrap, ARealm, AValidateFunc);
  Result := Self;
end;

function THttpAppBuilderHelper.UseBasicAuthentication(const AOptions: TBasicAuthOptions; AValidateFunc: TBasicAuthValidateFunc): TAppBuilder;
begin
  TApplicationBuilderBasicAuthExtensions.UseBasicAuthentication(Self.Unwrap, AOptions, AValidateFunc);
  Result := Self;
end;

function THttpAppBuilderHelper.UseSwagger(const AOptions: TOpenAPIOptions): TAppBuilder;
begin
  TSwaggerExtensions.UseSwagger(Self.Unwrap, AOptions);
  Result := Self;
end;

function THttpAppBuilderHelper.UseSwagger: TAppBuilder;
begin
  TSwaggerExtensions.UseSwagger(Self.Unwrap);
  Result := Self;
end;

function THttpAppBuilderHelper.UseStaticFiles(const AOptions: TStaticFileOptions): TAppBuilder;
begin
  TApplicationBuilderStaticFilesExtensions.UseStaticFiles(Self.Unwrap, AOptions);
  Result := Self;
end;

function THttpAppBuilderHelper.UseStaticFiles(const ARootPath: string): TAppBuilder;
begin
  TApplicationBuilderStaticFilesExtensions.UseStaticFiles(Self.Unwrap, ARootPath);
  Result := Self;
end;

function THttpAppBuilderHelper.UseMiddleware(AMiddleware: TClass): TAppBuilder;
begin
  Self.Unwrap.UseMiddleware(AMiddleware);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGet(const Path: string; Handler: TStaticHandler): TAppBuilder;
begin
  Self.Unwrap.MapGet(Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPost(const Path: string; Handler: TStaticHandler): TAppBuilder;
begin
  Self.Unwrap.MapPost(Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPut(const Path: string; Handler: TStaticHandler): TAppBuilder;
begin
  Self.Unwrap.MapPut(Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDelete(const Path: string; Handler: TStaticHandler): TAppBuilder;
begin
  Self.Unwrap.MapDelete(Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQuery(const Path: string; Handler: TStaticHandler): TAppBuilder;
begin
  Self.Unwrap.MapQuery(Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapFast(const AMethod, APath: string; AHandler: TDextFastRouteHandler): TAppBuilder;
begin
  Self.Unwrap.MapFast(AMethod, APath, AHandler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapFast(const APath: string; AHandler: TDextFastRouteHandler): TAppBuilder;
begin
  Self.Unwrap.MapFast('GET', APath, AHandler);
  Result := Self;
end;

{$IFDEF DEXT_ENABLE_ENTITY}
function THttpAppBuilderHelper.MapFast<TDbContext>(const AMethod, APath: string; AHandler: TDextFastContextRouteHandler<TDbContext>): TAppBuilder;
var
  App: IApplicationBuilder;
  FastHandler: TDextFastRouteHandler;
begin
  App := Self.Unwrap;
  FastHandler := procedure(const Req: IHttpRequest; const Res: IHttpResponse)
    var
      Services: IServiceProvider;
      Unk: IInterface;
      Pool: IDextPool<TDbContext>;
      Ctx: TDbContext;
    begin
      Ctx := nil;
      Services := App.GetServiceProvider;
      if Services <> nil then
      begin
        Unk := Services.GetServiceAsInterface(TypeInfo(IDextPool<TDbContext>));
        if (Unk <> nil) and Supports(Unk, IDextPool<TDbContext>, Pool) then
        begin
          if Pool.Acquire(Ctx) and (Ctx <> nil) then
          begin
            try
              AHandler(Ctx, Req, Res);
            finally
              Pool.Release(Ctx);
            end;
          end;
        end;
      end;
    end;
  App.MapFast(AMethod, APath, FastHandler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapFast<TDbContext>(const APath: string; AHandler: TDextFastContextRouteHandler<TDbContext>): TAppBuilder;
begin
  Result := MapFast<TDbContext>('GET', APath, AHandler);
end;

function TWebApplicationHelper.MapFast<TDbContext>(const AMethod, APath: string; AHandler: TDextFastContextRouteHandler<TDbContext>): IWebApplication;
begin
  Self.GetBuilder.MapFast<TDbContext>(AMethod, APath, AHandler);
  Result := Self;
end;

function TWebApplicationHelper.MapFast<TDbContext>(const APath: string; AHandler: TDextFastContextRouteHandler<TDbContext>): IWebApplication;
begin
  Self.GetBuilder.MapFast<TDbContext>('GET', APath, AHandler);
  Result := Self;
end;
{$ENDIF}

function THttpAppBuilderHelper.Build: TRequestDelegate;
begin
  Result := Self.Unwrap.Build;
end;

{ THttpAppBuilderHelper }

function THttpAppBuilderHelper.UseStaticFiles: TAppBuilder;
begin
  TApplicationBuilderStaticFilesExtensions.UseStaticFiles(Self.Unwrap);
  Result := Self;
end;

function THttpAppBuilderHelper.UseDeveloperExceptionPage: TAppBuilder;
begin
  TApplicationBuilderMiddlewareExtensions.UseDeveloperExceptionPage(Self.Unwrap);
  Result := Self;
end;


// -------------------------------------------------------------------------
// THttpAppBuilderHelper (Rate Limiting Extensions)
// -------------------------------------------------------------------------

function THttpAppBuilderHelper.UseRateLimiting(const APolicy: TRateLimitPolicy): TAppBuilder;
begin
  TApplicationBuilderRateLimitExtensions.UseRateLimiting(Self.Unwrap, APolicy);
  Result := Self;
end;

function THttpAppBuilderHelper.UseForwardedHeaders: TAppBuilder;
begin
  TApplicationBuilderForwardedHeadersExtensions.UseForwardedHeaders(Self.Unwrap);
  Result := Self;
end;

function THttpAppBuilderHelper.UseForwardedHeaders(const AOptions: TForwardedHeadersOptions): TAppBuilder;
begin
  TApplicationBuilderForwardedHeadersExtensions.UseForwardedHeaders(Self.Unwrap, AOptions);
  Result := Self;
end;

function THttpAppBuilderHelper.UseForwardedHeaders(const AForwardedBuilder: TForwardedHeadersBuilder): TAppBuilder;
begin
  TApplicationBuilderForwardedHeadersExtensions.UseForwardedHeaders(Self.Unwrap, AForwardedBuilder);
  Result := Self;
end;

function THttpAppBuilderHelper.UseForwardedHeaders(AConfigurator: TProc<TForwardedHeadersBuilder>): TAppBuilder;
begin
  TApplicationBuilderForwardedHeadersExtensions.UseForwardedHeaders(Self.Unwrap, AConfigurator);
  Result := Self;
end;

function THttpAppBuilderHelper.UsePathBase(const APathBase: string): TAppBuilder;
begin
  Self.Unwrap.UseMiddleware(TDextPathBaseMiddleware.Create(APathBase));
  Result := Self;
end;

// -------------------------------------------------------------------------
// THttpAppBuilderHelper (Response Caching Extensions)
// -------------------------------------------------------------------------


function THttpAppBuilderHelper.UseResponseCache(AConfigurator: TResponseCacheBuilderProc): TAppBuilder;
begin
  TApplicationBuilderCacheExtensions.UseResponseCache(Self.Unwrap, AConfigurator);
  Result := Self;
end;

function THttpAppBuilderHelper.UseResponseCache(const ACacheBuilder: TResponseCacheBuilder): AppBuilder;
begin
  TApplicationBuilderCacheExtensions.UseResponseCache(Self.Unwrap, ACacheBuilder);
  Result := Self;
end;

function THttpAppBuilderHelper.UseResponseCaching(AConfigurator: TResponseCacheBuilderProc): AppBuilder;
begin
  TApplicationBuilderCacheExtensions.UseResponseCache(Self.Unwrap, AConfigurator);
  Result := Self;
end;

function THttpAppBuilderHelper.UseResponseCaching(const ACacheBuilder: TResponseCacheBuilder): AppBuilder;
begin
  TApplicationBuilderCacheExtensions.UseResponseCache(Self.Unwrap, ACacheBuilder);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPost<T>(const Path: string; Handler: THandlerProc<T>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<T>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPost<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<T1, T2>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPost<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPost<T1, T2, T3>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPostResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPostResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPostResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPostResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPostResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPostResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPostResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPostResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGet<T>(const Path: string; Handler: THandlerProc<T>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<T>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGet<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<T1, T2>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGet<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGet<T1, T2, T3>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGetResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGetResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapEndpoints(AMapper: TProc<TAppBuilder>):
  AppBuilder;
begin
  AMapper(Self);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGetResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGetResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDataApis: TAppBuilder;
begin
  TDataApi.MapAll(Self.Unwrap);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGetResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGetResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGetResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGetResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPut<T>(const Path: string; Handler: THandlerProc<T>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPut<T>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPut<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPut<T1, T2>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPut<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPut<T1, T2, T3>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPut<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPutResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPut<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPutResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPut<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPutResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPut<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPutResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPutResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPutResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPutResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPutResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPutResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPutResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPutResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPutResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDelete<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDeleteResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDelete<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDeleteResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDelete<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDeleteResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDelete<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDeleteResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDelete<T>(const Path: string; Handler: THandlerProc<T>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDelete<T>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDelete<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDelete<T1, T2>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGet<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGetResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGet<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGetResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGet<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGetResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapGet<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapGetResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPost<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPostResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPost<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPostResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPost<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPostResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapPost<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapPostResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDelete<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDelete<T1, T2, T3>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDeleteResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDeleteResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDeleteResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDeleteResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDeleteResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDeleteResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDeleteResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapDeleteResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQuery<T>(const Path: string; Handler: THandlerProc<T>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQuery<T>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQuery<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQuery<T1, T2>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQuery<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQuery<T1, T2, T3>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQuery<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQueryResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQuery<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQueryResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQuery<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQueryResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQuery<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQueryResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQueryResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQueryResult<TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQueryResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQueryResult<T, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQueryResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQueryResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.MapQueryResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): AppBuilder;
begin
  TApplicationBuilderExtensions.MapQueryResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
  Result := Self;
end;

function THttpAppBuilderHelper.WithSummary(const ASummary: string): AppBuilder;
begin
  Dext.OpenAPI.Extensions.TEndpointMetadataExtensions.WithSummary(Self.Unwrap, ASummary);
  Result := Self;
end;

function THttpAppBuilderHelper.WithDescription(const ADescription: string): AppBuilder;
begin
  Dext.OpenAPI.Extensions.TEndpointMetadataExtensions.WithDescription(Self.Unwrap, ADescription);
  Result := Self;
end;

function THttpAppBuilderHelper.WithTag(const ATag: string): AppBuilder;
begin
  Dext.OpenAPI.Extensions.TEndpointMetadataExtensions.WithTag(Self.Unwrap, ATag);
  Result := Self;
end;

function THttpAppBuilderHelper.WithTags(const ATags: array of string): AppBuilder;
begin
  Dext.OpenAPI.Extensions.TEndpointMetadataExtensions.WithTags(Self.Unwrap, ATags);
  Result := Self;
end;

function THttpAppBuilderHelper.WithMetadata(const ASummary, ADescription: string; const ATags: array of string): AppBuilder;
begin
  Dext.OpenAPI.Extensions.TEndpointMetadataExtensions.WithMetadata(Self.Unwrap, ASummary, ADescription, ATags);
  Result := Self;
end;

function THttpAppBuilderHelper.RequireAuthorization: AppBuilder;
begin
  Dext.OpenAPI.Extensions.TEndpointMetadataExtensions.RequireAuthorization(Self.Unwrap, ['Basic']);
  Result := Self;
end;

function THttpAppBuilderHelper.RequireAuthorization(const AScheme: string): AppBuilder;
begin
  Dext.OpenAPI.Extensions.TEndpointMetadataExtensions.RequireAuthorization(Self.Unwrap, AScheme);
  Result := Self;
end;

function THttpAppBuilderHelper.RequireAuthorization(const ASchemes: array of string): AppBuilder;
begin
  Dext.OpenAPI.Extensions.TEndpointMetadataExtensions.RequireAuthorization(Self.Unwrap, ASchemes);
  Result := Self;
end;

{$IFDEF DEXT_ENABLE_ENTITY}
function THttpAppBuilderHelper.MapDataApi<T>(const APath: string): AppBuilder;
begin
  TDataApi.Map(Self.Unwrap, TClass(T), APath);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDataApi<T>(const APath: string; AOptions: TDataApiOptions): AppBuilder;
begin
  TDataApi.Map(Self.Unwrap, TClass(T), APath, AOptions);
  Result := Self;
end;

function THttpAppBuilderHelper.MapDataApi(const AEntityClass: TClass; const APath: string; AOptions: TDataApiOptions): AppBuilder;
begin
  TDataApi.Map(Self.Unwrap, AEntityClass, APath, AOptions);
  Result := Self;
end;

function THttpAppBuilderHelper.MapEntityDataSet<T>(const APath: string;
  ADbContextClass: TClass): AppBuilder;
begin
  TEntityDataSetApi.Map<T>(Self.Unwrap, APath, ADbContextClass);
  Result := Self;
end;
{$ENDIF}

{ TWebServicesHelper }

{$IFDEF DEXT_ENABLE_ENTITY}
function TWebServicesHelper.AddDbContext<T>(const AOptions: TDbContextOptions): TDextServices;
begin
  Dext.Entity.TPersistence.AddDbContext<T>(Self.Unwrap, AOptions);
  Result := Self;
end;

function TWebServicesHelper.AddDbContext<T>(const ABuilder: TDbContextOptionsBuilder): TDextServices;
begin
  Dext.Entity.TPersistence.AddDbContext<T>(Self.Unwrap, ABuilder);
  Result := Self;
end;

function TWebServicesHelper.AddDbContext<T>(AConfigurator: TProc<TDbContextOptionsBuilder>): TDextServices;
begin
  Dext.Entity.TPersistence.AddDbContext<T>(Self.Unwrap, AConfigurator);
  Result := Self;
end;

function TWebServicesHelper.AddDbContext<T>(Config: TProc<TDbContextOptions>): TDextServices;
begin
  Dext.Entity.TPersistence.AddDbContext<T>(Self.Unwrap, Config);
  Result := Self;
end;

function TWebServicesHelper.AddDbContext<T>(const AConfig: IConfigurationSection): TDextServices;
begin
  Dext.Entity.TPersistence.AddDbContext<T>(Self.Unwrap,
    procedure(Options: TDbContextOptions)
    begin
      Dext.Configuration.Binder.TConfigurationBinder.Bind(AConfig, Options);
    end
  );
  Result := Self;
end;
{$ENDIF}

{$IFDEF DEXT_ENABLE_WEB_STENCILS}
function TWebServicesHelper.AddWebStencils: TDextServices;
begin
  Result := AddWebStencils(TProc<TViewOptions>(nil));
end;

function TWebServicesHelper.AddWebStencils(AConfig: TProc<TViewOptions>): TDextServices;
var
  ConfigProc: TProc<TViewOptions>;
begin
  Result := Self;
  ConfigProc := AConfig;
  TWebStencilsViewEngine.RegisterWebStencilsFunctions;
  Self.AddSingleton(TServiceType.FromInterface(TypeInfo(IViewEngine)), TWebStencilsViewEngine,
    function(Provider: IServiceProvider): TObject
    var
      Options: TViewOptions;
    begin
      Options := TViewOptions.Create;
      if Assigned(ConfigProc) then
        ConfigProc(Options);
      Result := TWebStencilsViewEngine.Create(Options);
    end);
end;

function TWebServicesHelper.AddWebStencils(const AOptions: TViewOptions): TDextServices;
var
  Options: TViewOptions;
begin
  Result := Self;
  Options := AOptions;
  TWebStencilsViewEngine.RegisterWebStencilsFunctions;
  Self.AddSingleton(TServiceType.FromInterface(TypeInfo(IViewEngine)), TWebStencilsViewEngine,
    function(Provider: IServiceProvider): TObject
    begin
      Result := TWebStencilsViewEngine.Create(Options);
    end);
end;

function TWebServicesHelper.AddWebStencils(const ABuilder: TViewOptionsBuilder): TDextServices;
var
  OptionsBuilder: TViewOptionsBuilder;
begin
  Result := Self;
  OptionsBuilder := ABuilder;
  TWebStencilsViewEngine.RegisterWebStencilsFunctions;
  Self.AddSingleton(TServiceType.FromInterface(TypeInfo(IViewEngine)), TWebStencilsViewEngine,
    function(Provider: IServiceProvider): TObject
    begin
      Result := TWebStencilsViewEngine.Create(TViewOptions(OptionsBuilder));
    end);
end;
{$ENDIF}

function TWebServicesHelper.AddDextTemplating: TDextServices;
begin
  Result := AddDextTemplating(TProc<TViewOptions>(nil));
end;

function TWebServicesHelper.AddDextTemplating(AConfig: TProc<TViewOptions>): TDextServices;
var
  ConfigProc: TProc<TViewOptions>;
begin
  ConfigProc := AConfig;
  Result := Self.AddSingleton(TServiceType.FromInterface(TypeInfo(IViewEngine)), TDextNativeViewEngine,
    function(Provider: IServiceProvider): TObject
    var
      Options: TViewOptions;
    begin
      Options := TViewOptions.Create;
      if Assigned(ConfigProc) then
        ConfigProc(Options);
      Result := TDextNativeViewEngine.Create(Options);
    end);
end;

function TWebServicesHelper.AddDextTemplating(const AOptions: TViewOptions): TDextServices;
var
  Options: TViewOptions;
begin
  Options := AOptions;
  Result := Self.AddSingleton(TServiceType.FromInterface(TypeInfo(IViewEngine)), TDextNativeViewEngine,
    function(Provider: IServiceProvider): TObject
    begin
      Result := TDextNativeViewEngine.Create(Options);
    end);
end;

function TWebServicesHelper.AddDextTemplating(const ABuilder: TViewOptionsBuilder): TDextServices;
var
  OptionsBuilder: TViewOptionsBuilder;
begin
  OptionsBuilder := ABuilder;
  Result := Self.AddSingleton(TServiceType.FromInterface(TypeInfo(IViewEngine)), TDextNativeViewEngine,
    function(Provider: IServiceProvider): TObject
    begin
      Result := TDextNativeViewEngine.Create(TViewOptions(OptionsBuilder));
    end);
end;

function THttpAppBuilderHelper.UseViewEngine: AppBuilder;
begin
  Result := Self;
end;

function TWebServicesHelper.AddStreamableSessions: TDextServices;
begin
  Result := Self.AddSingleton(TServiceType.FromInterface(TypeInfo(IStreamableSessionManager)), TInMemoryStreamableSessionManager,
    function(Provider: IServiceProvider): TObject
    begin
      Result := TInMemoryStreamableSessionManager.Create;
    end);
end;

function THttpAppBuilderHelper.UseStreamableSessions(AIntervalSeconds,
  ATimeoutMinutes: Integer): AppBuilder;
var
  Interval, Timeout: Integer;
  Started: Boolean;
begin
  Result := Self;
  Interval := AIntervalSeconds;
  Timeout  := ATimeoutMinutes;
  Started  := False;

  // Lazy middleware: Scavenger starts on the first real request,
  // when Ctx.Services is guaranteed to be fully built.
  // (During TWebHostBuilder.Configure, GetServiceProvider is still nil.)
  Self.Unwrap.Use(
    procedure(Ctx: IHttpContext; Next: TRequestDelegate)
    var
      Manager: IStreamableSessionManager;
      LifetimeIntf: IInterface;
      StoppingToken: ICancellationToken;
    begin
      if not Started then
      begin
        Manager := TDextServices.GetService<IStreamableSessionManager>(Ctx.Services);
        if Assigned(Manager) then
        begin
          // Resolve host ApplicationStopping token - Scavenger exits within 500ms
          // when the host begins shutdown, aligned with the framework's CT pattern.
          StoppingToken := nil;
          LifetimeIntf := Ctx.Services.GetServiceAsInterface(
            TServiceType.FromInterface(IHostApplicationLifetime));
          if LifetimeIntf <> nil then
            StoppingToken := (LifetimeIntf as IHostApplicationLifetime).ApplicationStopping;

          Manager.StartScavenger(Interval, Timeout, StoppingToken);
          Started := True;
        end
        else
          raise Exception.Create(
            'IStreamableSessionManager not registered. ' +
            'Call Services.AddStreamableSessions before App.UseStreamableSessions.');
      end;
      Next(Ctx);
    end);
end;

end.



