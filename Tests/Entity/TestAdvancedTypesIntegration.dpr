program TestAdvancedTypesIntegration;

{$APPTYPE CONSOLE}
{$TYPEINFO ON}
{$METHODINFO ON}

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  System.DateUtils,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Phys.PG,
  FireDAC.Phys.PGDef,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Error,
  FireDAC.UI.Intf,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  Dext,
  Dext.Collections,
  Dext.Entity.Core,
  Dext.Entity.Attributes,
  Dext.Entity.Context,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Mapping,
  Dext.Entity.TypeConverters,
  Dext.Entity.Dialects,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Base;

type
  [Table('test_advanced_entities')]
  TAdvancedEntity = class
  private
    FId: Integer;
    FDate: TDate;
    FTime: TTime;
    FDateTime: TDateTime;
    FDescription: string;
    FData: TBytes;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    [Column('date_col')]
    property Date: TDate read FDate write FDate;
    [Column('time_col')]
    property Time: TTime read FTime write FTime;
    [Column('datetime_col')]
    property DateTime: TDateTime read FDateTime write FDateTime;
    [Column('description')]
    property Description: string read FDescription write FDescription;
    [Column('binary_data')]
    property Data: TBytes read FData write FData;
  end;

  TAdvancedDbContext = class(TDbContext)
  private
    function GetEntities: IDbSet<TAdvancedEntity>;
  public
    property AdvancedEntities: IDbSet<TAdvancedEntity> read GetEntities;
  end;

{ TAdvancedDbContext }

function TAdvancedDbContext.GetEntities: IDbSet<TAdvancedEntity>;
begin
  Result := Entities<TAdvancedEntity>;
end;

procedure ExecSQL(Db: TDbContext; const SQL: string);
var
  Cmd: IDbCommand;
begin
  Cmd := Db.Connection.CreateCommand(SQL) as IDbCommand;
  Cmd.ExecuteNonQuery;
end;

procedure TestAdvanced(Db: TAdvancedDbContext);
var
  Entity, Loaded: TAdvancedEntity;
  List: IList<TAdvancedEntity>;
  TestDate: TDate;
  TestTime: TTime;
  TestDateTime: TDateTime;
  TestData: TBytes;
  i: Integer;
begin
  WriteLn('► Testing Advanced Types Integration...');
  
  TestDate := EncodeDate(2025, 12, 19);
  TestTime := EncodeTime(14, 30, 0, 0);
  TestDateTime := Now;
  
  SetLength(TestData, 10);
  for i := 0 to 9 do TestData[i] := 65 + i; // 'ABCDEFGHIJ'

  Entity := TAdvancedEntity.Create;
  Entity.Date := TestDate;
  Entity.Time := TestTime;
  Entity.DateTime := TestDateTime;
  Entity.Description := 'This is a long text description that should be stored as TEXT in PostgreSQL.';
  Entity.Data := TestData;

  WriteLn('  Step 1: Save');
  try
    Db.AdvancedEntities.Add(Entity);
    WriteLn('  Debug: Entity added to DbSet');
    Db.SaveChanges;
    WriteLn('  Debug: SaveChanges completed');
  except
    on E: Exception do
    begin
      WriteLn('  DEBUG Save Failure: ', E.Message);
      raise;
    end;
  end;
  
  var OrigDescription := Entity.Description;
  
  WriteLn('  Step 2: Clear and Reload');
  Db.Clear;
  List := Db.AdvancedEntities.List;
  
  if List.Count = 0 then
    raise Exception.Create('Entity was not saved');
    
  Loaded := List[0];
  
  WriteLn('  Step 3: Verify Data');
  
  if DateOf(Loaded.Date) <> DateOf(TestDate) then
    raise Exception.CreateFmt('Date mismatch: Expected %s, got %s', [DateToStr(TestDate), DateToStr(Loaded.Date)]);
    
  if TimeOf(Loaded.Time) <> TimeOf(TestTime) then
    raise Exception.CreateFmt('Time mismatch: Expected %s, got %s', [TimeToStr(TestTime), TimeToStr(Loaded.Time)]);

  // Use a small tolerance for DateTime comparison (PostgreSQL might truncate milliseconds depending on precision)
  if Abs(Loaded.DateTime - TestDateTime) > (1 / SecsPerDay) then
     raise Exception.CreateFmt('DateTime mismatch: Expected %s, got %s', [DateTimeToStr(TestDateTime), DateTimeToStr(Loaded.DateTime)]);

  if Loaded.Description <> OrigDescription then
  begin
    WriteLn(Format('  DEBUG: Description Expected: "%s"', [OrigDescription]));
    WriteLn(Format('  DEBUG: Description Got:      "%s"', [Loaded.Description]));
    raise Exception.Create('Description mismatch');
  end;

  if Length(Loaded.Data) <> Length(TestData) then
    raise Exception.Create('Binary data length mismatch');
    
  for i := 0 to High(TestData) do
    if Loaded.Data[i] <> TestData[i] then
      raise Exception.CreateFmt('Binary data mismatch at index %d', [i]);

  WriteLn('  ✓ All advanced types verified successfully');
end;

var
  Db: TAdvancedDbContext;
  Connection: IDbConnection;
  FDConn: TFDConnection;
  Dialect: ISQLDialect;
begin
  try
    FDConn := TFDConnection.Create(nil);
    FDConn.DriverName := 'PG';
    FDConn.Params.Values['Server'] := 'localhost';
    FDConn.Params.Values['Port'] := '5432';
    FDConn.Params.Values['Database'] := 'dext_test';
    FDConn.Params.Values['User_Name'] := 'postgres';
    FDConn.Params.Values['Password'] := 'root';
    
    Connection := TFireDACConnection.Create(FDConn, True);
    Dialect := TPostgreSQLDialect.Create;

    Db := TAdvancedDbContext.Create(Connection, Dialect);
    try
      // Clear previous
      var C: IInterface := Connection.CreateCommand('DROP TABLE IF EXISTS test_advanced_entities');
      (C as IDbCommand).ExecuteNonQuery;
      
      if Db.AdvancedEntities <> nil then;
      Db.EnsureCreated;
      
      TestAdvanced(Db);
      
      WriteLn('🎉 SUCCESS!');
    finally
      Db.Free;
    end;
  except
    on E: Exception do WriteLn('❌ FAILED: ' + E.Message);
  end;
  WriteLn('Done.');

  if (DebugHook <> 0) then
    ReadLn;
end.
