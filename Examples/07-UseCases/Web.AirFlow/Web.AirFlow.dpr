program Web.AirFlow;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Utils,
  Dext.Web,
  Dext.DI.Interfaces,
  AirFlow.Startup in 'AirFlow.Startup.pas',
  AirFlow.Domain in 'AirFlow.Domain.pas',
  AirFlow.Hubs in 'AirFlow.Hubs.pas',
  AirFlow.Simulator in 'AirFlow.Simulator.pas';

var
  App: IWebApplication;
  Startup: IStartup;
begin
  SetConsoleCharSet;
  try
    Writeln('🚀 Starting Dext AirFlow server...');

    App := TDextApplication.Create;
    App.UseNativeServer;
    Startup := TStartup.Create;
    App.UseStartup(Startup);
    App.BuildServices;

    Writeln('🌐 Server running on: http://localhost:9000');
    Writeln('Endpoints:');
    Writeln('  GET   /health');
    Writeln('  POST  /api/alerts?vehicleId=V01&message=CustomAlert');
    Writeln('  SSE   /hubs/airflow (SignalR-compatible endpoint)');
    Writeln;
    Writeln('Static Dashboard: http://localhost:9000/index.html');
    Writeln('Press ENTER to exit.');

    App.Run(9000);

  except
    on E: Exception do
      Writeln('❌ Critical Error: ', E.ClassName, ': ', E.Message);
  end;
  ConsolePause;
end.
