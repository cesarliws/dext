unit Dext.Core.ValueConverters;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  System.Variants,
  System.Classes;

type
  IValueConverter = interface
    ['{D7E3C021-C021-4000-8000-000000000001}']
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
  end;

  TValueConverterRegistry = class
  private
    class var FConverters: TDictionary<string, IValueConverter>; // Key: "SourceKind:TargetKind" or specific types
    class constructor Create;
    class destructor Destroy;
    class function GetKey(ASource, ATarget: PTypeInfo): string;
  public
    class procedure RegisterConverter(ASource, ATarget: PTypeInfo; AConverter: IValueConverter); overload;
    class procedure RegisterConverter(ASourceKind, ATargetKind: TTypeKind; AConverter: IValueConverter); overload;
    class function GetConverter(ASource, ATarget: PTypeInfo): IValueConverter;
  end;

  TValueConverter = class
  public
    class function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; overload;
    class function Convert<T>(const AValue: TValue): T; overload;
    class procedure ConvertAndSet(Instance: TObject; Prop: TRttiProperty; const Value: TValue);
  end;

  // Base Converter
  TBaseConverter = class(TInterfacedObject, IValueConverter)
  public
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; virtual; abstract;
  end;

  // --- Standard Converters ---

  // Variant -> *
  TVariantToIntegerConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  TVariantToStringConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  TVariantToBooleanConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  TVariantToFloatConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  TVariantToDateTimeConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  TVariantToEnumConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  TVariantToGuidConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // Integer -> Enum
  TIntegerToEnumConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // String -> Guid
  TStringToGuidConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

implementation

{ TValueConverterRegistry }

class constructor TValueConverterRegistry.Create;
begin
  FConverters := TDictionary<string, IValueConverter>.Create;
  
  // Register Default Converters
  
  // Variant -> Primitives
  RegisterConverter(TypeInfo(Variant), TypeInfo(Integer), TVariantToIntegerConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(Int64), TVariantToIntegerConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(string), TVariantToStringConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(Boolean), TVariantToBooleanConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(Double), TVariantToFloatConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(TDateTime), TVariantToDateTimeConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(TDate), TVariantToDateTimeConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(TTime), TVariantToDateTimeConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(TGUID), TVariantToGuidConverter.Create);

  // Variant -> Kinds (Catch-all for Enums if specific type not found? No, registry needs exact match or kind match)
  // We register Variant -> tkEnumeration
  RegisterConverter(tkVariant, tkEnumeration, TVariantToEnumConverter.Create);
  
  // Integer -> Enum
  RegisterConverter(tkInteger, tkEnumeration, TIntegerToEnumConverter.Create);
  
  // String -> GUID
  RegisterConverter(TypeInfo(string), TypeInfo(TGUID), TStringToGuidConverter.Create);
end;

class destructor TValueConverterRegistry.Destroy;
begin
  FConverters.Free;
end;

class function TValueConverterRegistry.GetKey(ASource, ATarget: PTypeInfo): string;
begin
  Result := Format('%p:%p', [Pointer(ASource), Pointer(ATarget)]);
end;

class procedure TValueConverterRegistry.RegisterConverter(ASource, ATarget: PTypeInfo; AConverter: IValueConverter);
begin
  FConverters.AddOrSetValue(GetKey(ASource, ATarget), AConverter);
end;

class procedure TValueConverterRegistry.RegisterConverter(ASourceKind, ATargetKind: TTypeKind; AConverter: IValueConverter);
begin
  // Use a special prefix for Kinds
  FConverters.AddOrSetValue(Format('K:%d:%d', [Ord(ASourceKind), Ord(ATargetKind)]), AConverter);
end;

class function TValueConverterRegistry.GetConverter(ASource, ATarget: PTypeInfo): IValueConverter;
begin
  // 1. Try Exact Match
  if not FConverters.TryGetValue(GetKey(ASource, ATarget), Result) then
  begin
    // 2. Try Kind Match
    if not FConverters.TryGetValue(Format('K:%d:%d', [Ord(ASource.Kind), Ord(ATarget.Kind)]), Result) then
    begin
      // 3. Special Case: Variant Source
      if (ASource.Kind = tkVariant) then
         FConverters.TryGetValue(Format('K:%d:%d', [Ord(tkVariant), Ord(ATarget.Kind)]), Result);
    end;
  end;
end;

{ TValueConverter }

class function TValueConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  Converter: IValueConverter;
begin
  if AValue.IsEmpty then
    Exit(TValue.Empty);

  // If types are same, return value
  if AValue.TypeInfo = ATargetType then
    Exit(AValue);

  Converter := TValueConverterRegistry.GetConverter(AValue.TypeInfo, ATargetType);
  if Converter <> nil then
    Result := Converter.Convert(AValue, ATargetType)
  else
  begin
    // Fallback: Try TValue.Cast (built-in RTTI conversion)
    try
      Result := AValue.Cast(ATargetType);
    except
      // If Cast fails, we might want to throw a better error or return default
      raise EConvertError.CreateFmt('Cannot convert %s to %s', [AValue.TypeInfo.Name, ATargetType.Name]);
    end;
  end;
end;

class function TValueConverter.Convert<T>(const AValue: TValue): T;
var
  Val: TValue;
begin
  Val := Convert(AValue, TypeInfo(T));
  Result := Val.AsType<T>;
end;

class procedure TValueConverter.ConvertAndSet(Instance: TObject; Prop: TRttiProperty; const Value: TValue);
var
  Converted: TValue;
begin
  if not Prop.IsWritable then Exit;
  
  Converted := Convert(Value, Prop.PropertyType.Handle);
  Prop.SetValue(Instance, Converted);
end;

{ TVariantToIntegerConverter }

function TVariantToIntegerConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
begin
  V := AValue.AsVariant;
  if VarIsNull(V) or VarIsEmpty(V) then
    Result := 0
  else
    Result := StrToIntDef(VarToStr(V), 0);
end;

{ TVariantToStringConverter }

function TVariantToStringConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  Result := VarToStr(AValue.AsVariant);
end;

{ TVariantToBooleanConverter }

function TVariantToBooleanConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
begin
  V := AValue.AsVariant;
  if VarIsNull(V) then Exit(False);
  
  if VarIsNumeric(V) then
    Result := Integer(V) <> 0
  else if VarIsStr(V) then
    Result := StrToBoolDef(V, False)
  else
    Result := Boolean(V);
end;

{ TVariantToFloatConverter }

function TVariantToFloatConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  Result := StrToFloatDef(VarToStr(AValue.AsVariant), 0.0);
end;

{ TVariantToDateTimeConverter }

function TVariantToDateTimeConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
begin
  V := AValue.AsVariant;
  if VarIsNull(V) then Exit(0.0);
  
  if VarIsNumeric(V) then
    Result := VarToDateTime(V)
  else
    Result := StrToDateTimeDef(VarToStr(V), 0.0);
end;

{ TVariantToEnumConverter }

function TVariantToEnumConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
  I: Integer;
begin
  V := AValue.AsVariant;
  if VarIsNumeric(V) then
  begin
    I := V;
    Result := TValue.FromOrdinal(ATargetType, I);
  end
  else
  begin
    // String to Enum
    I := GetEnumValue(ATargetType, VarToStr(V));
    if I = -1 then I := 0; // Default or Error?
    Result := TValue.FromOrdinal(ATargetType, I);
  end;
end;

{ TVariantToGuidConverter }

function TVariantToGuidConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  Result := TValue.From<TGUID>(StringToGUID(VarToStr(AValue.AsVariant)));
end;

{ TIntegerToEnumConverter }

function TIntegerToEnumConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  Result := TValue.FromOrdinal(ATargetType, AValue.AsInteger);
end;

{ TStringToGuidConverter }

function TStringToGuidConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  Result := TValue.From<TGUID>(StringToGUID(AValue.AsString));
end;

end.
