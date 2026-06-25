# 🔌 Servidor MCP (Model Context Protocol)

O Dext inclui suporte nativo para o **Model Context Protocol (MCP) v2025-03-26**, um padrão aberto desenvolvido pela Anthropic que permite a modelos de IA (LLMs) interagir de forma segura e padronizada com dados, ferramentas e prompts externos.

Com o Dext MCP, você pode expor o seu banco de dados (via Dext ORM / FireDAC), regras de negócio e recursos do seu sistema Delphi diretamente para assistentes como **Claude Code**, **Claude Desktop**, **Gemini** ou qualquer cliente compatível com MCP.

---

## 🏗️ Arquitetura e Transportes

O Dext MCP Server abstrai a camada de rede e suporta três tipos principais de transporte:

1. **HTTP Streamable (`mtStreamable`)** [Recomendado]:
   - Usa o protocolo padrão MCP 2025-03-26.
   - Comunicação assíncrona baseada em sessões HTTP (`Mcp-Session-Id` header).
   - O endpoint padrão é `POST /mcp` para requisições/mensagens.
   - Excelente para integração web ou conexões locais persistentes (como Claude Code).

2. **Stdio (`mtStdio`)**:
   - Comunicação via Entrada/Saída padrão (`stdin`/`stdout`).
   - O ciclo de vida do processo é gerenciado pelo próprio cliente de IA (como Claude Desktop).
   - Modo de execução ideal para servidores locais leves e segurança máxima.

3. **SSE legacy (`mtSSE`)**:
   - Server-Sent Events para conexões HTTP unidirecionais contínuas combinadas com requisições POST para mensagens.
   - Compatibilidade com clientes MCP mais antigos.

---

## 🛠️ Criando um Provider de MCP

A forma mais elegante e idiomática de criar ferramentas (Tools), recursos (Resources) e prompts no Dext é utilizando o padrão **RTTI com atributos**. Basta herdar de `TMCPToolProvider` e decorar seus métodos e parâmetros.

### Exemplo Prático: `TDemoDbProvider`

O exemplo abaixo demonstra como expor uma tabela de participantes de sorteio em um banco de dados SQLite para a IA:

```pascal
unit MCP.Demo.Provider;

interface

uses
  System.SysUtils,
  System.JSON,
  FireDAC.Comp.Client,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Types,
  Dext.AI.MCP.Tools;

type
  TDemoDbProvider = class(TMCPToolProvider)
  private
    FConn: TFDConnection;
  public
    constructor Create(AConn: TFDConnection);

    // 1. Uma Tool para listar participantes
    [MCPTool('listar-participantes', 'Retorna a lista de todos os participantes cadastrados para o sorteio.')]
    function ListarParticipantes(const Args: TJSONObject): TMCPToolResult; virtual;

    // 2. Uma Tool parametrizada para realizar o sorteio
    [MCPTool('sortear-participante', 'Sorteia um participante que ainda não ganhou e o marca como sorteado.')]
    [MCPParam('evento', 'Nome do evento de sorteio', ptString, True)]
    function SortearParticipante(const Args: TJSONObject): TMCPToolResult; virtual;

    // 3. Um Resource para ler regras do sorteio
    [MCPResource('regras://sorteio', 'Regras do Sorteio', 'Documento contendo as regras e termos do sorteio.', 'text/plain')]
    function ReadRegras(const AUri: string): TMCPResourceContents; virtual;
  end;

implementation

constructor TDemoDbProvider.Create(AConn: TFDConnection);
begin
  inherited Create;
  FConn := AConn;
end;

function TDemoDbProvider.ListarParticipantes(const Args: TJSONObject): TMCPToolResult;
var
  Qry: TFDQuery;
  JA: TJSONArray;
begin
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConn;
    Qry.Open('SELECT id, nome, email, sorteado FROM participantes');
    
    JA := TJSONArray.Create;
    while not Qry.Eof do
    begin
      JA.Add(TJSONObject.Create
        .AddPair('id', Qry.FieldByName('id').AsInteger)
        .AddPair('nome', Qry.FieldByName('nome').AsString)
        .AddPair('email', Qry.FieldByName('email').AsString)
        .AddPair('sorteado', Qry.FieldByName('sorteado').AsBoolean)
      );
      Qry.Next;
    end;
    
    Result := TMCPToolResult.Text(JA.ToJSON);
  finally
    Qry.Free;
  end;
end;

function TDemoDbProvider.SortearParticipante(const Args: TJSONObject): TMCPToolResult;
var
  Qry: TFDQuery;
  Evento, Nome, Email: string;
  Id: Integer;
begin
  Evento := Args.GetValue<string>('evento', 'Embarcadero Conference');
  
  Qry := TFDQuery.Create(nil);
  try
    Qry.Connection := FConn;
    // Seleciona um participante aleatório não sorteado
    Qry.Open('SELECT id, nome, email FROM participantes WHERE sorteado = 0 ORDER BY RANDOM() LIMIT 1');
    
    if Qry.IsEmpty then
      Exit(TMCPToolResult.Error('Nenhum participante disponível para sorteio ou todos já foram sorteados.'));
      
    Id    := Qry.FieldByName('id').AsInteger;
    Nome  := Qry.FieldByName('nome').AsString;
    Email := Qry.FieldByName('email').AsString;
    
    // Atualiza para sorteado
    Qry.Close;
    Qry.SQL.Text := 'UPDATE participantes SET sorteado = 1, data_sorteio = CURRENT_TIMESTAMP WHERE id = :id';
    Qry.ParamByName('id').AsInteger := Id;
    Qry.ExecSQL;
    
    Result := TMCPToolResult.Text(Format('Ganhador sorteado para o evento "%s": %s (%s)', [Evento, Nome, Email]));
  finally
    Qry.Free;
  end;
end;

function TDemoDbProvider.ReadRegras(const AUri: string): TMCPResourceContents;
begin
  Result := TMCPResourceContents.Create(AUri, 'text/plain');
  Result.Text := 'Regras do sorteio:' + sLineBreak +
                 '1. Apenas participantes ativos podem ser sorteados.' + sLineBreak +
                 '2. Cada participante só pode ganhar uma vez.';
end;

end.
```

---

## 🚀 Inicializando o Servidor MCP

Uma vez definido o seu provider, inicializar o servidor em sua aplicação (seja Console, Service, ou uma aplicação GUI VCL/FMX) é extremamente direto:

```pascal
uses
  Dext.AI.MCP.Server,
  MCP.Demo.Provider;

var
  Server: TMCPServer;
begin
  Server := TMCPServer.Create('meu-mcp-db', '1.0.0');
  try
    // O Servidor assume ownership do Provider e libera sua memória ao finalizar
    Server.RegisterProvider(TDemoDbProvider.Create(FDConnection1));
    
    // Inicia na porta padrão 3031 no modo Streamable (não-bloqueante)
    Server.Run(mtStreamable, 'http://localhost:3031');
    
    // Mantenha a aplicação rodando...
  finally
    // Parar o servidor antes de liberar a memória
    Server.Stop;
    Server.Free;
  end;
end;
```

> [!NOTE]
> O método `Server.Run` com transporte `mtStreamable` ou `mtSSE` é **não-bloqueante**. Ele inicializa um servidor HTTP leve (Indy) em segundo plano, o que significa que você pode rodá-lo dentro de aplicações visuais (VCL/FMX) sem travar a thread de interface gráfica (Main Thread).
> Lembre-se apenas de que, se suas ferramentas atualizarem componentes visuais (como um `TDBGrid`), você deve sincronizar a atualização com a main thread usando `TThread.Queue` ou `TThread.Synchronize`.

---

## 🔌 Conectando Assistentes de IA

### 1. Claude Code (CLI)
Para adicionar o servidor rodando em modo HTTP Streamable:
```bash
claude mcp add meu-mcp-db http://localhost:3031/mcp
```

### 2. Claude Desktop (Stdio)
Para configurar o Claude Desktop para iniciar o seu executável compilado via Stdio, edite o arquivo `%APPDATA%\Claude\claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "meu-mcp-db": {
      "command": "C:\\Caminho\\Para\\SuaApp.exe",
      "args": ["--stdio"]
    }
  }
}
```

### 3. Gemini Pro (ou outros clientes compatíveis)
Você pode usar qualquer cliente MCP genérico ou integrar chamadas REST via Dext. A ferramenta de teste `/health` retorna informações rápidas de status:
```bash
curl http://localhost:3031/health
```

---

## 📂 Exemplos no Repositório

Para ver implementações completas prontas para uso:
- **[MCP.FullDemo](../../Examples/04-Advanced/MCP.FullDemo)**: Exemplo console demonstrando ferramentas matemáticas, validação de CPF, múltiplos conteúdos de retorno, recursos de configuração e prompts reutilizáveis.
- **[MCP.VclDbDemo](../../Examples/04-Advanced/MCP.VclDbDemo)**: Exemplo visual com banco de dados SQLite, grid atualizado em tempo real, console de log integrado e ferramentas de sorteio para conferências e apresentações.
