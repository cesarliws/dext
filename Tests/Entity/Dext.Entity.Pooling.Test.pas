unit Dext.Entity.Pooling.Test;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  System.Classes,
  System.Threading, 
  System.Diagnostics,
  Dext.DI.Core,
  Dext.DI.Interfaces,
  Dext.Persistence,
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
  Result := DataSet(TypeInfo(TPoolTestEntity)) as IDbSet<TPoolTestEntity>;
end;

{ TCachingAndPoolingTests }

procedure TCachingAndPoolingTests.TestModelCachePerformance;
var
  SW: TStopwatch;
  Services: TDextServices;
  Provider: IServiceProvider;
  Context: TPoolTestContext;
  i: Integer;
begin
  Services := TDextServices.Create;
  Services.AddDbContext<TPoolTestContext>(nil);
  Provider := Services.BuildServiceProvider;

  SW := TStopwatch.StartNew;
  
  // First creation (builds model)
  Context := Provider.GetService<TPoolTestContext>;
  Assert.IsNotNull(Context);
  Context.Free;
  
  var FirstRun := SW.ElapsedMilliseconds;

  SW.Restart;
  // Second creation (should hit cache)
  for i := 1 to 1000 do
  begin
    Context := Provider.GetService<TPoolTestContext>;
    Context.Free;
  end;
  var SecondRun := SW.ElapsedMilliseconds;
  
  System.Writeln(Format('1st Create: %d ms | 1000 Creates: %d ms', [FirstRun, SecondRun]));
  
  // 1000 creations should be fast if cached. 
  Assert.IsTrue(SecondRun < 500, 'Model Caching failed to optimize creation time.');
end;

procedure TCachingAndPoolingTests.TestParallelPooling;
var
  Services: TDextServices;
  Provider: IServiceProvider;
begin
  Services := TDextServices.Create;
  
  // Note: Using SQLite :memory: might not be best for pooling tests as each connection is unique DB.
  // Using a file ensures shared logic.
  Services.AddDbContext<TPoolTestContext>(
    procedure(Options: TDbContextOptions)
    begin
      Options.UseSQLite('test_pool.db');
      Options.WithPooling(True, 10);
    end);
  Provider := Services.BuildServiceProvider;

  // Run 50 parallel requests
  TParallel.For(0, 49, 
    procedure(i: Integer)
    begin
       // Simulate Request Scope
       var Scope := Provider.CreateScope;
       try
         var Ctx := Scope.ServiceProvider.GetService<TPoolTestContext>;
         Assert.IsNotNull(Ctx);
         
         // Access Connection to ensure it's open and valid
         Assert.IsTrue(Ctx.Connection.IsConnected); 
         
       finally
         // Scope dies, Context dies, Connection returns to pool
         Scope.Dispose; 
       end;
    end);
end;

end.
