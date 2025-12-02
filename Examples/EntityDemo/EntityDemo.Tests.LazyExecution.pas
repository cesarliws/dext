unit EntityDemo.Tests.LazyExecution;

interface

uses
  EntityDemo.Tests.Base,
  System.SysUtils;

type
  TLazyExecutionTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

uses
  EntityDemo.Entities,
  System.Generics.Collections,
  Dext.Entity.Query;

{ TLazyExecutionTest }

procedure TLazyExecutionTest.Run;
var
  U1, U2, U3: TUser;
  LazyQuery: TFluentQuery<TUser>;
  User: TUser;
  Count: Integer;
  Name: string;
begin
  Log('🔄 Running Lazy Execution Tests...');
  Log('===================================');
  Log('');
  
  // Setup: Insert test data
  U1 := TUser.Create;
  U1.Name := 'Alice';
  U1.Age := 25;
  U1.Email := 'alice@test.com';
  FContext.Entities<TUser>.Add(U1);
  
  U2 := TUser.Create;
  U2.Name := 'Bob';
  U2.Age := 30;
  U2.Email := 'bob@test.com';
  FContext.Entities<TUser>.Add(U2);
  
  U3 := TUser.Create;
  U3.Name := 'Charlie';
  U3.Age := 17;
  U3.Email := 'charlie@test.com';
  FContext.Entities<TUser>.Add(U3);
  FContext.SaveChanges;
  
  LogSuccess('Inserted 3 test users');
  Log('');
  
  // Test 1: Lazy Query - Query is NOT executed yet!
  Log('📋 Test 1: Lazy Query Creation');
  Log('------------------------------');
  LazyQuery := FContext.Entities<TUser>.Query(UserEntity.Age >= 18);
  LogSuccess('✓ Query created (NOT executed yet!)');
  Log('  The query will only execute when we enumerate it.');
  Log('');
  
  // Test 2: Force execution by enumerating
  Log('🔍 Test 2: Force Execution via Enumeration');
  Log('------------------------------------------');
  Count := 0;
  for User in LazyQuery do
  begin
    Inc(Count);
    LogSuccess(Format('  Found: %s (Age: %d)', [User.Name, User.Age]));
  end;
  AssertTrue(Count = 2, 
    Format('Found %d adult users', [Count]), 
    'Expected 2 adult users');
  Log('');
  
  // Test 3: Query can be enumerated multiple times
  Log('🔁 Test 3: Re-enumerate Same Query');
  Log('-----------------------------------');
  Count := 0;
  for User in LazyQuery do
    Inc(Count);
  LogSuccess(Format('✓ Re-enumerated: Found %d users again', [Count]));
  Log('  Note: Query executes AGAIN (not cached)');
  Log('');
  
  // Test 4: Query all records (lazy)
  Log('📊 Test 4: Query All Records (Lazy)');
  Log('------------------------------------');
  var AllQuery := FContext.Entities<TUser>.QueryAll();
  LogSuccess('✓ Query() created for all records');
  
  Count := 0;
  for User in AllQuery do
    Inc(Count);
  AssertTrue(Count = 3, 
    Format('Found %d total users', [Count]), 
    'Expected 3 total users');
  Log('');
  
  // Test 5: Demonstrate difference between List() and Query()
  Log('⚡ Test 5: List() vs Query() - Execution Timing');
  Log('------------------------------------------------');
  Log('  List():  Executes IMMEDIATELY and returns TList<T>');
  Log('  Query(): Defers execution until enumerated (IEnumerable<T>)');
  Log('');
  
  var EagerList := FContext.Entities<TUser>.List(UserEntity.Age >= 18);
  LogSuccess(Format('✓ List() executed immediately: %d results', [EagerList.Count]));
  EagerList.Free;
  
  var LazyEnum := FContext.Entities<TUser>.Query(UserEntity.Age >= 18);
  LogSuccess('✓ Query() created (deferred execution)');
  Log(Format('  → Execution happens when we enumerate it (Query object: %p)', [Pointer(LazyEnum)]));
  LazyEnum.Free; // Free it since we are not enumerating it fully or transferring ownership
  Log('');
  
  // Test 6: Projections (Select)
  Log('🎯 Test 6: Projections (Select)');
  Log('------------------------------');
  var NamesQuery: TFluentQuery<string>;
  NamesQuery := FContext.Entities<TUser>
    .Query(UserEntity.Age >= 18)
    .Select<string>(function(U: TUser): string
      begin
        Result := U.Name;
      end);
      
  LogSuccess('✓ Select<string> created (deferred execution)');
  
  Count := 0;
  for Name in NamesQuery do
  begin
    Inc(Count);
    LogSuccess(Format('  Found Name: %s', [Name]));
  end;
  
  AssertTrue(Count = 2, 
    Format('Found %d names', [Count]), 
    'Expected 2 names');
  Log('');
  
  LogSuccess('✅ Lazy Execution & Projection tests complete!');
  Log('');
  
  // Test 7: Where (Filtering)
  Log('🔍 Test 7: Where (Filtering)');
  Log('---------------------------');
  var FilteredQuery := FContext
    .Entities<TUser>
    .QueryAll()
    .Where(function(U: TUser): Boolean
      begin
        Result := U.Age > 20;
      end);
      
  Count := 0;
  for User in FilteredQuery do
  begin
    Inc(Count);
    LogSuccess(Format('  Found: %s (Age: %d)', [User.Name, User.Age]));
  end;
  AssertTrue(Count = 2, 'Found 2 users > 20', 'Expected 2 users');
  Log('');

  // Test 8: Skip & Take (Pagination)
  Log('📄 Test 8: Skip & Take (Pagination)');
  Log('----------------------------------');
  // Order is not guaranteed without OrderBy, but for this test we assume insertion order or DB order
  // Alice(25), Bob(30), Charlie(17)
  
  var PagedQuery := FContext.Entities<TUser>
    .QueryAll()
    .Skip(1)
    .Take(1);
    
  Count := 0;
  for User in PagedQuery do
  begin
    Inc(Count);
    LogSuccess(Format('  Page Item: %s', [User.Name]));
  end;
  AssertTrue(Count = 1, 'Found 1 user', 'Expected 1 user');
  Log('');

  LogSuccess('✅ Fluent API (Where, Skip, Take) tests complete!');
  Log('');
  Log('💡 Key Takeaways:');
  Log('  • Query() returns TFluentQuery<T> with deferred execution');
  Log('  • Select<TResult>() projects results to a new type');
  Log('  • Where() filters results in memory (lazy)');
  Log('  • Skip() and Take() enable pagination');
  Log('  • List() returns TList<T> with immediate execution');
  Log('  • Use Query() when you might not need all results');
  Log('  • Use List() when you need to materialize results immediately');
  Log('');
end;

end.
