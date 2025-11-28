unit Dext.Entity.Dialects;

interface

uses
  System.SysUtils;

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
  end;

  /// <summary>
  ///   SQLite Dialect implementation.
  /// </summary>
  TSQLiteDialect = class(TBaseDialect)
  public
    function QuoteIdentifier(const AName: string): string; override;
    function GeneratePaging(ASkip, ATake: Integer): string; override;
    function BooleanToSQL(AValue: Boolean): string; override;
  end;

  /// <summary>
  ///   PostgreSQL Dialect implementation.
  /// </summary>
  TPostgreSQLDialect = class(TBaseDialect)
  public
    function QuoteIdentifier(const AName: string): string; override;
    function GeneratePaging(ASkip, ATake: Integer): string; override;
    function BooleanToSQL(AValue: Boolean): string; override;
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

end.
