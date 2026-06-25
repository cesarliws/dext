program Web.EventBusDemo;

{$APPTYPE CONSOLE}
(*
{***************************************************************************}
{  Web Event Bus Demo                                                       }
{                                                                           }
{  Demonstrates: AddScopedEventBus in a web API                             }
{    - Domain events published from controller actions                      }
{    - Handlers share the HTTP request DI scope (ILogger, DbContext, ...)   }
{    - TEventLoggingBehavior routes all dispatch output to ILogger          }
{    - TEventExceptionBehavior wraps handler failures with event context    }
{                                                                           }
{  Endpoints:                                                               }
{    POST   /api/tasks           - Create task (publishes TTaskCreatedEvent)}
{    PUT    /api/tasks/{id}/complete - Complete task (TTaskCompletedEvent)  }
{    DELETE /api/tasks/{id}      - Cancel task   (TTaskCancelledEvent)      }
{    GET    /swagger             - Swagger UI                               }
{***************************************************************************}
*)
uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  Dext,
  Dext.Web,
  EventBusWebDemo.Events         in 'EventBusWebDemo.Events.pas',
  EventBusWebDemo.Controller     in 'EventBusWebDemo.Controller.pas',
  EventBusWebDemo.EventBusConfig in 'EventBusWebDemo.EventBusConfig.pas',
  EventBusWebDemo.Startup        in 'EventBusWebDemo.Startup.pas';

var
  App: IWebApplication;
begin
  try
    SetConsoleCharSet(65001);
    WriteLn('==============================================');
    WriteLn(' Dext Event Bus - Web Integration Demo');
    WriteLn('==============================================');
    WriteLn;
    WriteLn('Pattern: AddScopedEventBus');
    WriteLn('  - IEventBus lifetime = HTTP request scope');
    WriteLn('  - Handlers share same ILogger / DbContext');
    WriteLn;
    WriteLn('Endpoints:');
    WriteLn('  POST   /api/tasks                - Create task');
    WriteLn('  PUT    /api/tasks/{id}/complete  - Complete task');
    WriteLn('  DELETE /api/tasks/{id}           - Cancel task');
    WriteLn('  GET    /swagger                  - Swagger UI');
    WriteLn;
    WriteLn('Example:');
    WriteLn('  curl -X POST http://localhost:8080/api/tasks \');
    WriteLn('    -H "Content-Type: application/json" \');
    WriteLn('    -d ''{"title":"Fix bug #42","assignedTo":"Alice"}''');
    WriteLn;

    App := TDextApplication.Create;
    App.UseStartup(TStartup.Create);
    App.Run(8080);

    WriteLn('[OK] Server stopped.');
  except
    on E: Exception do
    begin
      WriteLn('[ERROR] ', E.Message);
    end;
  end;
  ConsolePause;
end.
