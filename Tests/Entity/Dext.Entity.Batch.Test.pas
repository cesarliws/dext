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
{  Created: 2026-07-23                                                      }
{  Summary: Real DB Integration & Benchmark tests for Spec S59 Batch       }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Batch.Test;

interface

uses
  Data.DB,
  System.Classes,
  System.Diagnostics,
  System.Rtti,
  System.SysUtils,
  Dext.Assertions,
  Dext.Collections,
  Dext.Collections.Base,
  Dext.Collections.Dict,
  Dext.Core.Reflection,
  Dext.Core.SmartTypes,
  Dext.Entity,
  Dext.Entity.Attributes,
  Dext.Entity.BatchStrategy,
  Dext.Entity.Context,
  Dext.Entity.Core,
  Dext.Entity.Dialects,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Mapping,
  Dext.Entity.Setup,
  Dext.Specifications.SQL.Generator,
  FireDAC.Comp.Client;

type
  [Table('batch_test_items')]
  TBatchTestItem = class
  private
    FId: Prop<Integer>;
    FName: Prop<string>;
    FPrice: Prop<Integer>;
  public
    [PrimaryKey, AutoInc]
    property Id: Prop<Integer> read FId write FId;
    property Name: Prop<string> read FName write FName;
    property Price: Prop<Integer> read FPrice write FPrice;
  end;

  /// <summary>
  ///   Integration test & benchmark suite for Spec S59 Batch Operations across real DBs.
  /// </summary>
  TBatchStrategyTest = class
  private
    procedure Log(const Msg: string);
    procedure TestDatabaseBatch(const EngineName: string;
      Options: TDbContextOptions; ABatchCount: Integer = 1000);
  public
    procedure Run;
    procedure TestPostgresBatch;
    procedure TestFirebirdBatch;
    procedure TestSqlServerBatch;
    procedure TestMySqlBatch;
  end;

implementation

{ TBatchStrategyTest }

procedure TBatchStrategyTest.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

procedure TBatchStrategyTest.TestDatabaseBatch(const EngineName: string;
  Options: TDbContextOptions; ABatchCount: Integer);
var
  Context: TDbContext;
  Items: IList<TBatchTestItem>;
  ItemArray: TArray<TBatchTestItem>;
  Item: TBatchTestItem;
  i: Integer;
  SwInsert, SwUpdate, SwDelete: TStopwatch;
begin
  Log('  Benchmark & Test for ' + EngineName + ' (' + IntToStr(ABatchCount) + ' items)...');
  try
    Context := TDbContext.Create(Options.BuildConnection, Options.BuildDialect);
    try
      // Register entity set before EnsureCreated
      Context.Entities<TBatchTestItem>;
      Context.EnsureCreated;

      // Clean existing data if any
      try
        Context.Connection.CreateCommand('DELETE FROM batch_test_items').ExecuteNonQuery;
      except
        // Ignore if table does not exist yet
      end;
      
      // 1. Prepare items attached to Context (AddRange Benchmark)
      for i := 1 to ABatchCount do
      begin
        Item := TBatchTestItem.Create;
        Item.Name := 'Item ' + IntToStr(i);
        Item.Price := i * 10;
        Context.Entities<TBatchTestItem>.Add(Item);
      end;

      SwInsert := TStopwatch.StartNew;
      Context.SaveChanges;
      SwInsert.Stop;

      // Retrieve items with populated AutoInc IDs
      Items := Context.Entities<TBatchTestItem>.ToList;
      Log(Format('     [BENCHMARK] %s Insert 1000 items: %d ms',
        [EngineName, SwInsert.ElapsedMilliseconds]));

      // 2. Batch UPDATE via UpdateRange (+ 1000)
      SetLength(ItemArray, Items.Count);
      for i := 0 to Items.Count - 1 do
      begin
        ItemArray[i] := Items[i];
        ItemArray[i].Price := ItemArray[i].Price.Value + 1000;
      end;

      SwUpdate := TStopwatch.StartNew;
      Context.Entities<TBatchTestItem>.UpdateRange(ItemArray);
      SwUpdate.Stop;

      Log(Format('     [BENCHMARK] %s UpdateRange 1000 items: %d ms',
        [EngineName, SwUpdate.ElapsedMilliseconds]));

      // 3. Batch DELETE via RemoveRange
      SwDelete := TStopwatch.StartNew;
      Context.Entities<TBatchTestItem>.RemoveRange(ItemArray);
      SwDelete.Stop;

      Log(Format('     [BENCHMARK] %s RemoveRange 1000 items: %d ms',
        [EngineName, SwDelete.ElapsedMilliseconds]));
    finally
      Context.Free;
    end;
  except
    on E: Exception do
      Log('   [FAIL] ' + EngineName + ' Error: ' + E.Message);
  end;
end;

procedure TBatchStrategyTest.TestPostgresBatch;
var
  Options: TDbContextOptions;
  ConnStr: string;
begin
  Options := TDbContextOptions.Create;
  try
    ConnStr := 'Server=localhost;Port=5432;Database=postgres;User_Name=postgres;Password=root';
    {$IFDEF WIN64}
    if FileExists('C:\Program Files\PostgreSQL\17\bin\libpq.dll') then
      ConnStr := ConnStr + ';VendorLib=C:\Program Files\PostgreSQL\17\bin\libpq.dll';
    {$ENDIF}
    Options.UsePostgreSQL(ConnStr);
    TestDatabaseBatch('PostgreSQL', Options, 1000);
  finally
    Options.Free;
  end;
end;

procedure TBatchStrategyTest.TestFirebirdBatch;
var
  Options: TDbContextOptions;
begin
  Options := TDbContextOptions.Create;
  try
    Options.UseFirebird('Database=C:\temp\dext_batch_test.fdb;User_Name=SYSDBA;Password=masterkey;OpenMode=OpenOrCreate;PageSize=16384');
    TestDatabaseBatch('Firebird', Options, 1000);
  finally
    Options.Free;
  end;
end;

procedure TBatchStrategyTest.TestSqlServerBatch;
var
  Options: TDbContextOptions;
begin
  Options := TDbContextOptions.Create;
  try
    Options.UseSQLServer('Server=localhost;Database=master;OSAuthent=Yes;ODBCAdvanced=TrustServerCertificate=yes');
    TestDatabaseBatch('SQL Server', Options, 1000);
  finally
    Options.Free;
  end;
end;

procedure TBatchStrategyTest.TestMySqlBatch;
var
  Options: TDbContextOptions;
  ConnStr: string;
begin
  Options := TDbContextOptions.Create;
  try
    ConnStr := 'Server=localhost;Port=3306;Database=dext_test;User_Name=root;Password=root';
    {$IFDEF WIN64}
    if FileExists('C:\Program Files\MariaDB 12.1\lib\libmariadb.dll') then
      ConnStr := ConnStr + ';VendorLib=C:\Program Files\MariaDB 12.1\lib\libmariadb.dll';
    {$ENDIF}
    Options.UseMySQL(ConnStr);
    TestDatabaseBatch('MySQL / MariaDB', Options, 1000);
  finally
    Options.Free;
  end;
end;

procedure TBatchStrategyTest.Run;
begin
  Log('🧪 Spec S59 - Real Database Batch Operations Benchmark Suite (1,000 records)');
  Log('========================================================================');
  TestPostgresBatch;
  TestFirebirdBatch;
  TestSqlServerBatch;
  TestMySqlBatch;
  Log('');
end;

end.
