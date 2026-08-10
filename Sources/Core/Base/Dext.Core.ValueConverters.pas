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
  Data.FmtBcd,
  System.Classes,
  System.DateUtils,
  System.Rtti,
  System.SyncObjs,
  System.SysUtils,
  System.TypInfo,
  System.Variants,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Core.DateUtils,
  Dext.Types.UUID;

type
  /// <summary>
  ///   Interface for value converters, defining the contract for transforming a value to a target type.
  /// </summary>
  IValueConverter = interface
    ['{D7E3C021-C021-4000-8000-000000000001}']
    
    /// <summary>Converts the provided value to the specified target type.</summary>
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
  end;

  /// <summary>
  ///   Central registry of type converters in Dext.
  ///   Allows mapping transformations between pairs of types (e.g., String -> GUID) or categories (e.g., Variant -> Enum).
  /// </summary>
  TValueConverterRegistry = class
  private
    class var FConverters: IDictionary<string, IValueConverter>; 
    class var FLock: TCriticalSection;
    class constructor Create;
    class destructor Destroy;
    class function GetKey(ASource, ATarget: PTypeInfo): string;
  public
    /// <summary>Registers a converter for an exact pair of types via PTypeInfo.</summary>
    class procedure RegisterConverter(ASource, ATarget: PTypeInfo; AConverter: IValueConverter); overload;
    /// <summary>Registers a converter for type categories (e.g., any Integer to any Enum).</summary>
    class procedure RegisterConverter(ASourceKind, ATargetKind: TTypeKind; AConverter: IValueConverter); overload;
    /// <summary>Locates the best available converter for the requested pair of types.</summary>
    class function GetConverter(ASource, ATarget: PTypeInfo): IValueConverter;
  end;

  /// <summary>
  ///   Conversion execution engine.
  ///   This class orchestrates the conversion logic, also automatically handling Smart Types (Prop<T>) and Nullables.
  /// </summary>
  TValueConverter = class
  public
    /// <summary>Converts a TValue to the specified target type.</summary>
    class function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; overload;
    /// <summary>Converts a TValue to the requested generic type T.</summary>
    class function Convert<T>(const AValue: TValue): T; overload;
    /// <summary>Converts the value and assigns it directly to an RTTI property of an instance.</summary>
    class procedure ConvertAndSet(Instance: TObject; Prop: TRttiProperty; const Value: TValue);
    /// <summary>Converts the value and assigns it directly to an RTTI field of an instance.</summary>
    class procedure ConvertAndSetField(Instance: TObject; Field: TRttiField; const Value: TValue);
  end;

  /// <summary>
  ///   Base abstract class for value converters, providing a default implementation of IValueConverter.
  /// </summary>
  TBaseConverter = class(TInterfacedObject, IValueConverter)
  public
    /// <summary>Converts the provided value to the specified target type.</summary>
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

  TVariantToDateConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  TVariantToTimeConverter = class(TBaseConverter)
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
  
  // String -> TUUID
  TStringToUUIDConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // Variant -> TUUID
  TVariantToUUIDConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // Class -> Class (handles object pointers and inheritance)
  TClassToClassConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // Float -> String (Invariant)
  TFloatToStringConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // Integer -> String (Invariant)
  TIntegerToStringConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // Boolean -> String (Invariant)
  TBooleanToStringConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  // TBcd Converters

  /// <summary>
  ///   Converts TBcd values to Currency.
  /// </summary>
  TBcdToCurrencyConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Converts TBcd values to Double/Float.
  /// </summary>
  TBcdToDoubleConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Converts TBcd values to String using invariant format settings.
  /// </summary>
  TBcdToStringConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Converts TBcd values to Integer/Int64.
  /// </summary>
  TBcdToIntegerConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Converts Variant values to TBcd.
  /// </summary>
  TVariantToBcdConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Converts String values to TBcd using invariant format settings.
  /// </summary>
  TStringToBcdConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Converts Float/Double values to TBcd.
  /// </summary>
  TFloatToBcdConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Converts Integer/Int64 values to TBcd.
  /// </summary>
  TIntegerToBcdConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Converts Currency values to TBcd.
  /// </summary>
  TCurrencyToBcdConverter = class(TBaseConverter)
    function Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue; override;
  end;

implementation

uses
  Dext.Core.Reflection;

{ TValueConverterRegistry }

class constructor TValueConverterRegistry.Create;
var
  NumericToFloat: IValueConverter;
  NumericToInt: IValueConverter;
  NumericToEnum: IValueConverter;
  FloatToStrConv: IValueConverter;
  IntToStrConv: IValueConverter;
  BoolToStrConv: IValueConverter;
begin
  FLock := System.SyncObjs.TCriticalSection.Create;
  FConverters := TCollections.CreateDictionary<string, IValueConverter>(False);
  
  // Register Default Converters
  
  // Variant -> Primitives
  RegisterConverter(TypeInfo(Variant), TypeInfo(Integer), TVariantToIntegerConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(Int64), TVariantToIntegerConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(string), TVariantToStringConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(Boolean), TVariantToBooleanConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(Double), TVariantToFloatConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(Single), TVariantToFloatConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(Extended), TVariantToFloatConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(Currency), TVariantToFloatConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(TDateTime), TVariantToDateTimeConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(TDate), TVariantToDateConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(TTime), TVariantToTimeConverter.Create);
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
 
  // String -> Primitives (Extra safety for SQLite/Web)
  RegisterConverter(TypeInfo(string), TypeInfo(Integer), TVariantToIntegerConverter.Create);
  RegisterConverter(TypeInfo(string), TypeInfo(Int64), TVariantToIntegerConverter.Create);
  RegisterConverter(TypeInfo(string), TypeInfo(Double), TVariantToFloatConverter.Create);
  RegisterConverter(TypeInfo(string), TypeInfo(TDateTime), TVariantToDateTimeConverter.Create);
  RegisterConverter(TypeInfo(string), TypeInfo(Boolean), TVariantToBooleanConverter.Create);

  // Kind-based Catch-all for Strings to Primitives
  RegisterConverter(tkUString, tkInteger, TVariantToIntegerConverter.Create);
  RegisterConverter(tkUString, tkFloat, TVariantToFloatConverter.Create);
  RegisterConverter(tkUString, tkInt64, TVariantToIntegerConverter.Create);
  RegisterConverter(tkUString, tkEnumeration, TVariantToEnumConverter.Create);
  RegisterConverter(tkString, tkInteger, TVariantToIntegerConverter.Create);
  RegisterConverter(tkString, tkFloat, TVariantToFloatConverter.Create);
  RegisterConverter(tkString, tkEnumeration, TVariantToEnumConverter.Create);

  // TUUID support
  RegisterConverter(TypeInfo(string), TypeInfo(TUUID), TStringToUUIDConverter.Create);
  RegisterConverter(TypeInfo(Variant), TypeInfo(TUUID), TVariantToUUIDConverter.Create);

  // TBcd Support
  RegisterConverter(TypeInfo(TBcd), TypeInfo(Currency), TBcdToCurrencyConverter.Create);
  RegisterConverter(TypeInfo(TBcd), TypeInfo(Double), TBcdToDoubleConverter.Create);
  RegisterConverter(TypeInfo(TBcd), TypeInfo(Single), TBcdToDoubleConverter.Create);
  RegisterConverter(TypeInfo(TBcd), TypeInfo(Extended), TBcdToDoubleConverter.Create);
  RegisterConverter(TypeInfo(TBcd), TypeInfo(string), TBcdToStringConverter.Create);
  RegisterConverter(TypeInfo(TBcd), TypeInfo(Integer), TBcdToIntegerConverter.Create);
  RegisterConverter(TypeInfo(TBcd), TypeInfo(Int64), TBcdToIntegerConverter.Create);

  RegisterConverter(TypeInfo(Variant), TypeInfo(TBcd), TVariantToBcdConverter.Create);
  RegisterConverter(TypeInfo(string), TypeInfo(TBcd), TStringToBcdConverter.Create);
  RegisterConverter(tkUString, tkRecord, TStringToBcdConverter.Create);
  RegisterConverter(TypeInfo(Double), TypeInfo(TBcd), TFloatToBcdConverter.Create);
  RegisterConverter(TypeInfo(Single), TypeInfo(TBcd), TFloatToBcdConverter.Create);
  RegisterConverter(TypeInfo(Extended), TypeInfo(TBcd), TFloatToBcdConverter.Create);
  RegisterConverter(TypeInfo(Integer), TypeInfo(TBcd), TIntegerToBcdConverter.Create);
  RegisterConverter(TypeInfo(Int64), TypeInfo(TBcd), TIntegerToBcdConverter.Create);
  RegisterConverter(TypeInfo(Currency), TypeInfo(TBcd), TCurrencyToBcdConverter.Create);

  // Numerical Kinds catch-all (ensures Double -> Currency, Integer -> Double, etc)
  NumericToFloat := TVariantToFloatConverter.Create;
  RegisterConverter(tkInteger, tkFloat, NumericToFloat);
  RegisterConverter(tkInt64, tkFloat, NumericToFloat);
  RegisterConverter(tkFloat, tkFloat, NumericToFloat);
  
  NumericToInt := TVariantToIntegerConverter.Create;
  RegisterConverter(tkFloat, tkInteger, NumericToInt);
  RegisterConverter(tkInt64, tkInteger, NumericToInt);
  RegisterConverter(tkInteger, tkInteger, NumericToInt);
  
  RegisterConverter(tkFloat, tkInt64, NumericToInt);
  RegisterConverter(tkInteger, tkInt64, NumericToInt);
  
  // Float/Integer -> Enum support
  NumericToEnum := TVariantToEnumConverter.Create;
  RegisterConverter(tkInteger, tkEnumeration, NumericToEnum);
  RegisterConverter(tkInt64, tkEnumeration, NumericToEnum);
  RegisterConverter(tkFloat, tkEnumeration, NumericToEnum);

  // Invariant String support
  FloatToStrConv := TFloatToStringConverter.Create;
  RegisterConverter(tkFloat, tkUString, FloatToStrConv);
  RegisterConverter(tkFloat, tkString, FloatToStrConv);
  
  IntToStrConv := TIntegerToStringConverter.Create;
  RegisterConverter(tkInteger, tkUString, IntToStrConv);
  RegisterConverter(tkInteger, tkString, IntToStrConv);
  RegisterConverter(tkInt64, tkUString, IntToStrConv);
  RegisterConverter(tkInt64, tkString, IntToStrConv);

  BoolToStrConv := TBooleanToStringConverter.Create;
  RegisterConverter(tkEnumeration, tkUString, BoolToStrConv);
  RegisterConverter(tkEnumeration, tkString, BoolToStrConv);
end;

class destructor TValueConverterRegistry.Destroy;
begin
  FConverters := nil;
  FLock.Free;
end;

class function TValueConverterRegistry.GetKey(ASource, ATarget: PTypeInfo): string;
begin
  Result := Format('%p:%p', [Pointer(ASource), Pointer(ATarget)]);
end;

class procedure TValueConverterRegistry.RegisterConverter(ASource, ATarget: PTypeInfo; AConverter: IValueConverter);
begin
  FLock.Enter;
  try
    FConverters.AddOrSetValue(GetKey(ASource, ATarget), AConverter);
  finally
    FLock.Leave;
  end;
end;

class procedure TValueConverterRegistry.RegisterConverter(ASourceKind, ATargetKind: TTypeKind; AConverter: IValueConverter);
begin
  FLock.Enter;
  try
    // Use a special prefix for Kinds
    FConverters.AddOrSetValue(Format('K:%d:%d', [Ord(ASourceKind), Ord(ATargetKind)]), AConverter);
  finally
    FLock.Leave;
  end;
end;

class function TValueConverterRegistry.GetConverter(ASource, ATarget: PTypeInfo): IValueConverter;
begin
  FLock.Enter;
  try
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
  finally
    FLock.Leave;
  end;
end;

{ TValueConverter }

class function TValueConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  Converter: IValueConverter;
  Meta: TTypeMetadata;
  PropInstance: Pointer;
  InnerValue: TValue;
begin
  if AValue.IsEmpty or ((AValue.Kind = tkVariant) and VarIsNull(AValue.AsVariant)) then
  begin
    // For records (Prop<T>, Nullable<T>), return default instance instead of Empty
    if ATargetType.Kind = tkRecord then
    begin
      TValue.Make(nil, ATargetType, Result);
      Exit;
    end;
    Exit(TValue.Empty);
  end;

  // Fast path: If types are same, return value directly
  if AValue.TypeInfo = ATargetType then
    Exit(AValue);

  if ATargetType = TypeInfo(Boolean) then
  begin
    case AValue.Kind of
      tkEnumeration:
        Exit(TValue.From<Boolean>(AValue.AsOrdinal <> 0));
      tkInteger:
        Exit(TValue.From<Boolean>(AValue.AsInteger <> 0));
      tkInt64:
        Exit(TValue.From<Boolean>(AValue.AsInt64 <> 0));
      tkFloat:
        Exit(TValue.From<Boolean>(AValue.AsExtended <> 0));
      tkString, tkUString, tkWString, tkLString:
        Exit(TValue.From<Boolean>(StrToBoolDef(AValue.AsString, False)));
    end;
  end;

  // Use cached metadata for Smart Types and Nullables detection
  if ATargetType.Kind = tkRecord then
  begin
    Meta := TReflection.GetMetadata(ATargetType);
    
    // Handle Nullable<T>
    if Meta.IsNullable and (Meta.ValueField <> nil) then
    begin
      // Convert the source value to the inner type
      InnerValue := Convert(AValue, Meta.InnerType);
      
      // Create a new Nullable<T> instance and ensure it's clean
      TValue.Make(nil, ATargetType, Result);
      PropInstance := Result.GetReferenceToRawData;
      // Zero-init memory to avoid garbage in managed interface fields
      FillChar(PropInstance^, Meta.RttiType.TypeSize, 0);
      
      // Set the inner value
      Meta.ValueField.SetValue(PropInstance, InnerValue);
      
      // Set HasValue to true (can be string or boolean)
      if Meta.HasValueField <> nil then
      begin
        if Meta.HasValueField.FieldType.TypeKind = tkUString then
          Meta.HasValueField.SetValue(PropInstance, 'HasValue')
        else
          Meta.HasValueField.SetValue(PropInstance, True);
      end;
      Exit;
    end
    // Handle Prop<T> (Smart Type)
    else if Meta.IsSmartProp and (Meta.ValueField <> nil) then
    begin
      // Convert raw DB value to inner type T
      InnerValue := Convert(AValue, Meta.InnerType);
      
      // Create new Prop<T> instance and ensure it's clean
      TValue.Make(nil, ATargetType, Result);
      PropInstance := Result.GetReferenceToRawData;
      // Zero-init memory to avoid garbage in managed interface fields
      FillChar(PropInstance^, Meta.RttiType.TypeSize, 0);
      
      // Set FValue
      Meta.ValueField.SetValue(PropInstance, InnerValue);
      Exit;
    end;
  end;

  // Standard conversion via registry
  Converter := TValueConverterRegistry.GetConverter(AValue.TypeInfo, ATargetType);
  if Converter <> nil then
    Result := Converter.Convert(AValue, ATargetType)
  else
  begin
    // Fallback 1: Target is String
    if ATargetType.Kind in [tkString, tkUString, tkWString] then
    begin
       // Handle special types that TValue.ToString doesn't handle well
       if AValue.TypeInfo = TypeInfo(TDateTime) then
         Result := DateTimeToStr(AValue.AsType<TDateTime>)
       else if AValue.TypeInfo = TypeInfo(TDate) then
         Result := DateToStr(AValue.AsType<TDate>)
       else if AValue.TypeInfo = TypeInfo(TTime) then
         Result := TimeToStr(AValue.AsType<TTime>)
       else if AValue.TypeInfo = TypeInfo(TGUID) then
       begin
         Result := GUIDToString(AValue.AsType<TGUID>);
       end
       else if AValue.TypeInfo = TypeInfo(TUUID) then
       begin
         Result := AValue.AsType<TUUID>().ToString;
       end
       else
         Result := AValue.ToString;
       Exit;
    end;

    // Fallback 2: Try TValue.Cast (built-in RTTI conversion)
    try
      Result := AValue.Cast(ATargetType);
    except
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

class procedure TValueConverter.ConvertAndSetField(Instance: TObject; Field: TRttiField; const Value: TValue);
var
  Converted: TValue;
begin
  if Field = nil then Exit;
  
  Converted := Convert(Value, Field.FieldType.Handle);
  Field.SetValue(Instance, Converted);
end;

{ TVariantToIntegerConverter }

function TVariantToIntegerConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
  Val64: Int64;
begin
  V := AValue.AsVariant;
  if VarIsNull(V) or VarIsEmpty(V) then
    Val64 := 0
  else if VarIsNumeric(V) then
    Val64 := V
  else
    Val64 := StrToInt64Def(VarToStr(V), 0);

  if ATargetType = TypeInfo(Int64) then
    Result := TValue.From<Int64>(Val64)
  else
    Result := TValue.From<Integer>(Integer(Val64));
end;

{ TVariantToStringConverter }

function TVariantToStringConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  if AValue.Kind in [tkFloat, tkInteger, tkInt64] then
  begin
    if AValue.Kind = tkFloat then
      Result := FloatToStr(AValue.AsExtended, TFormatSettings.Invariant)
    else
      Result := IntToStr(AValue.AsInt64);
  end
  else
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
  else if AValue.Kind = tkEnumeration then
    Result := AValue.AsOrdinal <> 0
  else
    Result := Boolean(V);
end;

{ TVariantToFloatConverter }

function TVariantToFloatConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  Val: Extended;
  V: Variant;
  S: string;
  Dt: TDateTime;
begin
  V := AValue.AsVariant;
  if VarIsNull(V) or VarIsEmpty(V) then
    Val := 0.0
  else if VarIsNumeric(V) then
    Val := V
  else
  begin
    S := VarToStr(V);
    // If it looks like a date (ISO or common), use the date parser first!
    if (S.Contains('-') or S.Contains(':') or S.Contains('/')) and (not S.StartsWith('{')) then
    begin
       if TryParseCommonDate(S, Dt) then
         Val := Dt
       else
       begin
         try
           // SQLite format: 2026-01-31 11:38:13.975
           // Try to normalize to ISO8601
           if TryISO8601ToDate(StringReplace(S, ' ', 'T', [rfReplaceAll]), Dt) then
             Val := Dt
           else
             Val := StrToFloatDef(S, 0.0, TFormatSettings.Invariant);
         except
           Val := StrToFloatDef(S, 0.0, TFormatSettings.Invariant);
         end;
       end;
    end
    else
      Val := StrToFloatDef(S, 0.0, TFormatSettings.Invariant);
  end;

  if ATargetType = TypeInfo(Currency) then
    Result := TValue.From<Currency>(Val)
  else if ATargetType = TypeInfo(Single) then
    Result := TValue.From<Single>(Val)
  else if ATargetType = TypeInfo(TDateTime) then
    Result := TValue.From<TDateTime>(Val)
  else
    Result := TValue.From<Double>(Val);
end;

{ TVariantToDateTimeConverter }

function TVariantToDateTimeConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
  Dt: TDateTime;
  S: string;
begin
  V := AValue.AsVariant;
  if VarIsNull(V) then Exit(0.0);
  
  if VarIsNumeric(V) then
    Result := VarToDateTime(V)
  else 
  begin
    S := VarToStr(V);
    if TryParseCommonDate(S, Dt) then
      Result := Dt
    else
    begin
      try
         if TryISO8601ToDate(StringReplace(S, ' ', 'T', [rfReplaceAll]), Dt) then
           Result := Dt
         else
           Result := 0.0;
      except
         Result := 0.0;
      end;
    end;
  end;
end;

{ TVariantToDateConverter }

function TVariantToDateConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
  Dt: TDateTime;
begin
  V := AValue.AsVariant;
  if VarIsNull(V) then Exit(0.0);
  
  if VarIsNumeric(V) then
    Result := TValue.From<TDate>(DateOf(VarToDateTime(V)))
  else if TryParseCommonDate(VarToStr(V), Dt) then
    Result := TValue.From<TDate>(DateOf(Dt))
  else
    Result := 0.0;
end;

{ TVariantToTimeConverter }

function TVariantToTimeConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
var
  V: Variant;
  Dt: TDateTime;
begin
  V := AValue.AsVariant;
  if VarIsNull(V) then Exit(0.0);
  
  if VarIsNumeric(V) then
    Result := TValue.From<TTime>(TimeOf(VarToDateTime(V)))
  else if TryParseCommonDate(VarToStr(V), Dt) then
    Result := TValue.From<TTime>(TimeOf(Dt))
  else
    Result := 0.0;
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
    // Compatible - return the object as-is wrapped in TValue with the correct TargetType
    TValue.Make(@SourceObj, ATargetType, Result);
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

{ TStringToUUIDConverter }

function TStringToUUIDConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  Result := TValue.From<TUUID>(TUUID.FromString(AValue.AsString));
end;

{ TVariantToUUIDConverter }

function TVariantToUUIDConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  Result := TValue.From<TUUID>(TUUID.FromString(VarToStr(AValue.AsVariant)));
end;

{ TFloatToStringConverter }

function TFloatToStringConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  if AValue.TypeInfo = TypeInfo(TDateTime) then
    Result := DateTimeToStr(AValue.AsType<TDateTime>)
  else if AValue.TypeInfo = TypeInfo(TDate) then
    Result := DateToStr(AValue.AsType<TDate>)
  else if AValue.TypeInfo = TypeInfo(TTime) then
    Result := TimeToStr(AValue.AsType<TTime>)
  else
    Result := FloatToStr(AValue.AsExtended, TFormatSettings.Invariant);
end;

{ TIntegerToStringConverter }

function TIntegerToStringConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  Result := IntToStr(AValue.AsInt64);
end;

{ TBooleanToStringConverter }

function TBooleanToStringConverter.Convert(const AValue: TValue; ATargetType: PTypeInfo): TValue;
begin
  if AValue.Kind = tkEnumeration then
  begin
    if AValue.TypeInfo = TypeInfo(Boolean) then
      Result := BoolToStr(AValue.AsBoolean, True) // Returns 'True' or 'False' (Invariant)
    else
      Result := GetEnumName(AValue.TypeInfo, AValue.AsOrdinal);
  end
  else
    Result := AValue.ToString;
end;

{ TBcdToCurrencyConverter }

function TBcdToCurrencyConverter.Convert(const AValue: TValue;
  ATargetType: PTypeInfo): TValue;
var
  Bcd: TBcd;
  Curr: Currency;
begin
  Bcd := AValue.AsType<TBcd>;
  if BcdToCurr(Bcd, Curr) then
    Result := TValue.From<Currency>(Curr)
  else
    raise EConvertError.CreateFmt(
      'Cannot convert TBcd value (%s) to Currency due to overflow or scale incompatibility.',
      [BcdToStr(Bcd, TFormatSettings.Invariant)]);
end;

{ TBcdToDoubleConverter }

function TBcdToDoubleConverter.Convert(const AValue: TValue;
  ATargetType: PTypeInfo): TValue;
begin
  Result := TValue.From<Double>(BcdToDouble(AValue.AsType<TBcd>));
end;

{ TBcdToStringConverter }

function TBcdToStringConverter.Convert(const AValue: TValue;
  ATargetType: PTypeInfo): TValue;
begin
  Result := BcdToStr(AValue.AsType<TBcd>, TFormatSettings.Invariant);
end;

{ TBcdToIntegerConverter }

function TBcdToIntegerConverter.Convert(const AValue: TValue;
  ATargetType: PTypeInfo): TValue;
var
  Bcd: TBcd;
begin
  Bcd := AValue.AsType<TBcd>;
  if ATargetType = TypeInfo(Int64) then
    Result := TValue.From<Int64>(Trunc(BcdToDouble(Bcd)))
  else
    Result := TValue.From<Integer>(Trunc(BcdToDouble(Bcd)));
end;

{ TVariantToBcdConverter }

function TVariantToBcdConverter.Convert(const AValue: TValue;
  ATargetType: PTypeInfo): TValue;
var
  V: Variant;
begin
  V := AValue.AsVariant;
  if VarIsNull(V) or VarIsEmpty(V) then
    Result := TValue.From<TBcd>(StrToBcd('0', TFormatSettings.Invariant))
  else if VarIsFMTBcd(V) then
    Result := TValue.From<TBcd>(VarToBcd(V))
  else if VarIsStr(V) then
    Result := TValue.From<TBcd>(StrToBcd(VarToStr(V), TFormatSettings.Invariant))
  else if VarIsNumeric(V) then
    Result := TValue.From<TBcd>(DoubleToBcd(Double(V)))
  else
    Result := TValue.From<TBcd>(StrToBcd(VarToStr(V), TFormatSettings.Invariant));
end;

{ TStringToBcdConverter }

function TStringToBcdConverter.Convert(const AValue: TValue;
  ATargetType: PTypeInfo): TValue;
begin
  Result := TValue.From<TBcd>(StrToBcd(AValue.AsString, TFormatSettings.Invariant));
end;

{ TFloatToBcdConverter }

function TFloatToBcdConverter.Convert(const AValue: TValue;
  ATargetType: PTypeInfo): TValue;
begin
  Result := TValue.From<TBcd>(DoubleToBcd(AValue.AsExtended));
end;

{ TIntegerToBcdConverter }

function TIntegerToBcdConverter.Convert(const AValue: TValue;
  ATargetType: PTypeInfo): TValue;
begin
  Result := TValue.From<TBcd>(IntegerToBcd(AValue.AsInt64));
end;

{ TCurrencyToBcdConverter }

function TCurrencyToBcdConverter.Convert(const AValue: TValue;
  ATargetType: PTypeInfo): TValue;
var
  Curr: Currency;
  Bcd: TBcd;
begin
  Curr := AValue.AsType<Currency>;
  if CurrToBcd(Curr, Bcd) then
    Result := TValue.From<TBcd>(Bcd)
  else
    raise EConvertError.CreateFmt('Cannot convert Currency value to TBcd.', []);
end;

end.

