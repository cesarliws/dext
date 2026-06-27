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
{  Created: 2026-06-17                                                      }
{                                                                           }
{  Zero-allocation incremental HTTP/1.1 parser.                             }
{                                                                           }
{***************************************************************************}
unit Dext.Server.Iocp.HttpParser;

interface

uses
  System.Classes,
  System.SysUtils,
  Dext.Collections.Dict;

type
  /// <summary>
  ///   Represents a header segment parsed from the raw receive buffer.
  /// </summary>
  THeaderSegment = record
    KeyStart: Integer;
    KeyLen: Integer;
    ValueStart: Integer;
    ValueLen: Integer;
  end;

  THeaderSegments = TArray<THeaderSegment>;

  /// <summary>
  ///   Zero-allocation (on structural parsing) incremental HTTP/1.1 parser.
  /// </summary>
  TDextIocpHttpParser = record
  private
    class function FindByte(const ABuffer: TBytes; AStart, AEnd: Integer; AByte: Byte): Integer; static; inline;
    class function FindCRLF(const ABuffer: TBytes; AStart, AEnd: Integer): Integer; static; inline;
    class function GetMethodString(const ABuffer: TBytes; AStart, ALen: Integer): string; static; inline;
  public
    /// <summary>
    ///   Attempts to parse HTTP/1.1 request headers from a byte buffer.
    ///   Returns True if headers are complete and parsed successfully.
    ///   On success, returns the index where the body begins (ABodyOffset).
    /// </summary>
    class function TryParseRequest(
      const ABuffer: TBytes; 
      ALength: Integer;
      out AMethod: string;
      out APath: string;
      out AQuery: string;
      out AHeaderSegments: THeaderSegments;
      out ABodyOffset: Integer;
      out AContentLength: Int64
    ): Boolean; static;

    class function CompareBytesCI(const ABuffer: TBytes; AStart, ALen: Integer; const AStr: string): Boolean; static; inline;
  end;

implementation

{ TDextIocpHttpParser }

class function TDextIocpHttpParser.FindByte(const ABuffer: TBytes; AStart, AEnd: Integer; AByte: Byte): Integer;
var
  I: Integer;
begin
  for I := AStart to AEnd - 1 do
    if ABuffer[I] = AByte then
      Exit(I);
  Result := -1;
end;

class function TDextIocpHttpParser.FindCRLF(const ABuffer: TBytes; AStart, AEnd: Integer): Integer;
var
  I: Integer;
begin
  for I := AStart to AEnd - 2 do
    if (ABuffer[I] = 13) and (ABuffer[I+1] = 10) then
      Exit(I);
  Result := -1;
end;

class function TDextIocpHttpParser.CompareBytesCI(const ABuffer: TBytes; AStart, ALen: Integer; const AStr: string): Boolean;
var
  I: Integer;
  B1, B2: Byte;
begin
  if ALen <> Length(AStr) then Exit(False);
  for I := 0 to ALen - 1 do
  begin
    B1 := ABuffer[AStart + I];
    B2 := Ord(AStr[I + 1]);
    if (B1 >= 65) and (B1 <= 90) then B1 := B1 + 32;
    if (B2 >= 65) and (B2 <= 90) then B2 := B2 + 32;
    if B1 <> B2 then Exit(False);
  end;
  Result := True;
end;

class function TDextIocpHttpParser.GetMethodString(const ABuffer: TBytes; AStart, ALen: Integer): string;
begin
  case ALen of
    3:
      if (ABuffer[AStart] = 71) and (ABuffer[AStart+1] = 69) and (ABuffer[AStart+2] = 84) then
        Exit('GET')
      else if (ABuffer[AStart] = 80) and (ABuffer[AStart+1] = 85) and (ABuffer[AStart+2] = 84) then
        Exit('PUT');
    4:
      if (ABuffer[AStart] = 80) and (ABuffer[AStart+1] = 79) and (ABuffer[AStart+2] = 83) and (ABuffer[AStart+3] = 84) then
        Exit('POST')
      else if (ABuffer[AStart] = 72) and (ABuffer[AStart+1] = 69) and (ABuffer[AStart+2] = 65) and (ABuffer[AStart+3] = 68) then
        Exit('HEAD');
    5:
      if (ABuffer[AStart] = 80) and (ABuffer[AStart+1] = 65) and (ABuffer[AStart+2] = 84) and (ABuffer[AStart+3] = 67) and (ABuffer[AStart+4] = 72) then
        Exit('PATCH');
    6:
      if (ABuffer[AStart] = 68) and (ABuffer[AStart+1] = 69) and (ABuffer[AStart+2] = 76) and (ABuffer[AStart+3] = 69) and (ABuffer[AStart+4] = 84) and (ABuffer[AStart+5] = 69) then
        Exit('DELETE');
    7:
      if (ABuffer[AStart] = 79) and (ABuffer[AStart+1] = 80) and (ABuffer[AStart+2] = 84) and (ABuffer[AStart+3] = 73) and (ABuffer[AStart+4] = 79) and (ABuffer[AStart+5] = 78) and (ABuffer[AStart+6] = 83) then
        Exit('OPTIONS');
  end;
  Result := TEncoding.UTF8.GetString(ABuffer, AStart, ALen);
end;

class function TDextIocpHttpParser.TryParseRequest(
  const ABuffer: TBytes; 
  ALength: Integer;
  out AMethod: string;
  out APath: string;
  out AQuery: string;
  out AHeaderSegments: THeaderSegments;
  out ABodyOffset: Integer;
  out AContentLength: Int64
): Boolean;
var
  HeaderEnd: Integer;
  I: Integer;
  LineStart: Integer;
  LineEnd: Integer;
  Space1: Integer;
  Space2: Integer;
  UrlEnd: Integer;
  QueryStart: Integer;
  Colon: Integer;
  Seg: THeaderSegment;
  SegCount: Integer;
  PathStart, PathLen: Integer;
begin
  AMethod := '';
  APath := '';
  AQuery := '';
  ABodyOffset := -1;
  AContentLength := 0;
  SetLength(AHeaderSegments, 0);

  // 1. Locate the end of the headers (\r\n\r\n)
  HeaderEnd := -1;
  for I := 0 to ALength - 4 do
  begin
    if (ABuffer[I] = 13) and (ABuffer[I+1] = 10) and (ABuffer[I+2] = 13) and (ABuffer[I+3] = 10) then
    begin
      HeaderEnd := I;
      Break;
    end;
  end;

  if HeaderEnd = -1 then
    Exit(False); // Headers are incomplete

  // 2. Parse request line (first line)
  LineEnd := FindCRLF(ABuffer, 0, HeaderEnd);
  if LineEnd = -1 then Exit(False);

  Space1 := FindByte(ABuffer, 0, LineEnd, 32); // Space character
  if Space1 = -1 then Exit(False);

  Space2 := FindByte(ABuffer, Space1 + 1, LineEnd, 32);
  if Space2 = -1 then Exit(False);

  // Method (cached)
  AMethod := GetMethodString(ABuffer, 0, Space1);

  // URL / Path & Query
  UrlEnd := Space2;
  QueryStart := FindByte(ABuffer, Space1 + 1, Space2, 63); // '?' character
  
  PathStart := Space1 + 1;
  if QueryStart <> -1 then
    PathLen := QueryStart - PathStart
  else
    PathLen := Space2 - PathStart;

  // Path raiz otimizado
  if (PathLen = 1) and (ABuffer[PathStart] = 47) then
    APath := '/'
  else
    APath := TEncoding.UTF8.GetString(ABuffer, PathStart, PathLen);

  if QueryStart <> -1 then
    AQuery := TEncoding.UTF8.GetString(ABuffer, QueryStart, Space2 - QueryStart)
  else
    AQuery := '';

  SegCount := 0;
  SetLength(AHeaderSegments, 16);

  // 3. Parse headers line by line
  LineStart := LineEnd + 2;
  while LineStart < HeaderEnd do
  begin
    LineEnd := FindCRLF(ABuffer, LineStart, HeaderEnd);
    if LineEnd = -1 then LineEnd := HeaderEnd;

    if LineEnd > LineStart then
    begin
      Colon := FindByte(ABuffer, LineStart, LineEnd, 58); // ':' character
      if Colon <> -1 then
      begin
        Seg.KeyStart := LineStart;
        Seg.KeyLen := Colon - LineStart;
        Seg.ValueStart := Colon + 1;
        Seg.ValueLen := LineEnd - (Colon + 1);

        // Skip leading space of value
        while (Seg.ValueLen > 0) and (ABuffer[Seg.ValueStart] = 32) do
        begin
          Inc(Seg.ValueStart);
          Dec(Seg.ValueLen);
        end;

        if SegCount >= Length(AHeaderSegments) then
          SetLength(AHeaderSegments, SegCount + 8);

        AHeaderSegments[SegCount] := Seg;
        Inc(SegCount);

        if CompareBytesCI(ABuffer, Seg.KeyStart, Seg.KeyLen, 'content-length') then
        begin
          AContentLength := 0;
          for I := 0 to Seg.ValueLen - 1 do
          begin
            if (ABuffer[Seg.ValueStart + I] >= 48) and (ABuffer[Seg.ValueStart + I] <= 57) then
              AContentLength := AContentLength * 10 + (ABuffer[Seg.ValueStart + I] - 48);
          end;
        end;
      end;
    end;

    LineStart := LineEnd + 2;
  end;

  SetLength(AHeaderSegments, SegCount);
  ABodyOffset := HeaderEnd + 4;
  Result := True;
end;

end.
