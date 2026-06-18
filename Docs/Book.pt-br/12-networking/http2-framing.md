# Camada de Transporte HTTP/2 e HPACK

O Dext fornece uma implementação nativa de alta performance do **protocolo HTTP/2 (RFC 9113)** e compressão de cabeçalhos **HPACK (RFC 7541)**. Esta camada serve de base para o protocolo gRPC (S02) e opera diretamente sobre os engines nativos de sockets (S39).

---

## Arquitetura

A camada de transporte HTTP/2 é dividida em quatro componentes principais:

```
    IDextServerEngine (IOCP / epoll)
                 │
                 ▼ (Bytes Crus)
      TDextHttp2Connection
        ├── THpackDecoder & THpackEncoder (Compressão de Headers)
        ├── TDextHttp2FrameCodec (TryReadFrame / Writers)
        └── TDextHttp2StreamMap (Array Ordenado + Busca Binária)
                 │
                 ▼ (Callback de Requisição Parseada)
            OnRequest / gRPC Handler
```

### 1. Compressor HPACK (`Dext.Http2.Hpack.pas`)
Reduz o tamanho dos cabeçalhos trafegados por meio de:
- **Tabela Estática**: Um array constante com 61 campos pré-definidos de headers comuns (RFC 7541 Apêndice A).
- **Tabela Dinâmica**: Um buffer circular (ring-buffer) local por conexão contendo os cabeçalhos recebidos (evicção FIFO por tamanho em bytes).
- **Codificação Huffman**: Um sistema de descompressão por entropia (totalmente suportado no decoder por meio de uma FSM rápida).

### 2. Codec de Frames (`Dext.Http2.Framing.pas`)
Implementa serialização e análise sem cópia (zero-copy) para os 10 tipos de frames padrão do HTTP/2:
- `DATA` (0x0): Corpo da requisição/resposta.
- `HEADERS` (0x1): Cabeçalhos comprimidos via HPACK.
- `RST_STREAM` (0x3): Cancelamento de stream.
- `SETTINGS` (0x4): Configurações de parâmetros da conexão.
- `PING` (0x6): Verificação de conexão ativa e latência.
- `GOAWAY` (0x7): Encerramento de conexão gracioso ou indicação de erro.
- `WINDOW_UPDATE` (0x8): Controle de fluxo por janela.

### 3. Máquina de Estados de Streams (`Dext.Http2.Stream.pas`)
Gerencia as streams multiplexadas concorrentes (RFC 9113 §5.1), cuidando de:
- **Transições de Estado**: `idle` ➔ `open` ➔ `half-closed` ➔ `closed`.
- **Controle de Fluxo**: Janelas de fluxo individuais por stream (padrão de `65535` bytes).
- **Stream Map**: Armazenamento cache-friendly em array ordenado com busca binária de performance $O(\log n)$ para localização de streams ativos.

### 4. Orquestrador de Conexão (`Dext.Http2.Connection.pas`)
Orquestra o handshake a nível de conexão (validação da Preface do cliente `PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n` + envio inicial de frame `SETTINGS` mútuo) e demultiplexa os frames recebidos.

---

## Compatibilidade com gRPC

O gRPC exige transporte HTTP/2 e baseia-se nas seguintes regras:
1. **Content-Type**: Deve ser `application/grpc`.
2. **Mensagem Prefixada por Tamanho (Length-Prefixed)**: O corpo nos frames `DATA` consiste em um header de 5 bytes (`1 byte flag compressão` + `4 bytes big-endian length`) seguido pelos bytes brutos do Protobuf.
3. **Trailers**: Os códigos de status finais são enviados como metadados adicionais em um frame `HEADERS` final com a flag `END_STREAM` ativada (`grpc-status`, `grpc-message`).

---

## Exemplo de Uso

### Configurando uma Conexão HTTP/2 Manualmente

Exemplo de uso da máquina de conexão alimentada por um loop TCP:

```pascal
var
  Conn: TDextHttp2Connection;
begin
  Conn := TDextHttp2Connection.Create(THttp2ConnectionOptions.Default);
  try
    Conn.OnOutput := procedure(AData: PByte; ALen: Integer)
      begin
        // Envia os bytes brutos para o socket TCP
        Socket.Send(AData, ALen);
      end;

    Conn.OnRequest := procedure(AConn: TObject; AStreamId: Cardinal;
      const AHeaders: TNameValuePairs; const ABody: TBytes)
      var
        ResponseHeaders: TNameValuePairs;
        ResponseBody: TBytes;
      begin
        // Processa requisição
        SetLength(ResponseHeaders, 2);
        ResponseHeaders[0].Name := ':status';      ResponseHeaders[0].Value := '200';
        ResponseHeaders[1].Name := 'content-type'; ResponseHeaders[1].Value := 'application/json';
        
        ResponseBody := TEncoding.UTF8.GetBytes('{"msg": "Hello H2"}');
        Conn.SendResponse(AStreamId, ResponseHeaders, ResponseBody, True);
      end;

    // Loop: alimenta conexão com bytes recebidos
    Conn.Feed(RecvBuffer, BytesRead);
  finally
    Conn.Free;
  end;
end;
```
