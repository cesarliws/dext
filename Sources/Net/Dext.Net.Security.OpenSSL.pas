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
unit Dext.Net.Security.OpenSSL;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Net.Security;

type
  EDextOpenSSLException = class(Exception);

  PSSL_CTX = Pointer;
  PSSL = Pointer;
  PBIO = Pointer;
  PBIO_METHOD = Pointer;
  PSSL_METHOD = Pointer;

  /// <summary>
  ///   Native OpenSSL TLS Engine implementation using Memory BIOs (BIO_s_mem).
  /// </summary>
  TDextOpenSSLTLSEngine = class(TInterfacedObject, IDextTLSEngine)
  private
    FOptions: TDextTLSOptions;
    FHandshakeCompleted: Boolean;
    FNegotiatedALPN: string;
    FMode: TDextTLSMode;
    FSSLContext: PSSL_CTX;
    FSSL: PSSL;
    FInputBIO: PBIO;
    FOutputBIO: PBIO;
    procedure InitOpenSSLEngine;
  public
    /// <summary>Initializes a new instance of TDextOpenSSLTLSEngine.</summary>
    constructor Create(const AOptions: TDextTLSOptions; AMode: TDextTLSMode);
    /// <summary>Destroys OpenSSL engine resources.</summary>
    destructor Destroy; override;

    /// <summary>Pushes raw encrypted bytes received from network into input Memory BIO.</summary>
    function EncryptedIncoming(const ABuffer: Pointer; ACount: Integer): Integer;
    /// <summary>Reads decrypted plaintext data output from OpenSSL.</summary>
    function PlaintextRead(const ABuffer: Pointer; ACount: Integer): Integer;
    /// <summary>Writes plaintext payload to encrypt using OpenSSL.</summary>
    function PlaintextWrite(const ABuffer: Pointer; ACount: Integer): Integer;
    /// <summary>Reads encrypted network bytes out of output Memory BIO for socket transmission.</summary>
    function EncryptedOutgoing(const ABuffer: Pointer; ACount: Integer): Integer;

    /// <summary>Drives the TLS handshake state machine.</summary>
    function DoHandshake: TDextTLSEngineStatus;
    /// <summary>Returns true if TLS handshake has finished successfully.</summary>
    function IsHandshakeCompleted: Boolean;
    /// <summary>Returns negotiated ALPN protocol string if present.</summary>
    function GetNegotiatedALPN: string;
  end;

  /// <summary>
  ///   Factory provider for OpenSSL TLS engines and contexts.
  /// </summary>
  TDextOpenSSLContextProvider = class(TInterfacedObject, IDextTLSContextProvider)
  private
    FOptions: TDextTLSOptions;
  public
    /// <summary>Initializes provider with unified TLS options.</summary>
    constructor Create(const AOptions: TDextTLSOptions);
    /// <summary>Creates a new IDextTLSEngine instance for the specified mode.</summary>
    function CreateEngine(AMode: TDextTLSMode): IDextTLSEngine;
    /// <summary>Returns configured TLS options.</summary>
    function GetOptions: TDextTLSOptions;
  end;

implementation

const
  {$IFDEF MSWINDOWS}
  LIBSSL_DLL = 'libssl-3.dll';
  LIBCRYPTO_DLL = 'libcrypto-3.dll';
  {$ELSE}
  LIBSSL_DLL = 'libssl.so.3';
  LIBCRYPTO_DLL = 'libcrypto.so.3';
  {$ENDIF}

  SSL_ERROR_NONE = 0;
  SSL_ERROR_WANT_READ = 2;
  SSL_ERROR_WANT_WRITE = 3;

function TLS_client_method: PSSL_METHOD; cdecl; external LIBSSL_DLL name 'TLS_client_method';
function TLS_server_method: PSSL_METHOD; cdecl; external LIBSSL_DLL name 'TLS_server_method';
function SSL_CTX_new(method: PSSL_METHOD): PSSL_CTX; cdecl; external LIBSSL_DLL name 'SSL_CTX_new';
procedure SSL_CTX_free(ctx: PSSL_CTX); cdecl; external LIBSSL_DLL name 'SSL_CTX_free';

function SSL_new(ctx: PSSL_CTX): PSSL; cdecl; external LIBSSL_DLL name 'SSL_new';
procedure SSL_free(ssl: PSSL); cdecl; external LIBSSL_DLL name 'SSL_free';
procedure SSL_set_connect_state(ssl: PSSL); cdecl; external LIBSSL_DLL name 'SSL_set_connect_state';
procedure SSL_set_accept_state(ssl: PSSL); cdecl; external LIBSSL_DLL name 'SSL_set_accept_state';

function BIO_s_mem: PBIO_METHOD; cdecl; external LIBCRYPTO_DLL name 'BIO_s_mem';
function BIO_new(type_: PBIO_METHOD): PBIO; cdecl; external LIBCRYPTO_DLL name 'BIO_new';
function BIO_read(b: PBIO; out_: Pointer; len: Integer): Integer; cdecl; external LIBCRYPTO_DLL name 'BIO_read';
function BIO_write(b: PBIO; const buf: Pointer; len: Integer): Integer; cdecl; external LIBCRYPTO_DLL name 'BIO_write';
procedure SSL_set_bio(ssl: PSSL; rbio, wbio: PBIO); cdecl; external LIBSSL_DLL name 'SSL_set_bio';

function SSL_do_handshake(ssl: PSSL): Integer; cdecl; external LIBSSL_DLL name 'SSL_do_handshake';
function SSL_get_error(ssl: PSSL; ret: Integer): Integer; cdecl; external LIBSSL_DLL name 'SSL_get_error';
function SSL_read(ssl: PSSL; buf: Pointer; num: Integer): Integer; cdecl; external LIBSSL_DLL name 'SSL_read';
function SSL_write(ssl: PSSL; const buf: Pointer; num: Integer): Integer; cdecl; external LIBSSL_DLL name 'SSL_write';

const
  SSL_VERIFY_NONE = $00;
  SSL_VERIFY_PEER = $01;
  SSL_CTRL_SET_TLSEXT_HOSTNAME = 55;
  TLSEXT_NAMETYPE_host_name = 0;
  SSL_OP_NO_SSLv2 = $01000000;
  SSL_OP_NO_SSLv3 = $02000000;
  SSL_OP_NO_COMPRESSION = $00020000;
  SSL_CTRL_OPTIONS = 32;

procedure SSL_set_verify(ssl: PSSL; mode: Integer; callback: Pointer); cdecl; external LIBSSL_DLL name 'SSL_set_verify';
procedure SSL_CTX_set_verify(ctx: PSSL_CTX; mode: Integer; callback: Pointer); cdecl; external LIBSSL_DLL name 'SSL_CTX_set_verify';
function SSL_ctrl(ssl: PSSL; cmd: Integer; larg: NativeInt; parg: Pointer): NativeInt; cdecl; external LIBSSL_DLL name 'SSL_ctrl';
function SSL_CTX_ctrl(ctx: PSSL_CTX; cmd: Integer; larg: NativeInt; parg: Pointer): NativeInt; cdecl; external LIBSSL_DLL name 'SSL_CTX_ctrl';
function SSL_CTX_set_cipher_list(ctx: PSSL_CTX; const str: PAnsiChar): Integer; cdecl; external LIBSSL_DLL name 'SSL_CTX_set_cipher_list';
function SSL_CTX_set_default_verify_paths(ctx: PSSL_CTX): Integer; cdecl; external LIBSSL_DLL name 'SSL_CTX_set_default_verify_paths';
function OPENSSL_init_ssl(opts: UInt64; const settings: Pointer): Integer; cdecl; external LIBSSL_DLL name 'OPENSSL_init_ssl';

{ TDextOpenSSLTLSEngine }

constructor TDextOpenSSLTLSEngine.Create(const AOptions: TDextTLSOptions; AMode: TDextTLSMode);
begin
  inherited Create;
  FOptions := AOptions;
  FMode := AMode;
  FHandshakeCompleted := False;
  FNegotiatedALPN := '';
  InitOpenSSLEngine;
end;

procedure TDextOpenSSLTLSEngine.InitOpenSSLEngine;
var
  Method: PSSL_METHOD;
begin
  OPENSSL_init_ssl(0, nil);

  if FMode = tlsmClient then
    Method := TLS_client_method
  else
    Method := TLS_server_method;

  FSSLContext := SSL_CTX_new(Method);
  if not Assigned(FSSLContext) then
    raise EDextOpenSSLException.Create('Failed to create OpenSSL SSL_CTX');

  SSL_CTX_set_default_verify_paths(FSSLContext);
  SSL_CTX_ctrl(FSSLContext, SSL_CTRL_OPTIONS, SSL_OP_NO_SSLv2 or SSL_OP_NO_SSLv3 or SSL_OP_NO_COMPRESSION, nil);
  SSL_CTX_set_cipher_list(FSSLContext, PAnsiChar('DEFAULT:!aNULL:!eNULL:!MD5'));

  FSSL := SSL_new(FSSLContext);
  if not Assigned(FSSL) then
    raise EDextOpenSSLException.Create('Failed to create OpenSSL SSL object');

  FInputBIO := BIO_new(BIO_s_mem);
  FOutputBIO := BIO_new(BIO_s_mem);
  SSL_set_bio(FSSL, FInputBIO, FOutputBIO);

  if FOptions.VerifyServerCertificate then
  begin
    SSL_CTX_set_verify(FSSLContext, SSL_VERIFY_PEER, nil);
    SSL_set_verify(FSSL, SSL_VERIFY_PEER, nil);
  end
  else
  begin
    SSL_CTX_set_verify(FSSLContext, SSL_VERIFY_NONE, nil);
    SSL_set_verify(FSSL, SSL_VERIFY_NONE, nil);
  end;

  if FMode = tlsmClient then
  begin
    SSL_set_connect_state(FSSL);
    if FOptions.Host <> '' then
      SSL_ctrl(FSSL, SSL_CTRL_SET_TLSEXT_HOSTNAME, TLSEXT_NAMETYPE_host_name, PAnsiChar(AnsiString(FOptions.Host)));
  end
  else
    SSL_set_accept_state(FSSL);
end;

destructor TDextOpenSSLTLSEngine.Destroy;
begin
  if Assigned(FSSL) then
    SSL_free(FSSL);
  if Assigned(FSSLContext) then
    SSL_CTX_free(FSSLContext);
  inherited;
end;

function TDextOpenSSLTLSEngine.EncryptedIncoming(const ABuffer: Pointer; ACount: Integer): Integer;
begin
  if (ACount <= 0) or not Assigned(ABuffer) then Exit(0);
  Result := BIO_write(FInputBIO, ABuffer, ACount);
end;

function TDextOpenSSLTLSEngine.PlaintextRead(const ABuffer: Pointer; ACount: Integer): Integer;
begin
  if (ACount <= 0) or not Assigned(ABuffer) then Exit(0);
  Result := SSL_read(FSSL, ABuffer, ACount);
  if Result <= 0 then Result := 0;
end;

function TDextOpenSSLTLSEngine.PlaintextWrite(const ABuffer: Pointer; ACount: Integer): Integer;
begin
  if (ACount <= 0) or not Assigned(ABuffer) then Exit(0);
  Result := SSL_write(FSSL, ABuffer, ACount);
  if Result <= 0 then
    Result := ACount; // Handshake pending write buffer
end;

function TDextOpenSSLTLSEngine.EncryptedOutgoing(const ABuffer: Pointer; ACount: Integer): Integer;
begin
  if (ACount <= 0) or not Assigned(ABuffer) then Exit(0);
  Result := BIO_read(FOutputBIO, ABuffer, ACount);
  if Result < 0 then Result := 0;
end;

function TDextOpenSSLTLSEngine.DoHandshake: TDextTLSEngineStatus;
var
  Ret: Integer;
  Err: Integer;
begin
  if FHandshakeCompleted then
    Exit(tlsHandshakeCompleted);

  Ret := SSL_do_handshake(FSSL);
  if Ret = 1 then
  begin
    FHandshakeCompleted := True;
    Exit(tlsHandshakeCompleted);
  end;

  Err := SSL_get_error(FSSL, Ret);
  case Err of
    SSL_ERROR_WANT_READ: Result := tlsHandshakeNeedRead;
    SSL_ERROR_WANT_WRITE: Result := tlsHandshakeNeedWrite;
  else
    Result := tlsError;
  end;
end;

function TDextOpenSSLTLSEngine.IsHandshakeCompleted: Boolean;
begin
  Result := FHandshakeCompleted;
end;

function TDextOpenSSLTLSEngine.GetNegotiatedALPN: string;
begin
  Result := FNegotiatedALPN;
end;

{ TDextOpenSSLContextProvider }

constructor TDextOpenSSLContextProvider.Create(const AOptions: TDextTLSOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

function TDextOpenSSLContextProvider.CreateEngine(AMode: TDextTLSMode): IDextTLSEngine;
begin
  Result := TDextOpenSSLTLSEngine.Create(FOptions, AMode);
end;

function TDextOpenSSLContextProvider.GetOptions: TDextTLSOptions;
begin
  Result := FOptions;
end;

end.
