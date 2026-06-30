unit EntityDemo.Tests.Migrations;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Dext.Collections,
  Dext.Entity.Migrations.Operations,
  Dext.Entity.Migrations.Builder,
  Dext.Entity.Migrations.Model,
  Dext.Entity.Migrations.Differ,
  Dext.Entity.Migrations.Extractor,
  Dext.Entity.Migrations.Generator,
  Dext.Entity.Migrations,
  Dext.Entity.Migrations.Runner,
  Dext.Hosting.CLI,
  Dext.Hosting.CLI.Args,
  Dext.Hosting.CLI.Commands.MigrateList,
  Dext.Hosting.CLI.Commands.MigrateUp,
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
  Op: TCreateTableOperation;
  Dialects: TArray<ISQLDialect>;
  DialectNames: TArray<string>;
  i: Integer;
  OpGeneric: TMigrationOperation;
  SQL: string;
  PrevModel, CurrModel: TSnapshotModel;
  Table, PrevTable: TSnapshotTable;
  Col, PrevCol, IdCol: TSnapshotColumn;
  Ops: IList<TMigrationOperation>;
  Conn: TFDConnection;
  Dialect: ISQLDialect;
  DemoContext: TEntityDemoContext;
  Model: TSnapshotModel;
  UserTable: TSnapshotTable;
  GenBuilder: TSchemaBuilder;
  UnitCode: string;
  Lines: TArray<string>;
  RunnerConn: TFDConnection;
  RunnerDialect: ISQLDialect;
  RunnerContext: TDbContext;
  Migrator: TMigrator;
  Tables: TStringList;
  Qry: Variant;
  ContextFactory: TFunc<IDbContext>;
  CLI: TDextCLI;
  Args: TCommandLineArgs;
  ListCmd, UpCmd: IConsoleCommand;
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
      Op := TCreateTableOperation(Builder.Operations[0]);
      Log('   ✅ First operation is CreateTable: ' + Op.Name);
      Log('      Columns: ' + Op.Columns.Count.ToString);
    end;

    Log('');
    Log('📝 Generating SQL for Dialects...');

    SetLength(Dialects, 5);
    Dialects[0] := TSQLiteDialect.Create;
    Dialects[1] := TPostgreSQLDialect.Create;
    Dialects[2] := TSQLServerDialect.Create;
    Dialects[3] := TFirebirdDialect.Create;
    Dialects[4] := TMySQLDialect.Create;

    DialectNames := ['SQLite', 'PostgreSQL', 'SQL Server', 'Firebird', 'MySQL'];

    for i := 0 to High(Dialects) do
    begin
      Log('   🔹 ' + DialectNames[i] + ':');
      for OpGeneric in Builder.Operations do
      begin
        SQL := Dialects[i].GenerateMigration(OpGeneric);
        Log('      ' + SQL);
      end;
      Log('');
    end;

  finally
    Builder.Free;
  end;

  // --- Model Differ Test ---
  Log('🔍 Running Model Differ Tests...');

  PrevModel := TSnapshotModel.Create;
  CurrModel := TSnapshotModel.Create;
  try
    // Setup Previous Model (Empty)

    // Setup Current Model (1 Table)
    Table := TSnapshotTable.Create;
    Table.Name := 'Users';
    Col := TSnapshotColumn.Create;
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
    Ops := TModelDiffer.Diff(CurrModel, PrevModel);
    Log('   Diff 1 (Add Table): ' + Ops.Count.ToString + ' operations.');
    if (Ops.Count > 0) and (Ops[0] is TCreateTableOperation) then
      Log('   ✅ Detected CreateTable Users')
    else
      Log('   ❌ Failed to detect CreateTable');

    // Setup Previous Model to match Current
    PrevTable := TSnapshotTable.Create;
    PrevTable.Name := 'Users';
    PrevCol := TSnapshotColumn.Create;
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
      // Ops.Free;
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
      // Ops.Free;
    end;

  finally
    PrevModel.Free;
    CurrModel.Free;
  end;

  // --- Extractor Test ---
  Log('🔍 Running Extractor Tests...');

  // Create a temporary context with SQLite
  Conn := TFDConnection.Create(nil);
  Dialect := TSQLiteDialect.Create;
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

    DemoContext := TEntityDemoContext.Create(TFireDACConnection.Create(Conn, False), Dialect);
    try
      Model := TDbContextModelExtractor.Extract(DemoContext);
      try
        Log('   Extracted Tables: ' + Model.Tables.Count.ToString);

        UserTable := Model.FindTable('Users');
        if UserTable <> nil then
        begin
          Log('   ✅ Found Table: Users');
          Log('      Columns: ' + UserTable.Columns.Count.ToString);

          IdCol := UserTable.FindColumn('Id');
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
  GenBuilder := TSchemaBuilder.Create;
  try
    GenBuilder.CreateTable('Products', procedure(T: TTableBuilder)
    begin
      T.Column('Id', 'INTEGER').PrimaryKey.Identity;
      T.Column('Name', 'VARCHAR', 200).NotNull;
      T.Column('Price', 'DECIMAL').Precision(18, 2);
    end);

    GenBuilder.AddColumn('Products', 'Stock', 'INTEGER', 0, False);

    UnitCode := TMigrationGenerator.GenerateUnit('Migrations.Test', 'TMigration_20231001_Initial', GenBuilder.Operations);

    Log('   Generated Code:');
    Log('   ---------------------------------------------------');
    // Log only first few lines to avoid spamming
    Lines := UnitCode.Split([sLineBreak]);
    for i := 0 to Min(15, High(Lines)) do
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
  RunnerConn := TFDConnection.Create(nil);
  // Configure SQLite in Memory or File? Let's use file to be sure
  RunnerConn.DriverName := 'SQLite';
  RunnerConn.Params.Values['Database'] := TPath.Combine(ExtractFilePath(ParamStr(0)), 'runner_test.db');

  RunnerDialect := TSQLiteDialect.Create;
  RunnerContext := TDbContext.Create(TFireDACConnection.Create(RunnerConn, False), RunnerDialect);
  try
    // Ensure clean state
    try
      RunnerConn.ExecSQL('DROP TABLE IF EXISTS TestMigratedTable');
      RunnerConn.ExecSQL('DROP TABLE IF EXISTS __DextMigrations');
    except
    end;

    Migrator := TMigrator.Create(RunnerContext);
    try
      Migrator.Migrate;
      Log('   ✅ Migration executed.');

      // Verify Table Exists
      Tables := TStringList.Create;
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
      Qry := RunnerConn.ExecSQLScalar('SELECT COUNT(*) FROM __DextMigrations WHERE Id = ''20231001_TestMigration''');
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
  ContextFactory := function: IDbContext
  var
    C: TFDConnection;
  begin
    C := TFDConnection.Create(nil);
    C.DriverName := 'SQLite';
    C.Params.Values['Database'] := TPath.Combine(ExtractFilePath(ParamStr(0)), 'runner_test.db');
    Result := TDbContext.Create(TFireDACConnection.Create(C, True), TSQLiteDialect.Create);
  end;

  CLI := TDextCLI.Create(ContextFactory);
  try
    // Mock command line args?
    // TDextCLI reads ParamStr. We can't easily mock ParamStr in a running app.
    // However, we can test the Command classes directly or overload Run to accept args.
    // For now, let's just instantiate the commands manually to verify they compile and run logic.

    Args := TCommandLineArgs.Create;
    try
      Log('   Testing migrate:list command logic...');
      ListCmd := TMigrateListCommand.Create(ContextFactory);
      ListCmd.Execute(Args);
      Log('   ✅ migrate:list executed.');

      Log('   Testing migrate:up command logic...');
      UpCmd := TMigrateUpCommand.Create(ContextFactory);
      UpCmd.Execute(Args);
      Log('   ✅ migrate:up executed.');
    finally
      Args.Free;
    end;

  finally
    CLI.Free;
  end;

  Log('');
end;

end.
