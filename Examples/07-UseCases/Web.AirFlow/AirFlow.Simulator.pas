unit AirFlow.Simulator;

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  Dext.Collections,
  AirFlow.Domain;

type
  TVehicleCommand = (cmdNone, cmdRTL, cmdLand);

  TVehicleFlightState = record
    Heading: Double;
    Speed: Double;
  end;

  TSimulatorThread = class(TThread)
  private
    FVehicles: IList<TVehicle>;
    FFlightStates: TArray<TVehicleFlightState>;
    FCommands: array[0..39] of TVehicleCommand;
    FLock: TCriticalSection;
    FActive: Boolean;
    procedure InitializeVehicles;
    procedure UpdateVehicles;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ForceRTL(const AVehicleId: string);
    procedure ForceLand(const AVehicleId: string);
    property Active: Boolean read FActive write FActive;
  end;

implementation

uses
  System.Math,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Extensions;

{ TSimulatorThread }

constructor TSimulatorThread.Create;
var
  I: Integer;
begin
  inherited Create(True);
  FLock := TCriticalSection.Create;
  FVehicles := TCollections.CreateList<TVehicle>;
  FActive := False; // Simulator starts paused
  for I := 0 to 39 do
    FCommands[I] := cmdNone;
  InitializeVehicles;
end;

destructor TSimulatorThread.Destroy;
begin
  FVehicles := nil; // IList is ref-counted
  FLock.Free;
  inherited;
end;

procedure TSimulatorThread.ForceRTL(const AVehicleId: string);
var
  Idx: Integer;
begin
  Idx := StrToIntDef(Copy(AVehicleId, 2, Length(AVehicleId) - 1), 1) - 1;
  if (Idx >= 0) and (Idx < 40) then
  begin
    FLock.Enter;
    try
      FCommands[Idx] := cmdRTL;
    finally
      FLock.Leave;
    end;
  end;
end;

procedure TSimulatorThread.ForceLand(const AVehicleId: string);
var
  Idx: Integer;
begin
  Idx := StrToIntDef(Copy(AVehicleId, 2, Length(AVehicleId) - 1), 1) - 1;
  if (Idx >= 0) and (Idx < 40) then
  begin
    FLock.Enter;
    try
      FCommands[Idx] := cmdLand;
    finally
      FLock.Leave;
    end;
  end;
end;

procedure TSimulatorThread.InitializeVehicles;
var
  I: Integer;
  V: TVehicle;
  Regions: TArray<string>;
begin
  Regions := TArray<string>.Create('North', 'South', 'East', 'West');
  SetLength(FFlightStates, 40);
  for I := 1 to 40 do
  begin
    V.Id := 'V' + FormatFloat('00', I);
    V.Name := 'Cargo Drone ' + V.Id;
    // Spread them a bit wider initially
    V.Latitude := -23.5505 + (Random - 0.5) * 0.18;
    V.Longitude := -46.6333 + (Random - 0.5) * 0.18;
    V.Battery := 100;
    V.Status := TVehicleStatus.Active;
    V.Region := Regions[I mod 4];
    FVehicles.Add(V);

    // Initial heading in radians and speed
    FFlightStates[I - 1].Heading := Random * 2 * Pi;
    FFlightStates[I - 1].Speed := 0.0004 + Random * 0.0008;
  end;
end;

procedure TSimulatorThread.UpdateVehicles;
var
  I: Integer;
  V: TVehicle;
  HubContext: IHubContext;
  VehicleJson: string;
  StatusStr: string;
  Cmd: TVehicleCommand;
  LatDiff, LngDiff, Dist: Double;
begin
  try
    HubContext := THubExtensions.GetHubContext;
  except
    on E: Exception do
    begin
      Writeln('❌ Simulator HubContext Error: ', E.Message);
      Exit;
    end;
  end;

  Writeln('⚙️ Simulator running: updating ', FVehicles.Count, ' vehicles...');

  for I := 0 to FVehicles.Count - 1 do
  begin
    V := FVehicles[I];

    FLock.Enter;
    try
      Cmd := FCommands[I];
    finally
      FLock.Leave;
    end;

    // Apply command logic overrides
    if Cmd = cmdRTL then
    begin
      LatDiff := -23.5505 - V.Latitude;
      LngDiff := -46.6333 - V.Longitude;
      Dist := Sqrt(LatDiff * LatDiff + LngDiff * LngDiff);

      if Dist < 0.005 then
      begin
        FLock.Enter;
        try
          FCommands[I] := cmdLand;
          Cmd := cmdLand;
        finally
          FLock.Leave;
        end;
      end
      else
      begin
        // Heading is calculated in radians towards center base coordinates
        FFlightStates[I].Heading := ArcTan2(LngDiff, LatDiff);
      end;
    end;

    if Cmd = cmdLand then
    begin
      FFlightStates[I].Speed := 0;
      if V.Battery > 0 then
        V.Battery := Max(0, V.Battery - 5);
      V.Status := TVehicleStatus.Stopped;
    end
    else
    begin
      // Normal battery decay
      if Random < 0.1 then
        V.Battery := V.Battery - 1;
      if V.Battery < 0 then
        V.Battery := 100;

      // Random status changes
      if Random < 0.02 then
        V.Status := TVehicleStatus.Warning
      else if Random < 0.005 then
        V.Status := TVehicleStatus.Stopped
      else if Random < 0.05 then
        V.Status := TVehicleStatus.Active;
    end;

    // Simulate coordinates update using heading and speed
    V.Latitude := V.Latitude + Cos(FFlightStates[I].Heading) * FFlightStates[I].Speed;
    V.Longitude := V.Longitude + Sin(FFlightStates[I].Heading) * FFlightStates[I].Speed;

    // Boundary checks & reflections (only relevant when not landing/stopped)
    if Cmd <> cmdLand then
    begin
      if (V.Latitude < -23.65) or (V.Latitude > -23.45) then
      begin
        FFlightStates[I].Heading := Pi - FFlightStates[I].Heading;
        if V.Latitude < -23.65 then V.Latitude := -23.65 else V.Latitude := -23.45;
      end;
      if (V.Longitude < -46.73) or (V.Longitude > -46.53) then
      begin
        FFlightStates[I].Heading := -FFlightStates[I].Heading;
        if V.Longitude < -46.73 then V.Longitude := -46.73 else V.Longitude := -46.53;
      end;

      // Occasional subtle drift
      if Random < 0.05 then
        FFlightStates[I].Heading := FFlightStates[I].Heading + (Random - 0.5) * 0.15;
    end;

    FVehicles[I] := V;

    case V.Status of
      TVehicleStatus.Active: StatusStr := 'Active';
      TVehicleStatus.Warning: StatusStr := 'Warning';
      TVehicleStatus.Stopped: StatusStr := 'Stopped';
    end;

    // Send single vehicle update to its specific region group
    VehicleJson := Format('{"id":"%s","name":"%s","latitude":%.6f,"longitude":%.6f,"battery":%d,"status":"%s","region":"%s"}', [
      V.Id, V.Name, V.Latitude, V.Longitude, V.Battery, StatusStr, V.Region
    ], FormatSettings.Invariant);

    HubContext.Clients.Group(V.Region).SendAsync('OnVehicleUpdate', VehicleJson);
    HubContext.Clients.Group('All').SendAsync('OnVehicleUpdate', VehicleJson);

    // Random alerts
    if (V.Status = TVehicleStatus.Warning) and (Random < 0.02) then
    begin
      HubContext.Clients.All.SendAsync('OnSystemAlert',
        Format('{"vehicleId":"%s","message":"Low battery warning or route deviation!","timestamp":"%s"}', [
          V.Id, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
        ])
      );
    end;
  end;
end;

procedure TSimulatorThread.Execute;
begin
  Writeln('🧵 Simulator thread: Execute started');
  try
    while not Terminated do
    begin
      if FActive then
        UpdateVehicles;
      Sleep(200); // Send updates 5 times a second
    end;
  except
    on E: Exception do
      Writeln('❌ Simulator Thread Error: ', E.ClassName, ': ', E.Message);
  end;
  Writeln('🧵 Simulator thread: Execute finished');
end;

end.
