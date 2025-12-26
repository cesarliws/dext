{***************************************************************************}
{                                                                           }
{           Dext Framework - AutoMapper                                     }
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
{  Created: 2025-12-24                                                      }
{                                                                           }
{  Description:                                                             }
{    AutoMapper for DTO <-> Entity mapping using RTTI.                     }
{    Supports custom member mappings, ignoring properties, and collections.}
{                                                                           }
{***************************************************************************}
unit Dext.Mapper;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections;

type
  /// <summary>
  ///   Function type for custom member mapping.
  /// </summary>
  TMemberMapFunc<TSource, TDest> = reference to function(const Source: TSource): TValue;

  /// <summary>
  ///   Configuration for mapping a specific member.
  /// </summary>
  TMemberMapping = class
  private
    FDestMemberName: string;
    FMapFunc: TFunc<TObject, TValue>;
    FIgnore: Boolean;
  public
    property DestMemberName: string read FDestMemberName write FDestMemberName;
    property MapFunc: TFunc<TObject, TValue> read FMapFunc write FMapFunc;
    property Ignore: Boolean read FIgnore write FIgnore;
  end;

  /// <summary>
  ///   Base class for type mapping configuration.
  /// </summary>
  TTypeMapConfigBase = class
  protected
    FMemberMappings: TObjectDictionary<string, TMemberMapping>;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    property MemberMappings: TObjectDictionary<string, TMemberMapping> read FMemberMappings;
  end;

  /// <summary>
  ///   Configuration for mapping between two types.
  /// </summary>
  TTypeMapConfig<TSource: class; TDest: class> = class(TTypeMapConfigBase)
  public
    constructor Create; override;

    /// <summary>
    ///   Configure custom mapping for a destination member.
    /// </summary>
    function ForMember(const DestMemberName: string;
      MapFunc: TMemberMapFunc<TSource, TDest>): TTypeMapConfig<TSource, TDest>;

    /// <summary>
    ///   Ignore a destination member during mapping.
    /// </summary>
    function Ignore(const DestMemberName: string): TTypeMapConfig<TSource, TDest>;
  end;

  /// <summary>
  ///   Global mapper registry and mapping executor.
  /// </summary>
  TMapper = class
  private
    class var FConfigurations: TDictionary<string, TObject>;
    class function GetConfigKey(SourceType, DestType: PTypeInfo): string;
    class constructor Create;
    class destructor Destroy;
  public
    /// <summary>
    ///   Create a mapping configuration between two types.
    /// </summary>
    class function CreateMap<TSource: class; TDest: class>: TTypeMapConfig<TSource, TDest>;

    /// <summary>
    ///   Map a source object to a new destination object.
    /// </summary>
    class function Map<TSource; TDest>(const Source: TSource; AOnlyNonDefault: Boolean = False): TDest; overload;

    /// <summary>
    ///   Map a source object to an existing destination object.
    /// </summary>
    class procedure Map<TSource; TDest>(const Source: TSource; var Dest: TDest; AOnlyNonDefault: Boolean = False); overload;

    /// <summary>
    ///   Map a list of source objects to a list of destination objects.
    /// </summary>
    class function MapList<TSource; TDest>(const SourceList: TEnumerable<TSource>; AOnlyNonDefault: Boolean = False): TList<TDest>;
  end;

implementation

uses
  Dext.Core.Activator;

{ TMemberMapping }

{ TTypeMapConfigBase }

constructor TTypeMapConfigBase.Create;
begin
  FMemberMappings := TObjectDictionary<string, TMemberMapping>.Create([doOwnsValues]);
end;

destructor TTypeMapConfigBase.Destroy;
begin
  FMemberMappings.Free;
  inherited;
end;

{ TTypeMapConfig<TSource, TDest> }

constructor TTypeMapConfig<TSource, TDest>.Create;
begin
  inherited Create;
end;

function TTypeMapConfig<TSource, TDest>.ForMember(const DestMemberName: string;
  MapFunc: TMemberMapFunc<TSource, TDest>): TTypeMapConfig<TSource, TDest>;
var
  Mapping: TMemberMapping;
begin
  Mapping := TMemberMapping.Create;
  Mapping.DestMemberName := DestMemberName;
  Mapping.MapFunc := function(Obj: TObject): TValue
    begin
      if Obj is TSource then
        Result := MapFunc(Obj as TSource)
      else
        raise Exception.Create('Invalid source type for mapping');
    end;
  FMemberMappings.AddOrSetValue(DestMemberName, Mapping);
  Result := Self;
end;

function TTypeMapConfig<TSource, TDest>.Ignore(const DestMemberName: string): TTypeMapConfig<TSource, TDest>;
var
  Mapping: TMemberMapping;
begin
  Mapping := TMemberMapping.Create;
  Mapping.DestMemberName := DestMemberName;
  Mapping.Ignore := True;
  FMemberMappings.AddOrSetValue(DestMemberName, Mapping);
  Result := Self;
end;

{ TMapper }

class constructor TMapper.Create;
begin
  FConfigurations := TDictionary<string, TObject>.Create;
end;

class destructor TMapper.Destroy;
var
  Config: TObject;
begin
  for Config in FConfigurations.Values do
    Config.Free;
  FConfigurations.Free;
end;

class function TMapper.GetConfigKey(SourceType, DestType: PTypeInfo): string;
begin
  Result := string(SourceType.Name) + '->' + string(DestType.Name);
end;

class function TMapper.CreateMap<TSource, TDest>: TTypeMapConfig<TSource, TDest>;
var
  Key: string;
  Config: TTypeMapConfig<TSource, TDest>;
begin
  Key := GetConfigKey(TypeInfo(TSource), TypeInfo(TDest));

  if FConfigurations.ContainsKey(Key) then
    Result := TTypeMapConfig<TSource, TDest>(FConfigurations[Key])
  else
  begin
    Config := TTypeMapConfig<TSource, TDest>.Create;
    FConfigurations.Add(Key, Config);
    Result := Config;
  end;
end;

class function TMapper.Map<TSource, TDest>(const Source: TSource; AOnlyNonDefault: Boolean): TDest;
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
  Value: TValue;
begin
  Ctx := TRttiContext.Create;
  try
    RttiType := Ctx.GetType(TypeInfo(TDest));
    if RttiType.IsInstance then
    begin
      Value := TRttiInstanceType(RttiType).MetaclassType.Create;
      Value.ExtractRawData(@Result);
    end
    else
      Result := Default(TDest);
  finally
    Ctx.Free;
  end;
  Map<TSource, TDest>(Source, Result, AOnlyNonDefault);
end;

class procedure TMapper.Map<TSource, TDest>(const Source: TSource; var Dest: TDest; AOnlyNonDefault: Boolean);
var
  Ctx: TRttiContext;
  SourceType, DestType: TRttiType;
  SourceProp, DestProp: TRttiProperty;
  SourceField, DestField: TRttiField;
  ConfigKey: string;
  Config: TTypeMapConfigBase;
  Mapping: TMemberMapping;
  Value: TValue;
  HasConfig, IsDefault: Boolean;
  SrcPtr, DstPtr: Pointer;
begin
  Config := nil;

  Ctx := TRttiContext.Create;
  try
    SourceType := Ctx.GetType(TypeInfo(TSource));
    DestType := Ctx.GetType(TypeInfo(TDest));

    // Handle Source Pointer
    if SourceType.IsInstance then
    begin
      SrcPtr := PPointer(@Source)^;
      if SrcPtr = nil then Exit;
    end
    else
      SrcPtr := @Source;

    // Handle Destination Pointer
    if DestType.IsInstance then
    begin
      DstPtr := PPointer(@Dest)^;
      if DstPtr = nil then Exit;
    end
    else
      DstPtr := @Dest;

    // Check if there's a custom configuration
    ConfigKey := GetConfigKey(TypeInfo(TSource), TypeInfo(TDest));
    var ConfigObj: TObject;
    HasConfig := FConfigurations.TryGetValue(ConfigKey, ConfigObj);
    if HasConfig and (ConfigObj is TTypeMapConfigBase) then
      Config := ConfigObj as TTypeMapConfigBase;

    // Map each destination property
    for DestProp in DestType.GetProperties do
    begin
      if not DestProp.IsWritable then
        Continue;

      // Check if property is ignored
      if HasConfig and (Config <> nil) and Config.MemberMappings.TryGetValue(DestProp.Name, Mapping) then
      begin
        if Mapping.Ignore then
          Continue;

        // Use custom mapping function
        if Assigned(Mapping.MapFunc) then
        begin
          if SourceType.IsInstance then
            Value := Mapping.MapFunc(TObject(SrcPtr))
          else
            raise Exception.Create('Custom mapping not supported for records yet');

          DestProp.SetValue(DstPtr, Value);
          Continue;
        end;
      end;

      // Default: map by property name
      Value := TValue.Empty;
      SourceProp := SourceType.GetProperty(DestProp.Name);
      if (SourceProp <> nil) and SourceProp.IsReadable then
        Value := SourceProp.GetValue(SrcPtr)
      else
      begin
        SourceField := SourceType.GetField(DestProp.Name);
        if SourceField <> nil then
          Value := SourceField.GetValue(SrcPtr);
      end;

      if not Value.IsEmpty then
      begin
        if AOnlyNonDefault then
        begin
          IsDefault := False;
          case Value.Kind of
            tkInteger, tkInt64: IsDefault := Value.AsOrdinal = 0;
            tkFloat: IsDefault := Value.AsExtended = 0;
            tkUString, tkString, tkWString, tkLString: IsDefault := Value.AsString = '';
            tkEnumeration:
              if Value.TypeInfo <> TypeInfo(Boolean) then
                IsDefault := Value.AsOrdinal = 0;
          end;
          if IsDefault then Continue;
        end;

        // Handle type conversion if needed
        if Value.TypeInfo <> DestProp.PropertyType.Handle then
        begin
          // Try implicit conversion
          try
            Value := Value.Cast(DestProp.PropertyType.Handle);
          except
            // Skip if conversion fails
            Continue;
          end;
        end;

        DestProp.SetValue(DstPtr, Value);
      end;
    end;

    // Also try to match Destination Fields if they are not exposed via properties
    for DestField in DestType.GetFields do
    begin
      var PropName := DestField.Name;
      if PropName.StartsWith('FF', True) then
        PropName := PropName.Substring(1);

      if DestType.GetProperty(PropName) <> nil then
        Continue;

      Value := TValue.Empty;
      SourceProp := SourceType.GetProperty(PropName);
      if (SourceProp <> nil) and SourceProp.IsReadable then
        Value := SourceProp.GetValue(SrcPtr)
      else
      begin
        SourceField := SourceType.GetField(PropName);
        if SourceField <> nil then
          Value := SourceField.GetValue(SrcPtr);
      end;

      if not Value.IsEmpty then
      begin
        if AOnlyNonDefault then
        begin
          IsDefault := False;
          case Value.Kind of
            tkInteger, tkInt64: IsDefault := Value.AsOrdinal = 0;
            tkFloat: IsDefault := Value.AsExtended = 0;
            tkUString, tkString, tkWString, tkLString: IsDefault := Value.AsString = '';
          end;
          if IsDefault then Continue;
        end;

        DestField.SetValue(DstPtr, Value);
      end;
    end;
  finally
    Ctx.Free;
  end;
end;

class function TMapper.MapList<TSource, TDest>(const SourceList: TEnumerable<TSource>; AOnlyNonDefault: Boolean): TList<TDest>;
var
  Item: TSource;
begin
  Result := TList<TDest>.Create;
  try
    for Item in SourceList do
      Result.Add(Map<TSource, TDest>(Item, AOnlyNonDefault));
  except
    Result.Free;
    raise;
  end;
end;

end.
