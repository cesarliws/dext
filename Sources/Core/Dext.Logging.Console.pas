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
unit Dext.Logging.Console;

interface

uses
  System.SysUtils,
  Dext.Logging;

type
  TConsoleLogger = class(TAbstractLogger)
  private
    FCategoryName: string;
  protected
    procedure Log(ALevel: TLogLevel; const AMessage: string; const AArgs: array of const); override;
    procedure Log(ALevel: TLogLevel; const AException: Exception; const AMessage: string; const AArgs: array of const); override;
    function IsEnabled(ALevel: TLogLevel): Boolean; override;
  public
    constructor Create(const ACategoryName: string);
  end;

  TConsoleLoggerProvider = class(TInterfacedObject, ILoggerProvider)
  public
    function CreateLogger(const ACategoryName: string): ILogger;
    procedure Dispose;
  end;

implementation

{ TConsoleLogger }

constructor TConsoleLogger.Create(const ACategoryName: string);
begin
  inherited Create;
  FCategoryName := ACategoryName;
end;

function TConsoleLogger.IsEnabled(ALevel: TLogLevel): Boolean;
begin
  Result := ALevel <> TLogLevel.None;
end;

procedure TConsoleLogger.Log(ALevel: TLogLevel; const AMessage: string; const AArgs: array of const);
var
  LMsg: string;
  LLevelStr: string;
begin
  if not IsEnabled(ALevel) then Exit;

  case ALevel of
    TLogLevel.Trace: LLevelStr := 'trce';
    TLogLevel.Debug: LLevelStr := 'dbug';
    TLogLevel.Information: LLevelStr := 'info';
    TLogLevel.Warning: LLevelStr := 'warn';
    TLogLevel.Error: LLevelStr := 'fail';
    TLogLevel.Critical: LLevelStr := 'crit';
  else
    LLevelStr := '    ';
  end;

  try
    LMsg := Format(AMessage, AArgs);
  except
    on E: Exception do
      LMsg := AMessage + ' (Format Error: ' + E.Message + ')';
  end;

  Writeln(Format('%s: %s' + sLineBreak + '      %s', [LLevelStr, FCategoryName, LMsg]));
end;

procedure TConsoleLogger.Log(ALevel: TLogLevel; const AException: Exception; const AMessage: string; const AArgs: array of const);
begin
  if not IsEnabled(ALevel) then Exit;
  
  Log(ALevel, AMessage, AArgs);
  if AException <> nil then
    Writeln(Format('      %s: %s', [AException.ClassName, AException.Message]));
end;

{ TConsoleLoggerProvider }

function TConsoleLoggerProvider.CreateLogger(const ACategoryName: string): ILogger;
begin
  Result := TConsoleLogger.Create(ACategoryName);
end;

procedure TConsoleLoggerProvider.Dispose;
begin
  // Nothing to dispose
end;

end.

