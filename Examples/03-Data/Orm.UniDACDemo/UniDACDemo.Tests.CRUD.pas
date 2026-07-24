unit UniDACDemo.Tests.CRUD;

interface

uses
  System.SysUtils,
  Dext,
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Collections,
  UniDACDemo.Tests.Base,
  UniDACDemo.Entities;

procedure RunCRUDTests;

implementation

procedure RunCRUDTests;
var
  Base: TUniDACTestBase;
  Customer: TCustomer;
  List: IList<TCustomer>;
begin
  Base := TUniDACTestBase.Create;
  try
    // 1. Ensure schema
    WriteLn('[1] Ensuring schema...');
    Base.Context.Entities<TCustomer>;
    Base.Context.Entities<TOrder>;
    Base.Context.EnsureCreated;
    WriteLn('    Tables created.');
    WriteLn;

    // 2. INSERT
    WriteLn('[2] INSERT - Adding customers...');
    Customer := TCustomer.Create;
    Customer.Name := 'Alice Johnson';
    Customer.Email := 'alice@example.com';
    Customer.Balance := 1500.50;
    Customer.CreatedAt := Now;
    Base.Context.Entities<TCustomer>.Add(Customer);

    Customer := TCustomer.Create;
    Customer.Name := 'Bob Smith';
    Customer.Email := 'bob@example.com';
    Customer.Balance := 2300.00;
    Customer.CreatedAt := Now;
    Base.Context.Entities<TCustomer>.Add(Customer);

    Customer := TCustomer.Create;
    Customer.Name := 'Carol White';
    Customer.Email := 'carol@example.com';
    Customer.Balance := 500.75;
    Customer.CreatedAt := Now;
    Base.Context.Entities<TCustomer>.Add(Customer);

    Base.Context.SaveChanges;
    WriteLn('    3 customers inserted.');
    WriteLn;

    // 3. SELECT ALL
    WriteLn('[3] SELECT ALL - Reading customers...');
    List := Base.Context.Entities<TCustomer>.ToList;
    try
      WriteLn(Format('    Found %d customers:', [List.Count]));
      for Customer in List do
        WriteLn(Format('      #%d  %-15s  %-25s  Balance: %m',
          [Customer.Id, Customer.Name, Customer.Email, Customer.Balance]));
    finally
      // IList<T> manages memory
    end;
    WriteLn;

    // 4. UPDATE
    WriteLn('[4] UPDATE - Modifying customer #1...');
    Customer := Base.Context.Entities<TCustomer>.Find(1);
    if Customer <> nil then
    begin
      Customer.Name := 'Alice Johnson-Updated';
      Customer.Balance := 9999.99;
      Base.Context.Entities<TCustomer>.Update(Customer);
      Base.Context.SaveChanges;
      WriteLn('    Customer updated.');
    end;
    WriteLn;

    // 5. DELETE
    WriteLn('[5] DELETE - Removing customer #3...');
    Customer := Base.Context.Entities<TCustomer>.Find(3);
    if Customer <> nil then
    begin
      Base.Context.Entities<TCustomer>.Remove(Customer);
      Base.Context.SaveChanges;
      WriteLn('    Customer deleted.');
    end;
    WriteLn;

    // 6. VERIFY FINAL STATE
    WriteLn('[6] VERIFY - Final customer list:');
    List := Base.Context.Entities<TCustomer>.ToList;
    try
      WriteLn(Format('    Remaining: %d customers', [List.Count]));
      for Customer in List do
        WriteLn(Format('      #%d  %-25s  Balance: %m',
          [Customer.Id, Customer.Name, Customer.Balance]));
    finally
    end;

  finally
    Base.Free;
  end;
end;

end.