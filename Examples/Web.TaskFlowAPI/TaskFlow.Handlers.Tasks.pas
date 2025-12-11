unit TaskFlow.Handlers.Tasks;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  System.Rtti,
  Dext.Core.ModelBinding,      // ✅ Para [FromQuery], [FromRoute], [FromBody]
  Dext.DI.Interfaces,          // ✅ Para [FromServices]
  Dext.Core.Routing,           // ✅ NOVA UNIT - Nossos atributos customizados
  TaskFlow.Domain,
  TaskFlow.Repository.Interfaces;

type
  {$M+}
  // ===========================================================================
  // REQUEST/RESPONSE SPECIFICS (mantido igual)
  // ===========================================================================
  TUpdateStatusRequest = record
  public
    Status: TTaskStatus;

    function Validate: TArray<string>;
    function IsValid: Boolean;
  end;

  TBulkStatusUpdateRequest = record
  public
    TaskIds: TArray<Integer>;
    NewStatus: TTaskStatus;

    function Validate: TArray<string>;
    function IsValid: Boolean;
  end;

  TBulkDeleteRequest = record
  public
    TaskIds: TArray<Integer>;

    function Validate: TArray<string>;
    function IsValid: Boolean;
  end;

  TBulkOperationResponse = record
  public
    SuccessCount: Integer;
    TotalCount: Integer;
    Errors: TArray<string>;

    constructor Create(ASuccessCount, ATotalCount: Integer; AErrors: TArray<string> = []);
    function GetSuccessRate: Double;
  end;

  TDextResponse = record
  public
    Success: Boolean;
    Message: string;
    Data: TValue;

    constructor Create(ASuccess: Boolean; const AMessage: string; AData: TValue);
    class function SuccessResponse(const AMessage: string = ''): TDextResponse; static;
    class function ErrorResponse(const AMessage: string): TDextResponse; static;
  end;

  // ===========================================================================
  // HANDLER PRINCIPAL COM ATRIBUTOS COMPLETOS
  // ===========================================================================
  [DextController('/api')] // Prefixo opcional para todas as rotas
  TTaskHandlers = record
  public
    // ========================================================================
    // OPERAÇÕES CRUD
    // ========================================================================

    /// <summary>Lista todas as tarefas com suporte a filtros</summary>
    [DextGet('/tasks')]
    class function GetTasks(
      [FromQuery] Filter: TTaskFilter;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskListResponse; static;

    /// <summary>Obtém uma tarefa específica por ID</summary>
    [DextGet('/tasks/{id}')]
    class function GetTask(
      [FromRoute] Id: Integer;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskResponse; static;

    /// <summary>Cria uma nova tarefa</summary>
    [DextPost('/tasks')]
    class function CreateTask(
      [FromBody] Request: TCreateTaskRequest;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskResponse; static;

    /// <summary>Atualiza uma tarefa existente</summary>
    [DextPut('/tasks/{id}')]
    class function UpdateTask(
      [FromRoute] Id: Integer;
      [FromBody] Request: TCreateTaskRequest;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskResponse; static;

    /// <summary>Exclui uma tarefa</summary>
    [DextDelete('/tasks/{id}')]
    class function DeleteTask(
      [FromRoute] Id: Integer;
      [FromServices] TaskRepo: ITaskRepository
    ): TDextResponse; static;

    // ========================================================================
    // OPERAÇÕES ESPECIAIS
    // ========================================================================

    /// <summary>Busca avançada de tarefas</summary>
    [DextGet('/tasks/search')]
    class function SearchTasks(
      [FromQuery] Filter: TTaskFilter;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskListResponse; static;

    /// <summary>Obtém tarefas por status</summary>
    [DextGet('/tasks/status/{status}')]
    class function GetTasksByStatus(
      [FromRoute] Status: TTaskStatus;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskListResponse; static;

    /// <summary>Obtém tarefas por prioridade</summary>
    [DextGet('/tasks/priority/{priority}')]
    class function GetTasksByPriority(
      [FromRoute] Priority: TTaskPriority;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskListResponse; static;

    /// <summary>Obtém tarefas atrasadas</summary>
    [DextGet('/tasks/overdue')]
    class function GetOverdueTasks(
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskListResponse; static;

    // ========================================================================
    // OPERAÇÕES EM LOTE
    // ========================================================================

    /// <summary>Atualiza status de múltiplas tarefas</summary>
    [DextPost('/tasks/bulk/status')]
    class function BulkUpdateStatus(
      [FromBody] Request: TBulkStatusUpdateRequest;
      [FromServices] TaskRepo: ITaskRepository
    ): TBulkOperationResponse; static;

    /// <summary>Exclui múltiplas tarefas</summary>
    [DextPost('/tasks/bulk/delete')]
    class function BulkDeleteTasks(
      [FromBody] Request: TBulkDeleteRequest;
      [FromServices] TaskRepo: ITaskRepository
    ): TBulkOperationResponse; static;

    // ========================================================================
    // OPERAÇÕES DE STATUS
    // ========================================================================

    /// <summary>Atualiza o status de uma tarefa</summary>
    [DextPatch('/tasks/{id}/status')]
    class function UpdateTaskStatus(
      [FromRoute] Id: Integer;
      [FromBody] Request: TUpdateStatusRequest;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskResponse; static;

    /// <summary>Marca tarefa como concluída</summary>
    [DextPost('/tasks/{id}/complete')]
    class function CompleteTask(
      [FromRoute] Id: Integer;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskResponse; static;

    /// <summary>Marca tarefa como em progresso</summary>
    [DextPost('/tasks/{id}/start')]
    class function StartTask(
      [FromRoute] Id: Integer;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskResponse; static;

    /// <summary>Cancela uma tarefa</summary>
    [DextPost('/tasks/{id}/cancel')]
    class function CancelTask(
      [FromRoute] Id: Integer;
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskResponse; static;

    // ========================================================================
    // ESTATÍSTICAS E RELATÓRIOS
    // ========================================================================

    /// <summary>Obtém estatísticas das tarefas</summary>
    [DextGet('/tasks/stats')]
    class function GetTasksStats(
      [FromServices] TaskRepo: ITaskRepository
    ): TTaskStats; static;

    /// <summary>Obtém contagem por status</summary>
    [DextGet('/tasks/stats/status')]
    class function GetStatusCounts(
      [FromServices] TaskRepo: ITaskRepository
    ): TArray<TTaskStatusCount>; static;
  end;



implementation


{ TTaskHandlers }

// ============================================================================
// OPERAÇÕES CRUD
// ============================================================================

class function TTaskHandlers.GetTasks(Filter: TTaskFilter;
  TaskRepo: ITaskRepository): TTaskListResponse;
var
  Tasks: TArray<TTask>;
  TotalCount: Integer;
begin
  try
    // Se não tem filtro específico, usa padrão
    if not Filter.HasStatusFilter and not Filter.HasPriorityFilter and not Filter.HasDateFilter then
    begin
      Tasks := TaskRepo.GetAll;
      TotalCount := TaskRepo.GetTaskCount;
    end
    else
    begin
      Tasks := TaskRepo.SearchTasks(Filter);
      TotalCount := Length(Tasks); // Em uma implementação real, teríamos count separado
    end;

    Result := TTaskListResponse.Create(Tasks, TotalCount, Filter.Page, Filter.PageSize);

  except
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error retrieving tasks: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.GetTask(Id: Integer;
  TaskRepo: ITaskRepository): TTaskResponse;
var
  Task: TTask;
begin
  try
    Task := TaskRepo.GetById(Id);
    Result := TTaskResponse.CreateFromTask(Task);

  except
    on E: EArgumentException do
      raise EDextHttpException.Create(404, Format('Task not found: %d', [Id]));
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error retrieving task: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.CreateTask(Request: TCreateTaskRequest;
  TaskRepo: ITaskRepository): TTaskResponse;
var
  Task: TTask;
  ValidationErrors: TArray<string>;
begin
  // Validar request
  ValidationErrors := Request.Validate;
  if Length(ValidationErrors) > 0 then
    raise EDextHttpException.Create(400, 'Validation errors: ' + string.Join('; ', ValidationErrors));

  try
    // Converter request para domain
    Task := TTask.Create(
      Request.Title,
      Request.Description,
      Request.Priority,
      Request.DueDate
    );

    // Salvar no repositório
    Task := TaskRepo.CreateTask(Task);
    Result := TTaskResponse.CreateFromTask(Task);

  except
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error creating task: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.UpdateTask(Id: Integer; Request: TCreateTaskRequest;
  TaskRepo: ITaskRepository): TTaskResponse;
var
  ExistingTask, UpdatedTask: TTask;
  ValidationErrors: TArray<string>;
begin
  // Validar request
  ValidationErrors := Request.Validate;
  if Length(ValidationErrors) > 0 then
    raise EDextHttpException.Create(400, 'Validation errors: ' + string.Join('; ', ValidationErrors));

  try
    // Obter tarefa existente
    ExistingTask := TaskRepo.GetById(Id);

    // Atualizar campos
    UpdatedTask := ExistingTask;
    UpdatedTask.Title := Request.Title;
    UpdatedTask.Description := Request.Description;
    UpdatedTask.Priority := Request.Priority;
    UpdatedTask.DueDate := Request.DueDate;

    // Salvar alterações
    UpdatedTask := TaskRepo.UpdateTask(Id, UpdatedTask);
    Result := TTaskResponse.CreateFromTask(UpdatedTask);

  except
    on E: EArgumentException do
      raise EDextHttpException.Create(404, Format('Task not found: %d', [Id]));
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error updating task: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.DeleteTask(Id: Integer;
  TaskRepo: ITaskRepository): TDextResponse;
begin
  try
    if TaskRepo.DeleteTask(Id) then
      Result := TDextResponse.SuccessResponse(Format('Task %d deleted successfully', [Id]))
    else
      raise EDextHttpException.Create(404, Format('Task not found: %d', [Id]));

  except
    on E: EDextHttpException do
      raise;
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error deleting task: %s', [E.Message]));
  end;
end;

// ============================================================================
// OPERAÇÕES ESPECIAIS (continuação na próxima mensagem devido ao limite de tamanho)
// ============================================================================

class function TTaskHandlers.SearchTasks(Filter: TTaskFilter;
  TaskRepo: ITaskRepository): TTaskListResponse;
begin
  try
    if not Filter.IsValid then
      raise EDextHttpException.Create(400, 'Invalid filter parameters');

    var Tasks := TaskRepo.SearchTasks(Filter);
    var TotalCount := TaskRepo.GetTaskCount; // Em produção, teríamos count com filtro

    Result := TTaskListResponse.Create(Tasks, TotalCount, Filter.Page, Filter.PageSize);

  except
    on E: EDextHttpException do
      raise;
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error searching tasks: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.GetTasksByStatus(Status: TTaskStatus;
  TaskRepo: ITaskRepository): TTaskListResponse;
begin
  try
    var Tasks := TaskRepo.GetTasksByStatus(Status);
    var TotalCount := Length(Tasks);

    Result := TTaskListResponse.Create(Tasks, TotalCount, 1, TotalCount);

  except
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error retrieving tasks by status: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.GetTasksByPriority(Priority: TTaskPriority;
  TaskRepo: ITaskRepository): TTaskListResponse;
begin
  try
    var Tasks := TaskRepo.GetTasksByPriority(Priority);
    var TotalCount := Length(Tasks);

    Result := TTaskListResponse.Create(Tasks, TotalCount, 1, TotalCount);

  except
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error retrieving tasks by priority: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.GetOverdueTasks(TaskRepo: ITaskRepository): TTaskListResponse;
begin
  try
    var Tasks := TaskRepo.GetOverdueTasks;
    var TotalCount := Length(Tasks);

    Result := TTaskListResponse.Create(Tasks, TotalCount, 1, TotalCount);

  except
    on E: Exception do
      raise EDextHttpException.Create(500, 'Error retrieving overdue tasks');
  end;
end;

// ============================================================================
// CONTINUAÇÃO NAS PRÓXIMAS MENSAGENS...
// ============================================================================

{ TUpdateStatusRequest }

function TUpdateStatusRequest.Validate: TArray<string>;
begin
  Result := [];
  // Validação básica - status deve ser válido
  if not (Status in [Low(TTaskStatus)..High(TTaskStatus)]) then
    Result := Result + ['Invalid status value'];
end;

function TUpdateStatusRequest.IsValid: Boolean;
begin
  Result := Length(Validate) = 0;
end;

{ TBulkStatusUpdateRequest }

function TBulkStatusUpdateRequest.Validate: TArray<string>;
begin
  Result := [];

  if Length(TaskIds) = 0 then
    Result := Result + ['At least one task ID is required'];

  if Length(TaskIds) > 100 then
    Result := Result + ['Maximum 100 tasks per bulk operation'];

  if not (NewStatus in [Low(TTaskStatus)..High(TTaskStatus)]) then
    Result := Result + ['Invalid status value'];
end;

function TBulkStatusUpdateRequest.IsValid: Boolean;
begin
  Result := Length(Validate) = 0;
end;

{ TBulkDeleteRequest }

function TBulkDeleteRequest.Validate: TArray<string>;
begin
  Result := [];

  if Length(TaskIds) = 0 then
    Result := Result + ['At least one task ID is required'];

  if Length(TaskIds) > 100 then
    Result := Result + ['Maximum 100 tasks per bulk operation'];
end;

function TBulkDeleteRequest.IsValid: Boolean;
begin
  Result := Length(Validate) = 0;
end;

{ TBulkOperationResponse }

constructor TBulkOperationResponse.Create(ASuccessCount, ATotalCount: Integer;
  AErrors: TArray<string>);
begin
  Self.SuccessCount := ASuccessCount;
  Self.TotalCount := ATotalCount;
  Self.Errors := AErrors;
end;

function TBulkOperationResponse.GetSuccessRate: Double;
begin
  if TotalCount = 0 then
    Result := 0
  else
    Result := (SuccessCount / TotalCount) * 100;
end;

{ TDextResponse }

constructor TDextResponse.Create(ASuccess: Boolean; const AMessage: string; AData: TValue);
begin
  Self.Success := ASuccess;
  Self.Message := AMessage;
  Self.Data := AData;
end;

class function TDextResponse.SuccessResponse(const AMessage: string): TDextResponse;
begin
  Result := TDextResponse.Create(True, AMessage, TValue.Empty);
end;

class function TDextResponse.ErrorResponse(const AMessage: string): TDextResponse;
begin
  Result := TDextResponse.Create(False, AMessage, TValue.Empty);
end;

// ============================================================================
// OPERAÇÕES EM LOTE
// ============================================================================

class function TTaskHandlers.BulkUpdateStatus(Request: TBulkStatusUpdateRequest;
  TaskRepo: ITaskRepository): TBulkOperationResponse;
var
  ValidationErrors: TArray<string>;
  SuccessCount: Integer;
begin
  // Validar request
  ValidationErrors := Request.Validate;
  if Length(ValidationErrors) > 0 then
    raise EDextHttpException.Create(400, 'Validation errors: ' + string.Join('; ', ValidationErrors));

  try
    SuccessCount := TaskRepo.BulkUpdateStatus(Request.TaskIds, Request.NewStatus);
    Result := TBulkOperationResponse.Create(SuccessCount, Length(Request.TaskIds));

  except
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error in bulk status update: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.BulkDeleteTasks(Request: TBulkDeleteRequest;
  TaskRepo: ITaskRepository): TBulkOperationResponse;
var
  ValidationErrors: TArray<string>;
  SuccessCount: Integer;
begin
  // Validar request
  ValidationErrors := Request.Validate;
  if Length(ValidationErrors) > 0 then
    raise EDextHttpException.Create(400, 'Validation errors: ' + string.Join('; ', ValidationErrors));

  try
    SuccessCount := TaskRepo.BulkDelete(Request.TaskIds);
    Result := TBulkOperationResponse.Create(SuccessCount, Length(Request.TaskIds));

  except
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error in bulk delete: %s', [E.Message]));
  end;
end;

// ============================================================================
// OPERAÇÕES DE STATUS
// ============================================================================

class function TTaskHandlers.UpdateTaskStatus(Id: Integer; Request: TUpdateStatusRequest;
  TaskRepo: ITaskRepository): TTaskResponse;
var
  ExistingTask, UpdatedTask: TTask;
  ValidationErrors: TArray<string>;
begin
  // Validar request
  ValidationErrors := Request.Validate;
  if Length(ValidationErrors) > 0 then
    raise EDextHttpException.Create(400, 'Validation errors: ' + string.Join('; ', ValidationErrors));

  try
    // Obter tarefa existente
    ExistingTask := TaskRepo.GetById(Id);

    // Validar transição de status
    if not ExistingTask.CanChangeStatus(Request.Status) then
      raise EDextHttpException.Create(400,
        Format('Cannot change status from %s to %s',
          [ExistingTask.Status.ToString, Request.Status.ToString]));

    // Atualizar status
    UpdatedTask := ExistingTask;
    UpdatedTask.Status := Request.Status;

    // Salvar alterações
    UpdatedTask := TaskRepo.UpdateTask(Id, UpdatedTask);
    Result := TTaskResponse.CreateFromTask(UpdatedTask);

  except
    on E: EArgumentException do
      raise EDextHttpException.Create(404, Format('Task not found: %d', [Id]));
    on E: EDextHttpException do
      raise;
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error updating task status: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.CompleteTask(Id: Integer;
  TaskRepo: ITaskRepository): TTaskResponse;
var
  StatusRequest: TUpdateStatusRequest;
begin
  StatusRequest.Status := tsCompleted;
  Result := UpdateTaskStatus(Id, StatusRequest, TaskRepo);
end;

class function TTaskHandlers.StartTask(Id: Integer;
  TaskRepo: ITaskRepository): TTaskResponse;
var
  StatusRequest: TUpdateStatusRequest;
begin
  StatusRequest.Status := tsInProgress;
  Result := UpdateTaskStatus(Id, StatusRequest, TaskRepo);
end;

class function TTaskHandlers.CancelTask(Id: Integer;
  TaskRepo: ITaskRepository): TTaskResponse;
var
  StatusRequest: TUpdateStatusRequest;
begin
  StatusRequest.Status := tsCancelled;
  Result := UpdateTaskStatus(Id, StatusRequest, TaskRepo);
end;

// ============================================================================
// ESTATÍSTICAS E RELATÓRIOS
// ============================================================================

class function TTaskHandlers.GetTasksStats(
  TaskRepo: ITaskRepository): TTaskStats;
begin
  try
    Result := TaskRepo.GetTasksStats;
  except
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error retrieving task stats: %s', [E.Message]));
  end;
end;

class function TTaskHandlers.GetStatusCounts(
  TaskRepo: ITaskRepository): TArray<TTaskStatusCount>;
begin
  try
    Result := TaskRepo.GetTasksCountByStatus;
  except
    on E: Exception do
      raise EDextHttpException.Create(500, Format('Error retrieving status counts: %s', [E.Message]));
  end;
end;

end.
