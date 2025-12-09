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

  IHealthCheck = interface
    ['{7C3E8A9B-2D4F-4A1C-8E5B-9F0D3C6A7B8E}']
    function CheckHealth: THealthCheckResult;
  end;

  THealthCheckService = class
  private
    FChecks: TList<TClass>; // List of IHealthCheck classes
  public
    constructor Create;
    destructor Destroy; override;
    procedure RegisterCheck(CheckClass: TClass);
    function CheckHealth(AProvider: IServiceProvider): TDictionary<string, THealthCheckResult>;
  end;

  THealthCheckMiddleware = class(TMiddleware)
  private
    FService: THealthCheckService;
  public
    constructor Create(Service: THealthCheckService);
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  THealthCheckBuilder = class
  private
    FServices: IServiceCollection;
    FChecks: TList<TClass>;
    FSharedChecks: TList<TClass>; // ✅ Shared with factory
    FUpdateCallback: TProc; // ✅ Callback to update captured checks
  public
    constructor Create(Services: IServiceCollection; SharedChecks: TList<TClass>; UpdateCallback: TProc);
    destructor Destroy; override;
    function AddCheck<T: class, constructor>: THealthCheckBuilder;
    procedure Build; // Registers the service
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
  FChecks.Add(CheckClass);
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
      // Resolve check from DI using the provided scope/provider
      Obj := AProvider.GetService(TServiceType.FromClass(CheckClass));
      if Supports(Obj, IHealthCheck, Check) then
      begin
        try
          Res := Check.CheckHealth;
          Result.Add(CheckClass.ClassName, Res);
        except
          on E: Exception do
            Result.Add(CheckClass.ClassName, THealthCheckResult.Unhealthy('Exception during check', E));
        end;
      end
      else
      begin
        Result.Add(CheckClass.ClassName, THealthCheckResult.Unhealthy('Service does not implement IHealthCheck'));
      end;
    except
      on E: Exception do
        Result.Add(CheckClass.ClassName, THealthCheckResult.Unhealthy('Failed to resolve service', E));
    end;
  end;
end;

{ THealthCheckMiddleware }

constructor THealthCheckMiddleware.Create(Service: THealthCheckService);
begin
  inherited Create;
  if Service = nil then
    raise Exception.Create('THealthCheckMiddleware: Service is nil! Dependency Injection failed.');
  FService := Service;
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

    // Use the scoped provider from the context
    Results := FService.CheckHealth(AContext.Services); 
    try
      OverallStatus := THealthStatus.Healthy;
    for Pair in Results do
      if Pair.Value.Status = THealthStatus.Unhealthy then
        OverallStatus := THealthStatus.Unhealthy;

    Json := TStringBuilder.Create;
    try
      Json.Append('{');
      
      if OverallStatus = THealthStatus.Healthy then
        Json.Append('"status": "Healthy",')
      else
        Json.Append('"status": "Unhealthy",');
        
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
      if OverallStatus = THealthStatus.Healthy then
        AContext.Response.StatusCode := 200
      else
        AContext.Response.StatusCode := 503;
        
      AContext.Response.Write(Json.ToString);
    finally
      Json.Free;
    end;
  finally
    Results.Free;
  end;
end;

{ THealthCheckBuilder }

constructor THealthCheckBuilder.Create(Services: IServiceCollection; SharedChecks: TList<TClass>; UpdateCallback: TProc);
begin
  inherited Create;
  FServices := Services;
  FSharedChecks := SharedChecks; // Reference to shared list
  FChecks := FSharedChecks; // Use the same list
  FUpdateCallback := UpdateCallback; // Store callback
end;

destructor THealthCheckBuilder.Destroy;
begin
  // ✅ Free the shared list - we own it
  if Assigned(FSharedChecks) then
    FSharedChecks.Free;
  FChecks := nil;
  FSharedChecks := nil;
  FUpdateCallback := nil;
  inherited;
end;

function THealthCheckBuilder.AddCheck<T>: THealthCheckBuilder;
begin
  // Register the check implementation
  FServices.AddTransient(TServiceType.FromClass(T), T);
  
  // Add to our SHARED list (will be visible to the factory)
  FSharedChecks.Add(T);
  
  Result := Self;
end;

procedure THealthCheckBuilder.Build;
begin

  
  // ✅ Call the callback to copy checks to the factory's captured array
  if Assigned(FUpdateCallback) then
    FUpdateCallback();
  
  Self.Free;
end;

end.
