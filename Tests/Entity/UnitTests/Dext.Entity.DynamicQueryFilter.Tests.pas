unit Dext.Entity.DynamicQueryFilter.Tests;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Collections,
  Dext.Testing,
  Dext.Testing.Attributes,
  Dext.Entity,
  Dext.Entity.Mapping,
  Dext.Entity.Attributes,
  Dext.Specifications.SQL.Generator,
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Context,
  Dext.Entity.Setup,
  Dext.Entity.Core,
  Dext.Entity.Query,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Phys.SQLiteWrapper.Stat,
  Dext.Entity.Drivers.FireDAC,
  Dext.Types.Nullable;

type
  {$M+}

  /// <summary>
  ///   Entity with boolean soft delete for Dynamic Query Filter tests.
  /// </summary>
  [Table('dqf_tasks'), SoftDelete('IsDeleted')]
  TDqfTask = class
  private
    FId: Integer;
    FTitle: string;
    FIsDeleted: Boolean;
  public
    [PK]
    property Id: Integer read FId write FId;
    property Title: string read FTitle write FTitle;
    property IsDeleted: Boolean read FIsDeleted write FIsDeleted;
  end;

  {$M-}

  /// <summary>
  ///   DbContext for Dynamic Query Filter integration tests.
  /// </summary>
  TDqfContext = class(TDbContext)
  public
    function Tasks: IDbSet<TDqfTask>;
  end;

  // -----------------------------------------------------------------
  //  Unit tests - SQL generation level (no DB needed)
  // -----------------------------------------------------------------

  [Fixture]
  [Category('ORM'), Category('Unit'), Category('DynamicQueryFilter')]
  TDynamicQueryFilterUnitTests = class
  public
    [Test]
    procedure Test_SoftDeleteFilter_IsApplied_WhenNotIgnored;

    [Test]
    procedure Test_SoftDeleteFilter_IsRemoved_WhenIgnored;

    [Test]
    procedure Test_FluentQuery_IgnoreFilters_PropagatesFlag;

    [Test]
    procedure Test_Specification_IgnoreFilters_DisablesSoftDeleteClause;
  end;

  // -----------------------------------------------------------------
  //  Integration tests - end-to-end with SQLite in-memory
  // -----------------------------------------------------------------

  [Fixture]
  [Category('ORM'), Category('Integration'), Category('DynamicQueryFilter')]
  TDynamicQueryFilterIntegrationTests = class
  private
    FConn: TFDConnection;
    FContext: TDqfContext;
    procedure SetupDatabase;
    procedure SeedData;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_NormalQuery_HidesDeletedRecords;

    [Test]
    procedure Test_FluentQuery_IgnoreFilters_ReturnsAllRecords;

    [Test]
    procedure Test_Specification_IgnoreFilters_ReturnsAllRecords;

    [Test]
    procedure Test_DbSet_IgnoreFilters_ReturnsAllRecords;
  end;

implementation

// -----------------------------------------------------------------
//  Cracker to access protected GetSoftDeleteFilter
// -----------------------------------------------------------------

type
  TSqlGeneratorCracker<T: class> = class(TSqlGenerator<T>);

{ TDqfContext }

function TDqfContext.Tasks: IDbSet<TDqfTask>;
begin
  Result := Entities<TDqfTask>;
end;

{ TDynamicQueryFilterUnitTests }

procedure TDynamicQueryFilterUnitTests.Test_SoftDeleteFilter_IsApplied_WhenNotIgnored;
var
  Gen: TSqlGenerator<TDqfTask>;
  Filter: string;
begin
  Gen := TSqlGenerator<TDqfTask>.Create(TSQLiteDialect.Create, nil);
  try
    Gen.IgnoreQueryFilters := False;
    Filter := TSqlGeneratorCracker<TDqfTask>(Gen).GetSoftDeleteFilter;
    Should(Filter).NotBeEmpty;
    Should(Filter).Contain('IsDeleted');
  finally
    Gen.Free;
  end;
end;

procedure TDynamicQueryFilterUnitTests.Test_SoftDeleteFilter_IsRemoved_WhenIgnored;
var
  Gen: TSqlGenerator<TDqfTask>;
  Filter: string;
begin
  Gen := TSqlGenerator<TDqfTask>.Create(TSQLiteDialect.Create, nil);
  try
    Gen.IgnoreQueryFilters := True;
    Filter := TSqlGeneratorCracker<TDqfTask>(Gen).GetSoftDeleteFilter;
    Should(Filter).BeEmpty;
  finally
    Gen.Free;
  end;
end;

procedure TDynamicQueryFilterUnitTests.Test_FluentQuery_IgnoreFilters_PropagatesFlag;
var
  Spec: ISpecification<TDqfTask>;
  Query: TFluentQuery<TDqfTask>;
begin
  Spec := TSpecification<TDqfTask>.Create;
  Query := TFluentQuery<TDqfTask>.Create(nil, Spec);

  Should(Spec.IsIgnoringFilters).BeFalse;
  Query.IgnoreQueryFilters;
  Should(Spec.IsIgnoringFilters).BeTrue;
end;

procedure TDynamicQueryFilterUnitTests.Test_Specification_IgnoreFilters_DisablesSoftDeleteClause;
var
  Spec: ISpecification<TDqfTask>;
  Gen: TSqlGenerator<TDqfTask>;
  Filter: string;
begin
  Spec := TSpecification<TDqfTask>.Create;
  Spec.IgnoreQueryFilters;

  Gen := TSqlGenerator<TDqfTask>.Create(TSQLiteDialect.Create, nil);
  try
    // Simulate what ToList does: propagate flag from spec to generator
    Gen.IgnoreQueryFilters := Spec.IsIgnoringFilters;
    Filter := TSqlGeneratorCracker<TDqfTask>(Gen).GetSoftDeleteFilter;
    Should(Filter).BeEmpty;
  finally
    Gen.Free;
  end;
end;

{ TDynamicQueryFilterIntegrationTests }

procedure TDynamicQueryFilterIntegrationTests.Setup;
begin
  FConn := TFDConnection.Create(nil);
  FConn.DriverName := 'SQLite';
  FConn.Params.Add('Database=:memory:');
  FConn.Connected := True;

  SetupDatabase;
  FContext := TDqfContext.Create(TFireDACConnection.Create(FConn, False), TSQLiteDialect.Create);
  SeedData;
end;

procedure TDynamicQueryFilterIntegrationTests.TearDown;
begin
  FreeAndNil(FContext);
  FreeAndNil(FConn);
end;

procedure TDynamicQueryFilterIntegrationTests.SetupDatabase;
begin
  FConn.ExecSQL('CREATE TABLE dqf_tasks (Id INTEGER PRIMARY KEY, Title TEXT, IsDeleted INTEGER NOT NULL DEFAULT 0)');
end;

procedure TDynamicQueryFilterIntegrationTests.SeedData;
var
  Task: TDqfTask;
begin
  // Insert 2 active tasks
  Task := TDqfTask.Create;
  Task.Id := 1;
  Task.Title := 'Active Task 1';
  Task.IsDeleted := False;
  FContext.Tasks.Add(Task);
  FContext.SaveChanges;
  FContext.Clear;

  Task := TDqfTask.Create;
  Task.Id := 2;
  Task.Title := 'Active Task 2';
  Task.IsDeleted := False;
  FContext.Tasks.Add(Task);
  FContext.SaveChanges;
  FContext.Clear;

  // Insert and soft-delete a third task
  Task := TDqfTask.Create;
  Task.Id := 3;
  Task.Title := 'Deleted Task';
  Task.IsDeleted := False;
  FContext.Tasks.Add(Task);
  FContext.SaveChanges;
  FContext.Clear;

  Task := FContext.Tasks.Find(3);
  FContext.Tasks.Remove(Task);
  FContext.SaveChanges;
  FContext.Clear;
end;

procedure TDynamicQueryFilterIntegrationTests.Test_NormalQuery_HidesDeletedRecords;
var
  Tasks: IList<TDqfTask>;
begin
  Tasks := FContext.Tasks.ToList;
  // Soft-deleted record must be hidden by default
  Should(Tasks.Count).Be(2);
end;

procedure TDynamicQueryFilterIntegrationTests.Test_FluentQuery_IgnoreFilters_ReturnsAllRecords;
var
  Tasks: IList<TDqfTask>;
  Spec: ISpecification<TDqfTask>;
  Query: TFluentQuery<TDqfTask>;
begin
  // Create a spec and a fluent query pointing to it.
  // Calling IgnoreQueryFilters on the query propagates the flag to the spec.
  // Then pass the spec to ToList - this exercises the full Spec→DbSet path.
  Spec := TSpecification<TDqfTask>.Create;
  Query := TFluentQuery<TDqfTask>.Create(nil, Spec);
  Query.IgnoreQueryFilters;

  Tasks := FContext.Tasks.ToList(Spec);
  // All 3 records (including soft-deleted) must be returned
  Should(Tasks.Count).Be(3);
end;

procedure TDynamicQueryFilterIntegrationTests.Test_Specification_IgnoreFilters_ReturnsAllRecords;
var
  Tasks: IList<TDqfTask>;
  Spec: ISpecification<TDqfTask>;
begin
  Spec := TSpecification<TDqfTask>.Create;
  Spec.IgnoreQueryFilters;

  Tasks := FContext.Tasks.ToList(Spec);
  // All 3 records must be returned when spec has IgnoreQueryFilters
  Should(Tasks.Count).Be(3);
end;

procedure TDynamicQueryFilterIntegrationTests.Test_DbSet_IgnoreFilters_ReturnsAllRecords;
var
  Tasks: IList<TDqfTask>;
begin
  Tasks := FContext.Tasks.IgnoreQueryFilters.ToList;
  // All 3 records must be returned via the direct DbSet.IgnoreQueryFilters path
  Should(Tasks.Count).Be(3);
end;

end.
