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
unit Dext.Types.Nullable;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Variants,
  System.Generics.Defaults;

type
  /// <summary>
  ///   Generic Nullable type implementation.
  ///   Allows value types (Integer, Double, Boolean, etc.) to be null.
  /// </summary>
  Nullable<T> = record
  private
    FValue: T;
    FHasValue: Boolean;
    function GetValue: T;
    procedure SetValue(const Value: T);
  public
    constructor Create(const Value: T); overload;
    constructor Create(const Value: Variant); overload;
    
    procedure Clear;
    
    property Value: T read GetValue write SetValue;
    property HasValue: Boolean read FHasValue;
    
    function GetValueOrDefault: T; overload;
    function GetValueOrDefault(const ADefault: T): T; overload;
    
    class operator Implicit(const Value: T): Nullable<T>;
    class operator Implicit(const Value: Nullable<T>): T;
    class operator Implicit(const Value: Variant): Nullable<T>;
    class operator Implicit(const Value: Nullable<T>): Variant;
    
    class operator Equal(const Left, Right: Nullable<T>): Boolean;
    class operator NotEqual(const Left, Right: Nullable<T>): Boolean;
  end;

  TNullableHelper = record
  private
    FValueType: PTypeInfo;
    FHasValueOffset: NativeInt;
    FHasValueKind: TTypeKind;
  public
    constructor Create(TypeInfo: PTypeInfo);
    function GetValue(Instance: Pointer): TValue;
    function HasValue(Instance: Pointer): Boolean;
    property ValueType: PTypeInfo read FValueType;
  end;

  function IsNullable(TypeInfo: PTypeInfo): Boolean;
  function GetUnderlyingType(TypeInfo: PTypeInfo): PTypeInfo;

implementation

uses
  System.StrUtils;

function SkipShortString(P: Pointer): Pointer; inline;
begin
  Result := PByte(P) + PByte(P)^ + 1;
end;

function IsNullable(TypeInfo: PTypeInfo): Boolean;
const
  PrefixString = 'Nullable<';
begin
  Result := Assigned(TypeInfo) and (TypeInfo.Kind = tkRecord)
    and StartsText(PrefixString, string(TypeInfo.Name));
end;

function GetUnderlyingType(TypeInfo: PTypeInfo): PTypeInfo;
var
  Helper: TNullableHelper;
begin
  if IsNullable(TypeInfo) then
  begin
    Helper := TNullableHelper.Create(TypeInfo);
    Result := Helper.ValueType;
  end
  else
    Result := nil;
end;

{ TNullableHelper }

constructor TNullableHelper.Create(TypeInfo: PTypeInfo);
var
  P: PByte;
  Field: PRecordTypeField;
begin
  P := @TypeInfo.TypeData.ManagedFldCount;
  // skip TTypeData.ManagedFldCount and TTypeData.ManagedFields
  Inc(P, SizeOf(Integer) + SizeOf(TManagedField) * PInteger(P)^);
  // skip TTypeData.NumOps and TTypeData.RecOps
  Inc(P, SizeOf(Byte) + SizeOf(Pointer) * P^);
  // skip TTypeData.RecFldCnt
  Inc(P, SizeOf(Integer));
  
  // get TTypeData.RecFields[0] -> FValue
  Field := PRecordTypeField(P);
  FValueType := Field.Field.TypeRef^;
  
  // get TTypeData.RecFields[1] -> FHasValue
  // Skip Name of first field
  Field := PRecordTypeField(PByte(SkipShortString(@Field.Name)) + SizeOf(TAttrData));
  
  FHasValueOffset := Field.Field.FldOffset;
  FHasValueKind := Field.Field.TypeRef^.Kind;
end;

function TNullableHelper.GetValue(Instance: Pointer): TValue;
begin
  TValue.Make(Instance, FValueType, Result);
end;

function TNullableHelper.HasValue(Instance: Pointer): Boolean;
begin
  // FHasValue is Boolean, so it's 1 byte.
  Result := PBoolean(PByte(Instance) + FHasValueOffset)^;
end;

{ Nullable<T> }

constructor Nullable<T>.Create(const Value: T);
begin
  FValue := Value;
  FHasValue := True;
end;

constructor Nullable<T>.Create(const Value: Variant);
begin
  if VarIsNull(Value) or VarIsEmpty(Value) then
  begin
    FHasValue := False;
    FValue := Default(T);
  end
  else
  begin
    FHasValue := True;
    FValue := TValue.FromVariant(Value).AsType<T>;
  end;
end;

procedure Nullable<T>.Clear;
begin
  FHasValue := False;
  FValue := Default(T);
end;

function Nullable<T>.GetValue: T;
begin
  if not FHasValue then
    raise EInvalidOpException.Create('Nullable type has no value');
  Result := FValue;
end;

procedure Nullable<T>.SetValue(const Value: T);
begin
  FValue := Value;
  FHasValue := True;
end;

function Nullable<T>.GetValueOrDefault: T;
begin
  if FHasValue then
    Result := FValue
  else
    Result := Default(T);
end;

function Nullable<T>.GetValueOrDefault(const ADefault: T): T;
begin
  if FHasValue then
    Result := FValue
  else
    Result := ADefault;
end;

class operator Nullable<T>.Implicit(const Value: T): Nullable<T>;
begin
  Result.FValue := Value;
  Result.FHasValue := True;
end;

class operator Nullable<T>.Implicit(const Value: Nullable<T>): T;
begin
  Result := Value.Value;
end;

class operator Nullable<T>.Implicit(const Value: Variant): Nullable<T>;
begin
  Result := Nullable<T>.Create(Value);
end;

class operator Nullable<T>.Implicit(const Value: Nullable<T>): Variant;
begin
  if Value.HasValue then
    Result := TValue.From<T>(Value.Value).AsVariant
  else
    Result := Null;
end;

class operator Nullable<T>.Equal(const Left, Right: Nullable<T>): Boolean;
begin
  if Left.HasValue and Right.HasValue then
    Result := TEqualityComparer<T>.Default.Equals(Left.Value, Right.Value)
  else
    Result := Left.HasValue = Right.HasValue;
end;

class operator Nullable<T>.NotEqual(const Left, Right: Nullable<T>): Boolean;
begin
  Result := not (Left = Right);
end;

end.

