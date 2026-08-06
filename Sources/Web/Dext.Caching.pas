{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Caching;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Rtti,
  System.DateUtils,
  System.SyncObjs,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.Builder,
  Dext.Web.Interfaces;

type
  /// <summary>
  ///   Interface for pluggable cache storage backends.
  /// </summary>
  ICacheStore = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    
    /// <summary>
    ///   Tries to get a cached value by key.
    /// </summary>
    function TryGet(const AKey: string; out AValue: string): Boolean;
    
    /// <summary>
    ///   Sets a value in the cache with expiration.
    /// </summary>
    procedure SetValue(const AKey: string; const AValue: string; ADurationSeconds: Integer);
    
    /// <summary>
    ///   Removes a specific key from the cache.
    /// </summary>
    procedure Remove(const AKey: string);
    
    /// <summary>
    ///   Clears all cached entries.
    /// </summary>
    procedure Clear;
  end;

  /// <summary>
  ///   Cache entry with expiration time.
  /// </summary>
  TCacheEntry = record
    /// <summary> Cached payload string. </summary>
    Value: string;
    /// <summary> Expiration timestamp in UTC. </summary>
    ExpiresAt: TDateTime;
  end;

  /// <summary>
  ///   Holds full HTTP response state for caching.
  /// </summary>
  TCachedResponse = record
    /// <summary> HTTP status code (e.g. 200 OK). </summary>
    StatusCode: Integer;
    /// <summary> Response Content-Type header value. </summary>
    ContentType: string;
    /// <summary> Captured response body payload. </summary>
    Body: string;
  end;

  /// <summary>
  ///   In-memory cache store implementation (default).
  /// </summary>
  TMemoryCacheStore = class(TInterfacedObject, ICacheStore)
  private
    FEntries: IDictionary<string, TCacheEntry>;
    FLock: TCriticalSection;
    FMaxSize: Integer;
    
    procedure CleanupExpired;
    procedure EnforceMaxSize;
  public
    /// <summary> Initializes a new memory cache store with specified maximum capacity. </summary>
    constructor Create(AMaxSize: Integer = 1000);
    /// <summary> Destroys the memory store and releases critical sections. </summary>
    destructor Destroy; override;
    
    /// <summary> Tries to retrieve a cached value by key. </summary>
    function TryGet(const AKey: string; out AValue: string): Boolean;
    /// <summary> Stores a cached value with duration in seconds. </summary>
    procedure SetValue(const AKey: string; const AValue: string; ADurationSeconds: Integer);
    /// <summary> Removes a cached entry by key. </summary>
    procedure Remove(const AKey: string);
    /// <summary> Clears all cached entries. </summary>
    procedure Clear;
    
    /// <summary> Maximum capacity of cached items before LRU eviction. </summary>
    property MaxSize: Integer read FMaxSize write FMaxSize;
  end;

  /// <summary>
  ///   Response cache configuration options.
  /// </summary>
  TResponseCacheOptions = record
  public
    /// <summary>
    ///   Default cache duration in seconds.
    /// </summary>
    DefaultDuration: Integer;
    
    /// <summary>
    ///   Maximum number of cached entries (for memory store).
    /// </summary>
    MaxSize: Integer;
    
    /// <summary>
    ///   Whether to vary cache by query string.
    /// </summary>
    VaryByQuery: Boolean;
    
    /// <summary>
    ///   Headers to vary cache by.
    /// </summary>
    VaryByHeaders: TArray<string>;
    
    /// <summary>
    ///   HTTP methods to cache (default: GET, HEAD).
    /// </summary>
    CacheableMethods: TArray<string>;
    
    /// <summary>
    ///   Custom cache store (default: TMemoryCacheStore).
    /// </summary>
    CacheStore: ICacheStore;

    /// <summary>
    ///   Creates default cache options.
    /// </summary>
    class function Create(ADuration: Integer = 60): TResponseCacheOptions; static;
  end;

  /// <summary>
  ///   Wrapper for capturing response body for caching purposes.
  /// </summary>
  TResponseCaptureWrapper = class(TInterfacedObject, IHttpResponse)
  private
    FOriginal: IHttpResponse;
    FBodyBuffer: TStringBuilder;
    FStatusCode: Integer;
  public
    /// <summary> Creates a new response capture wrapper wrapping the original HTTP response. </summary>
    constructor Create(AOriginal: IHttpResponse);
    /// <summary> Destroys the response capture wrapper. </summary>
    destructor Destroy; override;
    
    /// <summary> Gets HTMX response wrapper. </summary>
    function GetHtmx: IHtmxResponse;
    /// <summary> Gets response headers collection. </summary>
    function GetHeaders: IStringDictionary;
    
    // IHttpResponse methods
    /// <summary> Gets current status code. </summary>
    function GetStatusCode: Integer;
    /// <summary> Gets Content-Type header. </summary>
    function GetContentType: string;
    /// <summary> Sets status code fluently. </summary>
    function Status(AValue: Integer): IHttpResponse;
    /// <summary> Sets HTTP status code. </summary>
    procedure SetStatusCode(AValue: Integer);
    /// <summary> Sets Content-Type header. </summary>
    procedure SetContentType(const AValue: string);
    /// <summary> Sets Content-Length header. </summary>
    procedure SetContentLength(const AValue: Int64);
    /// <summary> Writes text content to response buffer. </summary>
    procedure Write(const AContent: string); overload;
    /// <summary> Writes byte buffer to response. </summary>
    procedure Write(const ABuffer: TBytes); overload;
    /// <summary> Writes stream content to response. </summary>
    procedure Write(const AStream: TStream); overload;
    /// <summary> Sends UTF-8 encoded JSON. </summary>
    procedure SendJsonUtf8(const AUtf8Json: RawByteString); overload;
    /// <summary> Sends UTF-8 encoded JSON buffer. </summary>
    procedure SendJsonUtf8(const ABuffer: TBytes); overload;
    /// <summary> Gets underlying output stream. </summary>
    function GetOutputStream: TStream;
    /// <summary> Writes raw JSON string. </summary>
    procedure Json(const AJson: string); overload;
    /// <summary> Serializes object to JSON. </summary>
    procedure Json(const AValue: TValue); overload;
    /// <summary> Adds an HTTP response header. </summary>
    procedure AddHeader(const AName, AValue: string);
    /// <summary> Appends a cookie with options. </summary>
    procedure AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions); overload;
    /// <summary> Appends a simple cookie. </summary>
    procedure AppendCookie(const AName, AValue: string); overload;
    /// <summary> Deletes a cookie by name. </summary>
    procedure DeleteCookie(const AName: string);
    /// <summary> Redirects request to target URL. </summary>
    procedure Redirect(const AUrl: string; APermanent: Boolean = False);
    /// <summary> Responds with HTTP 401 Unauthorized. </summary>
    procedure Unauthorized(const AMessage: string = '');
    /// <summary> Responds with HTTP 403 Forbidden. </summary>
    procedure Forbidden(const AMessage: string = '');
    /// <summary> Responds with HTTP 400 Bad Request. </summary>
    procedure BadRequest(const AMessage: string = '');
    /// <summary> Responds with HTTP 404 Not Found. </summary>
    procedure NotFound(const AMessage: string = '');
    /// <summary> Flushes buffered response to client. </summary>
    procedure Flush;
    /// <summary> HTTP status code property. </summary>
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
    /// <summary> Content-Type property. </summary>
    property ContentType: string read GetContentType write SetContentType;

    // TResponseCaptureWrapper specific methods
    /// <summary> Gets the complete captured response body text. </summary>
    function GetCapturedBody: string;
  end;

  /// <summary>
  ///   Middleware that caches HTTP responses.
  /// </summary>
  TResponseCacheMiddleware = class(TMiddleware)
  private
    FOptions: TResponseCacheOptions;
    FStore: ICacheStore;
    
    function IsCacheable(AContext: IHttpContext): Boolean;
    function TryServeFromCache(AContext: IHttpContext; const AKey: string): Boolean;
    procedure CacheResponse(AContext: IHttpContext; const AKey: string; AWrapper: TResponseCaptureWrapper);
  protected
    /// <summary> Generates a unique cache key based on request URI, query string, and headers. </summary>
    function GenerateCacheKey(AContext: IHttpContext): string;
  public
    /// <summary> Creates a new response cache middleware with specified options. </summary>
    constructor Create(const AOptions: TResponseCacheOptions);
    /// <summary> Destroys the response cache middleware. </summary>
    destructor Destroy; override;
    
    /// <summary> Processes request in the pipeline, serving from cache or intercepting response for storage. </summary>
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  /// <summary>
  ///   Fluent builder for creating cache options.
  /// </summary>
  TResponseCacheBuilder = record
  private
    FOptions: TResponseCacheOptions;
    FInitialized: Boolean;
    procedure EnsureInitialized;
  public
    /// <summary>
    ///   Creates a new builder.
    /// </summary>
    class function Create: TResponseCacheBuilder; static;
    
    /// <summary>
    ///   Sets the default cache duration in seconds.
    /// </summary>
    function DefaultDuration(ASeconds: Integer): TResponseCacheBuilder;
    
    /// <summary>
    ///   Sets the maximum cache size (for memory store).
    /// </summary>
    function MaxSize(ASize: Integer): TResponseCacheBuilder;
    
    /// <summary>
    ///   Enables varying cache by query string.
    /// </summary>
    function VaryByQueryString: TResponseCacheBuilder;
    
    /// <summary>
    ///   Adds headers to vary cache by.
    /// </summary>
    function VaryByHeader(const AHeaders: array of string): TResponseCacheBuilder;
    
    /// <summary>
    ///   Sets which HTTP methods should be cached.
    /// </summary>
    function ForMethods(const AMethods: array of string): TResponseCacheBuilder;
    
    /// <summary>
    ///   Sets a custom cache store implementation.
    /// </summary>
    function Store(const AStore: ICacheStore): TResponseCacheBuilder;
    
    /// <summary>
    ///   Builds and returns the cache options.
    /// </summary>
    function Build: TResponseCacheOptions;
    
    /// <summary>
    ///   Implicit conversion to TResponseCacheOptions.
    /// </summary>
    class operator Implicit(const ABuilder: TResponseCacheBuilder): TResponseCacheOptions;
  end;

  /// <summary>
  ///   Delegate for configuring TResponseCacheBuilder via anonymous methods (passed by reference).
  /// </summary>
  TResponseCacheBuilderProc = reference to procedure(var Builder: TResponseCacheBuilder);

  /// <summary>
  ///   Extension methods for adding response caching to the application pipeline.
  /// </summary>
  TApplicationBuilderCacheExtensions = class
  public
    /// <summary>
    ///   Adds response caching with default settings (60 seconds).
    /// </summary>
    class function UseResponseCache(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload; static;
    
    /// <summary>
    ///   Adds response caching with specified duration.
    /// </summary>
    class function UseResponseCache(const ABuilder: IApplicationBuilder; ADurationSeconds: Integer): IApplicationBuilder; overload; static;
    
    /// <summary>
    ///   Adds response caching with custom options.
    /// </summary>
    class function UseResponseCache(const ABuilder: IApplicationBuilder; const AOptions: TResponseCacheOptions): IApplicationBuilder; overload; static;
    
    /// <summary>
    ///   Adds response caching configured with a builder.
    /// </summary>
    class function UseResponseCache(const ABuilder: IApplicationBuilder; AConfigurator: TResponseCacheBuilderProc): IApplicationBuilder; overload; static;

    /// <summary>
    ///   Adds response caching using a fluent builder directly.
    /// </summary>
    class function UseResponseCache(const ABuilder: IApplicationBuilder; const ACacheBuilder: TResponseCacheBuilder): IApplicationBuilder; overload; static;

    /// <summary> Alias for UseResponseCache with default settings. </summary>
    class function UseResponseCaching(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload; static; inline;
    /// <summary> Alias for UseResponseCache with specified duration. </summary>
    class function UseResponseCaching(const ABuilder: IApplicationBuilder; ADurationSeconds: Integer): IApplicationBuilder; overload; static; inline;
    /// <summary> Alias for UseResponseCache with custom options. </summary>
    class function UseResponseCaching(const ABuilder: IApplicationBuilder; const AOptions: TResponseCacheOptions): IApplicationBuilder; overload; static; inline;
    /// <summary> Alias for UseResponseCache with a builder procedure. </summary>
    class function UseResponseCaching(const ABuilder: IApplicationBuilder; AConfigurator: TResponseCacheBuilderProc): IApplicationBuilder; overload; static; inline;
    /// <summary> Alias for UseResponseCache with a fluent builder. </summary>
    class function UseResponseCaching(const ABuilder: IApplicationBuilder; const ACacheBuilder: TResponseCacheBuilder): IApplicationBuilder; overload; static; inline;
  end;

  /// <summary>
  ///   Helper for implicit conversion of TResponseCacheOptions to TValue.
  /// </summary>
  TResponseCacheOptionsHelper = record helper for TResponseCacheOptions
  public
    class operator Implicit(const AValue: TResponseCacheOptions): TValue;
  end;

implementation

uses
  System.Hash,
  Dext.Json;

{ TMemoryCacheStore }

constructor TMemoryCacheStore.Create(AMaxSize: Integer);
begin
  inherited Create;
  FEntries := TCollections.CreateDictionary<string, TCacheEntry>;
  FLock := TCriticalSection.Create;
  FMaxSize := AMaxSize;
end;

destructor TMemoryCacheStore.Destroy;
begin
  // FEntries is ARC
  FLock.Free;
  inherited;
end;

function TMemoryCacheStore.TryGet(const AKey: string; out AValue: string): Boolean;
var
  Entry: TCacheEntry;
begin
  FLock.Enter;
  try
    if FEntries.TryGetValue(AKey, Entry) then
    begin
      // Check if expired
      if Now < Entry.ExpiresAt then
      begin
        AValue := Entry.Value;
        Result := True;
      end
      else
      begin
        // Remove expired entry
        FEntries.Remove(AKey);
        Result := False;
      end;
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryCacheStore.SetValue(const AKey, AValue: string; ADurationSeconds: Integer);
var
  Entry: TCacheEntry;
begin
  FLock.Enter;
  try
    Entry.Value := AValue;
    Entry.ExpiresAt := IncSecond(Now, ADurationSeconds);
    
    FEntries.AddOrSetValue(AKey, Entry);
    
    // Enforce max size
    if FEntries.Count > FMaxSize then
      EnforceMaxSize;
      
    // Periodic cleanup
    if FEntries.Count mod 100 = 0 then
      CleanupExpired;
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryCacheStore.Remove(const AKey: string);
begin
  FLock.Enter;
  try
    FEntries.Remove(AKey);
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryCacheStore.Clear;
begin
  FLock.Enter;
  try
    FEntries.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryCacheStore.CleanupExpired;
var
  KeysToRemove: IList<string>;
  Key: string;
  Entry: TCacheEntry;
  Now: TDateTime;
begin
  KeysToRemove := TCollections.CreateList<string>;
  try
    Now := System.SysUtils.Now;
    
    for Key in FEntries.Keys do
    begin
      Entry := FEntries[Key];
      if Now >= Entry.ExpiresAt then
        KeysToRemove.Add(Key);
    end;
    
    for Key in KeysToRemove do
      FEntries.Remove(Key);
  finally
    // KeysToRemove is ARC
  end;
end;

procedure TMemoryCacheStore.EnforceMaxSize;
var
  KeysToRemove: IList<string>;
  Key: string;
  RemoveCount: Integer;
begin
  // Remove oldest 10% when max size is exceeded
  RemoveCount := FMaxSize div 10;
  if RemoveCount < 1 then
    RemoveCount := 1;
    
  KeysToRemove := TCollections.CreateList<string>;
  try
    for Key in FEntries.Keys do
    begin
      KeysToRemove.Add(Key);
      if KeysToRemove.Count >= RemoveCount then
        Break;
    end;
    
    for Key in KeysToRemove do
      FEntries.Remove(Key);
  finally
    // KeysToRemove is ARC
  end;
end;

{ TResponseCacheOptions }

class function TResponseCacheOptions.Create(ADuration: Integer): TResponseCacheOptions;
begin
  Result.DefaultDuration := ADuration;
  Result.MaxSize := 1000;
  Result.VaryByQuery := True;
  SetLength(Result.VaryByHeaders, 0);
  Result.CacheableMethods := ['GET', 'HEAD', 'QUERY'];
  Result.CacheStore := nil; // Will use default TMemoryCacheStore
end;

{ TResponseCacheMiddleware }

constructor TResponseCacheMiddleware.Create(const AOptions: TResponseCacheOptions);
begin
  inherited Create;
  FOptions := AOptions;
  
  // Use provided store or create default
  if Assigned(AOptions.CacheStore) then
    FStore := AOptions.CacheStore
  else
    FStore := TMemoryCacheStore.Create(AOptions.MaxSize);
end;

destructor TResponseCacheMiddleware.Destroy;
begin
  FStore := nil;
  inherited;
end;

function TResponseCacheMiddleware.GenerateCacheKey(AContext: IHttpContext): string;
var
  KeyBuilder: TStringBuilder;
  Header: string;
  HeaderValue: string;
  QueryArray: TArray<TPair<string, string>>;
  i: Integer;
  BodyStream: TStream;
  BodyHash: string;
begin
  KeyBuilder := TStringBuilder.Create;
  try
    // Base: Method + Path
    KeyBuilder.Append(AContext.Request.Method);
    KeyBuilder.Append(':');
    KeyBuilder.Append(AContext.Request.Path);
    
    // Vary by query string
    if FOptions.VaryByQuery and (AContext.Request.Query.Count > 0) then
    begin
      KeyBuilder.Append('?');
      QueryArray := AContext.Request.Query.ToArray;
      for i := 0 to High(QueryArray) do
      begin
        if i > 0 then KeyBuilder.Append('&');
        KeyBuilder.Append(QueryArray[i].Key);
        KeyBuilder.Append('=');
        KeyBuilder.Append(QueryArray[i].Value);
      end;
    end;
    
    // Vary by headers
    for Header in FOptions.VaryByHeaders do
    begin
      if AContext.Request.Headers.TryGetValue(LowerCase(Header), HeaderValue) then
      begin
        KeyBuilder.Append('|');
        KeyBuilder.Append(Header);
        KeyBuilder.Append('=');
        KeyBuilder.Append(HeaderValue);
      end;
    end;

    // Vary by body for QUERY requests
    if AContext.Request.Method = 'QUERY' then
    begin
      BodyStream := AContext.Request.Body;
      if (BodyStream <> nil) and (BodyStream.Size > 0) then
      begin
        BodyStream.Position := 0;
        BodyHash := THashSHA1.GetHashString(BodyStream);
        BodyStream.Position := 0;
        KeyBuilder.Append(':');
        KeyBuilder.Append(BodyHash);
      end;
    end;
    
    Result := KeyBuilder.ToString;
  finally
    KeyBuilder.Free;
  end;
end;

function TResponseCacheMiddleware.IsCacheable(AContext: IHttpContext): Boolean;
var
  Method: string;
  CacheableMethod: string;
  AuthHeader: string;
  CookieHeader: string;
  ReqCacheControl: string;
begin
  // 1. Prevent cache for authenticated requests via Authorization header
  if AContext.Request.Headers.TryGetValue('Authorization', AuthHeader) and (Trim(AuthHeader) <> '') then
    Exit(False);

  // 2. Prevent cache for requests carrying session/auth cookies
  if AContext.Request.Headers.TryGetValue('Cookie', CookieHeader) and (Trim(CookieHeader) <> '') then
  begin
    CookieHeader := LowerCase(CookieHeader);
    if CookieHeader.Contains('session') or CookieHeader.Contains('token') or 
       CookieHeader.Contains('jwt') or CookieHeader.Contains('auth') then
      Exit(False);
  end;

  // 3. Respect request Cache-Control directives: no-store, no-cache
  if AContext.Request.Headers.TryGetValue('Cache-Control', ReqCacheControl) then
  begin
    ReqCacheControl := LowerCase(ReqCacheControl);
    if ReqCacheControl.Contains('no-store') or ReqCacheControl.Contains('no-cache') then
      Exit(False);
  end;

  // 4. Validate allowed HTTP methods (GET, HEAD)
  Method := AContext.Request.Method;
  for CacheableMethod in FOptions.CacheableMethods do
    if SameText(Method, CacheableMethod) then
      Exit(True);
  Result := False;
end;

procedure TResponseCacheMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  CacheKey: string;
  OriginalResponse: IHttpResponse;
  Wrapper: TResponseCaptureWrapper;
begin
  // Skip non-cacheable methods (POST, PUT, DELETE, etc.)
  if not IsCacheable(AContext) then
  begin
    ANext(AContext);
    Exit;
  end;

  // Build the cache key (method + path + query + vary-by headers)
  CacheKey := GenerateCacheKey(AContext);

  // Try to serve a cached response (HIT)
  if TryServeFromCache(AContext, CacheKey) then
  begin
    Exit; // response already written, stop pipeline
  end;

  // MISS – add cache-control headers only if not already specified by application
  AContext.Response.AddHeader('X-Cache', 'MISS');
  if not AContext.Response.Headers.ContainsKey('Cache-Control') then
  begin
    AContext.Response.AddHeader('Cache-Control',
      Format('public, max-age=%d', [FOptions.DefaultDuration]));
  end;

  // Wrap the response to capture the body
  OriginalResponse := AContext.Response;
  Wrapper := TResponseCaptureWrapper.Create(OriginalResponse);
  AContext.Response := Wrapper;
  
  try
    // Continue pipeline
    ANext(AContext);
    
    // Cache the captured response
    CacheResponse(AContext, CacheKey, Wrapper);
  finally
    // Restore original response
    AContext.Response := OriginalResponse;
  end;
end;

function TResponseCacheMiddleware.TryServeFromCache(
  AContext: IHttpContext;
  const AKey: string
): Boolean;
var
  CachedValue: string;
  CachedResponse: TCachedResponse;
begin
  if FStore.TryGet(AKey, CachedValue) then
  begin
    AContext.Response.AddHeader('X-Cache', 'HIT');
    if not AContext.Response.Headers.ContainsKey('Cache-Control') then
    begin
      AContext.Response.AddHeader('Cache-Control',
        Format('public, max-age=%d', [FOptions.DefaultDuration]));
    end;
    if CachedValue.StartsWith('{"StatusCode":') or
       CachedValue.StartsWith('{"statusCode":') then
    begin
      try
        CachedResponse := TDextJson.Deserialize<TCachedResponse>(
          CachedValue
        );
        AContext.Response.SetStatusCode(CachedResponse.StatusCode);
        if CachedResponse.ContentType <> '' then
          AContext.Response.SetContentType(CachedResponse.ContentType);
        AContext.Response.Write(CachedResponse.Body);
        Exit(True);
      except
        // Fallback on deserialization failure
      end;
    end;

    // Legacy fallback
    if CachedValue.StartsWith('{') or CachedValue.StartsWith('[') then
      AContext.Response.Json(CachedValue)
    else
      AContext.Response.Write(CachedValue);
    Exit(True);
  end;
  Result := False;
end;

procedure TResponseCacheMiddleware.CacheResponse(
  AContext: IHttpContext;
  const AKey: string;
  AWrapper: TResponseCaptureWrapper
);
var
  Body: string;
  CachedResponse: TCachedResponse;
  Serialized: string;
  StatusCode: Integer;
  ResCacheControl: string;
  SetCookieHeader: string;
begin
  StatusCode := AWrapper.GetStatusCode;
  // Cache ONLY 200 OK responses
  if StatusCode <> 200 then
    Exit;

  // Do NOT cache responses setting cookies
  if AContext.Response.Headers.TryGetValue('Set-Cookie', SetCookieHeader) and (Trim(SetCookieHeader) <> '') then
    Exit;

  // Do NOT cache responses with private/no-store/no-cache
  if AContext.Response.Headers.TryGetValue('Cache-Control', ResCacheControl) then
  begin
    ResCacheControl := LowerCase(ResCacheControl);
    if ResCacheControl.Contains('private') or ResCacheControl.Contains('no-store') or ResCacheControl.Contains('no-cache') then
      Exit;
  end;

  Body := AWrapper.GetCapturedBody;
  if not Body.IsEmpty then
  begin
    CachedResponse.StatusCode := StatusCode;
    CachedResponse.ContentType := AWrapper.GetContentType;
    CachedResponse.Body := Body;
    Serialized := TDextJson.Serialize(CachedResponse);
    FStore.SetValue(AKey, Serialized, FOptions.DefaultDuration);
  end;
end;

{ TResponseCaptureWrapper }

constructor TResponseCaptureWrapper.Create(AOriginal: IHttpResponse);
begin
  inherited Create;
  FOriginal := AOriginal;
  FBodyBuffer := TStringBuilder.Create;
  FStatusCode := 200;
end;

destructor TResponseCaptureWrapper.Destroy;
begin
  FBodyBuffer.Free;
  inherited;
end;

function TResponseCaptureWrapper.Status(AValue: Integer): IHttpResponse;
begin
  SetStatusCode(AValue);
  Result := Self;
end;

procedure TResponseCaptureWrapper.SetStatusCode(AValue: Integer);
begin
  FStatusCode := AValue;
end;

procedure TResponseCaptureWrapper.SetContentType(const AValue: string);
begin
  FOriginal.SetContentType(AValue);
end;

procedure TResponseCaptureWrapper.SetContentLength(const AValue: Int64);
begin
  FOriginal.SetContentLength(AValue);
end;

procedure TResponseCaptureWrapper.Write(const AContent: string);
begin
  FBodyBuffer.Append(AContent);
  FOriginal.Write(AContent);
end;

procedure TResponseCaptureWrapper.Write(const ABuffer: TBytes);
begin
  if Length(ABuffer) > 0 then
    FBodyBuffer.Append(TEncoding.UTF8.GetString(ABuffer));
  FOriginal.Write(ABuffer);
end;

procedure TResponseCaptureWrapper.Write(const AStream: TStream);
var
  SS: TStringStream;
  Pos: Int64;
begin
  // Capture body
  if AStream.Size > 0 then
  begin
    Pos := AStream.Position;
    SS := TStringStream.Create('', TEncoding.UTF8);
    try
      SS.CopyFrom(AStream, 0);
      FBodyBuffer.Append(SS.DataString);
    finally
      SS.Free;
      AStream.Position := Pos;
    end;
  end;
  FOriginal.Write(AStream);
end;

procedure TResponseCaptureWrapper.SendJsonUtf8(const AUtf8Json: RawByteString);
begin
  if Length(AUtf8Json) > 0 then
    FBodyBuffer.Append(UTF8ToString(AUtf8Json));
  FOriginal.SendJsonUtf8(AUtf8Json);
end;

procedure TResponseCaptureWrapper.SendJsonUtf8(const ABuffer: TBytes);
begin
  if Length(ABuffer) > 0 then
    FBodyBuffer.Append(TEncoding.UTF8.GetString(ABuffer));
  FOriginal.SendJsonUtf8(ABuffer);
end;

function TResponseCaptureWrapper.GetOutputStream: TStream;
begin
  Result := FOriginal.GetOutputStream;
end;

procedure TResponseCaptureWrapper.Json(const AJson: string);
begin
  FBodyBuffer.Append(AJson);
  FOriginal.Json(AJson);
end;

procedure TResponseCaptureWrapper.Json(const AValue: TValue);
var
  JsonStr: string;
begin
  JsonStr := Dext.Json.TDextJson.Serialize(AValue);
  FBodyBuffer.Append(JsonStr);
  FOriginal.Json(JsonStr);
end;

procedure TResponseCaptureWrapper.AddHeader(const AName, AValue: string);
begin
  FOriginal.AddHeader(AName, AValue);
end;

procedure TResponseCaptureWrapper.AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions);
begin
  FOriginal.AppendCookie(AName, AValue, AOptions);
end;

procedure TResponseCaptureWrapper.AppendCookie(const AName, AValue: string);
begin
  FOriginal.AppendCookie(AName, AValue);
end;

procedure TResponseCaptureWrapper.DeleteCookie(const AName: string);
begin
  FOriginal.DeleteCookie(AName);
end;

procedure TResponseCaptureWrapper.Redirect(const AUrl: string; APermanent: Boolean);
begin
  FStatusCode := ifthen(APermanent, 301, 302);
  FOriginal.Redirect(AUrl, APermanent);
end;

procedure TResponseCaptureWrapper.Unauthorized(const AMessage: string);
begin
  FStatusCode := 401;
  if AMessage <> '' then FBodyBuffer.Append(AMessage);
  FOriginal.Unauthorized(AMessage);
end;

procedure TResponseCaptureWrapper.Forbidden(const AMessage: string);
begin
  FStatusCode := 403;
  if AMessage <> '' then FBodyBuffer.Append(AMessage);
  FOriginal.Forbidden(AMessage);
end;

procedure TResponseCaptureWrapper.BadRequest(const AMessage: string);
begin
  FStatusCode := 400;
  if AMessage <> '' then FBodyBuffer.Append(AMessage);
  FOriginal.BadRequest(AMessage);
end;

procedure TResponseCaptureWrapper.NotFound(const AMessage: string);
begin
  FStatusCode := 404;
  if AMessage <> '' then FBodyBuffer.Append(AMessage);
  FOriginal.NotFound(AMessage);
end;

procedure TResponseCaptureWrapper.Flush;
begin
  FOriginal.Flush;
end;

function TResponseCaptureWrapper.GetHtmx: IHtmxResponse;
begin
  Result := FOriginal.Htmx;
end;

function TResponseCaptureWrapper.GetHeaders: IStringDictionary;
begin
  Result := FOriginal.Headers;
end;

function TResponseCaptureWrapper.GetCapturedBody: string;
begin
  Result := FBodyBuffer.ToString;
end;


function TResponseCaptureWrapper.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TResponseCaptureWrapper.GetContentType: string;
begin
  Result := FOriginal.ContentType;
end;

{ TResponseCacheBuilder }

{ TResponseCacheBuilder }

procedure TResponseCacheBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    FOptions := TResponseCacheOptions.Create;
    FInitialized := True;
  end;
end;

class function TResponseCacheBuilder.Create: TResponseCacheBuilder;
begin
  Result.FOptions := TResponseCacheOptions.Create;
  Result.FInitialized := True;
end;

function TResponseCacheBuilder.DefaultDuration(ASeconds: Integer): TResponseCacheBuilder;
begin
  EnsureInitialized;
  FOptions.DefaultDuration := ASeconds;
  Result := Self;
end;

function TResponseCacheBuilder.MaxSize(ASize: Integer): TResponseCacheBuilder;
begin
  EnsureInitialized;
  FOptions.MaxSize := ASize;
  Result := Self;
end;

function TResponseCacheBuilder.VaryByQueryString: TResponseCacheBuilder;
begin
  EnsureInitialized;
  FOptions.VaryByQuery := True;
  Result := Self;
end;

function TResponseCacheBuilder.VaryByHeader(const AHeaders: array of string): TResponseCacheBuilder;
var
  I: Integer;
begin
  EnsureInitialized;
  SetLength(FOptions.VaryByHeaders, Length(AHeaders));
  for I := 0 to High(AHeaders) do
    FOptions.VaryByHeaders[I] := AHeaders[I];
  Result := Self;
end;

function TResponseCacheBuilder.ForMethods(const AMethods: array of string): TResponseCacheBuilder;
var
  I: Integer;
begin
  EnsureInitialized;
  SetLength(FOptions.CacheableMethods, Length(AMethods));
  for I := 0 to High(AMethods) do
    FOptions.CacheableMethods[I] := AMethods[I];
  Result := Self;
end;

function TResponseCacheBuilder.Store(const AStore: ICacheStore): TResponseCacheBuilder;
begin
  EnsureInitialized;
  FOptions.CacheStore := AStore;
  Result := Self;
end;

function TResponseCacheBuilder.Build: TResponseCacheOptions;
begin
  EnsureInitialized;
  Result := FOptions;
end;

class operator TResponseCacheBuilder.Implicit(const ABuilder: TResponseCacheBuilder): TResponseCacheOptions;
begin
  Result := ABuilder.FOptions;
end;

{ TApplicationBuilderCacheExtensions }

class function TApplicationBuilderCacheExtensions.UseResponseCache(
  const ABuilder: IApplicationBuilder): IApplicationBuilder;
begin
  // Register as Singleton to persist store
  Result := ABuilder.UseMiddleware(TResponseCacheMiddleware.Create(TResponseCacheOptions.Create));
end;

class function TApplicationBuilderCacheExtensions.UseResponseCache(
  const ABuilder: IApplicationBuilder; ADurationSeconds: Integer): IApplicationBuilder;
begin
  // Register as Singleton
  Result := ABuilder.UseMiddleware(TResponseCacheMiddleware.Create(TResponseCacheOptions.Create(ADurationSeconds)));
end;

class function TApplicationBuilderCacheExtensions.UseResponseCache(
  const ABuilder: IApplicationBuilder; const AOptions: TResponseCacheOptions): IApplicationBuilder;
begin
  // Register as Singleton
  Result := ABuilder.UseMiddleware(TResponseCacheMiddleware.Create(AOptions));
end;

class function TApplicationBuilderCacheExtensions.UseResponseCache(
  const ABuilder: IApplicationBuilder; AConfigurator: TResponseCacheBuilderProc): IApplicationBuilder;
var
  Builder: TResponseCacheBuilder;
begin
  Builder := TResponseCacheBuilder.Create;
  if Assigned(AConfigurator) then
    AConfigurator(Builder);

  // Register as Singleton
  Result := ABuilder.UseMiddleware(TResponseCacheMiddleware.Create(Builder.Build));
end;

class function TApplicationBuilderCacheExtensions.UseResponseCache(
  const ABuilder: IApplicationBuilder; const ACacheBuilder: TResponseCacheBuilder): IApplicationBuilder;
begin
  // Register as Singleton
  Result := ABuilder.UseMiddleware(TResponseCacheMiddleware.Create(ACacheBuilder.Build));
end;

class function TApplicationBuilderCacheExtensions.UseResponseCaching(
  const ABuilder: IApplicationBuilder): IApplicationBuilder;
begin
  Result := UseResponseCache(ABuilder);
end;

class function TApplicationBuilderCacheExtensions.UseResponseCaching(
  const ABuilder: IApplicationBuilder; ADurationSeconds: Integer): IApplicationBuilder;
begin
  Result := UseResponseCache(ABuilder, ADurationSeconds);
end;

class function TApplicationBuilderCacheExtensions.UseResponseCaching(
  const ABuilder: IApplicationBuilder; const AOptions: TResponseCacheOptions): IApplicationBuilder;
begin
  Result := UseResponseCache(ABuilder, AOptions);
end;

class function TApplicationBuilderCacheExtensions.UseResponseCaching(
  const ABuilder: IApplicationBuilder; AConfigurator: TResponseCacheBuilderProc): IApplicationBuilder;
begin
  Result := UseResponseCache(ABuilder, AConfigurator);
end;

class function TApplicationBuilderCacheExtensions.UseResponseCaching(
  const ABuilder: IApplicationBuilder; const ACacheBuilder: TResponseCacheBuilder): IApplicationBuilder;
begin
  Result := UseResponseCache(ABuilder, ACacheBuilder);
end;

{ TResponseCacheOptionsHelper }

class operator TResponseCacheOptionsHelper.Implicit(const AValue: TResponseCacheOptions): TValue;
begin
  Result := TValue.From<TResponseCacheOptions>(AValue);
end;

end.

