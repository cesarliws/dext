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
  Dext.Entity.Mapping, // Add Mapping unit
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Query,
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces,
  Dext.Specifications.SQL.Generator,
  Dext.Specifications.Types,
  Dext.Types.Nullable;

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
    FMap: TEntityMap;

    procedure MapEntity;
    function Hydrate(Reader: IDbReader): T;
  protected
    function GetEntityId(const AEntity: T): string; overload;
    function GetEntityId(const AEntity: TObject): string; overload;
    function GetPKColumns: TArray<string>;
    function GetRelatedId(const AObject: TObject): TValue;
    procedure DoLoadIncludes(const AEntities: TList<T>; const AIncludes: TArray<string>);
  public
    constructor Create(const AContext: IDbContext);
    destructor Destroy; override;

    function GetTableName: string;
    function FindObject(const AId: Variant): TObject;
    procedure Add(const AEntity: TObject); overload;
    procedure Update(const AEntity: TObject); overload;
    procedure Remove(const AEntity: TObject); overload;
    function ListObjects(const AExpression: IExpression): TList<TObject>;
    procedure PersistAdd(const AEntity: TObject);
    procedure PersistAddRange(const AEntities: TArray<TObject>);
    procedure PersistUpdate(const AEntity: TObject);
    procedure PersistRemove(const AEntity: TObject);
    function GenerateCreateTableScript: string;
    procedure Clear;

    procedure Add(const AEntity: T); overload;
    procedure Update(const AEntity: T); overload;
    procedure Remove(const AEntity: T); overload;
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

constructor TDbSet<T>.Create(const AContext: IDbContext);
begin
  inherited Create;
  FContext := AContext;
  FProps := TDictionary<string, TRttiProperty>.Create;
  FColumns := TDictionary<string, string>.Create;
  FPKColumns := TList<string>.Create;
  // Identity Map owns the entity instances to prevent memory leaks.
  // Entities are freed when the DbSet (and Context) is destroyed.
  FIdentityMap := TObjectDictionary<string, T>.Create([doOwnsValues]);
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
  PropMap: TPropertyMap;
  IsMapped: Boolean;
begin
  FRttiContext := TRttiContext.Create;
  Typ := FRttiContext.GetType(T);
  
  // Retrieve Fluent Mapping if available
  FMap := TEntityMap(FContext.GetMapping(TypeInfo(T)));

  // 1. Table Name
  FTableName := '';
  
  // Priority 1: Fluent Mapping
  if (FMap <> nil) and (FMap.TableName <> '') then
    FTableName := FMap.TableName;
    
  // Priority 2: Attributes
  if FTableName = '' then
  begin
    for Attr in Typ.GetAttributes do
      if Attr is TableAttribute then
        FTableName := TableAttribute(Attr).Name;
  end;
      
  // Priority 3: Naming Strategy
  if FTableName = '' then
    FTableName := FContext.Dialect.QuoteIdentifier(FContext.NamingStrategy.GetTableName(T)); 
    
  if FTableName = '' then
     FTableName := FContext.NamingStrategy.GetTableName(T);

  // 2. Properties & Columns
  for Prop in Typ.GetProperties do
  begin
    IsMapped := True;
    PropMap := nil;
    
    // Check Fluent Mapping for Property
    if FMap <> nil then
    begin
      if FMap.Properties.TryGetValue(Prop.Name, PropMap) then
      begin
        if PropMap.IsIgnored then IsMapped := False;
      end;
    end;

    // Check Attributes
    for Attr in Prop.GetAttributes do
      if Attr is NotMappedAttribute then
        IsMapped := False;

    if not IsMapped then Continue;

    ColName := '';

    // Priority 1: Fluent Mapping
    if (PropMap <> nil) and (PropMap.ColumnName <> '') then
      ColName := PropMap.ColumnName;

    // Priority 2: Attributes
    if ColName = '' then
    begin
      for Attr in Prop.GetAttributes do
      begin
        if Attr is ColumnAttribute then
          ColName := ColumnAttribute(Attr).Name;

        if Attr is ForeignKeyAttribute then
          ColName := ForeignKeyAttribute(Attr).ColumnName;
      end;
    end;
    
    // Priority 3: Naming Strategy
    if ColName = '' then
      ColName := FContext.NamingStrategy.GetColumnName(Prop);

    // PK Detection
    // Priority 1: Fluent Mapping
    if (PropMap <> nil) and PropMap.IsPK then
    begin
      if not FPKColumns.Contains(ColName) then
        FPKColumns.Add(ColName);
    end;
    
    // Priority 2: Attributes (Only if not already added by Fluent)
    
    if (FMap = nil) or (FMap.Keys.Count = 0) then
    begin
      for Attr in Prop.GetAttributes do
      begin
        if Attr is PKAttribute then
          if not FPKColumns.Contains(ColName) then
            FPKColumns.Add(ColName);
      end;
    end;

    FProps.Add(ColName.ToLower, Prop);
    FColumns.Add(Prop.Name, ColName);
  end;

  // Fallback if no PK defined: assume 'Id'
  if FPKColumns.Count = 0 then
  begin
    // If Map has keys defined but they weren't found in properties loop (e.g. composite key defined via HasKey(['A','B']))
    // We need to handle that.
    if (FMap <> nil) and (FMap.Keys.Count > 0) then
    begin
      for var KeyProp in FMap.Keys do
      begin
        if FColumns.ContainsKey(KeyProp) then
          FPKColumns.Add(FColumns[KeyProp]);
      end;
    end;
    
    // Default 'Id' convention
    if FPKColumns.Count = 0 then
    begin
      if FColumns.ContainsKey('Id') then
        FPKColumns.Add(FColumns['Id'])
      else if FColumns.ContainsKey('ID') then
        FPKColumns.Add(FColumns['ID']);
    end;
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
    
    // WriteLn(Format('DEBUG: Hydrate Col: %s, Val: %s', [ColName, Val.ToString]));

    if FProps.TryGetValue(ColName.ToLower, Prop) then
    begin
      try
        TValueConverter.ConvertAndSet(Result, Prop, Val);
      except
        on E: Exception do
          WriteLn(Format('ERROR setting prop %s from col %s: %s', [Prop.Name, ColName, E.Message]));
      end;
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

procedure TDbSet<T>.Update(const AEntity: TObject);
begin
  Update(T(AEntity));
end;

procedure TDbSet<T>.Remove(const AEntity: TObject);
begin
  Remove(T(AEntity));
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
  UseReturning: Boolean;
  RetVal: TValue;
begin
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
  try
    Sql := Generator.GenerateInsert(T(AEntity));
    
    // Check for RETURNING support
    UseReturning := (FPKColumns.Count = 1) and FContext.Dialect.SupportsInsertReturning;
    
    if UseReturning then
    begin
      // Append RETURNING clause
      Sql := Sql + ' ' + FContext.Dialect.GetReturningSQL(FPKColumns[0]);
    end;

    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;

    // Bind Params from Generator
    for var Pair in Generator.Params do
    begin
      try
        // Debug logging
        WriteLn(Format('DEBUG: Param %s, Type: %s', [Pair.Key, Pair.Value.TypeInfo.Name]));
        
        Cmd.AddParam(Pair.Key, Pair.Value);
      except
        on E: Exception do
        begin
          WriteLn(Format('CRITICAL ERROR in AddParam(%s): %s. Type: %s', 
            [Pair.Key, E.Message, Pair.Value.TypeInfo.Name]));
          raise;
        end;
      end;
    end;

    if UseReturning then
    begin
      // Execute Scalar to get the ID
      RetVal := Cmd.ExecuteScalar;
      if not RetVal.IsEmpty then
        PKVal := RetVal.AsVariant
      else
        PKVal := Null;
    end
    else
    begin
      // Standard Execute
      Cmd.ExecuteNonQuery;
      
      // Retrieve AutoInc ID if applicable
      if FPKColumns.Count = 1 then
      begin
         var LastIdSQL := FContext.Dialect.GetLastInsertIdSQL;
         if LastIdSQL <> '' then
         begin
           // Execute explicit SQL to get ID
           var IdCmd := FContext.Connection.CreateCommand(LastIdSQL) as IDbCommand;
           var IdVal := IdCmd.ExecuteScalar;
           if not IdVal.IsEmpty then
             PKVal := IdVal.AsVariant
           else
             PKVal := Null;
         end
         else
         begin
           // Fallback to Connection method
           PKVal := FContext.Connection.GetLastInsertId;
         end;
      end;
    end;
    
    // Assign ID to Entity
    if (FPKColumns.Count = 1) and not VarIsNull(PKVal) then
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

  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.PersistAddRange(const AEntities: TArray<TObject>);
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
  EntitiesT: TArray<T>;
  i: Integer;
  Props: TList<TPair<TRttiProperty, string>>;
  ParamValues: TArray<TValue>;
  Prop: TRttiProperty;
  ParamName: string;
  Val: TValue;
begin
  if Length(AEntities) = 0 then Exit;

  // Convert TObject array to T array
  SetLength(EntitiesT, Length(AEntities));
  for i := 0 to High(AEntities) do
    EntitiesT[i] := T(AEntities[i]);

  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
  try
    // 1. Generate Template SQL and get Mapped Properties
    Sql := Generator.GenerateInsertTemplate(Props);
    try
      if Sql = '' then Exit;

      Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;
      
      // 2. Set Array Size
      Cmd.SetArraySize(Length(EntitiesT));
      
      // 3. Bind Parameters (Arrays)
      SetLength(ParamValues, Length(EntitiesT));
      
      for var Pair in Props do
      begin
        Prop := Pair.Key;
        ParamName := Pair.Value;
        
        for i := 0 to High(EntitiesT) do
        begin
          Val := Prop.GetValue(Pointer(EntitiesT[i]));
          
          // Handle Nullable
          if IsNullable(Val.TypeInfo) then
          begin
             var Helper := TNullableHelper.Create(Val.TypeInfo);
             if Helper.HasValue(Val.GetReferenceToRawData) then
               ParamValues[i] := Helper.GetValue(Val.GetReferenceToRawData)
             else
               ParamValues[i] := TValue.Empty;
          end
          else
             ParamValues[i] := Val;
        end;
        
        Cmd.SetParamArray(ParamName, ParamValues);
      end;
      
      // 4. Execute Batch
      Cmd.ExecuteBatch(Length(EntitiesT));
      
    finally
      Props.Free;
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
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
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
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
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
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
  try
    Result := Generator.GenerateCreateTable(GetTableName);
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
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
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
var
  Spec: TSpecification<T>;
begin
  // Optimization: Use LIMIT 1 via Spec
  Spec := TSpecification<T>.Create(AExpression);
  Spec.Take(1);
  Result := Query(Spec).FirstOrDefault;
end;

function TDbSet<T>.Any(const AExpression: IExpression): Boolean;
var
  Spec: TSpecification<T>;
begin
  // Optimization: Use LIMIT 1 via Spec
  Spec := TSpecification<T>.Create(AExpression);
  Spec.Take(1);
  Result := Query(Spec).Any;
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
          Result := Self.List(ISpecification<T>(Spec));
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
