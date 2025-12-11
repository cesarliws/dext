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
unit Dext.Http.Cors;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Http.Core,
  Dext.Http.Interfaces;

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
    procedure AddCorsHeaders(AContext: IHttpContext);
    procedure DebugLog(const AMessage: string);
  public
    constructor Create; overload;
    constructor Create(const AOptions: TCorsOptions); overload;
    constructor Create(const AOptions: TCorsOptions; AEnableDebugLog: Boolean); overload;
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  /// <summary>
  ///   Fluent builder for creating CORS options.
  /// </summary>
  TCorsBuilder = class
  private
    FOptions: TCorsOptions;
  public
    constructor Create;
    
    /// <summary>
    ///   Specifies the allowed origins.
    /// </summary>
    function WithOrigins(const AOrigins: array of string): TCorsBuilder;
    
    /// <summary>
    ///   Allows any origin (*). Cannot be used with AllowCredentials.
    /// </summary>
    function AllowAnyOrigin: TCorsBuilder;
    
    /// <summary>
    ///   Specifies the allowed HTTP methods.
    /// </summary>
    function WithMethods(const AMethods: array of string): TCorsBuilder;
    
    /// <summary>
    ///   Allows any HTTP method.
    /// </summary>
    function AllowAnyMethod: TCorsBuilder;
    
    /// <summary>
    ///   Specifies the allowed request headers.
    /// </summary>
    function WithHeaders(const AHeaders: array of string): TCorsBuilder;
    
    /// <summary>
    ///   Allows any request header.
    /// </summary>
    function AllowAnyHeader: TCorsBuilder;
    
    /// <summary>
    ///   Specifies headers that can be exposed to the browser.
    /// </summary>
    function WithExposedHeaders(const AHeaders: array of string): TCorsBuilder;
    
    /// <summary>
    ///   Allows credentials (cookies, authorization headers).
    ///   Cannot be used with AllowAnyOrigin.
    /// </summary>
    function AllowCredentials: TCorsBuilder;
    
    /// <summary>
    ///   Sets how long (in seconds) the preflight response can be cached.
    /// </summary>
    function WithMaxAge(ASeconds: Integer): TCorsBuilder;

    /// <summary>
    ///   Builds and returns the CORS options.
    /// </summary>
    function Build: TCorsOptions;
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
    ///   Adds CORS middleware configured with a builder.
    /// </summary>
    class function UseCors(const ABuilder: IApplicationBuilder; AConfigurator: TProc<TCorsBuilder>): IApplicationBuilder; overload; static;
  end;

  /// <summary>
  ///   Helper for implicit conversion of TCorsOptions to TValue.
  /// </summary>
  TCorsOptionsHelper = record helper for TCorsOptions
  public
    class operator Implicit(const AValue: TCorsOptions): TValue;
  end;

implementation


{ TStringArrayHelper }

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

// ✅ Construtor com parâmetros
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
    WriteLn(AMessage);
end;

procedure TCorsMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  Headers: TArray<string>;
  I: Integer;
begin
  DebugLog('🚀 CORS MIDDLEWARE STARTED');
  DebugLog('📨 Request: ' + AContext.Request.Method + ' ' + AContext.Request.Path);

  // Debug: ver todos os headers da request
  if FEnableDebugLog then
  begin
    DebugLog('📋 Request Headers:');
    Headers := AContext.Request.Headers.Keys.ToArray;
    for I := 0 to High(Headers) do
      DebugLog('   ' + Headers[I] + ': ' + AContext.Request.Headers[Headers[I]]);
  end;

  // ✅ ADICIONAR HEADERS CORS
  AddCorsHeaders(AContext);

  // Se for preflight OPTIONS
  if AContext.Request.Method = 'OPTIONS' then
  begin
    DebugLog('🛬 CORS: Handling OPTIONS preflight');
    AContext.Response.StatusCode := 204; // No Content
    AContext.Response.SetContentType('text/plain');
    DebugLog('🛑 CORS: Stopping pipeline for OPTIONS');
    Exit;
  end;

  DebugLog('➡️ CORS: Continuing to next middleware');
  ANext(AContext);
  DebugLog('🏁 CORS MIDDLEWARE FINISHED');
end;

procedure TCorsMiddleware.AddCorsHeaders(AContext: IHttpContext);
var
  Origin: string;
  RequestOrigin: string;
begin
  // Obter Origin do request
  if AContext.Request.Headers.TryGetValue('origin', RequestOrigin) then
    Origin := RequestOrigin
  else
    Origin := '';

  // Verificar se origin é permitida
  if IsOriginAllowed(Origin) then
  begin
    AContext.Response.AddHeader('Access-Control-Allow-Origin', Origin);

    if FOptions.AllowCredentials then
      AContext.Response.AddHeader('Access-Control-Allow-Credentials', 'true');

    if Length(FOptions.ExposedHeaders) > 0 then
      AContext.Response.AddHeader('Access-Control-Expose-Headers',
        string.Join(', ', FOptions.ExposedHeaders));
  end
  else if FOptions.AllowedOrigins.Contains('*') then
  begin
    AContext.Response.AddHeader('Access-Control-Allow-Origin', '*');
  end;

  // Headers para preflight requests
  if AContext.Request.Method = 'OPTIONS' then
  begin
    if Length(FOptions.AllowedMethods) > 0 then
      AContext.Response.AddHeader('Access-Control-Allow-Methods',
        string.Join(', ', FOptions.AllowedMethods));

    if Length(FOptions.AllowedHeaders) > 0 then
      AContext.Response.AddHeader('Access-Control-Allow-Headers',
        string.Join(', ', FOptions.AllowedHeaders));

    if FOptions.MaxAge > 0 then
      AContext.Response.AddHeader('Access-Control-Max-Age',
        IntToStr(FOptions.MaxAge));
  end;
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

constructor TCorsBuilder.Create;
begin
  inherited Create;
  FOptions := TCorsOptions.Create;
end;

function TCorsBuilder.AllowAnyHeader: TCorsBuilder;
begin
  FOptions.AllowedHeaders := ['*'];
  Result := Self;
end;

function TCorsBuilder.AllowAnyMethod: TCorsBuilder;
begin
  FOptions.AllowedMethods := ['*'];
  Result := Self;
end;

function TCorsBuilder.AllowAnyOrigin: TCorsBuilder;
begin
  FOptions.AllowedOrigins := ['*'];
  Result := Self;
end;

function TCorsBuilder.AllowCredentials: TCorsBuilder;
begin
  FOptions.AllowCredentials := True;
  Result := Self;
end;

function TCorsBuilder.Build: TCorsOptions;
begin
  Result := FOptions;
end;

function TCorsBuilder.WithExposedHeaders(const AHeaders: array of string): TCorsBuilder;
var
  I: Integer;
begin
  SetLength(FOptions.ExposedHeaders, Length(AHeaders));
  for I := 0 to High(AHeaders) do
    FOptions.ExposedHeaders[I] := AHeaders[I];
  Result := Self;
end;

function TCorsBuilder.WithHeaders(const AHeaders: array of string): TCorsBuilder;
var
  I: Integer;
begin
  SetLength(FOptions.AllowedHeaders, Length(AHeaders));
  for I := 0 to High(AHeaders) do
    FOptions.AllowedHeaders[I] := AHeaders[I];
  Result := Self;
end;

function TCorsBuilder.WithMaxAge(ASeconds: Integer): TCorsBuilder;
begin
  FOptions.MaxAge := ASeconds;
  Result := Self;
end;

function TCorsBuilder.WithMethods(const AMethods: array of string): TCorsBuilder;
var
  I: Integer;
begin
  SetLength(FOptions.AllowedMethods, Length(AMethods));
  for I := 0 to High(AMethods) do
    FOptions.AllowedMethods[I] := AMethods[I];
  Result := Self;
end;

function TCorsBuilder.WithOrigins(const AOrigins: array of string): TCorsBuilder;
var
  I: Integer;
begin
  SetLength(FOptions.AllowedOrigins, Length(AOrigins));
  for I := 0 to High(AOrigins) do
    FOptions.AllowedOrigins[I] := AOrigins[I];
  Result := Self;
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
  Options: TCorsOptions;
begin
  Builder := TCorsBuilder.Create;
  try
    if Assigned(AConfigurator) then
      AConfigurator(Builder);
    Options := Builder.Build;
  finally
    Builder.Free;
  end;

  Result := ABuilder.UseMiddleware(TCorsMiddleware, Options);
end;

{ TCorsOptionsHelper }

class operator TCorsOptionsHelper.Implicit(const AValue: TCorsOptions): TValue;
begin
  Result := TValue.From<TCorsOptions>(AValue);
end;

end.

