unit AirFlow.Domain;

interface

uses
  System.SysUtils;

type
  TVehicleStatus = (Active, Warning, Stopped);

  TVehicle = record
    Id: string;
    Name: string;
    Latitude: Double;
    Longitude: Double;
    Battery: Integer;
    Status: TVehicleStatus;
    Region: string;
  end;

  TTelemetryUpdate = record
    VehicleId: string;
    Latitude: Double;
    Longitude: Double;
    Battery: Integer;
  end;

  TSystemAlert = record
    VehicleId: string;
    Message: string;
    Timestamp: string;
  end;

implementation

end.
