{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}

unit Dext.Web.ResponseWriter;

{$POINTERMATH ON}

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  Dext.Core.Span;

type
  TDextReleaseProc = procedure(AOwner: Pointer);

  TDextBufferSegment = record
    Data: PByte;
    Length: Integer;
    Sent: Integer;
    Owner: Pointer;
    ReleaseProc: TDextReleaseProc;
  end;

  PDextBufferSegment = ^TDextBufferSegment;

  /// <summary>Advances ownership across a sequence of partially sent segments.</summary>
  TDextBufferCursor = record
  public
    /// <summary>
    ///   Applies a completed byte count, releases every completed owner once,
    ///   and updates the index and offset of the first pending byte.
    /// </summary>
    class procedure Advance(ASegments: PDextBufferSegment;
      ASegmentCount, ACompletedBytes: Integer; var ASegmentIndex,
      ASegmentOffset: Integer); static;
  end;

  TDextBufferNode = record
    Next: Pointer;
    SizeClass: Integer;
    OwnerCache: Pointer;
{$IFOPT C+}
    State: Integer;
{$ENDIF}
  end;
  PDextBufferNode = ^TDextBufferNode;

  PDextBufferCache = ^TDextBufferCache;
  TDextBufferCache = record
    Next: PDextBufferCache;
    Heads: array[0..4] of Pointer;
    Counts: array[0..4] of Integer;
  end;

  TDextBufferPool = class
  private
    class var FGlobalHeads: array[0..4] of Pointer;
    class var FGlobalCounts: array[0..4] of Integer;
    class var FLock: TObject;
    class var FCaches: PDextBufferCache;
    class var FActiveOperations: Integer;
    class var FResetting: Integer;
    class procedure BeginOperation; static;
    class procedure EndOperation; static;
    class function GetThreadCache: PDextBufferCache; static;
  public
    class constructor Create;
    class destructor Destroy;
    class function Rent(ASize: Integer; out ARentedSize: Integer): Pointer;
    class procedure Release(APtr: Pointer);
    class procedure ResetPools;
  end;

  TDextResponseWriter = record
  private
    FSegments: array[0..31] of TDextBufferSegment;
    FSegmentCount: Integer;
    FSegmentsCapacity: Integer;
    FSegmentsPtr: PDextBufferSegment;

    FCurrentSegmentIndex: Integer;
    FCurrentSegmentData: PByte;
    FCurrentSegmentRemaining: Integer;
    FCurrentSegmentTotal: Integer;

    procedure GrowSegments;
    procedure RentNewSegment(AMinSize: Integer);
  public
    procedure Init;
    procedure Clear;
    function GetSpan(AMinSize: Integer): TByteSpan;
    procedure Advance(ACount: Integer);
    procedure Write(const ASpan: TByteSpan);
    procedure AddExternal(AData: Pointer; ALength: Integer;
      AOwner: Pointer; AReleaseProc: TDextReleaseProc);
    function Reserve(ACount: Integer): TByteSpan;
    procedure DetachSegment(AIndex: Integer);
    procedure Reset;

    property Segments: PDextBufferSegment read FSegmentsPtr;
    property SegmentCount: Integer read FSegmentCount;
  end;
  PDextResponseWriter = ^TDextResponseWriter;

/// <summary>Writes bytes directly to a response writer sink context.</summary>
procedure WriteUtf8ToResponseWriter(AContext, AData: Pointer; ALength: Integer);

implementation

const
  DextLocalPoolLimit = 32;
  DextCrossThreadPoolLimit = 256;

threadvar
  FThreadBufferCache: PDextBufferCache;

procedure DefaultReleaseProc(AOwner: Pointer);
begin
  TDextBufferPool.Release(AOwner);
end;

function SizeToSizeClass(ASize: Integer; out AClassSize: Integer): Integer;
begin
  if ASize <= 4096 then
  begin
    AClassSize := 4096;
    Exit(0);
  end;
  if ASize <= 8192 then
  begin
    AClassSize := 8192;
    Exit(1);
  end;
  if ASize <= 16384 then
  begin
    AClassSize := 16384;
    Exit(2);
  end;
  if ASize <= 32768 then
  begin
    AClassSize := 32768;
    Exit(3);
  end;
  AClassSize := 65536;
  Result := 4;
end;

{ TDextBufferPool }

class procedure TDextBufferPool.BeginOperation;
begin
  while True do
  begin
    while TInterlocked.CompareExchange(FResetting, 0, 0) <> 0 do
      TThread.Yield;
    TInterlocked.Increment(FActiveOperations);
    if TInterlocked.CompareExchange(FResetting, 0, 0) = 0 then
      Exit;
    TInterlocked.Decrement(FActiveOperations);
  end;
end;

procedure WriteUtf8ToResponseWriter(AContext, AData: Pointer; ALength: Integer);
begin
  if ALength > 0 then
    PDextResponseWriter(AContext)^.Write(TByteSpan.Create(AData, ALength));
end;

{ TDextBufferCursor }

class procedure TDextBufferCursor.Advance(ASegments: PDextBufferSegment;
  ASegmentCount, ACompletedBytes: Integer; var ASegmentIndex,
  ASegmentOffset: Integer);
var
  Available: Integer;
  Segment: PDextBufferSegment;
begin
  if ACompletedBytes < 0 then
    raise EArgumentOutOfRangeException.Create(
      'Completed byte count cannot be negative');
  while ASegmentIndex < ASegmentCount do
  begin
    Segment := ASegments + ASegmentIndex;
    Available := Segment.Length - ASegmentOffset;
    if ACompletedBytes < Available then
    begin
      Inc(ASegmentOffset, ACompletedBytes);
      Exit;
    end;

    Dec(ACompletedBytes, Available);
    if Assigned(Segment.ReleaseProc) then
      Segment.ReleaseProc(Segment.Owner);
    Segment.Owner := nil;
    Segment.ReleaseProc := nil;
    Inc(ASegmentIndex);
    ASegmentOffset := 0;
  end;

  if ACompletedBytes <> 0 then
    raise EArgumentOutOfRangeException.Create(
      'Completed byte count exceeds pending segment bytes');
end;

class procedure TDextBufferPool.EndOperation;
begin
  TInterlocked.Decrement(FActiveOperations);
end;

class function TDextBufferPool.GetThreadCache: PDextBufferCache;
begin
  Result := FThreadBufferCache;
  if Result <> nil then
    Exit;

  GetMem(Result, SizeOf(TDextBufferCache));
  FillChar(Result^, SizeOf(TDextBufferCache), 0);
  TMonitor.Enter(FLock);
  try
    Result.Next := FCaches;
    FCaches := Result;
  finally
    TMonitor.Exit(FLock);
  end;
  FThreadBufferCache := Result;
end;

class constructor TDextBufferPool.Create;
begin
  FLock := TObject.Create;
end;

class destructor TDextBufferPool.Destroy;
var
  Cache: PDextBufferCache;
  NextCache: PDextBufferCache;
begin
  ResetPools;
  Cache := FCaches;
  while Cache <> nil do
  begin
    NextCache := Cache.Next;
    FreeMem(Cache);
    Cache := NextCache;
  end;
  FCaches := nil;
  FThreadBufferCache := nil;
  FLock.Free;
end;

class function TDextBufferPool.Rent(ASize: Integer;
  out ARentedSize: Integer): Pointer;
var
  Idx, ClassSize: Integer;
  Node: PDextBufferNode;
  Cache: PDextBufferCache;
begin
  BeginOperation;
  try
  if ASize > 65536 then
  begin
    GetMem(Node, ASize + SizeOf(TDextBufferNode));
    Node.Next := nil;
    Node.SizeClass := -1;
    Node.OwnerCache := nil;
{$IFOPT C+}
    Node.State := 1;
{$ENDIF}
    ARentedSize := ASize;
    Exit(PByte(Node) + SizeOf(TDextBufferNode));
  end;

  Idx := SizeToSizeClass(ASize, ClassSize);
  ARentedSize := ClassSize;
  Cache := GetThreadCache;

  Node := PDextBufferNode(Cache.Heads[Idx]);
  if Node <> nil then
  begin
    Cache.Heads[Idx] := Node.Next;
    Dec(Cache.Counts[Idx]);
  end;

  if Node = nil then
  begin
    TMonitor.Enter(FLock);
    try
      Node := PDextBufferNode(FGlobalHeads[Idx]);
      if Node <> nil then
      begin
        FGlobalHeads[Idx] := Node.Next;
        Dec(FGlobalCounts[Idx]);
      end;
    finally
      TMonitor.Exit(FLock);
    end;
  end;

  if Node <> nil then
  begin
{$IFOPT C+}
    Assert(Node.State = 0, 'Response buffer pool returned a rented node');
    Node.State := 1;
{$ENDIF}
    Node.OwnerCache := Cache;
    Exit(PByte(Node) + SizeOf(TDextBufferNode));
  end;

  GetMem(Node, ClassSize + SizeOf(TDextBufferNode));
  Node.Next := nil;
  Node.SizeClass := Idx;
  Node.OwnerCache := Cache;
{$IFOPT C+}
  Node.State := 1;
{$ENDIF}
  Result := PByte(Node) + SizeOf(TDextBufferNode);
  finally
    EndOperation;
  end;
end;

class procedure TDextBufferPool.Release(APtr: Pointer);
var
  Node: PDextBufferNode;
  Idx: Integer;
  Cache: PDextBufferCache;
begin
  BeginOperation;
  try
  if APtr = nil then
    Exit;
  Node := PDextBufferNode(PByte(APtr) - SizeOf(TDextBufferNode));
  Idx := Node.SizeClass;

  if (Idx < -1) or (Idx > 4) then
    raise EInvalidOp.Create('Invalid response buffer size class');
{$IFOPT C+}
  Assert(Node.State = 1, 'Response buffer released more than once');
  Node.State := 0;
{$ENDIF}

  if Idx = -1 then
  begin
    FreeMem(Node);
    Exit;
  end;

  Cache := FThreadBufferCache;
  if (Cache <> nil) and (Node.OwnerCache = Cache) then
  begin
    if Cache.Counts[Idx] >= DextLocalPoolLimit then
    begin
      FreeMem(Node);
      Exit;
    end;
    Node.Next := Cache.Heads[Idx];
    Cache.Heads[Idx] := Node;
    Inc(Cache.Counts[Idx]);
    Exit;
  end;

  TMonitor.Enter(FLock);
  try
    if FGlobalCounts[Idx] >= DextCrossThreadPoolLimit then
    begin
      FreeMem(Node);
      Exit;
    end;
    Node.Next := FGlobalHeads[Idx];
    FGlobalHeads[Idx] := Node;
    Inc(FGlobalCounts[Idx]);
  finally
    TMonitor.Exit(FLock);
  end;
  finally
    EndOperation;
  end;
end;

class procedure TDextBufferPool.ResetPools;
var
  Idx: Integer;
  Node, Temp: PDextBufferNode;
  Cache: PDextBufferCache;
begin
  while TInterlocked.CompareExchange(FResetting, 1, 0) <> 0 do
    TThread.Yield;
  while TInterlocked.CompareExchange(FActiveOperations, 0, 0) <> 0 do
    TThread.Yield;
  TMonitor.Enter(FLock);
  try
    for Idx := 0 to 4 do
    begin
      Node := PDextBufferNode(FGlobalHeads[Idx]);
      FGlobalHeads[Idx] := nil;
      FGlobalCounts[Idx] := 0;
      while Node <> nil do
      begin
        Temp := Node.Next;
        FreeMem(Node);
        Node := Temp;
      end;
    end;
    Cache := FCaches;
    while Cache <> nil do
    begin
      for Idx := 0 to 4 do
      begin
        Node := PDextBufferNode(Cache.Heads[Idx]);
        Cache.Heads[Idx] := nil;
        Cache.Counts[Idx] := 0;
        while Node <> nil do
        begin
          Temp := Node.Next;
          FreeMem(Node);
          Node := Temp;
        end;
      end;
      Cache := Cache.Next;
    end;
  finally
    TMonitor.Exit(FLock);
    TInterlocked.Exchange(FResetting, 0);
  end;
end;

{ TDextResponseWriter }

procedure TDextResponseWriter.Init;
begin
  Self := Default(TDextResponseWriter);
  FSegmentsPtr := @FSegments[0];
  FSegmentsCapacity := 32;
  FCurrentSegmentIndex := -1;
end;

procedure TDextResponseWriter.Clear;
begin
  Reset;
  if (FSegmentsPtr <> nil) and (FSegmentsPtr <> @FSegments[0]) then
    FreeMem(FSegmentsPtr);
  FSegmentsPtr := nil;
  FSegmentsCapacity := 0;
end;

procedure TDextResponseWriter.GrowSegments;
var
  NewCap: Integer;
  NewPtr: PDextBufferSegment;
begin
  NewCap := FSegmentsCapacity * 2;
  GetMem(NewPtr, NewCap * SizeOf(TDextBufferSegment));
  Move(FSegmentsPtr^, NewPtr^, FSegmentCount * SizeOf(TDextBufferSegment));
  if FSegmentsPtr <> @FSegments[0] then
    FreeMem(FSegmentsPtr);
  FSegmentsPtr := NewPtr;
  FSegmentsCapacity := NewCap;
end;

procedure TDextResponseWriter.RentNewSegment(AMinSize: Integer);
var
  RentedSize: Integer;
  Buf: Pointer;
  Seg: PDextBufferSegment;
begin
  if FCurrentSegmentIndex >= 0 then
  begin
    Seg := FSegmentsPtr + FCurrentSegmentIndex;
    Seg^.Length := FCurrentSegmentTotal - FCurrentSegmentRemaining;
  end;

  if AMinSize < 4096 then
    AMinSize := 4096;

  Buf := TDextBufferPool.Rent(AMinSize, RentedSize);

  if FSegmentCount >= FSegmentsCapacity then
    GrowSegments;

  FCurrentSegmentIndex := FSegmentCount;
  Seg := FSegmentsPtr + FCurrentSegmentIndex;
  Seg^.Data := PByte(Buf);
  Seg^.Length := 0;
  Seg^.Sent := 0;
  Seg^.Owner := Buf;
  Seg^.ReleaseProc := DefaultReleaseProc;
  Inc(FSegmentCount);

  FCurrentSegmentData := PByte(Buf);
  FCurrentSegmentRemaining := RentedSize;
  FCurrentSegmentTotal := RentedSize;
end;

function TDextResponseWriter.GetSpan(AMinSize: Integer): TByteSpan;
begin
  if (FCurrentSegmentIndex < 0) or (FCurrentSegmentRemaining < AMinSize) then
    RentNewSegment(AMinSize);

  Result := TByteSpan.Create(FCurrentSegmentData, FCurrentSegmentRemaining);
end;

procedure TDextResponseWriter.Advance(ACount: Integer);
var
  Seg: PDextBufferSegment;
begin
  if ACount < 0 then
    raise EArgumentException.Create('Invalid advance count');
  if ACount > FCurrentSegmentRemaining then
    raise EArgumentOutOfRangeException.Create('Advance exceeds remaining');

  FCurrentSegmentData := FCurrentSegmentData + ACount;
  FCurrentSegmentRemaining := FCurrentSegmentRemaining - ACount;

  if FCurrentSegmentIndex >= 0 then
  begin
    Seg := FSegmentsPtr + FCurrentSegmentIndex;
    Seg^.Length := FCurrentSegmentTotal - FCurrentSegmentRemaining;
  end;
end;

procedure TDextResponseWriter.Write(const ASpan: TByteSpan);
var
  SpanData: PByte;
  SpanLen: Integer;
  Chunk: Integer;
  Writable: TByteSpan;
begin
  SpanData := ASpan.Data;
  SpanLen := ASpan.Length;
  while SpanLen > 0 do
  begin
    Writable := GetSpan(1);
    Chunk := Writable.Length;
    if Chunk > SpanLen then
      Chunk := SpanLen;
    Move(SpanData^, Writable.Data^, Chunk);
    Advance(Chunk);
    SpanData := SpanData + Chunk;
    Dec(SpanLen, Chunk);
  end;
end;

procedure TDextResponseWriter.AddExternal(AData: Pointer; ALength: Integer;
  AOwner: Pointer; AReleaseProc: TDextReleaseProc);
var
  Seg: PDextBufferSegment;
begin
  if FCurrentSegmentIndex >= 0 then
  begin
    Seg := FSegmentsPtr + FCurrentSegmentIndex;
    Seg^.Length := FCurrentSegmentTotal - FCurrentSegmentRemaining;
    FCurrentSegmentIndex := -1;
    FCurrentSegmentData := nil;
    FCurrentSegmentRemaining := 0;
    FCurrentSegmentTotal := 0;
  end;

  if FSegmentCount >= FSegmentsCapacity then
    GrowSegments;

  Seg := FSegmentsPtr + FSegmentCount;
  Seg^.Data := PByte(AData);
  Seg^.Length := ALength;
  Seg^.Sent := 0;
  Seg^.Owner := AOwner;
  Seg^.ReleaseProc := AReleaseProc;
  Inc(FSegmentCount);
end;

function TDextResponseWriter.Reserve(ACount: Integer): TByteSpan;
begin
  if (FCurrentSegmentIndex < 0) or (FCurrentSegmentRemaining < ACount) then
    RentNewSegment(ACount);

  Result := TByteSpan.Create(FCurrentSegmentData, ACount);
  Advance(ACount);
end;

procedure TDextResponseWriter.DetachSegment(AIndex: Integer);
var
  Seg: PDextBufferSegment;
begin
  if (AIndex < 0) or (AIndex >= FSegmentCount) then
    raise EArgumentOutOfRangeException.Create('Invalid segment index');
  Seg := FSegmentsPtr + AIndex;
  Seg^.Owner := nil;
  Seg^.ReleaseProc := nil;
end;

procedure TDextResponseWriter.Reset;
var
  I: Integer;
  Seg: PDextBufferSegment;
begin
  for I := 0 to FSegmentCount - 1 do
  begin
    Seg := FSegmentsPtr + I;
    if Assigned(Seg^.ReleaseProc) then
      Seg^.ReleaseProc(Seg^.Owner);
  end;
  FSegmentCount := 0;
  FCurrentSegmentIndex := -1;
  FCurrentSegmentData := nil;
  FCurrentSegmentRemaining := 0;
  FCurrentSegmentTotal := 0;
end;

end.
