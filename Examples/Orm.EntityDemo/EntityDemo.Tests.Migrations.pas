unit EntityDemo.Tests.Migrations;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Dext.Entity.Migrations.Operations,
  Dext.Entity.Migrations.Builder,
  Dext.Entity.Migrations.Model,
  Dext.Entity.Migrations.Differ,
  Dext.Entity.Migrations.Extractor,
  Dext.Entity.Migrations.Generator,
  Dext.Entity.Migrations,
  Dext.Entity.Migrations.Runner,
  Dext.Hosting.CLI,
  System.Math,
  Dext.Entity.Dialects,
  Dext.Entity.Core,
  Dext.Entity, // Add concrete TDbContext
  Dext.Entity.Drivers.FireDAC,
  FireDAC.Comp.Client,
  EntityDemo.Tests.Base;

type
  TMigrationsTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

  TTestMigration = class(TInterfacedObject, IMigration)
  public
    function GetId: string;
    procedure Up(Builder: TSchemaBuilder);
    procedure Down(Builder: TSchemaBuilder);
  end;

implementation

{ TTestMigration }

function TTestMigration.GetId: string;
begin
  Result := '20231001_TestMigration';
end;

procedure TTestMigration.Up(Builder: TSchemaBuilder);
begin
  Builder.CreateTable('TestMigratedTable', procedure(T: TTableBuilder)
  begin
    T.Column('Id', 'INTEGER').PrimaryKey;
    T.Column('Name', 'VARCHAR', 50);
  end);
end;

procedure TTestMigration.Down(Builder: TSchemaBuilder);
begin
  Builder.DropTable('TestMigratedTable');
end;

{ TMigrationsTest }

procedure TMigrationsTest.Run;
var
  Builder: TSchemaBuilder;
begin
  Log('🏗️ Running Migrations Builder Tests...');

  Builder := TSchemaBuilder.Create;
  try
    // Test Create Table
    Builder.CreateTable('TestUsers', procedure(T: TTableBuilder)
    begin
      T.Column('Id', 'INTEGER').PrimaryKey.Identity;
      T.Column('Name', 'VARCHAR', 100).NotNull;
      T.Column('Email', 'VARCHAR', 150).Nullable;
      T.Column('CreatedAt', 'TIMESTAMP').Default('CURRENT_TIMESTAMP');
    end);
    
    Log('   ✅ CreateTable operation defined.');
    
    // Test Add Column
    Builder.AddColumn('TestUsers', 'Age', 'INTEGER');
    Log('   ✅ AddColumn operation defined.');
    
    // Test Create Index
    Builder.CreateIndex('TestUsers', 'IX_TestUsers_Email', ['Email'], True);
    Log('   ✅ CreateIndex operation defined.');
    
    // Verify Operations Count
    if Builder.Operations.Count = 3 then
      Log('   ✅ Operations count matches (3).')
    else
      Log('   ❌ Operations count mismatch: ' + Builder.Operations.Count.ToString);
      
    // Inspect first operation
    if Builder.Operations[0] is TCreateTableOperation then
    begin
      var Op := TCreateTableOperation(Builder.Operations[0]);
      Log('   ✅ First operation is CreateTable: ' + Op.Name);
      Log('      Columns: ' + Op.Columns.Count.ToString);
    end;

    Log('');
    Log('📝 Generating SQL for Dialects...');
    
    var Dialects: TArray<ISQLDialect>;
    SetLength(Dialects, 5);
    Dialects[0] := TSQLiteDialect.Create;
    Dialects[1] := TPostgreSQLDialect.Create;
    Dialects[2] := TSQLServerDialect.Create;
    Dialects[3] := TFirebirdDialect.Create;
    Dialects[4] := TMySQLDialect.Create;
    
    var DialectNames: TArray<string> := ['SQLite', 'PostgreSQL', 'SQL Server', 'Firebird', 'MySQL'];
    
    for var i := 0 to High(Dialects) do
    begin
      Log('   🔹 ' + DialectNames[i] + ':');
      for var Op in Builder.Operations do
      begin
        var SQL := Dialects[i].GenerateMigration(Op);
        Log('      ' + SQL);
      end;
      Log('');
    end;

  finally
    Builder.Free;
  end;
  
  // --- Model Differ Test ---
  Log('🔍 Running Model Differ Tests...');
  
  var PrevModel := TSnapshotModel.Create;
  var CurrModel := TSnapshotModel.Create;
  try
    // Setup Previous Model (Empty)
    
    // Setup Current Model (1 Table)
    var Table := TSnapshotTable.Create;
    Table.Name := 'Users';
    var Col := TSnapshotColumn.Create;
    Col.Name := 'Id';
    Col.ColumnType := 'INTEGER';
    Col.IsPrimaryKey := True;
    Table.Columns.Add(Col);
    
    Col := TSnapshotColumn.Create;
    Col.Name := 'Name';
    Col.ColumnType := 'VARCHAR';
    Col.Length := 100;
    Table.Columns.Add(Col);
    
    CurrModel.Tables.Add(Table);
    
    // Diff 1: Empty -> Users
    var Ops := TModelDiffer.Diff(CurrModel, PrevModel);
    try
      Log('   Diff 1 (Add Table): ' + Ops.Count.ToString + ' operations.');
      if (Ops.Count > 0) and (Ops[0] is TCreateTableOperation) then
        Log('   ✅ Detected CreateTable Users')
      else
        Log('   ❌ Failed to detect CreateTable');
    finally
      Ops.Free;
    end;
    
    // Setup Previous Model to match Current
    var PrevTable := TSnapshotTable.Create;
    PrevTable.Name := 'Users';
    var PrevCol := TSnapshotColumn.Create;
    PrevCol.Name := 'Id';
    PrevCol.ColumnType := 'INTEGER';
    PrevCol.IsPrimaryKey := True;
    PrevTable.Columns.Add(PrevCol);
    
    PrevCol := TSnapshotColumn.Create;
    PrevCol.Name := 'Name';
    PrevCol.ColumnType := 'VARCHAR';
    PrevCol.Length := 100;
    PrevTable.Columns.Add(PrevCol);
    
    PrevModel.Tables.Add(PrevTable);
    
    // Modify Current: Add 'Email' column
    Col := TSnapshotColumn.Create;
    Col.Name := 'Email';
    Col.ColumnType := 'VARCHAR';
    Col.Length := 150;
    Table.Columns.Add(Col);
    
    // Diff 2: Users -> Users + Email
    Ops := TModelDiffer.Diff(CurrModel, PrevModel);
    try
      Log('   Diff 2 (Add Column): ' + Ops.Count.ToString + ' operations.');
      if (Ops.Count > 0) and (Ops[0] is TAddColumnOperation) then
        Log('   ✅ Detected AddColumn Email')
      else
        Log('   ❌ Failed to detect AddColumn');
    finally
      Ops.Free;
    end;
    
    // Diff 3: Users -> Empty (Drop Table)
    Ops := TModelDiffer.Diff(nil, PrevModel); // Current is nil/empty
    try
      Log('   Diff 3 (Drop Table): ' + Ops.Count.ToString + ' operations.');
      if (Ops.Count > 0) and (Ops[0] is TDropTableOperation) then
        Log('   ✅ Detected DropTable Users')
      else
        Log('   ❌ Failed to detect DropTable');
    finally
      Ops.Free;
    end;

  finally
    PrevModel.Free;
    CurrModel.Free;
  end;
  
  // --- Extractor Test ---
  Log('🔍 Running Extractor Tests...');
  
  // Create a temporary context with SQLite
  var Conn := TFDConnection.Create(nil);
  var Dialect: ISQLDialect := TSQLiteDialect.Create;
  // Context removed as it was unused and leaking
  try
    // Register Entities (Users is already registered in EntityDemo.Entities)
    // We need to ensure the context knows about them.
    // TDbContext usually discovers entities via RegisterEntity or OnModelCreating.
    // In EntityDemo, TTestDbContext registers them.
    // Let's use TTestDbContext from EntityDemo.Tests.Base if possible, or manually register.
    // Since TDbContext doesn't have a public RegisterEntity, we rely on OnModelCreating.
    // But we are using base TDbContext here.
    // Let's use the TTestDbContext defined in EntityDemo.Tests.Base (it's TEntityDemoContext).
    
    var DemoContext: TEntityDemoContext := TEntityDemoContext.Create(TFireDACConnection.Create(Conn, False), Dialect);
    try
      var Model := TDbContextModelExtractor.Extract(DemoContext);
      try
        Log('   Extracted Tables: ' + Model.Tables.Count.ToString);
        
        var UserTable := Model.FindTable('Users');
        if UserTable <> nil then
        begin
          Log('   ✅ Found Table: Users');
          Log('      Columns: ' + UserTable.Columns.Count.ToString);
          
          var IdCol := UserTable.FindColumn('Id');
          if IdCol <> nil then
            Log('      ✅ Found Column: Id (' + IdCol.ColumnType + ')')
          else
            Log('      ❌ Column Id not found');
        end
        else
          Log('   ❌ Table Users not found');
          
      finally
        Model.Free;
      end;
    finally
      DemoContext.Free;
    end;
  finally
    Dialect := nil;
    Conn.Free;
  end;

  // --- Generator Test ---
  Log('📝 Running Generator Tests...');
  
  // Reuse the Builder from the first test (we need to recreate it or use a new one)
  // Let's create a new simple builder for generation test
  var GenBuilder := TSchemaBuilder.Create;
  try
    GenBuilder.CreateTable('Products', procedure(T: TTableBuilder)
    begin
      T.Column('Id', 'INTEGER').PrimaryKey.Identity;
      T.Column('Name', 'VARCHAR', 200).NotNull;
      T.Column('Price', 'DECIMAL').Precision(18, 2);
    end);
    
    GenBuilder.AddColumn('Products', 'Stock', 'INTEGER', 0, False);
    
    var UnitCode := TMigrationGenerator.GenerateUnit('Migrations.Test', 'TMigration_20231001_Initial', GenBuilder.Operations);
    
    Log('   Generated Code:');
    Log('   ---------------------------------------------------');
    // Log only first few lines to avoid spamming
    var Lines := UnitCode.Split([sLineBreak]);
    for var i := 0 to Min(15, High(Lines)) do
      Log('   ' + Lines[i]);
    Log('   ... (truncated)');
    Log('   ---------------------------------------------------');
    
    if UnitCode.Contains('Builder.CreateTable(''Products''') and
       UnitCode.Contains('T.Column(''Name'', ''VARCHAR'', 200).NotNull;') and
       UnitCode.Contains('Builder.AddColumn(''Products'', ''Stock'', ''INTEGER'', 0, False);') then
      Log('   ✅ Generated code contains expected instructions.')
    else
      Log('   ❌ Generated code missing expected instructions.');
      
  finally
    GenBuilder.Free;
  end;

  // --- Runner Test ---
  Log('🏃 Running Migration Runner Tests...');
  
  // Register Test Migration
  RegisterMigration(TTestMigration.Create);
  
  // Create Context (using SQLite)
  var RunnerConn := TFDConnection.Create(nil);
  // Configure SQLite in Memory or File? Let's use file to be sure
  RunnerConn.DriverName := 'SQLite';
  RunnerConn.Params.Values['Database'] := TPath.Combine(ExtractFilePath(ParamStr(0)), 'runner_test.db');
  
  var RunnerDialect: ISQLDialect := TSQLiteDialect.Create;
  var RunnerContext: TDbContext := TDbContext.Create(TFireDACConnection.Create(RunnerConn, False), RunnerDialect);
  try
    // Ensure clean state
    try
      RunnerConn.ExecSQL('DROP TABLE IF EXISTS TestMigratedTable');
      RunnerConn.ExecSQL('DROP TABLE IF EXISTS __DextMigrations');
    except
    end;
    
    var Migrator := TMigrator.Create(RunnerContext);
    try
      Migrator.Migrate;
      Log('   ✅ Migration executed.');
      
      // Verify Table Exists
      var Tables := TStringList.Create;
      try
        RunnerConn.GetTableNames('', '', '', Tables);
        if Tables.IndexOf('TestMigratedTable') >= 0 then
          Log('   ✅ Table TestMigratedTable created.')
        else
          Log('   ❌ Table TestMigratedTable NOT created.');
      finally
        Tables.Free;
      end;
        
      // Verify History
      var Qry := RunnerConn.ExecSQLScalar('SELECT COUNT(*) FROM __DextMigrations WHERE Id = ''20231001_TestMigration''');
      if Integer(Qry) > 0 then
        Log('   ✅ Migration recorded in history.')
      else
        Log('   ❌ Migration NOT recorded in history.');
        
    finally
      Migrator.Free;
    end;
  finally
    RunnerContext.Free;
    RunnerDialect := nil;
    RunnerConn.Free;
  end;

  // --- CLI Test ---
  Log('💻 Running CLI Tests...');
  
  // Create a factory for the context
  var ContextFactory: TFunc<IDbContext> := function: IDbContext
  begin
    var C := TFDConnection.Create(nil);
    C.DriverName := 'SQLite';
    C.Params.Values['Database'] := TPath.Combine(ExtractFilePath(ParamStr(0)), 'runner_test.db');
    Result := TDbContext.Create(TFireDACConnection.Create(C, True), TSQLiteDialect.Create);
  end;
  
  var CLI := TDextCLI.Create(ContextFactory);
  try
    // Mock command line args? 
    // TDextCLI reads ParamStr. We can't easily mock ParamStr in a running app.
    // However, we can test the Command classes directly or overload Run to accept args.
    // For now, let's just instantiate the commands manually to verify they compile and run logic.
    
    Log('   Testing migrate:list command logic...');
    var ListCmd: IConsoleCommand := TMigrateListCommand.Create(ContextFactory);
    ListCmd.Execute([]);
    Log('   ✅ migrate:list executed.');
    
    Log('   Testing migrate:up command logic...');
    var UpCmd: IConsoleCommand := TMigrateUpCommand.Create(ContextFactory);
    UpCmd.Execute([]);
    Log('   ✅ migrate:up executed.');
    
  finally
    CLI.Free;
  end;

  Log('');
end;

end.
