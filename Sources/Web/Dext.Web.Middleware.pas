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
// Dext.Web.Middleware.pas
unit Dext.Web.Middleware;

interface

uses
  System.Classes,
  System.Diagnostics,
  System.SysUtils,
  Dext.Collections.Dict,
  Dext.Types.UUID,
  Dext.Web.Builder,
  Dext.Web.Interfaces,
  Dext.Logging,
  Dext.Utils;

type
  // Common HTTP Exceptions
  /// <summary>
  ///   Base class for exceptions that result in specific HTTP status codes.
  /// </summary>
  EHttpException = class(Exception)
  private
    FStatusCode: Integer;
  public
    constructor Create(const AMessage: string; AStatusCode: Integer);
    property StatusCode: Integer read FStatusCode;
  end;

  /// <summary> Exception representing HTTP 404 Not Found. </summary>
  ENotFoundException = class(EHttpException)
  public
    /// <summary> Creates a new HTTP 404 exception. </summary>
    constructor Create(const AMessage: string = 'Not Found');
  end;

  /// <summary> Exception representing HTTP 401 Unauthorized. </summary>
  EUnauthorizedException = class(EHttpException)
  public
    /// <summary> Creates a new HTTP 401 exception. </summary>
    constructor Create(const AMessage: string = 'Unauthorized');
  end;

  /// <summary> Exception representing HTTP 403 Forbidden. </summary>
  EForbiddenException = class(EHttpException)
  public
    /// <summary> Creates a new HTTP 403 exception. </summary>
    constructor Create(const AMessage: string = 'Forbidden');
  end;
  
  /// <summary> Exception representing HTTP 400 Bad Request / Validation Failure. </summary>
  EValidationException = class(EHttpException)
  public
    /// <summary> Creates a new validation exception. </summary>
    constructor Create(const AMessage: string = 'Validation Failed');
  end;

  /// <summary>
  ///   Domain invariant / business-rule violation mapped to HTTP 422 Unprocessable Entity
  ///   by <see cref="TExceptionHandlerMiddleware"/> (RFC 9457 Problem Details).
  /// </summary>
  EDomainException = class(EHttpException)
  public
    /// <summary>Creates a domain exception (HTTP 422).</summary>
    constructor Create(const AMessage: string = 'Domain rule violated');
  end;

  /// <summary>Alias for <see cref="EDomainException"/> emphasizing validation semantics.</summary>
  EDomainValidationException = EDomainException;

  // --- Exception Handling ---

  /// <summary> Options for configuring global exception handling middleware. </summary>
  TExceptionHandlerOptions = record
    /// <summary> Whether to enable development mode details and stack traces. </summary>
    IsDevelopment: Boolean;
    /// <summary> Whether to include exception stack trace in Problem Details payload. </summary>
    IncludeStackTrace: Boolean;
    /// <summary> Whether to log caught exceptions to the logging framework. </summary>
    LogExceptions: Boolean;
    /// <summary> Configures options pre-set for Development mode. </summary>
    class function Development: TExceptionHandlerOptions; static;
    /// <summary> Configures options pre-set for Production mode (sanitized 500 errors). </summary>
    class function Production: TExceptionHandlerOptions; static;
  end;

  /// <summary> Fluent builder for TExceptionHandlerOptions. </summary>
  TExceptionHandlerBuilder = record
  private
    FOptions: TExceptionHandlerOptions;
    FInitialized: Boolean;
    procedure EnsureInitialized;
  public
    /// <summary> Creates a new exception handler builder. </summary>
    class function Create: TExceptionHandlerBuilder; static;
    /// <summary> Configures Development mode flag. </summary>
    function Development(AValue: Boolean = True): TExceptionHandlerBuilder;
    /// <summary> Configures whether to include stack traces. </summary>
    function IncludeStackTrace(AValue: Boolean = True): TExceptionHandlerBuilder;
    /// <summary> Configures whether to log exceptions. </summary>
    function LogExceptions(AValue: Boolean = True): TExceptionHandlerBuilder;
    /// <summary> Builds and returns TExceptionHandlerOptions. </summary>
    function Build: TExceptionHandlerOptions;
    /// <summary> Implicit conversion operator from builder to options. </summary>
    class operator Implicit(const ABuilder: TExceptionHandlerBuilder): TExceptionHandlerOptions;
  end;

  /// <summary>
  ///   Structure to report HTTP errors following the RFC 9457 (Problem Details, obsoletes RFC 7807) standard.
  /// </summary>
  TProblemDetails = record
    /// <summary> URI reference identifying the problem type. </summary>
    &Type: string;
    /// <summary> Short, human-readable summary of the problem type. </summary>
    Title: string;
    /// <summary> HTTP status code generated by origin server for this occurrence. </summary>
    Status: Integer;
    /// <summary> Human-readable explanation specific to this occurrence. </summary>
    Detail: string;
    /// <summary> URI reference identifying the specific occurrence of the problem. </summary>
    Instance: string;
    /// <summary> Correlation trace ID for tracking error across telemetry logs. </summary>
    TraceId: string;
    /// <summary> Serializes Problem Details structure to RFC 9457 JSON string. </summary>
    function ToJson: string;
  end;

  /// <summary>
  ///   Middleware responsible for capturing unhandled exceptions and returning standardized responses.
  /// </summary>
  TExceptionHandlerMiddleware = class(TMiddleware)
  private
    FLogger: ILogger;
    FOptions: TExceptionHandlerOptions;
  public
    /// <summary> Creates a new exception handler middleware instance. </summary>
    constructor Create(AOptions: TExceptionHandlerOptions; ALogger: ILogger);
    /// <summary> Invokes exception handler middleware logic in the HTTP pipeline. </summary>
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;
  
  // Minimal implementation reuse TExceptionHandlerMiddleware logic with Development options
  /// <summary>
  ///   Middleware that displays a detailed error page during development.
  /// </summary>
  TDeveloperExceptionPageMiddleware = class(TExceptionHandlerMiddleware)
  public
    /// <summary> Creates developer exception page middleware with default logger. </summary>
    constructor Create(ALogger: ILogger);
  end;

  // --- HTTP Logging ---

  /// <summary> Options for configuring HTTP request/response logging middleware. </summary>
  THttpLoggingOptions = record
    /// <summary> Whether to log request headers. </summary>
    LogRequestHeaders: Boolean;
    /// <summary> Whether to log request payload body. </summary>
    LogRequestBody: Boolean;
    /// <summary> Whether to log response payload body. </summary>
    LogResponseBody: Boolean;
    /// <summary> Maximum payload body size to read for logging (bytes). </summary>
    MaxBodySize: Integer;
    /// <summary> List of header keys to redact from logs (e.g. Authorization, Cookie). </summary>
    RedactHeaders: TArray<string>;
    /// <summary> Returns default THttpLoggingOptions. </summary>
    class function Default: THttpLoggingOptions; static;
  end;

  /// <summary> Fluent builder for THttpLoggingOptions. </summary>
  THttpLoggingBuilder = record
  private
    FOptions: THttpLoggingOptions;
    FInitialized: Boolean;
    procedure EnsureInitialized;
  public
    /// <summary> Creates a new HTTP logging builder. </summary>
    class function Create: THttpLoggingBuilder; static;
    /// <summary> Configures whether to log headers. </summary>
    function LogHeaders(AValue: Boolean = True): THttpLoggingBuilder;
    /// <summary> Configures whether to log request body. </summary>
    function LogRequestBody(AValue: Boolean = True): THttpLoggingBuilder;
    /// <summary> Configures whether to log response body. </summary>
    function LogResponseBody(AValue: Boolean = True): THttpLoggingBuilder;
    /// <summary> Sets maximum payload body size to log. </summary>
    function MaxBodySize(ASize: Integer): THttpLoggingBuilder;
    /// <summary> Adds a header key to redact list. </summary>
    function RedactHeader(const AName: string): THttpLoggingBuilder;
    /// <summary> Adds multiple header keys to redact list. </summary>
    function RedactHeaders(const ANames: array of string): THttpLoggingBuilder;
    /// <summary> Builds and returns THttpLoggingOptions. </summary>
    function Build: THttpLoggingOptions;
    /// <summary> Implicit conversion operator from builder to options. </summary>
    class operator Implicit(const ABuilder: THttpLoggingBuilder): THttpLoggingOptions;
  end;

  /// <summary>
  ///   Middleware for logging details of HTTP requests and responses.
  /// </summary>
  THttpLoggingMiddleware = class(TMiddleware)
  private
    FLogger: ILogger;
    FOptions: THttpLoggingOptions;
  public
    /// <summary> Creates a new HTTP logging middleware instance. </summary>
    constructor Create(AOptions: THttpLoggingOptions; ALogger: ILogger);
    /// <summary> Invokes HTTP logging middleware logic in pipeline. </summary>
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

/// <summary> Factory function returning a fluent TExceptionHandlerBuilder instance. </summary>
function ExceptionHandlerOptions: TExceptionHandlerBuilder;
/// <summary> Factory function returning a fluent THttpLoggingBuilder instance. </summary>
function HttpLoggingOptions: THttpLoggingBuilder;

implementation

{ EHttpException }

constructor EHttpException.Create(const AMessage: string; AStatusCode: Integer);
begin
  inherited Create(AMessage);
  FStatusCode := AStatusCode;
end;

{ ENotFoundException }

constructor ENotFoundException.Create(const AMessage: string);
begin
  inherited Create(AMessage, 404);
end;

{ EUnauthorizedException }

constructor EUnauthorizedException.Create(const AMessage: string);
begin
  inherited Create(AMessage, 401);
end;

{ EForbiddenException }

constructor EForbiddenException.Create(const AMessage: string);
begin
  inherited Create(AMessage, 403);
end;

{ EValidationException }

constructor EValidationException.Create(const AMessage: string);
begin
  inherited Create(AMessage, 400);
end;

{ EDomainException }

constructor EDomainException.Create(const AMessage: string);
begin
  inherited Create(AMessage, 422);
end;

{ TExceptionHandlerOptions }

class function TExceptionHandlerOptions.Development: TExceptionHandlerOptions;
begin
  Result.IsDevelopment := True;
  Result.IncludeStackTrace := True;
  Result.LogExceptions := True;
end;

class function TExceptionHandlerOptions.Production: TExceptionHandlerOptions;
begin
  Result.IsDevelopment := False;
  Result.IncludeStackTrace := False;
  Result.LogExceptions := True;
end;

function EscapeJsonString(const AValue: string): string;
var
  Ch: Char;
begin
  Result := '';
  for Ch in AValue do
  begin
    case Ch of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #8:  Result := Result + '\b';
      #12: Result := Result + '\f';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9:  Result := Result + '\t';
    else
      if Ord(Ch) < 32 then
        Result := Result + '\u' + IntToHex(Ord(Ch), 4)
      else
        Result := Result + Ch;
    end;
  end;
end;

{ TProblemDetails }

function TProblemDetails.ToJson: string;
begin
  Result := Format(
    '{' +
    '"type": "%s",' +
    '"title": "%s",' +
    '"status": %d,' +
    '"detail": "%s",' +
    '"instance": "%s",' +
    '"traceId": "%s"' +
    '}',
    [EscapeJsonString(&Type), EscapeJsonString(Title), Status, 
     EscapeJsonString(Detail), EscapeJsonString(Instance), 
     EscapeJsonString(TraceId)]);
end;

{ TDeveloperExceptionPageMiddleware }

constructor TDeveloperExceptionPageMiddleware.Create(ALogger: ILogger);
begin
  inherited Create(TExceptionHandlerOptions.Development, ALogger);
end;

{ TExceptionHandlerMiddleware }

constructor TExceptionHandlerMiddleware.Create(AOptions: TExceptionHandlerOptions; ALogger: ILogger);
begin
  inherited Create;
  FLogger := ALogger;
  FOptions := AOptions;
end;

procedure TExceptionHandlerMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  Problem: TProblemDetails;
begin
  try
    ANext(AContext);
  except
    on E: Exception do
    begin
      if FOptions.LogExceptions then
      begin
        SafeWriteLn(Format('[Exception] Unhandled: %s: %s', [E.ClassName, E.Message]));
        if FLogger <> nil then
          FLogger.LogError(E, 'An unhandled exception has occurred while executing the request.', []);
      end;

      // Note: We can't easily check if response has started without extending IHttpResponse.
      // Assuming we can write.

      Problem.Status := 500;
      Problem.Title := 'An error occurred while processing your request.';
      Problem.Detail := E.Message;
      Problem.Instance := AContext.Request.Path;
      
      Problem.TraceId := '';
      if AContext.Request.Headers.TryGetValue('X-Request-ID', Problem.TraceId) and (not Problem.TraceId.IsEmpty) then
        // TraceId extracted
      else if AContext.Request.Headers.TryGetValue('traceparent', Problem.TraceId) and (not Problem.TraceId.IsEmpty) then
        // TraceId extracted from W3C header
      else
        Problem.TraceId := TUUID.NewV7.ToString;
        
      Problem.&Type := 'about:blank';

      if E is EHttpException then
      begin
        Problem.Status := EHttpException(E).StatusCode;
        Problem.Title := E.Message; 
        
        if E is ENotFoundException then Problem.Title := 'Not Found'
        else if E is EUnauthorizedException then Problem.Title := 'Unauthorized'
        else if E is EForbiddenException then Problem.Title := 'Forbidden'
        else if E is EValidationException then Problem.Title := 'Validation Failed'
        else if E is EDomainException then
        begin
          Problem.Title := 'Unprocessable Entity';
          Problem.&Type := 'https://dext.dev/errors/domain-validation';
        end;
      end;

      if not FOptions.IsDevelopment then
      begin
        if Problem.Status = 500 then
          Problem.Detail := 'An unhandled server error has occurred. Refer to traceId: ' + Problem.TraceId;
      end
      else
      begin
        Problem.Detail := Format('%s: %s', [E.ClassName, E.Message]);
      end;

      AContext.Response.StatusCode := Problem.Status;
      AContext.Response.SetContentType('application/problem+json');
      AContext.Response.Write(Problem.ToJson);
    end;
  end;
end;

{ THttpLoggingOptions }

class function THttpLoggingOptions.Default: THttpLoggingOptions;
begin
  Result.LogRequestHeaders := False;
  Result.LogRequestBody := False;
  Result.LogResponseBody := False;
  Result.MaxBodySize := 32 * 1024; // 32KB
  Result.RedactHeaders := ['authorization', 'cookie', 'set-cookie', 'x-api-key', 'proxy-authorization'];
end;

{ THttpLoggingMiddleware }

constructor THttpLoggingMiddleware.Create(AOptions: THttpLoggingOptions; ALogger: ILogger);
begin
  // inherited Create;
  FLogger := ALogger;
  FOptions := AOptions;
end;

procedure THttpLoggingMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  Stopwatch: TStopwatch;
  BodyStream: TStream;
  BodyContent: string;
  Buffer: TBytes;
  OldPos: Int64;
  HeaderPairs: TArray<TPair<string, string>>;
  Pair: TPair<string, string>;
  HeaderName, HeaderValue: string;
  LogHeadersStr: string;
  IsRedacted: Boolean;
  RedactKey: string;
  InfoEnabled, DebugEnabled: Boolean;
begin
  InfoEnabled := (FLogger <> nil) and FLogger.IsEnabled(TLogLevel.Information);
  DebugEnabled := (FLogger <> nil) and FLogger.IsEnabled(TLogLevel.Debug);
  if InfoEnabled then
  begin
    Stopwatch := TStopwatch.StartNew;
    FLogger.LogInformation('Request starting {Protocol} {Method} {Path}', 
      ['HTTP/1.1', AContext.Request.Method, AContext.Request.Path]);
  end;

  // Log Headers with Redaction
  if (FLogger <> nil) and FOptions.LogRequestHeaders and (AContext.Request.Headers <> nil) then
  begin
    HeaderPairs := AContext.Request.Headers.ToArray;
    LogHeadersStr := '';
    for Pair in HeaderPairs do
    begin
      HeaderName := Pair.Key;
      HeaderValue := Pair.Value;
      IsRedacted := False;
      for RedactKey in FOptions.RedactHeaders do
      begin
        if SameText(HeaderName, RedactKey) then
        begin
          IsRedacted := True;
          Break;
        end;
      end;
      if IsRedacted then
        HeaderValue := '[REDACTED]';
      if LogHeadersStr <> '' then
        LogHeadersStr := LogHeadersStr + ', ';
      LogHeadersStr := LogHeadersStr + HeaderName + '=' + HeaderValue;
    end;
    FLogger.LogInformation('Request Headers: {Headers}', [LogHeadersStr]);
  end;

  // Log Body
  BodyStream := AContext.Request.Body;
  if DebugEnabled and FOptions.LogRequestBody and (BodyStream <> nil) and (BodyStream.Size > 0) then
  begin
    if BodyStream.Size <= FOptions.MaxBodySize then
    begin
      OldPos := BodyStream.Position;
      try
        BodyStream.Position := 0;
        SetLength(Buffer, BodyStream.Size);
        BodyStream.Read(Buffer, BodyStream.Size);
        BodyContent := TEncoding.UTF8.GetString(Buffer);
        FLogger.LogDebug('Request Body: {Body}', [BodyContent]);
      finally
        BodyStream.Position := OldPos;
      end;
    end
    else
    begin
      FLogger.LogDebug('Request Body: [Truncated - Size: {Size} bytes]', [BodyStream.Size]);
    end;
  end;

  try
    ANext(AContext);
  finally
    if InfoEnabled then
    begin
      Stopwatch.Stop;
      FLogger.LogInformation('Request finished {Protocol} {Method} {Path} - {StatusCode} {Elapsed}ms',
        ['HTTP/1.1', AContext.Request.Method, AContext.Request.Path, AContext.Response.StatusCode, Stopwatch.ElapsedMilliseconds]);
    end;
  end;
end;

function ExceptionHandlerOptions: TExceptionHandlerBuilder;
begin
  Result := TExceptionHandlerBuilder.Create;
end;

function HttpLoggingOptions: THttpLoggingBuilder;
begin
  Result := THttpLoggingBuilder.Create;
end;

{ TExceptionHandlerBuilder }

class function TExceptionHandlerBuilder.Create: TExceptionHandlerBuilder;
begin
  Result.FOptions := TExceptionHandlerOptions.Production;
  Result.FInitialized := True;
end;

procedure TExceptionHandlerBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    FOptions := TExceptionHandlerOptions.Production;
    FInitialized := True;
  end;
end;

function TExceptionHandlerBuilder.Development(AValue: Boolean): TExceptionHandlerBuilder;
begin
  EnsureInitialized;
  FOptions.IsDevelopment := AValue;
  if AValue then
    FOptions.IncludeStackTrace := True;
  Result := Self;
end;

function TExceptionHandlerBuilder.IncludeStackTrace(AValue: Boolean): TExceptionHandlerBuilder;
begin
  EnsureInitialized;
  FOptions.IncludeStackTrace := AValue;
  Result := Self;
end;

function TExceptionHandlerBuilder.LogExceptions(AValue: Boolean): TExceptionHandlerBuilder;
begin
  EnsureInitialized;
  FOptions.LogExceptions := AValue;
  Result := Self;
end;

function TExceptionHandlerBuilder.Build: TExceptionHandlerOptions;
begin
  EnsureInitialized;
  Result := FOptions;
end;

class operator TExceptionHandlerBuilder.Implicit(const ABuilder: TExceptionHandlerBuilder): TExceptionHandlerOptions;
begin
  Result := ABuilder.Build;
end;

{ THttpLoggingBuilder }

class function THttpLoggingBuilder.Create: THttpLoggingBuilder;
begin
  Result.FOptions := THttpLoggingOptions.Default;
  Result.FInitialized := True;
end;

procedure THttpLoggingBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    FOptions := THttpLoggingOptions.Default;
    FInitialized := True;
  end;
end;

function THttpLoggingBuilder.LogHeaders(AValue: Boolean): THttpLoggingBuilder;
begin
  EnsureInitialized;
  FOptions.LogRequestHeaders := AValue;
  Result := Self;
end;

function THttpLoggingBuilder.LogRequestBody(AValue: Boolean): THttpLoggingBuilder;
begin
  EnsureInitialized;
  FOptions.LogRequestBody := AValue;
  Result := Self;
end;

function THttpLoggingBuilder.LogResponseBody(AValue: Boolean): THttpLoggingBuilder;
begin
  EnsureInitialized;
  FOptions.LogResponseBody := AValue;
  Result := Self;
end;

function THttpLoggingBuilder.MaxBodySize(ASize: Integer): THttpLoggingBuilder;
begin
  EnsureInitialized;
  FOptions.MaxBodySize := ASize;
  Result := Self;
end;

function THttpLoggingBuilder.RedactHeader(const AName: string): THttpLoggingBuilder;
begin
  EnsureInitialized;
  SetLength(FOptions.RedactHeaders, Length(FOptions.RedactHeaders) + 1);
  FOptions.RedactHeaders[High(FOptions.RedactHeaders)] := LowerCase(AName);
  Result := Self;
end;

function THttpLoggingBuilder.RedactHeaders(const ANames: array of string): THttpLoggingBuilder;
var
  I: Integer;
begin
  EnsureInitialized;
  for I := Low(ANames) to High(ANames) do
    RedactHeader(ANames[I]);
  Result := Self;
end;

function THttpLoggingBuilder.Build: THttpLoggingOptions;
begin
  EnsureInitialized;
  Result := FOptions;
end;

class operator THttpLoggingBuilder.Implicit(const ABuilder: THttpLoggingBuilder): THttpLoggingOptions;
begin
  Result := ABuilder.Build;
end;

end.
