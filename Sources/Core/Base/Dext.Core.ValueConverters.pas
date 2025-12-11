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

  // Variant -> Class (handles object pointers stored in Variant)
  TVariantToClassConverter = class(TBaseConverter)
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

  // Variant -> TBytes (BLOB support)
  TVariantToBytesConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // String -> TBytes (for text-based BLOB storage)
  TStringToBytesConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // Class -> Class (handles object pointers and inheritance)
  TClassToClassConverter = class(TBaseConverter)
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
  
  // Variant -> Class (for object pointers stored in Variant - CRITICAL for Lazy Loading)
  RegisterConverter(tkVariant, tkClass, TVariantToClassConverter.Create);
  
  // Integer -> Enum
  RegisterConverter(tkInteger, tkEnumeration, TIntegerToEnumConverter.Create);
  
  // String -> GUID
  RegisterConverter(TypeInfo(string), TypeInfo(TGUID), TStringToGuidConverter.Create);
  
  // TBytes (BLOB) support
  RegisterConverter(TypeInfo(Variant), TypeInfo(TBytes), TVariantToBytesConverter.Create);
  RegisterConverter(TypeInfo(string), TypeInfo(TBytes), TStringToBytesConverter.Create);
  
  // Class -> Class (for object references and inheritance)
  RegisterConverter(tkClass, tkClass, TClassToClassConverter.Create);
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
  Ctx: TRttiContext;
  TargetRType: TRttiType;
  TypeName: string;
  Fields: TArray<TRttiField>;
  HasValueField, ValueField: TRttiField;
  NullableInstance: Pointer;
  InnerValue: TValue;
  InnerType: PTypeInfo;
begin
  if AValue.IsEmpty then
    Exit(TValue.Empty);

  // If types are same, return value
  if AValue.TypeInfo = ATargetType then
    Exit(AValue);

  // Check if target is Nullable<T>
  if ATargetType.Kind = tkRecord then
  begin
    Ctx := TRttiContext.Create;
    TargetRType := Ctx.GetType(ATargetType);
    if TargetRType <> nil then
    begin
      TypeName := TargetRType.Name;
      
      // Check if it's a Nullable<T> by name
      if TypeName.StartsWith('Nullable<') or TypeName.StartsWith('TNullable') then
      begin
        // Find the fields
        Fields := TargetRType.GetFields;
        HasValueField := nil;
        ValueField := nil;
        
        for var Field in Fields do
        begin
          if Field.Name.ToLower.Contains('hasvalue') then
            HasValueField := Field
          else if Field.Name.ToLower = 'fvalue' then
            ValueField := Field;
        end;
        
        if (HasValueField <> nil) and (ValueField <> nil) then
        begin
          // Get the inner type from fValue field
          InnerType := ValueField.FieldType.Handle;
          
          // Convert the source value to the inner type
          InnerValue := Convert(AValue, InnerType);
          
          // Create a new Nullable<T> instance
          TValue.Make(nil, ATargetType, Result);
          NullableInstance := Result.GetReferenceToRawData;
          
          // Set the inner value
          ValueField.SetValue(NullableInstance, InnerValue);
          
          // Set HasValue to true (can be string or boolean)
          if HasValueField.FieldType.TypeKind = tkUString then
            HasValueField.SetValue(NullableInstance, 'HasValue')
          else if HasValueField.FieldType.TypeKind = tkEnumeration then
            HasValueField.SetValue(NullableInstance, True); // Standard boolean
          
          Exit;
        end;
      end;
    end;
  end;

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

{ TVariantToClassConverter }

function TVariantToClassConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
  Obj: TObject;
  TargetClass: TClass;
  VarData: PVarData;
begin
  // This is the CRITICAL converter for Lazy Loading!
  // When we do Prop.SetValue(Pointer(FParent), ChildObj) where ChildObj is TObject,
  // Delphi RTTI automatically converts TObject to Variant.
  // This converter extracts the object pointer from the Variant and validates it.
  
  V := AValue.AsVariant;
  
  // Check if Variant is null/empty
  if VarIsNull(V) or VarIsEmpty(V) then
    Exit(TValue.From<TObject>(nil));
  
  // Get target class
  if ATargetType.Kind <> tkClass then
    raise EConvertError.CreateFmt('Target type %s is not a class', [ATargetType.Name]);
    
  TargetClass := ATargetType.TypeData.ClassType;
  
  // Extract object pointer from Variant
  // When an object is stored in a Variant, it's stored as a pointer in VarData
  VarData := @V;
  
  // Check if Variant contains an object pointer (varUnknown or custom type)
  // Object pointers in Variants are typically stored as IUnknown or raw pointers
  if VarData.VType = varUnknown then
  begin
    // Try to get as IUnknown and cast
    Obj := TObject(VarData.VUnknown);
  end
  else
  begin
    // Try direct pointer extraction
    // This handles cases where object is stored directly
    try
      Obj := TObject(TVarData(V).VPointer);
    except
      raise EConvertError.CreateFmt('Variant does not contain a valid object pointer', []);
    end;
  end;
  
  // Validate object is compatible with target class
  if Obj = nil then
    Exit(TValue.From<TObject>(nil));
    
  if Obj is TargetClass then
    Result := TValue.From<TObject>(Obj)
  else
    raise EConvertError.CreateFmt('Object of type %s is not compatible with %s', 
      [Obj.ClassName, TargetClass.ClassName]);
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

{ TClassToClassConverter }

function TClassToClassConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  SourceObj: TObject;
  TargetClass: TClass;
begin
  // Handle object references and inheritance
  // This is needed for Lazy Loading where we have TObject containing TAddress
  // and need to assign it to a property of type TAddress
  
  if AValue.IsEmpty then
    Exit(TValue.Empty);
    
  // Get the source object
  SourceObj := AValue.AsObject;
  
  // If nil, return nil
  if SourceObj = nil then
    Exit(TValue.From<TObject>(nil));
  
  // Get target class
  if ATargetType.Kind <> tkClass then
    raise EConvertError.CreateFmt('Target type %s is not a class', [ATargetType.Name]);
    
  TargetClass := ATargetType.TypeData.ClassType;
  
  // Check if source object is compatible with target class
  if SourceObj is TargetClass then
  begin
    // Compatible - return the object as-is wrapped in TValue
    Result := TValue.From<TObject>(SourceObj);
  end
  else
  begin
    raise EConvertError.CreateFmt('Cannot convert %s to %s (incompatible types)', 
      [SourceObj.ClassName, TargetClass.ClassName]);
  end;
end;

{ TVariantToBytesConverter }

function TVariantToBytesConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
  Bytes: TBytes;
  Str: string;
  i: Integer;
begin
  // Convert Variant to TBytes
  // This handles BLOB fields from database (usually come as Variant)
  
  V := AValue.AsVariant;
  
  // Check if null/empty
  if VarIsNull(V) or VarIsEmpty(V) then
  begin
    SetLength(Bytes, 0);
    Exit(TValue.From<TBytes>(Bytes));
  end;
  
  // Check if it's already a byte array
  if VarIsArray(V) then
  begin
    // Variant array of bytes
    SetLength(Bytes, VarArrayHighBound(V, 1) - VarArrayLowBound(V, 1) + 1);
    for i := VarArrayLowBound(V, 1) to VarArrayHighBound(V, 1) do
      Bytes[i - VarArrayLowBound(V, 1)] := Byte(V[i]);
    Result := TValue.From<TBytes>(Bytes);
  end
  else if VarIsStr(V) then
  begin
    // String -> TBytes (UTF-8 encoding)
    Str := VarToStr(V);
    Bytes := TEncoding.UTF8.GetBytes(Str);
    Result := TValue.From<TBytes>(Bytes);
  end
  else
  begin
    // Try to convert to string first, then to bytes
    Str := VarToStr(V);
    Bytes := TEncoding.UTF8.GetBytes(Str);
    Result := TValue.From<TBytes>(Bytes);
  end;
end;

{ TStringToBytesConverter }

function TStringToBytesConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  Str: string;
  Bytes: TBytes;
begin
  // Convert String to TBytes using UTF-8 encoding
  Str := AValue.AsString;
  
  if Str = '' then
  begin
    SetLength(Bytes, 0);
    Exit(TValue.From<TBytes>(Bytes));
  end;
  
  Bytes := TEncoding.UTF8.GetBytes(Str);
  Result := TValue.From<TBytes>(Bytes);
end;

end.

