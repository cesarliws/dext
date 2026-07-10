{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License. }
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
unit Dext.Core.TypeModel;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.SyncObjs,
  System.TypInfo,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Core.Reflection;

type
  TDextNativeKind = (
    nkUnknown,
    nkInt32,
    nkInt64,
    nkUInt32,
    nkUInt64,
    nkBoolean,
    nkSingle,
    nkDouble,
    nkCurrency,
    nkDateTime,
    nkString,
    nkBytes,
    nkGuid,
    nkUuid,
    nkEnum,
    nkObject,
    nkList
  );

  /// <summary>Access strategy used by a field plan.</summary>
  TDextAccessMode = (
    amRtti,
    amDirectField,
    amGenerated
  );

  /// <summary>Shared field plan describing a mapped member for direct and generated codecs.</summary>
  TDextFieldPlan = record
    Name: string;
    ExternalName: string;
    ProtoTag: Integer;
    NativeKind: TDextNativeKind;
    TypeInfo: PTypeInfo;
    ElementType: PTypeInfo;
    ElementNativeKind: TDextNativeKind;
    ListOwnsObjects: Boolean;
    WireType: Byte;
    Offset: NativeInt;
    ValueOffset: NativeInt;
    HasValueOffset: NativeInt;
    IsNullable: Boolean;
    IsList: Boolean;
    IsObject: Boolean;
    AccessMode: TDextAccessMode;
    Handler: IPropertyHandler;
  end;

  /// <summary>Codec-oriented type plan interface exposed to consumers of the shared metadata model.</summary>
  IDextTypeCodecPlan = interface
    ['{75C0DA38-9C8B-4B62-88A1-5849B3E6079F}']
    /// <summary>Returns the source type info for the plan.</summary>
    function GetTypeInfo: PTypeInfo;
    /// <summary>Returns the mapped field plans.</summary>
    function GetFields: TArray<TDextFieldPlan>;
    /// <summary>Indicates whether the type has at least one direct field path.</summary>
    function HasDirectAccess: Boolean;
    /// <summary>Indicates whether a generated codec is registered for the type.</summary>
    function HasGeneratedCodec: Boolean;
    /// <summary>Finds a field plan by protobuf tag number.</summary>
    function TryGetFieldByProtoTag(ATag: Integer; out AField: TDextFieldPlan): Boolean;
  end;

  /// <summary>Entry point for building and caching codec-oriented type plans.</summary>
  TDextTypeModel = class
  private
    class var FCache: IDictionary<PTypeInfo, IDextTypeCodecPlan>;
    class var FLock: TCriticalSection;
    class constructor Create;
    class destructor Destroy;
  public
    /// <summary>Returns the cached codec plan for a type, building it on demand.</summary>
    class function GetPlan(AType: PTypeInfo): IDextTypeCodecPlan; static;
    /// <summary>Maps a Delphi type info to the shared native kind classification.</summary>
    class function NativeKindOf(AType: PTypeInfo): TDextNativeKind; static;
    /// <summary>Maps a shared native kind to its protobuf wire type.</summary>
    class function ProtobufWireType(AKind: TDextNativeKind): Byte; static;
    /// <summary>Indicates whether a native kind can be accessed directly by offset.</summary>
    class function IsDirectKind(AKind: TDextNativeKind): Boolean; static;
    /// <summary>Indicates whether a native kind is a direct reference container.</summary>
    class function IsDirectReferenceKind(AKind: TDextNativeKind): Boolean; static;
    /// <summary>Clears the cached codec plans.</summary>
    class procedure ClearCache; static;
  end;

implementation

uses
  Dext.Grpc.Attributes,
  Dext.Types.UUID;

type
  /// <summary>Internal implementation of a codec-oriented type plan.</summary>
  TDextTypeCodecPlan = class(TInterfacedObject, IDextTypeCodecPlan)
  private
    FTypeInfo: PTypeInfo;
    FFields: TArray<TDextFieldPlan>;
    FByProtoTag: IDictionary<Integer, Integer>;
    FHasDirectAccess: Boolean;
    FHasGeneratedCodec: Boolean;
    procedure Build(AType: PTypeInfo);
    function FindBackingField(ARttiType: TRttiType; AProp: TRttiProperty): TRttiField;
    function ReadProtoTag(AMember: TRttiMember): Integer;
    class procedure SortFields(var AFields: TArray<TDextFieldPlan>); static;
  public
    /// <summary>Builds a codec plan for the given type info.</summary>
    constructor Create(AType: PTypeInfo);
    /// <summary>Returns the source type info for the plan.</summary>
    function GetTypeInfo: PTypeInfo;
    /// <summary>Returns the mapped field plans.</summary>
    function GetFields: TArray<TDextFieldPlan>;
    /// <summary>Indicates whether the type has at least one direct field path.</summary>
    function HasDirectAccess: Boolean;
    /// <summary>Indicates whether a generated codec is registered for the type.</summary>
    function HasGeneratedCodec: Boolean;
    /// <summary>Finds a field plan by protobuf tag number.</summary>
    function TryGetFieldByProtoTag(ATag: Integer; out AField: TDextFieldPlan): Boolean;
  end;

{ TDextTypeModel }

class constructor TDextTypeModel.Create;
begin
  FCache := TCollections.CreateDictionary<PTypeInfo, IDextTypeCodecPlan>;
  FLock := TCriticalSection.Create;
end;

class destructor TDextTypeModel.Destroy;
begin
  FCache := nil;
  FLock.Free;
end;

class procedure TDextTypeModel.ClearCache;
begin
  FLock.Acquire;
  try
    FCache.Clear;
  finally
    FLock.Release;
  end;
end;

class function TDextTypeModel.GetPlan(AType: PTypeInfo): IDextTypeCodecPlan;
begin
  Result := nil;
  if AType = nil then
    Exit;

  FLock.Acquire;
  try
    if not FCache.TryGetValue(AType, Result) then
    begin
      Result := TDextTypeCodecPlan.Create(AType);
      FCache.Add(AType, Result);
    end;
  finally
    FLock.Release;
  end;
end;

class function TDextTypeModel.IsDirectKind(AKind: TDextNativeKind): Boolean;
begin
  Result := AKind in [
    nkInt32,
    nkInt64,
    nkUInt32,
    nkUInt64,
    nkBoolean,
    nkSingle,
    nkDouble,
    nkCurrency,
    nkDateTime,
    nkString,
    nkGuid,
    nkUuid
  ];
end;


class function TDextTypeModel.IsDirectReferenceKind(AKind: TDextNativeKind): Boolean;
begin
  Result := AKind in [nkObject, nkList];
end;

class function TDextTypeModel.NativeKindOf(AType: PTypeInfo): TDextNativeKind;
begin
  Result := nkUnknown;
  if AType = nil then
    Exit;

  case AType.Kind of
    tkInteger:
      Result := nkInt32;
    tkInt64:
      Result := nkInt64;
    tkEnumeration:
      if AType = TypeInfo(Boolean) then
        Result := nkBoolean
      else
        Result := nkEnum;
    tkFloat:
      if AType = TypeInfo(Single) then
        Result := nkSingle
      else if AType = TypeInfo(Currency) then
        Result := nkCurrency
      else if AType = TypeInfo(TDateTime) then
        Result := nkDateTime
      else
        Result := nkDouble;
    tkUString, tkString, tkWString, tkChar, tkWChar:
      Result := nkString;
    tkDynArray:
      if AType = TypeInfo(TBytes) then
        Result := nkBytes;
    tkClass:
      Result := nkObject;
    tkInterface:
      if TReflection.IsListType(AType) then
        Result := nkList
      else
        Result := nkObject;
    tkRecord:
      begin
        if AType = TypeInfo(TGUID) then
          Result := nkGuid
        else if AType = TypeInfo(TUUID) then
          Result := nkUuid;
      end;
  end;
end;

class function TDextTypeModel.ProtobufWireType(AKind: TDextNativeKind): Byte;
begin
  case AKind of
    nkInt32, nkInt64, nkUInt32, nkUInt64, nkBoolean, nkEnum:
      Result := 0;
    nkDouble, nkCurrency, nkDateTime:
      Result := 1;
    nkString, nkBytes, nkObject, nkList, nkGuid, nkUuid:
      Result := 2;
    nkSingle:
      Result := 5;
  else
    Result := 2;
  end;
end;

{ TDextTypeCodecPlan }

constructor TDextTypeCodecPlan.Create(AType: PTypeInfo);
begin
  inherited Create;
  FByProtoTag := TCollections.CreateDictionary<Integer, Integer>;
  Build(AType);
end;

procedure TDextTypeCodecPlan.Build(AType: PTypeInfo);
var
  Meta: TTypeMetadata;
  Handler: IPropertyHandler;
  Member: TRttiMember;
  Prop: TRttiProperty;
  Field: TRttiField;
  Plan: TDextFieldPlan;
  Tag: Integer;
  Index: Integer;
  RttiType: TRttiType;
begin
  FTypeInfo := AType;
  FFields := [];
  FHasDirectAccess := False;
  FHasGeneratedCodec := False;

  Meta := TReflection.GetMetadata(AType);
  if (Meta = nil) or (Meta.RttiType = nil) then
    Exit;

  RttiType := Meta.RttiType;
  for Handler in Meta.PropertyHandlers do
  begin
    if (Handler = nil) or (Handler.Member = nil) then
      Continue;

    Member := Handler.Member;
    Tag := ReadProtoTag(Member);
    if Tag <= 0 then
      Continue;

    Plan := Default(TDextFieldPlan);
    Plan.Name := Handler.Name;
    Plan.ExternalName := Handler.Name;
    Plan.ProtoTag := ReadProtoTag(Member);
    Plan.Handler := Handler;
    Plan.AccessMode := amRtti;
    Plan.Offset := -1;
    Plan.ValueOffset := -1;
    Plan.HasValueOffset := -1;

    if Member is TRttiProperty then
    begin
      Prop := TRttiProperty(Member);
      Plan.TypeInfo := Prop.PropertyType.Handle;
      Plan.NativeKind := TDextTypeModel.NativeKindOf(Plan.TypeInfo);
      Plan.WireType := TDextTypeModel.ProtobufWireType(Plan.NativeKind);
      Plan.IsObject := Prop.PropertyType.TypeKind in [tkClass, tkInterface];
      Plan.IsList := TReflection.IsListType(Plan.TypeInfo);
      if Plan.IsList and Assigned(TReflection.GetListElementType(Plan.TypeInfo)) then
      begin
        Plan.ElementType := TReflection.GetListElementType(Plan.TypeInfo);
        Plan.ElementNativeKind := TDextTypeModel.NativeKindOf(Plan.ElementType);
        Plan.ListOwnsObjects := (Plan.ElementNativeKind = nkObject) and
          (Plan.ElementType.Kind = tkClass);
      end;

      Field := FindBackingField(RttiType, Prop);
      if (Field <> nil) and
         ((TDextTypeModel.IsDirectKind(Plan.NativeKind)) or
          ((Plan.NativeKind = nkObject) and (Plan.TypeInfo <> nil) and (Plan.TypeInfo.Kind = tkClass)) or
          ((Plan.NativeKind = nkList) and (Plan.TypeInfo <> nil) and (Plan.TypeInfo.Kind in [tkClass, tkInterface]))) then
      begin
        Plan.Offset := Field.Offset;
        Plan.AccessMode := amDirectField;
        FHasDirectAccess := True;
      end;
    end
    else if Member is TRttiField then
    begin
      Field := TRttiField(Member);
      Plan.TypeInfo := Field.FieldType.Handle;
      Plan.NativeKind := TDextTypeModel.NativeKindOf(Plan.TypeInfo);
      Plan.WireType := TDextTypeModel.ProtobufWireType(Plan.NativeKind);
      Plan.IsObject := Field.FieldType.TypeKind in [tkClass, tkInterface];
      Plan.IsList := TReflection.IsListType(Plan.TypeInfo);
      if Plan.IsList then
      begin
        Plan.ElementType := TReflection.GetListElementType(Plan.TypeInfo);
        Plan.ElementNativeKind := TDextTypeModel.NativeKindOf(Plan.ElementType);
        Plan.ListOwnsObjects := (Plan.ElementNativeKind = nkObject) and
          (Plan.ElementType.Kind = tkClass);
      end;
      if (TDextTypeModel.IsDirectKind(Plan.NativeKind)) or
         ((Plan.NativeKind = nkObject) and (Plan.TypeInfo <> nil) and (Plan.TypeInfo.Kind = tkClass)) or
         ((Plan.NativeKind = nkList) and (Plan.TypeInfo <> nil) and (Plan.TypeInfo.Kind in [tkClass, tkInterface])) then
      begin
        Plan.Offset := Field.Offset;
        Plan.AccessMode := amDirectField;
        FHasDirectAccess := True;
      end;
    end
    else
      Continue;

    Index := Length(FFields);
    SetLength(FFields, Index + 1);
    FFields[Index] := Plan;
  end;

  SortFields(FFields);
  FByProtoTag.Clear;
  for Index := 0 to Length(FFields) - 1 do
    FByProtoTag.AddOrSetValue(FFields[Index].ProtoTag, Index);
end;

function TDextTypeCodecPlan.FindBackingField(ARttiType: TRttiType;
  AProp: TRttiProperty): TRttiField;
begin
  Result := nil;
  if (ARttiType = nil) or (AProp = nil) or (AProp.PropertyType = nil) then
    Exit;

  Result := ARttiType.GetField('F' + AProp.Name);
  if (Result = nil) or (Result.FieldType = nil) or
     (Result.FieldType.Handle <> AProp.PropertyType.Handle) then
  begin
    Result := ARttiType.GetField('_' + AProp.Name);
    if (Result = nil) or (Result.FieldType = nil) or
       (Result.FieldType.Handle <> AProp.PropertyType.Handle) then
      Result := nil;
  end;
end;

function TDextTypeCodecPlan.GetFields: TArray<TDextFieldPlan>;
begin
  Result := Copy(FFields);
end;

function TDextTypeCodecPlan.GetTypeInfo: PTypeInfo;
begin
  Result := FTypeInfo;
end;

function TDextTypeCodecPlan.HasDirectAccess: Boolean;
begin
  Result := FHasDirectAccess;
end;

function TDextTypeCodecPlan.HasGeneratedCodec: Boolean;
begin
  Result := FHasGeneratedCodec;
end;

function TDextTypeCodecPlan.ReadProtoTag(AMember: TRttiMember): Integer;
var
  Attr: TCustomAttribute;
begin
  Result := 0;
  if AMember = nil then
    Exit;

  for Attr in AMember.GetAttributes do
    if Attr is ProtoMemberAttribute then
      Exit(ProtoMemberAttribute(Attr).Tag);
end;

class procedure TDextTypeCodecPlan.SortFields(var AFields: TArray<TDextFieldPlan>);
var
  i: Integer;
  j: Integer;
  Temp: TDextFieldPlan;
begin
  for i := 0 to Length(AFields) - 2 do
    for j := i + 1 to Length(AFields) - 1 do
      if ((AFields[j].ProtoTag > 0) and (AFields[i].ProtoTag = 0)) or
         ((AFields[j].ProtoTag > 0) and (AFields[i].ProtoTag > 0) and
          (AFields[j].ProtoTag < AFields[i].ProtoTag)) or
         ((AFields[j].ProtoTag = 0) and (AFields[i].ProtoTag = 0) and
          (CompareText(AFields[j].Name, AFields[i].Name) < 0)) then
      begin
        Temp := AFields[i];
        AFields[i] := AFields[j];
        AFields[j] := Temp;
      end;
end;

function TDextTypeCodecPlan.TryGetFieldByProtoTag(ATag: Integer;
  out AField: TDextFieldPlan): Boolean;
var
  Index: Integer;
begin
  Result := FByProtoTag.TryGetValue(ATag, Index);
  if Result then
    AField := FFields[Index]
  else
    AField := Default(TDextFieldPlan);
end;

end.

