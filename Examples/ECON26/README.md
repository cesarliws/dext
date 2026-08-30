# ECON26 — projetos de palco

Abra `ECON26.groupproj` no Delphi 13 (`Studio\37.0`). Search path: DCUs em `DextRepository/Output/37.0/$(Platform)/$(Config)`.

Compile o Dext (packages / Sources) **antes**, como no resto da pasta `Examples`.

## Palestra 1 — Faturamento

| Projeto | Porta / o que mostrar |
|---|---|
| `Faturamento.Api` | `http://localhost:5000` · Swagger, `/hello`, GET `/api/products`, POST `/api/orders` |
| `Faturamento.Tests` | Fixture `TPlaceOrderTests` no Test Explorer |

Script da pipeline (ao lado do `.dproj` da API): `Test.ECON26.Faturamento.Api.ps1`. O `Scripts/run_examples.ps1` sobe o exe e roda esse arquivo.

No palco: `ECON26.Faturamento.Api.dpr` (denso + `/hello`) → `Product.pas` → `OrdersController.pas` → testes verdes.

`MapPost('/api/orders')` está comentado porque `MapControllers` já publica a mesma rota. `RequireAuth` no DataAPI também está comentado (sem JWT no projetor); a linha permanece no arquivo.

## Palestra 2 — WebStencils + Dext

Cópia do `Examples/04-Advanced/WebStencilsDemo` com a busca extraída para `ICustomerSearch`.

| Projeto | Porta / o que mostrar |
|---|---|
| `WebStencilsDemo` | `http://localhost:5000/customers` · HTMX |
| `WebStencilsDemo.Tests` | Fixture `TCustomerSearchTests` |

Script da pipeline: `Test.WebStencilsDemo.ps1` (ao lado do demo, não do projeto de testes).

Slide 6: em `Startup.pas`, comente `.AddWebStencils` e ligue `.AddDextTemplating` com `wwwroot/views-native`. Rebuild **só** este demo. Não mexa em `Dext.inc`.

Título na janela: **ECON26 · WebStencils + Dext**.
