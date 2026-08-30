program ECON26.Faturamento.Api;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  Dext,
  Dext.Entity,
  Dext.Web,
  Dext.Web.DataApi,
  Dext.Web.Results,
  Dext.Web.Interfaces,
  Dext.DI.Interfaces,
  Dext.OpenAPI.Generator,
  Dext.Swagger.Middleware,
  Dext.Logging,
  Dext.Logging.Extensions,
  Dext.Logging.Console,
  Product in 'Product.pas',
  Order in 'Order.pas',
  AppDbContext in 'AppDbContext.pas',
  OrderService in 'OrderService.pas',
  OrdersController in 'OrdersController.pas';

type
  TStartup = class(TInterfacedObject, IStartup)
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  end;

{ TStartup }

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  Services.AddLogging(
    procedure(Builder: ILoggingBuilder)
    begin
      Builder
        .SetMinimumLevel(TLogLevel.Information)
        .AddConsole
        .AddTelemetry;
    end);

  Services
    .AddDbContext<TAppDbContext>(
      procedure(Options: TDbContextOptions)
      begin
        Options.UseSQLite('faturamento.db');
        Options.Pooling := True;
      end)
    .AddScoped<IOrderService, TOrderService>
    .AddControllers;

  Services.AddHealthChecks.Build;
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive);

  App.Builder
    .UseDeveloperExceptionPage
    .UseExceptionHandler
    .UseHttpLogging

    { Gancho — denso. Atributos no tipo; genéricos no Map*. }


    .MapGet<TAppDbContext, TBuscaProduto, IResult>('/api/products/search',
      function(Db: TAppDbContext; Q: TBuscaProduto): IResult
      begin
        var P := Prototype.Entity<TProduct>;
        var Products := Db.Products
                          .Where((P.Active = True) and P.Name.Contains(Q.Termo))
                          .Take(20).ToList;
        Result := Results.Ok(Products);
      end)

     .MapPost<TNovoPedido, IOrderService, IResult>('/api/orders',
      function(Dto: TNovoPedido; Orders: IOrderService): IResult
      begin
        var Id := Orders.Place(Dto.ProductId, Dto.Qty);
        Result := Results.Created<Integer>('/api/orders/' + IntToStr(Id), Id);
      end)

    .MapGet<IResult>('/hello',
      function: IResult
      begin
        Result := Results.Ok('ECON26 · Dext 1.0');
      end)

    { DataAPI só leitura. RequireAuth comentado no palco (sem JWT no projetor).
      A cadeia fica visível — senão DataAPI parece dump. }
    .MapDataApi<TProduct>('/api/products',
      DataApiOptions
        .Allow([amGet, amGetList])
        // .RequireAuth
        .RequireReadRole('consulta,admin')
        // .RequireWriteRole('admin')
        .UseCamelCase
        .DbContext<TAppDbContext>
        .UseSwagger);

  App.MapControllers;

  App.Builder.UseSwagger(
    SwaggerOptions
      .Title('ECON26 · Faturamento')
      .Description('CQRS no palco: DataAPI lê, Controller escreve.')
      .Version('1.0')
      .Server('http://localhost:5000', 'Palco'));
end;

procedure SeedDatabase(const Provider: IServiceProvider);
var
  Scope: IServiceScope;
  Db: TAppDbContext;
  P: TProduct;
begin
  Scope := Provider.CreateScope;
  try
    Db := Scope.ServiceProvider.GetService(TAppDbContext) as TAppDbContext;
    if Db = nil then
      Exit;

    Db.EnsureCreated;

    if Db.Products.QueryAll.Count = 0 then
    begin
      Writeln('Seeding products...');

      P := TProduct.Create;
      P.Name := 'Ada Lovelace';
      P.Price := 99.90;
      P.Active := True;
      P.Cost := 40;
      Db.Products.Add(P);

      P := TProduct.Create;
      P.Name := 'Produto inativo';
      P.Price := 10;
      P.Active := False;
      P.Cost := 5;
      Db.Products.Add(P);

      Db.SaveChanges;
      Writeln('Database seeded.');
    end;
  finally
    Scope := nil;
  end;
end;

var
  App: IWebApplication;
  Provider: IServiceProvider;
begin
  SetConsoleCharSet;
  try
    Writeln('ECON26 · Faturamento API');
    Writeln('========================');

    App := WebApplication;
    App.UseStartup(TStartup.Create);

    Provider := App.BuildServices;
    if Provider <> nil then
      SeedDatabase(Provider);

    Writeln('http://localhost:5000');
    Writeln('Swagger: http://localhost:5000/swagger');
    Writeln('Hello:   http://localhost:5000/hello');
    App.Run(5000);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  App := nil;
  Provider := nil;
  ConsolePause;
end.
