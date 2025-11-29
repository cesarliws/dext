unit Dext.Specifications.SQL.Generator;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types,
  Dext.Entity.Dialects,
  Dext.Entity.Attributes;

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

  /// <summary>
  ///   Generates SQL for CRUD operations (Insert, Update, Delete).
  /// </summary>
  TSQLGenerator<T: class> = class
  private
    FDialect: ISQLDialect;
    FParams: TDictionary<string, TValue>;
    FParamCount: Integer;
    
    function GetNextParamName: string;
    function GetTableName: string;
  public
    constructor Create(ADialect: ISQLDialect);
    destructor Destroy; override;
    
    function GenerateInsert(const AEntity: T): string;
    function GenerateUpdate(const AEntity: T): string;
    function GenerateDelete(const AEntity: T): string;
    
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



{ TSQLGenerator<T> }

constructor TSQLGenerator<T>.Create(ADialect: ISQLDialect);
begin
  FDialect := ADialect;
  FParams := TDictionary<string, TValue>.Create;
  FParamCount := 0;
end;

destructor TSQLGenerator<T>.Destroy;
begin
  FParams.Free;
  inherited;
end;

function TSQLGenerator<T>.GetNextParamName: string;
begin
  Inc(FParamCount);
  Result := 'p' + IntToStr(FParamCount);
end;

function TSQLGenerator<T>.GetTableName: string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Attr: TCustomAttribute;
begin
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  Result := Typ.Name;
  
  for Attr in Typ.GetAttributes do
    if Attr is TableAttribute then
      Exit(TableAttribute(Attr).Name);
end;

function TSQLGenerator<T>.GenerateInsert(const AEntity: T): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ColName, ParamName: string;
  SBCols, SBVals: TStringBuilder;
  IsAutoInc, IsMapped: Boolean;
  Val: TValue;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBCols := TStringBuilder.Create;
  SBVals := TStringBuilder.Create;
  try
    var First := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsMapped := True;
      IsAutoInc := False;
      ColName := Prop.Name;
      
      for Attr in Prop.GetAttributes do
      begin
        if Attr is NotMappedAttribute then IsMapped := False;
        if Attr is AutoIncAttribute then IsAutoInc := True;
        if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
        if Attr is ForeignKeyAttribute then ColName := ForeignKeyAttribute(Attr).ColumnName;
      end;
      
      if not IsMapped or IsAutoInc then Continue;
      
      if not First then
      begin
        SBCols.Append(', ');
        SBVals.Append(', ');
      end;
      First := False;
      
      SBCols.Append(FDialect.QuoteIdentifier(ColName));
      
      ParamName := GetNextParamName;
      SBVals.Append(':').Append(ParamName);
      
      Val := Prop.GetValue(Pointer(AEntity));
      FParams.Add(ParamName, Val);
    end;
    
    Result := Format('INSERT INTO %s (%s) VALUES (%s)', 
      [FDialect.QuoteIdentifier(GetTableName), SBCols.ToString, SBVals.ToString]);
      
  finally
    SBCols.Free;
    SBVals.Free;
  end;
end;

function TSQLGenerator<T>.GenerateUpdate(const AEntity: T): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ColName, ParamName: string;
  SBSet, SBWhere: TStringBuilder;
  IsPK, IsMapped: Boolean;
  Val: TValue;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBSet := TStringBuilder.Create;
  SBWhere := TStringBuilder.Create;
  try
    var FirstSet := True;
    var FirstWhere := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsMapped := True;
      IsPK := False;
      ColName := Prop.Name;
      
      for Attr in Prop.GetAttributes do
      begin
        if Attr is NotMappedAttribute then IsMapped := False;
        if Attr is PKAttribute then IsPK := True;
        if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
        if Attr is ForeignKeyAttribute then ColName := ForeignKeyAttribute(Attr).ColumnName;
      end;
      
      if not IsMapped then Continue;
      
      Val := Prop.GetValue(Pointer(AEntity));
      ParamName := GetNextParamName;
      FParams.Add(ParamName, Val);
      
      if IsPK then
      begin
        if not FirstWhere then SBWhere.Append(' AND ');
        FirstWhere := False;
        SBWhere.Append(FDialect.QuoteIdentifier(ColName)).Append(' = :').Append(ParamName);
      end
      else
      begin
        if not FirstSet then SBSet.Append(', ');
        FirstSet := False;
        SBSet.Append(FDialect.QuoteIdentifier(ColName)).Append(' = :').Append(ParamName);
      end;
    end;
    
    if SBWhere.Length = 0 then
      raise Exception.Create('Cannot generate UPDATE: No Primary Key defined.');
      
    Result := Format('UPDATE %s SET %s WHERE %s', 
      [FDialect.QuoteIdentifier(GetTableName), SBSet.ToString, SBWhere.ToString]);
      
  finally
    SBSet.Free;
    SBWhere.Free;
  end;
end;

function TSQLGenerator<T>.GenerateDelete(const AEntity: T): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ColName, ParamName: string;
  SBWhere: TStringBuilder;
  IsPK: Boolean;
  Val: TValue;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBWhere := TStringBuilder.Create;
  try
    var FirstWhere := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsPK := False;
      ColName := Prop.Name;
      
      for Attr in Prop.GetAttributes do
      begin
        if Attr is PKAttribute then IsPK := True;
        if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
      end;
      
      if not IsPK then Continue;
      
      Val := Prop.GetValue(Pointer(AEntity));
      ParamName := GetNextParamName;
      FParams.Add(ParamName, Val);
      
      if not FirstWhere then SBWhere.Append(' AND ');
      FirstWhere := False;
      SBWhere.Append(FDialect.QuoteIdentifier(ColName)).Append(' = :').Append(ParamName);
    end;
    
    if SBWhere.Length = 0 then
      raise Exception.Create('Cannot generate DELETE: No Primary Key defined.');
      
    Result := Format('DELETE FROM %s WHERE %s', 
      [FDialect.QuoteIdentifier(GetTableName), SBWhere.ToString]);
      
  finally
    SBWhere.Free;
  end;
end;

end.
