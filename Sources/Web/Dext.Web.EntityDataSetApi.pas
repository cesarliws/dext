{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}
unit Dext.Web.EntityDataSetApi;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.Rtti,
  Data.DB,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Entity,
  Dext.Entity.Context,
  Dext.Entity.Mapping,
  Dext.Json,
  Dext.Json.Types,
  Dext.Web.Interfaces,
  Dext.Web.Routing;

type
  /// <summary>
  /// Represents the result of applying a single change item.
  /// </summary>
  TApplyItemResult = record
    /// <summary>The index of the change in the incoming list.</summary>
    Index: Integer;
    /// <summary>True if the change was applied successfully.</summary>
    Success: Boolean;
    /// <summary>Detailed error message in case of failure.</summary>
    ErrorMessage: string;
    /// <summary>Database keys (e.g. autoincrement ID).</summary>
    Keys: IDictionary<string, Variant>;
  end;

  /// <summary>
  /// Interface for processing and persisting entity change logs.
  /// </summary>
  IEntityDataSetStore = interface
    ['{F1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    /// <summary>
    /// Persists a batch of entity changes.
    /// </summary>
    function ApplyChanges(AEntityClass: TClass;
      const AChanges: IDextJsonArray;
      ADbContext: TDbContext): IList<TApplyItemResult>;
  end;

  /// <summary>
  /// DBContext-based store engine for persisting change logs.
  /// </summary>
  TDbContextEntityDataSetStore = class(TInterfacedObject, IEntityDataSetStore)
  private
    function GetEntityKeys(AEntity: TObject;
      Map: TEntityMap): IDictionary<string, Variant>;
    function ReadPropertyValue(AEntity: TObject;
      PropMap: TPropertyMap; out Value: Variant): Boolean;
    procedure SetPropertyValue(AEntity: TObject;
      PropMap: TPropertyMap; const Value: Variant);
  public
    /// <summary>
    /// Persists changes using the ORM DbContext SaveChanges.
    /// </summary>
    function ApplyChanges(AEntityClass: TClass;
      const AChanges: IDextJsonArray;
      ADbContext: TDbContext): IList<TApplyItemResult>;
  end;

  /// <summary>
  /// Exposes REST endpoints to load and persist datasets.
  /// </summary>
  TEntityDataSetApi = class
  public
    /// <summary>
    /// Maps GET and POST endpoints for a remote dataset.
    /// </summary>
    class procedure Map<T: class, constructor>(
      const ABuilder: IApplicationBuilder;
      const APath: string;
      ADbContextClass: TClass;
      AStore: IEntityDataSetStore = nil);
  end;

implementation

uses
  Dext.Core.Reflection;

{ TDbContextEntityDataSetStore }

function TDbContextEntityDataSetStore.ReadPropertyValue(AEntity: TObject;
  PropMap: TPropertyMap; out Value: Variant): Boolean;
var
  PValue: Pointer;
  RttiType: TRttiType;
  RttiProp: TRttiProperty;
  V: TValue;
begin
  Result := False;
  if (AEntity = nil) or (PropMap = nil) then Exit;

  if PropMap.FieldValueOffset > 0 then
  begin
    if (PropMap.FieldOffset > 0) and not
      PBoolean(Pointer(PByte(AEntity) + PropMap.FieldOffset))^ then
    begin
      Value := Null;
      Exit(True);
    end;

    PValue := Pointer(PByte(AEntity) + PropMap.FieldValueOffset);
    case PropMap.DataType of
      ftInteger, ftAutoInc: Value := PInteger(PValue)^;
      ftSmallint: Value := PSmallInt(PValue)^;
      ftShortint: Value := PShortInt(PValue)^;
      ftByte: Value := PByte(PValue)^;
      ftWord: Value := PWord(PValue)^;
      ftLargeint: Value := PInt64(PValue)^;
      ftString, ftWideString: Value := PString(PValue)^;
      ftFloat: Value := PDouble(PValue)^;
      ftCurrency: Value := PCurrency(PValue)^;
      ftBoolean: Value := PBoolean(PValue)^;
      ftDateTime, ftDate, ftTime: Value := PDateTime(PValue)^;
    else
      Exit(False);
    end;
    Result := True;
  end
  else
  begin
    RttiType := TReflection.Context.GetType(AEntity.ClassType);
    if RttiType <> nil then
    begin
      RttiProp := RttiType.GetProperty(PropMap.PropertyName);
      if RttiProp <> nil then
      begin
        V := RttiProp.GetValue(AEntity);
        Value := V.AsVariant;
        Result := True;
      end;
    end;
  end;
end;

procedure TDbContextEntityDataSetStore.SetPropertyValue(AEntity: TObject;
  PropMap: TPropertyMap; const Value: Variant);
var
  PValue: Pointer;
  RttiType: TRttiType;
  RttiProp: TRttiProperty;
begin
  if (AEntity = nil) or (PropMap = nil) then Exit;

  if PropMap.FieldValueOffset > 0 then
  begin
    if PropMap.FieldOffset > 0 then
      PBoolean(Pointer(PByte(AEntity) + PropMap.FieldOffset))^ :=
        not VarIsNull(Value);

    if not VarIsNull(Value) then
    begin
      PValue := Pointer(PByte(AEntity) + PropMap.FieldValueOffset);
      case PropMap.DataType of
        ftInteger, ftAutoInc: PInteger(PValue)^ := Value;
        ftSmallint: PSmallInt(PValue)^ := Value;
        ftShortint: PShortInt(PValue)^ := Value;
        ftByte: PByte(PValue)^ := Value;
        ftWord: PWord(PValue)^ := Value;
        ftLargeint: PInt64(PValue)^ := Value;
        ftString, ftWideString: PString(PValue)^ := string(Value);
        ftFloat: PDouble(PValue)^ := Double(Value);
        ftCurrency: PCurrency(PValue)^ := Currency(Value);
        ftBoolean: PBoolean(PValue)^ := Boolean(Value);
        ftDateTime, ftDate, ftTime: PDateTime(PValue)^ := TDateTime(Value);
      end;
    end;
  end;

  RttiType := TReflection.Context.GetType(AEntity.ClassType);
  if RttiType <> nil then
  begin
    RttiProp := RttiType.GetProperty(PropMap.PropertyName);
    if RttiProp <> nil then
    begin
      if VarIsNull(Value) then
        RttiProp.SetValue(AEntity, TValue.Empty)
      else
        RttiProp.SetValue(AEntity, TValue.FromVariant(Value));
    end;
  end;
end;

function TDbContextEntityDataSetStore.GetEntityKeys(AEntity: TObject;
  Map: TEntityMap): IDictionary<string, Variant>;
var
  Pair: TPair<string, TPropertyMap>;
  Val: Variant;
begin
  Result := TCollections.CreateDictionary<string, Variant>;
  if (AEntity <> nil) and (Map <> nil) then
  begin
    for Pair in Map.Properties do
    begin
      if Pair.Value.IsPK then
      begin
        if ReadPropertyValue(AEntity, Pair.Value, Val) then
          Result.Add(Pair.Key, Val);
      end;
    end;
  end;
end;

function TDbContextEntityDataSetStore.ApplyChanges(AEntityClass: TClass;
  const AChanges: IDextJsonArray;
  ADbContext: TDbContext): IList<TApplyItemResult>;
var
  Results: IList<TApplyItemResult>;
  ItemResult: TApplyItemResult;
  ChangeObj: IDextJsonObject;
  StateStr: string;
  KeysObj: IDextJsonObject;
  ValuesObj: IDextJsonObject;
  EntityObj: TObject;
  Map: TEntityMap;
  Pair: TPair<string, TPropertyMap>;
  i: Integer;
begin
  Results := TCollections.CreateList<TApplyItemResult>;
  Map := ADbContext.ModelBuilder.GetMap(AEntityClass.ClassInfo);

  for i := 0 to AChanges.Count - 1 do
  begin
    ChangeObj := AChanges.GetObject(i);
    StateStr := ChangeObj.GetString('state');
    KeysObj := nil;
    if ChangeObj.Contains('key') then
      KeysObj := ChangeObj.GetObject('key');
    ValuesObj := nil;
    if ChangeObj.Contains('values') then
      ValuesObj := ChangeObj.GetObject('values');

    ItemResult.Index := i;
    ItemResult.Success := True;
    ItemResult.ErrorMessage := '';
    ItemResult.Keys := nil;

    try
      if SameText(StateStr, 'inserted') then
      begin
        EntityObj := AEntityClass.Create;
        if (ValuesObj <> nil) and (Map <> nil) then
        begin
          for Pair in Map.Properties do
          begin
            if ValuesObj.Contains(Pair.Key) then
              SetPropertyValue(EntityObj, Pair.Value,
                ValuesObj.GetString(Pair.Key));
          end;
        end;

        ADbContext.ChangeTracker.Track(EntityObj, esAdded);
        ADbContext.SaveChanges;

        ItemResult.Keys := GetEntityKeys(EntityObj, Map);
      end
      else if SameText(StateStr, 'modified') then
      begin
        EntityObj := AEntityClass.Create;
        if (KeysObj <> nil) and (Map <> nil) then
        begin
          for Pair in Map.Properties do
          begin
            if Pair.Value.IsPK and KeysObj.Contains(Pair.Key) then
              SetPropertyValue(EntityObj, Pair.Value,
                KeysObj.GetString(Pair.Key));
          end;
        end;

        ADbContext.ChangeTracker.Track(EntityObj, esUnchanged);

        if (ValuesObj <> nil) and (Map <> nil) then
        begin
          for Pair in Map.Properties do
          begin
            if ValuesObj.Contains(Pair.Key) then
            begin
              SetPropertyValue(EntityObj, Pair.Value,
                ValuesObj.GetString(Pair.Key));
              ADbContext.Entry(EntityObj).Member(Pair.Key).IsModified := True;
            end;
          end;
        end;

        ADbContext.SaveChanges;
      end
      else if SameText(StateStr, 'deleted') then
      begin
        EntityObj := AEntityClass.Create;
        if (KeysObj <> nil) and (Map <> nil) then
        begin
          for Pair in Map.Properties do
          begin
            if Pair.Value.IsPK and KeysObj.Contains(Pair.Key) then
              SetPropertyValue(EntityObj, Pair.Value,
                KeysObj.GetString(Pair.Key));
          end;
        end;

        ADbContext.ChangeTracker.Track(EntityObj, esDeleted);
        ADbContext.SaveChanges;
      end;
    except
      on E: Exception do
      begin
        ItemResult.Success := False;
        ItemResult.ErrorMessage := E.Message;
      end;
    end;

    Results.Add(ItemResult);
  end;

  Result := Results;
end;

{ TEntityDataSetApi }

class procedure TEntityDataSetApi.Map<T>(
  const ABuilder: IApplicationBuilder;
  const APath: string;
  ADbContextClass: TClass;
  AStore: IEntityDataSetStore);
var
  Store: IEntityDataSetStore;
begin
  if AStore <> nil then
    Store := AStore
  else
    Store := TDbContextEntityDataSetStore.Create;

  ABuilder.MapGet(APath,
    procedure(Context: IHttpContext)
    var
      Ctx: TDbContext;
      List: IList<T>;
      JsonStr: string;
    begin
      Ctx := TDbContext(ADbContextClass.Create);
      try
        List := Ctx.Entities<T>.ToList;
        JsonStr := TDextJson.Serialize(List);
        Context.Response.SetContentType('application/json');
        Context.Response.Write(JsonStr);
      finally
        Ctx.Free;
      end;
    end);

  ABuilder.MapPost(APath + '/apply',
    procedure(Context: IHttpContext)
    var
      Ctx: TDbContext;
      RequestBody: string;
      JO: IDextJsonObject;
      ChangesArray: IDextJsonArray;
      ApplyResults: IList<TApplyItemResult>;
      ResJson: string;
      Reader: TStreamReader;
    begin
      Reader := TStreamReader.Create(Context.Request.Body, TEncoding.UTF8);
      try
        RequestBody := Reader.ReadToEnd;
      finally
        Reader.Free;
      end;

      JO := TDextJson.Provider.Parse(RequestBody) as IDextJsonObject;
      if (JO <> nil) and JO.Contains('changes') then
      begin
        ChangesArray := JO.GetArray('changes');
        Ctx := TDbContext(ADbContextClass.Create);
        try
          ApplyResults := Store.ApplyChanges(T, ChangesArray, Ctx);
          ResJson := TDextJson.Serialize(ApplyResults);
          Context.Response.SetContentType('application/json');
          Context.Response.Write(ResJson);
        finally
          Ctx.Free;
        end;
      end;
    end);
end;

end.
