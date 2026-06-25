unit Dext.Hosting.Events.Tests;

interface

uses
  System.SysUtils,
  Dext.DI.Core,
  Dext.DI.Interfaces,
  Dext.Events,
  Dext.Events.Interfaces,
  Dext.Events.Lifecycle,
  Dext.Hosting.BackgroundService,
  Dext.Hosting.Events,
  Dext.Hosting.Events.Bridge,
  Dext.Events.Extensions,
  Dext.Testing,
  Dext.Utils;

type
  /// <summary>
  ///   Mock handler for lifecycle events.
  ///   Inherits from TObject (not TInterfacedObject) to prevent ARC from
  ///   destroying the instance when temporary interface references are created
  ///   during EventBus dispatch. The DI container manages this object's lifetime
  ///   via AddSingletonInstance (stored in FSingletons as TObject).
  /// </summary>
  TMockLifecycleHandler = class(TObject,
    IEventHandler<TApplicationStartedEvent>,
    IEventHandler<TApplicationStoppingEvent>,
    IEventHandler<TApplicationStoppedEvent>)
  public
    StartedCalled: Boolean;
    StoppingCalled: Boolean;
    StoppedCalled: Boolean;
    procedure Handle(const AEvent: TApplicationStartedEvent); overload;
    procedure Handle(const AEvent: TApplicationStoppingEvent); overload;
    procedure Handle(const AEvent: TApplicationStoppedEvent); overload;

    // IInterface - Manual implementation (DI container manages lifetime)
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  end;

  [TestFixture]
  THostingEventsTests = class
  public
    [Test]
    procedure Test_Manager_Publishes_Lifecycle_Events;
  end;

implementation

{ TMockLifecycleHandler }

procedure TMockLifecycleHandler.Handle(const AEvent: TApplicationStartedEvent);
begin
  StartedCalled := True;
end;

procedure TMockLifecycleHandler.Handle(const AEvent: TApplicationStoppingEvent);
begin
  StoppingCalled := True;
end;

procedure TMockLifecycleHandler.Handle(const AEvent: TApplicationStoppedEvent);
begin
  StoppedCalled := True;
end;

function TMockLifecycleHandler.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TMockLifecycleHandler._AddRef: Integer;
begin
  Result := -1; // No-op - DI/test manages lifetime
end;

function TMockLifecycleHandler._Release: Integer;
begin
  Result := -1; // No-op - DI/test manages lifetime
end;

{ THostingEventsTests }

procedure THostingEventsTests.Test_Manager_Publishes_Lifecycle_Events;
var
  Services: TDextServices;
  Provider: IServiceProvider;
  Handler: TMockLifecycleHandler;
  Manager: IHostedServiceManager;
begin
  Services := TDextServices.New;

  Services.AddEventBus;
  
  Handler := TMockLifecycleHandler.Create;
  // 1. REGISTER THE MOCK INSTANCE FIRST!
  // This ensures DI already has the singleton before the Event Bus asks for it.
  // NOTE: DI container takes ownership - do NOT free Handler manually.
  Services.AddSingletonInstance<TMockLifecycleHandler>(Handler);
  
  // 2. Now register the handler in the Bus
  Services.AddEventHandler<TApplicationStartedEvent, TMockLifecycleHandler>;
  Services.AddEventHandler<TApplicationStoppingEvent, TMockLifecycleHandler>;
  Services.AddEventHandler<TApplicationStoppedEvent, TMockLifecycleHandler>;
  
  Services.AddBackgroundServices
    .AddLifecycleEvents
    .Build;
  
  Provider := Services.BuildServiceProvider;
  Manager := Provider.GetServiceAsInterface(TypeInfo(IHostedServiceManager)) as IHostedServiceManager;

  try
    // 1. Start
    Manager.StartAsync;
      
    // Wait a tiny bit just in case
    Sleep(10);
      
    if not Handler.StartedCalled then
      WriteLn('   [Mock] ❌ StartedCalled is still FALSE!');
        
    Should(Handler.StartedCalled).BeTrue;
      
    // 2. Stop
    Manager.StopAsync;
      
    if not Handler.StoppingCalled then
      WriteLn('   [Mock] ❌ StoppingCalled is still FALSE!');

    Should(Handler.StoppingCalled).BeTrue;
    // Note: TApplicationStoppedEvent depends on manager destruction or explicit fire
  except
    on E: Exception do
    begin
      WriteLn('   [Test] Caught ' + E.ClassName + ': ' + E.Message);
      raise;
    end;
  end;
end;

end.
