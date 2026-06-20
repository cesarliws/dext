unit AirFlow.Hubs;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Web.Hubs.Hub,
  AirFlow.Domain;

type
  TAirFlowHub = class(THub)
  public
    procedure JoinRegion(const ARegionName: string);
    procedure LeaveRegion(const ARegionName: string);
    procedure BroadcastAlert(const AVehicleId, AMessage: string);
  end;

implementation

{ TAirFlowHub }

procedure TAirFlowHub.JoinRegion(const ARegionName: string);
begin
  Groups.AddToGroupAsync(Context.ConnectionId, ARegionName);
  Clients.Caller.SendAsync('OnRegionJoined', ARegionName);
end;

procedure TAirFlowHub.LeaveRegion(const ARegionName: string);
begin
  Groups.RemoveFromGroupAsync(Context.ConnectionId, ARegionName);
  Clients.Caller.SendAsync('OnRegionLeft', ARegionName);
end;

procedure TAirFlowHub.BroadcastAlert(const AVehicleId, AMessage: string);
var
  AlertJson: string;
begin
  AlertJson := Format('{"vehicleId":"%s","message":"%s","timestamp":"%s"}', [
    AVehicleId, AMessage, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
  ]);
  Clients.All.SendAsync('OnSystemAlert', AlertJson);
end;

end.
