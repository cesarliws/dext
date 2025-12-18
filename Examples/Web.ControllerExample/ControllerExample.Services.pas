unit ControllerExample.Services;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  Dext,
  Dext.Web; // ? All-in-one framework unit

type
  // Settings Class for IOptions<T>
  TMySettings = class
  private
    FMessage: string;
    FSecretKey: string;
    FMaxRetries: Integer;
  public
    property Message: string read FMessage write FMessage;
    property SecretKey: string read FSecretKey write FSecretKey;
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;
  end;

  // Dummy Health Check
  TDatabaseHealthCheck = class(TInterfacedObject, IHealthCheck)
  public
    function CheckHealth: THealthCheckResult;
  end;

  // Dummy Background Service
  TWorkerService = class(TBackgroundService)
  protected
    procedure Execute(Token: ICancellationToken); override;
  end;

implementation

{ TDatabaseHealthCheck }

function TDatabaseHealthCheck.CheckHealth: THealthCheckResult;
begin
  // Always healthy for testing
  Result := THealthCheckResult.Healthy('Database is reachable');
end;

{ TWorkerService }

procedure TWorkerService.Execute(Token: ICancellationToken);
begin
  WriteLn('?? WorkerService started.');
  
  while not Token.IsCancellationRequested do
  begin
    WriteLn(Format('?? WorkerService running at: %s', [DateTimeToStr(Now)]));
    
    try
      // Wait for 5 seconds or until cancelled
      if Token.WaitForCancellation(5000) = wrSignaled then
        Break;
    except
      Break;
    end;
  end;
  
  WriteLn('?? WorkerService stopping.');
end;

end.
