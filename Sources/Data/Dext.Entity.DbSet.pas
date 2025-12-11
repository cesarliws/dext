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
unit Dext.Entity.DbSet;

interface

uses
  System.Generics.Collections,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  System.Variants,
  Dext.Collections,
  Dext.Core.Activator,
  Dext.Core.ValueConverters,
  Dext.Entity.Attributes,
  Dext.Entity.Core,
  Dext.Entity.Dialects,
  Dext.Entity.Mapping,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Query,
  Dext.Specifications.Base,
  Dext.Specifications.Expression,
  Dext.Specifications.Interfaces,
  Dext.Specifications.SQL.Generator,
  Dext.Specifications.Types,
  Dext.Types.Nullable;

type
  TDbSet<T: class> = class(TInterfacedObject, IDbSet<T>, IDbSet)
  private
    FContextPtr: Pointer;
    FRttiContext: TRttiContext; 
    FTableName: string;
    FPKColumns: TList<string>; 
    FProps: TDictionary<string, TRttiProperty>; 
    FColumns: TDictionary<string, string>;      
    FIdentityMap: TObjectDictionary<string, T>; 
    FMap: TEntityMap;
    // Filters control
    FIgnoreQueryFilters: Boolean;
    FOnlyDeleted: Boolean;

    function GetFContext: IDbContext;
    property FContext: IDbContext read GetFContext;

    procedure MapEntity;
    function Hydrate(const Reader: IDbReader; const Tracking: Boolean = True): T;
    procedure ExtractForeignKeys(const AEntities: IList<T>; PropertyToCheck: string;
      out IDs: TList<TValue>; out FKMap: TDictionary<T, TValue>);
    procedure LoadAndAssign(const AEntities: IList<T>; const NavPropName: string);
  protected
    function GetEntityId(const AEntity: T): string; overload;
    function GetEntityId(const AEntity: TObject): string; overload;
    function GetPKColumns: TArray<string>;
    function GetRelatedId(const AObject: TObject): TValue;
    procedure DoLoadIncludes(const AEntities: IList<T>; const AIncludes: TArray<string>);
  public
    constructor Create(const AContext: IDbContext); reintroduce;
    destructor Destroy; override;

    function GetTableName: string;
    function FindObject(const AId: Variant): TObject;
    procedure Add(const AEntity: TObject); overload;
    procedure Update(const AEntity: TObject); overload;
    procedure Remove(const AEntity: TObject); overload;
    function ListObjects(const AExpression: IExpression): IList<TObject>;
    procedure PersistAdd(const AEntity: TObject);
    procedure PersistAddRange(const AEntities: TArray<TObject>);
    procedure PersistUpdate(const AEntity: TObject);
    procedure PersistRemove(const AEntity: TObject);
    function GenerateCreateTableScript: string;
    procedure Clear;
    procedure DetachAll;
    procedure Detach(const AEntity: TObject); overload;


    procedure Add(const AEntity: T); overload;
    procedure Update(const AEntity: T); overload;
    procedure Remove(const AEntity: T); overload;
    procedure Detach(const AEntity: T); overload;
    function Find(const AId: Variant): T; overload;
    function Find(const AId: array of Integer): T; overload;
    function Find(const AId: array of Variant): T; overload;

    procedure AddRange(const AEntities: TArray<T>); overload;
    procedure AddRange(const AEntities: TEnumerable<T>); overload;

    procedure UpdateRange(const AEntities: TArray<T>); overload;
    procedure UpdateRange(const AEntities: TEnumerable<T>); overload;

    procedure RemoveRange(const AEntities: TArray<T>); overload;
    procedure RemoveRange(const AEntities: TEnumerable<T>); overload;

    function List: IList<T>; overload;
    function List(const ASpec: ISpecification<T>): IList<T>; overload;

    function List(const AExpression: IExpression): IList<T>; overload;
    function FirstOrDefault(const AExpression: IExpression): T; overload;
    function Any(const AExpression: IExpression): Boolean; overload;
    function Count(const AExpression: IExpression): Integer; overload;

    function Query(const ASpec: ISpecification<T>): TFluentQuery<T>; overload;
    function Query(const AExpression: IExpression): TFluentQuery<T>; overload;
    function QueryAll: TFluentQuery<T>;
    
    /// <summary>
    ///   Returns a query configured to not track entities (read-only).
    ///   Shortcut for QueryAll.AsNoTracking.
    /// </summary>
    function AsNoTracking: TFluentQuery<T>;

    // Soft Delete Control
    function IgnoreQueryFilters: IDbSet<T>;
    function OnlyDeleted: IDbSet<T>;
    procedure HardDelete(const AEntity: T);
    procedure Restore(const AEntity: T);
  end;

implementation

uses
  Dext.Entity.LazyLoading;

{ TDbSet<T> }

function TDbSet<T>.GetFContext: IDbContext;
begin
  Result := IDbContext(FContextPtr);
end;

constructor TDbSet<T>.Create(const AContext: IDbContext);
begin
  inherited Create;
  FContextPtr := Pointer(AContext);
  FProps := TDictionary<string, TRttiProperty>.Create;
  FColumns := TDictionary<string, string>.Create;
  FPKColumns := TList<string>.Create;
  FRttiContext := TRttiContext.Create;
  FIdentityMap := TObjectDictionary<string, T>.Create([doOwnsValues]);
  FIgnoreQueryFilters := False;
  FOnlyDeleted := False;
  MapEntity;
end;

destructor TDbSet<T>.Destroy;
begin
  FRttiContext.Free;
  FIdentityMap.Free;
  FProps.Free;
  FColumns.Free;
  FPKColumns.Free;
  inherited;
end;

procedure TDbSet<T>.MapEntity;
var
  Attr: TCustomAttribute;
  ColName: string;
  IsMapped: Boolean;
  Prop: TRttiProperty;
  PropMap: TPropertyMap;
  Typ: TRttiType;
begin
  Typ := FRttiContext.GetType(T);
  FMap := TEntityMap(FContext.GetMapping(TypeInfo(T)));
  FTableName := '';
  if (FMap <> nil) and (FMap.TableName <> '') then
    FTableName := FMap.TableName;
  if FTableName = '' then
  begin
    for Attr in Typ.GetAttributes do
      if Attr is TableAttribute then
        FTableName := TableAttribute(Attr).Name;
  end;
  if FTableName = '' then
    FTableName := FContext.Dialect.QuoteIdentifier(FContext.NamingStrategy.GetTableName(T)); 
  if FTableName = '' then
     FTableName := FContext.NamingStrategy.GetTableName(T);
  for Prop in Typ.GetProperties do
  begin
    IsMapped := True;
    PropMap := nil;
    if FMap <> nil then
    begin
      if FMap.Properties.TryGetValue(Prop.Name, PropMap) then
      begin
        if PropMap.IsIgnored then IsMapped := False;
      end;
    end;
    for Attr in Prop.GetAttributes do
      if Attr is NotMappedAttribute then
        IsMapped := False;
    if not IsMapped then Continue;
    ColName := '';
    if (PropMap <> nil) and (PropMap.ColumnName <> '') then
      ColName := PropMap.ColumnName;
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
    if ColName = '' then
      ColName := FContext.NamingStrategy.GetColumnName(Prop);
    if (PropMap <> nil) and PropMap.IsPK then
    begin
      if not FPKColumns.Contains(ColName) then
        FPKColumns.Add(ColName);
    end;
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
  if FPKColumns.Count = 0 then
  begin
    if (FMap <> nil) and (FMap.Keys.Count > 0) then
    begin
      for var KeyProp in FMap.Keys do
      begin
        if FColumns.ContainsKey(KeyProp) then
          FPKColumns.Add(FColumns[KeyProp]);
      end;
    end;
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
  Ctx := TRttiContext.Create;
  try
    Typ := Ctx.GetType(AObject.ClassType);
    for Prop in Typ.GetProperties do
    begin
      for Attr in Prop.GetAttributes do
        if Attr is PKAttribute then
          Exit(Prop.GetValue(AObject));
    end;
    Prop := Typ.GetProperty('Id');
    if Prop <> nil then
      Exit(Prop.GetValue(AObject));
  finally
    Ctx.Free;
  end;
  raise Exception.Create('Could not determine Primary Key for related entity ' + AObject.ClassName);
end;

function TDbSet<T>.Hydrate(const Reader: IDbReader; const Tracking: Boolean): T;
var
  i: Integer;
  ColName: string;
  Val: TValue;
  Prop: TRttiProperty;
  PKVal: string;
  PKValues: TDictionary<string, string>;
begin
  PKVal := '';
  
  if FPKColumns.Count > 0 then
  begin
    PKValues := TDictionary<string, string>.Create;
    try
      for i := 0 to Reader.GetColumnCount - 1 do
      begin
        ColName := Reader.GetColumnName(i);
        for var PKCol in FPKColumns do
        begin
          if SameText(PKCol, ColName) then
          begin
             PKValues.Add(PKCol, Reader.GetValue(i).ToString); 
             Break;
          end;
        end;
      end;
      if FPKColumns.Count = 1 then
      begin
        if PKValues.ContainsKey(FPKColumns[0]) then
          PKVal := PKValues[FPKColumns[0]];
      end
      else
      begin
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
  
  // Check IdentityMap
  if Tracking and (PKVal <> '') and FIdentityMap.TryGetValue(PKVal, Result) then
  begin
    // IMPORTANT: Inject lazy proxies even for cached entities
    // This ensures lazy loading works correctly after DetachAll/Clear
    TLazyInjector.Inject(FContext, Result);
    Exit;
  end;
  
  // Create new instance
  Result := TActivator.CreateInstance<T>;
  if Tracking and (PKVal <> '') then
    FIdentityMap.Add(PKVal, Result);
    
  // Inject lazy loading proxies
  TLazyInjector.Inject(FContext, Result);
  
  // Hydrate properties from reader
  for i := 0 to Reader.GetColumnCount - 1 do
  begin
    ColName := Reader.GetColumnName(i);
    Val := Reader.GetValue(i);
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

procedure TDbSet<T>.Detach(const AEntity: TObject);
begin
  Detach(T(AEntity));
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

procedure TDbSet<T>.Detach(const AEntity: T);
var
  Id: string;
begin
  Id := GetEntityId(AEntity);
  FIdentityMap.ExtractPair(Id);
  FContext.ChangeTracker.Remove(AEntity);
end;

procedure TDbSet<T>.AddRange(const AEntities: TArray<T>);
var
  Entity: T;
begin
  for Entity in AEntities do
    Add(Entity);
end;

procedure TDbSet<T>.AddRange(const AEntities: TEnumerable<T>);
var
  Entity: T;
begin
  for Entity in AEntities do
    Add(Entity);
end;

procedure TDbSet<T>.UpdateRange(const AEntities: TArray<T>);
var
  Entity: T;
begin
  for Entity in AEntities do
    Update(Entity);
end;

procedure TDbSet<T>.UpdateRange(const AEntities: TEnumerable<T>);
var
  Entity: T;
begin
  for Entity in AEntities do
    Update(Entity);
end;

procedure TDbSet<T>.RemoveRange(const AEntities: TArray<T>);
var
  Entity: T;
begin
  for Entity in AEntities do
    Remove(Entity);
end;

procedure TDbSet<T>.RemoveRange(const AEntities: TEnumerable<T>);
var
  Entity: T;
begin
  for Entity in AEntities do
    Remove(Entity);
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
    UseReturning := (FPKColumns.Count = 1) and FContext.Dialect.SupportsInsertReturning;
    if UseReturning then
    begin
      var ReturningClause := FContext.Dialect.GetReturningSQL(FPKColumns[0]);
      if FContext.Dialect.GetReturningPosition = rpBeforeValues then
      begin
        var ValuesPos := Pos(' VALUES ', UpperCase(Sql));
        if ValuesPos > 0 then
          Insert(' ' + ReturningClause + ' ', Sql, ValuesPos)
        else
          Sql := Sql + ' ' + ReturningClause;
      end
      else
        Sql := Sql + ' ' + ReturningClause;
    end;
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;
    for var Pair in Generator.Params do
      Cmd.AddParam(Pair.Key, Pair.Value);
    if UseReturning then
    begin
      RetVal := Cmd.ExecuteScalar;
      if not RetVal.IsEmpty then
        PKVal := RetVal.AsVariant
      else
        PKVal := Null;
    end
    else
    begin
      Cmd.ExecuteNonQuery;
      if FPKColumns.Count = 1 then
      begin
         var LastIdSQL := FContext.Dialect.GetLastInsertIdSQL;
         if LastIdSQL <> '' then
         begin
           var IdCmd := FContext.Connection.CreateCommand(LastIdSQL) as IDbCommand;
           var IdVal := IdCmd.ExecuteScalar;
           if not IdVal.IsEmpty then
             PKVal := IdVal.AsVariant
           else
             PKVal := Null;
         end
         else
           PKVal := FContext.Connection.GetLastInsertId;
      end;
    end;
     if FPKColumns.Count = 1 then
     begin
       if VarIsNull(PKVal) or VarIsEmpty(PKVal) then
         raise Exception.Create('Failed to retrieve ID for ' + GetTableName + '. Entity was not added to IdentityMap (possible memory leak).');
         
       if FProps.TryGetValue(FPKColumns[0].ToLower, Prop) then
       begin
         TValueConverter.ConvertAndSet(AEntity, Prop, TValue.FromVariant(PKVal));
         var NewId := VarToStr(PKVal); 
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
  SetLength(EntitiesT, Length(AEntities));
  for i := 0 to High(AEntities) do
    EntitiesT[i] := T(AEntities[i]);
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
  try
    Sql := Generator.GenerateInsertTemplate(Props);
    try
      if Sql = '' then Exit;
      Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;
      Cmd.SetArraySize(Length(EntitiesT));
      SetLength(ParamValues, Length(EntitiesT));
      for var Pair in Props do
      begin
        Prop := Pair.Key;
        ParamName := Pair.Value;
        for i := 0 to High(EntitiesT) do
        begin
          Val := Prop.GetValue(Pointer(EntitiesT[i]));
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
    for var Pair in Generator.Params do
      Cmd.AddParam(Pair.Key, Pair.Value);
    RowsAffected := Cmd.ExecuteNonQuery;
    if RowsAffected = 0 then
      raise EOptimisticConcurrencyException.Create('Concurrency violation: The record has been modified or deleted by another user.');
    Ctx := TRttiContext.Create;
    try
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
      Ctx.Free;
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
  Ctx: TRttiContext;
  RType: TRttiType;
  SoftDeleteAttr: SoftDeleteAttribute;
  Prop: TRttiProperty;
  ColumnName: string;
  IsSoftDelete: Boolean;
  PropName: string;
  DeletedVal: Variant;
begin
  IsSoftDelete := False;
  PropName := '';
  
  // 1. Check Fluent Mapping
  if (FMap <> nil) and FMap.IsSoftDelete then
  begin
    IsSoftDelete := True;
    PropName := FMap.SoftDeleteProp;
    DeletedVal := FMap.SoftDeleteDeletedValue;
  end
  // 2. Check Attribute
  else
  begin
    Ctx := TRttiContext.Create;
    try
      RType := Ctx.GetType(T);
      if RType <> nil then
      begin
        for var Attr in RType.GetAttributes do
        begin
          if Attr is SoftDeleteAttribute then
          begin
            SoftDeleteAttr := SoftDeleteAttribute(Attr);
            IsSoftDelete := True;
            PropName := SoftDeleteAttr.ColumnName;
            DeletedVal := SoftDeleteAttr.DeletedValue;
            Break;
          end;
        end;
      end;
    finally
      Ctx.Free;
    end;
  end;
  
  if IsSoftDelete then
  begin
    // Soft Delete: UPDATE entity to mark as deleted
    Ctx := TRttiContext.Create;
    try
      RType := Ctx.GetType(T);
      if RType <> nil then
      begin
        // Find the soft delete column property
        Prop := nil;
        ColumnName := PropName; // Use PropName as search key
        
        for var P in RType.GetProperties do
        begin
          // Check match by Property Name
          if SameText(P.Name, ColumnName) then
          begin
            Prop := P;
            Break;
          end;

          // Check match by Column Name (Only relevant if PropName was actually a Column Name from Attribute)
          for var Attr in P.GetAttributes do
          begin
            if Attr is ColumnAttribute then
            begin
               if SameText(ColumnAttribute(Attr).Name, ColumnName) then
               begin
                 Prop := P;
                 Break;
               end;
            end;
          end;
          if Prop <> nil then Break;
        end;
        
        if Prop <> nil then
        begin
          // Set the soft delete value
          var ValToSet: TValue;
          
          if Prop.PropertyType.Handle = TypeInfo(Boolean) then
            ValToSet := TValue.From(Boolean(DeletedVal))
          else 
            ValToSet := TValue.FromVariant(DeletedVal);
            
          Prop.SetValue(AEntity, ValToSet);
          
          // Use PersistUpdate to save the change
          PersistUpdate(AEntity);
          
          // Remove from identity map (entity is "deleted" from context perspective)
          var Key := GetEntityId(T(AEntity));
          if FIdentityMap.ContainsKey(Key) then
            FIdentityMap.Remove(Key)
          else
            AEntity.Free;
          Exit;
        end;
      end;
    finally
      Ctx.Free;
    end;
  end;
  
  // Hard Delete: Physical DELETE from database
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
  try
    Sql := Generator.GenerateDelete(T(AEntity));
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;
    for var Pair in Generator.Params do
      Cmd.AddParam(Pair.Key, Pair.Value);
    Cmd.ExecuteNonQuery;
    FIdentityMap.Remove(GetEntityId(T(AEntity)));
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

procedure TDbSet<T>.DetachAll;
var
  Key: string;
  Keys: TArray<string>;
begin
  Keys := FIdentityMap.Keys.ToArray;
  for Key in Keys do
    FIdentityMap.ExtractPair(Key);
end;

function TDbSet<T>.ListObjects(const AExpression: IExpression): IList<TObject>;
var
  TypedList: IList<T>;
  Item: T;
  Obj: TObject;
begin
  Result := TCollections.CreateList<TObject>;
  TypedList := List(AExpression);
  for Item in TypedList do
  begin
    Obj := TObject(Item);
    Result.Add(Obj);
  end;
end;


function TDbSet<T>.List: IList<T>;
begin
  Result := List(ISpecification<T>(nil));
end;

function TDbSet<T>.List(const AExpression: IExpression): IList<T>;
var
  Spec: ISpecification<T>;
begin
  Spec := TSpecification<T>.Create(AExpression);
  Result := List(Spec);
end;

function TDbSet<T>.List(const ASpec: ISpecification<T>): IList<T>;
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Reader: IDbReader;
  Cmd: IDbCommand;
  Entity: T;
  IsProjection: Boolean;
  Tracking: Boolean;
begin
  IsProjection := (ASpec <> nil) and (Length(ASpec.GetSelectedColumns) > 0);
  
  // Tracking defaults to True
  // If Spec is provided, respect its setting
  if ASpec <> nil then
    Tracking := ASpec.IsTrackingEnabled
  else
    Tracking := True;

  // Projections FORCE tracking off regardless of Spec setting
  if IsProjection then
    Tracking := False;

  if PTypeInfo(TypeInfo(T)).Kind = tkClass then
    Result := TCollections.CreateObjectList<T>(not Tracking)
  else
    Result := TCollections.CreateList<T>;

  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
  Generator.IgnoreQueryFilters := FIgnoreQueryFilters;
  Generator.OnlyDeleted := FOnlyDeleted;
  try
    if ASpec <> nil then
      Sql := Generator.GenerateSelect(ASpec)
    else
      Sql := Generator.GenerateSelect;
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;
    for var Pair in Generator.Params do
      Cmd.AddParam(Pair.Key, Pair.Value);
    
    Reader := Cmd.ExecuteQuery;
    while Reader.Next do
    begin
      Entity := Hydrate(Reader, Tracking);
      Result.Add(Entity);
    end;

    if (ASpec <> nil) and (Length(ASpec.GetIncludes) > 0) then
      DoLoadIncludes(Result, ASpec.GetIncludes);
  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.ExtractForeignKeys(const AEntities: IList<T>; PropertyToCheck: string;
  out IDs: TList<TValue>; out FKMap: TDictionary<T, TValue>);
var
  Ent: T;
  Val: TValue;
  Ctx: TRttiContext;
  Typ: TRttiType;
begin
  IDs := TList<TValue>.Create;
  FKMap := TDictionary<T, TValue>.Create;
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  var NavProp := Typ.GetProperty(PropertyToCheck);
  if NavProp = nil then Exit;
  var FoundFK := '';
  var FKAttr := NavProp.GetAttribute<ForeignKeyAttribute>;
  if FKAttr <> nil then
  begin
    for var Pair in FColumns do
    begin
      if SameText(Pair.Value, FKAttr.ColumnName) then
      begin
        FoundFK := Pair.Key;
        Break;
      end;
    end;
  end;
  if FoundFK = '' then
    FoundFK := PropertyToCheck + 'Id';
  var FKProp := Typ.GetProperty(FoundFK);
  if FKProp = nil then Exit;
  for Ent in AEntities do
  begin
    Val := FKProp.GetValue(Pointer(Ent));
    if TryUnwrapAndValidateFK(Val, Ctx) then
    begin
      if not IDs.Contains(Val) then
        IDs.Add(Val);
      FKMap.Add(Ent, Val);
    end;
  end;
end;

procedure TDbSet<T>.LoadAndAssign(const AEntities: IList<T>; const NavPropName: string);
var
  IDs: TList<TValue>;
  FKMap: TDictionary<T, TValue>;
  TargetType: TRttiType;
  TargetDbSet: IDbSet;
  LoadedMap: TDictionary<TValue, TObject>;
  NavProp: TRttiProperty;
  TargetList: IList<TObject>;
  Obj: TObject;
begin
  IDs := nil;
  FKMap := nil;
  LoadedMap := nil;
  try
    ExtractForeignKeys(AEntities, NavPropName, IDs, FKMap);
    if (IDs = nil) or (IDs.Count = 0) then Exit;
    NavProp := FRttiContext.GetType(T).GetProperty(NavPropName);
    if NavProp = nil then Exit;
    TargetType := NavProp.PropertyType;
    if TargetType.TypeKind <> tkClass then Exit;
    TargetDbSet := FContext.DataSet(TargetType.Handle);

    var IdStrings: TArray<string>;
    SetLength(IdStrings, IDs.Count);
    for var k := 0 to IDs.Count - 1 do
      IdStrings[k] := IDs[k].ToString;

    // FIX: Commented out expression logic to verify compilation
    var Expr: IExpression := TPropExpression.Create('Id').&In(IdStrings);

    TargetList := TargetDbSet.ListObjects(Expr);
    LoadedMap := TDictionary<TValue, TObject>.Create;
    for Obj in TargetList do
    begin
      var TargetRefId := TargetDbSet.GetEntityId(Obj);
      LoadedMap.AddOrSetValue(TargetRefId, Obj);
    end;
    for var Pair in FKMap do
    begin
      var Parent := Pair.Key;
      var FkVal := Pair.Value.ToString;
      if LoadedMap.ContainsKey(FkVal) then
      begin
        NavProp.SetValue(Pointer(Parent), LoadedMap[FkVal]);
      end;
    end;
  finally
    IDs.Free;
    FKMap.Free;
    LoadedMap.Free;
  end;
end;

procedure TDbSet<T>.DoLoadIncludes(const AEntities: IList<T>; const AIncludes: TArray<string>);
begin
  if (AEntities = nil) or (AEntities.Count = 0) then Exit;
  for var IncludePath in AIncludes do
    LoadAndAssign(AEntities, IncludePath);
end;

function TDbSet<T>.Find(const AId: Variant): T;
var
  L: IList<T>;
  VariantArray: TArray<Variant>;
  i: Integer;
begin
  // Check if AId is a VarArray (composite key)
  if VarIsArray(AId) then
  begin
    // Convert VarArray to array of Variant
    SetLength(VariantArray, VarArrayHighBound(AId, 1) - VarArrayLowBound(AId, 1) + 1);
    for i := 0 to High(VariantArray) do
      VariantArray[i] := AId[VarArrayLowBound(AId, 1) + i];
    
    // Call the array overload
    Result := Find(VariantArray);
    Exit;
  end;

  // Single key lookup
  // TODO : Get real mapping id column name
  var Expr: IExpression := TPropExpression.Create('Id') = TValue.FromVariant(AId);
  var Spec: ISpecification<T> := TSpecification<T>.Create(Expr);
  L := List(Spec);
  if L.Count > 0 then
  begin
    Result := L[0];
    (L as TSmartList<T>).Extract(Result);
  end
  else
    Result := nil;
end;

function TDbSet<T>.Find(const AId: array of Variant): T;
var
  L: IList<T>;
  Expr: IExpression;
  i: Integer;
  PropName: string;
begin
  if Length(AId) = 1 then
  begin
    Result := Find(AId[0]);
    Exit;
  end;

  // Validate that we have the correct number of keys
  if Length(AId) <> FPKColumns.Count then
    raise Exception.CreateFmt('Expected %d key values but got %d', [FPKColumns.Count, Length(AId)]);

  // Build composite key expression: (Col1 = Val1) AND (Col2 = Val2) AND ...
  Expr := nil;
  for i := 0 to FPKColumns.Count - 1 do
  begin
    // Find the property name for this PK column
    PropName := '';
    for var Pair in FColumns do
    begin
      if SameText(Pair.Value, FPKColumns[i]) then
      begin
        PropName := Pair.Key;
        Break;
      end;
    end;

    // If we couldn't find the property name, use the column name as fallback
    if PropName = '' then
      PropName := FPKColumns[i];

    // Create the equality expression for this key component
    var KeyExpr: IExpression := TBinaryExpression.Create(PropName, boEqual, TValue.FromVariant(AId[i]));

    // Combine with AND
    if Expr = nil then
      Expr := KeyExpr
    else
      Expr := TLogicalExpression.Create(Expr, KeyExpr, loAnd);
  end;

  // Execute the query
  var Spec: ISpecification<T> := TSpecification<T>.Create(Expr);
  L := List(Spec);
  
  if L.Count > 0 then
    Result := L[0]
  else
    Result := nil;
end;

function TDbSet<T>.Find(const AId: array of Integer): T;
var
  VarArray: TArray<Variant>;
  i: Integer;
begin
  SetLength(VarArray, Length(AId));
  for i := 0 to High(AId) do
    VarArray[i] := AId[i];
  Result := Find(VarArray);
end;

function TDbSet<T>.Query(const ASpec: ISpecification<T>): TFluentQuery<T>;
var
  LSelf: IDbSet<T>; 
  LSpec: ISpecification<T>;
begin
  LSpec := ASpec;
  LSelf := Self; 
  Result := TFluentQuery<T>.Create(
    function: TQueryIterator<T>
    begin
      Result := TSpecificationQueryIterator<T>.Create(
        function: IList<T>
        begin
          Result := LSelf.List(LSpec);
        end);
    end,
    LSpec); // Pass the spec reference to allow mutation via Fluent API
end;

function TDbSet<T>.Query(const AExpression: IExpression): TFluentQuery<T>;
var
  Spec: ISpecification<T>;
begin
  Spec := TSpecification<T>.Create(AExpression);
  Result := Query(Spec);
end;

function TDbSet<T>.QueryAll: TFluentQuery<T>;
var
  Spec: ISpecification<T>;
begin
  // Create spec explicitly and assign to interface variable to ensure correct ref counting
  Spec := TSpecification<T>.Create;
  Result := Query(Spec);
end;

function TDbSet<T>.AsNoTracking: TFluentQuery<T>;
begin
  Result := QueryAll.AsNoTracking;
end;

function TDbSet<T>.FirstOrDefault(const AExpression: IExpression): T;
var
  L: IList<T>;
  Spec: ISpecification<T>;
begin
  Spec := TSpecification<T>.Create(AExpression);
  Spec.Take(1);
  L := List(Spec);
  if L.Count > 0 then
    Result := L[0]
  else
    Result := nil;
end;

function TDbSet<T>.Any(const AExpression: IExpression): Boolean;
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
begin
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
  Generator.IgnoreQueryFilters := FIgnoreQueryFilters;
  Generator.OnlyDeleted := FOnlyDeleted;
  try
    var Spec: ISpecification<T> := TSpecification<T>.Create(AExpression);
    Spec.Take(1);
    
    Sql := Generator.GenerateSelect(Spec); 
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;
    for var Pair in Generator.Params do Cmd.AddParam(Pair.Key, Pair.Value);
    
    var Reader := Cmd.ExecuteQuery;
    Result := Reader.Next;
  finally
    Generator.Free;
  end;
end;

function TDbSet<T>.Count(const AExpression: IExpression): Integer;
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
begin
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
  Generator.IgnoreQueryFilters := FIgnoreQueryFilters;
  Generator.OnlyDeleted := FOnlyDeleted;
  try
    var Spec: ISpecification<T> := TSpecification<T>.Create(AExpression);
    Sql := Generator.GenerateCount(Spec);
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;
    for var Pair in Generator.Params do Cmd.AddParam(Pair.Key, Pair.Value);
    var Val := Cmd.ExecuteScalar;
    Result := Val.AsInteger;
  finally
    Generator.Free;
  end;
end;

function TDbSet<T>.IgnoreQueryFilters: IDbSet<T>;
begin
  FIgnoreQueryFilters := True;
  Result := Self;
end;

function TDbSet<T>.OnlyDeleted: IDbSet<T>;
begin
  FOnlyDeleted := True;
  Result := Self;
end;

procedure TDbSet<T>.HardDelete(const AEntity: T);
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
begin
  Generator := TSqlGenerator<T>.Create(FContext.Dialect, FMap);
  try
    Sql := Generator.GenerateDelete(AEntity);
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;
    for var Pair in Generator.Params do
      Cmd.AddParam(Pair.Key, Pair.Value);
    Cmd.ExecuteNonQuery;
    FIdentityMap.Remove(GetEntityId(AEntity));
  finally
    Generator.Free;
  end;
end;

procedure TDbSet<T>.Restore(const AEntity: T);
var
  Ctx: TRttiContext;
  RType: TRttiType;
  SoftDeleteAttr: SoftDeleteAttribute;
  Prop: TRttiProperty;
  ColumnName: string;
  IsSoftDelete: Boolean;
  PropName: string;
  NotDeletedVal: Variant;
begin
  IsSoftDelete := False;
  PropName := '';
  
  // 1. Check Fluent Mapping
  if (FMap <> nil) and FMap.IsSoftDelete then
  begin
    IsSoftDelete := True;
    PropName := FMap.SoftDeleteProp;
    NotDeletedVal := FMap.SoftDeleteNotDeletedValue;
  end
  // 2. Check Attribute
  else
  begin
    Ctx := TRttiContext.Create;
    try
      RType := Ctx.GetType(T);
      if RType <> nil then
      begin
        for var Attr in RType.GetAttributes do
        begin
          if Attr is SoftDeleteAttribute then
          begin
            SoftDeleteAttr := SoftDeleteAttribute(Attr);
            IsSoftDelete := True;
            PropName := SoftDeleteAttr.ColumnName;
            NotDeletedVal := SoftDeleteAttr.NotDeletedValue;
            Break;
          end;
        end;
      end;
    finally
      Ctx.Free;
    end;
  end;
  
  if IsSoftDelete then
  begin
    Ctx := TRttiContext.Create;
    try
      RType := Ctx.GetType(T);
      if RType <> nil then
      begin
        // Find the soft delete column property
        Prop := nil;
        ColumnName := PropName;
        
        for var P in RType.GetProperties do
        begin
           if SameText(P.Name, ColumnName) then
           begin
             Prop := P;
             Break;
           end;
           
           for var Attr in P.GetAttributes do
           begin
             if Attr is ColumnAttribute then
             begin
               if SameText(ColumnAttribute(Attr).Name, ColumnName) then
               begin
                 Prop := P;
                 Break;
               end;
             end;
           end;
           if Prop <> nil then Break;
        end;
        
        if Prop <> nil then
        begin
          var ValToSet: TValue;
          
          if Prop.PropertyType.Handle = TypeInfo(Boolean) then
            ValToSet := TValue.From(Boolean(NotDeletedVal))
          else 
            ValToSet := TValue.FromVariant(NotDeletedVal);

          Prop.SetValue(TObject(AEntity), ValToSet);
          PersistUpdate(AEntity);
        end;
      end;
    finally
      Ctx.Free;
    end;
  end;
end;

end.

