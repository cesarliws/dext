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
  Dext.DI.Interfaces,
  Dext.Logging,
  Dext.Logging.Sinks;

type
  /// <summary>
  ///   Builder interface for configuring logging services.
  /// </summary>
  ILoggingBuilder = interface
    ['{D4E5F678-9012-3456-7890-ABCDEF123456}']
    function Services: IServiceCollection;
    function AddProvider(const AProvider: ILoggerProvider): ILoggingBuilder;
    function SetMinimumLevel(ALevel: TLogLevel): ILoggingBuilder;
    function AddConsole: ILoggingBuilder;
    function AddFile(const AFileName: string; AMaxFileSizeMB: Integer = 0; ARollDaily: Boolean = False): ILoggingBuilder;
    function AddTelemetry: ILoggingBuilder;
    function AddAsync(ACapacityPowerOfTwo: Integer = 16): ILoggingBuilder;
    function AddSeq(const AUrl: string; const AApiKey: string = ''): ILoggingBuilder; overload;
    function AddSeq(const AUrl: string; const AApiKey: string; const AOptions: TBatchOptions): ILoggingBuilder; overload;
    function AddOpenTelemetry(const AUrl: string; const AServiceName: string = 'DextApp'; const AEnvironment: string = 'Production'): ILoggingBuilder; overload;
    function AddOpenTelemetry(const AUrl: string; const AServiceName, AEnvironment: string; AExportLogs, AExportTraces: Boolean; const AOptions: TBatchOptions): ILoggingBuilder; overload;
  end;

  /// <summary>
  ///   Extension methods for IServiceCollection to add logging infrastructure.
  /// </summary>
  TServiceCollectionLoggingExtensions = class
  public
    class function AddLogging(const AServices: IServiceCollection; const AConfigure: TProc<ILoggingBuilder> = nil): IServiceCollection;
  end;

implementation

uses
  System.TypInfo,
  System.Math,
  Dext.Collections,
  Dext.Logging.Console,
  Dext.Logging.Async,
  Dext.Logging.Telemetry;

type
  TLoggerFactoryOwner = class
  private
    FFactory: TLoggerFactory;
    FIntf: ILoggerFactory;
  public
    constructor Create(AFactory: TLoggerFactory);
    destructor Destroy; override;
    property Factory: TLoggerFactory read FFactory;
  end;

  TLoggingBuilder = class(TInterfacedObject, ILoggingBuilder)
  private
    FServices: IServiceCollection;
    FProviders: IList<ILoggerProvider>;
    FSinks: IList<ILogSink>;
    FMinLevel: TLogLevel;
    FTelemetryEnabled: Boolean;
    FAsync: Boolean;
    FAsyncCapacity: Integer;
  public
    constructor Create(AServices: IServiceCollection);
    destructor Destroy; override;
    
    function Services: IServiceCollection;
    function AddProvider(const AProvider: ILoggerProvider): ILoggingBuilder;
    function SetMinimumLevel(ALevel: TLogLevel): ILoggingBuilder;
    function AddConsole: ILoggingBuilder;
    function AddFile(const AFileName: string; AMaxFileSizeMB: Integer = 0; ARollDaily: Boolean = False): ILoggingBuilder;
    function AddTelemetry: ILoggingBuilder;
    function AddAsync(ACapacityPowerOfTwo: Integer = 16): ILoggingBuilder;
    function AddSeq(const AUrl: string; const AApiKey: string = ''): ILoggingBuilder; overload;
    function AddSeq(const AUrl: string; const AApiKey: string; const AOptions: TBatchOptions): ILoggingBuilder; overload;
    function AddOpenTelemetry(const AUrl: string; const AServiceName: string = 'DextApp'; const AEnvironment: string = 'Production'): ILoggingBuilder; overload;
    function AddOpenTelemetry(const AUrl: string; const AServiceName, AEnvironment: string; AExportLogs, AExportTraces: Boolean; const AOptions: TBatchOptions): ILoggingBuilder; overload;
    
    function ExtractProviders: IList<ILoggerProvider>;
    function ExtractSinks: IList<ILogSink>;
    function GetMinLevel: TLogLevel;
    function GetTelemetryEnabled: Boolean;
    function IsAsync: Boolean;
    function GetAsyncCapacity: Integer;
  end;

{ TLoggerFactoryOwner }

constructor TLoggerFactoryOwner.Create(AFactory: TLoggerFactory);
begin
  inherited Create;
  FFactory := AFactory;
  FIntf := AFactory;
end;

destructor TLoggerFactoryOwner.Destroy;
begin
  if FIntf <> nil then
  begin
    FIntf.Dispose;
    FIntf := nil;
  end;
  inherited;
end;

{ TLoggingBuilder }

constructor TLoggingBuilder.Create(AServices: IServiceCollection);
begin
  inherited Create;
  FServices := AServices;
  FProviders := TCollections.CreateList<ILoggerProvider>;
  FSinks := TCollections.CreateList<ILogSink>;
  FMinLevel := TLogLevel.Information;
  FTelemetryEnabled := False;
  FAsync := False;
  FAsyncCapacity := 16;
end;

destructor TLoggingBuilder.Destroy;
begin
  FProviders := nil;
  FSinks := nil;
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
  if FAsync then
    FSinks.Add(TConsoleSink.Create)
  else
    AddProvider(TConsoleLoggerProvider.Create);
  Result := Self;
end;

function TLoggingBuilder.AddFile(const AFileName: string; AMaxFileSizeMB: Integer; ARollDaily: Boolean): ILoggingBuilder;
begin
  if FAsync then
    FSinks.Add(TFileSink.Create(AFileName, AMaxFileSizeMB, ARollDaily))
  else
    AddProvider(TFileLoggerProvider.Create(AFileName, AMaxFileSizeMB, ARollDaily));
  Result := Self;
end;

function TLoggingBuilder.AddTelemetry: ILoggingBuilder;
begin
  FTelemetryEnabled := True;
  Result := Self;
end;

function TLoggingBuilder.AddAsync(ACapacityPowerOfTwo: Integer): ILoggingBuilder;
begin
  FAsync := True;
  FAsyncCapacity := ACapacityPowerOfTwo;
  Result := Self;
end;

function TLoggingBuilder.AddSeq(const AUrl, AApiKey: string): ILoggingBuilder;
begin
  Result := AddSeq(AUrl, AApiKey, TBatchOptions.Default);
end;

function TLoggingBuilder.AddSeq(const AUrl, AApiKey: string; const AOptions: TBatchOptions): ILoggingBuilder;
begin
  FSinks.Add(TTelemetrySinkRegistry.CreateSeq(AUrl, AApiKey, AOptions));
  Result := Self;
end;

function TLoggingBuilder.AddOpenTelemetry(const AUrl, AServiceName, AEnvironment: string): ILoggingBuilder;
begin
  Result := AddOpenTelemetry(AUrl, AServiceName, AEnvironment, True, True, TBatchOptions.Default);
end;

function TLoggingBuilder.AddOpenTelemetry(const AUrl, AServiceName, AEnvironment: string; AExportLogs, AExportTraces: Boolean; const AOptions: TBatchOptions): ILoggingBuilder;
begin
  FSinks.Add(TTelemetrySinkRegistry.CreateOTLP(AUrl, AServiceName, AEnvironment, AExportLogs, AExportTraces, AOptions));
  Result := Self;
end;

function TLoggingBuilder.ExtractProviders: IList<ILoggerProvider>;
begin
  Result := FProviders;
  FProviders := TCollections.CreateList<ILoggerProvider>; 
end;

function TLoggingBuilder.ExtractSinks: IList<ILogSink>;
begin
  Result := FSinks;
  FSinks := TCollections.CreateList<ILogSink>;
end;

function TLoggingBuilder.GetMinLevel: TLogLevel;
begin
  Result := FMinLevel;
end;

function TLoggingBuilder.GetTelemetryEnabled: Boolean;
begin
  Result := FTelemetryEnabled;
end;

function TLoggingBuilder.IsAsync: Boolean;
begin
  Result := FAsync;
end;

function TLoggingBuilder.GetAsyncCapacity: Integer;
begin
  Result := FAsyncCapacity;
end;

{ TServiceCollectionLoggingExtensions }

class function TServiceCollectionLoggingExtensions.AddLogging(const AServices: IServiceCollection; const AConfigure: TProc<ILoggingBuilder>): IServiceCollection;
var
  LBuilderIntf: ILoggingBuilder;
  LBuilderObj: TLoggingBuilder;
  LProvidersList: IList<ILoggerProvider>;
  LProvidersArray: TArray<ILoggerProvider>;
  LMinLevel: TLogLevel;
  LTelemetryEnabled: Boolean;
  CapturedMinLevel: TLogLevel;
  CapturedTelemetryEnabled: Boolean;
  CapturedProviders: TArray<ILoggerProvider>;
  CapturedSinks: TArray<ILogSink>;
begin
  LBuilderObj := TLoggingBuilder.Create(AServices);
  LBuilderIntf := LBuilderObj; // Mantém a referência viva
  
  if Assigned(AConfigure) then
    AConfigure(LBuilderIntf);
    
  LProvidersList := LBuilderObj.ExtractProviders;
  LProvidersArray := LProvidersList.ToArray;
  LProvidersList := nil;
  
  LMinLevel := LBuilderObj.GetMinLevel;
  LTelemetryEnabled := LBuilderObj.GetTelemetryEnabled;
  
  // Capture state for factory delegate
  CapturedMinLevel := LMinLevel;
  CapturedTelemetryEnabled := LTelemetryEnabled;
  CapturedProviders := LProvidersArray;

  if LBuilderObj.IsAsync then
  begin
    CapturedSinks := LBuilderObj.ExtractSinks.ToArray;
    // Register Async Factory
    AServices.AddSingleton(
      TServiceType.FromInterface(ILoggerFactory),
      TClass(nil),
      function(Provider: IServiceProvider): TObject
      var
        AsyncFactory: TAsyncLoggerFactory;
        S: ILogSink;
        L: ILogger;
      begin
        AsyncFactory := TAsyncLoggerFactory.Create;
        AsyncFactory.SetMinimumLevel(CapturedMinLevel);
        for S in CapturedSinks do
          AsyncFactory.AddSink(S);

        if CapturedTelemetryEnabled then
        begin
           L := AsyncFactory.CreateLogger('Telemetry');
           TDiagnosticSource.Instance.Subscribe(TLoggingTelemetryObserver.Create(L));
        end;
        Result := AsyncFactory;
      end
    );
  end
  else
  begin
    // 1. Register Owner (as concrete singleton Class) to ensure lifecycle destruction
    AServices.AddSingleton(
      TServiceType.FromClass(TLoggerFactoryOwner),
      TClass(nil),
      function(Provider: IServiceProvider): TObject
      var
        Factory: TLoggerFactory;
        Owner: TLoggerFactoryOwner;
        P: ILoggerProvider;
        L: ILogger;
      begin
        Factory := TLoggerFactory.Create;
        try
          Factory.SetMinimumLevel(CapturedMinLevel);
          for P in CapturedProviders do
            Factory.AddProvider(P);
            
          // If Telemetry is enabled, start the bridge
          if CapturedTelemetryEnabled then
          begin
             L := Factory.CreateLogger('Telemetry');
             TDiagnosticSource.Instance.Subscribe(TLoggingTelemetryObserver.Create(L));
          end;
          
          Owner := TLoggerFactoryOwner.Create(Factory);
          Result := Owner;
        except
          Factory.Free;
          raise;
        end;
      end
    );

    // 2. Register ILoggerFactory to resolve via Owner
    AServices.AddSingleton(
      TServiceType.FromInterface(ILoggerFactory),
      TClass(nil),
      function(Provider: IServiceProvider): TObject
      var
        Owner: TLoggerFactoryOwner;
      begin
        // Resolve owner (guaranteed to exist and be managed)
        Owner := Provider.GetService(TServiceType.FromClass(TLoggerFactoryOwner)) as TLoggerFactoryOwner;
        Result := Owner.Factory;
      end
    );
  end;
    
  // Register generic ILogger (default) - Resolve from ILoggerFactory
  AServices.AddSingleton(TServiceType.FromInterface(ILogger), TClass(nil),
    function(Provider: IServiceProvider): TObject
    var
      FactoryObj: TObject;
      Factory: TLoggerFactory;
    begin
      // Get factory as object (will be TLoggerFactory instance)
      FactoryObj := Provider.GetService(TServiceType.FromInterface(ILoggerFactory));
      Factory := FactoryObj as TLoggerFactory;
      // Call CreateLoggerInstance which returns TAggregateLogger (TObject)
      Result := Factory.CreateLoggerInstance('App');
    end);

  Result := AServices;
end;

end.

