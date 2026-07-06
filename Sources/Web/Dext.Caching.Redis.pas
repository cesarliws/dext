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
unit Dext.Caching.Redis;

{
  Redis Cache Store Implementation using Dext.Net.Redis
}

interface

uses
  System.SysUtils,
  Dext.Caching,
  Dext.Net.Redis;

type
  /// <summary>
  ///   Redis-based cache store implementation.
  /// </summary>
  TRedisCacheStore = class(TInterfacedObject, ICacheStore)
  private
    FHost: string;
    FPort: Integer;
    FPassword: string;
    FDatabase: Integer;
    FRedisClient: TDextRedisClient;
  protected
    function GetRedisKey(const AKey: string): string;
  public
    constructor Create(const AHost: string = 'localhost'; APort: Integer = 6379; 
      const APassword: string = ''; ADatabase: Integer = 0);
    destructor Destroy; override;
    
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure SetValue(const AKey: string; const AValue: string; ADurationSeconds: Integer);
    procedure Remove(const AKey: string);
    procedure Clear;
  end;

implementation

{ TRedisCacheStore }

constructor TRedisCacheStore.Create(const AHost: string; APort: Integer; 
  const APassword: string; ADatabase: Integer);
begin
  inherited Create;
  FHost := AHost;
  FPort := APort;
  FPassword := APassword;
  FDatabase := ADatabase;
  
  FRedisClient := TDextRedisClient.Create(FHost, FPort);
  // Note: auth & database select can be added if client supports auth command via Execute
  if FPassword <> '' then
    FRedisClient.Execute('AUTH', [FPassword]);
  if FDatabase <> 0 then
    FRedisClient.Execute('SELECT', [FDatabase.ToString]);
end;

destructor TRedisCacheStore.Destroy;
begin
  FRedisClient.Free;
  inherited;
end;

function TRedisCacheStore.GetRedisKey(const AKey: string): string;
begin
  Result := 'dext:cache:' + AKey;
end;

function TRedisCacheStore.TryGet(const AKey: string; out AValue: string): Boolean;
begin
  try
    AValue := FRedisClient.Get(GetRedisKey(AKey));
    Result := AValue <> '';
  except
    Result := False;
  end;
end;

procedure TRedisCacheStore.SetValue(const AKey, AValue: string; ADurationSeconds: Integer);
begin
  try
    FRedisClient.SetVal(GetRedisKey(AKey), AValue, ADurationSeconds);
  except
    // Silent fail or log
  end;
end;

procedure TRedisCacheStore.Remove(const AKey: string);
begin
  try
    FRedisClient.Del(GetRedisKey(AKey));
  except
    // Silent fail
  end;
end;

procedure TRedisCacheStore.Clear;
begin
  try
    // In production we could flush or use keys, for now let's flushdb
    FRedisClient.Execute('FLUSHDB', []);
  except
    // Silent fail
  end;
end;

end.

