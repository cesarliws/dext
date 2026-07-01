# 📑 S49: HTTP QUERY Method Support (RFC 10008)

**Status:** ✅ Implemented  
**Owner:** Cesar Romero & Engineering Team  
**Created:** 2026-06-30  
**Dependencies:** S39 (Native Server Engine), S20 (Fluent REST Evolution)  
**Enables:** Safe, idempotent complex data retrieval with request bodies, caching of query operations, and standard-compliant resource discovery via Accept-Query.

---

## 1. Goal

Implement support for the standardized HTTP `QUERY` method (RFC 10008) across both the client-side (`TRestClient` / `TRestRequest`) and server-side (`IApplicationBuilder` / routing engines) components of the Dext Framework. This enables clients to perform complex read-only queries with structured request bodies (JSON, SQL, GraphQL, etc.) in a safe, idempotent, and cacheable manner, without the URL length limits of `GET` or the semantic misuse of `POST`.

---

## 2. Technical Context & Objectives

Traditionally, web API developers faced a compromise when transmitting complex queries:
* **GET** is safe and idempotent but lacks a request body. Queries must be placed in the URL query string, risking length limits, URL encoding bottlenecks, and exposure in logs.
* **POST** supports a request body but is semantically unsafe and non-idempotent, preventing downstream caching (e.g., CDN and proxy caching).

**RFC 10008** defines the `QUERY` method, which is:
1. **Safe & Idempotent:** Semantically read-only; multiple identical requests yield identical side-effects.
2. **Request Body Enabled:** Allows full structured request payloads.
3. **Cacheable:** Responses can be cached based on both the URI and the request body content (via custom cache-key computation).
4. **Discoverable:** Advertised using the `Accept-Query` response header to list supported media types.

### Objectives
* Extend the client-side Rest Client with `hmQUERY` method enum and fluent methods.
* Implement server-side routing support for the `QUERY` method using `MapQuery`.
* Support the `Accept-Query` header to declare accepted request body formats.
* Integrate query caching using a request body hashing strategy.
* Guarantee high performance and zero-allocation processing of incoming request methods and headers.

---

## 3. Scope & Implementation

### 3.1 Rest Client & Request Executor Changes

We will introduce `hmQUERY` to the `TDextHttpMethod` enum and map the string `"QUERY"` to it.

#### Target File: [Dext.Net.RestClient.pas](file:///c:/dev/Dext/DextRepository/Sources/Net/Dext.Net.RestClient.pas)
* **Modify** `TDextHttpMethod` enum:
  ```pascal
  TDextHttpMethod = (hmGET, hmPOST, hmPUT, hmDELETE, hmPATCH, hmHEAD, hmOPTIONS, hmQUERY);
  ```
* **Modify** the string mapping helper to translate `hmQUERY` to `'QUERY'` and vice-versa:
  ```pascal
  hmQUERY: MethodStr := 'QUERY';
  ```

#### Target File: [Dext.Http.Executor.pas](file:///c:/dev/Dext/DextRepository/Sources/Net/Dext.Http.Executor.pas)
* **Modify** `THttpExecutor.MethodToEnum` to handle the `'QUERY'` method string.

---

### 3.2 Server-Side Routing & Request Pipeline

We will expose mapping methods for `QUERY` across all application builders.

#### Target File: [Dext.Web.Interfaces.pas](file:///c:/dev/Dext/DextRepository/Sources/Web/Dext.Web.Interfaces.pas)
* Add `MapQuery` to `IApplicationBuilder`:
  ```pascal
  function MapQuery(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
  ```

#### Target File: [Dext.Web.Builder.pas](file:///c:/dev/Dext/DextRepository/Sources/Web/Dext.Web.Builder.pas)
* Implement `MapQuery` on `TApplicationBuilder`:
  ```pascal
  function TApplicationBuilder.MapQuery(const Path: string; Handler: TStaticHandler): IApplicationBuilder;
  begin
    Result := MapEndpoint('QUERY', Path, Handler);
  end;
  ```

#### Target File: [Dext.Web.pas](file:///c:/dev/Dext/DextRepository/Sources/Web/Dext.Web.pas)
* Extend `THttpAppBuilderHelper` helper with fluent overloads for `MapQuery` and generic variations (`MapQuery<T>`, `MapQuery<T, TResult>`, etc.).

#### Target File: [Dext.Web.ApplicationBuilder.Extensions.pas](file:///c:/dev/Dext/DextRepository/Sources/Web/Dext.Web.ApplicationBuilder.Extensions.pas)
* Implement `TApplicationBuilderExtensions.MapQuery` static variations.

#### Target File: [Dext.Web.ModelBinding.Extensions.pas](file:///c:/dev/Dext/DextRepository/Sources/Web/Dext.Web.ModelBinding.Extensions.pas)
* Implement `MapQuery<T>` in `TApplicationBuilderWithModelBinding`.

---

### 3.3 Accept-Query Header Negotiation

To declare which media types are supported for `QUERY` requests at a given endpoint, Dext will provide a metadata attribute and fluent configuration to automatically append the `Accept-Query` header on options requests:

```pascal
App.MapQuery('/search', SearchHandler)
   .AcceptsQuery('application/jsonpath', 'application/sql');
```

For endpoints mapped with `MapQuery`, an implicit `OPTIONS` handler response will automatically include `QUERY` in the `Allow` header and the registered query content-types in the `Accept-Query` header.

---

### 3.4 Caching of QUERY Responses

Because `QUERY` is safe and idempotent, responses are cacheable. However, unlike `GET` requests where the URL is the unique cache key, the cache key for `QUERY` must be constructed using both the **Request URI** and the hash of the **Request Body**.

1. When a query response is marked cacheable (e.g. via `Response.Headers.Add('Cache-Control', ...)`), the caching middleware must calculate a hash of the request body.
2. The cache key will be generated using a zero-allocation hashing mechanism (e.g., xxHash or MurmurHash3) over the request body bytes.
3. Key format: `dext:cache:query:[MethodHash]:[URIHash]:[BodyHash]`.

---

## 4. Performance & Design Constraints

### 4.1 Strict Style Rules
To maintain consistency with the Dext codebase, the following coding guidelines must be strictly enforced:
* **No inline variables:** Declare variables inside the `var` block of the function/procedure, never inline.
* **No local variable prefixes:** Do not prefix local variables with the `L` prefix (e.g., use `bodyStream` instead of `LBodyStream`).
* **Loop counter:** If a loop counter variable is named `I`, it must be written in lowercase `i` (e.g., `for i := 0 to count - 1 do`).

### 4.2 High-Performance & Zero-Allocation on Heap
* **Use `TSpan<Char>` and `TSpan<Byte>`:** For parsing request headers, method strings, and hashing request body streams, prefer raw stack-allocated memory or `TSpan` slices.
* **String comparison bottlenecks:** Use case-insensitive methods operating directly on spans to parse the request method. Avoid constructing intermediate strings.
* **Dext Collections:** Never use `System.Generics.Collections` classes (like `TList<T>` or `TDictionary<K,V>`). Always utilize optimized custom `Dext Collections` (such as `TDextList<T>` or custom maps).

---

## 5. Verification Plan

### Automated Tests
* Create a new unit test suite: `WebFrameworkTests.Tests.QueryMethod.pas` in the [Web.FrameworkTests](file:///c:/dev/Dext/DextRepository/Tests/Web.FrameworkTests) project using the native Dext testing library.
* Assert that `QUERY` requests can be sent via `TRestClient` and successfully routed by `TApplicationBuilder`.
* Assert that the `Accept-Query` header is present when querying using `OPTIONS`.
* Test that model binding successfully extracts data from the body of a `QUERY` request.
* Assert that the Cache middleware constructs correct keys for identical query URIs but different request bodies.

### Manual Verification
* Run the benchmark suite to ensure that introducing the `QUERY` method parser inside `THttpExecutor` does not introduce any performance regression for existing `GET`/`POST` requests.
