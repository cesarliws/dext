unit Dext.Entity.LazyLoader;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  System.Variants,
  Dext.Entity.Core,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Mapping,
  Dext.Core.Reflection;

type
  /// <summary>
  ///   Standard implementation of ILazyLoader that interacts with IDbContext.
  /// </summary>
  TDextLazyLoader = class(TInterfacedObject, ILazyLoader)
  private
    {$IFDEF DEXT_HAS_WEAK}[Weak]{$ENDIF} FContext: IDbContext;
  public
    constructor Create(const AContext: IDbContext);
    procedure Load(AEntity: TObject; const APropertyName: string);
    procedure LoadCollection(AEntity: TObject; const APropertyName: string);
  end;

implementation

uses
  Dext.Entity.Context,
  Dext.Entity.TypeConverters,
  Dext.Core.Activator,
  System.Classes;

{ TDextLazyLoader }

constructor TDextLazyLoader.Create(const AContext: IDbContext);
begin
  inherited Create;
  FContext := AContext;
end;

procedure TDextLazyLoader.Load(AEntity: TObject; const APropertyName: string);
var
  Prop, FKProp, PKProp: TRttiProperty;
  Map: TEntityMap;
  PropMap, PMap: TPropertyMap;
  FKVal, PKValTyped: TValue;
  TargetSet: IDbSet;
  LoadedObj: TObject;
  FKName, PKCol, PKVal: string;
  PropField: TRttiField;
  DBVal, ExistingVal: TValue;
  Dialect: ISQLDialect;
  SQL: string;
  Cmd: IDbCommand;
  Reader: IDbReader;
  RType: TRttiType;
  NewObj: TObject;
  FinalVal: TValue;
  DBText: string;
begin
  if (FContext = nil) or (AEntity = nil) then Exit;

  Map := TEntityMap(FContext.GetMapping(AEntity.ClassInfo));
  if (Map <> nil) and Map.Properties.TryGetValue(APropertyName, PropMap) then
  begin
    RType := TReflection.Context.GetType(Map.EntityType);
    Prop := RType.GetProperty(APropertyName);
    if Prop = nil then Exit;
    
    PropField := RType.GetField(PropMap.FieldName);
    if PropField = nil then PropField := RType.GetField(TReflection.NormalizeFieldName(APropertyName));

    if PropMap.IsNavigation then
    begin
      FKName := PropMap.ForeignKeyColumn;
      if FKName = '' then FKName := APropertyName + 'Id';
      
      FKProp := RType.GetProperty(FKName);
      if FKProp <> nil then
      begin
        FKVal := FKProp.GetValue(AEntity);
        if not FKVal.IsEmpty then
        begin
          TargetSet := FContext.DataSet(Prop.PropertyType.Handle);
          LoadedObj := TargetSet.FindObject(FKVal.AsVariant);
          if LoadedObj <> nil then
          begin
            if PropField <> nil then
              PropField.SetValue(AEntity, LoadedObj)
            else
              Prop.SetValue(AEntity, LoadedObj);
          end;
        end;
      end;
    end
    else
    begin
      TargetSet := FContext.DataSet(Map.EntityType);
      if TargetSet <> nil then
      begin
        PKVal := TargetSet.GetEntityId(AEntity);
        if PKVal <> '' then
        begin
          Dialect := FContext.Dialect;
          PKCol := '';
          PKProp := nil;
          for PMap in Map.Properties.Values do
            if PMap.IsPK then
            begin
              PKCol := PMap.ColumnName;
              if PKCol = '' then PKCol := PMap.PropertyName;
              PKProp := RType.GetProperty(PMap.PropertyName);
              Break;
            end;

          if PKCol <> '' then
          begin
            SQL := Format('SELECT %s FROM %s WHERE %s = :p1', 
              [Dialect.QuoteIdentifier(PropMap.ColumnName), 
               Dialect.QuoteIdentifier(Map.TableName),
               Dialect.QuoteIdentifier(PKCol)]);
                
            Cmd := FContext.Connection.CreateCommand(SQL);
            if PKProp <> nil then
            begin
              PKValTyped := PKProp.GetValue(AEntity);
              Cmd.AddParam('p1', PKValTyped);
            end
            else
              Cmd.AddParam('p1', PKVal);
            Reader := Cmd.ExecuteQuery;
            if Reader.Next then
              DBVal := Reader.GetValue(0)
            else
              DBVal := TValue.Empty;
            if not DBVal.IsEmpty then
            begin
              DBText := DBVal.ToString;
              if DBVal.Kind = tkVariant then
                DBText := VarToStr(DBVal.AsVariant);
            end
            else
              DBText := '';
            
            ExistingVal := TValue.Empty;
            if PropField <> nil then 
              ExistingVal := PropField.GetValue(AEntity)
            else
              ExistingVal := Prop.GetValue(AEntity);

            if (not DBVal.IsEmpty) or (DBText <> '') then
            begin
              if ExistingVal.IsObject and (ExistingVal.AsObject is TStrings) then
              begin
                TStrings(ExistingVal.AsObject).Text := DBText;
              end
              else if Prop.PropertyType.IsInstance then
              begin
                NewObj := TActivator.CreateInstance(Prop.PropertyType.AsInstance.MetaclassType, []);
                if NewObj is TStrings then
                  TStrings(NewObj).Text := DBText;
                
                if PropField <> nil then
                  PropField.SetValue(AEntity, NewObj)
                else
                  TReflection.SetValue(Pointer(AEntity), Prop, TValue.From(NewObj));
              end
              else
              begin
                if PropMap.Converter <> nil then
                  FinalVal := PropMap.Converter.FromDatabase(DBVal, Prop.PropertyType.Handle)
                else
                  FinalVal := DBVal;
                
                if PropField <> nil then
                  PropField.SetValue(AEntity, FinalVal)
                else
                  TReflection.SetValue(Pointer(AEntity), Prop, FinalVal);
              end;
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TDextLazyLoader.LoadCollection(AEntity: TObject; const APropertyName: string);
begin
  // Implementation for collection loading fits here (D.2 expansion)
end;

end.
