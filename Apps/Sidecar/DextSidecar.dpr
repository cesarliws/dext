program DextSidecar;

{$MESSAGE HINT 'Dext CLI: This project generates the ".\Apps\dext-sidecar.exe" binary.'}


uses
  Dext.MM,
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  Dext.Hosting.CLI.Config,
  Main.Form in 'Main.Form.pas' {MainForm},
  Dext.Classes in 'Lib\Dext.Classes.pas',
  Dext.Dashboard.Routes in '..\..\Sources\Dashboard\Dext.Dashboard.Routes.pas',
  Dext.Services.FileWatcher in 'Dext.Services.FileWatcher.pas',
  Dext.Sidecar.Server in 'Dext.Sidecar.Server.pas',
  Dext.Vcl.FormDecorator in 'Lib\Dext.Vcl.FormDecorator.pas',
  Dext.Vcl.Helpers in 'Lib\Dext.Vcl.Helpers.pas',
  Dext.Vcl.TrayIcon in 'Lib\Dext.Vcl.TrayIcon.pas',
  Dext.Dashboard.TestScanner in '..\..\Sources\Dashboard\Dext.Dashboard.TestScanner.pas',
  Dext.Dashboard.TestRunner in '..\..\Sources\Dashboard\Dext.Dashboard.TestRunner.pas',
  Dext.Hosting.CLI.Hubs.Dashboard in '..\CLI\Hubs\Dext.Hosting.CLI.Hubs.Dashboard.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.ShowMainForm := False;
  Application.Title := 'Dext Sidecar';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
