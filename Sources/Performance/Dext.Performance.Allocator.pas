{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}

unit Dext.Performance.Allocator;

interface

uses
  System.SysUtils,
  System.SyncObjs;

type
  /// <summary>
  ///   Allocation events and requested byte counts captured by the tracker.
  /// </summary>
  TDextAllocStats = record
    AllocationCount: Int64;
    GetMemCount: Int64;
    AllocMemCount: Int64;
    ReallocMemCount: Int64;
    FreeCount: Int64;
    AllocatedBytes: Int64;
    ReallocatedBytes: Int64;
    RetainedBytes: Int64;
  end;

  /// <summary>
  ///   Thread-safe allocation tracking memory manager wrapper.
  ///   Used in benchmarks and tests to verify memory metrics.
  /// </summary>
  TDextAllocationTracker = class
  private
    class var FOriginalMM: TMemoryManagerEx;
    class var FHooked: Boolean;
    class var FLock: TObject;
    class var FThreadStatsHead: Pointer;
    class var FActiveThreadScopes: Integer;
    class var FRetainedStartBytes: Int64;
    class var FRetainedBytes: Int64;
    class procedure EnsureThreadStats; static;
    class procedure InstallMM;
    class procedure UninstallMM;
  public
    class constructor Create;
    class destructor Destroy;

    /// <summary>Installs the tracking memory manager wrapper.</summary>
    class procedure Install; static;
    /// <summary>Restores the memory manager that was active before installation.</summary>
    class procedure Uninstall; static;
    /// <summary>Starts or nests allocation tracking on the current thread.</summary>
    class procedure Start; static;
    /// <summary>Leaves one allocation tracking scope on the current thread.</summary>
    class procedure Stop; static;
    /// <summary>Resets counters registered by all participating threads.</summary>
    class procedure Reset; static;
    /// <summary>Aggregates counters from all participating threads.</summary>
    class function GetStats: TDextAllocStats; static;
    /// <summary>Returns whether the current thread is inside a tracking scope.</summary>
    class function IsTracking: Boolean; static;
  end;

implementation

{$IFDEF LINUX}
uses
  Posix.Fcntl,
  Posix.Unistd;
{$ENDIF}

type
  PDextThreadAllocStats = ^TDextThreadAllocStats;
  TDextThreadAllocStats = record
    Next: PDextThreadAllocStats;
    AllocationCount: Int64;
    GetMemCount: Int64;
    AllocMemCount: Int64;
    ReallocMemCount: Int64;
    FreeCount: Int64;
    AllocatedBytes: Int64;
    ReallocatedBytes: Int64;
  end;

threadvar
  FTrackingDepth: Integer;
  FThreadStats: PDextThreadAllocStats;
  FInsideHook: Boolean;

function GetCurrentAllocatedBytes: Int64;
{$IFDEF MSWINDOWS}
var
  State: TMemoryManagerState;
  i: Integer;
begin
{$WARN SYMBOL_PLATFORM OFF}
  GetMemoryManagerState(State);
{$WARN SYMBOL_PLATFORM ON}
  Result := State.TotalAllocatedMediumBlockSize +
    State.TotalAllocatedLargeBlockSize;
  for i := 0 to High(State.SmallBlockTypeStates) do
    Inc(Result,
      Int64(State.SmallBlockTypeStates[i].AllocatedBlockCount) *
      State.SmallBlockTypeStates[i].UseableBlockSize);
end;
{$ELSEIF Defined(LINUX)}
var
  Buffer: array[0..127] of AnsiChar;
  BytesRead: NativeInt;
  FileDescriptor: Integer;
  Position: Integer;
  ResidentPages: Int64;
begin
  Result := 0;
  FileDescriptor := open('/proc/self/statm', O_RDONLY);
  if FileDescriptor < 0 then
    Exit;
  try
    BytesRead := __read(FileDescriptor, @Buffer[0], Length(Buffer));
  finally
    __close(FileDescriptor);
  end;
  if BytesRead <= 0 then
    Exit;

  Position := 0;
  while (Position < BytesRead) and (Buffer[Position] <> ' ') do
    Inc(Position);
  while (Position < BytesRead) and (Buffer[Position] = ' ') do
    Inc(Position);
  ResidentPages := 0;
  while (Position < BytesRead) and
        (Buffer[Position] >= '0') and (Buffer[Position] <= '9') do
  begin
    ResidentPages := ResidentPages * 10 +
      (Ord(Buffer[Position]) - Ord('0'));
    Inc(Position);
  end;
  Result := ResidentPages * sysconf(_SC_PAGESIZE);
end;
{$ELSE}
begin
  Result := 0;
end;
{$ENDIF}

function TrackedGetMem(Size: NativeInt): Pointer;
begin
  if (FTrackingDepth > 0) and not FInsideHook then
  begin
    FInsideHook := True;
    Inc(FThreadStats.AllocationCount);
    Inc(FThreadStats.GetMemCount);
    Inc(FThreadStats.AllocatedBytes, Size);
    FInsideHook := False;
  end;
  Result := TDextAllocationTracker.FOriginalMM.GetMem(Size);
end;

function TrackedFreeMem(P: Pointer): Integer;
begin
  if (FTrackingDepth > 0) and not FInsideHook then
  begin
    FInsideHook := True;
    Inc(FThreadStats.FreeCount);
    FInsideHook := False;
  end;
  Result := TDextAllocationTracker.FOriginalMM.FreeMem(P);
end;

function TrackedReallocMem(P: Pointer; Size: NativeInt): Pointer;
begin
  if (FTrackingDepth > 0) and not FInsideHook then
  begin
    FInsideHook := True;
    Inc(FThreadStats.AllocationCount);
    Inc(FThreadStats.ReallocMemCount);
    Inc(FThreadStats.AllocatedBytes, Size);
    Inc(FThreadStats.ReallocatedBytes, Size);
    FInsideHook := False;
  end;
  Result := TDextAllocationTracker.FOriginalMM.ReallocMem(P, Size);
end;

function TrackedAllocMem(Size: NativeInt): Pointer;
begin
  if (FTrackingDepth > 0) and not FInsideHook then
  begin
    FInsideHook := True;
    Inc(FThreadStats.AllocationCount);
    Inc(FThreadStats.AllocMemCount);
    Inc(FThreadStats.AllocatedBytes, Size);
    FInsideHook := False;
  end;
  Result := TDextAllocationTracker.FOriginalMM.AllocMem(Size);
end;

{ TDextAllocationTracker }

class constructor TDextAllocationTracker.Create;
begin
  FLock := TObject.Create;
  FThreadStatsHead := nil;
  InstallMM;
end;

class destructor TDextAllocationTracker.Destroy;
var
  Stats: PDextThreadAllocStats;
  Next: PDextThreadAllocStats;
begin
  FTrackingDepth := 0;
  UninstallMM;
  Stats := PDextThreadAllocStats(FThreadStatsHead);
  while Stats <> nil do
  begin
    Next := Stats.Next;
    FOriginalMM.FreeMem(Stats);
    Stats := Next;
  end;
  FThreadStatsHead := nil;
  FLock.Free;
end;

class procedure TDextAllocationTracker.EnsureThreadStats;
var
  Stats: PDextThreadAllocStats;
begin
  if FThreadStats <> nil then
    Exit;

  Stats := FOriginalMM.GetMem(SizeOf(TDextThreadAllocStats));
  FillChar(Stats^, SizeOf(TDextThreadAllocStats), 0);

  TMonitor.Enter(FLock);
  try
    Stats.Next := PDextThreadAllocStats(FThreadStatsHead);
    FThreadStatsHead := Stats;
    FThreadStats := Stats;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TDextAllocationTracker.InstallMM;
var
  NewMM: TMemoryManagerEx;
begin
  TMonitor.Enter(FLock);
  try
    if FHooked then
      Exit;
    GetMemoryManager(FOriginalMM);

    NewMM := FOriginalMM;
    NewMM.GetMem := TrackedGetMem;
    NewMM.FreeMem := TrackedFreeMem;
    NewMM.ReallocMem := TrackedReallocMem;
    NewMM.AllocMem := TrackedAllocMem;

    SetMemoryManager(NewMM);
    FHooked := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TDextAllocationTracker.Install;
begin
  InstallMM;
end;

class procedure TDextAllocationTracker.UninstallMM;
begin
  TMonitor.Enter(FLock);
  try
    if not FHooked then
      Exit;
    if TInterlocked.CompareExchange(FActiveThreadScopes, 0, 0) <> 0 then
      raise EInvalidOp.Create(
        'Cannot uninstall allocation tracker while a scope is active');
    SetMemoryManager(FOriginalMM);
    FHooked := False;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TDextAllocationTracker.Uninstall;
begin
  UninstallMM;
end;

class procedure TDextAllocationTracker.Start;
begin
  EnsureThreadStats;
  if (FTrackingDepth = 0) and
     (TInterlocked.Increment(FActiveThreadScopes) = 1) then
  begin
    FRetainedStartBytes := GetCurrentAllocatedBytes;
  end;
  Inc(FTrackingDepth);
end;

class procedure TDextAllocationTracker.Stop;
begin
  if FTrackingDepth > 0 then
  begin
    Dec(FTrackingDepth);
    if (FTrackingDepth = 0) and
       (TInterlocked.Decrement(FActiveThreadScopes) = 0) then
    begin
      FRetainedBytes := GetCurrentAllocatedBytes - FRetainedStartBytes;
    end;
  end;
end;

class procedure TDextAllocationTracker.Reset;
var
  Stats: PDextThreadAllocStats;
begin
  TMonitor.Enter(FLock);
  try
    Stats := PDextThreadAllocStats(FThreadStatsHead);
    FRetainedBytes := 0;
    while Stats <> nil do
    begin
      Stats.AllocationCount := 0;
      Stats.GetMemCount := 0;
      Stats.AllocMemCount := 0;
      Stats.ReallocMemCount := 0;
      Stats.FreeCount := 0;
      Stats.AllocatedBytes := 0;
      Stats.ReallocatedBytes := 0;
      Stats := Stats.Next;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TDextAllocationTracker.GetStats: TDextAllocStats;
var
  Stats: PDextThreadAllocStats;
begin
  Result := Default(TDextAllocStats);
  TMonitor.Enter(FLock);
  try
    Stats := PDextThreadAllocStats(FThreadStatsHead);
    while Stats <> nil do
    begin
      Inc(Result.AllocationCount, Stats.AllocationCount);
      Inc(Result.GetMemCount, Stats.GetMemCount);
      Inc(Result.AllocMemCount, Stats.AllocMemCount);
      Inc(Result.ReallocMemCount, Stats.ReallocMemCount);
      Inc(Result.FreeCount, Stats.FreeCount);
      Inc(Result.AllocatedBytes, Stats.AllocatedBytes);
      Inc(Result.ReallocatedBytes, Stats.ReallocatedBytes);
      Stats := Stats.Next;
    end;
    Result.RetainedBytes := FRetainedBytes;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TDextAllocationTracker.IsTracking: Boolean;
begin
  Result := FTrackingDepth > 0;
end;

end.
