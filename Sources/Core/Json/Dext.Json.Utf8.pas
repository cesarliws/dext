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
{  Created: 2025-12-19                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Json.Utf8;

interface

uses
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Core.Span,
  Dext.Json.Types;

type
  /// <summary>
  ///   Exception type for JSON parsing and processing errors.
  /// </summary>
  EJsonException = class(Exception);

  /// <summary>
  ///   Defines the various JSON token types encountered during parsing.
  /// </summary>
  TJsonTokenType = (
    None,
    StartObject,    // {
    EndObject,      // }
    StartArray,     // [
    EndArray,       // ]
    PropertyName,   // "key": ...
    StringValue,    // "value"
    Number,         // 123.45
    TrueValue,      // true
    FalseValue,     // false
    NullValue,      // null
    Comment         // // or /* ... */ (if supported later)
  );

  /// <summary>
  ///   High-performance, forward-only, zero-allocation JSON reader for UTF-8 text.
  ///   Operates directly on a TByteSpan (ReadOnlySpan of bytes), avoiding string allocations during parsing.
  /// </summary>
  TUtf8JsonReader = record
  private
    FData: TByteSpan;
    FPtr: PByte;
    FEnd: PByte;
    FStart: PByte;
    FCurrentToken: TJsonTokenType;
    FValueSpan: TByteSpan;
    FHasValue: Boolean;

    procedure SkipWhitespace;
    function ConsumeString: TByteSpan;
    function ConsumeNumber: TByteSpan;
    function ConsumeLiteral(const ALiteral: string): Boolean;
    procedure ThrowJsonError(const AMessage: string);
  public
    /// <summary>
    ///   Initializes the reader with the JSON data.
    /// </summary>
    constructor Create(const AData: TByteSpan);

    /// <summary>Reads the next token from the JSON source. Returns True if a token was read, False if end of data.</summary>
    function Read: Boolean;

    /// <summary>
    ///   Skips the children of the current token (e.g., skips an entire object or array).
    /// </summary>
    procedure Skip;

    /// <summary>Type of the current token (StartObject, PropertyName, String, etc.).</summary>
    property TokenType: TJsonTokenType read FCurrentToken;

    /// <summary>
    ///   Span of raw bytes representing the current token value.
    ///   For strings, returns the inner content (without quotes).
    /// </summary>
    property ValueSpan: TByteSpan read FValueSpan;

    // --- Typed Getters (Perform conversion on demand) ---

    /// <summary>
    ///   Gets the value as a Delphi string (UTF-16). Allocates memory.
    /// </summary>
    function GetString: string;

    function GetInt32: Integer;
    function GetInt64: Int64;
    function GetDouble: Double;
    function GetBoolean: Boolean;
    
    /// <summary>
    ///   Checks if the current PropertyName matches the specified string (case-sensitive by default).
    ///   Optimized to compare against bytes without converting key to string.
    /// </summary>
    function ValueSpanEquals(const AText: string): Boolean;
  end;

  /// <summary>
  ///   High-performance, forward-only JSON writer that records UTF-8 text directly to a Stream.
  ///   Minimizes memory usage by avoiding the creation of large intermediate string buffers.
  /// </summary>
  TUtf8JsonWriter = record
  private
    FStream: TStream;
    FIndented: Boolean;
    FSettings: TJsonSettings;
    FNeedComma: array[0..63] of Boolean; // Max depth of 64
    FDepth: Integer;
    procedure WriteRaw(const S: string); inline;
    procedure WriteRawByte(B: Byte); inline;
    procedure WriteIndent;
    procedure CheckComma;
  public
    constructor Create(AStream: TStream; AIndented: Boolean = False);
    
    property Settings: TJsonSettings read FSettings write FSettings;
    
    procedure WriteStartObject;
    procedure WriteEndObject;
    procedure WriteStartArray;
    procedure WriteEndArray;
    
    procedure WritePropertyName(const AName: string);
    procedure WriteString(const AValue: string);
    procedure WriteNumber(AValue: Int64); overload;
    procedure WriteNumber(AValue: Double); overload;
    procedure WriteBoolean(AValue: Boolean);
    procedure WriteNull;
    
    /// <summary>Writes a raw TValue. Handles basic types.</summary>
    procedure WriteValue(const AValue: TValue);
  end;

function EscapeJsonString(const S: string): string;
function UnescapeJsonString(const S: string): string;
function GetJsonVal(const AVal: TValue): string; overload;
function GetJsonVal(const AVal: TValue; const ASettings: TJsonSettings): string; overload;

implementation

uses
  System.DateUtils,
  Dext.Core.Reflection,
  Dext.Json;

function EscapeJsonString(const S: string): string;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    c := S[i];
    case c of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      '/': Result := Result + '\/';
      #8: Result := Result + '\b';
      #9: Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
    else
      if (Ord(c) < 32) then
        Result := Result + Format('\u%.4x', [Ord(c)])
      else
        Result := Result + c;
    end;
  end;
end;

function UnescapeJsonString(const S: string): string;
var
  i: Integer;
  c: Char;
  IsEscaped: Boolean;
begin
  if Pos('\', S) = 0 then
    Exit(S);

  Result := '';
  IsEscaped := False;
  i := 1;
  while i <= Length(S) do
  begin
    c := S[i];
    if IsEscaped then
    begin
      case c of
        '"': Result := Result + '"';
        '\': Result := Result + '\';
        '/': Result := Result + '/';
        'b': Result := Result + #8;
        't': Result := Result + #9;
        'n': Result := Result + #10;
        'f': Result := Result + #12;
        'r': Result := Result + #13;
        'u':
          begin
            if i + 4 <= Length(S) then
            begin
              Result := Result + Char(StrToInt('$' + Copy(S, i + 1, 4)));
              Inc(i, 4);
            end;
          end;
      end;
      IsEscaped := False;
    end
    else if c = '\' then
      IsEscaped := True
    else
      Result := Result + c;
    Inc(i);
  end;
end;

function GetJsonVal(const AVal: TValue; const ASettings: TJsonSettings): string;
var
  Unwrapped: TValue;
begin
   if AVal.IsEmpty then Exit('null');

   // Handle Smart Properties (Prop<T>, Nullable<T>, etc.)
   if TReflection.TryUnwrapProp(AVal, Unwrapped) then
   begin
     Result := GetJsonVal(Unwrapped, ASettings);
     Exit;
   end;

   // Try to use framework serializer for other complex types (objects/arrays/interfaces)
   if AVal.Kind in [tkRecord, tkMRecord, tkDynArray, tkArray, tkClass, tkInterface] then
   begin
     // For normal records/objects, delegate to Dext.Json
     Result := TDextJson.Serialize(AVal, ASettings);
     Exit;
   end;

   case AVal.Kind of
     tkInteger, tkInt64: Result := IntToStr(AVal.AsInt64);
     tkFloat:
     begin
       if AVal.TypeInfo = TypeInfo(TDateTime) then
         Result := '"' + DateToISO8601(AVal.AsType<TDateTime>) + '"'
       else
         Result := FloatToStr(AVal.AsExtended, TFormatSettings.Invariant);
     end;
     tkString, tkUString, tkWString, tkChar, tkWChar: Result := '"' + EscapeJsonString(AVal.AsString) + '"';
     tkEnumeration:
       if AVal.TypeInfo = TypeInfo(Boolean) then
       begin
         if AVal.AsBoolean then
           Result := 'true'
         else
           Result := 'false';
       end
       else
       begin
         if ASettings.EnumStyle = TEnumStyle.AsString then
           Result := '"' + GetEnumName(AVal.TypeInfo, AVal.AsOrdinal) + '"'
         else
           Result := IntToStr(AVal.AsOrdinal);
       end;
   else
     Result := '"' + EscapeJsonString(AVal.ToString) + '"';
   end;
end;

function GetJsonVal(const AVal: TValue): string;
begin
  Result := GetJsonVal(AVal, TDextJson.GetDefaultSettings);
end;

{ TUtf8JsonReader }

constructor TUtf8JsonReader.Create(const AData: TByteSpan);
begin
  FData := AData;
  FStart := AData.Data;
  FPtr := AData.Data;
  FEnd := AData.Data + AData.Length;
  FCurrentToken := TJsonTokenType.None;
  FValueSpan := TByteSpan.Create(nil, 0);
  FHasValue := False;
end;

procedure TUtf8JsonReader.ThrowJsonError(const AMessage: string);
begin
  raise EJsonException.CreateFmt(
    '%s at position %d',
    [AMessage, FPtr - FStart]
  );
end;

procedure TUtf8JsonReader.SkipWhitespace;
begin
  while FPtr < FEnd do
  begin
    if (FPtr^ = $20) or (FPtr^ = $09) or (FPtr^ = $0A) or (FPtr^ = $0D) then
      Inc(FPtr)
    else
      Break;
  end;
end;

function TUtf8JsonReader.Read: Boolean;
var
  B: Byte;
  StrSpan: TByteSpan;
begin
  if FPtr >= FEnd then
  begin
    FCurrentToken := TJsonTokenType.None;
    Exit(False);
  end;

  SkipWhitespace;

  if FPtr >= FEnd then
  begin
    FCurrentToken := TJsonTokenType.None;
    Exit(False);
  end;

  B := FPtr^;

  // Handle separators that might appear before a token
  if (B = Ord(',')) or (B = Ord(':')) then
  begin
    Inc(FPtr);
    SkipWhitespace;
    if FPtr >= FEnd then
      ThrowJsonError('Unexpected end of JSON after separator');
    B := FPtr^;
  end;

  case Chr(B) of
    '{':
      begin
        FCurrentToken := TJsonTokenType.StartObject;
        FValueSpan := TByteSpan.Create(FPtr, 1);
        Inc(FPtr);
      end;
    '}':
      begin
        FCurrentToken := TJsonTokenType.EndObject;
        FValueSpan := TByteSpan.Create(FPtr, 1);
        Inc(FPtr);
      end;
    '[':
      begin
        FCurrentToken := TJsonTokenType.StartArray;
        FValueSpan := TByteSpan.Create(FPtr, 1);
        Inc(FPtr);
      end;
    ']':
      begin
        FCurrentToken := TJsonTokenType.EndArray;
        FValueSpan := TByteSpan.Create(FPtr, 1);
        Inc(FPtr);
      end;
    '"':
      begin
        StrSpan := ConsumeString;

        SkipWhitespace;
        // Check for colon
        if (FPtr < FEnd) and (FPtr^ = Ord(':')) then
        begin
          FCurrentToken := TJsonTokenType.PropertyName;
        end
        else
        begin
          FCurrentToken := TJsonTokenType.StringValue;
        end;

        FValueSpan := StrSpan;
      end;
    '-', '0'..'9':
      begin
        FCurrentToken := TJsonTokenType.Number;
        FValueSpan := ConsumeNumber;
      end;
    't':
      begin
        if ConsumeLiteral('true') then
        begin
          FCurrentToken := TJsonTokenType.TrueValue;
          FValueSpan := TByteSpan.Create(FPtr - 4, 4);
        end
        else
          ThrowJsonError('Invalid token (expected true)');
      end;
    'f':
      begin
        if ConsumeLiteral('false') then
        begin
          FCurrentToken := TJsonTokenType.FalseValue;
          FValueSpan := TByteSpan.Create(FPtr - 5, 5);
        end
        else
           ThrowJsonError('Invalid token (expected false)');
      end;
    'n':
      begin
        if ConsumeLiteral('null') then
        begin
          FCurrentToken := TJsonTokenType.NullValue;
          FValueSpan := TByteSpan.Create(FPtr - 4, 4);
        end
        else
           ThrowJsonError('Invalid token (expected null)');
      end;
    else
      ThrowJsonError('Invalid character: ' + Char(B));
  end;

  Result := True;
end;

function TUtf8JsonReader.ConsumeString: TByteSpan;
var
  StartPos: PByte;
  IsEscaped: Boolean;
  B: Byte;
begin
  Inc(FPtr); // Skip opening quote
  StartPos := FPtr;
  IsEscaped := False;

  while FPtr < FEnd do
  begin
    B := FPtr^;

    if IsEscaped then
    begin
      IsEscaped := False;
      Inc(FPtr);
      Continue;
    end;

    if B = Ord('\') then
    begin
      IsEscaped := True;
      Inc(FPtr);
      Continue;
    end;

    if B = Ord('"') then
    begin
      Result := TByteSpan.Create(StartPos, FPtr - StartPos);
      Inc(FPtr); // Skip closing quote
      Exit;
    end;

    Inc(FPtr);
  end;

  ThrowJsonError('Unterminated string');
end;

function TUtf8JsonReader.ConsumeNumber: TByteSpan;
var
  StartPos: PByte;
  B: Byte;
begin
  StartPos := FPtr;
  while FPtr < FEnd do
  begin
    B := FPtr^;
    if (B >= Ord('0')) and (B <= Ord('9')) or
       (B = Ord('.')) or (B = Ord('-')) or (B = Ord('+')) or
       (B = Ord('e')) or (B = Ord('E')) then
      Inc(FPtr)
    else
      Break;
  end;
  Result := TByteSpan.Create(StartPos, FPtr - StartPos);
end;

function TUtf8JsonReader.ConsumeLiteral(const ALiteral: string): Boolean;
var
  SpanToCheck: TByteSpan;
begin
  if FPtr + ALiteral.Length > FEnd then
    Exit(False);

  SpanToCheck := TByteSpan.Create(FPtr, ALiteral.Length);
  if SpanToCheck.EqualsString(ALiteral) then
  begin
    Inc(FPtr, ALiteral.Length);
    Result := True;
  end
  else
    Result := False;
end;

procedure TUtf8JsonReader.Skip;
var
  Depth: Integer;
begin
  if (FCurrentToken = TJsonTokenType.StartObject) or (FCurrentToken = TJsonTokenType.StartArray) then
  begin
    Depth := 1;
    while (Depth > 0) and Read do
    begin
      case FCurrentToken of
        TJsonTokenType.StartObject, TJsonTokenType.StartArray:
          Inc(Depth);
        TJsonTokenType.EndObject, TJsonTokenType.EndArray:
          Dec(Depth);
      end;
    end;
  end;
end;

function TUtf8JsonReader.GetString: string;
begin
  // Handle JSON escapes (\n, \", \uXXXX, etc.)
  Result := UnescapeJsonString(FValueSpan.ToString);
end;

function TUtf8JsonReader.GetInt32: Integer;
begin
  // Use Val or StrToInt on string representation? 
  // Optimization: Parse bytes directly
  // For now, convert to string then Int to be safe
  Result := StrToIntDef(FValueSpan.ToString, 0); 
end;

function TUtf8JsonReader.GetInt64: Int64;
begin
  Result := StrToInt64Def(FValueSpan.ToString, 0);
end;

function TUtf8JsonReader.GetDouble: Double;
var
  S: string;
  V: Double;
begin
  S := FValueSpan.ToString;
  if TryStrToFloat(S, V, TFormatSettings.Invariant) then
    Result := V
  else
    Result := 0.0;
end;

function TUtf8JsonReader.GetBoolean: Boolean;
begin
  Result := (FCurrentToken = TJsonTokenType.TrueValue);
end;

function TUtf8JsonReader.ValueSpanEquals(const AText: string): Boolean;
begin
  Result := FValueSpan.EqualsString(AText);
end;

{ TUtf8JsonWriter }

constructor TUtf8JsonWriter.Create(AStream: TStream; AIndented: Boolean);
begin
  FStream := AStream;
  FIndented := AIndented;
  FSettings := TJsonSettings.Default;
  if AIndented then 
    FSettings.Formatting := TJsonFormatting.Indented;
  FDepth := 0;
  FillChar(FNeedComma, SizeOf(FNeedComma), 0);
end;

procedure TUtf8JsonWriter.CheckComma;
begin
  if (FDepth > 0) and FNeedComma[FDepth - 1] then
    WriteRawByte(Ord(','));
  
  if FDepth > 0 then
    FNeedComma[FDepth - 1] := True;
end;

procedure TUtf8JsonWriter.WriteIndent;
var
  i: Integer;
begin
  if not FIndented then Exit;
  WriteRawByte(10); // LF
  for i := 0 to FDepth - 1 do
    WriteRaw('  ');
end;

procedure TUtf8JsonWriter.WriteRaw(const S: string);
var
  B: TBytes;
begin
  B := TEncoding.UTF8.GetBytes(S);
  if Length(B) > 0 then
    FStream.WriteBuffer(B[0], Length(B));
end;

procedure TUtf8JsonWriter.WriteRawByte(B: Byte);
begin
  FStream.WriteBuffer(B, 1);
end;

procedure TUtf8JsonWriter.WriteStartObject;
begin
  CheckComma;
  WriteIndent;
  WriteRawByte(Ord('{'));
  Inc(FDepth);
  FNeedComma[FDepth - 1] := False;
end;

procedure TUtf8JsonWriter.WriteEndObject;
begin
  Dec(FDepth);
  WriteIndent;
  WriteRawByte(Ord('}'));
  if FDepth > 0 then FNeedComma[FDepth - 1] := True;
end;

procedure TUtf8JsonWriter.WriteStartArray;
begin
  CheckComma;
  WriteIndent;
  WriteRawByte(Ord('['));
  Inc(FDepth);
  FNeedComma[FDepth - 1] := False;
end;

procedure TUtf8JsonWriter.WriteEndArray;
begin
  Dec(FDepth);
  WriteIndent;
  WriteRawByte(Ord(']'));
  if FDepth > 0 then FNeedComma[FDepth - 1] := True;
end;

procedure TUtf8JsonWriter.WritePropertyName(const AName: string);
begin
  CheckComma;
  WriteIndent;
  WriteRaw('"' + EscapeJsonString(AName) + '":');
  FNeedComma[FDepth - 1] := False; // Property written, next is value (no comma)
end;

procedure TUtf8JsonWriter.WriteString(const AValue: string);
begin
  CheckComma;
  WriteRaw('"' + EscapeJsonString(AValue) + '"');
end;

procedure TUtf8JsonWriter.WriteNumber(AValue: Int64);
begin
  CheckComma;
  WriteRaw(IntToStr(AValue));
end;

procedure TUtf8JsonWriter.WriteNumber(AValue: Double);
begin
  CheckComma;
  WriteRaw(FloatToStr(AValue, TFormatSettings.Invariant));
end;

procedure TUtf8JsonWriter.WriteBoolean(AValue: Boolean);
begin
  CheckComma;
  if AValue then WriteRaw('true') else WriteRaw('false');
end;

procedure TUtf8JsonWriter.WriteNull;
begin
  CheckComma;
  WriteRaw('null');
end;

procedure TUtf8JsonWriter.WriteValue(const AValue: TValue);
var
  Unwrapped: TValue;
begin
  if AValue.IsEmpty then
  begin
    WriteNull;
    Exit;
  end;

  // Handle Smart Properties (Prop<T>, Nullable<T>, etc.)
  if TReflection.TryUnwrapProp(AValue, Unwrapped) then
  begin
    WriteValue(Unwrapped);
    Exit;
  end;

  case AValue.Kind of
    tkInteger, tkInt64: WriteNumber(AValue.AsInt64);
    tkFloat: 
      begin
        if AValue.TypeInfo = TypeInfo(TDateTime) then
          WriteString(DateToISO8601(AValue.AsType<TDateTime>))
        else
          WriteNumber(AValue.AsType<Double>);
      end;
    tkString, tkUString, tkWString, tkLString, tkChar, tkWChar:
      WriteString(AValue.AsString);
    tkEnumeration:
      if AValue.TypeInfo = TypeInfo(Boolean) then
        WriteBoolean(AValue.AsBoolean)
      else
      begin
        if FSettings.EnumStyle = TEnumStyle.AsString then
          WriteString(GetEnumName(AValue.TypeInfo, AValue.AsOrdinal))
        else
          WriteNumber(AValue.AsOrdinal);
      end;
    tkClass, tkInterface:
      begin
        CheckComma;
        WriteIndent;
        // Delegate to full framework serializer to handle attributes, mapping and complex types
        WriteRaw(TDextJson.Serialize(AValue, FSettings));
      end;
    tkRecord, tkMRecord:
      begin
        CheckComma;
        // For normal records that are not SmartProps, use the default serializer
        WriteRaw(TDextJson.Serialize(AValue));
        if FDepth > 0 then
          FNeedComma[FDepth - 1] := True;
      end;
  else
    WriteString(AValue.ToString);
  end;
end;

end.
