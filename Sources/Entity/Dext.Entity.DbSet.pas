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
    function GetEntityId(const AEntity: T): string;
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

    function List(const ASpec: ISpecification<T>): TList<T>; overload;
    function List: TList<T>; overload;
    function FirstOrDefault(const ASpec: ISpecification<T>): T; overload;

    function Any(const ASpec: ISpecification<T>): Boolean; overload;
    function Count(const ASpec: ISpecification<T>): Integer; overload;

    // Inline Queries
    function List(const AExpression: IExpression): TList<T>; overload;
    function FirstOrDefault(const AExpression: IExpression): T; overload;
    function Any(const AExpression: IExpression): Boolean; overload;
    function Count(const AExpression: IExpression): Integer; overload;
    
    // Lazy Queries (Deferred Execution)
    function Query(const ASpec: ISpecification<T>): TFluentQuery<T>; overload;
    function Query(const AExpression: IExpression): TFluentQuery<T>; overload;
    function Query: TFluentQuery<T>; overload;
  end;

  // Helper class for inline queries (internal use)
  TInlineSpecification<T: class> = class(TSpecification<T>)
  public
    constructor CreateWithExpression(const AExpression: IExpression);
  end;

implementation


  constructor TInlineSpecification<T>.CreateWithExpression(const AExpression: IExpression);
  begin
    inherited Create;
    if AExpression <> nil then
      Where(AExpression);
  end;

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
      
      // Construct PKVal
      if PKValues.Count = FPKColumns.Count then
      begin
        if FPKColumns.Count = 1 then
          PKVal := PKValues[FPKColumns[0]]
        else
        begin
          // Composite
          var SB := TStringBuilder.Create;
          try
            for i := 0 to FPKColumns.Count - 1 do
            begin
              if i > 0 then SB.Append('|');
              SB.Append(PKValues[FPKColumns[i]]);
            end;
            PKVal := SB.ToString;
          finally
            SB.Free;
          end;
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
  
  // Populate properties
  for i := 0 to Reader.GetColumnCount - 1 do
  begin
    ColName := Reader.GetColumnName(i);
    Val := Reader.GetValue(i);
    
    if FProps.TryGetValue(ColName.ToLower, Prop) then
    begin
      TValueConverter.ConvertAndSet(Result, Prop, Val);
    end;
  end;
  
  // Add to Identity Map
  if PKVal <> '' then
    FIdentityMap.Add(PKVal, Result);
end;

function TDbSet<T>.FindObject(const AId: Variant): TObject;
begin
  Result := Find(AId);
end;

procedure TDbSet<T>.Add(const AEntity: TObject);
begin
  Add(T(AEntity));
end;

function TDbSet<T>.ListObjects(const AExpression: IExpression): TList<TObject>;
var
  ListT: TList<T>;
  Item: T;
begin
  Result := TList<TObject>.Create;
  ListT := List(AExpression);
  try
    for Item in ListT do
      Result.Add(Item);

    // TList dont have OwnsObjects, only TObjectList has
    //ListT.OwnsObjects := False; // Transfer ownership? No, ListObjects usually returns new list but objects are shared/owned by IdentityMap?
    // Actually, TDbSet owns objects in IdentityMap. List just returns references.
    // So caller should free List but NOT objects.
  finally
    ListT.Free;
  end;
end;

function TDbSet<T>.GenerateCreateTableScript: string;
var
  SB: TStringBuilder;
  Prop: TRttiProperty;
  ColName, ColType: string;
  IsPK, IsAutoInc: Boolean;
  Attr: TCustomAttribute;
  Body: string;
begin
  SB := TStringBuilder.Create;
  try
    //SB.Append('CREATE TABLE ').Append(GetTableName).Append(' (');
    
    var First := True;
    for Prop in FRttiContext.GetType(T).GetProperties do
    begin
      if not FColumns.ContainsKey(Prop.Name) then Continue;
      
      ColName := FColumns[Prop.Name];
      ColType := FContext.Dialect.GetColumnType(Prop.PropertyType.Handle);
      
      IsPK := False;
      IsAutoInc := False;
      
      for Attr in Prop.GetAttributes do
      begin
        if Attr is PKAttribute then IsPK := True;
        if Attr is AutoIncAttribute then IsAutoInc := True;
      end;
      
      if not First then SB.Append(', ');
      First := False;
      
      SB.Append(FContext.Dialect.QuoteIdentifier(ColName)).Append(' ').Append(ColType);
      
      if IsPK and (FPKColumns.Count = 1) then
        SB.Append(' PRIMARY KEY');
        
      if IsAutoInc then
        SB.Append(' AUTOINCREMENT'); // Dialect specific, but for SQLite/DuckDB ok
    end;
    
    // Composite PK
    if FPKColumns.Count > 1 then
    begin
      SB.Append(', PRIMARY KEY (');
      for var i := 0 to FPKColumns.Count - 1 do
      begin
        if i > 0 then SB.Append(', ');
        SB.Append(FContext.Dialect.QuoteIdentifier(FPKColumns[i]));
      end;
      SB.Append(')');
    end;
    
    //SB.Append(');');
    Body := SB.ToString;
    Result := FContext.Dialect.GetCreateTableSQL(GetTableName, Body);
  finally
    SB.Free;
  end;
end;

procedure TDbSet<T>.PersistAdd(const AEntity: TObject);
var
  Generator: TSQLGenerator<T>;
  SQL: string;
  Cmd: IDbCommand;
  Param: TPair<string, TValue>;
  LastId: Variant;
  PKProp: TRttiProperty;
  Entity: T;
begin
  Entity := T(AEntity);
  Generator := TSQLGenerator<T>.Create(FContext.Dialect);
  try
    SQL := Generator.GenerateInsert(Entity);
    Cmd := FContext.Connection.CreateCommand(SQL) as IDbCommand;
    
    for Param in Generator.Params do
      Cmd.AddParam(Param.Key, Param.Value);
      
    Cmd.Execute;
    
    // Handle AutoInc
    // If there is a single PK and it is AutoInc
    if (FPKColumns.Count = 1) then
    begin
       if FProps.TryGetValue(FPKColumns[0].ToLower, PKProp) then
       begin
         if PKProp.GetAttribute<AutoIncAttribute> <> nil then
         begin
            LastId := FContext.Connection.GetLastInsertId;
            TValueConverter.ConvertAndSet(Entity, PKProp, TValue.FromVariant(LastId));
         end;
       end;
    end;
    
    // Add to Identity Map
    var ID := GetEntityId(Entity);
    if not FIdentityMap.ContainsKey(ID) then
      FIdentityMap.Add(ID, Entity);
      
  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.Add(const AEntity: T);
begin
  FContext.ChangeTracker.Track(AEntity, esAdded);
end;

procedure TDbSet<T>.PersistUpdate(const AEntity: TObject);
var
  Generator: TSQLGenerator<T>;
  SQL: string;
  Cmd: IDbCommand;
  Param: TPair<string, TValue>;
  RowsAffected: Integer;
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  VersionProp: TRttiProperty;
  Entity: T;
begin
  Entity := T(AEntity);
  Generator := TSQLGenerator<T>.Create(FContext.Dialect);
  try
    SQL := Generator.GenerateUpdate(Entity);
    Cmd := FContext.Connection.CreateCommand(SQL) as IDbCommand;
    
    for Param in Generator.Params do
      Cmd.AddParam(Param.Key, Param.Value);
      
    RowsAffected := Cmd.ExecuteNonQuery;
    
    // Find Version Property
    VersionProp := nil;
    Ctx := TRttiContext.Create;
    Typ := Ctx.GetType(T);
    for Prop in Typ.GetProperties do
    begin
      for Attr in Prop.GetAttributes do
        if Attr is VersionAttribute then
        begin
          VersionProp := Prop;
          Break;
        end;
      if VersionProp <> nil then Break;
    end;

    if RowsAffected = 0 then
    begin
      if VersionProp <> nil then
        raise EOptimisticConcurrencyException.Create('Optimistic concurrency failure. Entity has been modified by another process.');
    end
    else if VersionProp <> nil then
    begin
      // Increment version in memory
      var CurrentVersion := VersionProp.GetValue(Pointer(Entity)).AsInteger;
      VersionProp.SetValue(Pointer(Entity), CurrentVersion + 1);
    end;
    
  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.Update(const AEntity: T);
begin
  FContext.ChangeTracker.Track(AEntity, esModified);
end;

procedure TDbSet<T>.PersistRemove(const AEntity: TObject);
var
  Generator: TSQLGenerator<T>;
  SQL: string;
  Cmd: IDbCommand;
  Param: TPair<string, TValue>;
  Entity: T;
begin
  Entity := T(AEntity);
  Generator := TSQLGenerator<T>.Create(FContext.Dialect);
  try
    SQL := Generator.GenerateDelete(Entity);
    Cmd := FContext.Connection.CreateCommand(SQL) as IDbCommand;
    
    for Param in Generator.Params do
      Cmd.AddParam(Param.Key, Param.Value);
      
    Cmd.Execute;
    
    // Remove from Identity Map
    var ID := GetEntityId(Entity);
    if FIdentityMap.ContainsKey(ID) then
      FIdentityMap.Remove(ID); 
      
  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.Remove(const AEntity: T);
begin
  FContext.ChangeTracker.Track(AEntity, esDeleted);
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
  for var Entity in AEntities do Add(Entity);
end;

procedure TDbSet<T>.AddRange(const AEntities: TEnumerable<T>);
begin
  for var Entity in AEntities do Add(Entity);
end;

procedure TDbSet<T>.UpdateRange(const AEntities: TArray<T>);
begin
  for var Entity in AEntities do Update(Entity);
end;

procedure TDbSet<T>.UpdateRange(const AEntities: TEnumerable<T>);
begin
  for var Entity in AEntities do Update(Entity);
end;

procedure TDbSet<T>.RemoveRange(const AEntities: TArray<T>);
begin
  for var Entity in AEntities do Remove(Entity);
end;

procedure TDbSet<T>.RemoveRange(const AEntities: TEnumerable<T>);
begin
  for var Entity in AEntities do Remove(Entity);
end;

procedure TDbSet<T>.DoLoadIncludes(const AEntities: TList<T>; const AIncludes: TArray<string>);
var
  IncludePath: string;
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  FKAttr: ForeignKeyAttribute;
  FKProp: TRttiProperty;
  FKValue: TValue;
  FKValues: TList<Integer>;
  FKSet: TDictionary<Integer, Boolean>;
  Entity: T;
  RelatedSet: IDbSet;
  RelatedEntities: TList<TObject>;
  RelatedEntity: TObject;
  FKMap: TDictionary<Integer, TObject>;
  RelatedType: PTypeInfo;
  RelatedPKName: string;
  Crit: IExpression;
  PropHelper: TProperty;
  P: TRttiProperty;
  Attr: TCustomAttribute;
  ColAttr: ColumnAttribute;
  RelTyp: TRttiType;
  RelPKProp: TRttiProperty;
  PKVal: TValue;
  ID: Integer;
begin
  if (AEntities.Count = 0) or (Length(AIncludes) = 0) then Exit;

  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);

  for IncludePath in AIncludes do
  begin
    // 1. Find Navigation Property
    Prop := Typ.GetProperty(IncludePath);
    if Prop = nil then Continue;
    
    // 2. Get FK Attribute
    FKAttr := nil;
    for Attr in Prop.GetAttributes do
      if Attr is ForeignKeyAttribute then
      begin
        FKAttr := ForeignKeyAttribute(Attr);
        Break;
      end;
      
    if FKAttr = nil then Continue;
    
    // 3. Find FK Property
    FKProp := Typ.GetProperty(FKAttr.ColumnName);
    if FKProp = nil then
    begin
       for P in Typ.GetProperties do
       begin
         ColAttr := P.GetAttribute<ColumnAttribute>;
         if (ColAttr <> nil) and (SameText(ColAttr.Name, FKAttr.ColumnName)) then
         begin
           FKProp := P;
           Break;
         end;
       end;
    end;
    
    if FKProp = nil then Continue;
    
    // 4. Collect FK Values
    FKSet := TDictionary<Integer, Boolean>.Create;
    try
      for Entity in AEntities do
      begin
        FKValue := FKProp.GetValue(Pointer(Entity));
        if not FKValue.IsEmpty and (FKValue.Kind in [tkInteger, tkInt64]) then
        begin
            if FKValue.AsInteger <> 0 then
              FKSet.AddOrSetValue(FKValue.AsInteger, True);
        end;
      end;
      
      if FKSet.Count = 0 then Continue;
      
      FKValues := TList<Integer>.Create;
      try
        for ID in FKSet.Keys do FKValues.Add(ID);
        
        // 5. Fetch Related Entities
        RelatedType := Prop.PropertyType.Handle;
        RelatedSet := FContext.DataSet(RelatedType);
        
        // Find PK name of related entity
        RelTyp := Ctx.GetType(RelatedType);
        RelatedPKName := 'Id';
        for P in RelTyp.GetProperties do
        begin
          if P.GetAttribute<PKAttribute> <> nil then
          begin
            RelatedPKName := P.Name;
            Break;
          end;
        end;
        
        // Build Expression: RelatedPK IN (FKValues)
        PropHelper := TProperty.Create(RelatedPKName);
        Crit := PropHelper.&In(FKValues.ToArray);
        
        RelatedEntities := RelatedSet.ListObjects(Crit);
        try
          // 6. Map FK -> RelatedEntity
          FKMap := TDictionary<Integer, TObject>.Create;
          try
            RelPKProp := RelTyp.GetProperty(RelatedPKName);
            if RelPKProp <> nil then
            begin
                for RelatedEntity in RelatedEntities do
                begin
                    PKVal := RelPKProp.GetValue(RelatedEntity);
                    if not PKVal.IsEmpty then
                        FKMap.AddOrSetValue(PKVal.AsInteger, RelatedEntity);
                end;
            end;
            
            // 7. Assign back to main entities
            for Entity in AEntities do
            begin
                FKValue := FKProp.GetValue(Pointer(Entity));
                if not FKValue.IsEmpty and (FKValue.AsInteger <> 0) then
                begin
                    if FKMap.TryGetValue(FKValue.AsInteger, RelatedEntity) then
                    begin
                        Prop.SetValue(Pointer(Entity), TValue.From(RelatedEntity));
                    end;
                end;
            end;
            
          finally
            FKMap.Free;
          end;
        finally
          RelatedEntities.Free;
        end;
        
      finally
        FKValues.Free;
      end;
    finally
      FKSet.Free;
    end;
  end;
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
    // 0. Generate SELECT columns
    if Length(ASpec.GetSelectedColumns) > 0 then
    begin
      SQL.Append('SELECT ');
      for var i := 0 to Length(ASpec.GetSelectedColumns) - 1 do
      begin
        if i > 0 then SQL.Append(', ');
        var ColName := ASpec.GetSelectedColumns[i];
        if FColumns.ContainsKey(ColName) then
          ColName := FColumns[ColName];
        SQL.Append(FContext.Dialect.QuoteIdentifier(ColName));
      end;
      SQL.Append(' FROM ').Append(GetTableName);
    end
    else
      SQL.Append('SELECT * FROM ').Append(GetTableName);
    
    // 1. Generate WHERE
    if ASpec.GetExpression <> nil then
    begin
      WhereClause := Generator.Generate(ASpec.GetExpression);
      if WhereClause <> '' then
        SQL.Append(' WHERE ').Append(WhereClause);
    end;
    
    // 2. Generate ORDER BY
    if Length(ASpec.GetOrderBy) > 0 then
    begin
      SQL.Append(' ORDER BY ');
      for var i := 0 to Length(ASpec.GetOrderBy) - 1 do
      begin
        if i > 0 then SQL.Append(', ');
        SQL.Append(ASpec.GetOrderBy[i].GetPropertyName);
        if not ASpec.GetOrderBy[i].GetAscending then
          SQL.Append(' DESC');
      end;
    end;
    
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
      
    // 5. Load Includes (Eager Loading)
    if Length(ASpec.GetIncludes) > 0 then
      DoLoadIncludes(Result, ASpec.GetIncludes);
      
  finally
    SQL.Free;
    Generator.Free;
  end;
end;

function TDbSet<T>.List: TList<T>;
begin
  // Empty spec = All
  var Cmd := FContext.Connection.CreateCommand('SELECT * FROM ' + GetTableName) as IDbCommand;
  var Reader := Cmd.ExecuteQuery;
  Result := TList<T>.Create;
  while Reader.Next do
    Result.Add(Hydrate(Reader));
end;

function TDbSet<T>.FirstOrDefault(const ASpec: ISpecification<T>): T;
var
  Generator: TSQLWhereGenerator;
  SQL: TStringBuilder;
  WhereClause: string;
  Cmd: IDbCommand;
  Reader: IDbReader;
  Param: TPair<string, TValue>;
begin
  Result := nil;
  Generator := TSQLWhereGenerator.Create(FContext.Dialect);
  SQL := TStringBuilder.Create;
  try
    // 0. Generate SELECT columns
    if Length(ASpec.GetSelectedColumns) > 0 then
    begin
      SQL.Append('SELECT ');
      for var i := 0 to Length(ASpec.GetSelectedColumns) - 1 do
      begin
        if i > 0 then SQL.Append(', ');
        var ColName := ASpec.GetSelectedColumns[i];
        if FColumns.ContainsKey(ColName) then
          ColName := FColumns[ColName];
        SQL.Append(FContext.Dialect.QuoteIdentifier(ColName));
      end;
      SQL.Append(' FROM ').Append(GetTableName);
    end
    else
      SQL.Append('SELECT * FROM ').Append(GetTableName);
    
    // 1. Generate WHERE
    if ASpec.GetExpression <> nil then
    begin
      WhereClause := Generator.Generate(ASpec.GetExpression);
      if WhereClause <> '' then
        SQL.Append(' WHERE ').Append(WhereClause);
    end;
    
    // 2. Generate ORDER BY
    if Length(ASpec.GetOrderBy) > 0 then
    begin
      SQL.Append(' ORDER BY ');
      for var i := 0 to Length(ASpec.GetOrderBy) - 1 do
      begin
        if i > 0 then SQL.Append(', ');
        SQL.Append(ASpec.GetOrderBy[i].GetPropertyName);
        if not ASpec.GetOrderBy[i].GetAscending then
          SQL.Append(' DESC');
      end;
    end;
    
    // 3. OPTIMIZATION: Always add LIMIT 1
    SQL.Append(' ').Append(FContext.Dialect.GeneratePaging(0, 1));
    
    // 4. Execute
    Cmd := FContext.Connection.CreateCommand(SQL.ToString) as IDbCommand;
    
    for Param in Generator.Params do
      Cmd.AddParam(Param.Key, Param.Value);
      
    Reader := Cmd.ExecuteQuery;
    if Reader.Next then
      Result := Hydrate(Reader);
      
    // Note: Include is not supported for FirstOrDefault (would need to load the single entity's includes)
    // If needed in the future, can call DoLoadIncludes with a single-item list
      
  finally
    SQL.Free;
    Generator.Free;
  end;
end;

function TDbSet<T>.Any(const ASpec: ISpecification<T>): Boolean;
var
  Generator: TSQLWhereGenerator;
  SQL: TStringBuilder;
  WhereClause: string;
  Cmd: IDbCommand;
  Reader: IDbReader;
  Param: TPair<string, TValue>;
begin
  // OPTIMIZATION: Use LIMIT 1 instead of COUNT(*)
  // This stops at the first match instead of counting all records
  Generator := TSQLWhereGenerator.Create(FContext.Dialect);
  SQL := TStringBuilder.Create;
  try
    SQL.Append('SELECT 1 FROM ').Append(GetTableName);
    
    // Generate WHERE clause
    if ASpec.GetExpression <> nil then
    begin
      WhereClause := Generator.Generate(ASpec.GetExpression);
      if WhereClause <> '' then
        SQL.Append(' WHERE ').Append(WhereClause);
    end;
    
    // Add LIMIT 1 for early termination
    SQL.Append(' ').Append(FContext.Dialect.GeneratePaging(0, 1));
    
    Cmd := FContext.Connection.CreateCommand(SQL.ToString) as IDbCommand;
    for Param in Generator.Params do
      Cmd.AddParam(Param.Key, Param.Value);
      
    Reader := Cmd.ExecuteQuery;
    Result := Reader.Next; // True if at least one record exists
  finally
    SQL.Free;
    Generator.Free;
  end;
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
    
    if ASpec.GetExpression <> nil then
    begin
      WhereClause := Generator.Generate(ASpec.GetExpression);
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

function TDbSet<T>.List(const AExpression: IExpression): TList<T>;
var
  Spec: ISpecification<T>;
begin
  Spec := TInlineSpecification<T>.CreateWithExpression(AExpression);
  Result := List(Spec);
end;

function TDbSet<T>.FirstOrDefault(const AExpression: IExpression): T;
var
  Spec: ISpecification<T>;
begin
  Spec := TInlineSpecification<T>.CreateWithExpression(AExpression);
  Result := FirstOrDefault(Spec as ISpecification<T>);
end;

function TDbSet<T>.Any(const AExpression: IExpression): Boolean;
var
  Spec: ISpecification<T>;
begin
  Spec := TInlineSpecification<T>.CreateWithExpression(AExpression);
  Result := Any(Spec as ISpecification<T>);
end;

function TDbSet<T>.Count(const AExpression: IExpression): Integer;
var
  Spec: ISpecification<T>;
begin
  Spec := TInlineSpecification<T>.CreateWithExpression(AExpression);
  Result := Count(Spec as ISpecification<T>);
end;

{ Lazy Query Methods }

function TDbSet<T>.Query(const ASpec: ISpecification<T>): TFluentQuery<T>;
begin
  // Return a lazy enumerable that defers execution until enumerated
  Result := TFluentQuery<T>.Create(
    function: TQueryIterator<T>
    begin
      // Capture ASpec in closure
      Result := TSpecificationQueryIterator<T>.Create(
        function: TList<T>
        begin
          // This is only executed when MoveNext is called!
          Result := List(ASpec);
        end);
    end);
end;

function TDbSet<T>.Query(const AExpression: IExpression): TFluentQuery<T>;
var
  Spec: ISpecification<T>;
begin
  Spec := TInlineSpecification<T>.CreateWithExpression(AExpression);
  Result := Query(Spec);
end;

function TDbSet<T>.Query: TFluentQuery<T>;
begin
  // Return all records (lazy)
  Result := TFluentQuery<T>.Create(
    function: TQueryIterator<T>
    begin
      Result := TSpecificationQueryIterator<T>.Create(
        function: TList<T>
        begin
          // This is only executed when MoveNext is called!
          Result := List();  // All records
        end);
    end);
end;

end.
