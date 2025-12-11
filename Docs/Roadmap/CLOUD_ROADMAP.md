# ☁️ Dext Cloud & Microservices - Roadmap

Este roadmap foca em funcionalidades para construção, orquestração e monitoramento de sistemas distribuídos e microsserviços.

> **Inspiração (.NET Aspire):** Trazer a experiência de desenvolvimento de sistemas distribuídos "Cloud Native" para o Delphi, focando em orquestração local, service discovery e observabilidade unificada.

---

## 🚀 Dext Aspire (Orchestration & Dev Experience)

O objetivo é resolver a complexidade de rodar múltiplos microsserviços, bancos de dados e containers durante o desenvolvimento.

### 1. AppHost (Orchestrator)
Um projeto Delphi "Host" que define e roda a topologia da aplicação.
- [ ] **Dext.AppHost**: Projeto console que orquestra a execução de outros projetos Dext e containers Docker.
  ```delphi
  var
    Redis: IResource;
    Api: IProjectResource;
  begin
    Host := TDistributedApplication.CreateBuilder(Args);
    
    // Define dependências (Containers)
    Redis := Host.AddRedis('cache');
    
    // Define Projetos e injeta dependências (Service Discovery)
    Api := Host.AddProject<TApiProject>('api')
               .WithReference(Redis);
               
    Host.AddProject<TWebProject>('web')
        .WithReference(Api);
        
    Host.Run;
  end;
  ```

### 2. Service Discovery
Resolução automática de endereços entre serviços.
- [ ] **Environment Injection**: Injeção automática de URLs e Connection Strings via variáveis de ambiente (`services__api__http__0`).
- [ ] **HttpClient Factory Integration**: `HttpClient.GetAsync('http://api/users')` resolve automaticamente para a porta correta localmente ou DNS em produção (K8s).

### 3. Developer Dashboard
Um painel web local (rodando junto com o AppHost) para visualizar o estado do sistema.
- [ ] **Unified Logs**: Console logs de todos os serviços agregados em uma única view.
- [ ] **Distributed Traces**: Visualização de traces (OpenTelemetry) mostrando a requisição viajando entre serviços.
- [ ] **Metrics**: Gráficos em tempo real de CPU/Memória/Requests de cada serviço.

---

## 🧩 Cloud Components (Integrations)

Componentes "opinativos" que já vêm configurados com resiliência, health checks e telemetria.

### 1. Message Brokers
- [ ] **Dext.Messaging.RabbitMQ**: Wrapper sobre RabbitMQ com retries, circuit breaker e tracing configurados.
- [ ] **Dext.Messaging.Kafka**: Suporte a Kafka para streaming de eventos.

### 2. Key-Value & Caching
- [ ] **Dext.Redis**: Componente Redis com suporte a Distributed Caching e Data Protection.

### 3. Resilience (Polly-like)
- [ ] **Resilience Pipelines**: Políticas de Retry, Circuit Breaker, Timeout e Rate Limiter aplicáveis a qualquer `IHttpClient` ou operação.
  - *Status*: Rate Limiter já existe no Web Framework, expandir para Client-Side.

---

## 🚢 Deployment & Containerization

### 1. Container Support
- [ ] **Dockerfile Generation**: Geração automática de Dockerfiles otimizados para aplicações Dext (Multi-stage build).
- [ ] **Health Checks**: Endpoints `/health` e `/alive` padronizados para Kubernetes probes.

### 2. Configuration Providers
- [ ] **Kubernetes ConfigMap/Secrets**: Provider para ler configurações diretamente da API do K8s ou montagens de volume.
- [ ] **Consul/Vault**: Integração com HashiCorp Consul e Vault para configuração centralizada.

---

## ⚡ Serverless / Functions (?)

Investigação sobre o suporte a arquiteturas Serverless (FaaS). O Delphi tem grande potencial aqui devido ao baixo "Cold Start" (binário nativo) e baixo consumo de memória.

### 1. AWS Lambda (Custom Runtime)
- [ ] **Dext.Lambda**: Implementação do `bootstrap` Linux que faz polling na AWS Runtime API.
  - Permite rodar binários Delphi nativos como Lambdas.
  - Vantagem: Startup time de milissegundos vs JVM/.NET.

### 2. Azure Functions (Custom Handler)
- [ ] **Dext.AzureFunctions**: Adaptação para rodar como um servidor web leve que responde ao host do Azure Functions.
  - O Dext já é um servidor web, então a adaptação é mínima (apenas mapeamento de triggers).
