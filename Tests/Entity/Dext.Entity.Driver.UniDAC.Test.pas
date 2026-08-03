unit Dext.Entity.Driver.UniDAC.Test;

/// <summary>
///   Unit tests for TUniDACConnection, TUniDACCommand, TUniDACReader,
///   and TUniDACTransaction.
///   Requires: DEXT_USE_UNIDAC defined AND UniDAC SQLite provider installed.
///   Uses SQLite in-memory database (Database=':memory:') for isolation.
/// </summary>

interface

{$I Dext.inc}

{$IFDEF DEXT_USE_UNIDAC}

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Rtti,
  Data.DB,
  Uni,
  Dext.Entity.Drivers.UniDAC,
  Dext.Entity.Drivers.UniDAC.Manager,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Setup;

type
  [TestFixture]
  TUniDACDriverTest = class
  private
    FConn: TUniConnection;
    FDextConn: IDbConnection;
    procedure CreateTestTable;
    function MakeConnection: TUniConnection;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Connection_ConnectDisconnect;

    [Test]
    procedure Test_Connection_IsPooled_ReturnsFalse_WhenNotPooled;

    [Test]
    procedure Test_Connection_DialectDetection_SQLite;

    [Test]
    procedure Test_Command_ExecuteNonQuery_CreateTable;

    [Test]
    procedure Test_Command_ExecuteQuery_EmptyTable;

    [Test]
    procedure Test_Command_ExecuteQuery_WithRows;

    [Test]
    procedure Test_Command_ExecuteScalar_Count;

    [Test]
    procedure Test_Reader_Next_IteratesAllRows;

    [Test]
    procedure Test_Reader_GetValue_ByName_AndByIndex;

    [Test]
    procedure Test_Command_AddParam_String;

    [Test]
    procedure Test_Command_AddParam_Integer;

    [Test]
    procedure Test_Command_AddParam_Null;

    [Test]
    procedure Test_Transaction_Commit;

    [Test]
    procedure Test_Transaction_Rollback;

    [Test]
    procedure Test_Batch_SimulatedLoop;

    [Test]
    procedure Test_TableExists_ReturnsTrue_WhenExists;

    [Test]
    procedure Test_TableExists_ReturnsFalse_WhenNotExists;

    [Test]
    /// <summary>
    ///   Tests fallback via SELECT last_insert_rowid() — for cases where
    ///   the INSERT was executed without a RETURNING clause.
    /// </summary>
    procedure Test_GetLastInsertId_Fallback_SQLite;

    [Test]
    /// <summary>
    ///   Tests the PREFERRED UniDAC pattern:
    ///   INSERT ... RETURNING id → read via GetParamValue('RET_ID').
    ///   UniDAC automatically creates an output param with prefix RET_
    ///   for each column listed in the RETURNING clause.
    /// </summary>
    procedure Test_GetLastInsertId_ViaReturning_SQLite;
  end;

{$ENDIF DEXT_USE_UNIDAC}

implementation

{$IFDEF DEXT_USE_UNIDAC}

{ TUniDACDriverTest }

function TUniDACDriverTest.MakeConnection: TUniConnection;
begin
  Result := TUniConnection.Create(nil);
  Result.ProviderName := 'SQLite';
  Result.SpecificOptions.Values['Database'] := ':memory:';
  Result.SpecificOptions.Values['UseUnicode'] := 'True';
end;

procedure TUniDACDriverTest.CreateTestTable;
var
  Cmd: IDbCommand;
begin
  Cmd := FDextConn.CreateCommand(
    'CREATE TABLE IF NOT EXISTS test_items (' +
    '  id   INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  name TEXT NOT NULL,' +
    '  val  INTEGER' +
    ')');
  Cmd.Execute;
end;

procedure TUniDACDriverTest.Setup;
begin
  FConn := MakeConnection;
  FDextConn := TUniDACConnection.Create(FConn, False); // FConn owned separately
  FDextConn.Connect;
  CreateTestTable;
end;

procedure TUniDACDriverTest.TearDown;
begin
  FDextConn.Disconnect;
  FDextConn := nil;
  FConn.Free;
end;

procedure TUniDACDriverTest.Test_Connection_ConnectDisconnect;
begin
  Assert.IsTrue(FDextConn.IsConnected, 'Should be connected after Setup');
  FDextConn.Disconnect;
  Assert.IsFalse(FDextConn.IsConnected, 'Should be disconnected');
  FDextConn.Connect;
  Assert.IsTrue(FDextConn.IsConnected, 'Should reconnect');
end;

procedure TUniDACDriverTest.Test_Connection_IsPooled_ReturnsFalse_WhenNotPooled;
begin
  Assert.IsFalse(FDextConn.IsPooled, 'Non-pooled connection should return False');
end;

procedure TUniDACDriverTest.Test_Connection_DialectDetection_SQLite;
begin
  Assert.AreEqual(ddSQLite, FDextConn.Dialect, 'SQLite provider should detect ddSQLite');
end;

procedure TUniDACDriverTest.Test_Command_ExecuteNonQuery_CreateTable;
var
  Cmd: IDbCommand;
  RowsAffected: Integer;
begin
  Cmd := FDextConn.CreateCommand(
    'CREATE TABLE IF NOT EXISTS temp_test (id INTEGER, name TEXT)');
  RowsAffected := Cmd.ExecuteNonQuery;
  // SQLite returns 0 for DDL — just check no exception is raised
  Assert.IsTrue(RowsAffected >= 0, 'DDL should succeed without exception');
end;

procedure TUniDACDriverTest.Test_Command_ExecuteQuery_EmptyTable;
var
  Cmd: IDbCommand;
  Reader: IDbReader;
begin
  Cmd := FDextConn.CreateCommand('SELECT * FROM test_items');
  Reader := Cmd.ExecuteQuery;
  Assert.IsFalse(Reader.Next, 'Empty table should return no rows');
  Reader.Close;
end;

procedure TUniDACDriverTest.Test_Command_ExecuteQuery_WithRows;
var
  InsertCmd, SelectCmd: IDbCommand;
  Reader: IDbReader;
  RowCount: Integer;
begin
  // Insert 3 rows
  InsertCmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (:name, :val)');
  InsertCmd.AddParam('name', TValue.From<string>('Alpha'));
  InsertCmd.AddParam('val', TValue.From<Integer>(1));
  InsertCmd.Execute;
  InsertCmd.ClearParams;
  InsertCmd.AddParam('name', TValue.From<string>('Beta'));
  InsertCmd.AddParam('val', TValue.From<Integer>(2));
  InsertCmd.Execute;
  InsertCmd.ClearParams;
  InsertCmd.AddParam('name', TValue.From<string>('Gamma'));
  InsertCmd.AddParam('val', TValue.From<Integer>(3));
  InsertCmd.Execute;

  SelectCmd := FDextConn.CreateCommand('SELECT * FROM test_items ORDER BY id');
  Reader := SelectCmd.ExecuteQuery;
  RowCount := 0;
  while Reader.Next do
    Inc(RowCount);
  Reader.Close;

  Assert.AreEqual(3, RowCount, 'Should read 3 inserted rows');
end;

procedure TUniDACDriverTest.Test_Command_ExecuteScalar_Count;
var
  InsertCmd, ScalarCmd: IDbCommand;
  Result: TValue;
begin
  InsertCmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (:name, :val)');
  InsertCmd.AddParam('name', TValue.From<string>('Item1'));
  InsertCmd.AddParam('val', TValue.From<Integer>(10));
  InsertCmd.Execute;

  ScalarCmd := FDextConn.CreateCommand('SELECT COUNT(*) FROM test_items');
  Result := ScalarCmd.ExecuteScalar;
  Assert.IsFalse(Result.IsEmpty, 'Scalar result should not be empty');
  Assert.IsTrue(Result.AsInt64 >= 1, 'Count should be at least 1');
end;

procedure TUniDACDriverTest.Test_Reader_Next_IteratesAllRows;
var
  Cmd: IDbCommand;
  Reader: IDbReader;
  Count: Integer;
begin
  // Insert 5 rows directly via native connection for speed
  FConn.ExecSQL('INSERT INTO test_items (name, val) VALUES (''R1'', 1)');
  FConn.ExecSQL('INSERT INTO test_items (name, val) VALUES (''R2'', 2)');
  FConn.ExecSQL('INSERT INTO test_items (name, val) VALUES (''R3'', 3)');
  FConn.ExecSQL('INSERT INTO test_items (name, val) VALUES (''R4'', 4)');
  FConn.ExecSQL('INSERT INTO test_items (name, val) VALUES (''R5'', 5)');

  Cmd := FDextConn.CreateCommand('SELECT id FROM test_items');
  Reader := Cmd.ExecuteQuery;
  Count := 0;
  while Reader.Next do Inc(Count);
  Reader.Close;

  Assert.AreEqual(5, Count, 'Should iterate all 5 rows');
end;

procedure TUniDACDriverTest.Test_Reader_GetValue_ByName_AndByIndex;
var
  InsertCmd, SelectCmd: IDbCommand;
  Reader: IDbReader;
  ValByName, ValByIndex: TValue;
begin
  InsertCmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (:name, :val)');
  InsertCmd.AddParam('name', TValue.From<string>('TestRead'));
  InsertCmd.AddParam('val', TValue.From<Integer>(42));
  InsertCmd.Execute;

  SelectCmd := FDextConn.CreateCommand(
    'SELECT name, val FROM test_items WHERE name = :name');
  SelectCmd.AddParam('name', TValue.From<string>('TestRead'));
  Reader := SelectCmd.ExecuteQuery;

  Assert.IsTrue(Reader.Next, 'Should have one row');
  ValByName  := Reader.GetValue('name');
  ValByIndex := Reader.GetValue(1);  // val is at index 1
  Reader.Close;

  Assert.AreEqual('TestRead', ValByName.AsString, 'name by column name');
  Assert.AreEqual(42, ValByIndex.AsInteger, 'val by column index');
end;

procedure TUniDACDriverTest.Test_Command_AddParam_String;
var
  InsertCmd, SelectCmd: IDbCommand;
  Reader: IDbReader;
begin
  InsertCmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (:name, :val)');
  InsertCmd.AddParam('name', TValue.From<string>('ParamTest'));
  InsertCmd.AddParam('val', TValue.From<Integer>(99));
  InsertCmd.Execute;

  SelectCmd := FDextConn.CreateCommand(
    'SELECT name FROM test_items WHERE val = :val');
  SelectCmd.AddParam('val', TValue.From<Integer>(99));
  Reader := SelectCmd.ExecuteQuery;
  Assert.IsTrue(Reader.Next);
  Assert.AreEqual('ParamTest', Reader.GetValue('name').AsString);
  Reader.Close;
end;

procedure TUniDACDriverTest.Test_Command_AddParam_Integer;
var
  InsertCmd, SelectCmd: IDbCommand;
  Reader: IDbReader;
begin
  InsertCmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (:name, :val)');
  InsertCmd.AddParam('name', TValue.From<string>('IntTest'));
  InsertCmd.AddParam('val', TValue.From<Integer>(777));
  InsertCmd.Execute;

  SelectCmd := FDextConn.CreateCommand(
    'SELECT val FROM test_items WHERE name = :name');
  SelectCmd.AddParam('name', TValue.From<string>('IntTest'));
  Reader := SelectCmd.ExecuteQuery;
  Assert.IsTrue(Reader.Next);
  Assert.AreEqual(777, Reader.GetValue(0).AsInteger);
  Reader.Close;
end;

procedure TUniDACDriverTest.Test_Command_AddParam_Null;
var
  InsertCmd, SelectCmd: IDbCommand;
  Reader: IDbReader;
  V: TValue;
begin
  InsertCmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (:name, :val)');
  InsertCmd.AddParam('name', TValue.From<string>('NullTest'));
  InsertCmd.AddParam('val', TValue.Empty);  // NULL
  InsertCmd.Execute;

  SelectCmd := FDextConn.CreateCommand(
    'SELECT val FROM test_items WHERE name = :name');
  SelectCmd.AddParam('name', TValue.From<string>('NullTest'));
  Reader := SelectCmd.ExecuteQuery;
  Assert.IsTrue(Reader.Next);
  V := Reader.GetValue('val');
  Assert.IsTrue(V.IsEmpty, 'NULL column should return TValue.Empty');
  Reader.Close;
end;

procedure TUniDACDriverTest.Test_Transaction_Commit;
var
  TX: IDbTransaction;
  Cmd: IDbCommand;
  Scalar: TValue;
begin
  TX := FDextConn.BeginTransaction;
  Cmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (''TxCommit'', 1)');
  Cmd.Execute;
  TX.Commit;

  Scalar := FDextConn.CreateCommand(
    'SELECT COUNT(*) FROM test_items WHERE name=''TxCommit''').ExecuteScalar;
  Assert.AreEqual(Int64(1), Scalar.AsInt64, 'Committed row must be visible');
end;

procedure TUniDACDriverTest.Test_Transaction_Rollback;
var
  TX: IDbTransaction;
  Cmd: IDbCommand;
  Scalar: TValue;
begin
  TX := FDextConn.BeginTransaction;
  Cmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (''TxRollback'', 2)');
  Cmd.Execute;
  TX.Rollback;

  Scalar := FDextConn.CreateCommand(
    'SELECT COUNT(*) FROM test_items WHERE name=''TxRollback''').ExecuteScalar;
  Assert.AreEqual(Int64(0), Scalar.AsInt64,
    'Rolled-back row must NOT be visible');
end;

procedure TUniDACDriverTest.Test_Batch_SimulatedLoop;
var
  Cmd: IDbCommand;
  Names: TArray<TValue>;
  Vals:  TArray<TValue>;
  ScalarCmd: IDbCommand;
  Count: TValue;
begin
  // Prepare 4 rows as arrays
  Names := [TValue.From<string>('B1'), TValue.From<string>('B2'),
            TValue.From<string>('B3'), TValue.From<string>('B4')];
  Vals  := [TValue.From<Integer>(10), TValue.From<Integer>(20),
            TValue.From<Integer>(30), TValue.From<Integer>(40)];

  Cmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (:name, :val)');
  Cmd.SetArraySize(4);
  Cmd.SetParamArray('name', Names);
  Cmd.SetParamArray('val',  Vals);
  Cmd.ExecuteBatch(4, 0);

  ScalarCmd := FDextConn.CreateCommand(
    'SELECT COUNT(*) FROM test_items WHERE name LIKE ''B%''');
  Count := ScalarCmd.ExecuteScalar;
  Assert.AreEqual(Int64(4), Count.AsInt64, 'All 4 batch rows must be inserted');
end;

procedure TUniDACDriverTest.Test_TableExists_ReturnsTrue_WhenExists;
begin
  Assert.IsTrue(FDextConn.TableExists('test_items'),
    'test_items was created in Setup, should exist');
end;

procedure TUniDACDriverTest.Test_TableExists_ReturnsFalse_WhenNotExists;
begin
  Assert.IsFalse(FDextConn.TableExists('no_such_table_xyz'),
    'Non-existent table should return False');
end;

procedure TUniDACDriverTest.Test_GetLastInsertId_Fallback_SQLite;
var
  InsertCmd: IDbCommand;
  LastId: Variant;
begin
  // Execute INSERT without RETURNING — use fallback SELECT last_insert_rowid().
  InsertCmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (''IdFallback'', 55)');
  InsertCmd.Execute;

  LastId := FDextConn.GetLastInsertId;
  Assert.IsFalse(VarIsNull(LastId) or VarIsEmpty(LastId),
    'Fallback GetLastInsertId should return a non-null value for SQLite');
  Assert.IsTrue(Integer(LastId) > 0, 'Last insert ID should be positive');
end;

procedure TUniDACDriverTest.Test_GetLastInsertId_ViaReturning_SQLite;
var
  InsertCmd: IDbCommand;
  ReturnedId: TValue;
begin
  // -----------------------------------------------------------------
  // UniDAC canonical pattern for last-insert-ID:
  //   1. Append "RETURNING <pk_column>" to the INSERT SQL.
  //   2. UniDAC auto-creates an output param named "RET_<COLUMN>".
  //      (The column name is uppercased, prefixed with RET_.)
  //   3. After Execute, read the value via GetParamValue('RET_ID').
  //
  // This works for SQLite >= 3.35, PostgreSQL, Firebird 2.1+,
  // Oracle, and SQL Server (OUTPUT INSERTED.id ... but syntax differs).
  // -----------------------------------------------------------------
  InsertCmd := FDextConn.CreateCommand(
    'INSERT INTO test_items (name, val) VALUES (:name, :val) RETURNING id');
  InsertCmd.AddParam('name', TValue.From<string>('IdReturning'));
  InsertCmd.AddParam('val',  TValue.From<Integer>(99));
  InsertCmd.Execute;

  // UniDAC places the returned id in param named 'RET_ID'
  ReturnedId := InsertCmd.GetParamValue('RET_ID');

  Assert.IsFalse(ReturnedId.IsEmpty,
    'RET_ID param must not be empty after INSERT ... RETURNING id');
  Assert.IsTrue(ReturnedId.AsInt64 > 0,
    'Returned ID must be a positive integer');
end;

{$ENDIF DEXT_USE_UNIDAC}

initialization
  {$IFDEF DEXT_USE_UNIDAC}
  TDUnitX.RegisterTestFixture(TUniDACDriverTest);
  {$ENDIF}

end.

