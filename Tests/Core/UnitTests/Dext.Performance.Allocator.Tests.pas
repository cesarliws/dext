{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}

unit Dext.Performance.Allocator.Tests;

interface

uses
  Dext.Testing,
  Dext.Performance.Allocator,
  System.SysUtils,
  System.Classes;

type
  [TestFixture('Dext Allocation Tracker')]
  TAllocatorTests = class
  public
    [Test]
    procedure Test_Tracking_GetMem_AllocMem;
    [Test]
    procedure Test_Tracking_Start_Stop;
    [Test]
    procedure Test_Tracking_Reset;
    [Test]
    procedure Test_Tracking_MultiThreaded;
    [Test]
    procedure Test_Tracking_NestedScopes;
    [Test]
    procedure Test_Tracking_ExceptionLeavesScope;
    [Test]
    procedure Test_MemoryManager_IsRestoredAndReinstalled;
  end;

implementation

{ TAllocatorTests }

procedure TAllocatorTests.Test_Tracking_GetMem_AllocMem;
var
  P: Pointer;
  Stats: TDextAllocStats;
begin
  TDextAllocationTracker.Reset;
  TDextAllocationTracker.Start;
  try
    P := AllocMem(200);
    try
      Stats := TDextAllocationTracker.GetStats;
      // We expect at least one allocation and 200 bytes
      Should(Stats.AllocationCount).BeGreaterThan(0);
      Should(Stats.AllocatedBytes).BeGreaterThan(199);
      Should(Stats.AllocMemCount).BeGreaterThan(0);
    finally
      FreeMem(P);
    end;
  finally
    TDextAllocationTracker.Stop;
  end;
end;

procedure TAllocatorTests.Test_Tracking_Start_Stop;
var
  P: Pointer;
  StatsBefore, StatsAfter: TDextAllocStats;
begin
  TDextAllocationTracker.Reset;
  TDextAllocationTracker.Stop;

  // With tracking stopped, stats should not change
  P := AllocMem(100);
  try
    StatsBefore := TDextAllocationTracker.GetStats;
    Should(StatsBefore.AllocationCount).Be(0);
    Should(StatsBefore.AllocatedBytes).Be(0);
  finally
    FreeMem(P);
  end;

  TDextAllocationTracker.Start;
  try
    P := AllocMem(100);
    try
      StatsAfter := TDextAllocationTracker.GetStats;
      Should(StatsAfter.AllocationCount).BeGreaterThan(0);
      Should(StatsAfter.AllocatedBytes).BeGreaterThan(99);
    finally
      FreeMem(P);
    end;
  finally
    TDextAllocationTracker.Stop;
  end;
end;

procedure TAllocatorTests.Test_Tracking_Reset;
var
  P: Pointer;
  Stats: TDextAllocStats;
begin
  TDextAllocationTracker.Reset;
  TDextAllocationTracker.Start;
  try
    P := AllocMem(50);
    try
      Stats := TDextAllocationTracker.GetStats;
      Should(Stats.AllocationCount).BeGreaterThan(0);
      TDextAllocationTracker.Reset;
      Stats := TDextAllocationTracker.GetStats;
      Should(Stats.AllocationCount).Be(0);
      Should(Stats.AllocatedBytes).Be(0);
    finally
      FreeMem(P);
    end;
  finally
    TDextAllocationTracker.Stop;
  end;
end;

procedure TAllocatorTests.Test_Tracking_MultiThreaded;
var
  Stats: TDextAllocStats;
  Threads: array[0..1] of TThread;
  i: Integer;
begin
  TDextAllocationTracker.Reset;
  TDextAllocationTracker.Stop;
  for i := 0 to High(Threads) do
  begin
    Threads[i] := TThread.CreateAnonymousThread(
      procedure
      var
        Memory: Pointer;
      begin
        TDextAllocationTracker.Start;
        try
          Memory := AllocMem(150);
          FreeMem(Memory);
        finally
          TDextAllocationTracker.Stop;
        end;
      end);
    Threads[i].FreeOnTerminate := False;
    Threads[i].Start;
  end;
  for i := 0 to High(Threads) do
  begin
    Threads[i].WaitFor;
    Threads[i].Free;
  end;

  Stats := TDextAllocationTracker.GetStats;
  Should(Stats.AllocMemCount).Be(2);
  Should(Stats.AllocatedBytes).Be(300);
end;

procedure TAllocatorTests.Test_Tracking_NestedScopes;
var
  P: Pointer;
  Stats: TDextAllocStats;
begin
  TDextAllocationTracker.Stop;
  TDextAllocationTracker.Reset;
  TDextAllocationTracker.Start;
  TDextAllocationTracker.Start;
  try
    P := AllocMem(64);
    FreeMem(P);
    TDextAllocationTracker.Stop;
    Should(TDextAllocationTracker.IsTracking).BeTrue;
    Stats := TDextAllocationTracker.GetStats;
    Should(Stats.AllocationCount).BeGreaterThan(0);
  finally
    TDextAllocationTracker.Stop;
  end;
  Should(TDextAllocationTracker.IsTracking).BeFalse;
end;

procedure TAllocatorTests.Test_Tracking_ExceptionLeavesScope;
begin
  TDextAllocationTracker.Stop;
  TDextAllocationTracker.Reset;
  try
    TDextAllocationTracker.Start;
    try
      raise Exception.Create('expected');
    finally
      TDextAllocationTracker.Stop;
    end;
  except
    { Expected by the test. }
  end;
  Should(TDextAllocationTracker.IsTracking).BeFalse;
end;

procedure TAllocatorTests.Test_MemoryManager_IsRestoredAndReinstalled;
var
  HookedManager: TMemoryManagerEx;
  RestoredManager: TMemoryManagerEx;
  ReinstalledManager: TMemoryManagerEx;
begin
  TDextAllocationTracker.Stop;
  GetMemoryManager(HookedManager);
  TDextAllocationTracker.Uninstall;
  try
    GetMemoryManager(RestoredManager);
    Should(PPointer(@RestoredManager.GetMem)^ <>
      PPointer(@HookedManager.GetMem)^).BeTrue;
  finally
    TDextAllocationTracker.Install;
  end;
  GetMemoryManager(ReinstalledManager);
  Should(PPointer(@ReinstalledManager.GetMem)^ =
    PPointer(@HookedManager.GetMem)^).BeTrue;
end;

end.
