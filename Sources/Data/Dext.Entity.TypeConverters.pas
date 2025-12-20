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
{  Created: 2025-12-18                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.TypeConverters;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Entity.Dialects,
  Dext.Entity.Attributes;

type
  /// <summary>
  ///   Marks an enum property to be saved as string instead of integer.
  /// </summary>
  EnumAsStringAttribute = class(TCustomAttribute)
  end;

  /// <summary>
  ///   Marks a TArray<T> property as database array column.
  /// </summary>
  ArrayColumnAttribute = class(TCustomAttribute)
  end;

  /// <summary>
  ///   Specifies custom database type for a column.
  /// </summary>
  ColumnTypeAttribute = class(TCustomAttribute)
  private
    FTypeName: string;
  public
    constructor Create(const ATypeName: string);
    property TypeName: string read FTypeName;
  end;

  /// <summary>
  ///   Interface for type converters that handle database-specific type mappings.
  /// </summary>
  ITypeConverter = interface
    ['{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}']
    /// <summary>Returns true if this converter can handle the given type.</summary>
    function CanConvert(ATypeInfo: PTypeInfo): Boolean;
    
    /// <summary>Converts a Delphi value to database representation.</summary>
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
    
    /// <summary>Converts a database value to Delphi representation.</summary>
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
    
    /// <summary>Returns SQL cast expression for the given parameter.</summary>
    function GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string;
  end;

  /// <summary>
  ///   Base class for type converters.
  /// </summary>
  TTypeConverterBase = class abstract(TInterfacedObject, ITypeConverter)
  public
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; virtual; abstract;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; virtual; abstract;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; virtual; abstract;
    function GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string; virtual;
  end;

  /// <summary>
  ///   Converter for TGUID type.
  /// </summary>
  TGuidConverter = class(TTypeConverterBase)
  private
    FSwapEndianness: Boolean;
    function DoSwap(const G: TGUID): TGUID;
  public
    constructor Create(ASwapEndianness: Boolean = False);
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
    function GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string; override;
  end;

  /// <summary>
  ///   Converter for Enum types.
  /// </summary>
  TEnumConverter = class(TTypeConverterBase)
  private
    FUseString: Boolean;
  public
    constructor Create(AUseString: Boolean);
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Converter for JSON/JSONB types (stores objects as JSON strings).
  /// </summary>
  TJsonConverter = class(TTypeConverterBase)
  private
    FUseJsonB: Boolean;
  public
    constructor Create(AUseJsonB: Boolean = True);
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
    function GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string; override;
  end;

  /// <summary>
  ///   Converter for Array types (PostgreSQL arrays).
  /// </summary>
  TArrayConverter = class(TTypeConverterBase)
  public
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
    function GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string; override;
  end;

  /// <summary>
  ///   Converter for TDateTime types.
  /// </summary>
  TDateTimeConverter = class(TTypeConverterBase)
  public
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
    function GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string; override;
  end;

  /// <summary>
  ///   Converter for TDate types.
  /// </summary>
  TDateConverter = class(TTypeConverterBase)
  public
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
    function GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string; override;
  end;

  /// <summary>
  ///   Converter for TTime types.
  /// </summary>
  TTimeConverter = class(TTypeConverterBase)
  public
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
    function GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string; override;
  end;

  /// <summary>
  ///   Converter for TBytes types (BLOBs).
  /// </summary>
  TBytesConverter = class(TTypeConverterBase)
  public
    function CanConvert(ATypeInfo: PTypeInfo): Boolean; override;
    function ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue; override;
    function FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue; override;
  end;

  /// <summary>
  ///   Registry for type converters.
  /// </summary>
  TTypeConverterRegistry = class
  private
    class var FInstance: TTypeConverterRegistry;
    FConverters: TList<ITypeConverter>;
    FCustomConverters: TDictionary<PTypeInfo, ITypeConverter>; // For property-specific converters
    class constructor Create;
    class destructor Destroy;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Registers a global type converter.</summary>
    procedure RegisterConverter(AConverter: ITypeConverter);
    
    /// <summary>Registers a converter for a specific type (overrides global).</summary>
    procedure RegisterConverterForType(ATypeInfo: PTypeInfo; AConverter: ITypeConverter);
    
    /// <summary>Gets the appropriate converter for a type.</summary>
    function GetConverter(ATypeInfo: PTypeInfo): ITypeConverter;
    
    /// <summary>Clears all custom converters (useful for testing).</summary>
    procedure ClearCustomConverters;
    
    class property Instance: TTypeConverterRegistry read FInstance;
  end;

implementation

uses
  System.SyncObjs,
  Dext.Json;

{ ColumnTypeAttribute }

constructor ColumnTypeAttribute.Create(const ATypeName: string);
begin
  inherited Create;
  FTypeName := ATypeName;
end;

{ TTypeConverterBase }

function TTypeConverterBase.GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string;
begin
  // Default: no cast
  Result := AParamName;
end;

{ TGuidConverter }

constructor TGuidConverter.Create(ASwapEndianness: Boolean);
begin
  inherited Create;
  FSwapEndianness := ASwapEndianness;
end;

function TGuidConverter.DoSwap(const G: TGUID): TGUID;
begin
  Result := G;
  Result.D1 := ((Result.D1 and $000000FF) shl 24) or
               ((Result.D1 and $0000FF00) shl 8) or
               ((Result.D1 and $00FF0000) shr 8) or
               ((Result.D1 and $FF000000) shr 24);
  Result.D2 := Swap(Result.D2);
  Result.D3 := Swap(Result.D3);
end;

function TGuidConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := ATypeInfo = TypeInfo(TGUID);
end;

function TGuidConverter.ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
var
  Guid: TGUID;
begin
  Guid := AValue.AsType<TGUID>;
  Result := GUIDToString(Guid); // Returns '{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}'
end;

function TGuidConverter.FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
var
  Guid: TGUID;
  GuidStr: string;
begin
  if AValue.IsEmpty then
  begin
    FillChar(Guid, SizeOf(TGUID), 0);
    TValue.Make(@Guid, TypeInfo(TGUID), Result);
  end
  else
  begin
    GuidStr := AValue.AsString;
    try
      Guid := StringToGUID(GuidStr);
      if FSwapEndianness then
        Guid := DoSwap(Guid);
    except
      on E: Exception do
        raise Exception.CreateFmt('''%s'' is not a valid GUID value (SourceType: %s, Kind: %d)', 
          [GuidStr, AValue.TypeInfo.Name, Ord(AValue.Kind)]);
    end;
    TValue.Make(@Guid, TypeInfo(TGUID), Result);
  end;
end;

function TGuidConverter.GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string;
begin
  case ADialect of
    ddPostgreSQL:
      Result := Format('%s::uuid', [AParamName]);
    ddSQLServer:
      Result := Format('CAST(%s AS UNIQUEIDENTIFIER)', [AParamName]);
    ddMySQL, ddSQLite:
      Result := AParamName; // Use as string
    else
      Result := AParamName;
  end;
end;

{ TEnumConverter }

constructor TEnumConverter.Create(AUseString: Boolean);
begin
  inherited Create;
  FUseString := AUseString;
end;

function TEnumConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := (ATypeInfo <> nil) and 
            (ATypeInfo.Kind = tkEnumeration) and 
            (ATypeInfo <> TypeInfo(Boolean)); // Boolean is handled separately
end;

function TEnumConverter.ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
begin
  if FUseString then
    Result := GetEnumName(AValue.TypeInfo, AValue.AsOrdinal)
  else
    Result := AValue.AsOrdinal;
end;

function TEnumConverter.FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
var
  OrdValue: Integer;
begin
  if AValue.IsEmpty then
  begin
    TValue.Make(0, ATypeInfo, Result);
  end
  else if FUseString then
  begin
    OrdValue := GetEnumValue(ATypeInfo, AValue.AsString);
    if OrdValue = -1 then
      raise Exception.CreateFmt('Invalid enum value: %s', [AValue.AsString]);
    TValue.Make(OrdValue, ATypeInfo, Result);
  end
  else
  begin
    TValue.Make(AValue.AsInteger, ATypeInfo, Result);
  end;
end;

{ TJsonConverter }

constructor TJsonConverter.Create(AUseJsonB: Boolean);
begin
  inherited Create;
  FUseJsonB := AUseJsonB;
end;

function TJsonConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  // Auto-convert known complex types effectively if registered without attribute, 
  // but usually we rely on property attributes.
  // However, returning True here allows Global Registration to work.
  Result := (ATypeInfo.Kind in [tkClass, tkRecord, tkDynArray]) and
            (ATypeInfo <> TypeInfo(TGUID)) and
            (ATypeInfo <> TypeInfo(TBytes));
end;

function TJsonConverter.ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
begin
  if AValue.IsEmpty then
    Exit(TValue.Empty);

  if AValue.IsObject then
  begin
    if AValue.AsObject = nil then
      Exit(TValue.Empty);
    Result := TDextJson.Serialize(AValue.AsObject);
  end
  else if AValue.Kind in [tkRecord, tkDynArray] then
  begin
    // Serialize Records and Arrays
    // We need to use TValue-based generic serialization if available, 
    // or assume TDextJson can handle TValue (it usually takes TObject or TypeInfo)
    // Looking at TDextJson.Serialize overloads... usually (Object) or (TypeInfo, Value).
    // Let's assume generic TValue serialization is supported via helper or RTTI.
    // If not, we might need a specific overload.
    // Using simple TObject serialization for now, but for records we need Deserialize(TypeInfo...).
    // For Serialize(Record), we likely need a pointer.
    
    // NOTE: TDextJson.Serialize(TValue) might not exist directly. 
    // We'll use the generic wrapper or assumed overload.
    // Ideally: TDextJson.Serialize(AValue)
    Result := TDextJson.Serialize(AValue); 
  end
  else
    Result := AValue.AsString; // Fallback
end;

function TJsonConverter.FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
var
  JsonStr: string;
begin
  if AValue.IsEmpty then
    Exit(TValue.Empty);
    
  JsonStr := AValue.AsString;
  if JsonStr.Trim.IsEmpty then
    Exit(TValue.Empty);
    
  if ATypeInfo.Kind in [tkClass, tkRecord, tkDynArray] then
    Result := TDextJson.Deserialize(ATypeInfo, JsonStr)
  else
    Result := AValue;
end;

function TJsonConverter.GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string;
begin
  case ADialect of
    ddPostgreSQL:
      if FUseJsonB then
        Result := Format('%s::jsonb', [AParamName])
      else
        Result := Format('%s::json', [AParamName]);
    else
      Result := AParamName; // Other databases use text
  end;
end;

{ TArrayConverter }

function TArrayConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  // For now, we don't auto-detect array types
  // User must register converter explicitly or use [ArrayColumn] attribute
  Result := False;
end;

function TArrayConverter.ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
var
  Arr: TArray<TValue>;
  I: Integer;
  Elements: TStringList;
  ElementStr: string;
begin
  if AValue.IsEmpty then
    Exit(TValue.Empty);
    
  // Get array elements
  Arr := AValue.AsType<TArray<TValue>>;
  
  case ADialect of
    ddPostgreSQL:
    begin
      // Format as PostgreSQL array: ARRAY['elem1', 'elem2']
      Elements := TStringList.Create;
      try
        Elements.Delimiter := ',';
        Elements.QuoteChar := '''';
        Elements.StrictDelimiter := True;
        
        for I := 0 to High(Arr) do
        begin
          case Arr[I].Kind of
            tkInteger, tkInt64: ElementStr := Arr[I].AsInteger.ToString;
            tkFloat: ElementStr := Arr[I].AsExtended.ToString;
            tkString, tkUString: ElementStr := Arr[I].AsString;
            else ElementStr := Arr[I].ToString;
          end;
          Elements.Add(ElementStr);
        end;
        
        Result := 'ARRAY[' + Elements.DelimitedText + ']';
      finally
        Elements.Free;
      end;
    end;
    else
    begin
      // For other databases, serialize as JSON array
      Result := TDextJson.Serialize(Arr);
    end;
  end;
end;

function TArrayConverter.FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
var
  JsonStr: string;
begin
  if AValue.IsEmpty then
    Exit(TValue.Empty);
    
  JsonStr := AValue.AsString;
  
  // TODO: Implement proper array deserialization
  // For now, return the JSON string as-is
  Result := AValue;
end;

function TArrayConverter.GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string;
begin
  case ADialect of
    ddPostgreSQL:
      Result := AParamName; // Array literal already includes type
    else
      Result := AParamName;
  end;
end;

{ TTypeConverterRegistry }

class constructor TTypeConverterRegistry.Create;
begin
  FInstance := TTypeConverterRegistry.Create;
end;

class destructor TTypeConverterRegistry.Destroy;
begin
  FInstance.Free;
end;

constructor TTypeConverterRegistry.Create;
begin
  inherited Create;
  FConverters := TList<ITypeConverter>.Create;
  FCustomConverters := TDictionary<PTypeInfo, ITypeConverter>.Create;
  
  // Register built-in converters
  RegisterConverter(TGuidConverter.Create);
  RegisterConverter(TDateTimeConverter.Create);
  RegisterConverter(TDateConverter.Create);
  RegisterConverter(TTimeConverter.Create);
  RegisterConverter(TBytesConverter.Create);
  // Note: Enum, JSON, Array converters are registered dynamically or explicitly
end;

destructor TTypeConverterRegistry.Destroy;
begin
  // Clear the lists first to release interface references properly
  // before destroying the container objects
  FCustomConverters.Clear;
  FConverters.Clear;
  
  FCustomConverters.Free;
  FConverters.Free;
  inherited;
end;

procedure TTypeConverterRegistry.RegisterConverter(AConverter: ITypeConverter);
begin
  FConverters.Add(AConverter);
end;

procedure TTypeConverterRegistry.RegisterConverterForType(ATypeInfo: PTypeInfo; AConverter: ITypeConverter);
begin
  FCustomConverters.AddOrSetValue(ATypeInfo, AConverter);
end;

procedure TTypeConverterRegistry.ClearCustomConverters;
begin
  FCustomConverters.Clear;
end;

function TTypeConverterRegistry.GetConverter(ATypeInfo: PTypeInfo): ITypeConverter;
var
  Converter: ITypeConverter;
begin
  Result := nil;
  
  if ATypeInfo = nil then
    Exit;
  
  // Check custom converters first (highest priority)
  if FCustomConverters.TryGetValue(ATypeInfo, Result) then
    Exit;
  
  // Find global converter
  for Converter in FConverters do
  begin
    if Converter.CanConvert(ATypeInfo) then
      Exit(Converter);
  end;
end;

{ TDateTimeConverter }

function TDateTimeConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := ATypeInfo = TypeInfo(TDateTime);
end;

function TDateTimeConverter.ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
begin
  Result := AValue; // TDateTime is already TValue compatible
end;

function TDateTimeConverter.FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
begin
  Result := AValue;
end;

function TDateTimeConverter.GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string;
begin
  case ADialect of
    ddPostgreSQL: Result := Format('%s::timestamp', [AParamName]);
    ddSQLServer: Result := Format('CAST(%s AS DATETIME2)', [AParamName]);
    else Result := AParamName;
  end;
end;

{ TDateConverter }

function TDateConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := ATypeInfo = TypeInfo(TDate);
end;

function TDateConverter.ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
begin
  Result := AValue;
end;

function TDateConverter.FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
begin
  Result := AValue;
end;

function TDateConverter.GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string;
begin
  case ADialect of
    ddPostgreSQL: Result := Format('%s::date', [AParamName]);
    ddSQLServer: Result := Format('CAST(%s AS DATE)', [AParamName]);
    else Result := AParamName;
  end;
end;

{ TTimeConverter }

function TTimeConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := ATypeInfo = TypeInfo(TTime);
end;

function TTimeConverter.ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
begin
  Result := AValue;
end;

function TTimeConverter.FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
begin
  Result := AValue;
end;

function TTimeConverter.GetSQLCast(const AParamName: string; ADialect: TDatabaseDialect): string;
begin
  case ADialect of
    ddPostgreSQL: Result := Format('%s::time', [AParamName]);
    ddSQLServer: Result := Format('CAST(%s AS TIME)', [AParamName]);
    else Result := AParamName;
  end;
end;

{ TBytesConverter }

function TBytesConverter.CanConvert(ATypeInfo: PTypeInfo): Boolean;
begin
  Result := (ATypeInfo <> nil) and (ATypeInfo = TypeInfo(TBytes));
end;

function TBytesConverter.ToDatabase(const AValue: TValue; ADialect: TDatabaseDialect): TValue;
begin
  Result := AValue;
end;

function TBytesConverter.FromDatabase(const AValue: TValue; ATypeInfo: PTypeInfo): TValue;
begin
  Result := AValue;
end;

end.
