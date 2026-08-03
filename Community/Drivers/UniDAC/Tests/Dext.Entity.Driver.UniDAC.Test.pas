unit Dext.Entity.Driver.UniDAC.Test;

interface

uses
  Dext.Testing.Core,
  Uni,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Drivers.UniDAC;

type
  [TestFixture('Dext.Entity.Driver.UniDAC')]
  TDextEntityDriverUniDACTest = class
  private
    FUniConn: TUniConnection;
    FConn: IDbConnection;
  public
    [SetUp]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestConnection;
    [Test]
    procedure TestQueryExecution;
    [Test]
    procedure TestTransactionCommit;
    [Test]
    procedure TestTransactionRollback;
  end;

implementation

procedure TDextEntityDriverUniDACTest.SetUp;
begin
  FUniConn := TUniConnection.Create(nil);
  FUniConn.ProviderName := 'SQLite';
  FUniConn.Database := ':memory:';
  FUniConn.Connect;
  FConn := TDextUniDACConnection.Create(FUniConn, True);
end;

procedure TDextEntityDriverUniDACTest.TearDown;
begin
  FConn := nil;
end;

procedure TDextEntityDriverUniDACTest.TestConnection;
begin
  Assert.IsTrue(FConn.IsConnected);
end;

procedure TDextEntityDriverUniDACTest.TestQueryExecution;
var
  Cmd: IDbCommand;
  Reader: IDbReader;
begin
  Cmd := FConn.CreateCommand('CREATE TABLE test_table (id INTEGER, name TEXT);');
  Cmd.ExecuteNonQuery;

  Cmd := FConn.CreateCommand('INSERT INTO test_table (id, name) VALUES (:id, :name);');
  Cmd.AddParam('id', 1);
  Cmd.AddParam('name', 'UniDAC Test');
  Cmd.ExecuteNonQuery;

  Cmd := FConn.CreateCommand('SELECT * FROM test_table;');
  Reader := Cmd.ExecuteReader;
  Assert.IsTrue(Reader.Next);
  Assert.AreEqual(1, Integer(Reader.GetValue('id')));
  Assert.AreEqual('UniDAC Test', string(Reader.GetValue('name')));
end;

procedure TDextEntityDriverUniDACTest.TestTransactionCommit;
var
  Tx: IDbTransaction;
  Cmd: IDbCommand;
  Reader: IDbReader;
begin
  Cmd := FConn.CreateCommand('CREATE TABLE tx_test (id INTEGER);');
  Cmd.ExecuteNonQuery;

  Tx := FConn.BeginTransaction;
  Cmd := FConn.CreateCommand('INSERT INTO tx_test (id) VALUES (100);');
  Cmd.ExecuteNonQuery;
  Tx.Commit;

  Cmd := FConn.CreateCommand('SELECT COUNT(*) FROM tx_test;');
  Reader := Cmd.ExecuteReader;
  Assert.IsTrue(Reader.Next);
  Assert.AreEqual(1, Integer(Reader.GetValue(0)));
end;

procedure TDextEntityDriverUniDACTest.TestTransactionRollback;
var
  Tx: IDbTransaction;
  Cmd: IDbCommand;
  Reader: IDbReader;
begin
  Cmd := FConn.CreateCommand('CREATE TABLE tx_roll (id INTEGER);');
  Cmd.ExecuteNonQuery;

  Tx := FConn.BeginTransaction;
  Cmd := FConn.CreateCommand('INSERT INTO tx_roll (id) VALUES (200);');
  Cmd.ExecuteNonQuery;
  Tx.Rollback;

  Cmd := FConn.CreateCommand('SELECT COUNT(*) FROM tx_roll;');
  Reader := Cmd.ExecuteReader;
  Assert.IsTrue(Reader.Next);
  Assert.AreEqual(0, Integer(Reader.GetValue(0)));
end;

end.
