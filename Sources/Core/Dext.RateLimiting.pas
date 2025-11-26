unit Dext.RateLimiting;

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
  ///   Rate limiting policy configuration.
  /// </summary>
  TRateLimitPolicy = record
  public
    /// <summary>
    ///   Maximum number of requests allowed in the time window.
    /// </summary>
    PermitLimit: Integer;
    
    /// <summary>
    ///   Time window in seconds.
    /// </summary>
    WindowSeconds: Integer;
    
    /// <summary>
    ///   Custom message to return when rate limit is exceeded.
    /// </summary>
    RejectionMessage: string;
    
    /// <summary>
    ///   HTTP status code to return when rate limit is exceeded (default: 429).
    /// </summary>
    RejectionStatusCode: Integer;

    /// <summary>
    ///   Creates a default rate limit policy.
    /// </summary>
    class function Create(APermitLimit: Integer = 100; AWindowSeconds: Integer = 60): TRateLimitPolicy; static;
  end;

  /// <summary>
  ///   Tracks request counts for a specific client.
  /// </summary>
  TRateLimitEntry = record
    RequestCount: Integer;
    WindowStart: TDateTime;
  end;

  /// <summary>
  ///   Middleware that enforces rate limiting based on client IP.
  /// </summary>
  TRateLimitMiddleware = class(TMiddleware)
  private
    FPolicy: TRateLimitPolicy;
    FClients: TDictionary<string, TRateLimitEntry>;
    FLock: TCriticalSection;
    
    function GetClientKey(AContext: IHttpContext): string;
    function IsRateLimitExceeded(const AClientKey: string): Boolean;
    procedure CleanupExpiredEntries;
  public
    constructor Create(const APolicy: TRateLimitPolicy);
    destructor Destroy; override;
    
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  /// <summary>
  ///   Fluent builder for creating rate limit policies.
  /// </summary>
  TRateLimitBuilder = class
  private
    FPolicy: TRateLimitPolicy;
  public
    constructor Create;
    
    /// <summary>
    ///   Sets the maximum number of requests allowed.
    /// </summary>
    function WithPermitLimit(ALimit: Integer): TRateLimitBuilder;
    
    /// <summary>
    ///   Sets the time window in seconds.
    /// </summary>
    function WithWindow(ASeconds: Integer): TRateLimitBuilder;
    
    /// <summary>
    ///   Sets a custom rejection message.
    /// </summary>
    function WithRejectionMessage(const AMessage: string): TRateLimitBuilder;
    
    /// <summary>
    ///   Sets the HTTP status code for rejections (default: 429).
    /// </summary>
    function WithRejectionStatusCode(AStatusCode: Integer): TRateLimitBuilder;
    
    /// <summary>
    ///   Builds and returns the rate limit policy.
    /// </summary>
    function Build: TRateLimitPolicy;
  end;

  /// <summary>
  ///   Extension methods for adding rate limiting to the application pipeline.
  /// </summary>
  TApplicationBuilderRateLimitExtensions = class
  public
    /// <summary>
    ///   Adds rate limiting middleware with default settings (100 requests per minute).
    /// </summary>
    class function UseRateLimiting(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload; static;
    
    /// <summary>
    ///   Adds rate limiting middleware with custom policy.
    /// </summary>
    class function UseRateLimiting(const ABuilder: IApplicationBuilder; const APolicy: TRateLimitPolicy): IApplicationBuilder; overload; static;
    
    /// <summary>
    ///   Adds rate limiting middleware configured with a builder.
    /// </summary>
    class function UseRateLimiting(const ABuilder: IApplicationBuilder; AConfigurator: TProc<TRateLimitBuilder>): IApplicationBuilder; overload; static;
  end;

  /// <summary>
  ///   Helper for implicit conversion of TRateLimitPolicy to TValue.
  /// </summary>
  TRateLimitPolicyHelper = record helper for TRateLimitPolicy
  public
    class operator Implicit(const AValue: TRateLimitPolicy): TValue;
  end;

implementation

{ TRateLimitPolicy }

class function TRateLimitPolicy.Create(APermitLimit, AWindowSeconds: Integer): TRateLimitPolicy;
begin
  Result.PermitLimit := APermitLimit;
  Result.WindowSeconds := AWindowSeconds;
  Result.RejectionMessage := '{"error":"Rate limit exceeded. Please try again later."}';
  Result.RejectionStatusCode := 429; // Too Many Requests
end;

{ TRateLimitMiddleware }

constructor TRateLimitMiddleware.Create(const APolicy: TRateLimitPolicy);
begin
  inherited Create;
  FPolicy := APolicy;
  FClients := TDictionary<string, TRateLimitEntry>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TRateLimitMiddleware.Destroy;
begin
  FClients.Free;
  FLock.Free;
  inherited;
end;

function TRateLimitMiddleware.GetClientKey(AContext: IHttpContext): string;
var
  XForwardedFor: string;
begin
  // Try to get real IP from X-Forwarded-For header (for proxies/load balancers)
  if AContext.Request.Headers.TryGetValue('x-forwarded-for', XForwardedFor) then
  begin
    // Take the first IP in the chain
    var IPs := XForwardedFor.Split([',']);
    if Length(IPs) > 0 then
      Result := IPs[0].Trim
    else
      Result := 'unknown';
  end
  else
  begin
    // Use the real remote IP from the socket
    Result := AContext.Request.RemoteIpAddress;
    
    // Fallback if empty (should not happen with Indy)
    if Result = '' then
      Result := 'unknown_client';
  end;
end;

function TRateLimitMiddleware.IsRateLimitExceeded(const AClientKey: string): Boolean;
var
  Entry: TRateLimitEntry;
  Now: TDateTime;
  WindowElapsed: Boolean;
begin
  FLock.Enter;
  try
    Now := System.SysUtils.Now;
    
    if FClients.TryGetValue(AClientKey, Entry) then
    begin
      // Check if window has expired
      WindowElapsed := SecondsBetween(Now, Entry.WindowStart) >= FPolicy.WindowSeconds;
      
      if WindowElapsed then
      begin
        // Reset window
        Entry.RequestCount := 1;
        Entry.WindowStart := Now;
        FClients.AddOrSetValue(AClientKey, Entry);
        Result := False;
      end
      else
      begin
        // Increment counter
        Inc(Entry.RequestCount);
        FClients.AddOrSetValue(AClientKey, Entry);
        Result := Entry.RequestCount > FPolicy.PermitLimit;
      end;
    end
    else
    begin
      // First request from this client
      Entry.RequestCount := 1;
      Entry.WindowStart := Now;
      FClients.Add(AClientKey, Entry);
      Result := False;
    end;
    
    // Cleanup old entries periodically (every 100 requests)
    if FClients.Count mod 100 = 0 then
      CleanupExpiredEntries;
      
  finally
    FLock.Leave;
  end;
end;

procedure TRateLimitMiddleware.CleanupExpiredEntries;
var
  KeysToRemove: TList<string>;
  Key: string;
  Entry: TRateLimitEntry;
  Now: TDateTime;
begin
  KeysToRemove := TList<string>.Create;
  try
    Now := System.SysUtils.Now;
    
    for Key in FClients.Keys do
    begin
      Entry := FClients[Key];
      if SecondsBetween(Now, Entry.WindowStart) >= (FPolicy.WindowSeconds * 2) then
        KeysToRemove.Add(Key);
    end;
    
    for Key in KeysToRemove do
      FClients.Remove(Key);
      
  finally
    KeysToRemove.Free;
  end;
end;

procedure TRateLimitMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  ClientKey: string;
  Entry: TRateLimitEntry;
  Remaining: Integer;
begin
  ClientKey := GetClientKey(AContext);
  
  if IsRateLimitExceeded(ClientKey) then
  begin
    // Rate limit exceeded
    AContext.Response.StatusCode := FPolicy.RejectionStatusCode;
    AContext.Response.SetContentType('application/json');
    AContext.Response.Write(FPolicy.RejectionMessage);
    
    // Add rate limit headers
    AContext.Response.AddHeader('X-RateLimit-Limit', IntToStr(FPolicy.PermitLimit));
    AContext.Response.AddHeader('X-RateLimit-Remaining', '0');
    AContext.Response.AddHeader('Retry-After', IntToStr(FPolicy.WindowSeconds));
    Exit;
  end;
  
  // Add rate limit info headers
  FLock.Enter;
  try
    if FClients.TryGetValue(ClientKey, Entry) then
    begin
      Remaining := FPolicy.PermitLimit - Entry.RequestCount;
      if Remaining < 0 then Remaining := 0;
      
      AContext.Response.AddHeader('X-RateLimit-Limit', IntToStr(FPolicy.PermitLimit));
      AContext.Response.AddHeader('X-RateLimit-Remaining', IntToStr(Remaining));
    end;
  finally
    FLock.Leave;
  end;
  
  // Continue pipeline
  ANext(AContext);
end;

{ TRateLimitBuilder }

constructor TRateLimitBuilder.Create;
begin
  inherited Create;
  FPolicy := TRateLimitPolicy.Create;
end;

function TRateLimitBuilder.WithPermitLimit(ALimit: Integer): TRateLimitBuilder;
begin
  FPolicy.PermitLimit := ALimit;
  Result := Self;
end;

function TRateLimitBuilder.WithWindow(ASeconds: Integer): TRateLimitBuilder;
begin
  FPolicy.WindowSeconds := ASeconds;
  Result := Self;
end;

function TRateLimitBuilder.WithRejectionMessage(const AMessage: string): TRateLimitBuilder;
begin
  FPolicy.RejectionMessage := AMessage;
  Result := Self;
end;

function TRateLimitBuilder.WithRejectionStatusCode(AStatusCode: Integer): TRateLimitBuilder;
begin
  FPolicy.RejectionStatusCode := AStatusCode;
  Result := Self;
end;

function TRateLimitBuilder.Build: TRateLimitPolicy;
begin
  Result := FPolicy;
end;

{ TApplicationBuilderRateLimitExtensions }

class function TApplicationBuilderRateLimitExtensions.UseRateLimiting(
  const ABuilder: IApplicationBuilder): IApplicationBuilder;
begin
  // ✅ Instantiate Singleton Middleware
  var Middleware := TRateLimitMiddleware.Create(TRateLimitPolicy.Create);
  Result := ABuilder.UseMiddleware(Middleware);
end;

class function TApplicationBuilderRateLimitExtensions.UseRateLimiting(
  const ABuilder: IApplicationBuilder; const APolicy: TRateLimitPolicy): IApplicationBuilder;
begin
  // ✅ Instantiate Singleton Middleware
  var Middleware := TRateLimitMiddleware.Create(APolicy);
  Result := ABuilder.UseMiddleware(Middleware);
end;

class function TApplicationBuilderRateLimitExtensions.UseRateLimiting(
  const ABuilder: IApplicationBuilder; AConfigurator: TProc<TRateLimitBuilder>): IApplicationBuilder;
var
  Builder: TRateLimitBuilder;
  Policy: TRateLimitPolicy;
begin
  Builder := TRateLimitBuilder.Create;
  try
    if Assigned(AConfigurator) then
      AConfigurator(Builder);
    Policy := Builder.Build;
  finally
    Builder.Free;
  end;

  // ✅ Instantiate Singleton Middleware
  var Middleware := TRateLimitMiddleware.Create(Policy);
  Result := ABuilder.UseMiddleware(Middleware);
end;

{ TRateLimitPolicyHelper }

class operator TRateLimitPolicyHelper.Implicit(const AValue: TRateLimitPolicy): TValue;
begin
  Result := TValue.From<TRateLimitPolicy>(AValue);
end;

end.
