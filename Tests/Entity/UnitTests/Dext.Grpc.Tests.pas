{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
{  Author:  Cesar Romero & Dext Contributors                                }
{  Created: 2026-07-07                                                      }
{                                                                           }
{  Description:                                                             }
{    Unit tests for gRPC, Protobuf, and dispatcher subsystems.              }
{                                                                           }
{***************************************************************************}
unit Dext.Grpc.Tests;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing,
  Dext.Grpc.Attributes,
  Dext.Grpc.Codec,
  Dext.Core.Span,
  Dext.Serialization.Protobuf,
  Dext.Web.Grpc.Server,
  Dext.Entity.GrpcProvider;

type
  [GrpcMessage]
  TDummyRequest = class
  private
    FMessage: string;
    FValue: Integer;
  public
    [ProtoMember(1)]
    property Message: string read FMessage write FMessage;
    [ProtoMember(2)]
    property Value: Integer read FValue write FValue;
  end;

  [GrpcMessage]
  TDummyResponse = class
  private
    FResult: string;
    FSuccess: Boolean;
  public
    [ProtoMember(1)]
    property Result: string read FResult write FResult;
    [ProtoMember(2)]
    property Success: Boolean read FSuccess write FSuccess;
  end;

  [GrpcService('dext.test.v1.DummyService')]
  IDummyService = interface(IInvokable)
    ['{E8F8B6C7-674A-4835-AB37-A3BA476C55AF}']
    [GrpcMethod('DummyCall')]
    function DummyCall(const ARequest: TDummyRequest): TDummyResponse;
  end;

  TDummyService = class(TInterfacedObject, IDummyService)
  public
    function DummyCall(const ARequest: TDummyRequest): TDummyResponse;
  end;

  [TestFixture('gRPC & Protobuf Infrastructure')]
  TGrpcTests = class
  public
    [Test]
    procedure Test_Protobuf_Serialization_Deserialization;
    [Test]
    procedure Test_Grpc_Lpm_Codec;
    procedure Test_Grpc_Lpm_EncodeInto;
    procedure Test_Grpc_Lpm_FrameInPlace;
    procedure Test_Protobuf_SerializeToStream;
    [Test]
    procedure Test_EndToEnd_Grpc_Dispatcher_And_Client;
  end;

implementation

{ TDummyService }

function TDummyService.DummyCall(
  const ARequest: TDummyRequest): TDummyResponse;
begin
  Result := TDummyResponse.Create;
  Result.Result := 'Echo: ' + ARequest.Message + ' with value ' +
    IntToStr(ARequest.Value);
  Result.Success := True;
end;

{ TGrpcTests }

procedure TGrpcTests.Test_Protobuf_Serialization_Deserialization;
var
  Req: TDummyRequest;
  Res: TDummyRequest;
  Bytes: TBytes;
begin
  Req := TDummyRequest.Create;
  Req.Message := 'Hello Protobuf';
  Req.Value := 12345;
  try
    Bytes := TProtobufSerializer.Serialize(Req);
    Should(Length(Bytes)).BeGreaterThan(0);

    Res := TDummyRequest.Create;
    try
      TProtobufSerializer.Deserialize(Bytes, Res);
      Should(Res.Message).Be('Hello Protobuf');
      Should(Res.Value).Be(12345);
    finally
      Res.Free;
    end;
  finally
    Req.Free;
  end;
end;

procedure TGrpcTests.Test_Grpc_Lpm_Codec;
var
  Payload: TBytes;
  Framed: TBytes;
  Decoded: TBytes;
  Offset: Integer;
  Compressed: Boolean;
begin
  SetLength(Payload, 4);
  Payload[0] := $AA;
  Payload[1] := $BB;
  Payload[2] := $CC;
  Payload[3] := $DD;

  Framed := TGrpcMessageCodec.Encode(Payload, False);
  Should(Length(Framed)).Be(9);
  Should(Framed[0]).Be(0); // Uncompressed
  Should(Framed[4]).Be(4); // Length 4

  Offset := 0;
  Should(TGrpcMessageCodec.TryDecode(
    Framed, Offset, Compressed, Decoded)).BeTrue;
  Should(Offset).Be(9);
  Should(Compressed).BeFalse;
  Should(Length(Decoded)).Be(4);
  Should(Decoded[0]).Be($AA);
end;

procedure TGrpcTests.Test_Grpc_Lpm_EncodeInto;
var
  Payload: TBytes;
  Framed: TBytes;
  Span: TByteSpan;
begin
  SetLength(Payload, 4);
  Payload[0] := $AA;
  Payload[1] := $BB;
  Payload[2] := $CC;
  Payload[3] := $DD;
  Span := TByteSpan.Create(@Payload[0], Length(Payload));
  Should(TGrpcMessageCodec.EncodeInto(Span, Framed)).Be(9);
  Should(Length(Framed)).Be(9);
  Should(Framed[0]).Be(0);
  Should(Framed[4]).Be(4);
  Should(Framed[5]).Be($AA);
end;

procedure TGrpcTests.Test_Grpc_Lpm_FrameInPlace;
var
  Framed: TBytes;
begin
  SetLength(Framed, 4);
  Framed[0] := $AA;
  Framed[1] := $BB;
  Framed[2] := $CC;
  Framed[3] := $DD;
  Should(TGrpcMessageCodec.FrameInPlace(Framed)).Be(9);
  Should(Length(Framed)).Be(9);
  Should(Framed[0]).Be(0);
  Should(Framed[4]).Be(4);
  Should(Framed[5]).Be($AA);
  Should(Framed[8]).Be($DD);
end;

procedure TGrpcTests.Test_Protobuf_SerializeToStream;
var
  Obj: TDummyRequest;
  Expected: TBytes;
  Stream: TBytesStream;
  Actual: TBytes;
begin
  Obj := TDummyRequest.Create;
  try
    Obj.Message := 'stream';
    Obj.Value := 7;
    Expected := TProtobufSerializer.Serialize(Obj, pcmRtti);
    Stream := TBytesStream.Create(nil);
    try
      TProtobufSerializer.SerializeToStream(Obj, Stream, pcmRtti);
      Actual := Stream.Bytes;
      SetLength(Actual, Stream.Size);
      Should(Length(Actual)).Be(Length(Expected));
      if Length(Expected) > 0 then
        Should(CompareMem(@Actual[0], @Expected[0], Length(Expected))).BeTrue;
    finally
      Stream.Free;
    end;
  finally
    Obj.Free;
  end;
end;

procedure TGrpcTests.Test_EndToEnd_Grpc_Dispatcher_And_Client;
var
  Dispatcher: TDextGrpcDispatcher;
  Client: TGrpcClient;
  Req: TDummyRequest;
  Res: TDummyResponse;
begin
  Dispatcher := TDextGrpcDispatcher.Create;
  try
    Dispatcher.RegisterService(IDummyService, TDummyService);
    Client := TGrpcClient.Create(Dispatcher);
    try
      Req := TDummyRequest.Create;
      Req.Message := 'Test Call';
      Req.Value := 42;
      Res := TDummyResponse.Create;
      try
        Client.CallMethod('dext.test.v1.DummyService', 'DummyCall', Req, Res);
        Should(Res.Success).BeTrue;
        Should(Res.Result).Be('Echo: Test Call with value 42');
      finally
        Req.Free;
        Res.Free;
      end;
    finally
      Client.Free;
    end;
  finally
    Dispatcher.Free;
  end;
end;

end.
