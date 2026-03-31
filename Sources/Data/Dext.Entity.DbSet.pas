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
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Collections,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  System.Variants,
  Dext.Core.Reflection,
  Dext.Core.Activator,
  Dext.Core.ValueConverters,
  Dext.Entity.TypeSystem,
  Dext.Entity.Attributes,
  Dext.Entity.Core,
  Dext.Entity.Dialects,
  Dext.Entity.Mapping,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Query,
  Dext.Core.SmartTypes,
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces,
  Dext.Specifications.SQL.Generator,
  Dext.Specifications.Types,
  Dext.Entity.TypeConverters,
  Dext.Entity.Prototype,
  Dext.Types.Nullable,
  Dext.Types.UUID,
  Dext.MultiTenancy,
  Dext.Entity.Tenancy,
  Dext.Entity.Collections,
  Dext.Entity.LazyLoading,
  Dext.Threading.Async;

// Helper function to convert TValue to string for identity map keys
// TValue.ToString does not work correctly for TGUID (returns type name, not value)
function TValueToKeyString(const AValue: TValue): string;

// Forward declarations: generic TDbSet<T> methods may only reference symbols
// declared in the interface (E2506 if these were implementation-only).
function DbSetHydratePropertyTypeLabel(const APropType: TRttiType): string;
function DbSetHydrateTValueKindStr(const AVal: TValue): string;
function DbSetHydrateIncomingTValueLabel(const AVal: TValue): string;

type
  TDbSet<T: class> = class(TInterfacedObject, IDbSet<T>, IDbSet)
  private
    FContextPtr: Pointer;
    FRttiContext: TRttiContext; 
    FTableName: string;
    FPKColumns: IList<string>; 
    FProps: IDictionary<string, TRttiProperty>; 
    FFields: IDictionary<string, TRttiField>; 
    FColumns: IDictionary<string, string>;      
    FIdentityMap: IDictionary<string, T>; 
    FOrphans: IList<T>; // Stores detached objects until DbSet is destroyed
    FMap: TEntityMap;
    // Filters control
    FIgnoreQueryFilters: Boolean;
    FOnlyDeleted: Boolean;



    procedure MapEntity;
    function Hydrate(const Reader: IDbReader; const Tracking: Boolean = True): T;
    procedure HydrateTarget(const Reader: IDbReader; Target: T);
    procedure ExtractForeignKeys(const AEntities: IList<T>; PropertyToCheck: string;
      out IDs: IList<TValue>; out FKMap: IDictionary<T, TValue>);
    procedure LoadAndAssign(const AEntities: IList<T>; const NavPropName: string);
    procedure LoadManyToMany(const AEntities: IList<T>; const NavPropName: string; const PropMap: TPropertyMap);
    procedure LoadOneToMany(const AEntities: IList<T>; const NavPropName: string; const PropMap: TPropertyMap);
    function CreateGenerator: TSqlGenerator<T>;
    procedure ResetQueryFlags;
    procedure HandleTimestamps(const AEntity: TObject; AIsInsert: Boolean);
  protected
    function GetEntityId(const AEntity: T): string; overload;
    function GetEntityId(const AEntity: TObject): string; overload;
    function GetPKColumns: TArray<string>;
    function GetRelatedId(const AObject: TObject): TValue;
    procedure DoLoadIncludes(const AEntities: IList<T>; const AIncludes: TArray<string>);
    function GetItem(Index: Integer): T;
    
    procedure ApplyTenantFilter(var ASpec: ISpecification<T>);
  public
    constructor Create(const AContext: IDbContext); reintroduce;
    destructor Destroy; override;

    function GetFContext: IDbContext;
    property FContext: IDbContext read GetFContext;

    function GetTableName: string;
    function GetEntityType: PTypeInfo;
    function FindObject(const AId: Variant): TObject; overload;
    function FindObject(const AId: Integer): TObject; overload;
    function Add(const AEntity: TObject): IDbSet; overload;
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
    procedure LinkManyToMany(const AEntity: TObject; const APropertyName: string; const ARelatedEntity: TObject); overload;
    procedure UnlinkManyToMany(const AEntity: TObject; const APropertyName: string; const ARelatedEntity: TObject); overload;
    
    function Add(const AEntity: T): IDbSet<T>; overload;
    function Add(const ABuilder: TFunc<IEntityBuilder<T>, T>): IDbSet<T>; overload;
    function Update(const AEntity: T): IDbSet<T>; overload;
    function Remove(const AEntity: T): IDbSet<T>; overload;
    function Detach(const AEntity: T): IDbSet<T>; overload;
    function Find(const AId: Variant): T; overload;
    function Find(const AId: Integer): T; overload;
    function Find(const AId: array of Integer): T; overload;
    function Find(const AId: array of Variant): T; overload;

    procedure AddRange(const AEntities: TArray<T>); overload;
    procedure AddRange(const AEntities: IEnumerable<T>); overload;

    procedure UpdateRange(const AEntities: TArray<T>); overload;
    procedure UpdateRange(const AEntities: IEnumerable<T>); overload;

    procedure RemoveRange(const AEntities: TArray<T>); overload;
    procedure RemoveRange(const AEntities: IEnumerable<T>); overload;

    function ToList: IList<T>; overload;
    function ToList(const ASpec: ISpecification<T>): IList<T>; overload;

    function ToList(const AExpression: IExpression): IList<T>; overload;
    function FirstOrDefault(const AExpression: IExpression): T; overload;
    function FirstOrDefault(const ASpec: ISpecification<T>): T; overload;
    function Any(const AExpression: IExpression): Boolean; overload;
    function Any(const ASpec: ISpecification<T>): Boolean; overload;
    function Count(const AExpression: IExpression): Integer; overload;
    function Count(const ASpec: ISpecification<T>): Integer; overload;
    
    // Smart Properties Support
    function Where(const APredicate: TQueryPredicate<T>): TFluentQuery<T>; overload;
    function Where(const AValue: BooleanExpression): TFluentQuery<T>; overload;
    function Where(const AExpression: TFluentExpression): TFluentQuery<T>; overload;
    function Where(const AExpression: IExpression): TFluentQuery<T>; overload;

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
    function HardDelete(const AEntity: T): IDbSet<T>;
    function Restore(const AEntity: T): IDbSet<T>;

    property Items[Index: Integer]: T read GetItem; default;
    
    /// <summary>
    ///   Returns a prototype entity of type T for building query expressions.
    ///   The prototype lifecycle is managed by this DbSet.
    /// </summary>
    function Prototype: T; overload;
    
    /// <summary>
    ///   Returns a prototype entity of any type for building query expressions (for Joins).
    ///   The prototype lifecycle is managed by this DbSet.
    /// </summary>
    function Prototype<TEntity: class>: TEntity; overload;
    
    /// <summary>
    ///   Links two entities in a Many-to-Many relationship.
    /// </summary>
    procedure LinkManyToMany(const AEntity: T; const APropertyName: string; const ARelatedEntity: TObject); overload;
    
    /// <summary>
    ///   Unlinks two entities in a Many-to-Many relationship.
    /// </summary>
    procedure UnlinkManyToMany(const AEntity: T; const APropertyName: string; const ARelatedEntity: TObject); overload;
    
    /// <summary>
    ///   Syncronizes a Many-to-Many relationship, replacing all existing links with new ones.
    /// </summary>
    procedure SyncManyToMany(const AEntity: T; const APropertyName: string; const ARelatedEntities: TArray<TObject>);
    
    // New Methods Implementation
    function ToListAsync: TAsyncBuilder<IList<T>>;
    function FromSql(const ASql: string; const AParams: array of TValue): TFluentQuery<T>; overload;
    function FromSql(const ASql: string): TFluentQuery<T>; overload;
    function TryLock(const AEntity: T; const AToken: string; ADurationMinutes: Integer = 30): Boolean;
    function Unlock(const AEntity: T): Boolean;
    
    /// <summary>
    ///   Returns a streaming iterator that reuses a single object instance (Flyweight pattern).
    ///   Perfect for high-performance view rendering.
    /// </summary>
    function RequestStreamingIterator(const ASpec: ISpecification<T>): IEnumerator<T>;
    
    class constructor Create;
  end;

  TDynamicDbSetFactory<T: class> = class(TInterfacedObject, IDynamicDbSetFactory)
  public
    function CreateDbSet(const AContext: IInterface): IInterface;
  end;



function TValueToVariant(const AValue: TValue): Variant;

type
  TSqlQueryIterator<T: class> = class(TQueryIterator<T>)
  private
    FDbSet: TDbSet<T>;
    FSql: string;
    FParams: TArray<TValue>;
    FReader: IDbReader;
    FInitialized: Boolean;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(ADbSet: TDbSet<T>; const ASql: string; const AParams: array of TValue);
  end;

  /// <summary>
  ///   High-performance "Flyweight" iterator that reuses a single object instance
  ///   during iteration. Optimized for SSR (Server-Side Rendering).
  /// </summary>
  TStreamingViewIterator<T: class> = class(TQueryIterator<T>)
  private
    FDbSet: TDbSet<T>;
    FReader: IDbReader;
    FIteratorObject: T;
    FInitialized: Boolean;
    FSpec: ISpecification<T>;
  protected
    function MoveNextCore: Boolean; override;
  public
    constructor Create(ADbSet: TDbSet<T>; const ASpec: ISpecification<T>);
    destructor Destroy; override;
  end;


implementation

uses
  Data.DB,
  Dext.Entity.ProxyFactory,
  Dext.Utils;

function TValueToKeyString(const AValue: TValue): string;
var
  V: Variant;
begin
  if AValue.IsEmpty then
    Exit('');

  // Use the robust Variant conversion which handles Prop<T> and TGUID
  V := TValueToVariant(AValue);
  if VarIsNull(V) or VarIsEmpty(V) then
    Exit('');
    
  Result := VarToStr(V);
  
  // Normalize GUIDs to lowercase matches for consistency
  if Result.StartsWith('{') and (Length(Result) = 38) then
    Result := LowerCase(Result);
end;

function DbSetHydratePropertyTypeLabel(const APropType: TRttiType): string;
begin
  if APropType = nil then
    Exit('(nil)');
  Result := APropType.QualifiedName;
  if Result = '' then
    Result := APropType.Name;
end;

function DbSetHydrateTValueKindStr(const AVal: TValue): string;
begin
  case AVal.Kind of
    tkUnknown: Result := 'tkUnknown';
    tkInteger: Result := 'tkInteger';
    tkInt64: Result := 'tkInt64';
    tkEnumeration: Result := 'tkEnumeration';
    tkFloat: Result := 'tkFloat';
    tkString: Result := 'tkString';
    tkLString: Result := 'tkLString';
    tkWString: Result := 'tkWString';
    tkUString: Result := 'tkUString';
    tkClass: Result := 'tkClass';
    tkInterface: Result := 'tkInterface';
    tkDynArray: Result := 'tkDynArray';
    tkArray: Result := 'tkArray';
    tkRecord: Result := 'tkRecord';
    tkVariant: Result := 'tkVariant';
  else
    Result := Format('KindOrdinal=%d', [Ord(AVal.Kind)]);
  end;
end;

function DbSetHydrateIncomingTValueLabel(const AVal: TValue): string;
begin
  if AVal.IsEmpty then
    Exit('empty');
  if AVal.TypeInfo <> nil then
    Exit(Format('%s [kind=%s]', [string(AVal.TypeInfo.Name), DbSetHydrateTValueKindStr(AVal)]))
  else
    Exit(Format('[kind=%s]', [DbSetHydrateTValueKindStr(AVal)]));
end;

function TValueToVariant(const AValue: TValue): Variant;
var
  Unwrapped: TValue;
  VTypeName: string;
begin
  if AValue.TypeInfo <> nil then VTypeName := string(AValue.TypeInfo.Name) else VTypeName := 'nil';
  
  if AValue.IsEmpty or ((AValue.Kind = tkUnknown) and (AValue.TypeInfo = nil)) then
    Exit(Null);

  // Use the central reflection utility to unwrap Prop<T>, Nullable<T> and variants
  if TReflection.TryUnwrapProp(AValue, Unwrapped) then
  begin
     // ONLY recurse if the TypeInfo pointer changed 
     if (Unwrapped.TypeInfo <> AValue.TypeInfo) then
        Exit(TValueToVariant(Unwrapped))
     else
        Exit(Unwrapped.AsVariant);
  end;

  if (AValue.Kind = tkVariant) then
    Exit(AValue.AsVariant);

  // Handle explicit types that don't convert to Variant automatically
  if (AValue.Kind = tkRecord) and (AValue.TypeInfo <> nil) then
  begin
    var TypeName := string(AValue.TypeInfo.Name);

    if TypeName = 'TGUID' then 
    begin
      var G: TGUID;
      AValue.ExtractRawData(@G);
      Exit(GUIDToString(G));
    end;

    if TypeName = 'TUUID' then
      Exit(AValue.AsType<TUUID>.ToString);
  end;
  
  // Fallback to variant conversion
  try
    Result := AValue.AsVariant;
  except
    on E: Exception do
      Result := AValue.ToString;
  end;
end;





{ TSqlQueryIterator<T> }

constructor TSqlQueryIterator<T>.Create(ADbSet: TDbSet<T>; const ASql: string; const AParams: array of TValue);
var
  I: Integer;
begin
  inherited Create;
  FDbSet := ADbSet;
  FSql := ASql;
  SetLength(FParams, Length(AParams));
  for I := 0 to Length(AParams) - 1 do
    FParams[I] := AParams[I];
end;

function TSqlQueryIterator<T>.MoveNextCore: Boolean;
var
  Cmd: IDbCommand;
  i: Integer;
begin
  if not FInitialized then
  begin
    Cmd := FDbSet.FContext.Connection.CreateCommand(FSql);
    for i := 0 to Length(FParams) - 1 do
      Cmd.AddParam('p' + IntToStr(i), FParams[i]);
      
    FReader := Cmd.ExecuteQuery;
    FInitialized := True;
  end;
  
  if FReader.Next then
  begin
    FCurrent := FDbSet.Hydrate(FReader, False); // Default to NoTracking for raw SQL for now
    Result := True;
  end
  else
    Result := False;
end;

{ TStreamingViewIterator<T> }

constructor TStreamingViewIterator<T>.Create(ADbSet: TDbSet<T>; const ASpec: ISpecification<T>);
begin
  inherited Create;
  FDbSet := ADbSet;
  FSpec := ASpec;
  // Create the single shared instance for this iterator
  FIteratorObject := TEntityProxyFactory.CreateInstance<T>(FDbSet.FContext);
  FCurrent := FIteratorObject;
end;

destructor TStreamingViewIterator<T>.Destroy;
begin
  FReader := nil;
  // Shared object is managed by the iterator
  FIteratorObject.Free;
  inherited;
end;

function TStreamingViewIterator<T>.MoveNextCore: Boolean;
var
  Gen: TSqlGenerator<T>;
  Cmd: IDbCommand;
  SQL: string;
  LParamPair: TPair<string, TValue>;
begin
  if not FInitialized then
  begin
    Gen := FDbSet.CreateGenerator;
    try
      SQL := Gen.GenerateSelect(FSpec);
      Cmd := FDbSet.FContext.Connection.CreateCommand(SQL);
      
      for LParamPair in Gen.Params do
      begin
        var ParamType: TFieldType;
        if Gen.ParamTypes.TryGetValue(LParamPair.Key, ParamType) then
          Cmd.AddParam(LParamPair.Key, LParamPair.Value, ParamType)
        else
          Cmd.AddParam(LParamPair.Key, LParamPair.Value);
      end;
        
      FReader := Cmd.ExecuteQuery;
    finally
      Gen.Free;
    end;
    FInitialized := True;
  end;
  
  if FReader.Next then
  begin
    FDbSet.HydrateTarget(FReader, FIteratorObject);
    Result := True;
  end
  else
    Result := False;
end;

{ TDbSet<T> }

class constructor TDbSet<T>.Create;
begin
  TModelBuilder.Instance.RegisterFactory(TypeInfo(T), TDynamicDbSetFactory<T>.Create);
end;

function TDbSet<T>.GetFContext: IDbContext;

begin
  Result := IDbContext(FContextPtr);
end;

constructor TDbSet<T>.Create(const AContext: IDbContext);
begin
  inherited Create;
  FContextPtr := Pointer(AContext);
  FProps := TCollections.CreateDictionary<string, TRttiProperty>;
  FFields := TCollections.CreateDictionary<string, TRttiField>;
  FColumns := TCollections.CreateDictionary<string, string>;
  FPKColumns := TCollections.CreateList<string>;
  FRttiContext := TRttiContext.Create;
  FIdentityMap := TCollections.CreateDictionary<string, T>(True);
  FOrphans := TCollections.CreateList<T>(True);
  FIgnoreQueryFilters := False;
  FOnlyDeleted := False;
  MapEntity;
end;

destructor TDbSet<T>.Destroy;
begin
  FRttiContext.Free;
  FIdentityMap := nil;
  FOrphans := nil;
  FProps := nil;
  FFields := nil;
  FColumns := nil;
  FPKColumns := nil;
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
  Field: TRttiField; // Added for field mapping discovery
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
        if TableAttribute(Attr).Name <> '' then
          FTableName := TableAttribute(Attr).Name;
  end;
  
  // Property-based Naming Discovery fallback
  if FTableName = '' then
    FTableName := TModelBuilder.Instance.GetDiscoveryName(TypeInfo(T));

  // Final fallback: Use naming strategy to derive from class name
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
          if PropMap.IsNavigation and not PropMap.IsJsonColumn then IsMapped := False;
        end;
      end;

      // Auto-detection fallback for classes/interfaces (Relationship by convention)
      if IsMapped and (PropMap = nil) and (Prop.PropertyType.TypeKind in [tkClass, tkInterface]) then
        IsMapped := False;

      for Attr in Prop.GetAttributes do
      begin
        if Attr is NotMappedAttribute then IsMapped := False;

        // Attributes like [HasMany], [BelongsTo] explicitly mark it as not a simple column
        if (Attr is HasManyAttribute) or (Attr is BelongsToAttribute) or 
           (Attr is HasOneAttribute) or (Attr is ManyToManyAttribute) then
          IsMapped := False;

        // [JsonColumn] always forces mapping as a simple column
        if Attr is JsonColumnAttribute then IsMapped := True;

        // [Nested] allows mapping classes as nested objects (multi-mapping)
        if Attr is NestedAttribute then IsMapped := True;
      end;
      
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
        if Attr is PrimaryKeyAttribute then
          if not FPKColumns.Contains(ColName) then
            FPKColumns.Add(ColName);
      end;
    end;

    // Navigation properties (Lazy<T>) should not be hydrated from DB fields directly
    // They are handled by the Lazy Injector. We only add them to FColumns for SQL generation.
    if not Prop.PropertyType.Name.StartsWith('Lazy<') then
      FProps.Add(ColName.ToLower, Prop);
      
    FColumns.Add(Prop.Name, ColName);
    
    // Check for backing field mapping - either explicit from fluent mapping or auto-detect for Smart Types
    if (PropMap <> nil) and (PropMap.FieldName <> '') then
    begin
      Field := Typ.GetField(PropMap.FieldName);
      if Field <> nil then
        FFields.Add(ColName.ToLower, Field);
    end
    else
    begin
      // Auto-detect backing field for Smart Types (Prop<T>)
      // Convention: Property "Name" has backing field "FName"
      if (Prop.PropertyType.TypeKind = tkRecord) then
      begin
        var FieldName := TReflection.NormalizeFieldName(Prop.Name);
        Field := Typ.GetField(FieldName);
        if Field <> nil then
          FFields.Add(ColName.ToLower, Field);
      end;
    end;
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

function TDbSet<T>.CreateGenerator: TSqlGenerator<T>;
begin
  Result := TSqlGenerator<T>.Create(FContext, FMap);
  Result.NamingStrategy := FContext.NamingStrategy;
  Result.IgnoreQueryFilters := FIgnoreQueryFilters;
  Result.OnlyDeleted := FOnlyDeleted;
  
  if (FContext.GetTenantProvider <> nil) and (FContext.GetTenantProvider.Tenant <> nil) then
    Result.Schema := FContext.GetTenantProvider.Tenant.Schema;
end;

function TDbSet<T>.GetTableName: string;
begin
  Result := FContext.Dialect.QuoteIdentifier(FTableName);
  if (FContext.GetTenantProvider <> nil) and (FContext.GetTenantProvider.Tenant <> nil) then
  begin
    var Schema := FContext.GetTenantProvider.Tenant.Schema;
    if (Schema <> '') and FContext.Dialect.UseSchemaPrefix then
       Result := FContext.Dialect.QuoteIdentifier(Schema) + '.' + Result;
  end;
end;

function TDbSet<T>.GetEntityType: PTypeInfo;
begin
  Result := TypeInfo(T);
end;

function TDbSet<T>.GetPKColumns: TArray<string>;
begin
  Result := FPKColumns.ToArray;
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
    Result := GetSmartValue(Val, Prop.PropertyType.Name);
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
        SB.Append(GetSmartValue(Val, Prop.PropertyType.Name));
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
        if Attr is PrimaryKeyAttribute then
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
  PKVal: string;
begin
  PKVal := '';
  
  if FPKColumns.Count > 0 then
  begin
    var PKValues := TCollections.CreateDictionary<string, string>;
    try
      for var i := 0 to Reader.GetColumnCount - 1 do
      begin
        var ColName := Reader.GetColumnName(i);
        for var PKCol in FPKColumns do
        begin
          if SameText(PKCol, ColName) then
          begin
             PKValues.Add(PKCol, TValueToKeyString(Reader.GetValue(i))); 
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
          for var i := 0 to FPKColumns.Count - 1 do
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
      PKValues := nil;
    end;
  end;
  
  // Check IdentityMap
  if Tracking and (PKVal <> '') and FIdentityMap.TryGetValue(PKVal, Result) then
  begin
    TLazyInjector.Inject(FContext, Result);
    Exit;
  end;
  
  // Create new instance with Discriminator support
  if (FMap <> nil) and (FMap.InheritanceStrategy = TInheritanceStrategy.TablePerHierarchy) and 
     (FMap.DiscriminatorColumn <> '') then
  begin
     var DiscVal := Reader.GetValue(FMap.DiscriminatorColumn).AsVariant;
     var SubMap := FContext.ModelBuilder.FindMapByDiscriminator(TypeInfo(T), DiscVal);
     if (SubMap <> nil) and (SubMap.EntityType <> TypeInfo(T)) then
        Result := T(TActivator.CreateInstance(GetTypeData(SubMap.EntityType)^.ClassType, []))
     else
        Result := TEntityProxyFactory.CreateInstance<T>(FContext);
  end
  else
    Result := TEntityProxyFactory.CreateInstance<T>(FContext);

  try
    if Tracking and (PKVal <> '') then
      FIdentityMap.Add(PKVal, Result);
    
    HydrateTarget(Reader, Result);
  except
    on E: Exception do
    begin
      if not Tracking or (PKVal = '') then
        Result.Free;
      raise;
    end;
  end;
end;

procedure TDbSet<T>.HydrateTarget(const Reader: IDbReader; Target: T);
var
  i: Integer;
  ColName: string;
  Val: TValue;
  Prop: TRttiProperty;
  Field: TRttiField;
begin
  TLazyInjector.Inject(FContext, Target);
  
  for i := 0 to Reader.GetColumnCount - 1 do
  begin
    ColName := Reader.GetColumnName(i);
    Val := Reader.GetValue(i);
    
    if FProps.TryGetValue(ColName.ToLower, Prop) then
    begin
      try
        var Converter: ITypeConverter := nil;
        var PropMap: TPropertyMap := nil;
        
        if FMap <> nil then FMap.Properties.TryGetValue(Prop.Name, PropMap);
        if PropMap <> nil then Converter := PropMap.Converter;
        if Converter = nil then Converter := TTypeConverterRegistry.Instance.GetConverter(Prop.PropertyType.Handle);
        if (Converter = nil) and (PropMap <> nil) and PropMap.IsJsonColumn then
          Converter := TJsonConverter.Create(PropMap.UseJsonB);
          
        if Converter <> nil then
           Val := Converter.FromDatabase(Val, Prop.PropertyType.Handle);
        
        if FFields.TryGetValue(ColName.ToLower, Field) then
          TReflection.SetValue(Pointer(Target), Field, Val)
        else
          TReflection.SetValue(Pointer(Target), Prop, Val);
      except
        on E: Exception do
          raise Exception.CreateFmt(
            'Hydration failed: entity=%s | column="%s" | property="%s" | PropertyType=%s | TypeKind=%s | incomingTValue=%s | %s: %s',
            [Target.ClassName,
             ColName,
             Prop.Name,
             DbSetHydratePropertyTypeLabel(Prop.PropertyType),
             GetEnumName(TypeInfo(TTypeKind), Ord(Prop.PropertyType.TypeKind)),
             DbSetHydrateIncomingTValueLabel(Val),
             E.ClassName,
             E.Message]);
      end;
    end
    else
    begin
      // Multi-Mapping
      var SeparatorIdx := ColName.IndexOf('_');
      if SeparatorIdx < 0 then SeparatorIdx := ColName.IndexOf('.');
      
      if SeparatorIdx > 0 then
      begin
        var Prefix := ColName.Substring(0, SeparatorIdx);
        if FProps.TryGetValue(Prefix.ToLower, Prop) and (Prop.PropertyType.TypeKind = tkClass) then
           TReflection.SetValueByPath(TObject(Target), ColName, Val);
      end;
    end;
  end;
end;

function TDbSet<T>.FindObject(const AId: Variant): TObject;
begin
  Result := Find(AId);
end;

function TDbSet<T>.FindObject(const AId: Integer): TObject;
begin
  Result := Find(AId);
end;

function TDbSet<T>.Add(const AEntity: TObject): IDbSet;
begin
  Add(T(AEntity));
  Result := Self;
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

function TDbSet<T>.GetItem(Index: Integer): T;
begin
  Result := ToList[Index];
end;

function TDbSet<T>.Add(const AEntity: T): IDbSet<T>;
begin
  FContext.ChangeTracker.Track(AEntity, esAdded);
  Result := Self;
end;

function TDbSet<T>.Add(const ABuilder: TFunc<IEntityBuilder<T>, T>): IDbSet<T>;
begin
  if Assigned(ABuilder) then
    Add(ABuilder(TEntityType<T>.New));
  Result := Self;
end;

function TDbSet<T>.Update(const AEntity: T): IDbSet<T>;
begin
  FContext.ChangeTracker.Track(AEntity, esModified);
  Result := Self;
end;

function TDbSet<T>.Remove(const AEntity: T): IDbSet<T>;
begin
  FContext.ChangeTracker.Track(AEntity, esDeleted);
  Result := Self;
end;

function TDbSet<T>.Detach(const AEntity: T): IDbSet<T>;
var
  Id: string;
begin
  Id := GetEntityId(AEntity);
  if FIdentityMap.ContainsKey(Id) then
    FOrphans.Add(FIdentityMap.Extract(Id));
  FContext.ChangeTracker.Remove(AEntity);
  Result := Self;
end;

procedure TDbSet<T>.AddRange(const AEntities: TArray<T>);
var
  Entity: T;
begin
  for Entity in AEntities do
    Add(Entity);
end;

procedure TDbSet<T>.AddRange(const AEntities: IEnumerable<T>);
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

procedure TDbSet<T>.UpdateRange(const AEntities: IEnumerable<T>);
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

procedure TDbSet<T>.RemoveRange(const AEntities: IEnumerable<T>);
var
  Entity: T;
begin
  for Entity in AEntities do
    Remove(Entity);
end;

procedure TDbSet<T>.HandleTimestamps(const AEntity: TObject; AIsInsert: Boolean);
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  NowVal: TDateTime;
begin
  NowVal := Now;
  Ctx := TRttiContext.Create;
  try
    Typ := Ctx.GetType(T);
    for Prop in Typ.GetProperties do
    begin
      for Attr in Prop.GetAttributes do
      begin
        if (Attr is CreatedAtAttribute) and AIsInsert then
        begin
          TReflection.SetValue(Pointer(AEntity), Prop, NowVal);
        end
        else if (Attr is UpdatedAtAttribute) then
        begin
          TReflection.SetValue(Pointer(AEntity), Prop, NowVal);
        end;
      end;
    end;
  finally
    Ctx.Free;
  end;
end;

procedure TDbSet<T>.PersistAdd(const AEntity: TObject);
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
  Prop, AutoIncProp: TRttiProperty;
  PKVal: Variant;
  RawPKVal: TValue;
  UseReturning: Boolean;
  RetVal: TValue;
  AutoIncColumn: string;
  Ctx: TRttiContext;
  Typ: TRttiType;
  Attr: TCustomAttribute;
  PropMap: TPropertyMap;
begin
  HandleTimestamps(AEntity, True);
  Generator := CreateGenerator;
  try
    Sql := Generator.GenerateInsert(T(AEntity));
    // Find AutoInc property and column
    AutoIncColumn := '';
    AutoIncProp := nil;
    Ctx := TRttiContext.Create;
    try
      Typ := Ctx.GetType(T);
    
    for Prop in Typ.GetProperties do
    begin
      // Check Fluent Mapping first
      PropMap := nil;
      if FMap <> nil then
        FMap.Properties.TryGetValue(Prop.Name, PropMap);
        
      if (PropMap <> nil) and PropMap.IsAutoInc then
      begin
        AutoIncProp := Prop;
        if PropMap.ColumnName <> '' then
          AutoIncColumn := PropMap.ColumnName
        else
          AutoIncColumn := Prop.Name;
        Break;
      end;
      
      // Check Attribute
      for Attr in Prop.GetAttributes do
      begin
        if Attr is AutoIncAttribute then
        begin
          AutoIncProp := Prop;
          AutoIncColumn := Prop.Name;
          // Check for Column attribute
          for var ColAttr in Prop.GetAttributes do
            if ColAttr is ColumnAttribute then
              AutoIncColumn := ColumnAttribute(ColAttr).Name;
          Break;
        end;
      end;
      if AutoIncProp <> nil then Break;
    end;

    UseReturning := (AutoIncColumn <> '') and FContext.Dialect.SupportsInsertReturning;
    if UseReturning then
    begin
      var ReturningClause := FContext.Dialect.GetReturningSQL(AutoIncColumn);
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
    Cmd := FContext.Connection.CreateCommand(Sql);
    for var Pair in Generator.Params do
    begin
      var ParamType: TFieldType;
      if Generator.ParamTypes.TryGetValue(Pair.Key, ParamType) then
        Cmd.AddParam(Pair.Key, Pair.Value, ParamType)
      else
        Cmd.AddParam(Pair.Key, Pair.Value);
    end;
    if UseReturning then
    begin
      RetVal := Cmd.ExecuteScalar;
      RawPKVal := RetVal;
      // We no longer call RetVal.AsVariant because calling AsVariant on a TGUID Record TValue 
      // throws an EInvalidCast ('Invalid class typecast') natively in Delphi.
    end
    else
    begin
      Cmd.ExecuteNonQuery;
      if AutoIncColumn <> '' then
      begin
         var LastIdSQL := FContext.Dialect.GetLastInsertIdSQL;
         if LastIdSQL <> '' then
         begin
           var IdCmd := FContext.Connection.CreateCommand(LastIdSQL);
           var IdVal := IdCmd.ExecuteScalar;
           RawPKVal := IdVal;
         end
         else
         begin
           PKVal := FContext.Connection.GetLastInsertId;
           RawPKVal := TValue.FromVariant(PKVal);
         end;
      end;
    end;
     if (AutoIncProp <> nil) and (AutoIncColumn <> '') then
     begin
       if RawPKVal.IsEmpty and (VarIsNull(PKVal) or VarIsEmpty(PKVal)) then
         raise Exception.Create('Failed to retrieve AutoInc ID for ' + GetTableName + '.');
       
        // Convert raw value using specific type converters BEFORE Reflection assigns it
        var PKConvert := RawPKVal;
        var Converter := TTypeConverterRegistry.Instance.GetConverter(AutoIncProp.PropertyType.Handle);
        if Converter <> nil then
          PKConvert := Converter.FromDatabase(PKConvert, AutoIncProp.PropertyType.Handle);
          
        // Use centralized reflection helper that handles conversion and Smart Types accurately
        TReflection.SetValue(Pointer(AEntity), AutoIncProp, PKConvert);
      end;
     
     // Add to identity map using full entity ID
     var NewId := GetEntityId(T(AEntity)); 
     if not FIdentityMap.ContainsKey(NewId) then
       FIdentityMap.Add(NewId, T(AEntity));
    finally
      Ctx.Free;
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
  Props: IList<TPair<TRttiProperty, string>>;
  ParamValues: TArray<TValue>;
  Prop: TRttiProperty;
  ParamName: string;
  Val: TValue;
begin
  if Length(AEntities) = 0 then Exit;
  SetLength(EntitiesT, Length(AEntities));
  for i := 0 to High(AEntities) do
  begin
    EntitiesT[i] := T(AEntities[i]);
    HandleTimestamps(AEntities[i], True);
  end;
  Generator := CreateGenerator;
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
      Props := nil;
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
  HandleTimestamps(AEntity, False);
  Generator := CreateGenerator;
  try
    Sql := Generator.GenerateUpdate(T(AEntity));
    Cmd := FContext.Connection.CreateCommand(Sql);
    for var Pair in Generator.Params do
    begin
      var ParamType: TFieldType;
      if Generator.ParamTypes.TryGetValue(Pair.Key, ParamType) then
        Cmd.AddParam(Pair.Key, Pair.Value, ParamType)
      else
        Cmd.AddParam(Pair.Key, Pair.Value);
    end;
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
            TReflection.SetValue(Pointer(AEntity), Prop, NewVer);
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
            
          TReflection.SetValue(Pointer(AEntity), Prop, ValToSet);
          
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
  Generator := CreateGenerator;
  try
    Sql := Generator.GenerateDelete(T(AEntity));
    Cmd := FContext.Connection.CreateCommand(Sql);
    for var Pair in Generator.Params do
    begin
      var ParamType: TFieldType;
      if Generator.ParamTypes.TryGetValue(Pair.Key, ParamType) then
        Cmd.AddParam(Pair.Key, Pair.Value, ParamType)
      else
        Cmd.AddParam(Pair.Key, Pair.Value);
    end;
    Cmd.ExecuteNonQuery;
    FIdentityMap.Remove(GetEntityId(T(AEntity)));
  finally
    Generator.Free;
  end;
end;

function TDbSet<T>.TryLock(const AEntity: T; const AToken: string; ADurationMinutes: Integer): Boolean;
var
  Typ: TRttiType;
  Prop, TokenProp, ExpiryProp: TRttiProperty;
  TokenCol, ExpiryCol: string;
  Sql: string;
  Cmd: IDbCommand;
  PKCols: TArray<string>;
  i: Integer;
begin
  Result := False;
  TokenProp := nil;
  ExpiryProp := nil;
  TokenCol := '';
  ExpiryCol := '';

  Typ := FRttiContext.GetType(T);
  for Prop in Typ.GetProperties do
  begin
    if Prop.HasAttribute<LockTokenAttribute> then TokenProp := Prop;
    if Prop.HasAttribute<LockExpirationAttribute> then ExpiryProp := Prop;
  end;

  if (TokenProp = nil) or (ExpiryProp = nil) then
    raise Exception.Create('Entity ' + Typ.Name + ' does not have [LockToken] and [LockExpiration] attributes.');

  // Find Column Names
  TokenCol := TokenProp.Name;
  ExpiryCol := ExpiryProp.Name;
  if FMap <> nil then
  begin
    var PMap: TPropertyMap;
    if FMap.Properties.TryGetValue(TokenProp.Name, PMap) and (PMap.ColumnName <> '') then TokenCol := PMap.ColumnName;
    if FMap.Properties.TryGetValue(ExpiryProp.Name, PMap) and (PMap.ColumnName <> '') then ExpiryCol := PMap.ColumnName;
  end;

  // Build atomic update
  // UPDATE Table SET Token = :me, Expiry = :future 
  // WHERE PK = :id AND (Token IS NULL OR Token = :me OR Expiry < :now)
  PKCols := GetPKColumns;
  if Length(PKCols) = 0 then raise Exception.Create('Entity must have a primary key for locking.');

  Sql := Format('UPDATE %s SET %s = :token, %s = :expiry WHERE ', 
    [GetTableName, FContext.Dialect.QuoteIdentifier(TokenCol), FContext.Dialect.QuoteIdentifier(ExpiryCol)]);

  for i := 0 to High(PKCols) do
  begin
    if i > 0 then Sql := Sql + ' AND ';
    Sql := Sql + FContext.Dialect.QuoteIdentifier(PKCols[i]) + ' = :pk' + IntToStr(i);
  end;

  Sql := Sql + Format(' AND (%s IS NULL OR %s = :token OR %s < :now)', 
    [FContext.Dialect.QuoteIdentifier(TokenCol), FContext.Dialect.QuoteIdentifier(TokenCol), FContext.Dialect.QuoteIdentifier(ExpiryCol)]);

  Cmd := FContext.Connection.CreateCommand(Sql);
  Cmd.AddParam('token', AToken);
  Cmd.AddParam('expiry', Now + (ADurationMinutes / 1440.0));
  Cmd.AddParam('now', Now);

  // Add PK Params
  // Extract PK values from entity
  for i := 0 to High(PKCols) do
  begin
    // Simple lookup: Find property matching PK column or name
    var Done := False;
    for Prop in Typ.GetProperties do
    begin
       var CurCol: string := Prop.Name;
       if FMap <> nil then
       begin
         var PMap: TPropertyMap;
         if FMap.Properties.TryGetValue(Prop.Name, PMap) and (PMap.ColumnName <> '') then CurCol := PMap.ColumnName;
       end;
       if SameText(CurCol, PKCols[i]) then
       begin
         Cmd.AddParam('pk' + IntToStr(i), Prop.GetValue(Pointer(AEntity)));
         Done := True;
         Break;
       end;
    end;
    if not Done then raise Exception.Create('Could not find PK property for ' + PKCols[i]);
  end;

  if Cmd.ExecuteNonQuery = 1 then
  begin
    // Update local entity
    TokenProp.SetValue(Pointer(AEntity), AToken);
    ExpiryProp.SetValue(Pointer(AEntity), Now + (ADurationMinutes / 1440.0));
    Result := True;
  end;
end;

function TDbSet<T>.Unlock(const AEntity: T): Boolean;
var
  Typ: TRttiType;
  Prop, TokenProp, ExpiryProp: TRttiProperty;
  TokenCol, ExpiryCol: string;
  Sql: string;
  Cmd: IDbCommand;
  PKCols: TArray<string>;
  i: Integer;
begin
  Result := False;
  TokenProp := nil;
  ExpiryProp := nil;

  Typ := FRttiContext.GetType(T);
  for Prop in Typ.GetProperties do
  begin
    if Prop.HasAttribute<LockTokenAttribute> then TokenProp := Prop;
    if Prop.HasAttribute<LockExpirationAttribute> then ExpiryProp := Prop;
  end;

  if (TokenProp = nil) or (ExpiryProp = nil) then Exit;

  // Find Column Names
  TokenCol := TokenProp.Name;
  ExpiryCol := ExpiryProp.Name;
  if FMap <> nil then
  begin
    var PMap: TPropertyMap;
    if FMap.Properties.TryGetValue(TokenProp.Name, PMap) and (PMap.ColumnName <> '') then TokenCol := PMap.ColumnName;
    if FMap.Properties.TryGetValue(ExpiryProp.Name, PMap) and (PMap.ColumnName <> '') then ExpiryCol := PMap.ColumnName;
  end;

  PKCols := GetPKColumns;
  Sql := Format('UPDATE %s SET %s = NULL, %s = NULL WHERE ', 
    [GetTableName, FContext.Dialect.QuoteIdentifier(TokenCol), FContext.Dialect.QuoteIdentifier(ExpiryCol)]);

  for i := 0 to High(PKCols) do
  begin
    if i > 0 then Sql := Sql + ' AND ';
    Sql := Sql + FContext.Dialect.QuoteIdentifier(PKCols[i]) + ' = :pk' + IntToStr(i);
  end;

  // Important: only unlock if I am the owner (optional business rule?)
  // For now, let's keep it simple: just unlock.
  
  Cmd := FContext.Connection.CreateCommand(Sql);
  for i := 0 to High(PKCols) do
  begin
    for Prop in Typ.GetProperties do
    begin
       var CurCol: string := Prop.Name;
       if FMap <> nil then
       begin
         var PMap: TPropertyMap;
         if FMap.Properties.TryGetValue(Prop.Name, PMap) and (PMap.ColumnName <> '') then CurCol := PMap.ColumnName;
       end;
       if SameText(CurCol, PKCols[i]) then
       begin
         Cmd.AddParam('pk' + IntToStr(i), Prop.GetValue(Pointer(AEntity)));
         Break;
       end;
    end;
  end;

  if Cmd.ExecuteNonQuery = 1 then
  begin
    TokenProp.SetValue(Pointer(AEntity), TValue.Empty);
    ExpiryProp.SetValue(Pointer(AEntity), TValue.Empty);
    Result := True;
  end;
end;

function TDbSet<T>.GenerateCreateTableScript: string;
var
  Generator: TSqlGenerator<T>;
begin
  Generator := CreateGenerator;
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
  Val: T;
begin
  Keys := FIdentityMap.Keys;
  for Key in Keys do
  begin
    if FIdentityMap.ContainsKey(Key) then
    begin
      Val := FIdentityMap.Extract(Key);
      if Val <> nil then
        FOrphans.Add(Val);
    end;
  end;
end;

function TDbSet<T>.ListObjects(const AExpression: IExpression): IList<TObject>;
var
  TypedList: IList<T>;
  Item: T;
  Obj: TObject;
begin
  Result := TCollections.CreateList<TObject>;
  TypedList := ToList(AExpression);
  for Item in TypedList do
  begin
    Obj := TObject(Item);
    Result.Add(Obj);
  end;
end;


function TDbSet<T>.ToList: IList<T>;
begin
  Result := ToList(ISpecification<T>(nil));
end;

function TDbSet<T>.ToListAsync: TAsyncBuilder<IList<T>>;
begin
  if not FContext.Connection.Pooled then
    raise Exception.Create('ToListAsync requires a pooled connection to ensure thread safety.');

  Result := TAsyncTask.Run<IList<T>>(
    TFunc<IList<T>>(
      function: IList<T>
      begin
        Result := Self.ToList;
      end
    )
  );
end;

function TDbSet<T>.ToList(const AExpression: IExpression): IList<T>;
var
  Spec: ISpecification<T>;
begin
  Spec := TSpecification<T>.Create(AExpression);
  Result := ToList(Spec);
end;

function TDbSet<T>.ToList(const ASpec: ISpecification<T>): IList<T>;
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Reader: IDbReader;
  Cmd: IDbCommand;
  Entity: T;
  IsProjection: Boolean;
  Tracking: Boolean;
  LSpec: ISpecification<T>;
begin
  LSpec := ASpec;
  ApplyTenantFilter(LSpec);

  IsProjection := (LSpec <> nil) and (Length(LSpec.GetSelectedColumns) > 0);
  
  // Tracking defaults to True
  // If Spec is provided, respect its setting
  if LSpec <> nil then
    Tracking := LSpec.IsTrackingEnabled
  else
    Tracking := True;

  // Projections FORCE tracking off regardless of Spec setting
  if IsProjection then
    Tracking := False;

  if PTypeInfo(TypeInfo(T)).Kind = tkClass then
    Result := TCollections.CreateObjectList<T>(not Tracking)
  else
    Result := TCollections.CreateList<T>;

  Generator := CreateGenerator;
  try
    if LSpec <> nil then
      Sql := Generator.GenerateSelect(LSpec)
    else
      Sql := Generator.GenerateSelect;
      
    Cmd := FContext.Connection.CreateCommand(Sql);
    for var Pair in Generator.Params do
    begin
      var ParamType: TFieldType;
      if Generator.ParamTypes.TryGetValue(Pair.Key, ParamType) then
        Cmd.AddParam(Pair.Key, Pair.Value, ParamType)
      else
        Cmd.AddParam(Pair.Key, Pair.Value);
    end;
    
    try
      Reader := Cmd.ExecuteQuery;
      while Reader.Next do
      begin
        Entity := Hydrate(Reader, Tracking);
        Result.Add(Entity);
      end;
    except
      on E: Exception do
      begin
        SafeWriteLn('ERROR in TDbSet.ToList during fetch: ' + E.Message);
        raise;
      end;
    end;

    if (LSpec <> nil) and (Length(LSpec.GetIncludes) > 0) then
      DoLoadIncludes(Result, LSpec.GetIncludes);
  finally
    Generator.Free;
    ResetQueryFlags;
  end;
end;

function TDbSet<T>.FromSql(const ASql: string; const AParams: array of TValue): TFluentQuery<T>;
var
  LParams: TArray<TValue>;
  I: Integer;
begin
  SetLength(LParams, Length(AParams));
  for I := 0 to Length(AParams) - 1 do
    LParams[I] := AParams[I];

  Result := TFluentQuery<T>.Create(
    TFunc<TQueryIterator<T>>(
      function: TQueryIterator<T>
      begin
        Result := TSqlQueryIterator<T>.Create(Self, ASql, LParams);
      end
    ),
    FContext.Connection
  );
end;

function TDbSet<T>.FromSql(const ASql: string): TFluentQuery<T>;
begin
  Result := FromSql(ASql, []);
end;

procedure TDbSet<T>.ApplyTenantFilter(var ASpec: ISpecification<T>);
var
  Provider: ITenantProvider;
begin
  if FIgnoreQueryFilters then Exit;

  // Check if T implements ITenantAware using RTTI
  if GetTypeData(TypeInfo(T))^.ClassType.GetInterfaceEntry(ITenantAware) = nil then Exit;

  Provider := FContext.TenantProvider;
  
  if (Provider = nil) or (Provider.Tenant = nil) then Exit;

  if ASpec = nil then
    ASpec := TSpecification<T>.Create;
    
  // Append TenantId filter
  ASpec.Where(TBinaryExpression.Create('TenantId', boEqual, Provider.Tenant.Id));
end;

procedure TDbSet<T>.ExtractForeignKeys(const AEntities: IList<T>; PropertyToCheck: string;
  out IDs: IList<TValue>; out FKMap: IDictionary<T, TValue>);
var
  Ent: T;
  Val: TValue;
  Ctx: TRttiContext;
  Typ: TRttiType;
begin
  IDs := TCollections.CreateList<TValue>;
  FKMap := TCollections.CreateDictionary<T, TValue>;
  Ctx := TRttiContext.Create;
  try
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
  finally
    Ctx.Free;
  end;
end;

procedure TDbSet<T>.LoadAndAssign(const AEntities: IList<T>; const NavPropName: string);
var
  IDs: IList<TValue>;
  FKMap: IDictionary<T, TValue>;
  TargetType: TRttiType;
  TargetDbSet: IDbSet;
  LoadedMap: IDictionary<string, TObject>;
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

    // Use Variant array to preserve types (Integer, String, GUID) for correct parameter binding
    // Ensure we handle Nullable types correctly before converting to variant
    var IdValues: TArray<Variant>;
    SetLength(IdValues, IDs.Count);
    for var k := 0 to IDs.Count - 1 do
      IdValues[k] := TValueToVariant(IDs[k]);

    // Use Variant array to preserve types (Integer, String, GUID) for correct parameter binding
    var Expr: IExpression := TPropExpression.Create('Id').&In(IdValues);

    TargetList := TargetDbSet.ListObjects(Expr);

    LoadedMap := TCollections.CreateDictionary<string, TObject>;
    for Obj in TargetList do
    begin
      var TargetRefId := TargetDbSet.GetEntityId(Obj);
      var KeyStr := TValueToKeyString(TargetRefId);
      LoadedMap.AddOrSetValue(KeyStr, Obj);
    end;
    
    for var Pair in FKMap do
    begin
      var Parent := Pair.Key;
      var FkVal := TValueToKeyString(Pair.Value);
      try
        if LoadedMap.ContainsKey(FkVal) then
        begin
          TReflection.SetValue(Pointer(Parent), NavProp, LoadedMap[FkVal]);
        end;
      except
        on E: Exception do
        begin
          raise;
        end;
      end;
    end;

  finally
    IDs := nil;
    FKMap := nil;
    LoadedMap := nil;
  end;
end;

procedure TDbSet<T>.DoLoadIncludes(const AEntities: IList<T>; const AIncludes: TArray<string>);
var
  PropMap: TPropertyMap;
begin
  if (AEntities = nil) or (AEntities.Count = 0) then Exit;
  for var IncludePath in AIncludes do
  begin
    // Check if this is a Many-to-Many relationship
    PropMap := nil;
    if (FMap <> nil) and FMap.Properties.TryGetValue(IncludePath, PropMap) then
    begin
      if PropMap.Relationship = rtManyToMany then
      begin
        LoadManyToMany(AEntities, IncludePath, PropMap);
        Continue;
      end;
      if PropMap.Relationship = rtOneToMany then
      begin
        LoadOneToMany(AEntities, IncludePath, PropMap);
        Continue;
      end;
    end;
    // Standard One-to-Many / Many-to-One loading
    LoadAndAssign(AEntities, IncludePath);
  end;
end;

procedure TDbSet<T>.LoadOneToMany(const AEntities: IList<T>; const NavPropName: string; const PropMap: TPropertyMap);
var
  ParentIds: IList<TValue>;
  ParentMap: IDictionary<string, T>;
  Ent: T;
  EntId: TValue;
  TargetDbSet: IDbSet;
  TargetType: TRttiType;
  TargetList: IList<TObject>;
  Obj: TObject;
  NavProp: TRttiProperty;
  TargetFKPropName: string;
  Ctx: TRttiContext;
  TargetFKValue: TValue;
  TargetFKStr: string;
  ListIntf: IInterface;
  TargetPropName: string;
  ObjProp: TRttiProperty;
  Val: TValue;
  TargetMap: TEntityMap;
  InversePropMap: TPropertyMap;
begin
  NavProp := FRttiContext.GetType(T).GetProperty(NavPropName);
  if NavProp = nil then Exit;

  // 1. Collect Parent IDs and build map
  ParentIds := TCollections.CreateList<TValue>;
  ParentMap := TCollections.CreateDictionary<string, T>;
  try
    for Ent in AEntities do
    begin
      EntId := GetRelatedId(Ent);
      if not EntId.IsEmpty then
      begin
        // Ensure ID is unwrapped if it is a Smart Type (Prop<T>)

        


        var KeyStr := TValueToKeyString(EntId);
        if not ParentIds.Contains(EntId) then
          ParentIds.Add(EntId);
        ParentMap.AddOrSetValue(KeyStr, Ent);
      end;
    end;
    if ParentIds.Count = 0 then Exit;

    // 2. Identify Target Type (from IList<TTarget>)
    TargetType := nil;
    Ctx := TRttiContext.Create;
    try
      var PropType := NavProp.PropertyType;
      if PropType.TypeKind = tkInterface then
      begin
        var TypeName := PropType.Name;
        var StartPos := Pos('<', TypeName);
        var EndPos := Pos('>', TypeName);
        if (StartPos > 0) and (EndPos > StartPos) then
        begin
          var GenericTypeName := Copy(TypeName, StartPos + 1, EndPos - StartPos - 1);
          TargetType := Ctx.FindType(GenericTypeName);
        end;
      end;
    finally
      Ctx.Free;
    end;
    
    if TargetType = nil then Exit;
    TargetDbSet := FContext.DataSet(TargetType.Handle);
    TargetMap := TModelBuilder.Instance.GetMap(TargetType.Handle);

    // 3. Identification of FK
    TargetFKPropName := PropMap.ForeignKeyColumn;
    
    // If we have an InverseProperty, look it up in the target map to find the FK
    if (TargetFKPropName = '') and (PropMap.InverseProperty <> '') and (TargetMap <> nil) then
    begin
       if TargetMap.Properties.TryGetValue(PropMap.InverseProperty, InversePropMap) then
         TargetFKPropName := InversePropMap.ForeignKeyColumn;
    end;
    
    // If still empty, scan target properties for any ForeignKey attribute pointing to our class name
    if (TargetFKPropName = '') and (TargetMap <> nil) then
    begin
       var ParentClassName := T.ClassName;
       if ParentClassName.StartsWith('T') then ParentClassName := Copy(ParentClassName, 2, MaxInt);
       
       for var P in TargetMap.Properties do
       begin
          if SameText(P.Key, ParentClassName) or SameText(P.Key, ParentClassName + 'Id') then
          begin
             if P.Value.ForeignKeyColumn <> '' then
             begin
                TargetFKPropName := P.Value.ForeignKeyColumn;
                Break;
             end;
          end;
       end;
    end;

    // Fallback guess
    if TargetFKPropName = '' then
    begin
       var ClassName := T.ClassName;
       if ClassName.StartsWith('T') then ClassName := Copy(ClassName, 2, MaxInt);
       TargetFKPropName := ClassName + 'Id';
    end;

    TargetPropName := TargetFKPropName;
    if TargetMap <> nil then
    begin
       for var P in TargetMap.Properties do
       begin
          if SameText(P.Key, TargetFKPropName) or SameText(P.Value.ColumnName, TargetFKPropName) then
          begin
             TargetPropName := P.Key;
             Break;
          end;
       end;
    end;

    var IdValues: TArray<Variant>;
    SetLength(IdValues, ParentIds.Count);
    for var i := 0 to ParentIds.Count - 1 do
      IdValues[i] := TValueToVariant(ParentIds[i]);

    // Query targets using Property Name
    var Expr := TPropExpression.Create(TargetPropName).&In(IdValues);
    
    TargetList := TargetDbSet.ListObjects(Expr);

    // 4. Assign children to parents
    for Obj in TargetList do
    begin
       ObjProp := FRttiContext.GetType(Obj.ClassType).GetProperty(TargetPropName);
       if ObjProp <> nil then
       begin
          TargetFKValue := ObjProp.GetValue(Obj);
          
          // CRITICAL: Must unwrap if it is Prop<T> or Nullable
          if not TryUnwrapAndValidateFK(TargetFKValue, FRttiContext) then Continue;

          TargetFKStr := TValueToKeyString(TargetFKValue);
          
          if ParentMap.ContainsKey(TargetFKStr) then
          begin
             var Parent := ParentMap[TargetFKStr];
             Val := NavProp.GetValue(Pointer(Parent));

             // Ensure List is initialized
             if Val.IsEmpty or ((Val.Kind = tkInterface) and (Val.AsInterface = nil)) then
             begin
                 var NewList := TTrackingListFactory.CreateList(TargetType.Handle, FContext, Parent, NavProp.Name);
                 TReflection.SetValue(Pointer(Parent), NavProp, NewList);
                 Val := NavProp.GetValue(Pointer(Parent));
             end;

             if Val.Kind = tkInterface then
             begin
                ListIntf := Val.AsInterface;
                if ListIntf <> nil then
                begin
                   var IntfTyp := FRttiContext.GetType(Val.TypeInfo);
                   var AddMethod := IntfTyp.GetMethod('Add');
                   if AddMethod <> nil then
                   begin
                      AddMethod.Invoke(Val, [Obj]);
                   end;
                end;
             end;
          end;
       end;
    end;

  finally
    ParentIds := nil;
    ParentMap := nil;
  end;
end;

procedure TDbSet<T>.LoadManyToMany(const AEntities: IList<T>; const NavPropName: string; const PropMap: TPropertyMap);
var
  NavProp: TRttiProperty;
  SQL: string;
  Ent: T;
  EntId: TValue;
  EntityIds: IList<TValue>;
  Reader: IDbReader;
  TargetIds: IDictionary<string, IList<TValue>>; // EntityId -> List of RelatedIds
  AllRelatedIds: IList<TValue>;
  RelatedObjects: IDictionary<string, TObject>; // RelatedId -> Object
  Ctx: TRttiContext;
  LTargetType: TRttiType;
  RelatedDbSet: IDbSet;
  IdValues: TArray<Variant>;
  RelatedExpr: IExpression;
  LoadedList: IList<TObject>;
  CollValue: TValue;
  TheList: IList<TObject>;
  LEntIdStr, LObjId, LRelIdStr, LTypeName, LGenericTypeName: string;
  LStartPos, LEndPos: Integer;
  PropType: TRttiType;
  NewList: IList<TObject>;
begin
  if PropMap.JoinTableName = '' then Exit;

  NavProp := FRttiContext.GetType(T).GetProperty(NavPropName);
  if NavProp = nil then Exit;

  // Collect all entity IDs
  EntityIds := TCollections.CreateList<TValue>;
  try
    for Ent in AEntities do
    begin
      EntId := GetRelatedId(Ent);
      if not EntityIds.Contains(EntId) then
        EntityIds.Add(EntId);
    end;
    if EntityIds.Count = 0 then Exit;

    // Build SQL to query join table
    var SB := TStringBuilder.Create;
    try
      SB.Append('SELECT ');
      SB.Append(FContext.Dialect.QuoteIdentifier(PropMap.LeftKeyColumn));
      SB.Append(', ');
      SB.Append(FContext.Dialect.QuoteIdentifier(PropMap.RightKeyColumn));
      SB.Append(' FROM ');
      SB.Append(FContext.Dialect.QuoteIdentifier(PropMap.JoinTableName));
      SB.Append(' WHERE ');
      SB.Append(FContext.Dialect.QuoteIdentifier(PropMap.LeftKeyColumn));
      SB.Append(' IN (');
      for var i := 0 to EntityIds.Count - 1 do
      begin
        if i > 0 then SB.Append(', ');
        SB.Append(':p' + IntToStr(i + 1));
      end;
      SB.Append(')');
      SQL := SB.ToString;
    finally
      SB.Free;
    end;

    var Cmd := FContext.Connection.CreateCommand(SQL);
    for var i := 0 to EntityIds.Count - 1 do
      Cmd.AddParam('p' + IntToStr(i + 1), EntityIds[i]);

    Reader := Cmd.ExecuteQuery;

    TargetIds := TCollections.CreateDictionary<string, IList<TValue>>(True);
    AllRelatedIds := TCollections.CreateList<TValue>;
    try
      while Reader.Next do
      begin
        var LeftKey := Reader.GetValue(0).ToString;
        var RightKey := Reader.GetValue(1);

        if not TargetIds.ContainsKey(LeftKey) then
          TargetIds.Add(LeftKey, TCollections.CreateList<TValue>);
        TargetIds[LeftKey].Add(RightKey);

        if not AllRelatedIds.Contains(RightKey) then
          AllRelatedIds.Add(RightKey);
      end;

      if AllRelatedIds.Count = 0 then Exit;

      Ctx := TRttiContext.Create;
      try
        LTargetType := nil;
        PropType := NavProp.PropertyType;
        if PropType.TypeKind = tkInterface then
        begin
          // IList<TRelated> - extract TRelated
          LTypeName := PropType.Name;
          // Parse generic: IList<TRelated>
          LStartPos := Pos('<', LTypeName);
          LEndPos := Pos('>', LTypeName);
          if (LStartPos > 0) and (LEndPos > LStartPos) then
          begin
            LGenericTypeName := Copy(LTypeName, LStartPos + 1, LEndPos - LStartPos - 1);
            LTargetType := Ctx.FindType(LGenericTypeName);
          end;
        end;

        if LTargetType = nil then Exit;

        RelatedDbSet := FContext.DataSet(LTargetType.Handle);
        SetLength(IdValues, AllRelatedIds.Count);
        for var i := 0 to AllRelatedIds.Count - 1 do
          IdValues[i] := TValueToVariant(AllRelatedIds[i]);

        RelatedExpr := TPropExpression.Create('Id').&In(IdValues);
        LoadedList := RelatedDbSet.ListObjects(RelatedExpr);

        RelatedObjects := TCollections.CreateDictionary<string, TObject>;
        try
          for var Obj in LoadedList do
          begin
            LObjId := RelatedDbSet.GetEntityId(Obj);
            RelatedObjects.AddOrSetValue(LObjId, Obj);
          end;

          for Ent in AEntities do
          begin
            EntId := GetRelatedId(Ent);
            LEntIdStr := EntId.ToString;

            CollValue := NavProp.GetValue(Pointer(Ent));
            if CollValue.IsEmpty or (CollValue.Kind <> tkInterface) or (CollValue.AsType<IInterface> = nil) then
            begin
              NewList := TCollections.CreateList<TObject>;
              NavProp.SetValue(Pointer(Ent), TValue.From<IList<TObject>>(NewList));
              CollValue := NavProp.GetValue(Pointer(Ent));
            end;

            if Supports(CollValue.AsType<IInterface>, IList<TObject>, TheList) then
            begin
              if TargetIds.ContainsKey(LEntIdStr) then
              begin
                for var RelId in TargetIds[LEntIdStr] do
                begin
                  LRelIdStr := RelId.ToString;
                  if RelatedObjects.ContainsKey(LRelIdStr) then
                    TheList.Add(RelatedObjects[LRelIdStr]);
                end;
              end;
            end;
          end;
        finally
          RelatedObjects := nil;
        end;
      finally
        Ctx.Free;
      end;
    finally
      TargetIds := nil;
      AllRelatedIds := nil;
    end;
  finally
    EntityIds := nil;
  end;
end;

procedure TDbSet<T>.LinkManyToMany(const AEntity: T; const APropertyName: string; const ARelatedEntity: TObject);
var
  PropMap: TPropertyMap;
  SQL: string;
  EntityId, RelatedId: TValue;
begin
  if FMap = nil then Exit;
  if not FMap.Properties.TryGetValue(APropertyName, PropMap) then Exit;
  if PropMap.Relationship <> rtManyToMany then Exit;
  if PropMap.JoinTableName = '' then Exit;
  
  EntityId := GetRelatedId(AEntity);
  RelatedId := GetRelatedId(ARelatedEntity);
  
  SQL := TJoinTableSQLHelper.GenerateInsert(FContext.Dialect,
    PropMap.JoinTableName, PropMap.LeftKeyColumn, PropMap.RightKeyColumn);
    
  var Cmd := FContext.Connection.CreateCommand(SQL);
  Cmd.AddParam('p1', EntityId);
  Cmd.AddParam('p2', RelatedId);
  Cmd.Execute;
end;

procedure TDbSet<T>.UnlinkManyToMany(const AEntity: T; const APropertyName: string; const ARelatedEntity: TObject);
var
  PropMap: TPropertyMap;
  SQL: string;
  EntityId, RelatedId: TValue;
begin
  if FMap = nil then Exit;
  if not FMap.Properties.TryGetValue(APropertyName, PropMap) then Exit;
  if PropMap.Relationship <> rtManyToMany then Exit;
  if PropMap.JoinTableName = '' then Exit;
  
  EntityId := GetRelatedId(AEntity);
  RelatedId := GetRelatedId(ARelatedEntity);
  
  SQL := TJoinTableSQLHelper.GenerateDelete(FContext.Dialect,
    PropMap.JoinTableName, PropMap.LeftKeyColumn, PropMap.RightKeyColumn);
    
  var Cmd := FContext.Connection.CreateCommand(SQL);
  Cmd.AddParam('p1', EntityId);
  Cmd.AddParam('p2', RelatedId);
  Cmd.Execute;
end;

{ Non-generic IDbSet implementations }

procedure TDbSet<T>.LinkManyToMany(const AEntity: TObject; const APropertyName: string; const ARelatedEntity: TObject);
begin
  LinkManyToMany(T(AEntity), APropertyName, ARelatedEntity);
end;

procedure TDbSet<T>.UnlinkManyToMany(const AEntity: TObject; const APropertyName: string; const ARelatedEntity: TObject);
begin
  UnlinkManyToMany(T(AEntity), APropertyName, ARelatedEntity);
end;

procedure TDbSet<T>.SyncManyToMany(const AEntity: T; const APropertyName: string; const ARelatedEntities: TArray<TObject>);
var
  PropMap: TPropertyMap;
  SQL: string;
  EntityId, RelatedId: TValue;
  RelEnt: TObject;
begin
  if FMap = nil then Exit;
  if not FMap.Properties.TryGetValue(APropertyName, PropMap) then Exit;
  if PropMap.Relationship <> rtManyToMany then Exit;
  if PropMap.JoinTableName = '' then Exit;
  
  EntityId := GetRelatedId(AEntity);
  
  // First, delete all existing links for this entity
  SQL := TJoinTableSQLHelper.GenerateDeleteByLeft(FContext.Dialect,
    PropMap.JoinTableName, PropMap.LeftKeyColumn);
    
  var Cmd := FContext.Connection.CreateCommand(SQL);
  Cmd.AddParam('p1', EntityId);
  Cmd.Execute;
  
  // Then, insert new links
  SQL := TJoinTableSQLHelper.GenerateInsert(FContext.Dialect,
    PropMap.JoinTableName, PropMap.LeftKeyColumn, PropMap.RightKeyColumn);
    
  for RelEnt in ARelatedEntities do
  begin
    RelatedId := GetRelatedId(RelEnt);
    var CmdLoop := FContext.Connection.CreateCommand(SQL);
    CmdLoop.AddParam('p1', EntityId);
    CmdLoop.AddParam('p2', RelatedId);
    CmdLoop.Execute;
  end;
end;

function TDbSet<T>.Find(const AId: Integer): T;
begin
  Result := Find(Variant(AId));
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
  var PropName: string := 'Id';
  var Val: TValue := TValue.Empty;
  
  if FPKColumns.Count > 0 then
  begin
    var PKProp: TRttiProperty;
    // FProps keys are lowercased in MapEntity
    if FProps.TryGetValue(FPKColumns[0].ToLower, PKProp) then
    begin
       PropName := PKProp.Name;
       // Coerce GUIDs and UUIDs if necessary
       if (PKProp.PropertyType.Handle = TypeInfo(TGUID)) and VarIsStr(AId) then
         Val := TValue.From<TGUID>(StringToGUID(VarToStr(AId)))
       else if (PKProp.PropertyType.Handle = TypeInfo(TUUID)) and VarIsStr(AId) then
         Val := TValue.From<TUUID>(TUUID.FromString(VarToStr(AId)))
       else
         Val := TValue.FromVariant(AId);
    end;
  end;
  
  if Val.IsEmpty then
    Val := TValue.FromVariant(AId);

  var Expr: IExpression := TPropExpression.Create(PropName) = Val;
  var Spec: ISpecification<T> := TSpecification<T>.Create(Expr);
  L := ToList(Spec);
  if L.Count > 0 then
  begin
    Result := L[0];
    L.Extract(Result);
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
  L := ToList(Spec);
  
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
  LFactory: TFunc<TQueryIterator<T>>;
begin
  LSpec := ASpec;
  LSelf := Self; 
  LFactory := function: TQueryIterator<T>
    begin
      Result := TSpecificationQueryIterator<T>.Create(
        function: IList<T>
        begin
          Result := LSelf.ToList(LSpec);
        end);
    end;

  Result := TFluentQuery<T>.Create(
    LFactory,
    LSpec as ISpecification,
    TFunc<ISpecification, Integer>(
      function(S: ISpecification): Integer
      begin
        Result := LSelf.Count(S as ISpecification<T>);
      end),
    TFunc<ISpecification, Boolean>(
      function(S: ISpecification): Boolean
      begin
        Result := LSelf.Any(S as ISpecification<T>);
      end),
    TFunc<ISpecification, T>(
      function(S: ISpecification): T
      begin
        Result := LSelf.FirstOrDefault(S as ISpecification<T>);
      end),
    FContext.Connection,
    function: IEnumerator<T>
    begin
      Result := LSelf.RequestStreamingIterator(LSpec);
    end
  );
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
  L := ToList(Spec);
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
  Generator := CreateGenerator;
  try
    var Spec: ISpecification<T> := TSpecification<T>.Create(AExpression);
    ApplyTenantFilter(Spec);
    Spec.Take(1);
    
    Sql := Generator.GenerateSelect(Spec); 
    
    Cmd := FContext.Connection.CreateCommand(Sql) as IDbCommand;
    for var Pair in Generator.Params do
    begin
      var ParamType: TFieldType;
      if Generator.ParamTypes.TryGetValue(Pair.Key, ParamType) then
        Cmd.AddParam(Pair.Key, Pair.Value, ParamType)
      else
        Cmd.AddParam(Pair.Key, Pair.Value);
    end;
    
    var Reader := Cmd.ExecuteQuery;
    Result := Reader.Next;
  finally
    Generator.Free;
    ResetQueryFlags;
  end;
end;

function TDbSet<T>.Where(const APredicate: TQueryPredicate<T>): TFluentQuery<T>;
var
  SmartRes: BooleanExpression;
begin
  SmartRes := APredicate(Dext.Entity.Prototype.Prototype.Entity<T>);
  Result := Query(TFluentExpression(SmartRes));
end;

function TDbSet<T>.Where(const AValue: BooleanExpression): TFluentQuery<T>;
begin
  Result := Query(AValue.Expression);
end;

function TDbSet<T>.Where(const AExpression: TFluentExpression): TFluentQuery<T>;
begin
  Result := Query(AExpression.Expression);
end;

function TDbSet<T>.Where(const AExpression: IExpression): TFluentQuery<T>;
begin
  Result := Query(AExpression);
end;

function TDbSet<T>.Count(const AExpression: IExpression): Integer;
begin
  Result := Count(TSpecification<T>.Create(AExpression));
end;

function TDbSet<T>.Count(const ASpec: ISpecification<T>): Integer;
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
  LSpec: ISpecification<T>;
begin
  Generator := CreateGenerator;
  try
    LSpec := ASpec;
    ApplyTenantFilter(LSpec);
    Sql := Generator.GenerateCount(LSpec);
    
    Cmd := FContext.Connection.CreateCommand(Sql);
    for var Pair in Generator.Params do
    begin
      var ParamType: TFieldType;
      if Generator.ParamTypes.TryGetValue(Pair.Key, ParamType) then
        Cmd.AddParam(Pair.Key, Pair.Value, ParamType)
      else
        Cmd.AddParam(Pair.Key, Pair.Value);
    end;
    var Val := Cmd.ExecuteScalar;
    if Val.IsEmpty then Result := 0 else Result := Val.AsInteger;
  finally
    Generator.Free;
    ResetQueryFlags;
  end;
end;

function TDbSet<T>.Any(const ASpec: ISpecification<T>): Boolean;
begin
  Result := Count(ASpec) > 0;
end;



function TDbSet<T>.FirstOrDefault(const ASpec: ISpecification<T>): T;
var
  L: IList<T>;
begin
  // Optimization: Apply Take(1) to the spec if it doesn't have it
  if (ASpec <> nil) and (ASpec.GetTake <= 0) then
    ASpec.Take(1);
    
  L := ToList(ASpec);
  if L.Count > 0 then
    Result := L[0]
  else
    Result := nil;
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

procedure TDbSet<T>.ResetQueryFlags;
begin
  FIgnoreQueryFilters := False;
  FOnlyDeleted := False;
end;


function TDbSet<T>.HardDelete(const AEntity: T): IDbSet<T>;
var
  Generator: TSqlGenerator<T>;
  Sql: string;
  Cmd: IDbCommand;
begin
  Generator := CreateGenerator;
  try
    Sql := Generator.GenerateDelete(AEntity);
    Cmd := FContext.Connection.CreateCommand(Sql);
    for var Pair in Generator.Params do
    begin
      var ParamType: TFieldType;
      if Generator.ParamTypes.TryGetValue(Pair.Key, ParamType) then
        Cmd.AddParam(Pair.Key, Pair.Value, ParamType)
      else
        Cmd.AddParam(Pair.Key, Pair.Value);
    end;
    Cmd.ExecuteNonQuery;
    FIdentityMap.Remove(GetEntityId(AEntity));
  finally
    Generator.Free;
  end;
  Result := Self;
end;

function TDbSet<T>.RequestStreamingIterator(const ASpec: ISpecification<T>): IEnumerator<T>;
begin
  Result := TStreamingViewIterator<T>.Create(Self, ASpec);
end;

function TDbSet<T>.Restore(const AEntity: T): IDbSet<T>;
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
 
          TReflection.SetValue(Pointer(AEntity), Prop, ValToSet);
          PersistUpdate(AEntity);
        end;
      end;
    finally
      Ctx.Free;
    end;
  end;
  Result := Self;
end;

function TDbSet<T>.Prototype: T;
begin
  Result := Dext.Entity.Prototype.Prototype.Entity<T>;
end;

function TDbSet<T>.Prototype<TEntity>: TEntity;
begin
  Result := Dext.Entity.Prototype.Prototype.Entity<TEntity>;
end;




{ TDynamicDbSetFactory<T> }

function TDynamicDbSetFactory<T>.CreateDbSet(const AContext: IInterface): IInterface;
begin
  Result := TDbSet<T>.Create(AContext as IDbContext);
end;

end.


