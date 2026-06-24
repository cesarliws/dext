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
  System.SysUtils,
  Spring.Benchmark in '..\External\Spring4D\Spring.Benchmark.pas',
  BM.Http in 'Sources\BM.Http.pas',
  BM.Orm in 'Sources\BM.Orm.pas';

begin
  try
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
  Write('Press [ENTER] to finish');
  ReadLn;
end.
