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
{    gRPC Dispatcher and routing engine for the Dext Web Server.            }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Grpc.Server;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  Dext.Collections.Dict,
  Dext.Collections,
  Dext.Core.Reflection,
  Dext.Core.Activator,
  Dext.Web.Interfaces,
  Dext.Grpc.Attributes,
  Dext.Grpc.Codec,
  Dext.Serialization.Protobuf;

type
  TGrpcMethodMeta = record
    MethodName: string;
    RttiMethod: TRttiMethod;
    RequestClass: TClass;
    ResponseClass: TClass;
  end;

  TGrpcServiceMeta = class
  public
    ServiceName: string;
    InterfaceGUID: TGUID;
    ServiceImplClass: TClass;
    Methods: IDictionary<string, TGrpcMethodMeta>;
    constructor Create;
    destructor Destroy; override;
  end;

  TDextGrpcDispatcher = class
  private
    FServiceRegistry: IDictionary<string, TGrpcServiceMeta>;
    class var FDefault: TDextGrpcDispatcher;
    class constructor CreateClass;
    class destructor DestroyClass;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Invoke(const AContext: IHttpContext);
    procedure RegisterService(const AInterface: TGUID;
      const AServiceImpl: TClass);

    class property Default: TDextGrpcDispatcher read FDefault;
  end;

implementation

{ TGrpcServiceMeta }

constructor TGrpcServiceMeta.Create;
begin
  Methods := TCollections.CreateDictionary<string, TGrpcMethodMeta>;
end;

destructor TGrpcServiceMeta.Destroy;
begin
  inherited;
end;

{ TDextGrpcDispatcher }

class constructor TDextGrpcDispatcher.CreateClass;
begin
  FDefault := TDextGrpcDispatcher.Create;
end;

class destructor TDextGrpcDispatcher.DestroyClass;
begin
  FDefault.Free;
end;

constructor TDextGrpcDispatcher.Create;
begin
  FServiceRegistry := TCollections.CreateDictionary<string, TGrpcServiceMeta>;
end;

destructor TDextGrpcDispatcher.Destroy;
var
  Meta: TGrpcServiceMeta;
begin
  for Meta in FServiceRegistry.Values do
    Meta.Free;
  inherited;
end;

procedure TDextGrpcDispatcher.RegisterService(const AInterface: TGUID;
  const AServiceImpl: TClass);
var
  Context: TRttiContext;
  RttiType: TRttiType;
  IntfType: TRttiInterfaceType;
  Attr: TCustomAttribute;
  ServiceName: string;
  ServiceMeta: TGrpcServiceMeta;
  Method: TRttiMethod;
  MethodMeta: TGrpcMethodMeta;
  Params: TArray<TRttiParameter>;
  T: TRttiType;
begin
  Context := TReflection.Context;
  IntfType := nil;
  for T in Context.GetTypes do
  begin
    if (T.TypeKind = tkInterface) and
       (TRttiInterfaceType(T).GUID = AInterface) then
    begin
      IntfType := TRttiInterfaceType(T);
      Break;
    end;
  end;

  if not Assigned(IntfType) then Exit;

  ServiceName := '';
  for Attr in IntfType.GetAttributes do
  begin
    if Attr is GrpcServiceAttribute then
    begin
      ServiceName := GrpcServiceAttribute(Attr).ServiceName;
      Break;
    end;
  end;

  if ServiceName = '' then
    ServiceName := IntfType.Name;

  ServiceMeta := TGrpcServiceMeta.Create;
  ServiceMeta.ServiceName := ServiceName;
  ServiceMeta.InterfaceGUID := AInterface;
  ServiceMeta.ServiceImplClass := AServiceImpl;

  RttiType := Context.GetType(AServiceImpl);
  if Assigned(RttiType) then
  begin
    for Method in IntfType.GetMethods do
    begin
      for Attr in Method.GetAttributes do
      begin
        if Attr is GrpcMethodAttribute then
        begin
          Params := Method.GetParameters;
          if Length(Params) = 1 then
          begin
            MethodMeta.MethodName := GrpcMethodAttribute(
              Attr).GrpcMethodName;
            MethodMeta.RttiMethod := RttiType.GetMethod(Method.Name);
            MethodMeta.RequestClass :=
              Params[0].ParamType.AsInstance.MetaclassType;
            MethodMeta.ResponseClass :=
              Method.ReturnType.AsInstance.MetaclassType;
            ServiceMeta.Methods.Add(MethodMeta.MethodName.ToLower, MethodMeta);
          end;
          Break;
        end;
      end;
    end;
  end;

  FServiceRegistry.Add(ServiceName.ToLower, ServiceMeta);
end;

procedure TDextGrpcDispatcher.Invoke(const AContext: IHttpContext);
var
  Path: string;
  Parts: TArray<string>;
  ServiceName: string;
  MethodName: string;
  Service: TGrpcServiceMeta;
  Method: TGrpcMethodMeta;
  Stream: TStream;
  Buffer: TBytes;
  Compressed: Boolean;
  MsgBytes: TBytes;
  Offset: Integer;
  Request: TObject;
  Response: TObject;
  ServiceInstance: TObject;
  Intf: IInterface;
  Serialized: TBytes;
  Framed: TBytes;
begin
  Path := AContext.Request.Path;
  Parts := Path.Split(['/']);

  if Length(Parts) < 3 then
  begin
    AContext.Response.StatusCode := 404;
    AContext.Response.Write('Service / Method not found in path');
    Exit;
  end;

  ServiceName := Parts[1].ToLower;
  MethodName := Parts[2].ToLower;

  if not FServiceRegistry.TryGetValue(ServiceName, Service) then
  begin
    AContext.Response.StatusCode := 404;
    AContext.Response.Write('Service not found: ' + Parts[1]);
    Exit;
  end;

  if not Service.Methods.TryGetValue(MethodName, Method) then
  begin
    AContext.Response.StatusCode := 404;
    AContext.Response.Write('Method not found: ' + Parts[2]);
    Exit;
  end;

  Stream := AContext.Request.Body;
  if Stream.Size = 0 then
  begin
    AContext.Response.StatusCode := 400;
    AContext.Response.Write('Empty request body');
    Exit;
  end;

  SetLength(Buffer, Stream.Size);
  Stream.Position := 0;
  Stream.Read(Buffer[0], Stream.Size);

  Offset := 0;
  if not TGrpcMessageCodec.TryDecode(Buffer, Offset, Compressed, MsgBytes) then
  begin
    AContext.Response.StatusCode := 400;
    AContext.Response.Write('Invalid gRPC frame');
    Exit;
  end;

  Request := TActivator.CreateInstance(Method.RequestClass, []);
  try
    TProtobufSerializer.Deserialize(MsgBytes, Request);

    ServiceInstance := nil;
    Intf := nil;
    if Assigned(AContext.Services) then
      ServiceInstance := AContext.Services.GetService(
        Service.ServiceImplClass);

    if not Assigned(ServiceInstance) then
    begin
      ServiceInstance := Service.ServiceImplClass.Create;
      if not Supports(ServiceInstance, IInterface, Intf) then
        Intf := nil;
    end;

    try
      try
        Response := Method.RttiMethod.Invoke(ServiceInstance,
          [Request]).AsObject;
        try
          Serialized := TProtobufSerializer.Serialize(Response);
          Framed := TGrpcMessageCodec.Encode(Serialized);

          AContext.Response.StatusCode := 200;
          AContext.Response.ContentType := 'application/grpc';
          AContext.Response.AddHeader('grpc-status', '0');
          AContext.Response.AddHeader('grpc-message', 'OK');
          AContext.Response.Write(Framed);
        finally
          Response.Free;
        end;
      except
        on E: Exception do
        begin
          AContext.Response.StatusCode := 200;
          AContext.Response.ContentType := 'application/grpc';
          AContext.Response.AddHeader('grpc-status', '13'); // INTERNAL
          AContext.Response.AddHeader('grpc-message', E.Message);
        end;
      end;
    finally
      if not Assigned(AContext.Services) and not Assigned(Intf) then
        ServiceInstance.Free;
    end;
  finally
    Request.Free;
  end;
end;

end.
