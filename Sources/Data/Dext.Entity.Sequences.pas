{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
{  Created: 2026-06-19                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Sequences;

interface

uses
  System.Classes,
  System.Rtti,
  System.SyncObjs,
  System.SysUtils,
  System.Variants,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Entity.Dialects,
  Dext.Entity.Drivers.Interfaces;

type
  /// <summary>
  ///   Tracks the low, high and current boundaries of a pre-allocated sequence range (HiLo).
  /// </summary>
  TSequenceRange = class
  public
    Low: Int64;
    High: Int64;
    Current: Int64;
    constructor Create(ALow, AHigh: Int64);
    function NextId(out AId: Int64): Boolean;
  end;

  /// <summary>
  ///   Thread-safe manager for DB sequence HiLo/Pooled allocation ranges.
  /// </summary>
  TSequenceManager = class
  private
    class var FInstance: TSequenceManager;
  private
    FCurrentRanges: IDictionary<string, TSequenceRange>;
    FLock: TCriticalSection;
    FInitializedSQLite: Boolean;
    procedure EnsureSQLiteTable(const AConnection: IDbConnection);
    function FetchNextRangeFromDb(const ASeqName: string; AAllocSize: Integer; const AConnection: IDbConnection; const ADialect: ISQLDialect): TSequenceRange;
    class constructor Create;
    class destructor Destroy;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>
    ///   Thread-safe entry point to generate a new sequential ID from a sequence.
    /// </summary>
    function GenerateId(const ASequenceName: string; AAllocationSize: Integer; const AConnection: IDbConnection; const ADialect: ISQLDialect): Int64;
    
    class property Instance: TSequenceManager read FInstance;
  end;

implementation

{ TSequenceRange }

constructor TSequenceRange.Create(ALow, AHigh: Int64);
begin
  inherited Create;
  Low := ALow;
  High := AHigh;
  Current := ALow;
end;

function TSequenceRange.NextId(out AId: Int64): Boolean;
begin
  if Current <= High then
  begin
    AId := Current;
    Inc(Current);
    Result := True;
  end
  else
    Result := False;
end;

{ TSequenceManager }

class constructor TSequenceManager.Create;
begin
  FInstance := TSequenceManager.Create;
end;

class destructor TSequenceManager.Destroy;
begin
  FreeAndNil(FInstance);
end;

constructor TSequenceManager.Create;
begin
  inherited Create;
  FCurrentRanges := TCollections.CreateDictionaryIgnoreCase<string, TSequenceRange>(True);
  FLock := TCriticalSection.Create;
  FInitializedSQLite := False;
end;

destructor TSequenceManager.Destroy;
var
  Pair: TPair<string, TSequenceRange>;
begin
  FLock.Acquire;
  try
    for Pair in FCurrentRanges do
      Pair.Value.Free;
    FCurrentRanges := nil;
  finally
    FLock.Release;
  end;
  FLock.Free;
  inherited;
end;

procedure TSequenceManager.EnsureSQLiteTable(const AConnection: IDbConnection);
var
  Cmd: IDbCommand;
begin
  if FInitializedSQLite then Exit;

  // Emulate sequence table for SQLite
  Cmd := AConnection.CreateCommand(
    'CREATE TABLE IF NOT EXISTS dext_sequences (name VARCHAR(255) PRIMARY KEY, nextval BIGINT);'
  );
  try
    Cmd.ExecuteNonQuery;
  finally
    Cmd := nil;
  end;
  FInitializedSQLite := True;
end;

function TSequenceManager.FetchNextRangeFromDb(const ASeqName: string; AAllocSize: Integer;
  const AConnection: IDbConnection; const ADialect: ISQLDialect): TSequenceRange;
var
  Cmd: IDbCommand;
  Reader: IDbReader;
  NextVal: Int64;
  SQL: string;
  Val: TValue;
begin
  if ADialect.GetDialect = ddSQLite then
  begin
    EnsureSQLiteTable(AConnection);
    
    // Seed sequence if not present
    Cmd := AConnection.CreateCommand(
      'INSERT OR IGNORE INTO dext_sequences (name, nextval) VALUES (:name, 0);'
    );
    try
      Cmd.AddParam('name', ASeqName);
      Cmd.ExecuteNonQuery;
    finally
      Cmd := nil;
    end;

    // Increment sequence by allocation size
    Cmd := AConnection.CreateCommand(
      'UPDATE dext_sequences SET nextval = nextval + :allocSize WHERE name = :name;'
    );
    try
      Cmd.AddParam('allocSize', AAllocSize);
      Cmd.AddParam('name', ASeqName);
      Cmd.ExecuteNonQuery;
    finally
      Cmd := nil;
    end;
  end;

  SQL := ADialect.GetSequenceNextValSQL(ASeqName);
  Cmd := AConnection.CreateCommand(SQL);
  try
    Reader := Cmd.ExecuteQuery;
    try
      if Reader.Next then
      begin
        Val := Reader.GetValue(0);
        NextVal := Val.AsInt64;
      end
      else
        raise Exception.CreateFmt('Failed to fetch next value for sequence %s', [ASeqName]);
    finally
      Reader.Close;
      Reader := nil;
    end;
  finally
    Cmd := nil;
  end;

  // Pooled-lo allocation:
  // NextVal is the new high-boundary returned by the sequence.
  // The range is [NextVal - AAllocSize + 1, NextVal]
  Result := TSequenceRange.Create(NextVal - AAllocSize + 1, NextVal);
end;

function TSequenceManager.GenerateId(const ASequenceName: string; AAllocationSize: Integer;
  const AConnection: IDbConnection; const ADialect: ISQLDialect): Int64;
var
  Range: TSequenceRange;
  GotId: Boolean;
begin
  FLock.Acquire;
  try
    if not FCurrentRanges.TryGetValue(ASequenceName, Range) then
    begin
      Range := FetchNextRangeFromDb(ASequenceName, AAllocationSize, AConnection, ADialect);
      FCurrentRanges.Add(ASequenceName, Range);
    end;

    GotId := Range.NextId(Result);
    if not GotId then
    begin
      // Range exhausted, fetch next block
      Range.Free;
      Range := FetchNextRangeFromDb(ASequenceName, AAllocationSize, AConnection, ADialect);
      FCurrentRanges.AddOrSetValue(ASequenceName, Range);
      if not Range.NextId(Result) then
        raise Exception.CreateFmt('Failed to generate next ID for sequence %s', [ASequenceName]);
    end;
  finally
    FLock.Release;
  end;
end;

end.
