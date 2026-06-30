program Web.ControllerExample.FluentAPI;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext, Dext.DI.Interfaces,
  Dext.Web,
  Dext.Utils,
  ControllerExample.Setup in 'ControllerExample.Setup.pas',
  ControllerExample.Services in 'ControllerExample.Services.pas',
  ControllerExample.Controller in 'ControllerExample.Controller.pas';

var
  App: IWebApplication;
  Builder: TAppBuilder;
begin
  SetConsoleCharSet;
  try
    WriteLn('🚀 Starting Dext Controller Example with Fluent API...');
    
    // Create appsettings.json if it doesn't exist
    EnsureAppSettingsExists;
    
    App := TDextApplication.Create;

    // 1. Register Configuration (IOptions)
    App.Services
      .Configure<TMySettings>(App.Configuration.GetSection('AppSettings'))
      .AddSingleton<IGreetingService, TGreetingService>
      .AddControllers
      // 3. Register Health Checks
      .AddHealthChecks
        .AddCheck<TDatabaseHealthCheck>
        .Build;

    // 4. Register Background Services
    App.Services.AddBackgroundServices
      .AddHostedService<TWorkerService>
      .Build;

    // 5. Configure Middleware Pipeline
    Builder := App.Builder;

    // ✨ CORS with Fluent API
    Builder
      .UseCors(
        CorsOptions
          .Origins(['http://localhost:5173'])
          .Methods(['GET', 'POST', 'PUT', 'DELETE'])
          .AllowAnyHeader
          .AllowCredentials
          .MaxAge(3600))
      // Static Files
      .UseStaticFiles(Builder.CreateStaticFileOptions);

    // Health Checks
    App.UseMiddleware(THealthCheckMiddleware);

    // ✨ JWT Authentication with Fluent API
    Builder.UseJwtAuthentication(
      JwtOptions('dext-secret-key-must-be-very-long-and-secure-at-least-32-chars')
        .Issuer('dext-issuer')
        .Audience('dext-audience')
        .ExpirationMinutes(60));
       
    // 6. Map Controllers
    App.MapControllers;

    // 6.1 Map Versioned API Examples
    RegisterVersionedRoutes(App.Builder);

    // 7. Run Application
    PrintFeatureInstructions;
    App.Run(8080);
  except
    on E: Exception do
      Writeln('❌ Error: ', E.ClassName, ': ', E.Message);
  end;
  ConsolePause;
end.
