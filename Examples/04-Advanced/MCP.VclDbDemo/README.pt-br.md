# MCP VCL Database Demo

Este exemplo demonstra como utilizar a implementação nativa do **Dext MCP Server** integrada a uma aplicação visual VCL no Delphi com o banco de dados **FireDAC** (SQLite em memória).

> [!WARNING]
> **Aviso de Arquitetura & Escabilidade:**
> Este projeto exemplo foi desenhado com o propósito exclusivo de demonstrar a integração rápida do Dext MCP em sistemas legados VCL existentes. Por simplicidade de demonstração, a classe do provedor (`TDatabaseMCPProvider`) está fortemente acoplada ao formulário principal (`TFormMain`) e compartilha diretamente os componentes visuais e de conexão dele.
>
> **Para sistemas em produção:**
> - **Desacoplamento:** Não acople regras de negócio, banco de dados ou provedores MCP ao código dos formulários.
> - **Camadas e DI:** Crie classes de serviço isoladas para a lógica de negócio e utilize o mecanismo nativo de Injeção de Dependências (DI) do Dext para injetar o `TDbContext` ou suas conexões.
> - **Gerenciamento de Ciclo de Vida:** Conexões de banco de dados devem ser criadas por escopo (Scoped/Transient) para suportar múltiplas chamadas concorrentes sem colidir a conexão da UI.

---

## Recursos Demonstrados

- **Servidor MCP Assíncrono**: Inicia o servidor em segundo plano sem congelar a tela da aplicação.
- **FireDAC**: Consulta e atualização de dados no SQLite.
- **DBGrid**: Visualização em tempo real das alterações feitas pelo modelo de IA (LLM).
- **Console de Eventos**: Memo integrado que exibe o log de requisições recebidas do cliente MCP.
- **Tools Personalizadas**:
  - `listar-participantes`: Retorna a listagem atual de pessoas cadastradas.
  - `sortear-participante`: Sorteia uma pessoa aleatória não sorteada, marcando-a no banco.
  - `executar-sql`: Permite a IA rodar consultas SELECT ou comandos UPDATE diretamente no banco.

---

## Como Executar

1. Compile e execute o projeto `MCP.VclDbDemo.dproj`.
2. Clique no botão **Iniciar Servidor**. Por padrão, ele escutará na porta `3031`.
3. Para testar localmente via curl:
   ```bash
   curl http://localhost:3031/health
   ```
4. Conecte ao seu assistente de preferência (ex: Claude Code):
   ```bash
   claude mcp add db-demo http://localhost:3031/mcp
   ```

5. Interaja com a IA:
   > "Faça um sorteio dos participantes agora e me diga quem ganhou"
   > "Quantos participantes temos no banco?"
   > "Rode uma query para ver quem já foi sorteado"
