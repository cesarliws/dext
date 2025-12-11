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
unit Dext.Entity.Migrations.Json;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.SysUtils,
  System.Types,
  Dext.Entity.Migrations,
  Dext.Entity.Migrations.Builder,
  Dext.Entity.Migrations.Operations,
  Dext.Entity.Migrations.Serializers.Json,
  Dext.Json,
  Dext.Json.Types;

type
  /// <summary>
  ///   Implementation of IMigration that reads operations from a JSON source.
  /// </summary>
  TJsonMigration = class(TInterfacedObject, IMigration)
  private
    FId: string;
    FJsonContent: string;
    FDescription: string;
    FAuthor: string;
  public
    constructor Create(const AId, AJsonContent: string);
    
    function GetId: string;
    procedure Up(Builder: TSchemaBuilder);
    procedure Down(Builder: TSchemaBuilder);
    
    property Description: string read FDescription;
    property Author: string read FAuthor;
  end;

  /// <summary>
  ///   Helper to load JSON migrations from a directory.
  /// </summary>
  TJsonMigrationLoader = class
  public
    class procedure LoadFromDirectory(const ADirectory: string);
  end;

implementation

{ TJsonMigration }

constructor TJsonMigration.Create(const AId, AJsonContent: string);
var
  Provider: IDextJsonProvider;
  Node: IDextJsonNode;
  Obj: IDextJsonObject;
begin
  inherited Create;
  FId := AId;
  FJsonContent := AJsonContent;
  
  // Parse metadata immediately to populate properties
  try
    Provider := TDextJson.Provider;
    Node := Provider.Parse(FJsonContent);
    if (Node <> nil) and (Node.GetNodeType = jntObject) then
    begin
      Obj := Node as IDextJsonObject;
      if Obj.Contains('description') then
        FDescription := Obj.GetString('description');
      if Obj.Contains('author') then
        FAuthor := Obj.GetString('author');
    end;
  except
    // Ignore parsing errors in constructor, Up() will catch them properly
  end;
end;

procedure TJsonMigration.Down(Builder: TSchemaBuilder);
begin
  // TODO: Implement Down operations if JSON supports it
  // For now, we assume JSON migrations are forward-only or we need a separate "down" section
end;

function TJsonMigration.GetId: string;
begin
  Result := FId;
end;

procedure TJsonMigration.Up(Builder: TSchemaBuilder);
var
  Provider: IDextJsonProvider;
  Node: IDextJsonNode;
  Obj: IDextJsonObject;
  OpsArr: IDextJsonArray;
  OpsJson: string;
  Ops: TObjectList<TMigrationOperation>;
  Op: TMigrationOperation;
begin
  Provider := TDextJson.Provider;
  Node := Provider.Parse(FJsonContent);
  
  if (Node = nil) or (Node.GetNodeType <> jntObject) then
    raise Exception.Create('Invalid migration JSON: Root must be an object.');
    
  Obj := Node as IDextJsonObject;
  
  if not Obj.Contains('operations') then
    Exit; // No operations
    
  OpsArr := Obj.GetArray('operations');
  if OpsArr = nil then
    Exit;
    
  // Serialize the array back to string to use our serializer
  // This is a bit inefficient but reuses the serializer logic
  // Alternatively, we could expose DeserializeOperations(IDextJsonArray) in the serializer
  OpsJson := OpsArr.ToJson(False);
  
  Ops := TMigrationJsonSerializer.Deserialize(OpsJson);
  try
    for Op in Ops do
    begin
      // Transfer ownership to Builder
      Builder.Operations.Add(Op);
    end;
    Ops.OwnsObjects := False; // Don't free the operations we just moved
  finally
    Ops.Free;
  end;
end;

{ TJsonMigrationLoader }

class procedure TJsonMigrationLoader.LoadFromDirectory(const ADirectory: string);
var
  Files: TStringDynArray;
  FileName: string;
  JsonContent: string;
  MigrationId: string;
  Migration: IMigration;
begin
  if not TDirectory.Exists(ADirectory) then
    Exit;
    
  Files := TDirectory.GetFiles(ADirectory, '*.json');
  for FileName in Files do
  begin
    // Expected filename format: YYYYMMDDHHMMSS_Name.json
    // ID is the filename without extension
    MigrationId := TPath.GetFileNameWithoutExtension(FileName);
    JsonContent := TFile.ReadAllText(FileName);
    
    try
      Migration := TJsonMigration.Create(MigrationId, JsonContent);
      RegisterMigration(Migration);
    except
      on E: Exception do
        WriteLn('Error loading migration ' + FileName + ': ' + E.Message);
    end;
  end;
end;

end.

