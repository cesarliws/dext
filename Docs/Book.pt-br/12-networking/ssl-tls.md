# 🔒 Arquitetura SSL/TLS Nativa e Otimizações de Rede (S43)

O Dext Framework oferece um subsistema avançado de **Segurança SSL/TLS Nativo** (`Dext.Net.Security`) e **Otimizações de Protocolo de Rede**, projetado para fornecer criptografia transparente, compactação de alta performance e serialização binária em todas as camadas da aplicação (Web Servers, WebSocket Hubs, Clientes HTTP, Clientes Redis e Sockets TCP assíncronos).

---

## 🎯 Principais Recursos da Spec S43

1. **Abstração Unificada de TLS (`Dext.Net.Security`)**: Interfaces `IDextTLSEngine`, `IDextTLSContextProvider` e `IDextTLSStream` que desacoplam o transporte da criptografia.
2. **Motor OpenSSL 3.x Nativo com Memory BIO (`BIO_s_mem`)**: Handshake e framing TLS assíncrono zero-copy/lock-free para servidores `epoll` (Linux) e `IOCP` (Windows).
3. **Bindings Nativos HTTP.sys e Schannel**: Suporte nativo do Kernel Windows com integração ao Windows Certificate Store sem dependência de DLLs externas.
4. **Ferramenta CLI `dext dev-certs https`**: Geração nativa em Pascal (via CryptoAPI) de certificados X.509 de desenvolvimento com extensão SAN (`localhost`, `127.0.0.1`) e registro no Root Certificate Store.
5. **WebSocket Permessage-Deflate (RFC 7692)**: Compactação transparente de frames WebSocket via zlib com suporte a janela deslizante (sliding window) e negociação de extensões.
6. **Protocolo Binário MessagePack para Hubs**: Serialização binária compacta de alta velocidade (`Dext.Web.Hubs.Protocol.MessagePack.pas`) compatível com SignalR.
7. **Suporte SSL no Cliente Redis (`rediss://`)**: Conexão segura transparente para o `TDextRedisClient`.
8. **REST Client com HTTPS Transparente**: Configuração fluente de SSL e suporte a callbacks de validação customizada (`IgnoreCertificateErrors`, `AllowSelfSigned`).

---

## ⚙️ Configuração via `appsettings.json` e Fluent API

### 1. Servidor Web (`appsettings.json`)
```json
{
    "Server": {
        "Port": 8080,
        "UseHttps": "true",
        "SslProvider": "OpenSSL",
        "SslCert": "server.crt",
        "SslKey": "server.key"
    }
}
```

### 2. Cliente Redis com SSL (`rediss://`)
```pascal
var
  Options: TDextRedisOptions;
  Client: TDextRedisClient;
begin
  Options := TDextRedisOptions.Default;
  Options.Host := '127.0.0.1';
  Options.Port := 6380;
  Options.UseSsl := True;
  Options.SslOptions.Provider := 'OpenSSL';
  
  Client := TDextRedisClient.Create(Options);
  Client.Connect;
end;
```

---

## 🚀 WebSocket Permessage-Deflate & SignalR MessagePack Hub

O Dext habilita automaticamente a otimização de banda para conexões de alta frequência via WebSockets:

```pascal
// Mapeamento do Hub com MessagePack e Permessage-Deflate
App.Builder.MapHub<TChatHub>('/chat', procedure(Options: TDextHubOptions)
begin
  Options.EnableMessagePack := True;
  Options.EnablePermessageDeflate := True;
end);
```

---

## 📊 Performance e Validação

- **Throughput em Carga Pesada**: **32.338+ requisições/segundo** com latência média de **986 microsegundos** sob **32 conexões simultâneas** e consumo de **11 MB de RAM**.
- **Compatibilidade Linux/Windows**: 100% dos testes unitários e de integração aprovados em Linux x86_64 (`epoll` nativo) e Windows (`http.sys`/`IOCP`).
