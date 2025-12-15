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
  System.Generics.Collections,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Json.Types;

type
  /// <summary>
  ///   Exception raised for errors during JSON serialization or deserialization.
  /// </summary>
  EDextJsonException = class(Exception);

  /// <summary>
  ///   Base class for all Dext JSON attributes.
  /// </summary>
  DextAttribute = class abstract(TCustomAttribute);

  /// <summary>
  ///   Specifies a custom name for a field in the JSON output.
  /// </summary>
  JsonNameAttribute = class(DextAttribute)
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
  JsonIgnoreAttribute = class(DextAttribute);

  /// <summary>
  ///   Specifies a custom format string for date/time fields.
  /// </summary>
  JsonFormatAttribute = class(DextAttribute)
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
  JsonStringAttribute = class(DextAttribute);
  
  /// <summary>
  ///   Forces a string field to be serialized as a number (if possible).
  /// </summary>
  JsonNumberAttribute = class(DextAttribute);
  
  /// <summary>
  ///   Forces a field to be serialized as a boolean.
  /// </summary>
  JsonBooleanAttribute = class(DextAttribute);

  /// <summary>
  ///   Defines the casing style for JSON property names.
  /// </summary>
  TDextCaseStyle = (
    /// <summary>Keep names as they are in the record/class.</summary>
    Unchanged, 
    /// <summary>Convert to camelCase (e.g., myProperty).</summary>
    CamelCase, 
    /// <summary>Convert to PascalCase (e.g., MyProperty).</summary>
    PascalCase, 
    /// <summary>Convert to snake_case (e.g., my_property).</summary>
    SnakeCase
  );

  /// <summary>
  ///   Defines how enumerations are serialized.
  /// </summary>
  TDextEnumStyle = (
    /// <summary>Serialize as the underlying integer value.</summary>
    AsNumber, 
    /// <summary>Serialize as the string name of the enum value.</summary>
    AsString
  );

  /// <summary>
  ///   Defines JSON output formatting.
  /// </summary>
  TDextFormatting = (
    /// <summary>Compact JSON (no whitespace).</summary>
    None, 
    /// <summary>Indented JSON for readability.</summary>
    Indented
  );

  /// <summary>
  ///   Defines standard date/time formats.
  /// </summary>
  TDextDateFormat = (
    /// <summary>ISO 8601 format (e.g., "2025-11-16T11:07:37.565").</summary>
    ISO8601,        
    /// <summary>Unix timestamp (seconds since epoch).</summary>
    UnixTimestamp,  
    /// <summary>Custom format string.</summary>
    CustomFormat    
  );

  /// <summary>
  ///   Configuration settings for the JSON serializer.
  /// </summary>
  TDextSettings = record
  public
    Formatting: TDextFormatting;
    IgnoreDefaultValues: Boolean;
    IgnoreNullValues: Boolean;
    DateFormat: string;
    CaseStyle: TDextCaseStyle;
    EnumStyle: TDextEnumStyle;
    CaseInsensitive: Boolean;
    DateFormatStyle: TDextDateFormat;
    
    /// <summary>
    ///   Returns the default settings.
    /// </summary>
    class function Default: TDextSettings; static;
    
    /// <summary>
    ///   Returns settings configured for indented output.
    /// </summary>
    class function Indented: TDextSettings; static;
    
    /// <summary>
    ///   Returns a new settings instance with CamelCase enabled.
    /// </summary>
    function WithCamelCase: TDextSettings;
    
    /// <summary>
    ///   Returns a new settings instance with PascalCase enabled.
    /// </summary>
    function WithPascalCase: TDextSettings;
    
    /// <summary>
    ///   Returns a new settings instance with SnakeCase enabled.
    /// </summary>
    function WithSnakeCase: TDextSettings;
    
    /// <summary>
    ///   Returns a new settings instance with Enums serialized as strings.
    /// </summary>
    function WithEnumAsString: TDextSettings;
    
    /// <summary>
    ///   Returns a new settings instance with Enums serialized as numbers.
    /// </summary>
    function WithEnumAsNumber: TDextSettings;
    
    /// <summary>
    ///   Returns a new settings instance that ignores null values during serialization.
    /// </summary>
    function WithIgnoreNullValues: TDextSettings;
    
    /// <summary>
    ///   Returns a new settings instance with case-insensitive property matching.
    /// </summary>
    function WithCaseInsensitive: TDextSettings;
    
    /// <summary>
    ///   Returns a new settings instance using ISO 8601 date format.
    /// </summary>
    function WithISODateFormat: TDextSettings;
    
    /// <summary>
    ///   Returns a new settings instance using Unix Timestamp date format.
    /// </summary>
    function WithUnixTimestamp: TDextSettings;
    
    /// <summary>
    ///   Returns a new settings instance using a custom date format.
    /// </summary>
    function WithCustomDateFormat(const Format: string): TDextSettings;
  end;

  /// <summary>
  ///   Main entry point for JSON serialization and deserialization.
  /// </summary>
  TDextJson = class
  private
    class var FProvider: IDextJsonProvider;
    class function GetProvider: IDextJsonProvider; static;
  public
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
    class function Deserialize<T>(const AJson: string; const ASettings: TDextSettings): T; overload; static;
    
    /// <summary>
    ///   Deserializes a JSON string into a TValue based on the provided type info.
    /// </summary>
    class function Deserialize(AType: PTypeInfo; const AJson: string): TValue; overload; static;
    
    /// <summary>
    ///   Deserializes a JSON string into a TValue based on the provided type info with custom settings.
    /// </summary>
    class function Deserialize(AType: PTypeInfo; const AJson: string; const ASettings: TDextSettings): TValue; overload; static;
    
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
    class function Serialize<T>(const AValue: T; const ASettings: TDextSettings): string; overload; static;

    /// <summary>
    ///   Serializes a TValue into a JSON string using default settings.
    /// </summary>
    class function Serialize(const AValue: TValue): string; overload; static;
  end;

  /// <summary>
  ///   Internal serializer class responsible for the conversion logic.
  ///   Usually you should use TDextJson static methods instead.
  /// </summary>
  TDextSerializer = class
  private
    FSettings: TDextSettings;
  protected
  protected
    function GetFieldName(AField: TRttiField): string;
    function GetRecordName(ARttiType: TRttiType): string;
    function SerializeRecord(const AValue: TValue): IDextJsonObject;
    function ShouldSkipField(AField: TRttiField; const AValue: TValue): Boolean;

    function JsonToValue(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
    function ValueToJson(const AValue: TValue): IDextJsonObject;
    
    function DeserializeArray(AJson: IDextJsonArray; AType: PTypeInfo): TValue;
    function DeserializeList(AJson: IDextJsonArray; AType: PTypeInfo): TValue;
    function SerializeArray(const AValue: TValue): IDextJsonArray;
    function SerializeList(const AValue: TValue): IDextJsonArray;
    
    function IsListType(AType: PTypeInfo): Boolean;
    function IsArrayType(AType: PTypeInfo): Boolean;
    function GetListElementType(AType: PTypeInfo): PTypeInfo;
    function GetArrayElementType(AType: PTypeInfo): PTypeInfo;
    function ApplyCaseStyle(const AName: string): string;
  public
    constructor Create(const ASettings: TDextSettings);
    function Deserialize<T>(const AJson: string): T;
    function DeserializeRecord(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
    function Serialize<T>(const AValue: T): string; overload;
    function Serialize(const AValue: TValue): string; overload;
  end;

  /// <summary>
  ///   Fluent JSON builder for programmatic JSON construction.
  ///   Example usage:
  ///     TJsonBuilder.Create
  ///       .Add('name', 'John')
  ///       .Add('age', 30)
  ///       .AddObject('address')
  ///         .Add('city', 'NYC')
  ///       .EndObject
  ///       .AddArray('tags')
  ///         .AddValue('one')
  ///         .AddValue('two')
  ///       .EndArray
  ///       .ToString
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
    FNodeStack: TList<TBuilderNode>;
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
    class function New: TJsonBuilder;
  end;

implementation

uses
  System.DateUtils,
  System.Variants,
  Dext.Json.Driver.JsonDataObjects; // Default driver

const
  ValueField = 'value';

function FloatToJsonString(Value: Extended): string;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';
  Result := FloatToStr(Value, FormatSettings);
end;

function JsonStringToFloat(const Value: string): Extended;
var
  FormatSettings: TFormatSettings;
  CleanValue: string;
begin
  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';

  if Pos(',', Value) > 0 then
    CleanValue := StringReplace(Value, ',', '.', [rfReplaceAll])
  else
    CleanValue := Value;

  Result := StrToFloatDef(CleanValue, 0, FormatSettings);
end;

function IntToJsonString(Value: Int64): string;
begin
  Result := IntToStr(Value);
end;

function JsonStringToInt(const Value: string): Int64;
begin
  Result := StrToInt64Def(Value, 0);
end;

function TryParseISODateTime(const Value: string; out DateTime: TDateTime): Boolean;
var
  FormatSettings: TFormatSettings;
  Year, Month, Day, Hour, Min, Sec, MSec: Word;
  Parts: TArray<string>;
  DatePart, TimePart: string;
begin
  Result := False;
  FormatSettings := TFormatSettings.Create;
  FormatSettings.DateSeparator := '-';
  FormatSettings.TimeSeparator := ':';
  FormatSettings.ShortDateFormat := 'yyyy-mm-dd';
  FormatSettings.LongDateFormat := 'yyyy-mm-dd"T"hh:nn:ss.zzz';

  if Value = '' then
    Exit;

  try
    if Length(Value) >= 19 then
    begin
      DatePart := Copy(Value, 1, 10);
      TimePart := Copy(Value, 12, 12);

      Parts := DatePart.Split(['-']);
      if Length(Parts) = 3 then
      begin
        Year := StrToInt(Parts[0]);
        Month := StrToInt(Parts[1]);
        Day := StrToInt(Parts[2]);

        if (Length(TimePart) >= 8) and (TimePart[3] = ':') and (TimePart[6] = ':') then
        begin
          Hour := StrToInt(Copy(TimePart, 1, 2));
          Min := StrToInt(Copy(TimePart, 4, 2));
          Sec := StrToInt(Copy(TimePart, 7, 2));

          if (Length(TimePart) > 8) and (TimePart[9] = '.') then
            MSec := StrToInt(Copy(TimePart, 10, 3))
          else
            MSec := 0;

          DateTime := EncodeDateTime(Year, Month, Day, Hour, Min, Sec, MSec);
          Result := True;
          Exit;
        end;
      end;
    end;

    if Length(Value) = 10 then
    begin
      Parts := Value.Split(['-']);
      if Length(Parts) = 3 then
      begin
        Year := StrToInt(Parts[0]);
        Month := StrToInt(Parts[1]);
        Day := StrToInt(Parts[2]);
        DateTime := EncodeDate(Year, Month, Day);
        Result := True;
        Exit;
      end;
    end;

    DateTime := StrToDateTimeDef(Value, 0, FormatSettings);
    Result := DateTime <> 0;

  except
    Result := False;
  end;
end;

function TryParseCommonDate(const Value: string; out DateTime: TDateTime): Boolean;
var
  FormatSettings: TFormatSettings;
  Parts: TArray<string>;
  Year, Month, Day: Word;
begin
  if TryParseISODateTime(Value, DateTime) then
    Exit(True);

  FormatSettings := TFormatSettings.Create;

  FormatSettings.DateSeparator := '/';
  FormatSettings.ShortDateFormat := 'dd/mm/yyyy';
  DateTime := StrToDateTimeDef(Value, 0, FormatSettings);
  if DateTime <> 0 then
    Exit(True);

  FormatSettings.ShortDateFormat := 'mm/dd/yyyy';
  DateTime := StrToDateTimeDef(Value, 0, FormatSettings);
  if DateTime <> 0 then
    Exit(True);

  FormatSettings.ShortDateFormat := 'yyyy/mm/dd';
  DateTime := StrToDateTimeDef(Value, 0, FormatSettings);
  if DateTime <> 0 then
    Exit(True);

  Parts := Value.Split(['/', '-']);
  if Length(Parts) = 3 then
  begin
    try
      Day := StrToInt(Parts[0]);
      Month := StrToInt(Parts[1]);
      Year := StrToInt(Parts[2]);
      if (Year > 1900) and (Year < 2100) and (Month >= 1) and (Month <= 12) and (Day >= 1) and (Day <= 31) then
      begin
        DateTime := EncodeDate(Year, Month, Day);
        Exit(True);
      end;

      Month := StrToInt(Parts[0]);
      Day := StrToInt(Parts[1]);
      Year := StrToInt(Parts[2]);
      if (Year > 1900) and (Year < 2100) and (Month >= 1) and (Month <= 12) and (Day >= 1) and (Day <= 31) then
      begin
        DateTime := EncodeDate(Year, Month, Day);
        Exit(True);
      end;
    except
    end;
  end;

  Result := False;
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

{ TDextSettings }

class function TDextSettings.Default: TDextSettings;
begin
  Result.Formatting := TDextFormatting.None;
  Result.IgnoreNullValues := False;
  Result.IgnoreDefaultValues := False;
  Result.DateFormat := 'yyyy-mm-dd"T"hh:nn:ss.zzz';
  Result.DateFormatStyle := TDextDateFormat.ISO8601;
  Result.CaseStyle := TDextCaseStyle.Unchanged;
  Result.EnumStyle := TDextEnumStyle.AsNumber;
  Result.CaseInsensitive := False;
end;

class function TDextSettings.Indented: TDextSettings;
begin
  Result := Default;
  Result.Formatting := TDextFormatting.Indented;
end;

function TDextSettings.WithCamelCase: TDextSettings;
begin
  Result := Self;
  Result.CaseStyle := TDextCaseStyle.CamelCase;
end;

function TDextSettings.WithPascalCase: TDextSettings;
begin
  Result := Self;
  Result.CaseStyle := TDextCaseStyle.PascalCase;
end;

function TDextSettings.WithSnakeCase: TDextSettings;
begin
  Result := Self;
  Result.CaseStyle := TDextCaseStyle.SnakeCase;
end;

function TDextSettings.WithUnixTimestamp: TDextSettings;
begin
  Result := Self;
  Result.DateFormatStyle := TDextDateFormat.UnixTimestamp;
  Result.DateFormat := '';
end;

function TDextSettings.WithEnumAsString: TDextSettings;
begin
  Result := Self;
  Result.EnumStyle := TDextEnumStyle.AsString;
end;

function TDextSettings.WithEnumAsNumber: TDextSettings;
begin
  Result := Self;
  Result.EnumStyle := TDextEnumStyle.AsNumber;
end;

function TDextSettings.WithIgnoreNullValues: TDextSettings;
begin
  Result := Self;
  Result.IgnoreNullValues := True;
end;

function TDextSettings.WithISODateFormat: TDextSettings;
begin
  Result := Self;
  Result.DateFormatStyle := TDextDateFormat.ISO8601;
  Result.DateFormat := 'yyyy-mm-dd"T"hh:nn:ss.zzz';
end;

function TDextSettings.WithCaseInsensitive: TDextSettings;
begin
  Result := Self;
  Result.CaseInsensitive := True;
end;

function TDextSettings.WithCustomDateFormat(const Format: string): TDextSettings;
begin
  Result := Self;
  Result.DateFormatStyle := TDextDateFormat.CustomFormat;
  Result.DateFormat := Format;
end;

{ TDextJson }

class function TDextJson.Deserialize<T>(const AJson: string): T;
begin
  Result := Deserialize<T>(AJson, TDextSettings.Default);
end;

class function TDextJson.Deserialize<T>(const AJson: string; const ASettings: TDextSettings): T;
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
  // Usar RTTI para chamar o método genérico apropriado
  case AType.Kind of
    tkInteger:
      Result := TValue.From<Integer>(Deserialize<Integer>(AJson));
    tkInt64:
      Result := TValue.From<Int64>(Deserialize<Int64>(AJson));
    tkFloat:
      if AType = TypeInfo(TDateTime) then
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
    else
      raise EDextJsonException.CreateFmt('Unsupported type for deserialization: %s', [AType.NameFld.ToString]);
  end;
end;

class function TDextJson.Deserialize(AType: PTypeInfo; const AJson: string; const ASettings: TDextSettings): TValue;
var
  Serializer: TDextSerializer;
  JsonNode: IDextJsonNode;
begin
  Serializer := TDextSerializer.Create(ASettings);
  try
    JsonNode := TDextJson.Provider.Parse(AJson);
    
    if JsonNode.GetNodeType = jntObject then
    begin
      if AType.Kind = tkRecord then
        Result := Serializer.DeserializeRecord(JsonNode as IDextJsonObject, AType)
      else
        raise EDextJsonException.CreateFmt('Unsupported type for deserialization with settings: %s', [AType.NameFld.ToString]);
    end
    else
      raise EDextJsonException.Create('JSON root must be Object for record deserialization');
  finally
    Serializer.Free;
  end;
end;

class function TDextJson.DeserializeRecord(AType: PTypeInfo; const AJson: string): TValue;
var
  Serializer: TDextSerializer;
  JsonNode: IDextJsonNode;
begin
  Serializer := TDextSerializer.Create(TDextSettings.Default);
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
  Result := Serialize<T>(AValue, TDextSettings.Default);
end;

class function TDextJson.Serialize<T>(const AValue: T; const ASettings: TDextSettings): string;
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
var
  Serializer: TDextSerializer;
begin
  Serializer := TDextSerializer.Create(TDextSettings.Default);
  try
    Result := Serializer.Serialize(AValue);
  finally
    Serializer.Free;
  end;
end;

{ TDextSerializer }

constructor TDextSerializer.Create(const ASettings: TDextSettings);
begin
  inherited Create;
  FSettings := ASettings;
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

function TDextSerializer.DeserializeRecord(AJson: IDextJsonObject; AType: PTypeInfo): TValue;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  Field: TRttiField;
  FieldName: string;
  ActualFieldName: string;
  FieldValue: TValue;
  Found: Boolean;
begin
  TValue.Make(nil, AType, Result);
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(AType);

    for Field in RttiType.GetFields do
    begin
      if ShouldSkipField(Field, Result) then
        Continue;

      FieldName := GetFieldName(Field);
      ActualFieldName := FieldName;
      Found := AJson.Contains(FieldName);

      // Se não encontrou e CaseInsensitive está habilitado, buscar ignorando case
      if (not Found) and FSettings.CaseInsensitive then
      begin
        // Precisamos iterar pelas chaves do JSON para encontrar uma correspondência case-insensitive
        // Como não temos acesso direto às chaves via interface, vamos tentar variações comuns
        var LowerFieldName := LowerCase(FieldName);
        var UpperFieldName := UpperCase(FieldName);
        
        // Tentar lowercase
        if AJson.Contains(LowerFieldName) then
        begin
          ActualFieldName := LowerFieldName;
          Found := True;
        end
        // Tentar uppercase
        else if AJson.Contains(UpperFieldName) then
        begin
          ActualFieldName := UpperFieldName;
          Found := True;
        end
        // Tentar primeira letra minúscula (camelCase)
        else if Length(FieldName) > 0 then
        begin
          var CamelCaseName := LowerCase(FieldName[1]) + Copy(FieldName, 2, Length(FieldName) - 1);
          if AJson.Contains(CamelCaseName) then
          begin
            ActualFieldName := CamelCaseName;
            Found := True;
          end;
        end;
      end;

      if not Found then
        Continue;

      if Field.FieldType.Handle = TypeInfo(TGUID) then
      begin
        try
          FieldValue := TValue.From<TGUID>(StringToGUID(AJson.GetString(ActualFieldName)));
        except
          FieldValue := TValue.From<TGUID>(TGUID.Empty);
        end;
        Field.SetValue(Result.GetReferenceToRawData, FieldValue);
        Continue;
      end;

      case Field.FieldType.TypeKind of
        tkInteger:
          FieldValue := TValue.From<Integer>(AJson.GetInteger(ActualFieldName));

        tkInt64:
          FieldValue := TValue.From<Int64>(AJson.GetInt64(ActualFieldName));

        tkFloat:
          begin
            if Field.FieldType.Handle = TypeInfo(TDateTime) then
            begin
              var DateStr := AJson.GetString(ActualFieldName);
              var DateValue: TDateTime;

              if TryParseCommonDate(DateStr, DateValue) then
                FieldValue := TValue.From<TDateTime>(DateValue)
              else
                FieldValue := TValue.Empty;
            end
            else
              FieldValue := TValue.From<Double>(AJson.GetDouble(ActualFieldName));
          end;

        tkString, tkLString, tkWString, tkUString:
          begin
            var ForceNumber := False;
            for var Attr in Field.GetAttributes do
              if Attr is JsonNumberAttribute then
                ForceNumber := True;

            if ForceNumber then
            begin
              // We need to get the raw string representation or convert
              // Since we are abstracted, we can just get string and convert manually if needed,
              // or trust GetString returns the value.
              // But wait, if it's a number in JSON, GetString should return string representation.
              // Our adapters should handle this.
              FieldValue := TValue.From<string>(AJson.GetString(ActualFieldName));
            end
            else
            begin
              FieldValue := TValue.From<string>(AJson.GetString(ActualFieldName));
            end;
          end;

        tkEnumeration:
          begin
            if Field.FieldType.Handle = TypeInfo(Boolean) then
              FieldValue := TValue.From<Boolean>(AJson.GetBoolean(ActualFieldName))
            else
            begin
              case FSettings.EnumStyle of
                TDextEnumStyle.AsString:
                  begin
                    var EnumName := AJson.GetString(ActualFieldName);
                    if EnumName <> '' then
                      FieldValue := TValue.FromOrdinal(Field.FieldType.Handle,
                        GetEnumValue(Field.FieldType.Handle, EnumName))
                    else
                      FieldValue := TValue.FromOrdinal(Field.FieldType.Handle, AJson.GetInteger(ActualFieldName));
                  end;
                TDextEnumStyle.AsNumber:
                  FieldValue := TValue.FromOrdinal(Field.FieldType.Handle, AJson.GetInteger(ActualFieldName));
              end;
            end;
          end;

        tkRecord:
          begin
            var NestedJson := AJson.GetObject(ActualFieldName);
            if NestedJson <> nil then
              FieldValue := DeserializeRecord(NestedJson, Field.FieldType.Handle)
            else
              FieldValue := TValue.Empty;
          end;
      end;

      if not FieldValue.IsEmpty then
        Field.SetValue(Result.GetReferenceToRawData, FieldValue);
    end;
  finally
    Context.Free;
  end;
end;

function TDextSerializer.GetFieldName(AField: TRttiField): string;
var
  Attribute: TCustomAttribute;
begin
  for Attribute in AField.GetAttributes do
  begin
    if Attribute is JsonNameAttribute then
      Exit(JsonNameAttribute(Attribute).Name);
  end;

  Result := ApplyCaseStyle(AField.Name);
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
begin
  if AType.Kind = tkRecord then
  begin
    Result := DeserializeRecord(AJson, AType);
  end
  else if IsArrayType(AType) then
  begin
    if AJson.Contains('value') then
    begin
      var Arr := AJson.GetArray('value');
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
      var Arr := AJson.GetArray('value');
      if Arr <> nil then
        Result := DeserializeList(Arr, AType)
      else
        Result := TValue.Empty;
    end
    else
      Result := TValue.Empty;
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
          if AType = TypeInfo(TDateTime) then
            Result := TValue.From<TDateTime>(StrToDateTimeDef(AJson.GetString(ValueField), 0))
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
    
  if FSettings.Formatting = TDextFormatting.Indented then
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
    
  if FSettings.Formatting = TDextFormatting.Indented then
    Result := JsonNode.ToJson(True)
  else
    Result := JsonNode.ToJson(False);
end;

function TDextSerializer.SerializeRecord(const AValue: TValue): IDextJsonObject;
var
  Context: TRttiContext;
  Field: TRttiField;
  FieldName: string;
  FieldValue: TValue;
  RttiType: TRttiType;
  HasCustomFormat: Boolean;
  CustomFormat: string;
begin
  Result := TDextJson.Provider.CreateObject;

  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(AValue.TypeInfo);
    for Field in RttiType.GetFields do
    begin
      if ShouldSkipField(Field, AValue) then
        Continue;

      FieldName := GetFieldName(Field);
      FieldValue := Field.GetValue(AValue.GetReferenceToRawData);

      HasCustomFormat := False;
      CustomFormat := '';

      for var Attr in Field.GetAttributes do
      begin
        if Attr is JsonFormatAttribute then
        begin
          HasCustomFormat := True;
          CustomFormat := JsonFormatAttribute(Attr).Format;
          Break;
        end;
      end;

      if FieldValue.TypeInfo = TypeInfo(TGUID) then
      begin
        Result.SetString(FieldName, GUIDToString(FieldValue.AsType<TGUID>));
        Continue;
      end;

      if (FieldValue.TypeInfo.Kind = tkEnumeration) and
         (FieldValue.TypeInfo <> TypeInfo(Boolean)) then
      begin
        case FSettings.EnumStyle of
          TDextEnumStyle.AsString:
            Result.SetString(FieldName, GetEnumName(FieldValue.TypeInfo, FieldValue.AsOrdinal));
          TDextEnumStyle.AsNumber:
            Result.SetInteger(FieldName, FieldValue.AsOrdinal);
        end;
        Continue;
      end;

      case FieldValue.TypeInfo.Kind of
        tkInteger, tkInt64:
          begin
            var ForceString := False;
            for var Attr in Field.GetAttributes do
              if Attr is JsonStringAttribute then
                ForceString := True;

            if ForceString then
              Result.SetString(FieldName, IntToJsonString(FieldValue.AsInt64))
            else
              Result.SetInt64(FieldName, FieldValue.AsInt64);
          end;

        tkFloat:
          begin
            if FieldValue.TypeInfo = TypeInfo(TDateTime) then
            begin
              if HasCustomFormat then
                Result.SetString(FieldName, FormatDateTime(CustomFormat, FieldValue.AsExtended))
              else
                case FSettings.DateFormatStyle of
                  TDextDateFormat.ISO8601:
                    Result.SetString(FieldName, FormatDateTime(FSettings.DateFormat, FieldValue.AsExtended));
                  TDextDateFormat.UnixTimestamp:
                    Result.SetInt64(FieldName, DateTimeToUnix(FieldValue.AsExtended));
                  TDextDateFormat.CustomFormat:
                    Result.SetString(FieldName, FormatDateTime(FSettings.DateFormat, FieldValue.AsExtended));
                end;
            end
            else
            begin
              var ForceString := False;
              for var Attr in Field.GetAttributes do
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
            var ForceNumber := False;
            for var Attr in Field.GetAttributes do
              if Attr is JsonNumberAttribute then
                ForceNumber := True;

            if ForceNumber then
            begin
              var NumValue := JsonStringToFloat(FieldValue.AsString);
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
              var ForceString := False;
              for var Attr in Field.GetAttributes do
                if Attr is JsonStringAttribute then
                  ForceString := True;

              if ForceString then
                Result.SetString(FieldName, BoolToStr(FieldValue.AsBoolean, True))
              else
                Result.SetBoolean(FieldName, FieldValue.AsBoolean);
            end
            else
              Result.SetString(FieldName, GetEnumName(FieldValue.TypeInfo, FieldValue.AsOrdinal));
          end;

        tkRecord:
          begin
            var NestedRecord := SerializeRecord(FieldValue);
            Result.SetObject(FieldName, NestedRecord);
          end;
      end;
    end;
  finally
    Context.Free;
  end;
end;

function TDextSerializer.ShouldSkipField(AField: TRttiField; const AValue: TValue): Boolean;
var
  Attribute: TCustomAttribute;
  FieldValue: TValue;
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

  if FSettings.IgnoreNullValues and FieldValue.IsEmpty then
    Exit(True);

  if FSettings.IgnoreDefaultValues then
  begin
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

  Result := (AField.Visibility <> mvPublic) or
            (AField.FieldType = nil) or
            (AField.Name.StartsWith('$'));
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

    else
      if IsListType(AValue.TypeInfo) then
      begin
        Result.SetArray(ValueField, SerializeList(AValue));
      end;
  end;
end;

class function TDextJson.GetProvider: IDextJsonProvider;
begin
  if FProvider = nil then
    FProvider := TJsonDataObjectsProvider.Create;
  Result := FProvider;
end;

function TDextSerializer.IsArrayType(AType: PTypeInfo): Boolean;
begin
  Result := (AType.Kind = tkDynArray);
end;

function TDextSerializer.IsListType(AType: PTypeInfo): Boolean;
begin
  Result := (AType.Kind = tkClass) and
            (Pos('System.Generics.Collections', string(AType.TypeData^.UnitName)) > 0);
end;

function TDextSerializer.GetArrayElementType(AType: PTypeInfo): PTypeInfo;
begin
  Result := AType.TypeData^.DynArrElType^;
end;

function TDextSerializer.GetListElementType(AType: PTypeInfo): PTypeInfo;
var
  Context: TRttiContext;
  RttiType: TRttiType;
  Method: TRttiMethod;
begin
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(AType);
    for Method in RttiType.GetMethods do
    begin
      if (Method.Name = 'Add') and (Length(Method.GetParameters) = 1) then
      begin
        Exit(Method.GetParameters[0].ParamType.Handle);
      end;
    end;
    Result := nil;
  finally
    Context.Free;
  end;
end;

function TDextSerializer.DeserializeArray(AJson: IDextJsonArray; AType: PTypeInfo): TValue;
var
  ElementType: PTypeInfo;
  DynArray: Pointer;
  I: Integer;
  ElementValue: TValue;
  P: PByte;
  Count: NativeInt;
begin
  ElementType := GetArrayElementType(AType);
  DynArray := nil;
  Count := AJson.GetCount;
  DynArraySetLength(DynArray, AType, 1, @Count); // AJson.Count -> GetCount

  try
    for I := 0 to AJson.GetCount - 1 do
    begin
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
            var Node := AJson.GetNode(I);
            if (Node <> nil) and (Node.GetNodeType = jntObject) then
              ElementValue := DeserializeRecord(Node as IDextJsonObject, ElementType)
            else
              ElementValue := TValue.Empty;
          end;
      else
        ElementValue := TValue.Empty;
      end;

      if not ElementValue.IsEmpty then
      begin
        P := PByte(DynArray) + (I * ElementType.TypeData^.elSize);
        Move(ElementValue.GetReferenceToRawData^, P^, ElementType.TypeData^.elSize);
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
  ElementType: PTypeInfo;
  List: TObject;
  I: Integer;
  ElementValue: TValue;
  AddMethod: TRttiMethod;
  Context: TRttiContext;
begin
  Context := TRttiContext.Create;
  try
    var CreateMethod := Context.GetType(AType).GetMethod('Create');
    Result := CreateMethod.Invoke(AType^.TypeData^.ClassType, []);
    List := Result.AsObject;

    AddMethod := Context.GetType(AType).GetMethod('Add');
    ElementType := GetListElementType(AType);

    for I := 0 to AJson.GetCount - 1 do
    begin
      var Node := AJson.GetNode(I);
      if (Node <> nil) and (Node.GetNodeType = jntObject) then
      begin
        ElementValue := DeserializeRecord(Node as IDextJsonObject, ElementType);
      end
      else
      begin
        case ElementType.Kind of
          tkInteger: ElementValue := TValue.From<Integer>(AJson.GetInteger(I));
          tkInt64: ElementValue := TValue.From<Int64>(AJson.GetInt64(I));
          tkFloat: ElementValue := TValue.From<Double>(AJson.GetDouble(I));
          tkUString, tkString, tkWString, tkLString:
            ElementValue := TValue.From<string>(AJson.GetString(I));
          tkEnumeration:
            if ElementType = TypeInfo(Boolean) then
              ElementValue := TValue.From<Boolean>(AJson.GetBoolean(I))
            else
              ElementValue := TValue.Empty;
          else
            ElementValue := TValue.Empty;
        end;
      end;

      if not ElementValue.IsEmpty then
        AddMethod.Invoke(List, [ElementValue]);
    end;
  finally
    Context.Free;
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
        Result.Add(SerializeRecord(ElementValue));
    else
      Result.AddNull;
    end;
  end;
end;

function TDextSerializer.SerializeList(const AValue: TValue): IDextJsonArray;
var
  List: TObject;
  Count: Integer;
  I: Integer;
  ElementValue: TValue;
  GetItemMethod: TRttiMethod;
  Context: TRttiContext;
begin
  Result := TDextJson.Provider.CreateArray;
  Context := TRttiContext.Create;
  try
    List := AValue.AsObject;
    Count := Context.GetType(AValue.TypeInfo).GetProperty('Count').GetValue(List).AsInteger;

    GetItemMethod := Context.GetType(AValue.TypeInfo).GetMethod('GetItem');
    if not Assigned(GetItemMethod) then
      GetItemMethod := Context.GetType(AValue.TypeInfo).GetMethod('Items');

    if Assigned(GetItemMethod) then
    begin
      for I := 0 to Count - 1 do
      begin
        ElementValue := GetItemMethod.Invoke(List, [I]);

        case ElementValue.TypeInfo.Kind of
          tkRecord:
            Result.Add(SerializeRecord(ElementValue));
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
  finally
    Context.Free;
  end;
end;

function TDextSerializer.ApplyCaseStyle(const AName: string): string;
begin
  case FSettings.CaseStyle of
    TDextCaseStyle.CamelCase:
      begin
        if AName.Length > 0 then
          Result := LowerCase(AName[1]) + Copy(AName, 2, MaxInt)
        else
          Result := AName;
      end;

    TDextCaseStyle.SnakeCase:
      begin
        Result := '';
        for var I := 1 to AName.Length do
        begin
          if (I > 1) and CharInSet(AName[I], ['A'..'Z']) then
            Result := Result + '_';
          Result := Result + LowerCase(AName[I]);
        end;
      end;

    TDextCaseStyle.PascalCase:
      begin
        if AName.Length > 0 then
          Result := UpperCase(AName[1]) + Copy(AName, 2, MaxInt)
        else
          Result := AName;
      end;
  else
    Result := AName;
  end;
end;

{ TJsonBuilder }

constructor TJsonBuilder.Create;
begin
  inherited Create;
  FNodeStack := TList<TBuilderNode>.Create;
  
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
  FNodeStack.Free;
  inherited;
end;

class function TJsonBuilder.New: TJsonBuilder;
begin
  Result := TJsonBuilder.Create;
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

end.
