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
  System.SysUtils;

type
  TDextAllocStats = record
    AllocationCount: Int64;
    FreeCount: Int64;
    AllocatedBytes: Int64;
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
    class procedure InstallMM;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure Start; static;
    class procedure Stop; static;
    class procedure Reset; static;
    class function GetStats: TDextAllocStats; static;
    class function IsTracking: Boolean; static;
  end;

implementation

threadvar
  FTrackingActive: Boolean;
  FAllocCount: Int64;
  FFreeCount: Int64;
  FAllocBytes: Int64;
  FInsideHook: Boolean;

function TrackedGetMem(Size: NativeInt): Pointer;
begin
  if FTrackingActive and not FInsideHook then
  begin
    FInsideHook := True;
    Inc(FAllocCount);
    Inc(FAllocBytes, Size);
    FInsideHook := False;
  end;
  Result := TDextAllocationTracker.FOriginalMM.GetMem(Size);
end;

function TrackedFreeMem(P: Pointer): Integer;
begin
  if FTrackingActive and not FInsideHook then
  begin
    FInsideHook := True;
    Inc(FFreeCount);
    FInsideHook := False;
  end;
  Result := TDextAllocationTracker.FOriginalMM.FreeMem(P);
end;

function TrackedReallocMem(P: Pointer; Size: NativeInt): Pointer;
begin
  if FTrackingActive and not FInsideHook then
  begin
    FInsideHook := True;
    Inc(FAllocCount);
    Inc(FAllocBytes, Size);
    FInsideHook := False;
  end;
  Result := TDextAllocationTracker.FOriginalMM.ReallocMem(P, Size);
end;

function TrackedAllocMem(Size: NativeInt): Pointer;
begin
  if FTrackingActive and not FInsideHook then
  begin
    FInsideHook := True;
    Inc(FAllocCount);
    Inc(FAllocBytes, Size);
    FInsideHook := False;
  end;
  Result := TDextAllocationTracker.FOriginalMM.AllocMem(Size);
end;

{ TDextAllocationTracker }

class constructor TDextAllocationTracker.Create;
begin
  FLock := TObject.Create;
  TMonitor.Enter(FLock);
  TMonitor.Exit(FLock);
  InstallMM;
end;

class destructor TDextAllocationTracker.Destroy;
begin
  FLock.Free;
end;

class procedure TDextAllocationTracker.InstallMM;
var
  NewMM: TMemoryManagerEx;
begin
  TMonitor.Enter(FLock);
  try
    if FHooked then Exit;
    GetMemoryManager(FOriginalMM);

    NewMM.GetMem := TrackedGetMem;
    NewMM.FreeMem := TrackedFreeMem;
    NewMM.ReallocMem := TrackedReallocMem;
    NewMM.AllocMem := TrackedAllocMem;
    NewMM.RegisterExpectedMemoryLeak :=
      FOriginalMM.RegisterExpectedMemoryLeak;
    NewMM.UnregisterExpectedMemoryLeak :=
      FOriginalMM.UnregisterExpectedMemoryLeak;

    SetMemoryManager(NewMM);
    FHooked := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TDextAllocationTracker.Start;
begin
  FTrackingActive := True;
end;

class procedure TDextAllocationTracker.Stop;
begin
  FTrackingActive := False;
end;

class procedure TDextAllocationTracker.Reset;
begin
  FAllocCount := 0;
  FFreeCount := 0;
  FAllocBytes := 0;
end;

class function TDextAllocationTracker.GetStats: TDextAllocStats;
begin
  Result.AllocationCount := FAllocCount;
  Result.FreeCount := FFreeCount;
  Result.AllocatedBytes := FAllocBytes;
end;

class function TDextAllocationTracker.IsTracking: Boolean;
begin
  Result := FTrackingActive;
end;

end.
