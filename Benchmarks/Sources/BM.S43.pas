unit BM.S43;

interface

uses
  Spring.Benchmark;

procedure BM_S43_MessagePack_Roundtrip(const State: TState);
procedure BM_S43_MessagePack_Serialize(const State: TState);
procedure BM_S43_MessagePack_ComplexRoundtrip(const State: TState);
procedure BM_S43_Deflate_Compress(const State: TState);
procedure BM_S43_Deflate_Roundtrip(const State: TState);
procedure BM_S43_WebSocket_EncodeDecode(const State: TState);

implementation

uses
  System.Rtti,
  System.SysUtils,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Protocol.MessagePack,
  Dext.WebSocket.Compression,
  Dext.WebSocket.Protocol;

const
  S43_PAYLOAD =
    'The quick brown fox jumps over the lazy dog. ' +
    'S43 measures binary serialization and WebSocket transport cost.';

function CreateMessage: THubMessage;
begin
  // Ping is the smallest SignalR MessagePack vector and has no managed
  // argument array lifetime involved in the hot path benchmark.
  Result := THubMessage.Ping;
end;

function CreateComplexMessage: THubMessage;
begin
  Result := THubMessage.Invocation(
    'telemetry.publish',
    [TValue.From<string>('device-001'), TValue.From<Integer>(42),
     TValue.From<string>(string(S43_PAYLOAD))]);
  Result.InvocationId := 's43-invocation';
end;

procedure BM_S43_MessagePack_Roundtrip(const State: TState);
var
  Protocol: IHubProtocol;
  Message, Decoded: THubMessage;
  Data: TBytes;
  Consumed: Integer;
begin
  Protocol := TMessagePackHubProtocol.Create;
  Message := CreateMessage;
  Data := Protocol.SerializeBinary(Message);
  while State.KeepRunning do
  begin
    Decoded := Protocol.DeserializeBinary(Data, 0, Length(Data), Consumed);
    if (Consumed <> Length(Data)) or (Decoded.Target <> Message.Target) then
      raise EInvalidOpException.Create('MessagePack roundtrip invariant failed');
  end;
end;

procedure BM_S43_MessagePack_Serialize(const State: TState);
var
  Protocol: IHubProtocol;
  Message: THubMessage;
  Data: TBytes;
begin
  Protocol := TMessagePackHubProtocol.Create;
  Message := CreateMessage;
  while State.KeepRunning do
  begin
    Data := Protocol.SerializeBinary(Message);
    if Length(Data) = 0 then
      raise EInvalidOpException.Create('MessagePack produced an empty payload');
  end;
end;

procedure BM_S43_MessagePack_ComplexRoundtrip(const State: TState);
var
  Protocol: IHubProtocol;
  Message, Decoded: THubMessage;
  Data: TBytes;
  Consumed: Integer;
begin
  Protocol := TMessagePackHubProtocol.Create;
  Message := CreateComplexMessage;
  Data := Protocol.SerializeBinary(Message);
  while State.KeepRunning do
  begin
    Decoded := Protocol.DeserializeBinary(Data, 0, Length(Data), Consumed);
    if (Consumed <> Length(Data)) or
       (Decoded.Target <> Message.Target) or
       (Length(Decoded.Arguments) <> 3) or
       (Decoded.Arguments[1].AsInteger <> 42) then
      raise EInvalidOpException.Create('Complex MessagePack invariant failed');
  end;
end;

procedure BM_S43_Deflate_Compress(const State: TState);
var
  Context: TWebSocketDeflateContext;
  Input, Output: TBytes;
begin
  Input := TEncoding.UTF8.GetBytes(string(S43_PAYLOAD));
  Context := TWebSocketDeflateContext.Create(True);
  try
    while State.KeepRunning do
    begin
      Output := Context.Compress(Input);
      if Length(Output) = 0 then
        raise EInvalidOpException.Create('DEFLATE produced an empty payload');
    end;
  finally
    Context.Free;
  end;
end;

procedure BM_S43_Deflate_Roundtrip(const State: TState);
var
  Context: TWebSocketDeflateContext;
  Input, Compressed, Output: TBytes;
begin
  Input := TEncoding.UTF8.GetBytes(string(S43_PAYLOAD));
  Context := TWebSocketDeflateContext.Create(True);
  try
    Compressed := Context.Compress(Input);
    while State.KeepRunning do
    begin
      Output := Context.Decompress(Compressed);
      if not CompareMem(@Output[0], @Input[0], Length(Input)) then
        raise EInvalidOpException.Create('DEFLATE roundtrip invariant failed');
    end;
  finally
    Context.Free;
  end;
end;

procedure BM_S43_WebSocket_EncodeDecode(const State: TState);
var
  Payload, Frame: TBytes;
  Decoded: TWebSocketFrame;
  Consumed: Integer;
  DecodeResult: TWebSocketDecodeResult;
begin
  Payload := TEncoding.UTF8.GetBytes(string(S43_PAYLOAD));
  Frame := TWebSocketFrameCodec.EncodeText(string(S43_PAYLOAD));
  while State.KeepRunning do
  begin
    DecodeResult := TWebSocketFrameCodec.Decode(
      Frame, 0, Length(Frame), Decoded, Consumed, False, 1024 * 1024);
    if (DecodeResult <> wsDecodeComplete) or
       (Consumed <> Length(Frame)) or
       (Length(Decoded.Payload) <> Length(Payload)) then
      raise EInvalidOpException.Create('WebSocket frame invariant failed');
  end;
end;

initialization
  Benchmark(BM_S43_MessagePack_Roundtrip, 'BM_S43_MessagePack_Roundtrip').Threads(1);
  Benchmark(BM_S43_MessagePack_Serialize, 'BM_S43_MessagePack_Serialize').Threads(1);
  Benchmark(BM_S43_MessagePack_ComplexRoundtrip, 'BM_S43_MessagePack_ComplexRoundtrip').Threads(1);
  Benchmark(BM_S43_Deflate_Compress, 'BM_S43_Deflate_Compress').Threads(1);
  Benchmark(BM_S43_Deflate_Roundtrip, 'BM_S43_Deflate_Roundtrip').Threads(1);
  Benchmark(BM_S43_WebSocket_EncodeDecode, 'BM_S43_WebSocket_EncodeDecode').Threads(1);

end.
