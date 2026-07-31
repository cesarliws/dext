{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025-2026 Cesar Romero & Dext Contributors        }
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
{  Author:  Cesar Romero                                                    }
{  Created: 2026-01-06                                                      }
{                                                                           }
{  Description:                                                             }
{    JSON Hub Protocol implementation (SignalR-compatible).                 }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs.Protocol.Json;

{$I Dext.inc}

interface

uses
  System.JSON,
  System.Rtti,
  System.SysUtils,
  System.Generics.Collections,
  System.TypInfo,
  Dext.Web.Hubs.Interfaces,
  Dext.Core.Reflection,
  Dext.Web.Hubs.Types;

type
  /// <summary>
  /// JSON Hub Protocol implementation.
  /// Compatible with SignalR's JSON protocol.
  /// </summary>
  TJsonHubProtocol = class(TInterfacedObject, IHubProtocol)
  private
    const RECORD_SEPARATOR = #$1E; // ASCII RS (Record Separator)
  public
    // IHubProtocol
    function GetName: string;
    function GetVersion: Integer;
    function GetTransferFormat: string;
    
    function Serialize(const Message: THubMessage): string;
    function Deserialize(const Data: string): THubMessage;
    function IsCompleteMessage(const Data: string): Boolean;
    
    // Helpers
    class function SerializeInvocation(const Target: string; const Args: TArray<TValue>): string;
    class function SerializeCompletion(const InvocationId: string; const AResult: TValue; const Error: string = ''): string;
    class function SerializePing: string;
    class function SerializeClose(const Error: string = ''): string;
    
    // TValue serialization helpers
    class function ValueToJson(const Value: TValue): TJSONValue;
    class function JsonToValue(const Json: TJSONValue; TypeInfo: PTypeInfo): TValue;
  end;

implementation

{ TJsonHubProtocol }

function TJsonHubProtocol.GetName: string;
begin
  Result := 'json';
end;

function TJsonHubProtocol.GetVersion: Integer;
begin
  Result := 1;
end;

function TJsonHubProtocol.GetTransferFormat: string;
begin
  Result := 'Text';
end;

function TJsonHubProtocol.Serialize(const Message: THubMessage): string;
var
  Json: TJSONObject;
  Args: TJSONArray;
  Arg: TValue;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('type', TJSONNumber.Create(Ord(Message.MessageType)));
    
    case Message.MessageType of
      hmtInvocation, hmtStreamInvocation:
        begin
          if Message.InvocationId <> '' then
            Json.AddPair('invocationId', Message.InvocationId);
          Json.AddPair('target', Message.Target);
          
          Args := TJSONArray.Create;
          for Arg in Message.Arguments do
            Args.AddElement(ValueToJson(Arg));
          Json.AddPair('arguments', Args);
        end;
        
      hmtCompletion:
        begin
          if Message.InvocationId <> '' then
            Json.AddPair('invocationId', Message.InvocationId);
            
          if Message.Error <> '' then
            Json.AddPair('error', Message.Error)
          else if not Message.Result.IsEmpty then
            Json.AddPair('result', ValueToJson(Message.Result));
        end;
        
      hmtClose:
        begin
          if Message.Error <> '' then
            Json.AddPair('error', Message.Error);
        end;
        
      hmtPing:
        ; // Just type is enough
    end;
    
    // SignalR uses Record Separator as message delimiter
    Result := Json.ToJSON + RECORD_SEPARATOR;
  finally
    Json.Free;
  end;
end;

function TJsonHubProtocol.Deserialize(const Data: string): THubMessage;
var
  CleanData: string;
  Json: TJSONObject;
  JArgs: TJSONArray;
  I: Integer;
  MsgType: Integer;
begin
  Result := Default(THubMessage);
  
  // Remove record separator if present
  CleanData := Data.TrimRight([RECORD_SEPARATOR, #13, #10]);
  if CleanData = '' then
    Exit;
    
  Json := TJSONObject.ParseJSONValue(CleanData) as TJSONObject;
  if Json = nil then
    raise EHubException.CreateFmt('Invalid JSON message: %s', [CleanData]);
    
  try
    MsgType := Json.GetValue<Integer>('type', 0);
    if (MsgType < Ord(Low(THubMessageType))) or (MsgType > Ord(High(THubMessageType))) then
      raise EHubException.CreateFmt('Invalid message type: %d', [MsgType]);
      
    Result.MessageType := THubMessageType(MsgType);
    Result.InvocationId := Json.GetValue<string>('invocationId', '');
    Result.Target := Json.GetValue<string>('target', '');
    Result.Error := Json.GetValue<string>('error', '');
    
    // Parse arguments
    if Json.TryGetValue<TJSONArray>('arguments', JArgs) then
    begin
      SetLength(Result.Arguments, JArgs.Count);
      for I := 0 to JArgs.Count - 1 do
        Result.Arguments[I] := JsonToValue(JArgs.Items[I], nil);
    end;
    
    // Parse result
    if Json.GetValue('result') <> nil then
      Result.Result := JsonToValue(Json.GetValue('result'), nil);
  finally
    Json.Free;
  end;
end;

function TJsonHubProtocol.IsCompleteMessage(const Data: string): Boolean;
begin
  // A complete message ends with the Record Separator
  Result := (Length(Data) > 0) and (Data[Length(Data)] = RECORD_SEPARATOR);
end;

class function TJsonHubProtocol.SerializeInvocation(const Target: string;
  const Args: TArray<TValue>): string;
var
  Json: TJSONObject;
  JArgs: TJSONArray;
  Arg: TValue;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('type', TJSONNumber.Create(1)); // Invocation
    Json.AddPair('target', Target);
    
    JArgs := TJSONArray.Create;
    for Arg in Args do
      JArgs.AddElement(ValueToJson(Arg));
    Json.AddPair('arguments', JArgs);
    
    Result := Json.ToJSON + #$1E;
  finally
    Json.Free;
  end;
end;

class function TJsonHubProtocol.SerializeCompletion(const InvocationId: string;
  const AResult: TValue; const Error: string): string;
var
  Json: TJSONObject;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('type', TJSONNumber.Create(3)); // Completion
    if InvocationId <> '' then
      Json.AddPair('invocationId', InvocationId);
      
    if Error <> '' then
      Json.AddPair('error', Error)
    else if not AResult.IsEmpty then
      Json.AddPair('result', ValueToJson(AResult));
      
    Result := Json.ToJSON + #$1E;
  finally
    Json.Free;
  end;
end;

class function TJsonHubProtocol.SerializePing: string;
begin
  Result := '{"type":6}' + #$1E;
end;

class function TJsonHubProtocol.SerializeClose(const Error: string): string;
var
  Json: TJSONObject;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('type', TJSONNumber.Create(7)); // Close
    if Error <> '' then
      Json.AddPair('error', Error);
    Result := Json.ToJSON + #$1E;
  finally
    Json.Free;
  end;
end;

class function TJsonHubProtocol.ValueToJson(const Value: TValue): TJSONValue;
var
  I: Integer;
  Arr: TJSONArray;
  Obj: TJSONObject;
  Field: TRttiField;
  Prop: TRttiProperty;
  RttiType: TRttiType;
begin
  if Value.IsEmpty then
    Exit(TJSONNull.Create);
    
  case Value.Kind of
    tkInteger, tkInt64:
      Result := TJSONNumber.Create(Value.AsInt64);
      
    tkFloat:
      Result := TJSONNumber.Create(Value.AsExtended);
      
    tkString, tkLString, tkWString, tkUString:
      Result := TJSONString.Create(Value.AsString);
      
    tkEnumeration:
      if Value.TypeInfo = TypeInfo(Boolean) then
        Result := TJSONBool.Create(Value.AsBoolean)
      else
        Result := TJSONNumber.Create(Value.AsOrdinal);
        
    tkClass:
      begin
        if Value.AsObject = nil then
          Exit(TJSONNull.Create);
          
        // Handle TJSONValue directly
        if Value.AsObject is TJSONValue then
          Exit(TJSONValue(Value.AsObject).Clone as TJSONValue);
          
        // Serialize object properties
        Obj := TJSONObject.Create;
        try
          RttiType := TReflection.Context.GetType(Value.AsObject.ClassType);
          for Prop in RttiType.GetProperties do
          begin
            if Prop.IsReadable and (Prop.Visibility in [mvPublic, mvPublished]) then
              Obj.AddPair(Prop.Name, ValueToJson(Prop.GetValue(Value.AsObject)));
          end;
        except
          Obj.Free;
          raise;
        end;
        Result := Obj;
      end;
      
    tkRecord:
      begin
        Obj := TJSONObject.Create;
        try
          RttiType := TReflection.Context.GetType(Value.TypeInfo);
          for Field in RttiType.GetFields do
            Obj.AddPair(Field.Name, ValueToJson(Field.GetValue(Value.GetReferenceToRawData)));
        except
          Obj.Free;
          raise;
        end;
        Result := Obj;
      end;
      
    tkDynArray:
      begin
        Arr := TJSONArray.Create;
        for I := 0 to Value.GetArrayLength - 1 do
          Arr.AddElement(ValueToJson(Value.GetArrayElement(I)));
        Result := Arr;
      end;
      
  else
    Result := TJSONString.Create(Value.ToString);
  end;
end;

class function TJsonHubProtocol.JsonToValue(const Json: TJSONValue;
  TypeInfo: PTypeInfo): TValue;
var
  I: Integer;
  Arr: TArray<TValue>;
begin
  if Json = nil then
    Exit(TValue.Empty);
    
  if Json is TJSONNull then
    Exit(TValue.Empty);
    
  if Json is TJSONBool then
    Exit(TJSONBool(Json).AsBoolean);
    
  if Json is TJSONNumber then
  begin
    // Try to preserve type
    if Pos('.', Json.ToString) > 0 then
      Exit(TJSONNumber(Json).AsDouble)
    else
      Exit(TJSONNumber(Json).AsInt64);
  end;
  
  if Json is TJSONString then
    Exit(TJSONString(Json).Value);
    
  if Json is TJSONArray then
  begin
    SetLength(Arr, TJSONArray(Json).Count);
    for I := 0 to TJSONArray(Json).Count - 1 do
      Arr[I] := JsonToValue(TJSONArray(Json).Items[I], nil);
    Exit(TValue.From<TArray<TValue>>(Arr));
  end;
  
  // For objects, return the JSON string for now
  // Full object deserialization would require TypeInfo
  if Json is TJSONObject then
    Exit(TValue.From<string>(Json.ToJSON));
    
  Result := TValue.Empty;
end;

end.
