unit EntityDemo.Tests.Relationships;

interface

uses
  System.SysUtils,
  Dext.Entity.Dialects,
  EntityDemo.Tests.Base,
  EntityDemo.Entities,
  EntityDemo.DbConfig;

type
  TRelationshipTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

{ TRelationshipTest }

procedure TRelationshipTest.Run;
var
  Dialect: ISQLDialect;
  Address: TAddress;
  User: TUser;
  UserId: Integer;
  AddressId: Integer;
  AddrToDelete: TAddress;
  SQL: string;
  Count: Integer;
begin
  Dialect := TDbConfig.CreateDialect;

  Log('🔗 Running Relationship Tests...');
  Log('==============================');

  // 1. Cascade Delete
  Log('🧨 Testing Cascade Delete...');

  Address := TAddress.Create;
  Address.Street := '999 Cascade Blvd';
  Address.City := 'Destruction City';

  User := TUser.Create;
  User.Name := 'Cascade Victim';
  User.Age := 99;
  User.Email := 'victim@dext.com';
  User.Address := Address;

  FContext.Entities<TAddress>.Add(Address);
  FContext.SaveChanges;
  User.AddressId := Address.Id;

  FContext.Entities<TUser>.Add(User);
  FContext.SaveChanges;
  UserId := User.Id;
  AddressId := Address.Id;

  AssertTrue(UserId > 0, 'User inserted.', 'User insert failed.');

  // Delete Address (should cascade to User because of DB constraint)
  // Note: Dext ORM doesn't handle cascade delete in memory automatically yet,
  // but the DB Foreign Key is set to CASCADE.

  AddrToDelete := FContext.Entities<TAddress>.Find(AddressId);
  if AddrToDelete <> nil then
  begin
    FContext.Entities<TAddress>.Remove(AddrToDelete);
    FContext.SaveChanges;
    LogSuccess('Address removed.');

    // Verify User is gone from DB (use proper quoting for each database)
    SQL := Format('SELECT COUNT(*) FROM %s WHERE %s = %d',
      [Dialect.QuoteIdentifier('users'), Dialect.QuoteIdentifier('Id'), UserId]);
    Count := FConn.ExecSQLScalar(SQL);
    AssertTrue(Count = 0, 'Cascade Delete Verified: User is gone from DB.', 'Cascade Delete Failed: User still exists in DB.');
  end;

  Log('');
end;

end.
