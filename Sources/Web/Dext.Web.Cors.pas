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
unit Dext.Web.Cors;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Web.Builder,
  Dext.Web.Interfaces;

type
  /// <summary>
  ///   CORS (Cross-Origin Resource Sharing) configuration options.
  /// </summary>
  TCorsOptions = record
  public
    /// <summary>
    ///   List of allowed origins. Use '*' for any origin.
    /// </summary>
    AllowedOrigins: TArray<string>;
    
    /// <summary>
    ///   List of allowed HTTP methods (GET, POST, PUT, DELETE, etc.).
    /// </summary>
    AllowedMethods: TArray<string>;
    
    /// <summary>
    ///   List of allowed request headers.
    /// </summary>
    AllowedHeaders: TArray<string>;
    
    /// <summary>
    ///   List of headers that can be exposed to the browser.
    /// </summary>
    ExposedHeaders: TArray<string>;
    
    /// <summary>
    ///   Whether to allow credentials (cookies, authorization headers).
    /// </summary>
    AllowCredentials: Boolean;
    
    /// <summary>
    ///   How long (in seconds) the preflight response can be cached.
    /// </summary>
    MaxAge: Integer;

    /// <summary>
    ///   Creates default CORS options with common settings.
    /// </summary>
    class function Create: TCorsOptions; static;
  end;

  /// <summary>
  ///   Helper for TArray&lt;string&gt; to check if it contains a value.
  /// </summary>
  TStringArrayHelper = record helper for TArray<string>
  public
    function Contains(const AValue: string): Boolean;
    function IsEmpty: Boolean;
  end;

  /// <summary>
  ///   Middleware that handles CORS (Cross-Origin Resource Sharing).
  /// </summary>
  TCorsMiddleware = class(TMiddleware)
  private
    FOptions: TCorsOptions;
    FEnableDebugLog: Boolean;
    function IsOriginAllowed(const AOrigin: string): Boolean;
    procedure DebugLog(const AMessage: string);
  public
    constructor Create; overload;
    constructor Create(const AOptions: TCorsOptions); overload;
    constructor Create(const AOptions: TCorsOptions; AEnableDebugLog: Boolean); overload;
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  /// <summary>
  ///   Fluent builder for creating CORS options.
  ///   This is a managed record - no manual memory management required.
  /// </summary>
  TCorsBuilder = record
  private
    FOptions: TCorsOptions;
    FInitialized: Boolean;
    procedure EnsureInitialized;
  public
    /// <summary>
    ///   Creates a new CORS builder with default options.
    /// </summary>
    class function Create: TCorsBuilder; static;
    
    // =====================================================================
    // New API (without 'With' prefix)
    // =====================================================================
    
    /// <summary>
    ///   Specifies the allowed origins.
    /// </summary>
    function Origins(const AOrigins: TArray<string>): TCorsBuilder;
    
    /// <summary>
    ///   Allows any origin (*). Cannot be used with AllowCredentials.
    /// </summary>
    function AllowAnyOrigin: TCorsBuilder;
    
    /// <summary>
    ///   Specifies the allowed HTTP methods.
    /// </summary>
    function Methods(const AMethods: TArray<string>): TCorsBuilder;
    
    /// <summary>
    ///   Allows any HTTP method.
    /// </summary>
    function AllowAnyMethod: TCorsBuilder;
    
    /// <summary>
    ///   Specifies the allowed request headers.
    /// </summary>
    function Headers(const AHeaders: TArray<string>): TCorsBuilder;
    
    /// <summary>
    ///   Allows any request header.
    /// </summary>
    function AllowAnyHeader: TCorsBuilder;
    
    /// <summary>
    ///   Specifies headers that can be exposed to the browser.
    /// </summary>
    function ExposedHeaders(const AHeaders: TArray<string>): TCorsBuilder;
    
    /// <summary>
    ///   Allows credentials (cookies, authorization headers).
    ///   Cannot be used with AllowAnyOrigin.
    /// </summary>
    function AllowCredentials: TCorsBuilder;
    
    /// <summary>
    ///   Sets how long (in seconds) the preflight response can be cached.
    /// </summary>
    function MaxAge(ASeconds: Integer): TCorsBuilder;

    // =====================================================================
    // Deprecated API (with 'With' prefix) - for backward compatibility
    // =====================================================================
    
    function WithOrigins(const AOrigins: TArray<string>): TCorsBuilder; deprecated 'Use Origins instead';
    function WithMethods(const AMethods: TArray<string>): TCorsBuilder; deprecated 'Use Methods instead';
    function WithHeaders(const AHeaders: TArray<string>): TCorsBuilder; deprecated 'Use Headers instead';
    function WithExposedHeaders(const AHeaders: TArray<string>): TCorsBuilder; deprecated 'Use ExposedHeaders instead';
    function WithMaxAge(ASeconds: Integer): TCorsBuilder; deprecated 'Use MaxAge instead';

    /// <summary>
    ///   Returns the built CORS options.
    /// </summary>
    function Build: TCorsOptions;
    
    /// <summary>
    ///   Implicit conversion to TCorsOptions for direct use in UseCors.
    /// </summary>
    class operator Implicit(const ABuilder: TCorsBuilder): TCorsOptions;
  end;

  /// <summary>
  ///   Extension methods for adding CORS to the application pipeline.
  /// </summary>
  TApplicationBuilderCorsExtensions = class
  public
    /// <summary>
    ///   Adds CORS middleware with default settings.
    /// </summary>
    class function UseCors(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload; static;
    
    /// <summary>
    ///   Adds CORS middleware with custom options.
    /// </summary>
    class function UseCors(const ABuilder: IApplicationBuilder; const AOptions: TCorsOptions): IApplicationBuilder; overload; static;
    
    /// <summary>
    ///   Adds CORS middleware configured with a builder callback.
    /// </summary>
    class function UseCors(const ABuilder: IApplicationBuilder; AConfigurator: TProc<TCorsBuilder>): IApplicationBuilder; overload; static;
    
    /// <summary>
    ///   Adds CORS middleware with a fluent builder.
    ///   Usage: UseCors(TCorsBuilder.Create.AllowAnyOrigin.AllowAnyMethod)
    /// </summary>
    class function UseCors(const ABuilder: IApplicationBuilder; const ACorsBuilder: TCorsBuilder): IApplicationBuilder; overload; static;
  end;

  /// <summary>
  ///   Helper for implicit conversion of TCorsOptions to TValue.
  /// </summary>
  TCorsOptionsHelper = record helper for TCorsOptions
  public
    class operator Implicit(const AValue: TCorsOptions): TValue;
  end;

function CorsOptions: TCorsBuilder;

implementation

uses
  Dext.Utils;

{ TStringArrayHelper }

function CorsOptions: TCorsBuilder;
begin
  Result := TCorsBuilder.Create;
end;

function TStringArrayHelper.Contains(const AValue: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Self) do
  begin
    if Self[I] = AValue then
      Exit(True);
  end;
  Result := False;
end;

function TStringArrayHelper.IsEmpty: Boolean;
begin
  Result := Length(Self) = 0;
end;

{ TCorsOptions }

class function TCorsOptions.Create: TCorsOptions;
begin
  Result.AllowedOrigins := [];
  Result.AllowedMethods := ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'];
  Result.AllowedHeaders := ['Content-Type', 'Authorization'];
  Result.ExposedHeaders := [];
  Result.AllowCredentials := False;
  Result.MaxAge := 0;
end;

{ TCorsMiddleware }

constructor TCorsMiddleware.Create;
begin
  inherited Create;
  FOptions := TCorsOptions.Create;
  FEnableDebugLog := False;
end;

// ? Construtor com parmetros
constructor TCorsMiddleware.Create(const AOptions: TCorsOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FEnableDebugLog := False;
end;

constructor TCorsMiddleware.Create(const AOptions: TCorsOptions; AEnableDebugLog: Boolean);
begin
  inherited Create;
  FOptions := AOptions;
  FEnableDebugLog := AEnableDebugLog;
end;

procedure TCorsMiddleware.DebugLog(const AMessage: string);
begin
  if FEnableDebugLog then
    SafeWriteLn(AMessage);
end;

procedure MergeVaryHeader(AContext: IHttpContext; const AToken: string);
var
  ExistingVary: string;
  Tokens: TArray<string>;
  T: string;
begin
  if AContext.Response.Headers.TryGetValue('Vary', ExistingVary) and (Trim(ExistingVary) <> '') then
  begin
    Tokens := ExistingVary.Split([',']);
    for T in Tokens do
    begin
      if SameText(Trim(T), AToken) then
        Exit;
    end;
    AContext.Response.AddHeader('Vary', ExistingVary + ', ' + AToken);
  end
  else
  begin
    AContext.Response.AddHeader('Vary', AToken);
  end;
end;

procedure TCorsMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  RequestOrigin: string;
  ReqMethod: string;
  ReqHeadersStr: string;
  ReqHeaders: TArray<string>;
  HeaderItem: string;
  HeaderAllowed: Boolean;
  MethodAllowed: Boolean;
  AllowedItem: string;
begin
  DebugLog('🛡️ CORS MIDDLEWARE STARTED');
  DebugLog('📥 Request: ' + AContext.Request.Method + ' ' + AContext.Request.Path);

  // Check if request carries Origin header
  if AContext.Request.Headers.TryGetValue('Origin', RequestOrigin) and (not RequestOrigin.IsEmpty) then
  begin
    MergeVaryHeader(AContext, 'Origin');

    // Is this a CORS Preflight OPTIONS request?
    if (AContext.Request.Method = 'OPTIONS') and 
       AContext.Request.Headers.TryGetValue('Access-Control-Request-Method', ReqMethod) and
       (not ReqMethod.IsEmpty) then
    begin
      DebugLog('🔄 CORS: Handling OPTIONS preflight for origin: ' + RequestOrigin);

      // 1. Validate Origin
      if not IsOriginAllowed(RequestOrigin) then
      begin
        AContext.Response.StatusCode := 403;
        AContext.Response.Write('CORS: Origin not allowed');
        Exit;
      end;

      // 2. Validate Requested Method
      MethodAllowed := FOptions.AllowedMethods.Contains('*');
      if not MethodAllowed then
      begin
        for AllowedItem in FOptions.AllowedMethods do
        begin
          if SameText(AllowedItem, ReqMethod) then
          begin
            MethodAllowed := True;
            Break;
          end;
        end;
      end;

      if not MethodAllowed then
      begin
        AContext.Response.StatusCode := 403;
        AContext.Response.Write('CORS: Method not allowed in preflight');
        Exit;
      end;

      // 3. Validate Requested Headers
      if AContext.Request.Headers.TryGetValue('Access-Control-Request-Headers', ReqHeadersStr) and
         (not ReqHeadersStr.IsEmpty) and (not FOptions.AllowedHeaders.Contains('*')) then
      begin
        ReqHeaders := ReqHeadersStr.Split([',']);
        for HeaderItem in ReqHeaders do
        begin
          HeaderAllowed := False;
          for AllowedItem in FOptions.AllowedHeaders do
          begin
            if SameText(Trim(HeaderItem), AllowedItem) then
            begin
              HeaderAllowed := True;
              Break;
            end;
          end;
          if not HeaderAllowed then
          begin
            AContext.Response.StatusCode := 403;
            AContext.Response.Write('CORS: Header not allowed in preflight');
            Exit;
          end;
        end;
      end;

      // All preflight checks passed - emit CORS headers
      if FOptions.AllowedOrigins.Contains('*') and (not FOptions.AllowCredentials) then
        AContext.Response.AddHeader('Access-Control-Allow-Origin', '*')
      else
        AContext.Response.AddHeader('Access-Control-Allow-Origin', RequestOrigin);

      if FOptions.AllowCredentials then
        AContext.Response.AddHeader('Access-Control-Allow-Credentials', 'true');

      if Length(FOptions.AllowedMethods) > 0 then
        AContext.Response.AddHeader('Access-Control-Allow-Methods', string.Join(', ', FOptions.AllowedMethods));

      if Length(FOptions.AllowedHeaders) > 0 then
        AContext.Response.AddHeader('Access-Control-Allow-Headers', string.Join(', ', FOptions.AllowedHeaders));

      if FOptions.MaxAge > 0 then
        AContext.Response.AddHeader('Access-Control-Max-Age', IntToStr(FOptions.MaxAge));

      AContext.Response.StatusCode := 204;
      AContext.Response.SetContentType('text/plain');
      Exit;
    end;

    // Actual CORS Request (non-preflight)
    if IsOriginAllowed(RequestOrigin) then
    begin
      if FOptions.AllowedOrigins.Contains('*') and (not FOptions.AllowCredentials) then
        AContext.Response.AddHeader('Access-Control-Allow-Origin', '*')
      else
        AContext.Response.AddHeader('Access-Control-Allow-Origin', RequestOrigin);

      if FOptions.AllowCredentials then
        AContext.Response.AddHeader('Access-Control-Allow-Credentials', 'true');

      if Length(FOptions.ExposedHeaders) > 0 then
        AContext.Response.AddHeader('Access-Control-Expose-Headers', string.Join(', ', FOptions.ExposedHeaders));
    end;
  end;

  // Non-CORS OPTIONS or regular request -> continue pipeline
  ANext(AContext);
end;

function TCorsMiddleware.IsOriginAllowed(const AOrigin: string): Boolean;
begin
  if FOptions.AllowedOrigins.Contains('*') then
    Exit(True);

  if AOrigin.IsEmpty then
    Exit(False);

  Result := FOptions.AllowedOrigins.Contains(AOrigin);
end;

{ TCorsBuilder }

procedure TCorsBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    FOptions := TCorsOptions.Create;
    FInitialized := True;
  end;
end;

class function TCorsBuilder.Create: TCorsBuilder;
begin
  Result.FOptions := TCorsOptions.Create;
  Result.FInitialized := True;
end;

function TCorsBuilder.AllowAnyHeader: TCorsBuilder;
begin
  EnsureInitialized;
  FOptions.AllowedHeaders := ['*'];
  Result := Self;
end;

function TCorsBuilder.AllowAnyMethod: TCorsBuilder;
begin
  EnsureInitialized;
  FOptions.AllowedMethods := ['*'];
  Result := Self;
end;

function TCorsBuilder.AllowAnyOrigin: TCorsBuilder;
begin
  EnsureInitialized;
  FOptions.AllowedOrigins := ['*'];
  Result := Self;
end;

function TCorsBuilder.AllowCredentials: TCorsBuilder;
begin
  EnsureInitialized;
  FOptions.AllowCredentials := True;
  Result := Self;
end;

function TCorsBuilder.Build: TCorsOptions;
begin
  EnsureInitialized;
  if FOptions.AllowedOrigins.Contains('*') and FOptions.AllowCredentials then
    raise Exception.Create(
      'CORS Security Error: Combining AllowAnyOrigin ("*") with AllowCredentials ' +
      'is forbidden by the W3C Fetch specification to prevent CSRF vulnerabilities.'
    );
  Result := FOptions;
end;

class operator TCorsBuilder.Implicit(const ABuilder: TCorsBuilder): TCorsOptions;
begin
  Result := ABuilder.FOptions;
end;

// =====================================================================
// New API implementations (without 'With' prefix)
// =====================================================================

function TCorsBuilder.Origins(const AOrigins: TArray<string>): TCorsBuilder;
begin
  EnsureInitialized;
  FOptions.AllowedOrigins := AOrigins;
  Result := Self;
end;

function TCorsBuilder.Methods(const AMethods: TArray<string>): TCorsBuilder;
begin
  EnsureInitialized;
  FOptions.AllowedMethods := AMethods;
  Result := Self;
end;

function TCorsBuilder.Headers(const AHeaders: TArray<string>): TCorsBuilder;
begin
  EnsureInitialized;
  FOptions.AllowedHeaders := AHeaders;
  Result := Self;
end;

function TCorsBuilder.ExposedHeaders(const AHeaders: TArray<string>): TCorsBuilder;
begin
  EnsureInitialized;
  FOptions.ExposedHeaders := AHeaders;
  Result := Self;
end;

function TCorsBuilder.MaxAge(ASeconds: Integer): TCorsBuilder;
begin
  EnsureInitialized;
  FOptions.MaxAge := ASeconds;
  Result := Self;
end;

// =====================================================================
// Deprecated API implementations (delegate to new methods)
// =====================================================================

function TCorsBuilder.WithOrigins(const AOrigins: TArray<string>): TCorsBuilder;
begin
  Result := Origins(AOrigins);
end;

function TCorsBuilder.WithMethods(const AMethods: TArray<string>): TCorsBuilder;
begin
  Result := Methods(AMethods);
end;

function TCorsBuilder.WithHeaders(const AHeaders: TArray<string>): TCorsBuilder;
begin
  Result := Headers(AHeaders);
end;

function TCorsBuilder.WithExposedHeaders(const AHeaders: TArray<string>): TCorsBuilder;
begin
  Result := ExposedHeaders(AHeaders);
end;

function TCorsBuilder.WithMaxAge(ASeconds: Integer): TCorsBuilder;
begin
  Result := MaxAge(ASeconds);
end;

{ TApplicationBuilderCorsExtensions }

class function TApplicationBuilderCorsExtensions.UseCors(
  const ABuilder: IApplicationBuilder): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TCorsMiddleware, TCorsOptions.Create);
end;

class function TApplicationBuilderCorsExtensions.UseCors(
  const ABuilder: IApplicationBuilder; const AOptions: TCorsOptions): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TCorsMiddleware, AOptions);
end;

class function TApplicationBuilderCorsExtensions.UseCors(
  const ABuilder: IApplicationBuilder; AConfigurator: TProc<TCorsBuilder>): IApplicationBuilder;
var
  Builder: TCorsBuilder;
begin
  Builder := TCorsBuilder.Create;
  if Assigned(AConfigurator) then
    AConfigurator(Builder);

  Result := ABuilder.UseMiddleware(TCorsMiddleware, Builder.Build);
end;

class function TApplicationBuilderCorsExtensions.UseCors(
  const ABuilder: IApplicationBuilder; const ACorsBuilder: TCorsBuilder): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TCorsMiddleware, ACorsBuilder.Build);
end;

{ TCorsOptionsHelper }

class operator TCorsOptionsHelper.Implicit(const AValue: TCorsOptions): TValue;
begin
  Result := TValue.From<TCorsOptions>(AValue);
end;

end.
