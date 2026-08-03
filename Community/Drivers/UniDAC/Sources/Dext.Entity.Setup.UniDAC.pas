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
unit Dext.Entity.Setup.UniDAC;

/// <summary>
///   Community variant of Dext.Entity.Setup configured for UniDAC driver.
///   Use this setup unit if you wish to build DbContext instances powered by UniDAC.
/// </summary>

interface

{$I Dext.inc}

uses
  System.SysUtils,
  System.Classes,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Drivers.UniDAC,
  Dext.Entity.Drivers.UniDAC.Manager,
  Dext.Entity.Drivers.UniDAC.Links;

type
  TUniDACDbContextOptions = class
  private
    FConnectionString: string;
    FDriverName: string;
    FParams: TStrings;
    FMaxPoolSize: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function UseSQLite(const ADatabase: string): TUniDACDbContextOptions;
    function UsePostgreSQL(const AConnectionString: string): TUniDACDbContextOptions;
    function UseMySQL(const AConnectionString: string): TUniDACDbContextOptions;
    function UseMSSQL(const AConnectionString: string): TUniDACDbContextOptions;
    function UseOracle(const AConnectionString: string): TUniDACDbContextOptions;
    function UseFirebird(const AConnectionString: string): TUniDACDbContextOptions;

    function BuildConnection: IDbConnection;
    property DriverName: string read FDriverName;
  end;

implementation

constructor TUniDACDbContextOptions.Create;
begin
  inherited Create;
  FParams := TStringList.Create;
  FMaxPoolSize := 50;
  FDriverName := 'SQLite';
end;

destructor TUniDACDbContextOptions.Destroy;
begin
  FParams.Free;
  inherited;
end;

function TUniDACDbContextOptions.UseSQLite(const ADatabase: string): TUniDACDbContextOptions;
begin
  FDriverName := 'SQLite';
  FParams.Clear;
  FParams.Values['Database'] := ADatabase;
  Result := Self;
end;

function TUniDACDbContextOptions.UsePostgreSQL(const AConnectionString: string): TUniDACDbContextOptions;
begin
  FDriverName := 'PostgreSQL';
  FConnectionString := AConnectionString;
  FParams.Clear;
  FParams.Text := StringReplace(AConnectionString, ';', sLineBreak, [rfReplaceAll]);
  Result := Self;
end;

function TUniDACDbContextOptions.UseMySQL(const AConnectionString: string): TUniDACDbContextOptions;
begin
  FDriverName := 'MySQL';
  FConnectionString := AConnectionString;
  FParams.Clear;
  FParams.Text := StringReplace(AConnectionString, ';', sLineBreak, [rfReplaceAll]);
  Result := Self;
end;

function TUniDACDbContextOptions.UseMSSQL(const AConnectionString: string): TUniDACDbContextOptions;
begin
  FDriverName := 'MSSQL';
  FConnectionString := AConnectionString;
  FParams.Clear;
  FParams.Text := StringReplace(AConnectionString, ';', sLineBreak, [rfReplaceAll]);
  Result := Self;
end;

function TUniDACDbContextOptions.UseOracle(const AConnectionString: string): TUniDACDbContextOptions;
begin
  FDriverName := 'Oracle';
  FConnectionString := AConnectionString;
  FParams.Clear;
  FParams.Text := StringReplace(AConnectionString, ';', sLineBreak, [rfReplaceAll]);
  Result := Self;
end;

function TUniDACDbContextOptions.UseFirebird(const AConnectionString: string): TUniDACDbContextOptions;
begin
  FDriverName := 'Firebird';
  FConnectionString := AConnectionString;
  FParams.Clear;
  FParams.Text := StringReplace(AConnectionString, ';', sLineBreak, [rfReplaceAll]);
  Result := Self;
end;

function TUniDACDbContextOptions.BuildConnection: IDbConnection;
var
  ProviderName: string;
  UniConn: TUniConnection;
begin
  ProviderName := TDextUniDACManager.MapDriverToProvider(FDriverName);
  UniConn := TDextUniDACManager.Instance.CreatePooledConnection(
    ProviderName,
    FParams,
    FMaxPoolSize
  );

  TDextUniDACManager.Instance.ApplyOptions(UniConn, []);
  Result := TDextUniDACConnection.Create(UniConn, True);
end;

end.
