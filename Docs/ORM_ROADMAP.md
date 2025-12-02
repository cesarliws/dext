# 🗺️ Dext Entity ORM - Roadmap

Este documento rastreia o desenvolvimento do **Dext Entity**, o ORM nativo do framework Dext.

> **Visão:** Um ORM moderno, leve e performático para Delphi, inspirado no Entity Framework Core e Hibernate, mas com a simplicidade do Delphi.

---

## 📊 Status Atual: **Alpha 0.6** 🚀

O núcleo do ORM está funcional, suportando operações CRUD, mapeamento básico, relacionamentos simples e controle de concorrência.

### ✅ Funcionalidades Implementadas

#### 1. Core & Mapeamento
- [x] **Entity Mapping**: Atributos `[Table]`, `[Column]`, `[PK]`, `[AutoInc]`, `[NotMapped]`.
- [x] **Identity Map**: Cache de primeiro nível para garantir instância única por Contexto.
- [x] **Database Drivers**: Abstração de driver (FireDAC implementado).
- [x] **Dialects**: Suporte multi-banco (SQLite, PostgreSQL).
- [x] **Schema Generation**: Geração automática de scripts `CREATE TABLE`.

#### 2. CRUD & Operações
- [x] **Basic CRUD**: `Add`, `Update`, `Remove`, `Find` (por ID).
- [x] **Composite Keys**: Suporte a chaves primárias compostas.
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
- [ ] **API Cleanup**: Padronização de nomes de métodos (`Update` vs `Update`) usando overloads.
- [ ] **Concurrency Fixes**: Correção de testes de concorrência otimista em cenários complexos.
- [ ] **Fluent API Fixes**: Correção de `Any`, `FirstOrDefault` e projeções em casos de borda.

### ⚡ Fase 5: Performance & Tuning
- [ ] **True Bulk SQL**: Otimizar `AddRange` para usar `INSERT INTO ... VALUES (...), (...)`.
- [ ] **Batch Updates**: `UPDATE ... WHERE ...` em massa sem carregar entidades.
- [ ] **Query Caching**: Cache de planos de execução ou resultados.
- [ ] **No-Tracking Queries**: Consultas rápidas sem overhead do Identity Map.

### 🛠️ Fase 6: Tooling & Migrations
- [ ] **Migrations**: Sistema de migração de schema Code-First.
- [ ] **CLI Tools**: Comandos para gerar migrations e atualizar banco.
- [ ] **Scaffolding**: Gerar classes de entidade a partir de banco existente (Db-First).

---

## 🗄️ Roadmap de Suporte a Bancos de Dados

### Status Atual
- ✅ **SQLite**: Suporte completo e testado
- ⚠️ **PostgreSQL**: Dialeto implementado, mas não validado completamente

### Expansão Planejada (Baseada em Pesquisa de Mercado Delphi)

#### Prioridade 1 - Crítica (Mercado BR + Prototipagem)
    - **Status**: ❌ Não implementado (Movido para Prioridade 2)

2. **PostgreSQL** (Promovido a Prioridade 1)
   - **Segmento**: Microserviços, Cloud, Docker, Uso Diário
   - **Driver**: FireDAC (TFDPhysPGDriverLink)
   - **Desafios**: JSONB, Case Sensitivity, Batch
   - **Status**: ⚠️ **Dialeto criado, precisa validação completa**

3. **SQLite** ✅
   - **Segmento**: Mobile, Testes, Prototipagem
   - **Driver**: FireDAC (TFDPhysSQLiteDriverLink)
   - **Desafios**: Concorrência (Locking), Tipos
   - **Status**: ✅ **Implementado e Validado**

#### Prioridade 2 - Alta (Legado + Cloud)
3. **Firebird 2.5**
   - **Segmento**: Legado, Migração
   - **Driver**: FireDAC (TFDPhysFBDriverLink)
   - **Desafios**: Paginação (FirstSkip), Boolean
   - **Status**: ❌ Não implementado (pode reutilizar dialeto FB 3.0/4.0)

4. **Firebird 3.0/4.0**
   - **Segmento**: ERPs Modernos, Mercado BR
   - **Driver**: FireDAC (TFDPhysFBDriverLink)
   - **Desafios**: Dialeto SQL, Transações, Generators
   - **Status**: ❌ Não implementado

#### Prioridade 3 - Média (Corporativo)
5. **SQL Server**
   - **Segmento**: Corporativo, Integração .NET
   - **Driver**: FireDAC (TFDPhysMSSQLDriverLink)
   - **Desafios**: Schemas, Tipos DateTime
   - **Status**: ❌ Não implementado

6. **MySQL/MariaDB**
   - **Segmento**: Web Hosting, Linux Barato
   - **Driver**: FireDAC (TFDPhysMySQLDriverLink)
   - **Desafios**: Transações Aninhadas, Engines
   - **Status**: ❌ Não implementado

#### Prioridade 4 - Baixa (Legado Oracle)
7. **Oracle**
   - **Segmento**: Grandes Corporações
   - **Driver**: FireDAC (TFDPhysOracleDriverLink)
   - **Desafios**: Sequences, Tipos
   - **Status**: ❌ Não implementado

---

## 📝 Notas de Design

- **Performance First**: Evitar Reflection excessivo em loops críticos (cache de RTTI já implementado).
- **Simplicidade**: API limpa e fácil de usar.
- **Extensibilidade**: Arquitetura baseada em Interfaces (`IDbSet`, `IDbContext`, `IDbCommand`).
