{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Dialects;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Entity.Attributes,
  Dext.Entity.Migrations.Operations;

type
  TReturningPosition = (rpAtEnd, rpBeforeValues);

  /// <summary>
  ///   Abstracts database-specific SQL syntax differences.
  /// </summary>
  ISQLDialect = interface
    ['{20000000-0000-0000-0000-000000000001}']
    function QuoteIdentifier(const AName: string): string;
    function GetParamPrefix: string;
    function GeneratePaging(ASkip, ATake: Integer): string;
    function BooleanToSQL(AValue: Boolean): string;
    function GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean = False): string;
    function GetCascadeActionSQL(AAction: TCascadeAction): string;
    function GetLastInsertIdSQL: string;
    function GetCreateTableSQL(const ATableName, ABody: string): string;
    
    // New methods for RETURNING clause support
    function SupportsInsertReturning: Boolean;
    function GetReturningSQL(const AColumnName: string): string;
    function GetReturningPosition: TReturningPosition;

    // Paging support
    function RequiresOrderByForPaging: Boolean;
    
    // Migration Support
    function GenerateMigration(AOperation: TMigrationOperation): string;
    function GenerateColumnDefinition(AColumn: TColumnDefinition): string;
  end;

  /// <summary>
  ///   Base class for dialects.
  /// </summary>
  TBaseDialect = class(TInterfacedObject, ISQLDialect)
  protected
    function GenerateCreateTable(AOp: TCreateTableOperation): string; virtual;
    function GenerateDropTable(AOp: TDropTableOperation): string; virtual;
    function GenerateAddColumn(AOp: TAddColumnOperation): string; virtual;
    function GenerateDropColumn(AOp: TDropColumnOperation): string; virtual;
    function GenerateAlterColumn(AOp: TAlterColumnOperation): string; virtual;
    function GenerateAddForeignKey(AOp: TAddForeignKeyOperation): string; virtual;
    function GenerateDropForeignKey(AOp: TDropForeignKeyOperation): string; virtual;
    function GenerateCreateIndex(AOp: TCreateIndexOperation): string; virtual;
    function GenerateDropIndex(AOp: TDropIndexOperation): string; virtual;
  public
    function QuoteIdentifier(const AName: string): string; virtual;
    function GetParamPrefix: string; virtual;
    function GeneratePaging(ASkip, ATake: Integer): string; virtual; abstract;
    function BooleanToSQL(AValue: Boolean): string; virtual;
    function GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean = False): string; virtual; abstract;
    function GetCascadeActionSQL(AAction: TCascadeAction): string; virtual;
    function GetLastInsertIdSQL: string; virtual; abstract;
    function GetCreateTableSQL(const ATableName, ABody: string): string; virtual;
    
    function SupportsInsertReturning: Boolean; virtual;
    function GetReturningSQL(const AColumnName: string): string; virtual;
    function GetReturningPosition: TReturningPosition; virtual;

    function RequiresOrderByForPaging: Boolean; virtual;
    
    function GenerateMigration(AOperation: TMigrationOperation): string; virtual;
    function GenerateColumnDefinition(AColumn: TColumnDefinition): string; virtual;
  end;

  /// <summary>
  ///   SQLite Dialect implementation.
  /// </summary>
  TSQLiteDialect = class(TBaseDialect)
  public
    function QuoteIdentifier(const AName: string): string; override;
    function GeneratePaging(ASkip, ATake: Integer): string; override;
    function BooleanToSQL(AValue: Boolean): string; override;
    function GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean = False): string; override;
    function GetLastInsertIdSQL: string; override;
    function GetCreateTableSQL(const ATableName, ABody: string): string; override;
  end;

  /// <summary>
  ///   PostgreSQL Dialect implementation.
  /// </summary>
  TPostgreSQLDialect = class(TBaseDialect)
  public
    function QuoteIdentifier(const AName: string): string; override;
    function GeneratePaging(ASkip, ATake: Integer): string; override;
    function BooleanToSQL(AValue: Boolean): string; override;
    function GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean = False): string; override;
    function GetLastInsertIdSQL: string; override;
    function GetCreateTableSQL(const ATableName, ABody: string): string; override;
    
    function SupportsInsertReturning: Boolean; override;
    function GetReturningSQL(const AColumnName: string): string; override;
  end;

  /// <summary>
  ///   Firebird 3.0+ Dialect implementation.
  /// </summary>
  TFirebirdDialect = class(TBaseDialect)
  public
    function QuoteIdentifier(const AName: string): string; override;
    function GeneratePaging(ASkip, ATake: Integer): string; override;
    function BooleanToSQL(AValue: Boolean): string; override;
    function GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean = False): string; override;
    function GetLastInsertIdSQL: string; override;
    function GetCreateTableSQL(const ATableName, ABody: string): string; override;
    
    function SupportsInsertReturning: Boolean; override;
    function GetReturningSQL(const AColumnName: string): string; override;
  end;

  /// <summary>
  ///   SQL Server (2012+) Dialect implementation.
  /// </summary>
  TSQLServerDialect = class(TBaseDialect)
  public
    function QuoteIdentifier(const AName: string): string; override;
    function GeneratePaging(ASkip, ATake: Integer): string; override;
    function BooleanToSQL(AValue: Boolean): string; override;
    function GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean = False): string; override;
    function GetLastInsertIdSQL: string; override;
    function GetCreateTableSQL(const ATableName, ABody: string): string; override;
    
    function SupportsInsertReturning: Boolean; override;
    function GetReturningSQL(const AColumnName: string): string; override;
    function GetReturningPosition: TReturningPosition; override;
    function RequiresOrderByForPaging: Boolean; override;
  end;

  /// <summary>
  ///   MySQL / MariaDB Dialect implementation.
  /// </summary>
  TMySQLDialect = class(TBaseDialect)
  public
    function QuoteIdentifier(const AName: string): string; override;
    function GeneratePaging(ASkip, ATake: Integer): string; override;
    function BooleanToSQL(AValue: Boolean): string; override;
    function GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean = False): string; override;
    function GetLastInsertIdSQL: string; override;
    function GetCreateTableSQL(const ATableName, ABody: string): string; override;
    
    function GenerateAlterColumn(AOp: TAlterColumnOperation): string; override;
  end;

  /// <summary>
  ///   Oracle (12c+) Dialect implementation.
  /// </summary>
  TOracleDialect = class(TBaseDialect)
  public
    function QuoteIdentifier(const AName: string): string; override;
    function GeneratePaging(ASkip, ATake: Integer): string; override;
    function BooleanToSQL(AValue: Boolean): string; override;
    function GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean = False): string; override;
    function GetLastInsertIdSQL: string; override;
    function GetCreateTableSQL(const ATableName, ABody: string): string; override;
    
    function SupportsInsertReturning: Boolean; override;
    function GetReturningSQL(const AColumnName: string): string; override;
  end;

implementation

{ TBaseDialect }

function TBaseDialect.BooleanToSQL(AValue: Boolean): string;
begin
  if AValue then Result := '1' else Result := '0';
end;

function TBaseDialect.GetParamPrefix: string;
begin
  Result := ':'; // Standard for FireDAC
end;

function TBaseDialect.QuoteIdentifier(const AName: string): string;
begin
  Result := '"' + AName + '"';
end;

function TBaseDialect.GetCascadeActionSQL(AAction: TCascadeAction): string;
begin
  case AAction of
    caNoAction: Result := 'NO ACTION';
    caCascade:  Result := 'CASCADE';
    caSetNull:  Result := 'SET NULL';
    caRestrict: Result := 'RESTRICT';
  else
    Result := 'NO ACTION';
  end;
end;

function TBaseDialect.GetCreateTableSQL(const ATableName, ABody: string): string;
begin
  // Default implementation (Standard SQL)
  Result := Format('CREATE TABLE %s (%s);', [ATableName, ABody]);
end;

function TBaseDialect.GenerateMigration(AOperation: TMigrationOperation): string;
begin
  case AOperation.OperationType of
    otCreateTable: Result := GenerateCreateTable(TCreateTableOperation(AOperation));
    otDropTable: Result := GenerateDropTable(TDropTableOperation(AOperation));
    otAddColumn: Result := GenerateAddColumn(TAddColumnOperation(AOperation));
    otDropColumn: Result := GenerateDropColumn(TDropColumnOperation(AOperation));
    otAlterColumn: Result := GenerateAlterColumn(TAlterColumnOperation(AOperation));
    otAddForeignKey: Result := GenerateAddForeignKey(TAddForeignKeyOperation(AOperation));
    otDropForeignKey: Result := GenerateDropForeignKey(TDropForeignKeyOperation(AOperation));
    otCreateIndex: Result := GenerateCreateIndex(TCreateIndexOperation(AOperation));
    otDropIndex: Result := GenerateDropIndex(TDropIndexOperation(AOperation));
    otSql: Result := TSqlOperation(AOperation).Sql;
  else
    Result := '-- Unknown operation';
  end;
end;

function TBaseDialect.GenerateColumnDefinition(AColumn: TColumnDefinition): string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append(QuoteIdentifier(AColumn.Name));
    SB.Append(' ');
    
    // Type
    SB.Append(AColumn.ColumnType);
    if AColumn.Length > 0 then
    begin
      SB.Append('(');
      SB.Append(AColumn.Length);
      if AColumn.Scale > 0 then
      begin
        SB.Append(',');
        SB.Append(AColumn.Scale); // Actually Precision, Scale usually goes together
      end;
      SB.Append(')');
    end
    else if (AColumn.Precision > 0) then
    begin
      SB.Append('(');
      SB.Append(AColumn.Precision);
      if AColumn.Scale > 0 then
      begin
        SB.Append(',');
        SB.Append(AColumn.Scale);
      end;
      SB.Append(')');
    end;
    
    // Nullable
    if not AColumn.IsNullable then
      SB.Append(' NOT NULL');
      
    // Identity - Note: Some DBs handle this in Type (SERIAL), others here
    if AColumn.IsIdentity then
    begin
      // Basic standard SQL identity, might need override in specific dialects
      // For now, assume the Type handles it (e.g. SERIAL) or we append generated
      // This is tricky for base dialect.
      // Let's assume the user set the correct Type for Identity if it's type-based (SERIAL)
      // Or we append 'GENERATED BY DEFAULT AS IDENTITY' for standard SQL
      // But TSQLiteDialect uses INTEGER PRIMARY KEY for autoinc.
      // Let's leave it to specific dialects or assume the Type string is correct for now.
    end;
    
    // Default
    if AColumn.DefaultValue <> '' then
    begin
      SB.Append(' DEFAULT ');
      SB.Append(AColumn.DefaultValue);
    end;
    
    // Primary Key (Inline)
    if AColumn.IsPrimaryKey then
      SB.Append(' PRIMARY KEY');
      
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TBaseDialect.GenerateCreateTable(AOp: TCreateTableOperation): string;
var
  SB: TStringBuilder;
  i: Integer;
begin
  SB := TStringBuilder.Create;
  try
    for i := 0 to AOp.Columns.Count - 1 do
    begin
      if i > 0 then SB.Append(', ');
      SB.Append(GenerateColumnDefinition(AOp.Columns[i]));
    end;
    
    // Composite PKs (if not inline)
    if (Length(AOp.PrimaryKey) > 1) then
    begin
      SB.Append(', PRIMARY KEY (');
      for i := 0 to High(AOp.PrimaryKey) do
      begin
        if i > 0 then SB.Append(', ');
        SB.Append(QuoteIdentifier(AOp.PrimaryKey[i]));
      end;
      SB.Append(')');
    end;
    
    Result := GetCreateTableSQL(QuoteIdentifier(AOp.Name), SB.ToString);
  finally
    SB.Free;
  end;
end;

function TBaseDialect.GenerateDropTable(AOp: TDropTableOperation): string;
begin
  Result := 'DROP TABLE ' + QuoteIdentifier(AOp.Name);
end;

function TBaseDialect.GenerateAddColumn(AOp: TAddColumnOperation): string;
begin
  Result := Format('ALTER TABLE %s ADD %s', [QuoteIdentifier(AOp.TableName), GenerateColumnDefinition(AOp.Column)]);
end;

function TBaseDialect.GenerateDropColumn(AOp: TDropColumnOperation): string;
begin
  Result := Format('ALTER TABLE %s DROP COLUMN %s', [QuoteIdentifier(AOp.TableName), QuoteIdentifier(AOp.Name)]);
end;

function TBaseDialect.GenerateAlterColumn(AOp: TAlterColumnOperation): string;
begin
  // Standard SQL often uses ALTER COLUMN or MODIFY COLUMN.
  // This is highly dialect specific.
  // Base implementation: ALTER COLUMN
  Result := Format('ALTER TABLE %s ALTER COLUMN %s', [QuoteIdentifier(AOp.TableName), GenerateColumnDefinition(AOp.Column)]);
end;

function TBaseDialect.GenerateAddForeignKey(AOp: TAddForeignKeyOperation): string;
var
  Cols, RefCols: string;
  i: Integer;
begin
  Cols := '';
  for i := 0 to High(AOp.Columns) do
  begin
    if i > 0 then Cols := Cols + ', ';
    Cols := Cols + QuoteIdentifier(AOp.Columns[i]);
  end;
  
  RefCols := '';
  for i := 0 to High(AOp.ReferencedColumns) do
  begin
    if i > 0 then RefCols := RefCols + ', ';
    RefCols := RefCols + QuoteIdentifier(AOp.ReferencedColumns[i]);
  end;

  Result := Format('ALTER TABLE %s ADD CONSTRAINT %s FOREIGN KEY (%s) REFERENCES %s (%s)',
    [QuoteIdentifier(AOp.Table), QuoteIdentifier(AOp.Name), Cols, QuoteIdentifier(AOp.ReferencedTable), RefCols]);
    
  if AOp.OnDelete <> '' then
    Result := Result + ' ON DELETE ' + AOp.OnDelete;
    
  if AOp.OnUpdate <> '' then
    Result := Result + ' ON UPDATE ' + AOp.OnUpdate;
end;

function TBaseDialect.GenerateDropForeignKey(AOp: TDropForeignKeyOperation): string;
begin
  Result := Format('ALTER TABLE %s DROP CONSTRAINT %s', [QuoteIdentifier(AOp.Table), QuoteIdentifier(AOp.Name)]);
end;

function TBaseDialect.GenerateCreateIndex(AOp: TCreateIndexOperation): string;
var
  Cols: string;
  i: Integer;
  UniqueStr: string;
begin
  Cols := '';
  for i := 0 to High(AOp.Columns) do
  begin
    if i > 0 then Cols := Cols + ', ';
    Cols := Cols + QuoteIdentifier(AOp.Columns[i]);
  end;
  
  if AOp.IsUnique then UniqueStr := 'UNIQUE ' else UniqueStr := '';
  
  Result := Format('CREATE %sINDEX %s ON %s (%s)', [UniqueStr, QuoteIdentifier(AOp.Name), QuoteIdentifier(AOp.Table), Cols]);
end;

function TBaseDialect.GenerateDropIndex(AOp: TDropIndexOperation): string;
begin
  Result := 'DROP INDEX ' + QuoteIdentifier(AOp.Name);
end;

{ TSQLiteDialect }

function TSQLiteDialect.BooleanToSQL(AValue: Boolean): string;
begin
  // SQLite uses 1/0 for boolean
  if AValue then Result := '1' else Result := '0';
end;

function TSQLiteDialect.GeneratePaging(ASkip, ATake: Integer): string;
begin
  // LIMIT <count> OFFSET <skip>
  Result := Format('LIMIT %d OFFSET %d', [ATake, ASkip]);
end;

function TSQLiteDialect.QuoteIdentifier(const AName: string): string;
begin
  // SQLite supports double quotes for identifiers
  Result := '"' + AName + '"';
end;

function TSQLiteDialect.GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean): string;
begin
  if AIsAutoInc then
    Exit('INTEGER'); // SQLite AutoInc must be INTEGER PRIMARY KEY

  case ATypeInfo.Kind of
    tkInteger, tkInt64: Result := 'INTEGER';
    tkFloat: 
      begin
        if ATypeInfo = TypeInfo(TDateTime) then Result := 'REAL' // Or TEXT/INTEGER depending on storage pref
        else if ATypeInfo = TypeInfo(TDate) then Result := 'REAL'
        else if ATypeInfo = TypeInfo(TTime) then Result := 'REAL'
        else Result := 'REAL';
      end;
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString: Result := 'TEXT';
    tkEnumeration:
      begin
        if ATypeInfo = TypeInfo(Boolean) then Result := 'INTEGER' // 0 or 1
        else Result := 'INTEGER'; // Store Enums as Ints by default
      end;
    tkVariant: Result := 'BLOB'; // Fallback
  else
    Result := 'TEXT'; // Default fallback
  end;
end;

function TSQLiteDialect.GetLastInsertIdSQL: string;
begin
  Result := 'SELECT last_insert_rowid()';
end;

function TSQLiteDialect.GetCreateTableSQL(const ATableName, ABody: string): string;
begin
  // SQLite supports IF NOT EXISTS
  Result := Format('CREATE TABLE IF NOT EXISTS %s (%s);', [ATableName, ABody]);
end;

{ TPostgreSQLDialect }

function TPostgreSQLDialect.BooleanToSQL(AValue: Boolean): string;
begin
  // Postgres uses TRUE/FALSE
  if AValue then Result := 'TRUE' else Result := 'FALSE';
end;

function TPostgreSQLDialect.GeneratePaging(ASkip, ATake: Integer): string;
begin
  // LIMIT <count> OFFSET <skip>
  Result := Format('LIMIT %d OFFSET %d', [ATake, ASkip]);
end;

function TPostgreSQLDialect.QuoteIdentifier(const AName: string): string;
begin
  // Postgres uses double quotes, but forces lowercase unless quoted.
  // We quote to preserve case sensitivity if needed.
  Result := '"' + AName + '"';
end;

function TPostgreSQLDialect.GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean): string;
begin
  if AIsAutoInc then
    Exit('SERIAL');

  case ATypeInfo.Kind of
    tkInteger: Result := 'INTEGER';
    tkInt64: Result := 'BIGINT';
    tkFloat: 
      begin
        if ATypeInfo = TypeInfo(Double) then Result := 'DOUBLE PRECISION'
        else if ATypeInfo = TypeInfo(Single) then Result := 'REAL'
        else if ATypeInfo = TypeInfo(Currency) then Result := 'MONEY'
        else if ATypeInfo = TypeInfo(TDateTime) then Result := 'TIMESTAMP'
        else Result := 'DOUBLE PRECISION';
      end;
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString: Result := 'VARCHAR(255)'; // Default length
    tkEnumeration:
      begin
        if ATypeInfo = TypeInfo(Boolean) then Result := 'BOOLEAN'
        else Result := 'INTEGER';
      end;
    tkRecord:
      begin
        if ATypeInfo = TypeInfo(TGUID) then Result := 'UUID'
        else Result := 'TEXT';
      end;
  else
    Result := 'TEXT';
  end;
end;

function TPostgreSQLDialect.GetLastInsertIdSQL: string;
begin
  Result := 'SELECT lastval()';
end;

function TPostgreSQLDialect.GetCreateTableSQL(const ATableName, ABody: string): string;
begin
  // PostgreSQL supports IF NOT EXISTS
  Result := Format('CREATE TABLE IF NOT EXISTS %s (%s);', [ATableName, ABody]);
end;

{ TFirebirdDialect }

function TFirebirdDialect.BooleanToSQL(AValue: Boolean): string;
begin
  // Firebird 3.0+ supports BOOLEAN type (TRUE/FALSE)
  if AValue then Result := 'TRUE' else Result := 'FALSE';
end;

function TFirebirdDialect.GeneratePaging(ASkip, ATake: Integer): string;
begin
  // Firebird 3.0+: OFFSET x ROWS FETCH NEXT y ROWS ONLY
  Result := Format('OFFSET %d ROWS FETCH NEXT %d ROWS ONLY', [ASkip, ATake]);
end;

function TFirebirdDialect.QuoteIdentifier(const AName: string): string;
begin
  Result := '"' + AName + '"';
end;

function TFirebirdDialect.GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean): string;
begin
  if AIsAutoInc then
    Exit('INTEGER GENERATED BY DEFAULT AS IDENTITY'); // Firebird 3.0+

  case ATypeInfo.Kind of
    tkInteger: Result := 'INTEGER';
    tkInt64: Result := 'BIGINT';
    tkFloat: 
      begin
        if ATypeInfo = TypeInfo(Double) then Result := 'DOUBLE PRECISION'
        else if ATypeInfo = TypeInfo(Single) then Result := 'FLOAT'
        else if ATypeInfo = TypeInfo(Currency) then Result := 'DECIMAL(18,4)'
        else if ATypeInfo = TypeInfo(TDateTime) then Result := 'TIMESTAMP'
        else Result := 'DOUBLE PRECISION';
      end;
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString: Result := 'VARCHAR(255)';
    tkEnumeration:
      begin
        if ATypeInfo = TypeInfo(Boolean) then Result := 'BOOLEAN'
        else Result := 'INTEGER';
      end;
    tkRecord:
      begin
        if ATypeInfo = TypeInfo(TGUID) then Result := 'CHAR(36)' // No native UUID in FB3, FB4 has BINARY(16)
        else Result := 'VARCHAR(255)';
      end;
  else
    Result := 'VARCHAR(255)';
  end;
end;

function TFirebirdDialect.GetLastInsertIdSQL: string;
begin
  // Firebird usually requires RETURNING clause in INSERT
  // There is no safe global "last insert id" function without RETURNING
  Result := ''; 
end;

function TFirebirdDialect.GetCreateTableSQL(const ATableName, ABody: string): string;
begin
  // Firebird doesn't support IF NOT EXISTS in CREATE TABLE directly in all versions,
  // but we can use RECREATE TABLE or EXECUTE BLOCK.
  // For simplicity in ORM generation, we stick to standard CREATE TABLE.
  // User should handle existence check or use EnsureCreated carefully.
  Result := Format('CREATE TABLE %s (%s);', [ATableName, ABody]);
end;

{ TSQLServerDialect }

function TSQLServerDialect.BooleanToSQL(AValue: Boolean): string;
begin
  if AValue then Result := '1' else Result := '0';
end;

function TSQLServerDialect.GeneratePaging(ASkip, ATake: Integer): string;
begin
  // SQL Server 2012+: OFFSET x ROWS FETCH NEXT y ROWS ONLY
  // Requires ORDER BY clause in the query!
  Result := Format('OFFSET %d ROWS FETCH NEXT %d ROWS ONLY', [ASkip, ATake]);
end;

function TSQLServerDialect.QuoteIdentifier(const AName: string): string;
begin
  Result := '[' + AName + ']';
end;

function TSQLServerDialect.GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean): string;
begin
  if AIsAutoInc then
    Exit('INT IDENTITY(1,1)');

  case ATypeInfo.Kind of
    tkInteger: Result := 'INT';
    tkInt64: Result := 'BIGINT';
    tkFloat: 
      begin
        if ATypeInfo = TypeInfo(Double) then Result := 'FLOAT'
        else if ATypeInfo = TypeInfo(Single) then Result := 'REAL'
        else if ATypeInfo = TypeInfo(Currency) then Result := 'MONEY'
        else if ATypeInfo = TypeInfo(TDateTime) then Result := 'DATETIME2'
        else Result := 'FLOAT';
      end;
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString: Result := 'NVARCHAR(255)';
    tkEnumeration:
      begin
        if ATypeInfo = TypeInfo(Boolean) then Result := 'BIT'
        else Result := 'INT';
      end;
    tkRecord:
      begin
        if ATypeInfo = TypeInfo(TGUID) then Result := 'UNIQUEIDENTIFIER'
        else Result := 'NVARCHAR(MAX)';
      end;
  else
    Result := 'NVARCHAR(MAX)';
  end;
end;

function TSQLServerDialect.GetLastInsertIdSQL: string;
begin
  Result := 'SELECT SCOPE_IDENTITY()';
end;

function TSQLServerDialect.GetCreateTableSQL(const ATableName, ABody: string): string;
begin
  // SQL Server uses IF NOT EXISTS with OBJECT_ID check
  Result := Format('IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''%s'') AND type = ''U'') ' +
                   'CREATE TABLE %s (%s);', [ATableName, ATableName, ABody]);
end;

function TSQLServerDialect.SupportsInsertReturning: Boolean;
begin
  Result := True; // SQL Server supports OUTPUT INSERTED
end;

function TSQLServerDialect.GetReturningSQL(const AColumnName: string): string;
begin
  // SQL Server uses OUTPUT INSERTED.column_name instead of RETURNING
  Result := 'OUTPUT INSERTED.' + QuoteIdentifier(AColumnName);
end;

function TSQLServerDialect.GetReturningPosition: TReturningPosition;
begin
  Result := rpBeforeValues;
end;

function TSQLServerDialect.RequiresOrderByForPaging: Boolean;
begin
  Result := True;
end;

{ TMySQLDialect }

function TMySQLDialect.BooleanToSQL(AValue: Boolean): string;
begin
  if AValue then Result := '1' else Result := '0';
end;

function TMySQLDialect.GeneratePaging(ASkip, ATake: Integer): string;
begin
  Result := Format('LIMIT %d OFFSET %d', [ATake, ASkip]);
end;

function TMySQLDialect.QuoteIdentifier(const AName: string): string;
begin
  Result := '`' + AName + '`';
end;

function TMySQLDialect.GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean): string;
begin
  if AIsAutoInc then
    Exit('INT AUTO_INCREMENT');

  case ATypeInfo.Kind of
    tkInteger: Result := 'INT';
    tkInt64: Result := 'BIGINT';
    tkFloat: 
      begin
        if ATypeInfo = TypeInfo(Double) then Result := 'DOUBLE'
        else if ATypeInfo = TypeInfo(Single) then Result := 'FLOAT'
        else if ATypeInfo = TypeInfo(Currency) then Result := 'DECIMAL(15,2)'
        else if ATypeInfo = TypeInfo(TDateTime) then Result := 'DATETIME'
        else Result := 'DOUBLE';
      end;
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString: Result := 'VARCHAR(255)';
    tkEnumeration:
      begin
        if ATypeInfo = TypeInfo(Boolean) then Result := 'TINYINT(1)'
        else Result := 'INT';
      end;
    tkRecord:
      begin
        if ATypeInfo = TypeInfo(TGUID) then Result := 'CHAR(36)'
        else Result := 'TEXT';
      end;
  else
    Result := 'TEXT';
  end;
end;

function TMySQLDialect.GetLastInsertIdSQL: string;
begin
  Result := 'SELECT LAST_INSERT_ID()';
end;

function TMySQLDialect.GetCreateTableSQL(const ATableName, ABody: string): string;
begin
  Result := Format('CREATE TABLE IF NOT EXISTS %s (%s);', [ATableName, ABody]);
end;

function TMySQLDialect.GenerateAlterColumn(AOp: TAlterColumnOperation): string;
begin
  // MySQL uses MODIFY COLUMN
  Result := Format('ALTER TABLE %s MODIFY COLUMN %s', [QuoteIdentifier(AOp.TableName), GenerateColumnDefinition(AOp.Column)]);
end;


{ TOracleDialect }

function TOracleDialect.BooleanToSQL(AValue: Boolean): string;
begin
  // Oracle doesn't have BOOLEAN type in SQL (only PL/SQL).
  // Standard practice is NUMBER(1) check (0/1) or CHAR(1) ('Y'/'N').
  // We use 1/0.
  if AValue then Result := '1' else Result := '0';
end;

function TOracleDialect.GeneratePaging(ASkip, ATake: Integer): string;
begin
  // Oracle 12c+: OFFSET x ROWS FETCH NEXT y ROWS ONLY
  Result := Format('OFFSET %d ROWS FETCH NEXT %d ROWS ONLY', [ASkip, ATake]);
end;

function TOracleDialect.QuoteIdentifier(const AName: string): string;
begin
  // Oracle uses double quotes for case sensitivity.
  // Unquoted identifiers are UPPERCASE.
  Result := '"' + AName + '"';
end;

function TOracleDialect.GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean): string;
begin
  if AIsAutoInc then
    Exit('NUMBER(10) GENERATED BY DEFAULT AS IDENTITY'); // Oracle 12c+

  case ATypeInfo.Kind of
    tkInteger: Result := 'NUMBER(10)';
    tkInt64: Result := 'NUMBER(19)';
    tkFloat: 
      begin
        if ATypeInfo = TypeInfo(Double) then Result := 'BINARY_DOUBLE'
        else if ATypeInfo = TypeInfo(Single) then Result := 'BINARY_FLOAT'
        else if ATypeInfo = TypeInfo(Currency) then Result := 'NUMBER(19,4)'
        else if ATypeInfo = TypeInfo(TDateTime) then Result := 'TIMESTAMP'
        else Result := 'BINARY_DOUBLE';
      end;
    tkChar, tkString, tkWChar, tkLString, tkWString, tkUString: Result := 'VARCHAR2(255)';
    tkEnumeration:
      begin
        if ATypeInfo = TypeInfo(Boolean) then Result := 'NUMBER(1)'
        else Result := 'NUMBER(10)';
      end;
    tkRecord:
      begin
        if ATypeInfo = TypeInfo(TGUID) then Result := 'VARCHAR2(36)' // Or RAW(16)
        else Result := 'VARCHAR2(4000)';
      end;
  else
    Result := 'VARCHAR2(255)';
  end;
end;

function TOracleDialect.GetLastInsertIdSQL: string;
begin
  // Oracle requires RETURNING INTO clause.
  // No global scalar function like SCOPE_IDENTITY available easily without PL/SQL context.
  Result := ''; 
end;

function TOracleDialect.GetCreateTableSQL(const ATableName, ABody: string): string;
begin
  // Oracle doesn't support IF NOT EXISTS.
  Result := Format('CREATE TABLE %s (%s);', [ATableName, ABody]);
end;

function TOracleDialect.SupportsInsertReturning: Boolean;
begin
  Result := True;
end;

function TOracleDialect.GetReturningSQL(const AColumnName: string): string;
begin
  Result := 'RETURNING ' + QuoteIdentifier(AColumnName) + ' INTO :RET_VAL';
end;

{ TBaseDialect }

function TBaseDialect.SupportsInsertReturning: Boolean;
begin
  Result := False;
end;

function TBaseDialect.GetReturningSQL(const AColumnName: string): string;
begin
  Result := '';
end;

function TBaseDialect.GetReturningPosition: TReturningPosition;
begin
  Result := rpAtEnd;
end;

function TBaseDialect.RequiresOrderByForPaging: Boolean;
begin
  Result := False;
end;

{ TPostgreSQLDialect }

function TPostgreSQLDialect.SupportsInsertReturning: Boolean;
begin
  Result := True;
end;

function TPostgreSQLDialect.GetReturningSQL(const AColumnName: string): string;
begin
  Result := 'RETURNING ' + QuoteIdentifier(AColumnName);
end;

{ TFirebirdDialect }

function TFirebirdDialect.SupportsInsertReturning: Boolean;
begin
  Result := True;
end;

function TFirebirdDialect.GetReturningSQL(const AColumnName: string): string;
begin
  Result := 'RETURNING ' + QuoteIdentifier(AColumnName);
end;

end.

