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
unit Dext.Net.Mqtt;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Dext.Core.Span,
  Dext.Net.Tcp,
  Dext.Net.Mqtt.Parser,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Collections.HashSet;

type
  /// <summary>
  ///   Represents an MQTT message.
  /// </summary>
  TMqttMessage = record
    Topic: string;
    Payload: TBytes;
    QoS: Byte;
    Retain: Boolean;
  end;

  /// <summary>
  ///   Event raised when a client receives a PUBLISH message.
  /// </summary>
  TMqttMessageEvent = reference to procedure(const AMessage: TMqttMessage);

  /// <summary>
  ///   Represents a single node in the MQTT topic routing Trie.
  /// </summary>
  TDextMqttTrieNode = class
  public
    Token: string;
    Children: TList<TDextMqttTrieNode>;
    Subscribers: TList<string>;
    /// <summary>Initializes a node with a token.</summary>
    constructor Create(const AToken: string);
    /// <summary>Destroys children and subscribers.</summary>
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Trie tree router matching wildcards (+ and #) for MQTT subscriptions.
  /// </summary>
  TDextMqttTopicTrie = class
  private
    FRoot: TDextMqttTrieNode;
    FLock: TCriticalSection;
    procedure RecursiveMatch(ANode: TDextMqttTrieNode; const ATokens: TArray<string>; AIndex: Integer; AResults: IHashSet<string>);
  public
    /// <summary>Initializes the trie root node.</summary>
    constructor Create;
    /// <summary>Destroys the root node.</summary>
    destructor Destroy; override;
    /// <summary>Registers a subscription route for a client.</summary>
    procedure AddSubscription(const AFilter: string; const AClientId: string);
    /// <summary>Unregisters a subscription route for a client.</summary>
    procedure RemoveSubscription(const AFilter: string; const AClientId: string);
    /// <summary>Finds all client IDs matching a topic filter.</summary>
    function MatchTopic(const ATopic: string): TArray<string>;
  end;

  /// <summary>
  ///   MQTT Client component supporting v3.1.1 protocol.
  /// </summary>
  TDextMqttClient = class
  private
    FTcpClient: TDextTcpClient;
    FClientId: string;
    FKeepAlive: Word;
    FRunning: Boolean;
    FRecvThread: TThread;
    FPingThread: TThread;
    FOnMessage: TMqttMessageEvent;
    FPacketIdCounter: Word;
    function NextPacketId: Word;
    procedure RecvLoop;
    procedure PingLoop;
  public
    /// <summary>Initializes the client.</summary>
    constructor Create;
    /// <summary>Disconnects and destroys the client.</summary>
    destructor Destroy; override;
    /// <summary>Establishes an MQTT connection and finishes CONNACK handshake.</summary>
    procedure Connect(const AHost: string; APort: Word; const AClientId: string = '');
    /// <summary>Closes connection gracefully sending DISCONNECT frame.</summary>
    procedure Disconnect;
    /// <summary>Publishes binary data to the specified topic.</summary>
    procedure Publish(const ATopic: string; const APayload: TBytes; AQoS: Byte = 0; ARetain: Boolean = False);
    /// <summary>Subscribes to a topic filter with QoS constraints.</summary>
    procedure Subscribe(const ATopicFilter: string; AQoS: Byte = 0);
    /// <summary>Unsubscribes from a topic filter.</summary>
    procedure Unsubscribe(const ATopicFilter: string);
    /// <summary>The unique identifier of this client connection.</summary>
    property ClientId: string read FClientId;
    /// <summary>Event triggered on message receipt.</summary>
    property OnMessageReceived: TMqttMessageEvent read FOnMessage write FOnMessage;
  end;

  /// <summary>
  ///   Represents an active client session on the broker.
  /// </summary>
  TDextMqttSession = class
  public
    ClientId: string;
    Connection: ITcpConnection;
    Buffer: TBytes;
    BufferLen: Integer;
    /// <summary>Appends incoming bytes to the session receive buffer.</summary>
    procedure AppendData(const ASpan: TByteSpan);
    /// <summary>Shifts the buffer window left by removing processed bytes.</summary>
    procedure ShiftBuffer(ACount: Integer);
  end;

  /// <summary>
  ///   MQTT Server (Broker) component.
  /// </summary>
  TDextMqttServer = class
  private
    FTcpServer: TDextTcpServer;
    FTrie: TDextMqttTopicTrie;
    FSessions: TDictionary<UInt64, TDextMqttSession>;
    FClientIdToSession: TDictionary<string, TDextMqttSession>;
    FLock: TCriticalSection;

    procedure OnConnect(const AConnection: ITcpConnection);
    procedure OnDisconnect(const AConnection: ITcpConnection);
    procedure OnDataSpan(const AConnection: ITcpConnection; const AData: TByteSpan);
    procedure OnError(const AConnection: ITcpConnection; AException: Exception);

    procedure ProcessPacket(ASession: TDextMqttSession; const APacketBytes: TByteSpan; const AHeader: TMqttFixedHeader);
    procedure HandleConnect(ASession: TDextMqttSession; const APayload: TByteSpan);
    procedure HandlePublish(ASession: TDextMqttSession; AFlags: Byte; const APayload: TByteSpan);
    procedure HandleSubscribe(ASession: TDextMqttSession; const APayload: TByteSpan);
    procedure HandleUnsubscribe(ASession: TDextMqttSession; const APayload: TByteSpan);
    procedure HandlePingReq(ASession: TDextMqttSession);
    procedure HandleDisconnect(ASession: TDextMqttSession);
  public
    /// <summary>Initializes the broker server.</summary>
    constructor Create;
    /// <summary>Stops and destroys the broker server.</summary>
    destructor Destroy; override;
    /// <summary>Binds the broker to a socket interface.</summary>
    procedure Bind(const AAddress: string; APort: Word);
    /// <summary>Starts listening for connections.</summary>
    procedure Start;
    /// <summary>Stops the server.</summary>
    procedure Stop;
    /// <summary>Retrieves the actual server listening port.</summary>
    function GetListenPort: Word;
    /// <summary>Exposes the active listening port.</summary>
    property ListenPort: Word read GetListenPort;
  end;

implementation

{ TDextMqttTrieNode }

constructor TDextMqttTrieNode.Create(const AToken: string);
begin
  inherited Create;
  Token := AToken;
  Children := TList<TDextMqttTrieNode>.Create;
  Subscribers := TList<string>.Create;
end;

destructor TDextMqttTrieNode.Destroy;
var
  i: Integer;
begin
  for i := 0 to Children.Count - 1 do
    Children[i].Free;
  Children.Free;
  Subscribers.Free;
  inherited;
end;

{ TDextMqttTopicTrie }

constructor TDextMqttTopicTrie.Create;
begin
  inherited Create;
  FRoot := TDextMqttTrieNode.Create('');
  FLock := TCriticalSection.Create;
end;

destructor TDextMqttTopicTrie.Destroy;
begin
  FRoot.Free;
  FLock.Free;
  inherited;
end;

procedure TDextMqttTopicTrie.AddSubscription(const AFilter: string; const AClientId: string);
var
  tokens: TArray<string>;
  currentNode: TDextMqttTrieNode;
  token: string;
  found: Boolean;
  child: TDextMqttTrieNode;
begin
  FLock.Acquire;
  try
    tokens := AFilter.Split(['/']);
    currentNode := FRoot;

    for token in tokens do
    begin
      found := False;
      for child in currentNode.Children do
      begin
        if child.Token = token then
        begin
          currentNode := child;
          found := True;
          Break;
        end;
      end;

      if not found then
      begin
        child := TDextMqttTrieNode.Create(token);
        currentNode.Children.Add(child);
        currentNode := child;
      end;
    end;

    if not currentNode.Subscribers.Contains(AClientId) then
      currentNode.Subscribers.Add(AClientId);
  finally
    FLock.Release;
  end;
end;

procedure TDextMqttTopicTrie.RemoveSubscription(const AFilter: string; const AClientId: string);
var
  tokens: TArray<string>;
  currentNode: TDextMqttTrieNode;
  token: string;
  found: Boolean;
  child: TDextMqttTrieNode;
begin
  FLock.Acquire;
  try
    tokens := AFilter.Split(['/']);
    currentNode := FRoot;

    for token in tokens do
    begin
      found := False;
      for child in currentNode.Children do
      begin
        if child.Token = token then
        begin
          currentNode := child;
          found := True;
          Break;
        end;
      end;
      if not found then Exit;
    end;

    currentNode.Subscribers.Remove(AClientId);
  finally
    FLock.Release;
  end;
end;

function TDextMqttTopicTrie.MatchTopic(const ATopic: string): TArray<string>;
var
  tokens: TArray<string>;
  resultsSet: IHashSet<string>;
begin
  resultsSet := THashSet<string>.Create;
  FLock.Acquire;
  try
    tokens := ATopic.Split(['/']);
    RecursiveMatch(FRoot, tokens, 0, resultsSet);
    Result := resultsSet.ToArray;
  finally
    FLock.Release;
  end;
end;

procedure TDextMqttTopicTrie.RecursiveMatch(ANode: TDextMqttTrieNode; const ATokens: TArray<string>; AIndex: Integer; AResults: IHashSet<string>);
var
  child: TDextMqttTrieNode;
  sub: string;
begin
  for child in ANode.Children do
  begin
    if child.Token = '#' then
    begin
      for sub in child.Subscribers do
        AResults.Add(sub);
    end
    else if (child.Token = '+') or ((AIndex < Length(ATokens)) and (child.Token = ATokens[AIndex])) then
    begin
      if AIndex = Length(ATokens) - 1 then
      begin
        for sub in child.Subscribers do
          AResults.Add(sub);
      end
      else
      begin
        RecursiveMatch(child, ATokens, AIndex + 1, AResults);
      end;
    end;
  end;
end;

{ TDextMqttClient }

constructor TDextMqttClient.Create;
begin
  inherited Create;
  FTcpClient := TDextTcpClient.Create;
  FRunning := False;
  FPacketIdCounter := 0;
end;

destructor TDextMqttClient.Destroy;
begin
  Disconnect;
  FTcpClient.Free;
  inherited;
end;

function TDextMqttClient.NextPacketId: Word;
begin
  if FPacketIdCounter = $FFFF then
    FPacketIdCounter := 1
  else
    Inc(FPacketIdCounter);
  Result := FPacketIdCounter;
end;

procedure TDextMqttClient.Connect(const AHost: string; APort: Word; const AClientId: string);
var
  writer: TMqttWriter;
  payload: TBytes;
  response: TBytes;
  bytesRead: Integer;
  header: TMqttFixedHeader;
  span: TByteSpan;
  connAckResult: Byte;
begin
  if FRunning then
    Exit;

  FTcpClient.Connect(AHost, APort);

  if AClientId = '' then
    FClientId := 'dext_client_' + IntToStr(Random(100000))
  else
    FClientId := AClientId;

  FKeepAlive := 60;

  writer.Initialize;
  writer.WriteString('MQTT');
  writer.WriteByte(4); // Protocol Level (v3.1.1)
  writer.WriteByte(2); // Clean Session flag only
  writer.WriteWord(FKeepAlive);
  writer.WriteString(FClientId);
  payload := writer.ToBytes;

  writer.Initialize;
  writer.WriteByte(Ord(mptConnect) shl 4);
  writer.WriteRemainingLength(Length(payload));
  writer.WriteBytes(payload);

  FTcpClient.Send(writer.ToBytes);

  SetLength(response, 1024);
  bytesRead := FTcpClient.Receive(response, 5000);
  if bytesRead < 4 then
  begin
    FTcpClient.Disconnect;
    raise EDextSocketError.Create('MQTT connection failed: did not receive CONNACK');
  end;

  span := TByteSpan.Create(@response[0], bytesRead);
  if not DecodeFixedHeader(span, header) or (header.PacketType <> mptConnAck) then
  begin
    FTcpClient.Disconnect;
    raise EDextSocketError.Create('MQTT connection failed: invalid CONNACK header');
  end;

  connAckResult := span[header.HeaderLength + 1];
  if connAckResult <> 0 then
  begin
    FTcpClient.Disconnect;
    raise EDextSocketError.CreateFmt('MQTT connection rejected by broker. Return code: %d', [connAckResult]);
  end;

  FRunning := True;

  FRecvThread := TThread.CreateAnonymousThread(RecvLoop);
  FRecvThread.FreeOnTerminate := False;
  FRecvThread.Start;

  FPingThread := TThread.CreateAnonymousThread(PingLoop);
  FPingThread.FreeOnTerminate := False;
  FPingThread.Start;
end;

procedure TDextMqttClient.Disconnect;
var
  writer: TMqttWriter;
begin
  if not FRunning then Exit;
  FRunning := False;

  try
    writer.Initialize;
    writer.WriteByte(Ord(mptDisconnect) shl 4);
    writer.WriteRemainingLength(0);
    FTcpClient.Send(writer.ToBytes);
  except
  end;

  FTcpClient.Disconnect;

  if FRecvThread <> nil then
  begin
    FRecvThread.WaitFor;
    FRecvThread.Free;
    FRecvThread := nil;
  end;

  if FPingThread <> nil then
  begin
    FPingThread.WaitFor;
    FPingThread.Free;
    FPingThread := nil;
  end;
end;

procedure TDextMqttClient.Publish(const ATopic: string; const APayload: TBytes; AQoS: Byte; ARetain: Boolean);
var
  packet: TMqttPublishPacket;
begin
  packet.Topic := ATopic;
  packet.Payload := APayload;
  packet.QoS := AQoS;
  packet.Retain := ARetain;
  packet.Dup := False;
  if AQoS > 0 then
    packet.PacketId := NextPacketId;

  FTcpClient.Send(EncodePublish(packet));
end;

procedure TDextMqttClient.Subscribe(const ATopicFilter: string; AQoS: Byte);
var
  writer: TMqttWriter;
  payload: TMqttWriter;
  payloadBytes: TBytes;
begin
  payload.Initialize;
  payload.WriteWord(NextPacketId);
  payload.WriteString(ATopicFilter);
  payload.WriteByte(AQoS);
  payloadBytes := payload.ToBytes;

  writer.Initialize;
  writer.WriteByte((Ord(mptSubscribe) shl 4) or 2); // bits 3-0 must be 0010
  writer.WriteRemainingLength(Length(payloadBytes));
  writer.WriteBytes(payloadBytes);

  FTcpClient.Send(writer.ToBytes);
end;

procedure TDextMqttClient.Unsubscribe(const ATopicFilter: string);
var
  writer: TMqttWriter;
  payload: TMqttWriter;
  payloadBytes: TBytes;
begin
  payload.Initialize;
  payload.WriteWord(NextPacketId);
  payload.WriteString(ATopicFilter);
  payloadBytes := payload.ToBytes;

  writer.Initialize;
  writer.WriteByte((Ord(mptUnsubscribe) shl 4) or 2); // bits 3-0 must be 0010
  writer.WriteRemainingLength(Length(payloadBytes));
  writer.WriteBytes(payloadBytes);

  FTcpClient.Send(writer.ToBytes);
end;

procedure TDextMqttClient.RecvLoop;
var
  recvBuffer: TBytes;
  buffer: TBytes;
  bufferLen: Integer;
  bytesRead: Integer;
  span: TByteSpan;
  header: TMqttFixedHeader;
  packet: TMqttPublishPacket;
  message: TMqttMessage;
begin
  SetLength(recvBuffer, 8192);
  SetLength(buffer, 8192);
  bufferLen := 0;

  while FRunning do
  begin
    try
      bytesRead := FTcpClient.Receive(recvBuffer, 100);
      if bytesRead > 0 then
      begin
        if bufferLen + bytesRead > Length(buffer) then
          SetLength(buffer, Length(buffer) + bytesRead + 8192);

        Move(recvBuffer[0], buffer[bufferLen], bytesRead);
        Inc(bufferLen, bytesRead);

        while bufferLen >= 2 do
        begin
          span := TByteSpan.Create(@buffer[0], bufferLen);
          if DecodeFixedHeader(span, header) then
          begin
            if bufferLen >= header.HeaderLength + header.RemainingLength then
            begin
              if header.PacketType = mptPublish then
              begin
                if ParsePublish(span.Slice(header.HeaderLength, header.RemainingLength), header.Flags, packet) then
                begin
                  message.Topic := packet.Topic;
                  message.Payload := packet.Payload;
                  message.QoS := packet.QoS;
                  message.Retain := packet.Retain;

                  if packet.QoS = 1 then
                  begin
                    try
                      FTcpClient.Send(EncodePubAck(packet.PacketId));
                    except
                    end;
                  end;

                  if Assigned(FOnMessage) then
                  begin
                    try
                      FOnMessage(message);
                    except
                    end;
                  end;
                end;
              end;

              Move(buffer[header.HeaderLength + header.RemainingLength], buffer[0], bufferLen - (header.HeaderLength + header.RemainingLength));
              Dec(bufferLen, header.HeaderLength + header.RemainingLength);
            end
            else
              Break;
          end
          else
            Break;
        end;
      end
      else if bytesRead < 0 then
      begin
        FRunning := False;
        Break;
      end;
    except
      FRunning := False;
      Break;
    end;
  end;
end;

procedure TDextMqttClient.PingLoop;
var
  writer: TMqttWriter;
  i: Integer;
begin
  writer.Initialize;
  writer.WriteByte(Ord(mptPingReq) shl 4);
  writer.WriteRemainingLength(0);

  while FRunning do
  begin
    for i := 0 to FKeepAlive - 1 do
    begin
      if not FRunning then Exit;
      Sleep(1000);
    end;

    if FRunning then
    begin
      try
        FTcpClient.Send(writer.ToBytes);
      except
        FRunning := False;
      end;
    end;
  end;
end;

{ TDextMqttSession }

procedure TDextMqttSession.AppendData(const ASpan: TByteSpan);
begin
  if BufferLen + ASpan.Length > Length(Buffer) then
    SetLength(Buffer, BufferLen + ASpan.Length + 4096);
  Move(ASpan.Data^, Buffer[BufferLen], ASpan.Length);
  Inc(BufferLen, ASpan.Length);
end;

procedure TDextMqttSession.ShiftBuffer(ACount: Integer);
begin
  if ACount > 0 then
  begin
    if ACount < BufferLen then
      Move(Buffer[ACount], Buffer[0], BufferLen - ACount);
    Dec(BufferLen, ACount);
  end;
end;

{ TDextMqttServer }

constructor TDextMqttServer.Create;
begin
  inherited Create;
  FTrie := TDextMqttTopicTrie.Create;
  FSessions := TDictionary<UInt64, TDextMqttSession>.Create(True);
  FClientIdToSession := TDictionary<string, TDextMqttSession>.Create;
  FLock := TCriticalSection.Create;

  FTcpServer := TDextTcpServer.Create;
  FTcpServer.OnConnect := OnConnect;
  FTcpServer.OnDisconnect := OnDisconnect;
  FTcpServer.OnDataSpan := OnDataSpan;
  FTcpServer.OnError := OnError;
end;

destructor TDextMqttServer.Destroy;
begin
  FTcpServer.Free;
  FSessions.Free;
  FClientIdToSession.Free;
  FTrie.Free;
  FLock.Free;
  inherited;
end;

procedure TDextMqttServer.Bind(const AAddress: string; APort: Word);
begin
  FTcpServer.Bind(AAddress, APort);
end;

procedure TDextMqttServer.Start;
begin
  FTcpServer.Start;
end;

procedure TDextMqttServer.Stop;
begin
  FTcpServer.Stop;
end;

function TDextMqttServer.GetListenPort: Word;
begin
  Result := FTcpServer.ListenPort;
end;

procedure TDextMqttServer.OnConnect(const AConnection: ITcpConnection);
var
  session: TDextMqttSession;
begin
  FLock.Acquire;
  try
    session := TDextMqttSession.Create;
    session.Connection := AConnection;
    SetLength(session.Buffer, 4096);
    session.BufferLen := 0;
    FSessions.Add(AConnection.ConnectionId, session);
  finally
    FLock.Release;
  end;
end;

procedure TDextMqttServer.OnDisconnect(const AConnection: ITcpConnection);
var
  session: TDextMqttSession;
  clientId: string;
begin
  FLock.Acquire;
  try
    if FSessions.TryGetValue(AConnection.ConnectionId, session) then
    begin
      clientId := session.ClientId;
      if clientId <> '' then
      begin
        FClientIdToSession.Remove(clientId);
      end;
      FSessions.Remove(AConnection.ConnectionId);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TDextMqttServer.OnError(const AConnection: ITcpConnection; AException: Exception);
begin
  AConnection.Close;
end;

procedure TDextMqttServer.OnDataSpan(const AConnection: ITcpConnection; const AData: TByteSpan);
var
  session: TDextMqttSession;
  span: TByteSpan;
  header: TMqttFixedHeader;
begin
  FLock.Acquire;
  try
    if not FSessions.TryGetValue(AConnection.ConnectionId, session) then Exit;
  finally
    FLock.Release;
  end;

  session.AppendData(AData);

  while session.BufferLen >= 2 do
  begin
    span := TByteSpan.Create(@session.Buffer[0], session.BufferLen);
    if DecodeFixedHeader(span, header) then
    begin
      if session.BufferLen >= header.HeaderLength + header.RemainingLength then
      begin
        ProcessPacket(session, span.Slice(header.HeaderLength, header.RemainingLength), header);
        session.ShiftBuffer(header.HeaderLength + header.RemainingLength);
      end
      else
        Break;
    end
    else
      Break;
  end;
end;

procedure TDextMqttServer.ProcessPacket(ASession: TDextMqttSession; const APacketBytes: TByteSpan; const AHeader: TMqttFixedHeader);
begin
  case AHeader.PacketType of
    mptConnect: HandleConnect(ASession, APacketBytes);
    mptPublish: HandlePublish(ASession, AHeader.Flags, APacketBytes);
    mptSubscribe: HandleSubscribe(ASession, APacketBytes);
    mptUnsubscribe: HandleUnsubscribe(ASession, APacketBytes);
    mptPingReq: HandlePingReq(ASession);
    mptDisconnect: HandleDisconnect(ASession);
  end;
end;

procedure TDextMqttServer.HandleConnect(ASession: TDextMqttSession; const APayload: TByteSpan);
var
  packet: TMqttConnectPacket;
  existingSession: TDextMqttSession;
begin
  if ParseConnect(APayload, packet) then
  begin
    FLock.Acquire;
    try
      ASession.ClientId := packet.ClientId;
      if FClientIdToSession.TryGetValue(packet.ClientId, existingSession) then
      begin
        existingSession.Connection.Close;
        FClientIdToSession.Remove(packet.ClientId);
      end;
      FClientIdToSession.Add(packet.ClientId, ASession);
    finally
      FLock.Release;
    end;

    ASession.Connection.Send(EncodeConnAck(0, False));
  end
  else
    ASession.Connection.Close;
end;

procedure TDextMqttServer.HandlePublish(ASession: TDextMqttSession; AFlags: Byte; const APayload: TByteSpan);
var
  packet: TMqttPublishPacket;
  subs: TArray<string>;
  subId: string;
  subSession: TDextMqttSession;
  forwardBytes: TBytes;
begin
  if ParsePublish(APayload, AFlags, packet) then
  begin
    if packet.QoS = 1 then
      ASession.Connection.Send(EncodePubAck(packet.PacketId));

    subs := FTrie.MatchTopic(packet.Topic);
    forwardBytes := EncodePublish(packet);

    FLock.Acquire;
    try
      for subId in subs do
      begin
        if FClientIdToSession.TryGetValue(subId, subSession) then
        begin
          try
            subSession.Connection.Send(forwardBytes);
          except
          end;
        end;
      end;
    finally
      FLock.Release;
    end;
  end;
end;

procedure TDextMqttServer.HandleSubscribe(ASession: TDextMqttSession; const APayload: TByteSpan);
var
  packet: TMqttSubscribePacket;
  returnCodes: TArray<Byte>;
  i: Integer;
begin
  if ParseSubscribe(APayload, packet) then
  begin
    SetLength(returnCodes, Length(packet.Topics));
    for i := 0 to Length(packet.Topics) - 1 do
    begin
      FTrie.AddSubscription(packet.Topics[i].TopicFilter, ASession.ClientId);
      returnCodes[i] := packet.Topics[i].RequestedQoS;
    end;
    ASession.Connection.Send(EncodeSubAck(packet.PacketId, returnCodes));
  end;
end;

procedure TDextMqttServer.HandleUnsubscribe(ASession: TDextMqttSession; const APayload: TByteSpan);
var
  packet: TMqttUnsubscribePacket;
  i: Integer;
begin
  if ParseUnsubscribe(APayload, packet) then
  begin
    for i := 0 to Length(packet.TopicFilters) - 1 do
      FTrie.RemoveSubscription(packet.TopicFilters[i], ASession.ClientId);
    ASession.Connection.Send(EncodeUnsubAck(packet.PacketId));
  end;
end;

procedure TDextMqttServer.HandlePingReq(ASession: TDextMqttSession);
begin
  ASession.Connection.Send(EncodePingResp);
end;

procedure TDextMqttServer.HandleDisconnect(ASession: TDextMqttSession);
begin
  ASession.Connection.Close;
end;

end.
