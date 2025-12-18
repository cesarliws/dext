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
unit Dext.Hosting.BackgroundService;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Dext.DI.Interfaces,
  Dext.Core.CancellationToken; // ? Added

type
  IHostedService = interface
    ['{8D4F5E6A-1B2C-4D3E-9F0A-7B8C9D0E1F2A}']
    procedure Start;
    procedure Stop;
  end;

  // ? Interface for THostedServiceManager to enable ARC management
  IHostedServiceManager = interface
    ['{F1E2D3C4-B5A6-7890-1234-567890ABCDEF}']
    procedure RegisterService(Service: IHostedService);
    procedure StartAsync;
    procedure StopAsync;
  end;

  TBackgroundService = class;

  TBackgroundServiceThread = class(TThread)
  private
    FService: TBackgroundService;
    FToken: ICancellationToken;
  protected
    procedure Execute; override;
  public
    constructor Create(Service: TBackgroundService; Token: ICancellationToken);
  end;

  /// <summary>
  ///   Base class for implementing a long running IHostedService.
  /// </summary>
  TBackgroundService = class(TInterfacedObject, IHostedService)
  private
    FThread: TBackgroundServiceThread;
    FCancellationTokenSource: TCancellationTokenSource;
  protected
    procedure Execute(Token: ICancellationToken); virtual; abstract;
  public
    procedure Start; virtual;
    procedure Stop; virtual;
  end;

  /// <summary>
  ///   Manager that starts and stops all registered hosted services.
  /// </summary>
  THostedServiceManager = class(TInterfacedObject, IHostedServiceManager)
  private
    FServices: TList<IHostedService>;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure RegisterService(Service: IHostedService);
    procedure StartAsync;
    procedure StopAsync;
  end;

  TBackgroundServiceBuilder = class
  private
    FServices: IServiceCollection;
    FHostedServices: TList<TClass>;
  public
    constructor Create(Services: IServiceCollection);
    destructor Destroy; override;
    function AddHostedService<T: class, constructor>: TBackgroundServiceBuilder;
    procedure Build;
  end;

implementation

{ TBackgroundServiceThread }

constructor TBackgroundServiceThread.Create(Service: TBackgroundService; Token: ICancellationToken);
begin
  inherited Create(True); // Create suspended
  FService := Service;
  FToken := Token;
  FreeOnTerminate := False;
end;

procedure TBackgroundServiceThread.Execute;
begin
  try
    FService.Execute(FToken);
  except
    on E: Exception do
      WriteLn(Format('? Error in BackgroundService thread: %s', [E.Message]));
  end;
end;

{ TBackgroundService }

procedure TBackgroundService.Start;
begin
  FCancellationTokenSource := TCancellationTokenSource.Create;
  FThread := TBackgroundServiceThread.Create(Self, FCancellationTokenSource.Token);
  FThread.Start;
end;

procedure TBackgroundService.Stop;
begin
  if Assigned(FCancellationTokenSource) then
  begin
    FCancellationTokenSource.Cancel;
  end;

  if Assigned(FThread) then
  begin
    // We don't terminate the thread abruptly, we wait for it to finish gracefully
    // The Execute method should check the token and exit.
    FThread.WaitFor;
    FThread.Free;
    FThread := nil;
  end;
  
  if Assigned(FCancellationTokenSource) then
  begin
    FCancellationTokenSource.Free;
    FCancellationTokenSource := nil;
  end;
end;

{ THostedServiceManager }

constructor THostedServiceManager.Create;
begin
  inherited Create;
  FServices := TList<IHostedService>.Create;
end;

destructor THostedServiceManager.Destroy;
begin
  // Services are interfaces managed by ARC
  // Just free the list container, not the services themselves
  FServices.Free;
  inherited;
end;

procedure THostedServiceManager.RegisterService(Service: IHostedService);
begin
  FServices.Add(Service);
end;

procedure THostedServiceManager.StartAsync;
var
  Service: IHostedService;
begin
  WriteLn('?? Starting Hosted Services...');
  for Service in FServices do
  begin
    try
      Service.Start;
      WriteLn(Format('  ? Started %s', [(Service as TObject).ClassName]));
    except
      on E: Exception do
        WriteLn(Format('  ? Failed to start %s: %s', [(Service as TObject).ClassName, E.Message]));
    end;
  end;
end;

procedure THostedServiceManager.StopAsync;
var
  Service: IHostedService;
begin
  WriteLn('?? Stopping Hosted Services...');
  for Service in FServices do
  begin
    try
      Service.Stop;
      WriteLn(Format('  ? Stopped %s', [(Service as TObject).ClassName]));
    except
      on E: Exception do
        WriteLn(Format('  ? Failed to stop %s: %s', [(Service as TObject).ClassName, E.Message]));
    end;
  end;
end;

{ TBackgroundServiceBuilder }

constructor TBackgroundServiceBuilder.Create(Services: IServiceCollection);
begin
  inherited Create;
  FServices := Services;
  FHostedServices := TList<TClass>.Create;
end;

destructor TBackgroundServiceBuilder.Destroy;
begin
  FHostedServices.Free;
  inherited;
end;

function TBackgroundServiceBuilder.AddHostedService<T>: TBackgroundServiceBuilder;
begin
  // Register as singleton
  FServices.AddSingleton(TServiceType.FromClass(T), T);
  FHostedServices.Add(T);
  Result := Self;
end;

procedure TBackgroundServiceBuilder.Build;
var
  CapturedServices: TArray<TClass>;
begin
  CapturedServices := FHostedServices.ToArray;
  
  // ? Register as INTERFACE to enable ARC management
  FServices.AddSingleton(
    TServiceType.FromInterface(IHostedServiceManager),
    THostedServiceManager,
    function(Provider: IServiceProvider): TObject
    var
      Manager: THostedServiceManager;
      ServiceClass: TClass;
      ServiceObj: TObject;
      HostedService: IHostedService;
    begin
      Manager := THostedServiceManager.Create;
      
      for ServiceClass in CapturedServices do
      begin
        ServiceObj := Provider.GetService(TServiceType.FromClass(ServiceClass));
        if Supports(ServiceObj, IHostedService, HostedService) then
          Manager.RegisterService(HostedService);
      end;
      
      Result := Manager;
    end
  );
  Self.Free;
end;

end.
