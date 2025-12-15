// Examples/MinimalAPI/MinimalAPIExample.pas
program Web.MinimalAPIExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Dext.MM,
  System.DateUtils,
  System.SysUtils,
  Dext.WebHost,
  Dext.DI.Interfaces,
  Dext.DI.Extensions,
  Dext.Web.Interfaces,
  Dext.Web.Results,
  Dext.Web.ApplicationBuilder.Extensions;

type
  ISomeService = interface
    ['{89A82D2C-D213-4629-A77E-F6C7D8A1B2C3}']
    procedure DoSomething;
  end;

  TSomeService = class(TInterfacedObject, ISomeService)
  public
    procedure DoSomething;
  end;

{ TSomeService }

procedure TSomeService.DoSomething;
begin
  WriteLn('Doing something...');
end;

var
  Builder: IWebHostBuilder;
  Host: IWebHost;

begin
  Builder := TDextWebHost.CreateDefaultBuilder;

  Builder.ConfigureServices(
    procedure(Services: IServiceCollection)
    begin
      TServiceCollectionExtensions.AddSingleton<ISomeService, TSomeService>(Services);
    end);

  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      // Simple GET endpoint
      App.Map('/hello',
        procedure(Context: IHttpContext)
        begin
          Context.Response.Write('Hello from Dext!');
        end);

      // GET with time
      App.Map('/time',
        procedure(Context: IHttpContext)
        begin
          Context.Response.Write(Format('Server time: %s', [DateTimeToStr(Now)]));
        end);

      // Simple JSON endpoint
      App.Map('/json',
        procedure(Context: IHttpContext)
        begin
          Context.Response.Json('{"message": "Hello JSON!", "timestamp": "' +
            DateTimeToStr(Now) + '"}');
        end);
        
      WriteLn('Routes mapped:');
      WriteLn('  GET /hello');
      WriteLn('  GET /time');
      WriteLn('  GET /json');
      WriteLn('');
      WriteLn('Server running on http://localhost:8080');
      WriteLn('Press Ctrl+C to stop');
    end);

  Host := Builder.Build;
  Host.Run;
end.