unit TaskFlow.Domain;

interface

uses
  System.DateUtils,
  System.SysUtils,
  Dext.Core.ModelBinding;

type
  // ===========================================================================
  // ENUMS PRINCIPAIS
  // ===========================================================================
  TTaskStatus = (tsPending, tsInProgress, tsCompleted, tsCancelled);
  TTaskPriority = (tpLow, tpMedium, tpHigh, tpCritical);

  // ===========================================================================
  // HELPERS PARA CONVERSÃO DE ENUMS
  // ===========================================================================
  TTaskStatusHelper = record helper for TTaskStatus
  public
    function ToString: string;
    function ToDisplayText: string;
    class function FromString(const Value: string): TTaskStatus; static;
    class function TryFromString(const Value: string; out Status: TTaskStatus): Boolean; static;
  end;

  TTaskPriorityHelper = record helper for TTaskPriority
  public
    function ToString: string;
    function ToDisplayText: string;
    function ToColor: string;
    class function FromString(const Value: string): TTaskPriority; static;
    class function TryFromString(const Value: string; out Priority: TTaskPriority): Boolean; static;
  end;

  // ===========================================================================
  // RECORDS DE DOMÍNIO
  // ===========================================================================
  TTaskFilter = record
  public
    [FromQuery('status')]
    Status: TTaskStatus;

    [FromQuery('priority')]
    Priority: TTaskPriority;

    [FromQuery('due_before')]
    DueBefore: TDateTime;

    [FromQuery('due_after')]
    DueAfter: TDateTime;

    [FromQuery('page')]
    Page: Integer;

    [FromQuery('page_size')]
    PageSize: Integer;

    constructor Create(APage, APageSize: Integer);

    // Factory methods
    class function CreateDefault: TTaskFilter; static;
    class function CreateWithStatus(AStatus: TTaskStatus): TTaskFilter; static;
    class function CreateWithPriority(APriority: TTaskPriority): TTaskFilter; static;

    function IsValid: Boolean;
    function HasDateFilter: Boolean;
    function HasStatusFilter: Boolean;
    function HasPriorityFilter: Boolean;
  end;

  TTask = record
  public
    Id: Integer;
    Title: string;
    Description: string;
    Status: TTaskStatus;
    Priority: TTaskPriority;
    CreatedAt: TDateTime;
    DueDate: TDateTime;
    UserId: string;

    constructor Create(const ATitle, ADescription: string;
      APriority: TTaskPriority; ADueDate: TDateTime);

    // Factory methods
    class function CreateQuick(const ATitle: string;
      APriority: TTaskPriority = tpMedium): TTask; static;
    class function CreateCritical(const ATitle, ADescription: string): TTask; static;
    class function CreateWithDueDate(const ATitle: string;
      ADueDate: TDateTime): TTask; static;

    function IsOverdue: Boolean;
    function CanChangeStatus(NewStatus: TTaskStatus): Boolean;
    function GetRemainingDays: Integer;
  end;

  TTaskListResponse = record
  public
    Tasks: TArray<TTask>;
    TotalCount: Integer;
    Page: Integer;
    PageSize: Integer;
    HasNextPage: Boolean;

    constructor Create(ATasks: TArray<TTask>; ATotalCount, APage, APageSize: Integer);

    // Factory methods
    class function CreateEmpty: TTaskListResponse; static;
    class function CreateSingle(const ATask: TTask): TTaskListResponse; static;

    function GetPageCount: Integer;
  end;

  // ===========================================================================
  // RECORDS PARA REQUEST/RESPONSE
  // ===========================================================================
  TCreateTaskRequest = record
  public
    Title: string;
    Description: string;
    Priority: TTaskPriority;
    DueDate: TDateTime;

    // Factory methods
    class function CreateDefault: TCreateTaskRequest; static;

    function Validate: TArray<string>; // Retorna lista de erros
    function IsValid: Boolean;
  end;

  TTaskResponse = record
  public
    Id: Integer;
    Title: string;
    Description: string;
    Status: TTaskStatus;
    Priority: TTaskPriority;
    CreatedAt: TDateTime;
    DueDate: TDateTime;
    UserId: string;
    IsOverdue: Boolean;
    RemainingDays: Integer;

    constructor Create(const Task: TTask);

    // Factory method
    class function CreateFromTask(const Task: TTask): TTaskResponse; static;
  end;

// ===========================================================================
// FUNÇÕES GLOBAIS ÚTEIS
// ===========================================================================
function GenerateTaskId: Integer;

implementation

uses
  System.StrUtils;

var
  GTaskIdCounter: Integer = 0;

// ===========================================================================
// IMPLEMENTAÇÃO TTaskStatusHelper
// ===========================================================================
function TTaskStatusHelper.ToString: string;
begin
  case Self of
    tsPending: Result := 'pending';
    tsInProgress: Result := 'in_progress';
    tsCompleted: Result := 'completed';
    tsCancelled: Result := 'cancelled';
  else
    Result := 'unknown';
  end;
end;

function TTaskStatusHelper.ToDisplayText: string;
begin
  case Self of
    tsPending: Result := 'Pendente';
    tsInProgress: Result := 'Em Progresso';
    tsCompleted: Result := 'Concluída';
    tsCancelled: Result := 'Cancelada';
  else
    Result := 'Desconhecido';
  end;
end;

class function TTaskStatusHelper.FromString(const Value: string): TTaskStatus;
begin
  if not TryFromString(Value, Result) then
    raise EConvertError.CreateFmt('Invalid task status: %s', [Value]);
end;

class function TTaskStatusHelper.TryFromString(const Value: string; out Status: TTaskStatus): Boolean;
const
  ValidValues: array[0..9] of string = (
    'pending', 'pendente',
    'in_progress', 'inprogress', 'em_progresso',
    'completed', 'concluida', 'concluída',
    'cancelled', 'cancelada'
  );
var
  LowerValue: string;
  I: Integer;
begin
  LowerValue := LowerCase(Trim(Value));

  for I := 0 to High(ValidValues) do
  begin
    if LowerValue = ValidValues[I] then
    begin
      case I of
        0..1: Status := tsPending;
        2..4: Status := tsInProgress;
        5..7: Status := tsCompleted;
        8..9: Status := tsCancelled;
      else
        Status := tsPending;
      end;
      Result := True;
      Exit;
    end;
  end;

  Result := False;
  Status := tsPending;
end;

// ===========================================================================
// IMPLEMENTAÇÃO TTaskPriorityHelper
// ===========================================================================
function TTaskPriorityHelper.ToString: string;
begin
  case Self of
    tpLow: Result := 'low';
    tpMedium: Result := 'medium';
    tpHigh: Result := 'high';
    tpCritical: Result := 'critical';
  else
    Result := 'unknown';
  end;
end;

function TTaskPriorityHelper.ToDisplayText: string;
begin
  case Self of
    tpLow: Result := 'Baixa';
    tpMedium: Result := 'Média';
    tpHigh: Result := 'Alta';
    tpCritical: Result := 'Crítica';
  else
    Result := 'Desconhecida';
  end;
end;

function TTaskPriorityHelper.ToColor: string;
begin
  case Self of
    tpLow: Result := '#28a745';      // Verde
    tpMedium: Result := '#ffc107';   // Amarelo
    tpHigh: Result := '#fd7e14';     // Laranja
    tpCritical: Result := '#dc3545'; // Vermelho
  else
    Result := '#6c757d';             // Cinza
  end;
end;

class function TTaskPriorityHelper.FromString(const Value: string): TTaskPriority;
begin
  if not TryFromString(Value, Result) then
    raise EConvertError.CreateFmt('Invalid task priority: %s', [Value]);
end;

class function TTaskPriorityHelper.TryFromString(const Value: string; out Priority: TTaskPriority): Boolean;
var
  LowerValue: string;
begin
  LowerValue := LowerCase(Trim(Value));
  Result := True;
  // TODO: converter para array
  if (LowerValue = 'low') or (LowerValue = 'baixa') then
    Priority := tpLow
  else if (LowerValue = 'medium') or (LowerValue = 'media') or (LowerValue = 'média') then
    Priority := tpMedium
  else if (LowerValue = 'high') or (LowerValue = 'alta') then
    Priority := tpHigh
  else if (LowerValue = 'critical') or (LowerValue = 'critica') or (LowerValue = 'crítica') then
    Priority := tpCritical
  else
  begin
    Result := False;
    Priority := tpMedium;
  end;
end;

// ===========================================================================
// IMPLEMENTAÇÃO TTaskFilter
// ===========================================================================
constructor TTaskFilter.Create(APage, APageSize: Integer);
begin
  Self.Status := tsPending;
  Self.Priority := tpMedium;
  Self.DueBefore := 0;
  Self.DueAfter := 0;
  Self.Page := APage;
  Self.PageSize := APageSize;
end;

function TTaskFilter.IsValid: Boolean;
begin
  Result := (Page > 0) and (PageSize > 0) and (PageSize <= 100);
  if HasDateFilter then
    Result := Result and (DueAfter <= DueBefore);
end;

class function TTaskFilter.CreateDefault: TTaskFilter;
begin
  Result := TTaskFilter.Create(1, 10);
end;

class function TTaskFilter.CreateWithStatus(AStatus: TTaskStatus): TTaskFilter;
begin
  Result := TTaskFilter.CreateDefault;
  Result.Status := AStatus;
end;

class function TTaskFilter.CreateWithPriority(APriority: TTaskPriority): TTaskFilter;
begin
  Result := TTaskFilter.CreateDefault;
  Result.Priority := APriority;
end;

function TTaskFilter.HasDateFilter: Boolean;
begin
  Result := (DueBefore > 0) and (DueAfter > 0);
end;

function TTaskFilter.HasStatusFilter: Boolean;
begin
  Result := Status <> tsPending; // Consideramos pending como "não filtrado"
end;

function TTaskFilter.HasPriorityFilter: Boolean;
begin
  Result := Priority <> tpMedium; // Consideramos medium como "não filtrado"
end;

// ===========================================================================
// IMPLEMENTAÇÃO TTask
// ===========================================================================
constructor TTask.Create(const ATitle, ADescription: string;
  APriority: TTaskPriority; ADueDate: TDateTime);
begin
  Self.Id := GenerateTaskId;
  Self.Title := ATitle;
  Self.Description := ADescription;
  Self.Status := tsPending;
  Self.Priority := APriority;
  Self.CreatedAt := Now;
  Self.DueDate := ADueDate;
  Self.UserId := 'system'; // Default - será substituído quando tivermos auth
end;

class function TTask.CreateQuick(const ATitle: string;
  APriority: TTaskPriority = tpMedium): TTask;
begin
  Result := TTask.Create(ATitle, '', APriority, Now + 7);
end;

class function TTask.CreateCritical(const ATitle, ADescription: string): TTask;
begin
  Result := TTask.Create(ATitle, ADescription, tpCritical, Now + 1);
end;

class function TTask.CreateWithDueDate(const ATitle: string;
  ADueDate: TDateTime): TTask;
begin
  Result := TTask.Create(ATitle, '', tpMedium, ADueDate);
end;

function TTask.IsOverdue: Boolean;
begin
  Result := (Status in [tsPending, tsInProgress]) and (DueDate < Now);
end;

function TTask.CanChangeStatus(NewStatus: TTaskStatus): Boolean;
begin
  // Lógica de transição de status
  case Status of
    tsPending: Result := NewStatus in [tsInProgress, tsCancelled];
    tsInProgress: Result := NewStatus in [tsCompleted, tsCancelled];
    tsCompleted, tsCancelled: Result := False; // Estados finais
  else
    Result := False;
  end;
end;

function TTask.GetRemainingDays: Integer;
begin
  if DueDate = 0 then
    Result := 0
  else
    Result := DaysBetween(Now, DueDate);
end;

// ===========================================================================
// IMPLEMENTAÇÃO TTaskListResponse
// ===========================================================================
constructor TTaskListResponse.Create(ATasks: TArray<TTask>; ATotalCount, APage, APageSize: Integer);
begin
  Self.Tasks := ATasks;
  Self.TotalCount := ATotalCount;
  Self.Page := APage;
  Self.PageSize := APageSize;
  Self.HasNextPage := (Page * PageSize) < TotalCount;
end;

class function TTaskListResponse.CreateEmpty: TTaskListResponse;
begin
  Result := TTaskListResponse.Create([], 0, 1, 10);
end;

class function TTaskListResponse.CreateSingle(const ATask: TTask): TTaskListResponse;
begin
  Result := TTaskListResponse.Create([ATask], 1, 1, 10);
end;

function TTaskListResponse.GetPageCount: Integer;
begin
  if TotalCount = 0 then
    Result := 0
  else
    Result := (TotalCount + PageSize - 1) div PageSize;
end;

// ===========================================================================
// IMPLEMENTAÇÃO TCreateTaskRequest
// ===========================================================================
function TCreateTaskRequest.Validate: TArray<string>;
begin
  Result := [];

  if Trim(Title) = '' then
    Result := Result + ['Title is required'];

  if Length(Trim(Title)) > 100 then
    Result := Result + ['Title must be less than 100 characters'];

  if Length(Trim(Description)) > 1000 then
    Result := Result + ['Description must be less than 1000 characters'];

  if DueDate < Now then
    Result := Result + ['Due date must be in the future'];
end;

class function TCreateTaskRequest.CreateDefault: TCreateTaskRequest;
begin
  Result.Title := '';
  Result.Description := '';
  Result.Priority := tpMedium;
  Result.DueDate := Now + 7;
end;

function TCreateTaskRequest.IsValid: Boolean;
begin
  Result := Length(Validate) = 0;
end;

// ===========================================================================
// IMPLEMENTAÇÃO TTaskResponse
// ===========================================================================
constructor TTaskResponse.Create(const Task: TTask);
begin
  Self.Id := Task.Id;
  Self.Title := Task.Title;
  Self.Description := Task.Description;
  Self.Status := Task.Status;
  Self.Priority := Task.Priority;
  Self.CreatedAt := Task.CreatedAt;
  Self.DueDate := Task.DueDate;
  Self.UserId := Task.UserId;
  Self.IsOverdue := Task.IsOverdue;
  Self.RemainingDays := Task.GetRemainingDays;
end;

// ===========================================================================
// FUNÇÕES GLOBAIS
// ===========================================================================
function GenerateTaskId: Integer;
begin
  Inc(GTaskIdCounter);
  Result := GTaskIdCounter;
end;

class function TTaskResponse.CreateFromTask(const Task: TTask): TTaskResponse;
begin
  Result := TTaskResponse.Create(Task);
end;

end.
