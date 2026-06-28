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
{  Created: 2026-02-24                                                      }
{                                                                           }
{  Generic dictionary (hash map) for Dext.Collections.                      }
{  Thin generic frontend over TRawDictionary backend.                       }
{                                                                           }
{***************************************************************************}
unit Dext.Collections.Dict;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Collections.Base,
  Dext.Collections.Memory,
  Dext.Collections.Comparers,
  Dext.Collections.RawDict;

{$M+}
type
  /// <summary>Key-value pair record</summary>
  TPair<K, V> = record
  private
    type
      P_K = ^K;
      P_V = ^V;
  public
    Key: K;
    Value: V;
    constructor Create(const AKey: K; const AValue: V);
  end;

  /// <summary>
  ///   Interface for a specialized string-to-string dictionary.
  /// </summary>
  IStringDictionary = interface
    ['{6AFA9C74-3A4B-4E38-AC36-9DC417C2DD53}']
    function GetItem(const AKey: string): string;
    function TryGetValue(const AKey: string; out AValue: string): Boolean;
    function GetValue(const AKey: string; const ADefault: string = ''): string;
    function ContainsKey(const AKey: string): Boolean;
    function GetCount: Integer;
    procedure Add(const AKey, AValue: string);
    procedure SetItem(const AKey, AValue: string);
    procedure AddOrSetValue(const AKey, AValue: string);
    function Remove(const AKey: string): Boolean;
    procedure Clear;
    function ToArray: TArray<TPair<string, string>>;
    property Count: Integer read GetCount;
    property Items[const AKey: string]: string read GetItem write SetItem; default;
  end;

  /// <summary>Generic interface for dictionaries (Hash Maps).</summary>
  IDictionary<K, V> = interface(Dext.Collections.Base.IEnumerable<TPair<K, V>>)
    ['{A7E3F294-60B1-4C01-B8D5-4E5F3A2C1D70}']
    function GetCount: Integer;
    function GetItem(const Key: K): V;
    procedure SetItem(const Key: K; const Value: V);

    /// <summary>Adds a new key-value pair. Raises an exception if the key already exists.</summary>
    procedure Add(const Key: K; const Value: V);
    /// <summary>Adds or updates the value associated with a key.</summary>
    procedure AddOrSetValue(const Key: K; const Value: V);
    /// <summary>Attempts to get the value associated with a key without raising exceptions.</summary>
    function TryGetValue(const Key: K; out Value: V): Boolean;
    /// <summary>Checks if a key is present in the dictionary.</summary>
    function ContainsKey(const Key: K): Boolean;
    /// <summary>Removes a key and its value. Returns True if the key existed.</summary>
    function Remove(const Key: K): Boolean;
    /// <summary>Removes and returns the value associated with a key.</summary>
    function Extract(const Key: K): V;
    /// <summary>Removes all items from the dictionary.</summary>
    procedure Clear;

    /// <summary>Returns an array containing all keys.</summary>
    function Keys: TArray<K>;
    /// <summary>Returns an array containing all values.</summary>
    function Values: TArray<V>;
    /// <summary>Converts the dictionary into an array of TPair.</summary>
    function ToArray: TArray<TPair<K, V>>;

    property Count: Integer read GetCount;
    property Items[const Key: K]: V read GetItem write SetItem; default;
  end;

  /// <summary>Enumerator for TDictionary (Record-based for performance)</summary>
  TDictionaryEnumerator<K, V> = record
  private
    FCore: TRawDictionary;
    FIndex: Integer;
    FCapacity: Integer;
  public
    constructor Create(ACore: TRawDictionary);
    function MoveNext: Boolean; inline;
    function GetCurrent: TPair<K, V>; inline;
    property Current: TPair<K, V> read GetCurrent;
  end;

  /// <summary>Enumerator for TDictionary (Class-based for interface compatibility)</summary>
  TDictEnumerator<K, V> = class(TInterfacedObject, IEnumerator<TPair<K, V>>)
  private
    FCore: TRawDictionary;
    FIndex: Integer;
  public
    constructor Create(ACore: TRawDictionary);
    function GetCurrent: TPair<K, V>;
    function MoveNext: Boolean;
    property Current: TPair<K, V> read GetCurrent;
  end;

  /// <summary>Base class avoiding Delphi explicit interface method mapping bug</summary>
  TDictionaryBase<K, V> = class(TInterfacedObject, IEnumerable<TPair<K, V>>)
  public
    function GetInterfaceEnumerator: IEnumerator<TPair<K, V>>; virtual; abstract;
    function GetEnumerator: IEnumerator<TPair<K, V>>;
  end;

  /// <summary>
  ///   High-performance generic dictionary implementation.
  ///   Uses a TRawDictionary backend to reduce generics bloat and optimize memory usage.
  /// </summary>
  TDictionary<K, V> = class(TDictionaryBase<K, V>, IDictionary<K, V>)
  private
    type
      P_K = ^K;
      P_V = ^V;
  private
    FCore: TRawDictionary;
    FOwnsValues: Boolean;
    function GetCount: Integer;
    function GetItem(const Key: K): V;
    procedure SetItem(const Key: K; const Value: V);
  public
    function GetInterfaceEnumerator: IEnumerator<TPair<K, V>>; override;

    constructor Create; overload;
    /// <summary>Creates the dictionary with a pre-allocated initial capacity.</summary>
    constructor Create(ACapacity: Integer); overload;
    /// <summary>Creates the dictionary specifying whether it should own the values (for classes only).</summary>
    constructor Create(AOwnsValues: Boolean; ACapacity: Integer = 0); overload;
    /// <summary>Creates the dictionary with advanced options for case sensitivity and capacity.</summary>
    constructor Create(AIgnoreCase: Boolean; AOwnsValues: Boolean; ACapacity: Integer); overload;
    /// <summary>Creates the dictionary with a custom equality comparer.</summary>
    constructor Create(const AComparer: IEqualityComparer<K>; ACapacity: Integer = 0); overload;
    destructor Destroy; override;

    /// <summary>Returns a Record-based enumerator for high performance in for-in loops.</summary>
    function GetEnumerator: TDictionaryEnumerator<K, V>; reintroduce; inline;
    
    procedure Add(const Key: K; const Value: V);
    procedure AddOrSetValue(const Key: K; const Value: V);
    function TryGetValue(const Key: K; out Value: V): Boolean;
    function ContainsKey(const Key: K): Boolean;
    function Remove(const Key: K): Boolean;
    function Extract(const Key: K): V;
    procedure Clear;

    function Keys: TArray<K>;
    function Values: TArray<V>;
    function ToArray: TArray<TPair<K, V>>;

    /// <summary>Number of elements present in the dictionary.</summary>
    property Count: Integer read GetCount;
    /// <summary>Direct access to values via key. Raises an exception if the key does not exist on 'read'.</summary>
    property Items[const Key: K]: V read GetItem write SetItem; default;
    /// <summary>If True, the dictionary will automatically free associated objects (TObject) on Destroy/Clear.</summary>
    property OwnsValues: Boolean read FOwnsValues write FOwnsValues;
  end;

  /// <summary>
  ///   Concrete implementation of a string-to-string dictionary.
  /// </summary>
  TDextStringDictionary = class(TInterfacedObject, IStringDictionary)
  private
    FData: TDictionary<string, string>;
  public
    constructor Create(AIgnoreCase: Boolean = False);
    destructor Destroy; override;
    
    function GetItem(const AKey: string): string;
    function TryGetValue(const AKey: string; out AValue: string): Boolean;
    function GetValue(const AKey: string; const ADefault: string = ''): string;
    function ContainsKey(const AKey: string): Boolean;
    function GetCount: Integer;
    procedure Add(const AKey, AValue: string);
    procedure SetItem(const AKey, AValue: string);
    procedure AddOrSetValue(const AKey, AValue: string);
    function Remove(const AKey: string): Boolean;
    procedure Clear;
    function ToArray: TArray<TPair<string, string>>;
  end;

{$M-}
implementation

{ TDextStringDictionary }

constructor TDextStringDictionary.Create(AIgnoreCase: Boolean);
begin
  inherited Create;
  FData := TDictionary<string, string>.Create(AIgnoreCase, False, 0); 
end;

destructor TDextStringDictionary.Destroy;
begin
  FData.Free;
  inherited;
end;

function TDextStringDictionary.GetItem(const AKey: string): string;
begin
  Result := FData.Items[AKey];
end;

function TDextStringDictionary.TryGetValue(const AKey: string; out AValue: string): Boolean;
begin
  Result := FData.TryGetValue(AKey, AValue);
end;

function TDextStringDictionary.GetValue(const AKey: string; const ADefault: string): string;
begin
  if not FData.TryGetValue(AKey, Result) then
    Result := ADefault;
end;

function TDextStringDictionary.ContainsKey(const AKey: string): Boolean;
begin
  Result := FData.ContainsKey(AKey);
end;

function TDextStringDictionary.GetCount: Integer;
begin
  Result := FData.Count;
end;

procedure TDextStringDictionary.Add(const AKey, AValue: string);
begin
  FData.Add(AKey, AValue);
end;

procedure TDextStringDictionary.SetItem(const AKey, AValue: string);
begin
  FData.AddOrSetValue(AKey, AValue);
end;

procedure TDextStringDictionary.AddOrSetValue(const AKey, AValue: string);
begin
  FData.AddOrSetValue(AKey, AValue);
end;

function TDextStringDictionary.Remove(const AKey: string): Boolean;
begin
  Result := FData.Remove(AKey);
end;

procedure TDextStringDictionary.Clear;
begin
  FData.Clear;
end;

function TDextStringDictionary.ToArray: TArray<TPair<string, string>>;
begin
  Result := FData.ToArray;
end;

{ TPair<K, V> }

constructor TPair<K, V>.Create(const AKey: K; const AValue: V);
begin
  Key := AKey;
  Value := AValue;
end;

{ TDictionaryBase<K, V> }

function TDictionaryBase<K, V>.GetEnumerator: IEnumerator<TPair<K, V>>;
begin
  Result := GetInterfaceEnumerator;
end;

{ TDictionary<K, V> }

constructor TDictionary<K, V>.Create;
begin
  Create(False, 0);
end;

constructor TDictionary<K, V>.Create(ACapacity: Integer);
begin
  Create(False, ACapacity);
end;

constructor TDictionary<K, V>.Create(AOwnsValues: Boolean; ACapacity: Integer);
begin
  Create(False, AOwnsValues, ACapacity);
end;

constructor TDictionary<K, V>.Create(const AComparer: IEqualityComparer<K>; ACapacity: Integer);
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

  FCore := TRawDictionary.Create(
    SizeOf(K), SizeOf(V),
    System.TypeInfo(K), System.TypeInfo(V),
    HF, EF,
    ACapacity
  );
end;

constructor TDictionary<K, V>.Create(AIgnoreCase: Boolean; AOwnsValues: Boolean; ACapacity: Integer);
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

  FCore := TRawDictionary.Create(
    SizeOf(K), SizeOf(V),
    System.TypeInfo(K), System.TypeInfo(V),
    HF, EF,
    ACapacity
  );
end;

destructor TDictionary<K, V>.Destroy;
begin
  if FOwnsValues and (PTypeInfo(System.TypeInfo(V))^.Kind = tkClass) then
  begin
    FCore.ForEachRaw(
      function(KeyPtr, ValuePtr: Pointer): Boolean
      begin
        if PPointer(ValuePtr)^ <> nil then
          TObject(PPointer(ValuePtr)^).Free;
        Result := True;
      end);
  end;
  FCore.Free;
  inherited;
end;

function TDictionary<K, V>.GetEnumerator: TDictionaryEnumerator<K, V>;
begin
  Result := TDictionaryEnumerator<K, V>.Create(FCore);
end;

function TDictionary<K, V>.GetInterfaceEnumerator: IEnumerator<TPair<K, V>>;
begin
  Result := TDictEnumerator<K, V>.Create(FCore);
end;

function TDictionary<K, V>.GetCount: Integer;
begin
  Result := FCore.Count;
end;

function TDictionary<K, V>.GetItem(const Key: K): V;
var
  VP: Pointer;
  KP: Pointer;
begin
  KP := @Key;
  if not FCore.TryGetRaw(KP, VP) then
    raise Exception.Create('Key not found in dictionary');
  
  RawCopyElement(@Result, VP, SizeOf(V), System.TypeInfo(V));
end;

procedure TDictionary<K, V>.SetItem(const Key: K; const Value: V);
begin
  AddOrSetValue(Key, Value);
end;

procedure TDictionary<K, V>.Add(const Key: K; const Value: V);
var
  KP: Pointer;
begin
  KP := @Key;
  FCore.AddRaw(KP, @Value);
end;

procedure TDictionary<K, V>.AddOrSetValue(const Key: K; const Value: V);
var
  VP: Pointer;
  KP: Pointer;
begin
  KP := @Key;
  if FOwnsValues and (PTypeInfo(System.TypeInfo(V))^.Kind = tkClass) then
  begin
    if FCore.TryGetRaw(KP, VP) then
    begin
      if PPointer(VP)^ <> nil then
        TObject(PPointer(VP)^).Free;
    end;
  end;
  FCore.AddOrSetRaw(KP, @Value);
end;

function TDictionary<K, V>.TryGetValue(const Key: K; out Value: V): Boolean;
var
  VP: Pointer;
  KP: Pointer;
begin
  KP := @Key;
  Result := FCore.TryGetRaw(KP, VP);
  if Result then
    RawCopyElement(@Value, VP, SizeOf(V), System.TypeInfo(V))
  else
    Value := Default(V);
end;

function TDictionary<K, V>.ContainsKey(const Key: K): Boolean;
var
  KP: Pointer;
begin
  KP := @Key;
  Result := FCore.ContainsKeyRaw(KP);
end;

function TDictionary<K, V>.Remove(const Key: K): Boolean;
var
  KP: Pointer;
  VP: Pointer;
begin
  KP := @Key;
  if FOwnsValues and (PTypeInfo(System.TypeInfo(V))^.Kind = tkClass) then
  begin
    if FCore.TryGetRaw(KP, VP) then
    begin
      if PPointer(VP)^ <> nil then
        TObject(PPointer(VP)^).Free;
    end;
  end;
  Result := FCore.RemoveRaw(KP);
end;

function TDictionary<K, V>.Extract(const Key: K): V;
var
  VP: Pointer;
  KP: Pointer;
begin
  KP := @Key;
  if FCore.TryGetRaw(KP, VP) then
  begin
    RawCopyElement(@Result, VP, SizeOf(V), System.TypeInfo(V));
    FCore.RemoveRaw(KP);
  end
  else
    Result := Default(V);
end;

procedure TDictionary<K, V>.Clear;
begin
  if FOwnsValues and (PTypeInfo(System.TypeInfo(V))^.Kind = tkClass) then
  begin
    FCore.ForEachRaw(
      function(KeyPtr, ValuePtr: Pointer): Boolean
      begin
        if PPointer(ValuePtr)^ <> nil then
          TObject(PPointer(ValuePtr)^).Free;
        Result := True;
      end);
  end;
  FCore.Clear;
end;

function TDictionary<K, V>.Keys: TArray<K>;
var
  Arr: TArray<K>;
  Idx: Integer;
begin
  SetLength(Arr, FCore.Count);
  Idx := 0;
  FCore.ForEachRaw(
    function(KeyPtr, ValuePtr: Pointer): Boolean
    begin
      RawCopyElement(@Arr[Idx], KeyPtr, SizeOf(K), System.TypeInfo(K));
      Inc(Idx);
      Result := True;
    end);
  Result := Arr;
end;

function TDictionary<K, V>.Values: TArray<V>;
var
  Arr: TArray<V>;
  Idx: Integer;
begin
  SetLength(Arr, FCore.Count);
  Idx := 0;
  FCore.ForEachRaw(
    function(KeyPtr, ValuePtr: Pointer): Boolean
    begin
      RawCopyElement(@Arr[Idx], ValuePtr, SizeOf(V), System.TypeInfo(V));
      Inc(Idx);
      Result := True;
    end);
  Result := Arr;
end;

function TDictionary<K, V>.ToArray: TArray<TPair<K, V>>;
var
  Arr: TArray<TPair<K, V>>;
  Idx: Integer;
begin
  SetLength(Arr, FCore.Count);
  Idx := 0;
  FCore.ForEachRaw(
    function(KeyPtr, ValuePtr: Pointer): Boolean
    begin
      RawCopyElement(@Arr[Idx].Key, KeyPtr, SizeOf(K), System.TypeInfo(K));
      RawCopyElement(@Arr[Idx].Value, ValuePtr, SizeOf(V), System.TypeInfo(V));
      Inc(Idx);
      Result := True;
    end);
  Result := Arr;
end;

{ TDictEnumerator<K, V> }

constructor TDictEnumerator<K, V>.Create(ACore: TRawDictionary);
begin
  inherited Create;
  FCore := ACore;
  FIndex := -1;
end;

function TDictEnumerator<K, V>.GetCurrent: TPair<K, V>;
begin
  RawCopyElement(@Result.Key, FCore.GetKeyPtrAtIndex(FIndex), SizeOf(K), System.TypeInfo(K));
  RawCopyElement(@Result.Value, FCore.GetValuePtrAtIndex(FIndex), SizeOf(V), System.TypeInfo(V));
end;

function TDictEnumerator<K, V>.MoveNext: Boolean;
begin
  Result := False;
  while FIndex < FCore.Capacity - 1 do
  begin
    Inc(FIndex);
    if FCore.IsSlotOccupied(FIndex) then
      Exit(True);
  end;
end;

{ TDictionaryEnumerator<K, V> }

constructor TDictionaryEnumerator<K, V>.Create(ACore: TRawDictionary);
begin
  FCore := ACore;
  FIndex := -1;
  FCapacity := ACore.Capacity;
end;

function TDictionaryEnumerator<K, V>.GetCurrent: TPair<K, V>;
begin
  RawCopyElement(@Result.Key, FCore.GetKeyPtrAtIndex(FIndex), SizeOf(K), System.TypeInfo(K));
  RawCopyElement(@Result.Value, FCore.GetValuePtrAtIndex(FIndex), SizeOf(V), System.TypeInfo(V));
end;

function TDictionaryEnumerator<K, V>.MoveNext: Boolean;
begin
  Result := False;
  while FIndex < FCapacity - 1 do
  begin
    Inc(FIndex);
    if FCore.IsSlotOccupied(FIndex) then
      Exit(True);
  end;
end;

end.
