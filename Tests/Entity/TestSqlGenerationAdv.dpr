program TestSqlGenerationAdv;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  Dext.Entity.Dialects,
  Dext.Entity.Attributes,
  Dext.Specifications.SQL.Generator,
  Dext.Entity.Mapping,
  System.Generics.Collections;

type
  [Table('test_advanced_types')]
  TAdvancedEntity = class
  private
    FId: Integer;
    FDate: TDate;
    FTime: TTime;
    FDateTime: TDateTime;
    FDescription: string;
    FData: TBytes;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    [Column('date_col')]
    property Date: TDate read FDate write FDate;
    [Column('time_col')]
    property Time: TTime read FTime write FTime;
    [Column('datetime_col')]
    property DateTime: TDateTime read FDateTime write FDateTime;
    [Column('description')]
    property Description: string read FDescription write FDescription;
    [Column('binary_data')]
    property Data: TBytes read FData write FData;
  end;

procedure TestPostgreSQL;
var
  Generator: TSqlGenerator<TAdvancedEntity>;
  Dialect: ISQLDialect;
  Entity: TAdvancedEntity;
begin
  WriteLn('--- PostgreSQL ---');
  Dialect := TPostgreSQLDialect.Create;
  Generator := TSqlGenerator<TAdvancedEntity>.Create(Dialect, nil);
  try
    WriteLn('DDL:');
    WriteLn(Generator.GenerateCreateTable('test_advanced_types'));
    
    Entity := TAdvancedEntity.Create;
    try
      WriteLn('Insert SQL:');
      WriteLn(Generator.GenerateInsert(Entity));
    finally
      Entity.Free;
    end;
  finally
    Generator.Free;
  end;
  WriteLn;
end;

procedure TestSQLite;
var
  Generator: TSqlGenerator<TAdvancedEntity>;
  Dialect: ISQLDialect;
begin
  WriteLn('--- SQLite ---');
  Dialect := TSQLiteDialect.Create;
  Generator := TSqlGenerator<TAdvancedEntity>.Create(Dialect, nil);
  try
    WriteLn(Generator.GenerateCreateTable('test_advanced_types'));
  finally
    Generator.Free;
  end;
  WriteLn;
end;

procedure TestSQLServer;
var
  Generator: TSqlGenerator<TAdvancedEntity>;
  Dialect: ISQLDialect;
begin
  WriteLn('--- SQL Server ---');
  Dialect := TSQLServerDialect.Create;
  Generator := TSqlGenerator<TAdvancedEntity>.Create(Dialect, nil);
  try
    WriteLn(Generator.GenerateCreateTable('test_advanced_types'));
  finally
    Generator.Free;
  end;
  WriteLn;
end;

begin
  try
    TestPostgreSQL;
    TestSQLite;
    TestSQLServer;
    WriteLn('--- End of Tests ---');
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.
