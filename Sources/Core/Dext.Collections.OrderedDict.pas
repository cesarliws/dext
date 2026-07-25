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
{  Author:  Stefano Monterisi (Dext Contributor)                            }
{  Created: 2026-07-21                                                       }
{                                                                           }
{  Insertion-ordered generic dictionary for Dext.Collections.               }
{  Thin generic frontend over the TRawOrderedDictionary backend, mirroring  }
{  the design of Dext.Collections.Dict.TDictionary<K,V>.                     }
{                                                                           }
{  Enumeration, Keys, Values and ToArray all follow insertion order.        }
{  Lookup, indexed add and iteration are O(1); a middle Remove is O(n).      }
{                                                                           }
{***************************************************************************}
unit Dext.Collections.OrderedDict;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Collections.Base,
  Dext.Collections.Comparers,
  Dext.Collections.Dict,
  Dext.Collections.Memory,
  Dext.Collections.Raw,
  Dext.Collections.RawDict,
  Dext.Collections.RawOrderedDict;

{$M+}
type
  /// <summary>
  ///   Generic interface for an insertion-ordered dictionary.
  ///   Behaves like IDictionary&lt;K,V&gt; but enumeration and the Keys/Values
  ///   projections always reflect the order in which keys were first added,
  ///   and elements can be reached by their 0-based position.
  /// </summary>
  IOrderedDictionary<K, V> = interface(IDictionary<K, V>)
    ['{C3A5E1B2-7D64-4F08-9A31-2E6B5C0D8F14}']
    /// <summary>Returns the key stored at the given insertion position.</summary>
    function GetKeyAt(Index: Integer): K;
    /// <summary>Returns the value stored at the given insertion position.</summary>
    function GetValueAt(Index: Integer): V;
    /// <summary>Returns the 0-based insertion position of a key, or -1 if absent.</summary>
    function IndexOf(const Key: K): Integer;
    /// <summary>Returns the key-value pair stored at a given position.</summary>
    function PairAt(Index: Integer): TPair<K, V>;
    /// <summary>The key stored at the given insertion position.</summary>
    property KeyAt[Index: Integer]: K read GetKeyAt;
    /// <summary>The value stored at the given insertion position.</summary>
    property ValueAt[Index: Integer]: V read GetValueAt;
  end;

  /// <summary>Record-based enumerator (dense insertion-order walk, no slot skipping).</summary>
  TOrderedDictionaryEnumerator<K, V> = record
  private
    FCore: TRawOrderedDictionary;
    FIndex: Integer;
    FCount: Integer;
  public
    constructor Create(ACore: TRawOrderedDictionary);
    function MoveNext: Boolean; inline;
    function GetCurrent: TPair<K, V>; inline;
    property Current: TPair<K, V> read GetCurrent;
  end;

  /// <summary>Class-based enumerator for interface compatibility.</summary>
  TOrderedDictEnumerator<K, V> = class(TInterfacedObject, IEnumerator<TPair<K, V>>)
  private
    FCore: TRawOrderedDictionary;
    FIndex: Integer;
  public
    constructor Create(ACore: TRawOrderedDictionary);
    function GetCurrent: TPair<K, V>;
    function MoveNext: Boolean;
    property Current: TPair<K, V> read GetCurrent;
  end;

  /// <summary>Base class avoiding Delphi explicit interface method mapping bug.</summary>
  TOrderedDictionaryBase<K, V> = class(TInterfacedObject, IEnumerable<TPair<K, V>>)
  public
    function GetInterfaceEnumerator: IEnumerator<TPair<K, V>>; virtual; abstract;
    function GetEnumerator: IEnumerator<TPair<K, V>>;
  end;

  /// <summary>
  ///   High-performance insertion-ordered dictionary.
  ///   Uses a TRawOrderedDictionary backend to keep generics bloat low and to
  ///   reuse the framework hashing/comparer plumbing.
  /// </summary>
  TOrderedDictionary<K, V> = class(TOrderedDictionaryBase<K, V>,
    IOrderedDictionary<K, V>, IDictionary<K, V>)
  private
    type
      P_K = ^K;
      P_V = ^V;
  private
    FCore: TRawOrderedDictionary;
    FOwnsValues: Boolean;
    function GetCount: Integer;
    function GetItem(const Key: K): V;
    procedure SetItem(const Key: K; const Value: V);
    function ValueIsClass: Boolean; inline;
    procedure FreeValueAt(Pos: Integer);
  public
    function GetInterfaceEnumerator: IEnumerator<TPair<K, V>>; override;

    /// <summary>Creates a default empty insertion-ordered dictionary.</summary>
    constructor Create; overload;
    /// <summary>Creates the dictionary with a pre-allocated initial capacity.</summary>
    constructor Create(ACapacity: Integer); overload;
    /// <summary>Creates the dictionary specifying whether it should own the values (classes only).</summary>
    constructor Create(AOwnsValues: Boolean; ACapacity: Integer = 0); overload;
    /// <summary>Creates the dictionary with case sensitivity and capacity options.</summary>
    constructor Create(AIgnoreCase: Boolean; AOwnsValues: Boolean; ACapacity: Integer); overload;
    /// <summary>Creates the dictionary with a custom equality comparer.</summary>
    constructor Create(const AComparer: IEqualityComparer<K>; ACapacity: Integer = 0); overload;
    destructor Destroy; override;

    /// <summary>Returns a record-based enumerator for high-performance for-in loops.</summary>
    function GetEnumerator: TOrderedDictionaryEnumerator<K, V>; reintroduce; inline;

    /// <summary>Adds a new key-value pair. Raises if the key already exists.</summary>
    procedure Add(const Key: K; const Value: V);
    /// <summary>Adds a new pair or updates the existing value in-place without changing key order.</summary>
    procedure AddOrSetValue(const Key: K; const Value: V);
    /// <summary>Attempts to retrieve the value associated with the key.</summary>
    function TryGetValue(const Key: K; out Value: V): Boolean;
    /// <summary>Returns True if the key exists in the dictionary.</summary>
    function ContainsKey(const Key: K): Boolean;
    /// <summary>Removes the key and its value. Returns True if removed.</summary>
    function Remove(const Key: K): Boolean;
    /// <summary>Removes and returns the value associated with Key without freeing object instances.</summary>
    function Extract(const Key: K): V;
    /// <summary>Removes all key-value pairs from the dictionary.</summary>
    procedure Clear;

    /// <summary>Returns an array of all keys in insertion order.</summary>
    function Keys: TArray<K>;
    /// <summary>Returns an array of all values in insertion order.</summary>
    function Values: TArray<V>;
    /// <summary>Returns an array of key-value pairs in insertion order.</summary>
    function ToArray: TArray<TPair<K, V>>;

    // Ordered access
    /// <summary>Returns the 0-based insertion position of a key, or -1 if absent.</summary>
    function IndexOf(const Key: K): Integer;
    /// <summary>Returns the key stored at the given insertion position.</summary>
    function GetKeyAt(Index: Integer): K;
    /// <summary>Returns the value stored at the given insertion position.</summary>
    function GetValueAt(Index: Integer): V;
    /// <summary>Returns the key-value pair stored at a given position.</summary>
    function PairAt(Index: Integer): TPair<K, V>;

    /// <summary>Number of elements present in the dictionary.</summary>
    property Count: Integer read GetCount;
    /// <summary>Direct access to values via key. Raises if the key does not exist on read.</summary>
    property Items[const Key: K]: V read GetItem write SetItem; default;
    /// <summary>The key stored at a given insertion position.</summary>
    property KeyAt[Index: Integer]: K read GetKeyAt;
    /// <summary>The value stored at a given insertion position.</summary>
    property ValueAt[Index: Integer]: V read GetValueAt;
    /// <summary>If True, associated objects are freed on Remove/Clear/Destroy/overwrite.</summary>
    property OwnsValues: Boolean read FOwnsValues write FOwnsValues;
  end;
{$M-}

implementation

{ TOrderedDictionaryEnumerator<K, V> }

constructor TOrderedDictionaryEnumerator<K, V>.Create(ACore: TRawOrderedDictionary);
begin
  FCore := ACore;
  FIndex := -1;
  FCount := ACore.Count;
end;

function TOrderedDictionaryEnumerator<K, V>.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < FCount;
end;

function TOrderedDictionaryEnumerator<K, V>.GetCurrent: TPair<K, V>;
begin
  RawCopyElement(@Result.Key, FCore.GetKeyPtrAt(FIndex), SizeOf(K), System.TypeInfo(K));
  RawCopyElement(@Result.Value, FCore.GetValuePtrAt(FIndex), SizeOf(V), System.TypeInfo(V));
end;

{ TOrderedDictEnumerator<K, V> }

constructor TOrderedDictEnumerator<K, V>.Create(ACore: TRawOrderedDictionary);
begin
  inherited Create;
  FCore := ACore;
  FIndex := -1;
end;

function TOrderedDictEnumerator<K, V>.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < FCore.Count;
end;

function TOrderedDictEnumerator<K, V>.GetCurrent: TPair<K, V>;
begin
  RawCopyElement(@Result.Key, FCore.GetKeyPtrAt(FIndex), SizeOf(K), System.TypeInfo(K));
  RawCopyElement(@Result.Value, FCore.GetValuePtrAt(FIndex), SizeOf(V), System.TypeInfo(V));
end;

{ TOrderedDictionaryBase<K, V> }

function TOrderedDictionaryBase<K, V>.GetEnumerator: IEnumerator<TPair<K, V>>;
begin
  Result := GetInterfaceEnumerator;
end;

{ TOrderedDictionary<K, V> }

constructor TOrderedDictionary<K, V>.Create;
begin
  Create(False, False, 0);
end;

constructor TOrderedDictionary<K, V>.Create(ACapacity: Integer);
begin
  Create(False, False, ACapacity);
end;

constructor TOrderedDictionary<K, V>.Create(AOwnsValues: Boolean; ACapacity: Integer);
begin
  Create(False, AOwnsValues, ACapacity);
end;

constructor TOrderedDictionary<K, V>.Create(AIgnoreCase: Boolean; AOwnsValues: Boolean;
  ACapacity: Integer);
var
  HF: TRawHashFunc;
  EF: TRawEqualFunc;
  Comp: IEqualityComparer<K>;
begin
  inherited Create;
  FOwnsValues := AOwnsValues;

  if AIgnoreCase and (PTypeInfo(System.TypeInfo(K))^.Kind in [tkUString, tkLString, tkWString]) then
  begin
    HF := StringRawHashIgnoreCase;
    EF := StringRawEqualIgnoreCase;
  end
  else
  begin
    Comp := TEqualityComparer<K>.Default;
    HF := function(Key: Pointer; KeySize: Integer): Cardinal
          begin
            Result := Cardinal(Comp.GetHashCode(P_K(Key)^));
          end;
    EF := function(A, B: Pointer; KeySize: Integer): Boolean
          begin
            Result := Comp.Equals(P_K(A)^, P_K(B)^);
          end;
  end;

  FCore := TRawOrderedDictionary.Create(
    SizeOf(K), SizeOf(V),
    System.TypeInfo(K), System.TypeInfo(V),
    HF, EF,
    ACapacity);
end;

constructor TOrderedDictionary<K, V>.Create(const AComparer: IEqualityComparer<K>;
  ACapacity: Integer);
var
  HF: TRawHashFunc;
  EF: TRawEqualFunc;
  Comp: IEqualityComparer<K>;
begin
  inherited Create;
  FOwnsValues := False;
  Comp := AComparer;
  if Comp = nil then
    Comp := TEqualityComparer<K>.Default;

  HF := function(Key: Pointer; KeySize: Integer): Cardinal
        begin
          Result := Cardinal(Comp.GetHashCode(P_K(Key)^));
        end;
  EF := function(A, B: Pointer; KeySize: Integer): Boolean
        begin
          Result := Comp.Equals(P_K(A)^, P_K(B)^);
        end;

  FCore := TRawOrderedDictionary.Create(
    SizeOf(K), SizeOf(V),
    System.TypeInfo(K), System.TypeInfo(V),
    HF, EF,
    ACapacity);
end;

destructor TOrderedDictionary<K, V>.Destroy;
var
  I: Integer;
begin
  if ValueIsClass then
    for I := 0 to FCore.Count - 1 do
      FreeValueAt(I);
  FCore.Free;
  inherited;
end;

function TOrderedDictionary<K, V>.ValueIsClass: Boolean;
begin
  Result := FOwnsValues and (PTypeInfo(System.TypeInfo(V))^.Kind = tkClass);
end;

procedure TOrderedDictionary<K, V>.FreeValueAt(Pos: Integer);
var
  VP: Pointer;
begin
  VP := FCore.GetValuePtrAt(Pos);
  if PPointer(VP)^ <> nil then
    TObject(PPointer(VP)^).Free;
end;

function TOrderedDictionary<K, V>.GetInterfaceEnumerator: IEnumerator<TPair<K, V>>;
begin
  Result := TOrderedDictEnumerator<K, V>.Create(FCore);
end;

function TOrderedDictionary<K, V>.GetEnumerator: TOrderedDictionaryEnumerator<K, V>;
begin
  Result := TOrderedDictionaryEnumerator<K, V>.Create(FCore);
end;

function TOrderedDictionary<K, V>.GetCount: Integer;
begin
  Result := FCore.Count;
end;

function TOrderedDictionary<K, V>.GetItem(const Key: K): V;
var
  VP: Pointer;
begin
  if not FCore.TryGetRaw(@Key, VP) then
    raise Exception.Create('Key not found in dictionary');
  RawCopyElement(@Result, VP, SizeOf(V), System.TypeInfo(V));
end;

procedure TOrderedDictionary<K, V>.SetItem(const Key: K; const Value: V);
begin
  AddOrSetValue(Key, Value);
end;

procedure TOrderedDictionary<K, V>.Add(const Key: K; const Value: V);
begin
  FCore.AddRaw(@Key, @Value);
end;

procedure TOrderedDictionary<K, V>.AddOrSetValue(const Key: K; const Value: V);
var
  Pos: Integer;
begin
  if ValueIsClass then
  begin
    Pos := FCore.IndexOfRaw(@Key);
    if Pos >= 0 then
      FreeValueAt(Pos);
  end;
  FCore.AddOrSetRaw(@Key, @Value);
end;

function TOrderedDictionary<K, V>.TryGetValue(const Key: K; out Value: V): Boolean;
var
  VP: Pointer;
begin
  Result := FCore.TryGetRaw(@Key, VP);
  if Result then
    RawCopyElement(@Value, VP, SizeOf(V), System.TypeInfo(V))
  else
    Value := Default(V);
end;

function TOrderedDictionary<K, V>.ContainsKey(const Key: K): Boolean;
begin
  Result := FCore.ContainsKeyRaw(@Key);
end;

function TOrderedDictionary<K, V>.Remove(const Key: K): Boolean;
var
  Pos: Integer;
begin
  if ValueIsClass then
  begin
    Pos := FCore.IndexOfRaw(@Key);
    if Pos >= 0 then
      FreeValueAt(Pos);
  end;
  Result := FCore.RemoveRaw(@Key);
end;

function TOrderedDictionary<K, V>.Extract(const Key: K): V;
var
  VP: Pointer;
begin
  if FCore.TryGetRaw(@Key, VP) then
  begin
    RawCopyElement(@Result, VP, SizeOf(V), System.TypeInfo(V));
    FCore.RemoveRaw(@Key);
  end
  else
    Result := Default(V);
end;

procedure TOrderedDictionary<K, V>.Clear;
var
  I: Integer;
begin
  if ValueIsClass then
    for I := 0 to FCore.Count - 1 do
      FreeValueAt(I);
  FCore.Clear;
end;

function TOrderedDictionary<K, V>.Keys: TArray<K>;
var
  I, N: Integer;
begin
  N := FCore.Count;
  SetLength(Result, N);
  for I := 0 to N - 1 do
    RawCopyElement(@Result[I], FCore.GetKeyPtrAt(I), SizeOf(K), System.TypeInfo(K));
end;

function TOrderedDictionary<K, V>.Values: TArray<V>;
var
  I, N: Integer;
begin
  N := FCore.Count;
  SetLength(Result, N);
  for I := 0 to N - 1 do
    RawCopyElement(@Result[I], FCore.GetValuePtrAt(I), SizeOf(V), System.TypeInfo(V));
end;

function TOrderedDictionary<K, V>.ToArray: TArray<TPair<K, V>>;
var
  I, N: Integer;
begin
  N := FCore.Count;
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    RawCopyElement(@Result[I].Key, FCore.GetKeyPtrAt(I), SizeOf(K), System.TypeInfo(K));
    RawCopyElement(@Result[I].Value, FCore.GetValuePtrAt(I), SizeOf(V), System.TypeInfo(V));
  end;
end;

function TOrderedDictionary<K, V>.IndexOf(const Key: K): Integer;
begin
  Result := FCore.IndexOfRaw(@Key);
end;

function TOrderedDictionary<K, V>.GetKeyAt(Index: Integer): K;
begin
  if (Index < 0) or (Index >= FCore.Count) then
    raise Exception.CreateFmt('Ordered dictionary index out of range: %d', [Index]);
  RawCopyElement(@Result, FCore.GetKeyPtrAt(Index), SizeOf(K), System.TypeInfo(K));
end;

function TOrderedDictionary<K, V>.GetValueAt(Index: Integer): V;
begin
  if (Index < 0) or (Index >= FCore.Count) then
    raise Exception.CreateFmt('Ordered dictionary index out of range: %d', [Index]);
  RawCopyElement(@Result, FCore.GetValuePtrAt(Index), SizeOf(V), System.TypeInfo(V));
end;

function TOrderedDictionary<K, V>.PairAt(Index: Integer): TPair<K, V>;
begin
  if (Index < 0) or (Index >= FCore.Count) then
    raise Exception.CreateFmt('Ordered dictionary index out of range: %d', [Index]);
  RawCopyElement(@Result.Key, FCore.GetKeyPtrAt(Index), SizeOf(K), System.TypeInfo(K));
  RawCopyElement(@Result.Value, FCore.GetValuePtrAt(Index), SizeOf(V), System.TypeInfo(V));
end;

end.
