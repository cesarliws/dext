# PR 1 of 3 — Web: UTF-8 for HTML/text/static responses

**Compare:** https://github.com/cesarliws/dext/compare/main...usofm:pr/01-web-utf8-html?expand=1

## Suggested title

`fix(web): UTF-8 charset for HTML, text, and static file responses`

---

## Bug

Non-ASCII text (Arabic, Persian, emoji, etc.) displayed incorrectly in the browser for `Results.Html`, `Results.HtmlFromFile`, and similar responses, even when data was valid UTF-8 in Delphi and in the database.

### Example symptom

- Endpoint returns HTML with mixed-language content.
- Response header: `Content-Type: text/html` **without** `charset=utf-8`.
- Browser guesses a legacy encoding → mojibake.

### Example code (call sites unchanged)

```pascal
Result := Results.Html(Html);
Results.HtmlFromFile('login.html').Execute(Context);
```

---

## Root cause

1. `Results.Html` / `Text` / `HtmlFromFile` did not append `; charset=utf-8`.
2. **Indy:** `TIndyHttpResponse.Write(string)` only defaulted to UTF-8 when `Content-Type` was empty; for `text/html` it did not add charset.
3. Static file MIME map omitted charset for text-like types.

---

## Changes

| File | Summary |
|------|---------|
| `Dext.Web.Results.pas` | `charset=utf-8` on HTML/text; UTF-8 file read; safer “view not found” snippet. |
| `Dext.Web.Indy.pas` | Append `charset=utf-8` for `text/*` when missing. |
| `Dext.Web.StaticFiles.pas` | `charset=utf-8` on html, css, js, json, xml, txt. |

---

## Verify

Inspect response headers: `Content-Type: text/html; charset=utf-8`. Confirm correct rendering for non-Latin text.
