unit EntityDemo.Tests.NoTracking;

interface

uses
  System.SysUtils,
  Dext.Entity,
  Dext.Collections, // IList
  Dext.Specifications.Interfaces,
  Dext.Specifications.Fluent,
  EntityDemo.Entities,
  EntityDemo.Tests.Base;

type
  TNoTrackingTest = class(TBaseTest)
  public
    procedure Run; override;
    procedure TestAsNoTrackingSpec;
    procedure TestAsNoTrackingFluent;
  end;

implementation

{ TNoTrackingTest }

procedure TNoTrackingTest.Run;
begin
  Log('🧪 Running NoTracking Tests...');
  TestAsNoTrackingSpec;
  TestAsNoTrackingFluent;
  Log('');
end;

procedure TNoTrackingTest.TestAsNoTrackingFluent;
var
  U: TUser;
  Users: IList<TUser>;
  CachedU: TUser;
begin
  Log('   Testing Context.Entities.AsNoTracking...');
  TearDown;
  Setup;
  
  // 1. Insert a user normally
  U := TUser.Create;
  U.Name := 'Fluent NoTrack';
  U.Age := 25;
  FContext.Entities<TUser>.Add(U);
  FContext.SaveChanges;
  
  // Clear context to ensure IdentityMap is empty
  FContext.Entities<TUser>.Clear;
  
  // 2. Load with AsNoTracking
  // Context.Entities.AsNoTracking returns a TFluentQuery<T>
  Users := FContext.Entities<TUser>.AsNoTracking.ToList;
  
  AssertTrue(Users.Count = 1, 'Should find 1 user', Format('Found %d', [Users.Count]));
  AssertTrue(Users[0].Name = 'Fluent NoTrack', 'Name match', Users[0].Name);
  
  // 3. Verify it is NOT in IdentityMap
  // We can try to Find it by ID. If it's in IdentityMap, Find returns the SAME instance.
  // Since we cleared context, Find will query DB and create NEW instance if not tracked.
  // Wait, let's verify Identity Map state if possible? 
  // We don't have direct access to IdentityMap from here easily without internals.
  // But we can check instance equality.
  
  CachedU := FContext.Entities<TUser>.Find(Users[0].Id);
  
  AssertTrue(Users[0] <> CachedU, 
    'AsNoTracking entity should be DIFFERENT instance from Find() result (which loads tracked)', 
    'Instances were same');
    
  // 4. Verify Memory Management (Implicit)
  // Users list should own the objects. 
  // When Users goes out of scope (interface), objects should be freed.
  // Any memory leak report will catch this if it fails.
  
  // Cleanup
  // CachedU is tracked, so Context owns it.
  // Users[0] is untracked, List owns it.
end;

procedure TNoTrackingTest.TestAsNoTrackingSpec;
var
  U: TUser;
  Users: IList<TUser>;
  Spec: ISpecification<TUser>;
  CachedU: TUser;
begin
  Log('   Testing Specification.AsNoTracking...');
  TearDown;
  Setup;
  
  // 1. Insert a user
  U := TUser.Create;
  U.Name := 'Spec NoTrack';
  U.Age := 30;
  FContext.Entities<TUser>.Add(U);
  FContext.SaveChanges;
  
  FContext.Entities<TUser>.Clear;
  
  // 2. Create Spec and Set AsNoTracking
  Spec := Specification.All<TUser>;
  Spec.AsNoTracking;
  
  // 3. List(Spec)
  Users := FContext.Entities<TUser>.List(Spec);
  
  AssertTrue(Users.Count = 1, 'Should find 1 user', Format('Found %d', [Users.Count]));
  
  // 4. Verify Instance Not Tracked
  CachedU := FContext.Entities<TUser>.Find(Users[0].Id);
  AssertTrue(Users[0] <> CachedU, 'Instance should not be tracked', 'Instances match');
  
  Spec := nil;
end;

end.
