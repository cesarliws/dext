# 🗺️ Project Dext - Roadmap & Status

Bem-vindo ao documento oficial de roadmap do **Project Dext**. Este documento serve como ponto central para acompanhar o progresso do desenvolvimento, entender a visão do projeto e comparar funcionalidades com outros frameworks.

> **Visão:** Criar o "ASP.NET Core para Delphi" — um framework web moderno, modular, de alto desempenho e com uma experiência de desenvolvimento (DX) superior.

---

## 📊 Status Atual do Projeto: **Beta 0.9** 🚀

O framework já possui a maioria das funcionalidades do núcleo (Core) implementadas e estáveis. Estamos na fase de polimento, documentação e expansão do ecossistema (testes, exemplos, templates).

### 🏆 Comparativo de Funcionalidades

Abaixo, comparamos o Dext com as principais alternativas do mercado Delphi e sua inspiração direta (.NET).

| Funcionalidade | ⚡ Dext | 🐴 Horse | 📦 DMVC | 🔷 ASP.NET Core |
| :--- | :---: | :---: | :---: | :---: |
| **Arquitetura** | Modular (Microsoft.Extensions.* style) | Middleware-based (Express.js style) | MVC Clássico | Modular |
| **Injeção de Dependência** | ✅ **Nativa & First-Class** (Scoped, Transient, Singleton) | ❌ (Requer lib externa) | ⚠️ (Limitada/Externa) | ✅ Nativa |
| **Minimal APIs** | ✅ `App.MapGet('/route', ...)` | ✅ | ❌ | ✅ |
| **Controllers** | ✅ Suporte completo (Attributes) | ❌ | ✅ | ✅ |
| **Model Binding** | ✅ **Avançado** (Body, Query, Route, Header, Services) | ⚠️ Básico | ✅ | ✅ |
| **Middleware Pipeline** | ✅ Robusto (`UseMiddleware<T>`) | ✅ Simples | ✅ | ✅ |
| **Autenticação/AuthZ** | ✅ **Nativa** (Identity, JWT, Policies) | ⚠️ (Middleware externo) | ✅ | ✅ |
| **OpenAPI / Swagger** | 🚧 **Nativo** (Geração automática) | ✅ (Swagger-UI) | ✅ | ✅ |
| **Caching** | ✅ **Nativo** (In-Memory, Redis) | ❌ | ❌ | ✅ |
| **Rate Limiting** | ✅ **Nativo** | ⚠️ (Middleware externo) | ✅ | ✅ |
| **Async/Await** | ❌ (Limitação da linguagem*) | ❌ | ❌ | ✅ |

*\* O Dext utiliza Tasks e Futures para operações assíncronas onde possível.*

---

## 📅 Roadmap Detalhado para v1.0

### 1. Core & Arquitetura (✅ Concluído)
- [x] **IHost / IWebApplication**: Abstração do ciclo de vida da aplicação.
- [x] **Dependency Injection**: Container IOC completo (Singleton, Scoped, Transient).
- [x] **Configuration**: Sistema de configuração (JSON, Environment Variables).
- [x] **Logging**: Abstração `ILogger` com múltiplos sinks (Console, File).

### 2. HTTP & Routing (✅ Concluído)
- [x] **HttpContext**: Abstração robusta de Request/Response.
- [x] **Routing**: Árvore de rotas eficiente, parâmetros de rota, constraints.
- [x] **Minimal APIs**: Métodos de extensão `MapGet`, `MapPost`, etc.
- [x] **Model Binding**: Binding inteligente de parâmetros (JSON -> Record/Class).
- [x] **Content Negotiation**: Suporte a JSON nativo (`Dext.Json`).

### 3. Middleware & Pipeline (✅ Concluído)
- [x] **Middleware Factory**: Criação e injeção de middlewares tipados.
- [x] **Exception Handling**: Middleware global de tratamento de erros (RFC 7807 Problem Details).
- [x] **CORS**: Configuração flexível de Cross-Origin Resource Sharing.
- [x] **Static Files**: Servir arquivos estáticos.

### 4. Funcionalidades Avançadas (🚧 Em Polimento)
- [x] **Controllers**: Suporte a Controllers baseados em classes com Atributos (`[HttpGet]`, `[Route]`).
- [x] **Authentication**: Sistema base (`IIdentity`, `IPrincipal`) e JWT Bearer.
- [x] **Caching**: Abstração `IDistributedCache` com implementações Memory e Redis.
- [x] **Rate Limiting**: Middleware de limitação de requisições.
- [ ] **Validation**: Integração de validação de modelos (FluentValidation style).

### 5. Ecossistema & Tooling (📅 Planejado)
- [ ] **CLI**: Ferramenta de linha de comando (`dext new webapi`).
- [ ] **Templates**: Templates de projeto para Delphi (IDE Wizards).
- [ ] **Web Stencils**: Integração com engine de renderização server-side.
- [ ] **Docker**: Imagens oficiais e exemplos de deploy.

### 6. Documentação & Qualidade (🚧 Em Andamento)
- [ ] **Unit Tests**: Cobertura abrangente (Core, DI, Http).
- [ ] **Documentation**: Site de documentação oficial (VitePress/Docusaurus).
- [ ] **Samples**: Repositório de exemplos "Real World".

---

## 🤝 Como Contribuir

O projeto é Open Source e aceita contribuições!
1.  Faça um Fork do repositório.
2.  Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`).
3.  Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`).
4.  Push para a branch (`git push origin feature/AmazingFeature`).
5.  Abra um Pull Request.

---

*Última atualização: 25 de Novembro de 2025*
