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
unit Dext.Web.Hubs.Client;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.SyncObjs,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.Socket,
  System.JSON,
  System.Generics.Collections,
  System.NetEncoding,
  Dext.Web.Hubs.Client.Types;

type
  /// <summary>
  /// Represents a custom HTTP header name/value pair for the client builder.
  /// </summary>
  TClientHeader = record
    Name: string;
    Value: string;
  end;

  /// <summary>
  /// Represents a custom HTTP query parameter name/value pair for the client builder.
  /// </summary>
  TClientQueryParam = record
    Name: string;
    Value: string;
  end;

  /// <summary>
  /// Transport interface defining standard client connections.
  /// </summary>
  IHubClientTransport = interface
    ['{1A2B3C4D-5E6F-7A8B-9C0D-E1F2A3B4C5D6}']
    /// <summary>Connects the transport to the target hub URL.</summary>
    procedure Connect(const AUrl: string; const AHeaders: TArray<TClientHeader>; const AQueryParams: TArray<TClientQueryParam>);
    /// <summary>Disconnects the transport.</summary>
    procedure Disconnect;
    /// <summary>Sends a raw message string over the transport.</summary>
    procedure SendMessage(const AMessage: string);
    /// <summary>Registers the callback to execute when a new message is received.</summary>
    procedure SetOnMessage(const ACallback: TProc<string>);
    /// <summary>Registers the callback to execute when the transport connection closes.</summary>
    procedure SetOnClose(const ACallback: TProc<Exception>);
    /// <summary>Returns True if the transport is currently connected.</summary>
    function IsConnected: Boolean;
  end;

  /// <summary>
  /// Callback registry mapping event names to registered callbacks.
  /// </summary>
  THubCallbackRegistry = class
  private
    FCallbacks: TDictionary<string, TList<TValue>>;
    FLock: TCriticalSection;
  public
    /// <summary>Initializes a new callback registry.</summary>
    constructor Create;
    /// <summary>Frees internal memory.</summary>
    destructor Destroy; override;
    /// <summary>Registers a callback for the given event name.</summary>
    procedure RegisterCallback(const AEventName: string; const ACallback: TValue);
    /// <summary>Dispatches the arguments to all callbacks registered for the event.</summary>
    procedure Dispatch(const AEventName: string; const AArgs: TArray<TValue>); reintroduce;
  end;

  /// <summary>
  /// Fluent builder to configure and instantiate a Delphi Hub Client connection.
  /// </summary>
  TDextHubConnectionBuilder = class
  private
    FUrl: string;
    FTransport: TClientTransportType;
    FHeaders: TList<TClientHeader>;
    FQueryParams: TList<TClientQueryParam>;
    FMarshalToMainThread: Boolean;
  public
    /// <summary>Initializes the builder.</summary>
    constructor Create;
    /// <summary>Frees the builder configuration.</summary>
    destructor Destroy; override;
    
    /// <summary>Creates a new instance of the builder.</summary>
    class function New: TDextHubConnectionBuilder;
    
    /// <summary>Sets the connection URL.</summary>
    function WithUrl(const AUrl: string): TDextHubConnectionBuilder;
    /// <summary>Sets the preferred transport type (WebSocket or SSE).</summary>
    function WithTransport(const ATransport: TClientTransportType): TDextHubConnectionBuilder;
    /// <summary>Adds a custom HTTP header to the client handshake/negotiate.</summary>
    function WithHeader(const AName, AValue: string): TDextHubConnectionBuilder;
    /// <summary>Adds a query parameter to the connection URL.</summary>
    function WithQueryParam(const AName, AValue: string): TDextHubConnectionBuilder;
    /// <summary>Enables marshaling of all callback dispatches to the UI/Main thread.</summary>
    function WithUIThreadMarshaling(AMarshal: Boolean = True): TDextHubConnectionBuilder;
    
    /// <summary>Builds the IDextHubConnection instance and frees the builder.</summary>
    function Build: IDextHubConnection;
  end;

implementation

uses
  Dext.Web.Hubs.Types,
  Dext.Web.Hubs.Protocol.Json,
  Dext.WebSocket.Protocol,
  Dext.Web.Hubs.Interfaces;

type
  // -------------------------------------------------------------
  // SSE Client Transport Implementation
  // -------------------------------------------------------------
  TSSEClientTransport = class(TInterfacedObject, IHubClientTransport)
  private
    FHTTPClient: THTTPClient;
    FThread: TThread;
    FOnMessage: TProc<string>;
    FOnClose: TProc<Exception>;
    FConnected: Boolean;
    FLock: TCriticalSection;
    FUrl: string;
    FHeaders: TArray<TClientHeader>;
    FQueryParams: TArray<TClientQueryParam>;
    procedure StreamThreadProc;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Connect(const AUrl: string; const AHeaders: TArray<TClientHeader>; const AQueryParams: TArray<TClientQueryParam>);
    procedure Disconnect;
    procedure SendMessage(const AMessage: string);
    procedure SetOnMessage(const ACallback: TProc<string>);
    procedure SetOnClose(const ACallback: TProc<Exception>);
    function IsConnected: Boolean;
  end;

  // -------------------------------------------------------------
  // WebSocket Client Transport Implementation
  // -------------------------------------------------------------
  TWebSocketClientTransport = class(TInterfacedObject, IHubClientTransport)
  private
    FSocket: TSocket;
    FThread: TThread;
    FOnMessage: TProc<string>;
    FOnClose: TProc<Exception>;
    FConnected: Boolean;
    FLock: TCriticalSection;
    procedure ReadThreadProc;
    procedure PerformHandshake(const AURI: TURI; const AHeaders: TArray<TClientHeader>);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Connect(const AUrl: string; const AHeaders: TArray<TClientHeader>; const AQueryParams: TArray<TClientQueryParam>);
    procedure Disconnect;
    procedure SendMessage(const AMessage: string);
    procedure SetOnMessage(const ACallback: TProc<string>);
    procedure SetOnClose(const ACallback: TProc<Exception>);
    function IsConnected: Boolean;
  end;

  // -------------------------------------------------------------
  // Hub Connection Implementation
  // -------------------------------------------------------------
  TDextHubConnection = class(TInterfacedObject, IDextHubConnection)
  private
    FUrl: string;
    FTransportType: TClientTransportType;
    FHeaders: TArray<TClientHeader>;
    FQueryParams: TArray<TClientQueryParam>;
    FState: THubConnectionState;
    FConnectionId: string;
    FTransport: IHubClientTransport;
    FRegistry: THubCallbackRegistry;
    FOnConnected: TOnHubConnected;
    FOnDisconnected: TOnHubDisconnected;
    FProtocol: IHubProtocol;
    FLock: TCriticalSection;
    FPingThread: TThread;
    FStopPing: Boolean;
    FMarshalToMainThread: Boolean;
    FInvocationIdCounter: Integer;
    FPendingInvokes: TDictionary<string, TValue>;

    // Negotiation
    procedure Negotiate;
    procedure InitializeHandshake;
    procedure StartPingLoop;
    procedure StopPingLoop;
    procedure HandleIncomingMessage(const AData: string);
    procedure HandleDisconnect(const AError: Exception);
  public
    constructor Create(const AUrl: string; ATransportType: TClientTransportType;
      const AHeaders: TArray<TClientHeader>; const AQueryParams: TArray<TClientQueryParam>;
      AMarshalToMainThread: Boolean);
    destructor Destroy; override;

    // IDextHubConnection
    function GetState: THubConnectionState;
    function GetConnectionId: string;
    procedure Start;
    procedure Stop;
    procedure On(const AEventName: string; const ACallback: TProc<string>); overload;
    procedure On(const AEventName: string; const ACallback: TProc<string, string>); overload;
    procedure On(const AEventName: string; const AArgTypes: TArray<PTypeInfo>; const ACallbackRef: IHubCallback); overload;
    procedure OnConnected(const ACallback: TOnHubConnected);
    procedure OnDisconnected(const ACallback: TOnHubDisconnected);
    procedure Send(const AMethodName: string; const AArgs: TArray<TValue>);
    procedure Invoke(const AMethodName: string; const AArgs: TArray<TValue>; 
      const AResultType: PTypeInfo; const ACallback: TValue); overload;
    procedure Invoke<T>(const AMethodName: string; const AArgs: TArray<TValue>; const ACallback: TInvokeCallback<T>); overload;
  end;

{ THubCallbackRegistry }

constructor THubCallbackRegistry.Create;
begin
  inherited Create;
  FCallbacks := TDictionary<string, TList<TValue>>.Create;
  FLock := TCriticalSection.Create;
end;

destructor THubCallbackRegistry.Destroy;
var
  Val: TList<TValue>;
begin
  for Val in FCallbacks.Values do
    Val.Free;
  FCallbacks.Free;
  FLock.Free;
  inherited;
end;

procedure THubCallbackRegistry.RegisterCallback(const AEventName: string; const ACallback: TValue);
var
  List: TList<TValue>;
begin
  FLock.Enter;
  try
    if not FCallbacks.TryGetValue(AEventName.ToLower, List) then
    begin
      List := TList<TValue>.Create;
      FCallbacks.Add(AEventName.ToLower, List);
    end;
    List.Add(ACallback);
  finally
    FLock.Leave;
  end;
end;

procedure THubCallbackRegistry.Dispatch(const AEventName: string; const AArgs: TArray<TValue>);
var
  List: TList<TValue>;
  CB: TValue;
begin
  FLock.Enter;
  try
    if FCallbacks.TryGetValue(AEventName.ToLower, List) then
    begin
      for CB in List do
      begin
        // Native dispatch using Rtti invoking
        if CB.IsType<TProc<string>> then
        begin
          if Length(AArgs) >= 1 then
            CB.AsType<TProc<string>>()(AArgs[0].AsString)
          else
            CB.AsType<TProc<string>>()('');
        end
        else if CB.IsType<TProc<string, string>> then
        begin
          if Length(AArgs) >= 2 then
            CB.AsType<TProc<string, string>>()(AArgs[0].AsString, AArgs[1].AsString)
          else if Length(AArgs) = 1 then
            CB.AsType<TProc<string, string>>()(AArgs[0].AsString, '')
          else
            CB.AsType<TProc<string, string>>()('', '');
        end
        else
        begin
          // Custom interface callback
          if CB.IsType<IHubCallback> then
            CB.AsType<IHubCallback>.Execute(AArgs);
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

{ TDextHubConnectionBuilder }

constructor TDextHubConnectionBuilder.Create;
begin
  inherited Create;
  FTransport := ctWebSocket;
  FHeaders := TList<TClientHeader>.Create;
  FQueryParams := TList<TClientQueryParam>.Create;
  FMarshalToMainThread := False;
end;

destructor TDextHubConnectionBuilder.Destroy;
begin
  FHeaders.Free;
  FQueryParams.Free;
  inherited;
end;

class function TDextHubConnectionBuilder.New: TDextHubConnectionBuilder;
begin
  Result := TDextHubConnectionBuilder.Create;
end;

function TDextHubConnectionBuilder.WithUrl(const AUrl: string): TDextHubConnectionBuilder;
begin
  FUrl := AUrl;
  Result := Self;
end;

function TDextHubConnectionBuilder.WithTransport(const ATransport: TClientTransportType): TDextHubConnectionBuilder;
begin
  FTransport := ATransport;
  Result := Self;
end;

function TDextHubConnectionBuilder.WithHeader(const AName, AValue: string): TDextHubConnectionBuilder;
var
  Header: TClientHeader;
begin
  Header.Name := AName;
  Header.Value := AValue;
  FHeaders.Add(Header);
  Result := Self;
end;

function TDextHubConnectionBuilder.WithQueryParam(const AName, AValue: string): TDextHubConnectionBuilder;
var
  Param: TClientQueryParam;
begin
  Param.Name := AName;
  Param.Value := AValue;
  FQueryParams.Add(Param);
  Result := Self;
end;

function TDextHubConnectionBuilder.WithUIThreadMarshaling(AMarshal: Boolean): TDextHubConnectionBuilder;
begin
  FMarshalToMainThread := AMarshal;
  Result := Self;
end;

function TDextHubConnectionBuilder.Build: IDextHubConnection;
begin
  try
    Result := TDextHubConnection.Create(FUrl, FTransport, FHeaders.ToArray, FQueryParams.ToArray, FMarshalToMainThread);
  finally
    Self.Free;
  end;
end;

{ TSSEClientTransport }

constructor TSSEClientTransport.Create;
begin
  inherited Create;
  FHTTPClient := THTTPClient.Create;
  FLock := TCriticalSection.Create;
  FConnected := False;
end;

destructor TSSEClientTransport.Destroy;
begin
  Disconnect;
  FHTTPClient.Free;
  FLock.Free;
  inherited;
end;

procedure TSSEClientTransport.Connect(const AUrl: string; const AHeaders: TArray<TClientHeader>;
  const AQueryParams: TArray<TClientQueryParam>);
var
  FullUrl: string;
  P: TClientQueryParam;
begin
  FLock.Enter;
  try
    if FConnected then Exit;
    FUrl := AUrl;
    FHeaders := AHeaders;
    FQueryParams := AQueryParams;

    FullUrl := FUrl;
    if Length(FQueryParams) > 0 then
    begin
      if not FullUrl.Contains('?') then
        FullUrl := FullUrl + '?'
      else
        FullUrl := FullUrl + '&';

      for P in FQueryParams do
        FullUrl := FullUrl + TNetEncoding.URL.Encode(P.Name) + '=' + TNetEncoding.URL.Encode(P.Value) + '&';
      FullUrl := FullUrl.TrimRight(['&']);
    end;

    FConnected := True;
    FThread := TThread.CreateAnonymousThread(StreamThreadProc);
    FThread.FreeOnTerminate := False;
    FThread.Start;
  finally
    FLock.Leave;
  end;
end;

procedure TSSEClientTransport.Disconnect;
begin
  FLock.Enter;
  try
    if not FConnected then Exit;
    FConnected := False;
  finally
    FLock.Leave;
  end;

  if Assigned(FThread) then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
end;

procedure TSSEClientTransport.SendMessage(const AMessage: string);
var
  PostClient: THTTPClient;
  Headers: TList<TNetHeader>;
  H: TClientHeader;
  Stream: TStringStream;
  FullUrl: string;
  P: TClientQueryParam;
begin
  // SSE uses separate POST request to send messages to the server
  PostClient := THTTPClient.Create;
  Headers := TList<TNetHeader>.Create;
  Stream := TStringStream.Create(AMessage, TEncoding.UTF8);
  try
    Headers.Add(TNetHeader.Create('Content-Type', 'text/plain;charset=UTF-8'));
    for H in FHeaders do
      Headers.Add(TNetHeader.Create(H.Name, H.Value));

    FullUrl := FUrl;
    if Length(FQueryParams) > 0 then
    begin
      if not FullUrl.Contains('?') then
        FullUrl := FullUrl + '?'
      else
        FullUrl := FullUrl + '&';
      for P in FQueryParams do
        FullUrl := FullUrl + TNetEncoding.URL.Encode(P.Name) + '=' + TNetEncoding.URL.Encode(P.Value) + '&';
      FullUrl := FullUrl.TrimRight(['&']);
    end;

    PostClient.Post(FullUrl, Stream, nil, Headers.ToArray);
  finally
    Stream.Free;
    Headers.Free;
    PostClient.Free;
  end;
end;

procedure TSSEClientTransport.SetOnMessage(const ACallback: TProc<string>);
begin
  FOnMessage := ACallback;
end;

procedure TSSEClientTransport.SetOnClose(const ACallback: TProc<Exception>);
begin
  FOnClose := ACallback;
end;

function TSSEClientTransport.IsConnected: Boolean;
begin
  Result := FConnected;
end;

procedure TSSEClientTransport.StreamThreadProc;
var
  Headers: TList<TNetHeader>;
  H: TClientHeader;
  Response: IHTTPResponse;
  Stream: TStream;
  Reader: TStreamReader;
  Line: string;
  DataContent: string;
  FullUrl: string;
  P: TClientQueryParam;
begin
  Headers := TList<TNetHeader>.Create;
  try
    Headers.Add(TNetHeader.Create('Accept', 'text/event-stream'));
    for H in FHeaders do
      Headers.Add(TNetHeader.Create(H.Name, H.Value));

    FullUrl := FUrl;
    if Length(FQueryParams) > 0 then
    begin
      if not FullUrl.Contains('?') then
        FullUrl := FullUrl + '?'
      else
        FullUrl := FullUrl + '&';
      for P in FQueryParams do
        FullUrl := FullUrl + TNetEncoding.URL.Encode(P.Name) + '=' + TNetEncoding.URL.Encode(P.Value) + '&';
      FullUrl := FullUrl.TrimRight(['&']);
    end;

    try
      Response := FHTTPClient.Get(FullUrl, nil, Headers.ToArray);
      if Response.StatusCode <> 200 then
        raise Exception.CreateFmt('HTTP error %d: %s', [Response.StatusCode, Response.StatusText]);

      Stream := Response.ContentStream;
      Reader := TStreamReader.Create(Stream, TEncoding.UTF8);
      try
        while FConnected and not TThread.CurrentThread.CheckTerminated do
        begin
          Line := Reader.ReadLine;
          if Line = '' then Continue;

          if Line.StartsWith('data:') then
          begin
            DataContent := Line.Substring(5).Trim;
            if Assigned(FOnMessage) then
              FOnMessage(DataContent);
          end;
        end;
      finally
        Reader.Free;
      end;
    except
      on E: Exception do
      begin
        if FConnected and Assigned(FOnClose) then
          FOnClose(E);
      end;
    end;
  finally
    Headers.Free;
    FConnected := False;
    if Assigned(FOnClose) then
      FOnClose(nil);
  end;
end;

{ TWebSocketClientTransport }

constructor TWebSocketClientTransport.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FConnected := False;
end;

destructor TWebSocketClientTransport.Destroy;
begin
  Disconnect;
  FLock.Free;
  inherited;
end;

procedure TWebSocketClientTransport.Connect(const AUrl: string; const AHeaders: TArray<TClientHeader>;
  const AQueryParams: TArray<TClientQueryParam>);
var
  URI: TURI;
  FullUrl: string;
  P: TClientQueryParam;
begin
  FLock.Enter;
  try
    if FConnected then Exit;

    FullUrl := AUrl;
    if Length(AQueryParams) > 0 then
    begin
      if not FullUrl.Contains('?') then
        FullUrl := FullUrl + '?'
      else
        FullUrl := FullUrl + '&';
      for P in AQueryParams do
        FullUrl := FullUrl + TNetEncoding.URL.Encode(P.Name) + '=' + TNetEncoding.URL.Encode(P.Value) + '&';
      FullUrl := FullUrl.TrimRight(['&']);
    end;

    URI := TURI.Create(FullUrl);
    FSocket := TSocket.Create(TSocketType.TCP);
    FSocket.Connect('', URI.Host, '', URI.Port);

    PerformHandshake(URI, AHeaders);

    FConnected := True;
    FThread := TThread.CreateAnonymousThread(ReadThreadProc);
    FThread.FreeOnTerminate := False;
    FThread.Start;
  except
    on E: Exception do
    begin
      if Assigned(FSocket) then FreeAndNil(FSocket);
      raise;
    end;
  end;
  FLock.Leave;
end;

procedure TWebSocketClientTransport.Disconnect;
begin
  FLock.Enter;
  try
    if not FConnected then Exit;
    FConnected := False;
  finally
    FLock.Leave;
  end;

  if Assigned(FSocket) then
  begin
    FSocket.Close;
  end;

  if Assigned(FThread) then
  begin
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;

  if Assigned(FSocket) then
  begin
    FreeAndNil(FSocket);
  end;
end;

procedure TWebSocketClientTransport.SendMessage(const AMessage: string);
var
  Frame: TWebSocketFrame;
  Encoded: TBytes;
begin
  FLock.Enter;
  try
    if not FConnected then Exit;

    Frame.FIN := True;
    Frame.Opcode := wsText;
    Frame.Masked := True;
    Frame.Payload := TEncoding.UTF8.GetBytes(AMessage);
    Frame.PayloadLength := Length(Frame.Payload);
    
    // Generate random 4-byte mask key
    Frame.MaskKey[0] := Random(256);
    Frame.MaskKey[1] := Random(256);
    Frame.MaskKey[2] := Random(256);
    Frame.MaskKey[3] := Random(256);

    Encoded := TWebSocketFrameCodec.Encode(Frame);
    FSocket.Send(Encoded);
  finally
    FLock.Leave;
  end;
end;

procedure TWebSocketClientTransport.SetOnMessage(const ACallback: TProc<string>);
begin
  FOnMessage := ACallback;
end;

procedure TWebSocketClientTransport.SetOnClose(const ACallback: TProc<Exception>);
begin
  FOnClose := ACallback;
end;

function TWebSocketClientTransport.IsConnected: Boolean;
begin
  Result := FConnected;
end;

procedure TWebSocketClientTransport.PerformHandshake(const AURI: TURI; const AHeaders: TArray<TClientHeader>);
var
  HandshakeStr: string;
  H: TClientHeader;
  ResponseStr: string;
  Buffer: TBytes;
  BytesRead: Integer;
begin
  HandshakeStr := 'GET ' + AURI.Path + AURI.Query + ' HTTP/1.1' + #13#10 +
                  'Host: ' + AURI.Host + ':' + AURI.Port.ToString + #13#10 +
                  'Upgrade: websocket' + #13#10 +
                  'Connection: Upgrade' + #13#10 +
                  'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' + #13#10 +
                  'Sec-WebSocket-Version: 13' + #13#10;
                  
  for H in AHeaders do
    HandshakeStr := HandshakeStr + H.Name + ': ' + H.Value + #13#10;
  HandshakeStr := HandshakeStr + #13#10;

  FSocket.Send(TEncoding.UTF8.GetBytes(HandshakeStr));

  SetLength(Buffer, 4096);
  BytesRead := FSocket.Receive(Buffer, 0, Length(Buffer));
  if BytesRead <= 0 then
    raise Exception.Create('WebSocket connection failed during handshake');

  ResponseStr := TEncoding.UTF8.GetString(Buffer, 0, BytesRead);
  if not ResponseStr.Contains('101') then
    raise Exception.CreateFmt('WebSocket handshake rejected: %s', [ResponseStr]);
end;

procedure TWebSocketClientTransport.ReadThreadProc;
var
  Buffer: TBytes;
  BufferOffset: Integer;
  BytesRead: Integer;
  Frame: TWebSocketFrame;
  BytesConsumed: Integer;
  PayloadStr: string;
  Pong: TBytes;
begin
  SetLength(Buffer, 65536);
  BufferOffset := 0;

  try
    while FConnected and not TThread.CurrentThread.CheckTerminated do
    begin
      BytesRead := FSocket.Receive(Buffer, BufferOffset, Length(Buffer) - BufferOffset);
      if BytesRead <= 0 then
        Break;

      Inc(BufferOffset, BytesRead);

      while BufferOffset > 0 do
      begin
        BytesConsumed := 0;
        if TWebSocketFrameCodec.TryDecode(Buffer, 0, BufferOffset, Frame, BytesConsumed) then
        begin
          case Frame.Opcode of
            wsText:
            begin
              PayloadStr := TEncoding.UTF8.GetString(Frame.Payload);
              if Assigned(FOnMessage) then
                FOnMessage(PayloadStr);
            end;
            wsClose:
            begin
              FConnected := False;
              Break;
            end;
            wsPing:
            begin
              // Respond with pong
              Pong := TWebSocketFrameCodec.EncodePong(Frame.Payload);
              FSocket.Send(Pong);
            end;
          end;

          if BytesConsumed > 0 then
          begin
            if BytesConsumed < BufferOffset then
              Move(Buffer[BytesConsumed], Buffer[0], BufferOffset - BytesConsumed);
            Dec(BufferOffset, BytesConsumed);
          end
          else
            Break;
        end
        else
          Break;
      end;
    end;
  except
    on E: Exception do
    begin
      if FConnected and Assigned(FOnClose) then
        FOnClose(E);
    end;
  end;

  FConnected := False;
  if Assigned(FOnClose) then
    FOnClose(nil);
end;

{ TDextHubConnection }

constructor TDextHubConnection.Create(const AUrl: string; ATransportType: TClientTransportType;
  const AHeaders: TArray<TClientHeader>; const AQueryParams: TArray<TClientQueryParam>;
  AMarshalToMainThread: Boolean);
begin
  inherited Create;
  FUrl := AUrl;
  FTransportType := ATransportType;
  FHeaders := AHeaders;
  FQueryParams := AQueryParams;
  FMarshalToMainThread := AMarshalToMainThread;
  FState := csDisconnected;
  FRegistry := THubCallbackRegistry.Create;
  FProtocol := TJsonHubProtocol.Create;
  FLock := TCriticalSection.Create;
  FInvocationIdCounter := 0;
  FPendingInvokes := TDictionary<string, TValue>.Create;
end;

destructor TDextHubConnection.Destroy;
begin
  Stop;
  FRegistry.Free;
  FLock.Free;
  FPendingInvokes.Free;
  inherited;
end;

function TDextHubConnection.GetState: THubConnectionState;
begin
  Result := FState;
end;

function TDextHubConnection.GetConnectionId: string;
begin
  Result := FConnectionId;
end;

procedure TDextHubConnection.Start;
var
  LId: string;
  LQueueProc: TThreadProcedure;
begin
  FLock.Enter;
  try
    if FState <> csDisconnected then Exit;
    FState := csConnecting;

    // 1. Negotiate connection
    Negotiate;

    // 2. Instantiate correct transport
    if FTransportType = ctWebSocket then
      FTransport := TWebSocketClientTransport.Create
    else
      FTransport := TSSEClientTransport.Create;

    FTransport.SetOnMessage(procedure(Msg: string) begin HandleIncomingMessage(Msg); end);
    FTransport.SetOnClose(procedure(E: Exception) begin HandleDisconnect(E); end);

    // 3. Connect transport
    FTransport.Connect(FUrl, FHeaders, FQueryParams);

    FState := csConnected;

    // 4. Send SignalR Handshake
    InitializeHandshake;

    // 5. Start Heartbeat
    StartPingLoop;

    if Assigned(FOnConnected) then
    begin
      LId := FConnectionId;
      if FMarshalToMainThread then
      begin
        LQueueProc := procedure begin FOnConnected(LId); end;
        TThread.Queue(nil, LQueueProc);
      end
      else
        FOnConnected(LId);
    end;
  except
    on E: Exception do
    begin
      FState := csDisconnected;
      FTransport := nil;
      raise;
    end;
  end;
  FLock.Leave;
end;

procedure TDextHubConnection.Stop;
var
  LQueueProc: TThreadProcedure;
begin
  FLock.Enter;
  try
    if FState = csDisconnected then Exit;
    FState := csDisconnected;

    StopPingLoop;

    if Assigned(FTransport) then
    begin
      FTransport.Disconnect;
      FTransport := nil;
    end;

    if Assigned(FOnDisconnected) then
    begin
      if FMarshalToMainThread then
      begin
        LQueueProc := procedure begin FOnDisconnected(nil); end;
        TThread.Queue(nil, LQueueProc);
      end
      else
        FOnDisconnected(nil);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TDextHubConnection.Negotiate;
var
  HTTPClient: THTTPClient;
  Headers: TList<TNetHeader>;
  H: TClientHeader;
  NegotiateUrl: string;
  Response: IHTTPResponse;
  Json: TJSONObject;
  P: TClientQueryParam;
begin
  HTTPClient := THTTPClient.Create;
  Headers := TList<TNetHeader>.Create;
  try
    for H in FHeaders do
      Headers.Add(TNetHeader.Create(H.Name, H.Value));

    NegotiateUrl := FUrl;
    if not NegotiateUrl.EndsWith('/') then
      NegotiateUrl := NegotiateUrl + '/';
    NegotiateUrl := NegotiateUrl + 'negotiate';

    // Build Query String if any
    if Length(FQueryParams) > 0 then
    begin
      NegotiateUrl := NegotiateUrl + '?';
      for P in FQueryParams do
        NegotiateUrl := NegotiateUrl + TNetEncoding.URL.Encode(P.Name) + '=' + TNetEncoding.URL.Encode(P.Value) + '&';
      NegotiateUrl := NegotiateUrl.TrimRight(['&']);
    end;

    Response := HTTPClient.Post(NegotiateUrl, TStream(nil), nil, Headers.ToArray);
    if Response.StatusCode = 200 then
    begin
      Json := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
      if Assigned(Json) then
      begin
        try
          FConnectionId := Json.GetValue<string>('connectionId', '');
        finally
          Json.Free;
        end;
      end;
    end;
  finally
    Headers.Free;
    HTTPClient.Free;
  end;
end;

procedure TDextHubConnection.InitializeHandshake;
begin
  // Handshake JSON message followed by Record Separator
  FTransport.SendMessage('{"protocol":"json","version":1}' + #$1E);
end;

procedure TDextHubConnection.StartPingLoop;
begin
  FStopPing := False;
  FPingThread := TThread.CreateAnonymousThread(
    procedure
    begin
      while not FStopPing and not TThread.CurrentThread.CheckTerminated do
      begin
        TThread.Sleep(15000);
        if FStopPing then Break;

        FLock.Enter;
        try
          if (FState = csConnected) and Assigned(FTransport) then
          begin
            FTransport.SendMessage(TJsonHubProtocol.SerializePing);
          end;
        finally
          FLock.Leave;
        end;
      end;
    end);
  FPingThread.FreeOnTerminate := False;
  FPingThread.Start;
end;

procedure TDextHubConnection.StopPingLoop;
begin
  FStopPing := True;
  if Assigned(FPingThread) then
  begin
    FPingThread.Terminate;
    FPingThread.WaitFor;
    FreeAndNil(FPingThread);
  end;
end;

procedure TDextHubConnection.HandleIncomingMessage(const AData: string);
var
  Msg: THubMessage;
  InvId: string;
  LCallback: TValue;
  Msgs: TArray<string>;
  M: string;
  LQueueProc: TThreadProcedure;
  LTarget: string;
  LArgs: TArray<TValue>;
begin
  Msgs := AData.Split([#$1E]);
  for M in Msgs do
  begin
    if M = '' then Continue;
    try
      Msg := FProtocol.Deserialize(M + #$1E);
      case Msg.MessageType of
        hmtInvocation:
        begin
          // Dispatch to callbacks
          if FMarshalToMainThread then
          begin
            LTarget := Msg.Target;
            LArgs := Msg.Arguments;
            LQueueProc := procedure begin FRegistry.Dispatch(LTarget, LArgs); end;
            TThread.Queue(nil, LQueueProc);
          end
          else
            FRegistry.Dispatch(Msg.Target, Msg.Arguments);
        end;
        hmtCompletion:
        begin
          InvId := Msg.InvocationId;
          FLock.Enter;
          try
            if FPendingInvokes.TryGetValue(InvId, LCallback) then
            begin
              FPendingInvokes.Remove(InvId);
              
              if FMarshalToMainThread then
              begin
                LQueueProc := procedure begin end;
                TThread.Queue(nil, LQueueProc);
              end;
            end;
          finally
            FLock.Leave;
          end;
        end;
      end;
    except
      // Ignore invalid JSON frames
    end;
  end;
end;

procedure TDextHubConnection.HandleDisconnect(const AError: Exception);
begin
  FLock.Enter;
  try
    if FState = csDisconnected then Exit;
    
    // Automatic reconnection attempt (exponential backoff)
    if FState = csConnected then
    begin
      FState := csReconnecting;
      StopPingLoop;
      
      TThread.CreateAnonymousThread(
        procedure
        var
          RetryDelay: Integer;
          RetryCount: Integer;
          LQueueProc: TThreadProcedure;
        begin
          RetryDelay := 1000;
          RetryCount := 0;
          while (FState = csReconnecting) and (RetryCount < 5) do
          begin
            TThread.Sleep(RetryDelay);
            Inc(RetryCount);
            RetryDelay := RetryDelay * 2;
            
            try
              FTransport.Disconnect;
              FTransport.Connect(FUrl, FHeaders, FQueryParams);
              FState := csConnected;
              InitializeHandshake;
              StartPingLoop;
              Exit;
            except
              // Continue retrying
            end;
          end;
          
          // Failed to reconnect, disconnect fully
          FState := csDisconnected;
          if Assigned(FOnDisconnected) then
          begin
            if FMarshalToMainThread then
            begin
              LQueueProc := procedure begin FOnDisconnected(AError); end;
              TThread.Queue(nil, LQueueProc);
            end
            else
              FOnDisconnected(AError);
          end;
        end).Start;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TDextHubConnection.On(const AEventName: string; const ACallback: TProc<string>);
begin
  FRegistry.RegisterCallback(AEventName, TValue.From<TProc<string>>(ACallback));
end;

procedure TDextHubConnection.On(const AEventName: string; const ACallback: TProc<string, string>);
begin
  FRegistry.RegisterCallback(AEventName, TValue.From<TProc<string, string>>(ACallback));
end;

procedure TDextHubConnection.On(const AEventName: string; const AArgTypes: TArray<PTypeInfo>; const ACallbackRef: IHubCallback);
begin
  FRegistry.RegisterCallback(AEventName, TValue.From<IHubCallback>(ACallbackRef));
end;

procedure TDextHubConnection.OnConnected(const ACallback: TOnHubConnected);
begin
  FOnConnected := ACallback;
end;

procedure TDextHubConnection.OnDisconnected(const ACallback: TOnHubDisconnected);
begin
  FOnDisconnected := ACallback;
end;

procedure TDextHubConnection.Send(const AMethodName: string; const AArgs: TArray<TValue>);
var
  Payload: string;
begin
  FLock.Enter;
  try
    if FState <> csConnected then
      raise Exception.Create('Hub Connection is not connected');

    Payload := TJsonHubProtocol.SerializeInvocation(AMethodName, AArgs);
    FTransport.SendMessage(Payload);
  finally
    FLock.Leave;
  end;
end;

procedure TDextHubConnection.Invoke(const AMethodName: string; const AArgs: TArray<TValue>; 
  const AResultType: PTypeInfo; const ACallback: TValue);
var
  InvId: string;
  Msg: THubMessage;
  Payload: string;
begin
  FLock.Enter;
  try
    if FState <> csConnected then
      raise Exception.Create('Hub Connection is not connected');

    Inc(FInvocationIdCounter);
    InvId := FInvocationIdCounter.ToString;

    // Register pending invoke
    FPendingInvokes.Add(InvId, ACallback);

    Msg.MessageType := hmtInvocation;
    Msg.InvocationId := InvId;
    Msg.Target := AMethodName;
    Msg.Arguments := AArgs;

    Payload := FProtocol.Serialize(Msg);
    FTransport.SendMessage(Payload);
  finally
    FLock.Leave;
  end;
end;

procedure TDextHubConnection.Invoke<T>(const AMethodName: string; const AArgs: TArray<TValue>; 
  const ACallback: TInvokeCallback<T>);
begin
  Invoke(AMethodName, AArgs, TypeInfo(T), TValue.From<TInvokeCallback<T>>(ACallback));
end;

end.
