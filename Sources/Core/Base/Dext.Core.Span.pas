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
{  Created: 2025-12-18                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Core.Span;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  /// <summary>
  ///   A Span is a lightweight, zero-allocation reference to a contiguous region of memory.
  /// </summary>
  TSpan<T> = record
  private
    FPtr: Pointer;
    FLength: Integer;
    function GetItem(AIndex: Integer): T;
    procedure SetItem(AIndex: Integer; const Value: T);
    function GetLength: Boolean;
  public
    constructor Create(APtr: Pointer; ALength: Integer); overload;
    constructor Create(var AValue: T); overload;
    
    /// <summary>Returns a new span that is a slice of the current one.</summary>
    function Slice(AStart: Integer): TSpan<T>; overload;
    function Slice(AStart, ALength: Integer): TSpan<T>; overload;
    
    /// <summary>Copies the contents of the span to a new array.</summary>
    function ToArray: TArray<T>;
    
    /// <summary>Clears the memory referenced by the span.</summary>
    procedure Clear;
    
    property Ptr: Pointer read FPtr;
    property Length: Integer read FLength;
    property Items[Index: Integer]: T read GetItem write SetItem; default;
    property IsEmpty: Boolean read GetLength; // Added helper
  public
    class function Empty: TSpan<T>; static;
    class function From(var AArray: TArray<T>): TSpan<T>; static;
  end;

  /// <summary>
  ///   Specialization of TSpan for Bytes, optimized for network and JSON processing.
  /// </summary>
  TByteSpan = record
  private
    FData: PByte;
    FLength: Integer;
    function GetItem(AIndex: Integer): Byte; inline;
    procedure SetItem(AIndex: Integer; const Value: Byte); inline;
  public
    constructor Create(APtr: Pointer; ALength: Integer);
    
    function Slice(AStart: Integer): TByteSpan; overload;
    function Slice(AStart, ALength: Integer): TByteSpan; overload;
    
    /// <summary>Efficiently compares two spans byte by byte.</summary>
    function Equals(const AOther: TByteSpan): Boolean;
    
    /// <summary>Compares with a string as UTF-8 without allocation.</summary>
    function EqualsString(const AValue: string): Boolean;

    /// <summary>Finds the index of a byte.</summary>
    function IndexOf(AValue: Byte; AStartIndex: Integer = 0): Integer;

    /// <summary>Returns the span as a UTF-8 string (requires allocation).</summary>
    function ToString: string;
    
    /// <summary>Returns the span as a raw TBytes.</summary>
    function ToBytes: TBytes;

    property Data: PByte read FData;
    property Length: Integer read FLength;
    property Items[Index: Integer]: Byte read GetItem write SetItem; default;

    class function FromString(const AValue: string): TByteSpan; static; // Warning: Static reference to string memory
    class function FromBytes(const ABytes: TBytes): TByteSpan; static;
  end;

implementation

{ TSpan<T> }

constructor TSpan<T>.Create(APtr: Pointer; ALength: Integer);
begin
  FPtr := APtr;
  FLength := ALength;
end;

constructor TSpan<T>.Create(var AValue: T);
begin
  FPtr := @AValue;
  FLength := 1;
end;

class function TSpan<T>.Empty: TSpan<T>;
begin
  Result.FPtr := nil;
  Result.FLength := 0;
end;

class function TSpan<T>.From(var AArray: TArray<T>): TSpan<T>;
begin
  if System.Length(AArray) = 0 then
    Exit(Empty);
  Result.FPtr := @AArray[0];
  Result.FLength := System.Length(AArray);
end;

function TSpan<T>.GetItem(AIndex: Integer): T;
begin
  if (AIndex < 0) or (AIndex >= FLength) then
    raise ERangeError.Create('Span index out of range');
  Move(PByte(FPtr)[AIndex * SizeOf(T)], Result, SizeOf(T));
end;

function TSpan<T>.GetLength: Boolean;
begin
  Result := FLength = 0;
end;

procedure TSpan<T>.SetItem(AIndex: Integer; const Value: T);
begin
  if (AIndex < 0) or (AIndex >= FLength) then
    raise ERangeError.Create('Span index out of range');
  Move(Value, PByte(FPtr)[AIndex * SizeOf(T)], SizeOf(T));
end;

function TSpan<T>.Slice(AStart: Integer): TSpan<T>;
begin
  Result := Slice(AStart, FLength - AStart);
end;

function TSpan<T>.Slice(AStart, ALength: Integer): TSpan<T>;
begin
  if (AStart < 0) or (AStart + ALength > FLength) then
    raise ERangeError.Create('Span slice out of range');
  Result.FPtr := @PByte(FPtr)[AStart * SizeOf(T)];
  Result.FLength := ALength;
end;

function TSpan<T>.ToArray: TArray<T>;
var
  i: Integer;
begin
  System.SetLength(Result, FLength);
  for i := 0 to FLength - 1 do
    Result[i] := GetItem(i);
end;

procedure TSpan<T>.Clear;
begin
  if (FPtr <> nil) and (FLength > 0) then
    FillChar(FPtr^, FLength * SizeOf(T), 0);
end;

{ TByteSpan }

constructor TByteSpan.Create(APtr: Pointer; ALength: Integer);
begin
  FData := PByte(APtr);
  FLength := ALength;
end;

function TByteSpan.Equals(const AOther: TByteSpan): Boolean;
begin
  if FLength <> AOther.FLength then
    Exit(False);
  if FData = AOther.FData then
    Exit(True);
  Result := CompareMem(FData, AOther.FData, FLength);
end;

function TByteSpan.EqualsString(const AValue: string): Boolean;
var
  U8: TBytes;
begin
  U8 := TEncoding.UTF8.GetBytes(AValue);
  if FLength <> System.Length(U8) then
    Exit(False);
  Result := CompareMem(FData, @U8[0], FLength);
end;

class function TByteSpan.FromBytes(const ABytes: TBytes): TByteSpan;
begin
  if System.Length(ABytes) = 0 then
  begin
    Result.FData := nil;
    Result.FLength := 0;
  end
  else
  begin
    Result.FData := @ABytes[0];
    Result.FLength := System.Length(ABytes);
  end;
end;

class function TByteSpan.FromString(const AValue: string): TByteSpan;
begin
  // DANGER: Only use if AValue lifetime is guaranteed
  Result.FData := PByte(PChar(AValue));
  Result.FLength := System.Length(AValue) * SizeOf(Char); 
end;

function TByteSpan.GetItem(AIndex: Integer): Byte;
begin
  Result := FData[AIndex];
end;

function TByteSpan.IndexOf(AValue: Byte; AStartIndex: Integer): Integer;
var
  i: Integer;
begin
  for i := AStartIndex to FLength - 1 do
    if FData[i] = AValue then
      Exit(i);
  Result := -1;
end;

procedure TByteSpan.SetItem(AIndex: Integer; const Value: Byte);
begin
  FData[AIndex] := Value;
end;

function TByteSpan.Slice(AStart: Integer): TByteSpan;
begin
  Result := Slice(AStart, FLength - AStart);
end;

function TByteSpan.Slice(AStart, ALength: Integer): TByteSpan;
begin
  if (AStart < 0) or (AStart + ALength > FLength) then
    raise ERangeError.Create('ByteSpan slice out of range');
  Result.FData := @FData[AStart];
  Result.FLength := ALength;
end;

function TByteSpan.ToBytes: TBytes;
begin
  System.SetLength(Result, FLength);
  if FLength > 0 then
    Move(FData^, Result[0], FLength);
end;

function TByteSpan.ToString: string;
begin
  if FLength = 0 then
    Exit('');
  Result := TEncoding.UTF8.GetString(ToBytes);
end;

end.
