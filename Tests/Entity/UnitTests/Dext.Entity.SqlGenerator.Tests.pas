unit Dext.Entity.SqlGenerator.Tests;

interface

uses
  System.SysUtils,
  System.Rtti,
{$IFDEF CONSOLE}
  FireDAC.ConsoleUI.Wait,
{$ELSE}
  FireDAC.VCLUI.Wait,
{$ENDIF}
  Dext.Mocks,
  Dext.Mocks.Matching,
  Dext.Testing,
  Dext.Testing.Attributes,

  Dext.Entity.Dialects,
  Dext.Specifications.SQL.Generator,
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces,
  Dext.Entity,
  Dext.Entity.Attributes,
  Dext.Entity.Mapping,
  Dext.Entity.Core;

type
  {$M+}
  [Table('Users')]
  TTestUser = class
  private
    FId: Integer;
    FName: string;
    FIsDeleted: Boolean;
  public
    [PK] property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property IsDeleted: Boolean read FIsDeleted write FIsDeleted;
  end;
  {$M-}

  // Entity that mirrors the real-world pattern reported:
  // [Column('ID'), PK, AutoInc] on an Integer field with Firebird dialect.
  [Table('COMPANY')]
  TEmpresaAutoInc = class
  private
    FId: Integer;
    FName: string;
  public
    [Column('ID'), PK, AutoInc]
    property Id: Integer read FId write FId;
    [Column('NAME')]
    property Name: string read FName write FName;
  end;

  // Entity that uses AutoInc without an explicit [Column] name, to ensure the
  // auto-discovered PropMap.DataType path is also handled correctly.
  [Table('simple_autoinc')]
  TSimpleAutoInc = class
  private
    FId: Integer;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
  end;

  [TestFixture('SQL Generator Tests (Mocked Dialect)')]
  TSqlGeneratorTests = class
  private
    FDialectMock: Mock<ISQLDialect>;
    FGenerator: TSqlGenerator<TTestUser>;
  public
    [Setup]
    procedure Setup;
    
    [Teardown]
    procedure Teardown;

    [Test]
    procedure Test_GenerateSelect_Basic;
    
    [Test]
    procedure Test_GenerateSelect_WithIgnoreFilters;
  end;

  // Regression tests: GenerateCreateTable must produce dialect-specific IDENTITY syntax
  // even when PropMap.DataType is filled by auto-discovery (non-ftUnknown).
  // Bug: DiscoverAttributes always sets PropMap.DataType = ftInteger for Integer properties,
  // causing GenerateCreateTable to call GetColumnTypeForField(ftInteger, True) which returns
  // plain 'INTEGER' instead of the correct identity syntax.
  [TestFixture('GenerateCreateTable AutoInc Tests')]
  TCreateTableAutoIncTests = class
  public
    [Test]
    // Firebird + [Column('ID'), PK, AutoInc] - mirrors TEmpresa from the Evo project.
    procedure Test_Firebird_ColumnAttr_AutoInc_ProducesIdentity;

    [Test]
    // Firebird + [PK, AutoInc] without explicit [Column] name.
    procedure Test_Firebird_NoColumnAttr_AutoInc_ProducesIdentity;

    [Test]
    // PostgreSQL + [PK, AutoInc] must produce SERIAL.
    procedure Test_PostgreSQL_AutoInc_ProducesSerial;

    [Test]
    // SQL Server + [PK, AutoInc] must produce INT IDENTITY(1,1).
    procedure Test_SQLServer_AutoInc_ProducesIdentity;
  end;

implementation

{ TSqlGeneratorTests }

procedure TSqlGeneratorTests.Setup;
begin
  // Register the entity to ensure mapping is discovered correctly
  TModelBuilder.Instance.Entity<TTestUser>.Table('Users');
  TModelBuilder.Instance.Entity<TTestUser>.Prop('IsDeleted').Ignore();

  FDialectMock := Mock<ISQLDialect>.Create;
  
  // Setup default dialect behavior: QuoteIdentifier just wraps in brackets
  FDialectMock
    .Setup.Executes(procedure(Inv: IInvocation)
      begin
        Inv.Result := '[' + Inv.Arguments[0].AsString + ']';

      end)
    .When.QuoteIdentifier(Arg.Any<string>);

  // Default schema behavior
  FDialectMock.Setup.Returns(TValue.From<Boolean>(False)).When.UseSchemaPrefix;

  FGenerator := TSqlGenerator<TTestUser>.Create(FDialectMock.Instance, nil);
end;

procedure TSqlGeneratorTests.Teardown;
begin
  FGenerator.Free;
end;

procedure TSqlGeneratorTests.Test_GenerateSelect_Basic;
var
  Spec: ISpecification<TTestUser>;
  SQL: string;
begin
  Spec := TSpecification<TTestUser>.Create;
  SQL := FGenerator.GenerateSelect(Spec);
  
  // Simple check: SQL should contain our quoted table and columns
  Should(SQL).Contain('FROM [Users]');
  Should(SQL).Contain('[Id]');
  Should(SQL).Contain('[Name]');
end;

procedure TSqlGeneratorTests.Test_GenerateSelect_WithIgnoreFilters;
var
  Spec: ISpecification<TTestUser>;
  SQL: string;
begin
  Spec := TSpecification<TTestUser>.Create;
  
  // By default, it might have filters if TTestUser was soft-delete (managed via mapping)
  // Let's force a filter in the generator to test the override
  
  FGenerator.IgnoreQueryFilters := True;
  SQL := FGenerator.GenerateSelect(Spec);
  
  // If IgnoreQueryFilters is True, it should not append soft delete WHERE clauses
  // This depends on TSqlGenerator implementation details we just enhanced
  
  Should(SQL).NotContain('IsDeleted'); // In this mock setup, no filter should be added
end;

{ TCreateTableAutoIncTests }

procedure TCreateTableAutoIncTests.Test_Firebird_ColumnAttr_AutoInc_ProducesIdentity;
var
  Generator: TSqlGenerator<TEmpresaAutoInc>;
  SQL: string;
begin
  Generator := TSqlGenerator<TEmpresaAutoInc>.Create(TFirebirdDialect.Create, nil);
  try
    SQL := Generator.GenerateCreateTable('"EMPRESA"');
    // The ID column must use Firebird identity syntax, not plain INTEGER
    Should(SQL).Contain('INTEGER GENERATED BY DEFAULT AS IDENTITY');
    Should(SQL).NotContain('"ID" INTEGER PRIMARY KEY');
  finally
    Generator.Free;
  end;
end;

procedure TCreateTableAutoIncTests.Test_Firebird_NoColumnAttr_AutoInc_ProducesIdentity;
var
  Generator: TSqlGenerator<TSimpleAutoInc>;
  SQL: string;
begin
  Generator := TSqlGenerator<TSimpleAutoInc>.Create(TFirebirdDialect.Create, nil);
  try
    SQL := Generator.GenerateCreateTable('"simple_autoinc"');
    Should(SQL).Contain('INTEGER GENERATED BY DEFAULT AS IDENTITY');
  finally
    Generator.Free;
  end;
end;

procedure TCreateTableAutoIncTests.Test_PostgreSQL_AutoInc_ProducesSerial;
var
  Generator: TSqlGenerator<TSimpleAutoInc>;
  SQL: string;
begin
  Generator := TSqlGenerator<TSimpleAutoInc>.Create(TPostgreSQLDialect.Create, nil);
  try
    SQL := Generator.GenerateCreateTable('"simple_autoinc"');
    Should(SQL).Contain('SERIAL');
  finally
    Generator.Free;
  end;
end;

procedure TCreateTableAutoIncTests.Test_SQLServer_AutoInc_ProducesIdentity;
var
  Generator: TSqlGenerator<TSimpleAutoInc>;
  SQL: string;
begin
  Generator := TSqlGenerator<TSimpleAutoInc>.Create(TSQLServerDialect.Create, nil);
  try
    SQL := Generator.GenerateCreateTable('[simple_autoinc]');
    Should(SQL).Contain('IDENTITY');
  finally
    Generator.Free;
  end;
end;

end.
