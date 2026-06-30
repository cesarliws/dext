unit EventBusWebDemo.Startup;

{***************************************************************************}
{  Web Event Bus Demo - Application Startup                                 }
{                                                                           }
{  Key pattern: AddScopedEventBus                                           }
{    - IEventBus is created once per HTTP request scope.                    }
{    - Handlers resolved during Publish() share the same DI scope:          }
{      same ILogger context, same DbContext, same identity, etc.            }
{    - Contrast with AddEventBus (singleton): each Publish creates a        }
{      fresh child scope, isolating handlers from the caller.               }
{                                                                           }
{  Note on record helpers:                                                  }
{    TWebServicesHelper (Dext.Web) and TEventBusDIExtensions                }
{    (Dext.Events.Extensions) both extend TDextServices. Delphi allows      }
{    only one record helper per type in scope, so Event Bus registration    }
{    is isolated in EventBusWebDemo.EventBusConfig to keep both helpers     }
{    working correctly in their respective units.                            }
{***************************************************************************}

interface

uses
  System.SysUtils,
  Dext, Dext.DI.Interfaces,
  Dext.Web,
  EventBusWebDemo.EventBusConfig,
  EventBusWebDemo.Controller;

type
  TStartup = class(TInterfacedObject, IStartup)
  public
    procedure ConfigureServices(const Services: TDextServices;
      const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

implementation

{ TStartup }

procedure TStartup.ConfigureServices(const Services: TDextServices;
  const Configuration: IConfiguration);
begin
  ConfigureEventBus(Services);
  Services.AddControllers;
end;

procedure TStartup.Configure(const App: IWebApplication);
var
  SwaggerOpts: TOpenAPIOptions;
begin
  JsonDefaultSettings(JsonSettings.Default.CamelCase.CaseInsensitive);

  App.Builder.UseExceptionHandler;

  App.MapControllers;

  SwaggerOpts := TOpenAPIOptions.Default;
  SwaggerOpts.Title := 'Web Event Bus Demo';
  SwaggerOpts.Version := '1.0.0';
  SwaggerOpts.Description :=
    'Demonstrates AddScopedEventBus: handlers share the HTTP request DI scope.';
  SwaggerOpts.SwaggerPath     := '/swagger';
  SwaggerOpts.SwaggerJsonPath := '/swagger.json';
  App.Builder.UseSwagger(SwaggerOpts);
end;

end.
