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
unit Dext.Codecs.S54.Tests;

interface

uses
  System.Classes,
  System.IOUtils,
  System.Rtti,
  System.SysUtils,
  Dext.Collections,
  Dext.Core.Activator,
  Dext.Core.DirectAccess,
  Dext.Core.TypeModel,
  Dext.Core.ValueConverters,
  Dext.Entity.Dialects,
  Dext.Entity.TypeConverters,
  Dext.Serialization.Protobuf,
  Dext.Grpc.Attributes,
  Dext.Hosting.CLI.Args,
  Dext.Hosting.CLI.Commands.Codecs,
  Dext.Testing;

type
  [GrpcMessage]
  TCodecChild = class
  private
    FName: string;
  public
    [ProtoMember(1)]
    property Name: string read FName write FName;
  end;

  [GrpcMessage]
  TCodecRoot = class
  private
    FId: Integer;
    FName: string;
    FItems: IList<TCodecChild>;
  public
    constructor Create;
    destructor Destroy; override;
    [ProtoMember(1)]
    property Id: Integer read FId write FId;
    [ProtoMember(2)]
    property Name: string read FName write FName;
    [ProtoMember(3)]
    property Items: IList<TCodecChild> read FItems write FItems;
  end;

  [GrpcMessage]
  TCodecScalarListRoot = class
  private
    FValues: IList<Integer>;
  public
    constructor Create;
    destructor Destroy; override;
    [ProtoMember(1)]
    property Values: IList<Integer> read FValues write FValues;
  end;

  [GrpcMessage]
  TCodecNestedRoot = class
  private
    FChild: TCodecChild;
    FItems: IList<TCodecChild>;
  public
    constructor Create;
    destructor Destroy; override;
    [ProtoMember(1)]
    property Child: TCodecChild read FChild write FChild;
    [ProtoMember(2)]
    property Items: IList<TCodecChild> read FItems write FItems;
  end;

  TDirectTarget = class
  private
    FCount: Integer;
    FName: string;
    FActive: Boolean;
  public
    property Count: Integer read FCount write FCount;
    property Name: string read FName write FName;
    property Active: Boolean read FActive write FActive;
  end;

  [TestFixture('S54 - TypeModel')]
  TTypeModelTests = class
  public
    [Test]
    procedure ShouldBuildPlansForDirectAndListFields;
    [Test]
    procedure ShouldClassifyNativeKinds;
  end;

  [TestFixture('S54 - DirectAccess')]
  TDirectAccessTests = class
  public
    [Test]
    procedure ShouldReadAndWriteFieldsByOffset;
    [Test]
    procedure ShouldConvertDatabaseValuesToBoolean;
  end;

  [TestFixture('S54 - CLI Codecs')]
  TCodecsCommandTests = class
  public
    [Test]
    procedure ShouldGenerateProtoAndStaticCodecsForNestedLists;
    [Test]
    procedure ShouldSerializeAndDeserializeNestedObjectWithDirectCodec;
    [Test]
    procedure ShouldGenerateGrpcInvokersForServices;
    [Test]
    procedure ShouldRoundtripNestedJsonColumnThroughConverter;
  end;

implementation

constructor TCodecRoot.Create;
begin
  inherited Create;
  FItems := TCollections.CreateList<TCodecChild>(True);
end;

destructor TCodecRoot.Destroy;
begin
  FItems := nil;
  inherited;
end;

constructor TCodecScalarListRoot.Create;
begin
  inherited Create;
  FValues := TCollections.CreateList<Integer>;
end;

destructor TCodecScalarListRoot.Destroy;
begin
  FValues := nil;
  inherited;
end;

constructor TCodecNestedRoot.Create;
begin
  inherited Create;
  FChild := TCodecChild.Create;
  FItems := TCollections.CreateList<TCodecChild>(True);
end;

destructor TCodecNestedRoot.Destroy;
begin
  FChild.Free;
  FItems := nil;
  inherited;
end;

procedure TTypeModelTests.ShouldBuildPlansForDirectAndListFields;
var
  Plan: IDextTypeCodecPlan;
  Field: TDextFieldPlan;
begin
  Plan := TDextTypeModel.GetPlan(TypeInfo(TCodecRoot));
  Should(Plan <> nil).BeTrue;
  Should(Plan.HasDirectAccess).BeTrue;
  Should(Plan.HasGeneratedCodec).BeFalse;
  Should(Length(Plan.GetFields)).Be(3);
  Should(Plan.TryGetFieldByProtoTag(1, Field)).BeTrue;
  Should(Field.Name).Be('Id');
  Should(Field.NativeKind).Be(nkInt32);
  Should(Field.AccessMode).Be(amDirectField);
  Should(Plan.TryGetFieldByProtoTag(3, Field)).BeTrue;
  Should(Field.IsList).BeTrue;
  Should(Field.ElementType = TypeInfo(TCodecChild)).BeTrue;
end;

procedure TTypeModelTests.ShouldClassifyNativeKinds;
begin
  Should(TDextTypeModel.NativeKindOf(TypeInfo(Integer))).Be(nkInt32);
  Should(TDextTypeModel.NativeKindOf(TypeInfo(Boolean))).Be(nkBoolean);
  Should(TDextTypeModel.NativeKindOf(TypeInfo(TDateTime))).Be(nkDateTime);
  Should(TDextTypeModel.NativeKindOf(TypeInfo(string))).Be(nkString);
end;

procedure TDirectAccessTests.ShouldReadAndWriteFieldsByOffset;
var
  Target: TDirectTarget;
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  FieldCount: TRttiField;
  FieldName: TRttiField;
  FieldActive: TRttiField;
begin
  Target := TDirectTarget.Create;
  try
    RttiContext := TRttiContext.Create;
    RttiType := RttiContext.GetType(TypeInfo(TDirectTarget));
    FieldCount := RttiType.GetField('FCount');
    FieldName := RttiType.GetField('FName');
    FieldActive := RttiType.GetField('FActive');

    TDextDirectAccess.WriteInt32(Target, FieldCount.Offset, 42);
    TDextDirectAccess.WriteString(Target, FieldName.Offset, 'Dext');
    TDextDirectAccess.WriteBoolean(Target, FieldActive.Offset, True);

    Should(TDextDirectAccess.ReadInt32(Target, FieldCount.Offset)).Be(42);
    Should(TDextDirectAccess.ReadString(Target, FieldName.Offset)).Be('Dext');
    Should(TDextDirectAccess.ReadBoolean(Target, FieldActive.Offset)).BeTrue;
  finally
    Target.Free;
  end;
end;

procedure TDirectAccessTests.ShouldConvertDatabaseValuesToBoolean;
var
  IntegerValue: TValue;
  StringValue: TValue;
  Converted: TValue;
begin
  IntegerValue := TValue.From<Integer>(1);
  StringValue := TValue.From<string>('False');

  Converted := TValueConverter.Convert(IntegerValue, TypeInfo(Boolean));
  Should(Converted.AsBoolean).BeTrue;

  Converted := TValueConverter.Convert(StringValue, TypeInfo(Boolean));
  Should(Converted.AsBoolean).BeFalse;
end;

procedure TCodecsCommandTests.ShouldGenerateGrpcInvokersForServices;
var
  TempDir: string;
  InputFile: string;
  GeneratedUnit: string;
  SourceText: string;
  Args: TCommandLineArgs;
  Command: TCodecsCommand;
  Lines: TStringList;
begin
  TempDir := TPath.Combine(TPath.GetTempPath, 'DextS54GrpcCodecs');
  if not TDirectory.Exists(TempDir) then
    TDirectory.CreateDirectory(TempDir);

  InputFile := TPath.Combine(TempDir, 'GrpcInput.pas');
  GeneratedUnit := TPath.Combine(TempDir, 'GrpcInput.DextCodecs.pas');

  SourceText :=
    'unit GrpcInput;' + sLineBreak + sLineBreak +
    'interface' + sLineBreak + sLineBreak +
    'uses Dext.Grpc.Attributes;' + sLineBreak + sLineBreak +
    'type' + sLineBreak +
    '  [GrpcMessage]' + sLineBreak +
    '  TGrpcRequest = class' + sLineBreak +
    '  private' + sLineBreak +
    '    FId: Integer;' + sLineBreak +
    '  public' + sLineBreak +
    '    [ProtoMember(1)]' + sLineBreak +
    '    property Id: Integer read FId write FId;' + sLineBreak +
    '  end;' + sLineBreak + sLineBreak +
    '  [GrpcService(''dext.test.v1.DummyService'')]' + sLineBreak +
    '  IDummyService = interface(IInvokable)' + sLineBreak +
    '    [''{E8F8B6C7-674A-4835-AB37-A3BA476C55AF}'']' + sLineBreak +
    '    [GrpcMethod(''DummyCall'')]' + sLineBreak +
    '    function DummyCall(const ARequest: TGrpcRequest): TGrpcRequest;' + sLineBreak +
    '  end;' + sLineBreak + sLineBreak +
    'implementation' + sLineBreak + sLineBreak +
    'initialization' + sLineBreak + sLineBreak +
    '  TActivator.RegisterDefault<IList<TCodecChild>, TList<TCodecChild>>;' + sLineBreak +
    '  TActivator.RegisterDefault<IList<Integer>, TList<Integer>>;' + sLineBreak + sLineBreak +
    'end.';
  TFile.WriteAllText(InputFile, SourceText, TEncoding.UTF8);

  Lines := TStringList.Create;
  try
    Args := TCommandLineArgs.Create;
    try
      Command := TCodecsCommand.Create;
      try
        Args.Parse(['codecs', 'generate', '--unit', InputFile, '--out', GeneratedUnit]);
        Command.Execute(Args);
        Should(TFile.Exists(GeneratedUnit)).BeTrue;
        Lines.LoadFromFile(GeneratedUnit, TEncoding.UTF8);
        Should(Lines.Text).Contain('function Invoke_IDummyService_DummyCall(AService: TObject; ARequest: TObject): TObject;');
        Should(Lines.Text).Contain('Result := IDummyService(AService).DummyCall(TGrpcRequest(ARequest));');
        Should(Lines.Text).Contain('TDextCodecRegistry.RegisterGrpcInvoker(''dext.test.v1.DummyService'', ''DummyCall'', Invoke_IDummyService_DummyCall);');
      finally
        Command.Free;
      end;
    finally
      Args.Free;
    end;
  finally
    Lines.Free;
  end;
end;
procedure TCodecsCommandTests.ShouldSerializeAndDeserializeNestedObjectWithDirectCodec;
var
  Source: TCodecChild;
  Target: TCodecChild;
  Bytes: TBytes;
begin
  Source := TCodecChild.Create;
  Target := TCodecChild.Create;
  try
    Source.Name := 'Nested';

    Bytes := TProtobufSerializer.Serialize(Source, pcmDirect);
    TProtobufSerializer.Deserialize(Bytes, Target, pcmDirect);

    Should(Target.Name).Be('Nested');
  finally
    Target.Free;
    Source.Free;
  end;
end;

procedure TCodecsCommandTests.ShouldRoundtripNestedJsonColumnThroughConverter;
var
  Converter: TJsonConverter;
  JsonValue: TValue;
  Root: TCodecNestedRoot;
  Target: TCodecNestedRoot;
  Deserialized: TValue;
begin
  Converter := TJsonConverter.Create(True);
  Root := TCodecNestedRoot.Create;
  Target := nil;
  try
    Root.Child.Name := 'Nested';
    Root.Items.Add(TCodecChild.Create);
    Root.Items[0].Name := 'Item1';

    JsonValue := Converter.ToDatabase(TValue.From<TObject>(Root), ddPostgreSQL);
    Should(JsonValue.IsEmpty).BeFalse;

    Deserialized := Converter.FromDatabase(JsonValue, TypeInfo(TCodecNestedRoot));
    Should(Deserialized.IsEmpty).BeFalse;

    Target := Deserialized.AsObject as TCodecNestedRoot;
    Should(Target <> nil).BeTrue;
    Should(Target.Child <> nil).BeTrue;
    Should(Target.Child.Name).Be('Nested');
    Should(Target.Items.Count).Be(1);
    Should(Target.Items[0].Name).Be('Item1');
  finally
    Target.Free;
    Root.Free;
    Converter.Free;
  end;
end;

procedure TCodecsCommandTests.ShouldGenerateProtoAndStaticCodecsForNestedLists;
var
  TempDir: string;
  InputFile: string;
  GeneratedUnit: string;
  ProtoFile: string;
  SourceText: string;
  Args: TCommandLineArgs;
  Command: TCodecsCommand;
  Lines: TStringList;
  ProtoText: string;
begin
  TempDir := TPath.Combine(TPath.GetTempPath, 'DextS54Codecs');
  if not TDirectory.Exists(TempDir) then
    TDirectory.CreateDirectory(TempDir);

  InputFile := TPath.Combine(TempDir, 'CodecInput.pas');
  GeneratedUnit := TPath.Combine(TempDir, 'CodecInput.DextCodecs.pas');
  ProtoFile := TPath.Combine(TempDir, 'CodecInput.proto');

  SourceText :=
    'unit CodecInput;' + sLineBreak + sLineBreak +
    'interface' + sLineBreak + sLineBreak +
    'uses Dext.Collections, Dext.Grpc.Attributes;' + sLineBreak + sLineBreak +
    'type' + sLineBreak +
    '  [GrpcMessage]' + sLineBreak +
    '  TChild = class' + sLineBreak +
    '  private' + sLineBreak +
    '    FName: string;' + sLineBreak +
    '  public' + sLineBreak +
    '    [ProtoMember(1)]' + sLineBreak +
    '    property Name: string read FName write FName;' + sLineBreak +
    '  end;' + sLineBreak + sLineBreak +
    '  [GrpcMessage]' + sLineBreak +
    '  TRoot = class' + sLineBreak +
    '  private' + sLineBreak +
    '    FId: Integer;' + sLineBreak +
    '    FItems: IList<TChild>;' + sLineBreak +
    '  public' + sLineBreak +
    '    constructor Create;' + sLineBreak +
    '    [ProtoMember(1)]' + sLineBreak +
    '    property Id: Integer read FId write FId;' + sLineBreak +
    '    [ProtoMember(2)]' + sLineBreak +
    '    property Items: IList<TChild> read FItems write FItems;' + sLineBreak +
    '  end;' + sLineBreak + sLineBreak +
    'implementation' + sLineBreak + sLineBreak +
    'constructor TRoot.Create;' + sLineBreak +
    'begin' + sLineBreak +
    '  inherited Create;' + sLineBreak +
    '  FItems := TCollections.CreateList<TChild>(True);' + sLineBreak +
    'end;' + sLineBreak + sLineBreak +
    'initialization' + sLineBreak + sLineBreak +
    '  TActivator.RegisterDefault<IList<TCodecChild>, TList<TCodecChild>>;' + sLineBreak +
    '  TActivator.RegisterDefault<IList<Integer>, TList<Integer>>;' + sLineBreak + sLineBreak +
    'end.';

  TFile.WriteAllText(InputFile, SourceText, TEncoding.UTF8);

  Lines := TStringList.Create;
  try
    Args := TCommandLineArgs.Create;
    try
      Command := TCodecsCommand.Create;
      try
        Args.Parse(['codecs', 'generate', '--unit', InputFile, '--out', GeneratedUnit]);
        Command.Execute(Args);
        Should(TFile.Exists(GeneratedUnit)).BeTrue;
        Lines.LoadFromFile(GeneratedUnit, TEncoding.UTF8);
        Should(Lines.Text).Contain('TCollections.CreateList<TChild>(True)');
        Should(Lines.Text).Contain('for i := 0 to Obj.Items.Count - 1 do');
        Should(Lines.Text).Contain('Obj.Items.Add(TChild(ReadMessageObject(Reader, TChild.Create)));');
      finally
        Command.Free;
      end;
    finally
      Args.Free;
    end;

    Args := TCommandLineArgs.Create;
    try
      Command := TCodecsCommand.Create;
      try
        Args.Parse(['codecs', 'proto', '--unit', InputFile, '--out', ProtoFile]);
        Command.Execute(Args);
        Should(TFile.Exists(ProtoFile)).BeTrue;
        ProtoText := TFile.ReadAllText(ProtoFile, TEncoding.UTF8);
        Should(ProtoText).Contain('repeated Child Items = 2;');
      finally
        Command.Free;
      end;
    finally
      Args.Free;
    end;
  finally
    Lines.Free;
  end;
end;

initialization
  TActivator.RegisterDefault<IList<TCodecChild>, TList<TCodecChild>>;

end.


