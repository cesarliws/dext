program Grpc.EntityDataSet.Demo;

uses

{$IFDEF WIN64}
  {$DEFINE USE_RDP}
  {$IFDEF USE_RDP}
  RDPMM64 in 'RDPMM64.pas',
  RDPSimd64 in 'RDPSimd64.pas',
  {$ENDIF}
{$ENDIF}
{$IFNDEF USE_RDP}
  Dext.MM,
{$ENDIF}
  Vcl.Forms,
  Grpc.EntityDataSet.Demo.Main.Form in 'Grpc.EntityDataSet.Demo.Main.Form.pas' {FormMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
