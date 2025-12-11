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
// Dext.Http.Middleware.pas
unit Dext.Http.Middleware;

interface

uses
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.SysUtils,
  Dext.Http.Core,
  Dext.Http.Interfaces,
  Dext.Logging;

type
  // Common HTTP Exceptions
  EHttpException = class(Exception)
  private
    FStatusCode: Integer;
  public
    constructor Create(const AMessage: string; AStatusCode: Integer);
    property StatusCode: Integer read FStatusCode;
  end;

  ENotFoundException = class(EHttpException)
  public
    constructor Create(const AMessage: string = 'Not Found');
  end;

  EUnauthorizedException = class(EHttpException)
  public
    constructor Create(const AMessage: string = 'Unauthorized');
  end;

  EForbiddenException = class(EHttpException)
  public
    constructor Create(const AMessage: string = 'Forbidden');
  end;
  
  EValidationException = class(EHttpException)
  public
    constructor Create(const AMessage: string = 'Validation Failed');
  end;

  // --- Exception Handling ---

  TExceptionHandlerOptions = record
    IsDevelopment: Boolean;
    IncludeStackTrace: Boolean;
    LogExceptions: Boolean;
    class function Development: TExceptionHandlerOptions; static;
    class function Production: TExceptionHandlerOptions; static;
  end;

  TProblemDetails = record
    &Type: string;
    Title: string;
    Status: Integer;
    Detail: string;
    Instance: string;
    TraceId: string;
    function ToJson: string;
  end;

  TExceptionHandlerMiddleware = class(TMiddleware)
  private
    FLogger: ILogger;
    FOptions: TExceptionHandlerOptions;
  public
    constructor Create(AOptions: TExceptionHandlerOptions; ALogger: ILogger);
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  // --- HTTP Logging ---

  THttpLoggingOptions = record
    LogRequestHeaders: Boolean;
    LogRequestBody: Boolean;
    LogResponseBody: Boolean;
    MaxBodySize: Integer;
    class function Default: THttpLoggingOptions; static;
  end;

  THttpLoggingMiddleware = class(TMiddleware)
  private
    FLogger: ILogger;
    FOptions: THttpLoggingOptions;
  public
    constructor Create(AOptions: THttpLoggingOptions; ALogger: ILogger);
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

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

{ TProblemDetails }

function TProblemDetails.ToJson: string;
begin
  // Simple JSON construction
  Result := Format(
    '{' +
    '"type": "%s",' +
    '"title": "%s",' +
    '"status": %d,' +
    '"detail": "%s",' +
    '"instance": "%s",' +
    '"traceId": "%s"' +
    '}',
    [&Type, Title, Status, Detail, Instance, TraceId]);
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
        FLogger.LogError(E, 'An unhandled exception has occurred while executing the request.', []);
      end;

      // Note: We can't easily check if response has started without extending IHttpResponse.
      // Assuming we can write.

      Problem.Status := 500;
      Problem.Title := 'An error occurred while processing your request.';
      Problem.Detail := E.Message;
      Problem.Instance := AContext.Request.Path;
      Problem.TraceId := ''; // TODO: Get from context items or headers
      if AContext.Request.Headers.ContainsKey('X-Request-ID') then
        Problem.TraceId := AContext.Request.Headers['X-Request-ID'];
        
      Problem.&Type := 'about:blank';

      if E is EHttpException then
      begin
        Problem.Status := EHttpException(E).StatusCode;
        Problem.Title := E.Message; 
        
        if E is ENotFoundException then Problem.Title := 'Not Found'
        else if E is EUnauthorizedException then Problem.Title := 'Unauthorized'
        else if E is EForbiddenException then Problem.Title := 'Forbidden'
        else if E is EValidationException then Problem.Title := 'Validation Failed';
      end;

      if FOptions.IsDevelopment then
      begin
        // Sanitize stack trace for JSON?
        Problem.Detail := Format('%s: %s', [E.ClassName, E.Message]);
        // Stack trace might be too long or contain newlines breaking simple JSON format above.
        // Keeping it simple for now.
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
  Header: TPair<string, string>;
  BodyStream: TStream;
  BodyContent: string;
  Buffer: TBytes;
begin
  Stopwatch := TStopwatch.StartNew;
  
  FLogger.LogInformation('Request starting {Protocol} {Method} {Path}', 
    ['HTTP/1.1', AContext.Request.Method, AContext.Request.Path]);

  // Log Headers
  if FOptions.LogRequestHeaders then
  begin
    for Header in AContext.Request.Headers do
      FLogger.LogDebug('Header: {Name}: {Value}', [Header.Key, Header.Value]);
  end;

  // Log Body
  if FOptions.LogRequestBody and (AContext.Request.Body <> nil) and (AContext.Request.Body.Size > 0) then
  begin
    BodyStream := AContext.Request.Body;
    if BodyStream.Size <= FOptions.MaxBodySize then
    begin
      var OldPos := BodyStream.Position;
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
    Stopwatch.Stop;
    FLogger.LogInformation('Request finished {Protocol} {Method} {Path} - {StatusCode} {Elapsed}ms',
      ['HTTP/1.1', AContext.Request.Method, AContext.Request.Path, AContext.Response.StatusCode, Stopwatch.ElapsedMilliseconds]);
  end;
end;

end.

