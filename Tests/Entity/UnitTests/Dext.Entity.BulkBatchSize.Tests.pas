unit Dext.Entity.BulkBatchSize.Tests;

interface

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Comp.Client,
  Dext.Assertions,
  Dext.Testing.Attributes,
  Dext.Collections,
  Dext.Entity.Core,
  Dext.Entity.Context,
  Dext.Entity.DbSet,
  Dext.Entity.Setup,
  Dext.Entity.Dialects,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Attributes;

type
  [Table('bulk_test_entities')]
  TBulkTestEntity = class
  private
    FId: Integer;
    FValString: string;
  public
    [PrimaryKey, AutoInc]
    property Id: Integer read FId write FId;
    property ValString: string read FValString write FValString;
  end;

  TBulkTestContext = class(TDbContext)
  end;

  [Fixture]
  [Category('ORM'), Category('Integration'), Category('Bulk')]
  TBulkBatchSizeTests = class
  private
    FConn: TFDConnection;
    FContext: TBulkTestContext;
    procedure SetupDatabase;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_WithBulkBatchSize_ShouldPropagateToContextAndExecuteInChunks;
  end;

implementation

{ TBulkBatchSizeTests }

procedure TBulkBatchSizeTests.SetupDatabase;
begin
  FConn.ExecSQL('CREATE TABLE bulk_test_entities (id INTEGER PRIMARY KEY AUTOINCREMENT, valstring TEXT)');
end;

procedure TBulkBatchSizeTests.Setup;
var
  Options: TDbContextOptions;
begin
  FConn := TFDConnection.Create(nil);
  FConn.DriverName := 'SQLite';
  FConn.Params.Add('Database=:memory:');
  FConn.Connected := True;
  
  SetupDatabase;

  Options := TDbContextOptions.Create;
  try
    Options.UseSQLite(':memory:')
           .WithBulkBatchSize(5); // Chunk size of 5
  
    Options.CustomConnection := TFireDACConnection.Create(FConn, False);

    FContext := TBulkTestContext.Create(Options);
  finally
    Options.Free;
  end;
end;

procedure TBulkBatchSizeTests.TearDown;
begin
  FreeAndNil(FContext);
  FreeAndNil(FConn);
end;

procedure TBulkBatchSizeTests.Test_WithBulkBatchSize_ShouldPropagateToContextAndExecuteInChunks;
var
  Items: TArray<TObject>;
  Entity: TBulkTestEntity;
  i: Integer;
  UpdatedList: IList<TBulkTestEntity>;
begin
  // Assert BulkBatchSize was propagated
  Should(FContext.BulkBatchSize).Be(5);

  // 1. Insert 12 entities
  SetLength(Items, 12);
  for i := 0 to 11 do
  begin
    Entity := TBulkTestEntity.Create;
    Entity.ValString := 'Original ' + IntToStr(i);
    FContext.Entities<TBulkTestEntity>.Add(Entity);
    Items[i] := Entity;
  end;
  
  FContext.SaveChanges;

  // 2. Modify value and perform Update
  for i := 0 to 11 do
  begin
    TBulkTestEntity(Items[i]).ValString := 'Updated ' + IntToStr(i);
    FContext.Entities<TBulkTestEntity>.Update(TBulkTestEntity(Items[i]));
  end;
  FContext.SaveChanges;

  // 3. Verify they were all updated in DB
  UpdatedList := FContext.Entities<TBulkTestEntity>.ToList;
  Should(UpdatedList.Count).Be(12);
  for i := 0 to 11 do
  begin
    Entity := FContext.Entities<TBulkTestEntity>.Find(TBulkTestEntity(Items[i]).Id);
    Should(Entity).NotBeNil;
    Should(Entity.ValString).Be('Updated ' + IntToStr(i));
  end;
end;

end.
