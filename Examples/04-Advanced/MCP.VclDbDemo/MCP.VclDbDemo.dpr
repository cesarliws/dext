program MCP.VclDbDemo;

uses
  Vcl.Forms,
  MCP.VclDbDemo.Main in 'MCP.VclDbDemo.Main.pas' {FormMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
