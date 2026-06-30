unit TicketSales.Startup;

{***************************************************************************}
{                                                                           }
{           Web.TicketSales - Application Startup                           }
{                                                                           }
{           Configuration of services, middleware, and routing              }
{                                                                           }
{***************************************************************************}

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
  Dext.Web;

type
  TStartup = class(TInterfacedObject, IStartup)
  private
    const JWT_SECRET = 'ticket-sales-super-secret-key-minimum-32-characters';
    const JWT_ISSUER = 'ticket-sales-api';
    const JWT_AUDIENCE = 'ticket-sales-clients';
    const JWT_EXPIRATION_MINUTES = 120;
    
    procedure ConfigureDatabase(Options: TDbContextOptions);
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

implementation

uses
  TicketSales.Data.Context,
  TicketSales.Services,
  TicketSales.Controllers;

{ TStartup }

procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options.UseSQLite('TicketSales.db');
  // Options.UseSnakeCaseNamingConvention;
end;

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    // Logging infrastructure with Telemetry Bridge
    .AddLogging(
      procedure(Builder: ILoggingBuilder)
      begin
        Builder
          .SetMinimumLevel(TLogLevel.Information)
          .AddConsole
          .AddTelemetry;
      end)
    // Database Context
    .AddDbContext<TTicketSalesDbContext>(ConfigureDatabase)
    // JWT Token Handler
    .AddSingleton<IJwtTokenHandler, TJwtTokenHandler>(
      function(Provider: IServiceProvider): TObject
      begin
        Result := TJwtTokenHandler.Create(JWT_SECRET, JWT_ISSUER, JWT_AUDIENCE, JWT_EXPIRATION_MINUTES);
      end)
    .AddTransient<IClaimsBuilder, TClaimsBuilder>
    // Business Services (Scoped - one per request)
    .AddScoped<IEventService, TEventService>
    .AddScoped<ITicketTypeService, TTicketTypeService>
    .AddScoped<ICustomerService, TCustomerService>
    .AddScoped<IOrderService, TOrderService>
    .AddScoped<ITicketService, TTicketService>
    // Register Controllers
    .AddControllers;
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  // Global JSON settings: camelCase, case-insensitive
  JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive);

  App.Builder
    // 1. Exception Handler (first middleware)
    .UseExceptionHandler
    // 2. HTTP Logging
    .UseHttpLogging
    // 3. CORS
    .UseCors(CorsOptions.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader)
    // 4. JWT Authentication
    .UseJwtAuthentication(
      JwtOptions(JWT_SECRET)
        .Issuer(JWT_ISSUER)
        .Audience(JWT_AUDIENCE)
        .ExpirationMinutes(JWT_EXPIRATION_MINUTES))
    // 5. Rate Limiting (100 requests per minute)
    .UseRateLimiting(
      RateLimitPolicy.FixedWindow(100, 60)
        .RejectionMessage('Too many requests. Please try again later.')
        .RejectionStatusCode(429))
    // 6. Response Cache
    .UseResponseCache(
      ResponseCacheOptions
        .DefaultDuration(30)
        .VaryByQueryString);

    // 7. Map Controllers
    App.MapControllers;

    // 8. Swagger (last, after routes are mapped)
    App.Builder.UseSwagger(
      SwaggerOptions
        .Title('Ticket Sales API')
        .Description('API for managing event ticket sales')
        .Version('v1')
        .BearerAuth);
end;

end.
