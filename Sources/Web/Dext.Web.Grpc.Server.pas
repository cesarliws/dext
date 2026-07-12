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
  Dext.Codecs.Registry,
  Dext.Core.Reflection,
  Dext.Core.Span,
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

uses
  System.Diagnostics, System.JSON, Dext.Logging, Dext.Logging.Global,
  Dext.Logging.Telemetry, Dext.Logging.Tracing;

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
  Values: TArray<TGrpcServiceMeta>;
  Meta: TGrpcServiceMeta;
  i: Integer;
  j: Integer;
  Found: Boolean;
begin
  Values := FServiceRegistry.Values;
  for i := 0 to High(Values) do
  begin
    Meta := Values[i];
    Found := False;
    for j := 0 to i - 1 do
      if Values[j] = Meta then
      begin
        Found := True;
        Break;
      end;
    if not Found then
      Meta.Free;
  end;
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
  LowerName: string;
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
            if not ServiceMeta.Methods.ContainsKey(MethodMeta.MethodName) then
              ServiceMeta.Methods.Add(MethodMeta.MethodName, MethodMeta);
            LowerName := MethodMeta.MethodName.ToLower;
            if LowerName <> MethodMeta.MethodName then
              if not ServiceMeta.Methods.ContainsKey(LowerName) then
                ServiceMeta.Methods.Add(LowerName, MethodMeta);
          end;
          Break;
        end;
      end;
    end;
  end;

  if not FServiceRegistry.ContainsKey(ServiceName) then
    FServiceRegistry.Add(ServiceName, ServiceMeta);
  LowerName := ServiceName.ToLower;
  if LowerName <> ServiceName then
    if not FServiceRegistry.ContainsKey(LowerName) then
      FServiceRegistry.Add(LowerName, ServiceMeta);
end;

procedure TDextGrpcDispatcher.Invoke(const AContext: IHttpContext);
var
  Path: string;
  ServicePath: string;
  MethodPath: string;
  ServiceName: string;
  MethodName: string;
  SlashPos: Integer;
  i: Integer;
  Service: TGrpcServiceMeta;
  Method: TGrpcMethodMeta;
  Stream: TStream;
  Buffer: TBytes;
  BodySpan: TByteSpan;
  RequestSize: Integer;
  Compressed: Boolean;
  MsgSpan: TByteSpan;
  Offset: Integer;
  Request: TObject;
  Response: TObject;
  ServiceInstance: TObject;
  Intf: IInterface;
  Serialized: TBytes;
  Framed: TBytes;
  Sw: TStopwatch;
  SwSub: TStopwatch;
  Span: TSpan;
  TelemetryActive: Boolean;
  LogInfoActive: Boolean;
  TimingActive: Boolean;
  Payload: TJSONObject;
  Invoker: TDextGrpcMethodInvoker;
begin
  TelemetryActive := TDiagnosticSource.Instance.IsActive;
  LogInfoActive := Log.Logger.IsEnabled(TLogLevel.Information);
  TimingActive := TelemetryActive or LogInfoActive;
  if TimingActive then
    Sw := TStopwatch.StartNew;
  Path := AContext.Request.Path;
  SlashPos := 0;
  if (Path <> '') and (Path[1] = '/') then
    for i := 2 to Length(Path) do
      if Path[i] = '/' then
      begin
        SlashPos := i;
        Break;
      end;

  if (SlashPos <= 2) or (SlashPos >= Length(Path)) then
  begin
    AContext.Response.StatusCode := 404;
    AContext.Response.Write('Service / Method not found in path');
    Exit;
  end;

  ServicePath := Copy(Path, 2, SlashPos - 2);
  MethodPath := Copy(Path, SlashPos + 1, MaxInt);
  ServiceName := ServicePath;
  MethodName := MethodPath;

  if TelemetryActive then
    Span := TTracer.BeginSpan('gRPC Server ' + ServicePath + '/' + MethodPath,
      'gRPC')
  else
    Span := TSpan.Create(nil);
  try
    if not FServiceRegistry.TryGetValue(ServiceName, Service) then
    begin
      ServiceName := ServicePath.ToLower;
      if not FServiceRegistry.TryGetValue(ServiceName, Service) then
      begin
        AContext.Response.StatusCode := 404;
        AContext.Response.Write('Service not found: ' + ServicePath);
        Exit;
      end;
    end;

    if not Service.Methods.TryGetValue(MethodName, Method) then
    begin
      MethodName := MethodPath.ToLower;
      if not Service.Methods.TryGetValue(MethodName, Method) then
      begin
        AContext.Response.StatusCode := 404;
        AContext.Response.Write('Method not found: ' + MethodPath);
        Exit;
      end;
    end;

    try
      Stream := AContext.Request.Body;
    except
      on E: Exception do
      begin
        Log.Error('[gRPC-Server] Request body read failed: {Class} | {Error}',
          [E.ClassName, E.Message]);
        AContext.Response.StatusCode := 200;
        AContext.Response.ContentType := 'application/grpc';
        AContext.Response.AddHeader('grpc-status', '13');
        AContext.Response.AddHeader('grpc-message', E.Message);
        Exit;
      end;
    end;
    if Stream.Size = 0 then
    begin
      AContext.Response.StatusCode := 400;
      AContext.Response.Write('Empty request body');
      Exit;
    end;

    RequestSize := Integer(Stream.Size);
    Stream.Position := 0;
    if (Stream is TCustomMemoryStream) and
       (TCustomMemoryStream(Stream).Memory <> nil) then
      BodySpan := TByteSpan.Create(TCustomMemoryStream(Stream).Memory, RequestSize)
    else
    begin
      SetLength(Buffer, RequestSize);
      if RequestSize > 0 then
        Stream.ReadBuffer(Buffer[0], RequestSize);
      if RequestSize > 0 then
        BodySpan := TByteSpan.Create(@Buffer[0], RequestSize)
      else
        BodySpan := TByteSpan.Create(nil, 0);
    end;

    Offset := 0;
    if TelemetryActive then
      SwSub := TStopwatch.StartNew;
    if not TGrpcMessageCodec.TryDecode(BodySpan, Offset, Compressed, MsgSpan) then
    begin
      AContext.Response.StatusCode := 400;
      AContext.Response.Write('Invalid gRPC frame');
      Exit;
    end;
    if TelemetryActive then
    begin
      SwSub.Stop;
      Payload := TJSONObject.Create;
      Payload.AddPair('service', ServicePath);
      Payload.AddPair('method', MethodPath);
      Payload.AddPair('size', TJSONNumber.Create(MsgSpan.Length));
      TDiagnosticSource.Instance.Write('gRPC.Server.Decode', Payload,
        'gRPC', SwSub.ElapsedMilliseconds);
    end;

    Request := TActivator.CreateInstance(Method.RequestClass, []);
    try
      if TelemetryActive then
        SwSub := TStopwatch.StartNew;
      TProtobufSerializer.Deserialize(MsgSpan, Request);

      if TelemetryActive then
      begin
        SwSub.Stop;
        Payload := TJSONObject.Create;
        Payload.AddPair('service', ServicePath);
        Payload.AddPair('method', MethodPath);
        TDiagnosticSource.Instance.Write('gRPC.Server.Deserialize', Payload,
          'gRPC', SwSub.ElapsedMilliseconds);
      end;

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
          if TelemetryActive then
            SwSub := TStopwatch.StartNew;
          if TDextCodecRegistry.TryGetGrpcInvoker(Service.ServiceName,
            Method.MethodName, Invoker) then
            Response := Invoker(ServiceInstance, Request)
          else
            Response := Method.RttiMethod.Invoke(ServiceInstance,
              [Request]).AsObject;

          if TelemetryActive then
          begin
            SwSub.Stop;
            Payload := TJSONObject.Create;
            Payload.AddPair('service', ServicePath);
            Payload.AddPair('method', MethodPath);
            TDiagnosticSource.Instance.Write('gRPC.Server.InvokeMethod', Payload,
              'gRPC', SwSub.ElapsedMilliseconds);
          end;

          try
            if TelemetryActive then
              SwSub := TStopwatch.StartNew;
            Serialized := TProtobufSerializer.Serialize(Response, pcmAuto);

            if TelemetryActive then
            begin
              SwSub.Stop;
              Payload := TJSONObject.Create;
              Payload.AddPair('service', ServicePath);
              Payload.AddPair('method', MethodPath);
              Payload.AddPair('size', TJSONNumber.Create(Length(Serialized)));
              TDiagnosticSource.Instance.Write('gRPC.Server.Serialize', Payload,
                'gRPC', SwSub.ElapsedMilliseconds);
            end;

            if TelemetryActive then
              SwSub := TStopwatch.StartNew;
            Framed := TGrpcMessageCodec.Encode(Serialized, False);

            if TelemetryActive then
            begin
              SwSub.Stop;
              Payload := TJSONObject.Create;
              Payload.AddPair('service', ServicePath);
              Payload.AddPair('method', MethodPath);
              Payload.AddPair('size', TJSONNumber.Create(Length(Framed)));
              TDiagnosticSource.Instance.Write('gRPC.Server.Encode', Payload,
                'gRPC', SwSub.ElapsedMilliseconds);
            end;

            AContext.Response.StatusCode := 200;
            AContext.Response.ContentType := 'application/grpc';
            AContext.Response.AddHeader('grpc-status', '0');
            AContext.Response.AddHeader('grpc-message', 'OK');
            AContext.Response.Write(Framed);

            if TimingActive then
              Sw.Stop;
            if LogInfoActive then
              Log.Info('[gRPC-Server] Invoke: {Service}/{Method} | ' +
                'Duration: {Time} ms | Req: {ReqSz} bytes | Res: {ResSz} bytes',
                [ServicePath, MethodPath, Sw.ElapsedMilliseconds, RequestSize,
                 Length(Framed)]);

            Span.SetStatus('Success');
            if TelemetryActive then
            begin
              Payload := TJSONObject.Create;
              Payload.AddPair('service', ServicePath);
              Payload.AddPair('method', MethodPath);
              Payload.AddPair('req_size', TJSONNumber.Create(RequestSize));
              Payload.AddPair('res_size', TJSONNumber.Create(Length(Framed)));
              TDiagnosticSource.Instance.Write('gRPC.Server.Invoke', Payload,
                'gRPC', Sw.ElapsedMilliseconds);
            end;
          finally
            Response.Free;
          end;
        except
          on E: Exception do
          begin
            Sw.Stop;
            Log.Error('[gRPC-Server] Invoke Error: {Service}/{Method} | ' +
              'Duration: {Time} ms | Error: {Err}',
              [ServicePath, MethodPath, Sw.ElapsedMilliseconds, E.Message]);

            Span.SetStatus('Error', E.Message);
            if TelemetryActive then
            begin
              Payload := TJSONObject.Create;
              Payload.AddPair('service', ServicePath);
              Payload.AddPair('method', MethodPath);
              Payload.AddPair('status', '13');
              Payload.AddPair('error', E.Message);
              TDiagnosticSource.Instance.Write('gRPC.Server.Error', Payload,
                'gRPC', Sw.ElapsedMilliseconds);
            end;

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
  except
    on E: Exception do
    begin
      Span.SetStatus('Error', E.Message);
      raise;
    end;
  end;
end;

end.




