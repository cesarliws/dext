# 🛠️ Dext IDE Integration - Roadmap

Este roadmap foca na experiência do desenvolvedor (DX) dentro da IDE do Delphi, trazendo ferramentas modernas de produtividade inspiradas no Visual Studio, Rider e IntelliJ.

> **Visão:** Transformar a IDE do Delphi em um ambiente moderno e produtivo para desenvolvimento Web e Cloud, preenchendo as lacunas da IDE nativa com ferramentas inteligentes baseadas em AST.

---

## 🧠 Code Intelligence (AST-Based)

Uso do **DelphiAST** para análise estática profunda e funcionalidades de "Smart Code".

### 1. Dext Code Inspector
Um "Object Inspector" para código-fonte.
- [ ] **Smart Navigation**: Indexação de todos os fontes e uses do projeto. Pesquisa rápida por símbolos (classes, métodos) com `Ctrl+T` (estilo ReSharper).
- [ ] **Context-Aware Completion**: Code completion avançado que entende o contexto do Dext (ex: sugerir apenas métodos válidos em uma Fluent API).
- [ ] **Documentation Insight**: Visualização rica de XML Documentation ao passar o mouse ou completar código.

### 2. Static Analysis & Validation
- [ ] **Expression Validator**: Validação em tempo de design de expressões lambda ou strings mágicas usadas no ORM.
- [ ] **Best Practices Analyzer**: Linter específico para o Dext (ex: avisar se esquecer de registrar um serviço na DI).

### 3. SQL Inspector (Language Injection)
- [ ] **Embedded SQL Support**: Reconhecimento de strings SQL dentro do código Pascal.
- [ ] **Smart Completion**: Autocomplete de tabelas e colunas do banco configurado no projeto, direto na string SQL.
- [ ] **Syntax Highlighting**: Colorização de sintaxe SQL dentro das strings.

### 4. Integrated Test Ecosystem (The "Rider" Experience)
Arquitetura de execução de testes fora do processo da IDE para estabilidade máxima.

- [ ] **Test Runner Service**: Executável "Worker" que carrega a DLL de testes do projeto.
  - Comunicação via HTTP/Sockets com o plugin da IDE.
  - Execução isolada (Crash no teste não fecha o Delphi).
- [ ] **Inline Testing (Gutter Icons)**:
  - Uso do **DelphiAST** para identificar métodos de teste no código fonte aberto.
  - Botões "Run/Debug" desenhados diretamente na margem do editor.
  - Feedback visual (Verde/Vermelho) pintado no editor após execução.
- [ ] **Smart Code Coverage**:
  - Instrumentação de código fonte em memória usando **DelphiAST** (Source Instrumentation).
  - Mapa de calor visual (Highlighting) nas linhas executadas diretamente na IDE.
  - Relatórios precisos mesmo com Generics e Lambdas.

---

## ⚡ Productivity Tools

### 1. Scaffolding & Generators
- [ ] **Controller Generator**: Wizard para criar Controllers a partir de Entidades ou Serviços.
- [ ] **Minimal API Endpoint Wizard**: UI para adicionar rapidamente rotas `MapGet`/`MapPost`.
- [ ] **DTO/Mapping Generator**: Gerar classes de DTO e configurações de mapeamento automaticamente.

### 2. Integrated Test Runner
- [ ] **Inline Testing**: Executar testes unitários (DUnitX) diretamente do editor de código (ícone "Play" ao lado do método de teste), similar ao Visual Studio/Rider.
- [ ] **Live Results**: Visualização de Pass/Fail inline no código.

### 3. Integrated Console
- [ ] **Dext Terminal**: Terminal integrado à IDE com contexto do projeto carregado.
- [ ] **CLI Integration**: Atalhos para comandos do Dext CLI (`dext migrate`, `dext run`).
- [ ] Suport to font ligatures, font icons, syntax highlighting and auto-completion, search, copy, paste, export as... etc.

### 4. Markdown & Diagrams
- [ ] **Markdown Viewer**: Visualizador de MD com suporte a **Mermaid.js** para renderizar diagramas de arquitetura direto na IDE.
- [ ] **Markdown Editor**: Editor com syntax highlighting e preview em tempo real.

### 5. DevOps Integration
- [ ] **CI/CD Generator**: Wizard para gerar pipelines de CI/CD (GitHub Actions, GitLab CI, Azure Pipelines).
  - Templates para Build, Teste e Deploy (Docker/Cloud).
- [ ] **Docker Compose Designer**: Editor visual para orquestrar serviços no `docker-compose.yml`.

---

## 📦 Ecosystem & Management

### 1. Template Repository
- [ ] **Project Gallery**: Interface para navegar e baixar templates de projetos (Clean Architecture, Vertical Slice, Microservice).
- [ ] **Snippet Manager**: Repositório de snippets de código comuns do Dext.

### 2. Dependency Manager (Sugestão)
- [ ] **Module Manager**: UI para visualizar e gerenciar módulos/dependências do Dext no projeto (similar ao NuGet Package Manager).

---

## 🚀 Web Development Experience (Sugestões)

### 1. HTTP Client (.http files)
- [ ] **Rest Client**: Suporte a arquivos `.http` (padrão IntelliJ/VS) para testar APIs diretamente da IDE, sem sair para o Postman.
  ```http
  GET http://localhost:8080/api/users
  Authorization: Bearer {{token}}
  ```

### 2. Hot Reload / Live Preview
- [ ] **View Preview**: Visualização em tempo real de Views (HTML/Razor-like) enquanto edita.
- [ ] **Hot Reload Trigger**: Botão para recarregar a aplicação ou injetar alterações sem restart completo (onde possível).

### 3. Web Visual Tools
- [ ] **Asset Intelligence**: Autocomplete e preview visual para recursos web.
  - **Colors**: Color picker ao digitar códigos hex/rgb.
  - **Icons**: Preview de ícones (FontAwesome/Material) no code completion.
  - **Images**: Preview de imagens referenciadas no código.
- [ ] **Template Designer**: Editor visual (ou split-view) para templates HTML/Razor com suporte a drag-and-drop de componentes Dext.
