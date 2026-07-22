unit Dext.Entity.Dialect.MSSQL.Test;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Entity.Dialects,
  Dext.Entity.Attributes,
  Dext.Specifications.Interfaces;

type
  TSQLServerDialectTest = class
  private
    FDialect: TSQLServerDialect;
    procedure AssertEqual(const Expected, Actual, Msg: string);
    procedure Log(const Msg: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
    procedure TestLockingSQL;
  end;

implementation

{ TSQLServerDialectTest }

constructor TSQLServerDialectTest.Create;
begin
  FDialect := TSQLServerDialect.Create;
end;

destructor TSQLServerDialectTest.Destroy;
begin
  FDialect.Free;
  inherited;
end;

procedure TSQLServerDialectTest.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

procedure TSQLServerDialectTest.AssertEqual(const Expected, Actual, Msg: string);
begin
  if Expected = Actual then
    WriteLn('   [PASS] ', Msg)
  else
  begin
    WriteLn('   [FAIL] ', Msg);
    WriteLn('      Expected: ', Expected);
    WriteLn('      Actual:   ', Actual);
  end;
end;

procedure TSQLServerDialectTest.Run;
begin
  Log('ðŸ¢ Testing SQL Server Dialect');
  Log('-----------------------------');

  // 1. Identifiers
  AssertEqual('[Users]', FDialect.QuoteIdentifier('Users'), 'QuoteIdentifier should add brackets');

  // 2. Booleans
  AssertEqual('1', FDialect.BooleanToSQL(True), 'BooleanToSQL(True) should be 1');
  AssertEqual('0', FDialect.BooleanToSQL(False), 'BooleanToSQL(False) should be 0');

  // 3. Paging
  AssertEqual('SELECT * FROM Users ORDER BY ID OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY', FDialect.GeneratePaging('SELECT * FROM Users ORDER BY ID', 0, 10), 'Paging (Skip 0, Take 10)');
  
  // 4. Column Types
  AssertEqual('INT', FDialect.GetColumnType(TypeInfo(Integer)), 'Integer mapping');
  AssertEqual('BIGINT', FDialect.GetColumnType(TypeInfo(Int64)), 'Int64 mapping');
  AssertEqual('NVARCHAR(255)', FDialect.GetColumnType(TypeInfo(string)), 'String mapping');
  AssertEqual('BIT', FDialect.GetColumnType(TypeInfo(Boolean)), 'Boolean mapping');
  AssertEqual('DATETIME2', FDialect.GetColumnType(TypeInfo(TDateTime)), 'DateTime mapping');
  AssertEqual('FLOAT', FDialect.GetColumnType(TypeInfo(Double)), 'Double mapping');
  AssertEqual('MONEY', FDialect.GetColumnType(TypeInfo(Currency)), 'Currency mapping');
  
  // 5. AutoInc
  AssertEqual('INT IDENTITY(1,1)', FDialect.GetColumnType(TypeInfo(Integer), True), 'AutoInc Integer should be IDENTITY');
  
  // 6. Last Insert ID
  AssertEqual('SELECT SCOPE_IDENTITY()', FDialect.GetLastInsertIdSQL, 'Last Insert ID SQL');

  // 7. UUID Support
  AssertEqual('UNIQUEIDENTIFIER', FDialect.GetColumnType(TypeInfo(TGUID)), 'GUID mapping should be UNIQUEIDENTIFIER');

  // 8. Stored Procedure Call
  AssertEqual('EXEC CalculateBonus :pEmpId, :pAmount', 
    FDialect.GenerateProcedureCallSQL('CalculateBonus', ['pEmpId', 'pAmount']), 'Procedure Call SQL');

  // 9. Locking SQL
  TestLockingSQL;
end;

procedure TSQLServerDialectTest.TestLockingSQL;
var
  SQL: string;
begin
  Log('9. Locking SQL');
  Log('-----------------');
  SQL := FDialect.GetLockingSQL(lmExclusive);
  AssertEqual('WITH (UPDLOCK, ROWLOCK)', SQL, 'GetLockingSQL(lmExclusive) should be WITH (UPDLOCK, ROWLOCK)');
end;

end.
