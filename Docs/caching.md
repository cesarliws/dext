# Response Caching - Dext Framework

Sistema de cache de respostas HTTP com arquitetura plugável para suportar diferentes backends (Memória, Redis, etc.).

## 💾 O que é Response Caching?

Response Caching armazena respostas HTTP para reutilizá-las em requisições subsequentes, reduzindo:

- **Latência**: Respostas instantâneas do cache
- **Carga no Servidor**: Menos processamento
- **Uso de Banco de Dados**: Menos queries
- **Custos**: Menos recursos computacionais

## 📦 Recursos

- ✅ **Interface Plugável** (`ICacheStore`) para diferentes backends
- ✅ **In-Memory Cache** (padrão) - Zero configuração
- ✅ **Redis Support** (futuro) - Cache distribuído
- ✅ **Builder Fluente** para configuração elegante
- ✅ **Vary By** - Query, Headers
- ✅ **Headers Padrão** - Cache-Control, X-Cache
- ✅ **Thread-Safe** com `TCriticalSection`
- ✅ **Auto-Cleanup** de entradas expiradas

## 🏗️ Arquitetura Plugável

### Interface ICacheStore

```pascal
ICacheStore = interface
  function TryGet(const Key: string; out Value: string): Boolean;
  procedure SetValue(const Key, Value: string; DurationSeconds: Integer);
  procedure Remove(const Key: string);
  procedure Clear;
end;
```

### Implementações Disponíveis

| Store | Status | Uso | Escalabilidade |
|-------|--------|-----|----------------|
| **TMemoryCacheStore** | ✅ Disponível | Single instance | Limitado pela RAM |
| **TRedisCacheStore** | 🔜 Futuro | Multi-instance | Distribuído |
| **Custom** | ✅ Você implementa | Qualquer | Depende da impl. |

## 🚀 Uso Básico

### 1. Cache Padrão (In-Memory)

```pascal
uses
  Dext.Caching;

var
  App: IWebApplication;
begin
  App := TDextApplication.Create;
  var Builder := App.GetApplicationBuilder;

  // ✅ 60 segundos de cache (padrão)
  TApplicationBuilderCacheExtensions.UseResponseCache(Builder);

  // ... configurar rotas ...

  App.Run(8080);
end;
```

### 2. Cache Personalizado

```pascal
// ✅ 30 segundos de cache
TApplicationBuilderCacheExtensions.UseResponseCache(Builder, 30);

// ✅ Com builder fluente
TApplicationBuilderCacheExtensions.UseResponseCache(Builder,
  procedure(Cache: TResponseCacheBuilder)
  begin
    Cache
      .WithDefaultDuration(60)
      .WithMaxSize(1000)
      .VaryByQueryString
      .ForMethods(['GET', 'HEAD']);
  end);
```

### 3. Cache com Redis (Futuro)

```pascal
uses
  Dext.Caching.Redis;

var
  RedisStore: ICacheStore;
begin
  // Criar store Redis
  RedisStore := TRedisCacheStore.Create('localhost', 6379);

  // Usar Redis como backend
  TApplicationBuilderCacheExtensions.UseResponseCache(Builder,
    procedure(Cache: TResponseCacheBuilder)
    begin
      Cache
        .WithDefaultDuration(300)
        .WithStore(RedisStore);  // ← Cache distribuído!
    end);
end;
```

## 🎯 Exemplos Práticos

### Exemplo 1: API de Dados Estáticos

```pascal
// Cache longo para dados que mudam raramente
TApplicationBuilderCacheExtensions.UseResponseCache(Builder,
  procedure(Cache: TResponseCacheBuilder)
  begin
    Cache
      .WithDefaultDuration(3600)  // 1 hora
      .WithMaxSize(500);
  end);
```

### Exemplo 2: API com Paginação

```pascal
// Vary by query para cachear cada página separadamente
TApplicationBuilderCacheExtensions.UseResponseCache(Builder,
  procedure(Cache: TResponseCacheBuilder)
  begin
    Cache
      .WithDefaultDuration(300)   // 5 minutos
      .VaryByQueryString;          // Cada ?page=X tem seu cache
  end);
```

### Exemplo 3: API Multilíngue

```pascal
// Vary by Accept-Language header
TApplicationBuilderCacheExtensions.UseResponseCache(Builder,
  procedure(Cache: TResponseCacheBuilder)
  begin
    Cache
      .WithDefaultDuration(600)
      .VaryByHeader(['Accept-Language', 'Accept-Encoding']);
  end);
```

### Exemplo 4: Cache Seletivo por Método

```pascal
// Apenas GET e HEAD (padrão é seguro)
TApplicationBuilderCacheExtensions.UseResponseCache(Builder,
  procedure(Cache: TResponseCacheBuilder)
  begin
    Cache
      .WithDefaultDuration(120)
      .ForMethods(['GET', 'HEAD']);  // Nunca cachear POST/PUT/DELETE
  end);
```

### Exemplo 5: Custom Cache Store

```pascal
// Implementar seu próprio backend
type
  TMyCustomCacheStore = class(TInterfacedObject, ICacheStore)
  public
    function TryGet(const Key: string; out Value: string): Boolean;
    procedure SetValue(const Key, Value: string; DurationSeconds: Integer);
    procedure Remove(const Key: string);
    procedure Clear;
  end;

// Usar
var CustomStore := TMyCustomCacheStore.Create;
Cache.WithStore(CustomStore);
```

## 📋 Métodos do Builder

| Método | Descrição | Exemplo |
|--------|-----------|---------|
| `WithDefaultDuration(seconds)` | Define duração padrão do cache | `.WithDefaultDuration(60)` |
| `WithMaxSize(size)` | Máximo de entradas (memory store) | `.WithMaxSize(1000)` |
| `VaryByQueryString` | Cachear por query string | `.VaryByQueryString` |
| `VaryByHeader(headers)` | Cachear por headers específicos | `.VaryByHeader(['Accept-Language'])` |
| `ForMethods(methods)` | Métodos HTTP cacheáveis | `.ForMethods(['GET', 'HEAD'])` |
| `WithStore(store)` | Define backend customizado | `.WithStore(RedisStore)` |
| `Build` | Retorna `TResponseCacheOptions` | `.Build` |

## 📊 Headers HTTP

### Headers Adicionados Automaticamente

**Cache HIT (do cache):**
```
X-Cache: HIT
Cache-Control: public, max-age=60
```

**Cache MISS (gerado):**
```
X-Cache: MISS
Cache-Control: public, max-age=60
```

### Como Funciona o Cache Key

```pascal
// Geração da chave de cache
Key = Method + ':' + Path + '?' + QueryString + '|' + Headers

// Exemplos:
'GET:/api/users'
'GET:/api/users?page=1'
'GET:/api/users|Accept-Language=pt-BR'
```

## 🔍 Como Funciona

### 1. Fluxo de Requisição

```
┌─────────────────────────────────────────────┐
│  1. Request chega                            │
│     ↓                                        │
│  2. É cacheável? (GET/HEAD)                  │
│     ├─ Não: Continue pipeline                │
│     └─ Sim: ↓                                │
│  3. Gerar cache key                          │
│     (Method + Path + Query + Headers)        │
│     ↓                                        │
│  4. TryGet(key) do ICacheStore               │
│     ├─ HIT: Retornar resposta cached         │
│     └─ MISS: ↓                               │
│  5. Executar handler                         │
│     ↓                                        │
│  6. Armazenar resposta no cache              │
│     ↓                                        │
│  7. Retornar resposta                        │
└─────────────────────────────────────────────┘
```

### 2. In-Memory Store

```pascal
TMemoryCacheStore = class
private
  FEntries: TDictionary<string, TCacheEntry>;
  FLock: TCriticalSection;
  FMaxSize: Integer;
end;

TCacheEntry = record
  Value: string;
  ExpiresAt: TDateTime;
end;
```

**Características:**
- Thread-safe com `TCriticalSection`
- Cleanup automático de expirados
- Limite de tamanho (LRU-like)

### 3. Redis Store (Futuro)

```pascal
TRedisCacheStore = class
  function TryGet: Boolean;
    // Redis GET command
  
  procedure SetValue;
    // Redis SETEX command
end;
```

**Vantagens:**
- Cache compartilhado entre instâncias
- Persistência opcional
- Escalabilidade horizontal

## 🧪 Testando

### Teste com cURL

```bash
# Primeira requisição (MISS)
curl -I http://localhost:8080/api/data
# X-Cache: MISS

# Segunda requisição (HIT)
curl -I http://localhost:8080/api/data
# X-Cache: HIT

# Após expiração (MISS novamente)
sleep 61
curl -I http://localhost:8080/api/data
# X-Cache: MISS
```

### Teste Vary By Query

```bash
# Cada query string é cacheada separadamente
curl http://localhost:8080/api/users?page=1  # MISS
curl http://localhost:8080/api/users?page=1  # HIT
curl http://localhost:8080/api/users?page=2  # MISS (diferente)
curl http://localhost:8080/api/users?page=2  # HIT
```

### Verificar Headers

```bash
curl -v http://localhost:8080/api/data 2>&1 | grep -i cache

# Saída:
< X-Cache: HIT
< Cache-Control: public, max-age=60
```

## ⚡ Performance

### Benchmarks Estimados

| Cenário | Latência sem Cache | Latência com Cache | Melhoria |
|---------|-------------------|-------------------|----------|
| Query simples | 50ms | < 1ms | **50x** |
| Query complexa | 500ms | < 1ms | **500x** |
| Com joins | 2000ms | < 1ms | **2000x** |

### Características de Performance

| Métrica | In-Memory | Redis |
|---------|-----------|-------|
| **Latência** | < 1ms | 1-5ms |
| **Throughput** | 100k req/s | 50k req/s |
| **Escalabilidade** | Single instance | Multi-instance |
| **Persistência** | ❌ | ✅ (opcional) |

## 🔒 Segurança

### Boas Práticas

1. **Nunca cachear dados sensíveis**
   ```pascal
   // ❌ NÃO cachear
   GET /api/users/{id}/password
   GET /api/admin/secrets
   
   // ✅ OK para cachear
   GET /api/products
   GET /api/public/news
   ```

2. **Apenas métodos seguros**
   ```pascal
   // ✅ Padrão seguro
   Cache.ForMethods(['GET', 'HEAD']);
   
   // ❌ NUNCA cachear
   POST, PUT, DELETE, PATCH
   ```

3. **Vary by usuário para dados privados**
   ```pascal
   // Se cachear dados por usuário
   Cache.VaryByHeader(['Authorization']);
   ```

4. **TTL apropriado**
   ```pascal
   // Dados que mudam frequentemente
   Cache.WithDefaultDuration(30);  // 30 segundos
   
   // Dados estáticos
   Cache.WithDefaultDuration(3600);  // 1 hora
   ```

### Limitações Atuais

- ⚠️ Cache apenas de respostas GET/HEAD
- ⚠️ In-memory não persiste entre restarts
- ⚠️ Não compartilha entre múltiplas instâncias (use Redis)

## 🎯 Roadmap

### Implementado ✅
- [x] Interface `ICacheStore` plugável
- [x] `TMemoryCacheStore` (in-memory)
- [x] Builder fluente
- [x] Vary by query/headers
- [x] Headers Cache-Control e X-Cache
- [x] Thread-safety
- [x] Auto-cleanup

### Próximas Features 🔜
- [ ] `TRedisCacheStore` completo
- [ ] Cache invalidation API
- [ ] Cache tags/groups
- [ ] Conditional requests (ETag, If-Modified-Since)
- [ ] Compression (gzip)
- [ ] Cache warming
- [ ] Metrics/statistics

## 💡 Implementando Custom Store

### Exemplo: Database Cache

```pascal
type
  TDatabaseCacheStore = class(TInterfacedObject, ICacheStore)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    
    function TryGet(const Key: string; out Value: string): Boolean;
    begin
      // SELECT value FROM cache WHERE key = :key AND expires_at > NOW()
    end;
    
    procedure SetValue(const Key, Value: string; DurationSeconds: Integer);
    begin
      // INSERT INTO cache (key, value, expires_at) VALUES (...)
      // ON CONFLICT (key) DO UPDATE ...
    end;
    
    procedure Remove(const Key: string);
    begin
      // DELETE FROM cache WHERE key = :key
    end;
    
    procedure Clear;
    begin
      // DELETE FROM cache
    end;
  end;
```

### Exemplo: File System Cache

```pascal
type
  TFileCacheStore = class(TInterfacedObject, ICacheStore)
  private
    FCacheDir: string;
    function GetFilePath(const Key: string): string;
  public
    constructor Create(const ACacheDir: string);
    
    function TryGet(const Key: string; out Value: string): Boolean;
    begin
      var FilePath := GetFilePath(Key);
      if FileExists(FilePath) then
      begin
        // Check expiration from file timestamp
        // Read file content
      end;
    end;
    
    // ... implementar outros métodos
  end;
```

## 📚 Referências

- [RFC 7234 - HTTP Caching](https://tools.ietf.org/html/rfc7234)
- [MDN - HTTP Caching](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching)
- [Redis Documentation](https://redis.io/docs/)

---

**Desenvolvido com 💾 para o Dext Framework**
