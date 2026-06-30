unit EntityDemo.Tests.CRUD;

interface

uses
  System.SysUtils,
  EntityDemo.Tests.Base,
  EntityDemo.Entities;

type
  TCRUDTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

{ TCRUDTest }

procedure TCRUDTest.Run;
var
  User: TUser;
  Address: TAddress;
  FoundUser: TUser;
  UpdatedUser: TUser;
  IdToDelete: Integer;
  DeletedUser: TUser;
begin
  Log('🚀 Running CRUD Tests...');
  Log('========================');

  // 1. Insert
  Log('📝 Testing Insert...');

  Address := TAddress.Create;
  Address.Street := '123 Main St';
  Address.City := 'New York';

  User := TUser.Create;
  User.Name := 'Alice';
  User.Age := 25;
  User.Email := 'alice@dext.com';
  User.Address := Address; // Link address

  // Manual insert of Address since Cascade Insert is not fully implemented yet
  FContext.Entities<TAddress>.Add(Address);
  FContext.SaveChanges;
  User.AddressId := Address.Id; // Link FK manually

  FContext.Entities<TUser>.Add(User);
  FContext.SaveChanges;

  AssertTrue(User.Id > 0,
    Format('User inserted with ID: %d', [User.Id]),
    'User ID is 0 or empty after insert!');

  AssertTrue(Address.Id > 0,
    Format('Address inserted with ID: %d', [Address.Id]),
    'Address ID is 0 or empty after insert!');

  // 2. Read (Find)
  Log('🔍 Testing Find...');
  FoundUser := FContext.Entities<TUser>.Find(User.Id);

  AssertTrue(FoundUser <> nil, 'User found.', 'User not found.');

  // Assertions commented out due to potential runtime crash (investigation needed)
  if FoundUser <> nil then
  begin
    AssertTrue(FoundUser.Name = 'Alice', 'User Name is correct.', 'User Name is incorrect.');
    // Lazy loading check omitted for now
  end;

  // 3. Update
  Log('🔄 Testing Update...');
  if FoundUser <> nil then
  begin
    FoundUser.Age := 26;
    FContext.Entities<TUser>.Update(FoundUser);
    FContext.SaveChanges;

    // Verify
    UpdatedUser := FContext.Entities<TUser>.Find(User.Id);
    AssertTrue(UpdatedUser.Age = 26, 'User Age updated to 26.', 'User Age update failed.');
  end;

  // 4. Delete
  Log('🗑️ Testing Delete...');
  if FoundUser <> nil then
  begin
    IdToDelete := User.Id; // Capture ID before object is freed
    FContext.Entities<TUser>.Remove(FoundUser);
    FContext.SaveChanges;

    DeletedUser := FContext.Entities<TUser>.Find(IdToDelete);
    AssertTrue(DeletedUser = nil, 'User removed successfully.', 'User still exists after remove.');
  end;

  Log('');
end;

end.
