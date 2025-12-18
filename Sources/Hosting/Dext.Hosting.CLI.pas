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
unit Dext.Hosting.CLI;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Entity.Migrations,
  Dext.Entity.Migrations.Runner,
  Dext.Entity.Migrations.Json,
  Dext.Entity.Drivers.Interfaces;

type
  IConsoleCommand = interface
    ['{A1B2C3D4-E5F6-4789-0123-456789ABCDEF}']
    function GetName: string;
    function GetDescription: string;
    procedure Execute(const Args: TArray<string>);
  end;

  TDextCLI = class
  private
    FCommands: TDictionary<string, IConsoleCommand>;
    FContextFactory: TFunc<IDbContext>;
    procedure RegisterCommands;
    procedure ShowHelp;
  public
    constructor Create(AContextFactory: TFunc<IDbContext>);
    destructor Destroy; override;
    // Returns True if a command was executed, False if normal startup should proceed
    function Run: Boolean; 
  end;

  // --- Commands ---

  TMigrateUpCommand = class(TInterfacedObject, IConsoleCommand)
  private
    FContextFactory: TFunc<IDbContext>;
  public
    constructor Create(AContextFactory: TFunc<IDbContext>);
    function GetName: string;
    function GetDescription: string;
    procedure Execute(const Args: TArray<string>);
  end;

  TMigrateListCommand = class(TInterfacedObject, IConsoleCommand)
  private
    FContextFactory: TFunc<IDbContext>;
  public
    constructor Create(AContextFactory: TFunc<IDbContext>);
    function GetName: string;
    function GetDescription: string;
    procedure Execute(const Args: TArray<string>);
  end;

implementation

{ TDextCLI }

constructor TDextCLI.Create(AContextFactory: TFunc<IDbContext>);
begin
  FContextFactory := AContextFactory;
  FCommands := TDictionary<string, IConsoleCommand>.Create;
  RegisterCommands;
end;

destructor TDextCLI.Destroy;
begin
  FCommands.Free;
  inherited;
end;

procedure TDextCLI.RegisterCommands;
begin
  var CmdUp := TMigrateUpCommand.Create(FContextFactory);
  FCommands.Add(CmdUp.GetName, CmdUp);
  
  var CmdList := TMigrateListCommand.Create(FContextFactory);
  FCommands.Add(CmdList.GetName, CmdList);
end;

procedure TDextCLI.ShowHelp;
begin
  WriteLn('Dext CLI Tool');
  WriteLn('-------------');
  WriteLn('Usage: MyApp.exe <command> [args]');
  WriteLn('');
  WriteLn('Available Commands:');
  for var Cmd in FCommands.Values do
  begin
    WriteLn('  ' + Cmd.GetName.PadRight(20) + Cmd.GetDescription);
  end;
  WriteLn('');
end;

function TDextCLI.Run: Boolean;
var
  CmdName: string;
  Cmd: IConsoleCommand;
  Args: TArray<string>;
  i: Integer;
begin
  // Check if any arguments passed
  if ParamCount = 0 then
    Exit(False); // No command, proceed to normal app startup

  CmdName := ParamStr(1).ToLower;
  
  // Handle Help
  if (CmdName = 'help') or (CmdName = '--help') or (CmdName = '-h') then
  begin
    ShowHelp;
    Exit(True);
  end;

  if FCommands.TryGetValue(CmdName, Cmd) then
  begin
    // Collect remaining args
    SetLength(Args, ParamCount - 1);
    for i := 2 to ParamCount do
      Args[i - 2] := ParamStr(i);
      
    try
      Cmd.Execute(Args);
    except
      on E: Exception do
        WriteLn('Error executing command: ' + E.Message);
    end;
    Result := True; // Command executed, app should terminate
  end
  else
  begin
    // If arg starts with -, it might be a flag for the main app, so ignore
    if CmdName.StartsWith('-') then
      Exit(False);
      
    WriteLn('Unknown command: ' + CmdName);
    ShowHelp;
    Result := True; // Prevent normal startup on bad command
  end;
end;

{ TMigrateUpCommand }

constructor TMigrateUpCommand.Create(AContextFactory: TFunc<IDbContext>);
begin
  FContextFactory := AContextFactory;
end;

function TMigrateUpCommand.GetName: string;
begin
  Result := 'migrate:up';
end;

function TMigrateUpCommand.GetDescription: string;
begin
  Result := 'Applies all pending migrations to the database. Usage: migrate:up [--source <path>]';
end;

procedure TMigrateUpCommand.Execute(const Args: TArray<string>);
var
  Context: IDbContext;
  Migrator: TMigrator;
  i: Integer;
  SourcePath: string;
begin
  // Parse arguments
  for i := 0 to High(Args) do
  begin
    if (Args[i] = '--source') or (Args[i] = '-s') then
    begin
      if i + 1 <= High(Args) then
        SourcePath := Args[i + 1];
    end;
  end;

  if SourcePath <> '' then
  begin
    WriteLn('   📂 Loading migrations from: ' + SourcePath);
    TJsonMigrationLoader.LoadFromDirectory(SourcePath);
  end;

  WriteLn('Starting migration update...');
  Context := FContextFactory();
  try
    Migrator := TMigrator.Create(Context);
    try
      Migrator.Migrate;
      WriteLn('Database is up to date.');
    finally
      Migrator.Free;
    end;
  finally
    // Context is interface managed, but TDbContext disables ref counting.
    // We must manually free it if it's an object.
    if Context is TDbContext then
    begin
      var CtxObj := Context as TDbContext;
      Context := nil; // Clear interface ref to prevent _IntfClear on dead object
      CtxObj.Free;
    end;
  end;
end;

{ TMigrateListCommand }

constructor TMigrateListCommand.Create(AContextFactory: TFunc<IDbContext>);
begin
  FContextFactory := AContextFactory;
end;

function TMigrateListCommand.GetName: string;
begin
  Result := 'migrate:list';
end;

function TMigrateListCommand.GetDescription: string;
begin
  Result := 'Lists applied and pending migrations.';
end;

procedure TMigrateListCommand.Execute(const Args: TArray<string>);
var
  Context: IDbContext;
  Migrator: TMigrator;
  Applied: TList<string>;
  Available: TArray<IMigration>;
  Status: string;
begin
  Context := FContextFactory();
  try
    // We need to expose internal logic of Migrator or duplicate it here.
    // Ideally TMigrator should have GetPendingMigrations.
    // For now, let's use a "hack" or refactor TMigrator later.
    // Let's instantiate TMigrator just to ensure history table exists.
    Migrator := TMigrator.Create(Context);
    try
      // Accessing private method via RTTI or just duplicating logic?
      // Let's duplicate logic for now as it's simple: GetApplied vs Registry.
      // Ideally we should refactor TMigrator to expose this.
      
      // We can't access GetAppliedMigrations because it's private in TMigrator.
      // Let's assume we refactor TMigrator to make it public or protected.
      // For this step, I will use a "friend class" hack or just execute SQL directly since I know the table name.
      
      WriteLn('Migration Status:');
      WriteLn('-----------------');
      
      Available := TMigrationRegistry.Instance.GetMigrations;
      
      // Quick check if table exists
      if not Context.Connection.TableExists('__DextMigrations') then
      begin
        WriteLn('History table not found. All ' + Length(Available).ToString + ' migrations are PENDING.');
        Exit;
      end;
      
      // Get Applied
      Applied := TList<string>.Create;
      try
        var Cmd := Context.Connection.CreateCommand('SELECT Id FROM __DextMigrations');
        var Reader := IDbCommand(Cmd).ExecuteQuery;
        while Reader.Next do
          Applied.Add(Reader.GetValue(0).AsString);
          
        for var Mig in Available do
        begin
          if Applied.Contains(Mig.GetId) then
            Status := '[Applied]'
          else
            Status := '[Pending]';
            
          WriteLn(Status.PadRight(12) + Mig.GetId);
        end;
        
      finally
        Applied.Free;
      end;

    finally
      Migrator.Free;
    end;
  finally
    // Context released
    if Context is TDbContext then
    begin
      var CtxObj := Context as TDbContext;
      Context := nil; // Clear interface ref to prevent _IntfClear on dead object
      CtxObj.Free;
    end;
  end;
end;

end.

