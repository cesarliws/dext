# Feature Flags e Rollout Dinâmico

Gerencie recursos da aplicação e estratégias de implantação progressiva via `IFeatureManager`.

## Conceitos Principais

- **Feature Flags Booleanas**: Ative/desative recursos diretamente via configuração (`appsettings.json`).
- **Filtros de Feature Incorporados**:
  - `Percentage`: Rollout percentual determinístico por usuário ou tenant.
  - `TimeWindow`: Ativação por janela temporal (início e término em ISO-8601).
- **Atributos de Proteção**: `[FeatureGate('NomeFeature')]` em controllers e handlers.

## Exemplo de Uso

```pascal
uses
  Dext.Configuration.Interfaces,
  Dext.Configuration.Core,
  Dext.FeatureFlags;

var
  Config: IConfiguration;
  FeatureMgr: IFeatureManager;
begin
  Config := TDextConfiguration.New
    .AddValues([
      TPair<string, string>.Create('FeatureManagement:NovoCheckout', 'True'),
      TPair<string, string>.Create('FeatureManagement:DescontoNatal:EnabledFor:0', 'TimeWindow'),
      TPair<string, string>.Create('FeatureManagement:DescontoNatal:EnabledFor:0:Parameters:Start', '2026-12-01T00:00:00Z'),
      TPair<string, string>.Create('FeatureManagement:DescontoNatal:EnabledFor:0:Parameters:End', '2026-12-26T23:59:59Z')
    ])
    .Build;

  FeatureMgr := TFeatureManager.Create(Config);

  if FeatureMgr.IsEnabled('NovoCheckout') then
    WriteLn('Novo checkout ativado!')
  else
    WriteLn('Checkout legado em uso.');
end;
```
