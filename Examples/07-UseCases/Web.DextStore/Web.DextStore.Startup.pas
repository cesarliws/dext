unit Web.DextStore.Startup;

interface

uses
  System.SysUtils,
  Dext, Dext.DI.Interfaces,
  Dext.Web,
  Dext.Auth.JWT,
  Dext.Web.Cors;

type
  TStartup = class(TInterfacedObject, IStartup)
  private
    const JwtSecret = 'dext-store-secret-key-must-be-very-long-and-secure';
    const JwtIssuer = 'dext-store';
    const JwtAudience = 'dext-users';
    const JwtExpiration = 120;
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

implementation

uses
  DextStore.Models,
  DextStore.Services,
  DextStore.Controllers;

{ TStartup }

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services
    // Register JWT Token Handler
    .AddSingleton<IJwtTokenHandler, TJwtTokenHandler>(
      function(Provider: IServiceProvider): TObject
      begin
        Result := TJwtTokenHandler.Create(JwtSecret, JwtIssuer, JwtAudience, JwtExpiration);
      end)
    .AddTransient<IClaimsBuilder, TClaimsBuilder>
    // Register Services (Singleton for In-Memory Persistence)
    .AddSingleton<IProductService, TProductService>
    .AddSingleton<ICartService, TCartService>
    .AddSingleton<IOrderService, TOrderService>
    // Register Controllers
    .AddControllers;
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
(*
    // 4. JWT Authentication
    .UseJwtAuthentication(
      JwtOptions(JWT_SECRET)
        .Issuer(JWT_ISSUER)
        .Audience(JWT_AUDIENCE)
        .ExpirationMinutes(JWT_EXPIRATION_MINUTES)
    )
*)
  App.Builder
    // ✨ CORS with Fluent API
    .UseCors(CorsOptions.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader)
    // ✨ JWT Authentication
    .UseJwtAuthentication(
      JwtOptions(JwtSecret)
        .Issuer(JwtIssuer)
        .Audience(JwtAudience)
        .ExpirationMinutes(JwtExpiration))
    // Minimal API Health Check
    .MapGet('/health',
      procedure(Ctx: IHttpContext)
      begin
        Ctx.Response.Json('{"status": "healthy", "timestamp": "' + DateTimeToStr(Now) + '"}');
      end);

  // Routing & Controllers
  App.MapControllers;
end;

end.
