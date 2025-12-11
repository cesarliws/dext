unit EntityDemo.Tests.CompositeKeys;

interface

uses
  System.SysUtils,
  System.Variants,
  EntityDemo.Tests.Base,
  EntityDemo.Entities;

type
  TCompositeKeyTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

{ TCompositeKeyTest }

procedure TCompositeKeyTest.Run;
begin
  Log('🔑 Running Composite Key Tests...');
  Log('===============================');

  var OrderItem := TOrderItem.Create;
  OrderItem.OrderId := 100;
  OrderItem.ProductId := 50;
  OrderItem.Quantity := 2;
  OrderItem.Price := 10.50;

  FContext.Entities<TOrderItem>.Add(OrderItem);
  FContext.SaveChanges;
  FContext.SaveChanges;
  OrderItem.Free; // Free the object after adding it, as Add copies the values or we need to manage lifecycle if not owned
  LogSuccess('OrderItem (100, 50) added.');

  // Find using Composite Key
  var FoundItem := FContext.Entities<TOrderItem>.Find([100, 50]);

  AssertTrue(FoundItem <> nil, 'Found OrderItem by Composite Key.', 'Failed to find OrderItem.');

  if FoundItem <> nil then
  begin
    AssertTrue(FoundItem.Quantity = 2, 'Quantity is correct.', 'Quantity is incorrect.');

    // Update
    FoundItem.Quantity := 5;
    FContext.Entities<TOrderItem>.Update(FoundItem);
    FContext.SaveChanges;
    LogSuccess('OrderItem updated.');

    // Remove
    FContext.Entities<TOrderItem>.Remove(FoundItem);
    FContext.SaveChanges;

    // Verify Remove
    var DeletedItem := FContext.Entities<TOrderItem>.Find(VarArrayOf([100, 50]));
    AssertTrue(DeletedItem = nil, 'Composite Key Remove Verified.', 'Composite Key Remove Failed.');
  end;

  Log('');
end;

end.
