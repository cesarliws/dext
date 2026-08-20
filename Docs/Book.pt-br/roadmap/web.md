# 🌐 Web Framework Dext - Roadmap

Este documento foca nas funcionalidades de alto nível do framework web (API, MVC, Views), construído sobre a infraestrutura do Dext.

> **Visão:** Um framework web completo, produtivo e moderno, comparável ao ASP.NET Core e Spring Boot.

---

## 📊 Status Atual: **Release Candidate 1.0** 🚀

O Web Framework consolidou seu pipeline de roteamento, middleware e hubs em tempo real, atingindo maturidade para produção.

*Última atualização: 07 de Abril de 2026*

---

## 🚀 Funcionalidades Core (Web)

### 1. Abstrações HTTP & Performance
- [x] **Lazy Headers**: Acesso a cabeçalhos sem alocações desnecessárias.
- [x] **Items Bag**: Dicionário compartilhado no contexto da requisição (HttpContext).
- [x] **Compressão de Resposta**: Suporte nativo a GZip.
- [x] **Escrita em Stream**: Suporte a envio eficiente de arquivos e streams de dados grandes.

### 2. Melhorias em Web API
- [x] **Dext.Json Persistence**: Serialização e Deserialização robusta de objetos complexos e listas.
- [x] **Negociação de Conteúdo**: Suporte a múltiplos formatos (JSON, XML).
- [x] **Versionamento de API**: Versionamento nativo via URL, Query String ou Headers.
- [x] **Suporte a Multipart**: Upload de arquivos via `IFormFile`.

### 3. Database as API (DataAPI)
- [x] **TDataApiHandler<T>**: Endpoints REST zero-code para entidades ORM.
- [x] **CRUD Completo**: Endpoints automáticos para GET, POST, PUT e DELETE.
- [x] **Consultas Dinâmicas**: Filtros, paginação e segurança integrados.

### 4. MVC & Engine de Views
- [x] **Web Stencils**: Engine de templates inspirada em Razor do .NET.
- [x] **Layouts & Partials**: Reuso de componentes visuais renderizados no servidor.
- [x] **Integração HTMX**: Suporte nativo para SSR dinâmico utilizando HTMX.

### 5. Tempo Real (Dext Web Hubs)
- [x] **Comunicação Bidirecional**: RPC Cliente-Servidor funcional.
- [x] **Gerenciamento de Grupos**: Organização de conexões em salas ou grupos.
- [x] **Cliente JavaScript**: Biblioteca cliente moderna `dext-hubs.js`.

---

## 🎯 Próximos Passos (v1.1+)

1. **Suporte a OData**: Suporte completo ao protocolo OData no ORM e Web API.
2. **GraphQL**: Camada nativa para exposição de grafos de dados.
3. **OpenTelemetry**: Monitoramento e rastreamento distribuído nativo integrado.

---
*Dext Web - Construindo a web moderna com Delphi.*

