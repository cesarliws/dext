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
  Dext.Specifications.Interfaces,
  Dext.Specifications.SQL.Generator;

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
    function GetTableName: string;
    function Hydrate(Reader: IDbReader): T;
    function GetRelatedId(const AObject: TObject): TValue;
  protected
    function GetEntityId(const AEntity: T): string;
    function GetPKColumns: TArray<string>;
  public
    constructor Create(AContext: IDbContext);
    destructor Destroy; override;
    
    function FindObject(const AId: Variant): TObject;
    function GenerateCreateTableScript: string;
    
    procedure Add(const AEntity: T);
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
  FPKColumns := TList<string>.Create;
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
  FKAttr: ForeignKeyAttribute;
  RelatedEntity: TObject;
  RelatedSet: IDbSet;
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
        // Check if ColName is in FPKColumns
        // Simple linear search is fine for small number of PKs
        if FPKColumns.Contains(ColName) then // Case sensitive? FPKColumns usually from Attr/Prop name
        begin
          // We need to match case insensitive if DB returns different case
          // But FPKColumns stores what we mapped.
          // Let's assume Reader returns correct case or we normalize.
          // Actually, let's just store by name.
           PKValues.Add(ColName, Reader.GetValue(i).ToString);
        end;
      end;
      
      // Construct PKVal
      if PKValues.Count = FPKColumns.Count then
      begin
        if FPKColumns.Count = 1 then
          PKVal := PKValues[FPKColumns[0]]
        else
        begin
          var SB := TStringBuilder.Create;
          try
            for i := 0 to FPKColumns.Count - 1 do
            begin
              if i > 0 then SB.Append('|');
              if PKValues.ContainsKey(FPKColumns[i]) then
                SB.Append(PKValues[FPKColumns[i]])
              else
              begin
                // Missing PK column in result set?
                // Try case insensitive lookup?
                // For now, fail or empty.
                PKVal := ''; 
                Break;
              end;
            end;
            if PKVal = '' then PKVal := SB.ToString;
          finally
            SB.Free;
          end;
        end;
      end;
      
    finally
      PKValues.Free;
    end;
  end;
  
  if (PKVal <> '') and FIdentityMap.TryGetValue(PKVal, Result) then
  begin
    // Found in cache! Return it.
    // TODO: Should we refresh properties? For now, Identity Map pattern usually means "return cached instance".
    Exit;
  end;

  // Not found, create new
  // Use Activator to create instance (handles generic constraint issue)
  Result := TActivator.CreateInstance<T>([]);
  
  // Add to Identity Map immediately if we have a PK
  if PKVal <> '' then
    FIdentityMap.Add(PKVal, Result);

  try
    for i := 0 to Reader.GetColumnCount - 1 do
    begin
      ColName := Reader.GetColumnName(i).ToLower;
      Val := Reader.GetValue(i);
      
      if FProps.TryGetValue(ColName, Prop) then
      begin
        if not Val.IsEmpty then
        begin
          // Check if it's a Foreign Key
          FKAttr := nil;
          for var Attr in Prop.GetAttributes do
            if Attr is ForeignKeyAttribute then
              FKAttr := ForeignKeyAttribute(Attr);
              
          if FKAttr <> nil then
          begin
            // It's a relationship!
            // 1. Get the DbSet for the related type
            // Note: Prop.PropertyType.Handle gives PTypeInfo
            RelatedSet := FContext.DataSet(Prop.PropertyType.Handle);
            
            // 2. Find the related entity using the FK value
            if RelatedSet <> nil then
            begin
              RelatedEntity := RelatedSet.FindObject(Val.AsVariant);
              if RelatedEntity <> nil then
                Prop.SetValue(Pointer(Result), TValue.From(RelatedEntity));
            end;
          end
          else
          begin
            // Normal Property
            // Use Robust Converter
            var ConvertedVal := TValueConverter.Convert(Val, Prop.PropertyType.Handle);
            Prop.SetValue(Pointer(Result), ConvertedVal);
          end;
        end;
      end;
    end;
  except
    // If we added to map but failed to populate, we should remove it?
    if PKVal <> '' then FIdentityMap.Remove(PKVal);
    // Result is owned by Map if added. If we remove, we must free it.
    // But if we raise, the caller won't get Result.
    // If we added to map, Map owns it.
    // If we remove from map with OwnsValues, it frees it.
    // So FIdentityMap.Remove(PKVal) will free Result.
    raise;
  end;
end;

function TDbSet<T>.Find(const AId: array of Integer): T;
var
  i: Integer;
  VArray: array of Variant;
begin
  SetLength(VArray, Length(AId));
  for i := 0 to High(AId) do
    VArray[i] := AId[i];
  Result := Find(VarArrayOf(VArray));
end;

function TDbSet<T>.FindObject(const AId: Variant): TObject;
begin
  Result := Find(AId);
end;

function TDbSet<T>.GenerateCreateTableScript: string;
type
  TFKInfo = record
    ColumnName: string;
    ReferencedTable: string;
    ReferencedType: PTypeInfo;
    ReferencedColumn: string;
    OnDelete: TCascadeAction;
    OnUpdate: TCascadeAction;
  end;
var
  SB: TStringBuilder;
  Pair: TPair<string, string>;
  Prop: TRttiProperty;
  ColName, ColType: string;
  IsPK, IsAutoInc, IsForeignKey: Boolean;
  First: Boolean;
  FKAttr: ForeignKeyAttribute;
  ForeignKeys: TArray<TFKInfo>;
  FKInfo: TFKInfo;
  i: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('CREATE TABLE IF NOT EXISTS ').Append(GetTableName).Append(' (');
    
    First := True;
    SetLength(ForeignKeys, 0);
    
    // Iterate over columns
    for Pair in FColumns do
    begin
      if not First then
        SB.Append(', ');
      First := False;
      
      ColName := Pair.Value;
      Prop := FProps[ColName.ToLower];
      
      IsPK := FPKColumns.Contains(ColName);
      IsAutoInc := False;
      IsForeignKey := False;
      FKAttr := nil;
      
      for var Attr in Prop.GetAttributes do
      begin
        if Attr is AutoIncAttribute then
          IsAutoInc := True;
          
        if Attr is ForeignKeyAttribute then
        begin
          IsForeignKey := True;
          FKAttr := ForeignKeyAttribute(Attr);
        end;
      end;
          
      SB.Append(FContext.Dialect.QuoteIdentifier(ColName));
      SB.Append(' ');
      
      // Get Type from Dialect
      ColType := FContext.Dialect.GetColumnType(Prop.PropertyType.Handle, IsAutoInc);
      SB.Append(ColType);
      
      // Add PRIMARY KEY inline for single PK (including AutoInc)
      // For SQLite, AutoInc columns should have PRIMARY KEY
      if IsPK and (FPKColumns.Count = 1) then 
        SB.Append(' PRIMARY KEY');
        
      // Collect FK information for later
      if IsForeignKey and (FKAttr <> nil) then
      begin
        // Extract referenced table and column from the property type
        // For now, we'll use the property type name as the table name
        // and assume the referenced column is 'Id' (can be enhanced later)
        FKInfo.ColumnName := FKAttr.ColumnName;
        FKInfo.ReferencedTable := Prop.PropertyType.Name; // e.g., 'TUser' -> 'users'
        FKInfo.ReferencedType := Prop.PropertyType.Handle;
        FKInfo.ReferencedColumn := 'Id'; // Default assumption
        FKInfo.OnDelete := FKAttr.OnDelete;
        FKInfo.OnUpdate := FKAttr.OnUpdate;
        
        SetLength(ForeignKeys, Length(ForeignKeys) + 1);
        ForeignKeys[High(ForeignKeys)] := FKInfo;
      end;
    end;
    
    // Composite PK Constraint
    if FPKColumns.Count > 1 then
    begin
      SB.Append(', PRIMARY KEY (');
      for i := 0 to FPKColumns.Count - 1 do
      begin
        if i > 0 then SB.Append(', ');
        SB.Append(FContext.Dialect.QuoteIdentifier(FPKColumns[i]));
      end;
      SB.Append(')');
    end;
    
    // Add FOREIGN KEY constraints
    for FKInfo in ForeignKeys do
    begin
      SB.Append(', FOREIGN KEY (');
      SB.Append(FContext.Dialect.QuoteIdentifier(FKInfo.ColumnName));
      SB.Append(') REFERENCES ');
      
      // Get the actual table name from the referenced type's Table attribute
      var RefTable := FKInfo.ReferencedTable;
      var RefTableName: string;
      var Found := False;
      
      try
        // Try to get from Context first (reliable if registered)
        var RefSet := FContext.DataSet(FKInfo.ReferencedType);
        if RefSet <> nil then
        begin
          RefTableName := RefSet.GetTableName; // Already quoted
          Found := True;
        end;
      except
        // Ignore if not found/registered yet
      end;
      
      if not Found then
      begin
        var RefTypeInfo := FRttiContext.FindType(RefTable);
        if RefTypeInfo <> nil then
        begin
          for var Attr in RefTypeInfo.GetAttributes do
          begin
            if Attr is TableAttribute then
            begin
              RefTable := TableAttribute(Attr).Name;
              Break;
            end;
          end;
        end;
        
        // Fallback: simple conversion if no Table attribute found
        if RefTable = FKInfo.ReferencedTable then
        begin
          if RefTable.StartsWith('T') then
            RefTable := RefTable.Substring(1);
          RefTable := RefTable.ToLower + 's'; // Simple pluralization
        end;
        
        RefTableName := FContext.Dialect.QuoteIdentifier(RefTable);
      end;
      
      SB.Append(RefTableName);
      SB.Append('(');
      SB.Append(FContext.Dialect.QuoteIdentifier(FKInfo.ReferencedColumn));
      SB.Append(')');
      
      // Add CASCADE actions if not NO ACTION
      if FKInfo.OnDelete <> caNoAction then
      begin
        SB.Append(' ON DELETE ');
        SB.Append(FContext.Dialect.GetCascadeActionSQL(FKInfo.OnDelete));
      end;
      
      if FKInfo.OnUpdate <> caNoAction then
      begin
        SB.Append(' ON UPDATE ');
        SB.Append(FContext.Dialect.GetCascadeActionSQL(FKInfo.OnUpdate));
      end;
    end;
    
    SB.Append(')');
    Result := SB.ToString;
  finally
    SB.Free;
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
  //PKVal: string;
begin
  try
    SB := TStringBuilder.Create;
    Cols := TStringBuilder.Create;
    Vals := TStringBuilder.Create;
    ParamsToSet := TList<TPair<string, TValue>>.Create;
    try
      SB.Append('INSERT INTO ').Append(GetTableName).Append(' (');
      
      var First := True;
      
      for Pair in FColumns do
      begin
        try
          Prop := FProps[Pair.Value.ToLower];
          
          // Check for AutoInc (skip PK if autoinc)
          IsAutoInc := False;
          var IsFK := False;
          
          for var Attr in Prop.GetAttributes do
          begin
            if Attr is AutoIncAttribute then IsAutoInc := True;
            if Attr is ForeignKeyAttribute then IsFK := True;
          end;
              
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
          
          if IsFK then
          begin
            // Extract ID from related object
            if Val.IsObject and (Val.AsObject <> nil) then
              Val := GetRelatedId(Val.AsObject)
            else
              Val := TValue.Empty; // NULL
          end;
          
          ParamsToSet.Add(TPair<string, TValue>.Create(ParamName, Val));
        except
          on E: Exception do
            raise Exception.CreateFmt('Error processing property "%s": %s', [Pair.Value, E.Message]);
        end;
      end;
      
      SB.Append(Cols.ToString).Append(') VALUES (').Append(Vals.ToString).Append(')');
      
      var CmdIntf := FContext.Connection.CreateCommand(SB.ToString);
      if not Supports(CmdIntf, StringToGUID('{20000000-0000-0000-0000-000000000004}'), Cmd) then
        raise Exception.Create('Failed to create IDbCommand');
      
      try
        for var P in ParamsToSet do
          Cmd.AddParam(P.Key, P.Value);
      except
        on E: Exception do
          raise Exception.CreateFmt('Error adding params to command: %s', [E.Message]);
      end;
        
      try
        Cmd.ExecuteNonQuery;
        
        // Handle AutoInc ID retrieval and Identity Map
        if FPKColumns.Count = 1 then
        begin
          var PKColName := FPKColumns[0];
          var PKProp := FProps[PKColName.ToLower];
          var IsPKAutoInc := False;

          for var Attr in PKProp.GetAttributes do
            if Attr is AutoIncAttribute then IsPKAutoInc := True;
            
          if IsPKAutoInc then
          begin
            // Fetch the new ID
            var IdCmd := FContext.Connection.CreateCommand(FContext.Dialect.GetLastInsertIdSQL) as IDbCommand;
            var NewIdVal := IdCmd.ExecuteScalar; // TValue
            
            // Update Entity
            var ConvertedId := TValueConverter.Convert(NewIdVal, PKProp.PropertyType.Handle);
            PKProp.SetValue(Pointer(AEntity), ConvertedId);
            
            // Add to Identity Map
            var IdStr := NewIdVal.ToString;
            if not FIdentityMap.ContainsKey(IdStr) then
              FIdentityMap.Add(IdStr, AEntity);
          end
          else
          begin
            // Not AutoInc, user provided ID. Add to Map.
            var IdVal := PKProp.GetValue(Pointer(AEntity));
            var IdStr := IdVal.ToString;
            if (IdStr <> '') and (IdStr <> '0') and not FIdentityMap.ContainsKey(IdStr) then
              FIdentityMap.Add(IdStr, AEntity);
          end;
        end;
        
      except
        on E: Exception do
          raise Exception.CreateFmt('Error executing insert SQL: %s', [E.Message]);
      end;
      
    finally
      SB.Free;
      Cols.Free;
      Vals.Free;
      ParamsToSet.Free;
    end;
  except
    on E: Exception do
    begin
      var F: TextFile;
      AssignFile(F, 'c:\dev\Dext\error.log');
      if FileExists('c:\dev\Dext\error.log') then Append(F) else Rewrite(F);
      Writeln(F, 'CRITICAL ERROR in TDbSet.Add: ' + E.Message);
      CloseFile(F);
      raise Exception.CreateFmt('CRITICAL ERROR in TDbSet.Add: %s', [E.Message]);
    end;
  end;
end;

procedure TDbSet<T>.Update(const AEntity: T);
var
  SB: TStringBuilder;
  Cmd: IDbCommand;
  Pair: TPair<string, string>;
  Prop: TRttiProperty;
  Val: TValue;
  ParamName: string;
  PKValue: TValue;
  First: Boolean;
  i: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('UPDATE ').Append(GetTableName).Append(' SET ');
    
    First := True;
    PKValue := TValue.Empty;

    for Pair in FColumns do
    begin
      Prop := FProps[Pair.Value.ToLower];
      
      // If it is PK, don't update it
      if FPKColumns.Contains(Pair.Value) then Continue;

      if not First then
        SB.Append(', ');
      First := False;
      
      ParamName := 'p_' + Pair.Value;
      SB.Append(FContext.Dialect.QuoteIdentifier(Pair.Value))
        .Append(' = :')
        .Append(ParamName);
    end;
    
    // WHERE Clause
    SB.Append(' WHERE ');
    for i := 0 to FPKColumns.Count - 1 do
    begin
      if i > 0 then SB.Append(' AND ');
      SB.Append(FContext.Dialect.QuoteIdentifier(FPKColumns[i]))
        .Append(' = :pk_')
        .Append(FPKColumns[i]);
    end;
    
    Cmd := IDbCommand(FContext.Connection.CreateCommand(SB.ToString));

    // Bind Params (Update fields)
    for Pair in FColumns do
    begin
      if FPKColumns.Contains(Pair.Value) then Continue;
      
      Prop := FProps[Pair.Value.ToLower];
      Val := Prop.GetValue(Pointer(AEntity));

      // Check for FK
      var IsFK := False;
      for var Attr in Prop.GetAttributes do
        if Attr is ForeignKeyAttribute then IsFK := True;
        
      if IsFK then
      begin
        if Val.IsObject and (Val.AsObject <> nil) then
          Val := GetRelatedId(Val.AsObject)
        else
          Val := TValue.Empty;
      end;

      Cmd.AddParam('p_' + Pair.Value, Val);
    end;
    
    // Bind PK Params
    for i := 0 to FPKColumns.Count - 1 do
    begin
      if not FProps.TryGetValue(FPKColumns[i].ToLower, Prop) then
        raise Exception.Create('PK Property not found: ' + FPKColumns[i]);
        
      Val := Prop.GetValue(Pointer(AEntity));
      Cmd.AddParam('pk_' + FPKColumns[i], Val);
    end;
    
    Cmd.ExecuteNonQuery;
    
  finally
    SB.Free;
  end;
end;

procedure TDbSet<T>.Remove(const AEntity: T);
var
  SB: TStringBuilder;
  Cmd: IDbCommand;
  i: Integer;
  Prop: TRttiProperty;
  Val: TValue;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('DELETE FROM ').Append(GetTableName).Append(' WHERE ');
    
    for i := 0 to FPKColumns.Count - 1 do
    begin
      if i > 0 then SB.Append(' AND ');
      SB.Append(FContext.Dialect.QuoteIdentifier(FPKColumns[i]))
        .Append(' = :pk_')
        .Append(FPKColumns[i]);
    end;
    
    Cmd := IDbCommand(FContext.Connection.CreateCommand(SB.ToString));
    
    for i := 0 to FPKColumns.Count - 1 do
    begin
      if not FProps.TryGetValue(FPKColumns[i].ToLower, Prop) then
        raise Exception.Create('PK Property not found: ' + FPKColumns[i]);
        
      Val := Prop.GetValue(Pointer(AEntity));
      Cmd.AddParam('pk_' + FPKColumns[i], Val);
    end;
    
    Cmd.ExecuteNonQuery;
    
    // Remove from Identity Map
    var Id := GetEntityId(AEntity);
    if FIdentityMap.ContainsKey(Id) then
      FIdentityMap.ExtractPair(Id); // Extract so we don't free the instance we are holding
  finally
    SB.Free;
  end;
end;

procedure TDbSet<T>.AddRange(const AEntities: TArray<T>);
var
  Entity: T;
  OwnTransaction: Boolean;
begin
  OwnTransaction := not FContext.InTransaction;
  if OwnTransaction then FContext.BeginTransaction;
  try
    for Entity in AEntities do
      Add(Entity);
      
    if OwnTransaction then FContext.Commit;
  except
    if OwnTransaction then FContext.Rollback;
    raise;
  end;
end;

procedure TDbSet<T>.AddRange(const AEntities: TEnumerable<T>);
var
  Entity: T;
  OwnTransaction: Boolean;
begin
  try
    OwnTransaction := not FContext.InTransaction;
    if OwnTransaction then FContext.BeginTransaction;
    try
      for Entity in AEntities do
        Add(Entity);
        
      if OwnTransaction then FContext.Commit;
    except
      if OwnTransaction then FContext.Rollback;
      raise;
    end;
  except
    on E: Exception do
      raise Exception.CreateFmt('CRITICAL ERROR in AddRange: %s', [E.Message]);
  end;
end;

procedure TDbSet<T>.UpdateRange(const AEntities: TArray<T>);
var
  Entity: T;
  OwnTransaction: Boolean;
begin
  OwnTransaction := not FContext.InTransaction;
  if OwnTransaction then FContext.BeginTransaction;
  try
    for Entity in AEntities do
      Update(Entity);
      
    if OwnTransaction then FContext.Commit;
  except
    if OwnTransaction then FContext.Rollback;
    raise;
  end;
end;

procedure TDbSet<T>.UpdateRange(const AEntities: TEnumerable<T>);
var
  Entity: T;
  OwnTransaction: Boolean;
begin
  OwnTransaction := not FContext.InTransaction;
  if OwnTransaction then FContext.BeginTransaction;
  try
    for Entity in AEntities do
      Update(Entity);
      
    if OwnTransaction then FContext.Commit;
  except
    if OwnTransaction then FContext.Rollback;
    raise;
  end;
end;

procedure TDbSet<T>.RemoveRange(const AEntities: TArray<T>);
var
  Entity: T;
  OwnTransaction: Boolean;
begin
  OwnTransaction := not FContext.InTransaction;
  if OwnTransaction then FContext.BeginTransaction;
  try
    for Entity in AEntities do
      Remove(Entity);
      
    if OwnTransaction then FContext.Commit;
  except
    if OwnTransaction then FContext.Rollback;
    raise;
  end;
end;

procedure TDbSet<T>.RemoveRange(const AEntities: TEnumerable<T>);
var
  Entity: T;
  OwnTransaction: Boolean;
begin
  OwnTransaction := not FContext.InTransaction;
  if OwnTransaction then FContext.BeginTransaction;
  try
    for Entity in AEntities do
      Remove(Entity);
      
    if OwnTransaction then FContext.Commit;
  except
    if OwnTransaction then FContext.Rollback;
    raise;
  end;
end;

function TDbSet<T>.Find(const AId: Variant): T;
var
  Cmd: IDbCommand;
  Reader: IDbReader;
  SB: TStringBuilder;
  IdStr: string;
  i: Integer;
  Val: TValue;
begin
  // 1. Construct ID String for Cache
  if VarIsArray(AId) then
  begin
    // Composite Key passed as Array
    if VarArrayHighBound(AId, 1) - VarArrayLowBound(AId, 1) + 1 <> FPKColumns.Count then
      raise Exception.Create('Find: Argument count does not match PK column count.');
      
    SB := TStringBuilder.Create;
    try
      for i := VarArrayLowBound(AId, 1) to VarArrayHighBound(AId, 1) do
      begin
        if i > VarArrayLowBound(AId, 1) then SB.Append('|');
        SB.Append(VarToStr(AId[i]));
      end;
      IdStr := SB.ToString;
    finally
      SB.Free;
    end;
  end
  else
  begin
    // Single Value
    if FPKColumns.Count > 1 then
      raise Exception.Create('Find: Entity has composite PK, but single value provided.');
    IdStr := VarToStr(AId);
  end;
  
  // 2. Check Identity Map
  if FIdentityMap.TryGetValue(IdStr, Result) then
    Exit;

  Result := nil;
  
  // 3. Build Query
  SB := TStringBuilder.Create;
  try
    SB.Append('SELECT * FROM ').Append(GetTableName).Append(' WHERE ');
    
    for i := 0 to FPKColumns.Count - 1 do
    begin
      if i > 0 then SB.Append(' AND ');
      SB.Append(FContext.Dialect.QuoteIdentifier(FPKColumns[i]))
        .Append(' = :pk_')
        .Append(FPKColumns[i]);
    end;
    
    Cmd := IDbCommand(FContext.Connection.CreateCommand(SB.ToString));
    
    // Bind Params
    if VarIsArray(AId) then
    begin
      for i := 0 to FPKColumns.Count - 1 do
      begin
        Val := TValue.FromVariant(AId[VarArrayLowBound(AId, 1) + i]);
        Cmd.AddParam('pk_' + FPKColumns[i], Val);
      end;
    end
    else
    begin
      Val := TValue.FromVariant(AId);
      Cmd.AddParam('pk_' + FPKColumns[0], Val);
    end;
    
    Reader := Cmd.ExecuteQuery;
    if Reader.Next then
      Result := Hydrate(Reader); // Hydrate will add to map
      
  finally
    SB.Free;
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
