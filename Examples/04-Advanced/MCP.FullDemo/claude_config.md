# Configuração Claude - MCP Full Demo

## Claude Code (recomendado - MCP 2025-03-26)

```bash
# Adicionar o servidor
claude mcp add full-demo http://localhost:3031/mcp

# Verificar se foi adicionado
claude mcp list

# Remover (se necessário)
claude mcp remove full-demo
```

Após adicionar, feche e reabra o Claude Code. O servidor aparecerá disponível e você pode testar:

> "Calcule o desconto para um valor de R$ 850,00"
> "Valide o CPF 529.982.247-25"
> "Leia o resource config://demo"
> "Use o prompt revisao-codigo-delphi com este código: ..."

---

## Claude Desktop (SSE legacy)

Edite `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "full-demo-sse": {
      "url": "http://localhost:3031/sse"
    }
  }
}
```

Execute com flag `--sse`:
```
MCP.FullDemo.exe --sse
```

Reinicie o Claude Desktop após editar o arquivo.

---

## Claude Desktop (Stdio - processo gerenciado)

```json
{
  "mcpServers": {
    "full-demo-stdio": {
      "command": "C:\\caminho\\para\\MCP.FullDemo.exe",
      "args": ["--stdio"]
    }
  }
}
```

Com stdio, o Claude Desktop inicia e encerra o processo automaticamente.

---

## Sequência de teste manual

Execute o servidor:
```
MCP.FullDemo.exe
```

Copie os comandos curl do arquivo `mcp_test.http` (seção final) para verificar cada endpoint.

Ou use o VS Code REST Client / JetBrains HTTP Client para executar o arquivo `.http` diretamente.

---

## O que confirma que o MCP está 100% funcional

| Teste | O que verifica |
|---|---|
| Health `/health` retorna `"tools":4,"resources":2,"prompts":2` | Registro correto dos 3 pilares |
| `initialize` retorna `protocolVersion: "2025-03-26"` com capabilities de tools + resources + prompts | Protocolo atualizado |
| `initialize` retorna header `Mcp-Session-Id` | HTTP Streamable funcionando |
| `tools/call calcular-desconto` com `valor: 750` retorna texto com 15% | Tool RTTI executando corretamente |
| `tools/call validar-cpf` com CPF inválido retorna `"isError": true` | TMCPToolResult.Error funcionando |
| `tools/call gerar-relatorio-texto` retorna `content` com 5 itens | Multi-content funcionando |
| `resources/read config://demo` retorna JSON de configuração | Resources funcionando |
| `prompts/get analise-venda` retorna `messages[0].role = "user"` | Prompts funcionando |
| Claude Code reconhece as tools após `claude mcp add` | Integração completa |
