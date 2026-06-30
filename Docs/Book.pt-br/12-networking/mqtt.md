# 📡 Protocolo MQTT (Cliente e Broker Server)

O Dext inclui uma implementação nativa e eficiente do protocolo **MQTT v3.1.1** (mensageria pub/sub), otimizada para internet das coisas (IoT) e microsserviços.

## Árvore de Tópicos (`TDextMqttTopicTrie`)

O roteador de mensagens utiliza uma árvore Trie altamente performática que realiza o matching de tópicos com suporte a wildcards:
- `+` (coringa de nível único, ex: `sensors/+/temp`)
- `#` (coringa multi-nível, ex: `sensors/#`)

---

## Servidor Broker MQTT (`TDextMqttServer`)

Você pode subir seu próprio Broker MQTT nativo no Delphi em poucas linhas de código.

```pascal
var
  Broker: TDextMqttServer;
begin
  Broker := TDextMqttServer.Create;
  try
    Broker.Bind('0.0.0.0', 1883);
    Broker.Start;
    
    Writeln('Broker MQTT rodando na porta 1883...');
    Readln;
    
    Broker.Stop;
  finally
    Broker.Free;
  end;
end;
```

---

## Cliente MQTT (`TDextMqttClient`)

O `TDextMqttClient` permite que suas aplicações Delphi publiquem e se inscrevam em tópicos de maneira assíncrona.

```pascal
var
  Client: TDextMqttClient;
begin
  Client := TDextMqttClient.Create;
  try
    // Conecta de forma assíncrona com keep-alive automático
    Client.Connect('127.0.0.1', 1883, 'DelphiAppClient');

    // Define a callback de mensagens recebidas
    Client.OnMessageReceived :=
      procedure(const AMessage: TMqttMessage)
      begin
        Writeln('Tópico: ', AMessage.Topic);
        Writeln('Payload: ', TEncoding.UTF8.GetString(AMessage.Payload));
      end;

    // Subscreve com suporte a wildcards
    Client.Subscribe('sensors/+/temp');

    // Publica dados (QoS 0/1 suportado)
    Client.Publish('sensors/kitchen/temp', TEncoding.UTF8.GetBytes('24.5'));

    Sleep(5000);
    Client.Disconnect;
  finally
    Client.Free;
  end;
end;
```
