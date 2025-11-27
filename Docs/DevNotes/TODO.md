1. Revisão do Roadmap vs. Código
A maioria dos itens marcados como "Concluído" (✅) realmente existe no código, EXCETO um item crítico:

Configuration: O roadmap marca como concluído:
[x] Configuration: Sistema de configuração (JSON, Environment Variables).
Realidade: Não encontrei arquivos ou interfaces referentes a IConfiguration, IConfigurationBuilder ou suporte a appsettings.json na pasta 
Sources\Core
. Parece que essa feature foi planejada/marcada mas ainda não implementada.
2. Features Faltantes na Comparação (vs ASP.NET Core)
Além do que já está listado no roadmap para v1.1 (Distributed Cache, etc.), notei algumas features importantes do ASP.NET Core que não estão listadas na tabela comparativa nem no roadmap:

WebSockets / SignalR: Essencial para aplicações real-time. É um diferencial grande do ASP.NET Core.
Health Checks: Padrão para microsserviços e orquestradores (K8s). É fácil de implementar e agrega muito valor "Enterprise".
Options Pattern (IOptions<T>): Fortemente ligado à Configuração, permite injetar configurações tipadas.
Background Services (IHostedService): Para tarefas em segundo plano.
3. Sugestão de Próxima Feature
Considerando a visão de ser o "ASP.NET Core para Delphi", minha sugestão forte para a próxima feature é:

👉 Sistema de Configuração (Microsoft.Extensions.Configuration style)

Por que?

Está marcado como "Done" no roadmap, mas falta no código.
É fundamental para qualquer aplicação séria (não hardcodar connection strings, chaves de API, etc.).
Habilita o Options Pattern, que melhora muito a DX.
Permite configurar o Kestrel/Indy (portas, SSL) via JSON sem recompilar.
Plano sugerido:

Criar Dext.Configuration.Interfaces (IConfiguration, IConfigurationSection).
Criar Dext.Configuration.Json (Ler de appsettings.json).
Criar Dext.Configuration.EnvironmentVariables.
Integrar no WebHostBuilder para carregar automaticamente.
O que acha? Devemos focar em Configuration agora para fechar esse gap do roadmap?