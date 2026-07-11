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
  System.SysUtils,
  System.Classes,
  Dext.Core.Span,
  Dext.Json.Types,
  Dext.Collections.Simd;

type
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
    FNodeRef: IDextJsonNode;
  public
    procedure Init(AType: TDextJsonNodeType; const ASpan: TByteSpan);
    property NodeType: TDextJsonNodeType read FType;
    property ValueSpan: TByteSpan read FValueSpan;
    property NodeRef: IDextJsonNode read FNodeRef;

    function AsString: string;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsDouble: Double;
    function AsBoolean: Boolean;
    function IsNull: Boolean;
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
    FPos: Integer;
    FLen: Integer;
    class function ScanStringEnd(
      const AData: TByteSpan;
      var Pos: Integer;
      Len: Integer
    ): Integer; static; inline;
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
      const AData: TByteSpan
    ): IDextJsonNode; static;
  end;

  /// <summary>
  ///   Objeto JSON baseado em Spans.
  /// </summary>
  TNextGenJsonObject = class(TInterfacedObject, IDextJsonNode, IDextJsonObject)
  private
    FKeys: TArray<TJsonKey>;
    FValues: TArray<TNextGenJsonValue>;
    FCount: Integer;
    function FindKey(const Name: string): Integer;
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
  FNodeRef := nil;
end;

function TNextGenJsonValue.AsString: string;
begin
  if FType = TDextJsonNodeType.jntNull then
    Result := ''
  else
    Result := FValueSpan.ToString;
end;

function TNextGenJsonValue.AsInteger: Integer;
begin
  Result := Integer(AsInt64);
end;

function TNextGenJsonValue.AsInt64: Int64;
begin
  Result := TNextGenJsonParser.ParseInt64(FValueSpan);
end;

function TNextGenJsonValue.AsDouble: Double;
begin
  Result := TNextGenJsonParser.ParseNumber(FValueSpan);
end;

function TNextGenJsonValue.AsBoolean: Boolean;
begin
  if FType = TDextJsonNodeType.jntBoolean then
    Result := FValueSpan.EqualsString('true')
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

class function TNextGenJsonParser.ScanStringEnd(
  const AData: TByteSpan;
  var Pos: Integer;
  Len: Integer
): Integer;
var
  B: Byte;
begin
  while Pos < Len do
  begin
    B := AData.Data[Pos];
    if B = Ord('"') then
      Exit(Pos)
    else if B = Ord('\') then
      Inc(Pos);
    Inc(Pos);
  end;
  Result := Pos;
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
{$IFDEF CPUX64}
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
  Obj: TNextGenJsonObject;
  KeySpan: TByteSpan;
  Val: TNextGenJsonValue;
  StartKey: Integer;
begin
  Obj := TNextGenJsonPool.RentObject;
  Inc(FPos); // Pula '{'
  while FPos < FLen do
  begin
    while (FPos < FLen) and (GWhitespace[FData.Data[FPos]] <> 0) do
      Inc(FPos);
    if (FPos < FLen) and (FData.Data[FPos] = Ord('}')) then
    begin
      Inc(FPos);
      Exit(Obj);
    end;

    if (FPos < FLen) and (FData.Data[FPos] = Ord('"')) then
    begin
      Inc(FPos);
      StartKey := FPos;
      ScanStringEnd(FData, FPos, FLen);
      KeySpan := FData.Slice(StartKey, FPos - StartKey);
      Inc(FPos); // Pula '"'

      while (FPos < FLen) and (GWhitespace[FData.Data[FPos]] <> 0) do
        Inc(FPos);
      if (FPos < FLen) and (FData.Data[FPos] = Ord(':')) then
      begin
        Inc(FPos);
        Val := ParseValue;
        Obj.AddPair(KeySpan, Val);
      end;
    end;

    while (FPos < FLen) and (GWhitespace[FData.Data[FPos]] <> 0) do
      Inc(FPos);
    if (FPos < FLen) and (FData.Data[FPos] = Ord(',')) then
      Inc(FPos)
    else if (FPos < FLen) and (FData.Data[FPos] = Ord('}')) then
    begin
      Inc(FPos);
      Break;
    end;
  end;
  Result := Obj;
end;

function TNextGenJsonParser.ParseArray: IDextJsonArray;
var
  Arr: TNextGenJsonArray;
  Val: TNextGenJsonValue;
begin
  Arr := TNextGenJsonPool.RentArray;
  Inc(FPos); // Pula '['
  while FPos < FLen do
  begin
    while (FPos < FLen) and (GWhitespace[FData.Data[FPos]] <> 0) do
      Inc(FPos);
    if (FPos < FLen) and (FData.Data[FPos] = Ord(']')) then
    begin
      Inc(FPos);
      Exit(Arr);
    end;

    Val := ParseValue;
    Arr.AddValue(Val);

    while (FPos < FLen) and (GWhitespace[FData.Data[FPos]] <> 0) do
      Inc(FPos);
    if (FPos < FLen) and (FData.Data[FPos] = Ord(',')) then
      Inc(FPos)
    else if (FPos < FLen) and (FData.Data[FPos] = Ord(']')) then
    begin
      Inc(FPos);
      Break;
    end;
  end;
  Result := Arr;
end;

function TNextGenJsonParser.ParseValue: TNextGenJsonValue;
var
  StartPos: Integer;
  Val: TNextGenJsonValue;
  B: Byte;
  ValSpan: TByteSpan;
begin
  while (FPos < FLen) and (GWhitespace[FData.Data[FPos]] <> 0) do
    Inc(FPos);
  if FPos >= FLen then
  begin
    Val.Init(TDextJsonNodeType.jntNull, TByteSpan.Create(nil, 0));
    Exit(Val);
  end;

  B := FData.Data[FPos];
  if B = Ord('{') then
  begin
    Val.Init(
      TDextJsonNodeType.jntObject,
      TByteSpan.Create(FData.Data + FPos, 0)
    );
    Val.FNodeRef := ParseObject;
    Exit(Val);
  end;

  if B = Ord('[') then
  begin
    Val.Init(
      TDextJsonNodeType.jntArray,
      TByteSpan.Create(FData.Data + FPos, 0)
    );
    Val.FNodeRef := ParseArray;
    Exit(Val);
  end;

  if B = Ord('"') then
  begin
    Inc(FPos);
    StartPos := FPos;
    ScanStringEnd(FData, FPos, FLen);
    Val.Init(
      TDextJsonNodeType.jntString,
      FData.Slice(StartPos, FPos - StartPos)
    );
    Inc(FPos); // Pula '"'
    Exit(Val);
  end;

  StartPos := FPos;
  while (FPos < FLen) and (GWhitespace[FData.Data[FPos]] = 0)
    and (FData.Data[FPos] <> Ord(','))
    and (FData.Data[FPos] <> Ord('}'))
    and (FData.Data[FPos] <> Ord(']')) do
  begin
    Inc(FPos);
  end;

  ValSpan := FData.Slice(StartPos, FPos - StartPos);
  if ValSpan.EqualsString('true') then
    Val.Init(TDextJsonNodeType.jntBoolean, ValSpan)
  else if ValSpan.EqualsString('false') then
    Val.Init(TDextJsonNodeType.jntBoolean, ValSpan)
  else if ValSpan.EqualsString('null') then
    Val.Init(TDextJsonNodeType.jntNull, ValSpan)
  else
    Val.Init(TDextJsonNodeType.jntNumber, ValSpan);

  Result := Val;
end;

class function TNextGenJsonParser.Parse(
  const AData: TByteSpan
): IDextJsonNode;
var
  Parser: TNextGenJsonParser;
begin
  Parser.FData := AData;
  Parser.FPos := 0;
  Parser.FLen := AData.Length;

  while (Parser.FPos < Parser.FLen) and (GWhitespace[Parser.FData.Data[Parser.FPos]] <> 0) do
    Inc(Parser.FPos);

  if (Parser.FPos < Parser.FLen) and (Parser.FData.Data[Parser.FPos] = Ord('{')) then
    Result := Parser.ParseObject
  else if (Parser.FPos < Parser.FLen) and (Parser.FData.Data[Parser.FPos] = Ord('[')) then
    Result := Parser.ParseArray
  else
    Result := TNextGenJsonPrimitive.Create(Parser.ParseValue);
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
  SetLength(FKeys, 0);
  SetLength(FValues, 0);
  FCount := 0;
end;

destructor TNextGenJsonObject.Destroy;
begin
  inherited Destroy;
end;

function TNextGenJsonObject.FindKey(const Name: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if FKeys[I].EqualsString(Name) then
      Exit(I);
  Result := -1;
end;

procedure TNextGenJsonObject.AddPair(
  const AKey: TByteSpan;
  const AValue: TNextGenJsonValue
);
begin
  if FCount >= Length(FKeys) then
  begin
    SetLength(FKeys, FCount + 8);
    SetLength(FValues, FCount + 8);
  end;
  FKeys[FCount].Span := AKey;
  FKeys[FCount].StrValue := '';
  FValues[FCount] := AValue;
  Inc(FCount);
end;

procedure TNextGenJsonObject.AddPair(
  const AKey: string;
  const AValue: TNextGenJsonValue
);
begin
  if FCount >= Length(FKeys) then
  begin
    SetLength(FKeys, FCount + 8);
    SetLength(FValues, FCount + 8);
  end;
  FKeys[FCount].Span := TByteSpan.Create(nil, 0);
  FKeys[FCount].StrValue := AKey;
  FValues[FCount] := AValue;
  Inc(FCount);
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

function TNextGenJsonObject.ToJson(Indented: Boolean): string;
var
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('{');
    for I := 0 to FCount - 1 do
    begin
      if I > 0 then
        SB.Append(',');
      SB.Append('"').Append(FKeys[I].ToString).Append('":');
      if FValues[I].NodeType = TDextJsonNodeType.jntString then
        SB.Append('"').Append(FValues[I].AsString).Append('"')
      else
        SB.Append(FValues[I].AsString);
    end;
    SB.Append('}');
    Result := SB.ToString;
  finally
    SB.Free;
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
    if (FValues[Idx].NodeType = TDextJsonNodeType.jntObject) or
       (FValues[Idx].NodeType = TDextJsonNodeType.jntArray) then
      Result := FValues[Idx].FNodeRef
    else
      Result := TNextGenJsonPrimitive.Create(FValues[Idx]);
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
    Result := FValues[Idx].AsString
  else
    Result := '';
end;

function TNextGenJsonObject.GetInteger(const Name: string): Integer;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
    Result := FValues[Idx].AsInteger
  else
    Result := 0;
end;

function TNextGenJsonObject.GetInt64(const Name: string): Int64;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
    Result := FValues[Idx].AsInt64
  else
    Result := 0;
end;

function TNextGenJsonObject.GetDouble(const Name: string): Double;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
    Result := FValues[Idx].AsDouble
  else
    Result := 0.0;
end;

function TNextGenJsonObject.GetBoolean(const Name: string): Boolean;
var
  Idx: Integer;
begin
  Idx := FindKey(Name);
  if Idx >= 0 then
    Result := FValues[Idx].AsBoolean
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
    Result := FKeys[Index].ToString
  else
    Result := '';
end;

procedure TNextGenJsonObject.SetString(const Name, Value: string);
begin
end;

procedure TNextGenJsonObject.SetInteger(const Name: string; Value: Integer);
begin
end;

procedure TNextGenJsonObject.SetInt64(const Name: string; Value: Int64);
begin
end;

procedure TNextGenJsonObject.SetDouble(const Name: string; Value: Double);
begin
end;

procedure TNextGenJsonObject.SetBoolean(const Name: string; Value: Boolean);
begin
end;

procedure TNextGenJsonObject.SetObject(
  const Name: string;
  Value: IDextJsonObject
);
begin
end;

procedure TNextGenJsonObject.SetArray(
  const Name: string;
  Value: IDextJsonArray
);
begin
end;

procedure TNextGenJsonObject.SetNode(const Name: string; Value: IDextJsonNode);
begin
end;

procedure TNextGenJsonObject.SetNull(const Name: string);
begin
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
begin
  if FCount >= Length(FValues) then
    SetLength(FValues, FCount + 8);
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
  SB: TStringBuilder;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('[');
    for I := 0 to FCount - 1 do
    begin
      if I > 0 then
        SB.Append(',');
      if FValues[I].NodeType = TDextJsonNodeType.jntString then
        SB.Append('"').Append(FValues[I].AsString).Append('"')
      else
        SB.Append(FValues[I].AsString);
    end;
    SB.Append(']');
    Result := SB.ToString;
  finally
    SB.Free;
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
begin
end;

procedure TNextGenJsonArray.Add(Value: Integer);
begin
end;

procedure TNextGenJsonArray.Add(Value: Int64);
begin
end;

procedure TNextGenJsonArray.Add(Value: Double);
begin
end;

procedure TNextGenJsonArray.Add(Value: Boolean);
begin
end;

procedure TNextGenJsonArray.Add(Value: IDextJsonObject);
begin
end;

procedure TNextGenJsonArray.Add(Value: IDextJsonArray);
begin
end;

procedure TNextGenJsonArray.AddNull;
begin
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
begin
  if GetNodeType = TDextJsonNodeType.jntString then
    Result := '"' + AsString + '"'
  else
    Result := AsString;
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
    AnObj.FValues[I].FNodeRef := nil;
  AnObj.FCount := 0;

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

  if FArrayCount < 1024 then
  begin
    FArrayPool[FArrayCount] := AnArr;
    Inc(FArrayCount);
  end
  else
    AnArr.Free;
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

end.
