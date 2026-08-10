program Web.FastPath.OrmPool;

{$APPTYPE CONSOLE}

{$I Dext.inc}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  System.Classes,
  
  // Dext Core & Collections
  Dext,
  Dext.Collections.Pool,
  Dext.Entity,
  Dext.Entity.Core,
  Dext.Entity.Context,
  Dext.Entity.DbSet,
  System.Rtti,
  Dext.Web,
  Dext.Web.Interfaces,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.DI.Interfaces,

  // Storage & Drivers
  FireDAC.Comp.Client,
  
  // Logging
  Dext.Logging;

type
  { --- ENTITY: Benchmark User --- }
  [Table('BenchmarkUsers')]
  TBenchmarkUser = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
    FCity: string;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Email: string read FEmail write FEmail;
    property City: string read FCity write FCity;
  end;

  TAppDbContext = class(TDbContext)
  protected
    procedure OnModelCreating(Builder: TModelBuilder); override;
  end;

{ TAppDbContext }

procedure TAppDbContext.OnModelCreating(Builder: TModelBuilder);
begin
  inherited;
  Builder.Entity<TBenchmarkUser>;
end;

var
  DbPool: IDextPool<TAppDbContext>;

procedure SeedDatabase(const APool: IDextPool<TAppDbContext>);
var
  SeedProc: TProc<TAppDbContext>;
begin
  SeedProc := procedure(Ctx: TAppDbContext)
    var
      User: TBenchmarkUser;
      Idx: Integer;
    begin
      Ctx.EnsureCreated;

      if Ctx.Entities<TBenchmarkUser>.ToList.Count = 0 then
      begin
        Writeln('Seeding 100 benchmark users...');
        for Idx := 1 to 100 do
        begin
          User := TBenchmarkUser.Create;
          User.Name := 'User ' + IntToStr(Idx);
          User.Email := 'user' + IntToStr(Idx) + '@dext.dev';
          User.City := 'City ' + IntToStr(Idx mod 10);
          Ctx.Entities<TBenchmarkUser>.Add(User);
        end;
        Ctx.SaveChanges;
        Writeln('Database seeded successfully.');
      end;
    end;
  APool.Use(SeedProc);
end;

var
  App: IWebApplication;
  Config: TDextPoolConfig;
  Factory: TFunc<TAppDbContext>;
  ResetAction: TProc<TAppDbContext>;

begin
  SetConsoleCharSet;
  try
    Writeln('Dext FastPath Minimal WebAPI with DbContext Pooling & Fast ORM');
    Writeln('===============================================================');
    Writeln('');

    // 1. Initialize Thread-Safe DbContext Pool (0ms DI Overhead per request)
    Config := TDextPoolConfig.Default;
    Config.MinSize := 5;
    Config.MaxSize := 50;

    Factory := function: TAppDbContext
      var
        Opts: TDbContextOptions;
      begin
        Opts := TDbContextOptions.Create;
        Opts.UseSQLite('fastpath_benchmark.db');
        Opts.Pooling := True;
        Result := TAppDbContext.Create(Opts);
      end;

    ResetAction := procedure(Ctx: TAppDbContext)
      begin
        Ctx.ResetState; // Clear change tracker & rollback transactions
      end;

    DbPool := TDextPool<TAppDbContext>.Create(Config, Factory, ResetAction);

    // 2. Seed initial benchmark data
    SeedDatabase(DbPool);

    // 3. Configure FastPath Minimal WebAPI Routes
    App := WebApplication;
    App.Services.AddSingleton<IDextPool<TAppDbContext>>(DbPool);

    // FastPath Direct Query Streaming (/fastusers):
    App.GetApplicationBuilder.MapFast('GET', '/fastusers',
      procedure(const Req: IHttpRequest; const Res: IHttpResponse)
      var
        Ctx: TAppDbContext;
      begin
        if DbPool.Acquire(Ctx) then
        begin
          try
            Res.Status(200).WriteJson(Ctx.UseSql('SELECT "Id", "Name", "Email", "City" FROM "BenchmarkUsers"'));
          finally
            DbPool.Release(Ctx);
          end;
        end;
      end);

    // FastPath Fluent ORM Streaming (/users):
    App.GetApplicationBuilder.MapFast('GET', '/users',
      procedure(const Req: IHttpRequest; const Res: IHttpResponse)
      var
        Ctx: TAppDbContext;
      begin
        if DbPool.Acquire(Ctx) then
        begin
          try
            Res.WriteJson(Ctx.Entities<TBenchmarkUser>);
          finally
            DbPool.Release(Ctx);
          end;
        end;
      end);

    Writeln('FastPath Server listening on http://localhost:5050');
    Writeln(' - GET http://localhost:5050/fastusers (FastPath Raw Direct Query)');
    Writeln(' - GET http://localhost:5050/users     (FastPath Fluent ORM Streaming)');
    Writeln('');

    App.Run(5050);

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  App := nil;
  DbPool := nil;
  ConsolePause;
end.
