unit EventHub.Startup;

{***************************************************************************}
{                                                                           }
{           Web.EventHub - Application Startup                              }
{                                                                           }
{           Configuration of services, middleware, and routing              }
{                                                                           }
{***************************************************************************}

interface

uses
  // 1. Delphi Units
  System.SysUtils,
  // 2. Dext, Dext.DI.Interfaces Specialized Units
  Dext.Auth.Middleware,
  Dext.Caching,
  Dext.Entity.Core,
  Dext.Logging,
  Dext.RateLimiting,
  Dext.RateLimiting.Policy,
  Dext.Core.SmartTypes,
  Dext.Collections,
  // 3. Dext, Dext.DI.Interfaces Facades (ALWAYS LAST in Dext, Dext.DI.Interfaces Group)
  Dext, Dext.DI.Interfaces,
  Dext.Entity,
  Dext.Web;

type
  TStartup = class(TInterfacedObject, IStartup)
  private
    const JWT_SECRET = 'eventhub-super-secret-key-minimum-32-characters!';
    const JWT_ISSUER = 'eventhub-api';
    const JWT_AUDIENCE = 'eventhub-clients';
    const JWT_EXPIRATION_MINUTES = 120;

    procedure ConfigureDatabase(Options: TDbContextOptions);
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

implementation

uses
  EventHub.Data.Context,
  EventHub.Services,
  EventHub.Endpoints;

{ TStartup }

procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseSQLite('EventHub.db')
    .UseSnakeCaseNamingConvention
    .WithPooling;
end;

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    // Database Context
    .AddDbContext<TEventHubDbContext>(ConfigureDatabase)

    // JWT Token Handler (Singleton - stateless)
    .AddSingleton<IJwtTokenHandler, TJwtTokenHandler>(
      function(Provider: IServiceProvider): TObject
      begin
        Result := TJwtTokenHandler.Create(JWT_SECRET, JWT_ISSUER, JWT_AUDIENCE, JWT_EXPIRATION_MINUTES);
      end)
    .AddTransient<IClaimsBuilder, TClaimsBuilder>

    // Business Services (Scoped - one per request)
    .AddScoped<IEventService, TEventService>
    .AddScoped<ISpeakerService, TSpeakerService>
    .AddScoped<IAttendeeService, TAttendeeService>
    .AddScoped<IRegistrationService, TRegistrationService>;
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  // Global JSON settings: camelCase, case-insensitive, ISO dates
  JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive.ISODateFormat);

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
        .ExpirationMinutes(JWT_EXPIRATION_MINUTES)
    )
    // 5. Rate Limiting (200 requests per minute)
    .UseRateLimiting(
      RateLimitPolicy
        .FixedWindow(200, 60)
        .RejectionMessage('Too many requests. Please slow down.')
        .RejectionStatusCode(429))
    // 6. Response Cache
    .UseResponseCache(
      ResponseCacheOptions
        .DefaultDuration(15)
        .VaryByQueryString
    )
    // 7. Map Minimal API Endpoints
    .MapEndpoints(TEventHubEndpoints.MapEndpoints)
    // 8. Swagger (AFTER routes are mapped)
    .UseSwagger(SwaggerOptions
      .Title('EventHub API')
      .Description('Event Management & Registration Platform - Built with Dext Framework')
      .Version('v1')
      .BearerAuth);
end;

end.
