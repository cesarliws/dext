# ⚡ Redis Client (Dext.Redis)

Dext includes a native, high-performance Redis client library supporting RESP2 and RESP3 protocols. It features zero-allocation parser optimizations, built-in connection pooling, asynchronous command pipeline via `TAsyncTask`, and concurrency Pub/Sub handling using channels.

## Core Features

- **RESP2/RESP3 Protocols**: Supports the Redis Serialization Protocol, including RESP3 additions like Nulls, Booleans, and Doubles.
- **Connection Pool**: Built-in `TDextRedisConnectionPool` for efficient resource reuse under heavy concurrent loads.
- **Asynchronous Execution**: Fully integrated with Dext's async/await pipeline `TAsyncTask.Run`.
- **Reactive Pub/Sub**: Message dispatching using Dext's thread-safe channels (`IChannel<T>`).
- **RedisJSON Integration**: Serialization and deserialization of Delphi classes directly to/from Redis using `Dext.Json`.

---

## Basic Redis Client Usage (`TDextRedisClient`)

Initialize the client, perform operations, and utilize connection pooling transparently:

```pascal
uses
  System.SysUtils,
  Dext.Net.Redis;

var
  Client: TDextRedisClient;
  Val: string;
  Ok: Boolean;
begin
  // Pool size defaults to 16
  Client := TDextRedisClient.Create('127.0.0.1', 6379, 16);
  try
    // Set a key with 60 seconds expiration
    Ok := Client.SetVal('username', 'Cezar', 60);
    if Ok then
      Writeln('Key set successfully');

    // Get a key
    Val := Client.Get('username');
    Writeln('Username: ', Val);

    // Delete a key
    Client.Del('username');
  finally
    Client.Free;
  end;
end;
```

---

## Asynchronous Commands

Execute commands asynchronously utilizing `TAsyncTask` integration:

```pascal
uses
  Dext.Net.Redis,
  Dext.Threading.Async;

begin
  Client.ExecuteAsync('GET', ['mykey'])
    .OnComplete(procedure(Val: TDextRedisValue)
      begin
        Writeln('Async Result: ', Val.AsString);
      end)
    .Start;
end;
```

---

## Reactive Pub/Sub with Channels

Subscribe to channels reactively using Dext's native non-blocking concurrent channel pipelines:

```pascal
uses
  System.SysUtils,
  Dext.Net.Redis,
  Dext.Collections.Channels;

var
  Chan: IChannel<TDextRedisMessage>;
  Msg: TDextRedisMessage;
begin
  // Subscribe returns a thread-safe IChannel
  Chan := Client.Subscribe('telemetry');

  // Read message (blocks the current thread until a message is received)
  Msg := Chan.Read;
  Writeln('Received message from channel: ', Msg.Channel);
  Writeln('Payload: ', Msg.Payload);
  
  // Publish payload
  Client.Publish('telemetry', 'event_fired');
end;
```

---

## RedisJSON & Dext.Json Integration

Store and retrieve structured objects directly as JSON values:

```pascal
uses
  Dext.Net.Redis;

var
  User, LoadedUser: TUser;
begin
  User := TUser.Create;
  try
    User.Name := 'Alice';
    User.Age := 30;
    
    // Set JSON object
    Client.JsonSet('user:100', '$', User);
    
    // Get JSON object and auto-deserialize
    LoadedUser := Client.JsonGet<TUser>('user:100');
    try
      Writeln('Loaded user: ', LoadedUser.Name);
    finally
      LoadedUser.Free;
    end;
  finally
    User.Free;
  end;
end;
```
