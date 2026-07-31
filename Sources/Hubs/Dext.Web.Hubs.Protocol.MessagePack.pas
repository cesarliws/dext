{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           SignalR-compatible MessagePack Hub Protocol.                    }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs.Protocol.MessagePack;

{$I Dext.inc}

interface

uses
  System.Rtti,
  System.SysUtils,
  Dext.Web.Hubs.Interfaces;

type
  TMessagePackHubProtocol = class(TInterfacedObject, IHubProtocol)
  public
    function GetName: string;
    function GetVersion: Integer;
    function GetTransferFormat: string;
    function Serialize(const Message: THubMessage): string;
    function Deserialize(const Data: string): THubMessage;
    function SerializeBinary(const Message: THubMessage): TBytes;
    function DeserializeBinary(const Data: TBytes; AOffset, ACount: Integer;
      out AConsumed: Integer): THubMessage;
    function IsCompleteMessage(const Data: string): Boolean;
    function IsCompleteBinary(const Data: TBytes; AOffset, ACount: Integer): Boolean;
  end;

implementation

uses
  System.TypInfo;

type
  TMsgPackWriter = record
  private
    FBuffer: TBytes;
    FLength: Integer;
    procedure Ensure(ACount: Integer);
    procedure PutByte(AValue: Byte);
    procedure PutBE16(AValue: Word);
    procedure PutBE32(AValue: Cardinal);
    procedure PutBE64(AValue: UInt64);
  public
    procedure WriteNil;
    procedure WriteBool(AValue: Boolean);
    procedure WriteInt(AValue: Int64);
    procedure WriteUInt(AValue: UInt64);
    procedure WriteDouble(AValue: Double);
    procedure WriteString(const AValue: string);
    procedure WriteArrayHeader(ACount: Integer);
    procedure WriteMapHeader(ACount: Integer);
    procedure WriteValue(const AValue: TValue);
    function Finish: TBytes;
  end;

  TMsgPackReader = record
  private
    FData: TBytes;
    FPos: Integer;
    FLimit: Integer;
    function ReadByte: Byte;
    function ReadBE16: Word;
    function ReadBE32: Cardinal;
    function ReadBE64: UInt64;
  public
    procedure Init(const AData: TBytes; AOffset, ACount: Integer);
    function ReadArrayHeader: Integer;
    function ReadMapHeader: Integer;
    function ReadStringOrNil: string;
    function ReadValue: TValue;
    procedure SkipValue;
    property Position: Integer read FPos;
  end;

procedure TMsgPackWriter.Ensure(ACount: Integer);
var
  Capacity: Integer;
begin
  if FLength + ACount <= Length(FBuffer) then
    Exit;
  Capacity := Length(FBuffer);
  if Capacity = 0 then
    Capacity := 128;
  while Capacity < FLength + ACount do
    Capacity := Capacity * 2;
  SetLength(FBuffer, Capacity);
end;

procedure TMsgPackWriter.PutByte(AValue: Byte);
begin
  Ensure(1);
  FBuffer[FLength] := AValue;
  Inc(FLength);
end;

procedure TMsgPackWriter.PutBE16(AValue: Word);
begin
  Ensure(2);
  FBuffer[FLength] := Byte(AValue shr 8);
  FBuffer[FLength + 1] := Byte(AValue);
  Inc(FLength, 2);
end;

procedure TMsgPackWriter.PutBE32(AValue: Cardinal);
begin
  Ensure(4);
  FBuffer[FLength] := Byte(AValue shr 24);
  FBuffer[FLength + 1] := Byte(AValue shr 16);
  FBuffer[FLength + 2] := Byte(AValue shr 8);
  FBuffer[FLength + 3] := Byte(AValue);
  Inc(FLength, 4);
end;

procedure TMsgPackWriter.PutBE64(AValue: UInt64);
begin
  PutBE32(Cardinal(AValue shr 32));
  PutBE32(Cardinal(AValue));
end;

procedure TMsgPackWriter.WriteNil;
begin
  PutByte($C0);
end;

procedure TMsgPackWriter.WriteBool(AValue: Boolean);
begin
  if AValue then PutByte($C3) else PutByte($C2);
end;

procedure TMsgPackWriter.WriteUInt(AValue: UInt64);
begin
  if AValue <= $7F then PutByte(Byte(AValue))
  else if AValue <= $FF then begin PutByte($CC); PutByte(Byte(AValue)); end
  else if AValue <= $FFFF then begin PutByte($CD); PutBE16(Word(AValue)); end
  else if AValue <= $FFFFFFFF then begin PutByte($CE); PutBE32(Cardinal(AValue)); end
  else begin PutByte($CF); PutBE64(AValue); end;
end;

procedure TMsgPackWriter.WriteInt(AValue: Int64);
begin
  if AValue >= 0 then
    WriteUInt(UInt64(AValue))
  else if AValue >= -32 then
    PutByte(Byte(ShortInt(AValue)))
  else if AValue >= Low(ShortInt) then
  begin
    PutByte($D0); PutByte(Byte(ShortInt(AValue)));
  end
  else if AValue >= Low(SmallInt) then
  begin
    PutByte($D1); PutBE16(Word(SmallInt(AValue)));
  end
  else if AValue >= Low(Integer) then
  begin
    PutByte($D2); PutBE32(Cardinal(Integer(AValue)));
  end
  else
  begin
    PutByte($D3); PutBE64(UInt64(AValue));
  end;
end;

procedure TMsgPackWriter.WriteDouble(AValue: Double);
var
  Bits: UInt64 absolute AValue;
begin
  PutByte($CB);
  PutBE64(Bits);
end;

procedure TMsgPackWriter.WriteString(const AValue: string);
var
  Bytes: TBytes;
  Count: Integer;
begin
  Bytes := TEncoding.UTF8.GetBytes(AValue);
  Count := Length(Bytes);
  if Count <= 31 then PutByte($A0 or Byte(Count))
  else if Count <= $FF then begin PutByte($D9); PutByte(Byte(Count)); end
  else if Count <= $FFFF then begin PutByte($DA); PutBE16(Word(Count)); end
  else begin PutByte($DB); PutBE32(Cardinal(Count)); end;
  if Count > 0 then
  begin
    Ensure(Count);
    Move(Bytes[0], FBuffer[FLength], Count);
    Inc(FLength, Count);
  end;
end;

procedure TMsgPackWriter.WriteArrayHeader(ACount: Integer);
begin
  if ACount < 0 then
    raise EArgumentOutOfRangeException.Create('Negative MessagePack array size');
  if ACount <= 15 then PutByte($90 or Byte(ACount))
  else if ACount <= $FFFF then begin PutByte($DC); PutBE16(Word(ACount)); end
  else begin PutByte($DD); PutBE32(Cardinal(ACount)); end;
end;

procedure TMsgPackWriter.WriteMapHeader(ACount: Integer);
begin
  if ACount < 0 then
    raise EArgumentOutOfRangeException.Create('Negative MessagePack map size');
  if ACount <= 15 then PutByte($80 or Byte(ACount))
  else if ACount <= $FFFF then begin PutByte($DE); PutBE16(Word(ACount)); end
  else begin PutByte($DF); PutBE32(Cardinal(ACount)); end;
end;

procedure TMsgPackWriter.WriteValue(const AValue: TValue);
var
  I: Integer;
begin
  if AValue.IsEmpty then
  begin
    WriteNil;
    Exit;
  end;
  case AValue.Kind of
    tkEnumeration:
      if AValue.TypeInfo = System.TypeInfo(Boolean) then
        WriteBool(AValue.AsBoolean)
      else
        WriteInt(AValue.AsOrdinal);
    tkInteger:
      WriteInt(AValue.AsInteger);
    tkInt64:
      WriteInt(AValue.AsInt64);
    tkFloat:
      WriteDouble(AValue.AsExtended);
    tkChar, tkWChar, tkString, tkLString, tkWString, tkUString:
      WriteString(AValue.ToString);
    tkDynArray, tkArray:
      begin
        WriteArrayHeader(AValue.GetArrayLength);
        for I := 0 to AValue.GetArrayLength - 1 do
          WriteValue(AValue.GetArrayElement(I));
      end;
  else
    raise EConvertError.CreateFmt('Unsupported MessagePack TValue kind %d',
      [Ord(AValue.Kind)]);
  end;
end;

function TMsgPackWriter.Finish: TBytes;
begin
  SetLength(FBuffer, FLength);
  Result := FBuffer;
end;

procedure TMsgPackReader.Init(const AData: TBytes; AOffset, ACount: Integer);
begin
  if (AOffset < 0) or (ACount < 0) or (AOffset > Length(AData) - ACount) then
    raise EArgumentOutOfRangeException.Create('Invalid MessagePack buffer range');
  FData := AData;
  FPos := AOffset;
  FLimit := AOffset + ACount;
end;

function TMsgPackReader.ReadByte: Byte;
begin
  if FPos >= FLimit then
    raise EConvertError.Create('Unexpected end of MessagePack payload');
  Result := FData[FPos];
  Inc(FPos);
end;

function TMsgPackReader.ReadBE16: Word;
begin
  Result := Word(ReadByte) shl 8;
  Result := Result or ReadByte;
end;

function TMsgPackReader.ReadBE32: Cardinal;
begin
  Result := Cardinal(ReadByte) shl 24;
  Result := Result or Cardinal(ReadByte) shl 16;
  Result := Result or Cardinal(ReadByte) shl 8;
  Result := Result or ReadByte;
end;

function TMsgPackReader.ReadBE64: UInt64;
begin
  Result := UInt64(ReadBE32) shl 32;
  Result := Result or ReadBE32;
end;

function TMsgPackReader.ReadArrayHeader: Integer;
var
  Code: Byte;
  Count: Cardinal;
begin
  Code := ReadByte;
  if (Code and $F0) = $90 then Exit(Code and $0F);
  if Code = $DC then Exit(ReadBE16);
  if Code <> $DD then
    raise EConvertError.Create('MessagePack array expected');
  Count := ReadBE32;
  if Count > Cardinal(MaxInt) then
    raise EConvertError.Create('MessagePack array is too large');
  Result := Integer(Count);
end;

function TMsgPackReader.ReadMapHeader: Integer;
var
  Code: Byte;
  Count: Cardinal;
begin
  Code := ReadByte;
  if (Code and $F0) = $80 then Exit(Code and $0F);
  if Code = $DE then Exit(ReadBE16);
  if Code <> $DF then
    raise EConvertError.Create('MessagePack map expected');
  Count := ReadBE32;
  if Count > Cardinal(MaxInt) then
    raise EConvertError.Create('MessagePack map is too large');
  Result := Integer(Count);
end;

function TMsgPackReader.ReadStringOrNil: string;
var
  Code: Byte;
  Count: Cardinal;
begin
  Code := ReadByte;
  if Code = $C0 then Exit('');
  if (Code and $E0) = $A0 then Count := Code and $1F
  else if Code = $D9 then Count := ReadByte
  else if Code = $DA then Count := ReadBE16
  else if Code = $DB then Count := ReadBE32
  else raise EConvertError.Create('MessagePack string expected');
  if Count > Cardinal(FLimit - FPos) then
    raise EConvertError.Create('Incomplete MessagePack string');
  Result := TEncoding.UTF8.GetString(FData, FPos, Count);
  Inc(FPos, Count);
end;

function TMsgPackReader.ReadValue: TValue;
var
  Code: Byte;
  Count, I: Integer;
  Items: TArray<TValue>;
  Bits: UInt64;
  Number: Double absolute Bits;
begin
  Code := ReadByte;
  if Code <= $7F then Exit(TValue.From<Integer>(Code));
  if Code >= $E0 then Exit(TValue.From<Integer>(ShortInt(Code)));
  if (Code and $E0) = $A0 then
  begin
    Dec(FPos);
    Exit(TValue.From<string>(ReadStringOrNil));
  end;
  if (Code and $F0) = $90 then
  begin
    Count := Code and $0F;
    SetLength(Items, Count);
    for I := 0 to Count - 1 do Items[I] := ReadValue;
    Exit(TValue.From<TArray<TValue>>(Items));
  end;
  case Code of
    $C0: Result := TValue.Empty;
    $C2: Result := TValue.From<Boolean>(False);
    $C3: Result := TValue.From<Boolean>(True);
    $CC: Result := TValue.From<Integer>(ReadByte);
    $CD: Result := TValue.From<Integer>(ReadBE16);
    $CE: Result := TValue.From<Int64>(ReadBE32);
    $CF: Result := TValue.From<UInt64>(ReadBE64);
    $D0: Result := TValue.From<Integer>(ShortInt(ReadByte));
    $D1: Result := TValue.From<Integer>(SmallInt(ReadBE16));
    $D2: Result := TValue.From<Integer>(Integer(ReadBE32));
    $D3: Result := TValue.From<Int64>(Int64(ReadBE64));
    $CB:
      begin
        Bits := ReadBE64;
        Result := TValue.From<Double>(Number);
      end;
    $D9, $DA, $DB:
      begin
        Dec(FPos);
        Result := TValue.From<string>(ReadStringOrNil);
      end;
    $DC, $DD:
      begin
        Dec(FPos);
        Count := ReadArrayHeader;
        SetLength(Items, Count);
        for I := 0 to Count - 1 do Items[I] := ReadValue;
        Result := TValue.From<TArray<TValue>>(Items);
      end;
  else
    raise EConvertError.CreateFmt('Unsupported MessagePack code %.2x', [Code]);
  end;
end;

procedure TMsgPackReader.SkipValue;
var
  Value: TValue;
begin
  Value := ReadValue;
end;

function TMessagePackHubProtocol.GetName: string;
begin
  Result := 'messagepack';
end;

function TMessagePackHubProtocol.GetVersion: Integer;
begin
  Result := 1;
end;

function TMessagePackHubProtocol.GetTransferFormat: string;
begin
  Result := 'Binary';
end;

function TMessagePackHubProtocol.Serialize(const Message: THubMessage): string;
begin
  raise EInvalidOp.Create('MessagePack Hub Protocol requires binary transport');
end;

function TMessagePackHubProtocol.Deserialize(const Data: string): THubMessage;
begin
  raise EInvalidOp.Create('MessagePack Hub Protocol requires binary transport');
end;

function TMessagePackHubProtocol.IsCompleteMessage(const Data: string): Boolean;
begin
  Result := False;
end;

function ReadVarInt(const Data: TBytes; AOffset, ACount: Integer;
  out AValue, ABytes: Integer): Boolean;
var
  I, Shift: Integer;
  B: Byte;
begin
  Result := False;
  AValue := 0;
  ABytes := 0;
  Shift := 0;
  for I := 0 to 4 do
  begin
    if I >= ACount then Exit;
    B := Data[AOffset + I];
    if (I = 4) and ((B and $F8) <> 0) then
      raise EConvertError.Create('Invalid SignalR VarInt length prefix');
    AValue := AValue or Integer(B and $7F) shl Shift;
    Inc(ABytes);
    if (B and $80) = 0 then Exit(True);
    Inc(Shift, 7);
  end;
  raise EConvertError.Create('Invalid SignalR VarInt length prefix');
end;

function AddVarIntPrefix(const Payload: TBytes): TBytes;
var
  Prefix: array[0..4] of Byte;
  PrefixLength, Value: Integer;
begin
  Value := Length(Payload);
  PrefixLength := 0;
  repeat
    Prefix[PrefixLength] := Byte(Value and $7F);
    Value := Value shr 7;
    if Value <> 0 then Prefix[PrefixLength] := Prefix[PrefixLength] or $80;
    Inc(PrefixLength);
  until Value = 0;
  SetLength(Result, PrefixLength + Length(Payload));
  Move(Prefix[0], Result[0], PrefixLength);
  if Length(Payload) > 0 then
    Move(Payload[0], Result[PrefixLength], Length(Payload));
end;

function TMessagePackHubProtocol.SerializeBinary(
  const Message: THubMessage): TBytes;
var
  Writer: TMsgPackWriter;
  Arg: TValue;
  ResultKind: Integer;
begin
  Writer := Default(TMsgPackWriter);
  case Message.MessageType of
    hmtInvocation, hmtStreamInvocation:
      begin
        Writer.WriteArrayHeader(6);
        Writer.WriteInt(Ord(Message.MessageType));
        Writer.WriteMapHeader(0);
        if Message.InvocationId = '' then Writer.WriteNil
        else Writer.WriteString(Message.InvocationId);
        Writer.WriteString(Message.Target);
        Writer.WriteArrayHeader(Length(Message.Arguments));
        for Arg in Message.Arguments do Writer.WriteValue(Arg);
        Writer.WriteArrayHeader(0);
      end;
    hmtCompletion:
      begin
        if Message.Error <> '' then ResultKind := 1
        else if Message.Result.IsEmpty then ResultKind := 2
        else ResultKind := 3;
        if ResultKind = 2 then Writer.WriteArrayHeader(4)
        else Writer.WriteArrayHeader(5);
        Writer.WriteInt(3);
        Writer.WriteMapHeader(0);
        Writer.WriteString(Message.InvocationId);
        Writer.WriteInt(ResultKind);
        if ResultKind = 1 then Writer.WriteString(Message.Error)
        else if ResultKind = 3 then Writer.WriteValue(Message.Result);
      end;
    hmtStreamItem:
      begin
        Writer.WriteArrayHeader(4);
        Writer.WriteInt(2);
        Writer.WriteMapHeader(0);
        Writer.WriteString(Message.InvocationId);
        Writer.WriteValue(Message.Result);
      end;
    hmtCancelInvocation:
      begin
        Writer.WriteArrayHeader(3);
        Writer.WriteInt(5);
        Writer.WriteMapHeader(0);
        Writer.WriteString(Message.InvocationId);
      end;
    hmtPing:
      begin
        Writer.WriteArrayHeader(1);
        Writer.WriteInt(6);
      end;
    hmtClose:
      begin
        Writer.WriteArrayHeader(3);
        Writer.WriteInt(7);
        if Message.Error = '' then Writer.WriteNil
        else Writer.WriteString(Message.Error);
        Writer.WriteBool(False);
      end;
  else
    raise EConvertError.Create('Unsupported SignalR MessagePack message type');
  end;
  Result := AddVarIntPrefix(Writer.Finish);
end;

function TMessagePackHubProtocol.DeserializeBinary(const Data: TBytes;
  AOffset, ACount: Integer; out AConsumed: Integer): THubMessage;
var
  PayloadLength, PrefixLength, Count, I, HeaderCount, ResultKind: Integer;
  Reader: TMsgPackReader;
  MessageTypeValue: TValue;
  ArgsValue: TValue;
begin
  AConsumed := 0;
  if not ReadVarInt(Data, AOffset, ACount, PayloadLength, PrefixLength) or
     (PayloadLength > ACount - PrefixLength) then
    raise EConvertError.Create('Incomplete SignalR MessagePack message');
  Reader.Init(Data, AOffset + PrefixLength, PayloadLength);
  Count := Reader.ReadArrayHeader;
  if Count < 1 then raise EConvertError.Create('Empty Hub message array');
  MessageTypeValue := Reader.ReadValue;
  Result := Default(THubMessage);
  Result.MessageType := THubMessageType(MessageTypeValue.AsInteger);
  case Result.MessageType of
    hmtInvocation, hmtStreamInvocation:
      begin
        if Count < 6 then raise EConvertError.Create('Invalid invocation layout');
        HeaderCount := Reader.ReadMapHeader;
        for I := 0 to HeaderCount - 1 do begin Reader.SkipValue; Reader.SkipValue; end;
        Result.InvocationId := Reader.ReadStringOrNil;
        Result.Target := Reader.ReadStringOrNil;
        ArgsValue := Reader.ReadValue;
        Result.Arguments := ArgsValue.AsType<TArray<TValue>>;
        Reader.SkipValue;
      end;
    hmtCompletion:
      begin
        if Count < 4 then raise EConvertError.Create('Invalid completion layout');
        HeaderCount := Reader.ReadMapHeader;
        for I := 0 to HeaderCount - 1 do begin Reader.SkipValue; Reader.SkipValue; end;
        Result.InvocationId := Reader.ReadStringOrNil;
        ResultKind := Reader.ReadValue.AsInteger;
        if ResultKind = 1 then Result.Error := Reader.ReadStringOrNil
        else if ResultKind = 3 then Result.Result := Reader.ReadValue;
      end;
    hmtStreamItem:
      begin
        if Count < 4 then raise EConvertError.Create('Invalid stream item layout');
        HeaderCount := Reader.ReadMapHeader;
        for I := 0 to HeaderCount - 1 do begin Reader.SkipValue; Reader.SkipValue; end;
        Result.InvocationId := Reader.ReadStringOrNil;
        Result.Result := Reader.ReadValue;
      end;
    hmtCancelInvocation:
      begin
        if Count < 3 then raise EConvertError.Create('Invalid cancel layout');
        HeaderCount := Reader.ReadMapHeader;
        for I := 0 to HeaderCount - 1 do begin Reader.SkipValue; Reader.SkipValue; end;
        Result.InvocationId := Reader.ReadStringOrNil;
      end;
    hmtPing: ;
    hmtClose:
      begin
        if Count > 1 then Result.Error := Reader.ReadStringOrNil;
        if Count > 2 then Reader.SkipValue;
      end;
  else
    raise EConvertError.Create('Unsupported Hub message type');
  end;
  AConsumed := PrefixLength + PayloadLength;
end;

function TMessagePackHubProtocol.IsCompleteBinary(const Data: TBytes;
  AOffset, ACount: Integer): Boolean;
var
  PayloadLength, PrefixLength: Integer;
begin
  Result := (AOffset >= 0) and (ACount >= 0) and
    (AOffset <= Length(Data) - ACount) and
    ReadVarInt(Data, AOffset, ACount, PayloadLength, PrefixLength) and
    (PayloadLength <= ACount - PrefixLength);
end;

end.
