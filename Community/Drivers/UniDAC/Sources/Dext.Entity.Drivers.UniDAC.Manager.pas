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
  /// </summary>
  TUniDACOptimization = (
    uoptUseUnicode,         // Force Unicode string mode (important for SQLite)
    uoptDisableAutoCommit   // Disable auto-commit (useful for batch operations)
  );
  TUniDACOptimizations = set of TUniDACOptimization;

  /// <summary>
  ///   Manages UniDAC connection creation and pooling configuration.
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
    /// </summary>
    function CreatePooledConnection(const AProviderName: string;
      const AParams: TStrings; APoolMax: Integer = 50): TUniConnection;

    /// <summary>
    ///   Applies UniDAC-specific optimizations to a connection.
    /// </summary>
    procedure ApplyOptions(AConnection: TUniConnection;
      const AOptimizations: TUniDACOptimizations);

    /// <summary>
    ///   Maps a Dext/FireDAC driver name to a UniDAC ProviderName string.
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

function TDextUniDACManager.CreatePooledConnection(const AProviderName: string;
  const AParams: TStrings; APoolMax: Integer): TUniConnection;
var
  i: Integer;
  Key, Val: string;
begin
  Result := TUniConnection.Create(nil);
  try
    Result.ProviderName := AProviderName;

    if AParams <> nil then
    begin
      for i := 0 to AParams.Count - 1 do
      begin
        Key := AParams.Names[i];
        Val := AParams.ValueFromIndex[i];
        if Key <> '' then
        begin
          if SameText(Key, 'Database') then
            Result.Database := Val
          else if SameText(Key, 'Server') or SameText(Key, 'Host') or SameText(Key, 'HostName') then
            Result.Server := Val
          else if SameText(Key, 'Port') then
            Result.Port := StrToIntDef(Val, 0)
          else if SameText(Key, 'User_Name') or SameText(Key, 'Username') or SameText(Key, 'User ID') or SameText(Key, 'User') then
            Result.Username := Val
          else if SameText(Key, 'Password') then
            Result.Password := Val
          else
            Result.SpecificOptions.Values[Key] := Val;
        end;
      end;
    end;

    if APoolMax > 0 then
    begin
      Result.SpecificOptions.Values['Pooling'] := 'True';
      Result.SpecificOptions.Values['MaxPoolSize'] := IntToStr(APoolMax);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TDextUniDACManager.ApplyOptions(AConnection: TUniConnection;
  const AOptimizations: TUniDACOptimizations);
begin
  if AConnection = nil then Exit;

  if uoptUseUnicode in AOptimizations then
    AConnection.SpecificOptions.Values['UseUnicode'] := 'True';

  if uoptDisableAutoCommit in AOptimizations then
    AConnection.SpecificOptions.Values['AutoCommit'] := 'False';
end;

class function TDextUniDACManager.MapDriverToProvider(const ADriverName: string): string;
var
  Upper: string;
begin
  Upper := UpperCase(Trim(ADriverName));
  if (Upper = 'SQLITE') then
    Result := 'SQLite'
  else if (Upper = 'PG') or (Upper = 'POSTGRES') or (Upper = 'POSTGRESQL') then
    Result := 'PostgreSQL'
  else if (Upper = 'MYSQL') or (Upper = 'MARIADB') then
    Result := 'MySQL'
  else if (Upper = 'MSSQL') or (Upper = 'SQLSERVER') then
    Result := 'SQL Server'
  else if (Upper = 'ORACLE') or (Upper = 'ORA') then
    Result := 'Oracle'
  else if (Upper = 'FB') or (Upper = 'FIREBIRD') or (Upper = 'IB') or (Upper = 'INTERBASE') then
    Result := 'InterBase'
  else if (Upper = 'DB2') then
    Result := 'DB2'
  else if (Upper = 'ODBC') then
    Result := 'ODBC'
  else
    Result := ADriverName;
end;

end.
