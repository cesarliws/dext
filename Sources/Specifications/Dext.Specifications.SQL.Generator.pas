unit Dext.Specifications.SQL.Generator;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types,
  Dext.Entity.Dialects;

type
  /// <summary>
  ///   Translates a Criteria Tree into a SQL WHERE clause and Parameters.
  /// </summary>
  TSQLWhereGenerator = class
  private
    FSQL: TStringBuilder;
    FParams: TDictionary<string, TValue>;
    FParamCount: Integer;
    FDialect: ISQLDialect;
    
    procedure Process(const ACriterion: ICriterion);
    procedure ProcessBinary(const C: TBinaryCriterion);
    procedure ProcessLogical(const C: TLogicalCriterion);
    procedure ProcessUnary(const C: TUnaryCriterion);
    procedure ProcessConstant(const C: TConstantCriterion);
    
    function GetNextParamName: string;
    function GetBinaryOpSQL(Op: TBinaryOperator): string;
    function GetLogicalOpSQL(Op: TLogicalOperator): string;
    function GetUnaryOpSQL(Op: TUnaryOperator): string;
  public
    constructor Create(ADialect: ISQLDialect);
    destructor Destroy; override;
    
    /// <summary>
    ///   Generates the SQL and populates Params.
    ///   Returns empty string if Criteria is nil.
    /// </summary>
    function Generate(const ACriterion: ICriterion): string;
    
    /// <summary>
    ///   Access the parameters generated during the process.
    /// </summary>
    property Params: TDictionary<string, TValue> read FParams;
  end;

implementation

{ TSQLWhereGenerator }

constructor TSQLWhereGenerator.Create(ADialect: ISQLDialect);
begin
  FSQL := TStringBuilder.Create;
  FParams := TDictionary<string, TValue>.Create;
  FParamCount := 0;
  FDialect := ADialect;
end;

destructor TSQLWhereGenerator.Destroy;
begin
  FSQL.Free;
  FParams.Free;
  inherited;
end;

function TSQLWhereGenerator.Generate(const ACriterion: ICriterion): string;
begin
  FSQL.Clear;
  FParams.Clear;
  FParamCount := 0;
  
  if ACriterion = nil then
    Exit('');
    
  Process(ACriterion);
  Result := FSQL.ToString;
end;

function TSQLWhereGenerator.GetNextParamName: string;
begin
  Inc(FParamCount);
  Result := 'p' + IntToStr(FParamCount);
end;

procedure TSQLWhereGenerator.Process(const ACriterion: ICriterion);
begin
  if ACriterion is TBinaryCriterion then
    ProcessBinary(TBinaryCriterion(ACriterion))
  else if ACriterion is TLogicalCriterion then
    ProcessLogical(TLogicalCriterion(ACriterion))
  else if ACriterion is TUnaryCriterion then
    ProcessUnary(TUnaryCriterion(ACriterion))
  else if ACriterion is TConstantCriterion then
    ProcessConstant(TConstantCriterion(ACriterion))
  else
    raise Exception.Create('Unknown criterion type: ' + ACriterion.ToString);
end;

procedure TSQLWhereGenerator.ProcessBinary(const C: TBinaryCriterion);
var
  ParamName: string;
begin
  ParamName := GetNextParamName;
  
  // Store parameter value
  FParams.Add(ParamName, C.Value);
  
  // Generate SQL: (Column Op :Param)
  FSQL.Append('(')
      .Append(FDialect.QuoteIdentifier(C.PropertyName))
      .Append(' ')
      .Append(GetBinaryOpSQL(C.Operator))
      .Append(' :')
      .Append(ParamName)
      .Append(')');
end;

procedure TSQLWhereGenerator.ProcessLogical(const C: TLogicalCriterion);
begin
  FSQL.Append('(');
  Process(C.Left);
  FSQL.Append(' ')
      .Append(GetLogicalOpSQL(C.Operator))
      .Append(' ');
  Process(C.Right);
  FSQL.Append(')');
end;

procedure TSQLWhereGenerator.ProcessUnary(const C: TUnaryCriterion);
begin
  if C.Operator = uoNot then
  begin
    FSQL.Append('(NOT ');
    Process(C.Criterion);
    FSQL.Append(')');
  end
  else
  begin
    // IsNull / IsNotNull
    FSQL.Append('(')
        .Append(FDialect.QuoteIdentifier(C.PropertyName))
        .Append(' ')
        .Append(GetUnaryOpSQL(C.Operator))
        .Append(')');
  end;
end;

procedure TSQLWhereGenerator.ProcessConstant(const C: TConstantCriterion);
begin
  if C.Value then
    FSQL.Append('(1=1)')
  else
    FSQL.Append('(1=0)');
end;

function TSQLWhereGenerator.GetBinaryOpSQL(Op: TBinaryOperator): string;
begin
  case Op of
    boEqual: Result := '=';
    boNotEqual: Result := '<>';
    boGreaterThan: Result := '>';
    boGreaterThanOrEqual: Result := '>=';
    boLessThan: Result := '<';
    boLessThanOrEqual: Result := '<=';
    boLike: Result := 'LIKE';
    boNotLike: Result := 'NOT LIKE';
    boIn: Result := 'IN';
    boNotIn: Result := 'NOT IN';
  else
    Result := '=';
  end;
end;

function TSQLWhereGenerator.GetLogicalOpSQL(Op: TLogicalOperator): string;
begin
  case Op of
    loAnd: Result := 'AND';
    loOr: Result := 'OR';
  else
    Result := 'AND';
  end;
end;

function TSQLWhereGenerator.GetUnaryOpSQL(Op: TUnaryOperator): string;
begin
  case Op of
    uoIsNull: Result := 'IS NULL';
    uoIsNotNull: Result := 'IS NOT NULL';
  else
    Result := '';
  end;
end;

end.
