# Dext Framework vs .NET / EF Core — Matriz de Comparação de Recursos

> **Objetivo**: Este documento fornece uma comparação abrangente e objetiva entre o Dext Framework para Delphi e o ecossistema equivalente de ASP.NET Core + Entity Framework Core para .NET. Destina-se a ajudar os desenvolvedores a entender o que o Dext oferece, onde possui paridade, onde vai além e onde existem diferenças devido ao contexto de cada plataforma.
>
> *Última Atualização: Maio de 2026*

---

## Como Ler Este Documento

Esta comparação está estruturada em quatro blocos lógicos:

| Bloco | Significado |
|---|---|
| **A — Paridade Total** | O Dext implementa o equivalente funcional do recurso em .NET |
| **B — Exclusivo do Dext** | Recursos que o Dext possui e o .NET não possui (ou exige pacotes de terceiros) |
| **C — Parcial / Roadmap** | O .NET possui esse recurso; o Dext o possui parcialmente ou está planejado |
| **D — Diferença de Contexto** | Recursos do .NET que não se aplicam ao Delphi por design |

---

## Bloco A — Paridade Total de Recursos

> [!NOTE]
> Todos os recursos listados aqui estão totalmente implementados no Dext. A convenção de nomenclatura e a interface das APIs foram mantidas intencionalmente próximas às contrapartes do .NET para reduzir a curva de aprendizado de desenvolvedores que estão migrando do ecossistema .NET.

### A.1 ORM / Acesso a Dados

| Recurso | EF Core | Equivalente Dext | Notas |
|:---|:---|:---|:---|
| **DbContext (Unit of Work)** | `DbContext` | `TDbContext` | Padrão Unit of Work (Unidade de Trabalho) completo |
| **Change Tracking** | Automático (Added / Modified / Deleted / Unchanged) | Automático — mesmos 4 estados | Identity Map para unicidade de instância por PK (Chave Primária) |
| **SaveChanges** | `SaveChanges()` / `SaveChangesAsync()` | `SaveChanges()` | Persiste todas as alterações rastreadas dentro de uma transação |
| **Repositório Genérico** | `DbSet<T>` | `DbSet<T>` | Operações: `Add`, `Update`, `Remove`, `Find`, `Where`, `Include`, `ToList` |
| **Code-First Migrations** | `dotnet ef migrations add` | Sistema de Migrações Automatizado | Também via CLI. Snapshots cronológicos com detecção de renomeação de tabelas/colunas. **Expert no IDE com wizard planejado.** |
| **Lazy Loading** | Baseado em Proxies (`UseLazyLoadingProxies`) | Objetos Proxy (interceptação transparente) | Mesma arquitetura técnica |
| **Eager Loading** | `Include()` / `ThenInclude()` | `Include()` / `ThenInclude()` | Mesma interface de API |
| **Soft Delete** | Filtros de Consulta Globais (manual) | Atributos `[SoftDelete]` / `[DeletedAt]` | Totalmente declarativo. Suporta HardDelete, Restore, OnlyDeleted, IgnoreQueryFilters. O `[DeletedAt]` carimba automaticamente a data/hora da exclusão. |
| **Multi-tenancy** | Manual / Filtros de Consulta do EF | `Dext.MultiTenancy` | 3 estratégias: DB Compartilhado (TenantId), Isolamento de Esquema (Schema), DB por Tenant |
| **Bloqueio Pessimista** | Não nativo (apenas via SQL bruto) | `FOR UPDATE` nativo | Integrado diretamente no motor de consulta do ORM |
| **Herança: TPH** | Tabela por Hierarquia (Table-Per-Hierarchy) | TPH com atributos de discriminador | Hidratação polimórfica automática |
| **Herança: TPT** | Tabela por Tipo (Table-Per-Type) | Suporte parcial | Planejado no roadmap |
| **Conversores de Valor** | `HasConversion<T>()` | `TValueConverterRegistry` | Mais de 20 conversores embutidos (Enum, GUID, TUUID, JSONB, TBytes...) |
| **Consultas em Coluna JSON** | `OwnsOne().ToJson()` / `JSON_VALUE` | `[JsonColumn]` + `.Json('path')` | Cross-DB: PostgreSQL JSONB, MySQL JSON_EXTRACT, SQLite json_extract, SQL Server JSON_VALUE |
| **Stored Procedures** | `FromSqlRaw()` / `ExecuteSqlRaw()` | `[StoredProcedure]` + `[DbParam]` | Totalmente declarativo via atributos nas classes |
| **Specification Pattern** | Pacote de terceiros (Ardalis.Specification) | `Dext.Specifications` — **nativo** | Builder fluente com suporte a `Where`, `OrderBy`, `Include`, `Take`, `Skip` |
| **Query Extensions (Estilo LINQ)** | LINQ Nativo | `Dext.Collections.Extensions` | Motor de expressões unificado, records gerenciados e operadores implícitos. Otimizado por cache de RTTI thread-safe. |
| **Suporte Multi-Banco** | Pacotes NuGet separados por provedor | **7 drivers unificados de fábrica** | Construído diretamente sobre a camada de FireDAC Phys Drivers (sem componentes visuais como TQuery). PostgreSQL, SQL Server, MySQL, SQLite, Oracle, Firebird, InterBase. |
| **Multi-Mapping (Estilo Dapper)** | Não nativo | Atributo `[Nested]` | Hidratação recursiva. Suporta mapeamento direto para Views e Stored Procedures, não apenas tabelas. |
| **Pool de Conexões** | Pooling do ADO.NET | Configuração Fluente + Autodetecção de Pooling | Métodos como `UsePostgreSQL`, `UseFirebird`, etc., com pooling automático |
| **Paginação** | `Skip()` / `Take()` | `Skip()` / `Take()` | Mesma API |
| **Agregações** | `Count()`, `Sum()`, `Max()`, `Min()`, `Avg()` | `Count()`, `Sum()`, `Max()`, `Min()`, `Average()` | Mesma API |
| **Cache de SQL** | Consultas compiladas do EF | Cache de reaproveitamento de comandos SQL | Consultas repetidas reutilizam o SQL gerado anteriormente |
| **Operações em Lote (Bulk)** | `ExecuteUpdate()` / `ExecuteDelete()` | `AddRange` / `UpdateRange` / `RemoveRange` | Suporte nativo para inserção, atualização e exclusão em lote de alta performance em uma única chamada física. |
| **Mapeamento de Objetos** | AutoMapper (terceiros) | `TMapper` — **nativo** | `CreateMap<TSource, TDest>`, `ForMember`, `Map<TSource, TDest>`, mapeamento de coleções |

### A.2 Framework Web / Equivalente ao ASP.NET Core

| Recurso | ASP.NET Core | Equivalente Dext | Notas |
|:---|:---|:---|:---|
| **Minimal APIs** | `app.MapGet(...)` / `app.MapPost(...)` | `app.MapGet(...)` / `app.MapPost(...)` | Mesma API fluente de roteamento |
| **APIs Baseadas em Controllers** | `[ApiController]` + `ControllerBase` | `[ApiController]` + roteamento por atributos | Mesmo padrão arquitetônico |
| **Pipeline de Middlewares** | `app.Use(...)` — Chain of Responsibility | `app.Use(...)` — mesma arquitetura | Suporte a middlewares funcionais (delegates) e baseados em classes com injeção de DI |
| **Model Binding** | `[FromBody]`, `[FromQuery]`, `[FromRoute]`, `[FromHeader]`, `[FromServices]` | Mesmos atributos | Alocação zero via `TByteSpan` (desserialização UTF-8 direta da rede) |
| **Versionamento de API** | `Asp.Versioning` (NuGet) | **Nativo** — 4 leitores | `THeaderApiVersionReader`, `TQueryStringApiVersionReader`, `TPathApiVersionReader`, `TCompositeApiVersionReader` |
| **Controle de Vazão (Rate Limiting)** | `Microsoft.AspNetCore.RateLimiting` | **Nativo** — 4 algoritmos | Fixed Window, Sliding Window, Token Bucket, Concurrency Limiter |
| **CORS** | `UseCors()` | Middleware de CORS — embutido | |
| **Cache de Saída** | `IOutputCache` | Em memória (Redis Client planejado) | O cliente nativo Redis do Dext está 80% completo, focando em máxima performance |
| **Health Checks** | `IHealthCheck` | Health Checks — embutido | Implementação básica integrada; integrações com bancos e serviços externos no roadmap |
| **ProblemDetails (RFC 9457)** | Nativo no .NET 8+ | Embutido | O middleware de tratamento de exceções gera respostas compatíveis com a RFC 9457 |
| **OpenAPI / Swagger** | `Microsoft.AspNetCore.OpenApi` | **Nativo** — geração automática | Endpoints registrados aparecem automaticamente no Swagger gerado na inicialização |
| **SSE (Server-Sent Events)** | `IServerSentEvents` | SSE nativo | Suporte para streaming unidirecional de eventos |
| **Equivalente ao SignalR (Hubs)** | SignalR | Mensageria baseada em SSE (SignalR completo planejado) | Atualmente transmissão básica via SSE. Interfaces de Hub bidirecionais prontas; implementação completa pós-motor nativo IOCP/EPOLL. |
| **Serviços em Segundo Plano** | `IHostedService` / `BackgroundService` | `IHostedService` + `TBackgroundService` | Método `Execute(ICancellationToken)` |
| **Ciclo de Vida da Aplicação** | `IHostApplicationLifetime` | `IHostApplicationLifetime` | Eventos `ApplicationStarted`, `ApplicationStopping`, `ApplicationStopped` |
| **Motor de Templates** | Razor | Motor de Templates Dext | Baseado em AST, zero dependências, herança de layouts, macros, filtros |
| **Motor de Templates Alternativo** | Razor Pages | Web Stencils (Delphi 12.2+) | Alternativa nativa do Delphi integrada |
| **Multipart / Upload de Arquivos** | `IFormFile` | `IFormFile` | Mesma abstração de manipulação de stream |
| **Compressão GZip** | `UseResponseCompression` | Middleware embutido | Middleware GZip de alta performance |
| **Developer Exception Page** | `UseDeveloperExceptionPage()` | Middleware `DeveloperExceptionPage` | Detalhes de exceção formatados para o desenvolvedor em ambiente de testes |

### A.3 Recursos Core do Framework

| Recurso | .NET | Equivalente Dext | Notas |
|:---|:---|:---|:---|
| **Injeção de Dependência** | `Microsoft.Extensions.DI` | `TDextServices` | `AddSingleton`, `AddTransient`, `AddScoped`, `AddSingletonFactory` |
| **Ciclos de Vida de DI** | Singleton / Transient / Scoped | Singleton / Transient / Scoped | `CreateScope` para resolução isolada de dependências filhas |
| **Resolução Automática de Coleções** | Injeção de `IEnumerable<T>` | `IList<T>`, `IEnumerable<T>`, `IDictionary<K,V>` | Resolvidos automaticamente pelo contêiner de DI |
| **Atributos de DI** | `[FromServices]` | `[Inject]`, `[ServiceConstructor]` | Injeção por campo, propriedade ou construtor |
| **Sistema de Configuração** | `IConfiguration` / `appsettings.json` | `TDextConfiguration` | Provedores: JSON, YAML, ENV, argumentos CLI, memória — mesmo design extensível |
| **Options Pattern** | `IOptions<T>`, `IOptionsSnapshot<T>`, `IOptionsMonitor<T>` | `IOptions<T>`, `IOptionsSnapshot<T>`, `IOptionsMonitor<T>` | Mesmas interfaces e comportamentos |
| **Hot-Reload de Configuração** | `IChangeToken` | `IChangeToken` + callback `OnReload` | Atualização dinâmica de arquivos de configuração |
| **Logging (Registros)** | `ILogger<T>` / `ILoggerFactory` | `ILoggerFactory` / `ILogger` | Níveis: Trace, Debug, Information, Warning, Error, Critical |
| **Async / Await** | `Task<T>` / `async/await` | `TAsyncTask` + Work-Stealing Scheduler | Concorrência assíncrona robusta em Object Pascal |
| **Cancellation Token** | `CancellationToken` | `ICancellationToken` | Métodos `WaitForCancellation`, `IsCancellationRequested` |
| **Nullable<T>** | `Nullable<T>` / `T?` | `Nullable<T>` | Métodos `HasValue`, `Value`, `GetValueOrDefault` e operadores implícitos |
| **Lazy<T>** | `Lazy<T>` | `Lazy<T>` | Bloqueio duplo thread-safe (double-checked locking); baseado em factory |
| **Span<T> / ReadOnlySpan<T>** | `Span<T>` / `ReadOnlySpan<T>` | `TSpan<T>` / `TReadOnlySpan<T>` | Manipulação rápida de memória com alocação zero e verificação de limites |
| **Mapeamento de Objetos** | AutoMapper (terceiros) | `TMapper` nativo | Integrado ao ecossistema |
| **Serialização JSON** | `System.Text.Json` / Newtonsoft | `TDextJson` + Streaming de baixo nível UTF-8 | Drivers plugáveis. Leitor/gravador binário de alta performance via `TSpan` sem alocações na heap. |
| **Frozen Collections** | `FrozenDictionary<K,V>` (.NET 8+) | `TFrozenDictionary<K,V>` / `TFrozenSet<T>` | Leitura livre de locks (lock-free) e coleções imutáveis após construção |
| **Canais (Channels)** | `System.Threading.Channels` | `TChannel<T>` | Inspirado em Go. Canais Bounded (com backpressure) e Unbounded; ChannelReader/ChannelWriter |
| **Event Bus / MediatR** | MediatR (terceiros) | `Dext.Events` — **nativo** | Pipeline de Behaviors (logs, tempos, exceções); bus escopado ou singleton |
| **Padrão Defer** | `using` / `IDisposable` | `IDeferred` / `TDeferredAction` | Inspirado em Go; ação executada automaticamente na saída do escopo do bloco |

### A.4 Infraestrutura de Testes

| Recurso | .NET | Equivalente Dext | Notas |
|:---|:---|:---|:---|
| **Framework de Testes** | xUnit / NUnit / MSTest (terceiros) | `Dext.Testing` — **nativo** | Integrado diretamente ao framework |
| **Testes Baseados em Atributos** | `[Fact]`, `[Theory]`, `[Test]` | `[Fact]`, `[Test]`, `[Fixture]`, `[TestClass]` | |
| **Testes Baseados em Dados** | `[InlineData]`, `[MemberData]` | `[TestCase]`, `[TestCaseSource]`, `[Values]`, `[Range]`, `[Random]` | |
| **Testes Combinatórios** | Parametrizado (manual) | `[Combinatorial]` | Todas as combinações de parâmetros são geradas automaticamente |
| **Ciclos de Vida (Lifecycle Hooks)** | `[SetUp]`, `[TearDown]`, `[OneTimeSetUp]` | `[Setup]`, `[TearDown]`, `[BeforeAll]`, `[AfterAll]`, `[AssemblyInitialize]` | |
| **Asserções Fluidas** | FluentAssertions (terceiros) | `Dext.Assertions` — **nativo** | Padrão de escrita fluida `Should(Value)`; comparações estruturais complexas |
| **Asserções Suaves (Soft Asserts)** | FluentAssertions (terceiros) | `Assert.Multiple(...)` — nativo | Coleta múltiplas falhas antes de abortar a execução do teste |
| **Testes de Snapshot** | Verify (terceiros) | Nativo no Dext | Base de comparação em disco, comparação estrutural de JSON, modo de atualização automática |
| **Simulações (Mocks)** | Moq / NSubstitute (terceiros) | `Dext.Mocks` — **nativo** | `Mock<T>.Setup.Returns(Val)`, seletores de argumentos (matchers) e verificação |
| **Auto-Mocking** | AutoFixture + Moq (terceiros) | `TAutoMocker` — **nativo** | Injeção automática de mocks diretamente no contêiner de DI de testes |
| **Relatórios de CI/CD** | Bibliotecas de terceiros | Integrado | Formatos nativos: JUnit XML, xUnit XML, TRX (Azure DevOps), HTML (Dark Theme), JSON, SonarQube |

---

## Bloco B — Recursos Exclusivos do Dext

> [!IMPORTANT]
> Os recursos listados neste bloco existem no Dext, mas **não possuem equivalente direto no ecossistema .NET de fábrica** (ou exigem soluções comerciais complexas de terceiros sem suporte oficial). Estes são os principais diferenciais competitivos e tecnológicos do Dext.

| Recurso | Dext | Status no .NET / EF Core | Impacto Prático |
|:---|:---|:---|:---|
| **Database as API** | Atributo `[DataApi]` + `app.MapDataApis` — gera uma API REST CRUD completa em tempo de execução com **1 única linha** | Sem equivalente. Exige a escrita manual de Scaffold, Controllers, camada de Serviço, Repositório e DTOs | 🔴 Altíssimo — elimina dias de trabalho repetitivo escrevendo código de CRUD padrão |
| **Smart Properties / `Prop<T>`** | Record genérico de modo duplo: armazena valores OU gera AST via sobrecarga de operadores. Consultas fortemente tipadas **sem strings mágicas**. Mesma AST interpretada pelo ORM, cache em memória e roteador HTTP | O LINQ é nativo no C#; porém a árvore de expressão gerada (AST) não é portável entre o ORM e outros subsistemas do framework de forma simples | 🔴 Altíssimo — elimina o uso de `nameof()` e a necessidade de boilerplates complexos de Expression Trees |
| **EntityDataSet (Ponte ORM ↔ VCL/FMX)** | Conecta listas `TList<T>` (baseadas em POCO ou Smart Properties) diretamente a componentes visuais de tela (DBGrid, FastReport, etc.). **Visualização em tempo real de dados reais no próprio IDE no modo de design** sem precisar compilar | Sem equivalente corporativo de fábrica. O DataAdapter do Windows Forms não se integra diretamente a entidades POCO modernas e não gera prévias visuais em tempo de design no IDE a partir do ORM | 🔴 Altíssimo (Diferencial específico e exclusivo para o Delphi corporativo) |
| **SIMD-Accelerated Collections** | `TRawDictionary` com endereçamento aberto + Linear Probing. Consultas vetorizadas via instruções AVX2/SSE2. **6.6 vezes mais rápido** que o `TDictionary` padrão da RTL | Coleções da biblioteca BCL usam técnicas semelhantes, mas o desenvolvedor não tem controle ou possibilidade de tuning fino nessa camada | 🟡 Alto — performance crítica em fluxos de alta concorrência |
| **`TExpressionEvaluator` Integrado** | Avalia a **mesma AST do ORM** diretamente contra objetos de memória e dicionários. Utilizado no motor de filtros do `EntityDataSet` ou de forma avulsa | O EF Core não expõe um avaliador em memória acessível para a mesma árvore de expressão utilizada para a geração de queries SQL físicas | 🟡 Alto — unifica de fato as regras de consulta física e lógica de memória em um único lugar |
| **`TStringExpressionParser`** | Converte parâmetros da URL QueryString (`?age_gt=18`) diretamente em nós de AST do tipo `IExpression` com inferência automática de tipo de dado | Sem equivalente nativo no .NET. Ecossistemas como Django REST (Python) fazem isso; no ASP.NET exige a escrita de rotinas personalizadas | 🟡 Alto — atua como a engrenagem que viabiliza o dinamismo do `Database as API` |
| **Servidor MCP Nativo** | Implementação sem dependências externas do protocolo Model Context Protocol (MCP 2025-03-26). Atributos RTTI `[MCPTool]`, `[MCPParam]`, `[MCPResource]`. Transportes via HTTP Stream, SSE, Stdio | Sem implementação oficial de servidor MCP pelo time do .NET (ecossistema ainda nascente em 2026) | 🟡 Alto — habilita o framework a interagir nativamente com agentes de IA (AI-Native) |
| **Flyweight / Streaming SSR** | `TStreamingViewIterator<T>` — renderiza views HTML com mais de 10.000 registros mantendo **consumo de memória constante O(1)** durante laços de repetição `@foreach` | Recursos como `IAsyncEnumerable<T>` e streaming via `yield return` existem, mas exigem encadeamento e arquitetura manual complexa para evitar carregar a lista na heap | 🟡 Alto — essencial para SSR de grande volume de dados |
| **Detecção Automática de HTMX** | O framework detecta automaticamente os cabeçalhos `HX-Request` nas requisições HTTP e suprime o layout global padrão em respostas de páginas | O ASP.NET não possui integração nativa out-of-the-box para o ecossistema HTMX; exige tratamento manual de cabeçalho nas rotas | 🟢 Médio |
| **Binary Code Folding** | `TRawList<T>` — as classes genéricas tipadas atuam apenas como cascas finas sobre um núcleo de gerenciamento de memória bruta. **Redução de até 60% no tempo de compilação** | Não aplicável ao C# (o CLR não sofre com o problema de "Generic Bloom" que gera inchaço de binário em Delphi) | 🟢 Médio (Diferencial técnico vital para Delphi) |
| **Live IDE Scaffolding Expert** | O Dext Design-Time Expert interpreta units `.pas` e cria os componentes visuais `TFields` dinamicamente **sem precisar compilar o projeto**. Permite seleção de tabelas com prévia de SQL em tempo real | O Scaffold do EF Core exige compilação prévia e execução de ferramentas de terminal; não possui integração visual interativa ao IDE | 🟢 Médio (Vantagem para modernização RAD) |
| **AI Skills Integradas** | Arquivos de habilidades em formato Markdown (`.md`) nativos que ensinam assistentes de IA (Cursor, Antigravity, Copilot, Claude) a gerar códigos Dext corretos de forma idiomática | Aumenta significativamente a produtividade ao utilizar editores de código modernos assistidos por IA | 🟢 Médio — Multiplicador de DX |
| **Painel de Telemetria Visual Integrado** | Painel web integrado (Em Desenvolvimento) com árvore de spans estilo Gantt, gráficos de métricas RED (RPS, latência, erros), profiler de SQL e requisições HTTP | No .NET, exige a configuração complexa e independente de Grafana + Prometheus + Jaeger + OpenTelemetry Collector | 🔴 Altíssimo para equipes de desenvolvimento sem infraestrutura complexa de DevOps corporativo |
| **UUID v7 Nativo** | `TUUID.NewV7` — identificadores ordenados no tempo de acordo com a RFC 9562. Troca automática de endianness para tratamento otimizado de campos PostgreSQL `uuid` | O método `Guid.NewGuid()` gera UUID v4; o uso de v7 no .NET exige a dependência de pacotes NuGet adicionais de terceiros (como o UUIDNext) | 🟢 Médio |
| **Integração com FireDAC `ConnectionDef`** | Método `UseConnectionDef('MyConn')` resolve automaticamente o dialeto SQL, drivers físicos e pooling a partir do FDManager do Delphi | Habilita deploy com configuração zero ao ler diretamente os perfis globais ativos de conexão da IDE ou do Servidor. | 🟢 Médio (Facilidade operacional em Delphi) |
| **Executável de Arquivos `.http` Integrado** | Analisador nativo para arquivos padrão `.http`. O mesmo arquivo documenta a API no repositório, serve para testes rápidos no Painel e é executado pelo RestClient | A convenção de arquivos `.http` é suportada por plugins de editores (como VS Code); o ASP.NET não possui um executor nativo na engine | 🟢 Médio — Facilidade para documentação viva |

---

## Bloco C — Parcial no Dext / Planejado no Roadmap

> [!NOTE]
> Estes são recursos onde o ecossistema .NET oferece atualmente uma implementação mais madura, completa ou estruturada de fábrica. O Dext os possui de forma parcial ou eles já estão planejados no roadmap oficial de evolução do framework.

| Recurso | Status no .NET | Status no Dext | Notas |
|:---|:---|:---|:---|
| **ActivitySource do OpenTelemetry** | Totalmente integrado (suporte a ActivitySource, Meter e W3C Trace Context out-of-the-box) | Parcial — suporte nativo a `TDiagnosticSource` + rastreamento de CorrelationId | Mapeado no Roadmap: desenvolvimento de exportadores OTel nativos (OTLP, Console) |
| **HybridCache (L1 + L2 Unificados)** | Introduzido no .NET 9+ — unifica L1 (memória local) + L2 (Redis/SQL) com proteção contra cache stampede e invalidação por tags | Parcial — motores de Cache em Memória e Redis disponíveis separadamente | Mapeado no Roadmap: unificação das camadas sob uma única API de `HybridCache` |
| **Pool de DbContext** | Método `AddDbContextPool<T>` — pool de reaproveitamento de instâncias do DbContext em tráfego massivo | Não implementado | Mapeado no Roadmap: classe `TPooledDbContextFactory` |
| **Named Query Filters (múltiplos)** | Introduzido no EF Core 10 — permite aplicar múltiplos filtros globais por entidade, ativando/desativando seletivamente | Parcial — suporte a um único filtro global estático por entidade | Mapeado no Roadmap: suporte a múltiplos filtros nomeados dinâmicos |
| **Auditoria via Interceptors** | EF Core Interceptors — pipeline totalmente desacoplado por eventos do ciclo de vida | Parcial — auditoria de entidades centralizada via sobrescrita de métodos no `DbContext` | Mapeado no Roadmap: interfaces formais desacopladas para interceptores |
| **Interceptador de `IDbCommand`** | Intercepção formal de comandos SQL executados para auditoria e injeção de Correlation IDs | Parcial — o motor `TDiagnosticSource` intercepta e coleta a execução física do SQL | Mapeado no Roadmap: interfaces formais de comando e transação |
| **Busca Vetorial / Busca Híbrida** | Integrado no EF Core 10 + suporte nativo a SQL Server 2025 | Não implementado | Demanda de nicho — o time avalia a adoção de bancos vetoriais pelo mercado Delphi |

---

## Bloco D — Diferenças de Contexto (Não Aplicáveis ao Delphi por Design)

> [!NOTE]
> Os itens listados neste bloco referem-se a recursos do ecossistema .NET que não fazem sentido ou não se aplicam ao Dext Framework devido a diferenças de arquitetura de baixo nível e de plataforma. Não representam lacunas do Dext, mas sim diferenças estruturais.

| Recurso no .NET | Por que não se aplica ao Dext |
|:---|:---|
| **Blazor / WebAssembly** | O Delphi compila nativamente para binários de máquina. Para interfaces visuais desktop, utiliza-se a VCL (Windows) ou FMX (multiplataforma nativa). Não há necessidade de runtime de navegador web |
| **Interoperabilidade JavaScript** | O Delphi não opera sobre uma engine JS interna. A comunicação e integração com navegadores ou outras plataformas de frontend é realizada por meio de APIs REST padrão da indústria |
| **Compilação Nativa AOT** | O compilador do Delphi sempre gerou binários nativos AOT (Ahead-of-Time) de fábrica por padrão. Não há compilação JIT (Just-In-Time) e nem tempos de inicialização lentos (cold start) |
| **UI de Identidade por Biometria / Passkey** | Protocolo de nível de navegador WebAuthn — geralmente tratado nas camadas de proxy reverso ou nos clientes de frontend (SPA, Mobile) |
| **Módulo do IIS (ANCM)** | O Dext utiliza o `WebBroker Adapter` para integração transparente e nativa a servidores IIS/ISAPI/CGI, atuando como componente nativo de primeira classe |
| **Compilador gRPC (Geração de Código `.proto`)** | O Delphi não possui um compilador gRPC nativo fornecido pela Embarcadero. **O gRPC e Protobuf estão mapeados na Wave 3 do Roadmap do Dext ([S02](../../DextRepository/Docs/ROADMAP.md#L36))** como um motor nativo baseado em IOCP/EPOLL de alta performance com mapeamento direto Code-First para Interfaces Delphi ([S14](../../DextRepository/Docs/ROADMAP.md#L42)). |
| **Compiled Models (EF Core)** | Como o Delphi resolve tudo ahead-of-time, os metadados do ORM são processados e otimizados em tempo de compilação. Não há custo de warm-up ao inicializar o ORM em tempo de execução |
| **Validação via Source Generators** | O Delphi não possui Source Generators como recurso de sintaxe da linguagem. O Dext implementa validações baseadas em RTTI (`[Required]`, `[Range]`, etc.) que atingem o mesmo objetivo com flexibilidade |
| **Middleware de HSTS** | Geralmente configurado nas camadas de proxy reverso e balanceadores (Nginx, Caddy, Traefik). O Dext foca nos fluxos críticos do nível de aplicação |
| **Pipeline de Ativos Estáticos (`MapStaticAssets`)** | Relevante para frameworks que servem arquivos de frontend estáticos diretamente da aplicação. Aplicações Delphi em escala produtiva delegam a entrega de arquivos estáticos a CDNs ou proxies reversos |

---

## Estatísticas de Comparação

| Categoria | Quantidade |
|:---|:---:|
| Recursos em Paridade Total (Bloco A) | 60+ |
| Recursos Exclusivos do Dext (Bloco B) | 17 |
| Itens em Roadmap / Parciais (Bloco C) | 7 |
| Diferenças de Contexto (Bloco D) | 10 |

---

## Engenharia & Fundações de Alta Performance

Para compreender como estes pontos de paridade funcional e os recursos exclusivos de arquitetura são implementados no nível mais baixo (otimizações do compilador, uso de memória e benchmarks físicos), consulte o nosso guia técnico principal de engenharia:

* 👉 **[Visão Geral do Ecossistema Dext](https://github.com/dotpas/dext/blob/main/Docs/Dext_Ecosystem_Overview.pt-br.md)**: Estudo detalhado sobre o *Zero-Allocation Web Pipeline*, a técnica de *Binary Code Folding* (que resolve oGeneric Bloom em Delphi) e as *Coleções Otimizadas por SIMD*.

---

## Navegação

Este documento é uma **tabela de referência rápida** — utilize-a para buscar recursos específicos ou realizar comparações pontuais.

| Quero... | Ir para... |
|:---|:---|
| Compreender *por que* o Dext foi construído e obter a visão geral narrativa | [Dext vs .NET — Narrativa de Arquitetura](./Dext_vs_DotNet_Narrative.pt-br.md) |
| Aprofundar-me nas capacidades do ORM com exemplos de código reais (Delphi vs C#) | [Dext ORM — Referência Completa de Recursos](./Dext_ORM_Capabilities.pt-br.md) |
| Compreender o licenciamento sob Apache 2.0 e conformidade jurídica corporativa | [Licenciamento Open Source para Empresas](./Open_Source_Licensing_Enterprise.pt-br.md) |
| Ler sobre a engenharia de baixo nível do ecossistema do Dext | [Visão Geral do Ecossistema Dext](https://github.com/dotpas/dext/blob/main/Docs/Dext_Ecosystem_Overview.pt-br.md) |

---

*Dext Framework — Referência de Comparação de Recursos | Maio de 2026*
