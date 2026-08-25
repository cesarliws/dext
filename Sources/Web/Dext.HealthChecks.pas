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
  Dext.DI.Attributes,
  Dext.Web.Builder,
  Dext.Web.Interfaces,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces;

type
  THealthStatus = (Healthy, Degraded, Unhealthy);

  THealthCheckResult = record
    Status: THealthStatus;
    Description: string;
    Exception: Exception;
    Data: IDictionary<string, string>;
    class function Healthy(const Description: string = ''): THealthCheckResult; static;
    class function Unhealthy(const Description: string = ''; Ex: Exception = nil): THealthCheckResult; static;
  end;

  /// <summary>
  ///   Interface for individual health checks.
  ///   Implement this interface to create custom health checks (e.g. DB, Redis, External API).
  /// </summary>
  IHealthCheck = interface
    ['{7C3E8A9B-2D4F-4A1C-8E5B-9F0D3C6A7B8E}']
    function CheckHealth: THealthCheckResult;
  end;

  /// <summary>
  ///   Interface for the Health Check Service.
  ///   Orchestrates the execution of all registered health checks.
  ///   Lifecycle is managed by DI (ARC) as a Singleton.
  /// </summary>
  IHealthCheckService = interface
    ['{8A9B7C3E-2D4F-4A1C-8E5B-9F0D3C6A7B8E}']
    procedure RegisterCheck(CheckClass: TClass);
    function CheckHealth(AProvider: IServiceProvider): IDictionary<string, THealthCheckResult>;
    function GetCheckCount: Integer;
  end;

  /// <summary>
  ///   Default implementation of IHealthCheckService.
  ///   Executes checks in isolation and captures exceptions.
  /// </summary>
  THealthCheckService = class(TInterfacedObject, IHealthCheckService)
  private
    FChecks: IList<TClass>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterCheck(CheckClass: TClass);
    function CheckHealth(AProvider: IServiceProvider): IDictionary<string, THealthCheckResult>;
    function GetCheckCount: Integer;
  end;

  /// <summary>
  ///   Path options for health probe endpoints (Kubernetes-style live/ready + aggregate).
  /// </summary>
  THealthCheckOptions = record
    /// <summary>Aggregate health endpoint (runs all registered checks). Default: /health</summary>
    HealthPath: string;
    /// <summary>Liveness probe (process up). Default: /health/live</summary>
    LivePath: string;
    /// <summary>Readiness probe (dependencies). Default: /health/ready</summary>
    ReadyPath: string;
    /// <summary>Returns the framework defaults for health probe paths.</summary>
    class function Default: THealthCheckOptions; static;
  end;

  /// <summary>
  ///   Middleware that intercepts health probe paths and returns system status in JSON.
  ///   Defaults: <c>/health</c> (aggregate), <c>/health/live</c> (liveness), <c>/health/ready</c> (readiness).
  ///   Registered as Singleton in the DI container.
  ///   Receives IHealthCheckService via constructor injection.
  /// </summary>
  THealthCheckMiddleware = class(TMiddleware)
  private
    FService: IHealthCheckService;
    FOptions: THealthCheckOptions;
    procedure WriteLiveResponse(AContext: IHttpContext);
    procedure WriteChecksResponse(AContext: IHttpContext);
  public
    /// <summary>Creates middleware with default probe paths.</summary>
    [ServiceConstructor]
    constructor Create(AService: IHealthCheckService); overload;
    /// <summary>Creates middleware with custom probe paths.</summary>
    constructor Create(AService: IHealthCheckService; const AOptions: THealthCheckOptions); overload;
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
  THealthCheckBuilder = record
  private
    FServices: IServiceCollection;
    FChecks: IList<TClass>;
  public
    constructor Create(AServices: IServiceCollection);
    function AddCheck<T: class, constructor>: THealthCheckBuilder;
    procedure Build;
  end;

implementation

uses
  Dext.Web.Results;

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
  FChecks := TCollections.CreateList<TClass>;
end;

destructor THealthCheckService.Destroy;
begin
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

function THealthCheckService.CheckHealth(AProvider: IServiceProvider): IDictionary<string, THealthCheckResult>;
var
  CheckClass: TClass;
  Check: IHealthCheck;
  Obj: TObject;
  Res: THealthCheckResult;
begin
  Result := TCollections.CreateDictionary<string, THealthCheckResult>;
  
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

{ THealthCheckOptions }

class function THealthCheckOptions.Default: THealthCheckOptions;
begin
  Result.HealthPath := '/health';
  Result.LivePath := '/health/live';
  Result.ReadyPath := '/health/ready';
end;

{ THealthCheckMiddleware }

constructor THealthCheckMiddleware.Create(AService: IHealthCheckService);
begin
  Create(AService, THealthCheckOptions.Default);
end;

constructor THealthCheckMiddleware.Create(AService: IHealthCheckService;
  const AOptions: THealthCheckOptions);
begin
  inherited Create;
  if AService = nil then
    raise Exception.Create('THealthCheckMiddleware: IHealthCheckService is nil! Dependency Injection failed.');
  FService := AService;
  FOptions := AOptions;
  if FOptions.HealthPath = '' then
    FOptions.HealthPath := '/health';
  if FOptions.LivePath = '' then
    FOptions.LivePath := '/health/live';
  if FOptions.ReadyPath = '' then
    FOptions.ReadyPath := '/health/ready';
end;

procedure THealthCheckMiddleware.WriteLiveResponse(AContext: IHttpContext);
begin
  AContext.Response.StatusCode := 200;
  AContext.Response.SetContentType('application/json');
  AContext.Response.Write('{"status":"Healthy","probe":"live"}');
end;

procedure THealthCheckMiddleware.WriteChecksResponse(AContext: IHttpContext);
var
  Results: IDictionary<string, THealthCheckResult>;
  OverallStatus: THealthStatus;
  Json: TStringBuilder;
  StatusStr: string;
  Key: string;
  Res: THealthCheckResult;
  First: Boolean;
begin
  Results := FService.CheckHealth(AContext.Services);
  OverallStatus := THealthStatus.Healthy;
  for Key in Results.Keys do
  begin
    Res := Results[Key];
    if Res.Status = THealthStatus.Unhealthy then
      OverallStatus := THealthStatus.Unhealthy
    else if (Res.Status = THealthStatus.Degraded) and (OverallStatus = THealthStatus.Healthy) then
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

    First := True;
    for Key in Results.Keys do
    begin
      if not First then
        Json.Append(',');
      First := False;

      Res := Results[Key];
      case Res.Status of
        THealthStatus.Healthy: StatusStr := 'Healthy';
        THealthStatus.Degraded: StatusStr := 'Degraded';
        THealthStatus.Unhealthy: StatusStr := 'Unhealthy';
      end;

      Json.AppendFormat('"%s": {"status": "%s", "description": "%s"}',
        [Key, StatusStr, Res.Description]);
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
end;

procedure THealthCheckMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  Path: string;
begin
  Path := AContext.Request.Path;

  if SameText(Path, FOptions.LivePath) then
  begin
    WriteLiveResponse(AContext);
    Exit;
  end;

  if SameText(Path, FOptions.ReadyPath) or SameText(Path, FOptions.HealthPath) then
  begin
    WriteChecksResponse(AContext);
    Exit;
  end;

  ANext(AContext);
end;

{ THealthCheckBuilder }

constructor THealthCheckBuilder.Create(AServices: IServiceCollection);
begin
  FServices := AServices;
  FChecks := TCollections.CreateList<TClass>;
end;

function THealthCheckBuilder.AddCheck<T>: THealthCheckBuilder;
begin
  // Register the health check class as Transient in DI
  FServices.AddTransient(TServiceType.FromClass(T), T);
  
  // Store the class reference to be added to the service later
  if not FChecks.Contains(T) then
    FChecks.Add(T);
  
  Result := Self;
end;

procedure THealthCheckBuilder.Build;
var
  CapturedChecks: TArray<TClass>;
  LChecks: IList<TClass>;
  Factory: TFunc<IServiceProvider, TObject>;
begin
  // Capture the checks array for the factory closure
  LChecks := FChecks;
  CapturedChecks := LChecks.ToArray;
  
  // Create factory that will configure the service with registered checks
  // Note: We don't capture 'Self' (the record) here, only the local CapturedChecks
  Factory := 
    function(Provider: IServiceProvider): TObject
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

  // LChecks is ARC
end;

end.
