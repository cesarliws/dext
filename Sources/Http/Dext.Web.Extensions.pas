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
unit Dext.Web.Extensions;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.TypInfo,
  Dext.DI.Interfaces,
  Dext.Http.Interfaces,
  Dext.Http.Formatters.Interfaces,
  Dext.Http.Formatters.Selector,
  Dext.Http.Formatters.Json;

type
  TWebDIHelpers = class
  public
    class procedure AddContentNegotiation(Services: IServiceCollection);
  end;

  TWebRouteHelpers = class
  public
    class procedure HasApiVersion(Builder: IApplicationBuilder; const Version: string);
  end;

  TOutputFormatterRegistry = class(TInterfacedObject, IOutputFormatterRegistry)
  private
    FFormatters: TList<IOutputFormatter>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(Formatter: IOutputFormatter);
    function GetAll: TArray<IOutputFormatter>;
  end;

implementation

{ TOutputFormatterRegistry }

constructor TOutputFormatterRegistry.Create;
begin
  inherited Create;
  FFormatters := TList<IOutputFormatter>.Create;
end;

destructor TOutputFormatterRegistry.Destroy;
begin
  FFormatters.Free;
  inherited;
end;

procedure TOutputFormatterRegistry.Add(Formatter: IOutputFormatter);
begin
  FFormatters.Add(Formatter);
end;

function TOutputFormatterRegistry.GetAll: TArray<IOutputFormatter>;
begin
  Result := FFormatters.ToArray;
end;

{ TWebDIHelpers }

class procedure TWebDIHelpers.AddContentNegotiation(Services: IServiceCollection);
begin
  // Register Registry & Default Formatter
  Services.AddSingleton(TServiceType.FromInterface(TypeInfo(IOutputFormatterRegistry)), TOutputFormatterRegistry,
    function(P: IServiceProvider): TObject
    var
      Reg: TOutputFormatterRegistry;
    begin
       Reg := TOutputFormatterRegistry.Create;
       Reg.Add(TJsonOutputFormatter.Create); // Add default JSON
       Result := Reg;
    end
  );

  // Register Selector
  Services.AddSingleton(TServiceType.FromInterface(TypeInfo(IOutputFormatterSelector)), TDefaultOutputFormatterSelector);
end;

{ TWebRouteHelpers }

class procedure TWebRouteHelpers.HasApiVersion(Builder: IApplicationBuilder; const Version: string);
begin
  // Builders typically have state of "Last Added Route".
  // Dext.Http.Interfaces defines UpdateLastRouteMetadata.
  var OriginalRoutes := Builder.GetRoutes;
  if Length(OriginalRoutes) > 0 then
  begin
    var LastRoute := OriginalRoutes[High(OriginalRoutes)];
    
    // Add version to array
    // LastRoute is TEndpointMetadata (Record)
    var NewVersions := LastRoute.ApiVersions;
    SetLength(NewVersions, Length(NewVersions) + 1);
    NewVersions[High(NewVersions)] := Version;
    
    LastRoute.ApiVersions := NewVersions;
    Builder.UpdateLastRouteMetadata(LastRoute);
  end;
end;

end.

