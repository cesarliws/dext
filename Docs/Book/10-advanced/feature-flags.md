# Feature Flags and Dynamic Rollouts

Manage application feature toggles and progressive deployment strategies via `IFeatureManager`.

## Core Features

- **Boolean Feature Flags**: Enable or disable features via `appsettings.json` configuration.
- **Built-in Feature Filters**:
  - `Percentage`: Deterministic percentage rollout per user or tenant key.
  - `TimeWindow`: Schedule feature flags between specific start/end timestamps (ISO-8601).
- **Custom Filters**: Implement `IFeatureFilter` to create domain-specific filter logic.

## Code Example

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
      TPair<string, string>.Create('FeatureManagement:NewCheckout', 'True'),
      TPair<string, string>.Create('FeatureManagement:HolidayDiscount:EnabledFor:0', 'TimeWindow'),
      TPair<string, string>.Create('FeatureManagement:HolidayDiscount:EnabledFor:0:Parameters:Start', '2026-12-01T00:00:00Z')
    ])
    .Build;

  FeatureMgr := TFeatureManager.Create(Config);

  if FeatureMgr.IsEnabled('NewCheckout') then
    WriteLn('New Checkout flow enabled!')
  else
    WriteLn('Legacy Checkout in place.');
end;
```
