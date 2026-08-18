{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-08-10                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Testing.WebApplicationFactory;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.Web.WebApplication;

type
  /// <summary>
  ///   Fluent in-memory test host and ApplicationFactory for integration testing.
  /// </summary>
  TDextApplicationFactory<TApp: class> = class
  private
    FApp: TWebApplication;
    FConfigureServicesProc: TProc<IServiceCollection>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    ///   Overrides or injects mocks into the DI container prior to server startup.
    /// </summary>
    function WithTestServices(AProc: TProc<IServiceCollection>): TDextApplicationFactory<TApp>; overload;
    function WithTestServices(AProc: TProc<TDextServices>): TDextApplicationFactory<TApp>; overload;

    /// <summary>
    ///   Initializes the in-memory application and returns the configured WebApplication instance.
    /// </summary>
    function CreateApplication: TWebApplication;
  end;

implementation

{ TDextApplicationFactory<TApp> }

constructor TDextApplicationFactory<TApp>.Create;
begin
  inherited Create;
  FApp := nil;
  FConfigureServicesProc := nil;
end;

destructor TDextApplicationFactory<TApp>.Destroy;
begin
  if FApp <> nil then
  begin
    FApp.Stop;
    FApp.Free;
  end;
  inherited Destroy;
end;

function TDextApplicationFactory<TApp>.WithTestServices(AProc: TProc<IServiceCollection>): TDextApplicationFactory<TApp>;
begin
  FConfigureServicesProc := AProc;
  Result := Self;
end;

function TDextApplicationFactory<TApp>.WithTestServices(AProc: TProc<TDextServices>): TDextApplicationFactory<TApp>;
begin
  FConfigureServicesProc := procedure(AServices: IServiceCollection)
    begin
      if Assigned(AProc) then
        AProc(TDextServices.Create(AServices));
    end;
  Result := Self;
end;

function TDextApplicationFactory<TApp>.CreateApplication: TWebApplication;
begin
  if FApp = nil then
  begin
    FApp := TWebApplication.Create;
    if Assigned(FConfigureServicesProc) then
      FConfigureServicesProc(FApp.GetServices.Collection);
  end;
  Result := FApp;
end;

end.
