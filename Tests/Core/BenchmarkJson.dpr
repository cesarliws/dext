program BenchmarkJson;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  Dext.Utils,
  Dext.Json.Types,
  DextJsonDataObjects,
  Dext.Core.Json.NextGen;

const
  ITERATIONS = 50000;
  JSON_DATA =
    '{"name": "Dext Framework", "version": 1.5, "active": true, ' +
    '"tags": ["delphi", "simd", "performance"], ' +
    '"author": {"name": "Cesar Romero", "id": 12345}, ' +
    '"empty": null}';

var
  OldMemMgr: TMemoryManagerEx;
  NewMemMgr: TMemoryManagerEx;
  AllocCount: Int64;

function HookGetMem(Size: NativeInt): Pointer;
begin
  Inc(AllocCount);
  Result := OldMemMgr.GetMem(Size);
end;

function HookAllocMem(Size: NativeInt): Pointer;
begin
  Inc(AllocCount);
  Result := OldMemMgr.AllocMem(Size);
end;

function HookReallocMem(P: Pointer; Size: NativeInt): Pointer;
begin
  Inc(AllocCount);
  Result := OldMemMgr.ReallocMem(P, Size);
end;

function HookFreeMem(P: Pointer): Integer;
begin
  Result := OldMemMgr.FreeMem(P);
end;

procedure StartAllocCount;
begin
  AllocCount := 0;
  GetMemoryManager(OldMemMgr);
  NewMemMgr := OldMemMgr;
  NewMemMgr.GetMem := HookGetMem;
  NewMemMgr.AllocMem := HookAllocMem;
  NewMemMgr.ReallocMem := HookReallocMem;
  NewMemMgr.FreeMem := HookFreeMem;
  SetMemoryManager(NewMemMgr);
end;

function StopAllocCount: Int64;
begin
  SetMemoryManager(OldMemMgr);
  Result := AllocCount;
end;

procedure RunBenchmark;
var
  Bytes: TBytes;
  I: Integer;
  SW: TStopwatch;
  Node1: DextJsonDataObjects.TJsonBaseObject;
  Node2: IDextJsonNode;
  DataSpan: TByteSpan;
  DextAlloc: Int64;
  NextGenAlloc: Int64;
begin
  Writeln('Starting JSON Benchmarks (Iterations: ', ITERATIONS, ')...');
  Bytes := TEncoding.UTF8.GetBytes(JSON_DATA);
  DataSpan := TByteSpan.FromBytes(Bytes);

  // 1. Warm-up & Pool Pre-allocation
  Node1 := DextJsonDataObjects.TJsonBaseObject.Parse(JSON_DATA);
  if Assigned(Node1) then
    Node1.Free;

  Node2 := TNextGenJsonParser.Parse(DataSpan);
  Assert(Assigned(Node2));
  Node2 := nil; // Release to pool

  // 2. Benchmark DextJsonDataObjects
  StartAllocCount;
  SW := TStopwatch.StartNew;
  for I := 1 to ITERATIONS do
  begin
    Node1 := DextJsonDataObjects.TJsonBaseObject.Parse(JSON_DATA);
    Node1.Free;
  end;
  SW.Stop;
  DextAlloc := StopAllocCount;
  Writeln('DextJsonDataObjects: ', SW.ElapsedMilliseconds, ' ms');
  Writeln('  Heap Allocations: ', DextAlloc);

  // 3. Benchmark NextGen JSON Parser
  StartAllocCount;
  SW := TStopwatch.StartNew;
  for I := 1 to ITERATIONS do
  begin
    Node2 := TNextGenJsonParser.Parse(DataSpan);
    Node2 := nil; // Force release back to pool each run
  end;
  SW.Stop;
  NextGenAlloc := StopAllocCount;
  Writeln('NextGen JSON Parser: ', SW.ElapsedMilliseconds, ' ms');
  Writeln('  Heap Allocations: ', NextGenAlloc);
end;

begin
  try
    RunBenchmark;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
  ConsolePause;
end.
