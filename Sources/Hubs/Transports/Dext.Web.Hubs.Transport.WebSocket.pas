{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025-2026 Cesar Romero & Dext Contributors        }
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
unit Dext.Web.Hubs.Transport.WebSocket;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.Rtti,
  System.SyncObjs,
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Auth.Identity,
  Dext.Threading.CancellationToken,
  Dext.Server.Engine.Interfaces,
  Dext.WebSocket.Protocol,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Interfaces;

type
  TOnBinaryHubMessage = reference to procedure(const ConnectionId: string;
    const Data: TBytes);

  IWebSocketHubConnectionControl = interface
    ['{DFA8ED6D-F78A-4658-914A-E08399DD92D5}']
    procedure Touch;
    procedure SendKeepAlive(ANow: UInt64);
  end;

  IWebSocketPreparedSender = interface
    ['{55CDCC90-0E44-41A2-9FA1-2B8B20D5855E}']
    procedure SendPreparedFrame(const AFrame: TBytes);
    function GetProtocolName: string;
    function IsCompressionEnabled: Boolean;
  end;

  TWebSocketHubTransport = class;

  TWebSocketKeepAliveThread = class(TThread)
  private
    FOwner: TWebSocketHubTransport;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TWebSocketHubTransport);
  end;

  /// <summary>
  /// WebSocket connection wrapping the raw server upgrade connection.
  /// </summary>
  TWebSocketHubConnection = class(TInterfacedObject, IHubConnection,
    IWebSocketHubConnectionControl, IWebSocketPreparedSender)
  private
    FConnectionId: string;
    FWSConnection: IDextWebSocketConnection;
    FState: TConnectionState;
    FUser: IClaimsPrincipal;
    FItems: IDictionary<string, TValue>;
    FAbortTokenSource: TCancellationTokenSource;
    FLock: TCriticalSection;
    FReceiveBuffer: TBytes;
    FReceiveStart: Integer;
    FReceiveEnd: Integer;
    FFragmentOpcode: TWebSocketOpcode;
    FFragmentActive: Boolean;
    FFragmentCompressed: Boolean;
    FFragmentPayload: TBytes;
    FLastActivityTick: Int64;
    FHandshakeComplete: Boolean;
    FProtocolName: string;
  public
    constructor Create(const AConnectionId: string;
      const AWSConnection: IDextWebSocketConnection;
      const AUser: IClaimsPrincipal = nil);
    destructor Destroy; override;

    // IHubConnection
    function GetConnectionId: string;
    function GetTransportType: TTransportType;
    function GetState: TConnectionState;
    function GetUser: IClaimsPrincipal;
    function GetUserIdentifier: string;
    function GetItems: IDictionary<string, TValue>;
    function GetAbortToken: ICancellationToken;

    procedure SendAsync(const Message: string);
    procedure SendPreparedFrame(const AFrame: TBytes);
    function GetProtocolName: string;
    function IsCompressionEnabled: Boolean;
    procedure Close(const Reason: string = '');
    procedure Touch;
    procedure SendKeepAlive(ANow: UInt64);

    property ConnectionId: string read GetConnectionId;
    property State: TConnectionState read GetState;
  end;

  /// <summary>
  /// WebSocket Transport manager implementing IHubTransport.
  /// </summary>
  TWebSocketHubTransport = class(TInterfacedObject, IHubTransport)
  private
    FConnections: IDictionary<string, IHubConnection>;
    FLock: TCriticalSection;
    FPreparedLock: TCriticalSection;
    FLastPreparedText: string;
    FLastPreparedFrame: TBytes;
    FOnMessageReceived: TOnMessageReceived;
    FOnBinaryMessageReceived: TOnBinaryHubMessage;
    FOnConnected: TOnConnectionEvent;
    FOnDisconnected: TOnConnectionEvent;
    FShuttingDown: Boolean;
    FKeepAliveThread: TWebSocketKeepAliveThread;
    procedure SendKeepAlives;
    procedure ProcessAsyncData(AConnection: TWebSocketHubConnection;
      const AWSConnection: IDextWebSocketConnection;
      const ABuffer: TBytes; ACount: Integer);
    procedure CompleteAsyncConnection(AConnection: TWebSocketHubConnection;
      const AWSConnection: IDextWebSocketConnection);
    function DispatchFrame(AConnection: TWebSocketHubConnection;
      const AWSConnection: IDextWebSocketConnection;
      const AFrame: TWebSocketFrame): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    // IHubTransport
    function GetTransportType: TTransportType;
    function IsAvailable: Boolean;
    procedure SendAsync(const ConnectionId, Data: string);
    procedure CloseConnection(const ConnectionId: string; const Reason: string = '');
    procedure SetOnMessageReceived(const Handler: TOnMessageReceived);
    procedure SetOnBinaryMessageReceived(const Handler: TOnBinaryHubMessage);
    procedure SetOnConnected(const Handler: TOnConnectionEvent);
    procedure SetOnDisconnected(const Handler: TOnConnectionEvent);

    // WebSocket-specific processing loop
    procedure ProcessConnection(const AContext: IHttpContext; var AConnectionId: string);
    procedure CloseAllConnections;
    function IsShuttingDown: Boolean;
    function GetConnection(const ConnectionId: string): IHubConnection;
  end;

implementation

uses
  System.JSON,
  System.DateUtils,
  Dext.Resilience,
  Dext.WebSocket.Handshake,
  Dext.Web.Hubs.Protocol.Json,
  Dext.Web.Hubs.Protocol.MessagePack;

var
  GStrictUtf8: TUTF8Encoding;

{ TWebSocketHubConnection }

constructor TWebSocketKeepAliveThread.Create(AOwner: TWebSocketHubTransport);
begin
  inherited Create(True);
  FOwner := AOwner;
  FreeOnTerminate := False;
end;

procedure TWebSocketKeepAliveThread.Execute;
begin
  while not Terminated do
  begin
    Sleep(1000);
    if not Terminated then
      FOwner.SendKeepAlives;
  end;
end;

constructor TWebSocketHubConnection.Create(const AConnectionId: string;
  const AWSConnection: IDextWebSocketConnection;
  const AUser: IClaimsPrincipal);
begin
  inherited Create;
  FConnectionId := AConnectionId;
  FWSConnection := AWSConnection;
  FState := csConnected;
  FUser := AUser;
  FItems := TCollections.CreateDictionary<string, TValue>;
  FAbortTokenSource := TCancellationTokenSource.Create;
  FLock := TCriticalSection.Create;
  FReceiveStart := 0;
  FReceiveEnd := 0;
  FFragmentActive := False;
  FLastActivityTick := GetTickCount64;
  FHandshakeComplete := False;
  FProtocolName := '';
end;

destructor TWebSocketHubConnection.Destroy;
begin
  FAbortTokenSource.Free;
  FItems := nil;
  FUser := nil;
  FWSConnection := nil;
  FReceiveBuffer := nil;
  FFragmentPayload := nil;
  FLock.Free;
  inherited;
end;

function TWebSocketHubConnection.GetConnectionId: string;
begin
  Result := FConnectionId;
end;

function TWebSocketHubConnection.GetTransportType: TTransportType;
begin
  Result := ttWebSockets;
end;

function TWebSocketHubConnection.GetState: TConnectionState;
begin
  Result := FState;
end;

function TWebSocketHubConnection.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

function TWebSocketHubConnection.GetUserIdentifier: string;
begin
  if FUser <> nil then
    Result := FUser.FindClaim('sub').Value // Standard claim for user ID
  else
    Result := '';
end;

function TWebSocketHubConnection.GetItems: IDictionary<string, TValue>;
begin
  Result := FItems;
end;

function TWebSocketHubConnection.GetAbortToken: ICancellationToken;
begin
  Result := FAbortTokenSource.Token;
end;

procedure TWebSocketHubConnection.SendAsync(const Message: string);
var
  JsonProtocol: TJsonHubProtocol;
  MessagePackProtocol: TMessagePackHubProtocol;
  HubMessage: THubMessage;
begin
  if SameText(FProtocolName, 'messagepack') then
  begin
    JsonProtocol := TJsonHubProtocol.Create;
    MessagePackProtocol := TMessagePackHubProtocol.Create;
    try
      HubMessage := JsonProtocol.Deserialize(Message);
      FWSConnection.SendBinary(MessagePackProtocol.SerializeBinary(HubMessage));
    finally
      MessagePackProtocol.Free;
      JsonProtocol.Free;
    end;
  end
  else
    SendPreparedFrame(TWebSocketFrameCodec.EncodeText(Message));
end;

procedure TWebSocketHubConnection.SendPreparedFrame(const AFrame: TBytes);
begin
  FLock.Enter;
  try
    if FState = csConnected then
      FWSConnection.SendFrame(AFrame);
  finally
    FLock.Leave;
  end;
end;

function TWebSocketHubConnection.GetProtocolName: string;
begin
  Result := FProtocolName;
end;

function TWebSocketHubConnection.IsCompressionEnabled: Boolean;
var
  Compression: IDextCompressedWebSocketConnection;
begin
  Result := Supports(FWSConnection, IDextCompressedWebSocketConnection,
    Compression);
  if Result then
    Result := Compression.IsCompressionEnabled;
end;

procedure TWebSocketHubConnection.Close(const Reason: string);
begin
  FLock.Enter;
  try
    if FState = csConnected then
    begin
      FState := csDisconnected;
      FAbortTokenSource.Cancel;
      FWSConnection.Close(1000, Reason);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketHubConnection.Touch;
begin
  TInterlocked.Exchange(FLastActivityTick, Int64(GetTickCount64));
end;

procedure TWebSocketHubConnection.SendKeepAlive(ANow: UInt64);
var
  LastActivity: UInt64;
begin
  LastActivity := UInt64(TInterlocked.Read(FLastActivityTick));
  if (FState = csConnected) and (ANow - LastActivity >= 15000) then
  begin
    FWSConnection.SendFrame(TWebSocketFrameCodec.EncodePing);
    TInterlocked.Exchange(FLastActivityTick, Int64(ANow));
  end;
end;

{ TWebSocketHubTransport }

constructor TWebSocketHubTransport.Create;
begin
  inherited Create;
  FConnections := TCollections.CreateDictionary<string, IHubConnection>;
  FLock := TCriticalSection.Create;
  FPreparedLock := TCriticalSection.Create;
  FShuttingDown := False;
  FKeepAliveThread := TWebSocketKeepAliveThread.Create(Self);
  FKeepAliveThread.Start;
end;

destructor TWebSocketHubTransport.Destroy;
begin
  if FKeepAliveThread <> nil then
  begin
    FKeepAliveThread.Terminate;
    FKeepAliveThread.WaitFor;
    FKeepAliveThread.Free;
    FKeepAliveThread := nil;
  end;
  CloseAllConnections;
  FPreparedLock.Free;
  FLock.Free;
  inherited;
end;

procedure TWebSocketHubTransport.SendKeepAlives;
var
  Connections: TArray<IHubConnection>;
  Connection: IHubConnection;
  Control: IWebSocketHubConnectionControl;
  Index: Integer;
  NowTick: UInt64;
begin
  if FShuttingDown then Exit;
  FLock.Enter;
  try
    SetLength(Connections, FConnections.Count);
    Index := 0;
    for Connection in FConnections.Values do
    begin
      Connections[Index] := Connection;
      Inc(Index);
    end;
  finally
    FLock.Leave;
  end;
  NowTick := GetTickCount64;
  for Connection in Connections do
    if Supports(Connection, IWebSocketHubConnectionControl, Control) then
      Control.SendKeepAlive(NowTick);
end;

function TWebSocketHubTransport.GetTransportType: TTransportType;
begin
  Result := ttWebSockets;
end;

function TWebSocketHubTransport.IsAvailable: Boolean;
begin
  Result := True;
end;

procedure TWebSocketHubTransport.SendAsync(const ConnectionId, Data: string);
var
  Conn: IHubConnection;
  PreparedSender: IWebSocketPreparedSender;
  PreparedFrame: TBytes;
begin
  FLock.Enter;
  try
    if not FConnections.TryGetValue(ConnectionId, Conn) then
      Conn := nil;
  finally
    FLock.Leave;
  end;
  if Conn <> nil then
  begin
    FPreparedLock.Enter;
    try
      if FLastPreparedText <> Data then
      begin
        FLastPreparedText := Data;
        FLastPreparedFrame := TWebSocketFrameCodec.EncodeText(Data);
      end;
      PreparedFrame := FLastPreparedFrame;
    finally
      FPreparedLock.Leave;
    end;
    if Supports(Conn, IWebSocketPreparedSender, PreparedSender) then
    begin
      if SameText(PreparedSender.GetProtocolName, 'messagepack') or
         PreparedSender.IsCompressionEnabled then
        Conn.SendAsync(Data)
      else
        PreparedSender.SendPreparedFrame(PreparedFrame);
    end
    else
      Conn.SendAsync(Data);
  end;
end;

procedure TWebSocketHubTransport.CloseConnection(const ConnectionId: string; const Reason: string);
var
  Conn: IHubConnection;
begin
  FLock.Enter;
  try
    if not FConnections.TryGetValue(ConnectionId, Conn) then
      Conn := nil;
  finally
    FLock.Leave;
  end;
  if Conn <> nil then
    Conn.Close(Reason);
end;

procedure TWebSocketHubTransport.SetOnMessageReceived(const Handler: TOnMessageReceived);
begin
  FOnMessageReceived := Handler;
end;

procedure TWebSocketHubTransport.SetOnBinaryMessageReceived(
  const Handler: TOnBinaryHubMessage);
begin
  FOnBinaryMessageReceived := Handler;
end;

procedure TWebSocketHubTransport.SetOnConnected(const Handler: TOnConnectionEvent);
begin
  FOnConnected := Handler;
end;

procedure TWebSocketHubTransport.SetOnDisconnected(const Handler: TOnConnectionEvent);
begin
  FOnDisconnected := Handler;
end;

procedure TWebSocketHubTransport.CloseAllConnections;
var
  Connections: TArray<IHubConnection>;
  Conn: IHubConnection;
  Index: Integer;
begin
  FShuttingDown := True;
  FLock.Enter;
  try
    SetLength(Connections, FConnections.Count);
    Index := 0;
    for Conn in FConnections.Values do
    begin
      Connections[Index] := Conn;
      Inc(Index);
    end;
  finally
    FLock.Leave;
  end;
  for Conn in Connections do
    if Conn <> nil then
      Conn.Close('Server shutting down');
end;

function TWebSocketHubTransport.IsShuttingDown: Boolean;
begin
  Result := FShuttingDown;
end;

function TWebSocketHubTransport.GetConnection(const ConnectionId: string): IHubConnection;
begin
  FLock.Enter;
  try
    if not FConnections.TryGetValue(ConnectionId, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketHubTransport.ProcessConnection(const AContext: IHttpContext; var AConnectionId: string);
var
  WSConn: IDextWebSocketConnection;
  ConnectionId: string;
  HubConnection: TWebSocketHubConnection;
  Buffer: TBytes;
  BufferStart: Integer;
  BufferEnd: Integer;
  BytesRead: Integer;
  Frame: TWebSocketFrame;
  BytesConsumed: Integer;
  KeepAliveTimer: TDateTime;
  ServerConnection: IDextServerConnection;
  DecodeResult: TWebSocketDecodeResult;
  NewCapacity: Integer;
  AsyncConnection: IDextAsyncWebSocketConnection;
  CompressedConnection: IDextCompressedWebSocketConnection;
  AllowRSV1: Boolean;
const
  INITIAL_BUFFER_SIZE = 8 * 1024;
  MAX_MESSAGE_SIZE = 16 * 1024 * 1024;
begin
  // Engines without a raw server connection (Indy, DCS, WebBroker) return nil.
  ServerConnection := AContext.Connection;
  if ServerConnection = nil then
  begin
    AConnectionId := '';
    Exit;
  end;

  WSConn := ServerConnection.UpgradeToWebSocket;
  if WSConn = nil then
  begin
    AConnectionId := '';
    Exit;
  end;
  AllowRSV1 := Supports(WSConn, IDextCompressedWebSocketConnection,
    CompressedConnection);
  if AllowRSV1 then
    AllowRSV1 := CompressedConnection.IsCompressionEnabled;

  if AConnectionId = '' then
    ConnectionId := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '')
  else
    ConnectionId := AConnectionId;

  AConnectionId := ConnectionId;
  HubConnection := TWebSocketHubConnection.Create(ConnectionId, WSConn,
    AContext.User);

  FLock.Enter;
  try
    FConnections.Add(ConnectionId, HubConnection);
  finally
    FLock.Leave;
  end;

  if Supports(WSConn, IDextAsyncWebSocketConnection, AsyncConnection) then
  begin
    AsyncConnection.SetOnData(
      procedure(const ABuffer: TBytes; ACount: Integer)
      begin
        ProcessAsyncData(HubConnection, WSConn, ABuffer, ACount);
      end);
    AsyncConnection.SetOnClosed(
      procedure
      begin
        CompleteAsyncConnection(HubConnection, WSConn);
      end);
    AsyncConnection.StartReceive;
    Exit;
  end;

  SetLength(Buffer, INITIAL_BUFFER_SIZE);
  BufferStart := 0;
  BufferEnd := 0;
  KeepAliveTimer := Now;

  try
    while (not FShuttingDown) and (HubConnection.State = csConnected) do
    begin
      if BufferEnd = Length(Buffer) then
      begin
        if BufferStart > 0 then
        begin
          Move(Buffer[BufferStart], Buffer[0], BufferEnd - BufferStart);
          Dec(BufferEnd, BufferStart);
          BufferStart := 0;
        end
        else
        begin
          if Length(Buffer) >= MAX_MESSAGE_SIZE then
          begin
            WSConn.Close(1009, 'Message too large');
            Break;
          end;
          NewCapacity := Length(Buffer) * 2;
          if NewCapacity > MAX_MESSAGE_SIZE then
            NewCapacity := MAX_MESSAGE_SIZE;
          SetLength(Buffer, NewCapacity);
        end;
      end;

      BytesRead := WSConn.Receive(
        Buffer, BufferEnd, Length(Buffer) - BufferEnd);
      if BytesRead <= 0 then
        Break;

      Inc(BufferEnd, BytesRead);

      while BufferStart < BufferEnd do
      begin
        BytesConsumed := 0;
        DecodeResult := TWebSocketFrameCodec.Decode(
          Buffer, BufferStart, BufferEnd - BufferStart, Frame,
          BytesConsumed, True, MAX_MESSAGE_SIZE,
          AllowRSV1);
        if DecodeResult = wsDecodeComplete then
        begin
          if not DispatchFrame(HubConnection, WSConn, Frame) then
            Break;

          if BytesConsumed > 0 then
          begin
            Inc(BufferStart, BytesConsumed);
            if BufferStart = BufferEnd then
            begin
              BufferStart := 0;
              BufferEnd := 0;
            end;
          end
          else
            Break;
        end
        else if DecodeResult = wsDecodeProtocolError then
        begin
          WSConn.Close(1002, 'Invalid WebSocket frame');
          Break;
        end
        else if DecodeResult = wsDecodeMessageTooBig then
        begin
          WSConn.Close(1009, 'Message too large');
          Break;
        end
        else
          Break;
      end;

      if SecondsBetween(Now, KeepAliveTimer) >= 15 then
      begin
        WSConn.SendFrame(TWebSocketFrameCodec.EncodePing);
        KeepAliveTimer := Now;
      end;
    end;
  finally
    FLock.Enter;
    try
      FConnections.Remove(ConnectionId);
    finally
      FLock.Leave;
    end;

    if Assigned(FOnDisconnected) then
      FOnDisconnected(ConnectionId);

    WSConn.Close(1000);
  end;
end;

procedure TWebSocketHubTransport.ProcessAsyncData(
  AConnection: TWebSocketHubConnection;
  const AWSConnection: IDextWebSocketConnection;
  const ABuffer: TBytes; ACount: Integer);
const
  INITIAL_BUFFER_SIZE = 8 * 1024;
  MAX_MESSAGE_SIZE = 16 * 1024 * 1024;
var
  Required: Integer;
  NewCapacity: Integer;
  Frame: TWebSocketFrame;
  Consumed: Integer;
  DecodeResult: TWebSocketDecodeResult;
  CompressedConnection: IDextCompressedWebSocketConnection;
  AllowRSV1: Boolean;
begin
  if (AConnection = nil) or (ACount <= 0) or FShuttingDown then
    Exit;
  AllowRSV1 := Supports(AWSConnection, IDextCompressedWebSocketConnection,
    CompressedConnection);
  if AllowRSV1 then
    AllowRSV1 := CompressedConnection.IsCompressionEnabled;
  Required := AConnection.FReceiveEnd + ACount;
  if Required > Length(AConnection.FReceiveBuffer) then
  begin
    if AConnection.FReceiveStart > 0 then
    begin
      Move(AConnection.FReceiveBuffer[AConnection.FReceiveStart],
        AConnection.FReceiveBuffer[0],
        AConnection.FReceiveEnd - AConnection.FReceiveStart);
      Dec(AConnection.FReceiveEnd, AConnection.FReceiveStart);
      AConnection.FReceiveStart := 0;
      Required := AConnection.FReceiveEnd + ACount;
    end;
    if Required > Length(AConnection.FReceiveBuffer) then
    begin
      NewCapacity := Length(AConnection.FReceiveBuffer);
      if NewCapacity = 0 then
        NewCapacity := INITIAL_BUFFER_SIZE;
      while (NewCapacity < Required) and
            (NewCapacity < MAX_MESSAGE_SIZE) do
        NewCapacity := NewCapacity * 2;
      if (Required > MAX_MESSAGE_SIZE) or
         (NewCapacity > MAX_MESSAGE_SIZE) then
      begin
        AWSConnection.Close(1009, 'Message too large');
        Exit;
      end;
      SetLength(AConnection.FReceiveBuffer, NewCapacity);
    end;
  end;
  Move(ABuffer[0], AConnection.FReceiveBuffer[AConnection.FReceiveEnd],
    ACount);
  Inc(AConnection.FReceiveEnd, ACount);

  while AConnection.FReceiveStart < AConnection.FReceiveEnd do
  begin
    Consumed := 0;
    DecodeResult := TWebSocketFrameCodec.Decode(
      AConnection.FReceiveBuffer, AConnection.FReceiveStart,
      AConnection.FReceiveEnd - AConnection.FReceiveStart, Frame,
      Consumed, True, MAX_MESSAGE_SIZE,
      AllowRSV1);
    case DecodeResult of
      wsDecodeIncomplete:
        Exit;
      wsDecodeProtocolError:
        begin
          AWSConnection.Close(1002, 'Invalid WebSocket frame');
          Exit;
        end;
      wsDecodeMessageTooBig:
        begin
          AWSConnection.Close(1009, 'Message too large');
          Exit;
        end;
    end;

    if not DispatchFrame(AConnection, AWSConnection, Frame) then
      Exit;

    Inc(AConnection.FReceiveStart, Consumed);
    if AConnection.FReceiveStart = AConnection.FReceiveEnd then
    begin
      AConnection.FReceiveStart := 0;
      AConnection.FReceiveEnd := 0;
      if Length(AConnection.FReceiveBuffer) > INITIAL_BUFFER_SIZE then
        SetLength(AConnection.FReceiveBuffer, INITIAL_BUFFER_SIZE);
    end;
  end;
end;

function TWebSocketHubTransport.DispatchFrame(
  AConnection: TWebSocketHubConnection;
  const AWSConnection: IDextWebSocketConnection;
  const AFrame: TWebSocketFrame): Boolean;
const
  MAX_MESSAGE_SIZE = 16 * 1024 * 1024;
var
  OldLength: Integer;
  PayloadText: string;
  TextBytes: TBytes;
  BinaryBytes: TBytes;
  MessageOpcode: TWebSocketOpcode;
  JsonValue: TJSONValue;
  JsonObject: TJSONObject;
  ProtocolValue: TJSONValue;
  VersionValue: TJSONValue;
  CompressedConnection: IDextCompressedWebSocketConnection;
  MessageCompressed: Boolean;
  HasCompression: Boolean;
begin
  Result := True;
  MessageOpcode := AFrame.Opcode;
  MessageCompressed := AFrame.RSV1;
  case AFrame.Opcode of
    wsText:
      begin
        if AConnection.FFragmentActive then
        begin
          AWSConnection.Close(1002, 'Unexpected data frame');
          Exit(False);
        end;
        if AFrame.FIN then
          TextBytes := AFrame.Payload
        else
        begin
          AConnection.FFragmentActive := True;
          AConnection.FFragmentOpcode := wsText;
          AConnection.FFragmentCompressed := AFrame.RSV1;
          AConnection.FFragmentPayload := Copy(
            AFrame.Payload, 0, Length(AFrame.Payload));
          Exit;
        end;
      end;

    wsContinuation:
      begin
        if not AConnection.FFragmentActive then
        begin
          AWSConnection.Close(1002, 'Unexpected continuation frame');
          Exit(False);
        end;
        OldLength := Length(AConnection.FFragmentPayload);
        if UInt64(OldLength) + UInt64(Length(AFrame.Payload)) >
           MAX_MESSAGE_SIZE then
        begin
          AWSConnection.Close(1009, 'Message too large');
          Exit(False);
        end;
        SetLength(AConnection.FFragmentPayload,
          OldLength + Length(AFrame.Payload));
        if Length(AFrame.Payload) > 0 then
          Move(AFrame.Payload[0],
            AConnection.FFragmentPayload[OldLength],
            Length(AFrame.Payload));
        if not AFrame.FIN then
          Exit;
        MessageOpcode := AConnection.FFragmentOpcode;
        MessageCompressed := AConnection.FFragmentCompressed;
        if MessageOpcode = wsText then
          TextBytes := AConnection.FFragmentPayload
        else
          BinaryBytes := AConnection.FFragmentPayload;
        AConnection.FFragmentPayload := nil;
        AConnection.FFragmentActive := False;
      end;

    wsBinary:
      begin
        if AConnection.FFragmentActive then
        begin
          AWSConnection.Close(1002, 'Unexpected data frame');
          Exit(False);
        end;
        if AFrame.FIN then
          BinaryBytes := AFrame.Payload
        else
        begin
          AConnection.FFragmentActive := True;
          AConnection.FFragmentOpcode := wsBinary;
          AConnection.FFragmentCompressed := AFrame.RSV1;
          AConnection.FFragmentPayload := Copy(
            AFrame.Payload, 0, Length(AFrame.Payload));
          Exit;
        end;
      end;

    wsPing:
      begin
        AWSConnection.SendFrame(
          TWebSocketFrameCodec.EncodePong(AFrame.Payload));
        Exit;
      end;

    wsPong:
      Exit;

    wsClose:
      begin
        AWSConnection.Close(1000);
        Exit(False);
      end;
  else
    begin
      AWSConnection.Close(1002, 'Unsupported opcode');
      Exit(False);
    end;
  end;

  if MessageCompressed then
  begin
    HasCompression := Supports(AWSConnection,
      IDextCompressedWebSocketConnection, CompressedConnection);
    if HasCompression then
      HasCompression := CompressedConnection.IsCompressionEnabled;
    if not HasCompression then
    begin
      AWSConnection.Close(1002, 'Compressed message was not negotiated');
      Exit(False);
    end;
    try
      if MessageOpcode = wsText then
        TextBytes := CompressedConnection.DecompressMessage(TextBytes)
      else
        BinaryBytes := CompressedConnection.DecompressMessage(BinaryBytes);
    except
      on E: Exception do
      begin
        AWSConnection.Close(1007, 'Invalid compressed payload');
        Exit(False);
      end;
    end;
  end;

  if MessageOpcode = wsBinary then
  begin
    if not AConnection.FHandshakeComplete or
       not SameText(AConnection.FProtocolName, 'messagepack') then
    begin
      AWSConnection.Close(1003, 'Binary protocol was not negotiated');
      Exit(False);
    end;
    AConnection.Touch;
    if Assigned(FOnBinaryMessageReceived) then
      FOnBinaryMessageReceived(AConnection.ConnectionId, BinaryBytes);
    Exit;
  end;

  try
    PayloadText := GStrictUtf8.GetString(TextBytes);
  except
    on E: EEncodingError do
    begin
      AWSConnection.Close(1007, 'Invalid UTF-8 payload');
      Exit(False);
    end;
  end;

  if not AConnection.FHandshakeComplete then
  begin
    if not PayloadText.EndsWith(#$1E) then
    begin
      AWSConnection.Close(1002, 'Incomplete SignalR handshake');
      Exit(False);
    end;
    JsonValue := TJSONObject.ParseJSONValue(
      PayloadText.Substring(0, PayloadText.Length - 1));
    try
      if not (JsonValue is TJSONObject) then
      begin
        AWSConnection.Close(1002, 'Invalid SignalR handshake');
        Exit(False);
      end;
      JsonObject := TJSONObject(JsonValue);
      ProtocolValue := JsonObject.GetValue('protocol');
      VersionValue := JsonObject.GetValue('version');
      if (ProtocolValue = nil) or (VersionValue = nil) or
         (VersionValue.Value <> '1') or
         (not SameText(ProtocolValue.Value, 'json') and
          not SameText(ProtocolValue.Value, 'messagepack')) then
      begin
        AWSConnection.SendText(
          '{"error":"Unsupported Hub protocol or version"}' + #$1E);
        AWSConnection.Close(1002, 'Unsupported Hub protocol');
        Exit(False);
      end;
      AConnection.FProtocolName := LowerCase(ProtocolValue.Value);
      AConnection.FHandshakeComplete := True;
      AConnection.Touch;
      AWSConnection.SendText('{}' + #$1E);
      if Assigned(FOnConnected) then
        FOnConnected(AConnection.ConnectionId);
      Exit;
    finally
      JsonValue.Free;
    end;
  end;

  if not SameText(AConnection.FProtocolName, 'json') then
  begin
    AWSConnection.Close(1003, 'Text message for binary Hub protocol');
    Exit(False);
  end;
  AConnection.Touch;
  if Assigned(FOnMessageReceived) then
    FOnMessageReceived(AConnection.ConnectionId, PayloadText);
end;

procedure TWebSocketHubTransport.CompleteAsyncConnection(
  AConnection: TWebSocketHubConnection;
  const AWSConnection: IDextWebSocketConnection);
var
  ConnectionId: string;
begin
  if AConnection = nil then Exit;
  ConnectionId := AConnection.ConnectionId;
  FLock.Enter;
  try
    FConnections.Remove(ConnectionId);
  finally
    FLock.Leave;
  end;
  if Assigned(FOnDisconnected) then
    FOnDisconnected(ConnectionId);
end;

initialization
{$IF CompilerVersion >= 35.0}
  GStrictUtf8 := TUTF8Encoding.Create(False);
{$ELSE}
  GStrictUtf8 := TUTF8Encoding.Create;
{$IFEND}

finalization
  GStrictUtf8.Free;

end.
