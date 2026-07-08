{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}
unit Dext.Serialization.Protobuf;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  Dext.Collections.Dict,
  Dext.Collections,
  Dext.Core.Reflection,
  Dext.Grpc.Attributes;

type
  TProtobufSerializer = class
  private
    class procedure WriteVarint(Stream: TStream; Value: UInt64); static;
    class function ReadVarint(Stream: TStream): UInt64; static;
    class procedure WriteTag(Stream: TStream; Tag: Integer;
      WireType: Integer); static;
    class procedure WriteDouble(Stream: TStream; Value: Double); static;
    class function ReadDouble(Stream: TStream): Double; static;
    class procedure WriteSingle(Stream: TStream; Value: Single); static;
    class function ReadSingle(Stream: TStream): Single; static;
    class procedure SerializeField(Stream: TStream; Tag: Integer;
      const Value: TValue); static;
    class function DeserializeField(Stream: TStream; WireType: Integer;
      TypeInfoVal: PTypeInfo): TValue; static;
  public
    class function Serialize(Obj: TObject): TBytes; static;
    class procedure Deserialize(const Bytes: TBytes; Obj: TObject); static;
  end;

implementation

{ TProtobufSerializer }

class procedure TProtobufSerializer.WriteVarint(Stream: TStream; Value: UInt64);
var
  b: Byte;
begin
  while Value >= $80 do
  begin
    b := Byte((Value and $7F) or $80);
    Stream.Write(b, 1);
    Value := Value shr 7;
  end;
  b := Byte(Value);
  Stream.Write(b, 1);
end;

class function TProtobufSerializer.ReadVarint(Stream: TStream): UInt64;
var
  b: Byte;
  Shift: Integer;
begin
  Result := 0;
  Shift := 0;
  repeat
    if Stream.Read(b, 1) <> 1 then
      Exit;
    Result := Result or (UInt64(b and $7F) shl Shift);
    Inc(Shift, 7);
  until (b and $80) = 0;
end;

class procedure TProtobufSerializer.WriteTag(Stream: TStream; Tag: Integer;
  WireType: Integer);
begin
  WriteVarint(Stream, (UInt64(Tag) shl 3) or UInt64(WireType));
end;

class procedure TProtobufSerializer.WriteDouble(Stream: TStream; Value: Double);
begin
  Stream.Write(Value, SizeOf(Double));
end;

class function TProtobufSerializer.ReadDouble(Stream: TStream): Double;
begin
  Result := 0;
  Stream.Read(Result, SizeOf(Double));
end;

class procedure TProtobufSerializer.WriteSingle(Stream: TStream; Value: Single);
begin
  Stream.Write(Value, SizeOf(Single));
end;

class function TProtobufSerializer.ReadSingle(Stream: TStream): Single;
begin
  Result := 0;
  Stream.Read(Result, SizeOf(Single));
end;

class procedure TProtobufSerializer.SerializeField(Stream: TStream;
  Tag: Integer; const Value: TValue);
var
  Bytes: TBytes;
  i: Integer;
  ItemVal: TValue;
  NestedBytes: TBytes;
  NestedObj: TObject;
  ObjList: IObjectList;
  Str: string;
  TypeInfoVal: PTypeInfo;
  Intf: IInterface;
begin
  if Value.IsEmpty then Exit;

  TypeInfoVal := Value.TypeInfo;
  case TypeInfoVal.Kind of
    tkInteger:
    begin
      WriteTag(Stream, Tag, 0);
      WriteVarint(Stream, Value.AsInteger);
    end;
    tkInt64:
    begin
      WriteTag(Stream, Tag, 0);
      WriteVarint(Stream, Value.AsInt64);
    end;
    tkEnumeration:
    begin
      WriteTag(Stream, Tag, 0);
      if TypeInfoVal = TypeInfo(Boolean) then
      begin
        if Value.AsBoolean then
          WriteVarint(Stream, 1)
        else
          WriteVarint(Stream, 0);
      end
      else
        WriteVarint(Stream, Value.AsOrdinal);
    end;
    tkFloat:
    begin
      if TypeInfoVal = TypeInfo(Double) then
      begin
        WriteTag(Stream, Tag, 1);
        WriteDouble(Stream, Value.AsType<Double>);
      end
      else if TypeInfoVal = TypeInfo(TDateTime) then
      begin
        WriteTag(Stream, Tag, 1);
        WriteDouble(Stream, Value.AsType<TDateTime>);
      end
      else if TypeInfoVal = TypeInfo(Single) then
      begin
        WriteTag(Stream, Tag, 5);
        WriteSingle(Stream, Value.AsType<Single>);
      end;
    end;
    tkUString, tkString, tkWString, tkChar, tkWChar:
    begin
      Str := Value.AsString;
      Bytes := TEncoding.UTF8.GetBytes(Str);
      WriteTag(Stream, Tag, 2);
      WriteVarint(Stream, Length(Bytes));
      if Length(Bytes) > 0 then
        Stream.Write(Bytes[0], Length(Bytes));
    end;
    tkClass:
    begin
      NestedObj := Value.AsObject;
      if Assigned(NestedObj) then
      begin
        if Supports(NestedObj, IObjectList, ObjList) then
        begin
          for i := 0 to ObjList.Count - 1 do
          begin
            ItemVal := TValue.From<TObject>(ObjList.GetItem(i));
            SerializeField(Stream, Tag, ItemVal);
          end;
        end
        else
        begin
          NestedBytes := Serialize(NestedObj);
          WriteTag(Stream, Tag, 2);
          WriteVarint(Stream, Length(NestedBytes));
          if Length(NestedBytes) > 0 then
            Stream.Write(NestedBytes[0], Length(NestedBytes));
        end;
      end;
    end;
    tkInterface:
    begin
      Intf := Value.AsInterface;
      if Assigned(Intf) then
      begin
        if Supports(Intf, IObjectList, ObjList) then
        begin
          for i := 0 to ObjList.Count - 1 do
          begin
            ItemVal := TValue.From<TObject>(ObjList.GetItem(i));
            SerializeField(Stream, Tag, ItemVal);
          end;
        end;
      end;
    end;
    tkDynArray:
    begin
      if TypeInfoVal = TypeInfo(TBytes) then
      begin
        Bytes := Value.AsType<TBytes>;
        WriteTag(Stream, Tag, 2);
        WriteVarint(Stream, Length(Bytes));
        if Length(Bytes) > 0 then
          Stream.Write(Bytes[0], Length(Bytes));
      end;
    end;
  end;
end;

class function TProtobufSerializer.DeserializeField(Stream: TStream;
  WireType: Integer; TypeInfoVal: PTypeInfo): TValue;
var
  VarintVal: UInt64;
  DoubleVal: Double;
  SingleVal: Single;
  Len: UInt64;
  Bytes: TBytes;
  NestedObj: TObject;
begin
  Result := TValue.Empty;
  case TypeInfoVal.Kind of
    tkInteger:
    begin
      VarintVal := ReadVarint(Stream);
      Result := TValue.From<Integer>(Integer(VarintVal));
    end;
    tkInt64:
    begin
      VarintVal := ReadVarint(Stream);
      Result := TValue.From<Int64>(Int64(VarintVal));
    end;
    tkEnumeration:
    begin
      VarintVal := ReadVarint(Stream);
      if TypeInfoVal = TypeInfo(Boolean) then
        Result := TValue.From<Boolean>(VarintVal <> 0)
      else
        Result := TValue.FromOrdinal(TypeInfoVal, VarintVal);
    end;
    tkFloat:
    begin
      if WireType = 1 then
      begin
        DoubleVal := ReadDouble(Stream);
        if TypeInfoVal = TypeInfo(TDateTime) then
          Result := TValue.From<TDateTime>(DoubleVal)
        else
          Result := TValue.From<Double>(DoubleVal);
      end
      else if WireType = 5 then
      begin
        SingleVal := ReadSingle(Stream);
        Result := TValue.From<Single>(SingleVal);
      end;
    end;
    tkUString, tkString, tkWString, tkChar, tkWChar:
    begin
      Len := ReadVarint(Stream);
      if Len > 0 then
      begin
        SetLength(Bytes, Len);
        Stream.Read(Bytes[0], Len);
        Result := TValue.From<string>(TEncoding.UTF8.GetString(Bytes));
      end
      else
        Result := TValue.From<string>('');
    end;
    tkClass:
    begin
      Len := ReadVarint(Stream);
      if TypeInfoVal.TypeData <> nil then
      begin
        NestedObj := TypeInfoVal.TypeData.ClassType.Create;
        if Len > 0 then
        begin
          SetLength(Bytes, Len);
          Stream.Read(Bytes[0], Len);
          Deserialize(Bytes, NestedObj);
        end;
        Result := NestedObj;
      end;
    end;
    tkDynArray:
    begin
      if TypeInfoVal = TypeInfo(TBytes) then
      begin
        Len := ReadVarint(Stream);
        if Len > 0 then
        begin
          SetLength(Bytes, Len);
          Stream.Read(Bytes[0], Len);
          Result := TValue.From<TBytes>(Bytes);
        end
        else
          Result := TValue.From<TBytes>(nil);
      end;
    end;
  end;
end;

class function TProtobufSerializer.Serialize(Obj: TObject): TBytes;
var
  Stream: TMemoryStream;
  Context: TRttiContext;
  RttiType: TRttiType;
  Props: TArray<TRttiProperty>;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ProtoAttr: ProtoMemberAttribute;
  Val: TValue;
begin
  if not Assigned(Obj) then
    Exit(nil);

  Stream := TMemoryStream.Create;
  try
    Context := TReflection.Context;
    RttiType := Context.GetType(Obj.ClassType);
    if Assigned(RttiType) then
    begin
      Props := RttiType.GetProperties;
      for Prop in Props do
      begin
        for Attr in Prop.GetAttributes do
        begin
          if Attr is ProtoMemberAttribute then
          begin
            ProtoAttr := ProtoMemberAttribute(Attr);
            Val := Prop.GetValue(Obj);
            SerializeField(Stream, ProtoAttr.Tag, Val);
            Break;
          end;
        end;
      end;
    end;
    SetLength(Result, Stream.Size);
    if Stream.Size > 0 then
      Move(Stream.Memory^, Result[0], Stream.Size);
  finally
    Stream.Free;
  end;
end;

class procedure TProtobufSerializer.Deserialize(const Bytes: TBytes;
  Obj: TObject);
var
  Stream: TBytesStream;
  Context: TRttiContext;
  RttiType: TRttiType;
  Props: TArray<TRttiProperty>;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ProtoAttr: ProtoMemberAttribute;
  TagMap: IDictionary<Integer, TRttiProperty>;
  Tag: Integer;
  WireType: Integer;
  Header: UInt64;
  Decoded: TValue;
  ListObj: TObject;
  ObjList: IObjectList;
  TypeName: string;
  StartPos: Integer;
  EndPos: Integer;
  ItemTypeName: string;
  ItemType: TRttiType;
  t: TRttiType;
  ShortName: string;
  DotPos: Integer;
  ListIntf: IInterface;
begin
  if (Length(Bytes) = 0) or not Assigned(Obj) then
    Exit;

  Stream := TBytesStream.Create(Bytes);
  TagMap := TCollections.CreateDictionary<Integer, TRttiProperty>;
  try
    Context := TReflection.Context;
    RttiType := Context.GetType(Obj.ClassType);
    if Assigned(RttiType) then
    begin
      Props := RttiType.GetProperties;
      for Prop in Props do
      begin
        for Attr in Prop.GetAttributes do
        begin
          if Attr is ProtoMemberAttribute then
          begin
            ProtoAttr := ProtoMemberAttribute(Attr);
            TagMap.Add(ProtoAttr.Tag, Prop);
            Break;
          end;
        end;
      end;
    end;

    while Stream.Position < Stream.Size do
    begin
      Header := ReadVarint(Stream);
      Tag := Header shr 3;
      WireType := Header and 7;

      if TagMap.TryGetValue(Tag, Prop) then
      begin
        if (Prop.PropertyType.TypeKind = tkClass) or
           (Prop.PropertyType.TypeKind = tkInterface) then
        begin
          ObjList := nil;
          if Prop.PropertyType.TypeKind = tkInterface then
          begin
            ListIntf := Prop.GetValue(Obj).AsInterface;
            if Assigned(ListIntf) then
              Supports(ListIntf, IObjectList, ObjList);
          end
          else
          begin
            ListObj := Prop.GetValue(Obj).AsObject;
            if not Assigned(ListObj) then
            begin
              ListObj := TRttiInstanceType(Prop.PropertyType)
                .MetaclassType.Create;
              Prop.SetValue(Obj, ListObj);
            end;
            Supports(ListObj, IObjectList, ObjList);
          end;

          if Assigned(ObjList) then
          begin
            TypeName := Prop.PropertyType.Name;
            StartPos := Pos('<', TypeName);
            EndPos := Pos('>', TypeName);
            if (StartPos > 0) and (EndPos > StartPos) then
            begin
              ItemTypeName := Copy(TypeName, StartPos + 1,
                EndPos - StartPos - 1);
              ItemType := Context.FindType(ItemTypeName);
              if not Assigned(ItemType) then
              begin
                ShortName := ItemTypeName;
                DotPos := LastDelimiter('.', ItemTypeName);
                if DotPos > 0 then
                  ShortName := Copy(ItemTypeName, DotPos + 1, MaxInt);

                for t in Context.GetTypes do
                begin
                  if SameText(t.QualifiedName, ItemTypeName) or
                     SameText(t.Name, ShortName) then
                  begin
                    ItemType := t;
                    Break;
                  end;
                end;
              end;

              if Assigned(ItemType) then
              begin
                Decoded := DeserializeField(Stream, WireType,
                  ItemType.Handle);
                if not Decoded.IsEmpty then
                  ObjList.Add(Decoded.AsObject);
              end
              else
              begin
                case WireType of
                  0: ReadVarint(Stream);
                  1: Stream.Position := Stream.Position + 8;
                  2: Stream.Position := Stream.Position +
                       Int64(ReadVarint(Stream));
                  5: Stream.Position := Stream.Position + 4;
                end;
              end;
            end;
          end
          else if Prop.PropertyType.TypeKind = tkClass then
          begin
            Decoded := DeserializeField(Stream, WireType,
              Prop.PropertyType.Handle);
            if not Decoded.IsEmpty then
              Prop.SetValue(Obj, Decoded);
          end;
        end
        else
        begin
          Decoded := DeserializeField(Stream, WireType,
            Prop.PropertyType.Handle);
          if not Decoded.IsEmpty then
            Prop.SetValue(Obj, Decoded);
        end;
      end
      else
      begin
        // Skip unknown field
        case WireType of
          0: ReadVarint(Stream);
          1: Stream.Position := Stream.Position + 8;
          2: Stream.Position := Stream.Position + Int64(ReadVarint(Stream));
          5: Stream.Position := Stream.Position + 4;
        else
          raise Exception.CreateFmt('Invalid wire type %d at tag %d',
            [WireType, Tag]);
        end;
      end;
    end;
  finally
    Stream.Free;
  end;
end;

end.
