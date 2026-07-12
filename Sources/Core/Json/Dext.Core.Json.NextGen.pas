{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
unit Dext.Core.Json.NextGen;

{$POINTERMATH ON}
{$SCOPEDENUMS ON}

interface

uses
  System.Character,
  System.Classes,
  System.SysUtils,
  Dext.Collections.Simd,
  Dext.Core.Span,
  Dext.Json.Types;

type
  EJsonException = class(Exception)
  end;

  IJSONBufferOwner = interface
    ['{E3C2A1B0-9F8E-7D6C-5B4A-3C2B1A0F9E8D}']
  end;

  TJSONBufferOwner = class(TInterfacedObject, IJSONBufferOwner)
  private
    FBytes: TBytes;
  public
    constructor Create(const ABytes: TBytes);
  end;

  TNextGenJsonObject = class;
  TNextGenJsonArray = class;

  TJsonKey = record
    Span: TByteSpan;
    StrValue: string;
    function ToString: string; inline;
    function EqualsString(const AText: string): Boolean; inline;
  end;

  /// <summary>
  ///   Representação leve e Zero-Allocation de um valor JSON.
  /// </summary>
  TNextGenJsonValue = record
  private
    FType: TDextJsonNodeType;
    FValueSpan: TByteSpan;
    FStrValue: string;
    FStringDecoded: Boolean;
    FNodeRef: IDextJsonNode;
  public
    procedure Init(AType: TDextJsonNodeType; const ASpan: TByteSpan);
    property NodeType: TDextJsonNodeType read FType;
    property ValueSpan: TByteSpan read FValueSpan;
    property NodeRef: IDextJsonNode read FNodeRef;

    // We make NodeRef directly accessible by other classes inside the unit
    // to bypass the read-only property restriction.
    // However, FNodeRef is already in the private section of the record,
    // but inside the same unit Delphi allows direct field access!
    function AsString: string;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsDouble: Double;
    function AsBoolean: Boolean;
    function IsNull: Boolean;
  end;

  TNextGenJsonPair = record
    Key: TJsonKey;
    Value: TNextGenJsonValue;
  end;

  /// <summary>
  ///   Tabela de lookup de 256 bytes para validação léxica rápida.
  /// </summary>
  TJsonLookupTable = record
  public
    class var Structural: array[0..255] of Boolean;
    class var Whitespace: array[0..255] of Boolean;
    class constructor Create;
  end;

  /// <summary>
  ///   Parser JSON NextGen focado em Zero-Allocation e Spans.
  /// </summary>
  TNextGenJsonParser = record
  private
    FData: TByteSpan;
    FStart: PByte;
    FPtr: PByte;
    FEnd: PByte;
    procedure ScanString(var APtr: PByte); inline;
    class function ParseNumber(const ASpan: TByteSpan): Double; static;
    class function ParseInt64(const ASpan: TByteSpan): Int64; static;
    function ParseValue: TNextGenJsonValue;
    function ParseObject: IDextJsonObject;
    function ParseArray: IDextJsonArray;
  public
    class function ScanStructural_SSE42(
      Ptr: PByte;
      Length: Integer
    ): Integer; static;

    class function Parse(
      const AData: TByteSpan;
      const AKeepAlive: IInterface = nil
    ): IDextJsonNode; static;
  end;

  /// <summary>
  ///   Objeto JSON baseado em Spans.
  /// </summary>
  TNextGenJsonObject = class(TInterfacedObject, IDextJsonNode, IDextJsonObject)
  private
    FPairs: TArray<TNextGenJsonPair>;
    FCount: Integer;
    FHashTable: TArray<Integer>;
    FHashChain: TArray<Integer>;
    FHashBuilt: Boolean;
    FKeepAlive: IInterface;
    procedure BuildHash;
    function FindKey(const Name: string): Integer;
    procedure AddOrReplacePair(const AKey: string; const AValue: TNextGenJsonValue);
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddPair(const AKey: TByteSpan; const AValue: TNextGenJsonValue); overload;
    procedure AddPair(const AKey: string; const AValue: TNextGenJsonValue); overload;

    // IDextJsonNode
    function GetNodeType: TDextJsonNodeType;
    function AsString: string;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsDouble: Double;
    function AsBoolean: Boolean;
    function ToJson(Indented: Boolean = False): string;
    function IsNull: Boolean;

    // IDextJsonObject
    function Contains(const Name: string): Boolean;
    function GetNode(const Name: string): IDextJsonNode;
    function GetString(const Name: string): string;
    function GetInteger(const Name: string): Integer;
    function GetInt64(const Name: string): Int64;
    function GetDouble(const Name: string): Double;
    function GetBoolean(const Name: string): Boolean;
    function GetObject(const Name: string): IDextJsonObject;
    function GetArray(const Name: string): IDextJsonArray;
    function GetCount: Integer;
    function GetName(Index: Integer): string;

    procedure SetString(const Name, Value: string);
    procedure SetInteger(const Name: string; Value: Integer);
    procedure SetInt64(const Name: string; Value: Int64);
    procedure SetDouble(const Name: string; Value: Double);
    procedure SetBoolean(const Name: string; Value: Boolean);
    procedure SetObject(const Name: string; Value: IDextJsonObject);
    procedure SetArray(const Name: string; Value: IDextJsonArray);
    procedure SetNode(const Name: string; Value: IDextJsonNode);
    procedure SetNull(const Name: string);
  end;

  /// <summary>
  ///   Array JSON baseado em Spans.
  /// </summary>
  TNextGenJsonArray = class(TInterfacedObject, IDextJsonNode, IDextJsonArray)
  private
    FValues: TArray<TNextGenJsonValue>;
    FCount: Integer;
    FKeepAlive: IInterface;
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddValue(const AValue: TNextGenJsonValue);

    // IDextJsonNode
    function GetNodeType: TDextJsonNodeType;
    function AsString: string;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsDouble: Double;
    function AsBoolean: Boolean;
    function ToJson(Indented: Boolean = False): string;
    function IsNull: Boolean;

    // IDextJsonArray
    function GetCount: NativeInt;
    function GetNode(Index: Integer): IDextJsonNode;
    function GetString(Index: Integer): string;
    function GetInteger(Index: Integer): Integer;
    function GetInt64(Index: Integer): Int64;
    function GetDouble(Index: Integer): Double;
    function GetBoolean(Index: Integer): Boolean;
    function GetObject(Index: Integer): IDextJsonObject;
    function GetArray(Index: Integer): IDextJsonArray;

    procedure Add(const Value: string); overload;
    procedure Add(Value: Integer); overload;
    procedure Add(Value: Int64); overload;
    procedure Add(Value: Double); overload;
    procedure Add(Value: Boolean); overload;
    procedure Add(Value: IDextJsonObject); overload;
    procedure Add(Value: IDextJsonArray); overload;
    procedure AddNull;
  end;

  /// <summary>
  ///   Node adaptador para valores primitivos de folha.
  /// </summary>
  TNextGenJsonPrimitive = class(TInterfacedObject, IDextJsonNode)
  private
    FValue: TNextGenJsonValue;
  public
    FKeepAlive: IInterface;
    constructor Create(const AValue: TNextGenJsonValue);
    function GetNodeType: TDextJsonNodeType;
    function AsString: string;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsDouble: Double;
    function AsBoolean: Boolean;
    function ToJson(Indented: Boolean = False): string;
    function IsNull: Boolean;
  end;

  /// <summary>
  ///   Pool de Objetos para reciclagem rápida.
  /// </summary>
  TNextGenJsonPool = class
  private
    class var FObjectPool: array[0..1023] of TNextGenJsonObject;
    class var FObjectCount: Integer;
    class var FArrayPool: array[0..1023] of TNextGenJsonArray;
    class var FArrayCount: Integer;
    class constructor Create;
    class destructor Destroy;
  public
    class function RentObject: TNextGenJsonObject; static;
    class procedure ReturnObject(AnObj: TNextGenJsonObject); static;
    class function RentArray: TNextGenJsonArray; static;
    class procedure ReturnArray(AnArr: TNextGenJsonArray); static;
    class procedure ClearPool; static;
  end;

  /// <summary>
  ///   Record de escrita direta em UTF-8 para JSON de alta performance.
  /// </summary>
  TNextGenJsonWriter = record
  private
    FBuffer: TBytes;
    FLength: Integer;
    FNeedComma: Boolean;
    procedure EnsureCapacity(ANeeded: Integer); inline;
    procedure WriteRawByte(AByte: Byte); inline;
    procedure WriteRawBytes(const ABytes: TBytes); overload; inline;
    procedure WriteRawBytes(APtr: Pointer; ALength: Integer); overload; inline;
    procedure WriteEscapedString(const AValue: string);
    procedure WriteCommaIfNeeded; inline;
  public
    procedure Init(InitialCapacity: Integer = 65536);
    procedure Clear;
    procedure StartObject;
    procedure EndObject;
    procedure StartArray;
    procedure EndArray;
    procedure WritePropertyName(const AName: string); overload;
    procedure WritePropertyName(const AKey: TByteSpan); overload;
    procedure WriteStringValue(const AValue: string); overload;
    procedure WriteStringValue(const AValue: TByteSpan); overload;
    procedure WriteNumber(AValue: Int64); overload;
    procedure WriteNumber(AValue: Double); overload;
    procedure WriteBoolean(AValue: Boolean);
    procedure WriteNull;
    procedure WriteRawValue(const AValue: TByteSpan);
    function ToBytes: TBytes;
    // ... rest unchanged
    function ToString: string;
    procedure SaveToFile(const AFileName: string);
    property Buffer: TBytes read FBuffer;
    property Length: Integer read FLength;
  end;

  /// <summary>
  ///   Provedor padrão de JSON NextGen.
  /// </summary>
  TNextGenJsonProvider = class(TInterfacedObject, IDextJsonProvider)
  public
    function CreateObject: IDextJsonObject;
    function CreateArray: IDextJsonArray;
    function Parse(const Json: string): IDextJsonNode;
  end;

implementation

var
  GWhitespace: array[0..255] of Byte;
  GStructural: array[0..255] of Byte;

{ TJsonKey }

function TJsonKey.ToString: string;
begin
  if StrValue <> '' then
    Result := StrValue
  else
    Result := Span.ToString;
end;

function TJsonKey.EqualsString(const AText: string): Boolean;
begin
  if StrValue <> '' then
    Result := StrValue = AText
  else
    Result := Span.EqualsString(AText);
end;

{ TNextGenJsonValue }

procedure TNextGenJsonValue.Init(
  AType: TDextJsonNodeType;
  const ASpan: TByteSpan
);
begin
  FType := AType;
  FValueSpan := ASpan;
  FStrValue := '';
  FStringDecoded := False;
  FNodeRef := nil;
end;

function TNextGenJsonValue.AsString: string;
var
  Raw: string;
  Builder: TStringBuilder;
  I: Integer;
  Start: Integer;
  Code: Integer;
  Hex: Integer;
  C: Char;
begin
  if FType = TDextJsonNodeType.jntNull then Exit('');
  if FStringDecoded then Exit(FStrValue);
  Raw := FValueSpan.ToString;
  if Pos('\', Raw) = 0 then
  begin
    FStrValue := Raw;
    FStringDecoded := True;
    Exit(FStrValue);
  end;
  Builder := TStringBuilder.Create(Length(Raw));
  try
    I := 1; Start := 1;
    while I <= Length(Raw) do
    begin
      if Raw[I] <> '\' then begin Inc(I); Continue; end;
      if I > Start then Builder.Append(Copy(Raw, Start, I - Start));
      Inc(I);
      if I > Length(Raw) then raise EJsonException.Create('Unterminated string escape');
      C := Raw[I];
      case C of
        '"', '\', '/': Builder.Append(C);
        'b': Builder.Append(#8); 'f': Builder.Append(#12); 'n': Builder.Append(#10);
        'r': Builder.Append(#13); 't': Builder.Append(#9);
        'u': begin
          if I + 4 > Length(Raw) then raise EJsonException.Create('Invalid unicode escape sequence');
          Code := 0;
          for Hex := 1 to 4 do begin
            C := Raw[I + Hex];
            if CharInSet(C, ['0'..'9']) then
              Code := (Code shl 4) + Ord(C) - Ord('0')
            else if CharInSet(C, ['a'..'f']) then
              Code := (Code shl 4) + Ord(C) - Ord('a') + 10
            else if CharInSet(C, ['A'..'F']) then
              Code := (Code shl 4) + Ord(C) - Ord('A') + 10
            else raise EJsonException.Create('Invalid unicode escape sequence');
          end;
          Builder.Append(Char(Code)); Inc(I, 4);
        end;
      else raise EJsonException.Create('Invalid escape character: ' + C);
      end;
      Inc(I); Start := I;
    end;
    if Start <= Length(Raw) then Builder.Append(Copy(Raw, Start, Length(Raw) - Start + 1));
    FStrValue := Builder.ToString; FStringDecoded := True; Result := FStrValue;
  finally Builder.Free; end;
end;

function TNextGenJsonValue.AsInteger: Integer;
begin
  if FStrValue <> '' then
    Result := StrToIntDef(FStrValue, 0)
  else
    Result := Integer(AsInt64);
end;

function TNextGenJsonValue.AsInt64: Int64;
begin
  if FStrValue <> '' then
    Result := StrToInt64Def(FStrValue, 0)
  else
    Result := TNextGenJsonParser.ParseInt64(FValueSpan);
end;

function TNextGenJsonValue.AsDouble: Double;
begin
  if FStrValue <> '' then
    Result := StrToFloatDef(FStrValue, 0.0, TFormatSettings.Invariant)
  else
    Result := TNextGenJsonParser.ParseNumber(FValueSpan);
end;

function TNextGenJsonValue.AsBoolean: Boolean;
begin
  if FType = TDextJsonNodeType.jntBoolean then
  begin
    if FStrValue <> '' then
      Result := FStrValue.ToLower = 'true'
    else
      Result := FValueSpan.EqualsString('true');
  end
  else
    Result := False;
end;

function TNextGenJsonValue.IsNull: Boolean;
begin
  Result := FType = TDextJsonNodeType.jntNull;
end;

{ TJsonLookupTable }

class constructor TJsonLookupTable.Create;
begin
  FillChar(Structural, SizeOf(Structural), 0);
  FillChar(Whitespace, SizeOf(Whitespace), 0);

  Structural[Ord('{')] := True;
  Structural[Ord('}')] := True;
  Structural[Ord('[')] := True;
  Structural[Ord(']')] := True;
  Structural[Ord(':')] := True;
  Structural[Ord(',')] := True;
  Structural[Ord('"')] := True;
  Structural[Ord('\')] := True;

  Whitespace[Ord(' ')] := True;
  Whitespace[Ord(#9)] := True;
  Whitespace[Ord(#10)] := True;
  Whitespace[Ord(#13)] := True;
end;

{ TNextGenJsonParser }

procedure TNextGenJsonParser.ScanString(var APtr: PByte);
var
  B: Byte;
begin
  while APtr < FEnd do
  begin
    while (APtr < FEnd) and (APtr^ >= 32) and
          (APtr^ <> Ord('"')) and (APtr^ <> Ord('\')) do
      Inc(APtr);

    if APtr >= FEnd then
      Break;

    B := APtr^;
    if B = Ord('"') then
      Exit;

    if B < 32 then
    begin
      if (B = 10) or (B = 13) then
        raise EJsonException.Create(
          'Raw line break not allowed in string'
        )
      else
        raise EJsonException.Create(
          'Control character not allowed in string'
        );
    end;

    if B = Ord('\') then
    begin
      Inc(APtr);
      if APtr >= FEnd then
        raise EJsonException.Create('Unterminated string escape');
      B := APtr^;
      case B of
        Ord('"'), Ord('\'), Ord('/'), Ord('b'), Ord('f'), Ord('n'),
        Ord('r'), Ord('t'): ;
        Ord('u'):
          begin
            if APtr + 4 >= FEnd then
              raise EJsonException.Create(
                'Invalid unicode escape sequence'
              );
            Inc(APtr, 4);
          end;
      else
        raise EJsonException.Create(
          'Invalid escape character: \' + Char(B)
        );
      end;
    end;
    Inc(APtr);
  end;
  raise EJsonException.Create('String not closed');
end;

class function TNextGenJsonParser.ParseNumber(
  const ASpan: TByteSpan
): Double;
var
  I: Integer;
  Val: Double;
  Divisor: Double;
  Sign: Double;
  B: Byte;
  IsFraction: Boolean;
begin
  if ASpan.Length = 0 then
    Exit(0.0);
  Val := 0.0;
  Divisor := 1.0;
  Sign := 1.0;
  IsFraction := False;
  I := 0;
  if ASpan.Data[0] = Ord('-') then
  begin
    Sign := -1.0;
    Inc(I);
  end
  else if ASpan.Data[0] = Ord('+') then
  begin
    Inc(I);
  end;

  while I < ASpan.Length do
  begin
    B := ASpan.Data[I];
    if (B >= Ord('0')) and (B <= Ord('9')) then
    begin
      if IsFraction then
      begin
        Divisor := Divisor * 10.0;
        Val := Val + (B - Ord('0')) / Divisor;
      end
      else
      begin
        Val := Val * 10.0 + (B - Ord('0'));
      end;
    end
    else if B = Ord('.') then
    begin
      IsFraction := True;
    end
    else
    begin
      Exit(StrToFloatDef(ASpan.ToString, 0.0, TFormatSettings.Invariant));
    end;
    Inc(I);
  end;
  Result := Val * Sign;
end;

class function TNextGenJsonParser.ParseInt64(
  const ASpan: TByteSpan
): Int64;
var
  I: Integer;
  Val: Int64;
  Sign: Int64;
  B: Byte;
begin
  if ASpan.Length = 0 then
    Exit(0);
  Val := 0;
  Sign := 1;
  I := 0;
  if ASpan.Data[0] = Ord('-') then
  begin
    Sign := -1;
    Inc(I);
  end
  else if ASpan.Data[0] = Ord('+') then
  begin
    Inc(I);
  end;

  while I < ASpan.Length do
  begin
    B := ASpan.Data[I];
    if (B >= Ord('0')) and (B <= Ord('9')) then
      Val := Val * 10 + (B - Ord('0'))
    else
      Break;
    Inc(I);
  end;
  Result := Val * Sign;
end;

class function TNextGenJsonParser.ScanStructural_SSE42(
  Ptr: PByte;
  Length: Integer
): Integer;
{$IFDEF DEXT_JSON_SSE42_ENABLE}
// SSE4.2 fast path disabled by default (correctness bug, PR waldirpaim/nexo#2329 review):
// PCMPISTRI always writes its match index to ECX, but this routine also uses
// RCX as the buffer pointer inside the same loop, so `add rcx, 16` advances a
// clobbered value instead of Ptr once a chunk has no match. EAX is also never
// accumulated across loop iterations, and the @Scalar fallback zeroes RCX
// (destroying Ptr) before dereferencing an uninitialized R8 offset. Re-enable
// only after a corrected implementation is verified against tests covering
// buffers > 16 bytes with a match outside the first chunk, and the @Scalar
// fallback (buffers < 16 bytes) -- neither is exercised by the existing
// TestScanStructural test.
asm
  // RCX = Ptr, RDX = Length
  xor eax, eax
  cmp rdx, 16
  jl @Scalar

  mov rax, 05C222C3A5D5B7D7Bh // "{}[],:\"
  movq xmm0, rax

@Loop:
  cmp rdx, 16
  jl @Scalar
  pcmpistri xmm0, [rcx], 0
  jc @Found
  add rcx, 16
  sub rdx, 16
  jmp @Loop

@Found:
  add eax, ecx
  ret

@Scalar:
  xor ecx, ecx
@ScalarLoop:
  cmp ecx, edx
  jge @NotFound
  mov r8b, [rcx + r8]
  cmp r8b, '{'
  je @ScalarFound
  cmp r8b, '}'
  je @ScalarFound
  cmp r8b, '['
  je @ScalarFound
  cmp r8b, ']'
  je @ScalarFound
  cmp r8b, ':'
  je @ScalarFound
  cmp r8b, ','
  je @ScalarFound
  cmp r8b, '"'
  je @ScalarFound
  cmp r8b, '\'
  je @ScalarFound
  inc ecx
  jmp @ScalarLoop

@ScalarFound:
  mov eax, ecx
  ret

@NotFound:
  mov eax, -1
  ret
end;
{$ELSE}
begin
  Result := 0;
  while Result < Length do
  begin
    if TJsonLookupTable.Structural[Ptr[Result]] then
      Exit;
    Inc(Result);
  end;
  Result := -1;
end;
{$ENDIF}

function TNextGenJsonParser.ParseObject: IDextJsonObject;
var
  Obj: IDextJsonObject;
  ObjClass: TNextGenJsonObject;
  KeySpan: TByteSpan;
  Val: TNextGenJsonValue;
  StartKey: PByte;
begin
  Obj := TNextGenJsonPool.RentObject;
  ObjClass := TNextGenJsonObject(Obj);
  Inc(FPtr); // Pula '{'

  while (FPtr < FEnd) and (GWhitespace[FPtr^] <> 0) do
    Inc(FPtr);

  if (FPtr < FEnd) and (FPtr^ = Ord('}')) then
  begin
    Inc(FPtr);
    Exit(Obj);
  end;

  while FPtr < FEnd do
  begin
    while (FPtr < FEnd) and (GWhitespace[FPtr^] <> 0) do
      Inc(FPtr);

    if FPtr >= FEnd then
      raise EJsonException.Create('Expected key string or "}"');

    if FPtr^ <> Ord('"') then
      raise EJsonException.Create('Key string must be quoted');

    Inc(FPtr); // skip '"'
    StartKey := FPtr;
    ScanString(FPtr);
    KeySpan := TByteSpan.Create(StartKey, FPtr - StartKey);
    Inc(FPtr); // skip '"'

    while (FPtr < FEnd) and (GWhitespace[FPtr^] <> 0) do
      Inc(FPtr);

    if FPtr >= FEnd then
      raise EJsonException.Create('Expected ":" after key');

    if FPtr^ <> Ord(':') then
      raise EJsonException.Create('Expected ":" after key, found ' +
        Char(FPtr^));

    Inc(FPtr); // skip ':'

    Val := ParseValue;
    ObjClass.AddPair(KeySpan, Val);

    while (FPtr < FEnd) and (GWhitespace[FPtr^] <> 0) do
      Inc(FPtr);

    if FPtr >= FEnd then
      raise EJsonException.Create('Expected "," or "}"');

    if FPtr^ = Ord(',') then
    begin
      Inc(FPtr); // skip ','
      while (FPtr < FEnd) and (GWhitespace[FPtr^] <> 0) do
        Inc(FPtr);
      if (FPtr < FEnd) and (FPtr^ = Ord('}')) then
        raise EJsonException.Create('Trailing comma in object');
    end
    else if FPtr^ = Ord('}') then
    begin
      Inc(FPtr); // skip '}'
      if ObjClass.FCount < Length(ObjClass.FPairs) then
        SetLength(ObjClass.FPairs, ObjClass.FCount);
      Exit(Obj);
    end
    else
    begin
      raise EJsonException.Create('Expected "," or "}"');
    end;
  end;
  raise EJsonException.Create('Unclosed object');
end;

function TNextGenJsonParser.ParseArray: IDextJsonArray;
var
  Arr: IDextJsonArray;
  ArrClass: TNextGenJsonArray;
  Val: TNextGenJsonValue;
begin
  Arr := TNextGenJsonPool.RentArray;
  ArrClass := TNextGenJsonArray(Arr);
  Inc(FPtr); // Pula '['

  while (FPtr < FEnd) and (GWhitespace[FPtr^] <> 0) do
    Inc(FPtr);

  if (FPtr < FEnd) and (FPtr^ = Ord(']')) then
  begin
    Inc(FPtr);
    Exit(Arr);
  end;

  while FPtr < FEnd do
  begin
    if FPtr^ = Ord(',') then
      raise EJsonException.Create('Expected value, found ","');

    Val := ParseValue;
    ArrClass.AddValue(Val);

    while (FPtr < FEnd) and (GWhitespace[FPtr^] <> 0) do
      Inc(FPtr);

    if FPtr >= FEnd then
      raise EJsonException.Create('Expected "," or "]"');

    if FPtr^ = Ord(',') then
    begin
      Inc(FPtr); // skip ','
      while (FPtr < FEnd) and (GWhitespace[FPtr^] <> 0) do
        Inc(FPtr);
      if (FPtr < FEnd) and (FPtr^ = Ord(']')) then
        raise EJsonException.Create('Trailing comma in array');
    end
    else if FPtr^ = Ord(']') then
    begin
      Inc(FPtr); // skip ']'
      if ArrClass.FCount < Length(ArrClass.FValues) then
        SetLength(ArrClass.FValues, ArrClass.FCount);
      Exit(Arr);
    end
    else
    begin
      raise EJsonException.Create('Expected "," or "]"');
    end;
  end;
  raise EJsonException.Create('Unclosed array');
end;

function TNextGenJsonParser.ParseValue: TNextGenJsonValue;
var
  StartPos: PByte;
  Val: TNextGenJsonValue;
  B: Byte;
  ValSpan: TByteSpan;
  P: PByte;
begin
  while (FPtr < FEnd) and (GWhitespace[FPtr^] <> 0) do
    Inc(FPtr);

  if FPtr >= FEnd then
    raise EJsonException.Create('Unexpected end of JSON');

  B := FPtr^;
  if B = Ord('{') then
  begin
    Val.Init(
      TDextJsonNodeType.jntObject,
      TByteSpan.Create(FPtr, 0)
    );
    Val.FNodeRef := ParseObject;
    Exit(Val);
  end;

  if B = Ord('[') then
  begin
    Val.Init(
      TDextJsonNodeType.jntArray,
      TByteSpan.Create(FPtr, 0)
    );
    Val.FNodeRef := ParseArray;
    Exit(Val);
  end;

  if B = Ord('"') then
  begin
    Inc(FPtr); // skip '"'
    StartPos := FPtr;
    ScanString(FPtr);
    Val.Init(
      TDextJsonNodeType.jntString,
      TByteSpan.Create(StartPos, FPtr - StartPos)
    );
    Inc(FPtr); // skip '"'
    Exit(Val);
  end;

  StartPos := FPtr;
  while (FPtr < FEnd) and (GWhitespace[FPtr^] = 0)
    and (FPtr^ <> Ord(','))
    and (FPtr^ <> Ord('}'))
    and (FPtr^ <> Ord(']')) do
  begin
    Inc(FPtr);
  end;

  if StartPos = FPtr then
    raise EJsonException.Create('Expected value');

  ValSpan := TByteSpan.Create(StartPos, FPtr - StartPos);
  if ValSpan.EqualsString('true') then
    Val.Init(TDextJsonNodeType.jntBoolean, ValSpan)
  else if ValSpan.EqualsString('false') then
    Val.Init(TDextJsonNodeType.jntBoolean, ValSpan)
  else if ValSpan.EqualsString('null') then
    Val.Init(TDextJsonNodeType.jntNull, ValSpan)
  else
  begin
    if ValSpan.Length = 0 then
      raise EJsonException.Create('Invalid number');

    P := ValSpan.Data;
    if (P^ = Ord('-')) or (P^ = Ord('+')) then
    begin
      if P^ = Ord('+') then
        raise EJsonException.Create('Number cannot start with +');
      Inc(P);
      if P >= ValSpan.Data + ValSpan.Length then
        raise EJsonException.Create('Invalid number: sign only');
    end;

    if P^ = Ord('.') then
      raise EJsonException.Create('Decimal needs digit before dot');

    if P^ = Ord('0') then
    begin
      if (P + 1 < ValSpan.Data + ValSpan.Length) and
         (P[1] >= Ord('0')) and
         (P[1] <= Ord('9')) then
        raise EJsonException.Create('Leading zeroes not allowed');
    end;

    while (P < ValSpan.Data + ValSpan.Length) and
          (P^ >= Ord('0')) and
          (P^ <= Ord('9')) do
      Inc(P);

    if (P < ValSpan.Data + ValSpan.Length) and (P^ = Ord('.')) then
    begin
      Inc(P);
      if (P >= ValSpan.Data + ValSpan.Length) or
         (P^ < Ord('0')) or
         (P^ > Ord('9')) then
        raise EJsonException.Create('Expected digit after decimal point');
      while (P < ValSpan.Data + ValSpan.Length) and
            (P^ >= Ord('0')) and
            (P^ <= Ord('9')) do
        Inc(P);
    end;

    if (P < ValSpan.Data + ValSpan.Length) and
       ((P^ = Ord('e')) or (P^ = Ord('E'))) then
    begin
      Inc(P);
      if P >= ValSpan.Data + ValSpan.Length then
        raise EJsonException.Create('Exponent requires value');
      if (P^ = Ord('+')) or (P^ = Ord('-')) then
      begin
        Inc(P);
        if P >= ValSpan.Data + ValSpan.Length then
          raise EJsonException.Create('Exponent requires value');
      end;
      if (P^ < Ord('0')) or (P^ > Ord('9')) then
        raise EJsonException.Create('Expected digit in exponent');
      while (P < ValSpan.Data + ValSpan.Length) and
            (P^ >= Ord('0')) and
            (P^ <= Ord('9')) do
        Inc(P);
    end;

    if P < ValSpan.Data + ValSpan.Length then
      raise EJsonException.Create('Invalid character in number');

    Val.Init(TDextJsonNodeType.jntNumber, ValSpan);
  end;

  Result := Val;
end;

class function TNextGenJsonParser.Parse(
  const AData: TByteSpan;
  const AKeepAlive: IInterface
): IDextJsonNode;
var
  Parser: TNextGenJsonParser;
begin
  Parser.FData := AData;
  Parser.FStart := AData.Data;
  Parser.FPtr := AData.Data;
  Parser.FEnd := AData.Data + AData.Length;

  while (Parser.FPtr < Parser.FEnd) and (GWhitespace[Parser.FPtr^] <> 0) do
    Inc(Parser.FPtr);

  if Parser.FPtr >= Parser.FEnd then
    raise EJsonException.Create('Empty JSON string');

  if Parser.FPtr^ = Ord('{') then
  begin
    Result := Parser.ParseObject;
    if Assigned(AKeepAlive) then
      (Result as TNextGenJsonObject).FKeepAlive := AKeepAlive;
  end
  else if Parser.FPtr^ = Ord('[') then
  begin
    Result := Parser.ParseArray;
    if Assigned(AKeepAlive) then
      (Result as TNextGenJsonArray).FKeepAlive := AKeepAlive;
  end
  else
  begin
    Result := TNextGenJsonPrimitive.Create(Parser.ParseValue);
    if Assigned(AKeepAlive) then
      (Result as TNextGenJsonPrimitive).FKeepAlive := AKeepAlive;
  end;

  while (Parser.FPtr < Parser.FEnd) and (GWhitespace[Parser.FPtr^] <> 0) do
    Inc(Parser.FPtr);

  if Parser.FPtr < Parser.FEnd then
    raise EJsonException.Create('Extra trailing data after JSON root');
end;

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
function GetKeyHash(const K: TJsonKey): Cardinal; inline;
var
  I: Integer;
begin
  Result := 2166136261;
  if K.StrValue <> '' then
  begin
    for I := 1 to System.Length(K.StrValue) do
      Result := (Result xor Ord(K.StrValue[I])) * 16777619;
  end
  else
  begin
    for I := 0 to K.Span.Length - 1 do
      Result := (Result xor K.Span.Data[I]) * 16777619;
  end;
end;

function GetStringHash(const S: string): Cardinal; inline;
var
  I: Integer;
begin
  Result := 2166136261;
  for I := 1 to System.Length(S) do
    Result := (Result xor Ord(S[I])) * 16777619;
end;

{ TNextGenJsonObject }

function TNextGenJsonObject._AddRef: Integer;
begin
  Result := AtomicIncrement(FRefCount);
end;

function TNextGenJsonObject._Release: Integer;
begin
  Result := AtomicDecrement(FRefCount);
  if Result = 0 then
    TNextGenJsonPool.ReturnObject(Self);
end;

constructor TNextGenJsonObject.Create;
begin
  inherited Create;
  SetLength(FPairs, 0);
  FCount := 0;
  SetLength(FHashTable, 0);
  SetLength(FHashChain, 0);
  FHashBuilt := False;
end;

destructor TNextGenJsonObject.Destroy;
begin
  inherited Destroy;
end;

procedure TNextGenJsonObject.BuildHash;
var
  I: Integer;
  H: Cardinal;
  Bucket: Integer;
  BucketCount: Integer;
begin
  if FHashBuilt then Exit;
  BucketCount := 65536;
  while BucketCount < FCount * 2 do
    BucketCount := BucketCount * 2;

  SetLength(FHashTable, BucketCount);
  for I := 0 to BucketCount - 1 do
    FHashTable[I] := -1;

  SetLength(FHashChain, FCount);
  for I := 0 to FCount - 1 do
  begin
    H := GetKeyHash(FPairs[I].Key);
    Bucket := H and (BucketCount - 1);
    FHashChain[I] := FHashTable[Bucket];
    FHashTable[Bucket] := I;
  end;
  FHashBuilt := True;
end;

function TNextGenJsonObject.FindKey(const Name: string): Integer;
var
  I: Integer;
  Len: Integer;
  SearchBuf: array[0..127] of Byte;
  SearchSpan: TByteSpan;
  U8: TBytes;
  IsAscii: Boolean;
  H: Cardinal;
  Bucket: Integer;
  Idx: Integer;
  BucketCount: Integer;
begin
  Len := System.Length(Name);
  if Len = 0 then Exit(-1);

  if FCount > 64 then
  begin
    BuildHash;
    H := GetStringHash(Name);
    BucketCount := System.Length(FHashTable);
    Bucket := H and (BucketCount - 1);
    Idx := FHashTable[Bucket];
    while Idx >= 0 do
    begin
      if FPairs[Idx].Key.StrValue <> '' then
      begin
        if FPairs[Idx].Key.StrValue = Name then
          Exit(Idx);
      end
      else if FPairs[Idx].Key.Span.EqualsString(Name) then
        Exit(Idx);
      Idx := FHashChain[Idx];
    end;
    Exit(-1);
  end;

  IsAscii := True;
  if Len <= 128 then
  begin
    for I := 0 to Len - 1 do
    begin
      if Ord(Name[I + 1]) > 127 then
      begin
        IsAscii := False;
        Break;
      end;
      SearchBuf[I] := Byte(Name[I + 1]);
    end;
  end
  else
    IsAscii := False;

  if IsAscii then
  begin
    SearchSpan := TByteSpan.Create(@SearchBuf[0], Len);
    for I := 0 to FCount - 1 do
    begin
      if FPairs[I].Key.StrValue <> '' then
      begin
        if FPairs[I].Key.StrValue = Name then
          Exit(I);
      end
      else if FPairs[I].Key.Span.Equals(SearchSpan) then
        Exit(I);
    end;
  end
  else
  begin
    U8 := TEncoding.UTF8.GetBytes(Name);
    if System.Length(U8) > 0 then
      SearchSpan := TByteSpan.Create(@U8[0], System.Length(U8))
    else
      SearchSpan := TByteSpan.Create(nil, 0);

    for I := 0 to FCount - 1 do
    begin
      if FPairs[I].Key.StrValue <> '' then
      begin
        if FPairs[I].Key.StrValue = Name then
          Exit(I);
      end
      else if FPairs[I].Key.Span.Equals(SearchSpan) then
        Exit(I);
    end;
  end;
  Result := -1;
end;

procedure TNextGenJsonObject.AddPair(
  const AKey: TByteSpan;
  const AValue: TNextGenJsonValue
);
var
  NewCap: Integer;
begin
  if FCount >= Length(FPairs) then
  begin
    NewCap := Length(FPairs) * 2;
    if NewCap < 8 then NewCap := 8;
    SetLength(FPairs, NewCap);
  end;
  FPairs[FCount].Key.Span := AKey;
  FPairs[FCount].Key.StrValue := '';
  FPairs[FCount].Value := AValue;
  Inc(FCount);
  FHashBuilt := False;
end;

procedure TNextGenJsonObject.AddPair(
  const AKey: string;
  const AValue: TNextGenJsonValue
);
var
  NewCap: Integer;
begin
  if FCount >= Length(FPairs) then
  begin
    NewCap := Length(FPairs) * 2;
    if NewCap < 8 then NewCap := 8;
    SetLength(FPairs, NewCap);
  end;
  FPairs[FCount].Key.Span := TByteSpan.Create(nil, 0);
  FPairs[FCount].Key.StrValue := AKey;
  FPairs[FCount].Value := AValue;
  Inc(FCount);
  FHashBuilt := False;
end;

procedure TNextGenJsonObject.AddOrReplacePair(
  const AKey: string;
  const AValue: TNextGenJsonValue
);
var
  Idx: Integer;
begin
  Idx := FindKey(AKey);
  if Idx >= 0 then
  begin
    FPairs[Idx].Value := AValue;
  end
  else
  begin
    AddPair(AKey, AValue);
  end;
end;

function TNextGenJsonObject.GetNodeType: TDextJsonNodeType;
begin
  Result := TDextJsonNodeType.jntObject;
end;

function TNextGenJsonObject.AsString: string;
begin
  Result := ToJson;
end;

function TNextGenJsonObject.AsInteger: Integer;
begin
  Result := 0;
end;

function TNextGenJsonObject.AsInt64: Int64;
begin
  Result := 0;
end;

function TNextGenJsonObject.AsDouble: Double;
begin
  Result := 0.0;
end;

function TNextGenJsonObject.AsBoolean: Boolean;
begin
  Result := False;
end;

procedure NodeToWriter(
  const ANode: IDextJsonNode;
  var AWriter: TNextGenJsonWriter
);
var
  Obj: TNextGenJsonObject;
  Arr: TNextGenJsonArray;
  ObjIntf: IDextJsonObject;
  ArrIntf: IDextJsonArray;
  I: Integer;
  PropName: string;
  Val: TNextGenJsonValue;
  U8: TBytes;
begin
  if ANode = nil then
  begin
    AWriter.WriteNull;
    Exit;
  end;

  if ANode is TNextGenJsonObject then
  begin
    Obj := TNextGenJsonObject(ANode);
    AWriter.StartObject;
    for I := 0 to Obj.FCount - 1 do
    begin
      if Obj.FPairs[I].Key.StrValue <> '' then
        AWriter.WritePropertyName(Obj.FPairs[I].Key.StrValue)
      else
        AWriter.WritePropertyName(Obj.FPairs[I].Key.Span);

      Val := Obj.FPairs[I].Value;
      case Val.FType of
        TDextJsonNodeType.jntObject, TDextJsonNodeType.jntArray:
          NodeToWriter(Val.FNodeRef, AWriter);
        TDextJsonNodeType.jntString:
          if Val.FStrValue <> '' then
            AWriter.WriteStringValue(Val.FStrValue)
          else
            AWriter.WriteStringValue(Val.FValueSpan);
        TDextJsonNodeType.jntNull:
          AWriter.WriteNull;
        TDextJsonNodeType.jntNumber, TDextJsonNodeType.jntBoolean:
          if Val.FStrValue <> '' then
          begin
            if Val.FType = TDextJsonNodeType.jntBoolean then
              AWriter.WriteBoolean(Val.FStrValue = 'true')
            else
            begin
              U8 := TEncoding.UTF8.GetBytes(Val.FStrValue);
              AWriter.WriteRawValue(TByteSpan.FromBytes(U8));
            end;
          end
          else
            AWriter.WriteRawValue(Val.FValueSpan);
      end;
    end;
    AWriter.EndObject;
  end
  else if ANode is TNextGenJsonArray then
  begin
    Arr := TNextGenJsonArray(ANode);
    AWriter.StartArray;
    for I := 0 to Arr.FCount - 1 do
    begin
      Val := Arr.FValues[I];
      case Val.FType of
        TDextJsonNodeType.jntObject, TDextJsonNodeType.jntArray:
          NodeToWriter(Val.FNodeRef, AWriter);
        TDextJsonNodeType.jntString:
          if Val.FStrValue <> '' then
            AWriter.WriteStringValue(Val.FStrValue)
          else
            AWriter.WriteStringValue(Val.FValueSpan);
        TDextJsonNodeType.jntNull:
          AWriter.WriteNull;
        TDextJsonNodeType.jntNumber, TDextJsonNodeType.jntBoolean:
          if Val.FStrValue <> '' then
          begin
            if Val.FType = TDextJsonNodeType.jntBoolean then
              AWriter.WriteBoolean(Val.FStrValue = 'true')
            else
            begin
              U8 := TEncoding.UTF8.GetBytes(Val.FStrValue);
              AWriter.WriteRawValue(TByteSpan.FromBytes(U8));
            end;
          end
          else
            AWriter.WriteRawValue(Val.FValueSpan);
      end;
    end;
    AWriter.EndArray;
  end
  else
  begin
    case ANode.GetNodeType of
      TDextJsonNodeType.jntObject:
        begin
          ObjIntf := ANode as IDextJsonObject;
          AWriter.StartObject;
          for I := 0 to ObjIntf.GetCount - 1 do
          begin
            PropName := ObjIntf.GetName(I);
            AWriter.WritePropertyName(PropName);
            NodeToWriter(ObjIntf.GetNode(PropName), AWriter);
          end;
          AWriter.EndObject;
        end;
      TDextJsonNodeType.jntArray:
        begin
          ArrIntf := ANode as IDextJsonArray;
          AWriter.StartArray;
          for I := 0 to ArrIntf.GetCount - 1 do
            NodeToWriter(ArrIntf.GetNode(I), AWriter);
          AWriter.EndArray;
        end;
      TDextJsonNodeType.jntString:
        AWriter.WriteStringValue(ANode.AsString);
      TDextJsonNodeType.jntNumber:
        AWriter.WriteNumber(ANode.AsDouble);
      TDextJsonNodeType.jntBoolean:
        AWriter.WriteBoolean(ANode.AsBoolean);
      TDextJsonNodeType.jntNull:
        AWriter.WriteNull;
    end;
  end;
end;

function FormatJson(const AJson: string): string;
var
  I: Integer;
  Indent: Integer;
  InString: Boolean;
  C: Char;
  Len: Integer;
  SB: TStringBuilder;
  J: Integer;
begin
  Len := Length(AJson);
  if Len = 0 then Exit('');

  SB := TStringBuilder.Create(Len * 2);
  try
    Indent := 0;
    InString := False;
    I := 1;
    while I <= Len do
    begin
      C := AJson[I];
      if C = '"' then
      begin
        if (I > 1) and (AJson[I - 1] = '\') then
        begin
          // escaped quote
        end
        else
          InString := not InString;

        SB.Append(C);
      end
      else if InString then
      begin
        SB.Append(C);
      end
      else
      begin
        case C of
          '{', '[':
            begin
              SB.Append(C).Append(#13#10);
              Inc(Indent);
              for J := 1 to Indent * 2 do
                SB.Append(' ');
            end;
          '}', ']':
            begin
              SB.Append(#13#10);
              Dec(Indent);
              for J := 1 to Indent * 2 do
                SB.Append(' ');
              SB.Append(C);
            end;
          ',':
            begin
              SB.Append(C).Append(#13#10);
              for J := 1 to Indent * 2 do
                SB.Append(' ');
            end;
          ':':
            begin
              SB.Append(': ');
            end;
          ' ', #13, #10, #9:
            ; // skip extra whitespace
          else
            SB.Append(C);
        end;
      end;
      Inc(I);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TNextGenJsonObject.ToJson(Indented: Boolean): string;
var
  Writer: TNextGenJsonWriter;
begin
  Writer.Init(4096);
  try
    NodeToWriter(Self, Writer);
    Result := Writer.ToString;
    if Indented then
      Result := FormatJson(Result);
  finally
    Writer.Clear;
  end;
end;

function TNextGenJsonObject.IsNull: Boolean;
begin
  Result := False;
end;

function TNextGenJsonObject.Contains(const Name: string): Boolean;
begin
  Result := FindKey(Name) >= 0;
end;

// IDextJsonObject GetNode implementation
function TNextGenJsonObject.GetNode(const Name: string): IDextJsonNode;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
  begin
    if (FPairs[Idx].Value.NodeType = TDextJsonNodeType.jntObject) or
       (FPairs[Idx].Value.NodeType = TDextJsonNodeType.jntArray) then
      Result := FPairs[Idx].Value.FNodeRef
    else
      Result := TNextGenJsonPrimitive.Create(FPairs[Idx].Value);
  end
  else
    Result := nil;
end;

function TNextGenJsonObject.GetString(const Name: string): string;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
    Result := FPairs[Idx].Value.AsString
  else
    Result := '';
end;

function TNextGenJsonObject.GetInteger(const Name: string): Integer;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
    Result := FPairs[Idx].Value.AsInteger
  else
    Result := 0;
end;

function TNextGenJsonObject.GetInt64(const Name: string): Int64;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
    Result := FPairs[Idx].Value.AsInt64
  else
    Result := 0;
end;

function TNextGenJsonObject.GetDouble(const Name: string): Double;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
    Result := FPairs[Idx].Value.AsDouble
  else
    Result := 0.0;
end;

function TNextGenJsonObject.GetBoolean(const Name: string): Boolean;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
    Result := FPairs[Idx].Value.AsBoolean
  else
    Result := False;
end;

function TNextGenJsonObject.GetObject(const Name: string): IDextJsonObject;
begin
  Result := GetNode(Name) as IDextJsonObject;
end;

function TNextGenJsonObject.GetArray(const Name: string): IDextJsonArray;
begin
  Result := GetNode(Name) as IDextJsonArray;
end;

function TNextGenJsonObject.GetCount: Integer;
begin
  Result := FCount;
end;

function TNextGenJsonObject.GetName(Index: Integer): string;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FPairs[Index].Key.ToString
  else
    Result := '';
end;

procedure TNextGenJsonObject.SetString(const Name, Value: string);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntString;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := Value;
  Val.FNodeRef := nil;
  AddOrReplacePair(Name, Val);
end;

procedure TNextGenJsonObject.SetInteger(const Name: string; Value: Integer);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntNumber;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := IntToStr(Value);
  Val.FNodeRef := nil;
  AddOrReplacePair(Name, Val);
end;

procedure TNextGenJsonObject.SetInt64(const Name: string; Value: Int64);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntNumber;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := IntToStr(Value);
  Val.FNodeRef := nil;
  AddOrReplacePair(Name, Val);
end;

procedure TNextGenJsonObject.SetDouble(const Name: string; Value: Double);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntNumber;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := FloatToStr(Value, TFormatSettings.Invariant);
  Val.FNodeRef := nil;
  AddOrReplacePair(Name, Val);
end;

procedure TNextGenJsonObject.SetBoolean(const Name: string; Value: Boolean);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntBoolean;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  if Value then Val.FStrValue := 'true' else Val.FStrValue := 'false';
  Val.FNodeRef := nil;
  AddOrReplacePair(Name, Val);
end;

procedure TNextGenJsonObject.SetObject(
  const Name: string;
  Value: IDextJsonObject
);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntObject;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := '';
  Val.FNodeRef := Value;
  AddOrReplacePair(Name, Val);
end;

procedure TNextGenJsonObject.SetArray(
  const Name: string;
  Value: IDextJsonArray
);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntArray;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := '';
  Val.FNodeRef := Value;
  AddOrReplacePair(Name, Val);
end;

procedure TNextGenJsonObject.SetNode(const Name: string; Value: IDextJsonNode);
var
  Val: TNextGenJsonValue;
begin
  if Value = nil then
  begin
    SetNull(Name);
    Exit;
  end;

  Val.FType := Value.GetNodeType;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := '';
  Val.FNodeRef := nil;

  case Val.FType of
    TDextJsonNodeType.jntString: Val.FStrValue := Value.AsString;
    TDextJsonNodeType.jntNumber: Val.FStrValue :=
      FloatToStr(Value.AsDouble, TFormatSettings.Invariant);
    TDextJsonNodeType.jntBoolean:
      if Value.AsBoolean then Val.FStrValue := 'true' else Val.FStrValue := 'false';
    TDextJsonNodeType.jntObject, TDextJsonNodeType.jntArray:
      Val.FNodeRef := Value;
  end;

  AddOrReplacePair(Name, Val);
end;

procedure TNextGenJsonObject.SetNull(const Name: string);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntNull;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := '';
  Val.FNodeRef := nil;
  AddOrReplacePair(Name, Val);
end;

{ TNextGenJsonArray }

function TNextGenJsonArray._AddRef: Integer;
begin
  Result := AtomicIncrement(FRefCount);
end;

function TNextGenJsonArray._Release: Integer;
begin
  Result := AtomicDecrement(FRefCount);
  if Result = 0 then
    TNextGenJsonPool.ReturnArray(Self);
end;

constructor TNextGenJsonArray.Create;
begin
  inherited Create;
  SetLength(FValues, 0);
  FCount := 0;
end;

destructor TNextGenJsonArray.Destroy;
begin
  inherited Destroy;
end;

procedure TNextGenJsonArray.AddValue(const AValue: TNextGenJsonValue);
var
  NewCap: Integer;
begin
  if FCount >= Length(FValues) then
  begin
    NewCap := Length(FValues) * 2;
    if NewCap < 8 then NewCap := 8;
    SetLength(FValues, NewCap);
  end;
  FValues[FCount] := AValue;
  Inc(FCount);
end;

function TNextGenJsonArray.GetNodeType: TDextJsonNodeType;
begin
  Result := TDextJsonNodeType.jntArray;
end;

function TNextGenJsonArray.AsString: string;
begin
  Result := ToJson;
end;

// Array getters
function TNextGenJsonArray.AsInteger: Integer;
begin
  Result := 0;
end;

function TNextGenJsonArray.AsInt64: Int64;
begin
  Result := 0;
end;

function TNextGenJsonArray.AsDouble: Double;
begin
  Result := 0.0;
end;

function TNextGenJsonArray.AsBoolean: Boolean;
begin
  Result := False;
end;

function TNextGenJsonArray.ToJson(Indented: Boolean): string;
var
  Writer: TNextGenJsonWriter;
begin
  Writer.Init(4096);
  try
    NodeToWriter(Self, Writer);
    Result := Writer.ToString;
    if Indented then
      Result := FormatJson(Result);
  finally
    Writer.Clear;
  end;
end;

function TNextGenJsonArray.IsNull: Boolean;
begin
  Result := False;
end;

function TNextGenJsonArray.GetCount: NativeInt;
begin
  Result := FCount;
end;

function TNextGenJsonArray.GetNode(Index: Integer): IDextJsonNode;
begin
  if (Index >= 0) and (Index < FCount) then
  begin
    if (FValues[Index].NodeType = TDextJsonNodeType.jntObject) or
       (FValues[Index].NodeType = TDextJsonNodeType.jntArray) then
      Result := FValues[Index].FNodeRef
    else
      Result := TNextGenJsonPrimitive.Create(FValues[Index]);
  end
  else
    Result := nil;
end;

function TNextGenJsonArray.GetString(Index: Integer): string;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FValues[Index].AsString
  else
    Result := '';
end;

function TNextGenJsonArray.GetInteger(Index: Integer): Integer;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FValues[Index].AsInteger
  else
    Result := 0;
end;

function TNextGenJsonArray.GetInt64(Index: Integer): Int64;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FValues[Index].AsInt64
  else
    Result := 0;
end;

function TNextGenJsonArray.GetDouble(Index: Integer): Double;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FValues[Index].AsDouble
  else
    Result := 0.0;
end;

function TNextGenJsonArray.GetBoolean(Index: Integer): Boolean;
begin
  if (Index >= 0) and (Index < FCount) then
    Result := FValues[Index].AsBoolean
  else
    Result := False;
end;

function TNextGenJsonArray.GetObject(Index: Integer): IDextJsonObject;
begin
  Result := GetNode(Index) as IDextJsonObject;
end;

function TNextGenJsonArray.GetArray(Index: Integer): IDextJsonArray;
begin
  Result := GetNode(Index) as IDextJsonArray;
end;

procedure TNextGenJsonArray.Add(const Value: string);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntString;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := Value;
  Val.FNodeRef := nil;
  AddValue(Val);
end;

procedure TNextGenJsonArray.Add(Value: Integer);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntNumber;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := IntToStr(Value);
  Val.FNodeRef := nil;
  AddValue(Val);
end;

procedure TNextGenJsonArray.Add(Value: Int64);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntNumber;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := IntToStr(Value);
  Val.FNodeRef := nil;
  AddValue(Val);
end;

procedure TNextGenJsonArray.Add(Value: Double);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntNumber;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := FloatToStr(Value, TFormatSettings.Invariant);
  Val.FNodeRef := nil;
  AddValue(Val);
end;

procedure TNextGenJsonArray.Add(Value: Boolean);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntBoolean;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  if Value then Val.FStrValue := 'true' else Val.FStrValue := 'false';
  Val.FNodeRef := nil;
  AddValue(Val);
end;

procedure TNextGenJsonArray.Add(Value: IDextJsonObject);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntObject;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := '';
  Val.FNodeRef := Value;
  AddValue(Val);
end;

procedure TNextGenJsonArray.Add(Value: IDextJsonArray);
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntArray;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := '';
  Val.FNodeRef := Value;
  AddValue(Val);
end;

procedure TNextGenJsonArray.AddNull;
var
  Val: TNextGenJsonValue;
begin
  Val.FType := TDextJsonNodeType.jntNull;
  Val.FValueSpan := TByteSpan.Create(nil, 0);
  Val.FStrValue := '';
  Val.FNodeRef := nil;
  AddValue(Val);
end;

{ TNextGenJsonPrimitive }

constructor TNextGenJsonPrimitive.Create(const AValue: TNextGenJsonValue);
begin
  inherited Create;
  FValue := AValue;
end;

function TNextGenJsonPrimitive.GetNodeType: TDextJsonNodeType;
begin
  Result := FValue.NodeType;
end;

function TNextGenJsonPrimitive.AsString: string;
begin
  Result := FValue.AsString;
end;

function TNextGenJsonPrimitive.AsInteger: Integer;
begin
  Result := FValue.AsInteger;
end;

function TNextGenJsonPrimitive.AsInt64: Int64;
begin
  Result := FValue.AsInt64;
end;

function TNextGenJsonPrimitive.AsDouble: Double;
begin
  Result := FValue.AsDouble;
end;

function TNextGenJsonPrimitive.AsBoolean: Boolean;
begin
  Result := FValue.AsBoolean;
end;

function TNextGenJsonPrimitive.ToJson(Indented: Boolean): string;
var
  Writer: TNextGenJsonWriter;
begin
  Writer.Init(128);
  try
    NodeToWriter(Self, Writer);
    Result := Writer.ToString;
    if Indented then
      Result := FormatJson(Result);
  finally
    Writer.Clear;
  end;
end;

function TNextGenJsonPrimitive.IsNull: Boolean;
begin
  Result := FValue.IsNull;
end;

{ TNextGenJsonPool }

class constructor TNextGenJsonPool.Create;
begin
  FObjectCount := 0;
  FArrayCount := 0;
end;

class destructor TNextGenJsonPool.Destroy;
var
  I: Integer;
begin
  for I := 0 to FObjectCount - 1 do
    FObjectPool[I].Free;
  for I := 0 to FArrayCount - 1 do
    FArrayPool[I].Free;
end;

class function TNextGenJsonPool.RentObject: TNextGenJsonObject;
begin
  if FObjectCount > 0 then
  begin
    Dec(FObjectCount);
    Result := FObjectPool[FObjectCount];
  end
  else
    Result := TNextGenJsonObject.Create;
end;

class procedure TNextGenJsonPool.ReturnObject(AnObj: TNextGenJsonObject);
var
  I: Integer;
begin
  for I := 0 to AnObj.FCount - 1 do
    AnObj.FPairs[I].Value.FNodeRef := nil;
  AnObj.FCount := 0;
  AnObj.FKeepAlive := nil;

  if FObjectCount < 1024 then
  begin
    FObjectPool[FObjectCount] := AnObj;
    Inc(FObjectCount);
  end
  else
    AnObj.Free;
end;

class function TNextGenJsonPool.RentArray: TNextGenJsonArray;
begin
  if FArrayCount > 0 then
  begin
    Dec(FArrayCount);
    Result := FArrayPool[FArrayCount];
  end
  else
    Result := TNextGenJsonArray.Create;
end;

class procedure TNextGenJsonPool.ReturnArray(AnArr: TNextGenJsonArray);
var
  I: Integer;
begin
  for I := 0 to AnArr.FCount - 1 do
    AnArr.FValues[I].FNodeRef := nil;
  AnArr.FCount := 0;
  AnArr.FKeepAlive := nil;

  if FArrayCount < 1024 then
  begin
    FArrayPool[FArrayCount] := AnArr;
    Inc(FArrayCount);
  end
  else
    AnArr.Free;
end;

class procedure TNextGenJsonPool.ClearPool;
var
  I: Integer;
begin
  for I := 0 to FObjectCount - 1 do
    FObjectPool[I].Free;
  FObjectCount := 0;
  for I := 0 to FArrayCount - 1 do
    FArrayPool[I].Free;
  FArrayCount := 0;
end;

{ TJSONBufferOwner }

constructor TJSONBufferOwner.Create(const ABytes: TBytes);
begin
  inherited Create;
  FBytes := ABytes;
end;

{ TNextGenJsonProvider }

function TNextGenJsonProvider.CreateObject: IDextJsonObject;
begin
  Result := TNextGenJsonPool.RentObject;
end;

function TNextGenJsonProvider.CreateArray: IDextJsonArray;
begin
  Result := TNextGenJsonPool.RentArray;
end;

function TNextGenJsonProvider.Parse(const Json: string): IDextJsonNode;
var
  Bytes: TBytes;
  Span: TByteSpan;
  Owner: IJSONBufferOwner;
begin
  if Json = '' then
    raise EJsonException.Create('Empty JSON string');
  Bytes := TEncoding.UTF8.GetBytes(Json);
  Span := TByteSpan.FromBytes(Bytes);
  Owner := TJSONBufferOwner.Create(Bytes);
  Result := TNextGenJsonParser.Parse(Span, Owner);
end;

const
  GHex: array[0..15] of Char = '0123456789abcdef';

{ TNextGenJsonWriter }

procedure TNextGenJsonWriter.Init(InitialCapacity: Integer);
begin
  SetLength(FBuffer, InitialCapacity);
  FLength := 0;
  FNeedComma := False;
end;

procedure TNextGenJsonWriter.Clear;
begin
  FLength := 0;
  FNeedComma := False;
end;

procedure TNextGenJsonWriter.EnsureCapacity(ANeeded: Integer);
var
  NewCap: Integer;
  BufferLen: Integer;
begin
  BufferLen := System.Length(FBuffer);
  if FLength + ANeeded > BufferLen then
  begin
    NewCap := BufferLen * 2;
    if NewCap < FLength + ANeeded then
      NewCap := FLength + ANeeded + 65536;
    if NewCap < 512 then
      NewCap := 512;
    SetLength(FBuffer, NewCap);
  end;
end;

procedure TNextGenJsonWriter.WriteRawByte(AByte: Byte);
begin
  EnsureCapacity(1);
  FBuffer[FLength] := AByte;
  Inc(FLength);
end;

procedure TNextGenJsonWriter.WriteRawBytes(const ABytes: TBytes);
var
  Len: Integer;
begin
  Len := System.Length(ABytes);
  if Len > 0 then
  begin
    EnsureCapacity(Len);
    Move(ABytes[0], FBuffer[FLength], Len);
    Inc(FLength, Len);
  end;
end;

procedure TNextGenJsonWriter.WriteRawBytes(APtr: Pointer; ALength: Integer);
begin
  if ALength > 0 then
  begin
    EnsureCapacity(ALength);
    Move(APtr^, FBuffer[FLength], ALength);
    Inc(FLength, ALength);
  end;
end;

procedure TNextGenJsonWriter.WriteCommaIfNeeded;
begin
  if FNeedComma then
  begin
    WriteRawByte(Ord(','));
    FNeedComma := False;
  end;
end;

procedure TNextGenJsonWriter.StartObject;
begin
  if FNeedComma then
    WriteRawByte(Ord(','));
  WriteRawByte(Ord('{'));
  FNeedComma := False;
end;

procedure TNextGenJsonWriter.EndObject;
begin
  WriteRawByte(Ord('}'));
  FNeedComma := True;
end;

procedure TNextGenJsonWriter.StartArray;
begin
  if FNeedComma then
    WriteRawByte(Ord(','));
  WriteRawByte(Ord('['));
  FNeedComma := False;
end;

procedure TNextGenJsonWriter.EndArray;
begin
  WriteRawByte(Ord(']'));
  FNeedComma := True;
end;

procedure TNextGenJsonWriter.WritePropertyName(const AName: string);
begin
  if FNeedComma then
    WriteRawByte(Ord(','));
  WriteEscapedString(AName);
  WriteRawByte(Ord(':'));
  FNeedComma := False;
end;

procedure TNextGenJsonWriter.WritePropertyName(const AKey: TByteSpan);
begin
  if FNeedComma then
    WriteRawByte(Ord(','));
  WriteRawByte(Ord('"'));
  WriteRawBytes(AKey.Data, AKey.Length);
  WriteRawByte(Ord('"'));
  WriteRawByte(Ord(':'));
  FNeedComma := False;
end;

procedure TNextGenJsonWriter.WriteStringValue(const AValue: string);
begin
  WriteCommaIfNeeded;
  WriteEscapedString(AValue);
  FNeedComma := True;
end;

procedure TNextGenJsonWriter.WriteStringValue(const AValue: TByteSpan);
begin
  WriteCommaIfNeeded;
  WriteRawByte(Ord('"'));
  WriteRawBytes(AValue.Data, AValue.Length);
  WriteRawByte(Ord('"'));
  FNeedComma := True;
end;

procedure TNextGenJsonWriter.WriteRawValue(const AValue: TByteSpan);
begin
  WriteCommaIfNeeded;
  WriteRawBytes(AValue.Data, AValue.Length);
  FNeedComma := True;
end;

procedure TNextGenJsonWriter.WriteNumber(AValue: Int64);
var
  S: string;
  U8: TBytes;
begin
  WriteCommaIfNeeded;
  S := IntToStr(AValue);
  U8 := TEncoding.UTF8.GetBytes(S);
  WriteRawBytes(U8);
  FNeedComma := True;
end;

procedure TNextGenJsonWriter.WriteNumber(AValue: Double);
var
  S: string;
  U8: TBytes;
begin
  WriteCommaIfNeeded;
  S := FloatToStr(AValue, TFormatSettings.Invariant);
  U8 := TEncoding.UTF8.GetBytes(S);
  WriteRawBytes(U8);
  FNeedComma := True;
end;

procedure TNextGenJsonWriter.WriteBoolean(AValue: Boolean);
begin
  WriteCommaIfNeeded;
  if AValue then
  begin
    EnsureCapacity(4);
    FBuffer[FLength] := Ord('t');
    FBuffer[FLength+1] := Ord('r');
    FBuffer[FLength+2] := Ord('u');
    FBuffer[FLength+3] := Ord('e');
    Inc(FLength, 4);
  end
  else
  begin
    EnsureCapacity(5);
    FBuffer[FLength] := Ord('f');
    FBuffer[FLength+1] := Ord('a');
    FBuffer[FLength+2] := Ord('l');
    FBuffer[FLength+3] := Ord('s');
    FBuffer[FLength+4] := Ord('e');
    Inc(FLength, 5);
  end;
  FNeedComma := True;
end;

procedure TNextGenJsonWriter.WriteNull;
begin
  WriteCommaIfNeeded;
  EnsureCapacity(4);
  FBuffer[FLength] := Ord('n');
  FBuffer[FLength+1] := Ord('u');
  FBuffer[FLength+2] := Ord('l');
  FBuffer[FLength+3] := Ord('l');
  Inc(FLength, 4);
  FNeedComma := True;
end;

procedure TNextGenJsonWriter.WriteEscapedString(const AValue: string);
var
  P: PChar;
  C: Char;
  C2: Word;
  Val: Cardinal;
begin
  WriteRawByte(Ord('"'));
  if AValue <> '' then
  begin
    P := PChar(AValue);
    while P^ <> #0 do
    begin
      C := P^;
      if (C >= ' ') and (C <= '~') and (C <> '"') and (C <> '\') then
      begin
        WriteRawByte(Byte(C));
      end
      else
      begin
        case C of
          '"': begin WriteRawByte(Ord('\')); WriteRawByte(Ord('"')); end;
          '\': begin WriteRawByte(Ord('\')); WriteRawByte(Ord('\')); end;
          #8: begin WriteRawByte(Ord('\')); WriteRawByte(Ord('b')); end;
          #9: begin WriteRawByte(Ord('\')); WriteRawByte(Ord('t')); end;
          #10: begin WriteRawByte(Ord('\')); WriteRawByte(Ord('n')); end;
          #12: begin WriteRawByte(Ord('\')); WriteRawByte(Ord('f')); end;
          #13: begin WriteRawByte(Ord('\')); WriteRawByte(Ord('r')); end;
        else
          if C < ' ' then
          begin
            WriteRawByte(Ord('\'));
            WriteRawByte(Ord('u'));
            WriteRawByte(Ord('0'));
            WriteRawByte(Ord('0'));
            WriteRawByte(Byte(GHex[Ord(C) shr 4]));
            WriteRawByte(Byte(GHex[Ord(C) and $F]));
          end
          else
          begin
            Val := Ord(C);
            if (Val >= $D800) and (Val <= $DBFF) then
            begin
              Inc(P);
              if P^ <> #0 then
              begin
                C2 := Ord(P^);
                Val := ((Val - Cardinal($D800)) shl 10) +
                  (Cardinal(C2) - Cardinal($DC00)) + Cardinal($10000);
              end;
            end;

            if Val <= $7F then
            begin
              WriteRawByte(Val);
            end
            else if Val <= $7FF then
            begin
              WriteRawByte($C0 or (Val shr 6));
              WriteRawByte($80 or (Val and $3F));
            end;
          end;
        end;
      end;
      Inc(P);
    end;
  end;
  WriteRawByte(Ord('"'));
end;

function TNextGenJsonWriter.ToBytes: TBytes;
begin
  SetLength(Result, FLength);
  if FLength > 0 then
    Move(FBuffer[0], Result[0], FLength);
end;

function TNextGenJsonWriter.ToString: string;
begin
  if FLength > 0 then
    Result := TEncoding.UTF8.GetString(FBuffer, 0, FLength)
  else
    Result := '';
end;

procedure TNextGenJsonWriter.SaveToFile(const AFileName: string);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(AFileName, fmCreate);
  try
    if FLength > 0 then
      FS.WriteBuffer(FBuffer[0], FLength);
  finally
    FS.Free;
  end;
end;

initialization
  FillChar(GWhitespace, SizeOf(GWhitespace), 0);
  GWhitespace[9] := 1;
  GWhitespace[10] := 1;
  GWhitespace[13] := 1;
  GWhitespace[32] := 1;

  FillChar(GStructural, SizeOf(GStructural), 0);
  GStructural[Ord('{')] := 1;
  GStructural[Ord('}')] := 1;
  GStructural[Ord('[')] := 1;
  GStructural[Ord(']')] := 1;
  GStructural[Ord(':')] := 1;
  GStructural[Ord(',')] := 1;
  GStructural[Ord('"')] := 1;
  GStructural[Ord('\')] := 1;

finalization
  TNextGenJsonPool.ClearPool;

end.
