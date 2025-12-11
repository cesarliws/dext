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
{  Updated: 2025-12-10 - Simplified AddHealthChecks, removed factory leak   }
{                                                                           }
{***************************************************************************}
unit Dext.Http.Extensions;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  Dext.DI.Interfaces,
  Dext.HealthChecks,
  Dext.Core.ControllerScanner;


type
  /// <summary>
  ///   Extension methods for IServiceCollection.
  ///   Provides fluent API for registering framework services.
  /// </summary>
  TDextServiceCollectionExtensions = class
  public
    /// <summary>
    ///   Adds health check services to the DI container.
    ///   Returns a builder for configuring individual health checks.
    /// </summary>
    class function AddHealthChecks(Services: IServiceCollection): THealthCheckBuilder;
    


    /// <summary>
    ///   Scans and registers all controllers in the application.
    /// </summary>
    class function AddControllers(const ACollection: IServiceCollection): IServiceCollection;
  end;

implementation

{ TDextServiceCollectionExtensions }

class function TDextServiceCollectionExtensions.AddHealthChecks(
  Services: IServiceCollection): THealthCheckBuilder;
begin
  // Create the builder - it handles all registration in its Build method
  // The builder will register IHealthCheckService as Singleton with factory
  Result := THealthCheckBuilder.Create(Services);
end;



class function TDextServiceCollectionExtensions.AddControllers(
  const ACollection: IServiceCollection): IServiceCollection;
var
  Scanner: IControllerScanner;
begin
  // Create a temporary scanner to find and register controllers
  Scanner := TControllerScanner.Create;
  Scanner.RegisterServices(ACollection);
  Result := ACollection;
end;

end.
