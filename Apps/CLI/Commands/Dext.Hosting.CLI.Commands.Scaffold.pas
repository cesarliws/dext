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
{  Created: 2026-01-07                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Hosting.CLI.Commands.Scaffold;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  System.Generics.Collections,
  System.Diagnostics,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  Dext.Entity.Drivers.FireDAC.Links,
  Dext.Hosting.CLI.Args,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Scaffolding,
  Dext.Utils;

type
  TScaffoldCommand = class(TInterfacedObject, IConsoleCommand)
  private
    procedure ShowUsage;
  public
    function GetName: string;
    function GetDescription: string;
    procedure Execute(const Args: TCommandLineArgs);
  end;

implementation

{ TScaffoldCommand }

function TScaffoldCommand.GetName: string;
begin
  Result := 'scaffold';
end;

function TScaffoldCommand.GetDescription: string;
begin
  Result := 'Generates entity classes from database schema. Usage: scaffold --connection <string> --driver <driver>';
end;

procedure TScaffoldCommand.ShowUsage;
begin
  SafeWriteLn('');
  SafeWriteLn('Dext Scaffold - Entity Generator from Database');
  SafeWriteLn('===============================================');
  SafeWriteLn('');
  SafeWriteLn('Usage: dext scaffold --connection <string> --driver <driver> [options]');
  SafeWriteLn('');
  SafeWriteLn('Required:');
  SafeWriteLn('  --connection, -c   FireDAC connection string or database path');
  SafeWriteLn('  --driver, -d       Database driver: sqlite, pg, mssql, firebird, mysql, oracle');
  SafeWriteLn('');
  SafeWriteLn('Options:');
  SafeWriteLn('  --output, -o       Output file path (default: Entities.pas)');
  SafeWriteLn('  --unit, -u         Unit name (default: derived from output file)');
  SafeWriteLn('  --fluent           Use fluent mapping instead of attributes');
  SafeWriteLn('  -t, --tables <names>     Comma-separated list of tables to include');
  SafeWriteLn('  -s, --schema <name>      Database schema/search path');
  SafeWriteLn('  --smart            Use Dext Smart Properties (default)');
  SafeWriteLn('  --poco             Use native Delphi types + Metadata Classes');
  SafeWriteLn('  --no-metadata      Explicitly skip TEntityType classes');
  SafeWriteLn('  --with-metadata    Explicitly include TEntityType classes');
  SafeWriteLn('');
  SafeWriteLn('Examples:');
  SafeWriteLn('  dext scaffold -c "mydb.db" -d sqlite -o MyEntities.pas');
  SafeWriteLn('  dext scaffold -c "host=localhost;database=mydb;user=postgres;password=123" -d pg --fluent');
  SafeWriteLn('  dext scaffold -c "Server=.;Database=MyDB;Trusted_Connection=yes" -d mssql -t "users,orders,products"');
  SafeWriteLn('');
end;

procedure TScaffoldCommand.Execute(const Args: TCommandLineArgs);
var
  ConnectionStr: string;
  DriverName: string;
  OutputFile: string;
  UnitName: string;
  UseFluent: Boolean;
  TableFilter: string;
  TableList: TArray<string>;
  FDConnection: TFDConnection;
  Connection: IDbConnection;
  Provider: ISchemaProvider;
  Generator: IEntityGenerator;
  Tables: TArray<string>;
  MetaList: TArray<TMetaTable>;
  Code: string;
  MappingStyle: TMappingStyle;
  PropertyStyle: TPropertyStyle;
  GenerateMetadata: Boolean;
  SchemaName: string;
  MappingStr: string;
  PropertyStr: string;
  MetadataStr: string;
  FilteredTables: TList<string>;
  T, F: string;
  SW, TableSW: TStopwatch;
  TableName: string;
begin
  // Check for help
  if Args.HasOption('help') or Args.HasOption('h') then
  begin
    ShowUsage;
    Exit;
  end;

  // Parse required arguments
  ConnectionStr := Args.GetOption('connection');
  if ConnectionStr = '' then
    ConnectionStr := Args.GetOption('c');
    
  DriverName := Args.GetOption('driver');
  if DriverName = '' then
    DriverName := Args.GetOption('d');
    
  if (ConnectionStr = '') or (DriverName = '') then
  begin
    SafeWriteLn('Error: --connection and --driver are required.');
    ShowUsage;
    Exit;
  end;
  
  // Parse optional arguments
  OutputFile := Args.GetOption('output');
  if OutputFile = '' then
    OutputFile := Args.GetOption('o');
  if OutputFile = '' then
    OutputFile := 'Entities.pas';
    
  UnitName := Args.GetOption('unit');
  if UnitName = '' then
    UnitName := Args.GetOption('u');

  // If a custom unit name (with namespace) is provided but no output file,
  // use the unit name as the filename base.
  if (UnitName <> '') and (Args.GetOption('output') = '') and (Args.GetOption('o') = '') then
     OutputFile := UnitName + '.pas';

  // The Unit Name MUST match the physical filename in Delphi
  UnitName := TPath.GetFileNameWithoutExtension(OutputFile);
    
  TableFilter := Args.GetOption('tables');
  if TableFilter = '' then
    TableFilter := Args.GetOption('t');
    
  if TableFilter <> '' then
    TableList := TableFilter.Split([','])
  else
    TableList := [];

  SchemaName := Args.GetOption('schema');
  if SchemaName = '' then
    SchemaName := Args.GetOption('s');
    
  UseFluent := Args.HasOption('fluent');
    
  // Determine mapping style
  if UseFluent then
    MappingStyle := msFluent
  else
    MappingStyle := msAttributes;
    
  // Default Logic:
  // 1. If nothing specified -> Smart Properties, No Metadata
  // 2. If --smart -> Smart Properties, No Metadata
  // 3. If --poco -> POCO Style, With Metadata
  
  if Args.HasOption('poco') then
  begin
    PropertyStyle := psPOCO;
    GenerateMetadata := True;
  end
  else
  begin
    PropertyStyle := psSmart;
    GenerateMetadata := False;
  end;
  
  // Explicit overrides
  if Args.HasOption('no-metadata') then GenerateMetadata := False;
  if Args.HasOption('with-metadata') then GenerateMetadata := True;
  if Args.HasOption('smart') then PropertyStyle := psSmart;

  if UseFluent then MappingStr := 'Fluent' else MappingStr := 'Attributes';
  if PropertyStyle = psSmart then PropertyStr := 'Smart Properties' else PropertyStr := 'POCO';
  if GenerateMetadata then MetadataStr := 'Enabled' else MetadataStr := 'Disabled';

  SafeWriteLn('');
  SafeWriteLn('Dext Scaffold');
  SafeWriteLn('=============');
  SafeWriteLn('Driver: ' + DriverName);
  if SchemaName <> '' then
    SafeWriteLn('Schema: ' + SchemaName);
  SafeWriteLn('Output: ' + OutputFile);
  SafeWriteLn('Mapping: ' + MappingStr);
  SafeWriteLn('Properties: ' + PropertyStr);
  SafeWriteLn('Metadata: ' + MetadataStr);
  SafeWriteLn('');
  
  // Create FireDAC connection
  FDConnection := TFDConnection.Create(nil);
  try
    FDConnection.LoginPrompt := False;
    
    // Enable extended metadata to get AutoInc, PK, etc.
    FDConnection.Params.Values['ExtendedMetadata'] := 'True';
    
    DriverName := LowerCase(Trim(DriverName));
    if SchemaName <> '' then
    begin
      if (DriverName = 'oracle') or (DriverName = 'ora') then
        SchemaName := UpperCase(SchemaName);
      FDConnection.Params.Values['Schema'] := SchemaName;
      FDConnection.Params.Values['MetaCurSchema'] := SchemaName;
      FDConnection.Params.Values['MetaDefSchema'] := SchemaName;
    end;
    
    // Configure driver
    if DriverName = 'sqlite' then
    begin
      FDConnection.DriverName := 'SQLite';
      if not (Pos('=', ConnectionStr) > 0) then
        FDConnection.Params.Values['Database'] := ConnectionStr
      else
        FDConnection.ConnectionString := 'DriverID=SQLite;' + ConnectionStr;
    end
    else if (DriverName = 'pg') or (DriverName = 'postgres') or (DriverName = 'postgresql') then
    begin
      FDConnection.ConnectionString := 'DriverID=PG;' + ConnectionStr;
    end
    else if (DriverName = 'mssql') or (DriverName = 'sqlserver') then
    begin
      FDConnection.ConnectionString := 'DriverID=MSSQL;' + ConnectionStr;
    end
    else if (DriverName = 'fb') or (DriverName = 'firebird') then
    begin
      FDConnection.ConnectionString := 'DriverID=FB;' + ConnectionStr;
    end
    else if (DriverName = 'mysql') or (DriverName = 'mariadb') then
    begin
      FDConnection.ConnectionString := 'DriverID=MySQL;' + ConnectionStr;
    end
    else if (DriverName = 'oracle') or (DriverName = 'ora') then
    begin
      if ConnectionStr <> '' then
        FDConnection.ConnectionString := 'DriverID=Ora;' + ConnectionStr
      else
        FDConnection.Params.DriverID := 'Ora';
    end
    else
    begin
      SafeWriteLn('Error: Unknown driver "' + DriverName + '". Supported: sqlite, pg, mssql, firebird, mysql, oracle');
      Exit;
    end;
    
    // Create connection interface BEFORE opening to hook AfterConnect event
    Connection := TFireDACConnection.Create(FDConnection, False);
    Connection.OnLog := procedure(AMsg: string)
      begin
        SafeWriteLn('  > ' + AMsg);
      end;
    
    SafeWriteLn('Connecting to database...');
    try
      Connection.Connect;
      SafeWriteLn('Connected!');
    except
      on E: Exception do
      begin
        SafeWriteLn('Error: Failed to connect: ' + E.Message);
        Exit;
      end;
    end;
    
    // Create schema provider
    Provider := TFireDACSchemaProvider.Create(Connection);
    
    // Get tables
    SafeWriteLn('Reading schema...');
    Tables := Provider.GetTables;
    
    // Apply table filter if specified
    if Length(TableList) > 0 then
    begin
      FilteredTables := TList<string>.Create;
      try
        for T in Tables do
        begin
          for F in TableList do
          begin
            if SameText(T, Trim(F)) then
            begin
              FilteredTables.Add(T);
              Break;
            end;
          end;
        end;
        Tables := FilteredTables.ToArray;
      finally
        FilteredTables.Free;
      end;
    end;
    
    SafeWriteLn('Found ' + IntToStr(Length(Tables)) + ' tables:');
    for T in Tables do
      SafeWriteLn('  - ' + T);
    SafeWriteLn('');
    
    if Length(Tables) = 0 then
    begin
      SafeWriteLn('No tables found. Nothing to generate.');
      Exit;
    end;
    
    // Get metadata for each table
    SafeWriteLn('Extracting metadata...');
    SW := TStopwatch.StartNew;
    for TableName in Tables do
    begin
      TableSW := TStopwatch.StartNew;
      SafeWrite('  Reading metadata: ' + TableName + '...');
      try
        MetaList := MetaList + [Provider.GetTableMetadata(TableName)];
        SafeWriteLn(' Done in ' + IntToStr(TableSW.ElapsedMilliseconds) + ' ms');
      except
        on E: Exception do
          SafeWriteLn(' ❌ Error: ' + E.Message);
      end;
    end;
    SafeWriteLn(Format('Total metadata extraction time: %d ms', [SW.ElapsedMilliseconds]));
    
    // Generate code
    SafeWriteLn('');
    SafeWriteLn('Generating Delphi code...');
    Generator := TDelphiEntityGenerator.Create;
    Code := Generator.GenerateUnit(UnitName, MetaList, MappingStyle, PropertyStyle, GenerateMetadata);
    
    // Write to file
    TFile.WriteAllText(OutputFile, Code);
    SafeWriteLn('');
    SafeWriteLn('SUCCESS! Generated: ' + TPath.GetFullPath(OutputFile));
    SafeWriteLn('');
    
  finally
    FDConnection.Free;
  end;
end;

end.
