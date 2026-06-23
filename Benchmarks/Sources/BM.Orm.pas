unit BM.Orm;

interface

uses
  Spring.Benchmark;

procedure BM_Orm_RawDataset_Loop(const state: TState);
procedure BM_Orm_DextHydration_Loop(const state: TState);
procedure BM_Orm_Micro_Allocations(const state: TState);
procedure BM_Orm_Micro_ReaderGetValue(const state: TState);
procedure BM_Orm_Micro_RttiSetValue(const state: TState);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  Data.DB,
  Dext.Collections,
  Dext.Entity,
  Dext.Entity.Context,
  Dext.Entity.Attributes,
  Dext.Core.Reflection,
  Dext.Entity.ProxyFactory;

type
  [Table('BenchmarkUsers')]
  TBenchmarkUser = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
    FAge: Integer;
  public
    [PK]
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Email: string read FEmail write FEmail;
    property Age: Integer read FAge write FAge;
  end;

var
  GOptions: TDbContextOptions;
  GCtx: TDbContext;

procedure SetupDatabase;
var
  i: Integer;
  Tx: IDbTransaction;
  Cmd: IDbCommand;
begin
  GOptions := TDbContextOptions.Create;
  GOptions.UseSQLite(':memory:');
  GCtx := TDbContext.Create(GOptions, nil);
  GCtx.ModelBuilder.Entity<TBenchmarkUser>();
  GCtx.EnsureCreated;

  // Insert 5,000 mock users inside a transaction for maximum speed
  Tx := GCtx.Connection.BeginTransaction;
  try
    for i := 1 to 5000 do
    begin
      Cmd := GCtx.Connection.CreateCommand(
        'INSERT INTO BenchmarkUsers (Id, Name, Email, Age) VALUES (:Id, :Name, :Email, :Age)'
      );
      Cmd.AddParam('Id', i);
      Cmd.AddParam('Name', 'User Name ' + IntToStr(i));
      Cmd.AddParam('Email', 'username' + IntToStr(i) + '@example.com');
      Cmd.AddParam('Age', 20 + (i mod 50));
      Cmd.Execute;
    end;
    Tx.Commit;
  except
    Tx.Rollback;
    raise;
  end;
end;

procedure CleanupDatabase;
begin
  if Assigned(GCtx) then
    GCtx.Free;
  if Assigned(GOptions) then
    GOptions.Free;
end;

var
  GDummySum: Integer = 0;
  GDummyString: string = '';

procedure BM_Orm_RawDataset_Loop(const state: TState);
var
  Cmd: IDbCommand;
  Reader: IDbReader;
  Id, Age: Integer;
  Name, Email: string;
begin
  while state.KeepRunning do
  begin
    Cmd := GCtx.Connection.CreateCommand('SELECT Id, Name, Email, Age FROM BenchmarkUsers');
    Reader := Cmd.ExecuteQuery;
    while Reader.Next do
    begin
      Id := Reader.GetValue('Id').AsInteger;
      Name := Reader.GetValue('Name').AsString;
      Email := Reader.GetValue('Email').AsString;
      Age := Reader.GetValue('Age').AsInteger;
      
      Inc(GDummySum, Id + Age);
      GDummyString := Name + Email;
    end;
    Reader.Close;
  end;
end;

procedure BM_Orm_DextHydration_Loop(const state: TState);
var
  List: IList<TBenchmarkUser>;
begin
  while state.KeepRunning do
  begin
    // Fetch all 5000 rows as un-tracked Entities (using our fast reflection mapping path)
    List := GCtx.Entities<TBenchmarkUser>.AsNoTracking.ToList;
  end;
end;

procedure BM_Orm_Micro_Allocations(const state: TState);
var
  i: Integer;
  Obj: TBenchmarkUser;
begin
  while state.KeepRunning do
  begin
    for i := 1 to 5000 do
    begin
      Obj := TEntityProxyFactory.CreateInstance<TBenchmarkUser>(GCtx);
      Obj.Free;
    end;
  end;
end;

procedure BM_Orm_Micro_ReaderGetValue(const state: TState);
var
  Cmd: IDbCommand;
  Reader: IDbReader;
  Val: TValue;
begin
  Cmd := GCtx.Connection.CreateCommand('SELECT Id, Name, Email, Age FROM BenchmarkUsers');
  while state.KeepRunning do
  begin
    Reader := Cmd.ExecuteQuery;
    while Reader.Next do
    begin
      Val := Reader.GetValue(0);
      Val := Reader.GetValue(1);
      Val := Reader.GetValue(2);
      Val := Reader.GetValue(3);
    end;
    Reader.Close;
  end;
end;

procedure BM_Orm_Micro_RttiSetValue(const state: TState);
var
  Obj: TBenchmarkUser;
  PropId, PropName, PropEmail, PropAge: TRttiProperty;
  RType: TRttiType;
  ValId, ValName, ValEmail, ValAge: TValue;
  i: Integer;
begin
  RType := TReflection.Context.GetType(TypeInfo(TBenchmarkUser));
  PropId := RType.GetProperty('Id');
  PropName := RType.GetProperty('Name');
  PropEmail := RType.GetProperty('Email');
  PropAge := RType.GetProperty('Age');

  ValId := TValue.From<Integer>(42);
  ValName := TValue.From<string>('Test');
  ValEmail := TValue.From<string>('test@example.com');
  ValAge := TValue.From<Integer>(30);

  Obj := TBenchmarkUser.Create;
  try
    while state.KeepRunning do
    begin
      for i := 1 to 5000 do
      begin
        TReflection.SetValue(Pointer(Obj), PropId, ValId);
        TReflection.SetValue(Pointer(Obj), PropName, ValName);
        TReflection.SetValue(Pointer(Obj), PropEmail, ValEmail);
        TReflection.SetValue(Pointer(Obj), PropAge, ValAge);
      end;
    end;
  finally
    Obj.Free;
  end;
end;

initialization
  SetupDatabase;
  Benchmark(BM_Orm_RawDataset_Loop, 'BM_Orm_RawDataset_Loop');
  Benchmark(BM_Orm_DextHydration_Loop, 'BM_Orm_DextHydration_Loop');
  Benchmark(BM_Orm_Micro_Allocations, 'BM_Orm_Micro_Allocations');
  Benchmark(BM_Orm_Micro_ReaderGetValue, 'BM_Orm_Micro_ReaderGetValue');
  Benchmark(BM_Orm_Micro_RttiSetValue, 'BM_Orm_Micro_RttiSetValue');

finalization
  CleanupDatabase;

end.
