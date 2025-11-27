program TestController;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Dext.Configuration.Interfaces in '..\Sources\Core\Dext.Configuration.Interfaces.pas',
  ControllerExample.Controller in 'ControllerExample.Controller.pas';

begin
  try
    WriteLn('Compiling...');
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
