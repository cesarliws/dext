unit Sales.Startup;

interface

uses
  // 1. Delphi Units
  System.SysUtils,
  // 3. Dext, Dext.DI.Interfaces Specialized Units
  Dext.Auth.Middleware,
  Dext.Caching,
  Dext.Entity.Core,
  Dext.Logging,
  Dext.RateLimiting,
  Dext.RateLimiting.Policy,
  Dext.Web.DataApi,
  Dext.Core.SmartTypes,
  Dext.Collections,
  // 4. Dext, Dext.DI.Interfaces Facades Last to ensure precedence and valid helpers
  Dext, Dext.DI.Interfaces,
  Dext.Entity,
  Dext.Web,
  // 5. Current Project Units
  Sales.Auth,
  Sales.Data.Context,
  Sales.Domain.Entities,
  Sales.Domain.Models,
  Sales.Domain.Enums,
  Sales.Endpoints;

type
  TStartup = class(TInterfacedObject, IStartup)
  public
    const AuthSecret: string = 'my-super-secret-key-for-sales-system-minimum-32-chars';
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  private
    procedure ConfigureDatabase(Options: TDbContextOptions);
  end;

implementation

uses
  System.JSON,
  System.DateUtils,
  Dext.Web.Results,
  Dext.Auth.JWT, 
  Dext.Web.Cors; 

{ TStartup }

procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options.UseSQLite('SalesSystem.db').UseSnakeCaseNamingConvention;
end;

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    .AddDbContext<TSalesDbContext>(ConfigureDatabase)
    {$IFNDEF MODEL_BINDING_ARRAY}
    .AddTransient<IList<TOrderItemDto>, TSmartList<TOrderItemDto>>
    {$ENDIF}
    .AddSingleton<IAuthService, TAuthService>(
    function(P: IServiceProvider): TObject
    begin
      Result := TAuthService.Create(AuthSecret);
    end);
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  // ✨ Configurações globais de JSON
  JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive);

  App.Builder
    .UseExceptionHandler
    .UseHttpLogging
    .UseCors(CorsOptions.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader)
    .UseJwtAuthentication(JwtOptions(AuthSecret))
    .UseRateLimiting(RateLimitPolicy.FixedWindow(100, 60))
    .UseResponseCache(
      ResponseCacheOptions
        .DefaultDuration(30)
        .VaryByQueryString)
    .MapEndpoints(TSalesEndpoints.MapEndpoints)
    .UseSwagger(
      SwaggerOptions
        .Title('Sales System CQRS API')
        .Version('v1'));
end;

end.
