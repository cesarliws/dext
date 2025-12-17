unit Dext.Entity.Drivers.FireDAC.Manager;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Comp.Client,
  FireDAC.DApt;

type
  /// <summary>
  ///   Manages FireDAC Connection Definitions and Pooling globally
  ///   without requiring external INI files.
  /// </summary>
  TDextFireDACManager = class
  private
    class var FInstance: TDextFireDACManager;
    class var FCriticalSection: TCriticalSection;
    
    FManager: TFDManager;
    FDefinitions: TDictionary<string, string>; // Hash -> DefName

    constructor Create;
    destructor Destroy; override;
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>
    ///   Access the singleton instance.
    /// </summary>
    class function Instance: TDextFireDACManager;

    /// <summary>
    ///   Registers a connection definition with pooling enabled.
    ///   Returns the Definition Name to be used in TFDConnection.
    /// </summary>
    function RegisterConnectionDef(const ADriverName: string; 
      const AParams: TStrings; 
      APoolMax: Integer = 50): string;
      
    /// <summary>
    ///   Ensures the FDManager is active.
    /// </summary>
    procedure EnsureActive;
  end;

implementation

{ TDextFireDACManager }

class constructor TDextFireDACManager.Create;
begin
  FCriticalSection := TCriticalSection.Create;
end;

class destructor TDextFireDACManager.Destroy;
begin
  FInstance.Free;
  FCriticalSection.Free;
end;

constructor TDextFireDACManager.Create;
begin
  FManager := TFDManager.Create(nil);
  FManager.ConnectionDefFileAutoLoad := False; // Disable INI loading
  FManager.SilentMode := True;
  FDefinitions := TDictionary<string, string>.Create;
end;

destructor TDextFireDACManager.Destroy;
begin
  FManager.Close; // Close all connections in pool
  FManager.Free;
  FDefinitions.Free;
  inherited;
end;

procedure TDextFireDACManager.EnsureActive;
begin
  if not FManager.Active then
    FManager.Open;
end;

class function TDextFireDACManager.Instance: TDextFireDACManager;
begin
  if FInstance = nil then
  begin
    FCriticalSection.Enter;
    try
      if FInstance = nil then
        FInstance := TDextFireDACManager.Create;
    finally
      FCriticalSection.Leave;
    end;
  end;
  Result := FInstance;
end;

function TDextFireDACManager.RegisterConnectionDef(const ADriverName: string;
  const AParams: TStrings; APoolMax: Integer): string;
var
  HashKey: string;
  DefName: string;
  Def: IFDStanConnectionDef;
begin
  EnsureActive;

  // Create a unique key based on params to avoid duplicating pools for same config
  HashKey := ADriverName + ';' + AParams.Text;
  
  FCriticalSection.Enter;
  try
    // Return existing definition if matches
    if FDefinitions.TryGetValue(HashKey, DefName) then
      Exit(DefName);
      
    // Create new Definition
    DefName := 'DextPool_' + IntToHex(AParams.Text.GetHashCode, 8) + '_' + GetTickCount.ToString;
    
    Def := FManager.ConnectionDefs.AddConnectionDef;
    Def.Name := DefName;
    Def.Params.Assign(AParams);
    
    // Explicit Pooling Configuration
    Def.Params.DriverID := ADriverName;
    Def.Params.Pooled := True;
    Def.Params.PoolMaximumItems := APoolMax;
    Def.Params.PoolCleanupTimeout := 30000; // 30s
    Def.Params.PoolExpireTimeout := 60000; // 60s
    
    Def.Apply; // Register in FireDAC
    
    FDefinitions.Add(HashKey, DefName);
    Result := DefName;
  finally
    FCriticalSection.Leave;
  end;
end;

end.
