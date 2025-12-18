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
unit Dext.Logging.Extensions;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Dext.DI.Interfaces,
  Dext.Logging;

type
  ILoggingBuilder = interface
    ['{D4E5F678-9012-3456-7890-ABCDEF123456}']
    function Services: IServiceCollection;
    function AddProvider(const AProvider: ILoggerProvider): ILoggingBuilder;
    function SetMinimumLevel(ALevel: TLogLevel): ILoggingBuilder;
    function AddConsole: ILoggingBuilder;
  end;

  TServiceCollectionLoggingExtensions = class
  public
    class function AddLogging(const AServices: IServiceCollection; const AConfigure: TProc<ILoggingBuilder> = nil): IServiceCollection;
  end;

implementation

uses
  Dext.DI.Extensions,
  Dext.Logging.Console;

type
  TLoggingBuilder = class(TInterfacedObject, ILoggingBuilder)
  private
    FServices: IServiceCollection;
    FProviders: TList<ILoggerProvider>;
    FMinLevel: TLogLevel;
  public
    constructor Create(AServices: IServiceCollection);
    destructor Destroy; override;
    
    function Services: IServiceCollection;
    function AddProvider(const AProvider: ILoggerProvider): ILoggingBuilder;
    function SetMinimumLevel(ALevel: TLogLevel): ILoggingBuilder;
    function AddConsole: ILoggingBuilder;
    
    function ExtractProviders: TList<ILoggerProvider>;
    function GetMinLevel: TLogLevel;
  end;

{ TLoggingBuilder }

constructor TLoggingBuilder.Create(AServices: IServiceCollection);
begin
  inherited Create;
  FServices := AServices;
  FProviders := TList<ILoggerProvider>.Create;
  FMinLevel := TLogLevel.Information;
end;

destructor TLoggingBuilder.Destroy;
begin
  FProviders.Free;
  inherited;
end;

function TLoggingBuilder.Services: IServiceCollection;
begin
  Result := FServices;
end;

function TLoggingBuilder.AddProvider(const AProvider: ILoggerProvider): ILoggingBuilder;
begin
  FProviders.Add(AProvider);
  Result := Self;
end;

function TLoggingBuilder.SetMinimumLevel(ALevel: TLogLevel): ILoggingBuilder;
begin
  FMinLevel := ALevel;
  Result := Self;
end;

function TLoggingBuilder.AddConsole: ILoggingBuilder;
begin
  Result := AddProvider(TConsoleLoggerProvider.Create);
end;

function TLoggingBuilder.ExtractProviders: TList<ILoggerProvider>;
begin
  Result := FProviders;
  FProviders := TList<ILoggerProvider>.Create; 
end;

function TLoggingBuilder.GetMinLevel: TLogLevel;
begin
  Result := FMinLevel;
end;

{ TServiceCollectionLoggingExtensions }

class function TServiceCollectionLoggingExtensions.AddLogging(const AServices: IServiceCollection; const AConfigure: TProc<ILoggingBuilder>): IServiceCollection;
var
  LBuilderIntf: ILoggingBuilder;
  LBuilderObj: TLoggingBuilder;
  LProviders: TList<ILoggerProvider>;
  LMinLevel: TLogLevel;
begin
  LBuilderObj := TLoggingBuilder.Create(AServices);
  LBuilderIntf := LBuilderObj; // Mantém a referência viva
  
  if Assigned(AConfigure) then
    AConfigure(LBuilderIntf);
    
  LProviders := LBuilderObj.ExtractProviders;
  LMinLevel := LBuilderObj.GetMinLevel;
  
  // Register TLoggerFactory (Class) - Holds the configuration and providers
  AServices.AddSingleton(TServiceType.FromClass(TypeInfo(TLoggerFactory)), nil,
    function(Provider: IServiceProvider): TObject
    var
      Factory: TLoggerFactory;
      P: ILoggerProvider;
    begin
      Factory := TLoggerFactory.Create;
      Factory.SetMinimumLevel(LMinLevel);
      
      for P in LProviders do
        Factory.AddProvider(P);
        
      LProviders.Free; 
      
      Result := Factory;
    end);

  // Register ILoggerFactory (Interface) - Delegates to TLoggerFactory
  AServices.AddSingleton(TServiceType.FromInterface(ILoggerFactory), nil,
    function(Provider: IServiceProvider): TObject
    begin
      Result := TServiceProviderExtensions.GetRequiredServiceObject<TLoggerFactory>(Provider);
    end);
    
  // Register generic ILogger (default) - Uses CreateLoggerInstance to get TObject
  AServices.AddSingleton(TServiceType.FromInterface(ILogger), nil,
    function(Provider: IServiceProvider): TObject
    var
      Factory: TLoggerFactory;
    begin
      Factory := TServiceProviderExtensions.GetRequiredServiceObject<TLoggerFactory>(Provider);
      Result := Factory.CreateLoggerInstance('App');
    end);

  Result := AServices;
end;

end.

