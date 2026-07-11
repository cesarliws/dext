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
  System.Classes,
  System.Rtti,
  System.SyncObjs,
  System.SysUtils,
  System.TypInfo,
  Dext.Codecs.Registry,
  Dext.Collections,
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Core.Activator,
  Dext.Core.DirectAccess,
  Dext.Core.Span,
  Dext.Core.Reflection,
  Dext.Core.TypeModel,
  Dext.Types.UUID,
  Dext.Grpc.Attributes;

type
  /// <summary>Selects the serialization tier used by the protobuf codec.</summary>
  TProtobufCodecMode = (pcmAuto, pcmRtti, pcmDirect, pcmGenerated);

  /// <summary>Streaming protobuf writer used by generated and direct codecs.</summary>
  TProtobufWriter = class
  private
    FStream: TStream;
  public
    /// <summary>Creates a writer over the provided stream.</summary>
    /// <summary>Creates a reader over the provided stream.</summary>
    constructor Create(AStream: TStream);
    /// <summary>Writes a protobuf varint to the underlying stream.</summary>
    procedure WriteVarint(Value: UInt64);
    /// <summary>Writes a protobuf field tag and wire type.</summary>
    procedure WriteTag(Tag: Integer; WireType: Integer);
    /// <summary>Writes a 64-bit floating-point value.</summary>
    procedure WriteDouble(Value: Double);
    /// <summary>Writes a 32-bit floating-point value.</summary>
    procedure WriteSingle(Value: Single);
    /// <summary>Writes a signed 32-bit integer field.</summary>
    procedure WriteInt32(Tag: Integer; Value: Integer);
    /// <summary>Writes a signed 64-bit integer field.</summary>
    procedure WriteInt64(Tag: Integer; Value: Int64);
    /// <summary>Writes a boolean field.</summary>
    procedure WriteBool(Tag: Integer; Value: Boolean);
    /// <summary>Writes a UTF-8 string field.</summary>
    procedure WriteString(Tag: Integer; const Value: string);
    /// <summary>Writes a bytes field.</summary>
    procedure WriteBytes(Tag: Integer; const Value: TBytes);
    /// <summary>Writes a length-delimited nested message field.</summary>
    procedure WriteMessage(Tag: Integer; const Value: TBytes);
  end;

  /// <summary>Streaming protobuf reader used by generated and direct codecs.</summary>
  TProtobufReader = class
  private
    FStream: TStream;
    FTag: Integer;
    FWireType: Integer;
  public
    /// <summary>Creates a writer over the provided stream.</summary>
    /// <summary>Creates a reader over the provided stream.</summary>
    constructor Create(AStream: TStream);
    /// <summary>Advances to the next field and returns False at end of stream.</summary>
    function ReadField: Boolean;
    /// <summary>Reads a protobuf varint from the underlying stream.</summary>
    function ReadVarint: UInt64;
    /// <summary>Reads a 64-bit floating-point value.</summary>
    function ReadDouble: Double;
    /// <summary>Reads a 32-bit floating-point value.</summary>
    function ReadSingle: Single;
    /// <summary>Reads a signed 32-bit integer value.</summary>
    function ReadInt32: Integer;
    /// <summary>Reads a signed 64-bit integer value.</summary>
    function ReadInt64: Int64;
    /// <summary>Reads a boolean value.</summary>
    function ReadBool: Boolean;
    /// <summary>Reads a UTF-8 string value.</summary>
    function ReadString: string;
    /// <summary>Reads a length-delimited bytes payload.</summary>
    function ReadBytes: TBytes;
    /// <summary>Skips the current field payload.</summary>
    procedure SkipField;
    property Tag: Integer read FTag;
    property WireType: Integer read FWireType;
  end;

  TProtobufReadOnlySpanStream = class(TCustomMemoryStream)
  public
    constructor Create(const ABytes: TByteSpan);
    procedure Init(const ABytes: TByteSpan);
  end;

  /// <summary>High-level protobuf serializer with RTTI, direct-offset, and generated-code paths.</summary>
  TProtobufSerializer = class
  private
    class var FCache: IDictionary<TClass, IDictionary<Integer, IPropertyHandler>>;
    class var FLock: TCriticalSection;
    class constructor Create;
    class destructor Destroy;
    class function GetTagMap(AClass: TClass): IDictionary<Integer,
      IPropertyHandler>; static;
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
    class function TryReadSpan(Stream: TStream; Len: NativeInt;
      out Span: TByteSpan): Boolean; static;
    class function ReadUtf8String(Stream: TStream; Len: NativeInt): string; static;
    class function TrySerializeGenerated(Obj: TObject; out Bytes: TBytes): Boolean; static;
    class function TryDeserializeGenerated(const Bytes: TBytes; Obj: TObject): Boolean; overload; static;
    class function TryDeserializeGenerated(const Bytes: TByteSpan; Obj: TObject): Boolean; overload; static;
    class function TrySerializeDirect(Obj: TObject; out Bytes: TBytes): Boolean; static;
    class function TryDeserializeDirect(const Bytes: TBytes; Obj: TObject): Boolean; overload; static;
    class function TryDeserializeDirect(const Bytes: TByteSpan; Obj: TObject): Boolean; overload; static;
    class procedure SerializeDirectField(Stream: TStream; Obj: TObject;
      const Field: TDextFieldPlan); static;
    class function DeserializeDirectField(Stream: TStream; Obj: TObject;
      const Field: TDextFieldPlan; WireType: Integer): Boolean; static;
    class procedure SkipField(Stream: TStream; WireType: Integer); static;
  public
    /// <summary>Serializes an object using the selected codec mode.</summary>
    class function Serialize(Obj: TObject;
      Mode: TProtobufCodecMode = pcmAuto): TBytes; static;
    /// <summary>Deserializes a protobuf payload into an object using the selected codec mode.</summary>
    class procedure Deserialize(const Bytes: TBytes; Obj: TObject;
      Mode: TProtobufCodecMode = pcmAuto); overload; static;
    class procedure Deserialize(const Bytes: TByteSpan; Obj: TObject;
      Mode: TProtobufCodecMode = pcmAuto); overload; static;
  end;

implementation

{ TProtobufWriter }

constructor TProtobufWriter.Create(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
end;

procedure TProtobufWriter.WriteBool(Tag: Integer; Value: Boolean);
begin
  WriteTag(Tag, 0);
  if Value then
    WriteVarint(1)
  else
    WriteVarint(0);
end;

procedure TProtobufWriter.WriteBytes(Tag: Integer; const Value: TBytes);
begin
  WriteMessage(Tag, Value);
end;

procedure TProtobufWriter.WriteDouble(Value: Double);
begin
  FStream.Write(Value, SizeOf(Double));
end;

procedure TProtobufWriter.WriteInt32(Tag: Integer; Value: Integer);
begin
  WriteTag(Tag, 0);
  WriteVarint(UInt64(Value));
end;

procedure TProtobufWriter.WriteInt64(Tag: Integer; Value: Int64);
begin
  WriteTag(Tag, 0);
  WriteVarint(UInt64(Value));
end;

procedure TProtobufWriter.WriteMessage(Tag: Integer; const Value: TBytes);
begin
  WriteTag(Tag, 2);
  WriteVarint(Length(Value));
  if Length(Value) > 0 then
    FStream.Write(Value[0], Length(Value));
end;

procedure TProtobufWriter.WriteSingle(Value: Single);
begin
  FStream.Write(Value, SizeOf(Single));
end;

procedure TProtobufWriter.WriteString(Tag: Integer; const Value: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(Value);
  WriteMessage(Tag, Bytes);
end;

procedure TProtobufWriter.WriteTag(Tag, WireType: Integer);
begin
  WriteVarint((UInt64(Tag) shl 3) or UInt64(WireType));
end;

procedure TProtobufWriter.WriteVarint(Value: UInt64);
var
  b: Byte;
begin
  while Value >= $80 do
  begin
    b := Byte((Value and $7F) or $80);
    FStream.Write(b, 1);
    Value := Value shr 7;
  end;
  b := Byte(Value);
  FStream.Write(b, 1);
end;

{ TProtobufReader }

constructor TProtobufReader.Create(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
end;

constructor TProtobufReadOnlySpanStream.Create(const ABytes: TByteSpan);
begin
  inherited Create;
  Init(ABytes);
end;

procedure TProtobufReadOnlySpanStream.Init(const ABytes: TByteSpan);
begin
  if (ABytes.Data <> nil) and (ABytes.Length > 0) then
    SetPointer(ABytes.Data, ABytes.Length)
  else
    SetPointer(nil, 0);
  Position := 0;
end;

function TProtobufReader.ReadBool: Boolean;
begin
  Result := ReadVarint <> 0;
end;

function TProtobufReader.ReadBytes: TBytes;
var
  Len: UInt64;
begin
  Len := ReadVarint;
  SetLength(Result, Len);
  if Len > 0 then
    FStream.Read(Result[0], Len);
end;

function TProtobufReader.ReadDouble: Double;
begin
  Result := 0;
  FStream.Read(Result, SizeOf(Double));
end;

function TProtobufReader.ReadField: Boolean;
var
  Header: UInt64;
begin
  Result := FStream.Position < FStream.Size;
  if not Result then
    Exit;

  Header := ReadVarint;
  FTag := Header shr 3;
  FWireType := Header and 7;
end;

function TProtobufReader.ReadInt32: Integer;
begin
  Result := Integer(ReadVarint);
end;

function TProtobufReader.ReadInt64: Int64;
begin
  Result := Int64(ReadVarint);
end;

function TProtobufReader.ReadSingle: Single;
begin
  Result := 0;
  FStream.Read(Result, SizeOf(Single));
end;

function TProtobufReader.ReadString: string;
begin
  Result := TEncoding.UTF8.GetString(ReadBytes);
end;

function TProtobufReader.ReadVarint: UInt64;
var
  b: Byte;
  Shift: Integer;
begin
  Result := 0;
  Shift := 0;
  repeat
    if FStream.Read(b, 1) <> 1 then
      Exit;
    Result := Result or (UInt64(b and $7F) shl Shift);
    Inc(Shift, 7);
  until (b and $80) = 0;
end;

procedure TProtobufReader.SkipField;
begin
  TProtobufSerializer.SkipField(FStream, FWireType);
end;

{ TProtobufSerializer }

class constructor TProtobufSerializer.Create;
begin
  FCache := TCollections.CreateDictionary<TClass, IDictionary<Integer,
    IPropertyHandler>>;
  FLock := TCriticalSection.Create;
end;

class destructor TProtobufSerializer.Destroy;
begin
  FLock.Free;
end;

class function TProtobufSerializer.GetTagMap(AClass: TClass):
  IDictionary<Integer, IPropertyHandler>;
var
  Meta: TTypeMetadata;
  Handler: IPropertyHandler;
  Attr: TCustomAttribute;
  ProtoAttr: ProtoMemberAttribute;
begin
  FLock.Acquire;
  try
    if not FCache.TryGetValue(AClass, Result) then
    begin
      Result := TCollections.CreateDictionary<Integer, IPropertyHandler>;
      Meta := TReflection.GetMetadata(AClass.ClassInfo);
      if Assigned(Meta) then
      begin
        for Handler in Meta.PropertyHandlers do
        begin
          if Assigned(Handler.Member) then
          begin
            for Attr in Handler.Member.GetAttributes do
            begin
              if Attr is ProtoMemberAttribute then
              begin
                ProtoAttr := ProtoMemberAttribute(Attr);
                Result.Add(ProtoAttr.Tag, Handler);
                Break;
              end;
            end;
          end;
        end;
      end;
      FCache.Add(AClass, Result);
    end;
  finally
    FLock.Release;
  end;
end;

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
    tkRecord:
    begin
      if TypeInfoVal = TypeInfo(TGUID) then
      begin
        Str := GUIDToString(Value.AsType<TGUID>);
        Bytes := TEncoding.UTF8.GetBytes(Str);
        WriteTag(Stream, Tag, 2);
        WriteVarint(Stream, Length(Bytes));
        if Length(Bytes) > 0 then
          Stream.Write(Bytes[0], Length(Bytes));
      end
      else if TypeInfoVal = TypeInfo(TUUID) then
      begin
        Str := Value.AsType<TUUID>.ToString;
        Bytes := TEncoding.UTF8.GetBytes(Str);
        WriteTag(Stream, Tag, 2);
        WriteVarint(Stream, Length(Bytes));
        if Length(Bytes) > 0 then
          Stream.Write(Bytes[0], Length(Bytes));
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

class function TProtobufSerializer.TryReadSpan(Stream: TStream; Len: NativeInt;
  out Span: TByteSpan): Boolean;
var
  MemStream: TCustomMemoryStream;
  P: PByte;
begin
  Result := False;
  Span := TByteSpan.Create(nil, 0);
  if Len < 0 then
    Exit;

  if not (Stream is TCustomMemoryStream) then
    Exit;

  MemStream := TCustomMemoryStream(Stream);
  if (MemStream.Position + Len) > MemStream.Size then
    Exit;

  P := PByte(MemStream.Memory) + MemStream.Position;
  Span := TByteSpan.Create(P, Len);
  MemStream.Position := MemStream.Position + Len;
  Result := True;
end;

class function TProtobufSerializer.ReadUtf8String(Stream: TStream; Len: NativeInt): string;
var
  Bytes: TBytes;
begin
  if Len <= 0 then
    Exit('');

  SetLength(Bytes, Len);
  Stream.Read(Bytes[0], Len);
  Result := TEncoding.UTF8.GetString(Bytes);
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
  Span: TByteSpan;
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
      Result := TValue.From<string>(ReadUtf8String(Stream, Len));
    end;
    tkClass:
    begin
      Len := ReadVarint(Stream);
      if TypeInfoVal.TypeData <> nil then
      begin
        NestedObj := TypeInfoVal.TypeData.ClassType.Create;
        if Len > 0 then
        begin
          if TryReadSpan(Stream, Len, Span) then
            Deserialize(Span, NestedObj)
          else
          begin
            SetLength(Bytes, Len);
            Stream.Read(Bytes[0], Len);
            Deserialize(Bytes, NestedObj);
          end;
        end;
        Result := NestedObj;
      end;
    end;
    tkRecord:
    begin
      Len := ReadVarint(Stream);
      if TypeInfoVal = TypeInfo(TGUID) then
        Result := TValue.From<TGUID>(StringToGUID(ReadUtf8String(Stream, Len)))
      else if TypeInfoVal = TypeInfo(TUUID) then
        Result := TValue.From<TUUID>(TUUID.FromString(ReadUtf8String(Stream, Len)))
      else if Len > 0 then
        Stream.Position := Stream.Position + Int64(Len);
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

class procedure TProtobufSerializer.SkipField(Stream: TStream; WireType: Integer);
begin
  case WireType of
    0: ReadVarint(Stream);
    1: Stream.Position := Stream.Position + 8;
    2: Stream.Position := Stream.Position + Int64(ReadVarint(Stream));
    5: Stream.Position := Stream.Position + 4;
  else
    raise Exception.CreateFmt('Invalid wire type %d', [WireType]);
  end;
end;

class function TProtobufSerializer.TrySerializeGenerated(Obj: TObject;
  out Bytes: TBytes): Boolean;
var
  Stream: TBytesStream;
  Writer: TProtobufWriter;
  WriteProc: TDextCodecWriteProc;
  ReadProc: TDextCodecReadProc;
  Len: NativeInt;
begin
  Result := False;
  Bytes := nil;
  if not Assigned(Obj) then
    Exit;

  if not TDextCodecRegistry.TryGetProtobuf(Obj.ClassInfo, WriteProc, ReadProc) or
     not Assigned(WriteProc) then
    Exit;

  Stream := TBytesStream.Create(nil);
  try
    Writer := TProtobufWriter.Create(Stream);
    try
      WriteProc(Writer, Obj);
    finally
      Writer.Free;
    end;
    Bytes := Stream.Bytes;
    Len := Stream.Size;
  finally
    Stream.Free;
  end;
  SetLength(Bytes, Len);
  Result := True;
end;

class function TProtobufSerializer.TryDeserializeGenerated(const Bytes: TBytes;
  Obj: TObject): Boolean;
begin
  if Length(Bytes) > 0 then
    Result := TryDeserializeGenerated(TByteSpan.Create(@Bytes[0], Length(Bytes)), Obj)
  else
    Result := False;
end;

class function TProtobufSerializer.TryDeserializeGenerated(const Bytes: TByteSpan;
  Obj: TObject): Boolean;
var
  Stream: TProtobufReadOnlySpanStream;
  Reader: TProtobufReader;
  WriteProc: TDextCodecWriteProc;
  ReadProc: TDextCodecReadProc;
begin
  Result := False;
  if (Bytes.Length = 0) or not Assigned(Obj) then
    Exit;

  if not TDextCodecRegistry.TryGetProtobuf(Obj.ClassInfo, WriteProc, ReadProc) or
     not Assigned(ReadProc) then
    Exit;

  Stream := TProtobufReadOnlySpanStream.Create(Bytes);
  try
    Reader := TProtobufReader.Create(Stream);
    try
      ReadProc(Reader, Obj);
    finally
      Reader.Free;
    end;
  finally
    Stream.Free;
  end;
  Result := True;
end;

class procedure TProtobufSerializer.SerializeDirectField(Stream: TStream;
  Obj: TObject; const Field: TDextFieldPlan);
var
  Bytes: TBytes;
  NestedObj: TObject;
  Value: TValue;
begin
  if (Field.AccessMode <> amDirectField) or (Field.Offset < 0) then
  begin
    Value := Field.Handler.GetValue(Obj);
    SerializeField(Stream, Field.ProtoTag, Value);
    Exit;
  end;

  case Field.NativeKind of
    nkInt32:
      begin
        WriteTag(Stream, Field.ProtoTag, 0);
        WriteVarint(Stream, UInt64(TDextDirectAccess.ReadInt32(Obj, Field.Offset)));
      end;
    nkInt64:
      begin
        WriteTag(Stream, Field.ProtoTag, 0);
        WriteVarint(Stream, UInt64(TDextDirectAccess.ReadInt64(Obj, Field.Offset)));
      end;
    nkBoolean:
      begin
        WriteTag(Stream, Field.ProtoTag, 0);
        if TDextDirectAccess.ReadBoolean(Obj, Field.Offset) then
          WriteVarint(Stream, 1)
        else
          WriteVarint(Stream, 0);
      end;
    nkSingle:
      begin
        WriteTag(Stream, Field.ProtoTag, 5);
        WriteSingle(Stream, TDextDirectAccess.ReadSingle(Obj, Field.Offset));
      end;
    nkDouble, nkCurrency, nkDateTime:
      begin
        WriteTag(Stream, Field.ProtoTag, 1);
        if Field.NativeKind = nkCurrency then
          WriteDouble(Stream, TDextDirectAccess.ReadCurrency(Obj, Field.Offset))
        else
          WriteDouble(Stream, TDextDirectAccess.ReadDouble(Obj, Field.Offset));
      end;
    nkString:
      begin
        Bytes := TEncoding.UTF8.GetBytes(TDextDirectAccess.ReadString(Obj, Field.Offset));
        WriteTag(Stream, Field.ProtoTag, 2);
        WriteVarint(Stream, Length(Bytes));
        if Length(Bytes) > 0 then
          Stream.Write(Bytes[0], Length(Bytes));
      end;
    nkGuid:
      begin
        Bytes := TEncoding.UTF8.GetBytes(GUIDToString(TDextDirectAccess.ReadGUID(Obj, Field.Offset)));
        WriteTag(Stream, Field.ProtoTag, 2);
        WriteVarint(Stream, Length(Bytes));
        if Length(Bytes) > 0 then
          Stream.Write(Bytes[0], Length(Bytes));
      end;
    nkUuid:
      begin
        Bytes := TEncoding.UTF8.GetBytes(TDextDirectAccess.ReadUUID(Obj, Field.Offset).ToString);
        WriteTag(Stream, Field.ProtoTag, 2);
        WriteVarint(Stream, Length(Bytes));
        if Length(Bytes) > 0 then
          Stream.Write(Bytes[0], Length(Bytes));
      end;
    nkObject:
      begin
        NestedObj := TDextDirectAccess.ReadObject(Obj, Field.Offset);
        if Assigned(NestedObj) then
        begin
          Bytes := Serialize(NestedObj);
          WriteTag(Stream, Field.ProtoTag, 2);
          WriteVarint(Stream, Length(Bytes));
          if Length(Bytes) > 0 then
            Stream.Write(Bytes[0], Length(Bytes));
        end;
      end;
  else
    Value := Field.Handler.GetValue(Obj);
    SerializeField(Stream, Field.ProtoTag, Value);
  end;
end;

class function TProtobufSerializer.DeserializeDirectField(Stream: TStream;
  Obj: TObject; const Field: TDextFieldPlan; WireType: Integer): Boolean;
var
  VarintVal: UInt64;
  Len: UInt64;
  Bytes: TBytes;
  NestedObj: TObject;
  ListObj: TObject;
  ListIntf: IInterface;
  ObjList: IObjectList;
  Collection: ICollection;
  ItemObj: TObject;
  S: string;
  D: Double;
  F: Single;
  Span: TByteSpan;
begin
  Result := False;
  if (Field.AccessMode <> amDirectField) or (Field.Offset < 0) then
    Exit;

  case Field.NativeKind of
    nkInt32:
      begin
        VarintVal := ReadVarint(Stream);
        TDextDirectAccess.WriteInt32(Obj, Field.Offset, Integer(VarintVal));
        Result := True;
      end;
    nkInt64:
      begin
        VarintVal := ReadVarint(Stream);
        TDextDirectAccess.WriteInt64(Obj, Field.Offset, Int64(VarintVal));
        Result := True;
      end;
    nkBoolean:
      begin
        VarintVal := ReadVarint(Stream);
        TDextDirectAccess.WriteBoolean(Obj, Field.Offset, VarintVal <> 0);
        Result := True;
      end;
    nkSingle:
      begin
        F := ReadSingle(Stream);
        TDextDirectAccess.WriteSingle(Obj, Field.Offset, F);
        Result := True;
      end;
    nkCurrency:
      begin
        D := ReadDouble(Stream);
        TDextDirectAccess.WriteCurrency(Obj, Field.Offset, Currency(D));
        Result := True;
      end;
    nkDouble, nkDateTime:
      begin
        D := ReadDouble(Stream);
        TDextDirectAccess.WriteDouble(Obj, Field.Offset, D);
        Result := True;
      end;
    nkString:
      begin
        Len := ReadVarint(Stream);
        S := ReadUtf8String(Stream, Len);
        TDextDirectAccess.WriteString(Obj, Field.Offset, S);
        Result := True;
      end;
    nkGuid:
      begin
        Len := ReadVarint(Stream);
        S := ReadUtf8String(Stream, Len);
        TDextDirectAccess.WriteGUID(Obj, Field.Offset, StringToGUID(S));
        Result := True;
      end;
    nkUuid:
      begin
        Len := ReadVarint(Stream);
        S := ReadUtf8String(Stream, Len);
        TDextDirectAccess.WriteUUID(Obj, Field.Offset, TUUID.FromString(S));
        Result := True;
      end;
    nkObject:
      begin
        Len := ReadVarint(Stream);
        NestedObj := TDextDirectAccess.ReadObject(Obj, Field.Offset);
        if NestedObj = nil then
        begin
          NestedObj := TActivator.CreateInstance(nil, Field.TypeInfo).AsObject;
          TDextDirectAccess.WriteObject(Obj, Field.Offset, NestedObj);
        end;
        if (NestedObj <> nil) and (Len > 0) then
        begin
          if TryReadSpan(Stream, Len, Span) then
            Deserialize(Span, NestedObj)
          else
          begin
            SetLength(Bytes, Len);
            Stream.Read(Bytes[0], Len);
            Deserialize(Bytes, NestedObj);
          end;
        end;
        Result := True;
      end;
    nkList:
      begin
        Len := ReadVarint(Stream);
        Span := TByteSpan.Create(nil, 0);
        if (Len > 0) and not TryReadSpan(Stream, Len, Span) then
        begin
          SetLength(Bytes, Len);
          Stream.Read(Bytes[0], Len);
        end;

        ObjList := nil;
        if Field.TypeInfo <> nil then
        begin
          if Field.TypeInfo.Kind = tkClass then
          begin
            ListObj := TDextDirectAccess.ReadObject(Obj, Field.Offset);
            if ListObj = nil then
            begin
              ListObj := TActivator.CreateInstance(nil, Field.TypeInfo).AsObject;
              if Supports(ListObj, ICollection, Collection) then
                Collection.OwnsObjects := Field.ListOwnsObjects;
              TDextDirectAccess.WriteObject(Obj, Field.Offset, ListObj);
            end;
            Supports(ListObj, IObjectList, ObjList);
          end
          else if Field.TypeInfo.Kind = tkInterface then
          begin
            ListIntf := TDextDirectAccess.ReadInterface(Obj, Field.Offset);
            if ListIntf = nil then
            begin
              ListIntf := TActivator.CreateInstance(nil, Field.TypeInfo).AsInterface;
              if Supports(ListIntf, ICollection, Collection) then
                Collection.OwnsObjects := Field.ListOwnsObjects;
              TDextDirectAccess.WriteInterface(Obj, Field.Offset, ListIntf);
            end;
            Supports(ListIntf, IObjectList, ObjList);
          end;
        end;

        if Assigned(ObjList) and (Field.ElementType <> nil) and
           (Field.ElementType.Kind = tkClass) then
        begin
          ItemObj := TActivator.CreateInstance(nil, Field.ElementType).AsObject;
          if Len > 0 then
          begin
            if Span.Length > 0 then
              Deserialize(Span, ItemObj)
            else
              Deserialize(Bytes, ItemObj);
          end;
          ObjList.Add(ItemObj);
        end;
        Result := True;
      end;
  end;
end;

class function TProtobufSerializer.TrySerializeDirect(Obj: TObject;
  out Bytes: TBytes): Boolean;
var
  Stream: TBytesStream;
  Plan: IDextTypeCodecPlan;
  Field: TDextFieldPlan;
  Len: NativeInt;
begin
  Result := False;
  Bytes := nil;
  if not Assigned(Obj) then
    Exit;

  Plan := TDextTypeModel.GetPlan(Obj.ClassInfo);
  if (Plan = nil) or not Plan.HasDirectAccess then
    Exit;

  Stream := TBytesStream.Create(nil);
  try
    for Field in Plan.GetFields do
      SerializeDirectField(Stream, Obj, Field);
    Bytes := Stream.Bytes;
    Len := Stream.Size;
  finally
    Stream.Free;
  end;
  SetLength(Bytes, Len);
  Result := True;
end;

class function TProtobufSerializer.TryDeserializeDirect(const Bytes: TBytes;
  Obj: TObject): Boolean;
begin
  if Length(Bytes) > 0 then
    Result := TryDeserializeDirect(TByteSpan.Create(@Bytes[0], Length(Bytes)), Obj)
  else
    Result := False;
end;

class function TProtobufSerializer.TryDeserializeDirect(const Bytes: TByteSpan;
  Obj: TObject): Boolean;
var
  Stream: TProtobufReadOnlySpanStream;
  Plan: IDextTypeCodecPlan;
  Field: TDextFieldPlan;
  Header: UInt64;
  Tag: Integer;
  WireType: Integer;
  Decoded: TValue;
begin
  Result := False;
  if (Bytes.Length = 0) or not Assigned(Obj) then
    Exit;

  Plan := TDextTypeModel.GetPlan(Obj.ClassInfo);
  if (Plan = nil) or not Plan.HasDirectAccess then
    Exit;

  Stream := TProtobufReadOnlySpanStream.Create(Bytes);
  try
    while Stream.Position < Stream.Size do
    begin
      Header := ReadVarint(Stream);
      Tag := Header shr 3;
      WireType := Header and 7;

      if Plan.TryGetFieldByProtoTag(Tag, Field) then
      begin
        if not DeserializeDirectField(Stream, Obj, Field, WireType) then
        begin
          Decoded := DeserializeField(Stream, WireType, Field.TypeInfo);
          if not Decoded.IsEmpty then
            Field.Handler.SetValue(Obj, Decoded);
        end;
      end
      else
        SkipField(Stream, WireType);
    end;
  finally
    Stream.Free;
  end;
  Result := True;
end;
class function TProtobufSerializer.Serialize(Obj: TObject;
  Mode: TProtobufCodecMode): TBytes;
var
  Stream: TBytesStream;
  TagMap: IDictionary<Integer, IPropertyHandler>;
  Key: Integer;
  Handler: IPropertyHandler;
  Val: TValue;
  Len: NativeInt;
begin
  if not Assigned(Obj) then
    Exit(nil);

  if Mode in [pcmAuto, pcmGenerated] then
    if TrySerializeGenerated(Obj, Result) then
      Exit;

  if Mode in [pcmAuto, pcmDirect] then
    if TrySerializeDirect(Obj, Result) then
      Exit;

  Stream := TBytesStream.Create(nil);
  try
    TagMap := GetTagMap(Obj.ClassType);
    for Key in TagMap.Keys do
    begin
      Handler := TagMap[Key];
      Val := Handler.GetValue(Obj);
      SerializeField(Stream, Key, Val);
    end;

    Result := Stream.Bytes;
    Len := Stream.Size;
  finally
    Stream.Free;
  end;
  SetLength(Result, Len);
end;
class procedure TProtobufSerializer.Deserialize(const Bytes: TByteSpan;
  Obj: TObject; Mode: TProtobufCodecMode);
var
  Stream: TProtobufReadOnlySpanStream;
  TagMap: IDictionary<Integer, IPropertyHandler>;
  Tag: Integer;
  WireType: Integer;
  Header: UInt64;
  Decoded: TValue;
  ListObj: TObject;
  ObjList: IObjectList;
  ListIntf: IInterface;
  Handler: IPropertyHandler;
  Prop: TRttiProperty;
  PropMeta: TTypeMetadata;
begin
  if (Bytes.Length = 0) or not Assigned(Obj) then
    Exit;

  if Mode in [pcmAuto, pcmGenerated] then
    if TryDeserializeGenerated(Bytes, Obj) then
      Exit;

  if Mode in [pcmAuto, pcmDirect] then
    if TryDeserializeDirect(Bytes, Obj) then
      Exit;

  Stream := TProtobufReadOnlySpanStream.Create(Bytes);
  try
    TagMap := GetTagMap(Obj.ClassType);

    while Stream.Position < Stream.Size do
    begin
      Header := ReadVarint(Stream);
      Tag := Header shr 3;
      WireType := Header and 7;

      if TagMap.TryGetValue(Tag, Handler) then
      begin
        Prop := TRttiProperty(Handler.Member);
        if (Prop.PropertyType.TypeKind = tkClass) or
           (Prop.PropertyType.TypeKind = tkInterface) then
        begin
          ObjList := nil;
          if Prop.PropertyType.TypeKind = tkInterface then
          begin
            ListIntf := Handler.GetValue(Obj).AsInterface;
            if Assigned(ListIntf) then
              Supports(ListIntf, IObjectList, ObjList);
          end
          else
          begin
            ListObj := Handler.GetValue(Obj).AsObject;
            if not Assigned(ListObj) then
            begin
              ListObj := TRttiInstanceType(Prop.PropertyType)
                .MetaclassType.Create;
              Handler.SetValue(Obj, ListObj);
            end;
            Supports(ListObj, IObjectList, ObjList);
          end;

          if Assigned(ObjList) then
          begin
            PropMeta := TReflection.GetMetadata(Prop.PropertyType.Handle);
            if PropMeta.IsList and Assigned(PropMeta.ElementType) then
            begin
              Decoded := DeserializeField(Stream, WireType,
                PropMeta.ElementType);
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
          end
          else if Prop.PropertyType.TypeKind = tkClass then
          begin
            Decoded := DeserializeField(Stream, WireType,
              Prop.PropertyType.Handle);
            if not Decoded.IsEmpty then
              Handler.SetValue(Obj, Decoded);
          end;
        end
        else
        begin
          Decoded := DeserializeField(Stream, WireType,
            Prop.PropertyType.Handle);
          if not Decoded.IsEmpty then
            Handler.SetValue(Obj, Decoded);
        end;
      end
      else
      begin
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

class procedure TProtobufSerializer.Deserialize(const Bytes: TBytes;
  Obj: TObject; Mode: TProtobufCodecMode);
var
  Stream: TBytesStream;
  TagMap: IDictionary<Integer, IPropertyHandler>;
  Tag: Integer;
  WireType: Integer;
  Header: UInt64;
  Decoded: TValue;
  ListObj: TObject;
  ObjList: IObjectList;
  ListIntf: IInterface;
  Handler: IPropertyHandler;
  Prop: TRttiProperty;
  PropMeta: TTypeMetadata;
begin
  if (Length(Bytes) = 0) or not Assigned(Obj) then
    Exit;

  if Mode in [pcmAuto, pcmGenerated] then
    if TryDeserializeGenerated(Bytes, Obj) then
      Exit;

  if Mode in [pcmAuto, pcmDirect] then
    if TryDeserializeDirect(Bytes, Obj) then
      Exit;

  Stream := TBytesStream.Create(Bytes);
  try
    TagMap := GetTagMap(Obj.ClassType);

    while Stream.Position < Stream.Size do
    begin
      Header := ReadVarint(Stream);
      Tag := Header shr 3;
      WireType := Header and 7;

      if TagMap.TryGetValue(Tag, Handler) then
      begin
        Prop := TRttiProperty(Handler.Member);
        if (Prop.PropertyType.TypeKind = tkClass) or
           (Prop.PropertyType.TypeKind = tkInterface) then
        begin
          ObjList := nil;
          if Prop.PropertyType.TypeKind = tkInterface then
          begin
            ListIntf := Handler.GetValue(Obj).AsInterface;
            if Assigned(ListIntf) then
              Supports(ListIntf, IObjectList, ObjList);
          end
          else
          begin
            ListObj := Handler.GetValue(Obj).AsObject;
            if not Assigned(ListObj) then
            begin
              ListObj := TRttiInstanceType(Prop.PropertyType)
                .MetaclassType.Create;
              Handler.SetValue(Obj, ListObj);
            end;
            Supports(ListObj, IObjectList, ObjList);
          end;

          if Assigned(ObjList) then
          begin
            PropMeta := TReflection.GetMetadata(Prop.PropertyType.Handle);
            if PropMeta.IsList and Assigned(PropMeta.ElementType) then
            begin
              Decoded := DeserializeField(Stream, WireType,
                PropMeta.ElementType);
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
          end
          else if Prop.PropertyType.TypeKind = tkClass then
          begin
            Decoded := DeserializeField(Stream, WireType,
              Prop.PropertyType.Handle);
            if not Decoded.IsEmpty then
              Handler.SetValue(Obj, Decoded);
          end;
        end
        else
        begin
          Decoded := DeserializeField(Stream, WireType,
            Prop.PropertyType.Handle);
          if not Decoded.IsEmpty then
            Handler.SetValue(Obj, Decoded);
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

