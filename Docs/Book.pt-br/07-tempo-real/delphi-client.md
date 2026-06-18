# Cliente Delphi Hub (Delphi Hub Client)

O Dext Framework oferece um cliente SignalR nativo para Delphi de alta performance, permitindo que aplicações Delphi Desktop (VCL/FMX) ou de console se conectem a servidores Dext Hubs ou servidores ASP.NET Core SignalR compatíveis.

> 📦 **Exemplo**: [Testes do Hub Client](../../../Tests/Hubs/Dext.Web.Hubs.Client.Tests.pas)

## Características Principais

- **Suporte a Múltiplos Transportes**: WebSockets nativos de alta performance e Server-Sent Events (SSE).
- **Negociação Automática**: Negocia o transporte preferencial e formato do protocolo (JSON).
- **Gerenciamento de Threading / Marshaling**: Opção de marshaling automático para a thread principal (UI Thread), facilitando a atualização de controles visuais do VCL/FMX de forma segura.
- **Heartbeat & Ping**: Envio automático de mensagens ping para manter a conexão ativa e detectar desconexões.
- **API Fluente (Fluent Builder)**: Configuração simplificada da conexão.

---

## Configurando e Conectando

Utilize a classe `TDextHubConnectionBuilder` para criar e configurar a conexão.

```pascal
uses
  Dext.Web.Hubs.Client,
  Dext.Web.Hubs.Client.Types;

var
  LConnection: IDextHubConnection;
begin
  LConnection := TDextHubConnectionBuilder.New
    .WithUrl('http://localhost:8080/hubs/chat')
    .WithTransport(ctWebSocket) // Prefere WebSocket (ctWebSocket ou ctServerSentEvents)
    .WithHeader('Authorization', 'Bearer token_aqui') // Headers customizados
    .WithQueryParam('usuarioId', '123') // Parâmetros de query
    .WithUIThreadMarshaling(True) // Redireciona callbacks para a Main Thread (UI)
    .Build;

  // Registrar Callbacks de Status
  LConnection.OnConnected(
    procedure(const AConnectionId: string)
    begin
      ShowMessage('Conectado com ID: ' + AConnectionId);
    end);

  LConnection.OnDisconnected(
    procedure(const AError: Exception)
    begin
      if Assigned(AError) then
        ShowMessage('Desconectado devido a erro: ' + AError.Message)
      else
        ShowMessage('Desconectado de forma limpa.');
    end);

  // Iniciar a Conexão Asincronamente
  LConnection.Start;
end;
```

---

## Recebendo Mensagens do Servidor

Para ouvir eventos/chamadas de métodos disparadas pelo servidor, utilize os métodos `On`.

### 1. Com Argumentos Simples (Overloads Comuns)

```pascal
// Recebendo 1 string do servidor
LConnection.On('ReceberMensagem',
  procedure(const AMessage: string)
  begin
    MemoLog.Lines.Add(AMessage);
  end);

// Recebendo 2 strings do servidor
LConnection.On('ReceberMensagemComplexa',
  procedure(const AUser, AMessage: string)
  begin
    MemoLog.Lines.Add(AUser + ': ' + AMessage);
  end);
```

### 2. Com Argumentos Genéricos ou Complexos

Se o servidor enviar múltiplos argumentos de tipos diferentes, você pode implementar a interface `IHubCallback` para decodificar os valores manualmente.

---

## Enviando Mensagens ao Servidor

### 1. Enviar sem resposta (Fire-and-forget)
Use o método `Send` para invocar um método no servidor sem aguardar retorno.

```pascal
LConnection.Send('EnviarMensagem', ['Usuario_Delphi', 'Olá do Delphi VCL!']);
```

### 2. Invocar esperando resposta (Chamadas com Retorno)
Para chamar métodos que retornam um valor do servidor de forma assíncrona, use o helper genérico estático `TConnectionHelper.Invoke<T>`.

```pascal
TConnectionHelper.Invoke<string>(
  LConnection, 
  'CalcularHash', 
  ['texto_para_hash'],
  procedure(const AResult: string; const AError: Exception)
  begin
    if Assigned(AError) then
      ShowMessage('Erro: ' + AError.Message)
    else
      ShowMessage('Hash calculado: ' + AResult);
  end
);
```

---

## Ciclo de Vida e Fechamento

Para encerrar a conexão e limpar os recursos associados (como sockets e threads de ping/leitura):

```pascal
LConnection.Stop;
```

---

[← Comunicação em Tempo Real](README.md) | [Próximo: Testes →](../08-testes/README.md)
