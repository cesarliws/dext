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
unit Dext.Net.Mqtt.Parser;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Core.Span;

type
  /// <summary>
  ///   MQTT control packet types as defined in MQTT v3.1.1.
  /// </summary>
  TMqttPacketType = (
    mptReserved = 0,
    mptConnect = 1,
    mptConnAck = 2,
    mptPublish = 3,
    mptPubAck = 4,
    mptPubRec = 5,
    mptPubRel = 6,
    mptPubComp = 7,
    mptSubscribe = 8,
    mptSubAck = 9,
    mptUnsubscribe = 10,
    mptUnsubAck = 11,
    mptPingReq = 12,
    mptPingResp = 13,
    mptDisconnect = 14,
    mptReserved2 = 15
  );

  /// <summary>
  ///   High-performance stream reader for decoding raw MQTT protocol packets.
  /// </summary>
  TMqttReader = record
  private
    FBuffer: TByteSpan;
    FOffset: Integer;
  public
    /// <summary>Initializes a reader over a byte span.</summary>
    constructor Create(const ABuffer: TByteSpan);
    /// <summary>Attempts to read a single byte.</summary>
    function ReadByte(out AVal: Byte): Boolean;
    /// <summary>Attempts to read a two-byte word.</summary>
    function ReadWord(out AVal: Word): Boolean;
    /// <summary>Attempts to read a UTF-8 string prefixed with two-byte length.</summary>
    function ReadString(out AVal: string): Boolean;
    /// <summary>Attempts to read a raw byte array of specific length.</summary>
    function ReadBytes(ALen: Integer; out AVal: TBytes): Boolean;
    /// <summary>Returns true if the buffer has enough bytes left to read.</summary>
    function HasBytes(ALen: Integer): Boolean;
    /// <summary>The current read offset position.</summary>
    property Offset: Integer read FOffset write FOffset;
  end;

  /// <summary>
  ///   High-performance record-based dynamic buffer writer for encoding MQTT packets.
  /// </summary>
  TMqttWriter = record
  private
    FBuffer: TBytes;
    FLength: Integer;
    procedure EnsureCapacity(AAdditional: Integer);
  public
    /// <summary>Initializes the writer with pre-allocated buffer capacity.</summary>
    procedure Initialize;
    /// <summary>Writes a single byte.</summary>
    procedure WriteByte(AVal: Byte);
    /// <summary>Writes a two-byte word.</summary>
    procedure WriteWord(AVal: Word);
    /// <summary>Writes a length-prefixed UTF-8 string.</summary>
    procedure WriteString(const AStr: string);
    /// <summary>Writes a slice of a raw byte array.</summary>
    procedure WriteBytes(const ABytes: TBytes; AOffset, ALen: Integer); overload;
    /// <summary>Writes a raw byte array.</summary>
    procedure WriteBytes(const ABytes: TBytes); overload;
    /// <summary>Writes the remaining length integer using variable-byte encoding.</summary>
    procedure WriteRemainingLength(ALength: Integer);
    /// <summary>Exposes the written contents as a byte array.</summary>
    function ToBytes: TBytes;
  end;

  /// <summary>
  ///   Represents decoded MQTT fixed header properties.
  /// </summary>
  TMqttFixedHeader = record
    PacketType: TMqttPacketType;
    Flags: Byte;
    RemainingLength: Integer;
    HeaderLength: Integer;
  end;

  /// <summary>
  ///   Represents fields of a decoded CONNECT packet.
  /// </summary>
  TMqttConnectPacket = record
    ProtocolName: string;
    ProtocolLevel: Byte;
    ConnectFlags: Byte;
    KeepAlive: Word;
    ClientId: string;
    WillTopic: string;
    WillMessage: TBytes;
    Username: string;
    Password: string;
  end;

  /// <summary>
  ///   Represents fields of a decoded PUBLISH packet.
  /// </summary>
  TMqttPublishPacket = record
    Topic: string;
    PacketId: Word;
    Payload: TBytes;
    QoS: Byte;
    Retain: Boolean;
    Dup: Boolean;
  end;

  /// <summary>
  ///   Represents a topic filter subscription item.
  /// </summary>
  TMqttSubscribeTopic = record
    TopicFilter: string;
    RequestedQoS: Byte;
  end;

  /// <summary>
  ///   Represents fields of a decoded SUBSCRIBE packet.
  /// </summary>
  TMqttSubscribePacket = record
    PacketId: Word;
    Topics: TArray<TMqttSubscribeTopic>;
  end;

  /// <summary>
  ///   Represents fields of a decoded SUBACK packet.
  /// </summary>
  TMqttSubAckPacket = record
    PacketId: Word;
    ReturnCodes: TArray<Byte>;
  end;

  /// <summary>
  ///   Represents fields of a decoded UNSUBSCRIBE packet.
  /// </summary>
  TMqttUnsubscribePacket = record
    PacketId: Word;
    TopicFilters: TArray<string>;
  end;

/// <summary>Decodes the fixed header and remaining length from the socket buffer.</summary>
function DecodeFixedHeader(const ABuffer: TByteSpan; out AHeader: TMqttFixedHeader): Boolean;
/// <summary>Encodes a CONNACK packet into binary format.</summary>
function EncodeConnAck(AReturnCode: Byte; ASessionPresent: Boolean): TBytes;
/// <summary>Encodes a PINGRESP packet into binary format.</summary>
function EncodePingResp: TBytes;
/// <summary>Encodes a SUBACK packet into binary format.</summary>
function EncodeSubAck(APacketId: Word; const AReturnCodes: TArray<Byte>): TBytes;
/// <summary>Encodes an UNSUBACK packet into binary format.</summary>
function EncodeUnsubAck(APacketId: Word): TBytes;
/// <summary>Encodes a PUBACK packet into binary format.</summary>
function EncodePubAck(APacketId: Word): TBytes;
/// <summary>Encodes a PUBLISH packet into binary format.</summary>
function EncodePublish(const APacket: TMqttPublishPacket): TBytes;

/// <summary>Parses the payload of a CONNECT packet.</summary>
function ParseConnect(const APayload: TByteSpan; out APacket: TMqttConnectPacket): Boolean;
/// <summary>Parses the payload of a PUBLISH packet.</summary>
function ParsePublish(const APayload: TByteSpan; AFlags: Byte; out APacket: TMqttPublishPacket): Boolean;
/// <summary>Parses the payload of a SUBSCRIBE packet.</summary>
function ParseSubscribe(const APayload: TByteSpan; out APacket: TMqttSubscribePacket): Boolean;
/// <summary>Parses the payload of an UNSUBSCRIBE packet.</summary>
function ParseUnsubscribe(const APayload: TByteSpan; out APacket: TMqttUnsubscribePacket): Boolean;

implementation

{ TMqttReader }

constructor TMqttReader.Create(const ABuffer: TByteSpan);
begin
  FBuffer := ABuffer;
  FOffset := 0;
end;

function TMqttReader.ReadByte(out AVal: Byte): Boolean;
begin
  if FOffset < FBuffer.Length then
  begin
    AVal := FBuffer[FOffset];
    Inc(FOffset);
    Exit(True);
  end;
  AVal := 0;
  Result := False;
end;

function TMqttReader.ReadWord(out AVal: Word): Boolean;
begin
  if FOffset + 1 < FBuffer.Length then
  begin
    AVal := (Word(FBuffer[FOffset]) shl 8) or Word(FBuffer[FOffset + 1]);
    Inc(FOffset, 2);
    Exit(True);
  end;
  AVal := 0;
  Result := False;
end;

function TMqttReader.ReadString(out AVal: string): Boolean;
var
  len: Word;
begin
  AVal := '';
  if ReadWord(len) then
  begin
    if FOffset + len <= FBuffer.Length then
    begin
      if len > 0 then
        AVal := FBuffer.Slice(FOffset, len).ToString
      else
        AVal := '';
      Inc(FOffset, len);
      Exit(True);
    end;
  end;
  Result := False;
end;

function TMqttReader.ReadBytes(ALen: Integer; out AVal: TBytes): Boolean;
begin
  SetLength(AVal, 0);
  if (ALen >= 0) and (FOffset + ALen <= FBuffer.Length) then
  begin
    if ALen > 0 then
    begin
      SetLength(AVal, ALen);
      Move((FBuffer.Data + FOffset)^, AVal[0], ALen);
    end;
    Inc(FOffset, ALen);
    Exit(True);
  end;
  Result := False;
end;

function TMqttReader.HasBytes(ALen: Integer): Boolean;
begin
  Result := FOffset + ALen <= FBuffer.Length;
end;

{ TMqttWriter }

procedure TMqttWriter.EnsureCapacity(AAdditional: Integer);
var
  newCap: Integer;
begin
  if FLength + AAdditional > Length(FBuffer) then
  begin
    newCap := Length(FBuffer) * 2;
    if newCap < FLength + AAdditional then
      newCap := FLength + AAdditional + 64;
    SetLength(FBuffer, newCap);
  end;
end;

procedure TMqttWriter.Initialize;
begin
  SetLength(FBuffer, 64);
  FLength := 0;
end;

procedure TMqttWriter.WriteByte(AVal: Byte);
begin
  EnsureCapacity(1);
  FBuffer[FLength] := AVal;
  Inc(FLength);
end;

procedure TMqttWriter.WriteWord(AVal: Word);
begin
  EnsureCapacity(2);
  FBuffer[FLength] := Byte(AVal shr 8);
  FBuffer[FLength + 1] := Byte(AVal and $FF);
  Inc(FLength, 2);
end;

procedure TMqttWriter.WriteString(const AStr: string);
var
  utf8: TBytes;
begin
  if AStr = '' then
  begin
    WriteWord(0);
  end
  else
  begin
    utf8 := TEncoding.UTF8.GetBytes(AStr);
    WriteWord(Length(utf8));
    WriteBytes(utf8);
  end;
end;

procedure TMqttWriter.WriteBytes(const ABytes: TBytes; AOffset, ALen: Integer);
begin
  if ALen > 0 then
  begin
    EnsureCapacity(ALen);
    Move(ABytes[AOffset], FBuffer[FLength], ALen);
    Inc(FLength, ALen);
  end;
end;

procedure TMqttWriter.WriteBytes(const ABytes: TBytes);
begin
  WriteBytes(ABytes, 0, Length(ABytes));
end;

procedure TMqttWriter.WriteRemainingLength(ALength: Integer);
var
  b: Byte;
begin
  repeat
    b := ALength mod 128;
    ALength := ALength div 128;
    if ALength > 0 then
      b := b or 128;
    WriteByte(b);
  until ALength = 0;
end;

function TMqttWriter.ToBytes: TBytes;
begin
  SetLength(Result, FLength);
  if FLength > 0 then
    Move(FBuffer[0], Result[0], FLength);
end;

{ Global Helper Functions }

function DecodeFixedHeader(const ABuffer: TByteSpan; out AHeader: TMqttFixedHeader): Boolean;
var
  b: Byte;
  multiplier: Integer;
  encodedByte: Byte;
  bytesRead: Integer;
begin
  Result := False;
  AHeader.PacketType := mptReserved;
  AHeader.Flags := 0;
  AHeader.RemainingLength := 0;
  AHeader.HeaderLength := 0;

  if ABuffer.Length < 2 then
    Exit;

  b := ABuffer[0];
  AHeader.PacketType := TMqttPacketType(b shr 4);
  AHeader.Flags := b and $0F;

  multiplier := 1;
  bytesRead := 1;
  while bytesRead < ABuffer.Length do
  begin
    encodedByte := ABuffer[bytesRead];
    Inc(bytesRead);
    AHeader.RemainingLength := AHeader.RemainingLength + (encodedByte and 127) * multiplier;
    if multiplier > 128 * 128 * 128 then
      Exit; // Malformed Remaining Length
    multiplier := multiplier * 128;
    if (encodedByte and 128) = 0 then
    begin
      AHeader.HeaderLength := bytesRead;
      Result := True;
      Break;
    end;
  end;
end;

function EncodeConnAck(AReturnCode: Byte; ASessionPresent: Boolean): TBytes;
var
  writer: TMqttWriter;
begin
  writer.Initialize;
  writer.WriteByte((Ord(mptConnAck) shl 4));
  writer.WriteRemainingLength(2);
  if ASessionPresent then
    writer.WriteByte(1)
  else
    writer.WriteByte(0);
  writer.WriteByte(AReturnCode);
  Result := writer.ToBytes;
end;

function EncodePingResp: TBytes;
var
  writer: TMqttWriter;
begin
  writer.Initialize;
  writer.WriteByte((Ord(mptPingResp) shl 4));
  writer.WriteRemainingLength(0);
  Result := writer.ToBytes;
end;

function EncodeSubAck(APacketId: Word; const AReturnCodes: TArray<Byte>): TBytes;
var
  writer: TMqttWriter;
  len: Integer;
  i: Integer;
begin
  writer.Initialize;
  writer.WriteByte((Ord(mptSubAck) shl 4));
  len := 2 + Length(AReturnCodes);
  writer.WriteRemainingLength(len);
  writer.WriteWord(APacketId);
  for i := 0 to Length(AReturnCodes) - 1 do
    writer.WriteByte(AReturnCodes[i]);
  Result := writer.ToBytes;
end;

function EncodeUnsubAck(APacketId: Word): TBytes;
var
  writer: TMqttWriter;
begin
  writer.Initialize;
  writer.WriteByte((Ord(mptUnsubAck) shl 4));
  writer.WriteRemainingLength(2);
  writer.WriteWord(APacketId);
  Result := writer.ToBytes;
end;

function EncodePubAck(APacketId: Word): TBytes;
var
  writer: TMqttWriter;
begin
  writer.Initialize;
  writer.WriteByte((Ord(mptPubAck) shl 4));
  writer.WriteRemainingLength(2);
  writer.WriteWord(APacketId);
  Result := writer.ToBytes;
end;

function EncodePublish(const APacket: TMqttPublishPacket): TBytes;
var
  writer: TMqttWriter;
  payloadWriter: TMqttWriter;
  payloadBytes: TBytes;
  flags: Byte;
begin
  payloadWriter.Initialize;
  payloadWriter.WriteString(APacket.Topic);
  if APacket.QoS > 0 then
    payloadWriter.WriteWord(APacket.PacketId);
  if Length(APacket.Payload) > 0 then
    payloadWriter.WriteBytes(APacket.Payload);
  payloadBytes := payloadWriter.ToBytes;

  writer.Initialize;
  flags := 0;
  if APacket.Dup then flags := flags or 8;
  flags := flags or ((APacket.QoS and 3) shl 1);
  if APacket.Retain then flags := flags or 1;

  writer.WriteByte((Ord(mptPublish) shl 4) or flags);
  writer.WriteRemainingLength(Length(payloadBytes));
  writer.WriteBytes(payloadBytes);
  Result := writer.ToBytes;
end;

function ParseConnect(const APayload: TByteSpan; out APacket: TMqttConnectPacket): Boolean;
var
  reader: TMqttReader;
  protocolName: string;
  protocolLevel: Byte;
  connectFlags: Byte;
  keepAlive: Word;
  hasWill: Boolean;
  hasUsername: Boolean;
  hasPassword: Boolean;
  willLen: Word;
begin
  Result := False;
  FillChar(APacket, SizeOf(APacket), 0);
  reader := TMqttReader.Create(APayload);

  if not reader.ReadString(protocolName) then Exit;
  if (protocolName <> 'MQTT') and (protocolName <> 'MQIsdp') then Exit;
  APacket.ProtocolName := protocolName;

  if not reader.ReadByte(protocolLevel) then Exit;
  APacket.ProtocolLevel := protocolLevel;

  if not reader.ReadByte(connectFlags) then Exit;
  APacket.ConnectFlags := connectFlags;

  if not reader.ReadWord(keepAlive) then Exit;
  APacket.KeepAlive := keepAlive;

  if not reader.ReadString(APacket.ClientId) then Exit;

  hasWill := (connectFlags and 4) <> 0;
  hasUsername := (connectFlags and 128) <> 0;
  hasPassword := (connectFlags and 64) <> 0;

  if hasWill then
  begin
    if not reader.ReadString(APacket.WillTopic) then Exit;
    if not reader.ReadWord(willLen) then Exit;
    if not reader.ReadBytes(willLen, APacket.WillMessage) then Exit;
  end;

  if hasUsername then
  begin
    if not reader.ReadString(APacket.Username) then Exit;
  end;

  if hasPassword then
  begin
    if not reader.ReadString(APacket.Password) then Exit;
  end;

  Result := True;
end;

function ParsePublish(const APayload: TByteSpan; AFlags: Byte; out APacket: TMqttPublishPacket): Boolean;
var
  reader: TMqttReader;
  remainingBytes: Integer;
begin
  Result := False;
  FillChar(APacket, SizeOf(APacket), 0);
  reader := TMqttReader.Create(APayload);

  APacket.Dup := (AFlags and 8) <> 0;
  APacket.QoS := (AFlags shr 1) and 3;
  APacket.Retain := (AFlags and 1) <> 0;

  if not reader.ReadString(APacket.Topic) then Exit;

  if APacket.QoS > 0 then
  begin
    if not reader.ReadWord(APacket.PacketId) then Exit;
  end;

  remainingBytes := APayload.Length - reader.Offset;
  if remainingBytes > 0 then
  begin
    if not reader.ReadBytes(remainingBytes, APacket.Payload) then Exit;
  end;

  Result := True;
end;

function ParseSubscribe(const APayload: TByteSpan; out APacket: TMqttSubscribePacket): Boolean;
var
  reader: TMqttReader;
  topic: TMqttSubscribeTopic;
begin
  Result := False;
  FillChar(APacket, SizeOf(APacket), 0);
  reader := TMqttReader.Create(APayload);

  if not reader.ReadWord(APacket.PacketId) then Exit;

  while reader.Offset < APayload.Length do
  begin
    if not reader.ReadString(topic.TopicFilter) then Exit;
    if not reader.ReadByte(topic.RequestedQoS) then Exit;
    SetLength(APacket.Topics, Length(APacket.Topics) + 1);
    APacket.Topics[Length(APacket.Topics) - 1] := topic;
  end;

  Result := Length(APacket.Topics) > 0;
end;

function ParseUnsubscribe(const APayload: TByteSpan; out APacket: TMqttUnsubscribePacket): Boolean;
var
  reader: TMqttReader;
  topicFilter: string;
begin
  Result := False;
  FillChar(APacket, SizeOf(APacket), 0);
  reader := TMqttReader.Create(APayload);

  if not reader.ReadWord(APacket.PacketId) then Exit;

  while reader.Offset < APayload.Length do
  begin
    if not reader.ReadString(topicFilter) then Exit;
    SetLength(APacket.TopicFilters, Length(APacket.TopicFilters) + 1);
    APacket.TopicFilters[Length(APacket.TopicFilters) - 1] := topicFilter;
  end;

  Result := Length(APacket.TopicFilters) > 0;
end;

end.
