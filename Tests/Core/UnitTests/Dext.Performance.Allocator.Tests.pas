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
  ThreadAllocated: Boolean;
  Stats: TDextAllocStats;
  T: TThread;
begin
  TDextAllocationTracker.Reset;
  TDextAllocationTracker.Stop;
  ThreadAllocated := False;

  T := TThread.CreateAnonymousThread(
    procedure
    var
      P: Pointer;
      TStats: TDextAllocStats;
    begin
      TDextAllocationTracker.Reset;
      TDextAllocationTracker.Start;
      try
        P := AllocMem(150);
        try
          TStats := TDextAllocationTracker.GetStats;
          if (TStats.AllocationCount > 0) and
             (TStats.AllocatedBytes >= 150) then
            ThreadAllocated := True;
        finally
          FreeMem(P);
        end;
      finally
        TDextAllocationTracker.Stop;
      end;
    end);
  T.FreeOnTerminate := False;
  T.Start;
  T.WaitFor;
  try
    // Thread allocations should happen on its threadvar and not affect main thread
    Stats := TDextAllocationTracker.GetStats;
    Should(ThreadAllocated).BeTrue;
    Should(Stats.AllocationCount).Be(0);
    Should(Stats.AllocatedBytes).Be(0);
  finally
    T.Free;
  end;
end;

end.
