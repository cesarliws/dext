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
unit Dext.Entity.Migrations;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  Dext.Entity.Migrations.Builder;

type
  /// <summary>
  ///   Interface for a single migration step.
  /// </summary>
  IMigration = interface
    ['{8A9B7C6D-5E4F-3A2B-1C0D-9E8F7A6B5C4D}']
    function GetId: string;
    procedure Up(Builder: TSchemaBuilder);
    procedure Down(Builder: TSchemaBuilder);
  end;

  /// <summary>
  ///   Registry for available migrations.
  /// </summary>
  TMigrationRegistry = class
  private
    class var FInstance: TMigrationRegistry;
    FMigrations: TList<IMigration>;
    class function GetInstance: TMigrationRegistry; static;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Register(AMigration: IMigration);
    function GetMigrations: TArray<IMigration>;
    
    class property Instance: TMigrationRegistry read GetInstance;
  end;

procedure RegisterMigration(AMigration: IMigration);

implementation

procedure RegisterMigration(AMigration: IMigration);
begin
  TMigrationRegistry.Instance.Register(AMigration);
end;

{ TMigrationRegistry }

constructor TMigrationRegistry.Create;
begin
  FMigrations := TList<IMigration>.Create;
end;

destructor TMigrationRegistry.Destroy;
begin
  FMigrations.Free;
  inherited;
end;

class function TMigrationRegistry.GetInstance: TMigrationRegistry;
begin
  if FInstance = nil then
    FInstance := TMigrationRegistry.Create;
  Result := FInstance;
end;

function TMigrationRegistry.GetMigrations: TArray<IMigration>;
begin
  // Sort by ID to ensure chronological order
  FMigrations.Sort(TComparer<IMigration>.Construct(
    function(const Left, Right: IMigration): Integer
    begin
      Result := CompareText(Left.GetId, Right.GetId);
    end
  ));
  Result := FMigrations.ToArray;
end;

procedure TMigrationRegistry.Register(AMigration: IMigration);
begin
  FMigrations.Add(AMigration);
end;

initialization

finalization
  TMigrationRegistry.FInstance.Free;

end.

