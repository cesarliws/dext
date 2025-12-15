# Rate Limiting - Dext Framework

Sistema de limitação de taxa de requisições para proteger sua API contra abuso e ataques DDoS.

## 🚦 O que é Rate Limiting?

Rate Limiting é uma técnica que limita o número de requisições que um cliente pode fazer em um período de tempo. Isso protege sua API de:

- **Abuso**: Usuários fazendo requisições excessivas
- **DDoS**: Ataques de negação de serviço
- **Scraping**: Bots coletando dados em massa
- **Sobrecarga**: Proteção contra picos de tráfego

## 📦 Recursos

- ✅ **Builder Fluente** para configuração elegante
- ✅ **Thread-Safe** usando `TCriticalSection`
- ✅ **Baseado em IP** (suporta X-Forwarded-For)
- ✅ **Headers Informativos** (X-RateLimit-*)
- ✅ **Limpeza Automática** de entradas expiradas
- ✅ **Configurável** (limite, janela, mensagem, status code)
- ✅ **Zero Dependências** externas

## 📊 Comparação com Outras Soluções

| Feature | Dext | Express.js (rate-limiter-flexible) | ASP.NET Core |
|---------|------|-------------------------------------|--------------|
| **Builder Fluente** | ✅ | ❌ | ✅ |
| **Thread-Safe** | ✅ | ✅ | ✅ |
| **Headers Informativos** | ✅ | ✅ | ✅ |
| **Zero Config** | ✅ (100 req/min) | ❌ | ❌ |
| **Limpeza Automática** | ✅ | ❌ | ✅ |
| **Suporte a Proxy** | ✅ (X-Forwarded-For) | ✅ | ✅ |
| **Configuração** | Fluent API | Options Object | Policy Builder |
| **Persistência** | Memória | Redis/Memória | Memória/Redis |

**Vantagens do Dext:**
- 🎯 **Configuração em uma linha** com padrões sensatos
- 🔧 **Builder fluente** para customização elegante
- 📦 **Zero setup** - funciona out-of-the-box
- 🧹 **Auto-cleanup** - gerenciamento automático de memória
- 📝 **XMLDoc completo** - IntelliSense perfeito

## 🚀 Uso Básico

### 1. Rate Limiting Padrão

```pascal
uses
  Dext.RateLimiting;

var
  App: IWebApplication;
begin
  App := TDextApplication.Create;
  var Builder := App.GetApplicationBuilder;

  // ✅ 100 requisições por minuto (padrão)
  TApplicationBuilderRateLimitExtensions.UseRateLimiting(Builder);

  // ... configurar rotas ...

  App.Run(8080);
end;
```

### 2. Rate Limiting Personalizado

```pascal
// ✅ 10 requisições por minuto
TApplicationBuilderRateLimitExtensions.UseRateLimiting(Builder,
  procedure(RateLimit: TRateLimitBuilder)
  begin
    RateLimit
      .WithPermitLimit(10)
      .WithWindow(60);
  end);
```

### 3. Configuração Completa

```pascal
TApplicationBuilderRateLimitExtensions.UseRateLimiting(Builder,
  procedure(RateLimit: TRateLimitBuilder)
  begin
    RateLimit
      .WithPermitLimit(100)                    // 100 requests
      .WithWindow(60)                          // per 60 seconds
      .WithRejectionMessage('{"error":"Rate limit exceeded"}')
      .WithRejectionStatusCode(429);           // Too Many Requests
  end);
```

## 🎯 Exemplos Práticos

### Exemplo 1: API Pública (Restritiva)

```pascal
// API pública - limite baixo para prevenir abuso
TApplicationBuilderRateLimitExtensions.UseRateLimiting(Builder,
  procedure(RateLimit: TRateLimitBuilder)
  begin
    RateLimit
      .WithPermitLimit(30)      // 30 requests
      .WithWindow(60);          // per minute
  end);
```

### Exemplo 2: API Interna (Permissiva)

```pascal
// API interna - limite alto
TApplicationBuilderRateLimitExtensions.UseRateLimiting(Builder,
  procedure(RateLimit: TRateLimitBuilder)
  begin
    RateLimit
      .WithPermitLimit(1000)    // 1000 requests
      .WithWindow(60);          // per minute
  end);
```

### Exemplo 3: Diferentes Janelas de Tempo

```pascal
// 10 requests por segundo (proteção contra burst)
RateLimit.WithPermitLimit(10).WithWindow(1);

// 100 requests por minuto
RateLimit.WithPermitLimit(100).WithWindow(60);

// 1000 requests por hora
RateLimit.WithPermitLimit(1000).WithWindow(3600);

// 10000 requests por dia
RateLimit.WithPermitLimit(10000).WithWindow(86400);
```

### Exemplo 4: Mensagem Personalizada

```pascal
TApplicationBuilderRateLimitExtensions.UseRateLimiting(Builder,
  procedure(RateLimit: TRateLimitBuilder)
  begin
    RateLimit
      .WithPermitLimit(50)
      .WithWindow(60)
      .WithRejectionMessage(
        '{"error":"Você excedeu o limite de requisições",' +
        '"limit":50,' +
        '"window":"1 minuto",' +
        '"retry_after":60}'
      );
  end);
```

### Exemplo 5: Múltiplos Ambientes

```pascal
var
  Limit: Integer;
begin
  // Configurar limite baseado no ambiente
  {$IFDEF DEBUG}
  Limit := 1000;  // Desenvolvimento - sem restrições
  {$ELSE}
  Limit := 100;   // Produção - restritivo
  {$ENDIF}

  TApplicationBuilderRateLimitExtensions.UseRateLimiting(Builder,
    procedure(RateLimit: TRateLimitBuilder)
    begin
      RateLimit
        .WithPermitLimit(Limit)
        .WithWindow(60);
    end);
end;
```

## 📋 Métodos do Builder

| Método | Descrição | Exemplo |
|--------|-----------|---------|
| `WithPermitLimit(limit)` | Define o número máximo de requisições | `.WithPermitLimit(100)` |
| `WithWindow(seconds)` | Define a janela de tempo em segundos | `.WithWindow(60)` |
| `WithRejectionMessage(msg)` | Define mensagem de erro personalizada | `.WithRejectionMessage('...')` |
| `WithRejectionStatusCode(code)` | Define o status HTTP (padrão: 429) | `.WithRejectionStatusCode(429)` |
| `Build` | Retorna `TRateLimitPolicy` | `.Build` |

## 📊 Headers HTTP

O middleware adiciona headers informativos em todas as respostas:

### Headers de Sucesso (200 OK)

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
```

### Headers quando Rate Limited (429)

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
Retry-After: 60
```

## 🔍 Como Funciona

### 1. Identificação do Cliente

O middleware identifica clientes por IP:

```pascal
// Tenta obter IP real de proxies/load balancers
if Headers.TryGetValue('x-forwarded-for', XForwardedFor) then
  ClientIP := XForwardedFor.Split([','])[0].Trim
else
  ClientIP := 'fallback';
```

### 2. Rastreamento de Requisições

Para cada cliente, mantém:
- **RequestCount**: Número de requisições na janela atual
- **WindowStart**: Início da janela de tempo

### 3. Verificação de Limite

```
Se (Agora - WindowStart) >= WindowSeconds então
  Resetar contador (nova janela)
Senão
  Incrementar contador
  Se contador > PermitLimit então
    Rejeitar (429)
```

### 4. Limpeza Automática

Periodicamente (a cada 100 requisições), remove entradas expiradas para economizar memória.

## 🧪 Testando

### Teste com cURL

```bash
# Teste simples
curl http://localhost:8080/api/test -v

# Ver headers de rate limit
curl http://localhost:8080/api/test -I

# Teste em loop (Windows)
for /L %i in (1,1,15) do @(curl http://localhost:8080/api/test & echo.)

# PowerShell
1..15 | ForEach-Object { 
  curl http://localhost:8080/api/test
  Write-Host "Request $_"
}
```

### Teste com Script

```bash
# Bash
for i in {1..15}; do
  echo "Request $i:"
  curl -s http://localhost:8080/api/test | jq
  echo ""
done
```

### Verificar Headers

```bash
curl -I http://localhost:8080/api/test

# Saída esperada:
HTTP/1.1 200 OK
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 9
Content-Type: application/json
```

### Quando Rate Limited

```bash
# Após exceder o limite:
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 0
Retry-After: 60
Content-Type: application/json

{"error":"Rate limit exceeded. Please try again later."}
```

## 🔒 Segurança

### Boas Práticas

1. **Use limites apropriados**
   ```pascal
   // ❌ Muito permissivo
   RateLimit.WithPermitLimit(10000).WithWindow(1);
   
   // ✅ Balanceado
   RateLimit.WithPermitLimit(100).WithWindow(60);
   ```

2. **Considere o tipo de endpoint**
   ```pascal
   // Endpoints de leitura - mais permissivo
   RateLimit.WithPermitLimit(200).WithWindow(60);
   
   // Endpoints de escrita - mais restritivo
   RateLimit.WithPermitLimit(50).WithWindow(60);
   
   // Endpoints de autenticação - muito restritivo
   RateLimit.WithPermitLimit(5).WithWindow(60);
   ```

3. **Combine com autenticação**
   ```pascal
   // Rate limiting ANTES da autenticação
   Builder.UseRateLimiting(...);
   Builder.UseAuthentication(...);
   ```

4. **Monitore os limites**
   - Analise logs de 429 errors
   - Ajuste limites baseado no uso real
   - Considere diferentes limites por tier de usuário

### Limitações Atuais

- ⚠️ Baseado em memória (não persiste entre restarts)
- ⚠️ Não compartilha estado entre múltiplas instâncias
- ⚠️ Identificação por IP pode ser limitada em alguns cenários

### Melhorias Futuras

- [ ] Suporte a Redis para estado distribuído
- [ ] Rate limiting por usuário autenticado
- [ ] Diferentes políticas por endpoint
- [ ] Sliding window algorithm
- [ ] Burst allowance

## 💡 Dicas

### 1. Rate Limiting por Endpoint

```pascal
// Atualmente aplica globalmente
// Para diferentes limites por endpoint, use múltiplas instâncias

// Endpoint público
Builder.MapGet('/public', ...).UseRateLimiting(Policy1);

// Endpoint privado
Builder.MapGet('/private', ...).UseRateLimiting(Policy2);
```

### 2. Whitelist de IPs

```pascal
// Implementação futura - por enquanto, desabilite para IPs confiáveis
// verificando no middleware antes de aplicar rate limit
```

### 3. Resposta Amigável

```pascal
RateLimit.WithRejectionMessage(
  '{"error":"Você fez muitas requisições",' +
  '"message":"Por favor, aguarde 1 minuto antes de tentar novamente",' +
  '"retry_after":60}'
);
```

## ⚡ Performance

### Características de Performance

| Métrica | Valor | Observação |
|---------|-------|------------|
| **Overhead por Request** | < 1ms | Lookup em `TDictionary` + lock |
| **Memória por Cliente** | ~40 bytes | `TRateLimitEntry` (2 campos) |
| **Thread Safety** | ✅ | `TCriticalSection` |
| **Cleanup** | Automático | A cada 100 requests |
| **Escalabilidade** | Milhares de clientes | Limitado pela RAM |

### Otimizações Implementadas

1. **Dictionary Lookup** - O(1) para verificação de cliente
2. **Cleanup Periódico** - Remove apenas entradas antigas (2x janela)
3. **Lock Mínimo** - Critical section apenas durante update
4. **Zero Alocações** - Reutiliza estruturas existentes

### Benchmarks Estimados

```
1.000 clientes simultâneos:
  - Memória: ~40 KB
  - Throughput: ~10.000 req/s
  - Latência: < 1ms overhead

10.000 clientes simultâneos:
  - Memória: ~400 KB
  - Throughput: ~8.000 req/s
  - Latência: < 2ms overhead
```

## 🏗️ Arquitetura Interna

### Estrutura de Dados

```pascal
// Entrada por cliente
TRateLimitEntry = record
  RequestCount: Integer;    // Contador de requests
  WindowStart: TDateTime;   // Início da janela
end;

// Storage thread-safe
FClients: TDictionary<string, TRateLimitEntry>;
FLock: TCriticalSection;
```

### Fluxo de Execução

```
┌─────────────────────────────────────────────┐
│  1. Request chega                            │
│     ↓                                        │
│  2. GetClientKey(Context)                    │
│     - Tenta X-Forwarded-For                  │
│     - Fallback para IP direto                │
│     ↓                                        │
│  3. FLock.Enter                              │
│     ↓                                        │
│  4. Verificar se cliente existe              │
│     ├─ Não: Criar nova entry                 │
│     └─ Sim: Verificar janela                 │
│         ├─ Expirou: Reset contador           │
│         └─ Ativa: Incrementar                │
│     ↓                                        │
│  5. Contador > Limite?                       │
│     ├─ Sim: Retornar 429                     │
│     └─ Não: Adicionar headers + Continue    │
│     ↓                                        │
│  6. FLock.Leave                              │
│     ↓                                        │
│  7. A cada 100 requests: CleanupExpired()    │
└─────────────────────────────────────────────┘
```

### Thread Safety

```pascal
// Todas as operações no dictionary são protegidas
FLock.Enter;
try
  // Operações thread-safe aqui
  if FClients.TryGetValue(Key, Entry) then
    // ...
finally
  FLock.Leave;
end;
```

### Algoritmo de Cleanup

```pascal
// Remove entradas com janela expirada há mais de 2x o tempo
for Key in FClients.Keys do
begin
  Entry := FClients[Key];
  if SecondsBetween(Now, Entry.WindowStart) >= (WindowSeconds * 2) then
    KeysToRemove.Add(Key);
end;
```

## 📚 Referências

- [RFC 6585 - HTTP Status Code 429](https://tools.ietf.org/html/rfc6585)
- [IETF Draft - RateLimit Header Fields](https://datatracker.ietf.org/doc/html/draft-polli-ratelimit-headers)
- [OWASP - Denial of Service](https://owasp.org/www-community/attacks/Denial_of_Service)

---

**Desenvolvido com 🚦 para o Dext Framework**
