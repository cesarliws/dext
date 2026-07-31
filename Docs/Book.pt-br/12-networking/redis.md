# ⚡ Cliente Redis (Dext.Redis)

O Dext inclui uma biblioteca cliente nativa e de alta performance para o Redis, suportando os protocolos RESP2 e RESP3. Ele conta com otimizações de parsing zero-allocation, connection pooling integrado, pipelines assíncronos de comandos via `TAsyncTask` e processamento de Pub/Sub concorrente utilizando canais.

## Principais Recursos

- **Protocolos RESP2/RESP3**: Suporte completo ao Redis Serialization Protocol, incluindo novas adições do RESP3 como Nulos, Booleanos e Doubles.
- **Connection Pool**: `TDextRedisConnectionPool` embutido para reutilização eficiente de conexões sob cargas intensas de concorrência.
- **Execução Assíncrona**: Totalmente integrado com a API assíncrona de Dext (`TAsyncTask.Run`).
- **Pub/Sub Reativo**: Entrega de mensagens usando canais seguros para threads do Dext (`IChannel<T>`).
- **Integração RedisJSON**: Serialização e deserialização automática de objetos Delphi diretamente no Redis via `Dext.Json`.

---

## Uso Básico do Cliente Redis (`TDextRedisClient`)

Instancie o cliente, execute operações e utilize o connection pool de forma transparente:

```pascal
uses
  System.SysUtils,
  Dext.Net.Redis;

var
  Client: TDextRedisClient;
  Val: string;
  Ok: Boolean;
begin
  // O tamanho do pool padrão é 16
  Client := TDextRedisClient.Create('127.0.0.1', 6379, 16);
  try
    // Define uma chave com expiração de 60 segundos
    Ok := Client.SetVal('username', 'Cezar', 60);
    if Ok then
      Writeln('Chave criada com sucesso');

    // Recupera uma chave
    Val := Client.Get('username');
    Writeln('Username: ', Val);

    // Remove uma chave
    Client.Del('username');
  finally
    Client.Free;
  end;
end;
```

---

## Conexão Segura SSL/TLS (`TDextTLSOptions`)

O `TDextRedisClient` suporta conexões criptografadas TLS/SSL para instâncias
Redis gerenciadas em nuvem (ex: AWS ElastiCache, Azure Cache for Redis, Redis
Cloud). Para ativar o SSL/TLS, forneça as opções `TDextTLSOptions`:

```pascal
uses
  Dext.Net.Security,
  Dext.Net.Redis;

var
  TLSOptions: TDextTLSOptions;
  Client: TDextRedisClient;
begin
  TLSOptions := TDextTLSOptions.Create(
    True,                 // UseSSL
    'ca.crt',            // RootCertFile
    'client.crt',        // CertFile
    'client.key',        // KeyFile
    ''                   // Hostname override
  );

  Client := TDextRedisClient.Create('redis.cloud.redislabs.com', 6380, TLSOptions, 16);
  try
    Client.SetVal('secure_key', 'dados_criptografados');
  finally
    Client.Free;
  end;
end;
```

---

## Comandos Assíncronos

Execute comandos em segundo plano usando a integração com o `TAsyncTask`:

```pascal
uses
  Dext.Net.Redis,
  Dext.Threading.Async;

begin
  Client.ExecuteAsync('GET', ['mykey'])
    .OnComplete(procedure(Val: TDextRedisValue)
      begin
        Writeln('Resultado Assincrono: ', Val.AsString);
      end)
    .Start;
end;
```

---

## Pub/Sub Reativo com Canais

Inscreva-se em canais de forma reativa usando os pipelines de canais concorrentes do Dext:

```pascal
uses
  System.SysUtils,
  Dext.Net.Redis,
  Dext.Collections.Channels;

var
  Chan: IChannel<TDextRedisMessage>;
  Msg: TDextRedisMessage;
begin
  // Subscribe retorna um canal seguro para threads (IChannel)
  Chan := Client.Subscribe('telemetry');

  // Lê a mensagem (bloqueia a thread atual até que uma mensagem seja recebida)
  Msg := Chan.Read;
  Writeln('Mensagem recebida do canal: ', Msg.Channel);
  Writeln('Conteudo: ', Msg.Payload);
  
  // Publica uma mensagem no canal
  Client.Publish('telemetry', 'event_fired');
end;
```

---

## Integração com RedisJSON & Dext.Json

Grave e recupere objetos complexos diretamente como JSON no Redis:

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
    
    // Salva o objeto como JSON
    Client.JsonSet('user:100', '$', User);
    
    // Recupera o JSON e deserializa automaticamente
    LoadedUser := Client.JsonGet<TUser>('user:100');
    try
      Writeln('Usuario carregado: ', LoadedUser.Name);
    finally
      LoadedUser.Free;
    end;
  finally
    User.Free;
  end;
end;
```

---

## Provedor de Cache Web (`TRedisCacheStore`)

A unit `Dext.Caching.Redis` disponibiliza uma implementacao nativa da interface `ICacheStore` destinada ao Redis.

### Uso Manual
Para operacoes manuais de cache ou acesso direto, instancie o provedor:

```pascal
uses
  System.SysUtils,
  Dext.Caching,
  Dext.Caching.Redis;

var
  Cache: ICacheStore;
  CachedValue: string;
begin
  Cache := TRedisCacheStore.Create('127.0.0.1', 6379, 'senha_se_houver', 0 { database });
  try
    // Armazena um valor com 300 segundos de TTL
    Cache.SetValue('session:token', 'xyz123', 300);
    
    // Recupera o valor
    if Cache.TryGet('session:token', CachedValue) then
      Writeln('Token recuperado: ', CachedValue);
      
    // Remove a chave
    Cache.Remove('session:token');
    
    // Limpa a base de dados
    Cache.Clear;
  finally
    Cache := nil; // Referencia de interface auto-gerenciada
  end;
end;
```

### Registrando Cache de Respostas com Redis

Para ativar o cache global de respostas HTTP usando Redis, registre o `TRedisCacheStore` no pipeline do `TAppBuilder` atraves do `UseResponseCache`:

```pascal
uses
  Dext.Caching,
  Dext.Caching.Redis;

App.UseResponseCache(
  ResponseCacheOptions
    .DefaultDuration(300)
    .Store(TRedisCacheStore.Create('127.0.0.1', 6379))
);
```

Ou use o helper de extensao nativo `.UseRedisCache`:

```pascal
uses
  Dext.Caching.Redis;

App.UseRedisCache('127.0.0.1', 6379, 'senha_se_houver', 0 { database }, 300 { duracao padrao });
```
