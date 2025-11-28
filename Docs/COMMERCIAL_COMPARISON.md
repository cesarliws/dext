# 🏆 Dext vs Soluções Comerciais (TMS Sparkle, RAD Server)

Este documento compara o **Dext Framework** com as principais soluções comerciais e open-source disponíveis no ecossistema Delphi para desenvolvimento de APIs.

---

## 1. Dext vs TMS Sparkle (TMS Software)

O **TMS Sparkle** é o framework base para comunicação HTTP da TMS Software, servindo de fundação para o TMS XData. É um produto maduro, comercial e muito respeitado.

| Característica | 🔴 Dext Framework | 🔵 TMS Sparkle |
|:---|:---|:---|
| **Filosofia** | **Fluent API & Code-First** (inspirado em ASP.NET Core) | **Component-Based & Procedural** (estilo VCL clássico) |
| **Configuração** | Fluente (`App.UseCors(...)`) | Propriedades de Componentes ou Records complexos |
| **Middleware** | Pipeline real de Middlewares (Chain of Responsibility) | Módulos (Modules) - funcional, mas menos flexível |
| **Injeção de Dependência** | **Nativa e Integrada** (`App.Services.AddSingleton`) | Não nativa (geralmente requer frameworks de terceiros) |
| **Roteamento** | Atributos (`[DextGet]`) e Fluente (`MapGet`) | Atributos (via XData) ou Procedural |
| **Custo** | Open Source | Comercial (Licença paga) |
| **Performance** | Foco em alta performance (http.sys ou Indy) | Alta performance (baseado em http.sys) |

### 💡 O Veredicto
*   **Escolha TMS Sparkle se:** Você já investiu pesado no ecossistema TMS, prefere configurar serviços arrastando componentes no DataModule, ou precisa de suporte comercial garantido (SLA).
*   **Escolha Dext se:** Você quer código moderno, limpo, testável, adora a sintaxe do C#/Node.js, quer Injeção de Dependência nativa e não quer pagar licenças caras por desenvolvedor.

---

## 2. Dext vs TMS XData (TMS Software)

Enquanto o Sparkle é o motor, o **XData** é o framework de alto nível da TMS para construção de APIs REST, famoso pela integração com o ORM TMS Aurelius.

| Característica | 🔴 Dext Framework | 🔵 TMS XData |
|:---|:---|:---|
| **Foco Principal** | **Controle Total & Arquitetura Limpa** | **Produtividade via ORM & Auto-CRUD** |
| **Criação de Endpoints** | Explícita via Controllers (`[DextGet]`) | Automática baseada em Entidades (Aurelius) ou Service Operations |
| **Acoplamento** | **Baixo** (Agnóstico a banco/ORM) | **Alto** (Fortemente acoplado ao TMS Aurelius) |
| **Payload JSON** | Serialização flexível e customizável | Formato rígido (XData JSON format) |
| **Curva de Aprendizado** | Baixa para quem conhece Web moderno | Média (precisa aprender Aurelius e convenções XData) |

### 💡 O Veredicto
*   **Escolha TMS XData se:** Você ama ORMs, usa TMS Aurelius e quer expor seu banco de dados como API com o mínimo de código possível (RAD style).
*   **Escolha Dext se:** Você prefere **Domain-Driven Design (DDD)**, quer separar suas camadas, não quer ficar preso a um ORM específico e precisa de controle total sobre o formato do JSON de resposta.

---

## 3. Dext vs RAD Server (Embarcadero)

O **RAD Server** é a solução "turn-key" da Embarcadero para MEAP (Mobile Enterprise Application Platform).

| Característica | 🔴 Dext Framework | 🟣 RAD Server |
|:---|:---|:---|
| **Arquitetura** | Standalone ou Service (Leve) | Baseado em Apache/IIS (Pesado) |
| **Deploy** | Copiar EXE | Instalação complexa, requer InterBase para controle |
| **Licenciamento** | Grátis | **Muito Caro** (Custo por deploy/instância) |
| **Flexibilidade** | Total (você controla o `main`) | Limitada (você cria BPLs que o servidor carrega) |
| **Modernidade** | Alta (Async, Middleware, DI) | Média (Focado em Wizards e FireDAC) |

### 💡 O Veredicto
*   **Dext ganha de lavada** em simplicidade de deploy, custo e performance para microsserviços. O RAD Server só faz sentido se você precisa das features "out-of-the-box" de Analytics e Push Notifications integradas e tem orçamento ilimitado.

---

## 4. Dext vs Horse (Open Source)

O **Horse** é o framework web mais popular da comunidade Delphi atualmente (inspirado no Express.js).

| Característica | 🔴 Dext Framework | 🐴 Horse |
|:---|:---|:---|
| **Inspiração** | **ASP.NET Core** (Microsoft) | **Express.js** (Node.js) |
| **Estrutura** | Mais estruturado (DI Container, Configuration, Logging) | Minimalista (Micro-framework) |
| **Injeção de Dependência** | **First-class citizen** (Core do framework) | Via middleware de terceiros (não nativo) |
| **Controllers** | Suporte nativo a Controllers e MVC | Focado em rotas soltas (embora suporte controllers via plugins) |
| **Tipagem** | Forte (Generics em todo lugar) | Média (Muitos `TObject` e casts manuais em middlewares) |

### 💡 O Veredicto
*   **Horse** é excelente para microsserviços ultra-rápidos e simples.
*   **Dext** é a evolução natural para aplicações corporativas que precisam de estrutura, DI, testes unitários facilitados e padrões de projeto sólidos, sem perder a performance.

---

## 5. Dext vs TMS Web Core (Contexto)

Você mencionou o **TMS Web Core**. É importante notar que eles **não concorrem**, eles se **complementam**.

*   **TMS Web Core:** Compila Delphi para JavaScript/HTML/CSS (Frontend).
*   **Dext:** Roda no Servidor (Backend).

**Cenário Ideal:**
Você pode criar seu Frontend (SPA) usando **TMS Web Core** e ele consome a API REST feita em **Dext**.

```pascal
// No TMS Web Core (Cliente):
Client.Get('http://api.meusite.com/produtos');

// No Dext (Servidor):
App.MapGet('/produtos', ...);
```

---

## 🏆 Resumo Geral

| Framework | Foco Principal | Custo | Estilo de Código |
|:---|:---|:---|:---|
| **Dext** | **APIs Modernas, DI, Clean Code** | Grátis | Fluente, Moderno |
| **TMS XData** | ORM, Auto-CRUD, RAD | $$$ | Atributos, Service-Based |
| **TMS Sparkle** | Base para XData, Estabilidade | $$$ | Componentes, Tradicional |
| **RAD Server** | Enterprise, Analytics, Low-code | $$$$$ | Wizards, BPLs |
| **Horse** | Micro-serviços, Simplicidade | Grátis | Callbacks, Funcional |

O **Dext** se posiciona como a **opção "Enterprise Clean Code" gratuita**. Ele traz a robustez arquitetural do ASP.NET Core para o mundo Delphi, preenchendo a lacuna entre o minimalismo do Horse e o custo/peso das soluções comerciais.
