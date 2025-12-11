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
unit Dext.Json.Driver.SystemJson;

interface

uses
  System.Generics.Collections,
  System.JSON,
  System.SysUtils,
  Dext.Json.Types;

type
  TSystemJsonWrapper = class(TInterfacedObject, IDextJsonNode)
  protected
    function GetNodeType: TDextJsonNodeType; virtual; abstract;
    function AsString: string; virtual; abstract;
    function AsInteger: Integer; virtual; abstract;
    function AsInt64: Int64; virtual; abstract;
    function AsDouble: Double; virtual; abstract;
    function AsBoolean: Boolean; virtual; abstract;
    function ToJson(Indented: Boolean = False): string; virtual; abstract;
  end;

  TSystemJsonObjectAdapter = class(TSystemJsonWrapper, IDextJsonObject)
  private
    FObj: TJSONObject;
    FOwnsObject: Boolean;
  public
    constructor Create(AObj: TJSONObject; AOwnsObject: Boolean = True);
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

  TSystemJsonArrayAdapter = class(TSystemJsonWrapper, IDextJsonArray)
  private
    FArr: TJSONArray;
    FOwnsObject: Boolean;
  public
    constructor Create(AArr: TJSONArray; AOwnsObject: Boolean = True);
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

  TSystemJsonPrimitiveAdapter = class(TInterfacedObject, IDextJsonNode)
  private
    FValue: TJSONValue;
    FOwnsValue: Boolean;
  public
    constructor Create(AValue: TJSONValue; AOwnsValue: Boolean = True);
    destructor Destroy; override;
    
    function GetNodeType: TDextJsonNodeType;
    function AsString: string;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsDouble: Double;
    function AsBoolean: Boolean;
    function ToJson(Indented: Boolean = False): string;
  end;

  TSystemJsonProvider = class(TInterfacedObject, IDextJsonProvider)
  public
    function CreateObject: IDextJsonObject;
    function CreateArray: IDextJsonArray;
    function Parse(const Json: string): IDextJsonNode;
  end;

implementation

{ TSystemJsonPrimitiveAdapter }

constructor TSystemJsonPrimitiveAdapter.Create(AValue: TJSONValue; AOwnsValue: Boolean);
begin
  inherited Create;
  FValue := AValue;
  FOwnsValue := AOwnsValue;
end;

destructor TSystemJsonPrimitiveAdapter.Destroy;
begin
  if FOwnsValue then
    FValue.Free;
  inherited;
end;

function TSystemJsonPrimitiveAdapter.GetNodeType: TDextJsonNodeType;
begin
  if FValue is TJSONString then Result := jntString
  else if FValue is TJSONNumber then Result := jntNumber
  else if (FValue is TJSONTrue) or (FValue is TJSONFalse) then Result := jntBoolean
  else if FValue is TJSONNull then Result := jntNull
  else Result := jntString; // Fallback
end;

function TSystemJsonPrimitiveAdapter.AsString: string;
begin
  Result := FValue.Value;
end;

function TSystemJsonPrimitiveAdapter.AsInteger: Integer;
begin
  if FValue is TJSONNumber then
    Result := TJSONNumber(FValue).AsInt
  else
    Result := StrToIntDef(FValue.Value, 0);
end;

function TSystemJsonPrimitiveAdapter.AsInt64: Int64;
begin
  if FValue is TJSONNumber then
    Result := TJSONNumber(FValue).AsInt64
  else
    Result := StrToInt64Def(FValue.Value, 0);
end;

function TSystemJsonPrimitiveAdapter.AsDouble: Double;
begin
  if FValue is TJSONNumber then
    Result := TJSONNumber(FValue).AsDouble
  else
    Result := StrToFloatDef(FValue.Value, 0);
end;

function TSystemJsonPrimitiveAdapter.AsBoolean: Boolean;
begin
  if FValue is TJSONTrue then Result := True
  else if FValue is TJSONFalse then Result := False
  else Result := SameText(FValue.Value, 'true');
end;

function TSystemJsonPrimitiveAdapter.ToJson(Indented: Boolean): string;
begin
  Result := FValue.ToString;
end;

{ TSystemJsonObjectAdapter }

constructor TSystemJsonObjectAdapter.Create(AObj: TJSONObject; AOwnsObject: Boolean);
begin
  inherited Create;
  FObj := AObj;
  FOwnsObject := AOwnsObject;
end;

destructor TSystemJsonObjectAdapter.Destroy;
begin
  if FOwnsObject then
    FObj.Free;
  inherited;
end;

function TSystemJsonObjectAdapter.GetNodeType: TDextJsonNodeType;
begin
  Result := jntObject;
end;

function TSystemJsonObjectAdapter.AsString: string;
begin
  Result := FObj.ToString;
end;

function TSystemJsonObjectAdapter.AsInteger: Integer;
begin
  Result := 0;
end;

function TSystemJsonObjectAdapter.AsInt64: Int64;
begin
  Result := 0;
end;

function TSystemJsonObjectAdapter.AsDouble: Double;
begin
  Result := 0;
end;

function TSystemJsonObjectAdapter.AsBoolean: Boolean;
begin
  Result := False;
end;

function TSystemJsonObjectAdapter.ToJson(Indented: Boolean): string;
begin
  // System.Json doesn't have easy indentation built-in in older versions, 
  // but ToString usually returns minified.
  // For now we ignore Indented param or use FormatJSON if available.
  Result := FObj.ToString;
end;

function TSystemJsonObjectAdapter.Contains(const Name: string): Boolean;
begin
  Result := FObj.GetValue(Name) <> nil;
end;

function TSystemJsonObjectAdapter.GetNode(const Name: string): IDextJsonNode;
var
  Val: TJSONValue;
begin
  Val := FObj.GetValue(Name);
  if Val is TJSONObject then
    Result := TSystemJsonObjectAdapter.Create(TJSONObject(Val), False)
  else if Val is TJSONArray then
    Result := TSystemJsonArrayAdapter.Create(TJSONArray(Val), False)
  else if Val <> nil then
    Result := TSystemJsonPrimitiveAdapter.Create(Val, False)
  else
    Result := nil;
end;

function TSystemJsonObjectAdapter.GetString(const Name: string): string;
var
  Val: TJSONValue;
begin
  Val := FObj.GetValue(Name);
  if Val <> nil then
    Result := Val.Value
  else
    Result := '';
end;

function TSystemJsonObjectAdapter.GetInteger(const Name: string): Integer;
var
  Val: TJSONValue;
begin
  Val := FObj.GetValue(Name);
  if (Val <> nil) and (Val is TJSONNumber) then
    Result := TJSONNumber(Val).AsInt
  else
    Result := StrToIntDef(GetString(Name), 0);
end;

function TSystemJsonObjectAdapter.GetInt64(const Name: string): Int64;
var
  Val: TJSONValue;
begin
  Val := FObj.GetValue(Name);
  if (Val <> nil) and (Val is TJSONNumber) then
    Result := TJSONNumber(Val).AsInt64
  else
    Result := StrToInt64Def(GetString(Name), 0);
end;

function TSystemJsonObjectAdapter.GetDouble(const Name: string): Double;
var
  Val: TJSONValue;
begin
  Val := FObj.GetValue(Name);
  if (Val <> nil) and (Val is TJSONNumber) then
    Result := TJSONNumber(Val).AsDouble
  else
    Result := StrToFloatDef(GetString(Name), 0);
end;

function TSystemJsonObjectAdapter.GetBoolean(const Name: string): Boolean;
var
  Val: TJSONValue;
begin
  Val := FObj.GetValue(Name);
  if Val is TJSONTrue then
    Result := True
  else if Val is TJSONFalse then
    Result := False
  else
    Result := SameText(GetString(Name), 'true');
end;

function TSystemJsonObjectAdapter.GetObject(const Name: string): IDextJsonObject;
var
  Val: TJSONValue;
begin
  Val := FObj.GetValue(Name);
  if (Val <> nil) and (Val is TJSONObject) then
    Result := TSystemJsonObjectAdapter.Create(TJSONObject(Val), False)
  else
    Result := nil;
end;

function TSystemJsonObjectAdapter.GetArray(const Name: string): IDextJsonArray;
var
  Val: TJSONValue;
begin
  Val := FObj.GetValue(Name);
  if (Val <> nil) and (Val is TJSONArray) then
    Result := TSystemJsonArrayAdapter.Create(TJSONArray(Val), False)
  else
    Result := nil;
end;

function TSystemJsonObjectAdapter.GetCount: Integer;
begin
  Result := FObj.Count;
end;

function TSystemJsonObjectAdapter.GetName(Index: Integer): string;
begin
  Result := FObj.Pairs[Index].JsonString.Value;
end;

procedure TSystemJsonObjectAdapter.SetString(const Name, Value: string);
begin
  FObj.AddPair(Name, Value);
end;

procedure TSystemJsonObjectAdapter.SetInteger(const Name: string; Value: Integer);
begin
  FObj.AddPair(Name, TJSONNumber.Create(Value));
end;

procedure TSystemJsonObjectAdapter.SetInt64(const Name: string; Value: Int64);
begin
  FObj.AddPair(Name, TJSONNumber.Create(Value));
end;

procedure TSystemJsonObjectAdapter.SetDouble(const Name: string; Value: Double);
begin
  FObj.AddPair(Name, TJSONNumber.Create(Value));
end;

procedure TSystemJsonObjectAdapter.SetBoolean(const Name: string; Value: Boolean);
begin
  if Value then
    FObj.AddPair(Name, TJSONTrue.Create)
  else
    FObj.AddPair(Name, TJSONFalse.Create);
end;

procedure TSystemJsonObjectAdapter.SetObject(const Name: string; Value: IDextJsonObject);
begin
  if Value is TSystemJsonObjectAdapter then
  begin
    FObj.AddPair(Name, (Value as TSystemJsonObjectAdapter).FObj.Clone as TJSONObject);
  end;
end;

procedure TSystemJsonObjectAdapter.SetArray(const Name: string; Value: IDextJsonArray);
begin
  if Value is TSystemJsonArrayAdapter then
  begin
    FObj.AddPair(Name, (Value as TSystemJsonArrayAdapter).FArr.Clone as TJSONArray);
  end;
end;

procedure TSystemJsonObjectAdapter.SetNull(const Name: string);
begin
  FObj.AddPair(Name, TJSONNull.Create);
end;

{ TSystemJsonArrayAdapter }

constructor TSystemJsonArrayAdapter.Create(AArr: TJSONArray; AOwnsObject: Boolean);
begin
  inherited Create;
  FArr := AArr;
  FOwnsObject := AOwnsObject;
end;

destructor TSystemJsonArrayAdapter.Destroy;
begin
  if FOwnsObject then
    FArr.Free;
  inherited;
end;

function TSystemJsonArrayAdapter.GetNodeType: TDextJsonNodeType;
begin
  Result := jntArray;
end;

function TSystemJsonArrayAdapter.AsString: string;
begin
  Result := FArr.ToString;
end;

function TSystemJsonArrayAdapter.AsInteger: Integer;
begin
  Result := 0;
end;

function TSystemJsonArrayAdapter.AsInt64: Int64;
begin
  Result := 0;
end;

function TSystemJsonArrayAdapter.AsDouble: Double;
begin
  Result := 0;
end;

function TSystemJsonArrayAdapter.AsBoolean: Boolean;
begin
  Result := False;
end;

function TSystemJsonArrayAdapter.ToJson(Indented: Boolean): string;
begin
  Result := FArr.ToString;
end;

function TSystemJsonArrayAdapter.GetCount: NativeInt;
begin
  Result := FArr.Count;
end;

function TSystemJsonArrayAdapter.GetNode(Index: Integer): IDextJsonNode;
var
  Val: TJSONValue;
begin
  Val := FArr.Items[Index];
  if Val is TJSONObject then
    Result := TSystemJsonObjectAdapter.Create(TJSONObject(Val), False)
  else if Val is TJSONArray then
    Result := TSystemJsonArrayAdapter.Create(TJSONArray(Val), False)
  else if Val <> nil then
    Result := TSystemJsonPrimitiveAdapter.Create(Val, False)
  else
    Result := nil;
end;

function TSystemJsonArrayAdapter.GetString(Index: Integer): string;
begin
  Result := FArr.Items[Index].Value;
end;

function TSystemJsonArrayAdapter.GetInteger(Index: Integer): Integer;
var
  Val: TJSONValue;
begin
  Val := FArr.Items[Index];
  if Val is TJSONNumber then
    Result := TJSONNumber(Val).AsInt
  else
    Result := StrToIntDef(Val.Value, 0);
end;

function TSystemJsonArrayAdapter.GetInt64(Index: Integer): Int64;
var
  Val: TJSONValue;
begin
  Val := FArr.Items[Index];
  if Val is TJSONNumber then
    Result := TJSONNumber(Val).AsInt64
  else
    Result := StrToInt64Def(Val.Value, 0);
end;

function TSystemJsonArrayAdapter.GetDouble(Index: Integer): Double;
var
  Val: TJSONValue;
begin
  Val := FArr.Items[Index];
  if Val is TJSONNumber then
    Result := TJSONNumber(Val).AsDouble
  else
    Result := StrToFloatDef(Val.Value, 0);
end;

function TSystemJsonArrayAdapter.GetBoolean(Index: Integer): Boolean;
var
  Val: TJSONValue;
begin
  Val := FArr.Items[Index];
  if Val is TJSONTrue then
    Result := True
  else if Val is TJSONFalse then
    Result := False
  else
    Result := SameText(Val.Value, 'true');
end;

function TSystemJsonArrayAdapter.GetObject(Index: Integer): IDextJsonObject;
var
  Val: TJSONValue;
begin
  Val := FArr.Items[Index];
  if Val is TJSONObject then
    Result := TSystemJsonObjectAdapter.Create(TJSONObject(Val), False)
  else
    Result := nil;
end;

function TSystemJsonArrayAdapter.GetArray(Index: Integer): IDextJsonArray;
var
  Val: TJSONValue;
begin
  Val := FArr.Items[Index];
  if Val is TJSONArray then
    Result := TSystemJsonArrayAdapter.Create(TJSONArray(Val), False)
  else
    Result := nil;
end;

procedure TSystemJsonArrayAdapter.Add(const Value: string);
begin
  FArr.Add(Value);
end;

procedure TSystemJsonArrayAdapter.Add(Value: Integer);
begin
  FArr.Add(Value);
end;

procedure TSystemJsonArrayAdapter.Add(Value: Int64);
begin
  FArr.Add(Value);
end;

procedure TSystemJsonArrayAdapter.Add(Value: Double);
begin
  FArr.Add(Value);
end;

procedure TSystemJsonArrayAdapter.Add(Value: Boolean);
begin
  FArr.Add(Value);
end;

procedure TSystemJsonArrayAdapter.Add(Value: IDextJsonObject);
begin
  if Value is TSystemJsonObjectAdapter then
    FArr.Add((Value as TSystemJsonObjectAdapter).FObj.Clone as TJSONObject);
end;

procedure TSystemJsonArrayAdapter.Add(Value: IDextJsonArray);
begin
  if Value is TSystemJsonArrayAdapter then
    FArr.Add((Value as TSystemJsonArrayAdapter).FArr.Clone as TJSONArray);
end;

procedure TSystemJsonArrayAdapter.AddNull;
begin
  FArr.AddElement(TJSONNull.Create);
end;

{ TSystemJsonProvider }

function TSystemJsonProvider.CreateObject: IDextJsonObject;
begin
  Result := TSystemJsonObjectAdapter.Create(TJSONObject.Create, True);
end;

function TSystemJsonProvider.CreateArray: IDextJsonArray;
begin
  Result := TSystemJsonArrayAdapter.Create(TJSONArray.Create, True);
end;

function TSystemJsonProvider.Parse(const Json: string): IDextJsonNode;
var
  Val: TJSONValue;
begin
  Val := TJSONObject.ParseJSONValue(Json);
  if Val = nil then
    raise Exception.Create('Invalid JSON');

  if Val is TJSONObject then
    Result := TSystemJsonObjectAdapter.Create(TJSONObject(Val), True)
  else if Val is TJSONArray then
    Result := TSystemJsonArrayAdapter.Create(TJSONArray(Val), True)
  else
  begin
    Val.Free;
    raise Exception.Create('JSON root must be Object or Array');
  end;
end;

end.

