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
{  Author:  Cesar Romero                                                    }
{  Created: 2026-08-21                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Configuration.UserSecrets;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.Configuration.Json;

type
  /// <summary>
  ///   Configuration provider that reads application secrets stored outside the source tree.
  /// </summary>
  TUserSecretsConfigurationProvider = class(TJsonConfigurationProvider)
  private
    FUserSecretsId: string;
  public
    /// <summary>
    ///   Initializes a new instance of TUserSecretsConfigurationProvider.
    /// </summary>
    /// <param name="UserSecretsId">Unique project identifier for secrets.</param>
    /// <param name="Optional">Whether the secrets file is optional.</param>
    /// <param name="ReloadOnChange">Whether to reload configuration when the secrets file changes.</param>
    constructor Create(const UserSecretsId: string; Optional: Boolean = True;
      ReloadOnChange: Boolean = False);

    /// <summary>
    ///   Gets the UserSecretsId associated with this provider.
    /// </summary>
    property UserSecretsId: string read FUserSecretsId;

    /// <summary>
    ///   Resolves the cross-platform path to the secrets.json file for the given UserSecretsId.
    /// </summary>
    class function ResolveSecretsFilePath(const UserSecretsId: string): string; static;
  end;

  /// <summary>
  ///   Configuration source for user secrets.
  /// </summary>
  TUserSecretsConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FUserSecretsId: string;
    FOptional: Boolean;
    FReloadOnChange: Boolean;
  public
    /// <summary>
    ///   Initializes a new instance of TUserSecretsConfigurationSource.
    /// </summary>
    /// <param name="UserSecretsId">Unique project identifier for secrets.</param>
    /// <param name="Optional">Whether the secrets file is optional.</param>
    /// <param name="ReloadOnChange">Whether to reload configuration when the secrets file changes.</param>
    constructor Create(const UserSecretsId: string; Optional: Boolean = True;
      ReloadOnChange: Boolean = False);

    /// <summary>
    ///   Builds and returns the IConfigurationProvider instance.
    /// </summary>
    function Build(Builder: IConfigurationBuilder): IConfigurationProvider;
  end;

  /// <summary>
  ///   Extensions for TDextConfiguration to support User Secrets.
  /// </summary>
  TDextConfigurationUserSecretsExtensions = record helper for TDextConfiguration
  public
    /// <summary>
    ///   Adds a user secrets configuration source to the configuration builder.
    /// </summary>
    /// <param name="UserSecretsId">Unique project identifier for secrets.</param>
    /// <param name="Optional">Whether the secrets file is optional.</param>
    /// <param name="ReloadOnChange">Whether to reload configuration when the secrets file changes.</param>
    function AddUserSecrets(const UserSecretsId: string; Optional: Boolean = True;
      ReloadOnChange: Boolean = False): TDextConfiguration;
  end;

implementation

{ TUserSecretsConfigurationProvider }

class function TUserSecretsConfigurationProvider.ResolveSecretsFilePath(const UserSecretsId: string): string;
var
  BasePath: string;
begin
  if UserSecretsId = '' then
    Exit('');

  {$IFDEF MSWINDOWS}
  BasePath := GetEnvironmentVariable('APPDATA');
  if BasePath = '' then
    BasePath := TPath.Combine(TPath.GetHomePath, 'AppData\Roaming');
  Result := TPath.Combine(BasePath, TPath.Combine('Dext\UserSecrets', TPath.Combine(UserSecretsId, 'secrets.json')));
  {$ELSE}
  BasePath := GetEnvironmentVariable('HOME');
  if BasePath = '' then
    BasePath := TPath.GetHomePath;
  Result := TPath.Combine(BasePath, TPath.Combine('.dext/usersecrets', TPath.Combine(UserSecretsId, 'secrets.json')));
  {$ENDIF}
end;

constructor TUserSecretsConfigurationProvider.Create(const UserSecretsId: string;
  Optional: Boolean; ReloadOnChange: Boolean);
var
  SecretsFile: string;
begin
  FUserSecretsId := UserSecretsId;
  SecretsFile := ResolveSecretsFilePath(UserSecretsId);
  inherited Create(SecretsFile, Optional, ReloadOnChange);
end;

{ TUserSecretsConfigurationSource }

constructor TUserSecretsConfigurationSource.Create(const UserSecretsId: string;
  Optional: Boolean; ReloadOnChange: Boolean);
begin
  inherited Create;
  FUserSecretsId := UserSecretsId;
  FOptional := Optional;
  FReloadOnChange := ReloadOnChange;
end;

function TUserSecretsConfigurationSource.Build(Builder: IConfigurationBuilder): IConfigurationProvider;
begin
  Result := TUserSecretsConfigurationProvider.Create(FUserSecretsId, FOptional, FReloadOnChange);
end;

{ TDextConfigurationUserSecretsExtensions }

function TDextConfigurationUserSecretsExtensions.AddUserSecrets(const UserSecretsId: string;
  Optional: Boolean; ReloadOnChange: Boolean): TDextConfiguration;
begin
  Result := Add(TUserSecretsConfigurationSource.Create(UserSecretsId, Optional, ReloadOnChange));
end;

end.
