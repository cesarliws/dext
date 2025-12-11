unit Dext.Entity.Dialect.PostgreSQL.Test;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Entity.Dialects,
  Dext.Entity.Attributes;

type
  TPostgreSQLDialectTest = class
  private
    FDialect: TPostgreSQLDialect;
    procedure AssertEqual(const Expected, Actual, Msg: string);
    procedure Log(const Msg: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
  end;

implementation

{ TPostgreSQLDialectTest }

constructor TPostgreSQLDialectTest.Create;
begin
  FDialect := TPostgreSQLDialect.Create;
end;

destructor TPostgreSQLDialectTest.Destroy;
begin
  FDialect.Free;
  inherited;
end;

procedure TPostgreSQLDialectTest.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

procedure TPostgreSQLDialectTest.AssertEqual(const Expected, Actual, Msg: string);
begin
  if Expected = Actual then
    WriteLn('   ✅ ', Msg)
  else
  begin
    WriteLn('   ❌ ', Msg);
    WriteLn('      Expected: ', Expected);
    WriteLn('      Actual:   ', Actual);
  end;
end;

procedure TPostgreSQLDialectTest.Run;
begin
  Log('🐘 Testing PostgreSQL Dialect');
  Log('-----------------------------');

  // 1. Identifiers
  AssertEqual('"Users"', FDialect.QuoteIdentifier('Users'), 'QuoteIdentifier should add double quotes');
  AssertEqual('"user_accounts"', FDialect.QuoteIdentifier('user_accounts'), 'QuoteIdentifier should preserve case/underscore');

  // 2. Booleans
  AssertEqual('TRUE', FDialect.BooleanToSQL(True), 'BooleanToSQL(True) should be TRUE');
  AssertEqual('FALSE', FDialect.BooleanToSQL(False), 'BooleanToSQL(False) should be FALSE');

  // 3. Paging
  AssertEqual('LIMIT 10 OFFSET 0', FDialect.GeneratePaging(0, 10), 'Paging (Skip 0, Take 10)');
  AssertEqual('LIMIT 50 OFFSET 20', FDialect.GeneratePaging(20, 50), 'Paging (Skip 20, Take 50)');

  // 4. Column Types
  AssertEqual('INTEGER', FDialect.GetColumnType(TypeInfo(Integer)), 'Integer mapping');
  AssertEqual('BIGINT', FDialect.GetColumnType(TypeInfo(Int64)), 'Int64 mapping');
  AssertEqual('VARCHAR(255)', FDialect.GetColumnType(TypeInfo(string)), 'String mapping');
  AssertEqual('BOOLEAN', FDialect.GetColumnType(TypeInfo(Boolean)), 'Boolean mapping');
  AssertEqual('TIMESTAMP', FDialect.GetColumnType(TypeInfo(TDateTime)), 'DateTime mapping');
  AssertEqual('DOUBLE PRECISION', FDialect.GetColumnType(TypeInfo(Double)), 'Double mapping');
  AssertEqual('MONEY', FDialect.GetColumnType(TypeInfo(Currency)), 'Currency mapping');
  
  // 5. AutoInc
  AssertEqual('SERIAL', FDialect.GetColumnType(TypeInfo(Integer), True), 'AutoInc Integer should be SERIAL');
  
  // 6. Last Insert ID
  AssertEqual('SELECT lastval()', FDialect.GetLastInsertIdSQL, 'Last Insert ID SQL');

  // 7. Create Table
  AssertEqual('CREATE TABLE IF NOT EXISTS "Users" (Id SERIAL PRIMARY KEY);', 
    FDialect.GetCreateTableSQL('"Users"', 'Id SERIAL PRIMARY KEY'), 'Create Table SQL');

  // 8. UUID Support (Check current behavior)
  // Note: Currently TGuid might fall back to TEXT or fail if not explicitly handled.
  // Let's see what it does.
  AssertEqual('UUID', FDialect.GetColumnType(TypeInfo(TGUID)), 'GUID mapping should be UUID');
end;

end.
