unit EntityDemo.Tests.AdvancedQuery;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Dext.Entity,
  Dext.Entity.Query,
  Dext.Entity.Grouping,
  Dext.Entity.Joining,
  Dext.Persistence,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Fluent,
  EntityDemo.Entities,
  EntityDemo.Tests.Base;

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
  Users: TList<TUser>;
  Spec: ISpecification<TUser>;
  Builder: TSpecificationBuilder<TUser>;
  U: TUser;
begin
  Log('   Testing Select Optimized (Projections)...');
  TearDown;
  Setup;
  
  // Insert user with Name and Age
  U := TUser.Create;
  U.Name := 'John Doe';
  U.Age := 30;
  U.City := 'New York';
  FContext.Entities<TUser>.Add(U);
  FContext.SaveChanges;
  
  // Select only Name
  Builder := Specification.All<TUser>;
  Spec := Builder.Select(UserEntity.Name);
  
  Users := FContext.Entities<TUser>.List(Spec);
  try
    AssertTrue(Users.Count = 1, 'Should find 1 user', Format('Found %d', [Users.Count]));
    AssertTrue(Users[0].Name = 'John Doe', 'Name should be loaded', Format('Found "%s"', [Users[0].Name]));
    // Age should be default (0) because it wasn't selected
    AssertTrue(Users[0].Age = 0, 'Age should be 0 (not loaded)', Format('Found %d', [Users[0].Age]));
    // City should be default ('')
    AssertTrue(Users[0].City = '', 'City should be empty (not loaded)', Format('Found "%s"', [Users[0].City]));
  finally
    Users.Free;
  end;
end;
procedure TAdvancedQueryTest.TestAggregations;
var
  Users: TFluentQuery<TUser>;
  Count: Integer;
  SumAge: Double;
  AvgAge: Double;
  MinAge, MaxAge: Double;
begin
  Log('   Testing Aggregations...');
  
  // Setup Data
  var U1 := TUser.Create; U1.Name := 'A'; U1.Age := 10; FContext.Entities<TUser>.Add(U1);
  var U2 := TUser.Create; U2.Name := 'B'; U2.Age := 20; FContext.Entities<TUser>.Add(U2);
  var U3 := TUser.Create; U3.Name := 'C'; U3.Age := 30; FContext.Entities<TUser>.Add(U3);
  FContext.SaveChanges;
  
  Users := FContext.Entities<TUser>.Query;
  try
    // Count
    Count := Users.Count;
    AssertTrue(Count = 3, 'Count should be 3', Format('Count was %d', [Count]));
    
    // Sum
    SumAge := Users.Sum(function(U: TUser): Double
      begin
        Result := U.Age;
      end);
    AssertTrue(Abs(SumAge - 60) < 0.001, 'Sum Age should be 60', Format('Sum was %f', [SumAge]));

    // Average
    AvgAge := Users.Average(function(U: TUser): Double
      begin
        Result := U.Age;
      end);
    AssertTrue(Abs(AvgAge - 20) < 0.001, 'Avg Age should be 20', Format('Avg was %f', [AvgAge]));
    
    // Min/Max
    MinAge := Users.Min(function(U: TUser): Double
      begin
        Result := U.Age;
      end);
    MaxAge := Users.Max(function(U: TUser): Double
      begin
        Result := U.Age;
      end);
    AssertTrue(Abs(MinAge - 10) < 0.001, 'Min Age should be 10', Format('Min was %f', [MinAge]));
    AssertTrue(Abs(MaxAge - 30) < 0.001, 'Max Age should be 30', Format('Max was %f', [MaxAge]));
    
    // Any
    AssertTrue(Users.Any, 'Any should be true', 'Any was false');
    AssertTrue(Users.Any(function(U: TUser): Boolean
      begin
        Result := U.Age > 25;
      end), 'Any(Age > 25) should be true', 'Any(...) was false');
    AssertTrue(not Users.Any(function(U: TUser): Boolean
      begin
        Result := U.Age > 100;
      end), 'Any(Age > 100) should be false', 'Any(...) was true');
    
  finally
    Users.Free;
  end;
end;

procedure TAdvancedQueryTest.TestDistinct;
var
  Users: TFluentQuery<TUser>;
  Cities: TFluentQuery<string>;
  DistinctCities: TList<string>;
begin
  Log('   Testing Distinct...');
  
  // Let's add users with duplicate cities
  var U4 := TUser.Create; U4.Name := 'D'; U4.City := 'New York'; FContext.Entities<TUser>.Add(U4);
  var U5 := TUser.Create; U5.Name := 'E'; U5.City := 'New York'; FContext.Entities<TUser>.Add(U5);
  var U6 := TUser.Create; U6.Name := 'F'; U6.City := 'London'; FContext.Entities<TUser>.Add(U6);
  FContext.SaveChanges;
  
  // Project to City then Distinct
  Users := FContext.Entities<TUser>.Query;
  // Note: Users is passed as parent to the fluent chain, so it will be freed when Cities is freed.

  Cities := Users
    .Where(function(U: TUser): Boolean
       begin
         Result := U.City <> '';
       end)
    .Select<string>(function(U: TUser): string
       begin
         Result := U.City;
       end)
    .Distinct;

  try
    DistinctCities := Cities.ToList;
    try
      AssertTrue(DistinctCities.Count = 2, 'Should have 2 distinct cities (New York, London)', Format('Found %d', [DistinctCities.Count]));
      AssertTrue(DistinctCities.Contains('New York'), 'Should contain New York', 'Missing New York');
      AssertTrue(DistinctCities.Contains('London'), 'Should contain London', 'Missing London');
    finally
      DistinctCities.Free;
    end;
  finally
    Cities.Free; // This frees the entire chain including Users
  end;
end;

procedure TAdvancedQueryTest.TestPagination;
var
  Paged: IPagedResult<TUser>;
  i: Integer;
begin
  Log('   Testing Pagination...');
  
  // We have 6 users now (3 from Aggregations + 3 from Distinct)
  // Let's add 4 more to make 10
  for i := 7 to 10 do
  begin
    var U := TUser.Create;
    U.Name := 'User' + i.ToString;
    FContext.Entities<TUser>.Add(U);
  end;
  FContext.SaveChanges;
  
  var Query := FContext.Entities<TUser>.Query;
  try
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
    
  finally
    Query.Free;
  end;

end;

procedure TAdvancedQueryTest.TestGroupBy;
var
  Users: TFluentQuery<TUser>;
  Grouped: TFluentQuery<IGrouping<string, TUser>>;
  GroupsList: TList<IGrouping<string, TUser>>;
  Group: IGrouping<string, TUser>;
begin
  Log('   Testing GroupBy...');
  
  // We have users with cities: New York (2), London (1), and others empty/null.
  // U4, U5 -> New York
  // U6 -> London

  
  Users := FContext.Entities<TUser>.Query;
  
  // Use the TQuery.GroupBy function
  Grouped := TQuery.GroupBy<TUser, string>(
    Users.Where(function(U: TUser): Boolean begin Result := U.City <> ''; end),
    function(U: TUser): string begin Result := U.City; end
  );
  
  try
    GroupsList := Grouped.ToList;
    try
      AssertTrue(GroupsList.Count = 2, 'Should have 2 groups', Format('Found %d', [GroupsList.Count]));
      
      for Group in GroupsList do
      begin
        if Group.Key = 'New York' then
        begin
           // Count items in group
           var Count := 0;
           for var U in Group do Inc(Count);
           AssertTrue(Count = 2, 'New York group should have 2 users', Format('Found %d', [Count]));
        end
        else if Group.Key = 'London' then
        begin
           var Count := 0;
           for var U in Group do Inc(Count);
           AssertTrue(Count = 1, 'London group should have 1 user', Format('Found %d', [Count]));
        end
        else
          AssertTrue(False, 'Unexpected group key', Group.Key);
      end;
      
    finally
      GroupsList.Free;
    end;
  finally
    Grouped.Free; // This frees the chain
  end;
end;

procedure TAdvancedQueryTest.TestJoin;
var
  Users: TFluentQuery<TUser>;
  Addresses: TFluentQuery<TAddress>;
  Joined: TFluentQuery<string>;
  Results: TList<string>;
  U1, U2, U3: TUser;
  A1, A2: TAddress;
  OuterKeyFunc: TFunc<TUser, Integer>;
  InnerKeyFunc: TFunc<TAddress, Integer>;
  ResultFunc: TFunc<TUser, TAddress, string>;
begin
  Log('   Testing Join...');
  
  // Reset context to have clean state
  TearDown;
  Setup;

  // Setup data
  A1 := TAddress.Create; A1.Street := 'Street 1'; FContext.Entities<TAddress>.Add(A1);
  A2 := TAddress.Create; A2.Street := 'Street 2'; FContext.Entities<TAddress>.Add(A2);
  FContext.SaveChanges;
  
  U1 := TUser.Create; U1.Name := 'User 1'; U1.AddressId := A1.Id; FContext.Entities<TUser>.Add(U1);
  U2 := TUser.Create; U2.Name := 'User 2'; U2.AddressId := A2.Id; FContext.Entities<TUser>.Add(U2);
  U3 := TUser.Create; U3.Name := 'User 3'; U3.AddressId := 999; FContext.Entities<TUser>.Add(U3); // No match
  FContext.SaveChanges;
  
  Users := FContext.Entities<TUser>.Query;
  Addresses := FContext.Entities<TAddress>.Query;
  
  OuterKeyFunc := function(U: TUser): Integer begin Result := U.AddressId; end;
  InnerKeyFunc := function(A: TAddress): Integer begin Result := A.Id; end;
  ResultFunc := function(U: TUser; A: TAddress): string begin Result := U.Name + ' - ' + A.Street; end;
  
  Joined := TJoining.Join<TUser, TAddress, Integer, string>(
    Users,
    Addresses,
    OuterKeyFunc,
    InnerKeyFunc,
    ResultFunc
  );
  
  Results := Joined.ToList;
  try
    AssertTrue(Results.Count = 2, 'Should have 2 joined results', Format('Found %d', [Results.Count]));
    if Results.Count = 2 then
    begin
      AssertTrue(Results.Contains('User 1 - Street 1'), 'Should contain User 1 - Street 1', 'Missing User 1 - Street 1');
      AssertTrue(Results.Contains('User 2 - Street 2'), 'Should contain User 2 - Street 2', 'Missing User 2 - Street 2');
    end;
  finally
    Results.Free;
  end;

  // Test Simplified Join
  var JoinedSimplified := Users.Join<TAddress, Integer, string>(
    Addresses,
    UserEntity.AddressId, // Outer Key Prop
    UserEntity.Id,        // Inner Key Prop
    function(U: TUser; A: TAddress): string
    begin
      Result := U.Name + ' lives in ' + A.Street;
    end);
  
  try
    var SimpResults := JoinedSimplified.ToList;
    try
      AssertTrue(SimpResults.Count = 2, 'Simplified Join should have 2 results', Format('Found %d', [SimpResults.Count]));
      if SimpResults.Count = 2 then
         AssertTrue(SimpResults.Contains('User 1 lives in Street 1'), 'Should contain User 1...', 'Missing User 1...');
    finally
      SimpResults.Free;
    end;
  finally
    JoinedSimplified.Free;
  end;
end;

procedure TAdvancedQueryTest.TestInclude;
var
  Users: TList<TUser>;
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
  Spec := Builder.Include(UserEntity.Address);
  Users := FContext.Entities<TUser>.List(Spec);
  
  try
    AssertTrue(Users.Count = 2, 'Should have 2 users', Format('Found %d', [Users.Count]));
    
    // Verify that Address navigation property is loaded
    if Users.Count >= 1 then
    begin
      AssertTrue(Users[0].Address <> nil, 'User 1 Address should be loaded', 'User 1 Address is nil');
      if Users[0].Address <> nil then
        AssertTrue(Users[0].Address.Street = 'Main Street', 'User 1 should live on Main Street', Format('Found: %s', [Users[0].Address.Street]));
    end;
    
    if Users.Count >= 2 then
    begin
      AssertTrue(Users[1].Address <> nil, 'User 2 Address should be loaded', 'User 2 Address is nil');
      if Users[1].Address <> nil then
        AssertTrue(Users[1].Address.Street = 'Second Avenue', 'User 2 should live on Second Avenue', Format('Found: %s', [Users[1].Address.Street]));
    end;
  finally
    Users.Free;
  end;
end;



procedure TAdvancedQueryTest.TestFluentSyntax;
var
  Users: TFluentQuery<TUser>;
  Count: Integer;
  SumAge: Double;
  Names: TFluentQuery<string>;
  NameList: TList<string>;
  PartialUsers: TFluentQuery<TUser>;
  PartialList: TList<TUser>;
begin
  Log('   Testing Fluent Syntax Overloads...');
  
  // Setup Data
  TearDown;
  Setup;
  var U1 := TUser.Create; U1.Name := 'A'; U1.Age := 10; U1.City := 'NY'; FContext.Entities<TUser>.Add(U1);
  var U2 := TUser.Create; U2.Name := 'B'; U2.Age := 20; U2.City := 'LA'; FContext.Entities<TUser>.Add(U2);
  var U3 := TUser.Create; U3.Name := 'C'; U3.Age := 30; U3.City := 'NY'; FContext.Entities<TUser>.Add(U3);
  FContext.SaveChanges;
  
  Users := FContext.Entities<TUser>.Query;
  try
    // Test Where(IExpression) - Simplified syntax
    var Filtered := Users.Where(UserEntity.Age > 15);
    try
      Count := Filtered.Count;
      AssertTrue(Count = 2, 'Where(Age > 15) should return 2 users', Format('Found %d', [Count]));
    finally
      Filtered.Free;
    end;

    // Test Sum(string)
    SumAge := Users.Sum(UserEntity.Age.Name);
    AssertTrue(Abs(SumAge - 60) < 0.001, 'Sum("Age") should be 60', Format('Sum was %f', [SumAge]));
    
    // Test Select<string>(string)
    Names := Users.Select<string>(UserEntity.Name);
    try
      NameList := Names.ToList;
      try
        AssertTrue(NameList.Count = 3, 'Select<string>("Name") should return 3 names', Format('Found %d', [NameList.Count]));
        AssertTrue(NameList.Contains('A'), 'Should contain A', 'Missing A');
      finally
        NameList.Free;
      end;
    finally
      Names.Free;
    end;

    // Test Select(array of string) - Partial Load
    PartialUsers := Users.Select([UserEntity.Name, UserEntity.City]);
    try
      PartialList := PartialUsers.ToList;
      try
        AssertTrue(PartialList.Count = 3, 'Select(["Name", "City"]) should return 3 users', Format('Found %d', [PartialList.Count]));
        AssertTrue(PartialList[0].Name = 'A', 'Name should be loaded', 'Name was not loaded');
        AssertTrue(PartialList[0].City = 'NY', 'City should be loaded', 'City was not loaded');
        AssertTrue(PartialList[0].Age = 0, 'Age should NOT be loaded (0)', Format('Age was %d', [PartialList[0].Age]));
      finally
        PartialList.Free;
      end;
    finally
      PartialUsers.Free;
    end;
    
  finally
    Users.Free;
  end;
end;

end.
