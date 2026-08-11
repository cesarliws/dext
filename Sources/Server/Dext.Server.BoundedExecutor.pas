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
  ///   Callback procedure pointer type for executor tasks.
  /// </summary>
  TDextTaskProc = procedure(Data: Pointer);

  TDextTaskItem = record
    Proc: TDextTaskProc;
    Data: Pointer;
  end;

  /// <summary>
  ///   High-performance non-generic circular ring buffer task queue.
  /// </summary>
  TDextTaskQueue = record
  private
    FItems: TArray<TDextTaskItem>;
    FHead: Integer;
    FTail: Integer;
    FCount: Integer;
    FCapacity: Integer;
  public
    procedure Initialize(ACapacity: Integer);
    procedure Clear;
    function Enqueue(const ATask: TDextTaskItem): Boolean;
    function Dequeue(var ATask: TDextTaskItem): Boolean;
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
    function TryEnqueue(AProc: TDextTaskProc; AData: Pointer): Boolean; overload;
    function TryEnqueue(const AProc: TProc): Boolean; overload;
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
  begin
    FItems[i].Proc := nil;
    FItems[i].Data := nil;
  end;
  FHead := 0;
  FTail := 0;
  FCount := 0;
end;

function TDextTaskQueue.Enqueue(const ATask: TDextTaskItem): Boolean;
begin
  if FCount >= FCapacity then
    Exit(False);

  FItems[FTail] := ATask;
  FTail := (FTail + 1) mod FCapacity;
  Inc(FCount);
  Result := True;
end;

function TDextTaskQueue.Dequeue(var ATask: TDextTaskItem): Boolean;
begin
  if FCount <= 0 then
    Exit(False);

  ATask := FItems[FHead];
  FItems[FHead].Proc := nil;
  FItems[FHead].Data := nil;
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

procedure AnonymousTaskExecutor(Data: Pointer); forward;

destructor TDextBoundedExecutor.Destroy;
var
  Task: TDextTaskItem;
begin
  Shutdown;
  while FQueue.Dequeue(Task) do
  begin
    if (@Task.Proc = @AnonymousTaskExecutor) and (Task.Data <> nil) then
      IInterface(Task.Data)._Release;
  end;
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

procedure AnonymousTaskExecutor(Data: Pointer);
var
  Proc: TProc;
  P: Pointer absolute Proc;
begin
  if Data = nil then
    Exit;

  P := Data;
  try
    if Assigned(Proc) then
      Proc();
  finally
    // Release the manual reference held for the queue, and zero out P (Proc)
    // so the compiler's automatic _IntfClear does not run on freed memory.
    IInterface(Data)._Release;
    P := nil;
  end;
end;

function TDextBoundedExecutor.TryEnqueue(AProc: TDextTaskProc; AData: Pointer): Boolean;
var
  Item: TDextTaskItem;
begin
  Result := False;
  Item.Proc := AProc;
  Item.Data := AData;
  FLock.Enter;
  try
    if FRunning and FQueue.Enqueue(Item) then
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

function TDextBoundedExecutor.TryEnqueue(const AProc: TProc): Boolean;
var
  LProc: TProc;
  P: Pointer absolute LProc;
begin
  if not Assigned(AProc) then
    Exit(False);

  LProc := AProc;
  IInterface(P)._AddRef; // Explicitly retain 1 reference for queue duration

  if not TryEnqueue(AnonymousTaskExecutor, P) then
  begin
    IInterface(P)._Release;
    Exit(False);
  end;
  Result := True;
end;

procedure TDextBoundedExecutor.WorkerExecute(AThread: TThread);
var
  Task: TDextTaskItem;
begin
  while not THackThread(AThread).Terminated do
  begin
    FSemaphore.WaitFor(INFINITE);
    if not FRunning then
      Break;

    Task.Proc := nil;
    Task.Data := nil;
    FLock.Enter;
    try
      if FQueue.Dequeue(Task) then
        FQueueCount := FQueue.Count;
    finally
      FLock.Leave;
    end;

    if Assigned(Task.Proc) then
    begin
      try
        Task.Proc(Task.Data);
      except
        on E: Exception do
          if Assigned(FOnException) then
            FOnException(E);
      end;
    end;
  end;
end;

end.
