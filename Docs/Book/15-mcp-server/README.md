# 🔌 MCP Server (Model Context Protocol)

Dext includes native support for the **Model Context Protocol (MCP) v2025-03-26**, an open standard developed by Anthropic that allows AI models (LLMs) to securely and standardly interact with external data, tools, and prompts.

With Dext MCP, you can expose your database (via Dext ORM / FireDAC), business rules, and system resources directly to AI assistants such as **Claude Code**, **Claude Desktop**, **Gemini**, or any MCP-compatible client.

---

## 🏗️ Architecture & Transports

The Dext MCP Server abstracts the network layer and supports three main transport modes:

1. **HTTP Streamable (`mtStreamable`)** [Recommended]:
   - Follows the standard MCP 2025-03-26 protocol.
   - Asynchronous communication using HTTP sessions (via `Mcp-Session-Id` header).
   - Default endpoint is `POST /mcp` for requests/messages.
   - Ideal for web integrations or persistent local connections (like Claude Code).

2. **Stdio (`mtStdio`)**:
   - Standard Input/Output (`stdin`/`stdout`) communication.
   - Lifecycle of the process is managed directly by the AI client (like Claude Desktop).
   - Recommended for lightweight local servers and maximum security.

3. **SSE legacy (`mtSSE`)**:
   - Server-Sent Events for continuous one-way HTTP streams combined with POST requests for sending messages.
   - Maintained for compatibility with legacy MCP clients.

---

## 🛠️ Creating an MCP Provider

The most elegant and idiomatic way to declare Tools, Resources, and Prompts in Dext is using **RTTI with attributes**. Simply inherit from `TMCPToolProvider` and decorate your public virtual methods.

### Practical Example: `TDemoDbProvider`

The following example demonstrates how to expose a database table containing lucky draw participants from an SQLite database to the AI:

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

    // 1. Tool to list participants
    [MCPTool('listar-participantes', 'Returns the list of all registered participants for the lucky draw.')]
    function ListarParticipantes(const Args: TJSONObject): TMCPToolResult; virtual;

    // 2. Parameterized Tool to run the draw
    [MCPTool('sortear-participante', 'Draws a random participant who has not won yet and marks them as drawn.')]
    [MCPParam('evento', 'Name of the draw event', ptString, True)]
    function SortearParticipante(const Args: TJSONObject): TMCPToolResult; virtual;

    // 3. Resource to read draw rules
    [MCPResource('regras://sorteio', 'Rules of the Draw', 'Document detailing the terms and rules of the draw.', 'text/plain')]
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
    // Selects a random non-drawn participant
    Qry.Open('SELECT id, nome, email FROM participantes WHERE sorteado = 0 ORDER BY RANDOM() LIMIT 1');
    
    if Qry.IsEmpty then
      Exit(TMCPToolResult.Error('No participants available for drawing or everyone was already drawn.'));
      
    Id    := Qry.FieldByName('id').AsInteger;
    Nome  := Qry.FieldByName('nome').AsString;
    Email := Qry.FieldByName('email').AsString;
    
    // Mark as drawn
    Qry.Close;
    Qry.SQL.Text := 'UPDATE participantes SET sorteado = 1, data_sorteio = CURRENT_TIMESTAMP WHERE id = :id';
    Qry.ParamByName('id').AsInteger := Id;
    Qry.ExecSQL;
    
    Result := TMCPToolResult.Text(Format('Winner drawn for event "%s": %s (%s)', [Evento, Nome, Email]));
  finally
    Qry.Free;
  end;
end;

function TDemoDbProvider.ReadRegras(const AUri: string): TMCPResourceContents;
begin
  Result := TMCPResourceContents.Create(AUri, 'text/plain');
  Result.Text := 'Draw Rules:' + sLineBreak +
                 '1. Only active participants can be drawn.' + sLineBreak +
                 '2. Each participant can only win once.';
end;

end.
```

---

## 🚀 Starting the MCP Server (Fluent Builder API)

Once you have defined your provider, the best practice to configure and start the server within any Delphi application (Console, Service, or GUI VCL/FMX) is using the `TMCPServerBuilder`:

```pascal
uses
  Dext.AI.MCP.Server,
  Dext.Server.Engine.Types,
  MCP.Demo.Provider;

var
  Server: TMCPServer;
  Builder: TMCPServerBuilder;
  Options: TServerEngineOptions;
begin
  Builder := TMCPServerBuilder.Create;
  try
    Builder
      .Name('my-mcp-db')
      .Version('1.0.0')
      .Transport(mtStreamable)
      .Url('http://localhost:3031')
      .RegisterProvider(
        TDemoDbProvider.Create(FDConnection1));

    // Choose HTTP Stack: UseIndy (default) or UseHttpSys
    Builder.UseHttpSys; 
    
    Server := Builder.Build;
  finally
    Builder.Free;
  end;

  try
    // Starts listening with configurations defined in builder
    Server.Run;
    
    // Keep application running...
  finally
    Server.Stop;
    Server.Free;
  end;
end;
```

> [!NOTE]
> The `Server.Run` method using `mtStreamable` or `mtSSE` is **non-blocking**. It starts a lightweight HTTP server (Indy) in background threads, so it can run inside GUI applications (VCL/FMX) without freezing the Main UI Thread.
> However, if your tool callback modifies UI controls directly (e.g. updating a `TDBGrid`), make sure to synchronize updates with the main thread using `TThread.Queue` or `TThread.Synchronize`.

---

## 🔒 Running MCP Server over Native HTTPS (`http.sys`)

To run your MCP Server over Windows Kernel (`http.sys`) with encrypted HTTPS:

1. **Generate and bind the local certificate using Dext CLI (as Administrator):**
   ```bash
   dext dev-certs https --trust
   ```

2. **Configure `TMCPServerBuilder` with `UseHttpSys` and `UseHttps`:**
   ```pascal
   var
     Options: TServerEngineOptions;
   begin
     Options := TServerEngineOptions.Default;
     Options.UseHttps := True;
     
     Builder := TMCPServerBuilder.Create;
     try
       Builder
         .Name('my-mcp-server')
         .Transport(mtStreamable)
         .Url('https://localhost:3031')
         .UseHttpSys(Options);
         
       // Register tools...
       Server := Builder.Build;
     finally
       Builder.Free;
     end;
   end;
   ```

3. **Connect AI Assistants directly via HTTPS:**
   ```bash
   claude mcp add my-mcp https://localhost:3031/mcp
   ```

---

## 🔌 Connecting AI Assistants

### 1. Claude Code (CLI)
To add the server running in HTTP Streamable mode:
```bash
claude mcp add my-mcp-db http://localhost:3031/mcp
```

### 2. Claude Desktop (Stdio)
To configure Claude Desktop to run your compiled executable directly via Stdio, edit `%APPDATA%\Claude\claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "my-mcp-db": {
      "command": "C:\\Path\\To\\YourApp.exe",
      "args": ["--stdio"]
    }
  }
}
```

### 3. Gemini Pro (or other compatible clients)
You can use any generic MCP client, or hit the health endpoint directly:
```bash
curl http://localhost:3031/health
```

---

## 📂 Example Projects

For complete working implementations:
- **[MCP.FullDemo](../../Examples/04-Advanced/MCP.FullDemo)**: Console application showing mathematical tools, CPF validation, multi-content results, configuration resources, and reusable prompt templates.
- **[MCP.VclDbDemo](../../Examples/04-Advanced/MCP.VclDbDemo)**: Visual VCL application with SQLite database, real-time grid updates, integrated log console, and lucky draw tools.
