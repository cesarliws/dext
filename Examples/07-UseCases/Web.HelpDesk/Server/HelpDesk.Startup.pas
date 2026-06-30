unit HelpDesk.Startup;

{***************************************************************************}
{                                                                           }
{           Web.HelpDesk - Application Startup                              }
{                                                                           }
{           Configure Services, Middleware Pipeline, and Endpoints           }
{                                                                           }
{***************************************************************************}

interface

uses
  System.SysUtils,
  Dext.Entity.Core,     // Naming Strategy
  Dext.Logging,         // HttpLogging
  Dext.RateLimiting,
  Dext.RateLimiting.Policy,
  Dext, Dext.DI.Interfaces,        // Facade
  Dext.Web,    // Facade
  Dext.Entity; // Facade

type
  TStartup = class(TInterfacedObject, IStartup)
  private
    procedure ConfigureDatabase(Options: TDbContextOptions);
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

implementation

uses
  HelpDesk.Data.Context,
  HelpDesk.Services,
  HelpDesk.Endpoints;

{ TStartup }

procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options.UseSQLite('HelpDesk.db');
  Options.UseSnakeCaseNamingConvention;
end;

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    // 1. Data Access
    .AddDbContext<THelpDeskContext>(ConfigureDatabase)
    // 2. Domain Services (Scoped - one per request)
    .AddScoped<IUserService, TUserService>
    .AddScoped<ITicketService, TTicketService>;
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  // Global Settings
  JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive.ISODateFormat);

  App.Builder
    .UseExceptionHandler
    .UseHttpLogging
    .UseCors(CorsOptions.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader)
    .UseRateLimiting(RateLimitPolicy.FixedWindow(100, 60))
    // Map Endpoints (Minimal API)
    .MapEndpoints(TEndpoints.MapEndpoints)
    // Swagger (AFTER endpoints)
    .UseSwagger(SwaggerOptions
      .Title('HelpDesk API')
      .Version('v1')
      .Description('Issue Tracking System - Minimal API'));
end;

end.
