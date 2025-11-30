program EntityDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  EntityDemo.Entities in 'EntityDemo.Entities.pas',
  EntityDemo.Tests.AdvancedQuery in 'EntityDemo.Tests.AdvancedQuery.pas',
  EntityDemo.Tests.Base in 'EntityDemo.Tests.Base.pas',
  EntityDemo.Tests.Bulk in 'EntityDemo.Tests.Bulk.pas',
  EntityDemo.Tests.CompositeKeys in 'EntityDemo.Tests.CompositeKeys.pas',
  EntityDemo.Tests.Concurrency in 'EntityDemo.Tests.Concurrency.pas',
  EntityDemo.Tests.CRUD in 'EntityDemo.Tests.CRUD.pas',
  EntityDemo.Tests.FluentAPI in 'EntityDemo.Tests.FluentAPI.pas',
  EntityDemo.Tests.ExplicitLoading in 'EntityDemo.Tests.ExplicitLoading.pas',
  EntityDemo.Tests.LazyExecution in 'EntityDemo.Tests.LazyExecution.pas',
  EntityDemo.Tests.Relationships in 'EntityDemo.Tests.Relationships.pas';

procedure RunAllTests;
var
  Test: TBaseTest;
begin
  WriteLn('🚀 Dext Entity ORM Demo Suite');
  WriteLn('=============================');
  WriteLn('');

  // Run CRUD Tests
  Test := TCRUDTest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;

  // Run Bulk Tests
  Test := TBulkTest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;

  // Run Concurrency Tests
  Test := TConcurrencyTest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;

  // Run Relationship Tests
  Test := TRelationshipTest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;

  // Run Composite Key Tests
  Test := TCompositeKeyTest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;

  // Run Lazy Execution Tests
  Test := TLazyExecutionTest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;

  // Run Advanced Query Tests
  Test := TAdvancedQueryTest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;

  // Run Fluent API Tests
  Test := TFluentAPITest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;

  // Run Explicit Loading Tests
  Test := TExplicitLoadingTest.Create;
  try
    Test.Run;
  finally
    Test.Free;
  end;
  
  WriteLn('✨ All tests completed.');
end;

begin
  // TODO : Fix Memory leaks
  ReportMemoryLeaksOnShutdown := True;
  try
    RunAllTests;
  except
    on E: Exception do
      Writeln('❌ Critical Error: ', E.ClassName, ': ', E.Message);
  end;
  ReadLn;
end.
