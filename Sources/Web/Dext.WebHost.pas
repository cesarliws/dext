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
{  Created: 2025-12-10                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.WebHost;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.Web.WebApplication,
  Dext.Configuration.Interfaces;

type
  TWebHostBuilder = class(TInterfacedObject, IWebHostBuilder)
  private
    FServices: TDextServices;
    FUrls: TArray<string>;
    FAppConfig: TProc<IApplicationBuilder>; // Configuration delegate
    FServicesConfig: TProc<IServiceCollection>;

  public
    constructor Create;
    destructor Destroy; override;

    class function CreateDefault(Args: TArray<string>): IWebHostBuilder;
    
    // IWebHostBuilder implementation
    function ConfigureServices(AConfigurator: TProc<IServiceCollection>): IWebHostBuilder;
    function Configure(AConfigurator: TProc<IApplicationBuilder>): IWebHostBuilder;
    function UseUrls(const AUrls: string): IWebHostBuilder;
    function Build: IWebHost;

    // Fluent API extensions
    function ConfigureServicesExtended(AConfigurator: TProc<TDextServices>): IWebHostBuilder;
    function UseUrlsArray(const AUrls: TArray<string>): IWebHostBuilder;
  end;

implementation

{ TWebHostBuilder }

constructor TWebHostBuilder.Create;
begin
  inherited;
  FServices := TDextServices.New;
  // Default URL
  SetLength(FUrls, 1);
  FUrls[0] := 'http://localhost:5000';
end;

destructor TWebHostBuilder.Destroy;
begin
  // Release closures to break reference cycles
  FAppConfig := nil;
  FServicesConfig := nil;
  inherited;
end;

class function TWebHostBuilder.CreateDefault(Args: TArray<string>): IWebHostBuilder;
begin
  Result := TWebHostBuilder.Create;
  // TODO: Parse args to override settings (like urls)
end;

function TWebHostBuilder.ConfigureServices(AConfigurator: TProc<IServiceCollection>): IWebHostBuilder;
begin
  FServicesConfig := AConfigurator;
  Result := Self;
end;

function TWebHostBuilder.ConfigureServicesExtended(AConfigurator: TProc<TDextServices>): IWebHostBuilder;
begin
  AConfigurator(FServices);
  Result := Self;
end;

function TWebHostBuilder.Configure(AConfigurator: TProc<IApplicationBuilder>): IWebHostBuilder;
begin
  FAppConfig := AConfigurator;
  Result := Self;
end;

function TWebHostBuilder.UseUrlsArray(const AUrls: TArray<string>): IWebHostBuilder;
begin
  FUrls := AUrls;
  Result := Self;
end;

function TWebHostBuilder.UseUrls(const AUrls: string): IWebHostBuilder;
begin
  // Simple split by comma or semicolon
  var Parts := AUrls.Split([',', ';']);
  var CleanUrls: TArray<string>;
  for var Part in Parts do
  begin
    var Trimmed := Part.Trim;
    if Trimmed <> '' then
    begin
      SetLength(CleanUrls, Length(CleanUrls) + 1);
      CleanUrls[High(CleanUrls)] := Trimmed;
    end;
  end;
  
  if Length(CleanUrls) > 0 then
    FUrls := CleanUrls;
    
  Result := Self;
end;

function TWebHostBuilder.Build: IWebHost;
var
  Host: IWebApplication;
  Port: Integer;
  PortStr: string;
begin
  // 1. Create the Application Builder with the DI Container
  // The services registered in FServices are transferred/copied to the builder
  // Note: TDextApplication usually creates its own builder.
  // We need to bridge TWebHostBuilder -> TDextApplication.
  
  // Create the app instance
  Host := TDextApplication.Create;
  
  // Apply service configuration if any
  if Assigned(FServicesConfig) then
    FServicesConfig(Host.Services.Unwrap);

  // Register services collected in the builder
  Host.Services.AddRange(FServices); 

  // Manual copy for now as AddRange might not exist
  // Ideally, FServices should be passed to Host constructor or Builder
  
  // Let's create the AppBuilder manually to configure the pipeline
  // But TDextApplication encapsulates the builder.
  // We need to expose a way to configure the internal builder of TDextApplication BEFORE Build.
  
  // Actually, TDextApplication IS the Host (IWebHost).
  // And it exposes AppBuilder via a property or method usually.
  
  // In Dext.Web.WebApplication:
  // TDextApplication = class(TInterfacedObject, IWebApplication, ...)
  
  // 2. Apply Pipeline Configuration (call GetApplicationBuilder inline to avoid holding reference)
  if Assigned(FAppConfig) then
  begin
    FAppConfig(Host.GetApplicationBuilder);
    FAppConfig := nil; // Release closure immediately to break reference cycle
  end;
  
  // Also release services config if not already done
  FServicesConfig := nil;

  // 3. Determine Port from URLs (Naive implementation - takes first URL's port)
  if Length(FUrls) > 0 then
  begin
    var FirstUrl := FUrls[0];
    // http://localhost:5000
    // Very basic parsing for now
    var ColonPos := LastDelimiter(':', FirstUrl);
    if ColonPos > 0 then
    begin
      PortStr := Copy(FirstUrl, ColonPos + 1, Length(FirstUrl));
      // Removing trailing slash if present
      if PortStr.EndsWith('/') then
        PortStr := PortStr.Substring(0, Length(PortStr) - 1);
      
      if TryStrToInt(PortStr, Port) then
        Host.SetDefaultPort(Port);
    end;
  end;

  Result := Host as IWebHost;
end;

end.
