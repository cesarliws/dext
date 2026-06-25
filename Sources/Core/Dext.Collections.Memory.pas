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
{  Created: 2026-02-23                                                      }
{                                                                           }
{  Low-level memory management for Dext.Collections.                        }
{  Provides aligned allocation and safe managed-type operations on raw      }
{  memory buffers. This unit has NO generic types - everything operates     }
{  on Pointer + PTypeInfo + ElementSize.                                    }
{                                                                           }
{***************************************************************************}
unit Dext.Collections.Memory;

interface

uses
  System.SysUtils,
  System.TypInfo;

/// <summary>
///   Returns True if the given type requires compiler-managed lifecycle
///   (initialization, finalization, copy semantics). This includes strings,
///   interfaces, dynamic arrays, variants, and records containing any of those.
/// </summary>
function IsManagedType(ATypeInfo: PTypeInfo): Boolean;

/// <summary>
///   Initializes a contiguous block of raw memory for Count elements of the
///   given type. For managed types this calls System.InitializeArray; for
///   unmanaged types it simply zero-fills the memory.
/// </summary>
procedure RawInitialize(Dest: Pointer; Count: NativeInt;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo);

/// <summary>
///   Finalizes (releases) a contiguous block of raw memory for Count elements.
///   For managed types this calls System.FinalizeArray to release ref-counted
///   resources; for unmanaged types this is a no-op.
/// </summary>
procedure RawFinalize(Dest: Pointer; Count: NativeInt;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo);

/// <summary>
///   Copies Count elements from Source to Dest with correct managed type
///   semantics: for managed types uses System.CopyArray (addref); for
///   unmanaged types uses System.Move.
/// </summary>
procedure RawCopy(Dest, Source: Pointer; Count: NativeInt;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo); inline;

/// <summary>
///   Moves Count elements from Source to Dest, then zeros Source memory.
///   This effectively transfers ownership of managed resources without
///   addref/release overhead. Safe for overlapping regions if Dest < Source.
/// </summary>
procedure RawMove(Dest, Source: Pointer; Count: NativeInt;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo); inline;

/// <summary>
///   Copies a single element from Source to Dest. Handles managed types.
/// </summary>
procedure RawCopyElement(Dest, Source: Pointer;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo); inline;

/// <summary>
///   Finalizes a single element. For managed types releases ref-counted
///   resources; for unmanaged types this is a no-op.
/// </summary>
procedure RawFinalizeElement(Dest: Pointer;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo); inline;

implementation

function IsManagedType(ATypeInfo: PTypeInfo): Boolean;
begin
  if ATypeInfo = nil then
    Exit(False);

  case ATypeInfo.Kind of
    tkUString,
    tkLString,
    tkWString,
    tkInterface,
    tkDynArray,
    tkVariant:
      Result := True;

    tkRecord{$IF Declared(tkMRecord)}, tkMRecord{$IFEND}:
      Result := System.HasWeakRef(ATypeInfo) or
                (GetTypeData(ATypeInfo).ManagedFldCount > 0);
  else
    Result := False;
  end;
end;

procedure RawInitialize(Dest: Pointer; Count: NativeInt;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo);
begin
  if (Count <= 0) or (Dest = nil) then
    Exit;

  // Faster check: if ATypeInfo is nil, it's definitely not managed
  if (ATypeInfo <> nil) and IsManagedType(ATypeInfo) then
  begin
    FillChar(Dest^, Count * ElementSize, 0);
    {$IF CompilerVersion >= 35.0}  // Delphi 11+
    System.InitializeArray(Dest, ATypeInfo, Count);
    {$IFEND}
  end
  else
    FillChar(Dest^, Count * ElementSize, 0);
end;

procedure RawFinalize(Dest: Pointer; Count: NativeInt;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo);
begin
  if (Count <= 0) or (Dest = nil) or (ATypeInfo = nil) then
    Exit;

  if IsManagedType(ATypeInfo) then
    System.FinalizeArray(Dest, ATypeInfo, Count);
end;

procedure RawCopy(Dest, Source: Pointer; Count: NativeInt;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo);
var
  TotalSize: NativeInt;
begin
  if (Count <= 0) or (Dest = nil) or (Source = nil) or (Dest = Source) then
    Exit;

  TotalSize := Count * ElementSize;

  if (ATypeInfo <> nil) and IsManagedType(ATypeInfo) then
    System.CopyArray(Dest, Source, ATypeInfo, Count)
  else
  begin
    case TotalSize of
      1: PByte(Dest)^ := PByte(Source)^;
      2: PWord(Dest)^ := PWord(Source)^;
      4: PCardinal(Dest)^ := PCardinal(Source)^;
      8: PUInt64(Dest)^ := PUInt64(Source)^;
    else
      System.Move(Source^, Dest^, TotalSize);
    end;
  end;
end;

procedure RawMove(Dest, Source: Pointer; Count: NativeInt;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo);
var
  TotalSize: NativeInt;
begin
  if (Count <= 0) or (Dest = nil) or (Source = nil) or (Dest = Source) then
    Exit;

  TotalSize := Count * ElementSize;

  if (ATypeInfo <> nil) and IsManagedType(ATypeInfo) then
  begin
    System.FinalizeArray(Dest, ATypeInfo, Count);
    System.Move(Source^, Dest^, TotalSize);
    FillChar(Source^, TotalSize, 0);
  end
  else
    System.Move(Source^, Dest^, TotalSize);
end;

procedure RawCopyElement(Dest, Source: Pointer;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo);
begin
  if (ATypeInfo <> nil) and IsManagedType(ATypeInfo) then
    System.CopyArray(Dest, Source, ATypeInfo, 1)
  else
  begin
    case ElementSize of
      1: PByte(Dest)^ := PByte(Source)^;
      2: PWord(Dest)^ := PWord(Source)^;
      4: PCardinal(Dest)^ := PCardinal(Source)^;
      8: PUInt64(Dest)^ := PUInt64(Source)^;
    else
      System.Move(Source^, Dest^, ElementSize);
    end;
  end;
end;

procedure RawFinalizeElement(Dest: Pointer;
  ElementSize: NativeInt; ATypeInfo: PTypeInfo);
begin
  if IsManagedType(ATypeInfo) then
    System.FinalizeArray(Dest, ATypeInfo, 1);
end;

end.
