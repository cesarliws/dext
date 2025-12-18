unit Dext.Entity.Pooling.Test;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  System.Classes,
  System.Threading, 
  System.Diagnostics,
  FireDAC.Comp.Client,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.Dialects,
  Dext.DI.Core,
  Dext.DI.Interfaces,
  Dext.DI.Extensions,
  Dext.Entity,
  Dext.Entity.Setup,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Attributes,
  Dext.Entity.Core;

type
  [Table('pooling_test')]
  TPoolTestEntity = class
  private
    FId: Integer;
    FName: string;
  public
    [PK, AutoInc, Column('id')]
    property Id: Integer read FId write FId;
    [Column('name')]
    property Name: string read FName write FName;
  end;

  TPoolTestContext = class(TDbContext)
  public
    function Entities: IDbSet<TPoolTestEntity>;
  end;

  [TestFixture]
  TCachingAndPoolingTests = class
  public
    [Test]
    procedure TestModelCachePerformance;
    [Test]
    procedure TestParallelPooling;
  end;

implementation

{ TPoolTestContext }

function TPoolTestContext.Entities: IDbSet<TPoolTestEntity>;
begin
  Result := inherited Entities<TPoolTestEntity>;
end;

{ TCachingAndPoolingTests }

procedure TCachingAndPoolingTests.TestModelCachePerformance;
var
  SW: TStopwatch;
  Context: TPoolTestContext;
  FDConn: TFDConnection;
  DbConnection: IDbConnection;
  Dialect: ISQLDialect;
  i: Integer;
begin
  // Create FireDAC connection
  FDConn := TFDConnection.Create(nil);
  FDConn.DriverName := 'SQLite';
  FDConn.Params.Database := ':memory:';
  
  DbConnection := TFireDACConnection.Create(FDConn, True);
  Dialect := TSQLiteDialect.Create;

  SW := TStopwatch.StartNew;
  
  // First creation (builds model)
  Context := TPoolTestContext.Create(DbConnection, Dialect);
  Assert.IsNotNull(Context);
  Context.Free;
  
  var FirstRun := SW.ElapsedMilliseconds;

  SW.Reset;
  SW.Start;
  // Second creation (should hit cache)
  for i := 1 to 1000 do
  begin
    Context := TPoolTestContext.Create(DbConnection, Dialect);
    Context.Free;
  end;
  var SecondRun := SW.ElapsedMilliseconds;
  
  System.Writeln(Format('1st Create: %d ms | 1000 Creates: %d ms', [FirstRun, SecondRun]));
  
  // 1000 creations should be fast if cached. 
  Assert.IsTrue(SecondRun < 500, 'Model Caching failed to optimize creation time.');
end;

procedure TCachingAndPoolingTests.TestParallelPooling;
var
  FDConn: TFDConnection;
  DbConnection: IDbConnection;
  Dialect: ISQLDialect;
begin
  // Create a shared FireDAC connection
  FDConn := TFDConnection.Create(nil);
  FDConn.DriverName := 'SQLite';
  FDConn.Params.Database := 'test_pool.db';
  
  DbConnection := TFireDACConnection.Create(FDConn, True);
  Dialect := TSQLiteDialect.Create;

  // Run 50 parallel requests
  TParallel.&For(0, 49, 
    procedure(i: Integer)
    var
      Ctx: TPoolTestContext;
    begin
       // Create context (should use pooled connection)
       Ctx := TPoolTestContext.Create(DbConnection, Dialect);
       try
         Assert.IsNotNull(Ctx);
         
         // Just verify we can access entities
         Assert.IsNotNull(Ctx.Entities);
         
       finally
         Ctx.Free;
       end;
    end);
end;

end.
