unit BM.S54;

interface

uses
  Spring.Benchmark;

procedure BM_S54_Protobuf_Rtti_Roundtrip(const state: TState);
procedure BM_S54_Protobuf_Direct_Roundtrip(const state: TState);
procedure BM_S54_Protobuf_Generated_Roundtrip(const state: TState);
procedure BM_S54_Grpc_FrameInPlace(const state: TState);
procedure BM_S54_Grpc_Encode(const state: TState);
procedure BM_S54_Grpc_DecodeBytes(const state: TState);
procedure BM_S54_Grpc_DecodeSpan(const state: TState);
procedure BM_S54_Grpc_SerializeEncode(const state: TState);
procedure BM_S54_Protobuf_Stream(const state: TState);
procedure BM_S54_Protobuf_Rtti_Serialize(const state: TState);
procedure BM_S54_Protobuf_DeserializeBytes(const state: TState);
procedure BM_S54_Protobuf_DeserializeSpan(const state: TState);
procedure BM_S54_Json_Roundtrip(const state: TState);
procedure BM_S54_Orm_JsonConverter_Roundtrip(const state: TState);
procedure BM_S54_Tracing_BeginSpan_Inactive(const state: TState);
procedure BM_S54_Grpc_SubStopwatch_Always(const state: TState);
procedure BM_S54_Grpc_SubStopwatch_Guarded(const state: TState);
procedure BM_S54_Grpc_PathSplit(const state: TState);
procedure BM_S54_Grpc_PathManual(const state: TState);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Rtti,
  Dext.Codecs.Registry,
  Dext.Collections,
  Dext.Core.Activator,
  Dext.Core.Span,
  Dext.Entity.Dialects,
  Dext.Entity.TypeConverters,
  Dext.Grpc.Attributes,
  Dext.Grpc.Codec,
  Dext.Json,
  Dext.Logging.Telemetry,
  Dext.Logging.Tracing,
  Dext.Serialization.Protobuf;

type
  [GrpcMessage]
  TCodecChild = class
  private
    FIndex: Integer;
    FName: string;
  public
    [ProtoMember(1)]
    property Index: Integer read FIndex write FIndex;
    [ProtoMember(2)]
    property Name: string read FName write FName;
  end;

  [GrpcMessage]
  TCodecRoot = class
  private
    FChild: TCodecChild;
    FFlag: Boolean;
    FId: Integer;
    FItems: IList<TCodecChild>;
    FName: string;
  public
    constructor Create;
    destructor Destroy; override;

    [ProtoMember(1)]
    property Id: Integer read FId write FId;
    [ProtoMember(2)]
    property Name: string read FName write FName;
    [ProtoMember(3)]
    property Flag: Boolean read FFlag write FFlag;
    [ProtoMember(4)]
    property Child: TCodecChild read FChild write FChild;
    [ProtoMember(5)]
    property Items: IList<TCodecChild> read FItems write FItems;
  end;

var
  GJsonConverter: TJsonConverter;

constructor TCodecRoot.Create;
var
  i: Integer;
  Child: TCodecChild;
begin
  inherited Create;
  FChild := TCodecChild.Create;
  FItems := TCollections.CreateList<TCodecChild>(True);
  FId := 42;
  FName := 'S54 Codec Root';
  FFlag := True;
  FChild.Index := 7;
  FChild.Name := 'Nested Child';

  for i := 0 to 3 do
  begin
    Child := TCodecChild.Create;
    Child.Index := i;
    Child.Name := 'Item ' + IntToStr(i);
    FItems.Add(Child);
  end;
end;

destructor TCodecRoot.Destroy;
begin
  FChild.Free;
  FItems := nil;
  inherited;
end;

procedure WriteCodecChild(AWriter: TObject; AObj: TObject);
begin
  TProtobufWriter(AWriter).WriteInt32(1, TCodecChild(AObj).Index);
  TProtobufWriter(AWriter).WriteString(2, TCodecChild(AObj).Name);
end;

procedure ReadCodecChild(AReader: TObject; AObj: TObject);
var
  Reader: TProtobufReader;
begin
  Reader := TProtobufReader(AReader);
  while Reader.ReadField do
    case Reader.Tag of
      1: TCodecChild(AObj).Index := Reader.ReadInt32;
      2: TCodecChild(AObj).Name := Reader.ReadString;
    else
      Reader.SkipField;
    end;
end;

procedure WriteCodecRoot(AWriter: TObject; AObj: TObject);
var
  Writer: TProtobufWriter;
  Obj: TCodecRoot;
  i: Integer;
  Bytes: TBytes;
begin
  Writer := TProtobufWriter(AWriter);
  Obj := TCodecRoot(AObj);
  Writer.WriteInt32(1, Obj.Id);
  Writer.WriteString(2, Obj.Name);
  Writer.WriteBool(3, Obj.Flag);

  if Assigned(Obj.Child) then
  begin
    Bytes := TProtobufSerializer.Serialize(Obj.Child, pcmGenerated);
    Writer.WriteMessage(4, Bytes);
  end;

  if Obj.Items <> nil then
    for i := 0 to Obj.Items.Count - 1 do
      if Assigned(Obj.Items[i]) then
      begin
        Bytes := TProtobufSerializer.Serialize(Obj.Items[i], pcmGenerated);
        Writer.WriteMessage(5, Bytes);
      end;
end;

procedure ReadCodecRoot(AReader: TObject; AObj: TObject);
var
  Reader: TProtobufReader;
  Obj: TCodecRoot;
  Child: TCodecChild;
begin
  Reader := TProtobufReader(AReader);
  Obj := TCodecRoot(AObj);
  while Reader.ReadField do
    case Reader.Tag of
      1: Obj.Id := Reader.ReadInt32;
      2: Obj.Name := Reader.ReadString;
      3: Obj.Flag := Reader.ReadBool;
      4:
        begin
          Child := TCodecChild.Create;
          TProtobufSerializer.Deserialize(Reader.ReadBytes, Child, pcmGenerated);
          Obj.Child.Free;
          Obj.Child := Child;
        end;
      5:
        begin
          if Obj.Items = nil then
            Obj.Items := TCollections.CreateList<TCodecChild>(True);
          Child := TCodecChild.Create;
          TProtobufSerializer.Deserialize(Reader.ReadBytes, Child, pcmGenerated);
          Obj.Items.Add(Child);
        end;
    else
      Reader.SkipField;
    end;
end;

procedure InitializeFixtures;
begin
  TActivator.RegisterDefault<IList<TCodecChild>, Dext.Collections.TList<TCodecChild>>;
  TDextCodecRegistry.RegisterProtobuf<TCodecChild>(WriteCodecChild, ReadCodecChild);
  TDextCodecRegistry.RegisterProtobuf<TCodecRoot>(WriteCodecRoot, ReadCodecRoot);
  GJsonConverter := TJsonConverter.Create(True);
end;

procedure FinalizeFixtures;
begin
  GJsonConverter.Free;
end;

procedure BM_S54_Grpc_FrameInPlace(const state: TState);
var
  Buffer: TBytes;
  I: Integer;
begin
  SetLength(Buffer, 1024);
  for I := 0 to High(Buffer) do
    Buffer[I] := Byte(I);
  while state.KeepRunning do
  begin
    SetLength(Buffer, 1024);
    TGrpcMessageCodec.FrameInPlace(Buffer);
    SetLength(Buffer, 1024);
  end;
end;
procedure BM_S54_Grpc_Encode(const state: TState);
var
  Payload: TBytes;
  Framed: TBytes;
  I: Integer;
begin
  SetLength(Payload, 1024);
  for I := 0 to High(Payload) do
    Payload[I] := Byte(I);
  while state.KeepRunning do
    Framed := TGrpcMessageCodec.Encode(Payload, False);
end;


procedure BM_S54_Grpc_DecodeBytes(const state: TState);
var
  Payload: TBytes;
  Framed: TBytes;
  MsgSpan: TByteSpan;
  Offset: Integer;
  Compressed: Boolean;
  i: Integer;
begin
  SetLength(Payload, 1024);
  for i := 0 to High(Payload) do
    Payload[i] := Byte(i);
  Framed := TGrpcMessageCodec.Encode(Payload, False);

  while state.KeepRunning do
  begin
    Offset := 0;
    TGrpcMessageCodec.TryDecode(Framed, Offset, Compressed, MsgSpan);
  end;
end;

procedure BM_S54_Grpc_DecodeSpan(const state: TState);
var
  Payload: TBytes;
  Framed: TBytes;
  FramedSpan: TByteSpan;
  MsgSpan: TByteSpan;
  Offset: Integer;
  Compressed: Boolean;
  i: Integer;
begin
  SetLength(Payload, 1024);
  for i := 0 to High(Payload) do
    Payload[i] := Byte(i);
  Framed := TGrpcMessageCodec.Encode(Payload, False);
  FramedSpan := TByteSpan.Create(@Framed[0], Length(Framed));

  while state.KeepRunning do
  begin
    Offset := 0;
    TGrpcMessageCodec.TryDecode(FramedSpan, Offset, Compressed, MsgSpan);
  end;
end;

procedure BM_S54_Grpc_SerializeEncode(const state: TState);
var
  Source: TCodecRoot;
  Serialized: TBytes;
  Framed: TBytes;
begin
  Source := TCodecRoot.Create;
  try
    while state.KeepRunning do
    begin
      Serialized := TProtobufSerializer.Serialize(Source, pcmAuto);
      Framed := TGrpcMessageCodec.Encode(Serialized, False);
    end;
  finally
    Source.Free;
  end;
end;


procedure BM_S54_Protobuf_Stream(const state: TState);
var
  Source: TCodecRoot;
  Stream: TBytesStream;
begin
  Source := TCodecRoot.Create;
  Stream := TBytesStream.Create(nil);
  try
    while state.KeepRunning do
    begin
      Stream.Size := 0;
      TProtobufSerializer.SerializeToStream(Source, Stream, pcmRtti);
    end;
  finally
    Stream.Free;
    Source.Free;
  end;
end;
procedure BM_S54_Protobuf_Rtti_Serialize(const state: TState);
var
  Source: TCodecRoot;
  Bytes: TBytes;
begin
  Source := TCodecRoot.Create;
  try
    while state.KeepRunning do
      Bytes := TProtobufSerializer.Serialize(Source, pcmRtti);
  finally
    Source.Free;
  end;
end;


procedure BM_S54_Protobuf_DeserializeBytes(const state: TState);
var
  Source: TCodecRoot;
  Target: TCodecRoot;
  Bytes: TBytes;
begin
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmAuto);
    while state.KeepRunning do
    begin
      Target.Child.Free;
      Target.Child := nil;
      Target.Items.Clear;
      TProtobufSerializer.Deserialize(Bytes, Target, pcmAuto);
    end;
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure BM_S54_Protobuf_DeserializeSpan(const state: TState);
var
  Source: TCodecRoot;
  Target: TCodecRoot;
  Bytes: TBytes;
  Span: TByteSpan;
begin
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmAuto);
    Span := TByteSpan.Create(@Bytes[0], Length(Bytes));
    while state.KeepRunning do
    begin
      Target.Child.Free;
      Target.Child := nil;
      Target.Items.Clear;
      TProtobufSerializer.Deserialize(Span, Target, pcmAuto);
    end;
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure BM_S54_Protobuf_Rtti_Roundtrip(const state: TState);
var
  Source: TCodecRoot;
  Target: TCodecRoot;
  Bytes: TBytes;
begin
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmRtti);
    Target.Child.Free;
    Target.Child := nil;
    Target.Items.Clear;
    TProtobufSerializer.Deserialize(Bytes, Target, pcmRtti);

    while state.KeepRunning do
    begin
      Bytes := TProtobufSerializer.Serialize(Source, pcmRtti);
      Target.Child.Free;
      Target.Child := nil;
      Target.Items.Clear;
      TProtobufSerializer.Deserialize(Bytes, Target, pcmRtti);
    end;
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure BM_S54_Protobuf_Direct_Roundtrip(const state: TState);
var
  Source: TCodecRoot;
  Target: TCodecRoot;
  Bytes: TBytes;
begin
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmDirect);
    Target.Child.Free;
    Target.Child := nil;
    Target.Items.Clear;
    TProtobufSerializer.Deserialize(Bytes, Target, pcmDirect);

    while state.KeepRunning do
    begin
      Bytes := TProtobufSerializer.Serialize(Source, pcmDirect);
      Target.Child.Free;
      Target.Child := nil;
      Target.Items.Clear;
      TProtobufSerializer.Deserialize(Bytes, Target, pcmDirect);
    end;
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure BM_S54_Protobuf_Generated_Roundtrip(const state: TState);
var
  Source: TCodecRoot;
  Target: TCodecRoot;
  Bytes: TBytes;
begin
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmGenerated);
    Target.Child.Free;
    Target.Child := nil;
    Target.Items.Clear;
    TProtobufSerializer.Deserialize(Bytes, Target, pcmGenerated);

    while state.KeepRunning do
    begin
      Bytes := TProtobufSerializer.Serialize(Source, pcmGenerated);
      Target.Child.Free;
      Target.Child := nil;
      Target.Items.Clear;
      TProtobufSerializer.Deserialize(Bytes, Target, pcmGenerated);
    end;
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure BM_S54_Json_Roundtrip(const state: TState);
var
  Source: TCodecRoot;
  Target: TCodecRoot;
  JsonText: string;
begin
  Source := TCodecRoot.Create;
  Target := nil;
  try
    JsonText := TDextJson.Serialize<TCodecRoot>(Source);
    Target := TDextJson.Deserialize<TCodecRoot>(JsonText);
    Target.Free;
    Target := nil;

    while state.KeepRunning do
    begin
      JsonText := TDextJson.Serialize<TCodecRoot>(Source);
      Target := TDextJson.Deserialize<TCodecRoot>(JsonText);
      Target.Free;
      Target := nil;
    end;
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure BM_S54_Orm_JsonConverter_Roundtrip(const state: TState);
var
  Source: TCodecRoot;
  Converted: TValue;
  Deserialized: TValue;
  Target: TCodecRoot;
begin
  Source := TCodecRoot.Create;
  Target := nil;
  try
    Converted := GJsonConverter.ToDatabase(TValue.From<TObject>(Source), ddPostgreSQL);
    Deserialized := GJsonConverter.FromDatabase(Converted, TypeInfo(TCodecRoot));
    Target := Deserialized.AsObject as TCodecRoot;
    Target.Free;
    Target := nil;

    while state.KeepRunning do
    begin
      Converted := GJsonConverter.ToDatabase(TValue.From<TObject>(Source), ddPostgreSQL);
      Deserialized := GJsonConverter.FromDatabase(Converted, TypeInfo(TCodecRoot));
      Target := Deserialized.AsObject as TCodecRoot;
      Target.Free;
      Target := nil;
    end;
  finally
    Target.Free;
    Source.Free;
  end;
end;


procedure BM_S54_Tracing_BeginSpan_Inactive(const state: TState);
var
  Span: TSpan;
begin
  TDiagnosticSource.Instance.Enabled := False;
  try
    while state.KeepRunning do
    begin
      Span := TTracer.BeginSpan('gRPC Server dext.test.v1.DummyService/DummyCall', 'gRPC');
      Span.SetStatus('Success');
    end;
  finally
    TDiagnosticSource.Instance.Enabled := True;
  end;
end;


procedure BM_S54_Grpc_PathSplit(const state: TState);
var
  Path: string;
  Parts: TArray<string>;
  ServiceName: string;
  MethodName: string;
begin
  Path := '/dext.test.v1.DummyService/DummyCall';
  while state.KeepRunning do
  begin
    Parts := Path.Split(['/']);
    ServiceName := Parts[1].ToLower;
    MethodName := Parts[2].ToLower;
  end;
end;

procedure BM_S54_Grpc_PathManual(const state: TState);
var
  Path: string;
  ServicePath: string;
  MethodPath: string;
  ServiceName: string;
  MethodName: string;
  SlashPos: Integer;
  i: Integer;
begin
  Path := '/dext.test.v1.DummyService/DummyCall';
  while state.KeepRunning do
  begin
    SlashPos := 0;
    if (Path <> '') and (Path[1] = '/') then
      for i := 2 to Length(Path) do
        if Path[i] = '/' then
        begin
          SlashPos := i;
          Break;
        end;
    ServicePath := Copy(Path, 2, SlashPos - 2);
    MethodPath := Copy(Path, SlashPos + 1, MaxInt);
    ServiceName := ServicePath;
    MethodName := MethodPath;
  end;
end;


procedure BM_S54_Grpc_SubStopwatch_Always(const state: TState);
var
  SwSub: TStopwatch;
  i: Integer;
begin
  while state.KeepRunning do
    for i := 1 to 5 do
    begin
      SwSub := TStopwatch.StartNew;
      SwSub.Stop;
    end;
end;

procedure BM_S54_Grpc_SubStopwatch_Guarded(const state: TState);
var
  SwSub: TStopwatch;
  TelemetryActive: Boolean;
  i: Integer;
begin
  TelemetryActive := False;
  while state.KeepRunning do
    for i := 1 to 5 do
      if TelemetryActive then
      begin
        SwSub := TStopwatch.StartNew;
        SwSub.Stop;
      end;
end;

initialization
  InitializeFixtures;
  Benchmark(BM_S54_Protobuf_Rtti_Roundtrip, 'BM_S54_Protobuf_Rtti_Roundtrip').Threads(1);
  Benchmark(BM_S54_Protobuf_Direct_Roundtrip, 'BM_S54_Protobuf_Direct_Roundtrip').Threads(1);
  Benchmark(BM_S54_Protobuf_Generated_Roundtrip, 'BM_S54_Protobuf_Generated_Roundtrip').Threads(1);
  Benchmark(BM_S54_Grpc_FrameInPlace, 'BM_S54_Grpc_FrameInPlace').Threads(1);
  Benchmark(BM_S54_Grpc_Encode, 'BM_S54_Grpc_Encode').Threads(1);
  Benchmark(BM_S54_Grpc_DecodeBytes, 'BM_S54_Grpc_DecodeBytes').Threads(1);
  Benchmark(BM_S54_Grpc_DecodeSpan, 'BM_S54_Grpc_DecodeSpan').Threads(1);
  Benchmark(BM_S54_Grpc_SerializeEncode, 'BM_S54_Grpc_SerializeEncode').Threads(1);
  Benchmark(BM_S54_Protobuf_Stream, 'BM_S54_Protobuf_Stream').Threads(1);
  Benchmark(BM_S54_Protobuf_Rtti_Serialize, 'BM_S54_Protobuf_Rtti_Serialize').Threads(1);
  Benchmark(BM_S54_Protobuf_DeserializeBytes, 'BM_S54_Protobuf_DeserializeBytes').Threads(1);
  Benchmark(BM_S54_Protobuf_DeserializeSpan, 'BM_S54_Protobuf_DeserializeSpan').Threads(1);
  Benchmark(BM_S54_Json_Roundtrip, 'BM_S54_Json_Roundtrip').Threads(1);
  Benchmark(BM_S54_Orm_JsonConverter_Roundtrip, 'BM_S54_Orm_JsonConverter_Roundtrip').Threads(1);
  Benchmark(BM_S54_Tracing_BeginSpan_Inactive, 'BM_S54_Tracing_BeginSpan_Inactive').Threads(1);
  Benchmark(BM_S54_Grpc_SubStopwatch_Always, 'BM_S54_Grpc_SubStopwatch_Always').Threads(1);
  Benchmark(BM_S54_Grpc_SubStopwatch_Guarded, 'BM_S54_Grpc_SubStopwatch_Guarded').Threads(1);
  Benchmark(BM_S54_Grpc_PathSplit, 'BM_S54_Grpc_PathSplit').Threads(1);
  Benchmark(BM_S54_Grpc_PathManual, 'BM_S54_Grpc_PathManual').Threads(1);

finalization
  FinalizeFixtures;

end.

