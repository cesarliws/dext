unit EventBusDemo.Behaviors;

/// <summary>
///   Custom pipeline behavior for the EventBusDemo.
///   TConsolePipelineBehavior wraps every handler invocation and prints
///   entry/exit breadcrumbs, demonstrating how behaviors work in the pipeline.
/// </summary>

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Rtti,
  Dext.Events,
  Dext.Events.Interfaces;

type
  /// <summary>
  ///   Prints ">> entering" before and "&lt;&lt; leaving" after each handler.
  ///   Calls ANext() to continue the pipeline - omitting the call would
  ///   short-circuit all remaining behaviors and the handler itself.
  /// </summary>
  TConsolePipelineBehavior = class(TInterfacedObject, IEventBehavior)
  public
    procedure Intercept(AEventType: PTypeInfo; const AEvent: TValue;
      const ANext: TEventNextDelegate);
  end;

  /// <summary>
  ///   Per-event behavior used only for TOrderPlacedEvent.
  ///   Validates that TotalAmount is positive before letting the pipeline proceed.
  /// </summary>
  TOrderValidationBehavior = class(TInterfacedObject, IEventBehavior)
  public
    procedure Intercept(AEventType: PTypeInfo; const AEvent: TValue;
      const ANext: TEventNextDelegate);
  end;

implementation

uses
  EventBusDemo.Events;

{ TConsolePipelineBehavior }

procedure TConsolePipelineBehavior.Intercept(AEventType: PTypeInfo;
  const AEvent: TValue; const ANext: TEventNextDelegate);
begin
  WriteLn(Format('  [Pipeline] >> entering handler for %s',
    [string(AEventType.Name)]));
  ANext(); // continue to the next behavior / handler
  WriteLn(Format('  [Pipeline] << leaving handler for %s',
    [string(AEventType.Name)]));
end;

{ TOrderValidationBehavior }

procedure TOrderValidationBehavior.Intercept(AEventType: PTypeInfo;
  const AEvent: TValue; const ANext: TEventNextDelegate);
var
  Evt: TOrderPlacedEvent;
begin
  Evt := AEvent.AsType<TOrderPlacedEvent>;
  if Evt.TotalAmount <= 0 then
  begin
    WriteLn(Format('  [Validate] Order #%d rejected: TotalAmount must be > 0',
      [Evt.OrderId]));
    // Do NOT call ANext - short-circuit the pipeline for this handler.
    Exit;
  end;
  WriteLn(Format('  [Validate] Order #%d passed validation ($%.2f)',
    [Evt.OrderId, Evt.TotalAmount]));
  ANext();
end;

end.
