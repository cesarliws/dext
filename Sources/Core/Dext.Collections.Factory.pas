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
{  Code Folding classifier for Dext.Collections.                            }
{  Categorizes types into implementation groups so that multiple generic    }
{  specializations can share a single TRawList backend instance.            }
{                                                                           }
{  Example: IList<Integer>, IList<Cardinal>, IList<Single> all map to       }
{  ecUnmanaged4 since they are all 4-byte unmanaged types.                  }
{                                                                           }
{***************************************************************************}
unit Dext.Collections.Factory;

interface

uses
  System.TypInfo;

type
  /// <summary>
  ///   Categories of implementation (Code Folding groups).
  ///   Types within the same category share the same TRawList behavior.
  /// </summary>
  TElementCategory = (
    ecUnmanaged1,       // 1 byte (Byte, ShortInt, Boolean, AnsiChar)
    ecUnmanaged2,       // 2 bytes (Word, SmallInt, WideChar)
    ecUnmanaged4,       // 4 bytes (Integer, Cardinal, Single, Pointer32)
    ecUnmanaged8,       // 8 bytes (Int64, UInt64, Double, Currency, Pointer64)
    ecUnmanagedN,       // N bytes (records/arrays without managed fields)
    ecString,           // string (UnicodeString, AnsiString, WideString)
    ecInterface,        // IInterface descendants (pointer-sized, ref-counted)
    ecVariant,          // Variant/OleVariant
    ecDynArray,         // TArray<T> / array of T
    ecObject,           // TObject descendants (pointer-sized, optional ownership)
    ecManagedRecord     // Records with managed fields (string, interface, etc.)
  );

  TElementCategoryHelper = record
  public
    /// <summary>
    ///   Classifies a type into its Code Folding category based on TypeInfo and size.
    /// </summary>
    class function Classify(ATypeInfo: PTypeInfo; ASize: Integer): TElementCategory; static;

    /// <summary>
    ///   Returns True if the category requires compiler-managed lifecycle
    ///   (initialization, finalization, copy semantics).
    /// </summary>
    class function IsManaged(Cat: TElementCategory): Boolean; static;

    /// <summary>
    ///   Returns True if elements in this category are pointer-sized references
    ///   (objects, interfaces). Useful for ownership management.
    /// </summary>
    class function IsReference(Cat: TElementCategory): Boolean; static;
  end;

implementation

uses
  Dext.Collections.Memory;

{ TElementCategoryHelper }

class function TElementCategoryHelper.Classify(ATypeInfo: PTypeInfo;
  ASize: Integer): TElementCategory;
begin
  if ATypeInfo = nil then
  begin
    // No RTTI - classify by size only (unmanaged)
    case ASize of
      1: Result := ecUnmanaged1;
      2: Result := ecUnmanaged2;
      4: Result := ecUnmanaged4;
      8: Result := ecUnmanaged8;
    else
      Result := ecUnmanagedN;
    end;
    Exit;
  end;

  case ATypeInfo.Kind of
    // Strings - all reference-counted, pointer-sized storage
    tkUString,
    tkLString,
    tkWString:
      Result := ecString;

    // Interfaces - pointer-sized, reference-counted
    tkInterface:
      Result := ecInterface;

    // Dynamic arrays - pointer-sized, reference-counted
    tkDynArray:
      Result := ecDynArray;

    // Variants - 16 bytes, managed
    tkVariant:
      Result := ecVariant;

    // Classes - pointer-sized, may own objects
    tkClass:
      Result := ecObject;

    // Records - check for managed fields
    tkRecord{$IF Declared(tkMRecord)}, tkMRecord{$IFEND}:
    begin
      if IsManagedType(ATypeInfo) then
        Result := ecManagedRecord
      else
      begin
        // Unmanaged record - classify by size
        case ASize of
          1: Result := ecUnmanaged1;
          2: Result := ecUnmanaged2;
          4: Result := ecUnmanaged4;
          8: Result := ecUnmanaged8;
        else
          Result := ecUnmanagedN;
        end;
      end;
    end;

    // Integer types
    tkInteger:
    begin
      case ASize of
        1: Result := ecUnmanaged1;
        2: Result := ecUnmanaged2;
        4: Result := ecUnmanaged4;
        8: Result := ecUnmanaged8;
      else
        Result := ecUnmanagedN;
      end;
    end;

    // Floating point
    tkFloat:
    begin
      case ASize of
        4: Result := ecUnmanaged4;  // Single
        8: Result := ecUnmanaged8;  // Double, Currency, TDateTime
       10: Result := ecUnmanagedN;  // Extended (rare)
      else
        Result := ecUnmanagedN;
      end;
    end;

    // Enumerations (includes Boolean)
    tkEnumeration:
    begin
      case ASize of
        1: Result := ecUnmanaged1;
        2: Result := ecUnmanaged2;
        4: Result := ecUnmanaged4;
      else
        Result := ecUnmanagedN;
      end;
    end;

    // Sets
    tkSet:
    begin
      case ASize of
        1: Result := ecUnmanaged1;
        2: Result := ecUnmanaged2;
        4: Result := ecUnmanaged4;
        8: Result := ecUnmanaged8;
      else
        Result := ecUnmanagedN;
      end;
    end;

    // Characters
    tkChar:
      Result := ecUnmanaged1;
    tkWChar:
      Result := ecUnmanaged2;

    // Int64
    tkInt64:
      Result := ecUnmanaged8;

    // Pointer
    tkPointer:
    begin
      {$IFDEF CPUX64}
      Result := ecUnmanaged8;
      {$ELSE}
      Result := ecUnmanaged4;
      {$ENDIF}
    end;

    // Class reference / method pointer - platform pointer size
    tkClassRef,
    tkProcedure:
    begin
      {$IFDEF CPUX64}
      Result := ecUnmanaged8;
      {$ELSE}
      Result := ecUnmanaged4;
      {$ENDIF}
    end;

    // Method pointer is 2 x Pointer (Code + Data)
    tkMethod:
    begin
      {$IFDEF CPUX64}
      Result := ecUnmanagedN; // 16 bytes
      {$ELSE}
      Result := ecUnmanaged8; // 8 bytes
      {$ENDIF}
    end;

    // Static arrays - always unmanaged N
    tkArray:
      Result := ecUnmanagedN;

  else
    // Unknown - fallback to size-based classification
    case ASize of
      1: Result := ecUnmanaged1;
      2: Result := ecUnmanaged2;
      4: Result := ecUnmanaged4;
      8: Result := ecUnmanaged8;
    else
      Result := ecUnmanagedN;
    end;
  end;
end;

class function TElementCategoryHelper.IsManaged(Cat: TElementCategory): Boolean;
begin
  Result := Cat in [ecString, ecInterface, ecVariant, ecDynArray, ecManagedRecord];
end;

class function TElementCategoryHelper.IsReference(Cat: TElementCategory): Boolean;
begin
  Result := Cat in [ecObject, ecInterface];
end;

end.
