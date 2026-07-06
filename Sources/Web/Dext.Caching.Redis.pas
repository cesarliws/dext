{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
unit Dext.Caching.Redis;

interface

uses
  System.SysUtils,
  Dext.Caching,
  Dext.Net.Redis,
  Dext.Web.Interfaces;

type
  /// <summary>
  ///   Implementacao de provedor de cache baseada em Redis para o Dext Framework.
  /// </summary>
  TRedisCacheStore = class(TInterfacedObject, ICacheStore)
  private
    FHost: string;
    FPort: Integer;
    FPassword: string;
    FDatabase: Integer;
    FRedisClient: TDextRedisClient;
  protected
    /// <summary>
    ///   Retorna a chave formatada com o prefixo padrao do cache do Dext.
    /// </summary>
    function GetRedisKey(const AKey: string): string;
  public
    /// <summary>
    ///   Inicializa o provedor de cache com as credenciais e parametros de conexao do Redis.
    /// </summary>
    constructor Create(const AHost: string = 'localhost'; APort: Integer = 6379; 
      const APassword: string = ''; ADatabase: Integer = 0);
    /// <summary>
    ///   Destroi a instancia do provedor de cache liberando a conexao do Redis.
    /// </summary>
    destructor Destroy; override;
    
    /// <summary>
    ///   Tenta recuperar um valor do cache associado a chave especificada.
    /// </summary>
    function TryGet(const AKey: string; out AValue: string): Boolean;
    /// <summary>
    ///   Define um valor no cache associado a uma chave com um tempo de duracao em segundos.
    /// </summary>
    procedure SetValue(const AKey: string; const AValue: string; ADurationSeconds: Integer);
    /// <summary>
    ///   Remove uma chave e seu valor associado do cache.
    /// </summary>
    procedure Remove(const AKey: string);
    /// <summary>
    ///   Limpa todas as chaves do banco de dados Redis configurado.
    /// </summary>
    procedure Clear;
  end;

  /// <summary>
  ///   Record helper para expor UseRedisCache no TAppBuilder.
  /// </summary>
  TRedisAppBuilderHelper = record helper for TAppBuilder
  public
    /// <summary>
    ///   Configura e ativa o cache de resposta HTTP utilizando Redis.
    /// </summary>
    function UseRedisCache(const AHost: string = 'localhost'; APort: Integer = 6379; 
      const APassword: string = ''; ADatabase: Integer = 0; ADurationSeconds: Integer = 60): TAppBuilder;
  end;

implementation

{ TRedisAppBuilderHelper }

function TRedisAppBuilderHelper.UseRedisCache(const AHost: string; APort: Integer; 
  const APassword: string; ADatabase: Integer; ADurationSeconds: Integer): TAppBuilder;
begin
  TApplicationBuilderCacheExtensions.UseResponseCache(
    Self.Unwrap,
    TResponseCacheBuilder.Create
      .DefaultDuration(ADurationSeconds)
      .Store(TRedisCacheStore.Create(AHost, APort, APassword, ADatabase))
  );
  Result := Self;
end;

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
    // Falha silenciosa
  end;
end;

procedure TRedisCacheStore.Remove(const AKey: string);
begin
  try
    FRedisClient.Del(GetRedisKey(AKey));
  except
    // Falha silenciosa
  end;
end;

procedure TRedisCacheStore.Clear;
begin
  try
    FRedisClient.Execute('FLUSHDB', []);
  except
    // Falha silenciosa
  end;
end;

end.
