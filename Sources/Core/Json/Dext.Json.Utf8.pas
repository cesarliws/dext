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
  System.SysUtils,
  Dext.Core.Span;

type
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
  ///   A high-performance, forward-only, zero-allocation reader for UTF-8 encoded JSON text.
  ///   It reads directly from a TByteSpan (ReadOnlySpan<byte>).
  /// </summary>
  TUtf8JsonReader = record
  private
    FData: TByteSpan;
    FPosition: Integer;
    FCurrentToken: TJsonTokenType;
    FValueSpan: TByteSpan; // Points to the raw bytes of the current value/property name
    FHasValue: Boolean;    // True if current token has a value (String, Number, Bool, Null)

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

    /// <summary>
    ///   Reads the next token from the JSON source.
    ///   Returns True if a token was read, False if end of data.
    /// </summary>
    function Read: Boolean;

    /// <summary>
    ///   Skips the children of the current token (e.g., skips an entire object or array).
    /// </summary>
    procedure Skip;

    /// <summary>
    ///   Gets the type of the current token.
    /// </summary>
    property TokenType: TJsonTokenType read FCurrentToken;

    /// <summary>
    ///   Gets the raw byte span representing the current token's value.
    ///   For PropertyName and StringValue, this includes the quotes? No, let's strip them for usability.
    ///   Implementation decision: This returns the content *inside* quotes for strings.
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

implementation

{ TUtf8JsonReader }

constructor TUtf8JsonReader.Create(const AData: TByteSpan);
begin
  FData := AData;
  FPosition := 0;
  FCurrentToken := TJsonTokenType.None;
  FValueSpan := TByteSpan.Create(nil, 0);
  FHasValue := False;
end;

procedure TUtf8JsonReader.ThrowJsonError(const AMessage: string);
begin
  raise EJsonException.CreateFmt('%s at position %d', [AMessage, FPosition]);
end;

procedure TUtf8JsonReader.SkipWhitespace;
var
  B: Byte;
begin
  while FPosition < FData.Length do
  begin
    B := FData[FPosition];
    // Space (0x20), Tab (0x09), LF (0x0A), CR (0x0D)
    if (B = $20) or (B = $09) or (B = $0A) or (B = $0D) then
      Inc(FPosition)
    else
      Break;
  end;
end;

function TUtf8JsonReader.Read: Boolean;
var
  B: Byte;
begin
  if FPosition >= FData.Length then
  begin
    FCurrentToken := TJsonTokenType.None;
    Exit(False);
  end;

  // 1. Skip whitespace / separators
  SkipWhitespace;
  
  // Check EOF again after skip
  if FPosition >= FData.Length then
  begin
    FCurrentToken := TJsonTokenType.None;
    Exit(False);
  end;

  // 2. Determine token based on current char
  B := FData[FPosition];

  // Handle separators that might appear before a token
  if (B = Ord(',')) or (B = Ord(':')) then
  begin
    Inc(FPosition);
    SkipWhitespace;
    if FPosition >= FData.Length then
      ThrowJsonError('Unexpected end of JSON after separator');
    B := FData[FPosition];
  end;

  case Chr(B) of
    '{':
      begin
        FCurrentToken := TJsonTokenType.StartObject;
        FValueSpan := FData.Slice(FPosition, 1);
        Inc(FPosition);
      end;
    '}':
      begin
        FCurrentToken := TJsonTokenType.EndObject;
        FValueSpan := FData.Slice(FPosition, 1);
        Inc(FPosition);
      end;
    '[':
      begin
        FCurrentToken := TJsonTokenType.StartArray;
        FValueSpan := FData.Slice(FPosition, 1);
        Inc(FPosition);
      end;
    ']':
      begin
        FCurrentToken := TJsonTokenType.EndArray;
        FValueSpan := FData.Slice(FPosition, 1);
        Inc(FPosition);
      end;
    '"':
      begin
        // Could be PropertyName or StringValue
        // We need context to know for sure, OR we can infer based on what follows.
        // But a Reader typically just says "I found a String". 
        // In strictly valid JSON:
        // - Inside Object, expecting Key -> PropertyName
        // - After Key+Colon -> Value
        // Simple Readers usually rely on the caller knowing the structure or check the colon.
        // Let's implement a lookahead for colon to distinguish PropertyName.
        
        var StrSpan := ConsumeString;
        
        SkipWhitespace;
        // Check for colon
        if (FPosition < FData.Length) and (FData[FPosition] = Ord(':')) then
        begin
          FCurrentToken := TJsonTokenType.PropertyName;
          // Note: ConsumeString advanced FPosition past the closing quote
          // But our loop at the start of Read handles the colon in the *next* Read call?
          // No, usually "PropertyName" implies we are at the key.
          // If we are at PropertyName, the *next* token is the value.
          // So we should NOT consume the colon here, just peek it.
          // Wait, if we don't consume colon, next Read sees colon and loops.
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
          FValueSpan := FData.Slice(FPosition - 4, 4);
        end
        else
          ThrowJsonError('Invalid token (expected true)');
      end;
    'f':
      begin
        if ConsumeLiteral('false') then
        begin
          FCurrentToken := TJsonTokenType.FalseValue;
          FValueSpan := FData.Slice(FPosition - 5, 5);
        end
        else
           ThrowJsonError('Invalid token (expected false)');
      end;
    'n':
      begin
        if ConsumeLiteral('null') then
        begin
          FCurrentToken := TJsonTokenType.NullValue;
          FValueSpan := FData.Slice(FPosition - 4, 4);
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
  StartPos: Integer;
  IsEscaped: Boolean;
begin
  // Assume FData[FPosition] is '"'
  Inc(FPosition); // Skip opening quote
  StartPos := FPosition;
  IsEscaped := False;

  while FPosition < FData.Length do
  begin
    var B := FData[FPosition];
    
    if IsEscaped then
    begin
      IsEscaped := False;
      Inc(FPosition);
      Continue;
    end;

    if B = Ord('\') then
    begin
      IsEscaped := True;
      Inc(FPosition);
      Continue;
    end;

    if B = Ord('"') then
    begin
      // Closing quote found
      Result := FData.Slice(StartPos, FPosition - StartPos);
      Inc(FPosition); // Skip closing quote
      Exit;
    end;

    Inc(FPosition);
  end;

  ThrowJsonError('Unterminated string');
end;

function TUtf8JsonReader.ConsumeNumber: TByteSpan;
var
  StartPos: Integer;
begin
  StartPos := FPosition;
  // Simple validation: strictly allow only number chars -0..9.eE+
  while FPosition < FData.Length do
  begin
    var B := FData[FPosition];
    // Allow digits, dot, minus, plus, e, E
    if (B in [Ord('0')..Ord('9'), Ord('.'), Ord('-'), Ord('+'), Ord('e'), Ord('E')]) then
      Inc(FPosition)
    else
      Break;
  end;
  Result := FData.Slice(StartPos, FPosition - StartPos);
end;

function TUtf8JsonReader.ConsumeLiteral(const ALiteral: string): Boolean;
begin
  // Check if enough bytes remain
  if FPosition + ALiteral.Length > FData.Length then
    Exit(False);

  // We need to compare bytes. We assumes ALiteral is ASCII/UTF8 friendly (true/false/null always are)
  var SpanToCheck := FData.Slice(FPosition, ALiteral.Length);
  if SpanToCheck.EqualsString(ALiteral) then
  begin
    Inc(FPosition, ALiteral.Length);
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
  // If span has escapes (\n, \", \uXXXX), we need to unescape.
  // For v1, let's assume raw string first, implement unescape utility later or if needed.
  // Actually, standard JSON usually requires unescaping.
  // We can use a helper or TEncoding.
  
  // Basic UTF8 decoding (doesn't handle JSON escapes like \u0000)
  Result := FValueSpan.ToString;
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

end.
