# Web.Htmx4Demo — HTMX 4 multi-target partials

Dext + HTMX 4 (`Dext.Web.Htmx4`) demo served by the native server engine.

## Run

```text
dot: build Examples\07-UseCases\Web.Htmx4Demo\Web.Htmx4Demo.dproj (Win32) and run
URL: http://localhost:5299/
```

## What it shows

- `GET /` — dashboard page loading htmx 4 from the CDN.
- `GET /invoices` — branches on `Htmx4.Request(Context).IsPartial`:
  - **partial** (default element target): one response with two `<hx-partial>`
    elements — `hx-target="#invoice-grid"` (with default swap) and the
    `id="invoice-count"` shorthand. Both targets update from a single response.
  - **full** (`hx-target="body"` sends `HX-Request-Type: full`): the whole page.
- `GET /invoices/append` — appends a row with `hx-swap="beforeend"` and refreshes
  the counter, again with two partials in one response.

## Known limitation

Direct navigation to `/invoices` (a request **without** `HX-Request`, e.g. typing
the URL in the address bar) currently raises `Key not found in dictionary`
instead of rendering the full page: `THtmx4Request.GetHeader` uses the
`Headers[AName]` indexer, which throws for missing keys. HTMX-triggered requests
always send `HX-Request` and `HX-Request-Type`, so all three buttons above work.

Sources: <https://four.htmx.org/docs/>, <https://four.htmx.org/reference/headers/HX-Request-Type>
