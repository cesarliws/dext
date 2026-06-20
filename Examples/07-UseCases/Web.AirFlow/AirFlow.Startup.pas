unit AirFlow.Startup;

interface

uses
  System.SysUtils,
  Dext,
  Dext.Web,
  AirFlow.Simulator;

type
  TStartup = class(TInterfacedObject, IStartup)
  private
    FSimulator: TSimulatorThread;
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
    destructor Destroy; override;
  end;

implementation

uses
  Dext.Web.Hubs,
  Dext.Web.Hubs.Extensions,
  AirFlow.Hubs;

{ TStartup }

destructor TStartup.Destroy;
begin
  if Assigned(FSimulator) then
  begin
    FSimulator.Terminate;
    FSimulator.WaitFor;
    FSimulator.Free;
  end;
  THubExtensions.ShutdownHubs;
  inherited;
end;

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services.AddControllers;
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  THubExtensions.UseHubs(App.Builder);

  // Set up the request pipeline
  App.Builder
    .UseExceptionHandler
    .UseHttpLogging
    .UseCors(CorsOptions.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader)
    .UseStaticFiles('airflow_wwwroot'); // Serves files from airflow_wwwroot

  // Map the AirFlow Hub
  MapHub(App.Builder, '/hubs/airflow', TAirFlowHub);

  // Simple API Endpoint for manually reporting incidents/alerts
  App.Builder.MapPost('/api/alerts',
    procedure(Ctx: IHttpContext)
    var
      VehicleId, Message: string;
      HubContext: IHubContext;
      AlertJson: string;
    begin
      VehicleId := Ctx.Request.GetQueryParam('vehicleId');
      Message := Ctx.Request.GetQueryParam('message');
      
      if (VehicleId = '') or (Message = '') then
      begin
        Ctx.Response.StatusCode := 400;
        Ctx.Response.Write('{"error": "Missing vehicleId or message"}');
        Exit;
      end;

      try
        HubContext := THubExtensions.GetHubContext;
        AlertJson := Format('{"vehicleId":"%s","message":"%s","timestamp":"%s"}', [
          VehicleId, Message, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
        ]);
        HubContext.Clients.All.SendAsync('OnSystemAlert', AlertJson);
        Ctx.Response.Write('{"status": "Alert broadcasted"}');
      except
        on E: Exception do
        begin
          Ctx.Response.StatusCode := 500;
          Ctx.Response.Write('{"error": "' + E.Message + '"}');
        end;
      end;
    end);

  // Map health check
  App.Builder.MapGet('/health',
    procedure(Ctx: IHttpContext)
    begin
      Ctx.Response.Json('{"status": "healthy", "service": "Dext AirFlow"}');
    end);

  // Map simulator control endpoints
  App.Builder.MapPost('/api/simulator/start',
    procedure(Ctx: IHttpContext)
    begin
      FSimulator.Active := True;
      Ctx.Response.Json('{"active": true}');
    end);

  App.Builder.MapPost('/api/simulator/stop',
    procedure(Ctx: IHttpContext)
    begin
      FSimulator.Active := False;
      Ctx.Response.Json('{"active": false}');
    end);

  App.Builder.MapGet('/api/simulator/status',
    procedure(Ctx: IHttpContext)
    begin
      if FSimulator.Active then
        Ctx.Response.Json('{"active": true}')
      else
        Ctx.Response.Json('{"active": false}');
    end);

  // Map vehicle specific action commands
  App.Builder.MapPost('/api/vehicles/{id}/rtl',
    procedure(Ctx: IHttpContext)
    var
      Id: string;
    begin
      if Ctx.Request.RouteParams.TryGetValue('id', Id) then
        FSimulator.ForceRTL(Id);
      Ctx.Response.Json('{"status": "returning to base", "id": "' + Id + '"}');
    end);

  App.Builder.MapPost('/api/vehicles/{id}/land',
    procedure(Ctx: IHttpContext)
    var
      Id: string;
    begin
      if Ctx.Request.RouteParams.TryGetValue('id', Id) then
        FSimulator.ForceLand(Id);
      Ctx.Response.Json('{"status": "landing", "id": "' + Id + '"}');
    end);

  // Start background simulator
  FSimulator := TSimulatorThread.Create;
  FSimulator.Start;
end;

end.
