unit Dext;

interface

uses
  System.SysUtils,
  System.Classes,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Auth.Attributes,
  Dext.Auth.Identity,
  Dext.Auth.JWT,
  Dext.Auth.Middleware,
  Dext.Configuration.Interfaces,
  Dext.Core.Activator,
  Dext.Core.CancellationToken,
  Dext.Core.Controllers,
  Dext.Core.ControllerScanner,
  Dext.Core.Memory,
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
  Dext.Http.Results,
  Dext.Http.StaticFiles,
  Dext.OpenAPI.Attributes,
  Dext.Options,
  Dext.Options.Extensions,
  Dext.Validation;

type
  // ===========================================================================
  // 🏷️ Aliases for Common Types (Facade)
  // ===========================================================================
  
  // Core
  IWebApplication = Dext.Http.Interfaces.IWebApplication;
  TDextApplication = Dext.Core.WebApplication.TDextApplication;
  
  // HTTP
  IHttpContext = Dext.Http.Interfaces.IHttpContext;
  IHttpRequest = Dext.Http.Interfaces.IHttpRequest;
  IHttpResponse = Dext.Http.Interfaces.IHttpResponse;
  IMiddleware = Dext.Http.Interfaces.IMiddleware;
  TRequestDelegate = Dext.Http.Interfaces.TRequestDelegate;
  TStaticHandler = Dext.Http.Interfaces.TStaticHandler;
  
  // DI
  IServiceCollection = Dext.DI.Interfaces.IServiceCollection;
  IServiceProvider = Dext.DI.Interfaces.IServiceProvider;
  TServiceType = Dext.DI.Interfaces.TServiceType;
  
  // Configuration
  IConfiguration = Dext.Configuration.Interfaces.IConfiguration;
  IConfigurationSection = Dext.Configuration.Interfaces.IConfigurationSection;
  
  // Results
  IResult = Dext.Http.Interfaces.IResult;
  Results = Dext.Http.Results.Results;

  // Middleware
  THealthCheckMiddleware = Dext.HealthChecks.THealthCheckMiddleware;
  
  // CORS
  TCorsOptions = Dext.Http.Cors.TCorsOptions;
  TCorsBuilder = Dext.Http.Cors.TCorsBuilder;
  
  // Auth
  TJwtOptions = Dext.Auth.JWT.TJwtOptions;
  TJwtOptionsBuilder = Dext.Auth.JWT.TJwtOptionsBuilder;
  TJwtAuthenticationMiddleware = Dext.Auth.Middleware.TJwtAuthenticationMiddleware;
  
  // Static Files
  TStaticFileOptions = Dext.Http.StaticFiles.TStaticFileOptions;

  // Attributes & Routing
  DextControllerAttribute = Dext.Core.Routing.DextControllerAttribute;
  DextGetAttribute = Dext.Core.Routing.DextGetAttribute;
  DextPostAttribute = Dext.Core.Routing.DextPostAttribute;
  DextPutAttribute = Dext.Core.Routing.DextPutAttribute;
  DextDeleteAttribute = Dext.Core.Routing.DextDeleteAttribute;
  
  // Model Binding & Validation
  FromQueryAttribute = Dext.Core.ModelBinding.FromQueryAttribute;
  FromRouteAttribute = Dext.Core.ModelBinding.FromRouteAttribute;
  FromBodyAttribute = Dext.Core.ModelBinding.FromBodyAttribute;
  FromServicesAttribute = Dext.Core.ModelBinding.FromServicesAttribute;
  RequiredAttribute = Dext.Validation.RequiredAttribute;
  StringLengthAttribute = Dext.Validation.StringLengthAttribute;

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

  // Health Checks & Background Services
  IHealthCheck = Dext.HealthChecks.IHealthCheck;
  THealthCheckResult = Dext.HealthChecks.THealthCheckResult;
  TBackgroundService = Dext.Hosting.BackgroundService.TBackgroundService;
  ICancellationToken = Dext.Core.CancellationToken.ICancellationToken;

  // Memory Management
  IDeferred = Dext.Core.Memory.IDeferred;

  /// <summary>
  ///   Smart pointer record that automatically frees the object when it goes out of scope.
  ///   Uses an internal interface to support ARC (Automatic Reference Counting).
  /// </summary>
  Auto<T: class> = record
  private
    FLifetime: Dext.Core.Memory.ILifetime<T>;
    function GetValue: T;
  public
    constructor Create(AValue: T);
    
    /// <summary>
    ///   Access the underlying object.
    /// </summary>
    property Value: T read GetValue;
    
    /// <summary>
    ///   Implicitly converts the object to Auto&lt;T&gt;.
    /// </summary>
    class operator Implicit(const AValue: T): Auto<T>;
    
    /// <summary>
    ///   Implicitly converts Auto&lt;T&gt; to the object.
    /// </summary>
    class operator Implicit(const AAuto: Auto<T>): T;
  end;

  Auto = class abstract
  public
    class function Create<T: class>: Auto<T>;
  end;

  /// <summary>
  ///   Factory for creating interface-based objects with automatic reference counting (ARC).
  ///   This eliminates the need for try...finally blocks when working with interfaces.
  ///   
  ///   Example 1 - Parameterless constructor:
  ///   <code>
  ///   var Builder := Factory.Create&lt;TClaimsBuilder, IClaimsBuilder&gt;;
  ///   var Claims := Builder.WithName('John').WithRole('Admin').Build;
  ///   // Automatically freed when Builder goes out of scope
  ///   </code>
  ///   
  ///   Example 2 - Constructor with parameters:
  ///   <code>
  ///   var Handler := Factory.Create&lt;IJwtTokenHandler&gt;(
  ///     TJwtTokenHandler.Create('secret', 'issuer', 'audience', 120)
  ///   );
  ///   var Token := Handler.GenerateToken(Claims);
  ///   // Automatically freed when Handler goes out of scope
  ///   </code>
  /// </summary>
  Factory = class abstract
  public
    /// <summary>
    ///   Creates an instance of T using its parameterless constructor and returns as interface I.
    ///   Use this overload when the class has a default constructor.
    /// </summary>
    class function Create<T: class, constructor; I: IInterface>: I; overload;
    
    /// <summary>
    ///   Wraps an existing instance and returns as interface I.
    ///   Use this overload when you need to pass parameters to the constructor.
    ///   The instance will be automatically freed when the interface goes out of scope.
    /// </summary>
    class function Create<I: IInterface>(Instance: TInterfacedObject): I; overload;
  end;

  TActivator = Dext.Core.Activator.TActivator;

  // ===========================================================================
  // 🛠️ Fluent Helpers & Wrappers
  // ===========================================================================

  /// <summary>
  ///   Helper for TDextServices to add framework features.
  /// </summary>
  TDextServicesHelper = record helper for TDextServices
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
    /// </summary>
    function Configure<T: class, constructor>(Configuration: IConfiguration): TDextServices; overload;
    
    /// <summary>
    ///   Configures a settings class (IOptions&lt;T&gt;) from a specific configuration section.
    /// </summary>
    function Configure<T: class, constructor>(Section: IConfigurationSection): TDextServices; overload;
  end;



  /// <summary>
  ///   Helper for TDextAppBuilder to provide factory methods and extensions for middleware configuration.
  /// </summary>
  TDextAppBuilderHelper = record helper for TDextAppBuilder
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
    ///   Adds JWT Authentication middleware to the pipeline using a configuration delegate.
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

  /// <summary>
  ///   Schedules an action to be executed when the returned interface goes out of scope.
  /// </summary>
  function Defer(AAction: TProc): IDeferred;

implementation


{ Auto<T> }

constructor Auto<T>.Create(AValue: T);
begin
  if AValue <> nil then
    FLifetime := Dext.Core.Memory.TLifetime<T>.Create(AValue)
  else
    FLifetime := nil;
end;

function Auto<T>.GetValue: T;
begin
  if FLifetime <> nil then
    Result := FLifetime.GetValue
  else
    Result := nil;
end;

class operator Auto<T>.Implicit(const AValue: T): Auto<T>;
begin
  Result := Auto<T>.Create(AValue);
end;

class operator Auto<T>.Implicit(const AAuto: Auto<T>): T;
begin
  Result := AAuto.Value;
end;

{ TDextServicesHelper }

function TDextServicesHelper.AddControllers: TDextServices;
var
  Scanner: IControllerScanner;
begin
  Scanner := TControllerScanner.Create(nil);
  Scanner.RegisterServices(Self.Unwrap);
  Result := Self;
end;

function TDextServicesHelper.AddHealthChecks: THealthCheckBuilder;
begin
  Result := THealthCheckBuilder.Create(Self.Unwrap);
end;

function TDextServicesHelper.AddBackgroundServices: TBackgroundServiceBuilder;
begin
  Result := TBackgroundServiceBuilder.Create(Self.Unwrap);
end;

function TDextServicesHelper.Configure<T>(Configuration: IConfiguration): TDextServices;
begin
  TOptionsServiceCollectionExtensions.Configure<T>(Self.Unwrap, Configuration);
  Result := Self;
end;

function TDextServicesHelper.Configure<T>(Section: IConfigurationSection): TDextServices;
begin
  TOptionsServiceCollectionExtensions.Configure<T>(Self.Unwrap, Section);
  Result := Self;
end;

function Defer(AAction: TProc): IDeferred;
begin
  Result := Dext.Core.Memory.TDeferredAction.Create(AAction);
end;

{ TDextAppBuilderHelper }

function TDextAppBuilderHelper.CreateCorsOptions: TCorsOptions;
begin
  Result := TCorsOptions.Create;
end;

function TDextAppBuilderHelper.CreateJwtOptions(const Secret: string): TJwtOptions;
begin
  Result := TJwtOptions.Create(Secret);
end;

function TDextAppBuilderHelper.CreateStaticFileOptions: TStaticFileOptions;
begin
  Result := TStaticFileOptions.Create;
end;

function TDextAppBuilderHelper.UseCors(const AOptions: TCorsOptions): TDextAppBuilder;
begin
  TApplicationBuilderCorsExtensions.UseCors(Self.Unwrap, AOptions);
  Result := Self;
end;

function TDextAppBuilderHelper.UseCors(AConfigurator: TProc<TCorsBuilder>): TDextAppBuilder;
begin
  TApplicationBuilderCorsExtensions.UseCors(Self.Unwrap, AConfigurator);
  Result := Self;
end;

function TDextAppBuilderHelper.UseJwtAuthentication(const AOptions: TJwtOptions): TDextAppBuilder;
begin
  TApplicationBuilderJwtExtensions.UseJwtAuthentication(Self.Unwrap, AOptions);
  Result := Self;
end;

function TDextAppBuilderHelper.UseJwtAuthentication(const ASecretKey: string; AConfigurator: TProc<TJwtOptionsBuilder>): TDextAppBuilder;
begin
  TApplicationBuilderJwtExtensions.UseJwtAuthentication(Self.Unwrap, ASecretKey, AConfigurator);
  Result := Self;
end;

function TDextAppBuilderHelper.UseStaticFiles(const AOptions: TStaticFileOptions): TDextAppBuilder;
begin
  TApplicationBuilderStaticFilesExtensions.UseStaticFiles(Self.Unwrap, AOptions);
  Result := Self;
end;

function TDextAppBuilderHelper.UseStaticFiles(const ARootPath: string): TDextAppBuilder;
begin
  TApplicationBuilderStaticFilesExtensions.UseStaticFiles(Self.Unwrap, ARootPath);
  Result := Self;
end;

function TDextAppBuilderHelper.UseMiddleware(AMiddleware: TClass): TDextAppBuilder;
begin
  Self.Unwrap.UseMiddleware(AMiddleware);
  Result := Self;
end;

function TDextAppBuilderHelper.MapGet(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
begin
  Self.Unwrap.MapGet(Path, Handler);
  Result := Self;
end;

function TDextAppBuilderHelper.MapPost(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
begin
  Self.Unwrap.MapPost(Path, Handler);
  Result := Self;
end;

function TDextAppBuilderHelper.MapPut(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
begin
  Self.Unwrap.MapPut(Path, Handler);
  Result := Self;
end;

function TDextAppBuilderHelper.MapDelete(const Path: string; Handler: TStaticHandler): TDextAppBuilder;
begin
  Self.Unwrap.MapDelete(Path, Handler);
  Result := Self;
end;

function TDextAppBuilderHelper.Build: TRequestDelegate;
begin
  Result := Self.Unwrap.Build;
end;

{ Auto }

class function Auto.Create<T>: Auto<T>;
begin
  Result := TActivator.CreateInstance<T>([]);
end;

{ Factory }

class function Factory.Create<T, I>: I;
var
  Instance: TObject;
begin
  Instance := TActivator.CreateInstance<T>([]);
  if not Supports(Instance, GetTypeData(TypeInfo(I))^.Guid, Result) then
  begin
    Instance.Free;
    raise Exception.CreateFmt('Class %s does not implement interface %s', 
      [T.ClassName, GetTypeName(TypeInfo(I))]);
  end;
end;

class function Factory.Create<I>(Instance: TInterfacedObject): I;
begin
  if not Supports(Instance, GetTypeData(TypeInfo(I))^.Guid, Result) then
  begin
    Instance.Free;
    raise Exception.CreateFmt('Instance does not implement interface %s', 
      [GetTypeName(TypeInfo(I))]);
  end;
end;

end.
