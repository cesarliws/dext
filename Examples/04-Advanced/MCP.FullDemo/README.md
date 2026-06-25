# MCP Full Demo

Exemplo completo do **Dext MCP Server** implementando os três pilares do protocolo MCP 2025-03-26:
**Tools**, **Resources** e **Prompts** - usando o padrão RTTI com atributos.

---

## Arquitetura

```
MCP.FullDemo.exe
│
├── TDemoProvider (RTTI provider)
│   ├── [MCPTool]     calcular-desconto
│   ├── [MCPTool]     validar-cpf
│   ├── [MCPTool]     calcular-imc
│   ├── [MCPTool]     gerar-relatorio-texto
│   ├── [MCPResource] config://demo
│   ├── [MCPResource] docs://regras-desconto
│   ├── [MCPPrompt]   analise-venda
│   └── [MCPPrompt]   revisao-codigo-delphi
│
└── TMCPServer (Dext MCP 2025-03-26)
    ├── Transport: HTTP Streamable  →  POST /mcp
    ├── Session:   Mcp-Session-Id header
    └── Stack:     Indy TIdHTTPServer  (via TWebHostBuilder)
```

### Stack HTTP

O Dext abstrai o servidor HTTP via interfaces (`IWebHost`, `IHttpContext`). Por baixo, `TWebHostBuilder.CreateDefault` instancia um **`TIndyWebServer`** - wrapper sobre o `TIdHTTPServer` do [Indy](https://github.com/IndySockets/Indy). Não há nenhuma outra biblioteca HTTP sob o Indy. O Dext oferece dois adapters opcionais adicionais (DCS e WebBroker/IIS), mas o MCP usa exclusivamente o Indy.

---

## Pré-requisitos

| Requisito | Versão |
|---|---|
| Delphi | 11 Alexandria ou superior |
| Indy | incluído com Delphi |
| Dext Framework | este repositório |

Não há dependências externas além do próprio Dext.

---

## Como compilar

1. Abra o Delphi
2. Abra o arquivo `MCP.FullDemo.dpr`
3. Verifique que o **Search Path** do projeto inclui os caminhos do Dext:
   - `..\..\Sources\MCP`
   - `..\..\Sources\Web`
   - `..\..\Sources\Core`
   - *(ou use o `.groupproj` do Dext que configura tudo automaticamente)*
4. **Build** → `Ctrl+F9`
5. O executável será gerado em `..\..\Examples\Output\`

---

## Como executar

```
# Padrão - Streamable em http://localhost:3031 (recomendado)
MCP.FullDemo.exe

# Porta customizada
MCP.FullDemo.exe --port 3040

# SSE legacy (compatível com Claude Desktop mais antigo)
MCP.FullDemo.exe --sse

# Stdio (Claude Desktop gerencia o processo)
MCP.FullDemo.exe --stdio
```

Ao iniciar, o servidor exibe o banner com todos os endpoints e o comando de configuração do Claude Code.

---

## Conectar ao Claude Code

```bash
# Adicionar o servidor (Streamable, porta padrão)
claude mcp add full-demo http://localhost:3031/mcp

# Verificar se foi registrado
claude mcp list

# Remover
claude mcp remove full-demo
```

Após adicionar, feche e reabra o Claude Code. As tools, resources e prompts ficam disponíveis automaticamente.

**Exemplos de uso no Claude:**
> "Calcule o desconto progressivo para uma venda de R$ 1.200,00"
> "Valide o CPF 529.982.247-25"
> "Calcule o IMC de uma pessoa com 82kg e 1.78m"
> "Leia o resource config://demo"
> "Use o prompt revisao-codigo-delphi para revisar este código: ..."

---

## Conectar ao Claude Desktop (SSE legacy)

Execute com `--sse` e edite `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "full-demo": {
      "url": "http://localhost:3031/sse"
    }
  }
}
```

Reinicie o Claude Desktop.

---

## Conectar ao Claude Desktop (Stdio)

Sem precisar manter o executável rodando manualmente:

```json
{
  "mcpServers": {
    "full-demo": {
      "command": "C:\\caminho\\para\\MCP.FullDemo.exe",
      "args": ["--stdio"]
    }
  }
}
```

O Claude Desktop inicia e encerra o processo automaticamente.

---

## Testar manualmente

O arquivo `mcp_test.http` contém **18 requisições** cobrindo todos os endpoints. Compatível com:
- [VS Code REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
- JetBrains HTTP Client (IntelliJ, Rider)
- curl (comandos no final do arquivo)

**Sequência obrigatória:**

```
1. GET  /health           → confirma que o servidor está de pé
2. POST /mcp  initialize  → recebe Mcp-Session-Id no header de resposta
3. POST /mcp  <qualquer método>  com header Mcp-Session-Id: <id>
```

**Health check rápido via curl:**
```bash
curl http://localhost:3031/health
```

Resposta esperada:
```json
{
  "status": "ok",
  "server": "full-demo",
  "version": "1.0.0",
  "protocol": "2025-03-26",
  "tools": 4,
  "resources": 2,
  "prompts": 2
}
```

---

## Estrutura do código

```
MCP.FullDemo/
├── MCP.FullDemo.dpr          Programa principal - startup, flags CLI, banner
├── MCP.FullDemo.Provider.pas TDemoProvider - todas as tools, resources e prompts
├── mcp_test.http             18 testes HTTP para verificação manual
├── README.md                 Esta documentação
└── claude_config.md          Referência rápida de configuração
```

### `MCP.FullDemo.Provider.pas` - o arquivo mais importante

Contém `TDemoProvider`, uma subclasse de `TMCPToolProvider` com métodos anotados:

```pascal
type
  TDemoProvider = class(TMCPToolProvider)
  public
    // Tool: anotação [MCPTool] + [MCPParam] na mesma declaração
    [MCPTool('calcular-desconto', 'Calcula desconto progressivo')]
    [MCPParam('valor', 'Valor em reais', ptNumber)]
    function CalcularDesconto(const Args: TJSONObject): TMCPToolResult; virtual;

    // Resource: anotação [MCPResource]
    [MCPResource('config://demo', 'Configuração', 'Configurações do servidor')]
    function ReadConfig(const AUri: string): TMCPResourceContents; virtual;

    // Prompt: anotação [MCPPrompt] + [MCPPromptArg]
    [MCPPrompt('analise-venda', 'Análise comercial de venda')]
    [MCPPromptArg('valor', 'Valor em reais')]
    function AnaliseVenda(const Args: TJSONObject): TMCPPromptResult; virtual;
  end;
```

O registro no servidor é uma única linha:
```pascal
Server.RegisterProvider(TDemoProvider.Create);
// O servidor assume ownership do provider - não precisa Free manual
```

O RTTI do Delphi escaneia os atributos em tempo de execução e registra cada método automaticamente nas respectivas registries (tools, resources, prompts).

---

## Como adaptar para seu projeto

### 1. Criar seu provider

Copie `MCP.FullDemo.Provider.pas`, renomeie a classe e substitua os métodos pela lógica do seu domínio:

```pascal
type
  TERPProvider = class(TMCPToolProvider)
  private
    FDB: TDatabaseConnection; // sua conexão
  public
    constructor Create(ADB: TDatabaseConnection);

    [MCPTool('buscar-cliente', 'Busca dados completos de um cliente pelo CPF')]
    [MCPParam('cpf', 'CPF do cliente (somente dígitos)', ptString)]
    function BuscarCliente(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('criar-pedido', 'Registra um novo pedido de venda')]
    [MCPParam('cliente_id', 'ID do cliente', ptString)]
    [MCPParam('valor',      'Valor total',    ptNumber)]
    function CriarPedido(const Args: TJSONObject): TMCPToolResult; virtual;
  end;
```

### 2. Implementar os métodos

```pascal
function TERPProvider.BuscarCliente(const Args: TJSONObject): TMCPToolResult;
var
  CPF: string;
  JSON: string;
begin
  CPF := Args.GetValue<string>('cpf', '');

  if CPF = '' then
    Exit(TMCPToolResult.Error('CPF é obrigatório'));

  try
    JSON := FDB.QueryOne('SELECT * FROM clientes WHERE cpf = ?', [CPF]);
    if JSON = '' then
      Result := TMCPToolResult.Error('Cliente não encontrado: ' + CPF)
    else
      Result := TMCPToolResult.Text(JSON);
  except
    on E: Exception do
      Result := TMCPToolResult.Error('Erro ao buscar cliente: ' + E.Message);
  end;
end;
```

### 3. Registrar e iniciar

```pascal
Server := TMCPServer.Create('erp-server', '2.0.0');
Server.RegisterProvider(TERPProvider.Create(MinhaConexaoDb));
Server.Run(mtStreamable, 'http://localhost:3031');
```

---

## Referência de tipos de resultado

| Situação | Código |
|---|---|
| Retorno normal (texto) | `TMCPToolResult.Text('...')` |
| Erro que o LLM deve ver | `TMCPToolResult.Error('mensagem')` |
| Imagem PNG/JPEG (base64) | `TMCPToolResult.Image(base64, 'image/png')` |
| Áudio (base64) | `TMCPToolResult.Audio(base64, 'audio/mpeg')` |
| Resource embutido | `TMCPToolResult.Resource(uri, texto)` |
| Múltiplos conteúdos | `Result.AddContent(TMCPContent.Text('...'))` |

## Referência de tipos de parâmetro

| Constante | Tipo JSON Schema | Leitura no callback |
|---|---|---|
| `ptString` | `"string"` | `Args.GetValue<string>('nome', '')` |
| `ptInteger` | `"integer"` | `Args.GetValue<Integer>('qtd', 0)` |
| `ptNumber` | `"number"` | `Args.GetValue<Double>('valor', 0.0)` |
| `ptBoolean` | `"boolean"` | `Args.GetValue<Boolean>('flag', False)` |
| `ptObject` | `"object"` | `Args.GetValue('obj') as TJSONObject` |
| `ptArray` | `"array"` | `Args.GetValue('lista') as TJSONArray` |

---

## Endpoints do servidor

### Streamable (`--` padrão)

| Método | Path | Descrição |
|---|---|---|
| `POST` | `/mcp` | Envia JSON-RPC, recebe resposta síncrona |
| `DELETE` | `/mcp` | Encerra a sessão (`Mcp-Session-Id` no header) |
| `GET` | `/health` | Status e contagem de tools/resources/prompts |

### SSE legacy (`--sse`)

| Método | Path | Descrição |
|---|---|---|
| `GET` | `/sse` | Abre stream SSE persistente |
| `POST` | `/message?sessionId=<id>` | Envia JSON-RPC, retorna `202 Accepted` |
| `GET` | `/health` | Status do servidor |

---

## Métodos MCP implementados

| Método JSON-RPC | Capacidade |
|---|---|
| `initialize` | Cria sessão, retorna capabilities e `protocolVersion: 2025-03-26` |
| `notifications/initialized` | Confirmação do cliente (sem resposta) |
| `ping` | Keep-alive → `{}` |
| `tools/list` | Lista tools com JSON Schema dos parâmetros |
| `tools/call` | Invoca uma tool, retorna `TMCPToolResult` |
| `resources/list` | Lista resources disponíveis |
| `resources/read` | Lê conteúdo de um resource por URI |
| `prompts/list` | Lista templates de prompt com seus argumentos |
| `prompts/get` | Gera mensagens de um template com argumentos |

---

## Executando múltiplos servidores MCP

Cada `TMCPServer` é independente e não-bloqueante (SSE/Streamable). Você pode rodar vários em paralelo, cada um em uma porta:

```pascal
var
  ERPServer:    TMCPServer;
  FiscalServer: TMCPServer;
begin
  ERPServer := TMCPServer.Create('erp-server');
  ERPServer.RegisterProvider(TERPProvider.Create(DB));
  ERPServer.Run(mtStreamable, 'http://localhost:3031');

  FiscalServer := TMCPServer.Create('fiscal-server');
  FiscalServer.RegisterProvider(TFiscalProvider.Create(DB));
  FiscalServer.Run(mtStreamable, 'http://localhost:3032');

  Readln; // aguarda

  ERPServer.Stop;
  FiscalServer.Stop;
  // ...
end;
```

```bash
claude mcp add erp    http://localhost:3031/mcp
claude mcp add fiscal http://localhost:3032/mcp
```

---

## Combinando MCP com API REST Dext

O `TMCPServer` usa `TWebHostBuilder` internamente, convivendo perfeitamente com uma API REST Dext em paralelo:

```pascal
// MCP Server na porta 3031
MCPServer := TMCPServer.Create('meu-server');
MCPServer.RegisterProvider(TMyProvider.Create);
MCPServer.Run(mtStreamable, 'http://localhost:3031');  // non-blocking

// API REST Dext na porta 5000
RestHost := TWebHostBuilder.CreateDefault(nil)
  .UseUrls('http://localhost:5000')
  .Configure(procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/clientes', ...);
      App.MapPost('/pedidos', ...);
    end)
  .Build;
RestHost.Start;  // non-blocking

Readln;

MCPServer.Stop;
RestHost.Stop;
```
