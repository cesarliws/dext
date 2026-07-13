unit Dext.Web.ResponseWriter;

{$POINTERMATH ON}

interface

uses
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

  TDextBufferNode = record
    Next: Pointer;
    SizeClass: Integer;
  end;
  PDextBufferNode = ^TDextBufferNode;

  TDextBufferPool = class
  private
    class var FGlobalHeads: array[0..4] of Pointer;
  public
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
    procedure Reset;

    property Segments: PDextBufferSegment read FSegmentsPtr;
    property SegmentCount: Integer read FSegmentCount;
  end;

implementation

procedure DefaultReleaseProc(AOwner: Pointer);
begin
  TDextBufferPool.Release(AOwner);
end;

threadvar
  TLocalHeads: array[0..4] of Pointer;
  TLocalCounts: array[0..4] of Integer;

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

class function TDextBufferPool.Rent(ASize: Integer;
  out ARentedSize: Integer): Pointer;
var
  Idx, ClassSize: Integer;
  Node: PDextBufferNode;
  OldHead: Pointer;
begin
  if ASize > 65536 then
  begin
    GetMem(Node, ASize + SizeOf(TDextBufferNode));
    Node.Next := nil;
    Node.SizeClass := -1;
    ARentedSize := ASize;
    Exit(PByte(Node) + SizeOf(TDextBufferNode));
  end;

  Idx := SizeToSizeClass(ASize, ClassSize);
  ARentedSize := ClassSize;

  Node := TLocalHeads[Idx];
  if Node <> nil then
  begin
    TLocalHeads[Idx] := Node.Next;
    Dec(TLocalCounts[Idx]);
    Exit(PByte(Node) + SizeOf(TDextBufferNode));
  end;

  repeat
    OldHead := FGlobalHeads[Idx];
    if OldHead = nil then
    begin
      Node := nil;
      Break;
    end;
    Node := OldHead;
  until TInterlocked.CompareExchange(FGlobalHeads[Idx], Node.Next,
    OldHead) = OldHead;

  if Node <> nil then
    Exit(PByte(Node) + SizeOf(TDextBufferNode));

  GetMem(Node, ClassSize + SizeOf(TDextBufferNode));
  Node.Next := nil;
  Node.SizeClass := Idx;
  Result := PByte(Node) + SizeOf(TDextBufferNode);
end;

class procedure TDextBufferPool.Release(APtr: Pointer);
var
  Node: PDextBufferNode;
  Idx: Integer;
  OldHead: Pointer;
begin
  if APtr = nil then
    Exit;
  Node := PDextBufferNode(PByte(APtr) - SizeOf(TDextBufferNode));
  Idx := Node.SizeClass;

  if Idx = -1 then
  begin
    FreeMem(Node);
    Exit;
  end;

  if TLocalCounts[Idx] < 32 then
  begin
    Node.Next := TLocalHeads[Idx];
    TLocalHeads[Idx] := Node;
    Inc(TLocalCounts[Idx]);
  end
  else
  begin
    repeat
      OldHead := FGlobalHeads[Idx];
      Node.Next := OldHead;
    until TInterlocked.CompareExchange(FGlobalHeads[Idx], Node,
      OldHead) = OldHead;
  end;
end;

class procedure TDextBufferPool.ResetPools;
var
  Idx: Integer;
  Node, Temp: PDextBufferNode;
  OldHead: Pointer;
begin
  for Idx := 0 to 4 do
  begin
    repeat
      OldHead := FGlobalHeads[Idx];
      if OldHead = nil then
        Break;
    until TInterlocked.CompareExchange(FGlobalHeads[Idx], nil,
      OldHead) = OldHead;

    Node := OldHead;
    while Node <> nil do
    begin
      Temp := Node.Next;
      FreeMem(Node);
      Node := Temp;
    end;

    Node := TLocalHeads[Idx];
    TLocalHeads[Idx] := nil;
    TLocalCounts[Idx] := 0;
    while Node <> nil do
    begin
      Temp := Node.Next;
      FreeMem(Node);
      Node := Temp;
    end;
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
