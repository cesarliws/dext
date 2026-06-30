# 🌐 Sockets de Baixo Nível (TCP e UDP)

O módulo `Dext.Net` oferece componentes de alto desempenho e não-bloqueantes para comunicação de rede TCP e UDP de baixo nível, projetados para máxima vazão e mínima alocação.

## Servidor TCP (`TDextTcpServer`)

O `TDextTcpServer` é baseado em engines nativas de alto desempenho (IOCP no Windows, Epoll no Linux) e permite processar conexões de forma concorrente e assíncrona.

### Exemplo de Servidor de Echo
```pascal
var
  Server: TDextTcpServer;
begin
  Server := TDextTcpServer.Create;
  try
    // Define o manipulador de dados recebidos
    Server.OnDataSpan :=
      procedure(const AConnection: ITcpConnection; const AData: TByteSpan)
      begin
        // Ecoa os dados de volta para o cliente de forma assíncrona
        AConnection.Send(AData);
      end;

    // Vincula a uma porta randômica ou fixa e inicia o servidor
    Server.Bind('127.0.0.1', 8080);
    Server.Start;
    
    Writeln('Servidor escutando na porta: ', Server.ListenPort);
    Readln;
    Server.Stop;
  finally
    Server.Free;
  end;
end;
```

---

## Cliente TCP (`TDextTcpClient`)

O `TDextTcpClient` é um cliente TCP simples e rápido que suporta operações síncronas com timeout de leitura de forma nativa.

```pascal
var
  Client: TDextTcpClient;
  Buffer: TBytes;
  ReadCount: Integer;
begin
  Client := TDextTcpClient.Create;
  try
    Client.Connect('127.0.0.1', 8080);
    
    // Envia dados
    Client.Send(TBytes.Create($01, $02, $03));
    
    // Recebe com timeout de 2000ms
    SetLength(Buffer, 1024);
    ReadCount := Client.Receive(Buffer, 2000);
    
    Client.Disconnect;
  finally
    Client.Free;
  end;
end;
```

---

## Servidor UDP (`TDextUdpServer`) e Cliente (`TDextUdpClient`)

O módulo UDP expõe a mesma simplicidade com suporte a broadcast e multicast.

```pascal
// Servidor UDP
Server := TDextUdpServer.Create;
Server.OnPacketSpanReceived :=
  procedure(const APacket: TUdpSpanPacket)
  begin
    // Envia resposta para a origem
    Server.SendTo(APacket.RemoteAddress, APacket.RemotePort, APacket.Data);
  end;
Server.Bind('127.0.0.1', 9090);
Server.Start;

// Cliente UDP
Client := TDextUdpClient.Create;
Client.Send('127.0.0.1', 9090, TBytes.Create($01, $02));
```

---

## Desacoplamento de Protocolo (`IConnectionHandler`)

Para expor protocolos proprietários sem overhead de análise HTTP, as engines IOCP/Epoll podem ser associadas diretamente a uma implementação de `IConnectionHandler`.

```pascal
type
  TMyHandler = class(TInterfacedObject, IConnectionHandler)
  public
    procedure OnConnect(const AConnection: IDextTransportConnection);
    procedure OnDisconnect(const AConnection: IDextTransportConnection);
    procedure OnData(const AConnection: IDextTransportConnection; const ASpan: TByteSpan);
    procedure OnError(const AConnection: IDextTransportConnection; AException: Exception);
  end;
```
