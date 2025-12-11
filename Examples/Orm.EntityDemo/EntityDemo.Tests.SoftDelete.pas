unit EntityDemo.Tests.SoftDelete;

interface

uses
  System.SysUtils,
  EntityDemo.Tests.Base,
  EntityDemo.Entities,
  Dext.Entity.Drivers.Interfaces,
  Dext.Persistence,
  Dext.Collections,
  Dext.Entity; // Added for TDbContext

type
  TSoftDeleteTest = class(TBaseTest)
  public
    procedure Run; override;
    procedure ResetData;
    procedure TestSoftDelete;
    procedure TestSoftDeleteNotInList;
    procedure TestSoftDeleteCount;
    procedure TestMultipleSoftDeletes;
    
    // New Feature Tests
    procedure TestIgnoreQueryFilters;
    procedure TestOnlyDeleted;
    procedure TestRestore;
    procedure TestHardDelete;
    procedure TestFluentMapping;
  end;

implementation

{ TSoftDeleteTest }

procedure TSoftDeleteTest.ResetData;
begin
  if FContext <> nil then
    FContext.Clear;

  try
    var Cmd := FContext.Connection.CreateCommand('DELETE FROM tasks') as IDbCommand;
    Cmd.ExecuteNonQuery;
  except
    // ignore
  end;
end;

procedure TSoftDeleteTest.Run;
begin
  Log('🗑️ Running Soft Delete Tests...');
  
  ResetData;
  TestSoftDelete;
  
  ResetData;
  TestSoftDeleteNotInList;
  
  ResetData;
  TestSoftDeleteCount;
  
  ResetData;
  TestMultipleSoftDeletes;
  
  ResetData;
  TestIgnoreQueryFilters;
  
  ResetData;
  TestOnlyDeleted;
  
  ResetData;
  TestRestore;
  
  ResetData;
  TestHardDelete;
  
  ResetData;
  TestFluentMapping;
end;

// ... existing tests ...

procedure TSoftDeleteTest.TestFluentMapping;
var
  Entity: TFluentSoftDelete;
  LoadedEntity: TFluentSoftDelete;
  SavedId: Integer;
begin
  Log('🔧 Test 9: Fluent Mapping Soft Delete');
  
  // 1. Configure Mapping (Runtime)
  var Context := TDbContext(TObject(FContext)); // Cast to access concrete methods
  
  Context.ModelBuilder.Entity<TFluentSoftDelete>
    .HasSoftDelete('IsRemoved'); // Map soft delete to 'IsRemoved' property
    
  // Force DbSet creation so EnsureCreated sees it
  FContext.Entities<TFluentSoftDelete>;
    
  // Ensure table exists (since it's new)
  Context.EnsureCreated;
  
  // Clean table
  try
    var Cmd := FContext.Connection.CreateCommand('DELETE FROM fluent_soft_delete') as IDbCommand;
    Cmd.ExecuteNonQuery;
  except
  end;
  
  // 2. Add Entity
  Entity := TFluentSoftDelete.Create;
  Entity.Name := 'Fluent Delete';
  Entity.IsRemoved := False;
  
  FContext.Entities<TFluentSoftDelete>.Add(Entity);
  FContext.SaveChanges;
  SavedId := Entity.Id;
  
  // 3. Soft Delete
  FContext.Entities<TFluentSoftDelete>.Remove(Entity);
  FContext.SaveChanges;
  
  FContext.Clear;
  
  // 4. Verify Not Found (Soft Deleted)
  LoadedEntity := FContext.Entities<TFluentSoftDelete>.Find(SavedId);
  AssertTrue(LoadedEntity = nil, 'Entity hidden by soft delete', 'Entity found despite soft delete');
  
  // 5. Verify Found (Ignore Filters)
  LoadedEntity := FContext.Entities<TFluentSoftDelete>.IgnoreQueryFilters.Find(SavedId);
  AssertTrue(LoadedEntity <> nil, 'Entity found with IgnoreFilters', 'Entity not found even with IgnoreFilters');
  if LoadedEntity <> nil then
    AssertTrue(LoadedEntity.IsRemoved, 'Entity marked as removed', 'Entity IsRemoved is False');
  
  LogSuccess('Fluent Mapping for Soft Delete works!');
  WriteLn('');
end;


procedure TSoftDeleteTest.TestSoftDelete;
var
  Task: TTask;
  SavedTaskId: Integer;
  LoadedTask: TTask;
begin
  Log('🗑️ Test 1: Basic Soft Delete');
  
  // Create task
  Task := TTask.Create;
  Task.Title := 'Test Task';
  Task.Description := 'This is a test task';
  Task.IsCompleted := False;
  Task.IsDeleted := False;
  
  FContext.Entities<TTask>.Add(Task);
  FContext.SaveChanges;
  SavedTaskId := Task.Id;
  
  AssertTrue(SavedTaskId > 0, 'Task saved', 'Task ID not assigned');
  
  // Clear context
  FContext.Clear;
  
  // Load task - should be found
  LoadedTask := FContext.Entities<TTask>.Find(SavedTaskId);
  AssertTrue(LoadedTask <> nil, 'Task found before delete', 'Task not found');
  AssertTrue(LoadedTask.IsDeleted = False, 'Task not deleted', 'Task marked as deleted');
  
  // Soft delete the task
  FContext.Entities<TTask>.Remove(LoadedTask);
  FContext.SaveChanges;
  
  LogSuccess('Task soft deleted (UPDATE instead of DELETE)');
  
  // Clear context again
  FContext.Clear;
  
  // Try to load task - should NOT be found (filtered by global query filter)
  LoadedTask := FContext.Entities<TTask>.Find(SavedTaskId);
  AssertTrue(LoadedTask = nil, 'Task not found after soft delete', 'Task still found after soft delete');
  
  LogSuccess('Global query filter working - soft deleted task not visible');
  
  WriteLn('');
end;


procedure TSoftDeleteTest.TestSoftDeleteNotInList;
var
  Task1, Task2, Task3: TTask;
  Tasks: IList<TTask>;
begin
  Log('📋 Test 2: Soft Deleted Tasks Not in List');
  
  // Create 3 tasks
  Task1 := TTask.Create;
  Task1.Title := 'Task 1';
  Task1.Description := 'First task';
  
  Task2 := TTask.Create;
  Task2.Title := 'Task 2';
  Task2.Description := 'Second task';
  
  Task3 := TTask.Create;
  Task3.Title := 'Task 3';
  Task3.Description := 'Third task';
  
  FContext.Entities<TTask>.Add(Task1);
  FContext.Entities<TTask>.Add(Task2);
  FContext.Entities<TTask>.Add(Task3);
  FContext.SaveChanges;
  
  LogSuccess('3 tasks created');
  
  // List all tasks - should have 3
  Tasks := FContext.Entities<TTask>.List;
  AssertTrue(Tasks.Count = 3, '3 tasks in list', Format('Expected 3, got %d', [Tasks.Count]));
  
  // Soft delete Task2
  FContext.Entities<TTask>.Remove(Task2);
  FContext.SaveChanges;
  
  LogSuccess('Task 2 soft deleted');
  
  // Clear and list again - should have only 2
  FContext.Clear;
  Tasks := FContext.Entities<TTask>.List;
  AssertTrue(Tasks.Count = 2, '2 tasks in list after soft delete', Format('Expected 2, got %d', [Tasks.Count]));
  
  // Verify it's Task1 and Task3
  var HasTask1 := False;
  var HasTask2 := False;
  var HasTask3 := False;
  
  for var Task in Tasks do
  begin
    if Task.Title = 'Task 1' then HasTask1 := True;
    if Task.Title = 'Task 2' then HasTask2 := True;
    if Task.Title = 'Task 3' then HasTask3 := True;
  end;
  
  AssertTrue(HasTask1, 'Task 1 in list', 'Task 1 not found');
  AssertTrue(not HasTask2, 'Task 2 NOT in list', 'Task 2 still in list');
  AssertTrue(HasTask3, 'Task 3 in list', 'Task 3 not found');
  
  LogSuccess('Only non-deleted tasks visible in list');
  
  WriteLn('');
end;

procedure TSoftDeleteTest.TestSoftDeleteCount;
var
  Task1, Task2: TTask;
  Count: Integer;
begin
  Log('🔢 Test 3: Count Excludes Soft Deleted');
  
  // Create 2 tasks
  Task1 := TTask.Create;
  Task1.Title := 'Task A';
  
  Task2 := TTask.Create;
  Task2.Title := 'Task B';
  
  FContext.Entities<TTask>.Add(Task1);
  FContext.Entities<TTask>.Add(Task2);
  FContext.SaveChanges;
  
  // Count - should be 2
  Count := FContext.Entities<TTask>.Query(Specification.All<TTask>).Count;
  AssertTrue(Count = 2, '2 tasks counted', Format('Expected 2, got %d', [Count]));
  
  // Soft delete one
  FContext.Entities<TTask>.Remove(Task1);
  FContext.SaveChanges;
  
  LogSuccess('Task A soft deleted');
  
  // Count again - should be 1
  FContext.Clear;
  Count := FContext.Entities<TTask>.Query(Specification.All<TTask>).Count;
  AssertTrue(Count = 1, '1 task counted after soft delete', Format('Expected 1, got %d', [Count]));
  
  LogSuccess('COUNT query respects soft delete filter');
  
  WriteLn('');
end;

procedure TSoftDeleteTest.TestMultipleSoftDeletes;
var
  Tasks: array[1..5] of TTask;
  i: Integer;
  Count: Integer;
begin
  Log('🗑️ Test 4: Multiple Soft Deletes');
  
  // Create 5 tasks
  for i := 1 to 5 do
  begin
    Tasks[i] := TTask.Create;
    Tasks[i].Title := Format('Task %d', [i]);
    Tasks[i].Description := Format('Description %d', [i]);
    FContext.Entities<TTask>.Add(Tasks[i]);
  end;
  
  FContext.SaveChanges;
  LogSuccess('5 tasks created');
  
  // Verify count
  Count := FContext.Entities<TTask>.Query(Specification.All<TTask>).Count;
  AssertTrue(Count = 5, '5 tasks initially', Format('Expected 5, got %d', [Count]));
  
  // Soft delete tasks 2 and 4
  FContext.Entities<TTask>.Remove(Tasks[2]);
  FContext.Entities<TTask>.Remove(Tasks[4]);
  FContext.SaveChanges;
  
  LogSuccess('Tasks 2 and 4 soft deleted');
  
  // Count should be 3
  FContext.Clear;
  Count := FContext.Entities<TTask>.Query(Specification.All<TTask>).Count;
  AssertTrue(Count = 3, '3 tasks remaining', Format('Expected 3, got %d', [Count]));
  
  // List and verify
  var TaskList := FContext.Entities<TTask>.List;
  AssertTrue(TaskList.Count = 3, '3 tasks in list', Format('Expected 3, got %d', [TaskList.Count]));
  
  // Verify it's tasks 1, 3, and 5
  var Titles: TArray<string>;
  SetLength(Titles, TaskList.Count);
  for i := 0 to TaskList.Count - 1 do
    Titles[i] := TaskList[i].Title;
  
  var HasTask1 := False;
  var HasTask2 := False;
  var HasTask3 := False;
  var HasTask4 := False;
  var HasTask5 := False;
  
  for var Title in Titles do
  begin
    if Title = 'Task 1' then HasTask1 := True;
    if Title = 'Task 2' then HasTask2 := True;
    if Title = 'Task 3' then HasTask3 := True;
    if Title = 'Task 4' then HasTask4 := True;
    if Title = 'Task 5' then HasTask5 := True;
  end;
  
  AssertTrue(HasTask1, 'Task 1 present', 'Task 1 not found');
  AssertTrue(not HasTask2, 'Task 2 absent', 'Task 2 still present');
  AssertTrue(HasTask3, 'Task 3 present', 'Task 3 not found');
  AssertTrue(not HasTask4, 'Task 4 absent', 'Task 4 still present');
  AssertTrue(HasTask5, 'Task 5 present', 'Task 5 not found');
  
  LogSuccess('Multiple soft deletes working correctly');
  
  WriteLn('');
end;

procedure TSoftDeleteTest.TestIgnoreQueryFilters;
var
  Task: TTask;
  LoadedTask: TTask;
  SavedId: Integer;
begin
  Log('👀 Test 5: Ignore Query Filters');
  
  Task := TTask.Create;
  Task.Title := 'Hidden Task';
  FContext.Entities<TTask>.Add(Task);
  FContext.SaveChanges;
  SavedId := Task.Id;
  
  FContext.Entities<TTask>.Remove(Task);
  FContext.SaveChanges;
  
  FContext.Clear;
  
  // Standard Find - Should contain nothing
  LoadedTask := FContext.Entities<TTask>.Find(SavedId);
  AssertTrue(LoadedTask = nil, 'Task hidden by default', 'Task found via standard Find');
  
  // Ignore Filters
  LoadedTask := FContext.Entities<TTask>.IgnoreQueryFilters.Find(SavedId);
  AssertTrue(LoadedTask <> nil, 'Task found with IgnoreQueryFilters', 'Task NOT found with IgnoreQueryFilters');
  if LoadedTask <> nil then
    AssertTrue(LoadedTask.IsDeleted, 'Task is marked deleted', 'Task is NOT marked deleted');
    
  WriteLn('');
end;

procedure TSoftDeleteTest.TestOnlyDeleted;
var
  TaskActive, TaskDeleted: TTask;
  List: IList<TTask>;
begin
  Log('🕵️ Test 6: Only Deleted');
  
  TaskActive := TTask.Create;
  TaskActive.Title := 'Active';
  FContext.Entities<TTask>.Add(TaskActive);
  
  TaskDeleted := TTask.Create;
  TaskDeleted.Title := 'Deleted';
  FContext.Entities<TTask>.Add(TaskDeleted);
  FContext.SaveChanges;
  
  FContext.Entities<TTask>.Remove(TaskDeleted);
  FContext.SaveChanges;
  
  FContext.Clear;
  
  // Test OnlyDeleted
  List := FContext.Entities<TTask>.OnlyDeleted.List;
  AssertTrue(List.Count = 1, 'Only 1 deleted task found', Format('Expected 1, got %d', [List.Count]));
  if List.Count > 0 then
    AssertTrue(List[0].Title = 'Deleted', 'Correct task found', 'Wrong task found: ' + List[0].Title);
    
  WriteLn('');
end;

procedure TSoftDeleteTest.TestRestore;
var
  Task: TTask;
  SavedId: Integer;
  LoadedTask: TTask;
begin
  Log('♻️ Test 7: Restore');
  
  Task := TTask.Create;
  Task.Title := 'To Restore';
  FContext.Entities<TTask>.Add(Task);
  FContext.SaveChanges;
  SavedId := Task.Id;
  
  FContext.Entities<TTask>.Remove(Task);
  FContext.SaveChanges;
  
  FContext.Clear;
  
  // Find deleted task
  Task := FContext.Entities<TTask>.IgnoreQueryFilters.Find(SavedId);
  AssertTrue(Task <> nil, 'Deleted task found', 'Deleted task not found');
  
  // Restore
  if Task <> nil then
  begin
    FContext.Entities<TTask>.Restore(Task);
    // Restore executes update immediately
  end;
  
  FContext.Clear;
  
  // Find via normal Find
  LoadedTask := FContext.Entities<TTask>.Find(SavedId);
  AssertTrue(LoadedTask <> nil, 'Restored task found via normal Find', 'Restored task NOT found');
  if LoadedTask <> nil then
    AssertTrue(not LoadedTask.IsDeleted, 'Task is not deleted', 'Task still marked deleted');
    
  WriteLn('');
end;

procedure TSoftDeleteTest.TestHardDelete;
var
  Task: TTask;
  SavedId: Integer;
  LoadedTask: TTask;
begin
  Log('💥 Test 8: Hard Delete');
  
  Task := TTask.Create;
  Task.Title := 'To Hard Delete';
  FContext.Entities<TTask>.Add(Task);
  FContext.SaveChanges;
  SavedId := Task.Id;
  
  // Hard Delete
  FContext.Entities<TTask>.HardDelete(Task);
  
  FContext.Clear;
  
  // Verify with IgnoreQueryFilters - should be gone from DB
  LoadedTask := FContext.Entities<TTask>.IgnoreQueryFilters.Find(SavedId);
  AssertTrue(LoadedTask = nil, 'Task physically deleted', 'Task still exists in DB');
  
  WriteLn('');
end;

end.
