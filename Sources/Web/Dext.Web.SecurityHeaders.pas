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
unit Dext.Web.SecurityHeaders;

interface

uses
  System.SysUtils,
  Dext.Web.Builder,
  Dext.Web.Interfaces;

type
  /// <summary>
  ///   Configuration options for Security Headers middleware.
  /// </summary>
  /// <summary>
  ///   Configuration options for Security Headers middleware.
  /// </summary>
  TSecurityHeadersOptions = record
  public
    /// <summary> Enables HSTS (HTTP Strict Transport Security) header. </summary>
    EnableHsts: Boolean;
    /// <summary> HSTS max-age directive in seconds. </summary>
    HstsMaxAgeSeconds: Integer;
    /// <summary> Includes subdomains directive in HSTS header. </summary>
    HstsIncludeSubDomains: Boolean;
    /// <summary> X-Content-Type-Options header value (e.g. 'nosniff'). </summary>
    ContentTypeOptions: string;
    /// <summary> X-Frame-Options header value (e.g. 'SAMEORIGIN', 'DENY'). </summary>
    FrameOptions: string;
    /// <summary> Referrer-Policy header value. </summary>
    ReferrerPolicy: string;
    /// <summary> Content-Security-Policy header value. </summary>
    ContentSecurityPolicy: string;
    
    /// <summary> Creates default TSecurityHeadersOptions. </summary>
    class function Create: TSecurityHeadersOptions; static;
  end;

  /// <summary>
  ///   Fluent builder for Security Headers options.
  /// </summary>
  TSecurityHeadersBuilder = record
  private
    FOptions: TSecurityHeadersOptions;
    FInitialized: Boolean;
    procedure EnsureInitialized;
  public
    /// <summary> Creates a new TSecurityHeadersBuilder. </summary>
    class function Create: TSecurityHeadersBuilder; static;
    /// <summary> Configures HSTS max-age and includeSubDomains settings. </summary>
    function Hsts(AMaxAgeSeconds: Integer = 31536000; AIncludeSubDomains: Boolean = True): TSecurityHeadersBuilder;
    /// <summary> Configures X-Frame-Options header (e.g. 'SAMEORIGIN'). </summary>
    function FrameOptions(const AOption: string): TSecurityHeadersBuilder;
    /// <summary> Configures X-Content-Type-Options header (e.g. 'nosniff'). </summary>
    function ContentTypeOptions(const AOption: string = 'nosniff'): TSecurityHeadersBuilder;
    /// <summary> Configures Referrer-Policy header. </summary>
    function ReferrerPolicy(const APolicy: string): TSecurityHeadersBuilder;
    /// <summary> Configures Content-Security-Policy header. </summary>
    function ContentSecurityPolicy(const ACsp: string): TSecurityHeadersBuilder;
    /// <summary> Builds and returns configured TSecurityHeadersOptions. </summary>
    function Build: TSecurityHeadersOptions;
    /// <summary> Implicit conversion operator from builder to options. </summary>
    class operator Implicit(const ABuilder: TSecurityHeadersBuilder): TSecurityHeadersOptions;
  end;

  /// <summary>
  ///   Middleware that injects HTTP Security Headers into responses.
  /// </summary>
  TSecurityHeadersMiddleware = class(TMiddleware)
  private
    FOptions: TSecurityHeadersOptions;
  public
    /// <summary> Creates a new security headers middleware with default options. </summary>
    constructor Create; overload;
    /// <summary> Creates a new security headers middleware with custom options. </summary>
    constructor Create(const AOptions: TSecurityHeadersOptions); overload;
    /// <summary> Invokes security headers middleware in the HTTP pipeline. </summary>
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

/// <summary> Factory function returning a fluent TSecurityHeadersBuilder instance. </summary>
function SecurityHeadersOptions: TSecurityHeadersBuilder;

implementation

function SecurityHeadersOptions: TSecurityHeadersBuilder;
begin
  Result := TSecurityHeadersBuilder.Create;
end;

{ TSecurityHeadersOptions }

class function TSecurityHeadersOptions.Create: TSecurityHeadersOptions;
begin
  Result.EnableHsts := True;
  Result.HstsMaxAgeSeconds := 31536000; // 1 year
  Result.HstsIncludeSubDomains := True;
  Result.ContentTypeOptions := 'nosniff';
  Result.FrameOptions := 'SAMEORIGIN';
  Result.ReferrerPolicy := 'strict-origin-when-cross-origin';
  Result.ContentSecurityPolicy := '';
end;

{ TSecurityHeadersBuilder }

class function TSecurityHeadersBuilder.Create: TSecurityHeadersBuilder;
begin
  Result.FOptions := TSecurityHeadersOptions.Create;
  Result.FInitialized := True;
end;

procedure TSecurityHeadersBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    FOptions := TSecurityHeadersOptions.Create;
    FInitialized := True;
  end;
end;

function TSecurityHeadersBuilder.Hsts(AMaxAgeSeconds: Integer; AIncludeSubDomains: Boolean): TSecurityHeadersBuilder;
begin
  EnsureInitialized;
  FOptions.EnableHsts := True;
  FOptions.HstsMaxAgeSeconds := AMaxAgeSeconds;
  FOptions.HstsIncludeSubDomains := AIncludeSubDomains;
  Result := Self;
end;

function TSecurityHeadersBuilder.FrameOptions(const AOption: string): TSecurityHeadersBuilder;
begin
  EnsureInitialized;
  FOptions.FrameOptions := AOption;
  Result := Self;
end;

function TSecurityHeadersBuilder.ContentTypeOptions(const AOption: string): TSecurityHeadersBuilder;
begin
  EnsureInitialized;
  FOptions.ContentTypeOptions := AOption;
  Result := Self;
end;

function TSecurityHeadersBuilder.ReferrerPolicy(const APolicy: string): TSecurityHeadersBuilder;
begin
  EnsureInitialized;
  FOptions.ReferrerPolicy := APolicy;
  Result := Self;
end;

function TSecurityHeadersBuilder.ContentSecurityPolicy(const ACsp: string): TSecurityHeadersBuilder;
begin
  EnsureInitialized;
  FOptions.ContentSecurityPolicy := ACsp;
  Result := Self;
end;

function TSecurityHeadersBuilder.Build: TSecurityHeadersOptions;
begin
  EnsureInitialized;
  Result := FOptions;
end;

class operator TSecurityHeadersBuilder.Implicit(const ABuilder: TSecurityHeadersBuilder): TSecurityHeadersOptions;
begin
  Result := ABuilder.Build;
end;

{ TSecurityHeadersMiddleware }

constructor TSecurityHeadersMiddleware.Create;
begin
  inherited Create;
  FOptions := TSecurityHeadersOptions.Create;
end;

constructor TSecurityHeadersMiddleware.Create(const AOptions: TSecurityHeadersOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

procedure TSecurityHeadersMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  HstsVal: string;
begin
  if FOptions.ContentTypeOptions <> '' then
    AContext.Response.AddHeader('X-Content-Type-Options', FOptions.ContentTypeOptions);

  if FOptions.FrameOptions <> '' then
    AContext.Response.AddHeader('X-Frame-Options', FOptions.FrameOptions);

  if FOptions.ReferrerPolicy <> '' then
    AContext.Response.AddHeader('Referrer-Policy', FOptions.ReferrerPolicy);

  if FOptions.ContentSecurityPolicy <> '' then
    AContext.Response.AddHeader('Content-Security-Policy', FOptions.ContentSecurityPolicy);

  if FOptions.EnableHsts then
  begin
    HstsVal := 'max-age=' + IntToStr(FOptions.HstsMaxAgeSeconds);
    if FOptions.HstsIncludeSubDomains then
      HstsVal := HstsVal + '; includeSubDomains';
    AContext.Response.AddHeader('Strict-Transport-Security', HstsVal);
  end;

  ANext(AContext);
end;

end.
