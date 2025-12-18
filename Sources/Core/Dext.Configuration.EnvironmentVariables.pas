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
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Configuration.EnvironmentVariables;

interface

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core;

type
  TEnvironmentVariablesConfigurationProvider = class(TConfigurationProvider)
  private
    FPrefix: string;
  public
    constructor Create(const Prefix: string = '');
    procedure Load; override;
  end;

  TEnvironmentVariablesConfigurationSource = class(TInterfacedObject, IConfigurationSource)
  private
    FPrefix: string;
  public
    constructor Create(const Prefix: string = '');
    function Build(Builder: IConfigurationBuilder): IConfigurationProvider;
  end;

implementation

{ TEnvironmentVariablesConfigurationSource }

constructor TEnvironmentVariablesConfigurationSource.Create(const Prefix: string);
begin
  inherited Create;
  FPrefix := Prefix;
end;

function TEnvironmentVariablesConfigurationSource.Build(Builder: IConfigurationBuilder): IConfigurationProvider;
begin
  Result := TEnvironmentVariablesConfigurationProvider.Create(FPrefix);
end;

{ TEnvironmentVariablesConfigurationProvider }

constructor TEnvironmentVariablesConfigurationProvider.Create(const Prefix: string);
begin
  inherited Create;
  FPrefix := Prefix;
end;

procedure TEnvironmentVariablesConfigurationProvider.Load;
var
  Vars: TStringList;
  I: Integer;
  Key, Value: string;
  EqIndex: Integer;
  EnvKey: string;
begin
  FData.Clear;
  
  // Get environment variables
  // System.SysUtils.GetEnvironmentVariable is for single var.
  // We need to iterate.
  // On Windows, GetEnvironmentStrings API.
  // Delphi's TProcessEnvironment (System.Classes) or similar?
  // Actually, System.SysUtils doesn't expose iteration easily cross-platform in older versions, 
  // but modern Delphi might.
  
  // Let's use a helper if available, or platform specific.
  // Wait, TStringList has a way? No.
  
  // Let's use GetEnvironmentStrings via a helper or assume we can iterate.
  // Actually, we can use the `GetEnvironmentStrings` API on Windows or `environ` on POSIX.
  // But let's try to find a Delphi RTL way.
  
  // TProcessInfo? No.
  
  // Let's use a simple loop over a large block? No.
  
  // Okay, let's use a standard trick:
  // Use `GetEnvironmentVariable` is not enough.
  
  // Let's use the `GetEnvironmentStrings` API for Windows since we are on Windows.
  // Ideally we should abstract this.
  
  // Actually, `System.SysUtils` has `GetEnvironmentVariable` but not `GetEnvironmentVariables`.
  
  // Let's use a simple implementation using Windows API for now as the user is on Windows.
  // Or better, check if `System.Generics.Collections` or `System.Classes` has something.
  
  // Wait, `System.SysUtils` has `GetEnvironmentVariable` overload that returns all? No.
  
  // Let's implement a helper using `GetEnvironmentStrings`.
  
  Vars := TStringList.Create;
  try
    // Capture environment variables
    {$IFDEF MSWINDOWS}
    var P: PChar := GetEnvironmentStrings;
    try
      var PVar := P;
      while PVar^ <> #0 do
      begin
        Vars.Add(string(PVar));
        Inc(PVar, StrLen(PVar) + 1);
      end;
    finally
      FreeEnvironmentStrings(P);
    end;
    {$ENDIF}
    
    // Process variables
    for I := 0 to Vars.Count - 1 do
    begin
      var Line := Vars[I];
      EqIndex := Pos('=', Line);
      if EqIndex > 1 then
      begin
        EnvKey := Copy(Line, 1, EqIndex - 1);
        Value := Copy(Line, EqIndex + 1, MaxInt);
        
        // Filter by prefix
        if (FPrefix <> '') and (not EnvKey.StartsWith(FPrefix, True)) then
          Continue;
          
        // Remove prefix
        if FPrefix <> '' then
          Key := EnvKey.Substring(Length(FPrefix))
        else
          Key := EnvKey;
          
        // Replace double underscore with colon
        Key := StringReplace(Key, '__', TConfigurationPath.KeyDelimiter, [rfReplaceAll]);
        
        Set_(Key, Value);
      end;
    end;
    
  finally
    Vars.Free;
  end;
end;

end.

