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
// Dext.Web.RoutingMiddleware.pas
unit Dext.Web.RoutingMiddleware;

interface

uses
  Dext.Collections, Dext.Collections.Dict,
  Dext.Web.Builder,
  Dext.Web.Interfaces,
  Dext.Web.Routing;  // For IRouteMatcher

type
  /// <summary>
  ///   Middleware responsible for matching incoming requests to registered routes.
  ///   Injects route parameters and enforces basic authorization rules based on endpoint metadata.
  /// </summary>
  TRoutingMiddleware = class(TMiddleware)
  private
    FRouteMatcher: IRouteMatcher;  // Interface - no circular dependency
  public
    /// <summary>Initializes the routing middleware with a specific route matcher.</summary>
    constructor Create(const ARouteMatcher: IRouteMatcher);
    destructor Destroy; override;
    /// <summary>Executes the routing logic and passes the request to the matching handler.</summary>
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

implementation

uses
  System.Rtti, System.SysUtils;

{ TRoutingMiddleware }

constructor TRoutingMiddleware.Create(const ARouteMatcher: IRouteMatcher);
begin
  inherited Create;
  FRouteMatcher := ARouteMatcher;  // Interface manages lifecycle
end;

destructor TRoutingMiddleware.Destroy;
begin
  inherited;
end;

procedure TRoutingMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  Handler: TRequestDelegate;
  RouteParams: TRouteValueDictionary;
  Metadata: TEndpointMetadata;
  Path: string;
  Method: string;
  Scheme: string;
begin
  Path := AContext.Request.Path;
  Method := AContext.Request.Method;

  // Use RouteMatcher via interface with Method support
  if FRouteMatcher.FindMatchingRoute(AContext, Handler, RouteParams, Metadata) then
  begin
    try
      // Inject route parameters if found
      if RouteParams.Count > 0 then
      begin
        AContext.SetRouteParams(RouteParams);
      end;

      // Store Metadata in Context.Items if available for other middlewares (e.g. Auth)
      AContext.Items.AddOrSetValue('endpoint_metadata', TValue.From<TEndpointMetadata>(Metadata));

      // Authorization Check
      if (Length(Metadata.Security) > 0) and not Metadata.AllowAnonymous then
      begin        
        if (AContext.User = nil) or not AContext.User.Identity.IsAuthenticated then
        begin          
          AContext.Response.StatusCode := 401;
          for Scheme in Metadata.Security do
          begin
            if SameText(Scheme, 'Basic') then
            begin
              AContext.Response.AddHeader('WWW-Authenticate', 'Basic realm="Dext API"');
              break;
            end;
          end;
          AContext.Response.SetContentType('application/json; charset=utf-8');
          AContext.Response.Write('{"error": "Unauthorized", "message": "Authentication required. Please provide valid credentials."}');
          Exit;
        end;        
      end;

      Handler(AContext);
    finally
      RouteParams.Clear;
    end;
  end
  else
  begin
    // No matching route found - call next (404 handler)
    ANext(AContext);
  end;
end;

end.
