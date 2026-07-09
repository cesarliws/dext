unit BM.S54;

interface

uses
  Spring.Benchmark;

procedure BM_S54_Protobuf_Direct_Roundtrip(const state: TState);
procedure BM_S54_Json_Roundtrip(const state: TState);
procedure BM_S54_Orm_JsonConverter_Roundtrip(const state: TState);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
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

procedure InitializeFixtures;
begin
  TActivator.RegisterDefault<IList<TCodecChild>, Dext.Collections.TList<TCodecChild>>;
  GJsonConverter := TJsonConverter.Create(True);
end;

procedure FinalizeFixtures;
begin
  GJsonConverter.Free;
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
    TProtobufSerializer.Deserialize(Bytes, Target, pcmDirect);

    while state.KeepRunning do
    begin
      Bytes := TProtobufSerializer.Serialize(Source, pcmDirect);
      TProtobufSerializer.Deserialize(Bytes, Target, pcmDirect);
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
  Benchmark(BM_S54_Protobuf_Direct_Roundtrip, 'BM_S54_Protobuf_Direct_Roundtrip').Threads(1);
  Benchmark(BM_S54_Json_Roundtrip, 'BM_S54_Json_Roundtrip').Threads(1);
  Benchmark(BM_S54_Orm_JsonConverter_Roundtrip, 'BM_S54_Orm_JsonConverter_Roundtrip').Threads(1);

finalization
  FinalizeFixtures;

end.
