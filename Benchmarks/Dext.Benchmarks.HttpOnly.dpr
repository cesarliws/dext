program Dext.Benchmarks.HttpOnly;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  {$IFDEF LINUX}
  Dext.LinuxExceptionLogger in 'Sources\Dext.LinuxExceptionLogger.pas',
  {$ENDIF}
  System.SysUtils,
  Spring.Benchmark in '..\External\Spring4D\Spring.Benchmark.pas',
  BM.Http in 'Sources\BM.Http.pas';

function HasCommandLineSwitch(const SwitchName: string): Boolean;
var
  i: Integer;
  Argument: string;
begin
  Result := False;
  for i := 1 to ParamCount do
  begin
    Argument := ParamStr(i);
    if SameText(Argument, SwitchName) or
       SameText(Argument, '-' + SwitchName) or
       SameText(Argument, '/' + SwitchName) then
      Exit(True);
  end;
end;

begin
  try
    if HasCommandLineSwitch('--server') then
    begin
      if ParamCount >= 2 then
        RunStandaloneServer(ParamStr(2))
      else
        RunStandaloneServer('-indy');
    end
    else
    begin
      InitializeHttpBenchmarks;
      Benchmark_Main;
    end;
  except
    on E: Exception do
      Writeln(ErrOutput, 'Exception: ' + E.ClassName + ': ' + E.Message);
  end;
end.
