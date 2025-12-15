program Dext.ServerTest;

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
  Dext.Logging,
  Dext.Logging.Console;

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
  DebugLog('TTimeService.Create');
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
    Writeln('=== Starting Dext Web Server ===');

    var Host := TDextWebHost.CreateDefaultBuilder
      .ConfigureServices(procedure(Services: IServiceCollection)
      begin
        // Registrar serviços
        TServiceCollectionExtensions.AddSingleton<ITimeService, TTimeService>(Services);
        TServiceCollectionExtensions.AddSingleton<ILogger, TConsoleLogger>(Services);
      end)
      .Configure(procedure(App: IApplicationBuilder)
      begin
        // Configurar pipeline
        var ExceptionOptions := TExceptionHandlerOptions.Development;
        App.UseMiddleware(TExceptionHandlerMiddleware, TValue.From(ExceptionOptions));
        
        var LoggingOptions := THttpLoggingOptions.Default;
        App.UseMiddleware(THttpLoggingMiddleware, TValue.From(LoggingOptions));

        App.Map('/',
             procedure(Ctx: IHttpContext)
             begin
               Ctx.Response.Write('Welcome to Dext Web Framework!');
             end)
           .Map('/time',
             procedure(Ctx: IHttpContext)
             var
               TimeService: ITimeService;
             begin
               TimeService := TServiceProviderExtensions.GetService<ITimeService>(Ctx.Services);
               Ctx.Response.Write('Server time: ' + TimeService.GetCurrentTime);
             end)
           .Map('/hello', procedure(Ctx: IHttpContext)
             begin
               Ctx.Response.Json('{"message": "Hello from Dext!", "status": "success"}');
             end)

           .Map('/users/{id}', procedure(Ctx: IHttpContext)
             var
               UserId: string;
             begin
               UserId := Ctx.Request.RouteParams['id'];
               Ctx.Response.Write(Format('User ID: %s', [UserId]));
             end)

           .Map('/posts/{year}/{month}', procedure(Ctx: IHttpContext)
             var
               Year, Month: string;
             begin
               Year := Ctx.Request.RouteParams['year'];
               Month := Ctx.Request.RouteParams['month'];
               Ctx.Response.Write(Format('Posts from %s/%s', [Year, Month]));
             end);
      end)
      .Build;

    // ?? INICIAR SERVIDOR REAL!
    Host.Run;
    // Manter servidor rodando até Enter
    //Readln;
    Host.Stop;
  except
    on E: Exception do
      Writeln('Server error: ', E.ClassName, ': ', E.Message);
  end;
end.
