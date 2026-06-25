unit EventBusWebDemo.Events;

{***************************************************************************}
{  Web Event Bus Demo - Domain Events and Handlers                          }
{                                                                           }
{  Shows AddScopedEventBus: handlers receive the same DI scope as the       }
{  controller that published the event.                                     }
{  Handlers use WriteLn so output is visible in the server console.         }
{***************************************************************************}

interface

uses
  System.SysUtils,
  Dext.Events.Interfaces;

// ==========================================================================
// Domain Events (plain records - zero allocation, value semantics)
// ==========================================================================

type
  TTaskCreatedEvent = record
    TaskId: Integer;
    Title: string;
    AssignedTo: string;
    CreatedAt: TDateTime;
  end;

  TTaskCompletedEvent = record
    TaskId: Integer;
    CompletedBy: string;
    CompletedAt: TDateTime;
  end;

  TTaskCancelledEvent = record
    TaskId: Integer;
    Reason: string;
    CancelledAt: TDateTime;
  end;

// ==========================================================================
// Handlers - parameterless constructors, zero DI dependencies
// ==========================================================================

  TTaskCreatedHandler = class(TInterfacedObject, IEventHandler<TTaskCreatedEvent>)
  public
    constructor Create;
    procedure Handle(const AEvent: TTaskCreatedEvent);
  end;

  TTaskCompletedHandler = class(TInterfacedObject, IEventHandler<TTaskCompletedEvent>)
  public
    constructor Create;
    procedure Handle(const AEvent: TTaskCompletedEvent);
  end;

  TTaskCancelledHandler = class(TInterfacedObject, IEventHandler<TTaskCancelledEvent>)
  public
    constructor Create;
    procedure Handle(const AEvent: TTaskCancelledEvent);
  end;

implementation

{ TTaskCreatedHandler }

constructor TTaskCreatedHandler.Create;
begin
  inherited Create;
end;

procedure TTaskCreatedHandler.Handle(const AEvent: TTaskCreatedEvent);
begin
  WriteLn(Format('  [Handler] Task #%d created: "%s" assigned to %s',
    [AEvent.TaskId, AEvent.Title, AEvent.AssignedTo]));
end;

{ TTaskCompletedHandler }

constructor TTaskCompletedHandler.Create;
begin
  inherited Create;
end;

procedure TTaskCompletedHandler.Handle(const AEvent: TTaskCompletedEvent);
begin
  WriteLn(Format('  [Handler] Task #%d completed by %s at %s',
    [AEvent.TaskId, AEvent.CompletedBy, FormatDateTime('hh:nn:ss', AEvent.CompletedAt)]));
end;

{ TTaskCancelledHandler }

constructor TTaskCancelledHandler.Create;
begin
  inherited Create;
end;

procedure TTaskCancelledHandler.Handle(const AEvent: TTaskCancelledEvent);
begin
  WriteLn(Format('  [Handler] Task #%d cancelled. Reason: %s',
    [AEvent.TaskId, AEvent.Reason]));
end;

end.
