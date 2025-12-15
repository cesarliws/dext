program Web.DextStore;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext,
  Dext.Web,
  DextStore.Models in 'DextStore.Models.pas',
  DextStore.Services in 'DextStore.Services.pas',
  DextStore.Controllers in 'DextStore.Controllers.pas';

begin
  try
    WriteLn('?? Starting DextStore API...');
    
    var App: IWebApplication := TDextApplication.Create;
    var AppBuilder := App.Builder;

    // 1. Dependency Injection
    const JwtSecret = 'dext-store-secret-key-must-be-very-long-and-secure';
    const JwtIssuer = 'dext-store';
    const JwtAudience = 'dext-users';
    const JwtExpiration = 120;

    App.Services
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

    // 2. Middleware Pipeline
    // ? CORS with Fluent API
    AppBuilder
      .UseCors(procedure(Cors: TCorsBuilder)
      begin
        Cors.AllowAnyOrigin  // Allow all for demo
            .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
            .AllowAnyHeader
            .Build;
      end)

      // ? JWT Authentication with Fluent API
      .UseJwtAuthentication(JwtSecret,
      procedure(Auth: TJwtOptionsBuilder)
      begin
        Auth.WithIssuer(JwtIssuer)
            .WithAudience(JwtAudience)
            .WithExpirationMinutes(JwtExpiration);
      end)

      // Minimal API Health Check
      .MapGet('/health',
      procedure(Ctx: IHttpContext)
      begin
        Ctx.Response.Json('{"status": "healthy", "timestamp": "' + DateTimeToStr(Now) + '"}');
      end);

    // Routing & Controllers
    App.MapControllers;

    // 3. Run
    WriteLn('?? Server running on http://localhost:9000');
    WriteLn('');
    WriteLn('?? Available Endpoints:');
    WriteLn('  Authentication:');
    WriteLn('    POST /api/auth/login       - Login and get JWT token');
    WriteLn('');
    WriteLn('  Products:');
    WriteLn('    GET  /api/products         - List all products');
    WriteLn('    GET  /api/products/{id}    - Get product by ID');
    WriteLn('');
    WriteLn('  Cart (requires authentication):');
    WriteLn('    POST /api/cart/add         - Add item to cart');
    WriteLn('    GET  /api/cart             - Get cart items');
    WriteLn('    POST /api/cart/clear       - Clear cart');
    WriteLn('');
    WriteLn('  Orders (requires authentication):');
    WriteLn('    POST /api/orders/checkout  - Checkout cart');
    WriteLn('    GET  /api/orders           - Get user orders');
    WriteLn('');
    WriteLn('  Health:');
    WriteLn('    GET  /health               - Health check');
    WriteLn('');
    WriteLn('Press Ctrl+C to stop the server...');
    WriteLn('');
    
    App.Run(9000);
    
  except
    on E: Exception do
      Writeln('? Error: ', E.ClassName, ': ', E.Message);
  end;
end.
