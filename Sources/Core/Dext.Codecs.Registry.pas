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
unit Dext.Codecs.Registry;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.TypInfo,
  Dext.Collections.Dict;

type
  /// <summary>Procedure signature used by generated protobuf writers.</summary>
  TDextCodecWriteProc = procedure(AWriter: TObject; AObj: TObject);
  /// <summary>Procedure signature used by generated protobuf readers.</summary>
  TDextCodecReadProc = procedure(AReader: TObject; AObj: TObject);
  /// <summary>Function signature used by generated gRPC service invokers.</summary>
  TDextGrpcMethodInvoker = function(AService: TObject; ARequest: TObject): TObject;

  /// <summary>Pair of generated protobuf read and write procedures for one Delphi type.</summary>
  TDextCodecPair = record
    WriteProc: TDextCodecWriteProc;
    ReadProc: TDextCodecReadProc;
  end;

  /// <summary>Global registry for protobuf codecs and static gRPC method invokers.</summary>
  TDextCodecRegistry = class
  private
    class var FProtobuf: IDictionary<PTypeInfo, TDextCodecPair>;
    class var FGrpcInvokers: IDictionary<string, TDextGrpcMethodInvoker>;
    class var FLock: TCriticalSection;
    /// <summary>Initializes the shared registry caches.</summary>
    class constructor Create;
    /// <summary>Releases the shared registry caches.</summary>
    class destructor Destroy;
    /// <summary>Builds the normalized lookup key for a service method.</summary>
    class function MethodKey(const AServiceName, AMethodName: string): string; static;
  public
    /// <summary>Registers a protobuf codec pair for a specific type info.</summary>
    class procedure RegisterProtobuf(AType: PTypeInfo;
      AWrite: TDextCodecWriteProc; ARead: TDextCodecReadProc); overload; static;
    /// <summary>Registers a protobuf codec pair for a generic type.</summary>
    class procedure RegisterProtobuf<T>(AWrite: TDextCodecWriteProc;
      ARead: TDextCodecReadProc); overload; static;
    /// <summary>Looks up a registered protobuf codec pair for a type info.</summary>
    class function TryGetProtobuf(AType: PTypeInfo;
      out AWrite: TDextCodecWriteProc; out ARead: TDextCodecReadProc): Boolean; static;

    /// <summary>Registers a direct invoker for a gRPC service method.</summary>
    class procedure RegisterGrpcInvoker(const AServiceName, AMethodName: string;
      AInvoker: TDextGrpcMethodInvoker); static;
    /// <summary>Looks up a direct invoker for a gRPC service method.</summary>
    class function TryGetGrpcInvoker(const AServiceName, AMethodName: string;
      out AInvoker: TDextGrpcMethodInvoker): Boolean; static;

    /// <summary>Clears all registered codecs and invokers.</summary>
    class procedure Clear; static;
  end;

implementation

uses
  Dext.Collections;

class constructor TDextCodecRegistry.Create;
begin
  FProtobuf := TCollections.CreateDictionary<PTypeInfo, TDextCodecPair>;
  FGrpcInvokers := TCollections.CreateDictionary<string, TDextGrpcMethodInvoker>(True);
  FLock := TCriticalSection.Create;
end;

class destructor TDextCodecRegistry.Destroy;
begin
  FProtobuf := nil;
  FGrpcInvokers := nil;
  FLock.Free;
end;

class procedure TDextCodecRegistry.Clear;
begin
  FLock.Acquire;
  try
    FProtobuf.Clear;
    FGrpcInvokers.Clear;
  finally
    FLock.Release;
  end;
end;

class function TDextCodecRegistry.MethodKey(const AServiceName,
  AMethodName: string): string;
begin
  Result := AServiceName.ToLower + '/' + AMethodName.ToLower;
end;

class procedure TDextCodecRegistry.RegisterGrpcInvoker(const AServiceName,
  AMethodName: string; AInvoker: TDextGrpcMethodInvoker);
begin
  FLock.Acquire;
  try
    FGrpcInvokers.AddOrSetValue(MethodKey(AServiceName, AMethodName), AInvoker);
  finally
    FLock.Release;
  end;
end;

class procedure TDextCodecRegistry.RegisterProtobuf(AType: PTypeInfo;
  AWrite: TDextCodecWriteProc; ARead: TDextCodecReadProc);
var
  Pair: TDextCodecPair;
begin
  if AType = nil then
    Exit;

  Pair.WriteProc := AWrite;
  Pair.ReadProc := ARead;

  FLock.Acquire;
  try
    FProtobuf.AddOrSetValue(AType, Pair);
  finally
    FLock.Release;
  end;
end;

class procedure TDextCodecRegistry.RegisterProtobuf<T>(
  AWrite: TDextCodecWriteProc; ARead: TDextCodecReadProc);
begin
  RegisterProtobuf(TypeInfo(T), AWrite, ARead);
end;

class function TDextCodecRegistry.TryGetGrpcInvoker(const AServiceName,
  AMethodName: string; out AInvoker: TDextGrpcMethodInvoker): Boolean;
begin
  FLock.Acquire;
  try
    Result := FGrpcInvokers.TryGetValue(MethodKey(AServiceName, AMethodName),
      AInvoker);
  finally
    FLock.Release;
  end;
end;

class function TDextCodecRegistry.TryGetProtobuf(AType: PTypeInfo;
  out AWrite: TDextCodecWriteProc; out ARead: TDextCodecReadProc): Boolean;
var
  Pair: TDextCodecPair;
begin
  AWrite := nil;
  ARead := nil;

  FLock.Acquire;
  try
    Result := FProtobuf.TryGetValue(AType, Pair);
  finally
    FLock.Release;
  end;

  if Result then
  begin
    AWrite := Pair.WriteProc;
    ARead := Pair.ReadProc;
  end;
end;

end.
