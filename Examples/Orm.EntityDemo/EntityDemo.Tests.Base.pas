unit EntityDemo.Tests.Base;

interface

uses
  System.Classes,
  System.SysUtils,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.PG,
  FireDAC.Phys.PGDef,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.FB,
  FireDAC.Stan.ExprFuncs,
  FireDAC.ConsoleUI.Wait,
  FireDAC.Comp.Client,
  FireDAC.DApt,
  Dext.Persistence,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Mapping,
  EntityDemo.Entities,
  EntityDemo.DbConfig;

type
  TBaseTestClass = class of TBaseTest;
  
  // Define a specific context for tests to register entities automatically
  TEntityDemoContext = class(TDbContext)
  protected
    procedure OnModelCreating(Builder: TModelBuilder); override;
  end;

  TBaseTest = class
  protected
    FConn: TFDConnection;
    FContext: TDbContext;
    
    procedure Log(const Msg: string);
    procedure LogSuccess(const Msg: string);
    procedure LogError(const Msg: string);
    procedure AssertTrue(Condition: Boolean; const SuccessMsg, FailMsg: string);

    procedure Setup; virtual;
    procedure TearDown; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run; virtual; abstract;
  end;

implementation

{ TEntityDemoContext }

procedure TEntityDemoContext.OnModelCreating(Builder: TModelBuilder);
begin
  inherited;
  // Register Entities
  Builder.Entity<TUser>;
  Builder.Entity<TAddress>;
  Builder.Entity<TProduct>;
  Builder.Entity<TOrderItem>;
end;

{ TBaseTest }

constructor TBaseTest.Create;
begin
  inherited;
  Setup;
end;

destructor TBaseTest.Destroy;
begin
  TearDown;
  inherited;
end;

procedure TBaseTest.Setup;
var
  DbConnection: IDbConnection;
  Dialect: ISQLDialect;
  Tables: TStringList;
  
  procedure DropTableIfExists(const ATableName: string);
  begin
    try
      case TDbConfig.GetProvider of
        dpSQLite:
        begin
          // SQLite and PostgreSQL support DROP TABLE IF EXISTS
          FConn.ExecSQL('DROP TABLE IF EXISTS ' + ATableName);
        end;

        dpPostgreSQL:
        begin
          // SQLite and PostgreSQL support DROP TABLE IF EXISTS
          FConn.ExecSQL('DROP TABLE IF EXISTS ' + ATableName + ' CASCADE');
        end;
        
        dpFirebird:
        begin
          // Firebird: Check if table exists first
          Tables := TStringList.Create;
          try
            // FireDAC syntax: GetTableNames(Catalog, Schema, Pattern, List, Scopes, Kinds, FullName)
            FConn.GetTableNames('', '', '', Tables, [osMy], [tkTable], True);
            // Firebird returns table names with quotes: "table_name"
            // We need to use the exact name (with quotes) for DROP
            var TableNameWithQuotes := '"' + ATableName + '"';
            var idx := Tables.IndexOf(TableNameWithQuotes);
            if idx >= 0 then
            begin
              // Use the exact name from the list (with quotes)
              FConn.ExecSQL('DROP TABLE ' + Tables[idx]);
              WriteLn('  🗑️  Dropped table: ' + ATableName);
            end;
          finally
            Tables.Free;
          end;
        end;

        dpSQLServer:
        begin
          // SQL Server 2016+ supports DROP TABLE IF EXISTS
          FConn.ExecSQL('DROP TABLE IF EXISTS [' + ATableName + ']');
        end;
      end;
    except
      on E: Exception do
        WriteLn('  ⚠️  Warning dropping ' + ATableName + ': ' + E.Message);
    end;
  end;
  
begin
  WriteLn('🔧 Setting up test with: ' + TDbConfig.GetProviderName);
  
  // 1. Create connection using TDbConfig
  DbConnection := TDbConfig.CreateConnection;
  Dialect := TDbConfig.CreateDialect;
  
  // Get the underlying TFDConnection for raw SQL operations
  FConn := (DbConnection as TFireDACConnection).Connection;

  // Drop tables to ensure clean state
  WriteLn('🗑️  Dropping existing tables...');
  // Order matters due to FKs - drop child tables first
  DropTableIfExists('order_items');
  DropTableIfExists('products');
  DropTableIfExists('users');
  DropTableIfExists('addresses');
  DropTableIfExists('mixed_keys');
  DropTableIfExists('users_with_profile');
  DropTableIfExists('user_profiles');
  DropTableIfExists('documents');
  DropTableIfExists('articles');
  DropTableIfExists('tasks');

  // 2. Initialize Context
  FContext := TDbContext.Create(DbConnection, Dialect);
  
  // 3. Register Entities & Create Schema
  WriteLn('📦 Registering entities...');
  FContext.Entities<TAddress>;
  FContext.Entities<TUser>;
  FContext.Entities<TOrderItem>;
  FContext.Entities<TProduct>;
  FContext.Entities<TMixedKeyEntity>;
  FContext.Entities<TDocument>;
  FContext.Entities<TArticle>;
  FContext.Entities<TUserProfile>;
  FContext.Entities<TUserWithProfile>;
  FContext.Entities<TTask>;
  
  WriteLn('🏗️  Creating schema...');
  FContext.EnsureCreated;
  WriteLn('✅ Setup complete!');
  WriteLn('');
end;

procedure TBaseTest.TearDown;
begin
  FContext.Free;
  // FConn.Free; OwnConnection default = true
end;

procedure TBaseTest.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

procedure TBaseTest.LogSuccess(const Msg: string);
begin
  WriteLn('   ✅ ' + Msg);
end;

procedure TBaseTest.LogError(const Msg: string);
begin
  WriteLn('   ❌ ' + Msg);
end;

procedure TBaseTest.AssertTrue(Condition: Boolean; const SuccessMsg, FailMsg: string);
begin
  if Condition then
    LogSuccess(SuccessMsg)
  else
    LogError(FailMsg);
end;

end.
