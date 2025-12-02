unit Dext.Entity.DbSet;

interface

uses
  System.Generics.Collections,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  System.Variants,
  Dext.Core.Activator,
  Dext.Core.ValueConverters,
  Dext.Entity.Attributes,
  Dext.Entity.Core,
  Dext.Entity.Dialects,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Query,
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces,
  Dext.Specifications.SQL.Generator,
  Dext.Specifications.Types;

type
  TDbSet<T: class> = class(TInterfacedObject, IDbSet<T>, IDbSet)
  private
    FContext: IDbContext;
    FRttiContext: TRttiContext; // Keep RTTI context alive
    FTableName: string;
    FPKColumns: TList<string>; // List of PK Column Names
    FProps: TDictionary<string, TRttiProperty>; // Column Name -> Property
    FColumns: TDictionary<string, string>;      // Property Name -> Column Name
    FIdentityMap: TObjectDictionary<string, T>; // ID (String) -> Entity. Owns objects.

    procedure MapEntity;
    function Hydrate(Reader: IDbReader): T;
  protected
    function GetEntityId(const AEntity: T): string; overload;
    function GetEntityId(const AEntity: TObject): string; overload;
    function GetPKColumns: TArray<string>;
    function GetRelatedId(const AObject: TObject): TValue;
    procedure DoLoadIncludes(const AEntities: TList<T>; const AIncludes: TArray<string>);
  public
    constructor Create(AContext: IDbContext);
    destructor Destroy; override;

    function GetTableName: string;
    function FindObject(const AId: Variant): TObject;
    procedure Add(const AEntity: TObject); overload;
    function ListObjects(const AExpression: IExpression): TList<TObject>;
    procedure PersistAdd(const AEntity: TObject);
    procedure PersistUpdate(const AEntity: TObject);
    procedure PersistRemove(const AEntity: TObject);
    function GenerateCreateTableScript: string;
    procedure Clear;

    procedure Add(const AEntity: T); overload;
    procedure Update(const AEntity: T);
    procedure Remove(const AEntity: T);
    function Find(const AId: Variant): T; overload;
    function Find(const AId: array of Integer): T; overload;

    procedure AddRange(const AEntities: TArray<T>); overload;
    procedure AddRange(const AEntities: TEnumerable<T>); overload;

    procedure UpdateRange(const AEntities: TArray<T>); overload;
    procedure UpdateRange(const AEntities: TEnumerable<T>); overload;

    procedure RemoveRange(const AEntities: TArray<T>); overload;
    procedure RemoveRange(const AEntities: TEnumerable<T>); overload;

    function List: TList<T>; overload;
    function List(const ASpec: ISpecification<T>): TList<T>; overload;

    // Inline Queries (aceita IExpression diretamente)
    function List(const AExpression: IExpression): TList<T>; overload;
    function FirstOrDefault(const AExpression: IExpression): T; overload;
    function Any(const AExpression: IExpression): Boolean; overload;
    function Count(const AExpression: IExpression): Integer; overload;

    // Lazy Queries (Deferred Execution)
    function Query(const ASpec: ISpecification<T>): TFluentQuery<T>; overload;
    function Query(const AExpression: IExpression): TFluentQuery<T>; overload;
    function QueryAll: TFluentQuery<T>;
  end;

implementation

uses
  Dext.Entity.LazyLoading;

{ TDbSet<T> }

constructor TDbSet<T>.Create(AContext: IDbContext);
begin
  inherited Create;
  FContext := AContext;
  FProps := TDictionary<string, TRttiProperty>.Create;
  FColumns := TDictionary<string, string>.Create;
  FPKColumns := TList<string>.Create;
  FIdentityMap := TObjectDictionary<string, T>.Create([]);
  MapEntity;
end;

destructor TDbSet<T>.Destroy;
begin
  FIdentityMap.Free;
  FProps.Free;
  FColumns.Free;
  FPKColumns.Free;
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

    // First pass: determine column name
    for Attr in Prop.GetAttributes do
    begin
      if Attr is ColumnAttribute then
        ColName := ColumnAttribute(Attr).Name;

      if Attr is ForeignKeyAttribute then
        ColName := ForeignKeyAttribute(Attr).ColumnName;
    end;

    // Second pass: check for PK (now ColName is final)
    for Attr in Prop.GetAttributes do
    begin
      if Attr is PKAttribute then
        FPKColumns.Add(ColName);
    end;

    FProps.Add(ColName.ToLower, Prop); // Store lower for case-insensitive matching
    FColumns.Add(Prop.Name, ColName);
  end;

  // Fallback if no PK defined: assume 'Id'
  if FPKColumns.Count = 0 then
  begin
    if FColumns.ContainsKey('Id') then
      FPKColumns.Add(FColumns['Id'])
    else if FColumns.ContainsKey('ID') then
      FPKColumns.Add(FColumns['ID']);
  end;
end;

function TDbSet<T>.GetTableName: string;
begin
  Result := FContext.Dialect.QuoteIdentifier(FTableName);
end;

function TDbSet<T>.GetPKColumns: TArray<string>;
var
  i: Integer;
begin
  SetLength(Result, FPKColumns.Count);
  for i := 0 to FPKColumns.Count - 1 do
    Result[i] := FContext.Dialect.QuoteIdentifier(FPKColumns[i]);
end;

function TDbSet<T>.GetEntityId(const AEntity: T): string;
var
  Prop: TRttiProperty;
  Val: TValue;
  SB: TStringBuilder;
  i: Integer;
begin
  if FPKColumns.Count = 0 then
    raise Exception.Create('No Primary Key defined for entity ' + FTableName);

  if FPKColumns.Count = 1 then
  begin
    if not FProps.TryGetValue(FPKColumns[0].ToLower, Prop) then
      raise Exception.Create('Primary Key property not found: ' + FPKColumns[0]);
    Val := Prop.GetValue(Pointer(AEntity));
    Result := Val.ToString;
  end
  else
  begin
    // Composite Key: "Val1|Val2"
    SB := TStringBuilder.Create;
    try
      for i := 0 to FPKColumns.Count - 1 do
      begin
        if i > 0 then SB.Append('|');

        if not FProps.TryGetValue(FPKColumns[i].ToLower, Prop) then
          raise Exception.Create('Primary Key property not found: ' + FPKColumns[i]);

        Val := Prop.GetValue(Pointer(AEntity));
        SB.Append(Val.ToString);
      end;
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  end;
end;

function TDbSet<T>.GetEntityId(const AEntity: TObject): string;
begin
  Result := GetEntityId(T(AEntity));
end;

function TDbSet<T>.GetRelatedId(const AObject: TObject): TValue;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
begin
  // We need to find the PK of the related object.
  // We don't have its DbSet handy easily without looking it up,
  // but we can just scan its properties for [PK] or 'Id'.

  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(AObject.ClassType);

  for Prop in Typ.GetProperties do
  begin
    for Attr in Prop.GetAttributes do
      if Attr is PKAttribute then
        Exit(Prop.GetValue(AObject));
  end;

  // Fallback to 'Id'
  Prop := Typ.GetProperty('Id');
  if Prop <> nil then
    Exit(Prop.GetValue(AObject));

  raise Exception.Create('Could not determine Primary Key for related entity ' + AObject.ClassName);
end;

function TDbSet<T>.Hydrate(Reader: IDbReader): T;
var
  i: Integer;
  ColName: string;
  Val: TValue;
  Prop: TRttiProperty;
  PKVal: string;
  PKValues: TDictionary<string, string>;
begin
  // 1. Find PK Value first to check Identity Map
  PKVal := '';

  if FPKColumns.Count > 0 then
  begin
    PKValues := TDictionary<string, string>.Create;
    try
      // Scan columns to find PKs
      for i := 0 to Reader.GetColumnCount - 1 do
      begin
        ColName := Reader.GetColumnName(i);
         if FPKColumns.Contains(ColName) then
            PKValues.Add(ColName, Reader.GetValue(i).ToString);
      end;

      // Construct PK String
      if FPKColumns.Count = 1 then
      begin
        if PKValues.ContainsKey(FPKColumns[0]) then
          PKVal := PKValues[FPKColumns[0]];
      end
      else
      begin
        // Composite
        var SB := TStringBuilder.Create;
        try
          for i := 0 to FPKColumns.Count - 1 do
          begin
            if i > 0 then SB.Append('|');
            if PKValues.ContainsKey(FPKColumns[i]) then
              SB.Append(PKValues[FPKColumns[i]]);
          end;
          PKVal := SB.ToString;
        finally
          SB.Free;
        end;
      end;
    finally
      PKValues.Free;
    end;
  end;

  // Check Identity Map
  if (PKVal <> '') and FIdentityMap.TryGetValue(PKVal, Result) then
    Exit; // Return existing instance

  // Create new instance
  Result := TActivator.CreateInstance<T>;

  // Add to Identity Map
  if PKVal <> '' then
    FIdentityMap.Add(PKVal, Result);

  // Inject Lazy Loading (if applicable)
  TLazyInjector.Inject(FContext, Result);

  // Populate Properties
  for i := 0 to Reader.GetColumnCount - 1 do
  begin
    ColName := Reader.GetColumnName(i);
    Val := Reader.GetValue(i);

    if FProps.TryGetValue(ColName.ToLower, Prop) then
    begin
      TValueConverter.ConvertAndSet(Result, Prop, Val);
    end;
  end;
end;

function TDbSet<T>.FindObject(const AId: Variant): TObject;
begin
  Result := Find(AId);
end;

procedure TDbSet<T>.Add(const AEntity: TObject);
begin
  Add(T(AEntity));
end;

procedure TDbSet<T>.Add(const AEntity: T);
begin
  FContext.ChangeTracker.Track(AEntity, esAdded);
end;

procedure TDbSet<T>.Update(const AEntity: T);
begin
  FContext.ChangeTracker.Track(AEntity, esModified);
end;

procedure TDbSet<T>.Remove(const AEntity: T);
begin
  FContext.ChangeTracker.Track(AEntity, esDeleted);
end;

procedure TDbSet<T>.PersistAdd(const AEntity: TObject);
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
  Prop: TRttiProperty;
  PKVal: Variant;
begin
  Generator := TSqlGenerator<T>.Create(FContext.Dialect);
  try
    Sql := Generator.GenerateInsert(T(AEntity));
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;

    // Bind Params from Generator
    for var Pair in Generator.Params do
    begin
      try
        var V := Pair.Value.AsVariant;
      except
        on E: Exception do
          WriteLn('  AsVariant FAILED: ' + E.Message);
      end;
      Cmd.AddParam(Pair.Key, Pair.Value);
    end;

    Cmd.ExecuteNonQuery;
    
    // Retrieve AutoInc ID if applicable
    if FPKColumns.Count = 1 then
    begin
       // Check if AutoInc
       // For SQLite: select last_insert_rowid()
       // This should be part of Dialect or Driver
       PKVal := FContext.Connection.GetLastInsertId;

       if not VarIsNull(PKVal) then
       begin
         if FProps.TryGetValue(FPKColumns[0].ToLower, Prop) then
         begin
           try
             TValueConverter.ConvertAndSet(AEntity, Prop, TValue.FromVariant(PKVal));
           except
             on E: Exception do
               WriteLn('ConvertAndSet FAILED: ' + E.ClassName + ': ' + E.Message);
           end;

           // Update Identity Map with new ID?
           // The entity is already in memory, but maybe not in map if ID was 0.
           // We should add it to map now.
           var NewId := VarToStr(PKVal); // Simple conversion
           if not FIdentityMap.ContainsKey(NewId) then
             FIdentityMap.Add(NewId, T(AEntity));
         end;
       end;
    end;

  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.PersistUpdate(const AEntity: TObject);
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
  RowsAffected: Integer;
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  Val: TValue;
  NewVer: Integer;
begin
  Generator := TSqlGenerator<T>.Create(FContext.Dialect);
  try
    Sql := Generator.GenerateUpdate(T(AEntity));
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;

    // Bind Params from Generator
    for var Pair in Generator.Params do
    begin
      Cmd.AddParam(Pair.Key, Pair.Value);
    end;

    RowsAffected := Cmd.ExecuteNonQuery;
    
    if RowsAffected = 0 then
      raise EOptimisticConcurrencyException.Create('Concurrency violation: The record has been modified or deleted by another user.');
      
    // Update Version property in memory if applicable
    Ctx := TRttiContext.Create;
    Typ := Ctx.GetType(T);
    for Prop in Typ.GetProperties do
    begin
      for Attr in Prop.GetAttributes do
      begin
        if Attr is VersionAttribute then
        begin
          Val := Prop.GetValue(Pointer(AEntity));
          if Val.IsEmpty then NewVer := 1 else NewVer := Val.AsInteger + 1;
          Prop.SetValue(Pointer(AEntity), NewVer);
          Break;
        end;
      end;
    end;
    
  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.PersistRemove(const AEntity: TObject);
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
begin
  Generator := TSqlGenerator<T>.Create(FContext.Dialect);
  try
    Sql := Generator.GenerateDelete(T(AEntity));
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;

    // Bind Params from Generator
    for var Pair in Generator.Params do
    begin
      Cmd.AddParam(Pair.Key, Pair.Value);
    end;

    Cmd.ExecuteNonQuery;

    // Remove from Identity Map
    var Id := GetEntityId(T(AEntity));
    FIdentityMap.Remove(Id);

  finally
    Generator.Free;
  end;
end;

function TDbSet<T>.GenerateCreateTableScript: string;
var
  Generator: TSqlGenerator<T>;
begin
  Generator := TSqlGenerator<T>.Create(FContext.Dialect);
  try
    Result := Generator.GenerateCreateTable(GetTableName);
    // Result := ''; // TODO: Implement GenerateCreateTable in TSqlGenerator
  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.Clear;
begin
  FIdentityMap.Clear;
end;

function TDbSet<T>.ListObjects(const AExpression: IExpression): TList<TObject>;
var
  ListT: TList<T>;
  Obj: T;
begin
  Result := TList<TObject>.Create;
  ListT := List(AExpression);
  try
    for Obj in ListT do
      Result.Add(Obj);
  finally
    ListT.Free;
  end;
end;

function TDbSet<T>.Find(const AId: Variant): T;
var
  Cmd: IDbCommand;
  Reader: IDbReader;
  SB: TStringBuilder;
begin
  Result := nil;
  // Check Identity Map first
  if FIdentityMap.TryGetValue(VarToStr(AId), Result) then
    Exit;

  if FPKColumns.Count <> 1 then
    raise Exception.Create('Find(Variant) only supports single Primary Key entities.');

  // Build SELECT * FROM Table WHERE PK = :PK
  SB := TStringBuilder.Create;
  try
    SB.Append('SELECT * FROM ').Append(GetTableName).Append(' WHERE ');
    SB.Append(FContext.Dialect.QuoteIdentifier(FPKColumns[0])).Append(' = :PK');

    Cmd := FContext.Connection.CreateCommand(SB.ToString) as IDbCommand;
    Cmd.AddParam('PK', TValue.FromVariant(AId));

    Reader := Cmd.ExecuteQuery;
    if Reader.Next then
      Result := Hydrate(Reader); // Hydrate will add to map

  finally
    SB.Free;
  end;
end;

function TDbSet<T>.Find(const AId: array of Integer): T;
var
  V: Variant;
begin
  if Length(AId) = 1 then
  begin
    V := AId[0];
    Result := Find(V);
  end
  else
  begin
    // Composite key implementation omitted for brevity
    Result := nil;
  end;
end;

procedure TDbSet<T>.AddRange(const AEntities: TArray<T>);
begin
  for var Entity in AEntities do
    Add(Entity);
end;

procedure TDbSet<T>.AddRange(const AEntities: TEnumerable<T>);
begin
  for var Entity in AEntities do
    Add(Entity);
end;

procedure TDbSet<T>.UpdateRange(const AEntities: TArray<T>);
begin
  for var Entity in AEntities do
    Update(Entity);
end;

procedure TDbSet<T>.UpdateRange(const AEntities: TEnumerable<T>);
begin
  for var Entity in AEntities do
    Update(Entity);
end;

procedure TDbSet<T>.RemoveRange(const AEntities: TArray<T>);
begin
  for var Entity in AEntities do
    Remove(Entity);
end;

procedure TDbSet<T>.RemoveRange(const AEntities: TEnumerable<T>);
begin
  for var Entity in AEntities do
    Remove(Entity);
end;

function TDbSet<T>.List: TList<T>;
begin
  Result := List(TSpecification<T>.Create(nil));
end;

function TDbSet<T>.List(const ASpec: ISpecification<T>): TList<T>;
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
  Reader: IDbReader;
begin
  Result := TList<T>.Create;
  Generator := TSqlGenerator<T>.Create(FContext.Dialect);
  try
    Sql := Generator.GenerateSelect(ASpec);
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;

    // Bind Params from Generator
    for var Pair in Generator.Params do
    begin
      Cmd.AddParam(Pair.Key, Pair.Value);
    end;

    Reader := Cmd.ExecuteQuery;
    while Reader.Next do
    begin
      Result.Add(Hydrate(Reader));
    end;

    // Load Includes
    if Length(ASpec.GetIncludes) > 0 then
      DoLoadIncludes(Result, ASpec.GetIncludes);

  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.DoLoadIncludes(const AEntities: TList<T>; const AIncludes: TArray<string>);
begin
  // Implementation of Eager Loading (Include)
  // This is complex and requires analyzing the Include path and loading related entities.
  // For now, we will leave it empty or implement basic support later.
end;

function TDbSet<T>.List(const AExpression: IExpression): TList<T>;
begin
  Result := List(TSpecification<T>.Create(AExpression));
end;

function TDbSet<T>.FirstOrDefault(const AExpression: IExpression): T;
begin
  Result := Query(TSpecification<T>.Create(AExpression)).FirstOrDefault;
end;

function TDbSet<T>.Any(const AExpression: IExpression): Boolean;
begin
  Result := Query(TSpecification<T>.Create(AExpression)).Any;
end;

function TDbSet<T>.Count(const AExpression: IExpression): Integer;
begin
  Result := Query(TSpecification<T>.Create(AExpression)).Count;
end;

function TDbSet<T>.Query(const ASpec: ISpecification<T>): TFluentQuery<T>;
begin
  Result := TFluentQuery<T>.Create(
    function: TQueryIterator<T>
    begin
      var Spec := ASpec;
      Result := TSpecificationQueryIterator<T>.Create(
        function: TList<T>
        begin
          Result := Self.List(Spec);
        end
      );
    end
  );
end;

function TDbSet<T>.Query(const AExpression: IExpression): TFluentQuery<T>;
begin
  Result := Query(TSpecification<T>.Create(AExpression));
end;

function TDbSet<T>.QueryAll: TFluentQuery<T>;
begin
  Result := Query(TSpecification<T>.Create(nil));
end;

end.
