# 📡 MQTT Protocol (Client & Broker Server)

Dext includes a native, high-performance implementation of the **MQTT v3.1.1** pub/sub protocol, optimized for Internet of Things (IoT) applications and microservices.

## Topic Trie Router (`TDextMqttTopicTrie`)

The message routing engine utilizes a high-performance Trie tree structure to match topic subscriptions, fully supporting standard MQTT wildcards:
- `+` (single-level wildcard, e.g., `sensors/+/temp`)
- `#` (multi-level wildcard, e.g., `sensors/#`)

---

## MQTT Broker Server (`TDextMqttServer`)

You can launch a native MQTT broker in Delphi in just a few lines of code.

```pascal
var
  Broker: TDextMqttServer;
begin
  Broker := TDextMqttServer.Create;
  try
    Broker.Bind('0.0.0.0', 1883);
    Broker.Start;
    
    Writeln('MQTT Broker listening on port 1883...');
    Readln;
    
    Broker.Stop;
  finally
    Broker.Free;
  end;
end;
```

---

## MQTT Client (`TDextMqttClient`)

The `TDextMqttClient` allows Delphi applications to publish and subscribe to topics asynchronously.

```pascal
var
  Client: TDextMqttClient;
begin
  Client := TDextMqttClient.Create;
  try
    // Connects asynchronously with auto-ping keepalives
    Client.Connect('127.0.0.1', 1883, 'DelphiAppClient');

    // Register receipt callback
    Client.OnMessageReceived :=
      procedure(const AMessage: TMqttMessage)
      begin
        Writeln('Topic: ', AMessage.Topic);
        Writeln('Payload: ', TEncoding.UTF8.GetString(AMessage.Payload));
      end;

    // Subscribe with wildcards
    Client.Subscribe('sensors/+/temp');

    // Publish data (QoS 0/1 supported)
    Client.Publish('sensors/kitchen/temp', TEncoding.UTF8.GetBytes('24.5'));

    Sleep(5000);
    Client.Disconnect;
  finally
    Client.Free;
  end;
end;
```
