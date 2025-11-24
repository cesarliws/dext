program ControllerExample;

{$APPTYPE CONSOLE}
{.$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished]) FIELDS([vcPrivate, vcProtected, vcPublic])}

uses
  System.SysUtils,
  System.Rtti,
  Dext.Core.Routing,
  Dext.Core.WebApplication,
  Dext.DI.Interfaces,
  Dext.DI.Extensions,
  Dext.Http.Interfaces,
  Dext.Core.Controllers,
  Dext.Http.Cors,
  Dext.Http.StaticFiles,
  Dext.Auth.Middleware,
  ControllerExample.Controller in 'ControllerExample.Controller.pas';

begin
  try
    WriteLn('🚀 Starting Dext Controller Example...');
    var App := TDextApplication.Create;
    
    // Register services
    TServiceCollectionExtensions.AddSingleton<IGreetingService, TGreetingService>(App.Services);
    TServiceCollectionExtensions.AddControllers(App.Services);
    
    // Middleware Pipeline
    var Builder := App.GetApplicationBuilder;


//const cors = require('cors');
//const corsOptions ={
//    origin:'http://localhost:3000',
//    credentials:true,            //access-control-allow-credentials:true
//    optionSuccessStatus:200
//}
//app.use(cors(corsOptions));

//  Result.AllowedOrigins := [];
//  Result.AllowedMethods := ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'];
//  Result.AllowedHeaders := ['Content-Type', 'Authorization'];
//  Result.ExposedHeaders := [];
//  Result.AllowCredentials := False;
//  Result.MaxAge := 0;

   var corsOptions := TCorsOptions.Create;
   //corsOptions.AllowedOrigins := ['http://localhost:5173', 'http://localhost:8080'];
   corsOptions.AllowCredentials := True;

    // CORS
   TApplicationBuilderCorsExtensions.UseCors(Builder, corsOptions);
    
    // Static Files
    TApplicationBuilderStaticFilesExtensions.UseStaticFiles(Builder);
    
    // JWT Authentication
    // Builder.UseMiddleware(TJwtAuthenticationMiddleware, TValue.From(TJwtAuthenticationOptions.Default('dext-secret-key-must-be-very-long-and-secure-at-least-32-chars')));
       
    // Map controllers
    App.MapControllers;
    
    // Run
    App.Run(8080);
  except
    on E: Exception do
      Writeln('❌ Error: ', E.ClassName, ': ', E.Message);
  end;
end.
