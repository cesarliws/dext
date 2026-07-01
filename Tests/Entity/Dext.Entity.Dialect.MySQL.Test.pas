unit Dext.Entity.Dialect.MySQL.Test;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Entity.Dialects,
  Dext.Entity.Attributes;

type
  TMySQLDialectTest = class
  private
    FDialect: TMySQLDialect;
    procedure AssertEqual(const Expected, Actual, Msg: string);
    procedure Log(const Msg: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run;
  end;

implementation

{ TMySQLDialectTest }

constructor TMySQLDialectTest.Create;
begin
  FDialect := TMySQLDialect.Create;
end;

destructor TMySQLDialectTest.Destroy;
begin
  FDialect.Free;
  inherited;
end;

procedure TMySQLDialectTest.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

procedure TMySQLDialectTest.AssertEqual(const Expected, Actual, Msg: string);
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

procedure TMySQLDialectTest.Run;
begin
  Log('🐬 Testing MySQL Dialect');
  Log('------------------------');

  // 1. Identifiers
  AssertEqual('`Users`', FDialect.QuoteIdentifier('Users'), 'QuoteIdentifier should add backticks');

  // 2. Booleans
  AssertEqual('1', FDialect.BooleanToSQL(True), 'BooleanToSQL(True) should be 1');
  AssertEqual('0', FDialect.BooleanToSQL(False), 'BooleanToSQL(False) should be 0');

  // 3. Paging
  AssertEqual('SELECT * FROM Users LIMIT 10 OFFSET 0', FDialect.GeneratePaging('SELECT * FROM Users', 0, 10), 'Paging (Skip 0, Take 10)');
  
  // 4. Column Types
  AssertEqual('INT', FDialect.GetColumnType(TypeInfo(Integer)), 'Integer mapping');
  AssertEqual('BIGINT', FDialect.GetColumnType(TypeInfo(Int64)), 'Int64 mapping');
  AssertEqual('VARCHAR(255)', FDialect.GetColumnType(TypeInfo(string)), 'String mapping');
  AssertEqual('TINYINT(1)', FDialect.GetColumnType(TypeInfo(Boolean)), 'Boolean mapping');
  AssertEqual('DATETIME', FDialect.GetColumnType(TypeInfo(TDateTime)), 'DateTime mapping');
  AssertEqual('DOUBLE', FDialect.GetColumnType(TypeInfo(Double)), 'Double mapping');
  AssertEqual('DECIMAL(15,2)', FDialect.GetColumnType(TypeInfo(Currency)), 'Currency mapping');
  
  // 5. AutoInc
  AssertEqual('INT AUTO_INCREMENT', FDialect.GetColumnType(TypeInfo(Integer), True), 'AutoInc Integer should be AUTO_INCREMENT');
  
  // 6. Last Insert ID
  AssertEqual('SELECT LAST_INSERT_ID()', FDialect.GetLastInsertIdSQL, 'Last Insert ID SQL');

  // 7. UUID Support
  AssertEqual('CHAR(36)', FDialect.GetColumnType(TypeInfo(TGUID)), 'GUID mapping should be CHAR(36)');

  // 8. MariaDB Sequence Support
  var LMariaDBDialect := TMariaDBDialect.Create;
  try
    AssertEqual('SELECT 1 FROM information_schema.TABLES ' +
      'WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ''SEQ_TEST'' ' +
      'AND TABLE_TYPE = ''SEQUENCE''',
      LMariaDBDialect.GetSequenceExistsSQL('SEQ_TEST'), 'MariaDB Sequence Exists SQL');
    AssertEqual('CREATE SEQUENCE SEQ_TEST INCREMENT BY 50 START WITH 50',
      LMariaDBDialect.GetCreateSequenceSQL('SEQ_TEST', 50), 'MariaDB Create Sequence with allocation size');
    AssertEqual('CREATE SEQUENCE SEQ_TEST',
      LMariaDBDialect.GetCreateSequenceSQL('SEQ_TEST', 1), 'MariaDB Create Sequence with default size');
    AssertEqual('SELECT NEXTVAL(SEQ_TEST)',
      LMariaDBDialect.GetSequenceNextValSQL('SEQ_TEST', 50), 'MariaDB Get Sequence NextVal SQL');
  finally
    LMariaDBDialect.Free;
  end;
end;

end.
