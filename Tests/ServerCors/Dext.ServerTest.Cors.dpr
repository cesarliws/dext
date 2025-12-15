program Dext.ServerTest.Cors;

uses
  Dext.MM,
  System.SysUtils,
  System.Rtti,
  Dext.Utils,
  Dext.DI.Interfaces,
  Dext.DI.Extensions,
  Dext.Web.Interfaces,
  Dext.WebHost,
  Dext.Web.Middleware,
  Dext.Web.Cors,
  Dext.Logging,
  Dext.Logging.Console,
  Dext.ServerTest.Cors.Consts in 'Dext.ServerTest.Cors.Consts.pas',
  Dext.Json.Test in 'Dext.Json.Test.pas',
  Dext.ModelBinding.Tests in 'Dext.ModelBinding.Tests.pas',
  Dext.Web.Mocks in '..\Common\Dext.Web.Mocks.pas';

{$APPTYPE CONSOLE}

{$R *.res}

type
  ITimeService = interface
    ['{DB46A3F6-2C69-48DF-9D54-78FDA9E588BB}']
    function GetCurrentTime: string;
  end;

  TTimeService = class(TInterfacedObject, ITimeService)
  public
    constructor Create;
    destructor Destroy; override;
    function GetCurrentTime: string;
  end;

{ TTimeService }

constructor TTimeService.Create;
begin
  inherited Create;
  DebugLog('TTimeService.Create')
end;

destructor TTimeService.Destroy;
begin
  DebugLog('TTimeService.Destroy');
  inherited;
end;

function TTimeService.GetCurrentTime: string;
begin
  Result := DateTimeToStr(Now);
end;

begin
  try
    TestDextJson;
    TestDextJsonRecords;
    TestDextJsonAttributes;
    TestDextJsonArrays;
    TestListOnly;
    TestDextJsonSettings;
    TestCompleteSettings;
    TestEnumRoundTrip;
    TestGUIDSupport;
    TestGUIDWithSettings;
    TestJsonNumberOnString;
    TestDateTimeFormats;
    TestDateTimeWithOtherSettings;

    TestAdvancedAttributes;
    TestAllFeaturesCombined;
    TestEdgeCases;
    TestLocalization;
    TestProviders; // ? Adicionado teste de drivers
    Readln;
    Exit;
    TestBindingAttributes;
    TestRealWorldBindingScenarios;
    TestModelBinderBasic;

    WriteLn('--- Actual Tests --- ' + sLineBreak);

    TestBindHeaderComprehensive;
    TestBindServicesComprehensive;
    Readln;
    Exit;
    TestBindRouteComprehensive;
    TestBindRouteEdgeCases;
    Readln;
    Exit;
    TestBindQueryComprehensive;
    TestBindQueryEdgeCases;
    Readln;
    Exit;
    TestCompleteIntegration;
    TestFinalIntegration;
    TestWebHostIntegration;
    TestConciseIntegration;

    Readln;
    Exit;


    Writeln('=== Starting Dext Web Server with CORS ===');

    var Host := TDextWebHost.CreateDefaultBuilder
      .ConfigureServices(procedure(Services: IServiceCollection)
      begin
        // Registrar serviços
        TServiceCollectionExtensions.AddSingleton<ITimeService, TTimeService>(Services);
        TServiceCollectionExtensions.AddSingleton<ILogger, TConsoleLogger>(Services);
      end)
      .Configure(procedure(App: IApplicationBuilder)
      begin
        // ? CORREÇÃO: Usar TApplicationBuilderCorsExtensions.UseCors
        TApplicationBuilderCorsExtensions.UseCors(App,  // ? CORRETO!
          procedure(CorsBuilder: TCorsBuilder)
          begin
            CorsBuilder
              .WithOrigins(['http://localhost:3000', 'http://127.0.0.1:3000'])
              .WithMethods(['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'])
              .WithHeaders(['Content-Type', 'Authorization'])
              .AllowCredentials;
          end);

        // Configurar pipeline (agora App já tem CORS configurado)
        var ExceptionOptions := TExceptionHandlerOptions.Development;
        App.UseMiddleware(TExceptionHandlerMiddleware, TValue.From(ExceptionOptions));
        
        var LoggingOptions := THttpLoggingOptions.Default;
        App.UseMiddleware(THttpLoggingMiddleware, TValue.From(LoggingOptions));

        App.Map('/',
             procedure(Ctx: IHttpContext)
             begin
               Ctx.Response.Write('Welcome to Dext Web Framework with CORS!');
             end)
           .Map('/time',
             procedure(Ctx: IHttpContext)
             var
               TimeService: ITimeService;
             begin
               TimeService := TServiceProviderExtensions.GetService<ITimeService>(Ctx.Services);
               Ctx.Response.Write('Server time: ' + TimeService.GetCurrentTime);
             end)
           .Map('/hello',
             procedure(Ctx: IHttpContext)
             begin
               Ctx.Response.Json('{"message": "Hello from Dext!", "status": "success", "cors": "enabled"}');
             end)
           .Map('/users/{id}',
             procedure(Ctx: IHttpContext)
             var
               UserId: string;
             begin
               UserId := Ctx.Request.RouteParams['id'];
               Ctx.Response.Write(Format('User ID: %s', [UserId]));
             end)
           .Map('/posts/{year}/{month}',
             procedure(Ctx: IHttpContext)
             var
               Year, Month: string;
             begin
               Year := Ctx.Request.RouteParams['year'];
               Month := Ctx.Request.RouteParams['month'];
               Ctx.Response.Write(Format('Posts from %s/%s', [Year, Month]));
             end)
           // ? NOVA ROTA: Específica para testar CORS
           .Map('/cors-test',
             procedure(Ctx: IHttpContext)
             begin
               Ctx.Response.Json('{"cors": "working", "timestamp": "' + DateTimeToStr(Now) + '"}');
             end)
            .Map('/cors-demo',
              procedure(Ctx: IHttpContext)
              begin
                // ? CORREÇÃO: Usar SetContentType ANTES de Write
                Ctx.Response.SetContentType('text/html; charset=utf-8');
                Ctx.Response.Write(TextCorsHtml);
              end)
            .Map('/cors-test-page',
              procedure(Ctx: IHttpContext)
              begin
                // ? Simular que esta página vem de http://localhost:3000
                Ctx.Response.AddHeader('Access-Control-Allow-Origin', 'http://localhost:8080');
                Ctx.Response.SetContentType('text/html; charset=utf-8');
                Ctx.Response.Write(TextCorsHtmlTestPage);
              end);
      end)
      .Build;

    // ?? INICIAR SERVIDOR REAL!
    Host.Run;

    // Manter servidor rodando até Enter
    Readln;

    Host.Stop;

  except
    on E: Exception do
      Writeln('Server error: ', E.ClassName, ': ', E.Message);
  end;
end.
