unit EntityDemo.Tests.Bulk;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  EntityDemo.Tests.Base,
  EntityDemo.Entities;

type
  TBulkTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

{ TBulkTest }

procedure TBulkTest.Run;
var
  BulkUsers: TObjectList<TUser>;
  i: Integer;
  StartTime: TDateTime;
  Duration: TDateTime;
  Count: Integer;
begin
  Log('📦 Running Bulk Operation Tests...');
  Log('================================');

  BulkUsers := TObjectList<TUser>.Create(False);
  try
    // 1. Bulk Insert
    Log('   Preparing 100 users...');
    for i := 1 to 100 do
    begin
      var U := TUser.Create;
      U.Name := 'Bulk User ' + i.ToString;
      U.Age := 20;
      U.Email := 'bulk' + i.ToString + '@dext.com';
      U.Address := nil; 
      BulkUsers.Add(U);
    end;

    StartTime := Now;
    FContext.Entities<TUser>.AddRange(BulkUsers);
    FContext.SaveChanges;
    Duration := Now - StartTime;
    
    LogSuccess(Format('Inserted 100 users in %s', [FormatDateTime('ss.zzz', Duration)]));

    Count := FConn.ExecSQLScalar('SELECT COUNT(*) FROM "users" WHERE "Age" = 20 AND "full_name" LIKE ''Bulk User%''');
    AssertTrue(Count = 100, 'Bulk Add Verified.', Format('Bulk Add Failed: Found %d users.', [Count]));

    // 2. Bulk Update
    Log('   Updating 100 users...');
    for var U in BulkUsers do
    begin
      U.Age := 30;
      // Note: We need to call UpdateRange, but currently UpdateRange iterates and calls Update.
      // We can modify the objects here and then call UpdateRange.
    end;

    StartTime := Now;
    FContext.Entities<TUser>.UpdateRange(BulkUsers);
    FContext.SaveChanges;
    Duration := Now - StartTime;

    LogSuccess(Format('Updated 100 users in %s', [FormatDateTime('ss.zzz', Duration)]));

    Count := FConn.ExecSQLScalar('SELECT COUNT(*) FROM "users" WHERE "Age" = 30 AND "full_name" LIKE ''Bulk User%''');
    AssertTrue(Count = 100, 'Bulk Update Verified.', Format('Bulk Update Failed: Found %d users.', [Count]));

    // 3. Bulk Remove
    Log('   Removing 100 users...');
    StartTime := Now;
    FContext.Entities<TUser>.RemoveRange(BulkUsers);
    FContext.SaveChanges;
    Duration := Now - StartTime;

    LogSuccess(Format('Removed 100 users in %s', [FormatDateTime('ss.zzz', Duration)]));

    Count := FConn.ExecSQLScalar('SELECT COUNT(*) FROM "users" WHERE "full_name" LIKE ''Bulk User%''');
    AssertTrue(Count = 0, 'Bulk Remove Verified.', Format('Bulk Remove Failed: Found %d users.', [Count]));

  finally
    BulkUsers.Free;
  end;
  
  Log('');
end;

end.
