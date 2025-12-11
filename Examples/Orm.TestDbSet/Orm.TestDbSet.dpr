program Orm.TestDbSet;

{$APPTYPE CONSOLE}


uses
  FastMM5,
  TestUnit in 'TestUnit.pas';

begin
  ReportMemoryLeaksOnShutdown := True;
  RunTest;
end.
