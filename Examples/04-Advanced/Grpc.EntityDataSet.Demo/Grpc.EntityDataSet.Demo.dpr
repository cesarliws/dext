program Grpc.EntityDataSet.Demo;

uses
  Dext.MM,
  Vcl.Forms,
  Grpc.EntityDataSet.Demo.Main.Form in 'Grpc.EntityDataSet.Demo.Main.Form.pas' {FormMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
