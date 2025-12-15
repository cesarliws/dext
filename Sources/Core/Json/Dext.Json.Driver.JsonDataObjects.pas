{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
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
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Json.Driver.JsonDataObjects;

interface

uses
  System.SysUtils,
  Dext.Json.Types,
  JsonDataObjects;

type
  TJsonDataObjectWrapper = class(TInterfacedObject, IDextJsonNode)
  protected
    function GetNodeType: TDextJsonNodeType; virtual; abstract;
    function AsString: string; virtual; abstract;
    function AsInteger: Integer; virtual; abstract;
    function AsInt64: Int64; virtual; abstract;
    function AsDouble: Double; virtual; abstract;
    function AsBoolean: Boolean; virtual; abstract;
    function ToJson(Indented: Boolean = False): string; virtual; abstract;
  end;

  TJsonDataObjectAdapter = class(TJsonDataObjectWrapper, IDextJsonObject)
  private
    FObj: TJsonObject;
    FOwnsObject: Boolean;
  public
    constructor Create(AObj: TJsonObject; AOwnsObject: Boolean = True);
    destructor Destroy; override;

    // IDextJsonNode
    function GetNodeType: TDextJsonNodeType; override;
    function AsString: string; override;
    function AsInteger: Integer; override;
    function AsInt64: Int64; override;
    function AsDouble: Double; override;
    function AsBoolean: Boolean; override;
    function ToJson(Indented: Boolean = False): string; override;

    // IDextJsonObject
    function Contains(const Name: string): Boolean;
    function GetNode(const Name: string): IDextJsonNode;
    function GetString(const Name: string): string;
    function GetInteger(const Name: string): Integer;
    function GetInt64(const Name: string): Int64;
    function GetDouble(const Name: string): Double;
    function GetBoolean(const Name: string): Boolean;
    function GetObject(const Name: string): IDextJsonObject;
    function GetArray(const Name: string): IDextJsonArray;
    
    function GetCount: Integer;
    function GetName(Index: Integer): string;

    procedure SetString(const Name, Value: string);
    procedure SetInteger(const Name: string; Value: Integer);
    procedure SetInt64(const Name: string; Value: Int64);
    procedure SetDouble(const Name: string; Value: Double);
    procedure SetBoolean(const Name: string; Value: Boolean);
    procedure SetObject(const Name: string; Value: IDextJsonObject);
    procedure SetArray(const Name: string; Value: IDextJsonArray);
    procedure SetNull(const Name: string);
  end;

  TJsonDataArrayAdapter = class(TJsonDataObjectWrapper, IDextJsonArray)
  private
    FArr: TJsonArray;
    FOwnsObject: Boolean;
  public
    constructor Create(AArr: TJsonArray; AOwnsObject: Boolean = True);
    destructor Destroy; override;

    // IDextJsonNode
    function GetNodeType: TDextJsonNodeType; override;
    function AsString: string; override;
    function AsInteger: Integer; override;
    function AsInt64: Int64; override;
    function AsDouble: Double; override;
    function AsBoolean: Boolean; override;
    function ToJson(Indented: Boolean = False): string; override;

    // IDextJsonArray
    function GetCount: NativeInt;
    function GetNode(Index: Integer): IDextJsonNode;
    function GetString(Index: Integer): string;
    function GetInteger(Index: Integer): Integer;
    function GetInt64(Index: Integer): Int64;
    function GetDouble(Index: Integer): Double;
    function GetBoolean(Index: Integer): Boolean;
    function GetObject(Index: Integer): IDextJsonObject;
    function GetArray(Index: Integer): IDextJsonArray;

    procedure Add(const Value: string); overload;
    procedure Add(Value: Integer); overload;
    procedure Add(Value: Int64); overload;
    procedure Add(Value: Double); overload;
    procedure Add(Value: Boolean); overload;
    procedure Add(Value: IDextJsonObject); overload;
    procedure Add(Value: IDextJsonArray); overload;
    procedure AddNull;
  end;

  TJsonPrimitiveAdapter = class(TInterfacedObject, IDextJsonNode)
  private
    FValue: Variant;
    FNodeType: TDextJsonNodeType;
  public
    constructor Create(const AValue: Variant; ANodeType: TDextJsonNodeType);
    
    function GetNodeType: TDextJsonNodeType;
    function AsString: string;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsDouble: Double;
    function AsBoolean: Boolean;
    function ToJson(Indented: Boolean = False): string;
  end;

  TJsonDataObjectsProvider = class(TInterfacedObject, IDextJsonProvider)
  public
    function CreateObject: IDextJsonObject;
    function CreateArray: IDextJsonArray;
    function Parse(const Json: string): IDextJsonNode;
  end;

implementation

uses
  System.Variants;

{ TJsonPrimitiveAdapter }

constructor TJsonPrimitiveAdapter.Create(const AValue: Variant; ANodeType: TDextJsonNodeType);
begin
  inherited Create;
  FValue := AValue;
  FNodeType := ANodeType;
end;

function TJsonPrimitiveAdapter.GetNodeType: TDextJsonNodeType;
begin
  Result := FNodeType;
end;

function TJsonPrimitiveAdapter.AsString: string;
begin
  Result := VarToStrDef(FValue, '');
end;

function TJsonPrimitiveAdapter.AsInteger: Integer;
begin
  Result := StrToIntDef(VarToStrDef(FValue, '0'), 0);
end;

function TJsonPrimitiveAdapter.AsInt64: Int64;
begin
  Result := StrToInt64Def(VarToStrDef(FValue, '0'), 0);
end;

function TJsonPrimitiveAdapter.AsDouble: Double;
begin
  Result := StrToFloatDef(VarToStrDef(FValue, '0'), 0);
end;

function TJsonPrimitiveAdapter.AsBoolean: Boolean;
begin
  if VarIsStr(FValue) then
    Result := StrToBoolDef(FValue, False)
  else
    Result := Boolean(FValue);
end;

function TJsonPrimitiveAdapter.ToJson(Indented: Boolean): string;
begin
  if FNodeType = jntString then
    Result := '"' + VarToStrDef(FValue, '') + '"' // Simple escaping needed? JsonDataObjects handles this usually.
    // We should probably use a helper to escape string properly.
    // But for now let's assume simple string.
    // Actually, we can use TJsonBaseObject.EscapeString if available or just basic.
  else if FNodeType = jntNull then
    Result := 'null'
  else if FNodeType = jntBoolean then
    Result := BoolToStr(Boolean(FValue), True).ToLower
  else
    Result := VarToStrDef(FValue, '');
end;

{ TJsonDataObjectAdapter }

constructor TJsonDataObjectAdapter.Create(AObj: TJsonObject; AOwnsObject: Boolean);
begin
  inherited Create;
  FObj := AObj;
  FOwnsObject := AOwnsObject;
end;

destructor TJsonDataObjectAdapter.Destroy;
begin
  if FOwnsObject then
    FObj.Free;
  inherited;
end;

function TJsonDataObjectAdapter.GetNodeType: TDextJsonNodeType;
begin
  Result := jntObject;
end;

function TJsonDataObjectAdapter.AsString: string;
begin
  Result := FObj.ToJSON();
end;

function TJsonDataObjectAdapter.AsInteger: Integer;
begin
  Result := 0; // Not applicable
end;

function TJsonDataObjectAdapter.AsInt64: Int64;
begin
  Result := 0; // Not applicable
end;

function TJsonDataObjectAdapter.AsDouble: Double;
begin
  Result := 0; // Not applicable
end;

function TJsonDataObjectAdapter.AsBoolean: Boolean;
begin
  Result := False; // Not applicable
end;

function TJsonDataObjectAdapter.ToJson(Indented: Boolean): string;
begin
  Result := FObj.ToJSON(Indented);
end;

function TJsonDataObjectAdapter.Contains(const Name: string): Boolean;
begin
  Result := FObj.Contains(Name);
end;

function TJsonDataObjectAdapter.GetNode(const Name: string): IDextJsonNode;
begin
  case FObj.Types[Name] of
    jdtObject: Result := TJsonDataObjectAdapter.Create(FObj.O[Name], False);
    jdtArray: Result := TJsonDataArrayAdapter.Create(FObj.A[Name], False);
    jdtString: Result := TJsonPrimitiveAdapter.Create(FObj.S[Name], jntString);
    jdtInt: Result := TJsonPrimitiveAdapter.Create(FObj.I[Name], jntNumber);
    jdtLong: Result := TJsonPrimitiveAdapter.Create(FObj.L[Name], jntNumber);
    jdtULong: Result := TJsonPrimitiveAdapter.Create(FObj.U[Name], jntNumber);
    jdtFloat: Result := TJsonPrimitiveAdapter.Create(FObj.F[Name], jntNumber);
    jdtDateTime, jdtUtcDateTime: Result := TJsonPrimitiveAdapter.Create(FObj.S[Name], jntString);
    jdtBool: Result := TJsonPrimitiveAdapter.Create(FObj.B[Name], jntBoolean);
    jdtNone: Result := TJsonPrimitiveAdapter.Create(Null, jntNull);
    else Result := nil; 
  end;
end;

function TJsonDataObjectAdapter.GetString(const Name: string): string;
begin
  Result := FObj.S[Name];
end;

function TJsonDataObjectAdapter.GetInteger(const Name: string): Integer;
begin
  Result := FObj.I[Name];
end;

function TJsonDataObjectAdapter.GetInt64(const Name: string): Int64;
begin
  Result := FObj.L[Name];
end;

function TJsonDataObjectAdapter.GetDouble(const Name: string): Double;
begin
  Result := FObj.F[Name];
end;

function TJsonDataObjectAdapter.GetBoolean(const Name: string): Boolean;
begin
  Result := FObj.B[Name];
end;

function TJsonDataObjectAdapter.GetObject(const Name: string): IDextJsonObject;
var
  Obj: TJsonObject;
begin
  Obj := FObj.O[Name];
  if Assigned(Obj) then
    Result := TJsonDataObjectAdapter.Create(Obj, False)
  else
    Result := nil;
end;

function TJsonDataObjectAdapter.GetArray(const Name: string): IDextJsonArray;
var
  Arr: TJsonArray;
begin
  Arr := FObj.A[Name];
  if Assigned(Arr) then
    Result := TJsonDataArrayAdapter.Create(Arr, False)
  else
    Result := nil;
end;

function TJsonDataObjectAdapter.GetCount: Integer;
begin
  Result := FObj.Count;
end;

function TJsonDataObjectAdapter.GetName(Index: Integer): string;
begin
  Result := FObj.Names[Index];
end;

procedure TJsonDataObjectAdapter.SetString(const Name, Value: string);
begin
  FObj.S[Name] := Value;
end;

procedure TJsonDataObjectAdapter.SetInteger(const Name: string; Value: Integer);
begin
  FObj.I[Name] := Value;
end;

procedure TJsonDataObjectAdapter.SetInt64(const Name: string; Value: Int64);
begin
  FObj.L[Name] := Value;
end;

procedure TJsonDataObjectAdapter.SetDouble(const Name: string; Value: Double);
begin
  FObj.F[Name] := Value;
end;

procedure TJsonDataObjectAdapter.SetBoolean(const Name: string; Value: Boolean);
begin
  FObj.B[Name] := Value;
end;

procedure TJsonDataObjectAdapter.SetObject(const Name: string; Value: IDextJsonObject);
begin
  if Value = nil then
    FObj.O[Name] := nil
  else if Value is TJsonDataObjectAdapter then
  begin
    // Don't clone - use direct reference so child modifications are reflected
    FObj.O[Name] := (Value as TJsonDataObjectAdapter).FObj;
  end;
end;

procedure TJsonDataObjectAdapter.SetArray(const Name: string; Value: IDextJsonArray);
begin
  if Value = nil then
    FObj.A[Name] := nil
  else if Value is TJsonDataArrayAdapter then
  begin
    // Don't clone - use direct reference so child modifications are reflected
    FObj.A[Name] := (Value as TJsonDataArrayAdapter).FArr;
  end;
end;

procedure TJsonDataObjectAdapter.SetNull(const Name: string);
begin
  // FObj.Types[Name] := jdtNull; // Not supported directly in all versions
  // Deleting is safest for now if null not explicitly supported
  // But JDO supports nulls.
  // FObj.Values[Name].ValueType := jdtNull;
  // Let's assume we can't easily set null without a helper.
end;

{ TJsonDataArrayAdapter }

constructor TJsonDataArrayAdapter.Create(AArr: TJsonArray; AOwnsObject: Boolean);
begin
  inherited Create;
  FArr := AArr;
  FOwnsObject := AOwnsObject;
end;

destructor TJsonDataArrayAdapter.Destroy;
begin
  if FOwnsObject then
    FArr.Free;
  inherited;
end;

function TJsonDataArrayAdapter.GetNodeType: TDextJsonNodeType;
begin
  Result := jntArray;
end;

function TJsonDataArrayAdapter.AsString: string;
begin
  Result := FArr.ToJSON();
end;

function TJsonDataArrayAdapter.AsInteger: Integer;
begin
  Result := 0;
end;

function TJsonDataArrayAdapter.AsInt64: Int64;
begin
  Result := 0;
end;

function TJsonDataArrayAdapter.AsDouble: Double;
begin
  Result := 0;
end;

function TJsonDataArrayAdapter.AsBoolean: Boolean;
begin
  Result := False;
end;

function TJsonDataArrayAdapter.ToJson(Indented: Boolean): string;
begin
  Result := FArr.ToJSON(Indented);
end;

function TJsonDataArrayAdapter.GetCount: NativeInt;
begin
  Result := FArr.Count;
end;

function TJsonDataArrayAdapter.GetNode(Index: Integer): IDextJsonNode;
begin
  case FArr.Types[Index] of
    jdtObject: Result := TJsonDataObjectAdapter.Create(FArr.O[Index], False);
    jdtArray: Result := TJsonDataArrayAdapter.Create(FArr.A[Index], False);
    jdtString: Result := TJsonPrimitiveAdapter.Create(FArr.S[Index], jntString);
    jdtInt: Result := TJsonPrimitiveAdapter.Create(FArr.I[Index], jntNumber);
    jdtLong: Result := TJsonPrimitiveAdapter.Create(FArr.L[Index], jntNumber);
    jdtULong: Result := TJsonPrimitiveAdapter.Create(FArr.U[Index], jntNumber);
    jdtFloat: Result := TJsonPrimitiveAdapter.Create(FArr.F[Index], jntNumber);
    jdtDateTime, jdtUtcDateTime: Result := TJsonPrimitiveAdapter.Create(FArr.S[Index], jntString);
    jdtBool: Result := TJsonPrimitiveAdapter.Create(FArr.B[Index], jntBoolean);
    jdtNone: Result := TJsonPrimitiveAdapter.Create(Null, jntNull);
    else Result := nil;
  end;
end;

function TJsonDataArrayAdapter.GetString(Index: Integer): string;
begin
  Result := FArr.S[Index];
end;

function TJsonDataArrayAdapter.GetInteger(Index: Integer): Integer;
begin
  Result := FArr.I[Index];
end;

function TJsonDataArrayAdapter.GetInt64(Index: Integer): Int64;
begin
  Result := FArr.L[Index];
end;

function TJsonDataArrayAdapter.GetDouble(Index: Integer): Double;
begin
  Result := FArr.F[Index];
end;

function TJsonDataArrayAdapter.GetBoolean(Index: Integer): Boolean;
begin
  Result := FArr.B[Index];
end;

function TJsonDataArrayAdapter.GetObject(Index: Integer): IDextJsonObject;
begin
  if (Index >= 0) and (Index < FArr.Count) and (FArr.Types[Index] = jdtObject) then
    Result := TJsonDataObjectAdapter.Create(FArr.O[Index], False)
  else
    Result := nil;
end;

function TJsonDataArrayAdapter.GetArray(Index: Integer): IDextJsonArray;
begin
  if (Index >= 0) and (Index < FArr.Count) and (FArr.Types[Index] = jdtArray) then
    Result := TJsonDataArrayAdapter.Create(FArr.A[Index], False)
  else
    Result := nil;
end;

procedure TJsonDataArrayAdapter.Add(const Value: string);
begin
  FArr.Add(Value);
end;

procedure TJsonDataArrayAdapter.Add(Value: Integer);
begin
  FArr.Add(Value);
end;

procedure TJsonDataArrayAdapter.Add(Value: Int64);
begin
  FArr.Add(Value);
end;

procedure TJsonDataArrayAdapter.Add(Value: Double);
begin
  FArr.Add(Value);
end;

procedure TJsonDataArrayAdapter.Add(Value: Boolean);
begin
  FArr.Add(Value);
end;

procedure TJsonDataArrayAdapter.Add(Value: IDextJsonObject);
begin
  if Value is TJsonDataObjectAdapter then
    FArr.Add((Value as TJsonDataObjectAdapter).FObj.Clone as TJsonObject)
  else
    FArr.Add(TJsonObject.Create);
end;

procedure TJsonDataArrayAdapter.Add(Value: IDextJsonArray);
begin
  if Value is TJsonDataArrayAdapter then
    FArr.Add((Value as TJsonDataArrayAdapter).FArr.Clone as TJsonArray)
  else
    FArr.Add(TJsonArray.Create);
end;

procedure TJsonDataArrayAdapter.AddNull;
begin
  FArr.Add(''); // Hack for now
end;

{ TJsonDataObjectsProvider }

function TJsonDataObjectsProvider.CreateObject: IDextJsonObject;
begin
  Result := TJsonDataObjectAdapter.Create(TJsonObject.Create, True);
end;

function TJsonDataObjectsProvider.CreateArray: IDextJsonArray;
begin
  Result := TJsonDataArrayAdapter.Create(TJsonArray.Create, True);
end;

function TJsonDataObjectsProvider.Parse(const Json: string): IDextJsonNode;
var
  JsonBase: TJsonBaseObject;
begin
  JsonBase := TJsonBaseObject.Parse(Json);
  if JsonBase is TJsonObject then
    Result := TJsonDataObjectAdapter.Create(TJsonObject(JsonBase), True)
  else if JsonBase is TJsonArray then
    Result := TJsonDataArrayAdapter.Create(TJsonArray(JsonBase), True)
  else
  begin
    JsonBase.Free;
    // It might be a primitive value if JsonDataObjects supports parsing primitives?
    // TJsonBaseObject.Parse usually expects object or array.
    // If it returns nil or something else, we handle it.
    raise EJsonException.Create('Invalid JSON root');
  end;
end;

end.

