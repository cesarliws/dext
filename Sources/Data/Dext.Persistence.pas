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
unit Dext.Persistence;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  FireDAC.Comp.Client,
  System.SysUtils,
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Entity.DbSet,
  Dext.Entity.Attributes,
  Dext.Entity.Query,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Fluent,
  Dext.Entity.Grouping,
  Dext.Entity.Joining,
  Dext.Types.Lazy,
  Dext.Specifications.Types,
  // New Units
  Dext.Entity.Dialects,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.LazyLoading,
  Dext.Entity.Mapping,
  Dext.Entity.Migrations,
  Dext.Entity.Migrations.Builder,
  Dext.Entity.Migrations.Differ,
  Dext.Entity.Migrations.Extractor,
  Dext.Entity.Migrations.Generator,
  Dext.Entity.Migrations.Json,
  Dext.Entity.Migrations.Model,
  Dext.Entity.Migrations.Operations,
  Dext.Entity.Migrations.Runner,
  Dext.Entity.Naming,
  Dext.Entity.Scaffolding,
  Dext.Entity.Drivers.FireDAC,
  Dext.Specifications.SQL.Generator;

type
  TFDConnection = FireDAC.Comp.Client.TFDConnection;
  TFireDACConnection = Dext.Entity.Drivers.FireDAC.TFireDACConnection;
  TFireDACTransaction = Dext.Entity.Drivers.FireDAC.TFireDACTransaction;
  TFireDACReader = Dext.Entity.Drivers.FireDAC.TFireDACReader;
  TFireDACCommand = Dext.Entity.Drivers.FireDAC.TFireDACCommand;

  // Core Interfaces
  IDbContext = Dext.Entity.Core.IDbContext;
  IDbSet = Dext.Entity.Core.IDbSet;
  TDbContext = Dext.Entity.TDbContext;
  
  // Exceptions
  EOptimisticConcurrencyException = Dext.Entity.Core.EOptimisticConcurrencyException;

  IExpression = Dext.Specifications.Interfaces.IExpression;
  IChangeTracker = Dext.Entity.Core.IChangeTracker;
  ICollectionEntry = Dext.Entity.Core.ICollectionEntry;
  IReferenceEntry = Dext.Entity.Core.IReferenceEntry;
  IEntityEntry = Dext.Entity.Core.IEntityEntry;
  
  // Specification Builder Helper (Static Class)
  Specification = Dext.Specifications.Fluent.Specification;

  // Query Helpers
  TQueryGrouping = Dext.Entity.Grouping.TQuery;
  TQueryJoin = Dext.Entity.Joining.TJoining;

  // Driver Interfaces
  IDbConnection = Dext.Entity.Drivers.Interfaces.IDbConnection;
  IDbTransaction = Dext.Entity.Drivers.Interfaces.IDbTransaction;
  IDbCommand = Dext.Entity.Drivers.Interfaces.IDbCommand;
  IDbReader = Dext.Entity.Drivers.Interfaces.IDbReader;
  ISQLDialect = Dext.Entity.Dialects.ISQLDialect;

  // Dialects
  TBaseDialect = Dext.Entity.Dialects.TBaseDialect;
  TSQLiteDialect = Dext.Entity.Dialects.TSQLiteDialect;
  TPostgreSQLDialect = Dext.Entity.Dialects.TPostgreSQLDialect;
  TFirebirdDialect = Dext.Entity.Dialects.TFirebirdDialect;
  TSQLServerDialect = Dext.Entity.Dialects.TSQLServerDialect;
  TMySQLDialect = Dext.Entity.Dialects.TMySQLDialect;
  TOracleDialect = Dext.Entity.Dialects.TOracleDialect;

  // Mapping
  TModelBuilder = Dext.Entity.Mapping.TModelBuilder;
  
  // Migrations - Interfaces
  IMigration = Dext.Entity.Migrations.IMigration;
  IColumnBuilder = Dext.Entity.Migrations.Builder.IColumnBuilder;

  // Migrations - Core Classes
  TMigrationRegistry = Dext.Entity.Migrations.TMigrationRegistry;
  TMigrator = Dext.Entity.Migrations.Runner.TMigrator;
  
  // Migrations - Builders & Generators
  TSchemaBuilder = Dext.Entity.Migrations.Builder.TSchemaBuilder;
  TTableBuilder = Dext.Entity.Migrations.Builder.TTableBuilder;
  TColumnBuilder = Dext.Entity.Migrations.Builder.TColumnBuilder;
  TMigrationGenerator = Dext.Entity.Migrations.Generator.TMigrationGenerator;
  TJsonMigration = Dext.Entity.Migrations.Json.TJsonMigration;
  TJsonMigrationLoader = Dext.Entity.Migrations.Json.TJsonMigrationLoader;

  // Migrations - Model Extractors & Differs
  TModelDiffer = Dext.Entity.Migrations.Differ.TModelDiffer;
  TDbContextModelExtractor = Dext.Entity.Migrations.Extractor.TDbContextModelExtractor;
  
  // Migrations - Operations
  TMigrationOperation = Dext.Entity.Migrations.Operations.TMigrationOperation;
  TCreateTableOperation = Dext.Entity.Migrations.Operations.TCreateTableOperation;
  TDropTableOperation = Dext.Entity.Migrations.Operations.TDropTableOperation;
  TAddColumnOperation = Dext.Entity.Migrations.Operations.TAddColumnOperation;
  TDropColumnOperation = Dext.Entity.Migrations.Operations.TDropColumnOperation;
  TAlterColumnOperation = Dext.Entity.Migrations.Operations.TAlterColumnOperation;
  TAddForeignKeyOperation = Dext.Entity.Migrations.Operations.TAddForeignKeyOperation;
  TDropForeignKeyOperation = Dext.Entity.Migrations.Operations.TDropForeignKeyOperation;
  TCreateIndexOperation = Dext.Entity.Migrations.Operations.TCreateIndexOperation;
  TDropIndexOperation = Dext.Entity.Migrations.Operations.TDropIndexOperation;
  TSqlOperation = Dext.Entity.Migrations.Operations.TSqlOperation;

  // Migrations - Snapshot Model
  TSnapshotModel = Dext.Entity.Migrations.Model.TSnapshotModel;
  TSnapshotTable = Dext.Entity.Migrations.Model.TSnapshotTable;
  TSnapshotColumn = Dext.Entity.Migrations.Model.TSnapshotColumn;
  TSnapshotForeignKey = Dext.Entity.Migrations.Model.TSnapshotForeignKey;

  // Naming
  INamingStrategy = Dext.Entity.Naming.INamingStrategy;
  TDefaultNamingStrategy = Dext.Entity.Naming.TDefaultNamingStrategy;
  TSnakeCaseNamingStrategy = Dext.Entity.Naming.TSnakeCaseNamingStrategy;
  TLowerCaseNamingStrategy = Dext.Entity.Naming.TLowerCaseNamingStrategy;
  TUppercaseNamingStrategy = Dext.Entity.Naming.TUppercaseNamingStrategy;

  // Scaffolding
  ISchemaProvider = Dext.Entity.Scaffolding.ISchemaProvider;
  IEntityGenerator = Dext.Entity.Scaffolding.IEntityGenerator;
  TFireDACSchemaProvider = Dext.Entity.Scaffolding.TFireDACSchemaProvider;
  TDelphiEntityGenerator = Dext.Entity.Scaffolding.TDelphiEntityGenerator;

  // SQL Generation
  ISQLColumnMapper = Dext.Specifications.SQL.Generator.ISQLColumnMapper;

  // Atributes
  TableAttribute = Dext.Entity.Attributes.TableAttribute;
  ColumnAttribute = Dext.Entity.Attributes.ColumnAttribute;
  PKAttribute = Dext.Entity.Attributes.PKAttribute;
  AutoIncAttribute = Dext.Entity.Attributes.AutoIncAttribute;
  ForeignKeyAttribute = Dext.Entity.Attributes.ForeignKeyAttribute;
  NotMappedAttribute = Dext.Entity.Attributes.NotMappedAttribute;
  VersionAttribute = Dext.Entity.Attributes.VersionAttribute;
  SoftDeleteAttribute = Dext.Entity.Attributes.SoftDeleteAttribute;
  
  // Enums (Type Aliases)
  TCascadeAction = Dext.Entity.Attributes.TCascadeAction;

  Lazy<T> = record
  private
    FInstance: ILazy;
    function GetIsValueCreated: Boolean;
    function GetValue: T;
  public
    class function Create: Lazy<T>; overload; static;
    constructor Create(const AValueFactory: TFunc<T>; AOwnsValue: Boolean = True); overload;
    constructor CreateFrom(const AValue: T; AOwnsValue: Boolean = False);

    class operator Implicit(const Value: Lazy<T>): T;
    class operator Implicit(const Value: T): Lazy<T>;
    class operator Implicit(const ValueFactory: TFunc<T>): Lazy<T>;

    property IsValueCreated: Boolean read GetIsValueCreated;
    property Value: T read GetValue;
  end;



  /// <summary>
  ///   Helper record to build expressions fluently.
  ///   Usage: PropExpression('Age') > 18
  /// </summary>
  TPropExpression = Dext.Specifications.Types.TPropExpression;


const
  caNoAction = Dext.Entity.Attributes.TCascadeAction.caNoAction;
  caCascade = Dext.Entity.Attributes.TCascadeAction.caCascade;
  caSetNull = Dext.Entity.Attributes.TCascadeAction.caSetNull;
  caRestrict = Dext.Entity.Attributes.TCascadeAction.caRestrict;

implementation

uses
  System.Rtti,
  Dext.Specifications.OrderBy;

{ Lazy<T> }

class function Lazy<T>.Create: Lazy<T>;
begin
  // Default constructor returns empty/default
  Result.FInstance := TValueLazy<T>.Create(Default(T));
end;

constructor Lazy<T>.Create(const AValueFactory: TFunc<T>; AOwnsValue: Boolean);
begin
  FInstance := TLazy<T>.Create(AValueFactory, AOwnsValue);
end;

constructor Lazy<T>.CreateFrom(const AValue: T; AOwnsValue: Boolean = False);
begin
  FInstance := TValueLazy<T>.Create(AValue, AOwnsValue);
end;

function Lazy<T>.GetIsValueCreated: Boolean;
begin
  if FInstance <> nil then
    Result := FInstance.IsValueCreated
  else
    Result := False;
end;

function Lazy<T>.GetValue: T;
begin
  if FInstance <> nil then
    Result := FInstance.Value.AsType<T>
  else
    Result := Default(T);
end;

class operator Lazy<T>.Implicit(const Value: Lazy<T>): T;
begin
  Result := Value.Value;
end;

class operator Lazy<T>.Implicit(const Value: T): Lazy<T>;
begin
  Result.CreateFrom(Value);
end;

class operator Lazy<T>.Implicit(const ValueFactory: TFunc<T>): Lazy<T>;
begin
  Result.Create(ValueFactory);
end;


end.

