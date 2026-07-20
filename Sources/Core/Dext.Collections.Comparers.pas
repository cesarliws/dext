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
{  Created: 2026-02-25                                                      }
{                                                                           }
{  Dext-native comparer interfaces and default implementations.             }
{  Replaces System.Generics.Defaults with zero RTL generics dependency.     }
{                                                                           }
{  Design Notes:                                                            }
{  - Uses GetTypeKind(T) compiler intrinsic for compile-time branch         }
{    elimination, ensuring zero overhead for known types.                   }
{  - BobJenkins hash for consistent, high-quality hash codes.               }
{  - Currency type is correctly handled as fixed-point (Int64-based),       }
{    not as Double.                                                         }
{                                                                           }
{***************************************************************************}
unit Dext.Collections.Comparers;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Hash;

type
  PIInterface = ^IInterface;
  TComparison<T> = reference to function(const Left, Right: T): Integer;

  /// <summary>
  ///   Generic comparer interface for ordering comparison.
  ///   Returns negative if Left &lt; Right, zero if equal, positive if Left &gt; Right.
  /// </summary>
  IComparer<T> = interface
    function Compare(const Left, Right: T): Integer;
  end;

  /// <summary>
  ///   Generic equality comparer interface.
  ///   Provides equality comparison and hash code generation.
  /// </summary>
  IEqualityComparer<T> = interface
    function Equals(const Left, Right: T): Boolean;
    function GetHashCode(const Value: T): Integer;
  end;

  /// <summary>
  ///   Default ordering comparer.
  ///   Uses GetTypeKind for compile-time specialization per type kind.
  /// </summary>
  TDefaultComparer<T> = class(TInterfacedObject, IComparer<T>)
  private
    type P_T = ^T;
  private
    FIsUnsigned: Boolean;
  public
    constructor Create;
    function Compare(const Left, Right: T): Integer;
  end;

  /// <summary>
  ///   Default equality comparer.
  ///   Uses GetTypeKind for compile-time specialization and BobJenkins hash.
  /// </summary>
  TDefaultEqualityComparer<T> = class(TInterfacedObject, IEqualityComparer<T>)
  private
    type P_T = ^T;
  public
    function Equals(const Left, Right: T): Boolean; reintroduce;
    function GetHashCode(const Value: T): Integer; reintroduce;
  end;

  /// <summary>
  ///   Factory for creating IComparer&lt;T&gt; instances.
  ///   Usage: TComparer&lt;string&gt;.Default
  /// </summary>
  TComparer<T> = class
  private
    class var FDefault: IComparer<T>;
  public
    class function Default: IComparer<T>; static;
    class function Construct(const AComparison: TComparison<T>): IComparer<T>; static;
  end;

  TComparisonComparer<T> = class(TInterfacedObject, IComparer<T>)
  private
    FComparison: TComparison<T>;
  public
    constructor Create(const AComparison: TComparison<T>);
    function Compare(const Left, Right: T): Integer;
  end;

  /// <summary>
  ///   Factory for creating IEqualityComparer&lt;T&gt; instances.
  ///   Usage: TEqualityComparer&lt;string&gt;.Default
  /// </summary>
  TEqualityComparer<T> = class
  private
    class var FDefault: IEqualityComparer<T>;
  public
    class function Default: IEqualityComparer<T>; static;
  end;

/// <summary>Byte-level ordering comparison for generic fallback</summary>
function BinaryCompare(Left, Right: Pointer; Size: Integer): Integer;

implementation

{ BinaryCompare }

function BinaryCompare(Left, Right: Pointer; Size: Integer): Integer;
var
  I: Integer;
  LB, RB: Byte;
begin
  for I := 0 to Size - 1 do
  begin
    LB := PByte(NativeUInt(Left) + NativeUInt(I))^;
    RB := PByte(NativeUInt(Right) + NativeUInt(I))^;
    if LB < RB then Exit(-1);
    if LB > RB then Exit(1);
  end;
  Result := 0;
end;

{ TDefaultComparer<T> }

constructor TDefaultComparer<T>.Create;
var
  TI: PTypeInfo;
  TD: PTypeData;
begin
  inherited Create;
  FIsUnsigned := False;
  TI := TypeInfo(T);
  if Assigned(TI) then
  begin
    TD := GetTypeData(TI);
    if TI^.Kind = tkInt64 then
      FIsUnsigned := TD^.MinInt64Value >= 0
    else if TI^.Kind in [tkInteger, tkChar, tkEnumeration, tkSet, tkWChar] then
      FIsUnsigned := TD^.OrdType in [otUByte, otUWord, otULong];
  end;
end;

function TDefaultComparer<T>.Compare(const Left, Right: T): Integer;
var
  LP, RP: Pointer;
begin
  LP := @Left;
  RP := @Right;
  case GetTypeKind(T) of
    tkUString:
      Result := CompareStr(PString(LP)^, PString(RP)^);

    tkLString:
    begin
      if PAnsiString(LP)^ < PAnsiString(RP)^ then Result := -1
      else if PAnsiString(LP)^ > PAnsiString(RP)^ then Result := 1
      else Result := 0;
    end;

    tkWString:
    begin
      if PWideString(LP)^ < PWideString(RP)^ then Result := -1
      else if PWideString(LP)^ > PWideString(RP)^ then Result := 1
      else Result := 0;
    end;

    tkInteger, tkChar, tkEnumeration, tkSet, tkWChar:
    begin
      case SizeOf(T) of
        1:
          if PByte(LP)^ < PByte(RP)^ then Result := -1
          else if PByte(LP)^ > PByte(RP)^ then Result := 1
          else Result := 0;
        2:
          if PWord(LP)^ < PWord(RP)^ then Result := -1
          else if PWord(LP)^ > PWord(RP)^ then Result := 1
          else Result := 0;
        4:
          if FIsUnsigned then
          begin
            if PCardinal(LP)^ < PCardinal(RP)^ then Result := -1
            else if PCardinal(LP)^ > PCardinal(RP)^ then Result := 1
            else Result := 0;
          end else begin
            if PInteger(LP)^ < PInteger(RP)^ then Result := -1
            else if PInteger(LP)^ > PInteger(RP)^ then Result := 1
            else Result := 0;
          end;
        8:
          if FIsUnsigned then
          begin
            if PUInt64(LP)^ < PUInt64(RP)^ then Result := -1
            else if PUInt64(LP)^ > PUInt64(RP)^ then Result := 1
            else Result := 0;
          end else begin
            if PInt64(LP)^ < PInt64(RP)^ then Result := -1
            else if PInt64(LP)^ > PInt64(RP)^ then Result := 1
            else Result := 0;
          end;
      else
        Result := BinaryCompare(LP, RP, SizeOf(T));
      end;
    end;

    tkFloat:
    begin
      case SizeOf(T) of
        4: // Single
          if PSingle(LP)^ < PSingle(RP)^ then Result := -1
          else if PSingle(LP)^ > PSingle(RP)^ then Result := 1
          else Result := 0;
        8: // Double or Currency
          if TypeInfo(T) = TypeInfo(Currency) then
          begin
            if PCurrency(LP)^ < PCurrency(RP)^ then Result := -1
            else if PCurrency(LP)^ > PCurrency(RP)^ then Result := 1
            else Result := 0;
          end
          else
          begin
            if PDouble(LP)^ < PDouble(RP)^ then Result := -1
            else if PDouble(LP)^ > PDouble(RP)^ then Result := 1
            else Result := 0;
          end;
        10: // Extended
          if PExtended(LP)^ < PExtended(RP)^ then Result := -1
          else if PExtended(LP)^ > PExtended(RP)^ then Result := 1
          else Result := 0;
      else
        Result := BinaryCompare(LP, RP, SizeOf(T));
      end;
    end;

    tkInt64:
    begin
      if FIsUnsigned then
      begin
        if PUInt64(LP)^ < PUInt64(RP)^ then Result := -1
        else if PUInt64(LP)^ > PUInt64(RP)^ then Result := 1
        else Result := 0;
      end else begin
        if PInt64(LP)^ < PInt64(RP)^ then Result := -1
        else if PInt64(LP)^ > PInt64(RP)^ then Result := 1
        else Result := 0;
      end;
    end;

    tkClass, tkInterface:
    begin
      if NativeUInt(PPointer(LP)^) < NativeUInt(PPointer(RP)^) then Result := -1
      else if NativeUInt(PPointer(LP)^) > NativeUInt(PPointer(RP)^) then Result := 1
      else Result := 0;
    end;
  else
    // Records, variants, and other types: byte-level comparison
    Result := BinaryCompare(LP, RP, SizeOf(T));
  end;
end;

{ TDefaultEqualityComparer<T> }

function TDefaultEqualityComparer<T>.Equals(const Left, Right: T): Boolean;
var
  LP, RP: Pointer;
begin
  LP := @Left;
  RP := @Right;
  case GetTypeKind(T) of
    tkUString:
      Result := PString(LP)^ = PString(RP)^;
    tkLString:
      Result := PAnsiString(LP)^ = PAnsiString(RP)^;
    tkWString:
      Result := PWideString(LP)^ = PWideString(RP)^;
    tkInteger, tkChar, tkEnumeration, tkSet, tkWChar:
      case SizeOf(T) of
        1: Result := PByte(LP)^ = PByte(RP)^;
        2: Result := PWord(LP)^ = PWord(RP)^;
        4: Result := PCardinal(LP)^ = PCardinal(RP)^;
        8: Result := PUInt64(LP)^ = PUInt64(RP)^;
      else
        Result := CompareMem(LP, RP, SizeOf(T));
      end;
    tkFloat:
      case SizeOf(T) of
        4: Result := PSingle(LP)^ = PSingle(RP)^;
        8:
          if TypeInfo(T) = TypeInfo(Currency) then
            Result := PCurrency(LP)^ = PCurrency(RP)^
          else
            Result := PDouble(LP)^ = PDouble(RP)^;
        10: Result := PExtended(LP)^ = PExtended(RP)^;
      else
        Result := CompareMem(LP, RP, SizeOf(T));
      end;
    tkInt64:
      Result := PInt64(LP)^ = PInt64(RP)^;
    tkClass, tkPointer:
      Result := PPointer(LP)^ = PPointer(RP)^;
    tkInterface:
      begin
        // Robust MI-safe interface identity check
        Result := PIInterface(LP)^ = PIInterface(RP)^;
      end;
    tkRecord:
      begin
        Result := CompareMem(LP, RP, SizeOf(T));
      end;
  else
    Result := CompareMem(LP, RP, SizeOf(T));
  end;
end;

function TDefaultEqualityComparer<T>.GetHashCode(const Value: T): Integer;
var
  VP: Pointer;
begin
  VP := @Value;
  case GetTypeKind(T) of
    tkUString:
      Result := THashBobJenkins.GetHashValue(PString(VP)^);
    tkLString:
      Result := THashBobJenkins.GetHashValue(string(PAnsiString(VP)^));
    tkWString:
      Result := THashBobJenkins.GetHashValue(string(PWideString(VP)^));
    tkClass, tkInterface, tkPointer:
      Result := THashBobJenkins.GetHashValue(
        PPointer(VP)^,
        SizeOf(Pointer)
      );
  else
    // Integer, Float, Int64, Enum, Set, Record, etc: hash raw bytes
    Result := THashBobJenkins.GetHashValue(Value, SizeOf(T));
  end;
end;

{ TComparer<T> }

class function TComparer<T>.Default: IComparer<T>;
begin
  if FDefault = nil then
    FDefault := TDefaultComparer<T>.Create;
  Result := FDefault;
end;

class function TComparer<T>.Construct(const AComparison: TComparison<T>): IComparer<T>;
begin
  Result := TComparisonComparer<T>.Create(AComparison);
end;

{ TComparisonComparer<T> }

constructor TComparisonComparer<T>.Create(const AComparison: TComparison<T>);
begin
  inherited Create;
  FComparison := AComparison;
end;

function TComparisonComparer<T>.Compare(const Left, Right: T): Integer;
begin
  Result := FComparison(Left, Right);
end;

{ TEqualityComparer<T> }

class function TEqualityComparer<T>.Default: IEqualityComparer<T>;
begin
  if FDefault = nil then
    FDefault := TDefaultEqualityComparer<T>.Create;
  Result := FDefault;
end;

end.


