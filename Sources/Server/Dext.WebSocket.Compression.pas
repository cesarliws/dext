unit Dext.WebSocket.Compression;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.SysUtils,
  System.ZLib;

type
  EWebSocketCompressionError = class(Exception);

  TWebSocketDeflateContext = class
  private
    FDeflater: z_stream;
    FInflater: z_stream;
    FDeflaterReady: Boolean;
    FInflaterReady: Boolean;
    FNoContextTakeover: Boolean;
    FMaxDecompressedSize: Integer;
    procedure InitDeflater;
    procedure InitInflater;
  public
    constructor Create(ANoContextTakeover: Boolean = False;
      AMaxDecompressedSize: Integer = 16 * 1024 * 1024);
    destructor Destroy; override;
    function Compress(const AData: TBytes): TBytes;
    function Decompress(const AData: TBytes): TBytes;
  end;

  TWebSocketDeflatePool = class
  strict private
    class var FLock: TCriticalSection;
    class var FItems: TStack<TWebSocketDeflateContext>;
    class var FMaxRetained: Integer;
    class constructor Create;
    class destructor Destroy;
  public
    class function Acquire(
      AMaxDecompressedSize: Integer = 16 * 1024 * 1024): TWebSocketDeflateContext; static;
    class procedure Release(AContext: TWebSocketDeflateContext); static;
  end;

implementation

const
  OUTPUT_CHUNK_SIZE = 16 * 1024;

constructor TWebSocketDeflateContext.Create(ANoContextTakeover: Boolean;
  AMaxDecompressedSize: Integer);
begin
  inherited Create;
  FNoContextTakeover := ANoContextTakeover;
  if AMaxDecompressedSize <= 0 then
    raise EArgumentOutOfRangeException.Create(
      'Maximum decompressed WebSocket message size must be positive');
  FMaxDecompressedSize := AMaxDecompressedSize;
end;

destructor TWebSocketDeflateContext.Destroy;
begin
  if FDeflaterReady then
    deflateEnd(FDeflater);
  if FInflaterReady then
    inflateEnd(FInflater);
  inherited;
end;

procedure TWebSocketDeflateContext.InitDeflater;
begin
  if FDeflaterReady then Exit;
  FDeflater := Default(z_stream);
  if deflateInit2(FDeflater, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -15, 8,
    Z_DEFAULT_STRATEGY) <> Z_OK then
    raise EWebSocketCompressionError.Create('Unable to initialize raw DEFLATE');
  FDeflaterReady := True;
end;

procedure TWebSocketDeflateContext.InitInflater;
begin
  if FInflaterReady then Exit;
  FInflater := Default(z_stream);
  if inflateInit2(FInflater, -15) <> Z_OK then
    raise EWebSocketCompressionError.Create('Unable to initialize raw INFLATE');
  FInflaterReady := True;
end;

function TWebSocketDeflateContext.Compress(const AData: TBytes): TBytes;
var
  Chunk: array[0..OUTPUT_CHUNK_SIZE - 1] of Byte;
  Produced, OldLength: Integer;
  Status: Integer;
begin
  InitDeflater;
  Result := nil;
  if Length(AData) > 0 then
    FDeflater.next_in := @AData[0]
  else
    FDeflater.next_in := nil;
  FDeflater.avail_in := Length(AData);
  repeat
    FDeflater.next_out := @Chunk[0];
    FDeflater.avail_out := Length(Chunk);
    Status := deflate(FDeflater, Z_SYNC_FLUSH);
    if (Status <> Z_OK) and (Status <> Z_BUF_ERROR) then
      raise EWebSocketCompressionError.CreateFmt(
        'Raw DEFLATE failed with status %d', [Status]);
    Produced := Length(Chunk) - Integer(FDeflater.avail_out);
    if Produced > 0 then
    begin
      OldLength := Length(Result);
      SetLength(Result, OldLength + Produced);
      Move(Chunk[0], Result[OldLength], Produced);
    end;
  until (FDeflater.avail_in = 0) and (FDeflater.avail_out <> 0);

  if (Length(Result) < 4) or
     (Result[High(Result) - 3] <> $00) or
     (Result[High(Result) - 2] <> $00) or
     (Result[High(Result) - 1] <> $FF) or
     (Result[High(Result)] <> $FF) then
    raise EWebSocketCompressionError.Create('Invalid DEFLATE sync-flush tail');
  SetLength(Result, Length(Result) - 4);

  if FNoContextTakeover and (deflateReset(FDeflater) <> Z_OK) then
    raise EWebSocketCompressionError.Create('Unable to reset DEFLATE context');
end;

function TWebSocketDeflateContext.Decompress(const AData: TBytes): TBytes;
var
  Input: TBytes;
  Chunk: array[0..OUTPUT_CHUNK_SIZE - 1] of Byte;
  Produced, OldLength: Integer;
  Status: Integer;
begin
  InitInflater;
  SetLength(Input, Length(AData) + 4);
  if Length(AData) > 0 then
    Move(AData[0], Input[0], Length(AData));
  Input[Length(AData)] := $00;
  Input[Length(AData) + 1] := $00;
  Input[Length(AData) + 2] := $FF;
  Input[Length(AData) + 3] := $FF;
  FInflater.next_in := @Input[0];
  FInflater.avail_in := Length(Input);
  Result := nil;
  repeat
    FInflater.next_out := @Chunk[0];
    FInflater.avail_out := Length(Chunk);
    Status := inflate(FInflater, Z_SYNC_FLUSH);
    if (Status <> Z_OK) and (Status <> Z_STREAM_END) and
       not ((Status = Z_BUF_ERROR) and (FInflater.avail_in = 0)) then
      raise EWebSocketCompressionError.CreateFmt(
        'Raw INFLATE failed with status %d', [Status]);
    Produced := Length(Chunk) - Integer(FInflater.avail_out);
    if Produced > 0 then
    begin
      OldLength := Length(Result);
      if OldLength > FMaxDecompressedSize - Produced then
        raise EWebSocketCompressionError.Create(
          'Decompressed WebSocket message exceeds configured limit');
      SetLength(Result, OldLength + Produced);
      Move(Chunk[0], Result[OldLength], Produced);
    end;
  until ((FInflater.avail_in = 0) and (FInflater.avail_out <> 0)) or
        (Status = Z_STREAM_END);

  if FNoContextTakeover and (inflateReset(FInflater) <> Z_OK) then
    raise EWebSocketCompressionError.Create('Unable to reset INFLATE context');
end;

class constructor TWebSocketDeflatePool.Create;
begin
  FLock := TCriticalSection.Create;
  FItems := TStack<TWebSocketDeflateContext>.Create;
  FMaxRetained := TThread.ProcessorCount * 2;
  if FMaxRetained < 4 then FMaxRetained := 4;
  if FMaxRetained > 256 then FMaxRetained := 256;
end;

class destructor TWebSocketDeflatePool.Destroy;
var
  Context: TWebSocketDeflateContext;
begin
  for Context in FItems do
    Context.Free;
  FItems.Free;
  FLock.Free;
end;

class function TWebSocketDeflatePool.Acquire(
  AMaxDecompressedSize: Integer): TWebSocketDeflateContext;
begin
  FLock.Enter;
  try
    if FItems.Count > 0 then
      Result := FItems.Pop
    else
      Result := nil;
  finally
    FLock.Leave;
  end;
  if Result = nil then
    Result := TWebSocketDeflateContext.Create(True, AMaxDecompressedSize);
end;

class procedure TWebSocketDeflatePool.Release(
  AContext: TWebSocketDeflateContext);
var
  Retain: Boolean;
begin
  if AContext = nil then Exit;
  FLock.Enter;
  try
    Retain := FItems.Count < FMaxRetained;
    if Retain then
      FItems.Push(AContext);
  finally
    FLock.Leave;
  end;
  if not Retain then
    AContext.Free;
end;

end.
