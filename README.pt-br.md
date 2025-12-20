[ 🇺🇸 English ](README.md)

# Dext Framework - Modern Full-Stack Development for Delphi

> ⚠️ **Status: Desenvolvimento Ativo**
> O projeto está em fase de implementação da versão 1.0. A API pública, sintaxe fluente e nomes de métodos estão sujeitos a alterações (breaking changes) sem aviso prévio até o lançamento da primeira versão estável.

**Dext** é um ecossistema completo para desenvolvimento moderno em Delphi, combinando um framework web de alta performance (inspirado em ASP.NET Core) com um ORM robusto e ferramentas de infraestrutura avançadas.

## 🎯 Filosofia e Objetivos

*   **Paridade com .NET Core**: O objetivo primário é alcançar a paridade de funcionalidades com os frameworks equivalentes do ecossistema .NET (ASP.NET Core, EF Core), mantendo-se atualizado com as novidades da plataforma.
*   **Performance Nativa**: Após a estabilização funcional da v1, o foco total será em **otimização de performance**, visando competir com frameworks de alta velocidade.
*   **Inovação**: Embora inspirado no .NET, o Dext não se limita a ele, buscando implementar soluções que façam sentido especificamente para a linguagem Delphi.

---

## 📄 Licença

Este projeto é licenciado sob a **Apache License 2.0** (a mesma utilizada pelo .NET Core). Isso permite o uso livre em projetos comerciais e open-source, com a segurança de uma licença permissiva e moderna.

---

## 🚀 Módulos Principais

### 🌐 Dext.Web (Web Framework)
Um framework HTTP leve e poderoso para construir REST APIs e microserviços.
- **Minimal APIs**: Sintaxe fluente e concisa para definição de rotas.
- **Controllers**: Suporte tradicional baseado em classes para APIs complexas.
- **Smart Binding**: Serialização e validação automática de JSON para Records/Classes.
- **Middlewares**: Pipeline de requisição modular e extensível.
- **Smart JSON**: Suporte nativo para TGUID/UUID, Enums e tipos avançados na serialização JSON.
- **OpenAPI**: Integração nativa com Swagger e geração automática de documentação.

### 🗄️ Dext.Entity (ORM)
Um ORM moderno focado em produtividade e performance.
- **Code-First**: Defina seu banco de dados usando classes Delphi.
- **Scaffolding**: Suporte a Database-First para gerar entidades a partir de esquemas existentes.
- **Migrations**: Controle de versão do esquema do banco de dados via CLI.
- **Fluent Query API**: Consultas fortemente tipadas e expressivas.
- **Change Tracking**: Controle automático de mudanças e persistência otimizada.
- **Tipos Avançados**: Suporte nativo para UUID/GUID, Enums (como string ou int), JSON/JSONB e Arrays.
- **Multi-Database**: Suporte para SQL Server, PostgreSQL, Firebird, MySQL, Oracle e SQLite.
- **Drivers de Alta Performance**:
  - **Driver FireDAC Padrão**: Completo com compatibilidade TDataSet
  - **Driver FireDAC Phys**: Acesso "bare metal" sem TDataSet para máxima performance
  - Acesso direto à camada física do FireDAC (IFDPhysConnection) para queries ultra-rápidas

### ⚙️ Dext.Core (Infraestrutura)
A fundação do framework, utilizável em qualquer tipo de aplicação.
- **Dependency Injection**: Container IOC completo e rápido.
- **Configuration**: Sistema de configuração flexível (JSON, Variáveis de Ambiente).
- **Logging**: Abstração de log estruturado.
- **Async/Await**: Primitivas para programação assíncrona real.
- **Collections**: Coleções genéricas avançadas com extensões funcionais.
- **Specifications**: Encapsulamento e composição de regras de negócio (DDD).
- **Expressions**: Primitivas de árvores de expressão para avaliação dinâmica de lógica.
- **Serialização JSON**:
  - **UTF-8 de Alta Performance**: Serialização/desserialização direta em UTF-8 sem conversões intermediárias
  - **Parsing Zero-Copy**: Otimizado para mínimas alocações de memória
  - **Suporte Inteligente a Tipos**: Tratamento nativo de GUID, Enums, DateTime e tipos customizados
  - **Drivers Plugáveis**: Suporte para JsonDataObjects (padrão) e System.JSON

---

## 📚 Índice de Documentação

### 🚀 Começando


### 🌐 Web API
- **Roteamento & Endpoints**
  - [Minimal API](Docs/minimal-api.md)
  - [Validação](Docs/model-binding.md) # (Inclui validação)
- **Segurança & Middleware**
  - [Autenticação JWT](Docs/jwt-authentication.md)
  - [CORS](Docs/cors.md)
  - [Rate Limiting](Docs/rate-limiting.md)
- **Avançado**
  - [Background Services](Docs/background-services.md)
  - [Action Filters](Docs/action-filters.md)
  - [Swagger / OpenAPI](Docs/swagger.md)

### 🗄️ Acesso a Dados (ORM)
- [Configuração de Banco de Dados](Docs/database-config.md)
- [Fluent Query API](Docs/fluent-query-api.md)
- [Migrations](Docs/migrations-guide.md)
- [Lazy Loading](Docs/lazy-loading-advanced.md)
- [Bulk Operations](Docs/bulk-operations.md)
- [Soft Delete](Docs/soft-delete.md)

### ⚙️ Core & Infraestrutura
- [Dependency Injection & Scopes](Docs/scoped-services.md)
- [Configuration & Options Pattern](Docs/options-pattern.md)
- [Async Programming](Docs/async-api.md)
- [Caching](Docs/caching.md)

---

## 💻 Requisitos

- **Delphi**: Recomendado Delphi 10.4 Sydney ou superior (devido ao uso extensivo de features modernas da linguagem).
- **Indy**: Utiliza componentes Indy (já inclusos no Delphi) para a camada de transporte HTTP (sujeito a substituição/otimização futura).

## 📦 Instalação e Configuração

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/dext-framework/dext.git
   ```

   > 📦 **Nota sobre Pacotes**: O projeto está organizado em pacotes modulares localizados no diretório `Sources` (ex: `Dext.Core.dpk`, `Dext.Web.Core.dpk`, `Dext.Data.dpk`). Você pode abrir `Sources/DextFramework.groupproj` para carregar todos os pacotes de uma vez.

2. **Configure os Paths no Delphi:**
   Adicione os seguintes caminhos ao seu **Library Path** (para compilação) e **Browsing Path** (para navegação no código):
   - `\Sources\Core`
   - `\Sources\Data`
   - `\Sources\Expressions`
   - `\Sources\Hosting`
   - `\Sources\Http`
   - `\Sources\Testing`

   > 📝 **Nota**: Arquivos compilados (`.dcu`, binários) serão gerados no diretório `.\Output`.


3. **Dependências:**
   - O framework utiliza `FastMM5` (recomendado para debug de memória).
   - Drivers de banco de dados nativos (FireDAC, etc) são suportados.

---

## ⚡ Exemplo Rápido (Minimal API)

```pascal
program MyAPI;

uses
  Dext.Web;

begin
  var App := TDextApplication.Create;
  var Builder := App.Builder;

  // Rota simples
  Builder.MapGet<IResult>('/hello', 
    function: IResult
    begin
      Result := Results.Ok('{"message": "Hello Dext!"}');
    end);

  // Rota com parâmetro e binding
  Builder.MapGet<Integer, IResult>('/users/{id}',
    function(Id: Integer): IResult
    begin
      Result := Results.Json(Format('{"userId": %d}', [Id]));
    end);

  App.Run(8080);
end.
```

## 🧩 Model Binding & Injeção de Dependência

Dext resolve dependências automaticamente e deserializa JSON bodies para Records/Classes:

```pascal
// 1. Registre os Serviços
App.Services.AddSingleton<IEmailService, TEmailService>;

// 2. Defina o Endpoint com Dependências
// - 'Dto': Automaticamente populado a partir do JSON Body (Smart Binding)
// - 'EmailService': Automaticamente injetado do Container de DI
App.Builder.MapPost<TUserDto, IEmailService, IResult>('/register',
  function(Dto: TUserDto; EmailService: IEmailService): IResult
  begin
    EmailService.SendWelcome(Dto.Email);
    Result := Results.Created('/login', 'User registered');
  end);
```

## 💎 Exemplo ORM (Fluent Query)

O Dext ORM permite consultas expressivas e fortemente tipadas, eliminando SQL strings mágicas:

```pascal
// Consulta complexa com Joins e Filtros
// O: TOrder (Alias/Proxy)
var Orders := DbContext.Orders
  .Where((O.Status = TOrderStatus.Paid) and (O.Total > 1000))
  .Include('Customer')
  .Include('Items')
  .OrderBy(O.Date.Desc)
  .Take(50)
  .ToList;

// Bulk Update de alta performance
DbContext.Products
  .Where(P.Category = 'Outdated') // P: TProduct
  .Update                         // Inicia update em massa
  .Execute;
```

## ⚡ Exemplo Async (Fluent Tasks)

Esqueça a complexidade de `TThread`. Use uma API moderna baseada em Promises/Tasks:

```pascal
// Encadeamento de tarefas assíncronas
var Task := TAsyncTask.Run<TUserProfile>(
  function: TUserProfile
  begin
    // Executa em background
    Result := ExternalApi.GetUserProfile(UserId);
  end)
  .ThenBy<Boolean>(
    function(Profile: TUserProfile): Boolean
    begin
      Result := Profile.IsVerified and Profile.HasCredit;
    end)
  .OnComplete( // Volta para a UI Thread automaticamente
    procedure(IsVerified: Boolean)
    begin
      if IsVerified then
        ShowSuccess('User Verified!')
      else
        ShowError('Verification Failed');
    end)
  .Start; // Inicia a execução

// Controle de Timeout e Cancelamento
var CTS := TCancellationTokenSource.Create;

TAsyncTask.Run<TReport>(
  function: TReport
  begin
    // Passa o token para operação de longa duração
    Result := ReportService.GenerateHeavyReport(CTS.Token);
  end)
  .WithCancellation(CTS.Token) // Vincula token à pipeline da Task
  .OnComplete(
    procedure(Report: TReport)
    begin
      ShowReport(Report);
    end)
  .OnException(
    procedure(Ex: Exception)
    begin
      if Ex is EOperationCancelled then
        ShowMessage('Operação expirada (Timeout)!')
      else
        ShowError(Ex.Message);
    end)
  .Start;
```

## 🧪 Exemplos e Testes

O repositório contém projetos de exemplo práticos:

- **`Examples/Orm.EntityDemo`**: Demonstração abrangente dos recursos do ORM (CRUD, Migrations, Consultas).
- **`Examples/Web.ControllerExample`**: Demonstra implementação de API baseada em Controllers (inclui um cliente web em **Vite**).
- **`Examples/Web.SwaggerExample`**: Mostra como integrar e customizar a documentação OpenAPI/Swagger.
- **`Examples/Web.TaskFlowAPI`**: Uma API REST "Mundo Real" completa demonstrando arquitetura em camadas, ORM, Auth e DI.
- **`Examples/Dext.Starter.Admin`**: **(Recomendado)** Um Painel Administrativo Moderno com HTMX, Camada de Serviço e Minimal APIs. [Leia o Guia](Examples/Dext.Starter.Admin/README.md).

---

## 🔮 Em Breve

- **Advanced Testing Framework**: Framework de testes puramente Delphi focado em padrões modernos (TDD/BDD).
- **Documentação**: Revisão completa e suporte bilíngue (Inglês/Português) para todos os módulos.

---

## 🗺️ Roadmaps

Acompanhe o desenvolvimento do projeto:
- [Plano de Lançamento V1.0](Docs/Roadmap/v1-release-plan.md) 🚀
- [ORM Roadmap](Docs/Roadmap/orm-roadmap.md)
- [Web Framework Roadmap](Docs/Roadmap/web-roadmap.md)
- [Infra & IDE Roadmap](Docs/Roadmap/infra-roadmap.md)
- [Arquitetura & Performance](Docs/architecture-performance.pt-br.md)

---

**Dext Framework** - *Performance nativa, produtividade moderna.*
Desenvolvido com ❤️ pela comunidade Delphi.
