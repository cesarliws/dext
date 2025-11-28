program ControllerExampleFluentAPI;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Rtti,
  Dext; // ✅ The only core unit needed!

begin
  try
    WriteLn('🚀 Starting Dext Controller Example with Fluent API...');
    var App: IWebApplication := TDextApplication.Create;

    // 1. Register Configuration (IOptions)
    App.Services.Configure<TMySettings>(
      App.Configuration.GetSection('AppSettings')
    );

    // 2. Register Services
    App.Services
      .AddSingleton<IGreetingService, TGreetingService>
      .AddControllers;
    
    // 3. Register Health Checks
    App.Services.AddHealthChecks
      .AddCheck<TDatabaseHealthCheck>
      .Build;

    // 4. Register Background Services
    App.Services.AddBackgroundServices
      .AddHostedService<TWorkerService>
      .Build;

    // 5. Configure Middleware Pipeline
    var Builder := App.Builder;

    // ✨ CORS with Fluent API
    Builder.UseCors(procedure(Cors: TCorsBuilder)
    begin
      Cors.WithOrigins(['http://localhost:5173'])
          .WithMethods(['GET', 'POST', 'PUT', 'DELETE'])
          .AllowAnyHeader
          .AllowCredentials
          .WithMaxAge(3600);
    end);

    // Static Files
    Builder.UseStaticFiles(Builder.CreateStaticFileOptions);
    
    // Health Checks
    App.UseMiddleware(THealthCheckMiddleware);

    // ✨ JWT Authentication with Fluent API
    Builder.UseJwtAuthentication('dext-secret-key-must-be-very-long-and-secure-at-least-32-chars',
      procedure(Auth: TJwtOptionsBuilder)
      begin
        Auth.WithIssuer('dext-issuer')
            .WithAudience('dext-audience')
            .WithExpirationMinutes(60);
      end
    );
       
    // 6. Map Controllers
    App.MapControllers;

    // 7. Run Application
    WriteLn('✅ Server running on http://localhost:8080');
    WriteLn('📚 Endpoints:');
    WriteLn('   GET  /api/hello');
    WriteLn('   POST /api/login');
    WriteLn('   GET  /api/protected (requires JWT)');
    WriteLn('   GET  /health');
    WriteLn;
    App.Run(8080);
  except
    on E: Exception do
      Writeln('❌ Error: ', E.ClassName, ': ', E.Message);
  end;
end.
