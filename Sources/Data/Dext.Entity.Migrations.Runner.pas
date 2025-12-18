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
unit Dext.Entity.Migrations.Runner;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Entity.Migrations,
  Dext.Entity.Migrations.Builder,
  Dext.Entity.Migrations.Operations,
  Dext.Entity.Drivers.Interfaces;

type
  TMigrator = class
  private
    FContext: IDbContext;
    function GetAppliedMigrations: TList<string>;
    procedure EnsureHistoryTable;
    procedure ApplyMigration(AMigration: IMigration);
  public
    constructor Create(AContext: IDbContext);
    procedure Migrate;
    
    /// <summary>
    ///   Checks if the database schema is compatible with the expected version.
    ///   Returns True if the last applied migration is equal to or greater than the ExpectedVersion.
    ///   If ExpectedVersion is empty, returns True (no check).
    /// </summary>
    function ValidateSchemaCompatibility(const ExpectedVersion: string): Boolean;
  end;

implementation

{ TMigrator }

constructor TMigrator.Create(AContext: IDbContext);
begin
  FContext := AContext;
end;

procedure TMigrator.EnsureHistoryTable;
var
  Builder: TSchemaBuilder;
  Op: TMigrationOperation;
  SQL: string;
  CmdIntf: IInterface;
  Cmd: IDbCommand;
begin
  if FContext.Connection.TableExists('__DextMigrations') then
    Exit;
    
  Builder := TSchemaBuilder.Create;
  try
    Builder.CreateTable('__DextMigrations', procedure(T: TTableBuilder)
    begin
      T.Column('Id', 'VARCHAR', 255).PrimaryKey;
      T.Column('AppliedAt', 'TIMESTAMP').Default('CURRENT_TIMESTAMP');
    end);
    
    // Generate SQL
    Op := Builder.Operations[0];
    SQL := FContext.Dialect.GenerateMigration(Op);
    
    // Execute
    CmdIntf := FContext.Connection.CreateCommand(SQL);
    Cmd := CmdIntf as IDbCommand;
    Cmd.ExecuteNonQuery;
  finally
    Builder.Free;
  end;
end;

function TMigrator.GetAppliedMigrations: TList<string>;
var
  CmdIntf: IInterface;
  Cmd: IDbCommand;
  Reader: IDbReader;
begin
  Result := TList<string>.Create;
  try
    EnsureHistoryTable;
    
    CmdIntf := FContext.Connection.CreateCommand('SELECT Id FROM __DextMigrations');
    Cmd := CmdIntf as IDbCommand;
    Reader := Cmd.ExecuteQuery;
    try
      while Reader.Next do
      begin
        Result.Add(Reader.GetValue(0).AsString);
      end;
    finally
      Reader.Close;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TMigrator.ApplyMigration(AMigration: IMigration);
var
  Builder: TSchemaBuilder;
  Op: TMigrationOperation;
  SQL: string;
  CmdIntf: IInterface;
  Cmd: IDbCommand;
begin
  WriteLn('   🚀 Applying migration: ' + AMigration.GetId);
  
  FContext.BeginTransaction;
  try
    Builder := TSchemaBuilder.Create;
    try
      AMigration.Up(Builder);
      
      for Op in Builder.Operations do
      begin
        SQL := FContext.Dialect.GenerateMigration(Op);
        if SQL <> '' then
        begin
          CmdIntf := FContext.Connection.CreateCommand(SQL);
          Cmd := CmdIntf as IDbCommand;
          Cmd.ExecuteNonQuery;
        end;
      end;
      
      // Record in History
      SQL := 'INSERT INTO __DextMigrations (Id, AppliedAt) VALUES (' + 
             FContext.Dialect.GetParamPrefix + 'Id, ' + 
             FContext.Dialect.GetParamPrefix + 'AppliedAt)';
             
      CmdIntf := FContext.Connection.CreateCommand(SQL);
      Cmd := CmdIntf as IDbCommand;
      Cmd.AddParam('Id', AMigration.GetId);
      Cmd.AddParam('AppliedAt', Now);
      Cmd.ExecuteNonQuery;
      
    finally
      Builder.Free;
    end;
    
    FContext.Commit;
  except
    FContext.Rollback;
    raise;
  end;
end;

procedure TMigrator.Migrate;
var
  Applied: TList<string>;
  Available: TArray<IMigration>;
  Migration: IMigration;
begin
  Applied := GetAppliedMigrations;
  try
    Available := TMigrationRegistry.Instance.GetMigrations;
    
    if Length(Available) = 0 then
      WriteLn('   ⚠️No migrations found in registry.')
    else
      WriteLn('   🔎 Found ' + Length(Available).ToString + ' migrations in registry.');
    
    for Migration in Available do
    begin
      if not Applied.Contains(Migration.GetId) then
      begin
        ApplyMigration(Migration);
      end
      else
      begin
        // WriteLn('   ⏭️ Skipping applied migration: ' + Migration.GetId);
      end;
    end;
  finally
    Applied.Free;
  end;
end;

function TMigrator.ValidateSchemaCompatibility(const ExpectedVersion: string): Boolean;
var
  Applied: TList<string>;
  LastApplied: string;
begin
  if ExpectedVersion.IsEmpty then
    Exit(True);
    
  Applied := GetAppliedMigrations;
  try
    if Applied.Count = 0 then
      Exit(False); // No migrations applied, definitely not compatible if we expect something
      
    Applied.Sort; // Sort lexicographically (timestamps work well)
    LastApplied := Applied.Last;
    
    // Check if LastApplied >= ExpectedVersion
    Result := CompareText(LastApplied, ExpectedVersion) >= 0;
  finally
    Applied.Free;
  end;
end;

end.

