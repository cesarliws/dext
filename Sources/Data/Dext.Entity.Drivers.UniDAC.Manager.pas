{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Dext Contributors                                               }
{  Created: 2026-07-24                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Drivers.UniDAC.Manager;

interface

{$I Dext.inc}

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Uni;   // TUniConnection (UniDAC core unit)

type
  /// <summary>
  ///   Optimization hints that can be applied to UniDAC connections.
  ///   Many FireDAC-specific flags (MacroCreate, EscapeExpand, DirectExecute)
  ///   have no direct UniDAC equivalent and are silently ignored.
  /// </summary>
  TUniDACOptimization = (
    uoptUseUnicode,         // Force Unicode string mode (important for SQLite)
    uoptDisableAutoCommit   // Disable auto-commit (useful for batch operations)
  );
  TUniDACOptimizations = set of TUniDACOptimization;

  /// <summary>
  ///   Manages UniDAC connection creation and pooling configuration.
  ///   Unlike the FireDAC equivalent (TDextFireDACManager), UniDAC does not
  ///   require a global manager component: pooling is configured directly on
  ///   each TUniConnection via Pooling=True and PoolingOptions.MaxPoolSize.
  ///   This class is therefore a lightweight factory/configurator singleton.
  /// </summary>
  TDextUniDACManager = class
  private
    class var FInstance: TDextUniDACManager;
    class var FCriticalSection: TCriticalSection;
    constructor Create;
  public
    class constructor Create;
    class destructor Destroy;
    destructor Destroy; override;

    /// <summary>
    ///   Access the singleton instance.
    /// </summary>
    class function Instance: TDextUniDACManager;

    /// <summary>
    ///   Global cleanup — releases singleton.
    /// </summary>
    class procedure Finalize;

    /// <summary>
    ///   Creates a TUniConnection configured with connection pooling.
    ///   The caller is responsible for freeing the connection (or wrapping
    ///   it in TUniDACConnection with AOwnsConnection=True).
    ///   ProviderName must be the UniDAC provider string (e.g., 'SQLite',
    ///   'PostgreSQL', 'MySQL', 'SQL Server', 'Oracle', 'Interbase').
    /// </summary>
    function CreatePooledConnection(const AProviderName: string;
      const AParams: TStrings; APoolMax: Integer = 50): TUniConnection;

    /// <summary>
    ///   Applies UniDAC-specific optimizations to a connection.
    ///   Called after creation, before Connect.
    /// </summary>
    procedure ApplyOptions(AConnection: TUniConnection;
      const AOptimizations: TUniDACOptimizations);

    /// <summary>
    ///   Maps a Dext/FireDAC driver name to a UniDAC ProviderName string.
    ///   FireDAC names: SQLite, PG, MySQL, MSSQL, Oracle, FB, IB, DB2, ODBC
    ///   UniDAC names:  SQLite, PostgreSQL, MySQL, SQL Server, Oracle, Interbase, ...
    /// </summary>
    class function MapDriverToProvider(const ADriverName: string): string;
  end;

implementation

{ TDextUniDACManager }

class constructor TDextUniDACManager.Create;
begin
  FCriticalSection := TCriticalSection.Create;
end;

class destructor TDextUniDACManager.Destroy;
begin
  Finalize;
  FCriticalSection.Free;
end;

constructor TDextUniDACManager.Create;
begin
  inherited Create;
end;

destructor TDextUniDACManager.Destroy;
begin
  inherited;
end;

class procedure TDextUniDACManager.Finalize;
begin
  FCriticalSection.Enter;
  try
    FreeAndNil(FInstance);
  finally
    FCriticalSection.Leave;
  end;
end;

class function TDextUniDACManager.Instance: TDextUniDACManager;
begin
  if FInstance = nil then
  begin
    FCriticalSection.Enter;
    try
      if FInstance = nil then
        FInstance := TDextUniDACManager.Create;
    finally
      FCriticalSection.Leave;
    end;
  end;
  Result := FInstance;
end;

class function TDextUniDACManager.MapDriverToProvider(const ADriverName: string): string;
var
  Lower: string;
begin
  Lower := LowerCase(ADriverName);
  // FireDAC DriverID → UniDAC ProviderName
  if (Lower = 'sqlite') or (Lower = 'lite')                then Result := 'SQLite'
  else if (Lower = 'pg') or (Lower = 'postgresql')         then Result := 'PostgreSQL'
  else if (Lower = 'mysql')                                  then Result := 'MySQL'
  else if (Lower = 'mssql') or (Lower = 'sql server')      then Result := 'SQL Server'
  else if (Lower = 'oracle') or (Lower = 'ora')            then Result := 'Oracle'
  else if (Lower = 'fb') or (Lower = 'firebird')           then Result := 'Interbase'
  else if (Lower = 'ib') or (Lower = 'interbase')          then Result := 'Interbase'
  else if (Lower = 'db2')                                    then Result := 'DB2'
  else if (Lower = 'odbc')                                   then Result := 'ODBC'
  else
    Result := ADriverName; // pass through as-is and let UniDAC raise its own error
end;

function TDextUniDACManager.CreatePooledConnection(const AProviderName: string;
  const AParams: TStrings; APoolMax: Integer): TUniConnection;
var
  i: Integer;
begin
  Result := TUniConnection.Create(nil);
  try
    Result.ProviderName := AProviderName;

    // Copy all key=value params
    if AParams <> nil then
      for i := 0 to AParams.Count - 1 do
        Result.SpecificOptions.Values[AParams.Names[i]] := AParams.ValueFromIndex[i];

    // Enable UniDAC built-in connection pooling
    Result.Pooling := True;
    Result.PoolingOptions.MaxPoolSize := APoolMax;
    Result.PoolingOptions.MinPoolSize := 1;
    Result.PoolingOptions.ConnectionLifetime := 0; // 0 = unlimited
    Result.PoolingOptions.Validate := True;        // validate before reuse
  except
    Result.Free;
    raise;
  end;
end;

procedure TDextUniDACManager.ApplyOptions(AConnection: TUniConnection;
  const AOptimizations: TUniDACOptimizations);
var
  LProvider: string;
begin
  LProvider := LowerCase(AConnection.ProviderName);

  // Unicode mode — especially important for SQLite
  if (uoptUseUnicode in AOptimizations) or (LProvider = 'sqlite') then
    AConnection.SpecificOptions.Values['UseUnicode'] := 'True';

  // Auto-commit control
  if uoptDisableAutoCommit in AOptimizations then
    AConnection.AutoCommit := False;
end;

end.

