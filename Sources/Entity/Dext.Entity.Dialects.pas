unit Dext.Entity.Dialects;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Entity.Attributes;

type
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
  end;

  /// <summary>
  ///   Base class for dialects.
  /// </summary>
  TBaseDialect = class(TInterfacedObject, ISQLDialect)
  public
    function QuoteIdentifier(const AName: string): string; virtual;
    function GetParamPrefix: string; virtual;
    function GeneratePaging(ASkip, ATake: Integer): string; virtual; abstract;
    function BooleanToSQL(AValue: Boolean): string; virtual;
    function GetColumnType(ATypeInfo: PTypeInfo; AIsAutoInc: Boolean = False): string; virtual; abstract;
    function GetCascadeActionSQL(AAction: TCascadeAction): string; virtual;
    function GetLastInsertIdSQL: string; virtual; abstract;
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
  else
    Result := 'TEXT';
  end;
end;

function TPostgreSQLDialect.GetLastInsertIdSQL: string;
begin
  Result := 'SELECT lastval()';
end;

end.
