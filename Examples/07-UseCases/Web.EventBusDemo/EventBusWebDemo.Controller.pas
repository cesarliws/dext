unit EventBusWebDemo.Controller;

{***************************************************************************}
{  Web Event Bus Demo - Tasks Controller                                    }
{                                                                           }
{  IEventBus is injected as a SCOPED service (AddScopedEventBus).           }
{  Handlers resolved during Publish share the same DI scope as this         }
{  controller - same ILogger context, same DbContext (if registered).       }
{***************************************************************************}

interface

uses
  System.SysUtils,
  Dext.Web,
  Dext.Events.Interfaces,
  EventBusWebDemo.Events;

type
  // Request DTOs
  TCreateTaskRequest = record
    Title: string;
    AssignedTo: string;
  end;

  TCompleteTaskRequest = record
    CompletedBy: string;
  end;

  TCancelTaskRequest = record
    Reason: string;
  end;

  // Response DTO
  TTaskResponse = record
    TaskId: Integer;
    Title: string;
    AssignedTo: string;
    Status: string;
    Message: string;
  end;

  [ApiController('/api/tasks')]
  TTaskController = class
  private
    FEventBus: IEventBus;
    class var FNextId: Integer; // Simple in-memory ID counter (demo only)
  public
    constructor Create(const AEventBus: IEventBus);

    /// <summary>POST /api/tasks - Create a new task and publish TTaskCreatedEvent</summary>
    [HttpPost]
    function CreateTask(const Request: TCreateTaskRequest): IResult;

    /// <summary>PUT /api/tasks/{id}/complete - Complete a task and publish TTaskCompletedEvent</summary>
    [HttpPut('/{id}/complete')]
    function CompleteTask(Id: Integer; const Request: TCompleteTaskRequest): IResult;

    /// <summary>DELETE /api/tasks/{id} - Cancel a task and publish TTaskCancelledEvent</summary>
    [HttpDelete('/{id}')]
    function CancelTask(Id: Integer; const Request: TCancelTaskRequest): IResult;
  end;

implementation

{ TTaskController }

constructor TTaskController.Create(const AEventBus: IEventBus);
begin
  inherited Create;
  FEventBus := AEventBus;
end;

function TTaskController.CreateTask(const Request: TCreateTaskRequest): IResult;
var
  Event: TTaskCreatedEvent;
  Response: TTaskResponse;
begin
  Inc(FNextId);

  Event.TaskId     := FNextId;
  Event.Title      := Request.Title;
  Event.AssignedTo := Request.AssignedTo;
  Event.CreatedAt  := Now;
  TEventBusExtensions.Publish<TTaskCreatedEvent>(FEventBus, Event);

  Response.TaskId     := FNextId;
  Response.Title      := Request.Title;
  Response.AssignedTo := Request.AssignedTo;
  Response.Status     := 'Created';
  Response.Message    := 'Task created and domain event published';

  Result := Results.Created<TTaskResponse>('/api/tasks/' + IntToStr(FNextId), Response);
end;

function TTaskController.CompleteTask(Id: Integer;
  const Request: TCompleteTaskRequest): IResult;
var
  Event: TTaskCompletedEvent;
  Response: TTaskResponse;
begin
  Event.TaskId      := Id;
  Event.CompletedBy := Request.CompletedBy;
  Event.CompletedAt := Now;
  TEventBusExtensions.Publish<TTaskCompletedEvent>(FEventBus, Event);

  Response.TaskId  := Id;
  Response.Status  := 'Completed';
  Response.Message := 'Task completed and domain event published';

  Result := Results.Ok<TTaskResponse>(Response);
end;

function TTaskController.CancelTask(Id: Integer;
  const Request: TCancelTaskRequest): IResult;
var
  Event: TTaskCancelledEvent;
  Response: TTaskResponse;
begin
  Event.TaskId      := Id;
  Event.Reason      := Request.Reason;
  Event.CancelledAt := Now;
  TEventBusExtensions.Publish<TTaskCancelledEvent>(FEventBus, Event);

  Response.TaskId  := Id;
  Response.Status  := 'Cancelled';
  Response.Message := 'Task cancelled and domain event published';

  Result := Results.Ok<TTaskResponse>(Response);
end;

initialization
  TTaskController.ClassName;

end.
