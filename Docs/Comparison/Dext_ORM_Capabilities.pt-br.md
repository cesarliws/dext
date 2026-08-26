# Dext ORM — Referência Completa de Recursos

> **O Dext é projetado com a visão de "Inspiração, Não Limitação".**
> Embora o Entity Framework Core sirva como uma brilhante referência arquitetônica para persistência corporativa moderna, o Dext não é uma mera porta de entrada rígida ou clonagem simplista. Ele adapta padrões comprovados de alto desempenho do .NET, Java/Spring Boot, Go e Flutter/Dart, combinando-os com inovações nativas exclusivas projetadas especificamente para o compilador Delphi e os legados visuais VCL/FMX RAD.
> 
> *Última Atualização: Maio de 2026*

---

## Visão Geral
 
| Métrica | Valor |
|:---|:---|
| **Bancos de Dados Suportados** | 7 nativamente (PostgreSQL, SQL Server, MySQL, SQLite, Oracle, Firebird, InterBase) construídos sobre a **camada de drivers FireDAC Phys** — facilmente expansível para todos os motores de banco de dados suportados pelo FireDAC (DB2, MongoDB, Teradata, etc.). |
| **Arquitetura ORM** | DbContext / Unit of Work / Rastreamento de Mudanças (Change Tracking) / Identity Map |
| **Linguagem de Consulta** | DSL ergonômica e fortemente tipada via AST `Prop<T>` |
| **Recursos Exclusivos** | Database as API, EntityDataSet & Active Architecture, AST de Smart Properties, Consultas em Colunas JSON, Servidor MCP nativo |
| **Testes** | Matriz de CI com 5 bancos de dados (PostgreSQL, SQL Server, MySQL, SQLite, Firebird — cobrindo estruturalmente também o InterBase) |
| **Evidência em Produção** | AWS/Azure — ~800.000 requisições/dia em sistemas de gestão fiscal |

---

## 1. Arquitetura Central

### DbContext — Unit of Work

O Dext ORM segue o mesmo padrão Unit of Work + Repository que o Entity Framework Core.

**EF Core:**
```csharp
public class AppDbContext : DbContext
{
    public DbSet<Product> Products { get; set; }
    public DbSet<Order> Orders { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder options)
        => options.UseNpgsql(connectionString);
}

using var db = new AppDbContext();
db.Products.Add(new Product { Name = "Widget", Price = 9.99m });
await db.SaveChangesAsync();
```

**Dext (Sintaxe atual com getters manuais):**
```pascal
type
  TAppDbContext = class(TDbContext)
  private
    function GetProducts: IDbSet<TProduct>;
    function GetOrders: IDbSet<TOrder>;
  public
    property Products: IDbSet<TProduct> read GetProducts;
    property Orders: IDbSet<TOrder> read GetOrders;
  end;

function TAppDbContext.GetProducts: IDbSet<TProduct>;
begin
  Result := Entity<TProduct>; // Herdado da classe base TDbContext
end;

function TAppDbContext.GetOrders: IDbSet<TOrder>;
begin
  Result := Entity<TOrder>;
end;

var Db := TAppDbContext.Create(
  DbOptions.UsePostgreSQL(ConnectionString)
);
Db.Products.Add(TProduct.Create('Widget', 9.99));
Db.SaveChanges;
```

> [!NOTE]
> **Evolução do Roadmap ([S30](../../DextRepository/Docs/Specs/S30-DbContext-AutoHydration.md))**: No próximo lançamento de estabilidade da Wave 3, o Dext introduzirá a **Hidratação Automática de DbContext** para eliminar até mesmo esses getters de linha única. As propriedades serão mapeadas diretamente para campos privados (por exemplo, `property Products: IDbSet<TProduct> read FProducts;`), e o framework injetará automaticamente os repositórios correspondentes durante a inicialização do contexto usando o cache de RTTI otimizado.

Ambos seguem o mesmo padrão. A superfície de API é intencionalmente próxima.

---

## 2. Rastreamento de Mudanças (Change Tracking)

O Change Tracking do Dext usa o mesmo modelo de 4 estados do EF Core:

| Estado | Descrição |
|:---|:---|
| `Added` | A entidade foi adicionada via `Add()`, mas ainda não foi salva |
| `Modified` | A entidade rastreada teve suas propriedades alteradas |
| `Deleted` | A entidade foi marcada para exclusão via `Remove()` |
| `Unchanged` | A entidade foi carregada do banco de dados e nenhuma alteração foi detectada |

**Identity Map**: Assim como o EF Core, o Dext mantém um mapa em memória garantindo que duas consultas para a mesma Chave Primária (PK) retornem a mesma instância de objeto — evitando escritas fantasmas e estados inconsistentes.

---

## 3. Motor de Consulta — Fortemente Tipado, Sem Strings Mágicas

### Abordagem do EF Core (LINQ Fortemente Tipado):

```csharp
// Totalmente type-safe em tempo de compilação via C# Native LINQ
var products = await db.Products
    .Where(p => p.Price > 100 && p.Name.Contains("Widget"))
    .OrderByDescending(p => p.Price)
    .Skip(20)
    .Take(10)
    .ToListAsync();
```

### Abordagem do Dext (AST Fortemente Tipada via Smart Properties ou metadados TEntityType<T>):

```pascal
// Atinge exatamente o mesmo nível de type safety em tempo de compilação no Delphi.
// Operadores sobrecarregados geram uma AST segura sem as strings mágicas do antigo "FieldByName".
var P := Prototype.Entity<TProduct>;
var Products := Db.Products
  .Where((P.Price > 100) and P.Name.Contains('Widget'))
  .OrderBy(P.Price.Desc)
  .Skip(20)
  .Take(10)
  .ToList;
```

#### Arquitetura Dual-Mode & Cache de Metadados

O record `Prop<T>` é uma obra de engenharia projetada para funcionar perfeitamente em **modo dual**:
- **Modo de Execução (Runtime Mode)**: Opera como um valor de campo padrão, armazenando o valor do tipo `T` em memória.
- **Modo de Consulta/DSL (Query/DSL Mode)**: Operadores sobrecarregados (`>`, `<`, `=`, `and`, `or`, `Contains`, `Like`, `In`, `IsNull`...) geram automaticamente nós de AST do tipo `IExpression`. 

O Dext oferece ao desenvolvedor dois padrões elegantes para resolver os metadados complementares das entidades:
1. **Smart Properties (Entidade de Domínio Unificada)**: Ao incorporar `Prop<T>` (ou apelidos embutidos como IntType, StringType, BooleanType, etc.) diretamente dentro da entidade (ex.: `TProduct`), a classe torna-se a fonte única de verdade tanto para dados quanto para metadados, mantendo o domínio altamente coeso.
2. **Tipo Complementar Separado (`TEntityType<T>`)**: Se o desenvolvedor preferir trabalhar com tipos Pascal primitivos e puros (ex.: `Integer`, `String`, `Boolean` padrão), o Dext permite criar uma classe complementar (ex.: `TProductType`) carregando a AST.

Para tornar o uso elegante, os desenvolvedores podem definir uma função de classe simples na entidade que retorna os metadados:
```pascal
// Opção A: Smart Properties (Domínio Coeso)
class function TProduct.Prototype: TProduct;
begin
  Result := Prototype.Entity<TProduct>;
end;

// Opção B: Domínio Primitivo Puro + Classe Complementar
class function TProduct.Prototype: TEntityType<TProduct>;
begin
  Result := TProductType;
end;
```

**Por baixo dos panos**: O consumo e a performance da extração de metadados são exatamente idênticos. Ambas as abordagens aproveitam o cache de metadados de RTTI do Dext, que é altamente otimizado e thread-safe. A varredura de RTTI é executada apenas uma vez por tipo, populando o cache e resolvendo o mapeamento da AST sem overhead de execução ou de memória em tempo de execução.

**Esta mesma AST é utilizada por:**
1. O Compilador SQL do ORM (gera consultas de banco de dados).
2. O `TExpressionEvaluator` em memória (filtra coleções `TList<T>` padrão localmente).
3. O motor de `Database as API` (traduz filtros de URL como `?price_gt=100` em nós de AST automaticamente).

---

## 4. Relacionamentos & Estratégias de Carregamento

### Carregamento Imediato (Eager Loading)

**EF Core:**
```csharp
var orders = await db.Orders
    .Include(o => o.Customer)
    .ThenInclude(c => c.Address)
    .ToListAsync();
```

**Dext:**
```pascal
var Orders := Db.Orders
  .Include(O.Customer)
  .ThenInclude(C.Address)
  .ToList;
```

### Carregamento Preguiçoso (Lazy Loading)

O EF Core realiza o carregamento preguiçoso por meio de proxies virtuais transparentes (exigindo propriedades de navegação virtuais) ou por meio da injeção de `ILazyLoader`. 

O Dext oferece o melhor dos dois mundos. Ele suporta a interceptação transparente por proxy (o mesmo que os proxies virtuais do EF Core) **e** um padrão genérico altamente elegante do tipo **`Lazy<T>` wrapper**. O wrapper `Lazy<T>` mantém as entidades como POCOs 100% puras, sem a necessidade de métodos virtuais ou substituições complexas de classe:

```pascal
type
  [Table('Comments')]
  TComment = class
  private
    FId: Integer;
    FText: string;
    FAuthorId: Integer;
    FAuthor: Lazy<TAuthor>;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Text: string read FText write FText;
    
    [Column('author_id')]
    property AuthorId: Integer read FAuthorId write FAuthorId;
    
    [BelongsTo]
    [ForeignKey('author_id')]
    property Author: Lazy<TAuthor> read FAuthor write FAuthor;
  end;
```

Quando você acessa `Comment.Author.Value`, o framework Dext resolve e executa dinamicamente a consulta no banco de dados sob demanda, usando o travamento por verificação dupla (double-checked locking) thread-safe. Isso oferece um contrato arquitetônico altamente estruturado e auto-documentado diretamente na definição da entidade.

### Multi-Mapeamento (Estilo Dapper) & Hidratação Recursiva

Enquanto ORMs básicos sofrem com resultados de consultas planos que representam tabelas unidas (joins), o Dext apresenta um **hidratador recursivo de alto desempenho e zero boilerplate**, semelhante ao multi-mapping do Dapper (`splitOn`), mas com significativamente mais automação.

Ao declarar um campo de relacionamento com o atributo `[Nested]` (ou mapeá-lo fluentemente), você altera o **mapeador de caminho recursivo** do Dext.

```pascal
type
  TOrderLine = class
  private
    FProductId: Integer;
    FQuantity: Integer;
    FProduct: TProduct;
  public
    property ProductId: Integer read FProductId write FProductId;
    property Quantity: Integer read FQuantity write FQuantity;

    [Nested]
    property Product: TProduct read FProduct write FProduct;
  end;
```

#### Como Funciona por Baixo dos Panos (Sem Necessidade de `splitOn` Manual)

No Dapper (.NET), mapear uma linha resultante de um join exige a especificação de uma string de divisão manual `splitOn` (por exemplo, `'Id'`) para que o framework saiba onde segmentar a lista de colunas planas. 

O Dext elimina essa etapa de configuração ao utilizar **roteamento de caminho baseado em convenção** no nível do compilador/RTTI:

1. **Reconhecimento de Caminho por Nome**: O hidratador varre a lista de colunas retornada pelo banco de dados. Se encontrar uma coluna com um separador como `_` ou `.` (ex.: `Product_Id`, `Product_Name`, `Product_Price` ou `Product.Name`), ele extrai o prefixo (`Product`).
2. **Auto-Instanciação (Alocação Preguiçosa)**: Se a propriedade de destino (`Product`) for do tipo classe e estiver atualmente como `nil`, o hidratador **automaticamente a instancia** em tempo de execução usando o cache de metadados otimizado `TActivator`.
3. **Vinculação de Valor Recursiva**: Ele então roteia os segmentos de caminho restantes recursivamente (ex.: vinculando `Name` e `Price` diretamente a `FProduct.FName` e `FProduct.FPrice`).
4. **Mapeamento de Profundidade Infinita**: Como o `TReflection.SetValueByPath` do Dext é recursivo, ele pode mapear automaticamente hierarquias de múltiplos níveis (ex.: `Order_Customer_Address_City`) a qualquer profundidade com zero configuração manual.

#### Desempenho & Segurança
* **Zero Pressão sobre o Garbage Collector (GC)**: O parsing de caminho usa buffers leves alocados na stack e indexação de string in-place.
* **Interceptação de Propriedades**: Ignora setters de propriedades lentos escrevendo diretamente nos campos de suporte (resolvidos via cache de RTTI) durante a hidratação, evitando efeitos colaterais ou overhead de rastreamento de sujeira (dirty-tracking).

---

## 5. Sistema de Migrações

O Dext usa migrações code-first com snapshots cronológicos — o mesmo modelo conceitual do EF Core:

```
dotnet ef migrations add InitialCreate    →  dext migrations add InitialCreate
dotnet ef database update                 →  dext database update
```

**Capacidade Adicional**: O Dext detecta renomeações de tabelas e colunas via atributos, gerando SQL do tipo `RENAME TABLE` / `RENAME COLUMN` em vez de `DROP + CREATE`.

---

## 6. Exclusão Lógica — Atributo `[SoftDelete]`

O EF Core exige a configuração manual de Filtro Global de Consulta (Global Query Filter) para a exclusão lógica (soft delete). O Dext torna isso declarativo:

**EF Core (configuração manual):**
```csharp
// Configuração do modelo
modelBuilder.Entity<Task>().HasQueryFilter(t => !t.IsDeleted);

// Sobrescrever SaveChanges
public override Task<int> SaveChangesAsync(...)
{
    foreach (var entry in ChangeTracker.Entries<Task>())
        if (entry.State == EntityState.Deleted)
        {
            entry.State = EntityState.Modified;
            entry.Entity.IsDeleted = true;
        }
    return base.SaveChangesAsync(...);
}
```

**Dext (totalmente declarativo com rastreamento opcional de data/hora):**
```pascal
type
  [SoftDelete('IsDeleted')]
  TTask = class
  private
    FName: StringType;
    FIsDeleted: BoolType;
    FDeletedAt: DateTimeType;
  public
    property Name: StringType read FName write FName;
    property IsDeleted: BoolType read FIsDeleted write FIsDeleted;

    [DeletedAt]
    property DeletedAt: DateTimeType read FDeletedAt write FDeletedAt;
  end;
```

E pronto. O Dext faz isso automaticamente:
- Transforma `Remove()` em `UPDATE SET IsDeleted = TRUE` (e marca automaticamente a data/hora atual na propriedade `DeletedAt` se decorada com o atributo `[DeletedAt]`).
- Filtra registros excluídos de todas as consultas por padrão.
- Expõe métodos como `IgnoreQueryFilters`, `OnlyDeleted`, `HardDelete` e `Restore`.
- Limpa o Identity Map após a exclusão lógica.

Suporta valores customizados: `[SoftDelete('Status', 99, 0)]` — usa códigos de status inteiros/enums.

---

## 7. Consultas em Colunas JSON — `[JsonColumn]`

**EF Core (PostgreSQL):**
```csharp
// EF Core 7+ com suporte a JSON do PostgreSQL
var admins = db.Users
    .Where(u => EF.Functions.JsonExists(u.Settings, "role"))
    .ToList();
```

**Dext (multi-banco de dados):**
```pascal
var U: TUserType;
var Admins := Db.Users
  .Where(U.Settings.Json('role') = 'admin')
  .ToList;
```

Implementação compatível com diversos bancos:
- **PostgreSQL**: `settings #>> '{role}'` (JSONB indexado)
- **MySQL**: `JSON_UNQUOTE(JSON_EXTRACT(settings, '$.role'))`
- **SQLite**: `json_extract(settings, '$.role')`
- **SQL Server**: `JSON_VALUE(settings, '$.role')`

Caminhos aninhados também funcionam: `U.Settings.Json('profile.details.level') = 5`

---

## 8. Multi-Tenancy — Integrado

O Dext possui um módulo dedicado `Dext.MultiTenancy` com **três estratégias de isolamento**:

| Estratégia | Como Funciona | Recomendado Para |
|:---|:---|:---|
| **Shared Database (Banco Compartilhado)** | Coluna discriminadora `TenantId` — filtro automático | Tenants pequenos, eficiência de custo |
| **Schema Isolation (Esquema Isolado)** | Alternância do `search_path` no PostgreSQL por requisição | Tenants médios, isolamento lógico |
| **Database per Tenant (Banco por Tenant)** | String de conexão dinâmica por tenant | Clientes corporativos, isolamento estrito de dados |

```pascal
Services.AddMultiTenancy
  .UseSharedDatabase  // ou .UseSchemaIsolation ou .UseDatabasePerTenant
  .WithTenantFromHeader('X-Tenant-Id');
```

---

## 9. Mapeamento de Herança

**Tabela por Hierarquia (TPH — Table-Per-Hierarchy)** — suporte completo com hidratação polimórfica:

```pascal
type
  [Discriminator('Type')]
  TVehicle = class
    Name: StringType;
    [DiscriminatorValue('car')]
    // ...
  end;

  TCar = class(TVehicle)
    Doors: IntType;
  end;

  TTruck = class(TVehicle)
    Payload: FloatType;
  end;
```

---

## 10. Stored Procedures — Padrão de Comando Declarativo

A execução de Stored Procedures em sistemas corporativos modernos é um caminho crítico e comum, mas é notoriamente dolorosa em ORMs tradicionais.

### O Contraste

#### EF Core (Vinculação Manual de Parâmetros & Mapeamento Rígido)
O C# não oferece suporte nativo à inferência dinâmica de objetos ou mapeamento dinâmico de resultados de consultas nativamente no EF Core.
* Se a procedure retorna agregados customizados, você **deve declarar um DTO** e registrá-lo explicitamente como uma entidade sem chave no `DbContext` (`modelBuilder.Entity<T>().HasNoKey()`).
* Se a procedure possui parâmetros `OUT` ou `INOUT`, ou retorna múltiplos conjuntos de resultados, o EF Core **obriga você a recorrer ao boilerplate tradicional do ADO.NET** (`DbCommand`, `DbDataReader`), instanciando objetos manuais de `SqlParameter` e lendo os dados linha por linha.

```csharp
// EF Core: Propenso a erros de strings mágicas e exige configuração manual de parâmetros
var minPriceParam = new SqlParameter("@MinPrice", 100);
var result = await db.Database.ExecuteSqlRawAsync(
    "EXEC GetTopProducts @MinPrice", minPriceParam);
```

#### Dext (Padrão de Comando Declarativo)
O Dext encapsula Stored Procedures usando um **Padrão de Comando/CQRS** coeso. Embora exija a definição de uma classe, essa classe atua como um **contrato arquitetônico verificado em tempo de compilação** que encapsula todas as entradas, saídas e projeções.

```pascal
type
  [StoredProcedure('GetTopProducts')]
  TGetTopProducts = class
  private
    FMinPrice: Currency;
    FResults: IList<TProduct>;
  public
    [DbParam('MinPrice')]
    property MinPrice: Currency read FMinPrice write FMinPrice;

    // A projeção da consulta é auto-hidratada a partir do conjunto de resultados da procedure
    property Results: IList<TProduct> read FResults write FResults;
  end;

// Execução: Zero boilerplate de banco de dados, zero arrays de parâmetros soltos
var Command := TGetTopProducts.Create;
Command.MinPrice := 100;
Db.Execute(Command); 
```

### Principais Vantagens Arquitetônicas da Abordagem do Dext

1. **Zero Vazamentos de ADO.NET/FireDAC**: Você nunca escreve código de baixo nível para vincular parâmetros, definir tipos de dados ou abrir/fechar streams de conexão. O Dext gerencia o ciclo de vida da conexão, direção dos parâmetros e desalocação de memória automaticamente.
2. **Contrato Coeso e Fortemente Tipado**: Entradas (`[DbParam]`), saídas (parâmetros `out`) e datasets de retorno são estruturalmente vinculados ao objeto de comando. Isso elimina arrays de tempo de execução inseguros e castings manuais de tipo.
3. **Pronto para CQRS**: Alinha-se perfeitamente com padrões de *Segregação de Responsabilidade de Comando e Consulta* (CQRS). Cada operação complexa de banco de dados é tratada como uma unidade de comando isolada, testável e auto-documentada.
4. **Hidratação Rica de Projeções**: As linhas retornadas são automaticamente convertidas e mapeadas para ricos grafos de entidades ou listas leves de DTOs usando o hidratador otimizado com cache de RTTI.

---

## 11. Recursos Exclusivos (Não Disponíveis no EF Core)

### 11.1 Database as API

**O recurso mais poderoso do Dext ORM.** Gere uma API REST CRUD completa a partir de um único atributo — sem controllers, sem services, sem repositories:

```pascal
type
  [Table, DataApi('/api/products')]
  TProduct = class
    Id: IntType;
    Name: StringType;
    Price: CurrencyType;
  end;

// Na inicialização (startup):
App.MapDataApis; // Pronto.
```

Isso gera **5 endpoints automaticamente**:

| Método | Rota | Descrição |
|:---|:---|:---|
| `GET` | `/api/products` | Lista com paginação, ordenação e 11 operadores de filtragem |
| `GET` | `/api/products/{id}` | Busca por Chave Primária (simples ou composta) |
| `POST` | `/api/products` | Criação — retorna status 201 |
| `PUT` | `/api/products/{id}` | Atualização completa |
| `DELETE` | `/api/products/{id}` | Exclusão |

**Sistema de Filtros via URL (11 operadores):**
```
GET /api/products?price_gt=100&name_cont=widget&_orderby=price+desc&_limit=20&_offset=0
```

Operadores suportados: `_eq`, `_neq`, `_gt`, `_gte`, `_lt`, `_lte`, `_cont` (LIKE %x%), `_sw`, `_ew`, `_in`, `_null`

**Segurança Granular:**
```pascal
App.MapDataApis.Configure<TProduct>(
  DataApiOptions
    .RequireAuth
    .RequireWriteRole(['admin'])
    .Allow([amGet, amGetList]) // Somente leitura para não-admins
    .UseSnakeCase
    .UseSwagger
);
```

---

### 11.2 EntityDataSet — A Ponte ORM ↔ VCL/FMX

Conecte componentes legados do Delphi (DBGrid, FastReport, TDBEdit) a domínios ricos de Smart Properties ou coleções padrão de entidades POCO — com zero comprometimento da arquitetura:

```pascal
EntityDataSet1.Collection := Db.Products.ToList; // Lista direta (suporta tanto POCO quanto Smart Properties)
```

**Visualização em Tempo de Design (Live IDE Preview)**: Em tempo de design, forneça uma `TFDConnection` e um `DataProvider`, e o Dext gerará SQL dinâmico exibindo dados reais no DBGrid *sem a necessidade de compilar o projeto*.

Isso não possui **equivalente no ecossistema .NET** — o DataAdapter do Windows Forms exige mapeamento manual, e não há designer do Visual Studio que visualize dados do ORM em tempo real diretamente na IDE.

---

### 11.3 Avaliador de Expressões em Memória

A mesma AST gerada por `Prop<T>` pode ser avaliada contra coleções em memória — sem interagir com o banco de dados:

```pascal
var Filter := TExpressionEvaluator.Create;

// A mesma expressão usada para a consulta SQL...
var SqlResult := Db.Products.Where(P.Price > 100).ToList;

// ...também filtra uma lista local em memória:
var InMemoryResult := Filter.Evaluate(LocalCache, P.Price > 100);
```

O EF Core não expõe um avaliador em memória para a mesma árvore de expressão utilizada na geração de consultas SQL.

---

## 12. Características de Desempenho

| Benchmark | Dext | Notas |
|:---|:---|:---|
| **Roteamento de rotas** | 10.000 rotas em 47ms, zero alocações de heap | Roteamento baseado em `Span<T>` |
| **Busca em Dicionários** | 6.6x mais rápida que a RTL | AVX2/SSE2 SIMD + Open Addressing |
| **Tempo de compilação** | Redução de 60% vs genéricos padrão | Binary Code Folding |
| **Memória SSR** | O(1) para qualquer quantidade de registros | Iterador de streaming Flyweight |
| **Parsing de JSON** | UTF-8 com zero alocação via `TByteSpan` | Injeção direta por offset de campo |

---

## 13. Matriz de Testes Multi-Banco de Dados

O mecanismo de persistência do Dext ORM é validado contra uma **matriz de testes de CI com 5 bancos de dados reais** a cada release:

| Banco de Dados | Versão Testada | Notas |
|:---|:---|:---|
| **PostgreSQL** | 14, 15, 16 | JSONB, UUID, `search_path` para esquemas |
| **SQL Server** | 2019, 2022 | Funções de janela, TRY_CAST |
| **MySQL** | 8.0 | JSON_EXTRACT, LIMIT/OFFSET |
| **SQLite** | 3.x | In-process; json_extract |
| **Firebird** | 3.0, 4.0 | Paginação legada (ROWS/TO), SEQUENCE |

O banco Oracle é suportado em produção, mas não está incluído na matriz de testes automatizados do CI.

## 14. Engenharia de Alto Desempenho & Mergulho Arquitetônico

Embora as capacidades funcionais sejam cruciais, o grande diferencial do Dext é **como esses recursos são implementados** para alcançar eficiência de nível industrial:
* **Binary Code Folding**: Evita a "explosão de genéricos" no Delphi, reduzindo o tempo de compilação em até 60% e encolhendo o tamanho dos binários.
* **Coleções Aceleradas por SIMD**: Buscas vetorizadas via AVX2/SSE2 que tornam o `TRawDictionary` até 6.6x mais rápido que os dicionários padrão da RTL.
* **Avaliador de Expressões em Memória**: Reutilização direta da AST `Prop<T>` do ORM para avaliar consultas complexas contra listas padrão em memória com zero chamadas ao banco de dados.

Para um mergulho técnico completo no design de alocação zero do Dext, otimizações de compilador e benchmarks detalhados de baixo nível, consulte o [Visão Geral do Ecossistema Dext Framework](https://github.com/dotpas/dext/blob/main/Docs/Dext_Ecosystem_Overview.md).

---

## 15. Tabela de Referência Rápida do ORM

A tabela abaixo resume os principais recursos do ORM. Para a comparação completa do framework, incluindo web, DI, testes e recursos exclusivos, consulte a **[Comparação de Recursos →](./Feature_Comparison_Dext_vs_DotNet.pt-br.md)**.

| Recurso do ORM | EF Core | Dext ORM | Destaque do Dext |
|:---|:---:|:---:|:---|
| **DbContext / Unit of Work** | Sim | Sim | `TDbContext` - mesmo padrão de UoW + Identity Map |
| **Change Tracking (4 estados)** | Sim | Sim | `Added / Modified / Deleted / Unchanged` |
| **Migrações Code-First** | Sim | Sim | Baseadas em snapshots cronológicos, com detecção de renomeação |
| **Lazy / Eager Loading** | Sim | Sim | Mesma API com `Include()` / `ThenInclude()` |
| **Soft Delete (Exclusão Lógica)** | Parcial (filtro manual) | Sim | Suporte integrado via `[SoftDelete]` + `[DeletedAt]` |
| **Multi-Tenancy** | Parcial (filtro de consulta) | Sim | 3 estratégias: Banco Compartilhado, Esquema ou Banco por Tenant |
| **Bloqueio Pessimista** | Não (apenas SQL puro) | Sim | `FOR UPDATE` integrado diretamente no motor de consulta |
| **Consultas em Colunas JSON** | Sim | Sim | Mapeamento multi-banco via `[JsonColumn]` + `.Json('caminho')` |
| **Herança TPH** | Sim | Sim | Hidratação polimórfica via discriminador |
| **Herança TPT / TPC** | Sim | Parcial | Mapeado no roadmap |
| **Conversores de Valor** | Sim | Sim | `TValueConverterRegistry` - mais de 20 conversores embutidos |
| **Stored Procedures** | Sim | Sim | Totalmente declarativas via `[StoredProcedure]` + `[DbParam]` |
| **Multi-Mapeamento (estilo Dapper)** | Não | Sim | Atributo `[Nested]` - hidratação recursiva via separadores `_` ou `.` |
| **Suporte Multi-Banco** | Sim (NuGet) | Sim (7 nativos) | PostgreSQL, SQL Server, MySQL, SQLite, Oracle, Firebird, InterBase |
| **DSL de Consulta Type-Safe** | Sim (LINQ) | Sim (AST `Prop<T>`) | Mesma AST reutilizada para SQL, filtros locais e rotas HTTP |
| **Database as API** | Não | Sim | `[DataApi]` - API REST CRUD completa com apenas 1 atributo |
| **EntityDataSet (VCL/FMX)** | Não | Sim | Ponte entre POCO e DBGrid/FastReport com pré-visualização na IDE |
| **Avaliador de Expressão em Memória** | Não | Sim | A mesma AST de `Prop<T>` filtra listas `TList<T>` locais |
| **Parser de URL para Expressão** | Não | Sim | Converte automaticamente `?price_gt=100` in nó de AST |

---

## 16. Inspiração Global, Evolução Guiada pela Comunidade: Indo Além dos Paradigmas Padrão

Um princípio central do design do Dext é **"Inspirado no melhor, otimizado para o Delphi, impulsionado pela comunidade."** Nós não enxergamos o .NET ou o EF Core como modelos rígidos a serem copiados linha a linha, nem limitamos nosso horizonte à mera replicação. Em vez disso, nós os usamos como referências de mercado enquanto integramos os melhores paradigmas de todo o ecossistema global de engenharia de software.

### 1. Recursos Unificados Prontos para Uso (A Vantagem das Soluções Integradas)
Quando desenvolvedores avaliam o .NET, eles geralmente consideram o que está disponível em todo o ecossistema do NuGet, e não apenas na biblioteca padrão BCL (Base Class Library). O Dext adotou uma abordagem proativa ao **implementar de forma nativa os padrões mais populares, consagrados e críticos do C#** diretamente no núcleo do nosso framework. Isso elimina o gerenciamento complexo e dependências de pacotes externos:
* **Mapeamento de Objetos**: Integrado nativamente como `Dext.Mapper` (`TMapper`), inspirado no amplamente utilizado **AutoMapper** do ecossistema .NET.
* **Padrão de Especificação (Specification Pattern)**: Integrado nativamente como `Dext.Specifications`, inspirado no **Ardalis.Specification**.
* **Barramento de Eventos Corporativo & Pipeline Behaviors**: Integrado nativamente como `Dext.Events`, inspirado no padrão de mercado **MediatR**.
* **Testes & Mocks**: Motores de asserção integrados nativamente, combinações de casos de teste (`TestCase`) e `TAutoMocker`, inspirados em frameworks como **FluentAssertions**, **NUnit** e **Moq**.

### 2. Uma Arquitetura Poliglota: Adotando as Melhores Ideias
O Dext incorpora ativamente avanços arquitetônicos e padrões de alta produtividade de múltiplos ecossistemas consolidados:
* **Go (Golang)**: Adaptamos o padrão ultra-leve e de alta vazão de **Channels** (`TChannel<T>`) e o padrão determinístico **Defer** (`IDeferred`/`TDeferredAction`) para trazer gerenciamento de recursos limpo, livre de vazamentos e concorrência robusta ciente de contrapressão (backpressure) para o Delphi.
* **Flutter & Dart**: Buscamos inspiração nos paradigmas de segurança em tempo de compilação do Dart, ergonomia assíncrona e bindings reativos de UI para otimizar como nosso visual VCL/FMX `TEntityDataSet` se comporta sob alterações ativas em tempo de design.
* **Java & Spring Boot**: Estudamos a ergonomia do container de IoC/DI do Spring Boot e os mapeamentos declarativos por anotações para construir os mecanismos de injeção de dependência altamente intuitivos e rotas baseadas em atributos do Dext.
* **Python & JavaScript/TypeScript**: Analisamos a extrema facilidade de configuração e a ergonomia de frameworks web ágeis como FastAPI e Hono para implementar nossa detecção automática de **HTMX** e configurações do tipo **Database as API** (`[DataApi]`) com zero boilerplate.

### 3. Aberto à Evolução Contínua Conduzida pela Comunidade
Frameworks de software são sistemas vivos. Se um desenvolvedor perceber que um recurso altamente especializado "N" está ausente no ecossistema atual do Dext, não enxergamos isso como uma limitação permanente:
* **Roadmap de Evolução Adaptável**: Nossa arquitetura é intencionalmente modular e desacoplada. Adicionar novos recursos, dialetos de banco de dados, conversores personalizados ou middlewares de tratamento é um processo simples e limpo.
* **Aberto a Contribuições**: Estamos comprometidos em evoluir o Dext em estreita colaboração com a comunidade Delphi corporativa. Se o seu ambiente de produção exigir um padrão arquitetônico especializado ou um driver de acesso a dados específico, a equipe do Dext e a comunidade estão totalmente preparadas para construir, revisar e integrar essa solução.
* **Modernizando o Delphi Juntos**: O Dext é projetado para provar que os desenvolvedores Delphi não precisam fazer concessões dolorosas. Você pode ter binários nativos de compilação rápida, sem dependências externas e ultra-rápidos, enquanto desfruta dos padrões de arquitetura de software mais modernos, elegantes e poderosos do planeta.

---

*Dext Framework — Referência de Recursos do ORM | Maio de 2026*
