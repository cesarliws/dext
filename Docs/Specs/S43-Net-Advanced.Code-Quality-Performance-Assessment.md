# S43 Net-Advanced - Avaliacao de Qualidade e Desempenho

**Spec avaliada:** [S43-Net-Advanced.md](./S43-Net-Advanced.md)  
**Branch:** `feature/s43-advanced-networking-ssl-tls`  
**Data da avaliacao:** 2026-07-30  
**Metodo:** revisao estatica do codigo, testes, benchmarks e historico de implementacao

## 0. Progresso da implementacao

Legenda:

- `[x]` implementado e com projeto afetado compilando;
- `[~]` implementacao parcial ou aguardando fechamento tecnico;
- `[ ]` ainda nao implementado;
- validacao runtime e carga permanecem separadas, conforme o plano da S43.

### TLS e configuracao

- [x] Corrigir falso sucesso de `SSL_write`.
- [x] Expor estado de IO, erro nativo, bytes pendentes e shutdown no contrato TLS.
- [x] Carregar certificado, cadeia e chave privada no OpenSSL Memory BIO servidor.
- [x] Validar correspondencia entre certificado e chave privada.
- [x] Carregar CA bundle customizado ou trust store padrao.
- [x] Aplicar versoes TLS minima e maxima configuradas.
- [x] Configurar SNI e verificacao de hostname no cliente.
- [x] Implementar ALPN cliente, callback servidor e leitura do protocolo negociado.
- [x] Compartilhar `SSL_CTX` entre engines criadas pelo mesmo provider.
- [x] Corrigir loops TLS do Redis para partial write, drain e leitura completa.
- [x] Reutilizar buffers de rede e plaintext por conexao Redis.
- [x] Propagar configuracao PEM/provider/store/AppId para `TServerEngineOptions`.
- [x] Impedir que `Web.SslDemo` sobrescreva `appsettings.json` existente.
- [x] Remover exigencia de arquivos PEM do demo quando o provider e `HttpSys`.
- [x] Validar binding `http.sys` real no startup.
- [x] Tornar provisionamento CLI configuravel por endpoint, store e AppId.
- [x] Integrar OpenSSL Memory BIO ao `epoll` com handshake event-driven, filas de ciphertext, ALPN e partial I/O.

### WebSocket e Hubs

- [x] Validar RSV, opcode, masking e regras de control frames.
- [x] Rejeitar comprimentos nao canonicos, overflow e payload acima do limite.
- [x] Otimizar unmask removendo `mod` por byte.
- [x] Corrigir envio de ping/pong para nao encapsular um frame como payload binario.
- [x] Trocar buffer fixo de 64 KiB por buffer inicial adaptativo de 8 KiB.
- [x] Remover deslocamento do buffer apos cada frame, usando indices de leitura/escrita.
- [x] Liberar lock global antes de send/close.
- [x] Manter referencias de conexao seguras durante operacoes fora do lock.
- [x] Adicionar fila assíncrona limitada de envio por conexao `http.sys`.
- [x] Implementar receive/send WebSocket com `OVERLAPPED` no IOCP do `http.sys`.
- [x] Fazer conexao WebSocket ociosa devolver o worker IOCP.
- [x] Quebrar ciclos de callbacks no fechamento assíncrono.
- [x] Implementar backpressure por conexao, fechamento de cliente lento e metricas de fila.
- [x] Implementar fragmentacao/continuation WebSocket.
- [x] Implementar validacao UTF-8 estrita para mensagens texto.
- [x] Centralizar keep-alive assíncrono sem loop por conexao.
- [x] Implementar payload WebSocket imutavel compartilhado para broadcast.
- [x] Implementar `permessage-deflate` RFC 7692 com negociacao estrita, RSV1, fragmentacao, pool zlib e limite anti-zip-bomb.
- [x] Implementar MessagePack Hub Protocol, framing VarInt e negociacao por conexao.

### Build e testes

- [x] Corrigir search paths do projeto `Dext.Net.Socket.Tests`.
- [x] Corrigir search paths do projeto `Web.SslDemo`.
- [x] Corrigir search paths do projeto `TestDextHubs`.
- [x] Corrigir search paths do projeto `DextTool`.
- [x] Compilar `Dext.Net.Socket.Tests` Win64 apos mudancas TLS/Redis.
- [x] Compilar `Dext.Web.UnitTests` Win32 apos mudancas WebSocket/IOCP.
- [x] Compilar `Web.SslDemo` Win32 apos mudancas de configuracao.
- [x] Adicionar e compilar handshake OpenSSL cliente-servidor e testes negativos WebSocket.
- [x] Compilar todos os projetos afetados em Debug e Release nas plataformas Windows configuradas.
- [x] Compilar `Dext.Server.Epoll.pas` diretamente com `dcclinux64` sem executar o binario.
- [x] Compilar `Dext.Web.Hubs.Transport.WebSocket.pas` diretamente com `dcclinux64` sem executar o binario.
- [x] Criar matriz final de testes e procedimentos de validacao.
- [x] Adicionar benchmarks de hot path para MessagePack, DEFLATE e WebSocket.

## 1. Resumo executivo

### Reavaliacao apos a implementacao

As correcoes listadas no checklist acima foram implementadas nesta branch e
compiladas nos alvos Windows afetados. O unit `Dext.Server.Epoll.pas` tambem
foi compilado diretamente com `dcclinux64`, sem executar o binario. Isso prova
compilacao e coerencia estrutural, mas nao substitui a validacao HTTPS/WSS
runtime no Linux/PA-Server.

O estado atual e: OpenSSL Memory BIO integrado ao caminho `epoll`, MessagePack
negociavel por conexao e `permessage-deflate` integrado ao WebSocket `http.sys`.
Continuam pendentes a execucao dos testes runtime, stress, benchmarks e a
validacao end-to-end no ambiente Linux.

A S43 estabeleceu contratos importantes e uma direcao arquitetural adequada. A
implementacao agora possui os caminhos funcionais de TLS, WebSocket,
MessagePack e compressao descritos no checklist, mas ainda nao pode ser
classificada como competitiva com Go ou .NET sem os benchmarks controlados.

O principal risco restante nao e uma lacuna declarada de codec, e sim a falta
de validacao runtime de HTTPS/WSS no Linux, stress, interoperabilidade e
medicoes de alocacao/CPU. O `epoll` agora utiliza `IDextTLSEngine`, mas essa
integracao ainda aguarda execucao no ambiente PA-Server.

Classificacao geral:

| Area | Estado atual | Maturidade para producao | Potencial de desempenho |
|---|---|---:|---:|
| Contratos TLS | Boa base | Media | Alto |
| OpenSSL Memory BIO | Integrado; runtime pendente | Media | Alto |
| TLS no Redis | Funcional em cenario restrito | Baixa/Media | Medio |
| HTTPS no `http.sys` | Delegado ao kernel | Media/Alta | Alto |
| HTTPS no `epoll` | Integrado; runtime pendente | Media | Alto |
| WebSocket codec | Funcional basico | Media/Baixa | Medio |
| WebSocket Hub transport | Funcional basico | Baixa/Media | Baixo no desenho atual |
| WSS | Nao validado de ponta a ponta | Baixa | Indeterminado |
| MessagePack | Implementado; interoperabilidade pendente | Media | Alto |
| `permessage-deflate` | Implementado; stress pendente | Media | Depende da carga |
| Benchmarks especificos da S43 | Ausentes | Baixa | Nao demonstrado |

Conclusao: a branch entrega uma fundacao e uma prova de conceito parcial. Ela nao entrega ainda a promessa descrita na spec de TLS nativo "zero-copy/low-allocation", ALPN ou HTTPS/WSS sobre `epoll`.

## 2. Pontos positivos

### 2.1 Separacao entre transporte e TLS

`Dext.Net.Security.pas` define operacoes baseadas em ponteiro e tamanho:

- `EncryptedIncoming`;
- `PlaintextRead`;
- `PlaintextWrite`;
- `EncryptedOutgoing`;
- `DoHandshake`.

Essa fronteira evita obrigar o hot path a trafegar por `TStream`, `TBytes` ou strings. O desenho permite que buffers sejam controlados pelo servidor e pode evoluir para IO assincorno com poucas alocacoes.

### 2.2 Uso de Memory BIO

O uso de `BIO_s_mem` e apropriado para integrar OpenSSL a um event loop como `epoll` ou IOCP. Ele separa a maquina de estados TLS da operacao de socket e permite tratar `WANT_READ` e `WANT_WRITE` sem bloquear threads.

### 2.3 Base eficiente no servidor `epoll`

O servidor existente ja contem mecanismos coerentes com alta concorrencia:

- `epoll` com `EPOLLONESHOT`;
- sockets non-blocking;
- `writev` para header e body;
- `sendfile` para arquivos;
- `TCP_NODELAY`;
- buffers mantidos no contexto da conexao;
- HTTP keep-alive;
- parser que preserva offsets e posterga materializacao de algumas strings.

Os resultados historicos de aproximadamente 6 mil requests/s no WSL2 mostram evolucao real do transporte plaintext. Eles nao medem TLS nem representam ainda comparacao controlada com Go ou ASP.NET Core.

### 2.4 Algumas otimizacoes no codec WebSocket

O encoder de texto possui fast path ASCII e grava diretamente no buffer final. Isso elimina um array UTF-8 intermediario no caso comum de texto ASCII. O encoder binario tambem aloca uma unica saida e copia o payload uma vez.

### 2.5 Uso de pool no `http.sys`

O backend `http.sys` reutiliza contextos, requests, responses e buffers. Como o TLS e processado pelo kernel do Windows, esse backend evita o custo de Memory BIO no processo e deve continuar sendo a referencia de desempenho da plataforma Windows.

## 3. Achados criticos do baseline

Os itens desta secao registram o diagnostico feito antes da implementacao das
otimizacoes. Os pontos ja cobertos pelo checklist inicial foram resolvidos no
codigo atual; as observacoes abaixo permanecem como historico tecnico e nao
devem ser lidas como o estado atual sem considerar a reavaliacao da secao 9.

Os itens desta secao devem ser resolvidos antes de qualquer afirmacao de competitividade ou de producao.

### P0. O engine servidor OpenSSL Memory BIO nao carrega certificado e chave

`TDextOpenSSLTLSEngine.InitOpenSSLEngine` nao chama APIs equivalentes a:

- `SSL_CTX_use_certificate_chain_file`;
- `SSL_CTX_use_PrivateKey_file`;
- `SSL_CTX_check_private_key`.

`CertFile` e `KeyFile` existem em `TDextTLSOptions`, mas nao sao consumidos. Um engine em `tlsmServer` pode ser criado, porem nao consegue completar um handshake TLS de servidor autenticado.

Este achado e especifico do engine nativo `Dext.Net.Security.OpenSSL`, planejado para sockets brutos, `epoll` e IOCP. Ele nao se aplica ao provider OpenSSL do Indy. No caminho Indy, `TWebApplication.Run` le `SslCert`, `SslKey` e `SslRootCert`, cria `TDextIndyOpenSSLHandler` e o handler atribui esses arquivos a `TIdServerIOHandlerSSLOpenSSL.SSLOptions`.

No caminho `.UseNativeServer`, a factory nativa substitui a criacao do servidor Indy. Os arquivos ainda podem ser lidos durante a preparacao de `Run`, mas o `SSLHandler` resultante nao e entregue a `TDextNativeWebServer`. Alem disso, `UseNativeServer` copia da configuracao apenas `UseHttps` e `SslCertHash` para `TServerEngineOptions`; nao copia os caminhos PEM. Portanto, a presenca de `SslCert` e `SslKey` no exemplo nao configura o futuro engine OpenSSL do `epoll`.

Impacto:

- HTTPS/WSS nativo em sockets nao esta implementado;
- o teste que apenas cria o engine servidor nao valida capacidade de servir TLS;
- qualquer benchmark de servidor TLS seria prematuro.

### P0. Nao existia integracao TLS no `epoll` (resolvido)

`Dext.Server.Epoll.pas` nao referencia `Dext.Net.Security`, `IDextTLSEngine` ou `TDextOpenSSLContextProvider`. O event loop recebe bytes diretamente com `recv` e envia plaintext diretamente com `writev`, `send` ou `sendfile`.

Consequencias:

- `UseHttps` nao transforma o backend `epoll` em HTTPS;
- WSS sobre `epoll` tambem nao existe;
- a documentacao que descreve o fluxo Memory BIO no `epoll` representa arquitetura planejada, nao codigo implementado;
- `sendfile` deixa de ser diretamente aplicavel ao corpo quando TLS e processado em user space.

### P0. Configuracao HTTPS nativa nao representa igualmente `http.sys` e `epoll`

O mesmo bloco `Server` e reutilizado para providers com modelos de certificado diferentes:

- Indy/OpenSSL/Taurus consomem `SslCert`, `SslKey` e `SslRootCert`;
- `http.sys` consome um binding previamente registrado no Windows Certificate Store;
- o futuro `epoll` OpenSSL devera consumir os arquivos PEM por meio de `TDextTLSOptions`.

Hoje `UseNativeServer` transporta apenas `UseHttps` e `SslCertHash`. No `http.sys`, `SslCertHash` e somente exibido no log; `RegisterSslBinding` nao cria nem valida o binding do kernel. O comando `dext dev-certs https` cria o binding separadamente com porta `8080` e AppId fixos.

O AppId nao e necessario para o processo aceitar requests por um binding ja existente. Ele e necessario para criar ou atualizar o binding SSL no `http.sys`. Assim, ha duas estrategias validas:

1. manter o binding como etapa administrativa externa e fazer a aplicacao apenas validar se `IP:Port`, thumbprint e store correspondem a configuracao;
2. oferecer provisionamento explicito por CLI, lendo `port`, `certificate hash`, `store`, `AppId` e opcionalmente hostname/IP da configuracao.

Nao e recomendado alterar silenciosamente o binding durante o startup normal da aplicacao, porque a operacao exige privilegios administrativos e modifica estado global do Windows. Para o desenho atual, a pendencia mais segura e tornar o CLI configuravel e adicionar validacao fail-fast no backend `http.sys`.

O exemplo `Web.SslDemo` tambem precisa ser ajustado para refletir essa separacao:

- `EnsureAppSettings` regrava `appsettings.json` a cada execucao conforme os `DEFINE`s;
- somente a secao chamada `Server` e lida automaticamente; secoes como `Server_OpenSSL` funcionam apenas quando renomeadas;
- o demo exige que `SslCert` e `SslKey` existam mesmo com `SslProvider=HttpSys`;
- essa verificacao de arquivos deve valer somente para providers em user space;
- para `HttpSys`, o demo deve verificar o binding do endpoint ou produzir uma mensagem objetiva com o comando de provisionamento.

### P0. Tratamento incorreto de `SSL_write` (resolvido)

Quando `SSL_write` retorna erro ou solicita nova leitura/escrita, `PlaintextWrite` retorna `ACount`:

```pascal
if Result <= 0 then
  Result := ACount;
```

Isso informa ao consumidor que todo o plaintext foi aceito mesmo quando o OpenSSL nao o aceitou. Pode causar perda silenciosa de dados, especialmente em IO non-blocking, renegociacao, backpressure ou buffers BIO cheios.

O contrato precisa distinguir:

- bytes efetivamente consumidos;
- `WANT_READ`;
- `WANT_WRITE`;
- fechamento limpo;
- erro fatal.

### P0. Verificacao de identidade do servidor incompleta (resolvido)

`SSL_VERIFY_PEER` valida a cadeia, mas o codigo nao configura a verificacao do hostname com `SSL_set1_host` ou `X509_VERIFY_PARAM_set1_host`. SNI e configurado, mas SNI nao substitui verificacao de identidade.

Impacto:

- `VerifyServerCertificate=True` nao garante que o certificado pertence ao host acessado;
- existe risco de aceitar certificado valido para outro dominio;
- a configuracao nao e equivalente a clientes maduros de Go ou .NET.

### P0. WebSocket aceitava frames sem validacao suficiente (resolvido)

O decoder:

- ignora RSV1/RSV2/RSV3;
- converte qualquer opcode de quatro bits diretamente para o enum;
- nao exige masking em frames cliente-servidor;
- nao valida limites e regras de control frames;
- nao rejeita comprimentos nao canonicos;
- nao limita tamanho maximo de frame/mensagem;
- converte `UInt64` para `Integer` em alocacao e bytes consumidos;
- nao agrega fragmentos `continuation`;
- nao valida UTF-8 de mensagens texto.

Isso combina risco de interoperabilidade, consumo de memoria controlado pelo cliente e possiveis falhas por overflow. Antes de adicionar `permessage-deflate`, o parser base precisa ser endurecido.

## 4. Achados de alto impacto em eficiencia

### P1. Um `SSL_CTX` era criado por conexao (resolvido)

`TDextOpenSSLContextProvider.CreateEngine` cria `TDextOpenSSLTLSEngine`, e cada engine chama `SSL_CTX_new`, configura trust store e cipher list e depois cria `SSL`.

Em implementacoes maduras:

- `SSL_CTX` e compartilhado por listener/configuracao;
- apenas `SSL` e os BIOs sao criados por conexao;
- certificados, cadeia, trust store, session cache e callbacks ALPN pertencem ao contexto compartilhado.

Criar `SSL_CTX` por conexao aumenta CPU, alocacoes nativas, lock contention interna do OpenSSL e latencia de accept/handshake. Tambem impede uso eficiente de session cache e session tickets.

### P1. ALPN estava apenas no contrato (resolvido no engine; validacao ponta a ponta pendente)

`ALPNProtocols` existe nas opcoes e `GetNegotiatedALPN` existe na interface, mas:

- os protocolos nao sao codificados e enviados pelo cliente;
- nao existe callback de selecao no servidor;
- o protocolo negociado nao e consultado do OpenSSL;
- `FNegotiatedALPN` permanece vazio.

HTTP/2 sobre OpenSSL nativo nao pode ser habilitado no estado atual.

### P1. Opcoes TLS relevantes sao ignoradas

O engine nao aplica:

- `Protocols`;
- `CertFile`;
- `KeyFile`;
- `RootCertFile`;
- `ALPNProtocols`;
- selecao real de provider;
- configuracao de TLS 1.3 cipher suites;
- politica de shutdown.

Tambem ha dependencia estatica de nomes exatos `libssl-3` e `libcrypto-3`; portanto, a descricao de carregamento dinamico e compatibilidade OpenSSL 1.1/3.x nao corresponde ao codigo atual.

### P1. O transporte WebSocket ocupa um worker bloqueado por conexao ativa

`TWebSocketHubTransport.ProcessConnection` executa um loop bloqueante de `Receive`. Mesmo que o servidor HTTP de origem use IOCP ou `epoll`, o transporte Hub nao esta modelado como uma maquina de estados dirigida por eventos.

No backend `http.sys`, isso nao cria literalmente uma nova `TThread` para cada WebSocket. O problema e que o middleware executa dentro de um worker IOCP e permanece nele durante toda a conexao. `TDextHttpSysWebSocketConnection.Receive` chama `HttpReceiveRequestEntityBody` com `pOverlapped=nil`, convertendo a operacao em bloqueante. Na pratica, cada WebSocket ativo ocupa um dos workers disponiveis; quando todos estiverem ocupados, novas requisicoes e completions podem ficar sem capacidade de processamento.

Para dezenas de milhares de conexoes, esse desenho:

- exige muitas threads ou ocupa workers por longos periodos;
- aumenta stack memory e context switches;
- reduz previsibilidade de latencia;
- fica distante do modelo usado por Go e ASP.NET Core.

O objetivo deve ser conexoes WebSocket registradas no event loop, com callbacks de leitura/escrita e fila de saida por conexao.

### P1. Locks globais no transporte e nos grupos

O transporte WebSocket usa um unico `TCriticalSection` para o dicionario de todas as conexoes. `SendAsync` localiza a conexao e chama `Conn.SendAsync` ainda sob o lock global. A conexao, por sua vez, adquire outro lock e pode executar IO bloqueante.

O gerenciador de grupos tambem usa um lock unico para todas as operacoes e materializa arrays dentro da regiao critica.

Sob broadcast ou clientes lentos, isso cria convoy:

- uma conexao lenta pode atrasar outras;
- o throughput nao escala linearmente com cores;
- o tempo de lock cresce com o tamanho dos grupos.

O lookup deve reter uma referencia segura e liberar o lock antes do IO. Para escala maior, usar sharding por hash ou snapshots imutaveis/versionados.

### P1. Buffer WebSocket fixo e movimentacao repetida

Cada conexao aloca um buffer de 64 KiB. Depois de cada frame, bytes remanescentes sao deslocados para o inicio com `Move`.

Problemas:

- 100 mil conexoes representam cerca de 6,1 GiB apenas nesses buffers, sem contar stacks e objetos;
- frames maiores que o espaco livre nao fazem o buffer crescer;
- multiplos frames pequenos podem provocar copias repetidas;
- o decoder aloca e copia um novo `TBytes` para cada payload.

Uma implementacao competitiva deve usar:

- buffer pool com classes de tamanho;
- indices `read`/`write` ou ring buffer;
- parser incremental sobre spans;
- payload emprestado quando sua vida util permitir;
- limite configuravel de frame e mensagem;
- copia apenas quando houver fragmentacao ou retencao assincrona.

### P1. Caminho TLS do Redis tem buffers e fluxo incompletos

O cliente Redis aloca um `TBytes` de 64 KiB por comando e usa o mesmo array para ciphertext e plaintext. Embora `SetLength` repetido possa reutilizar a capacidade, a vida do buffer continua sendo por operacao.

Outros pontos:

- apenas uma chamada a `EncryptedOutgoing` e feita depois de `PlaintextWrite`;
- partial writes nao sao drenados corretamente;
- apenas uma chamada a `PlaintextRead` e feita por pacote recebido;
- plaintext adicional ja disponivel no BIO pode permanecer sem leitura;
- `SSL_ERROR_ZERO_RETURN`, `WANT_READ`, `WANT_WRITE` e erros fatais nao sao propagados;
- o pool cria e conecta uma conexao enquanto segura o lock global;
- o comando RESP e montado com `TStringBuilder`, convertido para `string` e depois para UTF-8.

Esse caminho pode funcionar em comandos pequenos e ambiente controlado, mas ainda nao e um pipeline robusto nem de baixa alocacao.

## 5. CPU, alocacoes e copias por subsistema

### 5.1 OpenSSL

Fluxo planejado por leitura:

```text
socket buffer -> BIO_write -> buffer interno BIO -> SSL_read -> plaintext buffer
```

Fluxo planejado por escrita:

```text
plaintext buffer -> SSL_write -> buffer interno BIO -> BIO_read -> socket buffer
```

Memory BIO nao e zero-copy. Ha pelo menos copias entre os buffers da aplicacao e os buffers internos do BIO/OpenSSL. O termo correto para o desenho atual e "buffer-oriented e de baixa alocacao potencial", desde que os buffers da aplicacao sejam reutilizados.

Otimizações prioritarias:

- contexto compartilhado;
- buffers por conexao vindos de pool;
- `BIO_ctrl_pending` para dimensionar drenagem;
- loops completos de drain/read;
- estado explicito de backpressure;
- TLS session resumption;
- medicao separada de handshake e transferencia persistente.

### 5.2 WebSocket

Envio de texto ASCII:

- uma alocacao do frame final;
- leitura completa da string para calcular tamanho;
- segunda leitura para gravar bytes.

Envio de texto nao ASCII:

- frame final;
- `TBytes` UTF-8 temporario;
- copia para frame.

Recepcao:

- buffer fixo por conexao;
- um `TBytes` novo por frame;
- copia do payload;
- loop byte a byte para unmask com `mod 4`;
- conversao UTF-8 para `string`;
- deslocamento do restante do buffer.

Para reduzir CPU:

- unmask por palavras de 32/64 bits, com fallback para cauda;
- evitar `mod` no loop;
- parse sobre ponteiro/span;
- UTF-8 incremental;
- enviar header e payload por scatter/gather quando TLS nao estiver ativo;
- sob TLS, coalescer de forma controlada conforme tamanho e record strategy.

### 5.3 Hubs JSON

O protocolo atual cria uma arvore `TJSONObject`/`TJSONArray` por mensagem, usa RTTI para objetos e gera uma `string` JSON antes do frame WebSocket.

Esse caminho tem custo alto de:

- objetos pequenos;
- reference counting de strings/interfaces;
- RTTI;
- conversao UTF-16 para UTF-8;
- copia para o frame.

MessagePack reduz bytes, mas nao resolve sozinho essas alocacoes. O novo protocolo deve escrever diretamente em um buffer binario expansivel/poolado e retornar um payload binario, sem construir uma arvore intermediaria.

### 5.4 `epoll`

O plaintext server tem escolhas eficientes, mas a integracao TLS mudara o perfil:

- `sendfile` nao atravessa OpenSSL user-space sem copia;
- `writev` de header/body precisa alimentar `SSL_write_ex`;
- eventos `EPOLLIN` podem gerar `WANT_WRITE`, e `EPOLLOUT` pode gerar `WANT_READ`;
- dados de handshake e aplicacao podem coexistir;
- a fila de ciphertext precisa sobreviver a partial sends.

O TLS deve ser uma maquina de estados por conexao, nao uma chamada sincrona em torno de `recv` e `send`.

## 6. Qualidade dos testes atuais

### Cobertura util

- vetor de handshake RFC 6455;
- roundtrip basico de frames WebSocket;
- criacao de opcoes e providers TLS;
- teste de Redis TLS contra Memurai em ambiente especifico;
- benchmarks plaintext existentes para `http.sys` e `epoll`.

### Lacunas

O teste `OpenSSL_ShouldDriveHandshakeAndEncryptPlaintextPayload` nao completa handshake entre cliente e servidor. Ele aceita qualquer estado nao fatal e depois considera sucesso quando `PlaintextWrite` retorna o tamanho solicitado. Como a implementacao retorna artificialmente `ACount` em caso de erro, esse teste pode passar sem criptografar o payload.

Faltam:

- handshake OpenSSL cliente-servidor inteiramente em memoria;
- certificado valido, invalido, expirado e hostname incorreto;
- partial reads/writes e backpressure;
- close notify e encerramento abrupto;
- ALPN;
- session resumption;
- HTTPS e WSS end-to-end;
- fragmentacao WebSocket;
- frames malformados e limites;
- fuzzing do parser;
- carga prolongada e deteccao de vazamentos;
- benchmark de alocacoes e CPU da S43.

## 7. Arquitetura recomendada

### 7.1 Contexto TLS por listener

Criar um objeto de longa duracao por configuracao/listener:

```text
TDextOpenSSLContext
  -> SSL_CTX compartilhado
  -> certificado, chave, trust store e ALPN
  -> session cache/tickets
  -> cria TDextOpenSSLConnection por socket
```

Cada conexao deve conter apenas:

- `SSL`;
- BIO de entrada e saida;
- estado do handshake/shutdown;
- buffers de rede e aplicacao;
- fila de escrita;
- protocolo ALPN selecionado.

### 7.2 TLS dirigido pelo event loop

O `epoll` deve operar uma maquina de estados:

```text
Accept
  -> TLS handshaking
  -> HTTP/1.1 ou HTTP/2 por ALPN
  -> WebSocket apos upgrade
  -> TLS shutdown
```

Cada evento deve:

1. drenar `recv` ate `EAGAIN`;
2. alimentar o BIO de entrada;
3. executar handshake ou `SSL_read_ex` ate `WANT_READ/WANT_WRITE`;
4. processar plaintext sem bloquear;
5. alimentar `SSL_write_ex` respeitando consumo parcial;
6. drenar ciphertext para uma fila de socket;
7. habilitar `EPOLLOUT` somente quando houver pendencia.

### 7.3 Pipeline binario unificado

Para WebSocket e Hubs, adotar um contrato binario:

```pascal
IHubProtocolBinary = interface
  function TryParse(const AInput: TByteSpan; out AMessage: THubMessage;
    out AConsumed: NativeInt): Boolean;
  function WriteMessage(const AMessage: THubMessage;
    const AWriter: IBufferWriter): Boolean;
end;
```

O protocolo JSON pode usar UTF-8 diretamente e o MessagePack pode escrever bytes no mesmo writer. A separacao texto/binario deve ocorrer no protocolo, nao obrigar todo Hub a passar por `string`.

### 7.4 Filas e backpressure

Cada conexao precisa de:

- limite de bytes pendentes;
- politica de cliente lento;
- single-writer por conexao;
- batch de mensagens pequenas;
- cancelamento e fechamento deterministico.

Broadcast deve preparar o payload uma vez e compartilhar um buffer imutavel com reference counting entre conexoes. Somente o framing/TLS por conexao deve ser individual.

### 7.5 Configuracao de certificados por provider

A configuracao deve separar responsabilidades em vez de tratar todos os providers como se consumissem os mesmos campos.

Para Indy/OpenSSL/Taurus:

- ler `SslCert`, `SslKey` e `SslRootCert`;
- validar existencia e permissao de leitura no startup;
- carregar os arquivos no contexto do provider;
- falhar imediatamente se certificado e chave nao corresponderem.

Para o futuro OpenSSL Memory BIO de `epoll`/IOCP:

- copiar os caminhos PEM de `appsettings.json` para `TDextTLSOptions`;
- criar e configurar um `SSL_CTX` compartilhado por listener;
- carregar cadeia, chave privada e trust store uma unica vez;
- criar somente `SSL` e BIOs por conexao;
- permitir reload atomico do contexto sem interromper conexoes existentes.

Para `http.sys`:

- nao exigir `SslCert` ou `SslKey` no processo servidor;
- considerar o binding do Windows a fonte efetiva do certificado;
- validar no startup o endpoint, thumbprint, store e binding esperados;
- falhar com diagnostico e comando corretivo quando o binding estiver ausente;
- manter criacao/alteracao do binding fora do startup normal.

O CLI de provisionamento deve aceitar ou ler:

- `Port`;
- IP ou hostname do binding;
- `SslCertHash`;
- certificate store;
- `HttpSysAppId`;
- opcao explicita para criar, atualizar ou remover o binding.

`HttpSysAppId` identifica o proprietario administrativo do binding e nao participa do processamento das requisicoes. O valor deve ser usado pelo CLI ou por uma operacao administrativa explicita, nao pelo hot path do servidor.

**Criterio de conclusao:**

- Indy completa handshake usando os arquivos configurados;
- OpenSSL Memory BIO servidor completa handshake com certificado configurado;
- `http.sys` inicia somente quando o binding real corresponde a configuracao;
- o demo nao exige arquivos PEM quando `SslProvider=HttpSys`;
- o demo nao sobrescreve configuracao do usuario durante uma execucao normal.

### 7.6 WebSocket assincorno especializado para `http.sys`

Como o objetivo de produto e usar WebSockets somente sobre `http.sys`, a primeira implementacao eficiente pode ser especializada para esse backend, sem aguardar uma abstracao multiplataforma completa.

O fluxo recomendado e:

```text
http.sys IOCP
  -> conclusao de receive WebSocket
  -> parser incremental de frames
  -> dispatch do Hub
  -> fila de saida por conexao
  -> conclusao de send WebSocket
```

Mudancas necessarias:

- concluir o upgrade no modo opaque apropriado do `http.sys`;
- substituir `Receive` bloqueante por `HttpReceiveRequestEntityBody` com `OVERLAPPED`;
- substituir sends bloqueantes por `HttpSendResponseEntityBody` com `OVERLAPPED`;
- adicionar tipos de operacao WebSocket ao dispatcher IOCP;
- manter uma maquina de estados e no maximo um receive e um send ativos por conexao;
- manter fila limitada de saida e politica para clientes lentos;
- retirar qualquer IO de dentro do lock global de conexoes;
- usar lock apenas para obter uma referencia segura da conexao;
- centralizar keep-alive em timer/scheduler, sem loop ou thread por conexao;
- executar parsing incremental sobre spans.

Politica de buffers recomendada:

- nao reservar 64 KiB por conexao no momento do upgrade;
- alugar buffer inicial de 4 ou 8 KiB somente quando uma leitura for postada;
- manter indices de leitura/escrita ou ring buffer, evitando `Move` do restante;
- crescer por classes de tamanho somente quando necessario;
- devolver buffers grandes ao pool depois da mensagem;
- definir limites de frame, mensagem e fila por conexao.

Para broadcast:

- serializar a mensagem uma unica vez;
- compartilhar payload imutavel entre as conexoes;
- criar apenas o estado de envio individual;
- nunca aguardar um cliente lento segurando o mapa global.

**Criterio de conclusao:**

- nenhuma conexao WebSocket ociosa ocupa um worker;
- nenhum IO WebSocket bloqueia thread;
- nenhum IO ocorre sob lock global;
- buffer ocioso por conexao fica abaixo da meta definida;
- conexoes lentas respeitam backpressure sem afetar as demais;
- testes cobrem partial receive/send, fragmentacao, ping/pong, close e desconexao;
- benchmark mede 1 mil, 10 mil e, se o ambiente permitir, 50 mil conexoes.

## 8. Roadmap para nivel competitivo

### Fase A - Correcao e seguranca

- carregar certificado, cadeia e chave;
- separar configuracao PEM de Indy/OpenSSL da configuracao de binding do `http.sys`;
- tornar o CLI de binding configuravel por endpoint, thumbprint, store e AppId;
- validar o binding `http.sys` no startup sem altera-lo implicitamente;
- verificar correspondencia da chave;
- implementar trust store customizada;
- verificar hostname/IP;
- aplicar versoes TLS;
- implementar estados detalhados de IO;
- corrigir partial reads/writes;
- implementar shutdown;
- endurecer parser WebSocket e adicionar limites;
- criar testes cliente-servidor reais.

**Criterio de saida:** interoperabilidade com `openssl s_client`, `curl`, clientes WebSocket padrao e suites negativas.

### Fase B - Integracao `epoll` HTTPS/WSS

- contexto TLS compartilhado por listener;
- estado TLS por conexao;
- filas non-blocking de ciphertext/plaintext;
- ALPN `h2` e `http/1.1`;
- upgrade WSS sobre o mesmo canal;
- ambiente Linux com Delphi/PA-Server;
- testes end-to-end e stress.

**Criterio de saida:** zero bloqueio do event loop, sem perda de dados em partial IO e estabilidade sob carga prolongada.

### Fase C - WebSocket/Hubs de baixa alocacao

- implementar primeiro o transporte IOCP assincorno especializado para `http.sys`;
- parser incremental baseado em spans;
- buffers poolados/ring buffer;
- fragmentacao;
- filas por conexao e backpressure;
- remover IO sob lock global;
- transporte event-driven;
- protocolo Hub binario;
- MessagePack sem arvore intermediaria.

**Criterio de saida:** alocacoes por mensagem conhecidas e regressao automatizada.

### Fase D - `permessage-deflate`

- negociacao RFC 7692 completa;
- context takeover configuravel;
- pools de estado zlib;
- limites anti-zip-bomb;
- decisao adaptativa de comprimir por tamanho/tipo;
- benchmark de CPU versus bytes economizados.

Compressao nao deve ser habilitada indiscriminadamente. Em LAN, payloads pequenos ou CPU saturada, pode reduzir throughput. O benchmark deve determinar thresholds e defaults.

### Fase E - Benchmark competitivo

Comparar Dext, Go e ASP.NET Core no mesmo host, kernel, OpenSSL, certificado e ferramenta de carga.

Cenarios minimos:

- HTTPS request pequeno com keep-alive;
- HTTPS JSON;
- handshake por segundo sem resumption;
- handshake por segundo com resumption;
- WSS echo de 32 B, 1 KiB e 64 KiB;
- broadcast para 1 mil, 10 mil e 50 mil conexoes;
- MessagePack versus JSON;
- `permessage-deflate` ligado/desligado;
- conexoes lentas e backpressure;
- TLS 1.2 versus TLS 1.3.

Metricas obrigatorias:

- throughput;
- latencia p50, p95, p99 e p99.9;
- CPU total e por core;
- bytes alocados e alocacoes por operacao;
- RSS por conexao;
- context switches;
- syscalls por mensagem;
- bytes copiados estimados;
- erros, reconnects e conexoes recusadas.

## 9. Metas quantitativas iniciais

As metas definitivas devem ser calibradas no hardware oficial. Como guardrails iniciais:

| Metrica | Meta inicial |
|---|---:|
| Alocacoes Delphi no steady-state TLS por read/write | 0 por evento |
| Alocacoes WebSocket de controle | 0 ou buffer poolado |
| Buffer reservado por conexao ociosa | menor que 16 KiB fora do OpenSSL |
| Locks globais no hot path de mensagem | 0 |
| IO bloqueante em worker de `epoll` | 0 |
| Erros em stress de 30 minutos | 0 |
| Regressao aceita de throughput | menor que 5% |
| Regressao aceita de p99 | menor que 10% |

Nao e realista exigir "zero allocation" total do OpenSSL, porque a biblioteca possui suas proprias estruturas e alocacoes nativas. A meta controlavel e zero alocacao Delphi no steady state e amortizacao das alocacoes nativas por conexao/contexto.

## 10. Veredito

A qualidade conceitual da S43 e boa: contratos por buffer, Memory BIO e um backend `epoll` previamente otimizado formam uma base capaz de chegar a um nivel competitivo.

A implementacao agora cobre o caminho funcional de OpenSSL servidor, ALPN e
`epoll` HTTPS com Memory BIO, alem de MessagePack e compressao WebSocket. A
classificacao de producao ainda nao foi atribuida porque faltam os testes
runtime, stress e benchmarks, especialmente WSS/HTTPS no Linux. O caminho
Redis TLS tambem permanece dependente dos testes de interoperabilidade e carga.

Para competir com Go e .NET, a prioridade correta e:

1. correcao e interoperabilidade;
2. event loop TLS completo;
3. backpressure e ausencia de locks globais;
4. reducao de copias e alocacoes;
5. MessagePack e compressao;
6. benchmark comparativo reproduzivel.

Sem as fases 1 a 3, otimizar codecs isolados tera impacto limitado e pode mascarar gargalos maiores de arquitetura.

## 11. Limitacoes desta avaliacao

Esta avaliacao e baseada em inspecao estatica do codigo atual e nos resultados historicos existentes. Nao foram executados benchmarks TLS/WSS nesta revisao, porque:

- nao existe benchmark dedicado da S43;
- o `epoll` TLS foi integrado, mas a validacao Linux depende do ambiente Delphi
  com PA-Server planejado para a etapa final;
- a validacao Linux depende do ambiente Delphi com PA-Server planejado para a etapa final.

Assim, comentarios de CPU, memoria e escalabilidade identificam custos estruturais e riscos provaveis. Numeros comparativos com Go ou .NET somente devem ser publicados depois da criacao e execucao da matriz de benchmark descrita neste documento.
