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
    FSemaphore: TSemaphore;
    FMaxThreads: Integer;
    FMaxQueueCapacity: Integer;
    FRunning: Boolean;
    FQueueCount: Integer;
    FOnException: TProc<Exception>;
    procedure WorkerExecute(AThread: TThread);
  public
    constructor Create(AMaxThreads, AMaxQueueCapacity: Integer);
    destructor Destroy; override;
    function TryEnqueue(const AProc: TDextTaskProc): Boolean;
    procedure Shutdown;
    property QueueCount: Integer read FQueueCount;
    property OnException: TProc<Exception> read FOnException write FOnException;
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
  i: Integer;
begin
  for i := 0 to Length(FItems) - 1 do
    FItems[i] := nil;
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
  i: Integer;
begin
  inherited Create;
  FMaxThreads := AMaxThreads;
  FMaxQueueCapacity := AMaxQueueCapacity;
  FQueue.Initialize(FMaxQueueCapacity);
  FLock := TCriticalSection.Create;
  FSemaphore := TSemaphore.Create(nil, 0, FMaxQueueCapacity + FMaxThreads, '');
  FRunning := True;
  FQueueCount := 0;

  SetLength(FThreads, FMaxThreads);
  for i := 0 to FMaxThreads - 1 do
  begin
    FThreads[i] := TThread.CreateAnonymousThread(
      procedure
      begin
        WorkerExecute(TThread.CurrentThread);
      end);
    FThreads[i].FreeOnTerminate := False;
    FThreads[i].Start;
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
  i: Integer;
begin
  FLock.Enter;
  try
    if not FRunning then
      Exit;
    FRunning := False;
  finally
    FLock.Leave;
  end;

  if Length(FThreads) > 0 then
    FSemaphore.Release(Length(FThreads));

  for i := 0 to Length(FThreads) - 1 do
  begin
    if FThreads[i] <> nil then
    begin
      FThreads[i].Terminate;
      FThreads[i].WaitFor;
      FThreads[i].Free;
      FThreads[i] := nil;
    end;
  end;
end;

function TDextBoundedExecutor.TryEnqueue(
  const AProc: TDextTaskProc): Boolean;
begin
  Result := False;
  FLock.Enter;
  try
    if FRunning and FQueue.Enqueue(AProc) then
    begin
      FQueueCount := FQueue.Count;
      Result := True;
    end;
  finally
    FLock.Leave;
  end;
  if Result then
    FSemaphore.Release;
end;

procedure TDextBoundedExecutor.WorkerExecute(AThread: TThread);
var
  Task: TDextTaskProc;
begin
  while not THackThread(AThread).Terminated do
  begin
    FSemaphore.WaitFor(INFINITE);
    if not FRunning then
      Break;

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
        on E: Exception do
          if Assigned(FOnException) then
            FOnException(E);
      end;
    end;
  end;
end;

end.
