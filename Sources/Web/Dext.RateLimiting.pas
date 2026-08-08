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
unit Dext.RateLimiting;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Dext.Web.Builder,
  Dext.Web.Interfaces,
  Dext.RateLimiting.Core,
  Dext.RateLimiting.Limiters,
  Dext.RateLimiting.Policy;

type
  /// <summary>
  ///   Advanced rate limiting middleware with support for multiple algorithms and partition strategies.
  /// </summary>
  TRateLimitMiddleware = class(TMiddleware)
  private
    FConfig: TRateLimitConfig;
    FLimiter: IRateLimiter;
    FGlobalLimiter: IRateLimiter;
    FLock: TCriticalSection;
    
    function GetPartitionKey(AContext: IHttpContext): string;
    function CreateLimiter(AConfig: TRateLimitConfig): IRateLimiter;
  public
    constructor Create(const APolicy: TRateLimitPolicy); overload;
    constructor Create(AConfig: TRateLimitConfig); overload;
    destructor Destroy; override;
    
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

  /// <summary>
  ///   Extension methods to facilitate Rate Limiting configuration in <see cref="IApplicationBuilder"/>.
  /// </summary>
  TApplicationBuilderRateLimitExtensions = class
  public
    /// <summary>
    ///   Adds rate limiting middleware to the pipeline.
    /// </summary>
    class function UseRateLimiting(ABuilder: IApplicationBuilder; const APolicy: TRateLimitPolicy): IApplicationBuilder; static;
  end;

implementation

{ TRateLimitMiddleware }

constructor TRateLimitMiddleware.Create(const APolicy: TRateLimitPolicy);
begin
  Create(APolicy.Build);
  // Policy is a record, no need to free. Initialization ownership transfered.
end;

constructor TRateLimitMiddleware.Create(AConfig: TRateLimitConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FLimiter := CreateLimiter(FConfig);
  FLock := TCriticalSection.Create;
  
  // Create global limiter if enabled
  if FConfig.EnableGlobalLimit then
  begin
    FGlobalLimiter := TConcurrencyLimiter.Create(FConfig.GlobalConcurrencyLimit);
  end;
end;

destructor TRateLimitMiddleware.Destroy;
begin
  FConfig.Free;
  FLock.Free;
  inherited;
end;

function TRateLimitMiddleware.CreateLimiter(AConfig: TRateLimitConfig): IRateLimiter;
begin
  case AConfig.LimiterType of
    rltFixedWindow:
      Result := TFixedWindowLimiter.Create(AConfig.PermitLimit, AConfig.WindowSeconds);
    
    rltSlidingWindow:
      Result := TSlidingWindowLimiter.Create(AConfig.PermitLimit, AConfig.WindowSeconds);
    
    rltTokenBucket:
      Result := TTokenBucketLimiter.Create(AConfig.TokenLimit, AConfig.RefillRate);
    
    rltConcurrency:
      Result := TConcurrencyLimiter.Create(AConfig.ConcurrencyLimit);
  else
    raise Exception.Create('Unknown rate limiter type');
  end;
end;

function TRateLimitMiddleware.GetPartitionKey(AContext: IHttpContext): string;
begin
  case FConfig.PartitionStrategy of
    psIpAddress:
      Result := AContext.Request.RemoteIpAddress;
    
    psHeader:
      begin
        if FConfig.PartitionHeader <> '' then
        begin
          if AContext.Request.Headers.TryGetValue(FConfig.PartitionHeader, Result) then
            Exit;
        end;
        Result := 'unknown';
      end;
    
    psRoute:
      Result := AContext.Request.Path;
    
    psCustom:
      begin
        if Assigned(FConfig.PartitionResolver) then
          Result := FConfig.PartitionResolver(AContext)
        else
          Result := 'unknown';
      end;
  else
    Result := 'unknown';
  end;
  
  // Fallback
  if Result = '' then
    Result := 'unknown';
end;

procedure TRateLimitMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  PartitionKey: string;
  LimitResult: TRateLimitResult;
  GlobalResult: TRateLimitResult;
  ShouldRelease: Boolean;
begin
  ShouldRelease := False;
  
  try
    // Check global limit first
    if Assigned(FGlobalLimiter) then
    begin
      GlobalResult := FGlobalLimiter.TryAcquire('__global__');
      if not GlobalResult.IsAllowed then
      begin
        AContext.Response.Status(FConfig.RejectionStatusCode);
        if GlobalResult.RetryAfter > 0 then
          AContext.Response.AddHeader('Retry-After', IntToStr(GlobalResult.RetryAfter));
        AContext.Response.Json(Format('{"error":"%s"}', [GlobalResult.Reason]));
        Exit;
      end;
      ShouldRelease := True;
    end;
    
    // Get partition key
    PartitionKey := GetPartitionKey(AContext);
    
    // Check partition limit
    LimitResult := FLimiter.TryAcquire(PartitionKey);
    
    if not LimitResult.IsAllowed then
    begin
      // Rate limit exceeded
      AContext.Response.Status(FConfig.RejectionStatusCode);
      AContext.Response.AddHeader('X-RateLimit-Limit', IntToStr(LimitResult.Limit));
      AContext.Response.AddHeader('X-RateLimit-Remaining', '0');
      AContext.Response.AddHeader('RateLimit-Limit', IntToStr(LimitResult.Limit));
      AContext.Response.AddHeader('RateLimit-Remaining', '0');
      if LimitResult.RetryAfter > 0 then
      begin
        AContext.Response.AddHeader('X-RateLimit-Reset', IntToStr(LimitResult.RetryAfter));
        AContext.Response.AddHeader('RateLimit-Reset', IntToStr(LimitResult.RetryAfter));
        AContext.Response.AddHeader('Retry-After', IntToStr(LimitResult.RetryAfter));
      end;
      AContext.Response.Json(Format('{"error":"%s"}', [FConfig.RejectionMessage]));
      Exit;
    end;
    
    // Allow request (RFC 9333 & Legacy headers)
    AContext.Response.AddHeader('X-RateLimit-Limit', IntToStr(LimitResult.Limit));
    AContext.Response.AddHeader('X-RateLimit-Remaining', IntToStr(LimitResult.Remaining));
    AContext.Response.AddHeader('RateLimit-Limit', IntToStr(LimitResult.Limit));
    AContext.Response.AddHeader('RateLimit-Remaining', IntToStr(LimitResult.Remaining));
    if LimitResult.RetryAfter > 0 then
    begin
      AContext.Response.AddHeader('X-RateLimit-Reset', IntToStr(LimitResult.RetryAfter));
      AContext.Response.AddHeader('RateLimit-Reset', IntToStr(LimitResult.RetryAfter));
    end;
    
    try
      ANext(AContext);
    finally
      // Release for concurrency limiter
      if FConfig.LimiterType = rltConcurrency then
        FLimiter.Release(PartitionKey);
    end;
    
  finally
    if ShouldRelease and Assigned(FGlobalLimiter) then
      FGlobalLimiter.Release('__global__');
  end;
end;

{ TApplicationBuilderRateLimitExtensions }

class function TApplicationBuilderRateLimitExtensions.UseRateLimiting(
  ABuilder: IApplicationBuilder; const APolicy: TRateLimitPolicy): IApplicationBuilder;
var
  Middleware: TRateLimitMiddleware;
begin
  Middleware := TRateLimitMiddleware.Create(APolicy);
  Result := ABuilder.UseMiddleware(Middleware);
end;

end.

