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
  System.Rtti,
  System.DateUtils,
  System.Generics.Collections,
  System.SyncObjs,
  Dext.Http.Core,
  Dext.Http.Interfaces;

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
    Value: string;
    ExpiresAt: TDateTime;
  end;

  /// <summary>
  ///   In-memory cache store implementation (default).
  /// </summary>
  TMemoryCacheStore = class(TInterfacedObject, ICacheStore)
  private
    FEntries: TDictionary<string, TCacheEntry>;
    FLock: TCriticalSection;
    FMaxSize: Integer;
    
    procedure CleanupExpired;
    procedure EnforceMaxSize;
  public
    constructor Create(AMaxSize: Integer = 1000);
    destructor Destroy; override;
    
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure SetValue(const AKey: string; const AValue: string; ADurationSeconds: Integer);
    procedure Remove(const AKey: string);
    procedure Clear;
    
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
  public
    constructor Create(AOriginal: IHttpResponse);
    destructor Destroy; override;
    
    // IHttpResponse
    function Status(AValue: Integer): IHttpResponse;
    procedure SetStatusCode(AValue: Integer);
    procedure SetContentType(const AValue: string);
    procedure SetContentLength(const AValue: Int64);
    procedure Write(const AContent: string); overload;
    procedure Write(const ABuffer: TBytes); overload;
    procedure Json(const AJson: string);
    procedure AddHeader(const AName, AValue: string);

    function GetCapturedBody: string;
    function GetStatusCode: Integer;
  end;

  /// <summary>
  ///   Middleware that caches HTTP responses.
  /// </summary>
  TResponseCacheMiddleware = class(TMiddleware)
  private
    FOptions: TResponseCacheOptions;
    FStore: ICacheStore;
    
    function GenerateCacheKey(AContext: IHttpContext): string;
    function IsCacheable(AContext: IHttpContext): Boolean;
    function TryServeFromCache(AContext: IHttpContext; const AKey: string): Boolean;
    procedure CacheResponse(AContext: IHttpContext; const AKey: string; AWrapper: TResponseCaptureWrapper);
  public
    constructor Create(const AOptions: TResponseCacheOptions);
    destructor Destroy; override;
    
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  /// <summary>
  ///   Fluent builder for creating cache options.
  /// </summary>
  TResponseCacheBuilder = class
  private
    FOptions: TResponseCacheOptions;
  public
    constructor Create;
    
    /// <summary>
    ///   Sets the default cache duration in seconds.
    /// </summary>
    function WithDefaultDuration(ASeconds: Integer): TResponseCacheBuilder;
    
    /// <summary>
    ///   Sets the maximum cache size (for memory store).
    /// </summary>
    function WithMaxSize(ASize: Integer): TResponseCacheBuilder;
    
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
    function WithStore(const AStore: ICacheStore): TResponseCacheBuilder;
    
    /// <summary>
    ///   Builds and returns the cache options.
    /// </summary>
    function Build: TResponseCacheOptions;
  end;

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
    class function UseResponseCache(const ABuilder: IApplicationBuilder; AConfigurator: TProc<TResponseCacheBuilder>): IApplicationBuilder; overload; static;
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
  System.Hash;

{ TMemoryCacheStore }

constructor TMemoryCacheStore.Create(AMaxSize: Integer);
begin
  inherited Create;
  FEntries := TDictionary<string, TCacheEntry>.Create;
  FLock := TCriticalSection.Create;
  FMaxSize := AMaxSize;
end;

destructor TMemoryCacheStore.Destroy;
begin
  FEntries.Free;
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
  KeysToRemove: TList<string>;
  Key: string;
  Entry: TCacheEntry;
  Now: TDateTime;
begin
  KeysToRemove := TList<string>.Create;
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
    KeysToRemove.Free;
  end;
end;

procedure TMemoryCacheStore.EnforceMaxSize;
var
  KeysToRemove: TList<string>;
  Key: string;
  RemoveCount: Integer;
begin
  // Remove oldest 10% when max size is exceeded
  RemoveCount := FMaxSize div 10;
  if RemoveCount < 1 then
    RemoveCount := 1;
    
  KeysToRemove := TList<string>.Create;
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
    KeysToRemove.Free;
  end;
end;

{ TResponseCacheOptions }

class function TResponseCacheOptions.Create(ADuration: Integer): TResponseCacheOptions;
begin
  Result.DefaultDuration := ADuration;
  Result.MaxSize := 1000;
  Result.VaryByQuery := True;
  SetLength(Result.VaryByHeaders, 0);
  Result.CacheableMethods := ['GET', 'HEAD'];
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
      KeyBuilder.Append(AContext.Request.Query.DelimitedText);
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
    
    Result := KeyBuilder.ToString;
  finally
    KeyBuilder.Free;
  end;
end;

function TResponseCacheMiddleware.IsCacheable(AContext: IHttpContext): Boolean;
var
  Method: string;
  CacheableMethod: string;
begin
  Method := AContext.Request.Method;
  for CacheableMethod in FOptions.CacheableMethods do
    if SameText(Method, CacheableMethod) then
      Exit(True);
  Result := False;
end;

procedure TResponseCacheMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  CacheKey: string;
begin
  // Skip non‑cacheable methods (POST, PUT, DELETE, etc.)
  if not IsCacheable(AContext) then
  begin
    ANext(AContext);
    Exit;
  end;

  // Build the cache key (method + path + query + vary‑by headers)
  CacheKey := GenerateCacheKey(AContext);

  // Try to serve a cached response (HIT)
  if TryServeFromCache(AContext, CacheKey) then
    Exit; // response already written, stop pipeline

  // MISS – add cache‑control headers
  AContext.Response.AddHeader('X-Cache', 'MISS');
  AContext.Response.AddHeader('Cache-Control',
    Format('public, max-age=%d', [FOptions.DefaultDuration]));

  // Wrap the response to capture the body
  var OriginalResponse := AContext.Response;
  var Wrapper := TResponseCaptureWrapper.Create(OriginalResponse);
  AContext.Response := Wrapper;
  
  try
    // Continue pipeline
    ANext(AContext);
    
    // Cache the captured response
    CacheResponse(AContext, CacheKey, Wrapper);
  finally
    // Restore original response (optional but good practice)
    AContext.Response := OriginalResponse;
  end;
end;

function TResponseCacheMiddleware.TryServeFromCache(AContext: IHttpContext; const AKey: string): Boolean;
var
  CachedValue: string;
begin
  if FStore.TryGet(AKey, CachedValue) then
  begin
    AContext.Response.AddHeader('X-Cache', 'HIT');
    // Simple detection of JSON vs Text
    if CachedValue.StartsWith('{') or CachedValue.StartsWith('[') then
      AContext.Response.Json(CachedValue)
    else
      AContext.Response.Write(CachedValue);
    Result := True;
  end
  else
    Result := False;
end;

procedure TResponseCacheMiddleware.CacheResponse(AContext: IHttpContext; const AKey: string; AWrapper: TResponseCaptureWrapper);
begin
  // Store the captured body in the cache
  var Body := AWrapper.GetCapturedBody;
  if not Body.IsEmpty then
  begin
    FStore.SetValue(AKey, Body, FOptions.DefaultDuration);
  end;
end;

{ TResponseCaptureWrapper }

constructor TResponseCaptureWrapper.Create(AOriginal: IHttpResponse);
begin
  inherited Create;
  FOriginal := AOriginal;
  FBodyBuffer := TStringBuilder.Create;
end;

destructor TResponseCaptureWrapper.Destroy;
begin
  FBodyBuffer.Free;
  inherited;
end;

procedure TResponseCaptureWrapper.SetStatusCode(AValue: Integer);
begin
  FOriginal.StatusCode := AValue;
end;

function TResponseCaptureWrapper.Status(AValue: Integer): IHttpResponse;
begin
  SetStatusCode(AValue);
  Result := Self;
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
  // For binary data, we can't easily cache it in a string buffer
  // Just pass through to original response
  FOriginal.Write(ABuffer);
end;

procedure TResponseCaptureWrapper.Json(const AJson: string);
begin
  FBodyBuffer.Append(AJson);
  FOriginal.Json(AJson);
end;

procedure TResponseCaptureWrapper.AddHeader(const AName, AValue: string);
begin
  FOriginal.AddHeader(AName, AValue);
end;

function TResponseCaptureWrapper.GetCapturedBody: string;
begin
  Result := FBodyBuffer.ToString;
end;


function TResponseCaptureWrapper.GetStatusCode: Integer;
begin
  Result := FOriginal.StatusCode;
end;

{ TResponseCacheBuilder }

constructor TResponseCacheBuilder.Create;
begin
  inherited Create;
  FOptions := TResponseCacheOptions.Create;
end;

function TResponseCacheBuilder.WithDefaultDuration(ASeconds: Integer): TResponseCacheBuilder;
begin
  FOptions.DefaultDuration := ASeconds;
  Result := Self;
end;

function TResponseCacheBuilder.WithMaxSize(ASize: Integer): TResponseCacheBuilder;
begin
  FOptions.MaxSize := ASize;
  Result := Self;
end;

function TResponseCacheBuilder.VaryByQueryString: TResponseCacheBuilder;
begin
  FOptions.VaryByQuery := True;
  Result := Self;
end;

function TResponseCacheBuilder.VaryByHeader(const AHeaders: array of string): TResponseCacheBuilder;
var
  I: Integer;
begin
  SetLength(FOptions.VaryByHeaders, Length(AHeaders));
  for I := 0 to High(AHeaders) do
    FOptions.VaryByHeaders[I] := AHeaders[I];
  Result := Self;
end;

function TResponseCacheBuilder.ForMethods(const AMethods: array of string): TResponseCacheBuilder;
var
  I: Integer;
begin
  SetLength(FOptions.CacheableMethods, Length(AMethods));
  for I := 0 to High(AMethods) do
    FOptions.CacheableMethods[I] := AMethods[I];
  Result := Self;
end;

function TResponseCacheBuilder.WithStore(const AStore: ICacheStore): TResponseCacheBuilder;
begin
  FOptions.CacheStore := AStore;
  Result := Self;
end;

function TResponseCacheBuilder.Build: TResponseCacheOptions;
begin
  Result := FOptions;
end;

{ TApplicationBuilderCacheExtensions }

class function TApplicationBuilderCacheExtensions.UseResponseCache(
  const ABuilder: IApplicationBuilder): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TResponseCacheMiddleware, TResponseCacheOptions.Create);
end;

class function TApplicationBuilderCacheExtensions.UseResponseCache(
  const ABuilder: IApplicationBuilder; ADurationSeconds: Integer): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TResponseCacheMiddleware, TResponseCacheOptions.Create(ADurationSeconds));
end;

class function TApplicationBuilderCacheExtensions.UseResponseCache(
  const ABuilder: IApplicationBuilder; const AOptions: TResponseCacheOptions): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TResponseCacheMiddleware, AOptions);
end;

class function TApplicationBuilderCacheExtensions.UseResponseCache(
  const ABuilder: IApplicationBuilder; AConfigurator: TProc<TResponseCacheBuilder>): IApplicationBuilder;
var
  Builder: TResponseCacheBuilder;
  Options: TResponseCacheOptions;
begin
  Builder := TResponseCacheBuilder.Create;
  try
    if Assigned(AConfigurator) then
      AConfigurator(Builder);
    Options := Builder.Build;
  finally
    Builder.Free;
  end;

  Result := ABuilder.UseMiddleware(TResponseCacheMiddleware, Options);
end;

{ TResponseCacheOptionsHelper }

class operator TResponseCacheOptionsHelper.Implicit(const AValue: TResponseCacheOptions): TValue;
begin
  Result := TValue.From<TResponseCacheOptions>(AValue);
end;

end.

