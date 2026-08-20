# 🌐 Dext Web Framework - Roadmap

Este documento foca nas funcionalidades de alto nível do framework web (API, MVC, Views), construído sobre a infraestrutura do Dext.

> **Visão:** Um framework web completo, produtivo e moderno, comparável ao ASP.NET Core e Spring Boot.

---

## 📊 Status Atual: **Release Candidate 1.0** 🚀

O Web Framework consolidou seu pipeline de roteamento, middleware e hubs em tempo real, atingindo maturidade para produção.

*Última atualização: 07 de Abril de 2026*

---

## 🚀 Funcionalidades Core (Web)

### 1. HTTP Abstractions & Performance
- [x] **Lazy Headers**: Acesso a headers sem alocações desnecessárias.
- [x] **Items Bag**: Dicionário compartilhado no contexto da requisição.
- [x] **Response Compression**: Suporte nativo a GZip.
- [x] **Stream Writing**: Suporte a envio eficiente de arquivos e streams grandes.

### 2. Web API Improvements
- [x] **Dext.Json Persistence**: Serialização e Deserialização robusta de objetos complexos e listas.
- [x] **Content Negotiation**: Suporte a múltiplos formatos (JSON, XML).
- [x] **API Versioning**: Versionamento via URL, Query String ou Headers.
- [x] **Multipart Support**: Upload de arquivos via `IFormFile`.

### 3. Database as API (DataAPI)
- [x] **TDataApiHandler<T>**: Zero-code REST endpoints para entidades ORM.
- [x] **Full CRUD**: GET, POST, PUT, DELETE automáticos.
- [x] **Querying**: Filtros, paginação e segurança integrados.

### 4. MVC & Views Engine
- [x] **Web Stencils**: Engine de templates inspirada em Razor.
- [x] **Layouts & Partials**: Reuso de componentes visuais no servidor.
- [x] **HTMX Integration**: Suporte nativo para SSR dinâmico com HTMX.

### 5. Real-Time (Dext Web Hubs)
- [x] **Bidirectional Communication**: RPC Cliente-Servidor funcional.
- [x] **Group Management**: Organização de conexões em salas/grupos.
- [x] **JavaScript Client**: Biblioteca cliente moderna `dext-hubs.js`.

---

## 🎯 Próximos Passos (v1.1+)

1. **OData Support**: Suporte completo a queries OData no ORM e Web API.
2. **GraphQL**: Camada nativa para exposição de grafos de dados.
3. **OpenTelemetry**: Monitoramento e rastreamento distribuído nativo.

---
*Dext Web - Building the modern web with Delphi.*
