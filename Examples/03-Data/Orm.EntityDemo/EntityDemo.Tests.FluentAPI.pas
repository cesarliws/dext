unit EntityDemo.Tests.FluentAPI;

interface

uses
  EntityDemo.Tests.Base,
  Dext.Entity;

type
  TFluentAPITest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

uses
  System.SysUtils,
  Dext.Collections,
  Dext.Specifications.Fluent,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types,
  EntityDemo.Entities,
  EntityDemo.Entities.Info;

{ TFluentAPITest }

procedure TFluentAPITest.Run;
var
  U1, U2, U3: TUser;
  AdultSpec: ISpecification<TUser>;
  Adults: IList<TUser>;
  InlineAdults: IList<TUser>;
  John: TUser;
  AdultCount: Integer;
  HasMinors: Boolean;
  ComplexResult: IList<TUser>;
  FluentAdults: IList<TUser>;
  FluentComplex: IList<TUser>;
  OrderedAsc: IList<TUser>;
  OrderedDesc: IList<TUser>;
  UWithAddr: TUser;
  Addr: TAddress;
  UsersWithAddr: IList<TUser>;
  LoadedUser: TUser;
begin
  Log('🔍 Running Fluent API Tests...');
  Log('==============================');
  Log('');
  Log('This test demonstrates all available fluent operators:');
  Log('');

  // Setup
  FContext.Entities<TUser>;
  FContext.EnsureCreated;

  // Insert test data
  U1 := TUser.Create;
  U1.Name := 'John Doe';
  U1.Age := 25;
  U1.Email := 'john@example.com';
  FContext.Entities<TUser>.Add(U1);

  U2 := TUser.Create;
  U2.Name := 'Jane Smith';
  U2.Age := 30;
  U2.Email := 'jane@example.com';
  FContext.Entities<TUser>.Add(U2);

  U3 := TUser.Create;
  U3.Name := 'Bob Johnson';
  U3.Age := 17;
  U3.Email := 'bob@example.com';
  FContext.Entities<TUser>.Add(U3);
  FContext.SaveChanges;

  LogSuccess('Test data inserted (3 users)');
  Log('');

  // Test using TAdultUsersSpec which uses: TUserType.Age >= 18
  Log('📊 Test: Using Specification with Fluent API');
  Log('---------------------------------------------');
  // Use interface variable to manage lifecycle via ARC (TSpecification inherits from TInterfacedObject)
  AdultSpec := TAdultUsersSpec.Create;
  Adults := FContext.Entities<TUser>.ToList(AdultSpec);
  LogSuccess(Format('✓ Found %d adult user(s) using: TUserType.Age >= 18', [Adults.Count]));
  AssertTrue(Adults.Count = 2, 'Adult users spec', 'Expected 2 adult users');
  // AdultSpec will be cleaned up automatically when it goes out of scope (ARC)

  Log('');
  Log('🚀 Test: Inline Queries (without Specification)');
  Log('------------------------------------------------');
  // Inline query - muito mais simples!
  InlineAdults := FContext.Entities<TUser>.ToList(TUserType.Age >= 18);
  LogSuccess(Format('✓ Inline query: Found %d adult(s)', [InlineAdults.Count]));
  AssertTrue(InlineAdults.Count = 2, 'Inline adults', 'Expected 2 adults');

  // FirstOrDefault inline
  John := FContext.Entities<TUser>.FirstOrDefault(TUserType.Name.StartsWith('John'));
  if John <> nil then
    LogSuccess(Format('✓ FirstOrDefault: Found user "%s"', [John.Name]))
  else
    LogError('FirstOrDefault failed');

  // Count inline
  AdultCount := FContext.Entities<TUser>.Count(TUserType.Age >= 18);
  LogSuccess(Format('✓ Count: %d adult user(s)', [AdultCount]));

  // Any inline
  HasMinors := FContext.Entities<TUser>.Any(TUserType.Age < 18);
  if HasMinors then
    LogSuccess('✓ Any: Found minor users')
  else
    LogError('Any: No minor users found');

  // Complex inline query
  ComplexResult := FContext.Entities<TUser>.ToList(
    (TUserType.Age >= 18) and TUserType.Name.Contains('o')
  );
  LogSuccess(Format('✓ Complex inline: Found %d user(s) with Age >= 18 AND Name contains "o"', [ComplexResult.Count]));

  Log('');
  Log('✨ Test: Fluent Specification Builder');
  Log('--------------------------------------');

  // Managed Specification with automatic cleanup
  FluentAdults := FContext.Entities<TUser>.ToList(
    Specification.Where<TUser>(TUserType.Age >= 18)
  );
  LogSuccess(Format('✓ Fluent Spec: Found %d adult(s)', [FluentAdults.Count]));
  AssertTrue(FluentAdults.Count = 2, 'Fluent spec adults', 'Expected 2 adults');

  // Complex fluent with chaining
  FluentComplex := FContext.Entities<TUser>.ToList(
    Specification.Where<TUser>((TUserType.Age >= 18) and TUserType.Name.Contains('o'))
      .Take(10)
      .Skip(0)
  );
  LogSuccess(Format('✓ Fluent Complex: Found %d user(s) with chaining', [FluentComplex.Count]));

  Log('');
  Log(' Test: OrderBy Tipado');
  Log('------------------------');

  // OrderBy with Asc
  OrderedAsc := FContext.Entities<TUser>.ToList(
    Specification.Where<TUser>(TUserType.Age >= 18)
      .OrderBy(TUserType.Name.Asc)
  );
  LogSuccess(Format('✓ OrderBy Asc: Found %d user(s) ordered by Name ascending', [OrderedAsc.Count]));
  if OrderedAsc.Count > 0 then
    LogSuccess(Format('  First: %s', [OrderedAsc[0].Name]));

  // OrderBy with Desc
  OrderedDesc := FContext.Entities<TUser>.ToList(
    Specification.Where<TUser>(TUserType.Age >= 18)
      .OrderBy(TUserType.Age.Desc)
  );
  LogSuccess(Format('✓ OrderBy Desc: Found %d user(s) ordered by Age descending', [OrderedDesc.Count]));
  if OrderedDesc.Count > 0 then
    LogSuccess(Format('  First: %s (Age: %d)', [OrderedDesc[0].Name, OrderedDesc[0].Age]));

  Log('');
  Log('🔗 Test: Include (Eager Loading)');
  Log('--------------------------------');

  // Create user with address
  UWithAddr := TUser.Create;
  UWithAddr.Name := 'User With Address';
  UWithAddr.Age := 40;
  UWithAddr.Email := 'addr@example.com';

  Addr := TAddress.Create;
  Addr.Street := 'Main St';
  Addr.City := 'New York';

  // ORM does not support Cascade Insert yet, so we must add Address manually
  FContext.Entities<TAddress>.Add(Addr);
  FContext.SaveChanges;

  UWithAddr.Address := Addr;
  UWithAddr.AddressId := Addr.Id; // Link FK manually just in case

  FContext.Entities<TUser>.Add(UWithAddr);
  FContext.SaveChanges;

  // Addr is now tracked by Context
  LogSuccess(Format('Inserted user with address ID: %d', [UWithAddr.AddressId.GetValueOrDefault]));

  // Fetch with Include
  UsersWithAddr := FContext.Entities<TUser>.ToList(
    Specification.Where<TUser>(TUserType.Id = UWithAddr.Id)
      .Include('Address')
  );

  AssertTrue(UsersWithAddr.Count = 1, 'Include count', 'Expected 1 user');
  if UsersWithAddr.Count > 0 then
  begin
    LoadedUser := UsersWithAddr[0];
    if LoadedUser.Address <> nil then
      LogSuccess(Format('✓ Include: Address loaded: %s, %s', [LoadedUser.Address.Street, LoadedUser.Address.City]))
    else
      LogError('Include: Address NOT loaded (nil)');
  end;
  // Note: Addr is now managed by the DbContext's IdentityMap (doOwnsValues), do not free manually!
  Log('');
  Log('📖 Available Fluent Operators:');
  Log('------------------------------');
  Log('');
  Log('🔢 Comparison Operators:');
  Log('  • TUserType.Age = 25');
  Log('  • TUserType.Age <> 25');
  Log('  • TUserType.Age > 20');
  Log('  • TUserType.Age >= 18');
  Log('  • TUserType.Age < 30');
  Log('  • TUserType.Age <= 30');
  Log('');
  Log('🔤 String Operators:');
  Log('  • TUserType.Name.StartsWith(''John'')');
  Log('  • TUserType.Name.EndsWith(''son'')');
  Log('  • TUserType.Name.Contains(''Smith'')');
  Log('  • TUserType.Name.Like(''%Doe%'')');
  Log('  • TUserType.Name.NotLike(''%Test%'')');
  Log('');
  Log('📏 Range Operators:');
  Log('  • TUserType.Age.Between(18, 65)');
  Log('');
  Log('❓ Null Operators:');
  Log('  • TUserType.Name.IsNull');
  Log('  • TUserType.Name.IsNotNull');
  Log('');
  Log('🔗 Logical Operators:');
  Log('  • (TUserType.Age >= 18) and (TUserType.Age <= 65)');
  Log('  • (TUserType.Age < 18) or (TUserType.Age > 65)');
  Log('  • not (TUserType.Age = 25)');
  Log('');

  LogSuccess('✅ Fluent API demonstration complete!');
  Log('');
end;

end.
