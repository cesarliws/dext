{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}
unit Dext.Server.BoundedExecutor;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs;

type
  /// <summary>
  ///   Callback procedure reference type for executor tasks.
  /// </summary>
  TDextTaskProc = reference to procedure;

  /// <summary>
  ///   High-performance non-generic circular ring buffer task queue.
  /// </summary>
  TDextTaskQueue = record
  private
    FItems: TArray<TDextTaskProc>;
    FHead: Integer;
    FTail: Integer;
    FCount: Integer;
    FCapacity: Integer;
  public
    procedure Initialize(ACapacity: Integer);
    procedure Clear;
    function Enqueue(const ATask: TDextTaskProc): Boolean;
    function Dequeue(var ATask: TDextTaskProc): Boolean;
    property Count: Integer read FCount;
  end;

  /// <summary>
  ///   Lightweight high-performance bounded task executor pool.
  /// </summary>
  TDextBoundedExecutor = class
  private
    FThreads: TArray<TThread>;
    FQueue: TDextTaskQueue;
    FLock: TCriticalSection;
    FSemaphore: TSimpleEvent;
    FMaxThreads: Integer;
    FMaxQueueCapacity: Integer;
    FRunning: Boolean;
    FQueueCount: Integer;
    procedure WorkerExecute(AThread: TThread);
  public
    constructor Create(AMaxThreads, AMaxQueueCapacity: Integer);
    destructor Destroy; override;
    function TryEnqueue(const AProc: TDextTaskProc): Boolean;
    procedure Shutdown;
    property QueueCount: Integer read FQueueCount;
  end;

type
  THackThread = class(TThread);

implementation

{ TDextTaskQueue }

procedure TDextTaskQueue.Initialize(ACapacity: Integer);
begin
  SetLength(FItems, ACapacity);
  FHead := 0;
  FTail := 0;
  FCount := 0;
  FCapacity := ACapacity;
end;

procedure TDextTaskQueue.Clear;
var
  I: Integer;
begin
  for I := 0 to Length(FItems) - 1 do
    FItems[I] := nil;
  FHead := 0;
  FTail := 0;
  FCount := 0;
end;

function TDextTaskQueue.Enqueue(const ATask: TDextTaskProc): Boolean;
begin
  if FCount >= FCapacity then
    Exit(False);

  FItems[FTail] := ATask;
  FTail := (FTail + 1) mod FCapacity;
  Inc(FCount);
  Result := True;
end;

function TDextTaskQueue.Dequeue(var ATask: TDextTaskProc): Boolean;
begin
  if FCount <= 0 then
    Exit(False);

  ATask := FItems[FHead];
  FItems[FHead] := nil;
  FHead := (FHead + 1) mod FCapacity;
  Dec(FCount);
  Result := True;
end;

{ TDextBoundedExecutor }

constructor TDextBoundedExecutor.Create(
  AMaxThreads, AMaxQueueCapacity: Integer);
var
  I: Integer;
begin
  inherited Create;
  FMaxThreads := AMaxThreads;
  FMaxQueueCapacity := AMaxQueueCapacity;
  FQueue.Initialize(FMaxQueueCapacity);
  FLock := TCriticalSection.Create;
  FSemaphore := TSimpleEvent.Create(nil, False, False, '');
  FRunning := True;
  FQueueCount := 0;

  SetLength(FThreads, FMaxThreads);
  for I := 0 to FMaxThreads - 1 do
  begin
    FThreads[I] := TThread.CreateAnonymousThread(
      procedure
      begin
        WorkerExecute(TThread.CurrentThread);
      end);
    FThreads[I].FreeOnTerminate := False;
    FThreads[I].Start;
  end;
end;

destructor TDextBoundedExecutor.Destroy;
begin
  Shutdown;
  FQueue.Clear;
  FLock.Free;
  FSemaphore.Free;
  inherited Destroy;
end;

procedure TDextBoundedExecutor.Shutdown;
var
  I: Integer;
begin
  if not FRunning then
    Exit;
  FRunning := False;

  // Signal all threads to wake up and exit
  for I := 0 to Length(FThreads) - 1 do
    FSemaphore.SetEvent;

  for I := 0 to Length(FThreads) - 1 do
  begin
    if FThreads[I] <> nil then
    begin
      FThreads[I].Terminate;
      FThreads[I].WaitFor;
      FThreads[I].Free;
      FThreads[I] := nil;
    end;
  end;
end;

function TDextBoundedExecutor.TryEnqueue(
  const AProc: TDextTaskProc): Boolean;
begin
  Result := False;
  if not FRunning then
    Exit;

  FLock.Enter;
  try
    if FQueue.Enqueue(AProc) then
    begin
      FQueueCount := FQueue.Count;
      Result := True;
      FSemaphore.SetEvent;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TDextBoundedExecutor.WorkerExecute(AThread: TThread);
var
  Task: TDextTaskProc;
begin
  while FRunning and not THackThread(AThread).Terminated do
  begin
    Task := nil;
    FLock.Enter;
    try
      if FQueue.Dequeue(Task) then
        FQueueCount := FQueue.Count;
    finally
      FLock.Leave;
    end;

    if Assigned(Task) then
    begin
      try
        Task();
      except
        // Prevent worker thread termination on exception
      end;
    end;

    // Wake or wait
    if FQueueCount = 0 then
      FSemaphore.WaitFor(100);
  end;
end;

end.
