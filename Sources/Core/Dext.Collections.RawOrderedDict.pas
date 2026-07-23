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
{  Non-generic insertion-ordered hash map backend for Dext.Collections.     }
{                                                                           }
{  Composes the existing tested backends instead of re-implementing a       }
{  probing hash: a TRawDictionary maps Key -> insertion position (reusing   }
{  the same hash/equal plumbing as TRawDictionary), while two TRawList hold  }
{  keys and values in insertion order. Lookup and iteration are O(1); a      }
{  middle removal shifts the order lists and re-indexes the tail (O(n)),     }
{  matching the semantics of .NET's OrderedDictionary<TKey,TValue>.          }
{                                                                           }
{  This unit has NO generic types - everything operates on                  }
{  Pointer + PTypeInfo + ElementSize.                                       }
{                                                                           }
{***************************************************************************}
unit Dext.Collections.RawOrderedDict;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Collections.Memory,
  Dext.Collections.Raw,
  Dext.Collections.RawDict;

type
  /// <summary>
  ///   Non-generic hash map that preserves insertion order.
  ///   Backed by a TRawDictionary (Key -> position) plus two ordered
  ///   TRawList storages (keys and values). Keys are held both in the index
  ///   and in the order list, trading a little memory for full reuse of the
  ///   tested probing/comparer backend.
  /// </summary>
  TRawOrderedDictionary = class
  private
    FIndex: TRawDictionary;   // Key -> Integer (insertion position)
    FKeys: TRawList;          // keys, insertion order (dense)
    FValues: TRawList;        // values, insertion order (parallel to FKeys)
    FKeySize: Integer;
    FValueSize: Integer;
    function GetCount: Integer; inline;
    /// <summary>Rewrites the stored position of every key from APos to the end.</summary>
    procedure Reindex(APos: Integer);
  public
    constructor Create(AKeySize, AValueSize: Integer;
      AKeyTypeInfo, AValueTypeInfo: PTypeInfo;
      AHashFunc: TRawHashFunc; AEqualFunc: TRawEqualFunc;
      AInitialCapacity: Integer = 0);
    destructor Destroy; override;

    /// <summary>Appends a new pair. Raises if the key already exists.</summary>
    procedure AddRaw(Key, Value: Pointer);

    /// <summary>
    ///   Adds a new pair (appended) or, if the key exists, updates its value
    ///   in place without changing its position.
    /// </summary>
    procedure AddOrSetRaw(Key, Value: Pointer);

    /// <summary>Returns a pointer to the value storage for a key, or nil.</summary>
    function TryGetRaw(Key: Pointer; out ValuePtr: Pointer): Boolean;

    /// <summary>Returns True if the key exists.</summary>
    function ContainsKeyRaw(Key: Pointer): Boolean; inline;

    /// <summary>Returns the 0-based insertion position of a key, or -1.</summary>
    function IndexOfRaw(Key: Pointer): Integer;

    /// <summary>Removes a key. Returns True if it was present.</summary>
    function RemoveRaw(Key: Pointer): Boolean;

    /// <summary>Removes all entries.</summary>
    procedure Clear;

    /// <summary>Pointer to the key stored at insertion position APos.</summary>
    function GetKeyPtrAt(APos: Integer): Pointer; inline;
    /// <summary>Pointer to the value stored at insertion position APos.</summary>
    function GetValuePtrAt(APos: Integer): Pointer; inline;

    property Count: Integer read GetCount;
    property KeySize: Integer read FKeySize;
    property ValueSize: Integer read FValueSize;
  end;

implementation

{ TRawOrderedDictionary }

constructor TRawOrderedDictionary.Create(AKeySize, AValueSize: Integer;
  AKeyTypeInfo, AValueTypeInfo: PTypeInfo;
  AHashFunc: TRawHashFunc; AEqualFunc: TRawEqualFunc;
  AInitialCapacity: Integer);
begin
  inherited Create;
  FKeySize := AKeySize;
  FValueSize := AValueSize;

  // Index maps the key to its Integer insertion position. It reuses the exact
  // same hash/equal callbacks as the standard dictionary.
  FIndex := TRawDictionary.Create(
    AKeySize, SizeOf(Integer),
    AKeyTypeInfo, System.TypeInfo(Integer),
    AHashFunc, AEqualFunc,
    AInitialCapacity);

  FKeys := TRawList.Create(AKeySize, AKeyTypeInfo,
    Dext.Collections.Memory.IsManagedType(AKeyTypeInfo));
  FValues := TRawList.Create(AValueSize, AValueTypeInfo,
    Dext.Collections.Memory.IsManagedType(AValueTypeInfo));

  if AInitialCapacity > 0 then
  begin
    FKeys.Capacity := AInitialCapacity;
    FValues.Capacity := AInitialCapacity;
  end;
end;

destructor TRawOrderedDictionary.Destroy;
begin
  FIndex.Free;
  FKeys.Free;
  FValues.Free;
  inherited;
end;

function TRawOrderedDictionary.GetCount: Integer;
begin
  Result := FKeys.Count;
end;

procedure TRawOrderedDictionary.Reindex(APos: Integer);
var
  I: Integer;
  NewPos: Integer;
begin
  // After a removal at APos the keys previously at APos+1.. shifted down by
  // one slot; rewrite their stored position so the index stays consistent.
  for I := APos to FKeys.Count - 1 do
  begin
    NewPos := I;
    FIndex.AddOrSetRaw(FKeys.GetItemPtr(I), @NewPos);
  end;
end;

procedure TRawOrderedDictionary.AddRaw(Key, Value: Pointer);
var
  Pos: Integer;
begin
  if FIndex.ContainsKeyRaw(Key) then
    raise Exception.Create('An item with the same key has already been added.');

  Pos := FKeys.Count;
  FKeys.AddRaw(Key);
  FValues.AddRaw(Value);
  FIndex.AddRaw(Key, @Pos);
end;

procedure TRawOrderedDictionary.AddOrSetRaw(Key, Value: Pointer);
var
  ValuePtr: Pointer;
  Pos: Integer;
begin
  if FIndex.TryGetRaw(Key, ValuePtr) then
  begin
    // Existing key: update the value in place, keep the position.
    Pos := PInteger(ValuePtr)^;
    FValues.SetRawItem(Pos, Value);
  end
  else
  begin
    Pos := FKeys.Count;
    FKeys.AddRaw(Key);
    FValues.AddRaw(Value);
    FIndex.AddRaw(Key, @Pos);
  end;
end;

function TRawOrderedDictionary.TryGetRaw(Key: Pointer; out ValuePtr: Pointer): Boolean;
var
  IdxPtr: Pointer;
begin
  Result := FIndex.TryGetRaw(Key, IdxPtr);
  if Result then
    ValuePtr := FValues.GetItemPtr(PInteger(IdxPtr)^)
  else
    ValuePtr := nil;
end;

function TRawOrderedDictionary.ContainsKeyRaw(Key: Pointer): Boolean;
begin
  Result := FIndex.ContainsKeyRaw(Key);
end;

function TRawOrderedDictionary.IndexOfRaw(Key: Pointer): Integer;
var
  IdxPtr: Pointer;
begin
  if FIndex.TryGetRaw(Key, IdxPtr) then
    Result := PInteger(IdxPtr)^
  else
    Result := -1;
end;

function TRawOrderedDictionary.RemoveRaw(Key: Pointer): Boolean;
var
  IdxPtr: Pointer;
  Pos: Integer;
begin
  Result := FIndex.TryGetRaw(Key, IdxPtr);
  if not Result then
    Exit;

  Pos := PInteger(IdxPtr)^;
  FIndex.RemoveRaw(Key);
  FKeys.DeleteRaw(Pos);
  FValues.DeleteRaw(Pos);
  Reindex(Pos);
end;

procedure TRawOrderedDictionary.Clear;
begin
  FIndex.Clear;
  FKeys.Clear;
  FValues.Clear;
end;

function TRawOrderedDictionary.GetKeyPtrAt(APos: Integer): Pointer;
begin
  Result := FKeys.GetItemPtr(APos);
end;

function TRawOrderedDictionary.GetValuePtrAt(APos: Integer): Pointer;
begin
  Result := FValues.GetItemPtr(APos);
end;

end.
