unit TaskFlow.Repository.Interfaces;

interface

uses
  TaskFlow.Domain;

type
  // ===========================================================================
  // RECORDS PARA ESTATÍSTICAS E RELATÓRIOS
  // ===========================================================================
  TTaskStatusCount = record
    Status: TTaskStatus;
    Count: Integer;

    constructor Create(AStatus: TTaskStatus; ACount: Integer);
  end;

  TTaskStats = record
    TotalTasks: Integer;
    PendingCount: Integer;
    InProgressCount: Integer;
    CompletedCount: Integer;
    CancelledCount: Integer;
    OverdueCount: Integer;
    AverageCompletionTime: Double; // em dias

    constructor Create(ATotal, APending, AInProgress, ACompleted, ACancelled, AOverdue: Integer;
      AAverageCompletionTime: Double);
    function GetCompletionRate: Double;
  end;

  // ===========================================================================
  // INTERFACE PRINCIPAL DO REPOSITÓRIO
  // ===========================================================================
  ITaskRepository = interface
    ['{A18BFF29-7086-4D93-8021-BA09D5A75305}']

    // Operações básicas CRUD
    function GetAll: TArray<TTask>;
    function GetById(Id: Integer): TTask;
    function CreateTask(const Task: TTask): TTask;
    function UpdateTask(Id: Integer; const Task: TTask): TTask;
    function DeleteTask(Id: Integer): Boolean;

    // Operações de busca e filtro
    function SearchTasks(const Filter: TTaskFilter): TArray<TTask>;
    function GetTasksByStatus(Status: TTaskStatus): TArray<TTask>;
    function GetTasksByPriority(Priority: TTaskPriority): TArray<TTask>;
    function GetOverdueTasks: TArray<TTask>;

    // Operações de agregação
    function GetTaskCount: Integer;
    function GetTasksCountByStatus: TArray<TTaskStatusCount>;
    function GetTasksStats: TTaskStats;

    // Operações em lote
    function BulkUpdateStatus(Ids: TArray<Integer>; NewStatus: TTaskStatus): Integer;
    function BulkDelete(Ids: TArray<Integer>): Integer;
  end;

  // ===========================================================================
  // INTERFACE PARA EVENTOS DO REPOSITÓRIO
  // ===========================================================================
  ITaskRepositoryEvents = interface
    ['{62847477-E866-4B03-9BCD-E13F71DD8925}']

    procedure OnTaskCreated(const Task: TTask);
    procedure OnTaskUpdated(const OldTask, NewTask: TTask);
    procedure OnTaskDeleted(Id: Integer);
    procedure OnTaskStatusChanged(Id: Integer; OldStatus, NewStatus: TTaskStatus);
  end;

  // ===========================================================================
  // INTERFACE PARA REPOSITÓRIO OBSERVÁVEL (EVENT DRIVEN)
  // ===========================================================================
  IObservableTaskRepository = interface(ITaskRepository)
    ['{70C187D7-5B76-42E9-8FF6-879130BA056F}']

    procedure Subscribe(Observer: ITaskRepositoryEvents);
    procedure Unsubscribe(Observer: ITaskRepositoryEvents);
    procedure NotifyTaskCreated(const Task: TTask);
    procedure NotifyTaskUpdated(const OldTask, NewTask: TTask);
    procedure NotifyTaskDeleted(Id: Integer);
    procedure NotifyTaskStatusChanged(Id: Integer; OldStatus, NewStatus: TTaskStatus);
  end;

implementation

{ TTaskStatusCount }

constructor TTaskStatusCount.Create(AStatus: TTaskStatus; ACount: Integer);
begin
  Self.Status := AStatus;
  Self.Count := ACount;
end;

{ TTaskStats }

constructor TTaskStats.Create(ATotal, APending, AInProgress, ACompleted, ACancelled, AOverdue: Integer;
  AAverageCompletionTime: Double);
begin
  Self.TotalTasks := ATotal;
  Self.PendingCount := APending;
  Self.InProgressCount := AInProgress;
  Self.CompletedCount := ACompleted;
  Self.CancelledCount := ACancelled;
  Self.OverdueCount := AOverdue;
  Self.AverageCompletionTime := AAverageCompletionTime;
end;

function TTaskStats.GetCompletionRate: Double;
begin
  if TotalTasks = 0 then
    Result := 0
  else
    Result := (CompletedCount / TotalTasks) * 100;
end;

end.
