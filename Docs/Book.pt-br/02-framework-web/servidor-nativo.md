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

## Escalonamento de Windows Processor Groups

Em máquinas Windows com alta contagem de núcleos (mais de 64 processadores lógicos), o sistema operacional divide os núcleos da CPU em **Processor Groups** (máximo de 64 núcleos por grupo). Por padrão, um processo é atribuído a apenas um grupo inicial, fazendo com que todos os outros grupos de núcleos fiquem ociosos.

O motor de servidor nativo do Dext resolve esse gargalo implementando o **Agendamento Ciente de Grupos de Processadores** (através da unit `Dext.Threading.ProcessorGroups`):
1. **Descoberta de Topologia**: Detecta automaticamente todos os grupos ativos e o número total de núcleos do sistema através da função `GetSystemLogicalProcessorCount`.
2. **Provisionamento Dinâmico**: Inicializa uma quantidade de threads de trabalho que condiz com o total real de núcleos da máquina (ex. 96 workers em um sistema com 2 grupos de 48 cores) em vez de se limitar ao grupo inicial.
3. **Balanceamento de Afinidade**: Distribui as threads de trabalho de E/S uniformemente em modo Round-Robin entre os grupos e núcleos disponíveis por meio do `SetThreadGroupAffinity` antes do início do loop de processamento.

Isso garante linearidade de escalabilidade e 100% de uso de CPU em todos os grupos de processadores e nós NUMA da máquina.

> [!WARNING]
> No Windows, a execução do servidor através do `http.sys` exige permissões de reserva de URL adequadas. Se você vincular o servidor a todas as interfaces (`0.0.0.0`), o Dext registrará o prefixo curinga forte `http://+:porta/`, que exige a execução da aplicação como Administrador ou a reserva correspondente no namespace de URLs via:
> ```cmd
> netsh http add urlacl url=http://+:5000/ user=Everyone
> ```
