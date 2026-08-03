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
unit Dext.Entity.UniDAC.Setup;

/// <summary>
///   Standalone setup helper to instantiate UniDAC connection drivers
///   without modifying core Dext framework units.
/// </summary>

interface

uses
  System.SysUtils,
  Dext.Entity.Setup,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Drivers.UniDAC,
  Dext.Entity.Drivers.UniDAC.Manager;

type
  TDextUniDACSetup = class
  public
    /// <summary>
    ///   Builds an IDbConnection instance powered by UniDAC using the given options.
    /// </summary>
    class function BuildConnection(AOptions: TDbContextOptions): IDbConnection;
  end;

implementation

class function TDextUniDACSetup.BuildConnection(AOptions: TDbContextOptions): IDbConnection;
var
  ProviderName: string;
  UniConn: TUniConnection;
begin
  ProviderName := TDextUniDACManager.MapDriverToProvider(AOptions.DriverName);
  UniConn := TDextUniDACManager.Instance.CreatePooledConnection(
    ProviderName,
    AOptions.Params,
    AOptions.MaxPoolSize
  );

  TDextUniDACManager.Instance.ApplyOptions(UniConn, []);
  Result := TDextUniDACConnection.Create(UniConn, True);
end;

end.
