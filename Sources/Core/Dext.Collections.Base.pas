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
{  Base interfaces and types for Dext.Collections.                          }
{                                                                           }
{***************************************************************************}
unit Dext.Collections.Base;

interface

type
  {$M+}
  IEnumerator<T> = interface(IInterface)
    function GetCurrent: T;
    function MoveNext: Boolean;
    property Current: T read GetCurrent;
  end;

  {$M+}
  IEnumerable<T> = interface(IInterface)
    function GetEnumerator: IEnumerator<T>;
  end;

  {$M+}
  ICollection = interface
    ['{A1B2C3D4-E5F6-4A5B-9C8D-0E1F2A3B4C5D}']
    function GetOwnsObjects: Boolean;
    procedure SetOwnsObjects(Value: Boolean);
    property OwnsObjects: Boolean read GetOwnsObjects write SetOwnsObjects;
  end;

  {$M+}
  IObjectList = interface
    ['{B989C717-9B05-46D9-B589-3F4A5E6B7C8D}']
    function GetCount: Integer;
    function GetItem(Index: Integer): TObject;
    procedure SetItem(Index: Integer; Value: TObject);
    procedure Add(Value: TObject);
    procedure Clear;
    procedure Delete(Index: Integer);
    procedure Insert(Index: Integer; Value: TObject);
    function IndexOf(Value: TObject): Integer;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TObject read GetItem write SetItem; default;
  end;

  /// <summary>
  ///   Single-pass flyweight sequence for SSR @foreach. Render Current before
  ///   the next MoveNext — the same instance may be reused (streaming ORM).
  /// </summary>
  {$M+}
  IStreamingSequence = interface
    ['{C4D8A2F1-6E3B-4A90-8D15-9B7E2C1F4A60}']
    function GetIsEmpty: Boolean;
    function MoveNext: Boolean;
    function GetCurrent: TObject;
    property IsEmpty: Boolean read GetIsEmpty;
    property Current: TObject read GetCurrent;
  end;

  {$M+}
  IDextBufferProvider = interface
    ['{F4A7CB6D-1393-4B9A-B0F6-764E8B0E85D4}']
    function GetBuffer: Pointer;
    function GetSize: NativeInt;
    function GetElementSize: NativeInt;
  end;

implementation

end.
