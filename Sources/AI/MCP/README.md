# Dext MCP Server

Implementação nativa do **Model Context Protocol (MCP) 2025-03-26** para o Dext Framework.  
Zero dependências externas - usa apenas RTL Delphi + infraestrutura Dext.

```
[Claude Code / Claude Desktop / Agente IA]
        |
   MCP 2025-03-26 (JSON-RPC 2.0)
        |
[TMCPServer em Delphi]
        |
[Tools · Resources · Prompts]
        |
[Banco de dados, APIs, regras de negócio...]
```

---

## Arquivos

| Arquivo | Descrição |
|---|---|
| `Dext.MCP.Protocol.pas` | Constantes JSON-RPC 2.0, tipos base, helper `TJsonRpc` |
| `Dext.MCP.Types.pas` | Tipos ricos: `TMCPToolResult`, `TMCPContent`, `TMCPResourceContents`, `TMCPPromptResult` |
| `Dext.MCP.Attributes.pas` | Atributos RTTI: `[MCPTool]`, `[MCPParam]`, `[MCPResource]`, `[MCPPrompt]` |
| `Dext.MCP.Tools.pas` | Registry de tools + builder fluente + provider RTTI |
| `Dext.MCP.Resources.pas` | Registry de resources + builder fluente |
| `Dext.MCP.Prompts.pas` | Registry de prompts + builder fluente |
| `Dext.MCP.Server.pas` | `TMCPServer` - Streamable, SSE legacy, Stdio; dispatch completo |

---

## Quick Start

### Streamable transport (recomendado - MCP 2025-03-26)

```pascal
uses
  Dext.MCP.Protocol, Dext.MCP.Types, Dext.MCP.Tools, Dext.MCP.Server;

var
  Server: TMCPServer;
begin
  Server := TMCPServer.Create('meu-servidor', '1.0.0');

  Server.Tool('buscar-cliente')
    .Description('Busca dados de um cliente pelo CPF')
    .Param('cpf', 'CPF do cliente (somente dígitos)', ptString)
    .OnCallResult(function(Args: TJSONObject): TMCPToolResult
      var CPF: string;
      begin
        CPF := Args.GetValue<string>('cpf', '');
        if CPF = '' then
          Result := TMCPToolResult.Error('CPF obrigatório')
        else
          Result := TMCPToolResult.Text(BuscarClienteNoBanco(CPF));
      end);

  Server.Run(mtStreamable, 'http://localhost:3031');
  // Claude Code: claude mcp add meu-servidor http://localhost:3031/mcp
end;
```

### Configurar no Claude Code

```bash
claude mcp add meu-servidor http://localhost:3031/mcp
```

### Configurar no Claude Desktop (legacy SSE)

```json
{
  "mcpServers": {
    "meu-servidor": {
      "url": "http://localhost:3031/sse"
    }
  }
}
```

---

## Transports

| Transport | Constante | URL de conexão | Protocolo |
|---|---|---|---|
| **HTTP Streamable** | `mtStreamable` | `http://host/mcp` | MCP 2025-03-26 ✓ |
| SSE legacy | `mtSSE` | `http://host/sse` | MCP 2024-11-05 |
| Stdio | `mtStdio` | - | Claude Desktop processo |

---

## Tools

### Builder fluente (callbacks inline)

```pascal
// Resultado simples de texto
Server.Tool('status')
  .Description('Status atual do sistema')
  .OnCallResult(function(Args: TJSONObject): TMCPToolResult
    begin
      Result := TMCPToolResult.Text('Sistema online');
    end);

// Erro explícito
Server.Tool('dividir')
  .Description('Divide dois números')
  .Param('a', 'Dividendo', ptNumber)
  .Param('b', 'Divisor', ptNumber)
  .OnCallResult(function(Args: TJSONObject): TMCPToolResult
    var A, B: Double;
    begin
      A := Args.GetValue<Double>('a', 0);
      B := Args.GetValue<Double>('b', 0);
      if B = 0 then
        Result := TMCPToolResult.Error('Divisão por zero')
      else
        Result := TMCPToolResult.Text(FloatToStr(A / B));
    end);

// Resultado com imagem
Server.Tool('gerar-grafico')
  .Description('Gera gráfico de vendas como imagem PNG')
  .Param('mes', 'Mês (1-12)', ptInteger)
  .OnCallResult(function(Args: TJSONObject): TMCPToolResult
    var Base64PNG: string;
    begin
      Base64PNG := GerarGraficoPNG(Args.GetValue<Integer>('mes', 1));
      Result := TMCPToolResult.Image(Base64PNG, 'image/png');
    end);

// Múltiplos conteúdos em um resultado
Server.Tool('relatorio-completo')
  .Description('Retorna relatório com texto e gráfico')
  .OnCallResult(function(Args: TJSONObject): TMCPToolResult
    begin
      Result := TMCPToolResult.Text('Relatório de Vendas - Março 2026');
      Result.AddContent(TMCPContent.Image(GerarGrafico, 'image/png'));
      Result.AddContent(TMCPContent.Text('Total: R$ 125.400,00'));
    end);
```

### Provider RTTI (recomendado para conjuntos grandes de tools)

```pascal
uses
  Dext.MCP.Attributes, Dext.MCP.Types, Dext.MCP.Tools;

type
  TERPTools = class(TMCPToolProvider)
  public
    [MCPTool('buscar-cliente', 'Busca cadastro completo de um cliente')]
    [MCPParam('cpf', 'CPF do cliente (somente dígitos)', ptString)]
    function BuscarCliente(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('criar-pedido', 'Cria um novo pedido de venda')]
    [MCPParam('cliente_id', 'ID do cliente', ptString)]
    [MCPParam('itens', 'Array de itens do pedido', ptArray)]
    function CriarPedido(const Args: TJSONObject): TMCPToolResult; virtual;

    [MCPTool('listar-produtos', 'Lista produtos com filtro opcional')]
    [MCPParam('categoria', 'Categoria do produto', ptString, {required=}False)]
    [MCPParam('estoque_min', 'Estoque mínimo', ptInteger, False)]
    function ListarProdutos(const Args: TJSONObject): TMCPToolResult; virtual;
  end;

// Registrar no servidor (o servidor assume ownership do provider)
Server.RegisterProvider(TERPTools.Create);
```

```pascal
function TERPTools.BuscarCliente(const Args: TJSONObject): TMCPToolResult;
var
  CPF: string;
begin
  CPF := Args.GetValue<string>('cpf', '');
  if CPF = '' then
    Exit(TMCPToolResult.Error('CPF é obrigatório'));

  try
    Result := TMCPToolResult.Text(FRepository.FindByCPF(CPF).ToJSON);
  except
    on E: EClienteNaoEncontrado do
      Result := TMCPToolResult.Error('Cliente não encontrado: ' + CPF);
    on E: Exception do
      Result := TMCPToolResult.Error('Erro interno: ' + E.Message);
  end;
end;
```

### Callback legado (string) - backward-compat

```pascal
// Código existente continua funcionando sem nenhuma mudança
Server.Tool('ping')
  .Description('Ping')
  .OnCall(function(Args: TJSONObject): string
    begin
      Result := '{"pong": true}';
    end);
```

---

## Resources

Resources são fontes de dados que o LLM pode ler por URI - como "documentos" acessíveis ao modelo.

### Builder fluente

```pascal
Server.Resource('config://app', 'Configuração da Aplicação')
  .Description('Configurações atuais em formato JSON')
  .MimeType('application/json')
  .OnRead(function(const AUri: string): TMCPResourceContents
    begin
      Result := TMCPResourceContents.TextResource(AUri, LoadConfigJSON);
    end);

Server.Resource('file:///docs/manual.md', 'Manual do Usuário')
  .Description('Manual completo do sistema em Markdown')
  .MimeType('text/markdown')
  .OnRead(function(const AUri: string): TMCPResourceContents
    begin
      Result := TMCPResourceContents.TextResource(AUri,
        TFile.ReadAllText('C:\Docs\manual.md', TEncoding.UTF8));
    end);
```

### Provider RTTI

```pascal
[MCPResource('config://app', 'Configuração', 'Configurações da aplicação')]
function ReadConfig(const AUri: string): TMCPResourceContents; virtual;

[MCPResource('schema://db', 'Schema DB', 'Schema do banco de dados', 'text/plain')]
function ReadSchema(const AUri: string): TMCPResourceContents; virtual;
```

---

## Prompts

Prompts são templates de mensagens que o LLM pode invocar por nome com argumentos.

### Builder fluente

```pascal
Server.Prompt('revisao-codigo', 'Revisão detalhada de código Delphi')
  .Arg('codigo', 'Código Delphi para revisar')
  .Arg('contexto', 'Contexto opcional', {required=}False)
  .OnGet(function(Args: TJSONObject): TMCPPromptResult
    var Code: string;
    begin
      Code := Args.GetValue<string>('codigo', '');
      Result := TMCPPromptResult.Create('Revisão de código');
      Result.AddMessage(TMCPPromptMessage.User(
        'Revise este código Delphi:' + sLineBreak +
        '```delphi' + sLineBreak + Code + sLineBreak + '```'));
    end);
```

### Provider RTTI

```pascal
[MCPPrompt('revisao-codigo', 'Revisão detalhada de código Delphi')]
[MCPPromptArg('codigo', 'Código Delphi para revisar')]
[MCPPromptArg('contexto', 'Contexto opcional', {required=}False)]
function RevisaoCodigo(const Args: TJSONObject): TMCPPromptResult; virtual;
```

---

## Tipos de resultado (`TMCPToolResult`)

| Factory method | Uso |
|---|---|
| `TMCPToolResult.Text(msg)` | Texto simples - caso mais comum |
| `TMCPToolResult.Error(msg)` | Erro da tool (`isError: true`) |
| `TMCPToolResult.Image(b64, mime)` | Imagem base64 (ex: `image/png`) |
| `TMCPToolResult.Audio(b64, mime)` | Áudio base64 (ex: `audio/mpeg`) |
| `TMCPToolResult.Resource(uri, text)` | Resource embutido no resultado |
| `.AddContent(TMCPContent.*)` | Adiciona item extra ao resultado |

---

## Tipos de parâmetros

| Constante | JSON Schema | Leitura em Delphi |
|---|---|---|
| `ptString` | `"string"` | `Args.GetValue<string>('nome', '')` |
| `ptInteger` | `"integer"` | `Args.GetValue<Integer>('qtd', 0)` |
| `ptNumber` | `"number"` | `Args.GetValue<Double>('valor', 0.0)` |
| `ptBoolean` | `"boolean"` | `Args.GetValue<Boolean>('ativo', True)` |
| `ptObject` | `"object"` | `Args.GetValue('obj') as TJSONObject` |
| `ptArray` | `"array"` | `Args.GetValue('lista') as TJSONArray` |

---

## Endpoints disponíveis

### Streamable (`mtStreamable`)

| Método | Path | Descrição |
|---|---|---|
| `POST` | `/mcp` | Envia JSON-RPC, recebe resposta síncrona |
| `DELETE` | `/mcp` | Encerra sessão (header `Mcp-Session-Id`) |
| `GET` | `/health` | `{"tools":N,"resources":N,"prompts":N,...}` |

### SSE legacy (`mtSSE`)

| Método | Path | Descrição |
|---|---|---|
| `GET` | `/sse` | Abre stream SSE |
| `POST` | `/message?sessionId=<id>` | Envia JSON-RPC, retorna `202` |
| `GET` | `/health` | Status do servidor |

---

## Métodos MCP implementados

| Método JSON-RPC | Capacidade |
|---|---|
| `initialize` | - handshake, cria sessão, retorna capabilities |
| `notifications/initialized` | - confirmação (sem resposta) |
| `ping` | - keep-alive |
| `tools/list` | `tools` |
| `tools/call` | `tools` |
| `resources/list` | `resources` |
| `resources/read` | `resources` |
| `prompts/list` | `prompts` |
| `prompts/get` | `prompts` |
