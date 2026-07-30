program Dext.ServerTest;

uses
  Dext.MM,
  System.SysUtils,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  Dext.Utils,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.WebHost,
  Dext.Web.Middleware,
  Dext.Logging,
  Dext.Logging.Console,
  Dext.Logging.Extensions;

{$APPTYPE CONSOLE}

{$R *.res}

type
  ITimeService = interface
    ['{DB46A3F6-2C69-48DF-9D54-78FDA9E588BB}']
    function GetCurrentTime: string;
  end;

  TTimeService = class(TInterfacedObject, ITimeService)
  public
    function GetCurrentTime: string;
  end;

{ TTimeService }

function TTimeService.GetCurrentTime: string;
begin
  Result := DateTimeToStr(Now);
end;

var
  Host: IWebHost;
begin
  SetConsoleCharSet(65001);
  try
    Writeln('=== Starting Dext Web Server ===');

    Host := TDextWebHost.CreateDefaultBuilder
      .ConfigureServices(procedure(Services: IServiceCollection)
      begin
        TDextServices.Create(Services)
          .AddSingleton<ITimeService, TTimeService>;
        TServiceCollectionLoggingExtensions.AddLogging(Services,
          procedure(Builder: ILoggingBuilder)
          begin
            Builder.AddConsole;
          end);
      end)
      .Configure(procedure(App: IApplicationBuilder)
      begin
        App.UseMiddleware(THttpLoggingMiddleware);

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
               TimeService := TDextServices.GetService<ITimeService>(Ctx.Services);
               Ctx.Response.Write('Server time: ' + TimeService.GetCurrentTime);
             end)
           .Map('/hello',
             procedure(Ctx: IHttpContext)
             begin
               Ctx.Response.Json('{"message": "Hello from Dext!", "status": "success"}');
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
             end);
      end)
      .Build;

    Host.Run;
  except
    on E: Exception do
      Writeln('Server error: ', E.ClassName, ': ', E.Message);
  end;
  ConsolePause;
end.
