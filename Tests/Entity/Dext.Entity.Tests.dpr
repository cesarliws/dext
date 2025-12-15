program Dext.Entity.Tests;

{$APPTYPE CONSOLE}



uses
  Dext.MM,
  System.SysUtils,
  Dext.Utils,
  Dext.Entity.Dialects in '..\Entity\Dext.Entity.Dialects.pas',
  Dext.Entity.Dialect.PostgreSQL.Test in 'Dext.Entity.Dialect.PostgreSQL.Test.pas',
  Dext.Entity.Dialect.Firebird.Test in 'Dext.Entity.Dialect.Firebird.Test.pas',
  Dext.Entity.Dialect.MSSQL.Test in 'Dext.Entity.Dialect.MSSQL.Test.pas',
  Dext.Entity.Dialect.MySQL.Test in 'Dext.Entity.Dialect.MySQL.Test.pas',
  Dext.Entity.Dialect.Oracle.Test in 'Dext.Entity.Dialect.Oracle.Test.pas',
  Dext.Entity.Naming.Test in 'Dext.Entity.Naming.Test.pas',
  Dext.Entity.Mapping.Test in 'Dext.Entity.Mapping.Test.pas';

procedure RunTests;
var
  TestPG: TPostgreSQLDialectTest;
  TestFB: TFirebirdDialectTest;
  TestMS: TSQLServerDialectTest;
  TestMY: TMySQLDialectTest;
  TestOR: TOracleDialectTest;
  TestNS: TNamingStrategyTest;
  TestMap: TMappingTest;
begin
  SetConsoleCharSet(65001);
  WriteLn('?? Running Dext Entity Unit Tests...');
  WriteLn('====================================');
  
  // Fluent Mapping
  TestMap := TMappingTest.Create;
  try
    TestMap.Run;
  finally
    TestMap.Free;
  end;
  WriteLn('');

  // Naming Strategy
  TestNS := TNamingStrategyTest.Create;
  try
    TestNS.Run;
  finally
    TestNS.Free;
  end;
  WriteLn('');

  // PostgreSQL
  TestPG := TPostgreSQLDialectTest.Create;
  try
    TestPG.Run;
  finally
    TestPG.Free;
  end;
  WriteLn('');

  // Firebird
  TestFB := TFirebirdDialectTest.Create;
  try
    TestFB.Run;
  finally
    TestFB.Free;
  end;
  WriteLn('');

  // SQL Server
  TestMS := TSQLServerDialectTest.Create;
  try
    TestMS.Run;
  finally
    TestMS.Free;
  end;
  WriteLn('');

  // MySQL
  TestMY := TMySQLDialectTest.Create;
  try
    TestMY.Run;
  finally
    TestMY.Free;
  end;
  WriteLn('');

  // Oracle
  TestOR := TOracleDialectTest.Create;
  try
    TestOR.Run;
  finally
    TestOR.Free;
  end;
  
  WriteLn('');
  WriteLn('? All unit tests completed.');
end;

begin
  try
    RunTests;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ReadLn;
end.
