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
unit Dext.Json;

interface

uses
  System.Character,
  System.Rtti,
  System.StrUtils,
  System.SysUtils,
  System.TypInfo,
  Dext.Collections,
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Core.Activator,
  Dext.DI.Interfaces,
  Dext.Json.Types,
  Dext.Types.UUID;

type
  TJsonSettings = Dext.Json.Types.TJsonSettings;
  /// <summary>
  ///   Exception raised for errors during JSON serialization or deserialization.
  /// </summary>
  EDextJsonException = class(Exception);

  /// <summary>
  ///   Base class for all Dext JSON attributes.
  /// </summary>
  DextJsonAttribute = class abstract(TCustomAttribute)
  end;

  /// <summary>
  ///   Specifies a custom name for a field in the JSON output.
  /// </summary>
  JsonNameAttribute = class(DextJsonAttribute)
  private
    FName: string;
  public
    /// <summary>
    ///   Initializes a new instance of the JsonNameAttribute class.
    /// </summary>
    /// <param name="AName">
    ///   The custom name to be used in the JSON.
    /// </param>
    constructor Create(const AName: string);
    property Name: string read FName;
  end;

  /// <summary>
  ///   Indicates that a field should be ignored during serialization and deserialization.
  /// </summary>
  JsonIgnoreAttribute = class(DextJsonAttribute);

  /// <summary>
  ///   Specifies a custom format string for date/time fields.
  /// </summary>
  JsonFormatAttribute = class(DextJsonAttribute)
  private
    FFormat: string;
  public
    /// <summary>
    ///   Initializes a new instance of the JsonFormatAttribute class.
    /// </summary>
    /// <param name="AFormat">
    ///   The format string (e.g., 'yyyy-mm-dd').
    /// </param>
    constructor Create(const AFormat: string);
    property Format: string read FFormat;
  end;

  /// <summary>
  ///   Forces a numeric field to be serialized as a string.
  /// </summary>
  JsonStringAttribute = class(DextJsonAttribute);

  /// <summary>
  ///   Forces a string field to be serialized as a number (if possible).
  /// </summary>
  JsonNumberAttribute = class(DextJsonAttribute);

  /// <summary>
  ///   Forces a field to be serialized as a boolean.
  /// </summary>
  JsonBooleanAttribute = class(DextJsonAttribute);

  /// <summary>Deprecated alias for TCaseStyle.</summary>
  TDextCaseStyle = TCaseStyle deprecated 'Use TCaseStyle instead';

  /// <summary>Deprecated alias for TEnumStyle.</summary>
  TDextEnumStyle = TEnumStyle deprecated 'Use TEnumStyle instead';

  /// <summary>Deprecated alias for TJsonFormatting.</summary>
  TDextFormatting = TJsonFormatting deprecated 'Use TJsonFormatting instead';

  /// <summary>Deprecated alias for TDateFormat.</summary>
  TDextDateFormat = TDateFormat deprecated 'Use TDateFormat instead';

  /// <summary>
  ///   Utilities for JSON manipulation, including casing.
  /// </summary>
  TJsonUtils = record
  public
    class function ToCamelCase(const S: string): string; static;
    class function ToPascalCase(const S: string): string; static;
    class function ToSnakeCase(const S: string): string; static;
    class function ApplyCaseStyle(const S: string; Style: TCaseStyle): string; static;
  end;

  /// <summary>Deprecated alias for TJsonSettings.</summary>
  TDextSettings = TJsonSettings deprecated 'Use TJsonSettings instead';

  /// <summary>
  ///   Main entry point for JSON serialization and deserialization in Dext.
  ///   Acts as a high-level facade that uses configurable providers (drivers).
  /// </summary>
  TDextJson = class
  private
    class var FProvider: IDextJsonProvider;
    class var FDefaultSettings: TJsonSettings;
    class var FInterfaceMappings: IDictionary<string, string>;
    class function GetProvider: IDextJsonProvider; static;
    class function GetInterfaceMappings: IDictionary<string, string>; static;
  public
    /// <summary>
    ///   Registers a default implementation class for an interface type.
    ///   Used during deserialization when an interface is encountered.
    /// </summary>
    class procedure RegisterImplementation(const AInterfaceName, AImplementationName: string); static;
  public
    /// <summary>
    ///   Sets the default settings to be used for all serialization/deserialization
    ///   operations that don't explicitly provide settings.
    /// </summary>
    class procedure SetDefaultSettings(const ASettings: TJsonSettings); static;

    /// <summary>
    ///   Gets the current default settings.
    /// </summary>
    class function GetDefaultSettings: TJsonSettings; static;
    /// <summary>
    ///   Gets or sets the JSON provider (driver) to be used.
    ///   Defaults to JsonDataObjects if not set.
    /// </summary>
    class property Provider: IDextJsonProvider read GetProvider write FProvider;

    /// <summary>
    ///   Deserializes a JSON string into a value of type T using default settings.
    /// </summary>
    class function Deserialize<T>(const AJson: string): T; overload; static;

    /// <summary>
    ///   Deserializes a JSON string into a value of type T using custom settings.
    /// </summary>
    class function Deserialize<T>(const AJson: string; const ASettings: TJsonSettings): T; overload; static;

    /// <summary>
    ///   Deserializes a JSON string into a TValue based on the provided type info.
    /// </summary>
    class function Deserialize(AType: PTypeInfo; const AJson: string): TValue; overload; static;

    /// <summary>
    ///   Deserializes a JSON string into a TValue based on the provided type info with custom settings.
    /// </summary>
    class function Deserialize(AType: PTypeInfo; const AJson: string; const ASettings: TJsonSettings): TValue; overload; static;

    /// <summary>
    ///   Deserializes a JSON string into a record TValue.
    /// </summary>
    class function DeserializeRecord(AType: PTypeInfo; const AJson: string): TValue; static;

    /// <summary>
    ///   Serializes a value of type T into a JSON string using default settings.
    /// </summary>
    class function Serialize<T>(const AValue: T): string; overload; static;

    /// <summary>
    ///   Serializes a value of type T into a JSON string using custom settings.
    /// </summary>
    class function Serialize<T>(const AValue: T; const ASettings: TJsonSettings): string; overload; static;

    /// <summary>
    ///   Serializes a TValue into a JSON string using default settings.
    /// </summary>
    class function Serialize(const AValue: TValue): string; overload; static;

    /// <summary>
    ///   Serializes a TValue into a JSON string using custom settings.
    /// </summary>
    class function Serialize(const AValue: TValue; const ASettings: TJsonSettings): string; overload; static;
  end;

  /// <summary>
  ///   Internal class responsible for complex conversion logic.
  ///   Manages type mapping, RTTI, attributes, and List/Dictionary conversion.
  /// </summary>
  TDextSerializer = class
  private
    FSettings: TJsonSettings;
    function CreateInstanceForDeserialization(AType: PTypeInfo): TValue;
  protected
    function GetFieldName(AField: TRttiField): string;
    function GetRecordName(ARttiType: TRttiType): string;
    function SerializeRecord(const AValue: TValue): IDextJsonObject;
    function SerializeObject(const AValue: TValue): IDextJsonObject;
    function ShouldSkipField(AField: TRttiField; const AValue: TValue): Boolean;

    function JsonToValue(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
    function ValueToJson(const AValue: TValue): IDextJsonObject;

    function DeserializeArray(AJson: IDextJsonArray; AType: PTypeInfo): TValue;
    function DeserializeList(AJson: IDextJsonArray; AType: PTypeInfo): TValue;
    function SerializeArray(const AValue: TValue): IDextJsonArray;
    function SerializeList(const AValue: TValue): IDextJsonArray;

    function IsListType(AType: PTypeInfo): Boolean;
    function IsArrayType(AType: PTypeInfo): Boolean;
    function IsDictionaryType(AType: PTypeInfo): Boolean;
    function GetListElementType(AType: PTypeInfo): PTypeInfo;
    function GetArrayElementType(AType: PTypeInfo): PTypeInfo;
    function GetDictionaryKeyType(AType: PTypeInfo): PTypeInfo;
    function GetDictionaryValueType(AType: PTypeInfo): PTypeInfo;
    function DeserializeDictionary(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
    function ApplyCaseStyle(const AName: string): string;
  public
    constructor Create(const ASettings: TJsonSettings);
    function Deserialize<T>(const AJson: string): T;
    function DeserializeRecord(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
    function DeserializeObject(AJson: IDextJsonObject; AType: PTypeInfo; AInstance: TObject = nil): TValue;
    function Serialize<T>(const AValue: T): string; overload;
    function Serialize(const AValue: TValue): string; overload;
    procedure Populate(AInstance: TObject; const AJson: string);
  end;

  /// <summary>
  ///   Fluent builder for programmatic construction of JSON objects and arrays.
  /// </summary>
  TJsonBuilder = class
  private
    type
      TBuilderNode = class
        NodeType: (ntObject, ntArray);
        Parent: TBuilderNode;
        Key: string;
        JsonObj: IDextJsonObject;
        JsonArr: IDextJsonArray;
      end;
  private
    FRoot: TBuilderNode;
    FCurrent: TBuilderNode;
    FNodeStack: IList<TBuilderNode>;
    function GetCurrentObject: IDextJsonObject;
    function GetCurrentArray: IDextJsonArray;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Adds a string value to the current object.</summary>
    function Add(const AKey, AValue: string): TJsonBuilder; overload;

    /// <summary>Adds an integer value to the current object.</summary>
    function Add(const AKey: string; AValue: Integer): TJsonBuilder; overload;

    /// <summary>Adds a 64-bit integer value to the current object.</summary>
    function Add(const AKey: string; AValue: Int64): TJsonBuilder; overload;

    /// <summary>Adds a floating-point value to the current object.</summary>
    function Add(const AKey: string; AValue: Double): TJsonBuilder; overload;

    /// <summary>Adds a boolean value to the current object.</summary>
    function Add(const AKey: string; AValue: Boolean): TJsonBuilder; overload;

    /// <summary>Starts a nested object with the given key.</summary>
    function AddObject(const AKey: string): TJsonBuilder;

    /// <summary>Ends the current nested object and returns to the parent.</summary>
    function EndObject: TJsonBuilder;

    /// <summary>Starts a nested array with the given key.</summary>
    function AddArray(const AKey: string): TJsonBuilder;

    /// <summary>Ends the current nested array and returns to the parent.</summary>
    function EndArray: TJsonBuilder;

    /// <summary>Adds a string value to the current array.</summary>
    function AddValue(const AValue: string): TJsonBuilder; overload;

    /// <summary>Adds an integer value to the current array.</summary>
    function AddValue(AValue: Integer): TJsonBuilder; overload;

    /// <summary>Adds a boolean value to the current array.</summary>
    function AddValue(AValue: Boolean): TJsonBuilder; overload;

    /// <summary>Returns the built JSON as a compact string.</summary>
    function ToString: string; override;

    /// <summary>Returns the built JSON as an indented string.</summary>
    function ToIndentedString: string;

    /// <summary>Creates a new JSON builder instance.</summary>
    class function NewBuilder: TJsonBuilder;
  end;

/// <summary>
///   Returns a default TJsonSettings instance for fluent configuration.
///   Usage: JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive);
/// </summary>
function JsonSettings: TJsonSettings;

/// <summary>
///   Sets the default JSON settings globally. Shorthand for TDextJson.SetDefaultSettings.
///   Usage: JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive);
/// </summary>
procedure JsonDefaultSettings(const ASettings: TJsonSettings);

implementation

uses
  System.Classes,
  System.DateUtils,
  System.Variants,
  Dext.Core.Reflection,
  Dext.Core.DateUtils,
  Dext.Json.Driver.DextJsonDataObjects; // Default driver

const
  ValueField = 'value';

function FloatToJsonString(Value: Extended): string;
begin
  Result := FloatToStr(Value, TFormatSettings.Invariant);
end;

function JsonStringToFloat(const Value: string): Extended;
var
  CleanValue: string;
begin

  if Pos(',', Value) > 0 then
    CleanValue := StringReplace(Value, ',', '.', [rfReplaceAll])
  else
    CleanValue := Value;

  Result := StrToFloatDef(CleanValue, 0, TFormatSettings.Invariant);
end;

function IntToJsonString(Value: Int64): string;
begin
  Result := IntToStr(Value);
end;

function JsonStringToInt(const Value: string): Int64;
begin
  Result := StrToInt64Def(Value, 0);
end;

{ TJsonUtils }

class function TJsonUtils.ToCamelCase(const S: string): string;
begin
  if S.IsEmpty then Exit('');
  Result := S;
  Result[1] := Result[1].ToLower;
end;

class function TJsonUtils.ToPascalCase(const S: string): string;
begin
  if S.Length > 0 then
    Result := UpperCase(S[1]) + Copy(S, 2, MaxInt)
  else
    Result := S;
end;

class function TJsonUtils.ToSnakeCase(const S: string): string;
var
  C: Char;
  i: Integer;
  SB: TStringBuilder;
begin
  if S.IsEmpty then Exit('');

  SB := TStringBuilder.Create;
  try
    for i := 0 to S.Length - 1 do
    begin
      C := S.Chars[i];
      if C.IsUpper then
      begin
        if i > 0 then
          SB.Append('_');
        SB.Append(C.ToLower);
      end
      else
        SB.Append(C);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TJsonUtils.ApplyCaseStyle(const S: string; Style: TCaseStyle): string;
begin
  case Style of
    TCaseStyle.CaseInherit,
    TCaseStyle.Unchanged: Result := S;
    TCaseStyle.CamelCase: Result := ToCamelCase(S);
    TCaseStyle.PascalCase: Result := ToPascalCase(S);
    TCaseStyle.SnakeCase: Result := ToSnakeCase(S);
  else
    Result := S;
  end;
end;

{ JsonNameAttribute }

constructor JsonNameAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

{ JsonFormatAttribute }

constructor JsonFormatAttribute.Create(const AFormat: string);
begin
  inherited Create;
  FFormat := AFormat;
end;

{ JsonSettings global function }

function JsonSettings: TJsonSettings;
begin
  Result := TJsonSettings.Default;
end;

{ JsonDefaultSettings global procedure }

procedure JsonDefaultSettings(const ASettings: TJsonSettings);
begin
  TDextJson.SetDefaultSettings(ASettings);
end;

{ TDextJson }

class function TDextJson.Deserialize<T>(const AJson: string): T;
begin
  Result := Deserialize<T>(AJson, GetDefaultSettings);
end;

class function TDextJson.Deserialize<T>(const AJson: string; const ASettings: TJsonSettings): T;
var
  Serializer: TDextSerializer;
begin
  Serializer := TDextSerializer.Create(ASettings);
  try
    Result := Serializer.Deserialize<T>(AJson);
  finally
    Serializer.Free;
  end;
end;

class function TDextJson.Deserialize(AType: PTypeInfo; const AJson: string): TValue;
begin
  // Use RTTI to call the appropriate generic method
  case AType.Kind of
    tkInteger:
      Result := TValue.From<Integer>(Deserialize<Integer>(AJson));
    tkInt64:
      Result := TValue.From<Int64>(Deserialize<Int64>(AJson));
    tkFloat:
      if (AType = TypeInfo(TDateTime)) or (AType = TypeInfo(TDate)) or (AType = TypeInfo(TTime)) then
        Result := TValue.From<TDateTime>(Deserialize<TDateTime>(AJson))
      else
        Result := TValue.From<Double>(Deserialize<Double>(AJson));
    tkString, tkLString, tkWString, tkUString:
      Result := TValue.From<string>(Deserialize<string>(AJson));
    tkEnumeration:
      if AType = TypeInfo(Boolean) then
        Result := TValue.From<Boolean>(Deserialize<Boolean>(AJson))
      else
        Result := TValue.FromOrdinal(AType, Deserialize<Integer>(AJson));
    tkRecord:
      Result := DeserializeRecord(AType, AJson);
    tkClass:
      Result := Deserialize(AType, AJson, GetDefaultSettings);
    else
      raise EDextJsonException.CreateFmt('Unsupported type for deserialization: %s', [AType.NameFld.ToString]);
  end;
end;

class function TDextJson.Deserialize(AType: PTypeInfo; const AJson: string; const ASettings: TJsonSettings): TValue;
var
  JsonNode: IDextJsonNode;
  Serializer: TDextSerializer;
begin
  Serializer := TDextSerializer.Create(ASettings);
  try
    JsonNode := TDextJson.Provider.Parse(AJson);

    if JsonNode.GetNodeType = jntObject then
    begin
      if AType.Kind = tkRecord then
        Result := Serializer.DeserializeRecord(JsonNode as IDextJsonObject, AType)
      else if AType.Kind = tkClass then
        Result := Serializer.DeserializeObject(JsonNode as IDextJsonObject, AType)
      else
        raise EDextJsonException.CreateFmt('Unsupported type for deserialization with settings: %s', [AType.NameFld.ToString]);
    end
    else if JsonNode.GetNodeType = jntArray then
    begin
      if Serializer.IsArrayType(AType) then
        Result := Serializer.DeserializeArray(JsonNode as IDextJsonArray, AType)
      else if Serializer.IsListType(AType) then
        Result := Serializer.DeserializeList(JsonNode as IDextJsonArray, AType)
      else
        raise EDextJsonException.Create('JSON is an array but target type is not array/list');
    end
    else
      raise EDextJsonException.Create('JSON root must be Object or Array');
  finally
    Serializer.Free;
  end;
end;

class function TDextJson.DeserializeRecord(AType: PTypeInfo; const AJson: string): TValue;
var
  JsonNode: IDextJsonNode;
  Serializer: TDextSerializer;
begin
  Serializer := TDextSerializer.Create(GetDefaultSettings);
  try
    JsonNode := TDextJson.Provider.Parse(AJson);
    if JsonNode.GetNodeType = jntObject then
      Result := Serializer.DeserializeRecord(JsonNode as IDextJsonObject, AType)
    else
      raise EDextJsonException.Create('JSON root must be Object for record deserialization');
  finally
    Serializer.Free;
  end;
end;

class function TDextJson.Serialize<T>(const AValue: T): string;
begin
  Result := Serialize<T>(AValue, GetDefaultSettings);
end;

class function TDextJson.Serialize<T>(const AValue: T; const ASettings: TJsonSettings): string;
var
  Serializer: TDextSerializer;
begin
  Serializer := TDextSerializer.Create(ASettings);
  try
    Result := Serializer.Serialize<T>(AValue);
  finally
    Serializer.Free;
  end;
end;

class function TDextJson.Serialize(const AValue: TValue): string;
begin
  Result := Serialize(AValue, GetDefaultSettings);
end;

class function TDextJson.Serialize(const AValue: TValue; const ASettings: TJsonSettings): string;
var
  Serializer: TDextSerializer;
begin
  Serializer := TDextSerializer.Create(ASettings);
  try
    Result := Serializer.Serialize(AValue);
  finally
    Serializer.Free;
  end;
end;

function GetUUIDString(const V: TValue): string;
var
  U: TUUID;
begin
  V.ExtractRawData(@U);
  Result := U.ToString;
end;

function GetGUIDString(const V: TValue): string;
var
  G: TGUID;
begin
  V.ExtractRawData(@G);
  Result := GUIDToString(G);
end;

{ TDextSerializer }

constructor TDextSerializer.Create(const ASettings: TJsonSettings);
begin
  inherited Create;
  FSettings := ASettings;
end;

function TDextSerializer.CreateInstanceForDeserialization(AType: PTypeInfo): TValue;
begin
  if FSettings.FServiceProvider <> nil then
    Result := TActivator.CreateInstance(FSettings.FServiceProvider, AType)
  else
    Result := TActivator.CreateInstanceRttiOnly(AType);
end;

function TDextSerializer.Deserialize<T>(const AJson: string): T;
var
  JsonNode: IDextJsonNode;
  Value: TValue;
begin
  JsonNode := TDextJson.Provider.Parse(AJson);
  try
    if JsonNode.GetNodeType = jntObject then
      Value := JsonToValue(JsonNode as IDextJsonObject, TypeInfo(T))
    else if JsonNode.GetNodeType = jntArray then
    begin
      // Handle root array deserialization
      if IsArrayType(TypeInfo(T)) then
        Value := DeserializeArray(JsonNode as IDextJsonArray, TypeInfo(T))
      else if IsListType(TypeInfo(T)) then
        Value := DeserializeList(JsonNode as IDextJsonArray, TypeInfo(T))
      else
        raise EDextJsonException.Create('JSON is an array but target type is not array/list');
    end
    else
      raise EDextJsonException.Create('JSON root must be Object or Array');

    Result := Value.AsType<T>;
  finally
    // Interface reference counting handles destruction
  end;
end;

function TDextSerializer.DeserializeObject(AJson: IDextJsonObject; AType: PTypeInfo; AInstance: TObject): TValue;
var
  ActualPropName: string;
  Attr: TCustomAttribute;
  Found: Boolean;
  Handler: IPropertyHandler;
  I: Integer;
  Instance: TObject;
  Key: string;
  LowerProp: string;
  Node: IDextJsonNode;
  Prop: TRttiProperty;
  PropName: string;
  RttiType: TRttiType;
  Val: TValue;
  ExistingPropVal: TValue;
  ExistingObj: TObject;
begin
  if AJson = nil then
    Exit(TValue.Empty);

  if AInstance <> nil then
  begin
    Instance := AInstance;
    Result := Instance;
  end
  else
  begin
    Result := CreateInstanceForDeserialization(AType);
    Instance := Result.AsObject;
  end;

  if Instance = nil then
    Exit;

  RttiType := TReflection.GetMetadata(AType).RttiType;
  try
    for Prop in RttiType.GetProperties do
    begin
      if (Prop.Visibility <> mvPublic) and (Prop.Visibility <> mvPublished) then
        Continue;

      if not Prop.IsWritable then
        Continue;

      PropName := ApplyCaseStyle(Prop.Name);

      // Check JsonName
      for Attr in Prop.GetAttributes do
        if Attr is JsonNameAttribute then
        begin
          PropName := JsonNameAttribute(Attr).Name;
          Break;
        end;

      ActualPropName := PropName;
      Found := AJson.Contains(PropName);

      if (not Found) and FSettings.FCaseInsensitive then
      begin
         // Simple scan
        LowerProp := LowerCase(PropName);
        for I := 0 to AJson.GetCount - 1 do
        begin
          Key := AJson.GetName(I);
          if LowerCase(Key) = LowerProp then
          begin
            ActualPropName := Key;
            Found := True;
            Break;
          end;
        end;
      end;

      if not Found then
        Continue;

      Node := AJson.GetNode(ActualPropName);
      if Node <> nil then
      begin
        Handler := TReflection.GetHandler(AType, Prop.Name);
        Val := TValue.Empty;
        case Node.GetNodeType of
          jntString:
            Val := TValue.From<string>(Node.AsString);
          jntNumber:
            begin
              case Prop.PropertyType.TypeKind of
                tkInteger:
                  Val := TValue.FromOrdinal(Prop.PropertyType.Handle, Node.AsInt64);
                tkInt64:
                  Val := Node.AsInt64;
                tkFloat:
                  if Prop.PropertyType.Handle = TypeInfo(TDateTime) then
                    Val := ISO8601ToDate(Node.AsString)
                  else
                    Val := TValue.From<Double>(Node.AsDouble);
                tkRecord:
                  if TReflection.IsSmartProp(Prop.PropertyType.Handle) then
                    Val := TValue.From<Double>(Node.AsDouble)
                  else
                    Val := TValue.Empty;
              else
                Val := TValue.Empty;
              end;
            end;
          jntBoolean:
            Val := TValue.From<Boolean>(Node.AsBoolean);
          jntObject:
            begin
              if (Prop.PropertyType.TypeKind = tkClass) or (Prop.PropertyType.TypeKind = tkInterface) then
              begin
                // Check if the property already holds an instance (e.g. created in constructor).
                // If so, populate it in-place instead of creating a new one.
                ExistingPropVal := Prop.GetValue(Instance);
                ExistingObj := nil;
                if not ExistingPropVal.IsEmpty then
                begin
                  if Prop.PropertyType.TypeKind = tkClass then
                    ExistingObj := ExistingPropVal.AsObject
                  else if (Prop.PropertyType.TypeKind = tkInterface) and
                          (ExistingPropVal.AsInterface <> nil) then
                    ExistingObj := ExistingPropVal.AsInterface as TObject;
                end;

                if ExistingObj <> nil then
                begin
                  // Populate the existing instance in-place using its actual runtime type.
                  // Leave Val = Empty so Handler.SetValue is skipped — the reference is already correct.
                  DeserializeObject(Node as IDextJsonObject,
                    TReflection.Context.GetType(ExistingObj.ClassType).Handle, ExistingObj);
                end
                else
                  Val := DeserializeObject(Node as IDextJsonObject, Prop.PropertyType.Handle);
              end
              else if (Prop.PropertyType.TypeKind = tkRecord) then
                Val := DeserializeRecord(Node as IDextJsonObject, Prop.PropertyType.Handle)
              else if IsDictionaryType(Prop.PropertyType.Handle) then
                Val := DeserializeDictionary(Node as IDextJsonObject, Prop.PropertyType.Handle)
              else
                Val := TValue.Empty;
            end;
          jntArray:
            begin
              if IsArrayType(Prop.PropertyType.Handle) then
                Val := DeserializeArray(Node as IDextJsonArray, Prop.PropertyType.Handle)
              else if IsListType(Prop.PropertyType.Handle) then
                Val := DeserializeList(Node as IDextJsonArray, Prop.PropertyType.Handle)
              else
                Val := TValue.Empty;
            end;
        else
          Val := TValue.Empty;
        end;

        if not Val.IsEmpty then
        begin
          if Handler <> nil then
            Handler.SetValue(Instance, Val)
          else
            Prop.SetValue(Instance, Val);
        end;
      end;
    end;
  except
    if AInstance = nil then
      Instance.Free;
    raise;
  end;
end;

function TDextSerializer.DeserializeRecord(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
var
  Field: TRttiField;
  FieldName: string;
  I: Integer;
  Node: IDextJsonNode;
  RttiType: TRttiType;
  Val: TValue;
  FieldPtr: ^IInterface;
begin
  if AType = TypeInfo(TGUID) then
    Exit(TValue.From<TGUID>(StringToGUID(AJson.GetString(ValueField))));
  if AType = TypeInfo(TUUID) then
    Exit(TValue.From<TUUID>(TUUID.FromString(AJson.GetString(ValueField))));

  TValue.Make(nil, AType, Result);
  RttiType := TReflection.GetMetadata(AType).RttiType;

  for Field in RttiType.GetFields do
  begin
    if ShouldSkipField(Field, Result) then
      Continue;

    FieldName := GetFieldName(Field);
    Node := AJson.GetNode(FieldName);

    // Case-insensitive fallback for records:
    if ((Node = nil) or Node.IsNull) and (FSettings.FCaseInsensitive or FSettings.FSmartRecordMapping) then
    begin
      for I := 0 to AJson.GetCount - 1 do
      begin
        if SameText(AJson.GetName(I), FieldName) then
        begin
          Node := AJson.GetNode(AJson.GetName(I));
          Break;
        end;
      end;
    end;

    if (Node = nil) or Node.IsNull then
      Continue;

    Val := TValue.Empty; // Reset for each field

    case Node.GetNodeType of
      jntString: Val := TValue.From<string>(Node.AsString);
      jntNumber:
        begin
          if (Field.FieldType.Handle = TypeInfo(Integer)) then
            Val := TValue.From<Integer>(Node.AsInteger)
          else if (Field.FieldType.Handle = TypeInfo(Int64)) then
            Val := TValue.From<Int64>(Node.AsInt64)
          else
            Val := TValue.From<Double>(Node.AsDouble);
        end;
      jntBoolean: Val := TValue.From<Boolean>(Node.AsBoolean);
      jntNull: Val := TValue.Empty;
      jntObject:
        begin
          if (Field.FieldType.TypeKind = tkClass) then
            Val := DeserializeObject(Node as IDextJsonObject, Field.FieldType.Handle)
          else if (Field.FieldType.TypeKind = tkRecord) then
            Val := DeserializeRecord(Node as IDextJsonObject, Field.FieldType.Handle)
          else if (Field.FieldType.TypeKind = tkInterface) then
            Val := DeserializeObject(Node as IDextJsonObject, Field.FieldType.Handle)
          else
            Val := TValue.Empty;
        end;
      jntArray:
        begin
          if IsArrayType(Field.FieldType.Handle) then
            Val := DeserializeArray(Node as IDextJsonArray, Field.FieldType.Handle)
          else if IsListType(Field.FieldType.Handle) then
            Val := DeserializeList(Node as IDextJsonArray, Field.FieldType.Handle)
          else
            Val := TValue.Empty;
        end;
      else Val := TValue.Empty;
    end;

    if not Val.IsEmpty then
    begin
      if (Field.FieldType <> nil) and (Field.FieldType.TypeKind = tkInterface) then
      begin
        FieldPtr := Pointer(PByte(Result.GetReferenceToRawData) + Field.Offset);
        FieldPtr^ := Val.AsInterface;
      end
      else
        TReflection.SetValue(Result.GetReferenceToRawData, Field, Val);
    end;
  end;
end;

function TDextSerializer.GetFieldName(AField: TRttiField): string;
var
  Attribute: TCustomAttribute;
  RttiType: TRttiType;
begin
  for Attribute in AField.GetAttributes do
    if Attribute is JsonNameAttribute then
      Exit(JsonNameAttribute(Attribute).Name);

  Result := AField.Name;

  // Standard Dext Convention for Records:
  // If field starts with 'F' and it is a record, we assume it is a storage field
  // and strip the 'F' to match the intended property name in JSON.
  RttiType := AField.Parent;
  if (RttiType <> nil) and (RttiType.IsRecord) and (FSettings.FSmartRecordMapping) then
  begin
    if (Result.Length > 1) and (Result.Chars[0] = 'F') then
    begin
      Result := Result.Substring(1);
    end;
  end;
  
  Result := ApplyCaseStyle(Result);
end;

function TDextSerializer.GetRecordName(ARttiType: TRttiType): string;
var
  Attribute: TCustomAttribute;
begin
  for Attribute in ARttiType.GetAttributes do
  begin
    if Attribute is JsonNameAttribute then
      Exit(JsonNameAttribute(Attribute).Name);
  end;
  Result := '';
end;

function TDextSerializer.JsonToValue(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
var
  Arr: IDextJsonArray;
  DtStr: string;
  DtVal: TDateTime;
begin
  if AType.Kind = tkRecord then
  begin
    if AType = TypeInfo(TGUID) then
      Result := TValue.From<TGUID>(StringToGUID(AJson.GetString(ValueField)))
    else if AType = TypeInfo(TUUID) then
      Result := TValue.From<TUUID>(TUUID.FromString(AJson.GetString(ValueField)))
    else
      Result := DeserializeRecord(AJson, AType);
  end
  else if AType.Kind = tkClass then
  begin
    Result := DeserializeObject(AJson, AType);
  end
  else if IsArrayType(AType) then
  begin
    if AJson.Contains('value') then
    begin
      Arr := AJson.GetArray('value');
      if Arr <> nil then
        Result := DeserializeArray(Arr, AType)
      else
        Result := TValue.Empty;
    end
    else
      Result := TValue.Empty;
  end
  else if IsListType(AType) then
  begin
    if AJson.Contains('value') then
    begin
      Arr := AJson.GetArray('value');
      if Arr <> nil then
        Result := DeserializeList(Arr, AType)
      else
        Result := TValue.Empty;
    end
    else
      Result := TValue.Empty;
  end
  else if IsDictionaryType(AType) then
  begin
    Result := DeserializeDictionary(AJson, AType);
  end
  else if AJson.Contains(ValueField) then
  begin
    case AType.Kind of
      tkInteger:
        Result := TValue.From<Integer>(AJson.GetInteger(ValueField));

      tkInt64:
        Result := TValue.From<Int64>(AJson.GetInt64(ValueField));

      tkFloat:
        begin
          if (AType = TypeInfo(TDateTime)) or
             (AType = TypeInfo(TDate)) or
             (AType = TypeInfo(TTime)) then
          begin
            DtStr := AJson.GetString(ValueField);
            if TryParseCommonDate(DtStr, DtVal) then
              Result := TValue.From<TDateTime>(DtVal)
            else
              Result := TValue.From<TDateTime>(0);
          end
          else
            Result := TValue.From<Double>(AJson.GetDouble(ValueField));
        end;

      tkString, tkLString, tkWString, tkUString:
        Result := TValue.From<string>(AJson.GetString(ValueField));

      tkEnumeration:
        begin
          if AType = TypeInfo(Boolean) then
            Result := TValue.From<Boolean>(AJson.GetBoolean(ValueField))
          else
            Result := TValue.FromOrdinal(AType, GetEnumValue(AType, AJson.GetString(ValueField)));
        end;

      else
        Result := TValue.Empty;
    end;
  end
  else
    Result := TValue.Empty;
end;

function TDextSerializer.Serialize<T>(const AValue: T): string;
var
  JsonNode: IDextJsonNode;
begin
  // Check if root is array or list
  if IsArrayType(TypeInfo(T)) then
    JsonNode := SerializeArray(TValue.From<T>(AValue))
  else if IsListType(TypeInfo(T)) then
    JsonNode := SerializeList(TValue.From<T>(AValue))
  else
    JsonNode := ValueToJson(TValue.From<T>(AValue));

  if FSettings.Formatting = TJsonFormatting.Indented then
    Result := JsonNode.ToJson(True)
  else
    Result := JsonNode.ToJson(False);
end;

function TDextSerializer.Serialize(const AValue: TValue): string;
var
  JsonNode: IDextJsonNode;
begin
  // Check if root is array or list
  if IsArrayType(AValue.TypeInfo) then
    JsonNode := SerializeArray(AValue)
  else if IsListType(AValue.TypeInfo) then
    JsonNode := SerializeList(AValue)
  else
    JsonNode := ValueToJson(AValue);

  if FSettings.Formatting = TJsonFormatting.Indented then
    Result := JsonNode.ToJson(True)
  else
    Result := JsonNode.ToJson(False);
end;

function TDextSerializer.SerializeRecord(const AValue: TValue): IDextJsonObject;
var
  Attr: TCustomAttribute;
  CustomFormat: string;
  Field: TRttiField;
  FieldName: string;
  FieldValue: TValue;
  ForceNumber: Boolean;
  ForceString: Boolean;
  HasCustomFormat: Boolean;
  NestedRecord: IDextJsonObject;
  NumValue: Double;
  RttiType: TRttiType;
  Unwrapped: TValue;
begin
  if AValue.TypeInfo = TypeInfo(TGUID) then
  begin
    Result := TDextJson.Provider.CreateObject;
    Result.SetString(ValueField, GetGUIDString(AValue));
    Exit;
  end;

  if AValue.TypeInfo = TypeInfo(TUUID) then
  begin
    Result := TDextJson.Provider.CreateObject;
    Result.SetString(ValueField, GetUUIDString(AValue));
    Exit;
  end;

  Result := TDextJson.Provider.CreateObject;
  RttiType := TReflection.GetMetadata(AValue.TypeInfo).RttiType;

  for Field in RttiType.GetFields do
  begin
    if ShouldSkipField(Field, AValue) then
      Continue;

    FieldName := GetFieldName(Field);
    FieldValue := Field.GetValue(AValue.GetReferenceToRawData);

    // Smart Properties Support: Unwrap Prop<T>
    if (FieldValue.Kind = tkRecord) and (FieldValue.TypeInfo <> nil) and
       TReflection.IsSmartProp(FieldValue.TypeInfo) then
    begin
      if TReflection.TryUnwrapProp(FieldValue, Unwrapped) then
        FieldValue := Unwrapped;
    end;

    // Handle null/empty values (e.g. Nullable without value)
    if FieldValue.IsEmpty then
    begin
      if not FSettings.FIgnoreNullValues then
        Result.SetNull(FieldName);
      Continue;
    end;

    HasCustomFormat := False;
    CustomFormat := '';

    for Attr in Field.GetAttributes do
    begin
      if Attr is JsonFormatAttribute then
      begin
        HasCustomFormat := True;
        CustomFormat := JsonFormatAttribute(Attr).Format;
        Break;
      end;
    end;

    if (Field.FieldType.Handle = TypeInfo(TGUID)) or (FieldValue.TypeInfo = TypeInfo(TGUID)) then
    begin
      Result.SetString(FieldName, GetGUIDString(FieldValue));
      Continue;
    end;

    if (Field.FieldType.Handle = TypeInfo(TUUID)) or (FieldValue.TypeInfo = TypeInfo(TUUID)) then
    begin
      Result.SetString(FieldName, GetUUIDString(FieldValue));
      Continue;
    end;

    if (FieldValue.TypeInfo.Kind = tkEnumeration) and
       (FieldValue.TypeInfo <> TypeInfo(Boolean)) then
    begin
      case FSettings.EnumStyle of
        TEnumStyle.AsString:
          Result.SetString(FieldName, GetEnumName(FieldValue.TypeInfo, FieldValue.AsOrdinal));
        TEnumStyle.AsNumber:
          Result.SetInteger(FieldName, FieldValue.AsOrdinal);
      end;
      Continue;
    end;

    case FieldValue.TypeInfo.Kind of
      tkInteger, tkInt64:
        begin
          ForceString := False;
          for Attr in Field.GetAttributes do
            if Attr is JsonStringAttribute then
              ForceString := True;

          if ForceString then
            Result.SetString(FieldName, IntToJsonString(FieldValue.AsInt64))
          else
            Result.SetInt64(FieldName, FieldValue.AsInt64);
        end;

      tkFloat:
        begin
        if (FieldValue.TypeInfo = TypeInfo(TDateTime)) or
           (FieldValue.TypeInfo = TypeInfo(TDate)) or
           (FieldValue.TypeInfo = TypeInfo(TTime)) then
          begin
            if HasCustomFormat then
              Result.SetString(FieldName, FormatDateTime(CustomFormat, FieldValue.AsExtended))
            else
              case FSettings.DateFormatStyle of
                TDateFormat.ISO8601:
                  Result.SetString(FieldName, FormatDateTime(FSettings.DateFormat, FieldValue.AsExtended));
                TDateFormat.UnixTimestamp:
                  Result.SetInt64(FieldName, DateTimeToUnix(FieldValue.AsExtended));
                TDateFormat.CustomFormat:
                  Result.SetString(FieldName, FormatDateTime(FSettings.DateFormat, FieldValue.AsExtended));
              end;
          end
          else
          begin
            ForceString := False;
            for Attr in Field.GetAttributes do
              if Attr is JsonStringAttribute then
                ForceString := True;

            if ForceString then
              Result.SetString(FieldName, FloatToJsonString(FieldValue.AsExtended))
            else
              Result.SetDouble(FieldName, FieldValue.AsExtended);
          end;
        end;

      tkString, tkLString, tkWString, tkUString:
        begin
          ForceNumber := False;
          for Attr in Field.GetAttributes do
            if Attr is JsonNumberAttribute then
              ForceNumber := True;

          if ForceNumber then
          begin
            NumValue := JsonStringToFloat(FieldValue.AsString);
            Result.SetDouble(FieldName, NumValue);
          end
          else
          begin
            Result.SetString(FieldName, FieldValue.AsString);
          end;
        end;

      tkEnumeration:
        begin
          if FieldValue.TypeInfo = TypeInfo(Boolean) then
          begin
            ForceString := False;
            for Attr in Field.GetAttributes do
              if Attr is JsonStringAttribute then
                ForceString := True;

            if ForceString then
              Result.SetString(FieldName, BoolToStr(FieldValue.AsBoolean, True).ToLower)
            else
              Result.SetBoolean(FieldName, FieldValue.AsBoolean);
          end
          else
            Result.SetString(FieldName, GetEnumName(FieldValue.TypeInfo, FieldValue.AsOrdinal));
        end;

      tkRecord:
        begin
          NestedRecord := SerializeRecord(FieldValue);
          Result.SetObject(FieldName, NestedRecord);
        end;

      tkInterface, tkClass:
        begin
          if IsListType(Field.FieldType.Handle) then
            Result.SetArray(FieldName, SerializeList(FieldValue))
          else if (Field.FieldType.Handle.Kind = tkClass) then
            Result.SetObject(FieldName, SerializeObject(FieldValue))
          else
            // Fallback for other interfaces or complex types
            Result.SetObject(FieldName, SerializeObject(FieldValue));
        end;

      tkDynArray:
        begin
          Result.SetArray(FieldName, SerializeArray(FieldValue));
        end;
    end;
  end;
end;

function TDextSerializer.SerializeObject(const AValue: TValue): IDextJsonObject;
var
  Attr: TCustomAttribute;
  Handler: IPropertyHandler;
  LTypeInfo: PTypeInfo;
  LTypeKind: TTypeKind;
  NestedRecord: IDextJsonObject;
  Obj: TObject;
  Prop: TRttiProperty;
  PropName: string;
  PropValue: TValue;
  RttiType: TRttiType;
  ShouldSkip: Boolean;
  Unwrapped: TValue;
begin
  Result := TDextJson.Provider.CreateObject;

  if AValue.IsEmpty then
    Exit;

  Obj := AValue.AsObject;
  if Obj = nil then
    Exit;

  RttiType := TReflection.GetMetadata(Obj.ClassInfo).RttiType;

  for Prop in RttiType.GetProperties do
  begin
    // Skip non-public/published properties
    if (Prop.Visibility <> mvPublic) and (Prop.Visibility <> mvPublished) then
      Continue;

    // Issue #108: Skip properties declared by TObject or TInterfacedObject.
    // These are Delphi internal properties (e.g. 'refCount') used for reference
    // counting and memory management -- they must never appear in JSON output.
    if (Prop.Parent <> nil) and
       ((Prop.Parent.Name = 'TObject') or (Prop.Parent.Name = 'TInterfacedObject')) then
      Continue;

    // Skip if has JsonIgnore attribute
    ShouldSkip := False;
    for Attr in Prop.GetAttributes do
    begin
      if (Attr is JsonIgnoreAttribute) or (Attr.ClassName = 'NotMappedAttribute') then
      begin
        ShouldSkip := True;
        Break;
      end;
    end;

    if ShouldSkip then
      Continue;

    PropName := ApplyCaseStyle(Prop.Name);

    // Check for JsonName attribute
    for Attr in Prop.GetAttributes do
      if Attr is JsonNameAttribute then
      begin
        PropName := JsonNameAttribute(Attr).Name;
        Break;
      end;

    Handler := TReflection.GetHandler(Obj.ClassInfo, Prop.Name);
    if Handler <> nil then
      PropValue := Handler.GetValue(Pointer(Obj))
    else
      PropValue := Prop.GetValue(Pointer(Obj));

    LTypeKind := PropValue.Kind;
    LTypeInfo := PropValue.TypeInfo;

    // Smart Properties Support: Unwrap Prop<T>
    if (LTypeKind = tkRecord) and (LTypeInfo <> nil) and
       TReflection.IsSmartProp(LTypeInfo) then
    begin
      if TReflection.TryUnwrapProp(PropValue, Unwrapped) then
      begin
        PropValue := Unwrapped;
        LTypeKind := PropValue.Kind;
        LTypeInfo := PropValue.TypeInfo;
      end;
    end;

    // Handle null/empty values
    if PropValue.IsEmpty then
    begin
      if not FSettings.FIgnoreNullValues then
        Result.SetNull(PropName);
      Continue;
    end;

    // Serialize based on property type
    case LTypeKind of
      tkInteger, tkInt64:
        Result.SetInt64(PropName, PropValue.AsInt64);

      tkFloat:
        begin
          if (LTypeInfo = TypeInfo(TDateTime)) or
             (LTypeInfo = TypeInfo(TDate)) or
             (LTypeInfo = TypeInfo(TTime)) then
            Result.SetString(PropName, FormatDateTime(FSettings.DateFormat, PropValue.AsExtended))
          else
            Result.SetDouble(PropName, PropValue.AsExtended);
        end;

      tkString, tkLString, tkWString, tkUString:
        Result.SetString(PropName, PropValue.AsString);

      tkEnumeration:
        begin
          if LTypeInfo = TypeInfo(Boolean) then
            Result.SetBoolean(PropName, PropValue.AsBoolean)
          else
            Result.SetString(PropName, GetEnumName(LTypeInfo, PropValue.AsOrdinal));
        end;

      tkRecord:
        begin
          if LTypeInfo = TypeInfo(TGUID) then
            Result.SetString(PropName, GetGUIDString(PropValue))
          else if LTypeInfo = TypeInfo(TUUID) then
            Result.SetString(PropName, GetUUIDString(PropValue))
          else
          begin
            NestedRecord := SerializeRecord(PropValue);
            Result.SetObject(PropName, NestedRecord);
          end;
        end;

      tkClass, tkInterface:
        begin
          if IsListType(LTypeInfo) then
            Result.SetArray(PropName, SerializeList(PropValue))
          else if LTypeKind = tkClass then
          begin
            if PropValue.AsObject = nil then
              Result.SetNull(PropName)
            else
              Result.SetObject(PropName, SerializeObject(PropValue));
          end
          else
            Result.SetNull(PropName);
        end;

      tkDynArray:
        Result.SetArray(PropName, SerializeArray(PropValue));
    end;
  end;
end;

function TDextSerializer.ShouldSkipField(AField: TRttiField; const AValue: TValue): Boolean;
var
  Attribute: TCustomAttribute;
  FieldValue: TValue;
  Unwrapped: TValue;
begin
  for Attribute in AField.GetAttributes do
  begin
    if Attribute is JsonIgnoreAttribute then
      Exit(True);
  end;

  if not AValue.IsEmpty then
    FieldValue := AField.GetValue(AValue.GetReferenceToRawData)
  else
    FieldValue := TValue.Empty;

  if FSettings.FIgnoreNullValues and FieldValue.IsEmpty then
    Exit(True);

  if FSettings.IgnoreDefaultValues then
  begin
    // Support Smart Properties (Prop<T>)
    if (FieldValue.Kind = tkRecord) and (FieldValue.TypeInfo <> nil) and
       TReflection.IsSmartProp(FieldValue.TypeInfo) then
    begin
      if TReflection.TryUnwrapProp(FieldValue, Unwrapped) then
        FieldValue := Unwrapped;
    end;

    case FieldValue.Kind of
      tkInteger: if FieldValue.AsInteger = 0 then Exit(True);
      tkInt64: if FieldValue.AsInt64 = 0 then Exit(True);
      tkFloat: if FieldValue.AsExtended = 0 then Exit(True);
      tkUString, tkString, tkWString, tkLString:
        if FieldValue.AsString = '' then Exit(True);
      tkEnumeration:
        if FieldValue.TypeInfo = TypeInfo(Boolean) then
        begin
          if not FieldValue.AsBoolean then Exit(True)
        end
        else if FieldValue.AsOrdinal = 0 then Exit(True);
    end;
  end;

  Result := (AField.FieldType = nil) or
            (AField.Name.StartsWith('$'));

  // Normal visibility check for classes
  // For records, we allow private fields starting with 'F' (storage fields)
  if not Assigned(AField.Parent) or not AField.Parent.IsRecord then
  begin
    if (AField.Visibility <> mvPublic) and (AField.Visibility <> mvPublished) then
      Result := True;
  end
  else
  begin
    // In records, if it's not public and doesn't start with F, skip it
    if (AField.Visibility <> mvPublic) and not AField.Name.StartsWith('F') then
      Result := True;
  end;
end;

function TDextSerializer.ValueToJson(const AValue: TValue): IDextJsonObject;
begin
  Result := TDextJson.Provider.CreateObject;

  if AValue.IsEmpty then
    Exit;

  case AValue.TypeInfo.Kind of
    tkInteger, tkInt64:
      Result.SetInt64(ValueField, AValue.AsInt64);

    tkFloat:
      begin
        if AValue.TypeInfo = TypeInfo(TDateTime) then
          Result.SetString(ValueField, FormatDateTime(FSettings.DateFormat, AValue.AsExtended))
        else
          Result.SetDouble(ValueField, AValue.AsExtended);
      end;

    tkString, tkLString, tkWString, tkUString:
      Result.SetString(ValueField, AValue.AsString);

    tkEnumeration:
      begin
        if AValue.TypeInfo = TypeInfo(Boolean) then
          Result.SetBoolean(ValueField, AValue.AsBoolean)
        else
          Result.SetString(ValueField, GetEnumName(AValue.TypeInfo, AValue.AsOrdinal));
      end;

    tkRecord:
      begin
        if AValue.TypeInfo = TypeInfo(TGUID) then
          Result.SetString(ValueField, GetGUIDString(AValue))
        else if AValue.TypeInfo = TypeInfo(TUUID) then
          Result.SetString(ValueField, GetUUIDString(AValue))
        else
          // Replace result with serialized record
          // Note: ValueToJson returns Object. If SerializeRecord returns Object, we are good.
          Result := SerializeRecord(AValue);
      end;

    // Array handling in ValueToJson is tricky because return type is IDextJsonObject
    // But SerializeArray returns IDextJsonArray.
    // We should probably change ValueToJson to return IDextJsonNode or handle arrays separately.
    // For now, let's wrap in "value" field if it's array, or change logic.
    // The original code did: Result.A[ValueField] := SerializeArray(AValue);
    tkDynArray:
      begin
        Result.SetArray(ValueField, SerializeArray(AValue));
      end;

    tkClass:
      begin
        // Distinguish between lists and regular objects
        if IsListType(AValue.TypeInfo) then
          Result.SetArray(ValueField, SerializeList(AValue))
        else
          Result := SerializeObject(AValue);
      end;
  end;
end;

class function TDextJson.GetProvider: IDextJsonProvider;
begin
  if FProvider = nil then
    FProvider := TJsonDataObjectsProvider.Create;
  Result := FProvider;
end;

class procedure TDextJson.SetDefaultSettings(const ASettings: TJsonSettings);
begin
  FDefaultSettings := ASettings;
end;

class function TDextJson.GetDefaultSettings: TJsonSettings;
begin
  // If not explicitly set, return the default
  if (FDefaultSettings.DateFormat = '') and not FDefaultSettings.FCaseInsensitive then
    Result := TJsonSettings.Default
  else
    Result := FDefaultSettings;
end;

class function TDextJson.GetInterfaceMappings: IDictionary<string, string>;
begin
  if not Assigned(FInterfaceMappings) then
    FInterfaceMappings := TCollections.CreateDictionary<string, string>;

  Result := FInterfaceMappings;
end;

class procedure TDextJson.RegisterImplementation(const AInterfaceName, AImplementationName: string);
begin
  GetInterfaceMappings.AddOrSetValue(AInterfaceName, AImplementationName);
end;

function TDextSerializer.IsArrayType(AType: PTypeInfo): Boolean;
begin
  Result := (AType.Kind = tkDynArray);
end;

function TDextSerializer.IsListType(AType: PTypeInfo): Boolean;
var
  TypeName: string;
begin
  Result := TActivator.IsListType(AType);
  if not Result and (AType <> nil) and (AType.Kind = tkInterface) then
  begin
    TypeName := string(AType.Name);
    Result := TypeName.Contains('IList<') or TypeName.Contains('IReadOnlyList<') or TypeName.Contains('IEnumerable<');
  end;
end;

function TDextSerializer.IsDictionaryType(AType: PTypeInfo): Boolean;
begin
  Result := TActivator.IsDictionaryType(AType);
end;

function TDextSerializer.GetDictionaryKeyType(AType: PTypeInfo): PTypeInfo;
begin
  Result := TActivator.GetDictionaryKeyType(AType);
end;

function TDextSerializer.GetDictionaryValueType(AType: PTypeInfo): PTypeInfo;
begin
  Result := TActivator.GetDictionaryValueType(AType);
end;

function TDextSerializer.GetArrayElementType(AType: PTypeInfo): PTypeInfo;
begin
  Result := AType.TypeData^.DynArrElType^;
end;

function TDextSerializer.GetListElementType(AType: PTypeInfo): PTypeInfo;
begin
  Result := TActivator.GetListElementType(AType);
end;

procedure TDextSerializer.Populate(AInstance: TObject; const AJson: string);
var
  Node: IDextJsonNode;
begin
  if (AInstance = nil) or (AJson = '') then Exit;
  Node := TDextJson.Provider.Parse(AJson);
  if (Node <> nil) and (Node.GetNodeType = jntObject) then
    DeserializeObject(Node as IDextJsonObject, AInstance.ClassInfo, AInstance);
end;

function TDextSerializer.DeserializeArray(AJson: IDextJsonArray; AType: PTypeInfo): TValue;
var
  Count: NativeInt;
  DynArray: Pointer;
  ElementType: PTypeInfo;
  ElementValue: TValue;
  I: Integer;
  Node: IDextJsonNode;
  P: PByte;
  ElSize: Integer;
begin
  ElementType := GetArrayElementType(AType);
  DynArray := nil;
  Count := AJson.GetCount;
  DynArraySetLength(DynArray, AType, 1, @Count); // AJson.Count -> GetCount
  ElSize := TReflection.GetMetadata(ElementType).RttiType.TypeSize;

  try
    for I := 0 to AJson.GetCount - 1 do
    begin
      Node := AJson.GetNode(I);
      case ElementType.Kind of
        tkInteger:
          ElementValue := TValue.From<Integer>(AJson.GetInteger(I));
        tkInt64:
          ElementValue := TValue.From<Int64>(AJson.GetInt64(I));
        tkFloat:
          if ElementType = TypeInfo(TDateTime) then
            ElementValue := TValue.From<TDateTime>(ISO8601ToDate(AJson.GetString(I)))
          else
            ElementValue := TValue.From<Double>(AJson.GetDouble(I));
        tkString, tkLString, tkWString, tkUString:
          ElementValue := TValue.From<string>(AJson.GetString(I));
        tkEnumeration:
          if ElementType = TypeInfo(Boolean) then
            ElementValue := TValue.From<Boolean>(AJson.GetBoolean(I))
          else
            ElementValue := TValue.FromOrdinal(ElementType, GetEnumValue(ElementType, AJson.GetString(I)));
        tkRecord:
          begin
            if ElementType = TypeInfo(TGUID) then
              ElementValue := TValue.From<TGUID>(StringToGUID(AJson.GetString(I)))
            else if ElementType = TypeInfo(TUUID) then
              ElementValue := TValue.From<TUUID>(TUUID.FromString(AJson.GetString(I)))
            else
            begin
              if (Node <> nil) and (Node.GetNodeType = jntObject) then
                ElementValue := DeserializeRecord(Node as IDextJsonObject, ElementType)
              else
                ElementValue := TValue.Empty;
            end;
          end;
        tkClass:
          begin
            if (Node <> nil) and (Node.GetNodeType = jntObject) then
               ElementValue := DeserializeObject(Node as IDextJsonObject, ElementType)
            else
               ElementValue := TValue.Empty;
          end;
        tkDynArray:
          begin
            if (Node <> nil) and (Node.GetNodeType = jntArray) then
               ElementValue := DeserializeArray(Node as IDextJsonArray, ElementType)
            else
               ElementValue := TValue.Empty;
          end;
      else
        ElementValue := TValue.Empty;
      end;

      if not ElementValue.IsEmpty then
      begin
        P := PByte(DynArray) + (I * ElSize);
        System.CopyArray(P, ElementValue.GetReferenceToRawData, ElementType, 1);
      end;
    end;

    TValue.Make(@DynArray, AType, Result);
    // The local DynArray pointer holds a reference. TValue.Make creates another (increments refcount).
    // We must clear the local reference so that only the TValue holds usage.
    DynArrayClear(DynArray, AType);
  except
    if DynArray <> nil then
      DynArrayClear(DynArray, AType);
    raise;
  end;
end;

function TDextSerializer.DeserializeList(AJson: IDextJsonArray; AType: PTypeInfo): TValue;
var
  ActualRttiType: TRttiType;
  AddMethod: TRttiMethod;
  Collection: ICollection;
  ElementType: PTypeInfo;
  ElementValue: TValue;
  I: Integer;
  InstObj: TObject;
  Intf: TRttiInterfaceType;
  Obj: TObject;
  Method: TRttiMethod;
  Node: IDextJsonNode;
  OwnsProp: TRttiProperty;
  RttiType: TRttiType;
  StrictValue: TValue;
  TargetInst: TValue;
begin
  // TODO : Refactory and optimize
  try
    ElementType := GetListElementType(AType);
    if ElementType = nil then
      raise EDextJsonException.CreateFmt('Could not determine element type for %s', [AType.NameFld.ToString]);

    // Instantiate via Activator (Handles DI, Fallbacks and Factory)
    Result := CreateInstanceForDeserialization(AType);

    RttiType := TReflection.GetMetadata(AType).RttiType;

    // Ensure the list owns its objects if they are classes
    if (ElementType.Kind = tkClass) then
    begin
       if Result.Kind = tkInterface then
       begin
         if Supports(Result.AsInterface, ICollection, Collection) then
           Collection.OwnsObjects := True;
       end
       else if Result.Kind = tkClass then
       begin
         // Try fetching via RTTI directly to avoid reference counting premature destruction
         OwnsProp := RttiType.GetProperty('OwnsObjects');
         if (OwnsProp <> nil) and (OwnsProp.PropertyType.Handle = TypeInfo(Boolean)) then
           OwnsProp.SetValue(Result.AsObject, True);
       end;
    end;

    InstObj := nil;
    if Result.Kind = tkInterface then
    begin
      try
        InstObj := Result.AsInterface as TObject;
      except
        InstObj := nil;
      end;
    end
    else if Result.Kind = tkClass then
      InstObj := Result.AsObject;

    if Assigned(InstObj) then
      ActualRttiType := TReflection.Context.GetType(InstObj.ClassType)
    else
      ActualRttiType := RttiType;

    AddMethod := nil;

    // First try concrete instance type
    if ActualRttiType is TRttiInstanceType then
    begin
      for Method in ActualRttiType.GetMethods do
        if (Method.Name = 'Add') and (Length(Method.GetParameters) = 1) then
        begin
          AddMethod := Method;
          Break;
        end;
    end;

    // Fallback to interface hierarchy
    if not Assigned(AddMethod) and (RttiType is TRttiInterfaceType) then
    begin
      Intf := TRttiInterfaceType(RttiType);
      while Intf <> nil do
      begin
        for Method in Intf.GetMethods do
          if (Method.Name = 'Add') and (Length(Method.GetParameters) = 1) then
          begin
            AddMethod := Method;
            Break;
          end;
        if Assigned(AddMethod) then Break;
        if Intf.BaseType is TRttiInterfaceType then
          Intf := TRttiInterfaceType(Intf.BaseType)
        else
          Intf := nil;
      end;
    end;

    if not Assigned(AddMethod) then
      raise EDextJsonException.CreateFmt('Could not find Add method for list type %s', [AType.NameFld.ToString]);

    try
      for I := 0 to AJson.GetCount - 1 do
      begin
        Node := AJson.GetNode(I);
        if (Node <> nil) and (Node.GetNodeType = jntObject) then
        begin
          if (ElementType.Kind = tkClass) or (ElementType.Kind = tkInterface) then
            ElementValue := DeserializeObject(Node as IDextJsonObject, ElementType)
          else
            ElementValue := DeserializeRecord(Node as IDextJsonObject, ElementType);
        end
        else
        begin
          case ElementType.Kind of
            tkInteger: ElementValue := TValue.From<Integer>(AJson.GetInteger(I));
            tkInt64: ElementValue := TValue.From<Int64>(AJson.GetInt64(I));
            tkFloat: ElementValue := TValue.From<Double>(AJson.GetDouble(I));
            tkString, tkLString, tkWString, tkUString:
              ElementValue := TValue.From<string>(AJson.GetString(I));
            tkEnumeration:
              if ElementType = TypeInfo(Boolean) then
                ElementValue := TValue.From<Boolean>(AJson.GetBoolean(I))
              else
                ElementValue := TValue.Empty;
            tkRecord:
              if ElementType = TypeInfo(TGUID) then
                ElementValue := TValue.From<TGUID>(StringToGUID(AJson.GetString(I)))
              else if ElementType = TypeInfo(TUUID) then
                ElementValue := TValue.From<TUUID>(TUUID.FromString(AJson.GetString(I)))
              else
                ElementValue := TValue.Empty;
            tkDynArray:
              begin
                if (Node <> nil) and (Node.GetNodeType = jntArray) then
                   ElementValue := DeserializeArray(Node as IDextJsonArray, ElementType)
                else
                   ElementValue := TValue.Empty;
              end;
            else
              ElementValue := TValue.Empty;
          end;
        end;

        if not ElementValue.IsEmpty then
        begin
          if Assigned(InstObj) and (AddMethod.Parent.IsInstance) then
            TargetInst := InstObj
          else
            TargetInst := Result;

          StrictValue := ElementValue;
          if (ElementType.Kind = tkClass) and (StrictValue.AsObject <> nil) then
          begin
            Obj := StrictValue.AsObject;
            TValue.Make(@Obj, ElementType, StrictValue);
          end;

          AddMethod.Invoke(TargetInst, [StrictValue]);
        end;
      end;
    finally
    end;

    Exit(Result);
  finally
  end;
end;

function TDextSerializer.DeserializeDictionary(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
var
  ActualRttiType: TRttiType;
  AddMethod: TRttiMethod;
  I: Integer;
  InstObj: TObject;
  Intf: TRttiInterfaceType;
  KeyName: string;
  KeyType, ValueType: PTypeInfo;
  KeyVal, ValVal: TValue;
  Method: TRttiMethod;
  Node: IDextJsonNode;
  RttiType: TRttiType;
  TargetInst: TValue;
begin
  try
    KeyType := GetDictionaryKeyType(AType);
    ValueType := GetDictionaryValueType(AType);

    if (KeyType = nil) or (ValueType = nil) then
      raise EDextJsonException.CreateFmt('Could not determine dictionary types for %s', [string(AType^.Name)]);

    // Instantiate via Activator
    Result := CreateInstanceForDeserialization(AType);

    RttiType := TReflection.GetMetadata(AType).RttiType;

    InstObj := nil;
    if Result.Kind = tkInterface then
    begin
      try
        InstObj := Result.AsInterface as TObject;
      except
        InstObj := nil;
      end;
    end
    else if Result.Kind = tkClass then
      InstObj := Result.AsObject;

    if Assigned(InstObj) then
      ActualRttiType := TReflection.Context.GetType(InstObj.ClassType)
    else
      ActualRttiType := RttiType;

    AddMethod := nil;

    // First try concrete instance type
    if ActualRttiType is TRttiInstanceType then
    begin
      for Method in ActualRttiType.GetMethods do
        if ((Method.Name = 'Add') or (Method.Name = 'AddOrSetValue')) and (Length(Method.GetParameters) = 2) then
        begin
          AddMethod := Method;
          Break;
        end;
    end;

    // Fallback to interface hierarchy
    if not Assigned(AddMethod) and (RttiType is TRttiInterfaceType) then
    begin
      Intf := TRttiInterfaceType(RttiType);
      while Intf <> nil do
      begin
        for Method in Intf.GetMethods do
          if ((Method.Name = 'Add') or (Method.Name = 'AddOrSetValue')) and (Length(Method.GetParameters) = 2) then
          begin
            AddMethod := Method;
            Break;
          end;
        if Assigned(AddMethod) then Break;
        if Intf.BaseType is TRttiInterfaceType then
          Intf := TRttiInterfaceType(Intf.BaseType)
        else
          Intf := nil;
      end;
    end;

    if not Assigned(AddMethod) then
      raise EDextJsonException.CreateFmt('Could not find Add method for dictionary type %s', [string(AType^.Name)]);

    for I := 0 to AJson.GetCount - 1 do
    begin
      KeyName := AJson.GetName(I);

      // Key conversion
      case KeyType.Kind of
        tkUString, tkString, tkWString, tkLString: KeyVal := TValue.From<string>(KeyName);
        tkInteger: KeyVal := TValue.From<Integer>(StrToIntDef(KeyName, 0));
        tkInt64: KeyVal := TValue.From<Int64>(StrToInt64Def(KeyName, 0));
        else KeyVal := TValue.Empty;
      end;

      if KeyVal.IsEmpty then Continue;

      // Value conversion
      Node := AJson.GetNode(KeyName);
      if (Node <> nil) and (Node.GetNodeType = jntObject) then
      begin
        if (ValueType.Kind = tkClass) or (ValueType.Kind = tkInterface) then
          ValVal := DeserializeObject(Node as IDextJsonObject, ValueType)
        else if ValueType.Kind = tkRecord then
          ValVal := DeserializeRecord(Node as IDextJsonObject, ValueType)
        else ValVal := TValue.Empty;
      end
      else if (Node <> nil) and (Node.GetNodeType = jntArray) then
      begin
        if IsArrayType(ValueType) then ValVal := DeserializeArray(Node as IDextJsonArray, ValueType)
        else if IsListType(ValueType) then ValVal := DeserializeList(Node as IDextJsonArray, ValueType)
        else ValVal := TValue.Empty;
      end
      else if (Node <> nil) then
      begin
        case ValueType.Kind of
          tkInteger: ValVal := TValue.From<Integer>(Node.AsInteger);
          tkInt64: ValVal := TValue.From<Int64>(Node.AsInt64);
          tkFloat: ValVal := TValue.From<Double>(Node.AsDouble);
          tkString, tkLString, tkWString, tkUString: ValVal := TValue.From<string>(Node.AsString);
          tkEnumeration:
            if ValueType = TypeInfo(Boolean) then ValVal := TValue.From<Boolean>(Node.AsBoolean)
            else ValVal := TValue.Empty;
          else ValVal := TValue.Empty;
        end;
      end;

      if not ValVal.IsEmpty then
      begin
        if Assigned(InstObj) and (AddMethod.Parent.IsInstance) then
          TargetInst := InstObj
        else
          TargetInst := Result;

        AddMethod.Invoke(TargetInst, [KeyVal, ValVal]);
      end;
    end;
  finally
  end;
end;

function TDextSerializer.SerializeArray(const AValue: TValue): IDextJsonArray;
var
  ElementType: PTypeInfo;
  I, Count: Integer;
  ElementValue: TValue;
begin
  Result := TDextJson.Provider.CreateArray;

  ElementType := GetArrayElementType(AValue.TypeInfo);
  Count := AValue.GetArrayLength;

  for I := 0 to Count - 1 do
  begin
    ElementValue := AValue.GetArrayElement(I);

    case ElementType.Kind of
      tkInteger:
        Result.Add(ElementValue.AsInteger);
      tkInt64:
        Result.Add(ElementValue.AsInt64);
      tkFloat:
        if ElementType = TypeInfo(TDateTime) then
          Result.Add(FormatDateTime(FSettings.DateFormat, ElementValue.AsExtended))
        else
          Result.Add(ElementValue.AsExtended);
      tkString, tkLString, tkWString, tkUString:
        Result.Add(ElementValue.AsString);
      tkEnumeration:
        if ElementType = TypeInfo(Boolean) then
          Result.Add(ElementValue.AsBoolean)
        else
          Result.Add(GetEnumName(ElementType, ElementValue.AsOrdinal));
      tkRecord:
        if ElementType = TypeInfo(TGUID) then
          Result.Add(GetGUIDString(ElementValue))
        else if ElementType = TypeInfo(TUUID) then
          Result.Add(GetUUIDString(ElementValue))
        else
          Result.Add(SerializeRecord(ElementValue));
      tkClass:
        begin
          if ElementValue.AsObject = nil then
            Result.AddNull
          else
            Result.Add(SerializeObject(ElementValue));
        end;
      tkDynArray:
        Result.Add(SerializeArray(ElementValue));
    else
      Result.AddNull;
    end;
  end;
end;

function TDextSerializer.SerializeList(const AValue: TValue): IDextJsonArray;
var
  Count: Integer;
  CountMethod, GetItemMethod: TRttiMethod;
  CountProp: TRttiProperty;
  ElementValue: TValue;
  I: Integer;
  Instance: TObject;
  IntfValue: IInterface;
  RttiType: TRttiType;
begin
  Result := TDextJson.Provider.CreateArray;
  if AValue.IsEmpty then Exit;

  RttiType := TActivator.GetRttiContext.GetType(AValue.TypeInfo);

  // For interfaces, we need to get the interface value
  if AValue.Kind = tkInterface then
  begin
    IntfValue := AValue.AsInterface;
    if IntfValue = nil then Exit;

    // Try to get Count via GetCount method instead of property
    CountMethod := RttiType.GetMethod('GetCount');
    if not Assigned(CountMethod) then Exit;

    Count := CountMethod.Invoke(AValue, []).AsInteger;

    // Get the GetItem method
    GetItemMethod := RttiType.GetMethod('GetItem');
    if not Assigned(GetItemMethod) then Exit;

    for I := 0 to Count - 1 do
    begin
      ElementValue := GetItemMethod.Invoke(AValue, [I]);

      if ElementValue.IsEmpty then
      begin
        Result.AddNull;
        Continue;
      end;

      case ElementValue.TypeInfo.Kind of
        tkRecord:
          if ElementValue.TypeInfo = TypeInfo(TGUID) then
            Result.Add(GetGUIDString(ElementValue))
          else if ElementValue.TypeInfo = TypeInfo(TUUID) then
            Result.Add(GetUUIDString(ElementValue))
          else
            Result.Add(SerializeRecord(ElementValue));
        tkClass:
          begin
            if ElementValue.AsObject = nil then
              Result.AddNull
            else
              Result.Add(SerializeObject(ElementValue));
          end;
        tkDynArray:
          Result.Add(SerializeArray(ElementValue));
        tkInteger, tkInt64:
          Result.Add(ElementValue.AsInt64);
        tkFloat:
          Result.Add(ElementValue.AsExtended);
        tkString, tkLString, tkWString, tkUString:
          Result.Add(ElementValue.AsString);
        tkEnumeration:
          if ElementValue.TypeInfo = TypeInfo(Boolean) then
            Result.Add(ElementValue.AsBoolean)
          else
            Result.Add(GetEnumName(ElementValue.TypeInfo, ElementValue.AsOrdinal));
      else
        Result.AddNull;
      end;
    end;
  end
  else if AValue.Kind = tkClass then
  begin
    // For classes, use the original RTTI approach
    Instance := AValue.AsObject;
    if Instance = nil then Exit;

    CountProp := RttiType.GetProperty('Count');
    if not Assigned(CountProp) then Exit;

    Count := CountProp.GetValue(Instance).AsInteger;

    GetItemMethod := RttiType.GetMethod('GetItem');
    if not Assigned(GetItemMethod) then
      GetItemMethod := RttiType.GetMethod('Items');

    if Assigned(GetItemMethod) then
    begin
      for I := 0 to Count - 1 do
      begin
        ElementValue := GetItemMethod.Invoke(Instance, [I]);

        case ElementValue.TypeInfo.Kind of
          tkRecord:
            if ElementValue.TypeInfo = TypeInfo(TGUID) then
              Result.Add(GetGUIDString(ElementValue))
            else if ElementValue.TypeInfo = TypeInfo(TUUID) then
              Result.Add(GetUUIDString(ElementValue))
            else
              Result.Add(SerializeRecord(ElementValue));
          tkClass:
            begin
              if ElementValue.AsObject = nil then
                Result.AddNull
              else
                Result.Add(SerializeObject(ElementValue));
            end;
          tkDynArray:
            Result.Add(SerializeArray(ElementValue));
          tkInteger, tkInt64:
            Result.Add(ElementValue.AsInt64);
          tkFloat:
            Result.Add(ElementValue.AsExtended);
          tkString, tkLString, tkWString, tkUString:
            Result.Add(ElementValue.AsString);
          tkEnumeration:
            if ElementValue.TypeInfo = TypeInfo(Boolean) then
              Result.Add(ElementValue.AsBoolean)
            else
              Result.Add(GetEnumName(ElementValue.TypeInfo, ElementValue.AsOrdinal));
        else
          Result.AddNull;
        end;
      end;
    end;
  end;
end;

function TDextSerializer.ApplyCaseStyle(const AName: string): string;
begin
  Result := TJsonUtils.ApplyCaseStyle(AName, FSettings.CaseStyle);
end;

{ TJsonBuilder }

constructor TJsonBuilder.Create;
begin
  inherited Create;
  FNodeStack := TCollections.CreateList<TBuilderNode>;

  FRoot := TBuilderNode.Create;
  FRoot.NodeType := ntObject;
  FRoot.JsonObj := TDextJson.Provider.CreateObject;
  FRoot.Parent := nil;

  FCurrent := FRoot;
  FNodeStack.Add(FRoot);
end;

destructor TJsonBuilder.Destroy;
var
  Node: TBuilderNode;
begin
  for Node in FNodeStack do
    Node.Free;
  FNodeStack := nil;
  inherited;
end;
function TJsonBuilder.GetCurrentObject: IDextJsonObject;
begin
  if FCurrent.NodeType = ntObject then
    Result := FCurrent.JsonObj
  else
    raise EDextJsonException.Create('Current context is not an object');
end;

function TJsonBuilder.GetCurrentArray: IDextJsonArray;
begin
  if FCurrent.NodeType = ntArray then
    Result := FCurrent.JsonArr
  else
    raise EDextJsonException.Create('Current context is not an array');
end;

function TJsonBuilder.Add(const AKey, AValue: string): TJsonBuilder;
begin
  GetCurrentObject.SetString(AKey, AValue);
  Result := Self;
end;

function TJsonBuilder.Add(const AKey: string; AValue: Integer): TJsonBuilder;
begin
  GetCurrentObject.SetInteger(AKey, AValue);
  Result := Self;
end;

function TJsonBuilder.Add(const AKey: string; AValue: Int64): TJsonBuilder;
begin
  GetCurrentObject.SetInt64(AKey, AValue);
  Result := Self;
end;

function TJsonBuilder.Add(const AKey: string; AValue: Double): TJsonBuilder;
begin
  GetCurrentObject.SetDouble(AKey, AValue);
  Result := Self;
end;

function TJsonBuilder.Add(const AKey: string; AValue: Boolean): TJsonBuilder;
begin
  GetCurrentObject.SetBoolean(AKey, AValue);
  Result := Self;
end;

function TJsonBuilder.AddObject(const AKey: string): TJsonBuilder;
var
  NewNode: TBuilderNode;
  NewObj: IDextJsonObject;
begin
  NewObj := TDextJson.Provider.CreateObject;
  GetCurrentObject.SetObject(AKey, NewObj);

  NewNode := TBuilderNode.Create;
  NewNode.NodeType := ntObject;
  NewNode.JsonObj := NewObj;
  NewNode.Parent := FCurrent;
  NewNode.Key := AKey;

  FNodeStack.Add(NewNode);
  FCurrent := NewNode;
  Result := Self;
end;

function TJsonBuilder.EndObject: TJsonBuilder;
begin
  if FCurrent.Parent = nil then
    raise EDextJsonException.Create('Cannot end root object');

  FCurrent := FCurrent.Parent;
  Result := Self;
end;

function TJsonBuilder.AddArray(const AKey: string): TJsonBuilder;
var
  NewNode: TBuilderNode;
  NewArr: IDextJsonArray;
begin
  NewArr := TDextJson.Provider.CreateArray;
  GetCurrentObject.SetArray(AKey, NewArr);

  NewNode := TBuilderNode.Create;
  NewNode.NodeType := ntArray;
  NewNode.JsonArr := NewArr;
  NewNode.Parent := FCurrent;
  NewNode.Key := AKey;

  FNodeStack.Add(NewNode);
  FCurrent := NewNode;
  Result := Self;
end;

function TJsonBuilder.EndArray: TJsonBuilder;
begin
  if FCurrent.Parent = nil then
    raise EDextJsonException.Create('Cannot end root array');

  FCurrent := FCurrent.Parent;
  Result := Self;
end;

function TJsonBuilder.AddValue(const AValue: string): TJsonBuilder;
begin
  GetCurrentArray.Add(AValue);
  Result := Self;
end;

function TJsonBuilder.AddValue(AValue: Integer): TJsonBuilder;
begin
  GetCurrentArray.Add(AValue);
  Result := Self;
end;

function TJsonBuilder.AddValue(AValue: Boolean): TJsonBuilder;
begin
  GetCurrentArray.Add(AValue);
  Result := Self;
end;

function TJsonBuilder.ToString: string;
begin
  Result := FRoot.JsonObj.ToJson(False);
end;

function TJsonBuilder.ToIndentedString: string;
begin
  Result := FRoot.JsonObj.ToJson(True);
end;

class function TJsonBuilder.NewBuilder: TJsonBuilder;
begin
  Result := TJsonBuilder.Create;
end;

initialization

finalization
  TDextJson.FInterfaceMappings := nil;

end.

