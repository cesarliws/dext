unit EventBusWebDemo.EventBusConfig;

{***************************************************************************}
{  Web Event Bus Demo - Event Bus registration                              }
{                                                                           }
{  Isolated in its own unit so that TEventBusDIExtensions (record helper    }
{  for TDextServices from Dext.Events.Extensions) does not shadow           }
{  TWebServicesHelper (from Dext.Web) in the main Startup unit.             }
{  Delphi allows only one record helper per type per compilation scope.     }
{***************************************************************************}

interface

uses
  Dext, Dext.DI.Interfaces;

procedure ConfigureEventBus(const Services: TDextServices);

implementation

uses
  Dext.Events.Extensions,
  Dext.Events.Behaviors,
  EventBusWebDemo.Events;

procedure ConfigureEventBus(const Services: TDextServices);
begin
  Services
    .AddScopedEventBus
    .AddEventHandler<TTaskCreatedEvent, TTaskCreatedHandler>
    .AddEventHandler<TTaskCompletedEvent, TTaskCompletedHandler>
    .AddEventHandler<TTaskCancelledEvent, TTaskCancelledHandler>
    .AddEventBehavior<TEventExceptionBehavior>;
end;

end.
