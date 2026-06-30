program Web.ControllerExample;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext, Dext.DI.Interfaces,
  Dext.Web,
  Dext.Utils,
  Dext.Web.Middleware.Logging,
  ControllerExample.Setup in 'ControllerExample.Setup.pas',
  ControllerExample.Controller in 'ControllerExample.Controller.pas',
  ControllerExample.Services in 'ControllerExample.Services.pas';

var
  App: IWebApplication;
  Builder: TAppBuilder;
  AuthOptions: TJwtOptions;
begin
  SetConsoleCharSet(65001); // Fix console encoding
  try
    WriteLn('🚀 Starting Dext Controller Example...');
    
    // Create appsettings.json if it doesn't exist
    EnsureAppSettingsExists;
    
    App := TDextApplication.Create;

    // Add Logging Middleware FIRST
    App.UseMiddleware(TRequestLoggingMiddleware);

    // 1. Register Configuration (IOptions)
    App.Services.Configure<TMySettings>(
      App.Configuration.GetSection('AppSettings')
    );

    // 2. Register Services
    App.Services
      .AddSingleton<IGreetingService, TGreetingService>
      .AddControllers
      .AddContentNegotiation;
    
    // 3. Register Health Checks
    App.Services.AddHealthChecks
      .AddCheck<TDatabaseHealthCheck>
      .Build;

    // 4. Register Background Services
    App.Services.AddBackgroundServices
      .AddHostedService<TWorkerService>
      .Build;

    // 5. Configure Middleware Pipeline
    Builder := App.Builder;

    // CORS
    Builder.UseCors(CorsOptions.Origins(['http://localhost:5173']).AllowCredentials.Build);

    // Static Files
    Builder.UseStaticFiles(Builder.CreateStaticFileOptions);
    
    // Health Checks
    App.UseMiddleware(THealthCheckMiddleware);

    // JWT Authentication
    AuthOptions := Builder.CreateJwtOptions('dext-secret-key-must-be-very-long-and-secure-at-least-32-chars');
    AuthOptions.Issuer := 'dext-issuer';
    AuthOptions.Audience := 'dext-audience';
    Builder.UseJwtAuthentication(AuthOptions);
       
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
end.
