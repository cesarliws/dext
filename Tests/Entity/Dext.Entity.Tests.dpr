program Dext.Entity.Tests;

{$APPTYPE CONSOLE}



uses
  {$I Dext.inc}
  Dext.MM,
  System.SysUtils,
  Dext.Utils,
  Dext.Entity.Dialects,
{$IFDEF DEXT_ENABLE_DB_POSTGRES}
  Dext.Entity.Dialect.PostgreSQL.Test,
{$ENDIF}
{$IFDEF DEXT_ENABLE_DB_FIREBIRD}
  Dext.Entity.Dialect.Firebird.Test,
{$ENDIF}
{$IFDEF DEXT_ENABLE_DB_MSSQL}
  Dext.Entity.Dialect.MSSQL.Test,
{$ENDIF}
{$IFDEF DEXT_ENABLE_DB_MYSQL}
  Dext.Entity.Dialect.MySQL.Test,
{$ENDIF}
{$IFDEF DEXT_ENABLE_DB_ORACLE}
  Dext.Entity.Dialect.Oracle.Test,
{$ENDIF}
  Dext.Entity.Naming.Test,
  Dext.Entity.Pooling.Test,
  Dext.Entity.Mapping.Test,
  Dext.Entity.DbType.Test,
  Dext.Entity.SmartTypes.Test,
  Dext.Entity.Setup.Test,
  Dext.Entity.Query.Test;

procedure RunTests;
var
{$IFDEF DEXT_ENABLE_DB_POSTGRES}
  TestPG: TPostgreSQLDialectTest;
{$ENDIF}
{$IFDEF DEXT_ENABLE_DB_FIREBIRD}
  TestFB: TFirebirdDialectTest;
{$ENDIF}
{$IFDEF DEXT_ENABLE_DB_MSSQL}
  TestMS: TSQLServerDialectTest;
{$ENDIF}
{$IFDEF DEXT_ENABLE_DB_MYSQL}
  TestMY: TMySQLDialectTest;
{$ENDIF}
{$IFDEF DEXT_ENABLE_DB_ORACLE}
  TestOR: TOracleDialectTest;
{$ENDIF}
  TestNS: TNamingStrategyTest;
  TestMap: TMappingTest;
  TestDBT: TDbTypeTest;
  TestST: TSmartTypesTest;
  TestQuery: TQueryParityTest;
  TestSetup: TSetupTest;
begin
  SetConsoleCharSet(65001);
  WriteLn('🧪 Running Dext Entity Unit Tests...');
  WriteLn('====================================');

  // Setup & ConnectionString
  TestSetup := TSetupTest.Create;
  try
    TestSetup.Run;
  finally
    TestSetup.Free;
  end;
  WriteLn('');

  // Query Parity & Optimizations
  TestQuery := TQueryParityTest.Create;
  try
    TestQuery.Run;
  finally
    TestQuery.Free;
  end;
  WriteLn('');

  // SmartTypes & Query Enhancements
  TestST := TSmartTypesTest.Create;
  try
    TestST.Run;
  finally
    TestST.Free;
  end;
  WriteLn('');
  
  // Fluent Mapping
  TestMap := TMappingTest.Create;
  try
    TestMap.Run;
  finally
    TestMap.Free;
  end;
  WriteLn('');
  
  // DbType Propagation
  TestDBT := TDbTypeTest.Create;
  try
    TestDBT.Run;
  finally
    TestDBT.Free;
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

{$IFDEF DEXT_ENABLE_DB_POSTGRES}
  // PostgreSQL
  TestPG := TPostgreSQLDialectTest.Create;
  try
    TestPG.Run;
  finally
    TestPG.Free;
  end;
  WriteLn('');
{$ENDIF}

{$IFDEF DEXT_ENABLE_DB_FIREBIRD}
  // Firebird
  TestFB := TFirebirdDialectTest.Create;
  try
    TestFB.Run;
  finally
    TestFB.Free;
  end;
  WriteLn('');
{$ENDIF}

{$IFDEF DEXT_ENABLE_DB_MSSQL}
  // SQL Server
  TestMS := TSQLServerDialectTest.Create;
  try
    TestMS.Run;
  finally
    TestMS.Free;
  end;
  WriteLn('');
{$ENDIF}

{$IFDEF DEXT_ENABLE_DB_MYSQL}
  // MySQL
  TestMY := TMySQLDialectTest.Create;
  try
    TestMY.Run;
  finally
    TestMY.Free;
  end;
  WriteLn('');
{$ENDIF}

{$IFDEF DEXT_ENABLE_DB_ORACLE}
  // Oracle
  TestOR := TOracleDialectTest.Create;
  try
    TestOR.Run;
  finally
    TestOR.Free;
  end;
{$ENDIF}
  
  WriteLn('');
  WriteLn('✨ All unit tests completed.');
end;

begin
  try
    RunTests;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ConsolePause;
end.
