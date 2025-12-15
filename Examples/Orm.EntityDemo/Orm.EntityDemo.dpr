
program Orm.EntityDemo;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  FireDAC.Comp.Client,
  EntityDemo.DbConfig in 'EntityDemo.DbConfig.pas',
  EntityDemo.Tests.AdvancedQuery in 'EntityDemo.Tests.AdvancedQuery.pas',
  EntityDemo.Tests.Base in 'EntityDemo.Tests.Base.pas',
  EntityDemo.Tests.Bulk in 'EntityDemo.Tests.Bulk.pas',
  EntityDemo.Tests.CompositeKeys in 'EntityDemo.Tests.CompositeKeys.pas',
  EntityDemo.Tests.Concurrency in 'EntityDemo.Tests.Concurrency.pas',
  EntityDemo.Tests.CRUD in 'EntityDemo.Tests.CRUD.pas',
  EntityDemo.Tests.ExplicitLoading in 'EntityDemo.Tests.ExplicitLoading.pas',
  EntityDemo.Tests.FluentAPI in 'EntityDemo.Tests.FluentAPI.pas',
  EntityDemo.Tests.LazyExecution in 'EntityDemo.Tests.LazyExecution.pas',
  EntityDemo.Tests.LazyLoading in 'EntityDemo.Tests.LazyLoading.pas',
  EntityDemo.Tests.Relationships in 'EntityDemo.Tests.Relationships.pas',
  EntityDemo.Tests.Scaffolding in 'EntityDemo.Tests.Scaffolding.pas',
  EntityDemo.Tests.FluentMappingSyntax in 'EntityDemo.Tests.FluentMappingSyntax.pas',
  EntityDemo.Entities in 'EntityDemo.Entities.pas',
  EntityDemo.Tests.Migrations in 'EntityDemo.Tests.Migrations.pas',
  EntityDemo.Tests.Collections in 'EntityDemo.Tests.Collections.pas',
  EntityDemo.Tests.NoTracking in 'EntityDemo.Tests.NoTracking.pas',
  EntityDemo.Tests.MixedCompositeKeys in 'EntityDemo.Tests.MixedCompositeKeys.pas',
  EntityDemo.Tests.SoftDelete in 'EntityDemo.Tests.SoftDelete.pas',
  EntityDemo.Tests.Async in 'EntityDemo.Tests.Async.pas';

procedure ConfigureDatabase(Provider: TDatabaseProvider);
begin
  // ========================================
  // Database Configuration
  // ========================================
  // Uncomment the provider you want to test:

  case Provider of
    // Option 1: SQLite (Default - Memory, good for development)
    dpSQLiteMemory: TDbConfig.ConfigureSQLiteMemory;
    // Option 2: SQLite (File-based, good for development)
    dpSQLite: TDbConfig.ConfigureSQLite('test.db');
    // Option 2: PostgreSQL (Server-based, production-ready)
    dpPostgreSQL: TDbConfig.ConfigurePostgreSQL('localhost', 5432, 'postgres', 'postgres', 'root');
    // Option 3: Firebird
    dpFirebird: TDbConfig.ConfigureFirebird('C:\temp\dext_test.fdb', 'SYSDBA', 'masterkey');
    // Option 4: SQL Server with Windows Authentication (Recommended)
    dpSQLServerWindowsAuthetication: TDbConfig.ConfigureSQLServerWindowsAuth('localhost', 'dext_test');
    // Option 5: SQL Server with SQL Authentication
    dpSQLServer: TDbConfig.ConfigureSQLServer('localhost', 'dext_test', 'sa', 'SQL@d3veloper');
  else
    raise Exception.Create('Database not supported');
// TODO:
//    dpMySQL:
//    dpOracle:
  end;

  if Provider in [dpSQLite, dpSQLiteMemory] then
  begin
    //RegisterExpectedMemoryLeak(Unknown)
  end;

  WriteLn('?? Database Provider: ' + TDbConfig.GetProviderName);
  WriteLn('');
end;

procedure RunTest(const TestClass: TBaseTestClass);
var
  Test: TBaseTest;
begin
  WriteLn('Running Test: ', TestClass.ClassName);
  Test := TestClass.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;
end;

procedure RunAllTests;
begin
  // 1. CRUD Tests
  RunTest(TCRUDTest);
  // 2. Relationships Tests
  RunTest(TRelationshipTest);
  // 3. Advanced Query Tests
  RunTest(TAdvancedQueryTest);
  // 4. Composite Keys Tests
  RunTest(TCompositeKeyTest);
  // 5. Explicit Loading Tests
  RunTest(TExplicitLoadingTest);
  // 6. Lazy Loading Tests -
  RunTest(TLazyLoadingTest);
  // 7. Fluent API Tests
  RunTest(TFluentAPITest);
  // 8. Lazy Execution Tests
  RunTest(TLazyExecutionTest);
  // 9. Bulk Operations Tests
  RunTest(TBulkTest);
  // 10. Concurrency Tests
  RunTest(TConcurrencyTest);
  // 11. Scaffolding Tests
  RunTest(TScaffoldingTest);
  // 12. Migrations Builder Tests
  RunTest(TMigrationsTest);
  // 13. Collections Tests
  RunTest(TCollectionsTest);
  // 14. No Tracking Tests
  RunTest(TNoTrackingTest);
  // 15. Mixed Composite Keys
  RunTest(TMixedCompositeKeyTest);
  // 16. Soft Delete Tests
  RunTest(TSoftDeleteTest);
  // 17. Async Tests
  RunTest(TAsyncTest);

  WriteLn('');
  WriteLn('? All tests completed.');
end;

begin
  SetConsoleCharSet(65001);
  try
    WriteLn('?? Dext Entity ORM Demo Suite');
    WriteLn('=============================');
    WriteLn('');
    ConfigureDatabase(dpSQLiteMemory);
    RunAllTests;
  except
    on E: Exception do
      Writeln('? Critical Error: ', E.ClassName, ': ', E.Message);
  end;

  ReadLn;
end.
