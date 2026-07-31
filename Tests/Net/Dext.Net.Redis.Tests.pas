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
unit Dext.Net.Redis.Tests;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing,
  Dext.Testing.Attributes,
  Dext.Testing.Fluent,
  Dext.Net.Redis,
  Dext.Net.Security;

type
  [TestFixture('Redis Client Tests')]
  TDextRedisClientTests = class
  private
    FClient: TDextRedisClient;
  public
    [SetUp]
    procedure SetUp;

    [TearDown]
    procedure TearDown;

    [Test('Ping Server')]
    procedure TestPing;

    [Test('Set and Get String Value')]
    procedure TestSetAndGet;

    [Test('Delete Key')]
    procedure TestDeleteKey;

    [Test('Key Expiration')]
    procedure TestExpire;

    [Test('Hash HSet and HGet')]
    procedure TestHashOperations;

    [Test('Real SSL/TLS Connection to Memurai (port 6380)')]
    procedure TestSSLConnection;
  end;

implementation

{ TDextRedisClientTests }

procedure TDextRedisClientTests.SetUp;
begin
  FClient := TDextRedisClient.Create('127.0.0.1', 6379, 8);
end;

procedure TDextRedisClientTests.TearDown;
begin
  if Assigned(FClient) then
  begin
    FClient.Del('dext:test:key');
    FClient.Del('dext:test:hash');
    FreeAndNil(FClient);
  end;
end;

procedure TDextRedisClientTests.TestPing;
var
  Res: TDextRedisValue;
begin
  Res := FClient.Execute('PING', []);
  Should(Res.AsString).Be('PONG');
end;

procedure TDextRedisClientTests.TestSetAndGet;
var
  Success: Boolean;
  ValueStr: string;
begin
  Success := FClient.SetVal('dext:test:key', 'Hello Dext Redis!');
  Should(Success).BeTrue;

  ValueStr := FClient.Get('dext:test:key');
  Should(ValueStr).Be('Hello Dext Redis!');
end;

procedure TDextRedisClientTests.TestDeleteKey;
var
  DeletedCount: Integer;
begin
  FClient.SetVal('dext:test:key', 'Temporary Value');
  DeletedCount := FClient.Del('dext:test:key');
  Should(DeletedCount).Be(1);

  Should(FClient.Get('dext:test:key')).Be('');
end;

procedure TDextRedisClientTests.TestExpire;
var
  Success: Boolean;
begin
  FClient.SetVal('dext:test:key', 'Expiring Value');
  Success := FClient.Expire('dext:test:key', 60);
  Should(Success).BeTrue;
end;

procedure TDextRedisClientTests.TestHashOperations;
var
  ValueStr: string;
begin
  FClient.HSet('dext:test:hash', 'user', 'Cesar');
  ValueStr := FClient.HGet('dext:test:hash', 'user');
  Should(ValueStr).Be('Cesar');
end;

procedure TDextRedisClientTests.TestSSLConnection;
var
  TLSOpts: TDextTLSOptions;
  SslClient: TDextRedisClient;
  Res: TDextRedisValue;
begin
  TLSOpts := TDextTLSOptions.DefaultClient;
  TLSOpts.VerifyServerCertificate := False;

  SslClient := TDextRedisClient.Create('127.0.0.1', 6380, TLSOpts, 4);
  try
    Res := SslClient.Execute('PING', []);
    Should(Res.AsString).Be('PONG');

    SslClient.SetVal('dext:ssl:key', 'Encrypted Payload Over TLS');
    Should(SslClient.Get('dext:ssl:key')).Be('Encrypted Payload Over TLS');
    SslClient.Del('dext:ssl:key');
  finally
    SslClient.Free;
  end;
end;

end.
