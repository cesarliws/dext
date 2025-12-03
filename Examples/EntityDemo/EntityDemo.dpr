program EntityDemo;

{$APPTYPE CONSOLE}

uses
  FastMM5,
  System.SysUtils,
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
  EntityDemo.Entities in 'EntityDemo.Entities.pas';

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
  // 6. Lazy Loading Tests
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
  
  WriteLn('');
  WriteLn('✨ All tests completed.');
end;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    WriteLn('🚀 Dext Entity ORM Demo Suite');
    WriteLn('=============================');
    WriteLn('');
    
    // ========================================
    // Database Configuration
    // ========================================
    // Uncomment the provider you want to test:
    
    // Option 1: SQLite (Default - File-based, good for development)
    TDbConfig.SetProvider(dpSQLite);
    TDbConfig.ConfigureSQLite('test.db');

    // Option 2: PostgreSQL (Server-based, production-ready)
    // TDbConfig.SetProvider(dpPostgreSQL);
    // TDbConfig.ConfigurePostgreSQL('localhost', 5432, 'postgres', 'postgres', 'root');
    
    // Option 3: Firebird (Brazilian market favorite)
    // TDbConfig.SetProvider(dpFirebird);
    // TDbConfig.ConfigureFirebird('C:\temp\dext_test.fdb', 'SYSDBA', 'masterkey');
    
    // Option 4: SQL Server (Enterprise)
    // TDbConfig.SetProvider(dpSQLServer);
    // TDbConfig.ConfigureSQLServer('localhost', 'dext_test', 'sa', 'Password123!');
    
    WriteLn('📊 Database Provider: ' + TDbConfig.GetProviderName);
    WriteLn('');
    
    // Run all tests
    RunAllTests;
  except
    on E: Exception do
      Writeln('❌ Critical Error: ', E.ClassName, ': ', E.Message);
  end;
  ReadLn;
end.
