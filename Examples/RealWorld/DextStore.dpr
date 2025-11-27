program DextStore;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext,
  DextStore.Models in 'DextStore.Models.pas',
  DextStore.Services in 'DextStore.Services.pas',
  DextStore.Controllers in 'DextStore.Controllers.pas';

begin
  try
    WriteLn('🛒 Starting DextStore API...');
    
    var App: IWebApplication := TDextApplication.Create;

    // 1. Dependency Injection
    App.Services
      // Register Services (Singleton for In-Memory Persistence)
      .AddSingleton<IProductService, TProductService>
      .AddSingleton<ICartService, TCartService>
      .AddSingleton<IOrderService, TOrderService>
      // Register Controllers
      .AddControllers;

    // 2. Middleware Pipeline
    var AppBuilder := App.Builder;

    // Global Error Handling (if not using built-in exception handler yet)
    // Dext has default exception handling, but we can add custom if needed.

    // CORS
    var Cors := AppBuilder.CreateCorsOptions;
    Cors.AllowedOrigins := ['*']; // Allow all for demo
    Cors.AllowedMethods := ['GET', 'POST', 'PUT', 'DELETE'];
    AppBuilder.UseCors(Cors);

    // Authentication
    var Auth := AppBuilder.CreateJwtOptions('dext-store-secret-key-must-be-very-long-and-secure');
    Auth.Issuer := 'dext-store';
    Auth.Audience := 'dext-users';
    AppBuilder.UseJwtAuthentication(Auth);

    // Minimal API Health Check
    AppBuilder.MapGet('/health', 
      procedure(Ctx: IHttpContext)
      begin
        Ctx.Response.Json('{"status": "healthy", "timestamp": "' + DateTimeToStr(Now) + '"}');
      end
    );

    // Routing & Controllers
    App.MapControllers;

    // 3. Run
    WriteLn('🚀 Server running on http://localhost:9000');
    App.Run(9000);
    
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
