unit OrderAPI.Startup;

interface

uses
  System.IOUtils,
  System.SysUtils,
  Dext, Dext.DI.Interfaces,        // Base interfaces and DI
  Dext.Utils,  // Base interfaces and DI
  Dext.Entity, // Persistence features
  Dext.Web,    // Web features, BasicAuth, Swagger
  OrderAPI.Entities,
  OrderAPI.Database,
  OrderAPI.Services;

type
  TStartup = class(TInterfacedObject, IStartup)
  public
    // IStartup Implementation - Instance Methods
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
    
    // Helper for Seeding (Static)
    class procedure SeedDatabase(const App: IWebApplication);
  private
    procedure ConfigureDatabase(Options: TDbContextOptions);
  end;

implementation

{ TStartup }

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  // Database Context
  Services.AddDbContext<TOrderDbContext>(ConfigureDatabase);

  // Application Services (Transient)
  Services.AddTransient<ICategoryService, TCategoryService>
          .AddTransient<IProductService, TProductService>
          .AddTransient<ITableService, TTableService>
          .AddTransient<IOrderService, TOrderService>
          .AddTransient<TReportService>; // Class-only service

  // Controllers
  Services.AddControllers;
end;

procedure TStartup.Configure(const App: IWebApplication);
var
  CorsOpts: TCorsOptions;
  SwaggerOpts: TOpenAPIOptions;
begin
  // JSON global settings
  JsonDefaultSettings(JsonSettings.Default.CamelCase.CaseInsensitive);

  // Middleware Pipeline
  CorsOpts := TCorsOptions.Create;
  // Options ownership transferred to Middleware
  CorsOpts.AllowedOrigins := ['*'];
  CorsOpts.AllowedMethods := ['*'];
  CorsOpts.AllowedHeaders := ['*'];
    
  App.Builder.UseCors(CorsOpts);

  App.Builder.UseExceptionHandler;

  // Basic Authentication
  App.Builder.UseBasicAuthentication(
    'Order API',
    function(const Username, Password: string): Boolean
    begin
      Result := (Username = 'admin') and (Password = 'admin');
    end);

  // Map Controllers FIRST so routes are available for Swagger introspection
  App.MapControllers;

  // Swagger Options
  SwaggerOpts := TOpenAPIOptions.Default;
  SwaggerOpts.Title := 'Order API';
  SwaggerOpts.Version := '1.0.0';
  SwaggerOpts.Description := 'API de gerenciamento de pedidos para restaurante';
  SwaggerOpts.SwaggerPath := '/api/swagger';
  SwaggerOpts.SwaggerJsonPath := '/api/swagger.json';

  App.Builder.UseSwagger(SwaggerOpts);
end;

procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  if FileExists('order_api.db') then
    DeleteFile('order_api.db');

  // SQLite com otimizações para concorrência
  Options.UseSQLite('order_api.db');
  
  // WAL mode é crítico para concurrent reads/writes
  Options.Params.AddOrSetValue('JournalMode', 'WAL');
  Options.Params.AddOrSetValue('LockingMode', 'Normal');
  Options.Params.AddOrSetValue('Synchronous', 'Normal');
  
  // Pooling para multi-thread
  Options.WithPooling(True, 20);
end;

class procedure TStartup.SeedDatabase(const App: IWebApplication);
var
  Scope: IServiceScope;
  DbContext: TOrderDbContext;
  Cat: TCategory;
  Prod: TProduct;
  Tbl: TRestaurantTable;
  I: Integer;
  ServiceProvider: IServiceProvider;
begin
  SafeWriteLn('[*] Initializing Database...');
  
  // Create Scope from Provider
  ServiceProvider := App.Services.BuildServiceProvider;
  
  if ServiceProvider = nil then
  begin
    SafeWriteLn('[ERROR] ServiceProvider could not be built.');
    Exit;
  end;

  Scope := ServiceProvider.CreateScope;
  DbContext := Scope.ServiceProvider.GetService(
    TServiceType.FromClass(TOrderDbContext)) as TOrderDbContext;

  if DbContext <> nil then
  begin
    // Force mapping initialization
    DbContext.Entities<TCategory>;
    DbContext.Entities<TProduct>;
    DbContext.Entities<TRestaurantTable>;
    DbContext.Entities<TOrder>;
    DbContext.Entities<TOrderItem>;

    DbContext.EnsureCreated; 
    SafeWriteLn('[OK] Database tables created/verified');

    // Check if seeded
    if DbContext.Entities<TCategory>.ToList.Count > 0 then
    begin
      SafeWriteLn('[INFO] Database already seeded');
      Exit;
    end;

    SafeWriteLn('[*] Seeding database...');

    // Categorias
    Cat := TCategory.Create;
    Cat.Name := 'Bebidas';
    Cat.Description := 'Bebidas alcoólicas e não alcoólicas';
    Cat.Active := True;
    DbContext.Entities<TCategory>.Add(Cat);

    Cat := TCategory.Create;
    Cat.Name := 'Entradas';
    Cat.Description := 'Porções e petiscos';
    Cat.Active := True;
    DbContext.Entities<TCategory>.Add(Cat);

    Cat := TCategory.Create;
    Cat.Name := 'Pratos Principais';
    Cat.Description := 'Refeições completas';
    Cat.Active := True;
    DbContext.Entities<TCategory>.Add(Cat);

    Cat := TCategory.Create;
    Cat.Name := 'Sobremesas';
    Cat.Description := 'Doces e sobremesas';
    Cat.Active := True;
    DbContext.Entities<TCategory>.Add(Cat);

    DbContext.SaveChanges;

    // Produtos
    Prod := TProduct.Create;
    Prod.Name := 'Cerveja Artesanal IPA';
    Prod.Description := 'Cerveja IPA 500ml';
    Prod.Price := 18.90;
    Prod.CategoryId := 1;
    Prod.Available := True;
    DbContext.Entities<TProduct>.Add(Prod);

    Prod := TProduct.Create;
    Prod.Name := 'Caipirinha de Limão';
    Prod.Description := 'Caipirinha tradicional';
    Prod.Price := 22.00;
    Prod.CategoryId := 1;
    Prod.Available := True;
    DbContext.Entities<TProduct>.Add(Prod);

    Prod := TProduct.Create;
    Prod.Name := 'Porção de Batata Frita';
    Prod.Description := 'Batata frita crocante 400g';
    Prod.Price := 32.00;
    Prod.CategoryId := 2;
    Prod.Available := True;
    DbContext.Entities<TProduct>.Add(Prod);

    Prod := TProduct.Create;
    Prod.Name := 'Picanha na Chapa';
    Prod.Description := 'Picanha com arroz, feijão e farofa';
    Prod.Price := 78.00;
    Prod.CategoryId := 3;
    Prod.Available := True;
    DbContext.Entities<TProduct>.Add(Prod);

    Prod := TProduct.Create;
    Prod.Name := 'Petit Gateau';
    Prod.Description := 'Bolo de chocolate com sorvete';
    Prod.Price := 28.00;
    Prod.CategoryId := 4;
    Prod.Available := True;
    DbContext.Entities<TProduct>.Add(Prod);

    DbContext.SaveChanges;

    // Mesas
    for I := 1 to 10 do
    begin
      Tbl := TRestaurantTable.Create;
      Tbl.Number := I;
      Tbl.Seats := 4;
      Tbl.Status := TTableStatus.tsAvailable;
      if I <= 3 then
        Tbl.Location := 'Área Externa'
      else if I <= 7 then
        Tbl.Location := 'Salão Principal'
      else
        Tbl.Location := 'Mezanino';
      DbContext.Entities<TRestaurantTable>.Add(Tbl);
    end;

    DbContext.SaveChanges;
    SafeWriteLn('[OK] Database seeded with sample data');
  end
  else
    SafeWriteLn('[WARN] Could not get DbContext for seeding');
end;

end.
