unit TaskFlow.Repository.Mock;

interface

uses
  System.Generics.Collections, System.SysUtils, System.DateUtils,
  TaskFlow.Domain, TaskFlow.Repository.Interfaces;

type
  // ===========================================================================
  // IMPLEMENTAÇÃO MOCK DO REPOSITÓRIO
  // ===========================================================================
  TTaskRepositoryMock = class(TInterfacedObject, IObservableTaskRepository, ITaskRepository)
  private
    FTasks: TDictionary<Integer, TTask>;
    FObservers: TList<ITaskRepositoryEvents>;
    FNextId: Integer;

    function GenerateNextId: Integer;
    function GetTasksArray: TArray<TTask>;
    function FilterTasks(const Tasks: TArray<TTask>; const Filter: TTaskFilter): TArray<TTask>;
  public
    constructor Create;
    destructor Destroy; override;

    // ITaskRepository
    function GetAll: TArray<TTask>;
    function GetById(Id: Integer): TTask;
    function CreateTask(const Task: TTask): TTask;
    function UpdateTask(Id: Integer; const Task: TTask): TTask;
    function DeleteTask(Id: Integer): Boolean;

    function SearchTasks(const Filter: TTaskFilter): TArray<TTask>;
    function GetTasksByStatus(Status: TTaskStatus): TArray<TTask>;
    function GetTasksByPriority(Priority: TTaskPriority): TArray<TTask>;
    function GetOverdueTasks: TArray<TTask>;

    function GetTaskCount: Integer;
    function GetTasksCountByStatus: TArray<TTaskStatusCount>;
    function GetTasksStats: TTaskStats;

    function BulkUpdateStatus(Ids: TArray<Integer>; NewStatus: TTaskStatus): Integer;
    function BulkDelete(Ids: TArray<Integer>): Integer;

    // IObservableTaskRepository
    procedure Subscribe(Observer: ITaskRepositoryEvents);
    procedure Unsubscribe(Observer: ITaskRepositoryEvents);
    procedure NotifyTaskCreated(const Task: TTask);
    procedure NotifyTaskUpdated(const OldTask, NewTask: TTask);
    procedure NotifyTaskDeleted(Id: Integer);
    procedure NotifyTaskStatusChanged(Id: Integer; OldStatus, NewStatus: TTaskStatus);

    // Métodos auxiliares para setup de testes
    procedure SeedSampleData;
    procedure Clear;
    function ContainsTask(Id: Integer): Boolean;
  end;

implementation

uses
  System.Math;

{ TTaskRepositoryMock }

constructor TTaskRepositoryMock.Create;
begin
  inherited Create;
  FTasks := TDictionary<Integer, TTask>.Create;
  FObservers := TList<ITaskRepositoryEvents>.Create;
  FNextId := 1;
  SeedSampleData;
end;

destructor TTaskRepositoryMock.Destroy;
begin
  FObservers.Free;
  FTasks.Free;
  inherited Destroy;
end;

function TTaskRepositoryMock.GenerateNextId: Integer;
begin
  Result := FNextId;
  Inc(FNextId);
end;

function TTaskRepositoryMock.GetTasksArray: TArray<TTask>;
begin
  Result := FTasks.Values.ToArray;
end;

function TTaskRepositoryMock.FilterTasks(const Tasks: TArray<TTask>;
  const Filter: TTaskFilter): TArray<TTask>;
var
  Task: TTask;
  FilteredTasks: TList<TTask>;
begin
  FilteredTasks := TList<TTask>.Create;
  try
    for Task in Tasks do
    begin
      // Filtro por status
      if Filter.HasStatusFilter and (Task.Status <> Filter.Status) then
        Continue;

      // Filtro por prioridade
      if Filter.HasPriorityFilter and (Task.Priority <> Filter.Priority) then
        Continue;

      // Filtro por data
      if Filter.HasDateFilter then
      begin
        if (Filter.DueAfter > 0) and (Task.DueDate < Filter.DueAfter) then
          Continue;
        if (Filter.DueBefore > 0) and (Task.DueDate > Filter.DueBefore) then
          Continue;
      end;

      FilteredTasks.Add(Task);
    end;

    // Aplicar paginação
    if Filter.Page > 0 then
    begin
      var StartIndex := (Filter.Page - 1) * Filter.PageSize;
      var EndIndex := Min(StartIndex + Filter.PageSize, FilteredTasks.Count);

      if StartIndex < FilteredTasks.Count then
      begin
        var PaginatedTasks: TArray<TTask> := [];
        SetLength(PaginatedTasks, EndIndex - StartIndex);
        for var I := StartIndex to EndIndex - 1 do
          PaginatedTasks[I - StartIndex] := FilteredTasks[I];
        Result := PaginatedTasks;
      end
      else
        Result := [];
    end
    else
      Result := FilteredTasks.ToArray;

  finally
    FilteredTasks.Free;
  end;
end;

// ===========================================================================
// OPERAÇÕES CRUD
// ===========================================================================

function TTaskRepositoryMock.GetAll: TArray<TTask>;
begin
  Result := GetTasksArray;
end;

function TTaskRepositoryMock.GetById(Id: Integer): TTask;
begin
  if not FTasks.TryGetValue(Id, Result) then
    raise EArgumentException.CreateFmt('Task with ID %d not found', [Id]);
end;

function TTaskRepositoryMock.CreateTask(const Task: TTask): TTask;
var
  NewTask: TTask;
begin
  NewTask := Task;
  NewTask.Id := GenerateNextId;
  NewTask.CreatedAt := Now;

  FTasks.Add(NewTask.Id, NewTask);
  NotifyTaskCreated(NewTask);

  Result := NewTask;
end;

function TTaskRepositoryMock.UpdateTask(Id: Integer; const Task: TTask): TTask;
var
  OldTask: TTask;
  UpdatedTask: TTask;
begin
  if not FTasks.TryGetValue(Id, OldTask) then
    raise EArgumentException.CreateFmt('Task with ID %d not found', [Id]);

  // Preservar alguns campos
  UpdatedTask := Task;
  UpdatedTask.Id := Id;
  UpdatedTask.CreatedAt := OldTask.CreatedAt;

  // Notificar mudança de status se houver
  if OldTask.Status <> UpdatedTask.Status then
    NotifyTaskStatusChanged(Id, OldTask.Status, UpdatedTask.Status);

  FTasks[Id] := UpdatedTask;
  NotifyTaskUpdated(OldTask, UpdatedTask);

  Result := UpdatedTask;
end;

function TTaskRepositoryMock.DeleteTask(Id: Integer): Boolean;
begin
  Result := FTasks.ContainsKey(Id);
  if Result then
  begin
    FTasks.Remove(Id);
    NotifyTaskDeleted(Id);
  end;
end;

// ===========================================================================
// OPERAÇÕES DE BUSCA
// ===========================================================================

function TTaskRepositoryMock.SearchTasks(const Filter: TTaskFilter): TArray<TTask>;
begin
  if not Filter.IsValid then
    raise EArgumentException.Create('Invalid filter parameters');

  Result := FilterTasks(GetTasksArray, Filter);
end;

function TTaskRepositoryMock.GetTasksByStatus(Status: TTaskStatus): TArray<TTask>;
var
  Filter: TTaskFilter;
begin
  Filter := TTaskFilter.CreateWithStatus(Status);
  Result := SearchTasks(Filter);
end;

function TTaskRepositoryMock.GetTasksByPriority(Priority: TTaskPriority): TArray<TTask>;
var
  Filter: TTaskFilter;
begin
  Filter := TTaskFilter.CreateWithPriority(Priority);
  Result := SearchTasks(Filter);
end;

function TTaskRepositoryMock.GetOverdueTasks: TArray<TTask>;
var
  AllTasks: TArray<TTask>;
  OverdueTasks: TList<TTask>;
  Task: TTask;
begin
  AllTasks := GetTasksArray;
  OverdueTasks := TList<TTask>.Create;
  try
    for Task in AllTasks do
    begin
      if Task.IsOverdue then
        OverdueTasks.Add(Task);
    end;
    Result := OverdueTasks.ToArray;
  finally
    OverdueTasks.Free;
  end;
end;

// ===========================================================================
// OPERAÇÕES DE AGREGAÇÃO
// ===========================================================================

function TTaskRepositoryMock.GetTaskCount: Integer;
begin
  Result := FTasks.Count;
end;

function TTaskRepositoryMock.GetTasksCountByStatus: TArray<TTaskStatusCount>;
var
  StatusCounts: TDictionary<TTaskStatus, Integer>;
  Task: TTask;
  Status: TTaskStatus;
  CountArray: TArray<TTaskStatusCount>;
begin
  StatusCounts := TDictionary<TTaskStatus, Integer>.Create;
  try
    // Inicializar contadores
    for Status := Low(TTaskStatus) to High(TTaskStatus) do
      StatusCounts.Add(Status, 0);

    // Contar tarefas por status
    for Task in FTasks.Values do
      StatusCounts[Task.Status] := StatusCounts[Task.Status] + 1;

    // Converter para array
    SetLength(CountArray, StatusCounts.Count);
    var I := 0;
    for Status in StatusCounts.Keys do
    begin
      CountArray[I] := TTaskStatusCount.Create(Status, StatusCounts[Status]);
      Inc(I);
    end;

    Result := CountArray;
  finally
    StatusCounts.Free;
  end;
end;

function TTaskRepositoryMock.GetTasksStats: TTaskStats;
var
  AllTasks: TArray<TTask>;
  Task: TTask;
  Pending, InProgress, Completed, Cancelled, Overdue: Integer;
  TotalCompletionTime: Double;
  CompletedCount: Integer;
begin
  AllTasks := GetTasksArray;

  Pending := 0;
  InProgress := 0;
  Completed := 0;
  Cancelled := 0;
  Overdue := 0;
  TotalCompletionTime := 0;
  CompletedCount := 0;

  for Task in AllTasks do
  begin
    case Task.Status of
      tsPending: Inc(Pending);
      tsInProgress: Inc(InProgress);
      tsCompleted:
      begin
        Inc(Completed);
        if Task.CreatedAt > 0 then
        begin
          TotalCompletionTime := TotalCompletionTime + DaysBetween(Task.CreatedAt, Now);
          Inc(CompletedCount);
        end;
      end;
      tsCancelled: Inc(Cancelled);
    end;

    if Task.IsOverdue then
      Inc(Overdue);
  end;

  var AverageCompletionTime := 0.0;
  if CompletedCount > 0 then
    AverageCompletionTime := TotalCompletionTime / CompletedCount;

  Result := TTaskStats.Create(
    Length(AllTasks), Pending, InProgress, Completed, Cancelled, Overdue, AverageCompletionTime
  );
end;

// ===========================================================================
// OPERAÇÕES EM LOTE
// ===========================================================================

function TTaskRepositoryMock.BulkUpdateStatus(Ids: TArray<Integer>; NewStatus: TTaskStatus): Integer;
var
  Id: Integer;
  Task: TTask;
  OldStatus: TTaskStatus;
begin
  Result := 0;
  for Id in Ids do
  begin
    if FTasks.TryGetValue(Id, Task) then
    begin
      if Task.CanChangeStatus(NewStatus) then
      begin
        OldStatus := Task.Status;
        Task.Status := NewStatus;
        FTasks[Id] := Task;
        NotifyTaskStatusChanged(Id, OldStatus, NewStatus);
        Inc(Result);
      end;
    end;
  end;
end;

function TTaskRepositoryMock.BulkDelete(Ids: TArray<Integer>): Integer;
var
  Id: Integer;
begin
  Result := 0;
  for Id in Ids do
  begin
    if FTasks.ContainsKey(Id) then
    begin
      FTasks.Remove(Id);
      NotifyTaskDeleted(Id);
      Inc(Result);
    end;
  end;
end;

// ===========================================================================
// OBSERVABLE PATTERN
// ===========================================================================

procedure TTaskRepositoryMock.Subscribe(Observer: ITaskRepositoryEvents);
begin
  if not FObservers.Contains(Observer) then
    FObservers.Add(Observer);
end;

procedure TTaskRepositoryMock.Unsubscribe(Observer: ITaskRepositoryEvents);
begin
  FObservers.Remove(Observer);
end;

procedure TTaskRepositoryMock.NotifyTaskCreated(const Task: TTask);
var
  Observer: ITaskRepositoryEvents;
begin
  for Observer in FObservers do
    Observer.OnTaskCreated(Task);
end;

procedure TTaskRepositoryMock.NotifyTaskUpdated(const OldTask, NewTask: TTask);
var
  Observer: ITaskRepositoryEvents;
begin
  for Observer in FObservers do
    Observer.OnTaskUpdated(OldTask, NewTask);
end;

procedure TTaskRepositoryMock.NotifyTaskDeleted(Id: Integer);
var
  Observer: ITaskRepositoryEvents;
begin
  for Observer in FObservers do
    Observer.OnTaskDeleted(Id);
end;

procedure TTaskRepositoryMock.NotifyTaskStatusChanged(Id: Integer; OldStatus, NewStatus: TTaskStatus);
var
  Observer: ITaskRepositoryEvents;
begin
  for Observer in FObservers do
    Observer.OnTaskStatusChanged(Id, OldStatus, NewStatus);
end;

// ===========================================================================
// MÉTODOS AUXILIARES
// ===========================================================================

procedure TTaskRepositoryMock.SeedSampleData;
begin
  // Dados de exemplo para testes
  CreateTask(TTask.Create('Implementar API REST', 'Criar endpoints da TaskFlow API', tpHigh, Now + 5));
  CreateTask(TTask.Create('Configurar DI Container', 'Integrar dependency injection', tpMedium, Now + 3));
  CreateTask(TTask.Create('Escrever documentação', 'Documentar uso da API', tpLow, Now + 7));
  CreateTask(TTask.Create('Testar performance', 'Realizar testes de carga', tpCritical, Now + 2));
  CreateTask(TTask.Create('Refatorar código', 'Melhorar estrutura do projeto', tpMedium, Now + 10));

  // Marcar algumas como em progresso e completas
  var Task := GetById(1);
  Task.Status := tsInProgress;
  UpdateTask(1, Task);

  Task := GetById(3);
  Task.Status := tsCompleted;
  UpdateTask(3, Task);
end;

procedure TTaskRepositoryMock.Clear;
begin
  FTasks.Clear;
  FNextId := 1;
end;

function TTaskRepositoryMock.ContainsTask(Id: Integer): Boolean;
begin
  Result := FTasks.ContainsKey(Id);
end;

end.
