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
  public
    class constructor Create;
    class destructor Destroy;
    destructor Destroy; override;
    
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
    ///   Registers a connection definition from an INI-style string (key=value lines).
    /// </summary>
    function RegisterConnectionDefFromString(const ADefName, AConfig: string): string;
      
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
  FManager := TFDManager(FireDAC.Comp.Client.FDManager);
  FDefinitions := TDictionary<string, string>.Create;
end;

destructor TDextFireDACManager.Destroy;
begin
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
  // Create a unique key based on params to avoid duplicating pools for same config
  HashKey := ADriverName + ';' + AParams.Text;
  
  FCriticalSection.Enter;
  try
    // Return existing definition if matches
    if FDefinitions.TryGetValue(HashKey, DefName) then
    begin
      // Ensure the manager still has it (might have been cleared)
      if FManager.ConnectionDefs.FindConnectionDef(DefName) <> nil then
        Exit(DefName);
    end;
      
    // Create new Definition
    DefName := 'DextPool_' + IntToHex(HashKey.GetHashCode, 8);
    
    // Check if it already exists in the global manager (manual check)
    Def := FManager.ConnectionDefs.FindConnectionDef(DefName);
    if Def = nil then
    begin
      Def := FManager.ConnectionDefs.AddConnectionDef;
      Def.Name := DefName;
    end;

    Def.Params.Clear;
    Def.Params.Assign(AParams);
    
    // Explicit Pooling Configuration
    Def.Params.DriverID := ADriverName;
    Def.Params.Pooled := True;
    Def.Params.PoolMaximumItems := APoolMax;
    Def.Params.PoolCleanupTimeout := 30000; // 30s
    Def.Params.PoolExpireTimeout := 60000; // 60s
    
    Def.Apply; // Register in FireDAC
    
    // FireDAC pooling initialization requires the manager to be opened
    EnsureActive;
    
    if not FDefinitions.ContainsKey(HashKey) then
      FDefinitions.Add(HashKey, DefName);
      
    Result := DefName;
  finally
    FCriticalSection.Leave;
  end;
end;

function TDextFireDACManager.RegisterConnectionDefFromString(const ADefName,
  AConfig: string): string;
var
  SL: TStringList;
  Def: IFDStanConnectionDef;
begin
  FCriticalSection.Enter;
  try
    SL := TStringList.Create;
    try
      SL.Text := AConfig;
      
      Def := FManager.ConnectionDefs.FindConnectionDef(ADefName);
      if Def = nil then
      begin
        Def := FManager.ConnectionDefs.AddConnectionDef;
        Def.Name := ADefName;
      end;
      
      Def.Params.Clear;
      Def.Params.AddStrings(SL);
      Def.Apply;
      
      EnsureActive;
      Result := ADefName;
    finally
      SL.Free;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

end.
