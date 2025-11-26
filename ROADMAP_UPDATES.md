# ROADMAP - Alterações para Action Filters

## Alterações na Tabela de Comparação

Adicione estas 2 linhas na tabela (após "Injeção de Dependência"):

```markdown
| **Scoped Services** | ✅ **Por Requisição** (DbContext, UoW) | ❌ | ❌ | ✅ |
```

E adicione esta linha (após "Controllers"):

```markdown
| **Action Filters** | ✅ **Declarativo** (OnExecuting/Executed) | ❌ | ✅ | ✅ |
```

## Resultado Final da Tabela

```markdown
| Funcionalidade | ⚡ Dext | 🐴 Horse | 📦 DMVC | 🔷 ASP.NET Core |
| :--- | :---: | :---: | :---: | :---: |
| **Arquitetura** | Modular (Microsoft.Extensions.* style) | Middleware-based (Express.js style) | MVC Clássico | Modular |
| **Injeção de Dependência** | ✅ **Nativa & First-Class** (Scoped, Transient, Singleton) | ❌ (Requer lib externa) | ⚠️ (Limitada/Externa) | ✅ Nativa |
| **Scoped Services** | ✅ **Por Requisição** (DbContext, UoW) | ❌ | ❌ | ✅ |
| **Minimal APIs** | ✅ `App.MapGet('/route', ...)` | ✅ | ❌ | ✅ |
| **Controllers** | ✅ Suporte completo (Attributes) | ❌ | ✅ | ✅ |
| **Action Filters** | ✅ **Declarativo** (OnExecuting/Executed) | ❌ | ✅ | ✅ |
| **Model Binding** | ✅ **Avançado** (Body, Query, Route, Header, Services) | ⚠️ Básico | ✅ | ✅ |
| **Validation** | ✅ **Automática** (Attributes + Minimal APIs) | ❌ | ✅ | ✅ |
| **Middleware Pipeline** | ✅ Robusto (`UseMiddleware<T>`) | ✅ Simples | ✅ | ✅ |
| **Autenticação/AuthZ** | ✅ **Nativa** (Identity, JWT, Policies) | ⚠️ (Middleware externo) | ✅ | ✅ |
| **OpenAPI / Swagger** | ✅ **Nativo** (Geração automática + Global Responses) | ✅ (Swagger-UI) | ✅ | ✅ |
| **Caching** | ✅ **Nativo** (In-Memory, Response Cache) | ❌ | ❌ | ✅ |
| **Rate Limiting** | ✅ **Avançado** (4 algoritmos, Partition Strategies) | ⚠️ (Middleware externo) | ✅ | ✅ |
| **Async/Await** | ❌ (Limitação da linguagem*) | ❌ | ❌ | ✅ |
```

## Adicionar na Seção "Funcionalidades Avançadas"

Após a linha de Swagger/OpenAPI, adicione:

```markdown
- [x] **Action Filters**: Sistema declarativo de filtros:
  - [x] OnActionExecuting / OnActionExecuted
  - [x] Short-circuit support
  - [x] Exception handling
  - [x] Filtros built-in (LogAction, RequireHeader, ResponseCache, AddHeader)
  - [x] Controller-level e Method-level filters
```

## Adicionar na Seção "Documentação & Qualidade"

Após "Rate Limiting Docs", adicione:

```markdown
- [x] **Action Filters Docs**: Documentação completa do sistema de Action Filters.
- [x] **Scoped Services Docs**: Documentação do Scoped Lifetime.
```

---

## Outras Features para a Tabela de Comparação

Sim! Temos mais features que merecem destaque:

### Features que já temos e podem ser adicionadas:

1. **Static Files** - ✅ Dext tem, Horse não tem nativo
2. **Problem Details (RFC 7807)** - ✅ Dext tem exception handling padronizado
3. **Fluent Configuration** - ✅ Dext tem API fluente para tudo
4. **JSON Serialization** - ✅ Dext tem `Dext.Json` nativo
5. **HTTP Logging** - ✅ Dext tem middleware de logging estruturado

### Sugestão de Linhas Adicionais:

```markdown
| **Static Files** | ✅ Middleware nativo | ❌ | ⚠️ (Manual) | ✅ |
| **Problem Details** | ✅ RFC 7807 | ❌ | ⚠️ | ✅ |
| **HTTP Logging** | ✅ Estruturado | ❌ | ⚠️ | ✅ |
```

Quer que eu crie uma versão completa da tabela com todas essas features?
