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
unit Dext.Swagger.Middleware;

interface

uses
  System.SysUtils,
  Dext.Web.Interfaces,
  Dext.Web.Builder,
  Dext.OpenAPI.Generator,
  Dext.OpenAPI.Types;

type
  /// <summary>
  ///   Middleware responsible for serving the visual interface of Swagger UI and the OpenAPI document (JSON).
  ///   Optimized to cache the JSON schema during initialization for maximum performance.
  /// </summary>
  TSwaggerMiddleware = class(TMiddleware)
  private
    FOptions: TOpenAPIOptions;
    FSwaggerPath: string;
    FJsonPath: string;
    FGenerator: TOpenAPIGenerator;
    FCachedJson: string;
    // Removed FAppBuilder to break circular reference - routes cached in constructor
    
    function GetSwaggerUIHtml(const AJsonUrl: string): string;
    function ShouldHandleRequest(const APath: string): Boolean;
    procedure HandleSwaggerUI(AContext: IHttpContext);
    procedure HandleSwaggerJson(AContext: IHttpContext);
  public
    constructor Create(AAppBuilder: IApplicationBuilder; const AOptions: TOpenAPIOptions; const ASwaggerPath: string = '/swagger'; const AJsonPath: string = '/swagger.json');
    destructor Destroy; override;
    
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  /// <summary>
  ///   Extension methods to enable interactive Swagger documentation in the application pipeline.
  /// </summary>
  TSwaggerExtensions = class
  public
    /// <summary>
    ///   Adds Swagger middleware to the application pipeline.
    /// </summary>
    class function UseSwagger(App: IApplicationBuilder; const AOptions: TOpenAPIOptions): IApplicationBuilder; overload;
    class function UseSwagger(App: IApplicationBuilder): IApplicationBuilder; overload;
  end;

implementation

uses
  System.Rtti,
  Dext.DI.Interfaces;

{ TSwaggerMiddleware }

constructor TSwaggerMiddleware.Create(AAppBuilder: IApplicationBuilder; const AOptions: TOpenAPIOptions; const ASwaggerPath: string; const AJsonPath: string);
var
  Endpoints: TArray<TEndpointMetadata>;
begin
  inherited Create;
  FOptions := AOptions;
  
  // Use paths from options if provided, otherwise use parameters (for backward compatibility)
  if (ASwaggerPath = '/swagger') and (AOptions.SwaggerPath <> '') then
    FSwaggerPath := AOptions.SwaggerPath
  else
    FSwaggerPath := ASwaggerPath;
    
  if (AJsonPath = '/swagger.json') and (AOptions.SwaggerJsonPath <> '') then
    FJsonPath := AOptions.SwaggerJsonPath
  else
    FJsonPath := AJsonPath;
    
  FGenerator := TOpenAPIGenerator.Create(AOptions);
  
  // Cache routes and generate JSON immediately to avoid holding AppBuilder reference
  Endpoints := AAppBuilder.GetRoutes;
  FCachedJson := FGenerator.GenerateJson(Endpoints);
  // AAppBuilder reference released here (not stored)
end;

destructor TSwaggerMiddleware.Destroy;
begin
  FGenerator.Free;
  inherited;
end;

function TSwaggerMiddleware.ShouldHandleRequest(const APath: string): Boolean;
begin
  Result := APath.Equals(FSwaggerPath) or APath.Equals(FJsonPath);
end;

// AJsonUrl is passed in rather than read from FJsonPath, because the URL the
// browser has to request depends on the request: under a PathBase the spec
// lives at <base>/swagger.json, not at /swagger.json.
function TSwaggerMiddleware.GetSwaggerUIHtml(const AJsonUrl: string): string;
begin
  Result := 
    '<!DOCTYPE html>' + sLineBreak +
    '<html lang="en">' + sLineBreak +
    '<head>' + sLineBreak +
    '  <meta charset="UTF-8">' + sLineBreak +
    '  <meta name="viewport" content="width=device-width, initial-scale=1.0">' + sLineBreak +
    '  <title>' + FOptions.Title + ' - Swagger UI</title>' + sLineBreak +
    '  <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.10.0/swagger-ui.css" />' + sLineBreak +
    '  <style>' + sLineBreak +
    '    html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }' + sLineBreak +
    '    *, *:before, *:after { box-sizing: inherit; }' + sLineBreak +
    '    body { margin: 0; padding: 0; }' + sLineBreak +
    '  </style>' + sLineBreak +
    '</head>' + sLineBreak +
    '<body>' + sLineBreak +
    '  <div id="swagger-ui"></div>' + sLineBreak +
    '  <script src="https://unpkg.com/swagger-ui-dist@5.10.0/swagger-ui-bundle.js"></script>' + sLineBreak +
    '  <script src="https://unpkg.com/swagger-ui-dist@5.10.0/swagger-ui-standalone-preset.js"></script>' + sLineBreak +
    '  <script>' + sLineBreak +
    '    window.onload = function() {' + sLineBreak +
    '      window.ui = SwaggerUIBundle({' + sLineBreak +
    '        url: "' + AJsonUrl + '",' + sLineBreak +
    '        dom_id: "#swagger-ui",' + sLineBreak +
    '        deepLinking: true,' + sLineBreak +
    '        presets: [' + sLineBreak +
    '          SwaggerUIBundle.presets.apis,' + sLineBreak +
    '          SwaggerUIStandalonePreset' + sLineBreak +
    '        ],' + sLineBreak +
    '        plugins: [' + sLineBreak +
    '          SwaggerUIBundle.plugins.DownloadUrl' + sLineBreak +
    '        ],' + sLineBreak +
    '        layout: "StandaloneLayout"' + sLineBreak +
    '      });' + sLineBreak +
    '    };' + sLineBreak +
    '  </script>' + sLineBreak +
    '</body>' + sLineBreak +
    '</html>';
end;

procedure TSwaggerMiddleware.HandleSwaggerUI(AContext: IHttpContext);
begin
  AContext.Response.StatusCode := 200;
  AContext.Response.SetContentType('text/html; charset=utf-8');
  // ToAppUrl puts the PathBase back on: the comparisons above work on the
  // stripped path, but this string is consumed by the BROWSER, which knows
  // nothing about the stripping and would ask the origin for /swagger.json.
  AContext.Response.Write
    (GetSwaggerUIHtml(AContext.Request.ToAppUrl(FJsonPath)));
end;

procedure TSwaggerMiddleware.HandleSwaggerJson(AContext: IHttpContext);
begin
  // JSON already cached in constructor
  AContext.Response.StatusCode := 200;
  AContext.Response.SetContentType('application/json; charset=utf-8');
  AContext.Response.AddHeader('Access-Control-Allow-Origin', '*');
  AContext.Response.Write(FCachedJson);
end;

procedure TSwaggerMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
begin
  if ShouldHandleRequest(AContext.Request.Path) then
  begin
    if AContext.Request.Path.Equals(FSwaggerPath) then
      HandleSwaggerUI(AContext)
    else if AContext.Request.Path.Equals(FJsonPath) then
      HandleSwaggerJson(AContext);
  end
  else
    ANext(AContext);
end;

{ TSwaggerExtensions }

class function TSwaggerExtensions.UseSwagger(App: IApplicationBuilder; const AOptions: TOpenAPIOptions): IApplicationBuilder;
var
  Middleware: IMiddleware;
begin
  // Create middleware instance (Singleton)
  // This ensures Generator and CachedJson are preserved
  Middleware := TSwaggerMiddleware.Create(App, AOptions);
  
  // Register as Singleton Middleware
  Result := App.UseMiddleware(Middleware);
end;

class function TSwaggerExtensions.UseSwagger(App: IApplicationBuilder): IApplicationBuilder;
begin
  Result := UseSwagger(App, TOpenAPIOptions.Default);
end;

end.

