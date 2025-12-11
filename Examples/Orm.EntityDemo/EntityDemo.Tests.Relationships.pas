unit EntityDemo.Tests.Relationships;

interface

uses
  System.SysUtils,
  EntityDemo.Tests.Base,
  EntityDemo.Entities;

type
  TRelationshipTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

{ TRelationshipTest }

procedure TRelationshipTest.Run;
begin
  Log('🔗 Running Relationship Tests...');
  Log('==============================');

  // 1. Cascade Delete
  Log('🧨 Testing Cascade Delete...');
  
  var Address := TAddress.Create;
  Address.Street := '999 Cascade Blvd';
  Address.City := 'Destruction City';
  
  var User := TUser.Create;
  User.Name := 'Cascade Victim';
  User.Age := 99;
  User.Email := 'victim@dext.com';
  User.Address := Address;
  
  FContext.Entities<TAddress>.Add(Address);
  FContext.SaveChanges;
  User.AddressId := Address.Id;
  
  FContext.Entities<TUser>.Add(User);
  FContext.SaveChanges;
  var UserId := User.Id;
  var AddressId := Address.Id;
  
  AssertTrue(UserId > 0, 'User inserted.', 'User insert failed.');
  
  // Delete Address (should cascade to User because of DB constraint)
  // Note: Dext ORM doesn't handle cascade delete in memory automatically yet, 
  // but the DB Foreign Key is set to CASCADE.
  
  var AddrToDelete := FContext.Entities<TAddress>.Find(AddressId);
  if AddrToDelete <> nil then
  begin
    FContext.Entities<TAddress>.Remove(AddrToDelete);
    FContext.SaveChanges;
    LogSuccess('Address removed.');
    
    // Verify User is gone from DB
    var Count: Integer := FConn.ExecSQLScalar('SELECT COUNT(*) FROM "users" WHERE "Id" = ' + UserId.ToString);
    AssertTrue(Count = 0, 'Cascade Delete Verified: User is gone from DB.', 'Cascade Delete Failed: User still exists in DB.');
  end;
  
  Log('');
end;

end.
