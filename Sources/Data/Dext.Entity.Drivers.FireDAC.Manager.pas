unit Dext.Entity.Drivers.FireDAC.Manager;

interface

{$I Dext.inc}

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
  FireDAC.DApt,
  FireDAC.Comp.UI,
  FireDAC.ConsoleUI.Wait
  {$IFDEF DEXT_ENABLE_DB_POSTGRES}, FireDAC.Phys.PG {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_SQLITE}, FireDAC.Phys.SQLite {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_MYSQL}, FireDAC.Phys.MySQL {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_MSSQL}, FireDAC.Phys.MSSQL {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_ORACLE}, FireDAC.Phys.Oracle {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_FIREBIRD}, FireDAC.Phys.FB {$ENDIF}
  {$IFDEF DEXT_ENABLE_DB_ODBC}, FireDAC.Phys.ODBC {$ENDIF};

type
  TComponentHelper = class helper for TComponent
  public
    procedure SetUniqueName;
  end;

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

    /// <summary>
    ///   Global finalization to drop all connections and close manager.
    /// </summary>
    class procedure Finalize;

    /// <summary>
    ///   Apply common resource options for specific databases (e.g. PostgreSQL)
    /// </summary>
    procedure ApplyResourceOptions(AConnection: TFDConnection);
  end;

implementation

{ TComponentHelper }

procedure TComponentHelper.SetUniqueName;
begin
  if Self.Name = '' then
    Self.Name := Self.ClassName + '_' + IntToHex(IntPtr(Self), 16);
end;

{ TDextFireDACManager }

class constructor TDextFireDACManager.Create;
begin
  FCriticalSection := TCriticalSection.Create;
end;

class destructor TDextFireDACManager.Destroy;
begin
  Finalize;
  FCriticalSection.Free;
end;

class procedure TDextFireDACManager.Finalize;
begin
  if FInstance <> nil then
  begin
    if FInstance.FManager <> nil then
    begin
      FInstance.FManager.Close;
    end;
    FreeAndNil(FInstance);
  end;
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
begin
  // Create a unique key based on params to avoid duplicating pools for same config
  // Use a canonical representation of params
  AParams.Delimiter := ';';
  HashKey := ADriverName + ';' + AParams.DelimitedText;
  
  FCriticalSection.Enter;
  try
    // Return existing definition if matches
    if FDefinitions.TryGetValue(HashKey, DefName) then
    begin
      if FManager.IsConnectionDef(DefName) then
        Exit(DefName);
    end;
      
    // Create new Definition name
    DefName := 'DextPool_' + IntToHex(HashKey.GetHashCode, 8);
    
    // Register in FireDAC using the robust AddConnectionDef method
    if not FManager.IsConnectionDef(DefName) then
    begin
      FManager.AddConnectionDef(DefName, ADriverName, AParams);
      
      // Configure pooling params explicitly if they weren't in AParams
      var Def := FManager.ConnectionDefs.FindConnectionDef(DefName);
      if Def <> nil then
      begin
        Def.Params.Pooled := True;
        Def.Params.PoolMaximumItems := APoolMax;
        Def.Params.PoolCleanupTimeout := 30000; // 30s
        Def.Params.PoolExpireTimeout := 60000; // 60s
        
        // Ensure wait cursor is set to none for server apps
        Def.Params.MonitorBy := mbNone;
      end;
    end;
    
    // FireDAC pooling initialization
    EnsureActive;
    
    if not FDefinitions.ContainsKey(HashKey) then
      FDefinitions.Add(HashKey, DefName);
      
    Result := DefName;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TDextFireDACManager.ApplyResourceOptions(AConnection: TFDConnection);
begin
  var DriverID := AConnection.DriverName.ToLower;
  
  // PostgreSQL performance optimizations from Foundation
  if DriverID.Contains('pg') or DriverID.Contains('postgres') then
  begin
    AConnection.ResourceOptions.MacroCreate := False;
    AConnection.ResourceOptions.MacroExpand := False;
    AConnection.ResourceOptions.EscapeExpand := False;
    AConnection.ResourceOptions.DirectExecute := True;
  end;
end;

function TDextFireDACManager.RegisterConnectionDefFromString(const ADefName,
  AConfig: string): string;
var
  SL: TStringList;
  DriverID: string;
begin
  FCriticalSection.Enter;
  try
    SL := TStringList.Create;
    try
      SL.Text := AConfig;
      DriverID := SL.Values['DriverID'];
      
      if not FManager.IsConnectionDef(ADefName) then
      begin
        FManager.AddConnectionDef(ADefName, DriverID, SL);
      end;
      
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
