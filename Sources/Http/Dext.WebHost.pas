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
unit Dext.WebHost;

interface

uses
  System.SysUtils,
  Dext.DI.Interfaces,
  Dext.Http.Interfaces,
  Dext.Http.Core,
  Dext.Http.Indy.Server;

type
  TWebHostBuilder = class(TInterfacedObject, IWebHostBuilder)
  private
    FServices: IServiceCollection;
    FAppConfig: TProc<IApplicationBuilder>;
    FUrl: string;
    
    function GetPortFromUrl(const Url: string): Integer;
  public
    constructor Create;

    function ConfigureServices(AConfigurator: TProc<IServiceCollection>): IWebHostBuilder;
    function Configure(AConfigurator: TProc<IApplicationBuilder>): IWebHostBuilder;
    function UseUrls(const AUrls: string): IWebHostBuilder;
    function Build: IWebHost;
    destructor Destroy; override;
  end;

implementation

uses
  Dext.DI.Core,
  System.StrUtils;

{ TWebHostBuilder }

constructor TWebHostBuilder.Create;
begin
  inherited Create;
  FServices := TDextServiceCollection.Create;
  FUrl := 'http://localhost:8080'; // Default
end;

function TWebHostBuilder.ConfigureServices(AConfigurator: TProc<IServiceCollection>): IWebHostBuilder;
begin
  if Assigned(AConfigurator) then
    AConfigurator(FServices);
  Result := Self;
end;

function TWebHostBuilder.Configure(AConfigurator: TProc<IApplicationBuilder>): IWebHostBuilder;
begin
  FAppConfig := AConfigurator;
  Result := Self;
end;

function TWebHostBuilder.UseUrls(const AUrls: string): IWebHostBuilder;
begin
  FUrl := AUrls;
  Result := Self;
end;

function TWebHostBuilder.GetPortFromUrl(const Url: string): Integer;
var
  Parts: TArray<string>;
  PortStr: string;
begin
  // Simple parser: assumes http://domain:port or http://*:port
  Result := 8080;
  if Url.IsEmpty then Exit;
  
  Parts := Url.Split([':']);
  if Length(Parts) >= 3 then // http: // domain : port
  begin
    PortStr := Parts[High(Parts)];
    // remove potential trailing slash
    if PortStr.EndsWith('/') then
      PortStr := PortStr.Substring(0, Length(PortStr)-1);
      
    Result := StrToIntDef(PortStr, 8080);
  end;
end;

destructor TWebHostBuilder.Destroy;
begin
  FAppConfig := nil; // Clear reference
  inherited;
end;

function TWebHostBuilder.Build: IWebHost;
var
  AppBuilder: IApplicationBuilder;
  Pipeline: TRequestDelegate;
  ServiceProvider: IServiceProvider;
  Port: Integer;
begin
  // ✅ PRIMEIRO construir o ServiceProvider, DEPOIS criar AppBuilder
  ServiceProvider := FServices.BuildServiceProvider;

  AppBuilder := TApplicationBuilder.Create(ServiceProvider); // ✅ CORREÇÃO

  if Assigned(FAppConfig) then
    FAppConfig(AppBuilder);

  Pipeline := AppBuilder.Build;

  Port := GetPortFromUrl(FUrl);

  Result := TIndyWebServer.Create(Port, Pipeline, ServiceProvider);
end;

end.

