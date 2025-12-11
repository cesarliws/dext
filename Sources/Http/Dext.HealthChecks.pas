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
{  Updated: 2025-12-10 - Refactored to use IHealthCheckService interface    }
{                                                                           }
{***************************************************************************}
unit Dext.HealthChecks;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Dext.Http.Core,
  Dext.Http.Interfaces,
  Dext.DI.Interfaces;

type
  THealthStatus = (Healthy, Degraded, Unhealthy);

  THealthCheckResult = record
    Status: THealthStatus;
    Description: string;
    Exception: Exception;
    Data: TDictionary<string, string>;
    class function Healthy(const Description: string = ''): THealthCheckResult; static;
    class function Unhealthy(const Description: string = ''; Ex: Exception = nil): THealthCheckResult; static;
  end;

  /// <summary>
  ///   Interface for individual health checks.
  ///   Implement this interface to create custom health checks.
  /// </summary>
  IHealthCheck = interface
    ['{7C3E8A9B-2D4F-4A1C-8E5B-9F0D3C6A7B8E}']
    function CheckHealth: THealthCheckResult;
  end;

  /// <summary>
  ///   Interface for the Health Check Service.
  ///   Manages the collection of health checks and executes them.
  ///   Lifecycle is managed by DI (ARC) as a Singleton.
  /// </summary>
  IHealthCheckService = interface
    ['{8A9B7C3E-2D4F-4A1C-8E5B-9F0D3C6A7B8E}']
    procedure RegisterCheck(CheckClass: TClass);
    function CheckHealth(AProvider: IServiceProvider): TDictionary<string, THealthCheckResult>;
    function GetCheckCount: Integer;
  end;

  /// <summary>
  ///   Implementation of IHealthCheckService.
  ///   Inherits from TInterfacedObject for automatic memory management via ARC.
  /// </summary>
  THealthCheckService = class(TInterfacedObject, IHealthCheckService)
  private
    FChecks: TList<TClass>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterCheck(CheckClass: TClass);
    function CheckHealth(AProvider: IServiceProvider): TDictionary<string, THealthCheckResult>;
    function GetCheckCount: Integer;
  end;

  /// <summary>
  ///   Middleware that handles /health endpoint requests.
  ///   Registered as Singleton in the DI container.
  ///   Receives IHealthCheckService via constructor injection.
  /// </summary>
  THealthCheckMiddleware = class(TMiddleware)
  private
    FService: IHealthCheckService;
  public
    constructor Create(AService: IHealthCheckService);
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  /// <summary>
  ///   Fluent builder for configuring health checks.
  ///   Usage:
  ///     App.Services.AddHealthChecks
  ///       .AddCheck<TDatabaseHealthCheck>
  ///       .AddCheck<TRedisHealthCheck>
  ///       .Build;
  /// </summary>
  THealthCheckBuilder = class
  private
    FServices: IServiceCollection;
    FChecks: TList<TClass>;
  public
    constructor Create(AServices: IServiceCollection);
    destructor Destroy; override;
    function AddCheck<T: class, constructor>: THealthCheckBuilder;
    procedure Build;
  end;

implementation

uses
  Dext.Http.Results;

{ THealthCheckResult }

class function THealthCheckResult.Healthy(const Description: string): THealthCheckResult;
begin
  Result.Status := THealthStatus.Healthy;
  Result.Description := Description;
  Result.Exception := nil;
  Result.Data := nil;
end;

class function THealthCheckResult.Unhealthy(const Description: string; Ex: Exception): THealthCheckResult;
begin
  Result.Status := THealthStatus.Unhealthy;
  Result.Description := Description;
  Result.Exception := Ex;
  Result.Data := nil;
end;

{ THealthCheckService }

constructor THealthCheckService.Create;
begin
  inherited Create;
  FChecks := TList<TClass>.Create;
end;

destructor THealthCheckService.Destroy;
begin
  FChecks.Free;
  inherited;
end;

procedure THealthCheckService.RegisterCheck(CheckClass: TClass);
begin
  if not FChecks.Contains(CheckClass) then
    FChecks.Add(CheckClass);
end;

function THealthCheckService.GetCheckCount: Integer;
begin
  Result := FChecks.Count;
end;

function THealthCheckService.CheckHealth(AProvider: IServiceProvider): TDictionary<string, THealthCheckResult>;
var
  CheckClass: TClass;
  Check: IHealthCheck;
  Obj: TObject;
  Res: THealthCheckResult;
begin
  Result := TDictionary<string, THealthCheckResult>.Create;
  
  for CheckClass in FChecks do
  begin
    try
      // Resolve check from DI - each check is Transient
      Obj := AProvider.GetService(TServiceType.FromClass(CheckClass));
      if Assigned(Obj) and Supports(Obj, IHealthCheck, Check) then
      begin
        try
          Res := Check.CheckHealth;
          Result.Add(CheckClass.ClassName, Res);
        except
          on E: Exception do
            Result.Add(CheckClass.ClassName, THealthCheckResult.Unhealthy('Exception during check: ' + E.Message));
        end;
      end
      else
      begin
        Result.Add(CheckClass.ClassName, THealthCheckResult.Unhealthy('Service does not implement IHealthCheck'));
      end;
    except
      on E: Exception do
        Result.Add(CheckClass.ClassName, THealthCheckResult.Unhealthy('Failed to resolve service: ' + E.Message));
    end;
  end;
end;

{ THealthCheckMiddleware }

constructor THealthCheckMiddleware.Create(AService: IHealthCheckService);
begin
  inherited Create;
  if AService = nil then
    raise Exception.Create('THealthCheckMiddleware: IHealthCheckService is nil! Dependency Injection failed.');
  FService := AService;
end;

procedure THealthCheckMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  Results: TDictionary<string, THealthCheckResult>;
  OverallStatus: THealthStatus;
  Json: TStringBuilder;
  Pair: TPair<string, THealthCheckResult>;
  StatusStr: string;
begin
  if AContext.Request.Path <> '/health' then
  begin
    ANext(AContext);
    Exit;
  end;

  // Use the scoped provider from the context to resolve health checks
  Results := FService.CheckHealth(AContext.Services);
  try
    OverallStatus := THealthStatus.Healthy;
    for Pair in Results do
    begin
      if Pair.Value.Status = THealthStatus.Unhealthy then
        OverallStatus := THealthStatus.Unhealthy
      else if (Pair.Value.Status = THealthStatus.Degraded) and (OverallStatus = THealthStatus.Healthy) then
        OverallStatus := THealthStatus.Degraded;
    end;

    Json := TStringBuilder.Create;
    try
      Json.Append('{');
      
      case OverallStatus of
        THealthStatus.Healthy: Json.Append('"status": "Healthy",');
        THealthStatus.Degraded: Json.Append('"status": "Degraded",');
        THealthStatus.Unhealthy: Json.Append('"status": "Unhealthy",');
      end;
        
      Json.Append('"checks": {');
      
      var First := True;
      for Pair in Results do
      begin
        if not First then Json.Append(',');
        First := False;
        
        case Pair.Value.Status of
          THealthStatus.Healthy: StatusStr := 'Healthy';
          THealthStatus.Degraded: StatusStr := 'Degraded';
          THealthStatus.Unhealthy: StatusStr := 'Unhealthy';
        end;
        
        Json.AppendFormat('"%s": {"status": "%s", "description": "%s"}', 
          [Pair.Key, StatusStr, Pair.Value.Description]);
      end;
      
      Json.Append('}}');
      
      AContext.Response.SetContentType('application/json');
      case OverallStatus of
        THealthStatus.Healthy: AContext.Response.StatusCode := 200;
        THealthStatus.Degraded: AContext.Response.StatusCode := 200;
        THealthStatus.Unhealthy: AContext.Response.StatusCode := 503;
      end;
        
      AContext.Response.Write(Json.ToString);
    finally
      Json.Free;
    end;
  finally
    Results.Free;
  end;
end;

{ THealthCheckBuilder }

constructor THealthCheckBuilder.Create(AServices: IServiceCollection);
begin
  inherited Create;
  FServices := AServices;
  FChecks := TList<TClass>.Create;
end;

destructor THealthCheckBuilder.Destroy;
begin
  FChecks.Free;
  inherited;
end;

function THealthCheckBuilder.AddCheck<T>: THealthCheckBuilder;
begin
  // Register the health check class as Transient in DI
  FServices.AddTransient(TServiceType.FromClass(T), T);
  
  // Store the class reference to be added to the service later
  FChecks.Add(T);
  
  Result := Self;
end;

procedure THealthCheckBuilder.Build;
var
  CapturedChecks: TArray<TClass>;
  Factory: TFunc<IServiceProvider, TObject>;
begin
  // Capture the checks array for the factory closure
  CapturedChecks := FChecks.ToArray;
  
  // Create factory that will configure the service with registered checks
  Factory := function(Provider: IServiceProvider): TObject
    var
      Service: THealthCheckService;
      CheckClass: TClass;
    begin
      Service := THealthCheckService.Create;
      for CheckClass in CapturedChecks do
        Service.RegisterCheck(CheckClass);
      Result := Service;
    end;

  // Register IHealthCheckService as Singleton with the factory
  FServices.AddSingleton(
    TServiceType.FromInterface(IHealthCheckService),
    THealthCheckService,
    Factory
  );
  
  // Self-destruct the builder
  Self.Free;
end;

end.
