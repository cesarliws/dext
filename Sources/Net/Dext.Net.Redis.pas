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
unit Dext.Net.Redis;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Core.Span,
  Dext.Net.Tcp,
  Dext.Threading.Async,
  Dext.Collections.Channels,
  Dext.Json,
  Dext.DI.Interfaces,
  Dext.Net.Security,
  Dext.Net.Security.OpenSSL;

type
  /// <summary>
  ///   Exception class thrown for Redis communication or protocol errors.
  /// </summary>
  EDextRedisException = class(Exception);

  /// <summary>
  ///   Supported Redis protocol value types.
  /// </summary>
  TDextRedisValueType = (
    rvNull,
    rvSimpleString,
    rvError,
    rvInteger,
    rvBulkString,
    rvArray,
    rvBoolean,
    rvDouble
  );

  /// <summary>
  ///   Zero-allocation/low-allocation representation of Redis responses.
  /// </summary>
  TDextRedisValue = record
  private
    FType: TDextRedisValueType;
    FRawSpan: TByteSpan;
    FIntegerValue: Int64;
    FDoubleValue: Double;
    FBooleanValue: Boolean;
    FArrayValue: TArray<TDextRedisValue>;
  public
    /// <summary>Creates a Redis value representing a Null response.</summary>
    class function CreateNull: TDextRedisValue; static;
    /// <summary>Creates a Redis value representing a Simple String response.</summary>
    class function CreateSimpleString(const ASpan: TByteSpan): TDextRedisValue; static;
    /// <summary>Creates a Redis value representing an Error response.</summary>
    class function CreateError(const ASpan: TByteSpan): TDextRedisValue; static;
    /// <summary>Creates a Redis value representing an Integer response.</summary>
    class function CreateInteger(AValue: Int64): TDextRedisValue; static;
    /// <summary>Creates a Redis value representing a Bulk String response.</summary>
    class function CreateBulkString(const ASpan: TByteSpan): TDextRedisValue; static;
    /// <summary>Creates a Redis value representing an Array response.</summary>
    class function CreateArray(const AArray: TArray<TDextRedisValue>): TDextRedisValue; static;
    /// <summary>Creates a Redis value representing a Boolean response (RESP3).</summary>
    class function CreateBoolean(AValue: Boolean): TDextRedisValue; static;
    /// <summary>Creates a Redis value representing a Double response (RESP3).</summary>
    class function CreateDouble(AValue: Double): TDextRedisValue; static;

    /// <summary>Gets the type of the Redis value.</summary>
    property ValueType: TDextRedisValueType read FType;
    /// <summary>Gets the raw byte span of the response.</summary>
    property RawSpan: TByteSpan read FRawSpan;
    /// <summary>Gets the value as an integer.</summary>
    property AsInteger: Int64 read FIntegerValue;
    /// <summary>Gets the value as a double float.</summary>
    property AsDouble: Double read FDoubleValue;
    /// <summary>Gets the value as a boolean.</summary>
    property AsBoolean: Boolean read FBooleanValue;
    /// <summary>Gets the elements of the response as a Redis value array.</summary>
    property AsArray: TArray<TDextRedisValue> read FArrayValue;

    /// <summary>Returns true if the value is null.</summary>
    function IsNull: Boolean;
    /// <summary>Converts the value to a string representation.</summary>
    function AsString: string;
  end;

  /// <summary>
  ///   Zero-allocation parsing helper for RESP2/RESP3.
  /// </summary>
  TDextRedisParser = record
  public
    /// <summary>Attempts to parse a Redis response from the provided buffer span.</summary>
    class function TryParse(const ABuffer: TByteSpan; out AValue: TDextRedisValue; out ABytesConsumed: Integer): Boolean; static;
  end;

  /// <summary>
  ///   High-performance TCP wrapper for Redis socket connections with optional SSL/TLS support.
  /// </summary>
  TDextRedisConnection = class
  private
    FTcpClient: TDextTcpClient;
    FHost: string;
    FPort: Word;
    FLock: TCriticalSection;
    FTLSOptions: TDextTLSOptions;
    FTLSEngine: IDextTLSEngine;
    FTLSNetworkBuffer: TBytes;
    FReceiveBuffer: TBytes;
    procedure PerformTlsHandshake;
    procedure DrainTlsOutput;
    procedure FeedTlsInput;
    procedure WriteTlsPlaintext(const AData: TBytes);
  public
    FBuffer: TBytes;
    FBufferLen: Integer;
    /// <summary>Appends incoming bytes to the connection buffer.</summary>
    procedure AppendData(const AData: TByteSpan);
    /// <summary>Shifts the connection buffer window after consuming bytes.</summary>
    procedure ShiftBuffer(ACount: Integer);
  public
    /// <summary>Initializes a connection with host and port details.</summary>
    constructor Create(const AHost: string; APort: Word); overload;
    /// <summary>Initializes a connection with host, port, and TLS configuration.</summary>
    constructor Create(const AHost: string; APort: Word; const ATLSOptions: TDextTLSOptions); overload;
    /// <summary>Frees connection resources.</summary>
    destructor Destroy; override;

    /// <summary>Establishes socket connection.</summary>
    procedure Connect;
    /// <summary>Gracefully disconnects the socket connection.</summary>
    procedure Disconnect;
    /// <summary>Returns true if currently connected.</summary>
    function Connected: Boolean;

    /// <summary>Executes a Redis command and returns the response.</summary>
    function ExecuteCommand(const ACommand: string; const AArgs: TArray<string>): TDextRedisValue;
    /// <summary>Executes a Redis command asynchronously.</summary>
    function ExecuteCommandAsync(const ACommand: string; const AArgs: TArray<string>): TAsyncBuilder<TDextRedisValue>;
  end;

  /// <summary>
  ///   Connection pool manager for TDextRedisConnection instances.
  /// </summary>
  TDextRedisConnectionPool = class
  private
    FHost: string;
    FPort: Word;
    FMaxPoolSize: Integer;
    FPool: IStack<TDextRedisConnection>;
    FLock: TCriticalSection;
    FCount: Integer;
    FTLSOptions: TDextTLSOptions;
  public
    /// <summary>Initializes a connection pool with size boundaries.</summary>
    constructor Create(const AHost: string; APort: Word; AMaxPoolSize: Integer = 16); overload;
    /// <summary>Initializes a connection pool with TLS options and size boundaries.</summary>
    constructor Create(const AHost: string; APort: Word; const ATLSOptions: TDextTLSOptions; AMaxPoolSize: Integer = 16); overload;
    /// <summary>Cleans and destroys the connection pool.</summary>
    destructor Destroy; override;

    /// <summary>Acquires a connection from the pool, creating one if empty.</summary>
    function Acquire: TDextRedisConnection;
    /// <summary>Releases a connection back into the pool.</summary>
    procedure Release(AConnection: TDextRedisConnection);
    /// <summary>Disconnects and clears all pooled connections.</summary>
    procedure Clear;

    /// <summary>Gets or sets the maximum size of the connection pool.</summary>
    property MaxPoolSize: Integer read FMaxPoolSize write FMaxPoolSize;
    /// <summary>Gets the current number of active connections managed by the pool.</summary>
    property CurrentCount: Integer read FCount;
  end;

  /// <summary>
  ///   Represents a Redis Pub/Sub message payload.
  /// </summary>
  TDextRedisMessage = record
    /// <summary>The channel the message was sent to.</summary>
    Channel: string;
    /// <summary>The payload content of the message.</summary>
    Payload: string;
  end;

  /// <summary>
  ///   Dedicated class for Redis Pub/Sub operations.
  /// </summary>
  TDextRedisPubSub = class
  private
    FConnection: TDextRedisConnection;
    FChannelMap: IDictionary<string, IChannel<TDextRedisMessage>>;
    FMapLock: TCriticalSection;
    FReaderThread: TThread;
    FActive: Boolean;
    procedure ReaderLoop;
  public
    /// <summary>Initializes Pub/Sub client connection.</summary>
    constructor Create(const AHost: string; APort: Word); overload;
    /// <summary>Initializes Pub/Sub client connection with TLS configuration.</summary>
    constructor Create(const AHost: string; APort: Word; const ATLSOptions: TDextTLSOptions); overload;
    /// <summary>Cleans Pub/Sub client connection.</summary>
    destructor Destroy; override;

    /// <summary>Subscribes to a channel, returning a concurrent channel.</summary>
    function Subscribe(const AChannelName: string): IChannel<TDextRedisMessage>;
    /// <summary>Unsubscribes from a channel.</summary>
    procedure Unsubscribe(const AChannelName: string);
  end;

  /// <summary>
  ///   The developer-facing native Redis client.
  /// </summary>
  TDextRedisClient = class
  private
    FPool: TDextRedisConnectionPool;
    FPubSub: TDextRedisPubSub;
  public
    /// <summary>Initializes the client with connection parameters.</summary>
    constructor Create(const AHost: string = 'localhost'; APort: Word = 6379; AMaxPoolSize: Integer = 16); overload;
    constructor Create(const AHost: string; APort: Word; const ATLSOptions: TDextTLSOptions; AMaxPoolSize: Integer = 16); overload;
    /// <summary>Cleans the client resources.</summary>
    destructor Destroy; override;

    /// <summary>Executes a command and returns the parsed value.</summary>
    function Execute(const ACommand: string; const AArgs: TArray<string>): TDextRedisValue;
    /// <summary>Executes a command asynchronously.</summary>
    function ExecuteAsync(const ACommand: string; const AArgs: TArray<string>): TAsyncBuilder<TDextRedisValue>;

    /// <summary>Retrieves a string value by key.</summary>
    function Get(const AKey: string): string;
    /// <summary>Sets a string value by key, with optional expiration.</summary>
    function SetVal(const AKey: string; const AValue: string; AExpireSeconds: Integer = 0): Boolean;
    /// <summary>Deletes a key from Redis.</summary>
    function Del(const AKey: string): Integer;
    /// <summary>Sets a key's time to live in seconds.</summary>
    function Expire(const AKey: string; ASeconds: Integer): Boolean;

    /// <summary>Sets a JSON object in RedisJSON at a path.</summary>
    function JsonSet(const AKey: string; const APath: string; const AJsonObject: TObject): Boolean;
    /// <summary>Retrieves and deserializes a JSON object from RedisJSON.</summary>
    function JsonGet<T: class, constructor>(const AKey: string; const APath: string = '$'): T;

    /// <summary>Sets a field in a Redis Hash.</summary>
    procedure HSet(const AKey: string; const AField: string; const AValue: string);
    /// <summary>Gets a field value from a Redis Hash.</summary>
    function HGet(const AKey: string; const AField: string): string;

    /// <summary>Prepends a value to a list.</summary>
    function LPush(const AKey: string; const AValue: string): Integer;
    /// <summary>Removes and returns the last element of a list.</summary>
    function RPop(const AKey: string): string;

    /// <summary>Adds a member to a set.</summary>
    function SAdd(const AKey: string; const AMember: string): Integer;
    /// <summary>Checks if a member belongs to a set.</summary>
    function SIsMember(const AKey: string; const AMember: string): Boolean;

    /// <summary>Subscribes to a Pub/Sub channel.</summary>
    function Subscribe(const AChannel: string): IChannel<TDextRedisMessage>;
    /// <summary>Publishes a message to a channel.</summary>
    procedure Publish(const AChannel: string; const AMessage: string);

    /// <summary>Executes a Lua script on the server side.</summary>
    function Eval(const AScript: string; const AKeys: TArray<string> = []; const AArgs: TArray<string> = []): TDextRedisValue;
  end;

  TDextTLSOptions = Dext.Net.Security.TDextTLSOptions;
  TDextTLSOptionsBuilder = Dext.Net.Security.TDextTLSOptionsBuilder;
  TDextTLSBuilder = Dext.Net.Security.TDextTLSBuilder;

/// <summary> Registers the Redis client in the Dependency Injection container. </summary>
procedure RegisterRedisClient(const AServices: IServiceCollection; const AHost: string = 'localhost'; APort: Word = 6379);

implementation

procedure RegisterRedisClient(const AServices: IServiceCollection; const AHost: string; APort: Word);
var
  Factory: TFunc<IServiceProvider, TObject>;
begin
  Factory := function(C: IServiceProvider): TObject
    begin
      Result := TDextRedisClient.Create(AHost, APort);
    end;

  AServices.AddSingleton(
    TServiceType.FromClass(TDextRedisClient),
    TDextRedisClient,
    Factory
  );
end;

function TryReadLine(const ABuffer: TByteSpan; AStart: Integer; out ALine: TByteSpan; out ABytesConsumed: Integer): Boolean;
var
  Idx: Integer;
begin
  Result := False;
  ALine := TByteSpan.Create(nil, 0);
  ABytesConsumed := 0;
  Idx := ABuffer.IndexOf(13, AStart); // Carriage Return '\r' = 13
  if Idx >= 0 then
  begin
    if (Idx + 1 < ABuffer.Length) and (ABuffer[Idx + 1] = 10) then // Line Feed '\n' = 10
    begin
      ALine := ABuffer.Slice(AStart, Idx - AStart);
      ABytesConsumed := (Idx + 2) - AStart;
      Result := True;
    end;
  end;
end;

{ TDextRedisValue }

class function TDextRedisValue.CreateNull: TDextRedisValue;
begin
  Result.FType := rvNull;
end;

class function TDextRedisValue.CreateSimpleString(const ASpan: TByteSpan): TDextRedisValue;
begin
  Result.FType := rvSimpleString;
  Result.FRawSpan := ASpan;
end;

class function TDextRedisValue.CreateError(const ASpan: TByteSpan): TDextRedisValue;
begin
  Result.FType := rvError;
  Result.FRawSpan := ASpan;
end;

class function TDextRedisValue.CreateInteger(AValue: Int64): TDextRedisValue;
begin
  Result.FType := rvInteger;
  Result.FIntegerValue := AValue;
end;

class function TDextRedisValue.CreateBulkString(const ASpan: TByteSpan): TDextRedisValue;
begin
  Result.FType := rvBulkString;
  Result.FRawSpan := ASpan;
end;

class function TDextRedisValue.CreateArray(const AArray: TArray<TDextRedisValue>): TDextRedisValue;
begin
  Result.FType := rvArray;
  Result.FArrayValue := AArray;
end;

class function TDextRedisValue.CreateBoolean(AValue: Boolean): TDextRedisValue;
begin
  Result.FType := rvBoolean;
  Result.FBooleanValue := AValue;
end;

class function TDextRedisValue.CreateDouble(AValue: Double): TDextRedisValue;
begin
  Result.FType := rvDouble;
  Result.FDoubleValue := AValue;
end;

function TDextRedisValue.IsNull: Boolean;
begin
  Result := FType = rvNull;
end;

function TDextRedisValue.AsString: string;
begin
  case FType of
    rvSimpleString, rvError, rvBulkString:
      Result := FRawSpan.ToString;
    rvInteger:
      Result := FIntegerValue.ToString;
    rvBoolean:
      Result := BoolToStr(FBooleanValue, True);
    rvDouble:
      Result := FloatToStr(FDoubleValue);
    else
      Result := '';
  end;
end;

{ TDextRedisParser }

class function TDextRedisParser.TryParse(const ABuffer: TByteSpan; out AValue: TDextRedisValue; out ABytesConsumed: Integer): Boolean;
var
  Leader: Byte;
  Line: TByteSpan;
  LineBytes: Integer;
  ValStr: string;
  Len: Integer;
  i: Integer;
  ElemBytes: Integer;
  CurrentOffset: Integer;
  ParsedArray: TArray<TDextRedisValue>;
  ElemValue: TDextRedisValue;
begin
  Result := False;
  AValue := TDextRedisValue.CreateNull;
  ABytesConsumed := 0;
  if ABuffer.Length = 0 then Exit;

  Leader := ABuffer[0];
  case Leader of
    Byte('+'): // Simple String
    begin
      if TryReadLine(ABuffer, 1, Line, LineBytes) then
      begin
        AValue := TDextRedisValue.CreateSimpleString(Line);
        ABytesConsumed := 1 + LineBytes;
        Result := True;
      end;
    end;
    Byte('-'): // Error
    begin
      if TryReadLine(ABuffer, 1, Line, LineBytes) then
      begin
        AValue := TDextRedisValue.CreateError(Line);
        ABytesConsumed := 1 + LineBytes;
        Result := True;
      end;
    end;
    Byte(':'): // Integer
    begin
      if TryReadLine(ABuffer, 1, Line, LineBytes) then
      begin
        ValStr := Line.ToString;
        AValue := TDextRedisValue.CreateInteger(StrToInt64(ValStr));
        ABytesConsumed := 1 + LineBytes;
        Result := True;
      end;
    end;
    Byte('$'): // Bulk String
    begin
      if TryReadLine(ABuffer, 1, Line, LineBytes) then
      begin
        ValStr := Line.ToString;
        Len := StrToInt(ValStr);
        if Len = -1 then
        begin
          AValue := TDextRedisValue.CreateNull;
          ABytesConsumed := 1 + LineBytes;
          Result := True;
        end
        else if Len >= 0 then
        begin
          if ABuffer.Length >= 1 + LineBytes + Len + 2 then
          begin
            if (ABuffer[1 + LineBytes + Len] = 13) and (ABuffer[1 + LineBytes + Len + 1] = 10) then
            begin
              AValue := TDextRedisValue.CreateBulkString(ABuffer.Slice(1 + LineBytes, Len));
              ABytesConsumed := 1 + LineBytes + Len + 2;
              Result := True;
            end;
          end;
        end;
      end;
    end;
    Byte('*'): // Array
    begin
      if TryReadLine(ABuffer, 1, Line, LineBytes) then
      begin
        ValStr := Line.ToString;
        Len := StrToInt(ValStr);
        if Len = -1 then
        begin
          AValue := TDextRedisValue.CreateNull;
          ABytesConsumed := 1 + LineBytes;
          Result := True;
        end
        else if Len >= 0 then
        begin
          SetLength(ParsedArray, Len);
          CurrentOffset := 1 + LineBytes;
          for i := 0 to Len - 1 do
          begin
            if not TryParse(ABuffer.Slice(CurrentOffset), ElemValue, ElemBytes) then
              Exit(False);
            ParsedArray[i] := ElemValue;
            CurrentOffset := CurrentOffset + ElemBytes;
          end;
          AValue := TDextRedisValue.CreateArray(ParsedArray);
          ABytesConsumed := CurrentOffset;
          Result := True;
        end;
      end;
    end;
    Byte('_'): // RESP3 Null
    begin
      if TryReadLine(ABuffer, 1, Line, LineBytes) then
      begin
        AValue := TDextRedisValue.CreateNull;
        ABytesConsumed := 1 + LineBytes;
        Result := True;
      end;
    end;
    Byte('#'): // RESP3 Boolean
    begin
      if TryReadLine(ABuffer, 1, Line, LineBytes) then
      begin
        if Line.Length > 0 then
        begin
          AValue := TDextRedisValue.CreateBoolean(Line[0] = Byte('t'));
          ABytesConsumed := 1 + LineBytes;
          Result := True;
        end;
      end;
    end;
    Byte(','): // RESP3 Double
    begin
      if TryReadLine(ABuffer, 1, Line, LineBytes) then
      begin
        ValStr := Line.ToString;
        AValue := TDextRedisValue.CreateDouble(StrToFloat(ValStr, FormatSettings.Invariant));
        ABytesConsumed := 1 + LineBytes;
        Result := True;
      end;
    end;
  end;
end;

function BuildRedisCommand(const ACommand: string; const AArgs: TArray<string>): TBytes;
var
  SB: TStringBuilder;
  RawStr: string;
  Arg: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('*').Append((1 + Length(AArgs)).ToString).Append(#13#10);
    SB.Append('$').Append(TEncoding.UTF8.GetByteCount(ACommand).ToString).Append(#13#10).Append(ACommand).Append(#13#10);
    for Arg in AArgs do
    begin
      SB.Append('$').Append(TEncoding.UTF8.GetByteCount(Arg).ToString).Append(#13#10).Append(Arg).Append(#13#10);
    end;
    RawStr := SB.ToString;
    Result := TEncoding.UTF8.GetBytes(RawStr);
  finally
    SB.Free;
  end;
end;

{ TDextRedisConnection }

constructor TDextRedisConnection.Create(const AHost: string; APort: Word);
begin
  Create(AHost, APort, Default(TDextTLSOptions));
end;

constructor TDextRedisConnection.Create(const AHost: string; APort: Word; const ATLSOptions: TDextTLSOptions);
begin
  inherited Create;
  FHost := AHost;
  FPort := APort;
  FTLSOptions := ATLSOptions;
  FTLSOptions.Host := AHost;
  FTcpClient := TDextTcpClient.Create;
  FLock := TCriticalSection.Create;
  FBufferLen := 0;
  SetLength(FTLSNetworkBuffer, 16 * 1024);
  SetLength(FReceiveBuffer, 16 * 1024);
end;

destructor TDextRedisConnection.Destroy;
begin
  Disconnect;
  FTcpClient.Free;
  FLock.Free;
  inherited;
end;

procedure TDextRedisConnection.PerformTlsHandshake;
var
  Provider: IDextTLSContextProvider;
  Status: TDextTLSEngineStatus;
  LoopCount: Integer;
begin
  Provider := TDextOpenSSLContextProvider.Create(FTLSOptions);
  FTLSEngine := Provider.CreateEngine(tlsmClient);

  LoopCount := 0;
  while not FTLSEngine.IsHandshakeCompleted do
  begin
    Inc(LoopCount);
    if LoopCount > 50 then
      raise EDextRedisException.Create('TLS handshake timeout: exceeded 50 iterations');

    Status := FTLSEngine.DoHandshake;
    DrainTlsOutput;

    if FTLSEngine.IsHandshakeCompleted or (Status = tlsHandshakeCompleted) then
      Break;

    if Status = tlsHandshakeNeedRead then
      FeedTlsInput
    else if Status = tlsError then
      raise EDextRedisException.CreateFmt(
        'TLS handshake failed at loop %d (OpenSSL error %d).',
        [LoopCount, FTLSEngine.GetLastErrorCode]);
  end;
end;

procedure TDextRedisConnection.DrainTlsOutput;
var
  BytesWritten: Integer;
begin
  repeat
    BytesWritten := FTLSEngine.EncryptedOutgoing(
      @FTLSNetworkBuffer[0], Length(FTLSNetworkBuffer));
    if BytesWritten > 0 then
      FTcpClient.Send(TByteSpan.Create(@FTLSNetworkBuffer[0], BytesWritten));
  until BytesWritten = 0;
end;

procedure TDextRedisConnection.FeedTlsInput;
var
  BytesRead: Integer;
begin
  BytesRead := FTcpClient.Receive(
    TByteSpan.Create(@FTLSNetworkBuffer[0], Length(FTLSNetworkBuffer)), 5000);
  if BytesRead <= 0 then
    raise EDextRedisException.Create(
      'Redis server closed the TLS connection unexpectedly');
  if FTLSEngine.EncryptedIncoming(
    @FTLSNetworkBuffer[0], BytesRead) <> BytesRead then
    raise EDextRedisException.Create(
      'OpenSSL input BIO did not accept all encrypted bytes');
end;

procedure TDextRedisConnection.WriteTlsPlaintext(const AData: TBytes);
var
  Offset: Integer;
  Written: Integer;
begin
  Offset := 0;
  while Offset < Length(AData) do
  begin
    Written := FTLSEngine.PlaintextWrite(
      @AData[Offset], Length(AData) - Offset);
    DrainTlsOutput;
    if Written > 0 then
      Inc(Offset, Written)
    else
      case FTLSEngine.GetLastIOStatus of
        tlsIONeedRead:
          FeedTlsInput;
        tlsIONeedWrite:
          Continue;
        tlsIOClosed:
          raise EDextRedisException.Create(
            'TLS connection closed while writing Redis command');
      else
        raise EDextRedisException.CreateFmt(
          'TLS write failed (OpenSSL error %d)',
          [FTLSEngine.GetLastErrorCode]);
      end;
  end;
  DrainTlsOutput;
end;

procedure TDextRedisConnection.Connect;
begin
  FTcpClient.Connect(FHost, FPort);
  if FTLSOptions.Enabled then
    PerformTlsHandshake;
end;

procedure TDextRedisConnection.Disconnect;
begin
  FTLSEngine := nil;
  FTcpClient.Disconnect;
  FBufferLen := 0;
end;

function TDextRedisConnection.Connected: Boolean;
begin
  Result := FTcpClient.Connected;
end;

procedure TDextRedisConnection.AppendData(const AData: TByteSpan);
begin
  if AData.Length = 0 then Exit;
  if FBufferLen + AData.Length > Length(FBuffer) then
    SetLength(FBuffer, (FBufferLen + AData.Length) * 2 + 1024);
  Move(AData.Data^, FBuffer[FBufferLen], AData.Length);
  FBufferLen := FBufferLen + AData.Length;
end;

procedure TDextRedisConnection.ShiftBuffer(ACount: Integer);
begin
  if (ACount <= 0) or (ACount > FBufferLen) then Exit;
  if ACount < FBufferLen then
  begin
    Move(FBuffer[ACount], FBuffer[0], FBufferLen - ACount);
    FBufferLen := FBufferLen - ACount;
  end
  else
  begin
    FBufferLen := 0;
  end;
end;

function TDextRedisConnection.ExecuteCommand(const ACommand: string; const AArgs: TArray<string>): TDextRedisValue;
var
  ReqBytes: TBytes;
  ParsedValue: TDextRedisValue;
  BytesConsumed: Integer;
  ReadSpan: TByteSpan;
  PlainCount: Integer;
begin
  FLock.Enter;
  try
    if not Connected then
      Connect;

    ReqBytes := BuildRedisCommand(ACommand, AArgs);
    if FTLSOptions.Enabled and Assigned(FTLSEngine) then
      WriteTlsPlaintext(ReqBytes)
    else
    begin
      // Plain TCP Send
      FTcpClient.Send(ReqBytes);
    end;

    while True do
    begin
      if FBufferLen > 0 then
      begin
        ReadSpan := TByteSpan.Create(@FBuffer[0], FBufferLen);
        if TDextRedisParser.TryParse(ReadSpan, ParsedValue, BytesConsumed) then
        begin
          ShiftBuffer(BytesConsumed);
          if ParsedValue.ValueType = rvError then
            raise EDextRedisException.Create(ParsedValue.AsString);
          Exit(ParsedValue);
        end;
      end;

      if FTLSOptions.Enabled and Assigned(FTLSEngine) then
      begin
        FeedTlsInput;
        repeat
          PlainCount := FTLSEngine.PlaintextRead(
            @FReceiveBuffer[0], Length(FReceiveBuffer));
          if PlainCount > 0 then
            AppendData(TByteSpan.Create(@FReceiveBuffer[0], PlainCount));
        until PlainCount = 0;
        if FTLSEngine.GetLastIOStatus = tlsIOError then
          raise EDextRedisException.CreateFmt(
            'TLS read failed (OpenSSL error %d)',
            [FTLSEngine.GetLastErrorCode]);
      end
      else
      begin
        // Plain TCP Recv
        PlainCount := FTcpClient.Receive(
          TByteSpan.Create(@FReceiveBuffer[0], Length(FReceiveBuffer)), 5000);
        if PlainCount <= 0 then
          raise EDextRedisException.Create('Redis server closed connection unexpectedly');
        AppendData(TByteSpan.Create(@FReceiveBuffer[0], PlainCount));
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TDextRedisConnection.ExecuteCommandAsync(const ACommand: string; const AArgs: TArray<string>): TAsyncBuilder<TDextRedisValue>;
var
  Func: TFunc<TDextRedisValue>;
begin
  Func := function: TDextRedisValue
    begin
      Result := ExecuteCommand(ACommand, AArgs);
    end;
  Result := TAsyncTask.Run<TDextRedisValue>(Func);
end;

{ TDextRedisConnectionPool }

constructor TDextRedisConnectionPool.Create(const AHost: string; APort: Word; AMaxPoolSize: Integer);
begin
  Create(AHost, APort, Default(TDextTLSOptions), AMaxPoolSize);
end;

constructor TDextRedisConnectionPool.Create(const AHost: string; APort: Word; const ATLSOptions: TDextTLSOptions; AMaxPoolSize: Integer);
begin
  inherited Create;
  FHost := AHost;
  FPort := APort;
  FTLSOptions := ATLSOptions;
  FMaxPoolSize := AMaxPoolSize;
  FPool := TCollections.CreateStack<TDextRedisConnection>;
  FLock := TCriticalSection.Create;
  FCount := 0;
end;

destructor TDextRedisConnectionPool.Destroy;
begin
  Clear;
  // FPool is managed
  FLock.Free;
  inherited;
end;

function TDextRedisConnectionPool.Acquire: TDextRedisConnection;
begin
  FLock.Enter;
  try
    if FPool.Count > 0 then
    begin
      Result := FPool.Pop;
    end
    else
    begin
      Result := TDextRedisConnection.Create(FHost, FPort, FTLSOptions);
      Result.Connect;
      Inc(FCount);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TDextRedisConnectionPool.Release(AConnection: TDextRedisConnection);
begin
  if not Assigned(AConnection) then Exit;
  FLock.Enter;
  try
    if (FPool.Count < FMaxPoolSize) and AConnection.Connected then
    begin
      FPool.Push(AConnection);
    end
    else
    begin
      AConnection.Free;
      Dec(FCount);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TDextRedisConnectionPool.Clear;
var
  Conn: TDextRedisConnection;
begin
  FLock.Enter;
  try
    while FPool.Count > 0 do
    begin
      Conn := FPool.Pop;
      Conn.Free;
    end;
    FCount := 0;
  finally
    FLock.Leave;
  end;
end;

{ TDextRedisPubSub }

constructor TDextRedisPubSub.Create(const AHost: string; APort: Word);
begin
  Create(AHost, APort, Default(TDextTLSOptions));
end;

constructor TDextRedisPubSub.Create(const AHost: string; APort: Word; const ATLSOptions: TDextTLSOptions);
begin
  inherited Create;
  FConnection := TDextRedisConnection.Create(AHost, APort, ATLSOptions);
  FChannelMap := TCollections.CreateDictionary<string, IChannel<TDextRedisMessage>>;
  FMapLock := TCriticalSection.Create;
  FActive := False;
end;

destructor TDextRedisPubSub.Destroy;
begin
  FActive := False;
  if Assigned(FReaderThread) then
  begin
    FReaderThread.Terminate;
    FConnection.Disconnect; // Force close socket to unblock read
    FReaderThread.WaitFor;
    FReaderThread.Free;
  end;
  FConnection.Free;
  // FChannelMap is managed
  FMapLock.Free;
  inherited;
end;

function TDextRedisPubSub.Subscribe(const AChannelName: string): IChannel<TDextRedisMessage>;
var
  Chan: IChannel<TDextRedisMessage>;
begin
  FMapLock.Enter;
  try
    if not (FChannelMap.TryGetValue(AChannelName, Chan)) then
    begin
      Chan := TChannel<TDextRedisMessage>.CreateUnbounded;
      FChannelMap.Add(AChannelName, Chan);

      FConnection.ExecuteCommand('SUBSCRIBE', [AChannelName]);

      if not FActive then
      begin
        FActive := True;
        FReaderThread := TThread.CreateAnonymousThread(ReaderLoop);
        FReaderThread.FreeOnTerminate := False;
        FReaderThread.Start;
      end;
    end;
    Result := Chan;
  finally
    FMapLock.Leave;
  end;
end;

procedure TDextRedisPubSub.Unsubscribe(const AChannelName: string);
begin
  FMapLock.Enter;
  try
    if FChannelMap.ContainsKey(AChannelName) then
    begin
      FConnection.ExecuteCommand('UNSUBSCRIBE', [AChannelName]);
      FChannelMap.Remove(AChannelName);
    end;
  finally
    FMapLock.Leave;
  end;
end;

procedure TDextRedisPubSub.ReaderLoop;
var
  RecvBuf: TBytes;
  ReadSpan: TByteSpan;
  RecvCount: Integer;
  ParsedValue: TDextRedisValue;
  BytesConsumed: Integer;
  MsgType: string;
  MsgChan: string;
  MsgPayload: string;
  Chan: IChannel<TDextRedisMessage>;
  Msg: TDextRedisMessage;
begin
  SetLength(RecvBuf, 65536);
  while FActive do
  begin
    try
      if FConnection.FBufferLen > 0 then
      begin
        ReadSpan := TByteSpan.Create(@FConnection.FBuffer[0], FConnection.FBufferLen);
        if TDextRedisParser.TryParse(ReadSpan, ParsedValue, BytesConsumed) then
        begin
          FConnection.ShiftBuffer(BytesConsumed);

          if (ParsedValue.ValueType = rvArray) and (Length(ParsedValue.AsArray) >= 3) then
          begin
            MsgType := ParsedValue.AsArray[0].AsString;
            if MsgType = 'message' then
            begin
              MsgChan := ParsedValue.AsArray[1].AsString;
              MsgPayload := ParsedValue.AsArray[2].AsString;

              FMapLock.Enter;
              try
                if FChannelMap.TryGetValue(MsgChan, Chan) then
                begin
                  Msg.Channel := MsgChan;
                  Msg.Payload := MsgPayload;
                  Chan.TryWrite(Msg);
                end;
              finally
                FMapLock.Leave;
              end;
            end;
          end;
          Continue;
        end;
      end;

      RecvCount := FConnection.FTcpClient.Receive(RecvBuf, 5000);
      if RecvCount > 0 then
        FConnection.AppendData(TByteSpan.Create(@RecvBuf[0], RecvCount))
      else if RecvCount <= 0 then
        Sleep(10);
    except
      Sleep(10);
    end;
  end;
end;

{ TDextRedisClient }

constructor TDextRedisClient.Create(const AHost: string; APort: Word; AMaxPoolSize: Integer);
begin
  Create(AHost, APort, Default(TDextTLSOptions), AMaxPoolSize);
end;

constructor TDextRedisClient.Create(const AHost: string; APort: Word; const ATLSOptions: TDextTLSOptions; AMaxPoolSize: Integer);
begin
  inherited Create;
  FPool := TDextRedisConnectionPool.Create(AHost, APort, ATLSOptions, AMaxPoolSize);
  FPubSub := TDextRedisPubSub.Create(AHost, APort, ATLSOptions);
end;

destructor TDextRedisClient.Destroy;
begin
  FPubSub.Free;
  FPool.Free;
  inherited;
end;

function TDextRedisClient.Execute(const ACommand: string; const AArgs: TArray<string>): TDextRedisValue;
var
  Conn: TDextRedisConnection;
begin
  Conn := FPool.Acquire;
  try
    Result := Conn.ExecuteCommand(ACommand, AArgs);
  finally
    FPool.Release(Conn);
  end;
end;

function TDextRedisClient.ExecuteAsync(const ACommand: string; const AArgs: TArray<string>): TAsyncBuilder<TDextRedisValue>;
var
  Func: TFunc<TDextRedisValue>;
begin
  Func := function: TDextRedisValue
    begin
      Result := Execute(ACommand, AArgs);
    end;
  Result := TAsyncTask.Run<TDextRedisValue>(Func);
end;

function TDextRedisClient.Get(const AKey: string): string;
var
  Val: TDextRedisValue;
begin
  Val := Execute('GET', [AKey]);
  if Val.IsNull then
    Result := ''
  else
    Result := Val.AsString;
end;

function TDextRedisClient.SetVal(const AKey: string; const AValue: string; AExpireSeconds: Integer): Boolean;
var
  Args: TArray<string>;
  Val: TDextRedisValue;
begin
  if AExpireSeconds > 0 then
    Args := [AKey, AValue, 'EX', AExpireSeconds.ToString]
  else
    Args := [AKey, AValue];
  Val := Execute('SET', Args);
  Result := Val.AsString = 'OK';
end;

function TDextRedisClient.Del(const AKey: string): Integer;
var
  Val: TDextRedisValue;
begin
  Val := Execute('DEL', [AKey]);
  Result := Val.AsInteger;
end;

function TDextRedisClient.Expire(const AKey: string; ASeconds: Integer): Boolean;
var
  Val: TDextRedisValue;
begin
  Val := Execute('EXPIRE', [AKey, ASeconds.ToString]);
  Result := Val.AsInteger = 1;
end;

function TDextRedisClient.JsonSet(const AKey, APath: string; const AJsonObject: TObject): Boolean;
var
  JsonStr: string;
  Val: TDextRedisValue;
begin
  JsonStr := TDextJson.Serialize(AJsonObject);
  Val := Execute('JSON.SET', [AKey, APath, JsonStr]);
  Result := Val.AsString = 'OK';
end;

function TDextRedisClient.JsonGet<T>(const AKey, APath: string): T;
var
  Val: TDextRedisValue;
  JsonStr: string;
begin
  Val := Execute('JSON.GET', [AKey, APath]);
  if Val.IsNull then
    Exit(nil);
  JsonStr := Val.AsString;
  Result := TDextJson.Deserialize<T>(JsonStr);
end;

procedure TDextRedisClient.HSet(const AKey, AField, AValue: string);
begin
  Execute('HSET', [AKey, AField, AValue]);
end;

function TDextRedisClient.HGet(const AKey, AField: string): string;
var
  Val: TDextRedisValue;
begin
  Val := Execute('HGET', [AKey, AField]);
  if Val.IsNull then
    Result := ''
  else
    Result := Val.AsString;
end;

function TDextRedisClient.LPush(const AKey, AValue: string): Integer;
var
  Val: TDextRedisValue;
begin
  Val := Execute('LPUSH', [AKey, AValue]);
  Result := Val.AsInteger;
end;

function TDextRedisClient.RPop(const AKey: string): string;
var
  Val: TDextRedisValue;
begin
  Val := Execute('RPOP', [AKey]);
  if Val.IsNull then
    Result := ''
  else
    Result := Val.AsString;
end;

function TDextRedisClient.SAdd(const AKey, AMember: string): Integer;
var
  Val: TDextRedisValue;
begin
  Val := Execute('SADD', [AKey, AMember]);
  Result := Val.AsInteger;
end;

function TDextRedisClient.SIsMember(const AKey, AMember: string): Boolean;
var
  Val: TDextRedisValue;
begin
  Val := Execute('SISMEMBER', [AKey, AMember]);
  Result := Val.AsInteger = 1;
end;

function TDextRedisClient.Subscribe(const AChannel: string): IChannel<TDextRedisMessage>;
begin
  Result := FPubSub.Subscribe(AChannel);
end;

procedure TDextRedisClient.Publish(const AChannel, AMessage: string);
begin
  Execute('PUBLISH', [AChannel, AMessage]);
end;

function TDextRedisClient.Eval(const AScript: string; const AKeys, AArgs: TArray<string>): TDextRedisValue;
var
  Args: IList<string>;
  K: string;
  Val: string;
  i: Integer;
  CommandArgs: TArray<string>;
begin
  Args := TCollections.CreateList<string>;
  Args.Add(AScript);
  Args.Add(Length(AKeys).ToString);
  for K in AKeys do
    Args.Add(K);
  for Val in AArgs do
    Args.Add(Val);

  SetLength(CommandArgs, Args.Count);
  for i := 0 to Args.Count - 1 do
    CommandArgs[i] := Args[i];

  Result := Execute('EVAL', CommandArgs);
end;

end.
