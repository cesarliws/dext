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
unit Dext.Logging;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  /// <summary>
  ///   Defines logging severity levels.
  /// </summary>
  TLogLevel = (
    Trace = 0,
    Debug = 1,
    Information = 2,
    Warning = 3,
    Error = 4,
    Critical = 5,
    None = 6
  );

  /// <summary>
  ///   Represents a type used to perform logging.
  /// </summary>
  ILogger = interface
    ['{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}']
    procedure Log(ALevel: TLogLevel; const AMessage: string; const AArgs: array of const); overload;
    procedure Log(ALevel: TLogLevel; const AException: Exception; const AMessage: string; const AArgs: array of const); overload;
    
    function IsEnabled(ALevel: TLogLevel): Boolean;
    
    // Convenience methods
    procedure LogTrace(const AMessage: string; const AArgs: array of const);
    procedure LogDebug(const AMessage: string; const AArgs: array of const);
    procedure LogInformation(const AMessage: string; const AArgs: array of const);
    procedure LogWarning(const AMessage: string; const AArgs: array of const);
    procedure LogError(const AMessage: string; const AArgs: array of const); overload;
    procedure LogError(const AException: Exception; const AMessage: string; const AArgs: array of const); overload;
    procedure LogCritical(const AMessage: string; const AArgs: array of const); overload;
    procedure LogCritical(const AException: Exception; const AMessage: string; const AArgs: array of const); overload;
  end;

  /// <summary>
  ///   Represents a type that can create instances of ILogger.
  /// </summary>
  ILoggerProvider = interface
    ['{B2C3D4E5-F678-9012-3456-7890ABCDEF12}']
    function CreateLogger(const ACategoryName: string): ILogger;
    procedure Dispose;
  end;

  /// <summary>
  ///   Represents a type used to configure the logging system and create instances of ILogger.
  /// </summary>
  ILoggerFactory = interface
    ['{C3D4E5F6-7890-1234-5678-90ABCDEF1234}']
    function CreateLogger(const ACategoryName: string): ILogger;
    procedure AddProvider(const AProvider: ILoggerProvider);
  end;

  /// <summary>
  ///   Base class for ILogger implementations.
  ///   Implements convenience methods by delegating to the abstract Log method.
  /// </summary>
  TAbstractLogger = class(TInterfacedObject, ILogger)
  protected
    procedure Log(ALevel: TLogLevel; const AMessage: string; const AArgs: array of const); overload; virtual; abstract;
    procedure Log(ALevel: TLogLevel; const AException: Exception; const AMessage: string; const AArgs: array of const); overload; virtual; abstract;
    function IsEnabled(ALevel: TLogLevel): Boolean; virtual; abstract;
  public
    procedure LogTrace(const AMessage: string; const AArgs: array of const);
    procedure LogDebug(const AMessage: string; const AArgs: array of const);
    procedure LogInformation(const AMessage: string; const AArgs: array of const);
    procedure LogWarning(const AMessage: string; const AArgs: array of const);
    procedure LogError(const AMessage: string; const AArgs: array of const); overload;
    procedure LogError(const AException: Exception; const AMessage: string; const AArgs: array of const); overload;
    procedure LogCritical(const AMessage: string; const AArgs: array of const); overload;
    procedure LogCritical(const AException: Exception; const AMessage: string; const AArgs: array of const); overload;
  end;

  /// <summary>
  ///   Aggregates multiple loggers into one.
  /// </summary>
  TAggregateLogger = class(TAbstractLogger)
  private
    FLoggers: TArray<ILogger>;
    FMinimumLevel: TLogLevel;
  public
    constructor Create(const ALoggers: TArray<ILogger>; AMinimumLevel: TLogLevel);
    
    procedure Log(ALevel: TLogLevel; const AMessage: string; const AArgs: array of const); override;
    procedure Log(ALevel: TLogLevel; const AException: Exception; const AMessage: string; const AArgs: array of const); override;
    
    function IsEnabled(ALevel: TLogLevel): Boolean; override;
  end;

  /// <summary>
  ///   Default implementation of ILoggerFactory.
  /// </summary>
  TLoggerFactory = class(TInterfacedObject, ILoggerFactory)
  private
    FProviders: TList<ILoggerProvider>;
    FLock: TObject;
    FMinimumLevel: TLogLevel;
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger(const ACategoryName: string): ILogger;
    function CreateLoggerInstance(const ACategoryName: string): TAggregateLogger;
    procedure SetMinimumLevel(ALevel: TLogLevel);
    procedure AddProvider(const AProvider: ILoggerProvider);
  end;

implementation

{ TLoggerFactory }

constructor TLoggerFactory.Create;
begin
  inherited;
  FProviders := TList<ILoggerProvider>.Create;
  FLock := TObject.Create;
  FMinimumLevel := TLogLevel.Information; // Default
end;

destructor TLoggerFactory.Destroy;
var
  LProvider: ILoggerProvider;
begin
  TMonitor.Enter(FLock);
  try
    for LProvider in FProviders do
    begin
      LProvider.Dispose;
    end;
    FProviders.Free;
  finally
    TMonitor.Exit(FLock);
    FLock.Free;
  end;
  inherited;
end;

procedure TLoggerFactory.AddProvider(const AProvider: ILoggerProvider);
begin
  TMonitor.Enter(FLock);
  try
    FProviders.Add(AProvider);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TLoggerFactory.SetMinimumLevel(ALevel: TLogLevel);
begin
  FMinimumLevel := ALevel;
end;

function TLoggerFactory.CreateLogger(const ACategoryName: string): ILogger;
var
  LLoggers: TArray<ILogger>;
  i: Integer;
begin
  TMonitor.Enter(FLock);
  try
    SetLength(LLoggers, FProviders.Count);
    for i := 0 to FProviders.Count - 1 do
    begin
      LLoggers[i] := FProviders[i].CreateLogger(ACategoryName);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  
  Result := TAggregateLogger.Create(LLoggers, FMinimumLevel);
end;

function TLoggerFactory.CreateLoggerInstance(const ACategoryName: string): TAggregateLogger;
var
  LLoggers: TArray<ILogger>;
  i: Integer;
begin
  TMonitor.Enter(FLock);
  try
    SetLength(LLoggers, FProviders.Count);
    for i := 0 to FProviders.Count - 1 do
    begin
      LLoggers[i] := FProviders[i].CreateLogger(ACategoryName);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  
  Result := TAggregateLogger.Create(LLoggers, FMinimumLevel);
end;

{ TAbstractLogger }

procedure TAbstractLogger.LogTrace(const AMessage: string; const AArgs: array of const);
begin
  Log(TLogLevel.Trace, AMessage, AArgs);
end;

procedure TAbstractLogger.LogDebug(const AMessage: string; const AArgs: array of const);
begin
  Log(TLogLevel.Debug, AMessage, AArgs);
end;

procedure TAbstractLogger.LogInformation(const AMessage: string; const AArgs: array of const);
begin
  Log(TLogLevel.Information, AMessage, AArgs);
end;

procedure TAbstractLogger.LogWarning(const AMessage: string; const AArgs: array of const);
begin
  Log(TLogLevel.Warning, AMessage, AArgs);
end;

procedure TAbstractLogger.LogError(const AMessage: string; const AArgs: array of const);
begin
  Log(TLogLevel.Error, AMessage, AArgs);
end;

procedure TAbstractLogger.LogError(const AException: Exception; const AMessage: string; const AArgs: array of const);
begin
  Log(TLogLevel.Error, AException, AMessage, AArgs);
end;

procedure TAbstractLogger.LogCritical(const AMessage: string; const AArgs: array of const);
begin
  Log(TLogLevel.Critical, AMessage, AArgs);
end;

procedure TAbstractLogger.LogCritical(const AException: Exception; const AMessage: string; const AArgs: array of const);
begin
  Log(TLogLevel.Critical, AException, AMessage, AArgs);
end;

{ TAggregateLogger }

constructor TAggregateLogger.Create(const ALoggers: TArray<ILogger>; AMinimumLevel: TLogLevel);
begin
  inherited Create;
  FLoggers := ALoggers;
  FMinimumLevel := AMinimumLevel;
end;

function TAggregateLogger.IsEnabled(ALevel: TLogLevel): Boolean;
var
  LLogger: ILogger;
begin
  if ALevel < FMinimumLevel then Exit(False);

  Result := False;
  for LLogger in FLoggers do
  begin
    if LLogger.IsEnabled(ALevel) then
      Exit(True);
  end;
end;

procedure TAggregateLogger.Log(ALevel: TLogLevel; const AMessage: string; const AArgs: array of const);
var
  LLogger: ILogger;
begin
  if ALevel < FMinimumLevel then Exit;

  for LLogger in FLoggers do
  begin
    LLogger.Log(ALevel, AMessage, AArgs);
  end;
end;

procedure TAggregateLogger.Log(ALevel: TLogLevel; const AException: Exception; const AMessage: string; const AArgs: array of const);
var
  LLogger: ILogger;
begin
  if ALevel < FMinimumLevel then Exit;

  for LLogger in FLoggers do
  begin
    LLogger.Log(ALevel, AException, AMessage, AArgs);
  end;
end;

end.

