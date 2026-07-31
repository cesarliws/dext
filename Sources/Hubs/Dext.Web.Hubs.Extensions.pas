{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025-2026 Cesar Romero & Dext Contributors        }
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
{  Created: 2026-01-06                                                      }
{                                                                           }
{  Description:                                                             }
{    Extension methods for integrating Hubs with IApplicationBuilder.       }
{                                                                           }
{  Usage:                                                                   }
{    App.MapHub<TMyHub>('/hubs/myhub');                                     }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs.Extensions;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  Dext.Web.Interfaces,
  Dext.DI.Interfaces,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Types,
  Dext.Web.Hubs.Hub,
  Dext.Web.Hubs.Middleware;

type
  /// <summary>
  /// Extension methods for Hub integration.
  /// </summary>
  THubExtensions = class
  private
    class var FMiddleware: THubMiddleware;
  public
    /// <summary>
    /// Maps a Hub to the specified path.
    /// </summary>
    /// <param name="App">The application builder</param>
    /// <param name="Path">The Hub endpoint path (e.g., '/hubs/chat')</param>
    /// <param name="HubClass">The Hub class to instantiate</param>
    class procedure MapHub(const App: IApplicationBuilder; const Path: string; HubClass: THubClass);
    
    /// <summary>
    /// Gets the shared Hub context for sending messages from outside Hubs.
    /// </summary>
    class function GetHubContext: IHubContext;
    
    /// <summary>
    /// Adds Hub middleware to the application pipeline.
    /// Call this before MapHub if you need to configure options.
    /// </summary>
    class procedure UseHubs(const App: IApplicationBuilder); overload;
    class procedure UseHubs(const App: IApplicationBuilder;
      const Options: THubOptions); overload;
    
    /// <summary>
    /// Registers Hub services in DI container.
    /// </summary>
    class procedure AddHubs(const Services: IServiceCollection);
    
    /// <summary>
    /// Gets the middleware instance (for advanced scenarios).
    /// </summary>
    class function Middleware: THubMiddleware;
    
    /// <summary>
    /// Gracefully shuts down all Hub connections.
    /// Call this before stopping the web server.
    /// </summary>
    class procedure ShutdownHubs;
  end;

/// <summary>
/// Convenience function to map a Hub (alternative to class method).
/// </summary>
procedure MapHub(const App: IApplicationBuilder; const Path: string; HubClass: THubClass);

implementation

uses
  Dext.Web.Hubs.Context,
  Dext.Web.Hubs.Connections;

procedure MapHub(const App: IApplicationBuilder; const Path: string; HubClass: THubClass);
begin
  THubExtensions.MapHub(App, Path, HubClass);
end;

{ THubExtensions }

class procedure THubExtensions.MapHub(const App: IApplicationBuilder;
  const Path: string; HubClass: THubClass);
begin
  // Ensure middleware is initialized
  if FMiddleware = nil then
    UseHubs(App);
    
  FMiddleware.MapHub(Path, HubClass);
end;

class function THubExtensions.GetHubContext: IHubContext;
begin
  if FMiddleware = nil then
    raise EHubException.Create('Hubs not initialized. Call UseHubs first.');
  Result := FMiddleware.GetHubContext;
end;

class procedure THubExtensions.UseHubs(const App: IApplicationBuilder);
begin
  UseHubs(App, THubOptions.Default);
end;

class procedure THubExtensions.UseHubs(const App: IApplicationBuilder;
  const Options: THubOptions);
begin
  if FMiddleware = nil then
  begin
    FMiddleware := THubMiddleware.Create(Options);
    
    // Add middleware to pipeline
    App.Use(
      procedure(Ctx: IHttpContext; Next: TRequestDelegate)
      begin
        FMiddleware.Handle(Ctx, Next);
      end);
  end;
end;

class procedure THubExtensions.AddHubs(const Services: IServiceCollection);
begin
  // Hub services are managed internally by the middleware
  // Use THubExtensions.GetHubContext to get IHubContext
end;

class function THubExtensions.Middleware: THubMiddleware;
begin
  Result := FMiddleware;
end;

class procedure THubExtensions.ShutdownHubs;
begin
  if FMiddleware <> nil then
  begin
    FMiddleware.Shutdown;
    Sleep(200);
  end;
end;

initialization

finalization
  if THubExtensions.FMiddleware <> nil then
  begin
    THubExtensions.FMiddleware.Free;
    THubExtensions.FMiddleware := nil;
  end;

end.
