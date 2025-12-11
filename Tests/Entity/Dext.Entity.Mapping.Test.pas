unit Dext.Entity.Mapping.Test;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Entity.Attributes,
  Dext.Entity.Core,
  Dext.Entity.Mapping,
  Dext.Entity, // TDbContext
  Dext.Entity.Dialects, // TSQLiteDialect
  Dext.Entity.DbSet; // TDbSet<T>

type
  // 1. Entity with Attributes
  [Table('attr_users')]
  TMappedUser = class
  private
    FId: Integer;
    FName: string;
  public
    [PK]
    property Id: Integer read FId write FId;
    
    [Column('attr_name')]
    property Name: string read FName write FName;
  end;

  // 2. Fluent Configuration
  TMappedUserConfig = class(TEntityTypeConfiguration<TMappedUser>)
  public
    procedure Configure(Builder: IEntityTypeBuilder<TMappedUser>); override;
  end;

  // 3. Test Context
  TTestContext = class(TDbContext)
  protected
    procedure OnModelCreating(Builder: TModelBuilder); override;
  end;

  TMappingTest = class
  private
    procedure AssertEqual(const Expected, Actual, Msg: string);
    procedure Log(const Msg: string);
  public
    procedure Run;
  end;

implementation

{ TMappedUserConfig }

procedure TMappedUserConfig.Configure(Builder: IEntityTypeBuilder<TMappedUser>);
begin
  // Override Table Name
  Builder.ToTable('fluent_users');
  
  // Override Column Name
  Builder.Prop('Name').HasColumnName('fluent_name');
end;

{ TTestContext }

procedure TTestContext.OnModelCreating(Builder: TModelBuilder);
begin
  // Register the configuration
  Builder.ApplyConfiguration<TMappedUser>(TMappedUserConfig.Create);
end;

{ TMappingTest }

procedure TMappingTest.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

procedure TMappingTest.AssertEqual(const Expected, Actual, Msg: string);
begin
  if Expected = Actual then
    WriteLn('   ✅ ', Msg)
  else
  begin
    WriteLn('   ❌ ', Msg);
    WriteLn('      Expected: ', Expected);
    WriteLn('      Actual:   ', Actual);
  end;
end;

procedure TMappingTest.Run;
var
  Ctx: TTestContext;
  SetUser: IDbSet<TMappedUser>;
  Sql: string;
  TableName: string;
begin
  Log('🗺️  Testing Fluent Mapping (External Mapping)');
  Log('===========================================');

  Ctx := TTestContext.Create(nil, TSQLiteDialect.Create);
  try
    // Get DbSet (triggers MapEntity)
    SetUser := Ctx.Entities<TMappedUser>;
    
    // 1. Verify Table Name Override
    // Attribute says 'attr_users', Fluent says 'fluent_users'
    TableName := SetUser.GetTableName;
    AssertEqual('"fluent_users"', TableName, 'Table Name should be overridden by Fluent Mapping');
    
    // 2. Verify Column Name Override
    // We can check this by generating a Create Table script or checking internal structures if exposed.
    // TDbSet.GenerateCreateTableScript is a good way to check the final SQL.
    // Expected SQL: CREATE TABLE "fluent_users" ("Id" INTEGER PRIMARY KEY AUTOINCREMENT, "fluent_name" TEXT);
    
    Sql := SetUser.GenerateCreateTableScript;
    
    if Sql.Contains('"fluent_users"') then
      Log('   ✅ SQL contains correct Table Name')
    else
      Log('   ❌ SQL missing correct Table Name: ' + Sql);
      
    if Sql.Contains('"fluent_name"') then
      Log('   ✅ SQL contains correct Column Name (fluent_name)')
    else
      Log('   ❌ SQL missing correct Column Name: ' + Sql);
      
    if not Sql.Contains('attr_name') then
      Log('   ✅ SQL does NOT contain Attribute Column Name (attr_name)')
    else
      Log('   ❌ SQL contains Attribute Column Name (should be ignored): ' + Sql);
  finally
    TObject(Ctx).Free;
  end;
end;

end.
