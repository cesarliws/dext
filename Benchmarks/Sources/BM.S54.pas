unit BM.S54;

interface

uses
  Spring.Benchmark;

procedure BM_S54_Protobuf_Rtti_Roundtrip(const state: TState);
procedure BM_S54_Protobuf_Direct_Roundtrip(const state: TState);
procedure BM_S54_Protobuf_Generated_Roundtrip(const state: TState);
procedure BM_S54_Json_Roundtrip(const state: TState);
procedure BM_S54_Orm_JsonConverter_Roundtrip(const state: TState);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  Dext.Codecs.Registry,
  Dext.Collections,
  Dext.Core.Activator,
  Dext.Entity.Dialects,
  Dext.Entity.TypeConverters,
  Dext.Grpc.Attributes,
  Dext.Json,
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

initialization
  InitializeFixtures;
  Benchmark(BM_S54_Protobuf_Rtti_Roundtrip, 'BM_S54_Protobuf_Rtti_Roundtrip').Threads(1);
  Benchmark(BM_S54_Protobuf_Direct_Roundtrip, 'BM_S54_Protobuf_Direct_Roundtrip').Threads(1);
  Benchmark(BM_S54_Protobuf_Generated_Roundtrip, 'BM_S54_Protobuf_Generated_Roundtrip').Threads(1);
  Benchmark(BM_S54_Json_Roundtrip, 'BM_S54_Json_Roundtrip').Threads(1);
  Benchmark(BM_S54_Orm_JsonConverter_Roundtrip, 'BM_S54_Orm_JsonConverter_Roundtrip').Threads(1);

finalization
  FinalizeFixtures;

end.

