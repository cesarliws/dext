unit Dext.Entity.DbSet;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Dext.Core.Activator,
  Dext.Entity.Core,
  Dext.Entity.Attributes,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Specifications.Interfaces,
  Dext.Specifications.SQL.Generator;

type
  TDbSet<T: class> = class(TInterfacedObject, IDbSet<T>)
  private
    FContext: IDbContext;
    FRttiContext: TRttiContext; // Keep RTTI context alive
    FTableName: string;
    FPKName: string;
    FProps: TDictionary<string, TRttiProperty>; // Column Name -> Property
    FColumns: TDictionary<string, string>;      // Property Name -> Column Name
    
    procedure MapEntity;
    function GetTableName: string;
    function GetPKColumn: string;
    function Hydrate(Reader: IDbReader): T;
    
  public
    constructor Create(AContext: IDbContext);
    destructor Destroy; override;
    
    procedure Add(const AEntity: T);
    procedure Update(const AEntity: T);
    procedure Remove(const AEntity: T);
    function Find(const AId: Variant): T;
    
    function List(const ASpec: ISpecification<T>): TList<T>; overload;
    function List: TList<T>; overload;
    function FirstOrDefault(const ASpec: ISpecification<T>): T;
    
    function Any(const ASpec: ISpecification<T>): Boolean;
    function Count(const ASpec: ISpecification<T>): Integer;
  end;

implementation

{ TDbSet<T> }

constructor TDbSet<T>.Create(AContext: IDbContext);
begin
  inherited Create;
  FContext := AContext;
  FProps := TDictionary<string, TRttiProperty>.Create;
  FColumns := TDictionary<string, string>.Create;
  MapEntity;
end;

destructor TDbSet<T>.Destroy;
begin
  FProps.Free;
  FColumns.Free;
  inherited;
end;

procedure TDbSet<T>.MapEntity;
var
  Typ: TRttiType;
  Attr: TCustomAttribute;
  Prop: TRttiProperty;
  ColName: string;
begin
  FRttiContext := TRttiContext.Create;
  Typ := FRttiContext.GetType(T);
  
  // 1. Table Name
  FTableName := Typ.Name; // Default
  for Attr in Typ.GetAttributes do
    if Attr is TableAttribute then
      FTableName := TableAttribute(Attr).Name;
      
  // 2. Properties & Columns
  for Prop in Typ.GetProperties do
  begin
    // Skip unmapped
    var IsMapped := True;
    for Attr in Prop.GetAttributes do
      if Attr is NotMappedAttribute then
        IsMapped := False;
        
    if not IsMapped then Continue;
    
    ColName := Prop.Name; // Default
    
    for Attr in Prop.GetAttributes do
    begin
      if Attr is ColumnAttribute then
        ColName := ColumnAttribute(Attr).Name;
        
      if Attr is PKAttribute then
        FPKName := ColName;
    end;
    
    FProps.Add(ColName.ToLower, Prop); // Store lower for case-insensitive matching
    FColumns.Add(Prop.Name, ColName);
  end;
  
  if FPKName = '' then
    FPKName := 'Id'; // Convention
end;

function TDbSet<T>.GetTableName: string;
begin
  Result := FContext.Dialect.QuoteIdentifier(FTableName);
end;

function TDbSet<T>.GetPKColumn: string;
begin
  Result := FContext.Dialect.QuoteIdentifier(FPKName);
end;

function TDbSet<T>.Hydrate(Reader: IDbReader): T;
var
  i: Integer;
  ColName: string;
  Val: TValue;
  Prop: TRttiProperty;
begin
  // Use Activator to create instance (handles generic constraint issue)
  Result := TActivator.CreateInstance<T>([]);

  try
    for i := 0 to Reader.GetColumnCount - 1 do
    begin
      ColName := Reader.GetColumnName(i).ToLower;
      Val := Reader.GetValue(i);
      
      if FProps.TryGetValue(ColName, Prop) then
      begin
        if not Val.IsEmpty then
        begin
          // Basic type conversion handling
          // In a real ORM, this needs a robust converter
          Prop.SetValue(Pointer(Result), Val);
        end;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TDbSet<T>.Add(const AEntity: T);
var
  SB: TStringBuilder;
  Cols, Vals: TStringBuilder;
  Cmd: IDbCommand;
  Pair: TPair<string, string>;
  Prop: TRttiProperty;
  Val: TValue;
  ParamName: string;
  IsAutoInc: Boolean;
  ParamsToSet: TList<TPair<string, TValue>>;
begin
  SB := TStringBuilder.Create;
  Cols := TStringBuilder.Create;
  Vals := TStringBuilder.Create;
  ParamsToSet := TList<TPair<string, TValue>>.Create;
  try
    SB.Append('INSERT INTO ').Append(GetTableName).Append(' (');
    
    var First := True;
    
    for Pair in FColumns do
    begin
      Prop := FProps[Pair.Value.ToLower];
      
      // Check for AutoInc (skip PK if autoinc)
      IsAutoInc := False;
      for var Attr in Prop.GetAttributes do
        if Attr is AutoIncAttribute then
          IsAutoInc := True;
          
      if IsAutoInc then Continue;
      
      if not First then
      begin
        Cols.Append(', ');
        Vals.Append(', ');
      end;
      First := False;
      
      Cols.Append(FContext.Dialect.QuoteIdentifier(Pair.Value));
      
      ParamName := 'p_' + Pair.Value;
      Vals.Append(':').Append(ParamName);
      
      Val := Prop.GetValue(Pointer(AEntity));
      ParamsToSet.Add(TPair<string, TValue>.Create(ParamName, Val));
    end;
    
    SB.Append(Cols.ToString).Append(') VALUES (').Append(Vals.ToString).Append(')');
    
    Cmd := FContext.Connection.CreateCommand(SB.ToString) as IDbCommand;
    
    for var P in ParamsToSet do
      Cmd.AddParam(P.Key, P.Value);
      
    Cmd.ExecuteNonQuery;
    
  finally
    SB.Free;
    Cols.Free;
    Vals.Free;
    ParamsToSet.Free;
  end;
end;

procedure TDbSet<T>.Update(const AEntity: T);
begin
  // TODO: Implement Update
end;

procedure TDbSet<T>.Remove(const AEntity: T);
begin
  // TODO: Implement Remove
end;

function TDbSet<T>.Find(const AId: Variant): T;
var
  Cmd: IDbCommand;
  Reader: IDbReader;
  SQL: string;
begin
  Result := nil;
  SQL := Format('SELECT * FROM %s WHERE %s = :id', [GetTableName, GetPKColumn]);
  
  Cmd := FContext.Connection.CreateCommand(SQL) as IDbCommand;
  Cmd.AddParam('id', TValue.FromVariant(AId));
  
  Reader := Cmd.ExecuteQuery;
  if Reader.Next then
    Result := Hydrate(Reader);
    
  // Reader is auto-freed by interface? No, usually interfaces are ref-counted.
  // But if the driver implementation is TInterfacedObject, it is.
end;

function TDbSet<T>.List(const ASpec: ISpecification<T>): TList<T>;
var
  Generator: TSQLWhereGenerator;
  SQL: TStringBuilder;
  WhereClause: string;
  Cmd: IDbCommand;
  Reader: IDbReader;
  Param: TPair<string, TValue>;
begin
  Result := TList<T>.Create;
  Generator := TSQLWhereGenerator.Create(FContext.Dialect);
  SQL := TStringBuilder.Create;
  try
    SQL.Append('SELECT * FROM ').Append(GetTableName);
    
    // 1. Generate WHERE
    if ASpec.GetCriteria <> nil then
    begin
      WhereClause := Generator.Generate(ASpec.GetCriteria);
      if WhereClause <> '' then
        SQL.Append(' WHERE ').Append(WhereClause);
    end;
    
    // 2. Generate ORDER BY (TODO)
    
    // 3. Generate Paging
    if ASpec.IsPagingEnabled then
    begin
      SQL.Append(' ').Append(FContext.Dialect.GeneratePaging(ASpec.GetSkip, ASpec.GetTake));
    end;
    
    // 4. Execute
    Cmd := FContext.Connection.CreateCommand(SQL.ToString) as IDbCommand;
    
    for Param in Generator.Params do
      Cmd.AddParam(Param.Key, Param.Value);
      
    Reader := Cmd.ExecuteQuery;
    while Reader.Next do
      Result.Add(Hydrate(Reader));
      
  finally
    Generator.Free;
    SQL.Free;
  end;
end;

function TDbSet<T>.List: TList<T>;
begin
  // Empty spec = All
  // We need a concrete spec class or just execute SELECT *
  // For simplicity, let's implement SELECT * directly
  var Cmd := FContext.Connection.CreateCommand('SELECT * FROM ' + GetTableName) as IDbCommand;
  var Reader := Cmd.ExecuteQuery;
  Result := TList<T>.Create;
  while Reader.Next do
    Result.Add(Hydrate(Reader));
end;

function TDbSet<T>.FirstOrDefault(const ASpec: ISpecification<T>): T;
var
  ListResult: TList<T>;
begin
  // Optimization: Apply Take(1) to Spec if not already paging?
  // For now, just fetch list and take first.
  ListResult := List(ASpec);
  try
    if ListResult.Count > 0 then
    begin
      Result := ListResult[0];
      ListResult.Extract(Result); // Prevent freeing by List
    end
    else
      Result := nil;
  finally
    ListResult.Free;
  end;
end;

function TDbSet<T>.Any(const ASpec: ISpecification<T>): Boolean;
begin
  Result := Count(ASpec) > 0;
end;

function TDbSet<T>.Count(const ASpec: ISpecification<T>): Integer;
var
  Generator: TSQLWhereGenerator;
  SQL: string;
  WhereClause: string;
  Cmd: IDbCommand;
  Param: TPair<string, TValue>;
begin
  Generator := TSQLWhereGenerator.Create(FContext.Dialect);
  try
    SQL := 'SELECT COUNT(*) FROM ' + GetTableName;
    
    if ASpec.GetCriteria <> nil then
    begin
      WhereClause := Generator.Generate(ASpec.GetCriteria);
      if WhereClause <> '' then
        SQL := SQL + ' WHERE ' + WhereClause;
    end;
    
    Cmd := FContext.Connection.CreateCommand(SQL) as IDbCommand;
    for Param in Generator.Params do
      Cmd.AddParam(Param.Key, Param.Value);
      
    Result := Cmd.ExecuteScalar.AsInteger;
  finally
    Generator.Free;
  end;
end;

end.
