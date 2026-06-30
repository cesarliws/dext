unit EntityDemo.Tests.Join;

interface

uses
  System.SysUtils,
  Dext.Collections,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Fluent,
  Dext.Entity.Query,
  EntityDemo.Entities,
  EntityDemo.Entities.Info,
  EntityDemo.Tests.Base;

type
  TJoinPatternsTest = class(TBaseTest)
  public
    procedure Run; override;
    procedure Test_SQL_Join_With_AsNoTracking;
    procedure Test_Generic_Join_Materializes_InMemory;
  end;

implementation

procedure TJoinPatternsTest.Run;
begin
  Log('🧪 Running Join Pattern Tests...');
  Test_SQL_Join_With_AsNoTracking;
  Test_Generic_Join_Materializes_InMemory;
  Log('');
end;

procedure TJoinPatternsTest.Test_SQL_Join_With_AsNoTracking;
var
  P1, P2: TProduct;
  O11, O12, O21: TOrderItem;
  Products: IList<TProduct>;
  LastSql: string;
begin
  Log('   Testing SQL-based Join (table/alias/type + string predicate)...');
  TearDown;
  Setup;

  // Use products + order_items to avoid ambiguous "Id" collision in SELECT list.
  P1 := TProduct.Create;
  P1.Name := 'Keyboard';
  P1.Price := 100;
  FContext.Entities<TProduct>.Add(P1);

  P2 := TProduct.Create;
  P2.Name := 'Mouse';
  P2.Price := 50;
  FContext.Entities<TProduct>.Add(P2);
  FContext.SaveChanges;

  O11 := TOrderItem.Create;
  O11.OrderId := 1;
  O11.ProductId := P1.Id;
  O11.Quantity := 2;
  O11.Price := 100;
  FContext.Entities<TOrderItem>.Add(O11);

  O12 := TOrderItem.Create;
  O12.OrderId := 2;
  O12.ProductId := P1.Id;
  O12.Quantity := 1;
  O12.Price := 100;
  FContext.Entities<TOrderItem>.Add(O12);

  O21 := TOrderItem.Create;
  O21.OrderId := 3;
  O21.ProductId := P2.Id;
  O21.Quantity := 1;
  O21.Price := 50;
  FContext.Entities<TOrderItem>.Add(O21);
  FContext.SaveChanges;

  LastSql := '';
  FContext.OnLog :=
    procedure(SQL: string)
    begin
      LastSql := SQL;
      WriteLn('      SQL> ' + SQL);
    end;

  // String predicate in ON clause (simple "left = right" parser):
  // products.id = oi.product_id
  Products := FContext.Entities<TProduct>
    .AsNoTracking
    .Join('order_items', 'oi', 'products.id = oi.product_id', jtInner)
    .OrderBy(TProductType.Name.Asc)
    .ToList;

  AssertTrue(Products.Count = 3,
    'Inner JOIN should return one row per matching join tuple',
    Format('Expected 3 rows, got %d', [Products.Count]));

  AssertTrue(Pos('join', LowerCase(LastSql)) > 0,
    'Generated SQL should contain JOIN',
    'Expected generated SQL with JOIN but it was not found');

  AssertTrue(Pos('order_items', LowerCase(LastSql)) > 0,
    'Generated SQL should reference joined table',
    'Expected joined table name in generated SQL');
end;

procedure TJoinPatternsTest.Test_Generic_Join_Materializes_InMemory;
var
  P1, P2: TProduct;
  O11, O12, O21: TOrderItem;
  OuterProducts: TFluentQuery<TProduct>;
  InnerOrderItems: TFluentQuery<TOrderItem>;
  Joined: TFluentQuery<string>;
  Results: IList<string>;
begin
  Log('   Testing generic Join<TInner,TKey,TResult> (in-memory correlation)...');
  TearDown;
  Setup;

  P1 := TProduct.Create;
  P1.Name := 'Keyboard';
  P1.Price := 100;
  FContext.Entities<TProduct>.Add(P1);

  P2 := TProduct.Create;
  P2.Name := 'Mouse';
  P2.Price := 50;
  FContext.Entities<TProduct>.Add(P2);
  FContext.SaveChanges;

  O11 := TOrderItem.Create;
  O11.OrderId := 1;
  O11.ProductId := P1.Id;
  O11.Quantity := 2;
  O11.Price := 100;
  FContext.Entities<TOrderItem>.Add(O11);

  O12 := TOrderItem.Create;
  O12.OrderId := 2;
  O12.ProductId := P1.Id;
  O12.Quantity := 1;
  O12.Price := 100;
  FContext.Entities<TOrderItem>.Add(O12);

  O21 := TOrderItem.Create;
  O21.OrderId := 3;
  O21.ProductId := P2.Id;
  O21.Quantity := 1;
  O21.Price := 50;
  FContext.Entities<TOrderItem>.Add(O21);
  FContext.SaveChanges;

  OuterProducts := FContext.Entities<TProduct>.AsNoTracking;
  InnerOrderItems := FContext.Entities<TOrderItem>.AsNoTracking;

  // Important: this overload materializes both sequences and correlates in memory.
  Joined := OuterProducts.Join<TOrderItem, Integer, string>(
    InnerOrderItems,
    'Id',
    'ProductId',
    function(P: TProduct; O: TOrderItem): string
    begin
      Result := P.Name + ' x' + O.Quantity.ToString;
    end
  );

  Results := Joined.ToList;

  AssertTrue(Results.Count = 3,
    'In-memory Join should produce one row per correlated tuple',
    Format('Expected 3 rows, got %d', [Results.Count]));

  AssertTrue(
    Results[0].Contains('Keyboard') or Results[1].Contains('Keyboard') or Results[2].Contains('Keyboard'),
    'In-memory Join should include joined rows for Keyboard',
    'Expected Keyboard correlated rows were not found'
  );
end;

end.
