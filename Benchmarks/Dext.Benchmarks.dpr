program Dext.Benchmarks;

{$APPTYPE CONSOLE}
{$DEFINE USE_RDP}

{$R *.res}

uses
{$IFDEF WIN64}
  {$IFDEF USE_RDP}
  RDPMM64 in 'RDPMM64.pas',
  RDPSimd64 in 'RDPSimd64.pas',
  {$ENDIF}
{$ENDIF}
  {$IFDEF LINUX}
  Dext.LinuxExceptionLogger in 'Sources\Dext.LinuxExceptionLogger.pas',
  {$ENDIF}
  System.SysUtils,
  Spring.Benchmark in '..\External\Spring4D\Spring.Benchmark.pas',
  Dext.Performance.Allocator in
    '..\Sources\Performance\Dext.Performance.Allocator.pas',
  BM.Http in 'Sources\BM.Http.pas',
  BM.Orm in 'Sources\BM.Orm.pas',
  BM.S54 in 'Sources\BM.S54.pas';

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

function IsBenchmarkFilterForHttp: Boolean;
var
  i: Integer;
  Argument: string;
begin
  Result := False;
  for i := 1 to ParamCount do
  begin
    Argument := ParamStr(i);
    if (Pos('--benchmark_filter=', LowerCase(Argument)) = 1) or
       (Pos('-benchmark_filter=', LowerCase(Argument)) = 1) or
       (Pos('/benchmark_filter=', LowerCase(Argument)) = 1) then
      Exit(Pos('bm_http', LowerCase(Argument)) > 0);
  end;
end;

function HasBenchmarkFilterParam: Boolean;
var
  i: Integer;
  Argument: string;
begin
  Result := False;
  for i := 1 to ParamCount do
  begin
    Argument := ParamStr(i);
    if (Pos('--benchmark_filter=', LowerCase(Argument)) = 1) or
       (Pos('-benchmark_filter=', LowerCase(Argument)) = 1) or
       (Pos('/benchmark_filter=', LowerCase(Argument)) = 1) then
      Exit(True);
  end;
end;

function ShouldInitializeHttpBenchmarks: Boolean;
begin
  Result := not HasCommandLineSwitch('--server');
  if Result and HasCommandLineSwitch('--benchmark_list_tests') then
    Exit(False);
  if Result and HasBenchmarkFilterParam then
    Exit(IsBenchmarkFilterForHttp);
end;
begin
  try
    if ShouldInitializeHttpBenchmarks then
      InitializeHttpBenchmarks;
    if (ParamCount >= 2) and SameText(ParamStr(1), '--server') then
    begin
      RunStandaloneServer(ParamStr(2));
    end
    else
    begin
      // Spring.Benchmark parses command line arguments and runs all registered benchmarks
      Benchmark_Main;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  {$IFDEF MSWINDOWS}
  if not FindCmdLineSwitch('non-interactive', ['-', '/'], True) then
  begin
    Write('Press [ENTER] to finish');
    ReadLn;
  end;
  {$ENDIF}
end.
