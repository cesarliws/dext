unit Dext.Entity.Migrations.Json.Tests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Dext.Entity.Migrations.Operations,
  Dext.Entity.Migrations.Serializers.Json,
  Dext.Json,
  Dext.Json.Types;

type
  [TestFixture]
  TMigrationJsonTests = class
  public
    [Test]
    procedure TestSerializeDeserialize_CreateTable;
    [Test]
    procedure TestSerializeDeserialize_AddColumn;
  end;

implementation

{ TMigrationJsonTests }

procedure TMigrationJsonTests.TestSerializeDeserialize_CreateTable;
var
  Op: TCreateTableOperation;
  Ops: TObjectList<TMigrationOperation>;
  Json: string;
  DeserializedOps: TObjectList<TMigrationOperation>;
  DeserializedOp: TCreateTableOperation;
begin
  Ops := TObjectList<TMigrationOperation>.Create;
  try
    Op := TCreateTableOperation.Create('Users');
    Op.Columns.Add(TColumnDefinition.Create('Id', 'GUID'));
    Op.Columns[0].IsPrimaryKey := True;
    Op.Columns.Add(TColumnDefinition.Create('Name', 'VARCHAR'));
    Op.Columns[1].Length := 100;
    Op.Columns[1].IsNullable := False;
    Ops.Add(Op);
    
    Json := TMigrationJsonSerializer.Serialize(Ops);
    WriteLn(Json);
    
    DeserializedOps := TMigrationJsonSerializer.Deserialize(Json);
    try
      Assert.AreEqual(1, DeserializedOps.Count);
      Assert.IsTrue(DeserializedOps[0] is TCreateTableOperation);
      
      DeserializedOp := TCreateTableOperation(DeserializedOps[0]);
      Assert.AreEqual('Users', DeserializedOp.Name);
      Assert.AreEqual(2, DeserializedOp.Columns.Count);
      
      Assert.AreEqual('Id', DeserializedOp.Columns[0].Name);
      Assert.IsTrue(DeserializedOp.Columns[0].IsPrimaryKey);
      
      Assert.AreEqual('Name', DeserializedOp.Columns[1].Name);
      Assert.AreEqual(100, DeserializedOp.Columns[1].Length);
      Assert.IsFalse(DeserializedOp.Columns[1].IsNullable);
    finally
      DeserializedOps.Free;
    end;
  finally
    Ops.Free;
  end;
end;

procedure TMigrationJsonTests.TestSerializeDeserialize_AddColumn;
var
  Op: TAddColumnOperation;
  Ops: TObjectList<TMigrationOperation>;
  Json: string;
  DeserializedOps: TObjectList<TMigrationOperation>;
  DeserializedOp: TAddColumnOperation;
begin
  Ops := TObjectList<TMigrationOperation>.Create;
  try
    Op := TAddColumnOperation.Create('Users', TColumnDefinition.Create('Age', 'INTEGER'));
    Ops.Add(Op);
    
    Json := TMigrationJsonSerializer.Serialize(Ops);
    
    DeserializedOps := TMigrationJsonSerializer.Deserialize(Json);
    try
      Assert.AreEqual(1, DeserializedOps.Count);
      Assert.IsTrue(DeserializedOps[0] is TAddColumnOperation);
      
      DeserializedOp := TAddColumnOperation(DeserializedOps[0]);
      Assert.AreEqual('Users', DeserializedOp.TableName);
      Assert.AreEqual('Age', DeserializedOp.Column.Name);
      Assert.AreEqual('INTEGER', DeserializedOp.Column.ColumnType);
    finally
      DeserializedOps.Free;
    end;
  finally
    Ops.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMigrationJsonTests);

end.
