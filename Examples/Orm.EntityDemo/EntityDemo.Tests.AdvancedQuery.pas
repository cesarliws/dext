unit EntityDemo.Tests.AdvancedQuery;

interface

uses
  System.SysUtils, System.Generics.Collections, Dext.Entity, Dext.Entity.Query,
  Dext.Collections, // Add Collections unit
  Dext.Entity.Grouping, Dext.Entity.Joining, Dext.Persistence,
  Dext.Specifications.Interfaces, Dext.Specifications.Fluent,
  EntityDemo.Entities, EntityDemo.Tests.Base;

type
  TAdvancedQueryTest = class(TBaseTest)
  public
    procedure Run; override;
    procedure TestAggregations;
    procedure TestDistinct;
    procedure TestPagination;
    procedure TestGroupBy;
    procedure TestJoin;
    procedure TestInclude;
    procedure TestSelectOptimized;
    procedure TestFluentSyntax;
  end;

implementation

procedure TAdvancedQueryTest.Run;
begin
  Log('🧪 Running Advanced Query Tests...');
  TestAggregations;
  TestDistinct;
  TestPagination;
  TestGroupBy;
  TestJoin;
  TestInclude;
  TestSelectOptimized;

  Log('');
end;

procedure TAdvancedQueryTest.TestSelectOptimized;
var
  Users: IList<TUser>; // Changed to IList
  Spec: ISpecification<TUser>;
  Builder: TSpecificationBuilder<TUser>;
  U: TUser;
  Addr: TAddress;
begin
  Log('   Testing Select Optimized (Projections)...');
  TearDown;
  Setup;

  // Create dummy address
  Addr := TAddress.Create;
  Addr.Street := 'Proj St';
  Addr.City := 'Proj City';
  FContext.Entities<TAddress>.Add(Addr);
  FContext.SaveChanges;

  // Insert user with Name and Age
  U := TUser.Create;
  U.Name := 'John Doe';
  U.Age := 30;
  U.City := 'New York';
  U.AddressId := Addr.Id;
  FContext.Entities<TUser>.Add(U);
  FContext.SaveChanges;

  // Select only Name
  Builder := Specification.All<TUser>;
  // Usa class operator TPropExpression.Implicit(const Value: TPropExpression): string
  Spec := Builder.Select(UserEntity.Name);

  Users := FContext.Entities<TUser>.List(Spec);
  // No try..finally needed for Users, it's ARC managed
  AssertTrue(Users.Count = 1, 'Should find 1 user', Format('Found %d', [Users.Count]));
  AssertTrue(Users[0].Name = 'John Doe', 'Name should be loaded', Format('Found "%s"', [Users[0].Name]));
  // Age should be default (0) because it wasn't selected
  AssertTrue(Users[0].Age = 0, 'Age should be 0 (not loaded)', Format('Found %d', [Users[0].Age]));
  // City should be default ('')
  AssertTrue(Users[0].City = '', 'City should be empty (not loaded)', Format('Found "%s"', [Users[0].City]));
end;

procedure TAdvancedQueryTest.TestAggregations;
var
  UsersQuery: TFluentQuery<TUser>;
  Count: Integer;
  SumAge: Double;
  AvgAge: Double;
  MinAge, MaxAge: Double;
  Addr: TAddress;
begin
  Log('   Testing Aggregations...');

  // Setup Data
  Addr := TAddress.Create;
  Addr.Street := 'Agg St';
  Addr.City := 'Agg City';
  FContext.Entities<TAddress>.Add(Addr);
  FContext.SaveChanges;

  var U1 := TUser.Create;
  U1.Name := 'A';
  U1.Age := 10;
  U1.AddressId := Addr.Id;
  FContext.Entities<TUser>.Add(U1);
  var U2 := TUser.Create;
  U2.Name := 'B';
  U2.Age := 20;
  U2.AddressId := Addr.Id;
  FContext.Entities<TUser>.Add(U2);
  var U3 := TUser.Create;
  U3.Name := 'C';
  U3.Age := 30;
  U3.AddressId := Addr.Id;
  FContext.Entities<TUser>.Add(U3);
  FContext.SaveChanges;

  UsersQuery := FContext.Entities<TUser>.QueryAll;
  // Count
  Count := UsersQuery.Count;
  AssertTrue(Count = 3, 'Count should be 3', Format('Count was %d', [Count]));

  // Sum
  SumAge := UsersQuery
    .Sum(function(U: TUser): Double
     begin
       Result := U.Age;
     end);
  AssertTrue(Abs(SumAge - 60) < 0.001, 'Sum Age should be 60', Format('Sum was %f', [SumAge]));

  // Average
  AvgAge := UsersQuery.Average(
    function(U: TUser): Double
    begin
      Result := U.Age;
    end);
  AssertTrue(Abs(AvgAge - 20) < 0.001, 'Avg Age should be 20', Format('Avg was %f', [AvgAge]));

  // Min/Max
  MinAge := UsersQuery.Min(
    function(U: TUser): Double
    begin
      Result := U.Age;
    end);

  MaxAge := UsersQuery.Max(
    function(U: TUser): Double
    begin
      Result := U.Age;
    end);

  AssertTrue(Abs(MinAge - 10) < 0.001, 'Min Age should be 10', Format('Min was %f', [MinAge]));
  AssertTrue(Abs(MaxAge - 30) < 0.001, 'Max Age should be 30', Format('Max was %f', [MaxAge]));

  // Any
  AssertTrue(UsersQuery.Any, 'Any should be true', 'Any was false');
  AssertTrue(UsersQuery.Any(
    function(U: TUser): Boolean
    begin
      Result := U.Age > 25;
    end),
    'Any(Age > 25) should be true', 'Any(...) was false');

  AssertTrue(not UsersQuery.Any(
    function(U: TUser): Boolean
    begin
      Result := U.Age > 100;
    end),
    'Any(Age > 100) should be false', 'Any(...) was true');
end;

procedure TAdvancedQueryTest.TestDistinct;
var
  UsersQuery: TFluentQuery<TUser>;
  CitiesQuery: TFluentQuery<string>;
  DistinctCities: IList<string>; // Changed to IList
  Addr: TAddress;
begin
  Log('   Testing Distinct...');

  // Create dummy address
  Addr := TAddress.Create;
  Addr.Street := 'Dist St';
  Addr.City := 'Dist City';
  FContext.Entities<TAddress>.Add(Addr);
  FContext.SaveChanges;

  // Let's add users with duplicate cities
  var U4 := TUser.Create;
  U4.Name := 'D';
  U4.City := 'New York';
  U4.AddressId := Addr.Id;
  FContext.Entities<TUser>.Add(U4);

  var U5 := TUser.Create;
  U5.Name := 'E';
  U5.City := 'New York';
  U5.AddressId := Addr.Id;
  FContext.Entities<TUser>.Add(U5);

  var U6 := TUser.Create;
  U6.Name := 'F';
  U6.City := 'London';
  U6.AddressId := Addr.Id;
  FContext.Entities<TUser>.Add(U6);
  FContext.SaveChanges;

  // Project to City then Distinct
  UsersQuery := FContext.Entities<TUser>.QueryAll;
  // Note: Users is passed as parent to the fluent chain, so it will be freed when Cities is freed.

  CitiesQuery := UsersQuery
    .Where(function(U: TUser): Boolean
      begin
        Result := U.City <> '';
      end)
    .Select<string>(function(U: TUser): string
      begin
        Result := U.City;
      end)
    .Distinct;

  DistinctCities := CitiesQuery.ToList;
  // No try..finally
  AssertTrue(DistinctCities.Count = 2,
    'Should have 2 distinct cities (New York, London)', Format('Found %d', [DistinctCities.Count]));
  AssertTrue(DistinctCities.Contains('New York'), 'Should contain New York',
    'Missing New York');
  AssertTrue(DistinctCities.Contains('London'), 'Should contain London',
    'Missing London');
end;

procedure TAdvancedQueryTest.TestPagination;
var
  Paged: IPagedResult<TUser>;
  i: Integer;
  Addr: TAddress;
begin
  Log('   Testing Pagination...');

  // Create dummy address
  Addr := TAddress.Create;
  Addr.Street := 'Page St';
  Addr.City := 'Page City';
  FContext.Entities<TAddress>.Add(Addr);
  FContext.SaveChanges;

  // We have 6 users now (3 from Aggregations + 3 from Distinct)
  // Let's add 4 more to make 10
  for i := 7 to 10 do
  begin
    var U := TUser.Create;
    U.Name := 'User' + i.ToString;
    U.AddressId := Addr.Id;
    FContext.Entities<TUser>.Add(U);
  end;
  FContext.SaveChanges;

  var Query := FContext.Entities<TUser>.QueryAll;
  // Page 1 of 3 (Size 3) -> 10 items total -> 4 pages (3, 3, 3, 1)
  Paged := Query.Paginate(1, 3);
  AssertTrue(Paged.TotalCount = 10, 'TotalCount should be 10', Format('TotalCount: %d', [Paged.TotalCount]));
  AssertTrue(Paged.PageCount = 4, 'PageCount should be 4', Format('PageCount: %d', [Paged.PageCount]));
  AssertTrue(Paged.Items.Count = 3, 'Page 1 should have 3 items', Format('Items: %d', [Paged.Items.Count]));
  AssertTrue(Paged.HasNextPage, 'Should have next page', 'No next page');
  AssertTrue(not Paged.HasPreviousPage, 'Should not have prev page', 'Has prev page');

// Page 4 (Last page)
  Paged := Query.Paginate(4, 3);
  AssertTrue(Paged.Items.Count = 1, 'Page 4 should have 1 item', Format('Items: %d', [Paged.Items.Count]));
  AssertTrue(not Paged.HasNextPage, 'Should not have next page', 'Has next page');
  AssertTrue(Paged.HasPreviousPage, 'Should have prev page', 'No prev page');
end;

procedure TAdvancedQueryTest.TestGroupBy;
var
  Grouped: TFluentQuery<IGrouping<string, TUser>>;
  GroupsList: IList<IGrouping<string, TUser>>; // Changed to IList
  Group: IGrouping<string, TUser>;
begin
  Log('   Testing GroupBy...');

  // We have users with cities: New York (2), London (1), and others empty/null.
  // U4, U5 -> New York
  // U6 -> London

  var UsersQuery := FContext.Entities<TUser>.QueryAll;

  // Use the TQuery.GroupBy function
  Grouped := TQuery.GroupBy<TUser, string>(UsersQuery.Where(
    function(U: TUser): Boolean
    begin
      Result := U.City <> '';
    end),
    function(U: TUser): string
    begin
      Result := U.City;
    end);

  GroupsList := Grouped.ToList;
  // No try..finally
  AssertTrue(GroupsList.Count = 2, 'Should have 2 groups', Format('Found %d',
    [GroupsList.Count]));

  for Group in GroupsList do
  begin
    if Group.Key = 'New York' then
    begin
     // Count items in group
      var Count := 0;
      for var U in Group do
        Inc(Count);
      AssertTrue(Count = 2, 'New York group should have 2 users', Format('Found %d', [Count]));
    end
    else if Group.Key = 'London' then
    begin
      var Count := 0;
      for var U in Group do
        Inc(Count);
      AssertTrue(Count = 1, 'London group should have 1 user', Format('Found %d',
        [Count]));
    end
    else
      AssertTrue(False, 'Unexpected group key', Group.Key);
  end;
end;

procedure TAdvancedQueryTest.TestJoin;
begin
  Log('   Testing Join... (SKIPPED)');
end;

procedure TAdvancedQueryTest.TestInclude;
var
  Users: IList<TUser>; // Changed to IList
  U1, U2: TUser;
  A1, A2: TAddress;
  Spec: ISpecification<TUser>;
  Builder: TSpecificationBuilder<TUser>;
begin
  Log('   Testing Include (Eager Loading)...');

  // Reset context
  TearDown;
  Setup;

  // Setup data: Create addresses first
  A1 := TAddress.Create;
  A1.Street := 'Main Street';
  A1.City := 'New York';
  FContext.Entities<TAddress>.Add(A1);

  A2 := TAddress.Create;
  A2.Street := 'Second Avenue';
  A2.City := 'Los Angeles';
  FContext.Entities<TAddress>.Add(A2);
  FContext.SaveChanges;

  // Create users with addresses
  U1 := TUser.Create;
  U1.Name := 'John';
  U1.AddressId := A1.Id;
  FContext.Entities<TUser>.Add(U1);

  U2 := TUser.Create;
  U2.Name := 'Jane';
  U2.AddressId := A2.Id;
  FContext.Entities<TUser>.Add(U2);
  FContext.SaveChanges;

  // Test: Load users with Include('Address')
  Builder := Specification.All<TUser>;
  Spec := Builder.Include(UserEntity.Address.Name);
  Users := FContext.Entities<TUser>.List(Spec);

  // No try..finally
  AssertTrue(Users.Count = 2, 'Should have 2 users', Format('Found %d', [Users.Count]));

  // Verify that Address navigation property is loaded
  if Users.Count >= 1 then
  begin
    AssertTrue(Users[0].Address <> nil, 'User 1 Address should be loaded',
      'User 1 Address is nil');
    if Users[0].Address <> nil then
      AssertTrue(Users[0].Address.Street = 'Main Street',
        'User 1 should live on Main Street', Format('Found: %s', [Users[0].Address.Street]));
  end;

  if Users.Count >= 2 then
  begin
    AssertTrue(Users[1].Address <> nil, 'User 2 Address should be loaded',
      'User 2 Address is nil');
    if Users[1].Address <> nil then
      AssertTrue(Users[1].Address.Street = 'Second Avenue',
        'User 2 should live on Second Avenue', Format('Found: %s', [Users[1].Address.Street]));
  end;
end;

procedure TAdvancedQueryTest.TestFluentSyntax;
begin
  Log('   Testing Fluent Syntax Overloads... (SKIPPED)');
end;

end.
