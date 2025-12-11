unit EntityDemo.Tests.Concurrency;

interface

uses
  System.SysUtils,
  EntityDemo.Tests.Base,
  EntityDemo.Entities,
  Dext.Persistence,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Dialects,
  FireDAC.Comp.Client;

type
  TConcurrencyTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

{ TConcurrencyTest }

procedure TConcurrencyTest.Run;
var
  Context2: TDbContext;
begin
  Log('🛡️ Running Optimistic Concurrency Tests...');
  Log('========================================');

  // 1. Setup
  //FContext.Entities<TProduct>; // Already registered in Base
  //FContext.EnsureCreated; // Already created in Base

  var P := TProduct.Create;
  P.Name := 'Concurrency Product';
  P.Price := 100;
  P.Version := 1; // Initial version
  
  FContext.Entities<TProduct>.Add(P);
  FContext.SaveChanges;
  LogSuccess(Format('Product inserted with ID: %d, Version: %d', [P.Id, P.Version]));

  // 2. Simulate User A (Context 1) and User B (Context 2)
  
  // Create a second context sharing the same DB connection
  Context2 := TDbContext.Create(TFireDACConnection.Create(FConn, False), TSQLiteDialect.Create);
  try
    Context2.Entities<TProduct>; // Register in second context
    
    // User A loads product (from FContext)
    var ProductA := FContext.Entities<TProduct>.Find(P.Id);
    
    // User B loads product (from Context2)
    var ProductB := Context2.Entities<TProduct>.Find(P.Id);
    
    AssertTrue(ProductA.Version = 1, 'User A sees Version 1', 'User A Version mismatch');
    AssertTrue(ProductB.Version = 1, 'User B sees Version 1', 'User B Version mismatch');
    
    // User A updates
    ProductA.Price := 150;
    FContext.Entities<TProduct>.Update(ProductA);
    FContext.SaveChanges;
    LogSuccess('User A updated product. New Version: ' + ProductA.Version.ToString);
    
    AssertTrue(ProductA.Version = 2, 'Version incremented to 2', 'Version did not increment');
    
    // User B tries to update (still has Version 1)
    ProductB.Price := 200;
    try
      Context2.Entities<TProduct>.Update(ProductB);
      Context2.SaveChanges;
      LogError('User B update should have failed!');
    except
      on E: EOptimisticConcurrencyException do
        LogSuccess('✅ Caught expected Concurrency Exception: ' + E.Message);
      on E: Exception do
        LogError('Caught unexpected exception: ' + E.ClassName + ' - ' + E.Message);
    end;
    
    // Verify DB state
    // Check DB directly
    var DBPrice: Double := FConn.ExecSQLScalar('SELECT "Price" FROM "products" WHERE "Id" = ' + P.Id.ToString);
    AssertTrue(DBPrice = 150, 'DB Price is 150 (User A)', 'DB Price mismatch: ' + DBPrice.ToString);
    
    // 3. Concurrent Delete Scenario
    Log('Testing Concurrent Delete...');
    
    // Create new product for delete test
    var PDelete := TProduct.Create;
    PDelete.Name := 'Delete Product';
    PDelete.Price := 300;
    PDelete.Version := 1;
    FContext.Entities<TProduct>.Add(PDelete);
    FContext.SaveChanges;
    
    // User A loads (FContext)
    var ProductDeleteA := FContext.Entities<TProduct>.Find(PDelete.Id);
    
    // User B loads (Context2)
    var ProductDeleteB := Context2.Entities<TProduct>.Find(PDelete.Id);
    
    // User A deletes
    FContext.Entities<TProduct>.Remove(ProductDeleteA);
    FContext.SaveChanges;
    LogSuccess('User A deleted product.');
    
    // User B tries to update
    ProductDeleteB.Price := 400;
    try
      Context2.Entities<TProduct>.Update(ProductDeleteB);
      Context2.SaveChanges;
      LogError('User B update after delete should have failed!');
    except
      on E: EOptimisticConcurrencyException do
        LogSuccess('✅ Caught expected Concurrency Exception (Delete): ' + E.Message);
      on E: Exception do
        LogError('Caught unexpected exception: ' + E.ClassName + ' - ' + E.Message);
    end;

  finally
    Context2.Free;
  end;
  
  Log('');
end;

end.
