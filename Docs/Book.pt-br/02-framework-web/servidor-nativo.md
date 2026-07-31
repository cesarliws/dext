# Servidor Nativo (High-Performance)

O Dext Framework inclui um motor de servidor HTTP nativo e de alta performance. Este motor ignora adaptadores padrão e se integra diretamente com APIs de alto desempenho do sistema operacional:
- **Windows**: Utiliza a API HTTP do kernel do Windows (`http.sys`) com processamento assíncrono.
- **Linux**: Utiliza chamadas de sistema `epoll` do Linux para loops de eventos de E/S não-bloqueantes.

Ao selecionar o motor nativo, você minimiza a sobrecarga no user-space (espaço do usuário), reduz a troca de contexto e atinge taxas de transferência HTTP e eficiência de recursos próximas ao limite do hardware.

## Principais Benefícios
1. **Integração com Kernel do SO**: O `http.sys` gerencia conexões TCP, handshakes SSL e cache de respostas dentro do próprio kernel do Windows, poupando ciclos de CPU do espaço do usuário.
2. **Parser HTTP Zero-Allocation**: O Dext utiliza um parser incremental altamente otimizado (`TDextIocpHttpParser`) que extrai segmentos de rota e cabeçalhos sem alocações na heap.
3. **Loops de Eventos de Alta Concorrência**: No Linux, o loop epoll gerencia milhares de conexões por thread simultaneamente utilizando sockets não-bloqueantes.

## Configuração

Para ativar o servidor nativo, faça um typecast da sua instância de `IWebHost` para `IWebApplication` e chame `.UseNativeServer`:

```pascal
program MyProject;

{$APPTYPE CONSOLE}

uses
  Dext.WebHost,
  Dext.Web;

var
  Builder: IWebHostBuilder;
  Host: IWebHost;
begin
  Builder := TDextWebHost.CreateDefaultBuilder;

  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/',
        procedure(Context: IHttpContext)
        begin
          Context.Response.Write('Olá do Servidor Nativo!');
        end);
    end);

  Host := Builder.Build;

  // Configura o Dext para usar o motor de servidor nativo HTTP.sys / epoll
  (Host as IWebApplication).UseNativeServer;

  Host.Run;
end.
```

## Opções de Configuração

Você pode ajustar o comportamento do motor nativo usando a estrutura `TServerEngineOptions`:

```pascal
var
  Options: TServerEngineOptions;
begin
  Options := TServerEngineOptions.Create;
  Options.IoThreadCount := 4; // Número de threads de trabalho (padrão é o número de núcleos da CPU)
  Options.QueueLimit := 1000;  // Limite da fila de requisições pendentes
  
  // Aplicar as opções ao inicializar o builder
  // ...
end;
```

## Gerenciamento de Threads com epoll no Linux

No Linux, o Dext implementa uma **Arquitetura Multi-Reactor** de alta performance combinada com balanceamento de carga ao nível de socket.

Em vez de ter uma única thread aceitando conexões e distribuindo-as para threads de trabalho (o que geraria um gargalo de disputa), o Dext distribui os loops de eventos diretamente na camada do sistema operacional:

1. **Multi-Reactor com SO_REUSEPORT**:
   Ao iniciar o servidor, o Dext cria um pool de threads de trabalho (`TDextEpollWorker`) correspondente à contagem de núcleos de CPU do sistema por padrão. Cada thread de trabalho possui sua própria instância isolada do `epoll` (`epoll_create1`) e faz o bind na mesma porta/IP de escuta utilizando a opção de socket `SO_REUSEPORT`. O kernel do Linux se encarrega de balancear as conexões de entrada diretamente entre os loops epoll de cada thread, eliminando a contenção na chamada `accept`.

2. **Loop de Eventos Edge-Triggered e One-Shot**:
   Cada worker thread monitora suas conexões no modo Edge-Triggered (`EPOLLET`) e One-Shot (`EPOLLONESHOT`). Essa combinação garante:
   - Máxima eficiência em notificações do `epoll_wait`.
   - Segurança de threads absoluta: uma vez que um socket cliente dispara um evento e é capturado por um worker, ele não disparará em nenhum outro loop de trabalho até que seja explicitamente rearmado.

3. **Despacho Assíncrono de Requisições**:
   Quando a thread de trabalho termina de ler e fazer o parse completo da requisição HTTP, ela não executa o manipulador da requisição de forma síncrona. Em vez disso, ela despacha a execução da lógica de negócios para o Pool de Threads padrão do Delphi (`TTask.Run`). Isso desacopla totalmente a E/S de rede (Network I/O) da lógica da aplicação, impedindo que requisições lentas ou chamadas bloqueantes a banco de dados travem o loop de rede.

4. **Escrita Assíncrona e Rearme da Conexão**:
   - A thread do pool processa a requisição e gera a resposta HTTP.
   - Caso a resposta não possa ser completamente transmitida em uma única chamada de sistema `writev` não-bloqueante, o restante dos dados é agendado no epoll do worker sob o evento `EPOLLOUT` para ser escrito de forma assíncrona.
   - Assim que a escrita é finalizada, a conexão é rearmada no loop epoll para novas requisições (Keep-Alive) ou é fechada de forma limpa.

5. **Otimizações Avançadas no Kernel do Linux**:
   - **Afinidade de Núcleo (CPU Pinning)**: Vincula cada thread `TDextEpollWorker` a um núcleo físico de CPU dedicado usando `pthread_setaffinity_np` para eliminar trocas de contexto e degradação de cache.
   - **TCP_DEFER_ACCEPT**: Adia o despertar de worker threads até que dados úteis do cliente cheguem, reduzindo desperdício com conexões vazias.
   - **TCP Fast Open (TFO)**: Permite que pacotes SYN iniciais tragam dados de requisição, economizando um RTT.
   - **Transmissão Zero-Copy (sendfile)**: Transmissão de arquivos via `sendfile()` transfere dados diretamente do descritor de arquivo para o descritor de rede no nível do kernel, sem alocar memória em espaço do usuário.
   - **Context Pooling**: Reutiliza instâncias de `TDextEpollContext` a partir de um pool local da thread de trabalho, mitigando fragmentação de heap.
   - **Gerenciamento de Timeouts & Keep-Alive**: Limpeza ativa de sockets inativos (>15s) e configurações finas de keep-alive a nível de kernel para evitar esgotamento de descritores de arquivo.
   - **SO_LINGER e Drenagem**: Encerramento controlado usando a opção `SO_LINGER` para garantir o envio total de pacotes pendentes antes do fechamento.

## Escalonamento de Windows Processor Groups

Em máquinas Windows com alta contagem de núcleos (mais de 64 processadores lógicos), o sistema operacional divide os núcleos da CPU em **Processor Groups** (máximo de 64 núcleos por grupo). Por padrão, um processo é atribuído a apenas um grupo inicial, fazendo com que todos os outros grupos de núcleos fiquem ociosos.

O motor de servidor nativo do Dext resolve esse gargalo implementando o **Agendamento Ciente de Grupos de Processadores** (através da unit `Dext.Threading.ProcessorGroups`):
1. **Descoberta de Topologia**: Detecta automaticamente todos os grupos ativos e o número total de núcleos do sistema através da função `GetSystemLogicalProcessorCount`.
2. **Provisionamento Dinâmico**: Inicializa uma quantidade de threads de trabalho que condiz com o total real de núcleos da máquina (ex. 96 workers em um sistema com 2 grupos de 48 cores) em vez de se limitar ao grupo inicial.
3. **Balanceamento de Afinidade**: Distribui as threads de trabalho de E/S uniformemente em modo Round-Robin entre os grupos e núcleos disponíveis por meio do `SetThreadGroupAffinity` antes do início do loop de processamento.

Isso garante linearidade de escalabilidade e 100% de uso de CPU em todos os grupos de processadores e nós NUMA da máquina.

## Configuração de HTTPS/SSL no Kernel do Windows (`http.sys`)

Ao utilizar o motor nativo `.UseNativeServer` no Windows (`http.sys`), o processamento de criptografia TLS/HTTPS é delegado diretamente para o Kernel do Windows (SChannel), garantindo zero-copy e performance máxima.

No `http.sys`, o Kernel do Windows gerencia os certificados através da loja de certificados do sistema (`LocalMachine\My`).

### Opção 1: Configuração Automatizada via Dext CLI (Recomendado)

Execute a CLI do Dext como Administrador para gerar os certificados, importar as chaves e realizar o binding no Kernel de forma 100% automatizada:

```bash
dext dev-certs https --trust
```

### Opção 2: Configuração Manual via Terminal Administrador

Caso deseje vincular um certificado manual existente à porta no Kernel:

1. **Importar o pacote PKCS#12 (`.pfx`) com Chave Privada:**
   ```powershell
   Import-PfxCertificate -FilePath "server.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password (ConvertTo-SecureString "dba" -AsPlainText -Force)
   ```

2. **Vincular o Thumbprint do Certificado à Porta no Kernel via `netsh`:**
   ```cmd
   netsh http add sslcert ipport=0.0.0.0:8080 certhash=SEU_THUMBPRINT_SHA1 appid={4f3b2c10-8a9b-4d7e-8f12-3456789abcde}
   ```

3. **Verificar os bindings ativos no Kernel:**
   ```cmd
   netsh http show sslcert ipport=0.0.0.0:8080
   ```

---

> netsh http add urlacl url=https://+:8080/ user=Everyone
> ```

---

## 🔒 HTTPS e TLS Nativo no Linux (`epoll` + OpenSSL)

No Linux (WSL2, Ubuntu, Debian ou RHEL), o Dext utiliza o motor **`epoll`** combinado com o **OpenSSL 3.x Memory BIO Engine** de forma totalmente desacoplada, garantindo criptografia TLS zero-copy de alta performance sem depender de proxies reversos (Nginx/HAProxy).

### 1. Pacotes Necessários no Linux

Instale as bibliotecas de desenvolvimento do OpenSSL:

```bash
# Ubuntu / Debian / WSL2
sudo apt update
sudo apt install -y libssl-dev openssl

# RHEL / AlmaLinux / Rocky Linux
sudo dnf install -y openssl-devel openssl
```

### 2. Gerando Certificados de Desenvolvimento com OpenSSL

```bash
# 1. Gerar Chave Privada da CA e Certificado Raiz
openssl req -x509 -newkey rsa:4096 -nodes -keyout ca.key -out ca.crt -days 365 -subj "/CN=Dext Test CA"

# 2. Gerar Chave Privada do Servidor e CSR
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr -subj "/CN=localhost"

# 3. Assinar o Certificado com Extensão SAN (Subject Alternative Name)
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 \
  -extfile <(printf "subjectAltName=DNS:localhost,IP:127.0.0.1")
```

### 3. Código em Pascal (Servidor Nativo Linux)

```pascal
var
  App: IWebApplication;
begin
  App := TWebApplication.Create;

  // No Linux, o Dext ativa automaticamente o epoll com OpenSSL 3.x Memory BIOs
  App.UseNativeServer(
    ServerEngineOptions
      .WithHttps(True)
  );

  App.MapGet('/ping', function(Req: IHttpRequest; Res: IHttpResponse)
  begin
    Res.Send('PONG over HTTPS (Linux epoll)');
  end);

  App.Run(8443);
end.
```

### 4. Testando a Conexão com `curl`

```bash
curl --cacert ca.crt https://localhost:8443/ping
# Resposta esperada: PONG over HTTPS (Linux epoll)
```
