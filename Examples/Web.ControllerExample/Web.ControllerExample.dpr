program Web.ControllerExample;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  System.Rtti,
  Dext,
  Dext.Web,
  Dext.Utils,
  Dext.Web.Middleware.Logging, // Added logging middleware
  ControllerExample.Controller in 'ControllerExample.Controller.pas',
  ControllerExample.Services in 'ControllerExample.Services.pas';

begin
  SetConsoleCharSet(65001); // Fix console encoding
  try
    WriteLn('?? Starting Dext Controller Example...');
    var App: IWebApplication := TDextApplication.Create;

    // Add Logging Middleware FIRST
    App.UseMiddleware(TRequestLoggingMiddleware);

    // 1. Register Configuration (IOptions)
    App.Services.Configure<TMySettings>(
      App.Configuration.GetSection('AppSettings')
    );

    // 2. Register Services
    App.Services
      .AddSingleton<IGreetingService, TGreetingService>
      .AddControllers;
      
    // 2.1 Enable Content Negotiation
    TWebDIHelpers.AddContentNegotiation(App.Services);
    
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

    // CORS
    var corsOptions := Builder.CreateCorsOptions;
    corsOptions.AllowedOrigins := ['http://localhost:5173'];
    corsOptions.AllowCredentials := True;
    Builder.UseCors(corsOptions);

    // Static Files
    Builder.UseStaticFiles(Builder.CreateStaticFileOptions);
    
    // Health Checks
    App.UseMiddleware(THealthCheckMiddleware);

    // JWT Authentication
    var AuthOptions := Builder.CreateJwtOptions('dext-secret-key-must-be-very-long-and-secure-at-least-32-chars');
    AuthOptions.Issuer := 'dext-issuer';
    AuthOptions.Audience := 'dext-audience';
    Builder.UseJwtAuthentication(AuthOptions);
       
    // 6. Map Controllers
    App.MapControllers;

    // 6.1 Map Versioned API Examples (Manual Routing)
    // V1
    App.Builder.MapGet('/api/versioned', 
      procedure(Ctx: IHttpContext)
      begin
        Ctx.Response.Json('{"version": "1.0", "message": "This is API v1"}');
      end);
    TWebRouteHelpers.HasApiVersion(App.Builder, '1.0');
      
    // V2
    App.Builder.MapGet('/api/versioned', 
      procedure(Ctx: IHttpContext)
      begin
        Ctx.Response.Json('{"version": "2.0", "message": "This is API v2 - Newer and Better!"}');
      end);
    TWebRouteHelpers.HasApiVersion(App.Builder, '2.0');

    // 7. Run Application
    WriteLn('');
    WriteLn('?? Feature Test Instructions:');
    WriteLn('---------------------------------------------------------');
    WriteLn('1. Content Negotiation (defaults to JSON):');
    WriteLn('   curl -H "Accept: application/json" http://localhost:8080/api/greet/negotiated');
    WriteLn('');
    WriteLn('2. API Versioning (Query String):');
    WriteLn('   v1: curl "http://localhost:8080/api/versioned?api-version=1.0"');
    WriteLn('   v2: curl "http://localhost:8080/api/versioned?api-version=2.0"');
    WriteLn('');
    WriteLn('3. API Versioning (Header):');
    WriteLn('   v1: curl -H "X-Version: 1.0" http://localhost:8080/api/versioned');
    WriteLn('   v2: curl -H "X-Version: 2.0" http://localhost:8080/api/versioned');
    WriteLn('---------------------------------------------------------');
    
    App.Run(8080);
  except
    on E: Exception do
      Writeln('? Error: ', E.ClassName, ': ', E.Message);
  end;
end.
