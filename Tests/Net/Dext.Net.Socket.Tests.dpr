program DextNetSocketTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Testing.Runner,
  Dext.Testing.Attributes,
  Dext.Testing.Fluent,
  Dext.Utils,
  Dext.Net.Socket.TestsUnit in 'Dext.Net.Socket.TestsUnit.pas',
  Dext.Net.Tcp in '..\..\Sources\Net\Dext.Net.Tcp.pas',
  Dext.Net.Udp in '..\..\Sources\Net\Dext.Net.Udp.pas',
  Dext.Net.Mqtt.Parser in '..\..\Sources\Net\Dext.Net.Mqtt.Parser.pas',
  Dext.Net.Mqtt in '..\..\Sources\Net\Dext.Net.Mqtt.pas',
  Dext.Net.Mqtt.Tests in 'Dext.Net.Mqtt.Tests.pas';

begin
  SetConsoleCharSet;
  try
    RunTests(ConfigureTests
      .Verbose
      .RegisterFixtures([
        TDextTcpTests,
        TDextUdpTests,
        TDextMqttTests
      ]));
  except
    on error: Exception do
    begin
      SafeWriteLn('FATAL ERROR: ' + error.ClassName + ': ' + error.Message);
      ExitCode := 1;
    end;
  end;
end.
