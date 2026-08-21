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
unit Dext.Configuration.CommandLine;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core;

type
  /// <summary>
  ///   Configuration provider that reads and parses command-line arguments.
  /// </summary>
  TCommandLineConfigurationProvider = class(TConfigurationProvider)
  private
    FArgs: TArray<string>;
    FSwitchMappings: IDictionary<string, string>;
    procedure ParseArgs;
    function NormalizeKey(const Key: string): string;
  public
    /// <summary>
    ///   Initializes a new instance of TCommandLineConfigurationProvider.
    /// </summary>
    /// <param name="Args">Custom array of command-line arguments. If empty or nil, ParamStr(1..ParamCount) is used.</param>
    /// <param name="SwitchMappings">Optional dictionary mapping short switch aliases (e.g., "-p") to full configuration keys ("Server:Port").</param>
    constructor Create(const Args: TArray<string> = nil; const SwitchMappings: IDictionary<string, string> = nil);
    destructor Destroy; override;

    /// <summary>
    ///   Loads and parses command-line arguments into configuration key-value pairs.
    /// </summary>
    procedure Load; override;
  end;

  /// <summary>
  ///   Configuration source for command-line arguments.
  /// </summary>
  TCommandLineConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FArgs: TArray<string>;
    FSwitchMappings: IDictionary<string, string>;
  public
    /// <summary>
    ///   Initializes a new instance of TCommandLineConfigurationSource.
    /// </summary>
    /// <param name="Args">Custom array of command-line arguments. If empty or nil, ParamStr(1..ParamCount) is used.</param>
    /// <param name="SwitchMappings">Optional dictionary mapping short switch aliases to full configuration keys.</param>
    constructor Create(const Args: TArray<string> = nil; const SwitchMappings: IDictionary<string, string> = nil);
    destructor Destroy; override;

    /// <summary>
    ///   Builds and returns the IConfigurationProvider instance.
    /// </summary>
    function Build(Builder: IConfigurationBuilder): IConfigurationProvider;
  end;

  /// <summary>
  ///   Extensions for TDextConfiguration to support command-line arguments.
  /// </summary>
  TDextConfigurationCommandLineExtensions = record helper for TDextConfiguration
  public
    /// <summary>
    ///   Adds command-line arguments configuration source to the configuration builder.
    /// </summary>
    /// <param name="Args">Custom array of command-line arguments. If nil, ParamStr(1..ParamCount) is used.</param>
    /// <param name="SwitchMappings">Optional dictionary mapping switch aliases to configuration keys.</param>
    function AddCommandLine(const Args: TArray<string> = nil;
      const SwitchMappings: IDictionary<string, string> = nil): TDextConfiguration;
  end;

implementation

{ TCommandLineConfigurationSource }

constructor TCommandLineConfigurationSource.Create(const Args: TArray<string>;
  const SwitchMappings: IDictionary<string, string>);
begin
  inherited Create;
  FArgs := Copy(Args);
  FSwitchMappings := SwitchMappings;
end;

destructor TCommandLineConfigurationSource.Destroy;
begin
  FArgs := nil;
  FSwitchMappings := nil;
  inherited;
end;

function TCommandLineConfigurationSource.Build(Builder: IConfigurationBuilder): IConfigurationProvider;
begin
  Result := TCommandLineConfigurationProvider.Create(FArgs, FSwitchMappings);
end;

{ TCommandLineConfigurationProvider }

constructor TCommandLineConfigurationProvider.Create(const Args: TArray<string>;
  const SwitchMappings: IDictionary<string, string>);
var
  i: Integer;
begin
  inherited Create;
  if Length(Args) > 0 then
    FArgs := Copy(Args)
  else
  begin
    SetLength(FArgs, ParamCount);
    for i := 1 to ParamCount do
      FArgs[i - 1] := ParamStr(i);
  end;

  FSwitchMappings := SwitchMappings;
end;

destructor TCommandLineConfigurationProvider.Destroy;
begin
  FArgs := nil;
  FSwitchMappings := nil;
  inherited;
end;

function TCommandLineConfigurationProvider.NormalizeKey(const Key: string): string;
var
  MappedKey: string;
begin
  if (FSwitchMappings <> nil) and FSwitchMappings.TryGetValue(Key, MappedKey) then
    Result := MappedKey
  else
    Result := Key;

  // Convert double underscore to colon (e.g. Database__Password -> Database:Password)
  Result := StringReplace(Result, '__', TConfigurationPath.KeyDelimiter, [rfReplaceAll]);
end;

procedure TCommandLineConfigurationProvider.ParseArgs;
var
  i: Integer;
  CurrentArg: string;
  NextArg: string;
  EqIndex: Integer;
  RawKey: string;
  Key: string;
  Value: string;
  IsSwitch: Boolean;
begin
  i := 0;
  while i < Length(FArgs) do
  begin
    CurrentArg := FArgs[i].Trim;
    if CurrentArg = '' then
    begin
      Inc(i);
      Continue;
    end;

    IsSwitch := False;
    RawKey := '';
    Value := '';

    if CurrentArg.StartsWith('--') then
    begin
      IsSwitch := True;
      RawKey := Copy(CurrentArg, 3, MaxInt);
    end
    else if CurrentArg.StartsWith('/') then
    begin
      IsSwitch := True;
      RawKey := Copy(CurrentArg, 2, MaxInt);
    end
    else if CurrentArg.StartsWith('-') then
    begin
      IsSwitch := True;
      RawKey := Copy(CurrentArg, 2, MaxInt);
    end;

    if IsSwitch then
    begin
      EqIndex := Pos('=', RawKey);
      if EqIndex > 0 then
      begin
        // Format: --Key=Value or /Key=Value or -Key=Value
        Value := Copy(RawKey, EqIndex + 1, MaxInt);
        RawKey := Copy(RawKey, 1, EqIndex - 1);
        Key := NormalizeKey(RawKey);
        Set_(Key, Value);
      end
      else
      begin
        // Check if next token is a value or another switch
        if (i + 1 < Length(FArgs)) and
           (not FArgs[i + 1].StartsWith('-')) and
           (not FArgs[i + 1].StartsWith('/')) then
        begin
          // Format: --Key Value or /Key Value or -Key Value
          NextArg := FArgs[i + 1];
          Key := NormalizeKey(RawKey);
          Set_(Key, NextArg);
          Inc(i); // Consume value argument
        end
        else
        begin
          // Standalone switch/flag, treat as true
          Key := NormalizeKey(RawKey);
          Set_(Key, 'true');
        end;
      end;
    end;

    Inc(i);
  end;
end;

procedure TCommandLineConfigurationProvider.Load;
begin
  ClearData;
  ParseArgs;
end;

{ TDextConfigurationCommandLineExtensions }

function TDextConfigurationCommandLineExtensions.AddCommandLine(const Args: TArray<string>;
  const SwitchMappings: IDictionary<string, string>): TDextConfiguration;
begin
  Result := Add(TCommandLineConfigurationSource.Create(Args, SwitchMappings));
end;

end.
