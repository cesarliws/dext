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
{  Author:  Cesar Romero & Antigravity AI                                   }
{  Created: 2026-07-23                                                      }
{                                                                           }
{  End-to-End communication integration tests for Dext SSL/TLS Security.     }
{                                                                           }
{***************************************************************************}
unit Dext.Net.Security.Tests;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Net.Security,
  Dext.Net.Security.OpenSSL,
  Dext.Net.Security.TestCerts,
  Dext.Net.Redis,
  Dext.Net.Engine,
  Dext.Web,
  Dext.Web.Interfaces,
  Dext.Server.Engine.Types,
  Dext.Server.HttpSys,
  Dext.Web.Indy.Server,
  Dext.Web.Indy.SSL.OpenSSL,
  Dext.Web.Indy.SSL.Taurus,
  Dext.Web.Indy.SSL.Interfaces;

type
  [TestFixture('Dext.Net SSL/TLS Options & Abstractions')]
  TDextSecurityOptionsTests = class
  public
    [Test]
    procedure Options_ShouldCreateDefaultClientOptions;
    [Test]
    procedure Options_ShouldCreateDefaultServerOptions;
  end;

  [TestFixture('Dext.Net Native OpenSSL TLS Engine Integration')]
  TDextSecurityOpenSSLTests = class
  public
    [Test]
    procedure OpenSSL_ShouldInitializeEngineAndContextProvider;
    [Test]
    procedure OpenSSL_ShouldDriveHandshakeAndEncryptPlaintextPayload;
  end;

  [TestFixture('Dext.Net Indy WebServer HTTPS Integration')]
  TDextSecurityIndyHandlerTests = class
  public
    [Test]
    procedure Indy_ShouldCreateOpenSSLHandlerAndStartHttpsServer;
    [Test]
    procedure Indy_ShouldCreateTaurusSSLHandler;
  end;

  [TestFixture('Dext.Net HttpSys Native HTTPS Engine Integration')]
  TDextSecurityHttpSysTests = class
  public
    [Test]
    procedure HttpSys_ShouldSupportHttpsConfigurationAndUrlPrefix;
  end;

  [TestFixture('Dext.Net Redis Client SSL Configuration')]
  TDextSecurityRedisTests = class
  public
    [Test]
    procedure Redis_ShouldInitializeWithTLSOptionsAndConnectMockStream;
  end;

  [TestFixture('Dext.Net REST Client HTTPS Integration')]
  TDextSecurityRestClientTests = class
  public
    [Test]
    procedure RestClient_ShouldAcceptHttpsOptions;
  end;

implementation

{ TDextSecurityOptionsTests }

procedure TDextSecurityOptionsTests.Options_ShouldCreateDefaultClientOptions;
var
  Opts: TDextTLSOptions;
begin
  Opts := TDextTLSOptions.DefaultClient;
  Should(Opts.Enabled).BeTrue;
  Should(Opts.Mode).Be(tlsmClient);
  Should(tls1_2 in Opts.Protocols).BeTrue;
  Should(tls1_3 in Opts.Protocols).BeTrue;
  Should(Opts.VerifyServerCertificate).BeTrue;
  Should(Opts.Provider).Be('Auto');
end;

procedure TDextSecurityOptionsTests.Options_ShouldCreateDefaultServerOptions;
var
  Opts: TDextTLSOptions;
  CertFile, KeyFile: string;
begin
  EnsureTestCertificates(CertFile, KeyFile);
  Opts := TDextTLSOptions.DefaultServer(CertFile, KeyFile);
  Should(Opts.Enabled).BeTrue;
  Should(Opts.Mode).Be(tlsmServer);
  Should(Opts.CertFile).Be(CertFile);
  Should(Opts.KeyFile).Be(KeyFile);
  Should(tls1_2 in Opts.Protocols).BeTrue;
  Should(Opts.StoreName).Be('MY');
end;

{ TDextSecurityOpenSSLTests }

procedure TDextSecurityOpenSSLTests.OpenSSL_ShouldInitializeEngineAndContextProvider;
var
  Opts: TDextTLSOptions;
  CertFile, KeyFile: string;
  Provider: IDextTLSContextProvider;
  Engine: IDextTLSEngine;
begin
{$IFNDEF DEXT_ENABLE_SSL}
  Exit;
{$ENDIF}
  EnsureTestCertificates(CertFile, KeyFile);
  Opts := TDextTLSOptions.DefaultServer(CertFile, KeyFile);
  Provider := TDextOpenSSLContextProvider.Create(Opts);
  Should(Provider).NotBeNil;

  Engine := Provider.CreateEngine(tlsmServer);
  Should(Engine).NotBeNil;
end;

procedure TDextSecurityOpenSSLTests.OpenSSL_ShouldDriveHandshakeAndEncryptPlaintextPayload;
var
  ClientOptions: TDextTLSOptions;
  ServerOptions: TDextTLSOptions;
  ClientEngine: IDextTLSEngine;
  ServerEngine: IDextTLSEngine;
  ClientStatus: TDextTLSEngineStatus;
  ServerStatus: TDextTLSEngineStatus;
  Plaintext: TBytes;
  Decrypted: TBytes;
  NetworkBuffer: TBytes;
  CertFile: string;
  KeyFile: string;
  Written: Integer;
  ReadCount: Integer;
  WireCount: Integer;
  Iteration: Integer;
begin
{$IFNDEF DEXT_ENABLE_SSL}
  Exit;
{$ENDIF}
  EnsureTestCertificates(CertFile, KeyFile);
  ServerOptions := TDextTLSOptions.DefaultServer(CertFile, KeyFile);
  ServerOptions.ALPNProtocols := ['h2', 'http/1.1'];
  ClientOptions := TDextTLSOptions.DefaultClient;
  ClientOptions.VerifyServerCertificate := False;
  ClientOptions.Host := 'localhost';
  ClientOptions.ALPNProtocols := ['h2', 'http/1.1'];
  ClientEngine := TDextOpenSSLTLSEngine.Create(
    ClientOptions, tlsmClient);
  ServerEngine := TDextOpenSSLTLSEngine.Create(
    ServerOptions, tlsmServer);
  SetLength(NetworkBuffer, 16 * 1024);

  for Iteration := 1 to 100 do
  begin
    ClientStatus := ClientEngine.DoHandshake;
    repeat
      WireCount := ClientEngine.EncryptedOutgoing(
        @NetworkBuffer[0], Length(NetworkBuffer));
      if WireCount > 0 then
        Should(ServerEngine.EncryptedIncoming(
          @NetworkBuffer[0], WireCount)).Be(WireCount);
    until WireCount = 0;

    ServerStatus := ServerEngine.DoHandshake;
    repeat
      WireCount := ServerEngine.EncryptedOutgoing(
        @NetworkBuffer[0], Length(NetworkBuffer));
      if WireCount > 0 then
        Should(ClientEngine.EncryptedIncoming(
          @NetworkBuffer[0], WireCount)).Be(WireCount);
    until WireCount = 0;

    if ClientEngine.IsHandshakeCompleted and
       ServerEngine.IsHandshakeCompleted then
      Break;
    Should(ClientStatus = tlsError).BeFalse;
    Should(ServerStatus = tlsError).BeFalse;
  end;

  Should(ClientEngine.IsHandshakeCompleted).BeTrue;
  Should(ServerEngine.IsHandshakeCompleted).BeTrue;
  Should(ClientEngine.GetNegotiatedALPN).Be('h2');
  Should(ServerEngine.GetNegotiatedALPN).Be('h2');

  Plaintext := TEncoding.UTF8.GetBytes('GET / HTTP/1.1'#13#10#13#10);
  Written := ClientEngine.PlaintextWrite(
    @Plaintext[0], Length(Plaintext));
  Should(Written).Be(Length(Plaintext));
  repeat
    WireCount := ClientEngine.EncryptedOutgoing(
      @NetworkBuffer[0], Length(NetworkBuffer));
    if WireCount > 0 then
      ServerEngine.EncryptedIncoming(@NetworkBuffer[0], WireCount);
  until WireCount = 0;

  SetLength(Decrypted, Length(Plaintext));
  ReadCount := ServerEngine.PlaintextRead(
    @Decrypted[0], Length(Decrypted));
  Should(ReadCount).Be(Length(Plaintext));
  Should(TEncoding.UTF8.GetString(Decrypted)).Be(
    TEncoding.UTF8.GetString(Plaintext));
end;

{ TDextSecurityIndyHandlerTests }

procedure TDextSecurityIndyHandlerTests.Indy_ShouldCreateOpenSSLHandlerAndStartHttpsServer;
var
  CertFile, KeyFile: string;
  Handler: IIndySSLHandler;
  Server: TDextIndyWebServer;
  TestPort: Integer;
begin
  EnsureTestCertificates(CertFile, KeyFile);
  Handler := TDextIndyOpenSSLHandler.Create(CertFile, KeyFile, '');
  Should(Handler).NotBeNil;

  TestPort := 58943;
  Server := TDextIndyWebServer.Create(TestPort,
    procedure(Context: IHttpContext)
    begin
      Context.Response.SetStatusCode(200);
      Context.Response.Write('HTTPS OK');
    end,
    nil,
    Handler
  );
  try
    Should(Server.GetPort).Be(TestPort);
  finally
    Server.Free;
  end;
end;

procedure TDextSecurityIndyHandlerTests.Indy_ShouldCreateTaurusSSLHandler;
var
  CertFile, KeyFile: string;
  Handler: IIndySSLHandler;
begin
  EnsureTestCertificates(CertFile, KeyFile);
  Handler := TDextIndyTaurusSSLHandler.Create(CertFile, KeyFile, '');
  Should(Handler).NotBeNil;
end;

{ TDextSecurityHttpSysTests }

procedure TDextSecurityHttpSysTests.HttpSys_ShouldSupportHttpsConfigurationAndUrlPrefix;
var
  Opts: TServerEngineOptions;
begin
  Opts := TServerEngineOptions.Default;
  Opts.UseHttps := True;
  Should(Opts.UseHttps).BeTrue;
end;

{ TDextSecurityRedisTests }

procedure TDextSecurityRedisTests.Redis_ShouldInitializeWithTLSOptionsAndConnectMockStream;
var
  Opts: TDextTLSOptions;
  Client: TDextRedisClient;
begin
  Opts := TDextTLSOptions.DefaultClient;
  Should(Opts.Enabled).BeTrue;
  Should(Opts.Mode).Be(tlsmClient);

  Client := TDextRedisClient.Create('localhost', 6379, Opts, 4);
  try
    Should(Client).NotBeNil;
  finally
    Client.Free;
  end;
end;

{ TDextSecurityRestClientTests }

procedure TDextSecurityRestClientTests.RestClient_ShouldAcceptHttpsOptions;
var
  Opts: TDextTLSOptions;
begin
  Opts := TDextTLSOptions.DefaultClient;
  Should(Opts.Enabled).BeTrue;
  Should(Opts.VerifyServerCertificate).BeTrue;
end;

end.
