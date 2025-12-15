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
unit Dext.RateLimiting.Limiters;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections,
  System.SyncObjs,
  System.Math,
  Dext.RateLimiting.Core;

type
  /// <summary>
  ///   Fixed window rate limiter.
  ///   Counts requests in fixed time windows.
  /// </summary>
  TFixedWindowLimiter = class(TInterfacedObject, IRateLimiter)
  private
    type
      TWindowEntry = record
        RequestCount: Integer;
        WindowStart: TDateTime;
      end;
  private
    FPermitLimit: Integer;
    FWindowSeconds: Integer;
    FEntries: TDictionary<string, TWindowEntry>;
    FLock: TCriticalSection;
  public
    constructor Create(APermitLimit, AWindowSeconds: Integer);
    destructor Destroy; override;
    
    function TryAcquire(const APartitionKey: string): TRateLimitResult;
    procedure Release(const APartitionKey: string);
    procedure Cleanup;
  end;

  /// <summary>
  ///   Sliding window rate limiter.
  ///   More precise than fixed window, prevents edge cases.
  /// </summary>
  TSlidingWindowLimiter = class(TInterfacedObject, IRateLimiter)
  private
    type
      TRequestTimestamp = record
        Timestamp: TDateTime;
      end;
      TRequestList = TList<TRequestTimestamp>;
  private
    FPermitLimit: Integer;
    FWindowSeconds: Integer;
    FEntries: TObjectDictionary<string, TRequestList>;
    FLock: TCriticalSection;
  public
    constructor Create(APermitLimit, AWindowSeconds: Integer);
    destructor Destroy; override;
    
    function TryAcquire(const APartitionKey: string): TRateLimitResult;
    procedure Release(const APartitionKey: string);
    procedure Cleanup;
  end;

  /// <summary>
  ///   Token bucket rate limiter.
  ///   Allows controlled bursts with token refill.
  /// </summary>
  TTokenBucketLimiter = class(TInterfacedObject, IRateLimiter)
  private
    type
      TBucketEntry = record
        Tokens: Double;
        LastRefill: TDateTime;
      end;
  private
    FTokenLimit: Integer;
    FRefillRate: Integer;  // Tokens per second
    FEntries: TDictionary<string, TBucketEntry>;
    FLock: TCriticalSection;
    
    procedure RefillTokens(var AEntry: TBucketEntry);
  public
    constructor Create(ATokenLimit, ARefillRate: Integer);
    destructor Destroy; override;
    
    function TryAcquire(const APartitionKey: string): TRateLimitResult;
    procedure Release(const APartitionKey: string);
    procedure Cleanup;
  end;

  /// <summary>
  ///   Concurrency limiter.
  ///   Limits number of concurrent requests.
  /// </summary>
  TConcurrencyLimiter = class(TInterfacedObject, IRateLimiter)
  private
    FConcurrencyLimit: Integer;
    FCurrentCount: TDictionary<string, Integer>;
    FLock: TCriticalSection;
  public
    constructor Create(AConcurrencyLimit: Integer);
    destructor Destroy; override;
    
    function TryAcquire(const APartitionKey: string): TRateLimitResult;
    procedure Release(const APartitionKey: string);
    procedure Cleanup;
  end;

implementation

{ TFixedWindowLimiter }

constructor TFixedWindowLimiter.Create(APermitLimit, AWindowSeconds: Integer);
begin
  inherited Create;
  FPermitLimit := APermitLimit;
  FWindowSeconds := AWindowSeconds;
  FEntries := TDictionary<string, TWindowEntry>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TFixedWindowLimiter.Destroy;
begin
  FEntries.Free;
  FLock.Free;
  inherited;
end;

function TFixedWindowLimiter.TryAcquire(const APartitionKey: string): TRateLimitResult;
var
  Entry: TWindowEntry;
  Now: TDateTime;
  WindowElapsed: Boolean;
begin
  FLock.Enter;
  try
    Now := System.SysUtils.Now;
    
    if FEntries.TryGetValue(APartitionKey, Entry) then
    begin
      WindowElapsed := SecondsBetween(Now, Entry.WindowStart) >= FWindowSeconds;
      
      if WindowElapsed then
      begin
        // Reset window
        Entry.RequestCount := 1;
        Entry.WindowStart := Now;
        FEntries.AddOrSetValue(APartitionKey, Entry);
        Result := TRateLimitResult.Allow;
      end
      else
      begin
        // Check limit
        if Entry.RequestCount >= FPermitLimit then
        begin
          var RetryAfter := FWindowSeconds - SecondsBetween(Now, Entry.WindowStart);
          Result := TRateLimitResult.Deny('Fixed window limit exceeded', RetryAfter);
        end
        else
        begin
          Inc(Entry.RequestCount);
          FEntries.AddOrSetValue(APartitionKey, Entry);
          Result := TRateLimitResult.Allow;
        end;
      end;
    end
    else
    begin
      // First request
      Entry.RequestCount := 1;
      Entry.WindowStart := Now;
      FEntries.Add(APartitionKey, Entry);
      Result := TRateLimitResult.Allow;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFixedWindowLimiter.Release(const APartitionKey: string);
begin
  // Fixed window doesn't need release
end;

procedure TFixedWindowLimiter.Cleanup;
var
  Now: TDateTime;
  KeysToRemove: TList<string>;
  Key: string;
  Entry: TWindowEntry;
begin
  FLock.Enter;
  try
    Now := System.SysUtils.Now;
    KeysToRemove := TList<string>.Create;
    try
      for Key in FEntries.Keys do
      begin
        Entry := FEntries[Key];
        if SecondsBetween(Now, Entry.WindowStart) > FWindowSeconds * 2 then
          KeysToRemove.Add(Key);
      end;
      
      for Key in KeysToRemove do
        FEntries.Remove(Key);
    finally
      KeysToRemove.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

{ TSlidingWindowLimiter }

constructor TSlidingWindowLimiter.Create(APermitLimit, AWindowSeconds: Integer);
begin
  inherited Create;
  FPermitLimit := APermitLimit;
  FWindowSeconds := AWindowSeconds;
  FEntries := TObjectDictionary<string, TRequestList>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
end;

destructor TSlidingWindowLimiter.Destroy;
begin
  FEntries.Free;
  FLock.Free;
  inherited;
end;

function TSlidingWindowLimiter.TryAcquire(const APartitionKey: string): TRateLimitResult;
var
  RequestList: TRequestList;
  Now: TDateTime;
  WindowStart: TDateTime;
  I: Integer;
  ValidCount: Integer;
  NewRequest: TRequestTimestamp;
begin
  FLock.Enter;
  try
    Now := System.SysUtils.Now;
    WindowStart := IncSecond(Now, -FWindowSeconds);
    
    if not FEntries.TryGetValue(APartitionKey, RequestList) then
    begin
      RequestList := TRequestList.Create;
      FEntries.Add(APartitionKey, RequestList);
    end;
    
    // Remove expired requests
    I := 0;
    while I < RequestList.Count do
    begin
      if RequestList[I].Timestamp < WindowStart then
        RequestList.Delete(I)
      else
        Inc(I);
    end;
    
    ValidCount := RequestList.Count;
    
    if ValidCount >= FPermitLimit then
    begin
      var OldestRequest := RequestList[0].Timestamp;
      var RetryAfter := SecondsBetween(IncSecond(OldestRequest, FWindowSeconds), Now);
      Result := TRateLimitResult.Deny('Sliding window limit exceeded', RetryAfter);
    end
    else
    begin
      NewRequest.Timestamp := Now;
      RequestList.Add(NewRequest);
      Result := TRateLimitResult.Allow;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSlidingWindowLimiter.Release(const APartitionKey: string);
begin
  // Sliding window doesn't need release
end;

procedure TSlidingWindowLimiter.Cleanup;
var
  Now: TDateTime;
  WindowStart: TDateTime;
  KeysToRemove: TList<string>;
  Key: string;
  RequestList: TRequestList;
begin
  FLock.Enter;
  try
    Now := System.SysUtils.Now;
    WindowStart := IncSecond(Now, -FWindowSeconds * 2);
    KeysToRemove := TList<string>.Create;
    try
      for Key in FEntries.Keys do
      begin
        RequestList := FEntries[Key];
        if (RequestList.Count = 0) or (RequestList[RequestList.Count - 1].Timestamp < WindowStart) then
          KeysToRemove.Add(Key);
      end;
      
      for Key in KeysToRemove do
        FEntries.Remove(Key);
    finally
      KeysToRemove.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

{ TTokenBucketLimiter }

constructor TTokenBucketLimiter.Create(ATokenLimit, ARefillRate: Integer);
begin
  inherited Create;
  FTokenLimit := ATokenLimit;
  FRefillRate := ARefillRate;
  FEntries := TDictionary<string, TBucketEntry>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TTokenBucketLimiter.Destroy;
begin
  FEntries.Free;
  FLock.Free;
  inherited;
end;

procedure TTokenBucketLimiter.RefillTokens(var AEntry: TBucketEntry);
var
  Now: TDateTime;
  ElapsedSeconds: Double;
  TokensToAdd: Double;
begin
  Now := System.SysUtils.Now;
  ElapsedSeconds := SecondSpan(AEntry.LastRefill, Now);
  TokensToAdd := ElapsedSeconds * FRefillRate;
  
  AEntry.Tokens := Min(FTokenLimit, AEntry.Tokens + TokensToAdd);
  AEntry.LastRefill := Now;
end;

function TTokenBucketLimiter.TryAcquire(const APartitionKey: string): TRateLimitResult;
var
  Entry: TBucketEntry;
begin
  FLock.Enter;
  try
    if FEntries.TryGetValue(APartitionKey, Entry) then
    begin
      RefillTokens(Entry);
    end
    else
    begin
      // Initialize new bucket
      Entry.Tokens := FTokenLimit;
      Entry.LastRefill := System.SysUtils.Now;
    end;
    
    if Entry.Tokens >= 1.0 then
    begin
      Entry.Tokens := Entry.Tokens - 1.0;
      FEntries.AddOrSetValue(APartitionKey, Entry);
      Result := TRateLimitResult.Allow;
    end
    else
    begin
      var RetryAfter := Ceil((1.0 - Entry.Tokens) / FRefillRate);
      FEntries.AddOrSetValue(APartitionKey, Entry);
      Result := TRateLimitResult.Deny('Token bucket empty', RetryAfter);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TTokenBucketLimiter.Release(const APartitionKey: string);
begin
  // Token bucket doesn't need release
end;

procedure TTokenBucketLimiter.Cleanup;
var
  Now: TDateTime;
  KeysToRemove: TList<string>;
  Key: string;
  Entry: TBucketEntry;
begin
  FLock.Enter;
  try
    Now := System.SysUtils.Now;
    KeysToRemove := TList<string>.Create;
    try
      for Key in FEntries.Keys do
      begin
        Entry := FEntries[Key];
        if SecondsBetween(Now, Entry.LastRefill) > 3600 then  // 1 hour idle
          KeysToRemove.Add(Key);
      end;
      
      for Key in KeysToRemove do
        FEntries.Remove(Key);
    finally
      KeysToRemove.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

{ TConcurrencyLimiter }

constructor TConcurrencyLimiter.Create(AConcurrencyLimit: Integer);
begin
  inherited Create;
  FConcurrencyLimit := AConcurrencyLimit;
  FCurrentCount := TDictionary<string, Integer>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TConcurrencyLimiter.Destroy;
begin
  FCurrentCount.Free;
  FLock.Free;
  inherited;
end;

function TConcurrencyLimiter.TryAcquire(const APartitionKey: string): TRateLimitResult;
var
  Count: Integer;
begin
  FLock.Enter;
  try
    if not FCurrentCount.TryGetValue(APartitionKey, Count) then
      Count := 0;
    
    if Count >= FConcurrencyLimit then
    begin
      Result := TRateLimitResult.Deny('Concurrency limit exceeded', 1);
    end
    else
    begin
      FCurrentCount.AddOrSetValue(APartitionKey, Count + 1);
      Result := TRateLimitResult.Allow;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TConcurrencyLimiter.Release(const APartitionKey: string);
var
  Count: Integer;
begin
  FLock.Enter;
  try
    if FCurrentCount.TryGetValue(APartitionKey, Count) then
    begin
      if Count > 1 then
        FCurrentCount.AddOrSetValue(APartitionKey, Count - 1)
      else
        FCurrentCount.Remove(APartitionKey);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TConcurrencyLimiter.Cleanup;
begin
  // Concurrency limiter doesn't need cleanup
end;

end.

