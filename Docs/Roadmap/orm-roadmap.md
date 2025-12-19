# 🗺️ Dext Entity ORM - Roadmap

Este documento rastreia o desenvolvimento do **Dext Entity**, o ORM nativo do framework Dext.

> **Visão:** Um ORM moderno, leve e performático para Delphi, inspirado no Entity Framework Core e Hibernate, mas com a simplicidade do Delphi.

---

## 📊 Status Atual: **Alpha 0.7** 🚀

O núcleo do ORM está funcional, suportando operações CRUD, mapeamento básico, relacionamentos simples e controle de concorrência.

### ✅ Funcionalidades Implementadas

#### 1. Core & Mapeamento
- [x] **Entity Mapping**: Atributos `[Table]`, `[Column]`, `[PK]`, `[AutoInc]`, `[NotMapped]`.
- [x] **Identity Map**: Cache de primeiro nível para garantir instância única por Contexto.
- [x] **Database Drivers**: Abstração de driver (FireDAC implementado).
- [x] **Dialects**: Suporte multi-banco (SQLite, PostgreSQL, **SQL Server**).
- [x] **Schema Generation**: Geração automática de scripts `CREATE TABLE`.
- [x] **Naming Strategies**: Convenções de nomenclatura configuráveis (SnakeCase, CamelCase).
- [x] **Fluent Mapping**: Mapeamento externo via código (`TEntityMap<T>`) para isolamento do domínio.
- [x] **Nullable Support**: Suporte completo a `Nullable<T>` para campos opcionais e Foreign Keys.
  - *Tipos*: `Nullable<Integer>`, `Nullable<String>`, `Nullable<TGUID>`, etc.
  - *Compatibilidade*: Spring4D e Delphi nativo
  - *Funcionalidades*: Persist, Hydrate, Foreign Key loading
  - *Documentação*: [NULLABLE_SUPPORT.md](NULLABLE_SUPPORT.md)

#### 2. CRUD & Operações
- [x] **Basic CRUD**: `Add`, `Update`, `Remove`, `Find` (por ID).
- [x] **Composite Keys**: Suporte a chaves primárias compostas.
- [x] **Mixed Composite Keys**: Suporte a chaves compostas com tipos diferentes (Integer + String, etc).
  - *API*: `Find([10, 'ABC'])` usando `array of Variant`
  - *Exemplo*: Entidade com `Key1: Integer` e `Key2: String`
  - *Status*: ✅ **Implementado e Validado**
  - *Documentação*: [MIXED_COMPOSITE_KEYS.md](MIXED_COMPOSITE_KEYS.md)
- [x] **Bulk Operations**: `AddRange`, `UpdateRange`, `RemoveRange` (Iterativo).
- [x] **Cascade Insert**: Inserção automática de entidades filhas novas.
- [x] **Optimistic Concurrency**: Controle de concorrência via atributo `[Version]` (Implementado e Validado).

#### 3. Relacionamentos
- [x] **Foreign Keys**: Mapeamento via `[ForeignKey]`.
- [x] **Cascade Delete**: Suporte via Constraint de banco de dados.

---

## 📅 Próximos Passos

### ✅ Fase 3: Advanced Querying (Concluído)
O objetivo foi permitir consultas complexas de forma tipada e fluente. Concluído com sucesso na versão Alpha 0.6.

- [x] **Fluent Query API**: Builder para consultas (`Where`, `OrderBy`, `Skip`, `Take`).
  - *Exemplo:* `Context.Entities<TUser>.List(UserEntity.Age >= 18)`
  - *Exemplo:* `Specification.Where<TUser>(UserEntity.Age >= 18).OrderBy(UserEntity.Name.Asc).Take(10)`
  - *Melhoria:* Overloads simplificados para `Where(IExpression)` e `Select(string)`.
- [x] **Metadados Tipados (TypeOf)**: Geração de metadados para evitar strings mágicas nas queries.
  - *Exemplo:* `UserEntity.Age >= 18`, `UserEntity.Name.StartsWith('John')`
- [x] **Specifications Pattern**: Integração completa com o padrão Specification.
  - Suporte a inline queries: `List(IExpression)`
  - Suporte a specifications reutilizáveis: `TAdultUsersSpec`
  - Fluent builder: `Specification.Where<T>(...).OrderBy(...).Take(...)`
- [x] **Operadores Fluentes**: 
  - Comparação: `=`, `<>`, `>`, `>=`, `<`, `<=`
  - String: `StartsWith`, `EndsWith`, `Contains`, `Like`, `NotLike`
  - Range: `Between(lower, upper)`
  - Null: `IsNull`, `IsNotNull`
  - Lógicos: `and`, `or`, `not`
- [x] **OrderBy Tipado**: `UserEntity.Name.Asc`, `UserEntity.Age.Desc`
- [x] **Include (Eager Loading)**: Carregamento antecipado de relacionamentos.
  - *Status*: ✅ **Implementado e Validado**
  - *Implementado*: `DoLoadIncludes`, API fluente `Specification.Include('Path')`, suporte a `IN` no SQL Generator
  - *Exemplo*: `Specification.All<TUser>.Include('Address')`

#### 🔄 Próximas Melhorias da Fluent API (Inspiradas em Spring4D/LINQ)

- [x] **Lazy Execution (Deferred Execution)**: Queries só executam quando iteradas
  - Implementado `TFluentQuery<T>` e iteradores customizados
  - Queries retornam `TFluentQuery<T>` que adia execução até `for..in` ou `.ToList()`
  - *Status*: ✅ **Implementado e Validado**

- [x] **Projeções (Select)**: Retornar apenas campos específicos
  - `Select<TResult>(selector: TFunc<T, TResult>): TFluentQuery<TResult>`
  - `Select<TResult>(PropertyName: string): TFluentQuery<TResult>` (Novo)
  - `Select(Properties: array of string): TFluentQuery<T>` (Novo - Partial Load)
  - *Exemplo*: `Context.Entities<TUser>.Select(['Name', 'City']).ToList()`
  - *Status*: ✅ **Implementado e Validado**
  - *Memory Safety*: Projeções usam automaticamente "No-Tracking" e "OwnsObjects=True" para prevenir leaks de entidades parciais.

- [x] **Agregações**: Funções de agregação tipadas
  - `Sum`, `Average`, `Min`, `Max` (Suporte a Property Name string e TFunc)
  - `Count()`, `Count(predicate)`, `Any()`, `Any(predicate)`
  - *Exemplo*: `var avgAge := Context.Entities<TUser>.Average('Age');`
  - *Status*: ✅ **Implementado e Validado**

- [x] **Distinct**: Remover duplicatas
  - `Distinct(): IEnumerable<T>`
  - *Exemplo*: `Context.Entities<TUser>.Select(u => u.City).Distinct()`
  - *Status*: ✅ **Implementado e Validado**

- [x] **Paginação Helper**: Resultado paginado com metadados
  - `Paginate(pageNumber, pageSize): IPagedResult<T>`
  - Retorna `TotalCount`, `PageCount`, `HasNextPage`, `HasPreviousPage`
  - *Exemplo*: `var page := Context.Entities<TUser>.Paginate(1, 20);`
  - *Status*: ✅ **Implementado e Validado**

- [x] **GroupBy**: Agrupamento com agregações
  - `GroupBy<TKey>(keySelector): IEnumerable<IGrouping<TKey, T>>`
  - *Exemplo*: `Context.Entities<TUser>.GroupBy(u => u.City)`
  - *Status*: ✅ **Implementado e Validado** (In-memory)
  - *Gap*: ⚠️ SQL translation pendente

- [x] **Join Explícito**: Joins tipados
  - `Join<TInner, TKey, TResult>(inner, outerKey, innerKey, resultSelector)`
  - *Exemplo*: `users.Join(addresses, 'AddressId', 'Id', ...)` (Novo overload simplificado)
  - *Status*: ✅ **Implementado e Validado** (In-memory)
  - *Gap*: ⚠️ SQL translation pendente

#### 🚀 Otimizações de Performance

- [x] **FirstOrDefault Otimizado**: Usa `LIMIT 1` no SQL
  - Ao invés de carregar todos os registros e pegar o primeiro
  - SQL gerado: `SELECT * FROM users WHERE age > 18 LIMIT 1`
  - *Status*: ✅ **Implementado e Validado**
  - *Benefício*: Performance significativa em queries grandes

- [x] **Any Otimizado**: Usa `SELECT 1 ... LIMIT 1` ao invés de `COUNT(*)`
  - Para na primeira ocorrência ao invés de contar todos os registros
  - SQL gerado: `SELECT 1 FROM users WHERE age > 18 LIMIT 1`
  - *Status*: ✅ **Implementado e Validado**
  - *Benefício*: Performance dramática em verificações de existência

- [x] **Select Otimizado (Projeções)**: Carrega apenas colunas necessárias
  - `Specification.Select(['Name', 'City'])`
  - SQL gerado: `SELECT Name, City FROM Users ...`
  - *Status*: ✅ **Implementado e Validado**
  - *Benefício*: Reduz tráfego de rede e uso de memória ao evitar `SELECT *`

### 📦 Fase 4: Loading Strategies & Memory Management

- [x] **Unit of Work Pattern**: Implementar rastreamento de mudanças e commit em lote.
  - Adicionar método `Clear()` no DbSet para limpar IdentityMap e destruir entidades gerenciadas
  - Implementar `SaveChanges()` no DbContext para persistir todas as mudanças de uma vez
  - Rastrear estado das entidades (Added, Modified, Deleted, Unchanged)
- [x] **Eager Loading (.Include)**: Carregamento antecipado completo e validado.
  - *Exemplo:* `Context.Entities<TUser>.Include('Address').Find(1);`
- [x] **Lazy Loading**: Carregamento sob demanda (via VirtualInterface e ILazy<T>).
  - *Status*: ✅ **Implementado e Validado**
  - *Implementação*: `TLazyInjector`, `TLazyInvokeHandler`, `TVirtualInterface`
  - *Suporte*: Referências (1:1/N:1) e Coleções (1:N)
  - *Tipos Especiais*: ✅ **TBytes (BLOB)**, ✅ **String (TEXT/CLOB)**
  - *Conversor*: `TVariantToBytesConverter`, `TStringToBytesConverter`
  - *Documentação*: [LAZY_LOADING_ADVANCED.md](LAZY_LOADING_ADVANCED.md)
  - *Testes*: ✅ **100% Validado** - Zero memory leaks
- [x] **Explicit Loading**: Carregamento manual de navegações (`Context.Entry(User).Collection('Orders').Load()`).

### 🔧 Manutenção & Débito Técnico
- [x] **API Cleanup**: Padronização de nomes de métodos (`Update` vs `Update`) usando overloads.
- [x] **Concurrency Fixes**: Correção de testes de concorrência otimista em cenários complexos.
- [x] **Fluent API Fixes**: Correção de `Any`, `FirstOrDefault` (Otimizados com LIMIT 1) e implementação de `Take`/`Skip` em `TSpecification`.
- [x] **Global Naming Strategy**: Estratégia global para convenção de nomes (SnakeCase, CamelCase) sem poluir entidades.
- [x] **External Mapping (Fluent Mapping)**: Configuração de mapeamento via código (Startup) para evitar Attributes nas entidades.
- [x] **ID Retrieval Fixes**: Correção crítica na recuperação de IDs em inserts (Single/Bulk) para garantir integridade referencial (FKs).
- [ ] **CLI Tools**: Comandos para gerar migrations e atualizar banco.
- [x] **Scaffolding**: Gerar classes de entidade a partir de banco existente (Db-First).

### 🚧 Fase 6: Migrations (Concluído)
Sistema completo de evolução de esquema Code-First.
- [x] **Schema Builder**: API fluente para definição de DDL (`CreateTable`, `AddColumn`).
- [x] **Model Diff**: Algoritmo para comparar Modelo Atual vs Snapshot Anterior.
- [x] **Migration Generator**: Gerar classes Pascal com os passos `Up`/`Down`.
- [x] **Migration Runner**: Aplicar migrações pendentes no banco e gerenciar tabela de histórico.
- [x] **JSON Migration Format**: Suporte a migrações em JSON (agnóstico a linguagem).
- [x] **External Runner**: `dext console` para rodar migrações em CI/CD (sem depender do executável da aplicação).
- [x] **Runtime Safety**: Validação de versão de esquema no startup ("Handshake").
- [x] **CLI Integration**: Comandos para criar e rodar migrações (`migrate add`, `migrate up`).

### 🚀 Fase 5: Performance & Observability (Novo)
Foco em otimização extrema, gerenciamento de memória e observabilidade.

#### 1. Benchmark & RTTI Optimization
- [ ] **Pre-Build RTTI Cache**: Scanner de classes que gera cache de metadados.
- [ ] **Converter Mapping Cache**: Mapeamento otimizado de converters para Load/Save.
- [ ] **FireDAC Phys API**: Reescrever driver usando `IFDPhysCommand`/`IFDPhysConnection`.
- [ ] **Managed Type System (TEntityType)** 🔥 **NOVO**: Arquitetura de metadados rica e centralizada.
  - Substituir lookups RTTI por `TEntityType<T>.Meta.Properties`.
  - Cachear converters de valor junto com a propriedade (`TPropertyMeta`).
  - Acessadores compilados (Fast Getters/Setters) para hidratação de alta performance.
  - Base para validação, mapeamento DTO e geração de Schema.

#### 2. Managed Container Types (Memory Safety)
- [x] **Smart Lists (`IList<T>`)**: Implementação de listas baseadas em interfaces.
- [x] **Expression Support**: Suporte a expressions diretamente nas listas.
- [x] **No Tracking Queries** 🔥: Queries sem tracking para APIs read-only.
  - *Status*: ✅ **Implementado e Validado**
  - *Documentação*: [NO_TRACKING.md](NO_TRACKING.md)

#### 3. Framework Garbage Collector
- [ ] **Background Disposal**: Serviço que coleta objetos marcados para destruição.
- [ ] **Deferred Destruction**: Remove o peso da destruição do thread principal.

#### 4. Telemetry & Observability
- [ ] **OpenTelemetry Support**: Tracing de queries e transações.
- [ ] **Database Agents**: Coletores de métricas específicos para bancos.
- [ ] **Web Integration**: Correlação de traces entre Web Framework e ORM.

---

## 🎯 Roadmap Estratégico (Q1-Q2 2025)

### **Sprint 1: Enterprise Essentials** 🔥 **PRIORITÁRIO** (5 semanas)

#### 0. **Class Inheritance Mapping** 🔥 **URGENTE** (1 semana)
Suportar hierarquias de classes no ORM com estratégias de mapeamento.

**Estratégia 1: Table-Per-Hierarchy (TPH)** - **Implementar Primeiro**
- Uma tabela para toda a hierarquia com coluna discriminadora
- Atributos: `[Inheritance(TablePerHierarchy)]`, `[Discriminator('user_type')]`, `[DiscriminatorValue('Admin')]`
- Queries polimórficas: `Context.Entities<TUser>` retorna `TAdmin`, `TCustomer`, `TGuest`
- Queries específicas: `Context.Entities<TAdmin>` adiciona filtro automático no discriminador
- **Pros**: Simples, rápido, sem JOINs
- **Cons**: Colunas nullable para campos de subclasses
- **Use Cases**: Hierarquias rasas (2-3 níveis), sistemas com poucos campos específicos

**Estratégia 2: Table-Per-Type (TPT)** - **Futuro**
- Tabela separada para cada classe (normalizado)
- Requer JOINs para queries
- **Pros**: Schema normalizado, sem nullables
- **Cons**: Performance (JOINs), complexidade

**Implementação TPH**:
- [ ] Adicionar atributos de herança (`InheritanceAttribute`, `DiscriminatorAttribute`, `DiscriminatorValueAttribute`)
- [ ] Atualizar `TEntityMapping` para armazenar informações de herança
- [ ] Modificar `ModelBuilder` para detectar hierarquias e adicionar coluna discriminadora
- [ ] Atualizar SQL Generator para incluir discriminador em INSERT/UPDATE
- [ ] Implementar filtro automático em queries (`WHERE user_type = 'Admin'`)
- [ ] Suportar queries polimórficas (retornar instâncias corretas baseado no discriminador)
- [ ] Criar testes abrangentes (inserção, atualização, queries polimórficas)

**Resultado**: Suporte completo a herança de classes (TPH), base para domain modeling rico

---

1. **Soft Delete** (1 semana)
   - [x] Global query filters + `[SoftDelete]` attribute
   - [x] Exclusão lógica transparente
2. **Multi-Tenancy** (2 semanas)
   - Query filters + Tenant discriminator
   - Isolamento de dados por tenants
   - **Estratégia 1: Single Database (Column)**: Todos no mesmo banco, separados por `TenantId`.
   - **Estratégia 2: Schema per Tenant**: Um banco físico, schemas isolados (`tenant1.Users`, `tenant2.Users`).
3. **Data Seeding** (3 dias)
   - `UseSeeding()` + fluent API
4. **Auditing** (1 semana)
   - `[CreatedBy]`, `[CreatedDate]`, `[ModifiedBy]`, `[ModifiedDate]`
   - Interceptors automáticos

**Resultado**: Features enterprise básicas completas

---

### **Sprint 2: Performance** (4 semanas)
1. **Batch Fetching** (2 semanas)
   - `findMultiple()` + auto-batching
   - Prevenção automática de N+1
2. **Second-Level Cache** (2 semanas)
   - Integração com Redis/Memcached
   - Cache distribuído
3. **Query Plan Caching** (1 semana)
   - Cache de planos de execução

**Resultado**: Performance competitiva com EF Core/Hibernate

---

### **Sprint 3: Advanced Queries** (3 semanas)
1. **SQL GroupBy Translation** (2 semanas)
   - Traduzir GroupBy para SQL
2. **SQL Join Translation** (2 semanas)
   - Traduzir Join para SQL
3. **JSON Column Support** (1 semana)
   - [x] Groundwork: Clean TGUID/Enum serialization in `Dext.Json`
   - [x] Foundation: `ITypeConverter` infrastructure
   - [ ] Mapeamento de colunas JSON
   - [ ] Query functions (JSON_EXTRACT, etc)

**Resultado**: Queries complexas otimizadas

---

### **Sprint 4: Raw SQL & Multi-Mapping (Dapper-Style)** 🔥 **NOVO** (4 semanas)
Inspirado no Dapper para cenários de alta performance onde o controle total do SQL é necessário.

1. **Raw SQL Query with Mapping** (2 semanas)
   - Executar qualquer SQL e mapear automaticamente para objetos
   - API: `Context.Query<TUser>("SELECT * FROM Users WHERE Age > @age", new { age = 18 })`
   - Suporte a parâmetros nomeados e posicionais
   - Mapeamento automático via convenção de nomes (coluna → propriedade)
   - **Use Cases**: Queries complexas, otimizações específicas de banco, stored procedures

2. **Multi-Mapping (Object Trees)** (2 semanas)
   - Mapear múltiplas tabelas em uma única query para árvore de objetos
   - API: `Context.Query<TUser, TAddress>("SELECT * FROM Users u JOIN Addresses a ON u.AddressId = a.Id", (user, address) => { user.Address := address; return user; })`
   - Suporte a splits automáticos ou manuais
   - Evitar N+1 queries com controle total do JOIN
   - **Use Cases**: Relatórios complexos, dashboards, APIs de leitura otimizadas

3. **Execute Raw SQL** (3 dias)
   - Executar comandos SQL sem retorno (INSERT, UPDATE, DELETE, DDL)
   - API: `Context.Execute("UPDATE Users SET IsActive = 1 WHERE Age > @age", new { age = 18 })`
   - Retorna número de linhas afetadas
   - **Use Cases**: Bulk updates, migrations, manutenção

4. **Stored Procedure Support** (1 semana)
   - Executar stored procedures com mapeamento de resultados
   - API: `Context.QueryProc<TUser>("sp_GetActiveUsers", new { minAge = 18 })`
   - Suporte a múltiplos result sets
   - Suporte a OUTPUT parameters
   - **Use Cases**: Integração com sistemas legados, lógica de negócio no banco

**Benefícios**:
- ✅ **Performance Máxima**: Zero overhead, controle total do SQL
- ✅ **Flexibilidade**: Não força padrões, você decide o SQL
- ✅ **Compatibilidade**: Integração com sistemas legados e stored procedures
- ✅ **Híbrido**: Combinar Fluent API (desenvolvimento rápido) com Raw SQL (otimização)

**Resultado**: ORM híbrido - simplicidade do Fluent API + poder do Dapper

---

### **Sprint 5: Async & AOT** (6 semanas)
1. **Infrastructure**: Connection Pooling & Thread-Safe Drivers.
2. **Async/Await Support** (4 semanas)
   - Integração com Fluent Tasks API
   - `FindAsync`, `SaveChangesAsync`, etc
3. **Pre-compiled Queries (POC)** (2 semanas)
   - Build-time code generation
   - Redução de startup time

**Resultado**: Ready for high-performance APIs

---

## 🔐 Segurança & Criptografia (Longo Prazo)

### **Field-Level Encryption**
- [ ] **Transparent Encryption**: Criptografia automática de campos sensíveis
  - `[Encrypted]` attribute para campos
  - Suporte a AES-256, RSA
  - Key management (Azure Key Vault, AWS KMS)
- [ ] **Searchable Encryption**: Busca em campos criptografados
  - Deterministic encryption para queries de igualdade
  - Order-preserving encryption para range queries
- [ ] **Column Masking**: Mascaramento de dados sensíveis
  - Dynamic data masking para logs/debug
  - PII (Personally Identifiable Information) protection

---

## 📄 Document Storage & NoSQL (Longo Prazo)

### **JSON Column Support** ⚠️ **Em Análise**
- [ ] **JSON Mapping**: Mapeamento de propriedades para colunas JSON
  - PostgreSQL `jsonb`, SQL Server `nvarchar(max)`, MySQL `json`
  - Query functions: `JSON_EXTRACT`, `JSON_VALUE`, etc
  - Indexing de campos JSON

### **Document Database Support** 🔮 **Futuro**
- [ ] **MongoDB Provider**
  - Driver nativo para MongoDB
  - Document mapping
  - Aggregation pipeline
- [ ] **Azure Cosmos DB Provider**
  - Support para Cosmos DB SQL API
  - Partition key management
  - Change feed integration
- [ ] **Hybrid Queries**: Queries que combinam relacional + document
  - Join entre SQL e NoSQL
  - Unified query API

**Nota**: JSON Columns em bancos relacionais é o primeiro passo para suporte a dados semi-estruturados, antes de implementar providers NoSQL completos.

---

## 🗄️ Roadmap de Suporte a Bancos de Dados

### Status Atual
- ✅ **SQLite**: Suporte completo e testado
- ✅ **PostgreSQL**: Suporte completo e validado (incluindo RETURNING clause, Nullable support)
- ✅ **Firebird**: Suporte completo e validado
- ✅ **SQL Server**: Suporte completo e validado (incluindo `OUTPUT INSERTED`, `IF NOT EXISTS`)

### Expansão Planejada

#### Prioridade 2 - Comunidade (Help Wanted)
5. **Oracle**
   - **Status**: ⏸️ **Aguardando Voluntários/Contribuição** (Dialeto implementado)

6. **MySQL/MariaDB**
   - **Status**: ⏸️ **Aguardando Voluntários/Contribuição** (Dialeto implementado)

#### Prioridade 3 - Legado
7. **Firebird 2.5**
   - **Status**: ❌ Não planejado no momento

---

## 📝 Notas de Design

- **Performance First**: Evitar Reflection excessivo em loops críticos (cache de RTTI já implementado).
- **Simplicidade**: API limpa e fácil de usar.
- **Extensibilidade**: Arquitetura baseada em Interfaces (`IDbSet`, `IDbContext`, `IDbCommand`).
- **Security by Design**: Criptografia e segurança como features de primeira classe (futuro).
- **Hybrid Data**: Suporte a relacional + document storage para flexibilidade máxima (futuro).

---

**Última Atualização**: Dezembro 2024  
**Versão**: Alpha 0.7+  
**Comparativo**: [ORM_COMPARISON_2024.md](ORM_COMPARISON_2024.md)


O núcleo do ORM está funcional, suportando operações CRUD, mapeamento básico, relacionamentos simples e controle de concorrência.

### ✅ Funcionalidades Implementadas

#### 1. Core & Mapeamento
- [x] **Entity Mapping**: Atributos `[Table]`, `[Column]`, `[PK]`, `[AutoInc]`, `[NotMapped]`.
- [x] **Identity Map**: Cache de primeiro nível para garantir instância única por Contexto.
- [x] **Database Drivers**: Abstração de driver (FireDAC implementado).
- [x] **Dialects**: Suporte multi-banco (SQLite, PostgreSQL, **SQL Server**).
- [x] **Schema Generation**: Geração automática de scripts `CREATE TABLE`.
- [x] **Naming Strategies**: Convenções de nomenclatura configuráveis (SnakeCase, CamelCase).
- [x] **Fluent Mapping**: Mapeamento externo via código (`TEntityMap<T>`) para isolamento do domínio.
- [x] **Nullable Support**: Suporte completo a `Nullable<T>` para campos opcionais e Foreign Keys.
  - *Tipos*: `Nullable<Integer>`, `Nullable<String>`, `Nullable<TGUID>`, etc.
  - *Compatibilidade*: Spring4D e Delphi nativo
  - *Funcionalidades*: Persist, Hydrate, Foreign Key loading
  - *Documentação*: [NULLABLE_SUPPORT.md](NULLABLE_SUPPORT.md)

#### 2. CRUD & Operações
- [x] **Basic CRUD**: `Add`, `Update`, `Remove`, `Find` (por ID).
- [x] **Composite Keys**: Suporte a chaves primárias compostas.
- [x] **Mixed Composite Keys**: Suporte a chaves compostas com tipos diferentes (Integer + String, etc).
  - *API*: `Find([10, 'ABC'])` usando `array of Variant`
  - *Exemplo*: Entidade com `Key1: Integer` e `Key2: String`
  - *Status*: ✅ **Implementado e Validado**
- [x] **Bulk Operations**: `AddRange`, `UpdateRange`, `RemoveRange` (Iterativo).
- [x] **Cascade Insert**: Inserção automática de entidades filhas novas.
- [x] **Optimistic Concurrency**: Controle de concorrência via atributo `[Version]` (Implementado e Validado).

#### 3. Relacionamentos
- [x] **Foreign Keys**: Mapeamento via `[ForeignKey]`.
- [x] **Cascade Delete**: Suporte via Constraint de banco de dados.
- [ ] **Polymorphic Associations**: Suporte a relacionamentos "Any" (ex: Comment belongs to Post OR Video).
  - *Strategy*: `SourceID` + `SourceType` discriminator columns.
  - *Use Case*: Sistema de Reputação do Dext Forum (Pontos vêm de Post ou Thread).


---

## 📅 Próximos Passos

### ✅ Fase 3: Advanced Querying (Concluído)
O objetivo foi permitir consultas complexas de forma tipada e fluente. Concluído com sucesso na versão Alpha 0.6.

- [x] **Fluent Query API**: Builder para consultas (`Where`, `OrderBy`, `Skip`, `Take`).
  - *Exemplo:* `Context.Entities<TUser>.List(UserEntity.Age >= 18)`
  - *Exemplo:* `Specification.Where<TUser>(UserEntity.Age >= 18).OrderBy(UserEntity.Name.Asc).Take(10)`
  - *Melhoria:* Overloads simplificados para `Where(IExpression)` e `Select(string)`.
- [x] **Metadados Tipados (TypeOf)**: Geração de metadados para evitar strings mágicas nas queries.
  - *Exemplo:* `UserEntity.Age >= 18`, `UserEntity.Name.StartsWith('John')`
- [x] **Specifications Pattern**: Integração completa com o padrão Specification.
  - Suporte a inline queries: `List(IExpression)`
  - Suporte a specifications reutilizáveis: `TAdultUsersSpec`
  - Fluent builder: `Specification.Where<T>(...).OrderBy(...).Take(...)`
- [x] **Operadores Fluentes**: 
  - Comparação: `=`, `<>`, `>`, `>=`, `<`, `<=`
  - String: `StartsWith`, `EndsWith`, `Contains`, `Like`, `NotLike`
  - Range: `Between(lower, upper)`
  - Null: `IsNull`, `IsNotNull`
  - Lógicos: `and`, `or`, `not`
- [x] **OrderBy Tipado**: `UserEntity.Name.Asc`, `UserEntity.Age.Desc`
- [x] **Include (Eager Loading)**: Carregamento antecipado de relacionamentos.
  - *Status*: ✅ **Implementado e Validado**
  - *Implementado*: `DoLoadIncludes`, API fluente `Specification.Include('Path')`, suporte a `IN` no SQL Generator
  - *Exemplo*: `Specification.All<TUser>.Include('Address')`

#### 🔄 Próximas Melhorias da Fluent API (Inspiradas em Spring4D/LINQ)

- [x] **Lazy Execution (Deferred Execution)**: Queries só executam quando iteradas
  - Implementado `TFluentQuery<T>` e iteradores customizados
  - Queries retornam `TFluentQuery<T>` que adia execução até `for..in` ou `.ToList()`
  - *Status*: ✅ **Implementado e Validado**

- [x] **Projeções (Select)**: Retornar apenas campos específicos
  - `Select<TResult>(selector: TFunc<T, TResult>): TFluentQuery<TResult>`
  - `Select<TResult>(PropertyName: string): TFluentQuery<TResult>` (Novo)
  - `Select(Properties: array of string): TFluentQuery<T>` (Novo - Partial Load)
  - *Exemplo*: `Context.Entities<TUser>.Select(['Name', 'City']).ToList()`
  - *Status*: ✅ **Implementado e Validado**
  - *Memory Safety*: Projeções usam automaticamente "No-Tracking" e "OwnsObjects=True" para prevenir leaks de entidades parciais.

- [x] **Agregações**: Funções de agregação tipadas
  - `Sum`, `Average`, `Min`, `Max` (Suporte a Property Name string e TFunc)
  - `Count()`, `Count(predicate)`, `Any()`, `Any(predicate)`
  - *Exemplo*: `var avgAge := Context.Entities<TUser>.Average('Age');`
  - *Status*: ✅ **Implementado e Validado**

- [x] **Distinct**: Remover duplicatas
  - `Distinct(): IEnumerable<T>`
  - *Exemplo*: `Context.Entities<TUser>.Select(u => u.City).Distinct()`
  - *Status*: ✅ **Implementado e Validado**

- [x] **Paginação Helper**: Resultado paginado com metadados
  - `Paginate(pageNumber, pageSize): IPagedResult<T>`
  - Retorna `TotalCount`, `PageCount`, `HasNextPage`, `HasPreviousPage`
  - *Exemplo*: `var page := Context.Entities<TUser>.Paginate(1, 20);`
  - *Status*: ✅ **Implementado e Validado**

- [x] **GroupBy**: Agrupamento com agregações
  - `GroupBy<TKey>(keySelector): IEnumerable<IGrouping<TKey, T>>`
  - *Exemplo*: `Context.Entities<TUser>.GroupBy(u => u.City)`
  - *Status*: ✅ **Implementado e Validado**

- [x] **Join Explícito**: Joins tipados
  - `Join<TInner, TKey, TResult>(inner, outerKey, innerKey, resultSelector)`
  - *Exemplo*: `users.Join(addresses, 'AddressId', 'Id', ...)` (Novo overload simplificado)
  - *Status*: ✅ **Implementado e Validado** (Em memória)

#### 🚀 Otimizações de Performance

- [x] **FirstOrDefault Otimizado**: Usa `LIMIT 1` no SQL
  - Ao invés de carregar todos os registros e pegar o primeiro
  - SQL gerado: `SELECT * FROM users WHERE age > 18 LIMIT 1`
  - *Status*: ✅ **Implementado e Validado**
  - *Benefício*: Performance significativa em queries grandes

- [x] **Any Otimizado**: Usa `SELECT 1 ... LIMIT 1` ao invés de `COUNT(*)`
  - Para na primeira ocorrência ao invés de contar todos os registros
  - SQL gerado: `SELECT 1 FROM users WHERE age > 18 LIMIT 1`
  - *Status*: ✅ **Implementado e Validado**
  - *Benefício*: Performance dramática em verificações de existência

- [x] **Select Otimizado (Projeções)**: Carrega apenas colunas necessárias
  - `Specification.Select(['Name', 'City'])`
  - SQL gerado: `SELECT Name, City FROM Users ...`
  - *Status*: ✅ **Implementado e Validado**
  - *Benefício*: Reduz tráfego de rede e uso de memória ao evitar `SELECT *`

### 📦 Fase 4: Loading Strategies & Memory Management
Melhorar como os dados relacionados são carregados e gerenciar ciclo de vida das entidades.

- [x] **Unit of Work Pattern**: Implementar rastreamento de mudanças e commit em lote.
  - Adicionar método `Clear()` no DbSet para limpar IdentityMap e destruir entidades gerenciadas
  - Implementar `SaveChanges()` no DbContext para persistir todas as mudanças de uma vez
  - Rastrear estado das entidades (Added, Modified, Deleted, Unchanged)
- [x] **Eager Loading (.Include)**: Carregamento antecipado completo e validado.
  - *Exemplo:* `Context.Entities<TUser>.Include('Address').Find(1);`
- [x] **Lazy Loading**: Carregamento sob demanda (via VirtualInterface e ILazy<T>).
  - *Status*: ✅ **Implementado e Validado**
  - *Implementação*: `TLazyInjector`, `TLazyInvokeHandler`, `TVirtualInterface`
  - *Suporte*: Referências (1:1/N:1) e Coleções (1:N)
- [x] **Explicit Loading**: Carregamento manual de navegações (`Context.Entry(User).Collection('Orders').Load()`).

### 🔧 Manutenção & Débito Técnico
- [x] **API Cleanup**: Padronização de nomes de métodos (`Update` vs `Update`) usando overloads.
- [x] **Concurrency Fixes**: Correção de testes de concorrência otimista em cenários complexos.
- [x] **Fluent API Fixes**: Correção de `Any`, `FirstOrDefault` (Otimizados com LIMIT 1) e implementação de `Take`/`Skip` em `TSpecification`.
- [x] **Global Naming Strategy**: Estratégia global para convenção de nomes (SnakeCase, CamelCase) sem poluir entidades.
- [x] **External Mapping (Fluent Mapping)**: Configuração de mapeamento via código (Startup) para evitar Attributes nas entidades.
- [x] **ID Retrieval Fixes**: Correção crítica na recuperação de IDs em inserts (Single/Bulk) para garantir integridade referencial (FKs).
- [ ] **CLI Tools**: Comandos para gerar migrations e atualizar banco.
- [x] **Scaffolding**: Gerar classes de entidade a partir de banco existente (Db-First).

### 🔑 Melhorias de Primary Keys & Composite Keys
Suporte robusto a diferentes tipos e combinações de chaves primárias.

- [x] **Composite Key Find**: Busca por chave composta implementada
  - Suporte a `Find([key1, key2])` e `Find(VarArrayOf([key1, key2]))`
  - Construção automática de expressões AND para múltiplas PKs
  - *Status*: ✅ **Implementado**
  
- [ ] **Dynamic PK Column Mapping** 🔥 **PRIORITÁRIO**
  - **Problema**: Código atual assume coluna PK fixa como "Id"
  - **Solução**: Usar mapeamento real da entidade (via Attributes ou Fluent Mapping)
  - **Impacto**: Métodos `Find(Variant)` e queries precisam usar PK real
  - **Exemplo**: `[PK] property OrderId` deve ser usado ao invés de assumir "Id"
  
- [ ] **Mixed Type Composite Keys** 🔥 **PRIORITÁRIO**
  - **Problema**: Implementação atual assume `array of Integer`
  - **Necessidade**: Suportar combinações variadas de tipos em PKs compostas
  - **Casos Comuns**:
    - `Integer + DateTime` (ex: OrderId + OrderDate)
    - `Integer + String` (ex: CompanyId + DocumentNumber)
    - `String + String` (ex: CountryCode + StateCode)
    - `GUID + Integer` (ex: TenantId + RecordId)
  - **Solução Proposta**:
    - Criar overload `Find(const AId: array of Variant)`
    - Usar RTTI para determinar tipo real de cada campo PK
    - Converter valores de acordo com tipo esperado
  - **Benefício**: Suporte a sistemas legados com PKs criativas

### 🚧 Fase 6: Migrations (Em Progresso)
Sistema completo de evolução de esquema Code-First.
- [x] **Schema Builder**: API fluente para definição de DDL (`CreateTable`, `AddColumn`).
- [x] **Model Diff**: Algoritmo para comparar Modelo Atual vs Snapshot Anterior.
- [x] **Migration Generator**: Gerar classes Pascal com os passos `Up`/`Down`.
- [x] **Migration Runner**: Aplicar migrações pendentes no banco e gerenciar tabela de histórico.
- [x] **JSON Migration Format**: Suporte a migrações em JSON (agnóstico a linguagem).
- [x] **External Runner**: `dext console` para rodar migrações em CI/CD (sem depender do executável da aplicação).
- [x] **Runtime Safety**: Validação de versão de esquema no startup ("Handshake").
- [x] **CLI Integration**: Comandos para criar e rodar migrações (`migrate add`, `migrate up`).

### 🚀 Fase 5: Performance & Observability (Novo)
Foco em otimização extrema, gerenciamento de memória e observabilidade.

#### 1. Benchmark & RTTI Optimization
Otimização do startup e overhead de runtime.
- [ ] **Pre-Build RTTI Cache**: Scanner de classes que gera cache de metadados.
  - Evitar processamento de RTTI em runtime para cada startup.
  - Carregar mapeamento e converters de um cache binário ou código gerado.
- [ ] **Converter Mapping Cache**: Mapeamento otimizado de converters para Load/Save.
- [ ] **FireDAC Phys API**: Reescrever driver usando `IFDPhysCommand`/`IFDPhysConnection` para performance máxima.

#### 2. Managed Container Types (Memory Safety)
Resolução definitiva para memory leaks e gerenciamento de ciclo de vida.
- [x] **Smart Lists (`IList<T>`)**: Implementação de listas baseadas em interfaces.
  - Gerenciamento automático de memória (ref-counted ou scope-based).
  - Substituição de `TObjectList<T>` crua nas APIs públicas (`Entities`, `Query.List`).
- [x] **Expression Support**: Suporte a expressions diretamente nas listas (`List.Where(x => x.Age > 18)`).
- [x] **No Tracking Queries** 🔥 **PRIORITÁRIO**: Queries sem tracking para APIs read-only.
  - **API**: `Context.Entities<TUser>.AsNoTracking.List` 
  - **Ownership**: Listas com `OwnsObjects=True` (objetos não vão para IdentityMap)
  - **Performance**: Sem overhead de ChangeTracker e IdentityMap
  - **Use Cases**: APIs REST, relatórios, bulk reads
  - **Memory**: Objetos liberados quando lista sai de escopo
  - **Detach Alternative**: Substituir uso de `Detach()` por queries no-tracking
  - *Status*: ✅ **Implementado e Validado**

#### 3. Framework Garbage Collector
Sistema de limpeza de objetos em background para alta performance em servidores HTTP.
- [ ] **Background Disposal**: Serviço que coleta objetos marcados para destruição.
- [ ] **Deferred Destruction**: Remove o peso da destruição do thread principal de requisição.

#### 4. Telemetry & Observability
Suporte nativo a instrumentação para monitoramento em produção.
- [ ] **OpenTelemetry Support**: Implementação do padrão OpenTelemetry.
  - Tracing de queries e transações.
  - Métricas de performance (tempo de query, pool connections).
- [ ] **Database Agents**: Coletores de métricas específicos para bancos.
- [ ] **Web Integration**: Correlação de traces entre Web Framework e ORM.

#### 5. Enterprise & Advanced Data Features
Funcionalidades essenciais para sistemas corporativos complexos.
- [ ] **Multi-Tenancy**: Suporte nativo a isolamento de dados por Tenant (Coluna discriminadora ou Schema por Tenant).
- [ ] **Spatial Data (GIS)**: Tipos de dados geográficos (`Point`, `Polygon`) com suporte a queries espaciais (PostGIS, SQL Server Spatial).
- [ ] **Auditing & History**:
  - **Temporal Tables**: Suporte a tabelas temporais do sistema (SQL Server/MariaDB).
  - **Audit Log**: Sistema de log de alterações automático (Quem mudou, Quando, Valor Antigo/Novo).
- [x] **Soft Delete**: Suporte nativo a exclusão lógica (`IsDeleted`) transparente nas queries.

#### 5. Async Support (Fluent Tasks API)
Integração transparente de operações assíncronas.
- [x] **Fluent Tasks API**: API fluente para orquestração de tasks.
- [ ] **Async ORM Methods**: `FindAsync`, `ToListByIdsAsync` (Depende de Connection Pooling).
- [ ] **Web & ORM Integration**: Suporte nativo em Controllers e DbContext.

### 🛠️ Fase 6: Tooling & Ecosystem
Ferramentas para aumentar a produtividade e extensibilidade.

- [ ] **Scaffolding com Templates**: Sistema flexível de geração de código.
  - Suporte a templates (ex: Mustache) para customizar a saída do scaffolding.
  - Metadados em JSON intermediários para permitir ferramentas externas (Transformer).
  - Permitir que a comunidade crie seus próprios templates de entidade/DTOs.

---

## 🗄️ Roadmap de Suporte a Bancos de Dados

### Status Atual
- ✅ **SQLite**: Suporte completo e testado
- ✅ **PostgreSQL**: Suporte completo e validado (incluindo RETURNING clause, Nullable support)
- ✅ **Firebird**: Suporte completo e validado
- ✅ **SQL Server**: Suporte completo e validado (incluindo `OUTPUT INSERTED`, `IF NOT EXISTS`)

### Expansão Planejada

#### Prioridade 2 - Comunidade (Help Wanted)
5. **Oracle**
   - **Status**: ⏸️ **Aguardando Voluntários/Contribuição** (Dialeto implementado)

6. **MySQL/MariaDB**
   - **Status**: ⏸️ **Aguardando Voluntários/Contribuição** (Dialeto implementado)

#### Prioridade 3 - Legado
7. **Firebird 2.5**
   - **Status**: ❌ Não planejado no momento

---

## 📝 Notas de Design

- **Performance First**: Evitar Reflection excessivo em loops críticos (cache de RTTI já implementado).
- **Simplicidade**: API limpa e fácil de usar.
- **Extensibilidade**: Arquitetura baseada em Interfaces (`IDbSet`, `IDbContext`, `IDbCommand`).
