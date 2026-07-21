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
procedure BM_S54_Json_SerializeUtf8(const state: TState);
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
  Dext.Performance.Allocator,
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

type
  PState = ^TState;

procedure TrackedBenchmark(state: PState; const Action: TProc);
var
  Stats: TDextAllocStats;
  Counter: TCounter;
begin
  TDextAllocationTracker.Reset;
  TDextAllocationTracker.Start;
  try
    Action();
  finally
    TDextAllocationTracker.Stop;
    Stats := TDextAllocationTracker.GetStats;
    Counter.Init(Stats.AllocationCount, [kAvgIterations]);
    state^.Counters['allocations'] := Counter;
    Counter.Init(Stats.GetMemCount, [kAvgIterations]);
    state^.Counters['getmem'] := Counter;
    Counter.Init(Stats.AllocMemCount, [kAvgIterations]);
    state^.Counters['allocmem'] := Counter;
    Counter.Init(Stats.ReallocMemCount, [kAvgIterations]);
    state^.Counters['reallocmem'] := Counter;
    Counter.Init(Stats.FreeCount, [kAvgIterations]);
    state^.Counters['frees'] := Counter;
    Counter.Init(Stats.AllocatedBytes, [kAvgIterations]);
    state^.Counters['allocated_bytes'] := Counter;
    Counter.Init(Stats.ReallocatedBytes, [kAvgIterations]);
    state^.Counters['reallocated_bytes'] := Counter;
    Counter.Init(Stats.RetainedBytes, [kAvgIterations]);
    state^.Counters['retained_bytes'] := Counter;
    if state^.Iterations > 0 then
      state^.SetLabel(Format('allocs/op:%.2f bytes/op:%.1f',
        [Stats.AllocationCount / state^.Iterations,
         Stats.AllocatedBytes / state^.Iterations]))
    else
      state^.SetLabel(Format('allocs:%d bytes:%d',
        [Stats.AllocationCount, Stats.AllocatedBytes]));
  end;
end;

procedure BM_S54_Grpc_FrameInPlace(const state: TState);
var
  Buffer: TBytes;
  I: Integer;
  P: PState;
begin
  P := @state;
  SetLength(Buffer, 1024);
  for I := 0 to High(Buffer) do
    Buffer[I] := Byte(I);
  TrackedBenchmark(P, procedure
  var
    LBuffer: TBytes;
  begin
    LBuffer := Buffer;
    while P^.KeepRunning do
    begin
      SetLength(LBuffer, 1024);
      TGrpcMessageCodec.FrameInPlace(LBuffer);
      SetLength(LBuffer, 1024);
    end;
  end);
end;

procedure BM_S54_Grpc_Encode(const state: TState);
var
  Payload: TBytes;
  I: Integer;
  P: PState;
begin
  P := @state;
  SetLength(Payload, 1024);
  for I := 0 to High(Payload) do
    Payload[I] := Byte(I);
  TrackedBenchmark(P, procedure
  var
    LFramed: TBytes;
  begin
    while P^.KeepRunning do
      LFramed := TGrpcMessageCodec.Encode(Payload, False);
  end);
end;

procedure BM_S54_Grpc_DecodeBytes(const state: TState);
var
  Payload: TBytes;
  Framed: TBytes;
  i: Integer;
  P: PState;
begin
  P := @state;
  SetLength(Payload, 1024);
  for i := 0 to High(Payload) do
    Payload[i] := Byte(i);
  Framed := TGrpcMessageCodec.Encode(Payload, False);

  TrackedBenchmark(P, procedure
  var
    LOffset: Integer;
    LCompressed: Boolean;
    LMsgSpan: TByteSpan;
  begin
    while P^.KeepRunning do
    begin
      LOffset := 0;
      TGrpcMessageCodec.TryDecode(Framed, LOffset, LCompressed, LMsgSpan);
    end;
  end);
end;

procedure BM_S54_Grpc_DecodeSpan(const state: TState);
var
  Payload: TBytes;
  Framed: TBytes;
  FramedSpan: TByteSpan;
  i: Integer;
  P: PState;
begin
  P := @state;
  SetLength(Payload, 1024);
  for i := 0 to High(Payload) do
    Payload[i] := Byte(i);
  Framed := TGrpcMessageCodec.Encode(Payload, False);
  FramedSpan := TByteSpan.Create(@Framed[0], Length(Framed));

  TrackedBenchmark(P, procedure
  var
    LOffset: Integer;
    LCompressed: Boolean;
    LMsgSpan: TByteSpan;
  begin
    while P^.KeepRunning do
    begin
      LOffset := 0;
      TGrpcMessageCodec.TryDecode(FramedSpan, LOffset, LCompressed, LMsgSpan);
    end;
  end);
end;

procedure BM_S54_Grpc_SerializeEncode(const state: TState);
var
  Source: TCodecRoot;
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  try
    TrackedBenchmark(P, procedure
    var
      LSerialized: TBytes;
      LFramed: TBytes;
    begin
      while P^.KeepRunning do
      begin
        LSerialized := TProtobufSerializer.Serialize(Source, pcmAuto);
        LFramed := TGrpcMessageCodec.Encode(LSerialized, False);
      end;
    end);
  finally
    Source.Free;
  end;
end;

procedure BM_S54_Protobuf_Stream(const state: TState);
var
  Source: TCodecRoot;
  Stream: TBytesStream;
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  Stream := TBytesStream.Create(nil);
  try
    TrackedBenchmark(P, procedure
    var
      LStream: TBytesStream;
    begin
      LStream := Stream;
      while P^.KeepRunning do
      begin
        LStream.Size := 0;
        TProtobufSerializer.SerializeToStream(Source, LStream, pcmRtti);
      end;
    end);
  finally
    Stream.Free;
    Source.Free;
  end;
end;

procedure BM_S54_Protobuf_Rtti_Serialize(const state: TState);
var
  Source: TCodecRoot;
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  try
    TrackedBenchmark(P, procedure
    var
      LBytes: TBytes;
    begin
      while P^.KeepRunning do
        LBytes := TProtobufSerializer.Serialize(Source, pcmRtti);
    end);
  finally
    Source.Free;
  end;
end;

procedure BM_S54_Protobuf_DeserializeBytes(const state: TState);
var
  Source: TCodecRoot;
  Target: TCodecRoot;
  Bytes: TBytes;
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmAuto);
    TrackedBenchmark(P, procedure
    var
      LTarget: TCodecRoot;
    begin
      LTarget := Target;
      while P^.KeepRunning do
      begin
        LTarget.Child.Free;
        LTarget.Child := nil;
        LTarget.Items.Clear;
        TProtobufSerializer.Deserialize(Bytes, LTarget, pcmAuto);
      end;
    end);
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
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmAuto);
    Span := TByteSpan.Create(@Bytes[0], Length(Bytes));
    TrackedBenchmark(P, procedure
    var
      LTarget: TCodecRoot;
    begin
      LTarget := Target;
      while P^.KeepRunning do
      begin
        LTarget.Child.Free;
        LTarget.Child := nil;
        LTarget.Items.Clear;
        TProtobufSerializer.Deserialize(Span, LTarget, pcmAuto);
      end;
    end);
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
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmRtti);
    Target.Child.Free;
    Target.Child := nil;
    Target.Items.Clear;
    TProtobufSerializer.Deserialize(Bytes, Target, pcmRtti);

    TrackedBenchmark(P, procedure
    var
      LTarget: TCodecRoot;
      LBytes: TBytes;
    begin
      LTarget := Target;
      while P^.KeepRunning do
      begin
        LBytes := TProtobufSerializer.Serialize(Source, pcmRtti);
        LTarget.Child.Free;
        LTarget.Child := nil;
        LTarget.Items.Clear;
        TProtobufSerializer.Deserialize(LBytes, LTarget, pcmRtti);
      end;
    end);
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
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmDirect);
    Target.Child.Free;
    Target.Child := nil;
    Target.Items.Clear;
    TProtobufSerializer.Deserialize(Bytes, Target, pcmDirect);

    TrackedBenchmark(P, procedure
    var
      LTarget: TCodecRoot;
      LBytes: TBytes;
    begin
      LTarget := Target;
      while P^.KeepRunning do
      begin
        LBytes := TProtobufSerializer.Serialize(Source, pcmDirect);
        LTarget.Child.Free;
        LTarget.Child := nil;
        LTarget.Items.Clear;
        TProtobufSerializer.Deserialize(LBytes, LTarget, pcmDirect);
      end;
    end);
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
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  Target := TCodecRoot.Create;
  try
    Bytes := TProtobufSerializer.Serialize(Source, pcmGenerated);
    Target.Child.Free;
    Target.Child := nil;
    Target.Items.Clear;
    TProtobufSerializer.Deserialize(Bytes, Target, pcmGenerated);

    TrackedBenchmark(P, procedure
    var
      LTarget: TCodecRoot;
      LBytes: TBytes;
    begin
      LTarget := Target;
      while P^.KeepRunning do
      begin
        LBytes := TProtobufSerializer.Serialize(Source, pcmGenerated);
        LTarget.Child.Free;
        LTarget.Child := nil;
        LTarget.Items.Clear;
        TProtobufSerializer.Deserialize(LBytes, LTarget, pcmGenerated);
      end;
    end);
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
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  Target := nil;
  try
    JsonText := TDextJson.Serialize<TCodecRoot>(Source);
    Target := TDextJson.Deserialize<TCodecRoot>(JsonText);
    Target.Free;
    Target := nil;

    TrackedBenchmark(P, procedure
    var
      LTarget: TCodecRoot;
      LJsonText: string;
    begin
      while P^.KeepRunning do
      begin
        LJsonText := TDextJson.Serialize<TCodecRoot>(Source);
        LTarget := TDextJson.Deserialize<TCodecRoot>(LJsonText);
        LTarget.Free;
      end;
    end);
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure BM_S54_Json_SerializeUtf8(const state: TState);
var
  Source: TCodecRoot;
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  try
    TrackedBenchmark(P, procedure
    var
      LBytes: TBytes;
    begin
      while P^.KeepRunning do
      begin
        LBytes := TDextJson.SerializeUtf8<TCodecRoot>(Source);
      end;
    end);
  finally
    Source.Free;
  end;
end;

procedure BM_S54_Orm_JsonConverter_Roundtrip(const state: TState);
var
  Source: TCodecRoot;
  Converted: TValue;
  Deserialized: TValue;
  Target: TCodecRoot;
  P: PState;
begin
  P := @state;
  Source := TCodecRoot.Create;
  Target := nil;
  try
    Converted := GJsonConverter.ToDatabase(
      TValue.From<TObject>(Source), ddPostgreSQL);
    Deserialized := GJsonConverter.FromDatabase(
      Converted, TypeInfo(TCodecRoot));
    Target := Deserialized.AsObject as TCodecRoot;
    Target.Free;
    Target := nil;

    TrackedBenchmark(P, procedure
    var
      LConverted: TValue;
      LDeserialized: TValue;
      LTarget: TCodecRoot;
    begin
      while P^.KeepRunning do
      begin
        LConverted := GJsonConverter.ToDatabase(
          TValue.From<TObject>(Source), ddPostgreSQL);
        LDeserialized := GJsonConverter.FromDatabase(
          LConverted, TypeInfo(TCodecRoot));
        LTarget := LDeserialized.AsObject as TCodecRoot;
        LTarget.Free;
      end;
    end);
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure BM_S54_Tracing_BeginSpan_Inactive(const state: TState);
var
  P: PState;
begin
  P := @state;
  TDiagnosticSource.Instance.Enabled := False;
  try
    TrackedBenchmark(P, procedure
    var
      Span: TSpan;
    begin
      while P^.KeepRunning do
      begin
        Span := TTracer.BeginSpan(
          'gRPC Server dext.test.v1.DummyService/DummyCall', 'gRPC');
        Span.SetStatus('Success');
      end;
    end);
  finally
    TDiagnosticSource.Instance.Enabled := True;
  end;
end;

procedure BM_S54_Grpc_PathSplit(const state: TState);
var
  Path: string;
  P: PState;
begin
  P := @state;
  Path := '/dext.test.v1.DummyService/DummyCall';
  TrackedBenchmark(P, procedure
  var
    Parts: TArray<string>;
    ServiceName: string;
    MethodName: string;
  begin
    while P^.KeepRunning do
    begin
      Parts := Path.Split(['/']);
      ServiceName := Parts[1].ToLower;
      MethodName := Parts[2].ToLower;
    end;
  end);
end;

procedure BM_S54_Grpc_PathManual(const state: TState);
var
  Path: string;
  P: PState;
begin
  P := @state;
  Path := '/dext.test.v1.DummyService/DummyCall';
  TrackedBenchmark(P, procedure
  var
    ServicePath: string;
    MethodPath: string;
    ServiceName: string;
    MethodName: string;
    SlashPos: Integer;
    i: Integer;
  begin
    while P^.KeepRunning do
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
  end);
end;

procedure BM_S54_Grpc_SubStopwatch_Always(const state: TState);
var
  P: PState;
begin
  P := @state;
  TrackedBenchmark(P, procedure
  var
    SwSub: TStopwatch;
    i: Integer;
  begin
    while P^.KeepRunning do
      for i := 1 to 5 do
      begin
        SwSub := TStopwatch.StartNew;
        SwSub.Stop;
      end;
  end);
end;

procedure BM_S54_Grpc_SubStopwatch_Guarded(const state: TState);
var
  TelemetryActive: Boolean;
  P: PState;
begin
  TelemetryActive := False;
  P := @state;
  TrackedBenchmark(P, procedure
  var
    SwSub: TStopwatch;
    i: Integer;
  begin
    while P^.KeepRunning do
      for i := 1 to 5 do
        if TelemetryActive then
        begin
          SwSub := TStopwatch.StartNew;
          SwSub.Stop;
        end;
  end);
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
  Benchmark(BM_S54_Json_SerializeUtf8, 'BM_S54_Json_SerializeUtf8').Threads(1);
  Benchmark(BM_S54_Orm_JsonConverter_Roundtrip, 'BM_S54_Orm_JsonConverter_Roundtrip').Threads(1);
  Benchmark(BM_S54_Tracing_BeginSpan_Inactive, 'BM_S54_Tracing_BeginSpan_Inactive').Threads(1);
  Benchmark(BM_S54_Grpc_SubStopwatch_Always, 'BM_S54_Grpc_SubStopwatch_Always').Threads(1);
  Benchmark(BM_S54_Grpc_SubStopwatch_Guarded, 'BM_S54_Grpc_SubStopwatch_Guarded').Threads(1);
  Benchmark(BM_S54_Grpc_PathSplit, 'BM_S54_Grpc_PathSplit').Threads(1);
  Benchmark(BM_S54_Grpc_PathManual, 'BM_S54_Grpc_PathManual').Threads(1);

finalization
  FinalizeFixtures;

end.

