{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}

unit Dext.Web.DataApi.Resolver;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  System.Variants,
  Dext.Entity.Mapping,
  Dext.Web.ModelBinding,
  Dext.Types.UUID;

type
  /// <summary>
  ///   Resolver for entity primary keys in Data API contexts.
  ///   Uses IModelBinder as the conversion engine.
  /// </summary>
  TEntityIdResolver = class
  private
    class function ValueToVariant(const AValue: TValue): Variant; static;
  public
    /// <summary>
    ///  Resolves a string ID (usually from route) into a typed Variant compatible with DbSet.Find.
    ///  Supports composite keys using the '|' separator.
    /// </summary>
    class function Resolve(AMap: TEntityMap; const AIdStr: string; ABinder: IModelBinder): Variant;
  end;

implementation

{ TEntityIdResolver }

class function TEntityIdResolver.ValueToVariant(const AValue: TValue): Variant;
begin
  if AValue.IsEmpty then
    Exit(Null);

  // Special handling for common Dext types that don't fit naturally in Variant
  if AValue.Kind = tkRecord then
  begin
    if AValue.TypeInfo = TypeInfo(TUUID) then
      Exit(AValue.AsType<TUUID>.ToString) // TUUID can always be represented as string without loss in Variant
    else if AValue.TypeInfo = TypeInfo(TGUID) then
      Exit(GuidToString(AValue.AsType<TGUID>)); // Variants handle strings better than raw TGUIDs
  end;

  Result := AValue.AsVariant;
end;

class function TEntityIdResolver.Resolve(AMap: TEntityMap; const AIdStr: string; ABinder: IModelBinder): Variant;
var
  i: Integer;
  PKProp: TPropertyMap;
  ShouldFreeBinder: Boolean;
  EffectiveBinder: IModelBinder;
  BinderVal: TValue;
  PartStart: Integer;
  PartEnd: Integer;
  PartValue: string;
begin
  if AMap.Keys.Count = 0 then
    raise Exception.CreateFmt('Entity %s does not have a primary key mapped.', [AMap.EntityType.Name]);

  ShouldFreeBinder := ABinder = nil;
  if ShouldFreeBinder then
    EffectiveBinder := TModelBinder.Create
  else
    EffectiveBinder := ABinder;

  try
    // Case 1: Simple Key (Common)
    if AMap.Keys.Count = 1 then
    begin
      PKProp := AMap.Properties[AMap.Keys[0]];
      // Delegation to Model Binder for type conversion (String, Integer, TUUID, TGUID, etc.)
      BinderVal := EffectiveBinder.BindValue(AIdStr, PKProp.Prop.PropertyType.Handle);
      Result := ValueToVariant(BinderVal);
    end
    else
    begin
      // Case 2: Composite Key (Dext pattern ID1|ID2|ID3)
      Result := VarArrayCreate([0, AMap.Keys.Count - 1], varVariant);
      PartStart := 1;
      for i := 0 to AMap.Keys.Count - 1 do
      begin
        PartEnd := PartStart;
        while (PartEnd <= Length(AIdStr)) and (AIdStr[PartEnd] <> '|') do
          Inc(PartEnd);

        if ((i < AMap.Keys.Count - 1) and (PartEnd > Length(AIdStr))) or
           ((i = AMap.Keys.Count - 1) and (PartEnd <= Length(AIdStr))) then
          raise EConvertError.CreateFmt('Invalid composite ID format. Expected %d parts separated by "|".', [AMap.Keys.Count]);

        PartValue := Copy(AIdStr, PartStart, PartEnd - PartStart);
        PKProp := AMap.Properties[AMap.Keys[i]];
        BinderVal := EffectiveBinder.BindValue(PartValue, PKProp.Prop.PropertyType.Handle);
        Result[i] := ValueToVariant(BinderVal);
        PartStart := PartEnd + 1;
      end;
    end;
  finally
    // IModelBinder is usually a class without IInterface in some Dext parts, 
    // or an interface. Check if we need to let ref-count or free.
    // TModelBinder.Create in Dext.Web.ModelBinding returns IModelBinder (interface).
    // So EffectiveBinder will be cleaned up by ARC if it's an interface.
    EffectiveBinder := nil;
  end;
end;

end.
