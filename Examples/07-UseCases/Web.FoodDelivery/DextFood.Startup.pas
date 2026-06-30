unit DextFood.Startup;

interface

uses
  System.TypInfo,
  System.Rtti,
  System.SysUtils,
  Dext, Dext.DI.Interfaces,
  Dext.Collections,
  Dext.Entity,           // Facade para ORM (TDbContext, TSnakeCaseNamingStrategy)
  Dext.Entity.Core,      // Explicitly needed for IDbSet<T>
  Dext.RateLimiting,
  Dext.RateLimiting.Policy,
  Dext.Caching,
  Dext.Web.DataApi,
  Dext.Web,
  DextFood.Domain;

type
  /// <summary>
  /// Contexto de banco de dados específico para o DextFood.
  /// </summary>
  TAppDbContext = class(TDbContext)
  private
    function GetOrders: IDbSet<TOrder>;
  public
    property Orders: IDbSet<TOrder> read GetOrders;
  end;

  /// <summary>
  /// Classe de inicialização (Bootstrap) do backend DextFood.
  /// </summary>
  TStartup = class(TInterfacedObject, IStartup)
  public
    procedure ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
    procedure Configure(const App: IWebApplication);
  private
    procedure ConfigureDatabase(Options: TDbContextOptions);
  end;

implementation

uses
  Dext.Json,
  DextFood.Services,
  DextFood.DbSeeder;

{ TAppDbContext }

function TAppDbContext.GetOrders: IDbSet<TOrder>;
begin
  Result := Entities<TOrder>;
end;

{ TStartup }

procedure TStartup.ConfigureServices(const Services: TDextServices; const Configuration: IConfiguration);
begin
  // 1. Motor de Persistência via Contexto Tipado
  Services.AddDbContext<TAppDbContext>(ConfigureDatabase);
  
  // 2. Registro de Serviços de Negócio
  Services.AddSingleton<IOrderService, TOrderService>;

  // 3. Suporte a Controllers
  Services.AddControllers;
end;

procedure TStartup.Configure(const App: IWebApplication);
begin
  // ✨ Configurações globais de JSON (CamelCase para APIs modernas)
  JsonDefaultSettings(JsonSettings.CamelCase.CaseInsensitive.EnumAsString);

  // Pipeline de middlewares configurado via Facade Dext.Web
  App.Builder
    .UseExceptionHandler
    .UseHttpLogging
    // 🚦 Rate Limiting (100 reqs/min)
    .UseRateLimiting(TRateLimitPolicy.FixedWindow(100, 60))

    // 💾 Response Caching
    .UseResponseCache(ResponseCacheOptions.DefaultDuration(10).VaryByQueryString)
    // 🛡️ Configuração granular de CORS
    .UseCors(CorsOptions.AllowAnyOrigin.AllowAnyMethod.AllowAnyHeader)
    // 🚀 Mapeia todas as rotas (Minimal APIs e Controllers) ANTES do Swagger
    // Health Check
    .MapGet('/health',
      procedure(Ctx: IHttpContext)
      begin
        Ctx.Response.Json('{"status": "healthy"}');
      end)
    // Minimal API Tipada
    .MapPost<IOrderService, IHttpContext, IResult>('/api/orders',
      function(Service: IOrderService; Ctx: IHttpContext): IResult
      var
        TotalStr: string;
        Total: Currency;
      begin
        if Ctx.Request.Query.TryGetValue('total', TotalStr) then
          Total := StrToCurrDef(TotalStr, 0)
        else
          Total := 0;
        Service.CreateOrder(Total);
        Result := Results.Ok('{"message": "Pedido criado"}');
      end)

    // Exemplo de consulta com Smart Properties e Dependency Injection
    .MapGet<TAppDbContext, IResult>('/api/orders/high-value',
      function(Db: TAppDbContext): IResult
      var
        Order: TOrder;
        List: IList<TOrder>;
      begin
        Order := Prototype.Entity<TOrder>;
        List := Db.Orders.Where(Order.Total > 50).ToList;
        Result := Results.Ok(List);
      end);

  // 🚀 Feature: Database as API (CRUD instantâneo para Pedidos)
  TDataApiHandler<TOrder>.Map(App.Builder, '/api/super-orders',
    TDataApiOptions<TOrder>.Create
      .DbContext<TAppDbContext> // Resolve via DI no runtime
      .UseSnakeCase
      .UseSwagger // Aparece no Swagger!
      .Tag('Super Orders'));

  // Controllers
  App.MapControllers;

  // ✨ Swagger UI em /swagger (Inspeção automática de rotas)
  App.Builder.UseSwagger(SwaggerOptions.Title('DextFood API').Version('v1'));
end;

procedure TStartup.ConfigureDatabase(Options: TDbContextOptions);
begin
  Options
    .UseSQLite('DextFood.db')
    .UseNamingStrategy(TSnakeCaseNamingStrategy.Create);
end;

end.

