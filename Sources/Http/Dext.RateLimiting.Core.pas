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
unit Dext.RateLimiting.Core;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  System.SyncObjs,
  Dext.Http.Interfaces;

type
  /// <summary>
  ///   Partition key resolver function type.
  /// </summary>
  TPartitionKeyResolver = reference to function(AContext: IHttpContext): string;

  /// <summary>
  ///   Rate limiter algorithm type.
  /// </summary>
  TRateLimiterType = (
    rltFixedWindow,      // Fixed time window
    rltSlidingWindow,    // Sliding time window (more precise)
    rltTokenBucket,      // Token bucket with refill
    rltConcurrency       // Concurrent request limit
  );

  /// <summary>
  ///   Partition strategy for rate limiting.
  /// </summary>
  TPartitionStrategy = (
    psIpAddress,         // Partition by client IP
    psHeader,            // Partition by specific header
    psRoute,             // Partition by route path
    psCustom             // Custom partition function
  );

  /// <summary>
  ///   Result of a rate limit check.
  /// </summary>
  TRateLimitResult = record
    IsAllowed: Boolean;
    RetryAfter: Integer;  // Seconds until retry
    Reason: string;
    
    class function Allow: TRateLimitResult; static;
    class function Deny(const AReason: string; ARetryAfter: Integer = 0): TRateLimitResult; static;
  end;

  /// <summary>
  ///   Base interface for rate limiters.
  /// </summary>
  IRateLimiter = interface
    ['{8A9B1C2D-3E4F-5A6B-7C8D-9E0F1A2B3C4D}']
    function TryAcquire(const APartitionKey: string): TRateLimitResult;
    procedure Release(const APartitionKey: string);
    procedure Cleanup;
  end;

  /// <summary>
  ///   Configuration for rate limiting policy.
  /// </summary>
  TRateLimitConfig = class
  private
    FLimiterType: TRateLimiterType;
    FPartitionStrategy: TPartitionStrategy;
    FPartitionHeader: string;
    FPartitionResolver: TPartitionKeyResolver;
    
    // Fixed Window / Sliding Window
    FPermitLimit: Integer;
    FWindowSeconds: Integer;
    
    // Token Bucket
    FTokenLimit: Integer;
    FRefillRate: Integer;  // Tokens per second
    
    // Concurrency
    FConcurrencyLimit: Integer;
    
    // Global limits
    FGlobalConcurrencyLimit: Integer;
    FEnableGlobalLimit: Boolean;
    
    // Response configuration
    FRejectionMessage: string;
    FRejectionStatusCode: Integer;
  public
    constructor Create;
    
    property LimiterType: TRateLimiterType read FLimiterType write FLimiterType;
    property PartitionStrategy: TPartitionStrategy read FPartitionStrategy write FPartitionStrategy;
    property PartitionHeader: string read FPartitionHeader write FPartitionHeader;
    property PartitionResolver: TPartitionKeyResolver read FPartitionResolver write FPartitionResolver;
    
    property PermitLimit: Integer read FPermitLimit write FPermitLimit;
    property WindowSeconds: Integer read FWindowSeconds write FWindowSeconds;
    
    property TokenLimit: Integer read FTokenLimit write FTokenLimit;
    property RefillRate: Integer read FRefillRate write FRefillRate;
    
    property ConcurrencyLimit: Integer read FConcurrencyLimit write FConcurrencyLimit;
    
    property GlobalConcurrencyLimit: Integer read FGlobalConcurrencyLimit write FGlobalConcurrencyLimit;
    property EnableGlobalLimit: Boolean read FEnableGlobalLimit write FEnableGlobalLimit;
    
    property RejectionMessage: string read FRejectionMessage write FRejectionMessage;
    property RejectionStatusCode: Integer read FRejectionStatusCode write FRejectionStatusCode;
  end;

implementation

{ TRateLimitResult }

class function TRateLimitResult.Allow: TRateLimitResult;
begin
  Result.IsAllowed := True;
  Result.RetryAfter := 0;
  Result.Reason := '';
end;

class function TRateLimitResult.Deny(const AReason: string; ARetryAfter: Integer): TRateLimitResult;
begin
  Result.IsAllowed := False;
  Result.RetryAfter := ARetryAfter;
  Result.Reason := AReason;
end;

{ TRateLimitConfig }

constructor TRateLimitConfig.Create;
begin
  inherited Create;
  FLimiterType := rltFixedWindow;
  FPartitionStrategy := psIpAddress;
  FPermitLimit := 100;
  FWindowSeconds := 60;
  FRejectionMessage := 'Rate limit exceeded. Please try again later.';
  FRejectionStatusCode := 429;
  FEnableGlobalLimit := False;
  FGlobalConcurrencyLimit := 0;
end;

end.

