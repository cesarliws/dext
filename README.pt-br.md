> **Reading this in English?** This page is the Portuguese README for Dext 1.0. The full English version — same examples, the book, and the complete feature map — is in [README.md](README.md). If English is more comfortable, click through and read that document instead of skimming a flag.

# Dext Framework 1.0
**Full-stack nativo para Delphi.**

<p align="center">
  <img src="Docs/Images/dext-mascot.png" alt="Mascote do Dext Framework">
</p>

O compilador Delphi nunca foi o problema. O problema era o chão.

Durante anos, um backend moderno em Object Pascal significava costurar dezenas de bibliotecas: uma para injeção de dependência, outra para HTTP, outra para ORM, outra para testes. Cada uma com um jeito. Nenhuma dormia junto.

O **Dext 1.0** é esse chão. Um ecossistema só — DI, ORM, pipeline web, telemetria e testes — compilado nativo. Sem JIT. Sem cold start. Sem colcha de retalhos.

E é **Apache 2.0**: gratuito para o ERP de vinte anos e para o produto que ainda não tem nome.

---

## Por que isso importa agora

Se a equipe está olhando para C# porque “no Delphi não tem o padrão da indústria”, o Dext fecha esse abismo sem reescrever o sistema.

Paridade funcional com ASP.NET Core e Entity Framework Core, na linguagem que vocês já dominam, com as vantagens que o .NET não entrega de graça: binário nativo, memória enxuta, startup instantâneo.

- [**Dext vs .NET: arquitetura**](Docs/Comparison/Dext_vs_DotNet_Narrative.pt-br.md) — como o Dext une padrão moderno e compilação nativa.
- [**Matriz recurso por recurso**](Docs/Comparison/Feature_Comparison_Dext_vs_DotNet.pt-br.md) — mais de 60 itens lado a lado.
- [**Capacidades do ORM**](Docs/Comparison/Dext_ORM_Capabilities.pt-br.md) — DbContext, Change Tracking, JSON, Lazy/Eager.
- [**Licenciamento corporativo**](Docs/Comparison/Open_Source_Licensing_Enterprise.pt-br.md) — por que Apache 2.0 é seguro para uso comercial.

---

## O livro

Não é um catálogo de features. É um produto corporativo real — o **Dext Faturamento** — construído do zero em cinco laboratórios: Minimal APIs, persistência, SaaS multi-tenant, JWT, jobs, Redis, Hubs, Docker, gRPC e ferramentas para agentes de IA. Sem deixar a IA gerar SQL arbitrário.

<p align="center">
  <img src="Docs/Images/dext-web-book-mockup.png" alt="Livro Desenvolvimento Web Profissional com Delphi e Dext Framework" width="70%">
</p>

**Desenvolvimento Web Profissional com Delphi e Dext Framework** — Cesar Romero, 1ª edição, 2026. ISBN 978-65-02-32503-2.

- **Impresso no Brasil (UICLAP):** [loja.uiclap.com/titulo/ua197387](https://loja.uiclap.com/titulo/ua197387)
- **Paperback na Amazon:** [amazon.com/dp/6502325033](https://www.amazon.com/dp/6502325033)
- **Kindle (Brasil):** [amazon.com.br/dp/B0HGYTSYYY](https://www.amazon.com.br/dp/B0HGYTSYYY)
- **Kindle (global):** [amazon.com/dp/B0HGYTSYYY](https://www.amazon.com/dp/B0HGYTSYYY)
- **Código dos laboratórios:** [github.com/dotpas/book-dext-web](https://github.com/dotpas/book-dext-web)

A edição em inglês está em revisão final.

---

## Para onde ir depois deste README

O README mostra o sabor. O mapa está na pasta `Docs`.

1. **[O Livro do Dext](Docs/Book.pt-br/README.md)** — o guia oficial: instalação, Minimal APIs, ORM, segurança, tempo real, CLI, MCP. Comece por [Por onde começar](Docs/Book.pt-br/01-primeiros-passos/por-onde-comecar.md) e [Instalação](Docs/Book.pt-br/01-primeiros-passos/instalacao.md).
2. **[Índice completo de features](Docs/Features_Implemented_Index.pt-br.md)** — tudo o que o 1.0 entrega, organizado por módulo, com a unit de implementação.
3. **[Comparativos com .NET](Docs/Comparison/README.pt-br.md)** — para levar à reunião em que alguém perguntar “por que não migrar?”.

English editions of the same docs live under [`Docs/Book`](Docs/Book/README.md) and [`Docs/Features_Implemented_Index.md`](Docs/Features_Implemented_Index.md).

---

## Onde o Dext entra

- **APIs de alta performance** — Minimal APIs, Controllers ou `[DataApi]` gerando REST a partir da entidade.
- **Aplicações web** — SSR com o template engine nativo ou Web Stencils, HTMX sem SPA pesado.
- **Concorrência de verdade** — `TAsyncTask`, cancellation tokens, Rest Client assíncrono. Sem `TThread` na unha.
- **Backend mobile** — a mesma API para iOS e Android, com JWT, rate limit e health checks.
- **Legado que precisa viver** — DataSnap, ISAPI/Apache, VCL. O Dext entra como fundação moderna sem apagar vinte anos de ERP.
- **Jobs, microserviços, IoT** — background jobs persistentes, MQTT, gRPC, Redis.

---

## Cinco minutos de código

### Minimal API

Um endpoint com DI e model binding não pede cerimônia:

```pascal
program MyAPI;

uses Dext.Web;

begin
  var App := WebApplication;

  App.MapGet('/hello', function: string
  begin
    Result := 'Hello from Dext! Modern full-stack for Delphi.';
  end);

  App.MapPost<TUserDto, IEmailService, IResult>('/register',
    function(Dto: TUserDto; EmailService: IEmailService): IResult
    begin
      EmailService.SendWelcome(Dto.Email);
      Result := Results.Created('/login', 'Usuário registrado com sucesso');
    end);

  App.Run(8080);
end.
```

### Entidade, DataAPI e Smart Properties

Convention over Configuration. A classe vira tabela — e, se você quiser, vira API:

```pascal
[Table]
[DataApi('/api/orders')]
TOrder = class
private
  FId: IntType;
  FStatus: Prop<TOrderStatus>;
  FNotes: StringType;
  FTotal: Nullable<CurrencyType>;
  FItems: Lazy<IList<TOrderItem>>;
public
  [PK, AutoInc]
  property Id: IntType read FId write FId;
  property Status: Prop<TOrderStatus> read FStatus write FStatus;
  property Notes: StringType read FNotes write FNotes;
  property Total: Nullable<CurrencyType> read FTotal write FTotal;
  property Items: Lazy<IList<TOrderItem>> read FItems write FItems;
end;
```

### ORM type-safe

Chega de magic string que quebra em produção. O Dext monta a AST da query no próprio Pascal:

```pascal
var O := Prototype.Entity<TOrder>;

var Orders := DbContext.Orders
  .Where((O.Status = TOrderStatus.Paid) and (O.Total > 1000))
  .Include('Customer')
  .Include('Items')
  .OrderBy(O.Date.Desc)
  .Take(50)
  .ToList;

DbContext.Products
  .Where(Prototype.Entity<TProduct>.Category = 'Outdated')
  .Update
  .Execute;
```

### Tasks fluentes

A complexidade de `TThread` vira pipeline. Thread pool, encadeamento, volta segura para a UI:

```pascal
var CTS := TCancellationTokenSource.Create;

TAsyncTask.Run<TStream>(
  function: TStream
  begin
    Result := AsyncClient.DownloadStream('https://api.empresa.com/dados', CTS.Token);
  end)
  .Then<TReport>(
    function(Stream: TStream): TReport
    begin
      Result := JsonSerializer.Deserialize<TReport>(Stream);
      Stream.Free;
    end)
  .OnComplete(
    procedure(Report: TReport)
    begin
      ShowReport(Report);
    end)
  .OnException(
    procedure(Ex: Exception)
    begin
      ShowError('Falha no processo: ' + Ex.Message);
    end)
  .Start;
```

### Configuration, Options e DI

JSON, YAML, User Secrets, variáveis de ambiente, linha de comando — na ordem Twelve-Factor:

```pascal
  var Builder := WebApplication.CreateBuilder;

  Builder.Configuration
    .AddJsonFile('appsettings.json')
    .AddYamlFile('config.yaml')
    .AddEnvironmentVariables;

  Builder.Services
    .Configure<TDatabaseSettings>(Builder.Configuration.GetSection('Database'))
    .AddSingleton<IEmailService, TSmtpEmailService>
    .AddScoped<IOrderRepository, TDbOrderRepository>;

  var App := Builder.Build;
```

### VCL sem abrir mão do ORM

`TEntityDataSet` coloca POCOs no DBGrid, no FastReport e no Object Inspector. Design-time de verdade: *TFields* e dados vivos na IDE, sem compilar o projeto.

---

## O Dext não é só CRUD

CRUD todo mundo faz. O 1.0 foi desenhado para o que vem depois: escala, governança e o restante da semana.

### Database as API

REST completo a partir da entidade — paginação, filtros, papéis e Swagger — com um atributo:

```pascal
[Table, DataApi('/api/products')]
TProduct = class
private
  FId: IntType;
  [Required, MaxLength(100)]
  FName: StringType;
  FPrice: CurrencyType;
public
  [PK, AutoInc]
  property Id: IntType read FId write FId;
  property Name: StringType read FName write FName;
  property Price: CurrencyType read FPrice write FPrice;
end;

App.MapDataApis.Configure<TProduct>(
  DataApiOptions.RequireAuth.RequireWriteRole(['admin'])
);
```

### Servidor MCP nativo

O Dext expõe a regra de negócio Delphi como ferramenta para agentes (Claude, Cursor, Antigravity), no protocolo **MCP**, sem um processo separado:

```pascal
type
  [MCPTool('search_products', 'Busca produtos ativos com filtros de preço')]
  [MCPParam('query', 'Termo de pesquisa do produto')]
  [MCPParam('maxPrice', 'Filtro opcional de preço máximo')]
  TSearchProductsTool = class
  public
    function Execute(const AQuery: string; AMaxPrice: Currency): TList<TProduct>;
  end;
```

### Clean Architecture na IDE

Desacoplar não precisa matar o RAD. Scaffolding no menu de contexto, metadados no Object Inspector, DBGrid com dados reais *antes* de apertar F9.

<details>
<summary><b>📸 Do banco físico ao live data no formulário</b></summary>
<br>

#### 1. Geração de entidades no menu de contexto
<p align="center">
  <img src="Docs/Images/dext-design-time-step1-menu.webp" alt="Passo 1: Menu de contexto do Dext" width="90%">
</p>

#### 2. Seleção das tabelas
<p align="center">
  <img src="Docs/Images/dext-design-time-step2-tables.webp" alt="Passo 2: Seleção de tabelas" width="90%">
</p>

#### 3. Preview do código gerado
<p align="center">
  <img src="Docs/Images/dext-design-time-step3-preview.webp" alt="Passo 3: Código de entidades gerado" width="90%">
</p>

#### 4. Metadados via RTTI no Object Inspector
<p align="center">
  <img src="Docs/Images/dext-design-time-step4-metadata.webp" alt="Passo 4: Editor de metadados" width="90%">
</p>

#### 5. DBGrid com dados vivos em design-time
<p align="center">
  <img src="Docs/Images/dext-design-time-step5-active.webp" alt="Passo 5: DBGrid com dados vivos na IDE" width="90%">
</p>

</details>

### Stored procedures como comandos

Sem amarrar parâmetro na unha. A procedure vira um objeto verificado em compilação:

```pascal
type
  [StoredProcedure('ProcessFiscalNotes')]
  TProcessNotesCommand = class
  private
    FStartDate: TDateTime;
    FProcessedCount: Integer;
  public
    [DbParam('StartDate')]
    property StartDate: TDateTime read FStartDate write FStartDate;

    [DbParam('ProcessedCount', pdOutput)]
    property ProcessedCount: Integer read FProcessedCount write FProcessedCount;
  end;
```

---

## Telemetria que não pede Grafana no notebook

O dashboard nativo coleta logs estruturados, SQL físico, latência HTTP e spans em Gantt — em background, sem travar a request.

<p align="center">
  <img src="Docs/Images/dext-telemetry-live-split.jfif" alt="Telemetria em tempo real com aplicação VCL" width="90%">
</p>

<details>
<summary><b>📸 Painel e tracing SQL</b></summary>
<br>

#### Métricas, RPS, CPU e logs
<p align="center">
  <img src="Docs/Images/dext-telemetry-dashboard.jfif" alt="Painel de telemetria Dext" width="90%">
</p>

#### SQL gerado, parâmetros e tempo
<p align="center">
  <img src="Docs/Images/dext-telemetry-sql-trace.jfif" alt="Dext ORM SQL tracing" width="90%">
</p>

</details>

Há também sinks para **Seq** e **OpenTelemetry** (SigNoz, Datadog) quando a operação cresce.

---

## O ecossistema, em uma página

<p align="center">
  <img src="Docs/Images/dext_ecosystem.png" alt="Arquitetura do ecossistema Dext" width="80%">
</p>

Você inclui o que a solução precisa. O restante fica de fora.

- **Core** — DI (Singleton, Transient, Scoped), RTTI em cache, `IOptions`, Smart Properties.
- **Coleções** — `IList` / `IDictionary` sem vazamento clássico; Binary Code Folding contra *generic bloat*.
- **ORM** — Unit of Work, transações, sete dialetos, JSON/JSONB, soft delete, batch.
- **Web** — Minimal APIs, Controllers, DataAPI, middlewares, Hubs/WebSockets, HTTP/2, HTMX, http.sys / epoll.
- **IA** — servidor MCP nativo; skills para Cursor, Claude e Copilot em `Docs`.
- **Testes** — `TAutoMocker`, snapshots, WebApplicationFactory, Test Explorer na IDE.

**[Lista completa de features e módulos](Docs/Features_Implemented_Index.pt-br.md)** — o índice que acompanha o 1.0, capítulo por capítulo.

---

## Instalação

O caminho curto é o **TMS Smart Setup**. O caminho longo está no Book.

### 1. TMS Smart Setup (recomendado)

O Dext é pacote da comunidade. Ative o Community Server uma vez:

```bash
tms server-enable community
tms install dotpas.dext
```

Na GUI: abra o TMS Smart Setup, habilite **Community Server** nas configurações, busque `dotpas.dext` e clique em **Install**.

> [!TIP]
> Sem o Smart Setup? [Página de download](https://doc.tmssoftware.com/smartsetup/download/).

### 2. Instalação manual

Paths, `Dext.inc`, pacotes de design-time:

- **[Guia completo de instalação](Docs/Book.pt-br/01-primeiros-passos/instalacao.md)**

### Requisitos

- **Tier 1:** Delphi 10.4 Sydney, 11 Alexandria, 12 Athens.
- **Tier 2:** 10.1 Berlin – 10.3 Rio, com limitações (sem inline vars).
- **Piso de compilação:** XE2+, com fallback Indy abaixo do XE8.
- **Dependências:** nenhuma obrigatória. HTTP usa Indy (já vem no Delphi) — sujeito a evolução.
- **Web Stencils:** Delphi 12.2+ (Windows).

**[Matriz de compatibilidade](Docs/Delphi_Compatibility_Matrix.md)**

---

## Nascido para performance

Frameworks recentes em Delphi adotaram alocação desenfreada em nome da conveniência. O Dext devolve o ritmo sem devolver a dor.

<p align="center">
  <img src="Docs/Images/dext_performance_graph.png" alt="Gráfico de performance do Dext" width="80%">
</p>

1. **Pipeline zero-allocation** — JSON direto via `TSpan` / UTF-8, sem gigabytes de `string` temporária no Memory Manager.
2. **SIMD** — parse e comparação em blocos AVX2/SSE2, resposta em poucos ticks de CPU.

---

## Licença

**Apache License 2.0.** Gratuito para open source e para software comercial. Crie, distribua, encapsule. Sem pegadinha.

---

## Comunidade

O Dext cresce com quem usa.

- **Estrela no repositório** — o sinal mais simples de que o projeto existe.
- **Histórias reais** — o que você construiu cabe nas [Discussions](https://github.com/dotpas/dext/discussions).
- **Issues e PRs** — [CONTRIBUTING.md](CONTRIBUTING.md) e o [workflow de features](Docs/CONTRIBUTING_IMPROVEMENTS.md).

Roadmap: [Docs/ROADMAP.md](Docs/ROADMAP.md). Conduta: [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).

<br>
<p align="center">
  <i>Pare de reconstruir fundações. Gaste energia no problema do cliente. O Dext cuida do resto.</i><br>
  <b>Feito com orgulho para o ecossistema Delphi.</b>
</p>
