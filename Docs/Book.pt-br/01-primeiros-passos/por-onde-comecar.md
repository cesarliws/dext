# Por Onde Começar?

Seja muito bem-vindo ao **Dext**! 

Se você está vindo do Delphi clássico (onde criar sistemas significava arrastar componentes visuais para um formulário), ou se está chegando agora para criar microsserviços modernos, você pode se perguntar: *por onde eu começo no meio de tantos recursos?*

O Dext é um ecossistema modular por design. Graças ao compilador Delphi, apenas os recursos que você realmente utiliza serão incluídos no binário final. Isso significa que você pode adotá-lo como um micro-framework super leve ou como uma suíte corporativa completa, sem overhead de peso ou CPU.

Para facilitar sua jornada, organizamos o aprendizado em **Trilhas Temáticas**. Escolha a que melhor se alinha ao seu objetivo atual:

---

## 🚀 Trilha A — Web APIs & Microsserviços
Se você precisa construir APIs REST leves, rápidas e escaláveis, ou quer substituir soluções existentes (como o Horse) por uma arquitetura mais modular com injeção de dependência nativa.

*   **1. Primeiros Passos:** Entenda a [Instalação](instalacao.md) e rode o seu primeiro [Hello World](hello-world.md).
*   **2. Minimal APIs:** Aprenda a mapear rotas simples e diretas em [Minimal APIs](../02-framework-web/minimal-apis.md).
*   **3. Middleware Pipeline:** Adicione tratamento de erros, CORS e compressão no [Middleware Pipeline](../02-framework-web/middleware.md).
*   **4. Exemplos Práticos:** Explore o código-fonte do exemplo [Web.MinimalAPI](../../Examples/Web.MinimalAPI/).

---

## 💾 Trilha B — Persistência & ORM (Dext.Entity)
Se o seu objetivo principal é interagir com bancos de dados relacionais de forma moderna, eliminando SQL strings manuais usando LINQ fortemente tipado e Change Tracking eficiente.

*   **1. Conceito do ORM:** Entenda como declarar sua primeira entidade e contexto em [Primeiros Passos do ORM](../05-orm/primeiros-passos.md).
*   **2. Mapeamento:** Aprenda a mapear tabelas, chaves primárias e colunas em [Entidades & Mapeamento](../05-orm/entidades.md).
*   **3. Consultas Modernas:** Realize consultas type-safe em [Consultas](../05-orm/consultas.md) e [Smart Properties](../05-orm/smart-properties.md).
*   **4. Exemplos Práticos:** Explore o exemplo [Orm.EntityDemo](../../Examples/Orm.EntityDemo/).

---

## 📡 Trilha C — Integração e Consumo de APIs (RestClient)
Se você precisa que sua aplicação Delphi se comunique com outros servidores, consuma APIs de terceiros (como buscar CEPs, dados de clima ou gateways de pagamento) de forma resiliente.

*   **1. Cliente REST:** Aprenda a fazer requisições HTTP fluentes em [Cliente REST](../12-networking/rest-client.md).

---

## 🏢 Trilha D — Modernização de ERPs Legados (VCL/FMX)
Se você tem um sistema desktop gigante e quer começar a aplicar Clean Architecture ou padrões como MVVM (separando a lógica de negócios da tela visual da IDE) sem perder a produtividade do RAD Studio.

*   **1. Injeção de Dependência:** Entenda como organizar o ciclo de vida das suas classes e evitar acoplamento em [Injeção de Dependência](../10-avancado/injecao-dependencia.md).
*   **2. EntityDataSet:** Mapeie coleções de objetos POCO de memória diretamente para componentes visuais como Grids do Delphi em [Desktop UI (Dext.UI)](../11-desktop-ui/README.md).

---

## 🛠️ Trilha E — Boas Práticas: Testes & Segurança
Para garantir que seu software continue funcionando corretamente após qualquer alteração, sem a necessidade de testes manuais exaustivos.

*   **1. Testes Unitários:** Aprenda a criar mocks e assertions elegantes em [Testes](../08-testes/README.md).

---

### Dica de Ouro
Recomendamos começar clonando o repositório, configurando o ambiente através do guia de [Instalação](instalacao.md) e brincando com o [Hello World](hello-world.md). A partir dali, siga a trilha que mais faz sentido para o seu projeto!
