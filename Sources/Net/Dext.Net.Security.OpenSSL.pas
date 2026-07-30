{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{                                                                           }
{***************************************************************************}
unit Dext.Net.Security.OpenSSL;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Dext.Net.Security;

type
  EDextOpenSSLException = class(Exception);

  PSSL_CTX = Pointer;
  PSSL = Pointer;
  PBIO = Pointer;
  PBIO_METHOD = Pointer;
  PSSL_METHOD = Pointer;

  IDextOpenSSLContext = interface
    ['{12BE6C98-62F4-4D90-A35F-BD668145C3D7}']
    function GetHandle: PSSL_CTX;
  end;

  /// <summary>Shared immutable OpenSSL context for one TLS configuration.</summary>
  TDextOpenSSLContext = class(TInterfacedObject, IDextOpenSSLContext)
  private
    FHandle: PSSL_CTX;
    FOptions: TDextTLSOptions;
    FMode: TDextTLSMode;
    FALPNWire: TBytes;
    procedure Configure;
    function GetHandle: PSSL_CTX;
  public
    constructor Create(const AOptions: TDextTLSOptions; AMode: TDextTLSMode);
    destructor Destroy; override;
  end;

  /// <summary>Native OpenSSL TLS engine using memory BIOs.</summary>
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
    FContext: IDextOpenSSLContext;
    FLastIOStatus: TDextTLSIOStatus;
    FLastErrorCode: NativeUInt;
    procedure InitOpenSSLEngine(const AContext: IDextOpenSSLContext);
    procedure UpdateIOStatus(AReturnCode: Integer);
    procedure UpdateNegotiatedALPN;
  public
    constructor Create(const AOptions: TDextTLSOptions; AMode: TDextTLSMode); overload;
    constructor Create(const AOptions: TDextTLSOptions; AMode: TDextTLSMode;
      const AContext: IDextOpenSSLContext); overload;
    destructor Destroy; override;

    function EncryptedIncoming(const ABuffer: Pointer; ACount: Integer): Integer;
    function PlaintextRead(const ABuffer: Pointer; ACount: Integer): Integer;
    function PlaintextWrite(const ABuffer: Pointer; ACount: Integer): Integer;
    function EncryptedOutgoing(const ABuffer: Pointer; ACount: Integer): Integer;
    function DoHandshake: TDextTLSEngineStatus;
    function IsHandshakeCompleted: Boolean;
    function GetNegotiatedALPN: string;
    function GetLastIOStatus: TDextTLSIOStatus;
    function GetLastErrorCode: NativeUInt;
    function GetPendingEncryptedBytes: NativeInt;
    function Shutdown: TDextTLSIOStatus;
  end;

  /// <summary>Factory that shares SSL_CTX instances between connections.</summary>
  TDextOpenSSLContextProvider = class(TInterfacedObject, IDextTLSContextProvider)
  private
    FOptions: TDextTLSOptions;
    FClientContext: IDextOpenSSLContext;
    FServerContext: IDextOpenSSLContext;
    FLock: TCriticalSection;
  public
    constructor Create(const AOptions: TDextTLSOptions);
    destructor Destroy; override;
    function CreateEngine(AMode: TDextTLSMode): IDextTLSEngine;
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
  SSL_ERROR_ZERO_RETURN = 6;
  SSL_VERIFY_NONE = $00;
  SSL_VERIFY_PEER = $01;
  SSL_FILETYPE_PEM = 1;

  SSL_CTRL_SET_TLSEXT_HOSTNAME = 55;
  TLSEXT_NAMETYPE_host_name = 0;
  SSL_CTRL_OPTIONS = 32;
  SSL_CTRL_SET_MIN_PROTO_VERSION = 123;
  SSL_CTRL_SET_MAX_PROTO_VERSION = 124;
  SSL_OP_NO_SSLv2 = $01000000;
  SSL_OP_NO_SSLv3 = $02000000;
  SSL_OP_NO_COMPRESSION = $00020000;

  TLS1_VERSION = $0301;
  TLS1_1_VERSION = $0302;
  TLS1_2_VERSION = $0303;
  TLS1_3_VERSION = $0304;
  BIO_CTRL_PENDING = 10;

  SSL_TLSEXT_ERR_OK = 0;
  SSL_TLSEXT_ERR_NOACK = 3;
  OPENSSL_NPN_NEGOTIATED = 1;

function TLS_client_method: PSSL_METHOD; cdecl; external LIBSSL_DLL name 'TLS_client_method';
function TLS_server_method: PSSL_METHOD; cdecl; external LIBSSL_DLL name 'TLS_server_method';
function SSL_CTX_new(method: PSSL_METHOD): PSSL_CTX; cdecl; external LIBSSL_DLL name 'SSL_CTX_new';
procedure SSL_CTX_free(ctx: PSSL_CTX); cdecl; external LIBSSL_DLL name 'SSL_CTX_free';
function SSL_CTX_use_certificate_chain_file(ctx: PSSL_CTX; const filename: PAnsiChar): Integer; cdecl; external LIBSSL_DLL name 'SSL_CTX_use_certificate_chain_file';
function SSL_CTX_use_PrivateKey_file(ctx: PSSL_CTX; const filename: PAnsiChar; filetype: Integer): Integer; cdecl; external LIBSSL_DLL name 'SSL_CTX_use_PrivateKey_file';
function SSL_CTX_check_private_key(ctx: PSSL_CTX): Integer; cdecl; external LIBSSL_DLL name 'SSL_CTX_check_private_key';
function SSL_CTX_load_verify_locations(ctx: PSSL_CTX; const CAfile, CApath: PAnsiChar): Integer; cdecl; external LIBSSL_DLL name 'SSL_CTX_load_verify_locations';
function SSL_CTX_set_default_verify_paths(ctx: PSSL_CTX): Integer; cdecl; external LIBSSL_DLL name 'SSL_CTX_set_default_verify_paths';
procedure SSL_CTX_set_verify(ctx: PSSL_CTX; mode: Integer; callback: Pointer); cdecl; external LIBSSL_DLL name 'SSL_CTX_set_verify';
function SSL_CTX_set_cipher_list(ctx: PSSL_CTX; const str: PAnsiChar): Integer; cdecl; external LIBSSL_DLL name 'SSL_CTX_set_cipher_list';
procedure SSL_CTX_set_alpn_select_cb(ctx: PSSL_CTX; cb: Pointer; arg: Pointer); cdecl; external LIBSSL_DLL name 'SSL_CTX_set_alpn_select_cb';
function SSL_CTX_ctrl(ctx: PSSL_CTX; cmd: Integer; larg: NativeInt; parg: Pointer): NativeInt; cdecl; external LIBSSL_DLL name 'SSL_CTX_ctrl';

function SSL_new(ctx: PSSL_CTX): PSSL; cdecl; external LIBSSL_DLL name 'SSL_new';
procedure SSL_free(ssl: PSSL); cdecl; external LIBSSL_DLL name 'SSL_free';
procedure SSL_set_connect_state(ssl: PSSL); cdecl; external LIBSSL_DLL name 'SSL_set_connect_state';
procedure SSL_set_accept_state(ssl: PSSL); cdecl; external LIBSSL_DLL name 'SSL_set_accept_state';
procedure SSL_set_verify(ssl: PSSL; mode: Integer; callback: Pointer); cdecl; external LIBSSL_DLL name 'SSL_set_verify';
function SSL_ctrl(ssl: PSSL; cmd: Integer; larg: NativeInt; parg: Pointer): NativeInt; cdecl; external LIBSSL_DLL name 'SSL_ctrl';
function SSL_do_handshake(ssl: PSSL): Integer; cdecl; external LIBSSL_DLL name 'SSL_do_handshake';
function SSL_get_error(ssl: PSSL; ret: Integer): Integer; cdecl; external LIBSSL_DLL name 'SSL_get_error';
function SSL_read(ssl: PSSL; buf: Pointer; num: Integer): Integer; cdecl; external LIBSSL_DLL name 'SSL_read';
function SSL_write(ssl: PSSL; const buf: Pointer; num: Integer): Integer; cdecl; external LIBSSL_DLL name 'SSL_write';
function SSL_shutdown(ssl: PSSL): Integer; cdecl; external LIBSSL_DLL name 'SSL_shutdown';
function SSL_set1_host(ssl: PSSL; const hostname: PAnsiChar): Integer; cdecl; external LIBSSL_DLL name 'SSL_set1_host';
function SSL_set_alpn_protos(ssl: PSSL; const protos: PByte; protos_len: Cardinal): Integer; cdecl; external LIBSSL_DLL name 'SSL_set_alpn_protos';
procedure SSL_get0_alpn_selected(ssl: PSSL; out data: PByte; out len: Cardinal); cdecl; external LIBSSL_DLL name 'SSL_get0_alpn_selected';
function SSL_select_next_proto(out out_: PByte; out outlen: Byte;
  const server, client: PByte; server_len, client_len: Cardinal): Integer; cdecl; external LIBSSL_DLL name 'SSL_select_next_proto';

function BIO_s_mem: PBIO_METHOD; cdecl; external LIBCRYPTO_DLL name 'BIO_s_mem';
function BIO_new(type_: PBIO_METHOD): PBIO; cdecl; external LIBCRYPTO_DLL name 'BIO_new';
function BIO_read(b: PBIO; out_: Pointer; len: Integer): Integer; cdecl; external LIBCRYPTO_DLL name 'BIO_read';
function BIO_write(b: PBIO; const buf: Pointer; len: Integer): Integer; cdecl; external LIBCRYPTO_DLL name 'BIO_write';
function BIO_ctrl(bp: PBIO; cmd: Integer; larg: NativeInt; parg: Pointer): NativeInt; cdecl; external LIBCRYPTO_DLL name 'BIO_ctrl';
procedure SSL_set_bio(ssl: PSSL; rbio, wbio: PBIO); cdecl; external LIBSSL_DLL name 'SSL_set_bio';

function OPENSSL_init_ssl(opts: UInt64; const settings: Pointer): Integer; cdecl; external LIBSSL_DLL name 'OPENSSL_init_ssl';
function ERR_get_error: NativeUInt; cdecl; external LIBCRYPTO_DLL name 'ERR_get_error';
procedure ERR_error_string_n(e: NativeUInt; buf: PAnsiChar; len: NativeUInt); cdecl; external LIBCRYPTO_DLL name 'ERR_error_string_n';

function OpenSSLErrorText: string;
var
  ErrorCode: NativeUInt;
  Buffer: array[0..255] of AnsiChar;
begin
  ErrorCode := ERR_get_error;
  if ErrorCode = 0 then
    Exit('unknown OpenSSL error');
  FillChar(Buffer, SizeOf(Buffer), 0);
  ERR_error_string_n(ErrorCode, @Buffer[0], SizeOf(Buffer));
  Result := string(AnsiString(PAnsiChar(@Buffer[0])));
end;

function TLSVersionNumber(AVersion: TDextTLSVersion): NativeInt;
begin
  case AVersion of
    tls1_0: Result := TLS1_VERSION;
    tls1_1: Result := TLS1_1_VERSION;
    tls1_2: Result := TLS1_2_VERSION;
    tls1_3: Result := TLS1_3_VERSION;
  else
    Result := TLS1_2_VERSION;
  end;
end;

function BuildALPNWire(const AProtocols: TArray<string>): TBytes;
var
  ProtocolName: string;
  ProtocolBytes: TBytes;
  Offset: Integer;
begin
  Result := nil;
  Offset := 0;
  for ProtocolName in AProtocols do
  begin
    ProtocolBytes := TEncoding.ASCII.GetBytes(ProtocolName);
    if (Length(ProtocolBytes) = 0) or (Length(ProtocolBytes) > 255) then
      raise EDextOpenSSLException.CreateFmt(
        'Invalid ALPN protocol length: %s', [ProtocolName]);
    SetLength(Result, Offset + 1 + Length(ProtocolBytes));
    Result[Offset] := Byte(Length(ProtocolBytes));
    Move(ProtocolBytes[0], Result[Offset + 1], Length(ProtocolBytes));
    Inc(Offset, 1 + Length(ProtocolBytes));
  end;
end;

function SelectALPN(ssl: PSSL; out out_: PByte; out outlen: Byte;
  const in_: PByte; inlen: Cardinal; arg: Pointer): Integer; cdecl;
var
  Context: TDextOpenSSLContext;
begin
  Context := TDextOpenSSLContext(arg);
  if (Context = nil) or (Length(Context.FALPNWire) = 0) then
    Exit(SSL_TLSEXT_ERR_NOACK);
  if SSL_select_next_proto(out_, outlen, @Context.FALPNWire[0], in_,
    Length(Context.FALPNWire), inlen) = OPENSSL_NPN_NEGOTIATED then
    Result := SSL_TLSEXT_ERR_OK
  else
    Result := SSL_TLSEXT_ERR_NOACK;
end;

{ TDextOpenSSLContext }

constructor TDextOpenSSLContext.Create(const AOptions: TDextTLSOptions;
  AMode: TDextTLSMode);
var
  Method: PSSL_METHOD;
begin
  inherited Create;
  FOptions := AOptions;
  FMode := AMode;
  if OPENSSL_init_ssl(0, nil) <> 1 then
    raise EDextOpenSSLException.Create('Failed to initialize OpenSSL');
  if AMode = tlsmClient then
    Method := TLS_client_method
  else
    Method := TLS_server_method;
  FHandle := SSL_CTX_new(Method);
  if FHandle = nil then
    raise EDextOpenSSLException.Create(
      'Failed to create OpenSSL SSL_CTX: ' + OpenSSLErrorText);
  try
    Configure;
  except
    SSL_CTX_free(FHandle);
    FHandle := nil;
    raise;
  end;
end;

destructor TDextOpenSSLContext.Destroy;
begin
  if FHandle <> nil then
    SSL_CTX_free(FHandle);
  inherited;
end;

function TDextOpenSSLContext.GetHandle: PSSL_CTX;
begin
  Result := FHandle;
end;

procedure TDextOpenSSLContext.Configure;
var
  MinVersion: TDextTLSVersion;
  MaxVersion: TDextTLSVersion;
  Version: TDextTLSVersion;
  HasVersion: Boolean;
  CertName: AnsiString;
  KeyName: AnsiString;
  RootName: AnsiString;
begin
  SSL_CTX_ctrl(FHandle, SSL_CTRL_OPTIONS,
    SSL_OP_NO_SSLv2 or SSL_OP_NO_SSLv3 or SSL_OP_NO_COMPRESSION, nil);
  if SSL_CTX_set_cipher_list(FHandle,
    PAnsiChar(AnsiString('DEFAULT:!aNULL:!eNULL:!MD5'))) <> 1 then
    raise EDextOpenSSLException.Create(
      'Failed to configure cipher list: ' + OpenSSLErrorText);

  HasVersion := False;
  MinVersion := High(TDextTLSVersion);
  MaxVersion := Low(TDextTLSVersion);
  for Version := Low(TDextTLSVersion) to High(TDextTLSVersion) do
    if Version in FOptions.Protocols then
    begin
      if not HasVersion or (Ord(Version) < Ord(MinVersion)) then
        MinVersion := Version;
      if not HasVersion or (Ord(Version) > Ord(MaxVersion)) then
        MaxVersion := Version;
      HasVersion := True;
    end;
  if not HasVersion then
    raise EDextOpenSSLException.Create(
      'At least one TLS protocol version must be enabled');
  if SSL_CTX_ctrl(FHandle, SSL_CTRL_SET_MIN_PROTO_VERSION,
    TLSVersionNumber(MinVersion), nil) <> 1 then
    raise EDextOpenSSLException.Create(
      'Failed to set minimum TLS version: ' + OpenSSLErrorText);
  if SSL_CTX_ctrl(FHandle, SSL_CTRL_SET_MAX_PROTO_VERSION,
    TLSVersionNumber(MaxVersion), nil) <> 1 then
    raise EDextOpenSSLException.Create(
      'Failed to set maximum TLS version: ' + OpenSSLErrorText);

  if FOptions.RootCertFile <> '' then
  begin
    RootName := AnsiString(FOptions.RootCertFile);
    if SSL_CTX_load_verify_locations(
      FHandle, PAnsiChar(RootName), nil) <> 1 then
      raise EDextOpenSSLException.Create(
        'Failed to load root certificate: ' + OpenSSLErrorText);
  end
  else if SSL_CTX_set_default_verify_paths(FHandle) <> 1 then
    raise EDextOpenSSLException.Create(
      'Failed to load default trust store: ' + OpenSSLErrorText);

  if FMode = tlsmServer then
  begin
    if (FOptions.CertFile = '') or (FOptions.KeyFile = '') then
      raise EDextOpenSSLException.Create(
        'Server TLS requires CertFile and KeyFile');
    CertName := AnsiString(FOptions.CertFile);
    KeyName := AnsiString(FOptions.KeyFile);
    if SSL_CTX_use_certificate_chain_file(
      FHandle, PAnsiChar(CertName)) <> 1 then
      raise EDextOpenSSLException.Create(
        'Failed to load server certificate: ' + OpenSSLErrorText);
    if SSL_CTX_use_PrivateKey_file(
      FHandle, PAnsiChar(KeyName), SSL_FILETYPE_PEM) <> 1 then
      raise EDextOpenSSLException.Create(
        'Failed to load server private key: ' + OpenSSLErrorText);
    if SSL_CTX_check_private_key(FHandle) <> 1 then
      raise EDextOpenSSLException.Create(
        'Server certificate and private key do not match: ' +
        OpenSSLErrorText);
  end;

  if FOptions.VerifyServerCertificate then
    SSL_CTX_set_verify(FHandle, SSL_VERIFY_PEER, nil)
  else
    SSL_CTX_set_verify(FHandle, SSL_VERIFY_NONE, nil);

  FALPNWire := BuildALPNWire(FOptions.ALPNProtocols);
  if (FMode = tlsmServer) and (Length(FALPNWire) > 0) then
    SSL_CTX_set_alpn_select_cb(FHandle, @SelectALPN, Self);
end;

{ TDextOpenSSLTLSEngine }

constructor TDextOpenSSLTLSEngine.Create(const AOptions: TDextTLSOptions;
  AMode: TDextTLSMode);
begin
  inherited Create;
  FOptions := AOptions;
  FMode := AMode;
  FHandshakeCompleted := False;
  FNegotiatedALPN := '';
  FLastIOStatus := tlsIOOk;
  FLastErrorCode := 0;
  InitOpenSSLEngine(TDextOpenSSLContext.Create(AOptions, AMode));
end;

constructor TDextOpenSSLTLSEngine.Create(const AOptions: TDextTLSOptions;
  AMode: TDextTLSMode; const AContext: IDextOpenSSLContext);
begin
  inherited Create;
  FOptions := AOptions;
  FMode := AMode;
  FHandshakeCompleted := False;
  FNegotiatedALPN := '';
  FLastIOStatus := tlsIOOk;
  FLastErrorCode := 0;
  InitOpenSSLEngine(AContext);
end;

procedure TDextOpenSSLTLSEngine.InitOpenSSLEngine(
  const AContext: IDextOpenSSLContext);
var
  ALPNWire: TBytes;
  HostName: AnsiString;
begin
  FContext := AContext;
  if FContext = nil then
    raise EDextOpenSSLException.Create('OpenSSL context is required');
  FSSLContext := FContext.GetHandle;
  FSSL := SSL_new(FSSLContext);
  if FSSL = nil then
    raise EDextOpenSSLException.Create(
      'Failed to create OpenSSL SSL object: ' + OpenSSLErrorText);

  FInputBIO := BIO_new(BIO_s_mem);
  FOutputBIO := BIO_new(BIO_s_mem);
  if (FInputBIO = nil) or (FOutputBIO = nil) then
  begin
    SSL_free(FSSL);
    FSSL := nil;
    raise EDextOpenSSLException.Create(
      'Failed to create OpenSSL memory BIOs: ' + OpenSSLErrorText);
  end;
  SSL_set_bio(FSSL, FInputBIO, FOutputBIO);

  if FOptions.VerifyServerCertificate then
    SSL_set_verify(FSSL, SSL_VERIFY_PEER, nil)
  else
    SSL_set_verify(FSSL, SSL_VERIFY_NONE, nil);

  if FMode = tlsmClient then
  begin
    SSL_set_connect_state(FSSL);
    if FOptions.Host <> '' then
    begin
      HostName := AnsiString(FOptions.Host);
      SSL_ctrl(FSSL, SSL_CTRL_SET_TLSEXT_HOSTNAME,
        TLSEXT_NAMETYPE_host_name, PAnsiChar(HostName));
      if FOptions.VerifyServerCertificate and
         (SSL_set1_host(FSSL, PAnsiChar(HostName)) <> 1) then
        raise EDextOpenSSLException.Create(
          'Failed to configure hostname verification: ' +
          OpenSSLErrorText);
    end;
    ALPNWire := BuildALPNWire(FOptions.ALPNProtocols);
    if (Length(ALPNWire) > 0) and
       (SSL_set_alpn_protos(FSSL, @ALPNWire[0],
        Length(ALPNWire)) <> 0) then
      raise EDextOpenSSLException.Create(
        'Failed to configure client ALPN: ' + OpenSSLErrorText);
  end
  else
    SSL_set_accept_state(FSSL);
end;

destructor TDextOpenSSLTLSEngine.Destroy;
begin
  if FSSL <> nil then
    SSL_free(FSSL);
  FSSL := nil;
  FInputBIO := nil;
  FOutputBIO := nil;
  FSSLContext := nil;
  FContext := nil;
  inherited;
end;

function TDextOpenSSLTLSEngine.EncryptedIncoming(
  const ABuffer: Pointer; ACount: Integer): Integer;
begin
  if (ACount <= 0) or (ABuffer = nil) then
    Exit(0);
  Result := BIO_write(FInputBIO, ABuffer, ACount);
  if Result > 0 then
    FLastIOStatus := tlsIOOk
  else
    FLastIOStatus := tlsIOError;
end;

procedure TDextOpenSSLTLSEngine.UpdateIOStatus(AReturnCode: Integer);
var
  ErrorKind: Integer;
begin
  ErrorKind := SSL_get_error(FSSL, AReturnCode);
  case ErrorKind of
    SSL_ERROR_NONE: FLastIOStatus := tlsIOOk;
    SSL_ERROR_WANT_READ: FLastIOStatus := tlsIONeedRead;
    SSL_ERROR_WANT_WRITE: FLastIOStatus := tlsIONeedWrite;
    SSL_ERROR_ZERO_RETURN: FLastIOStatus := tlsIOClosed;
  else
    begin
      FLastIOStatus := tlsIOError;
      FLastErrorCode := ERR_get_error;
    end;
  end;
end;

function TDextOpenSSLTLSEngine.PlaintextRead(
  const ABuffer: Pointer; ACount: Integer): Integer;
begin
  if (ACount <= 0) or (ABuffer = nil) then
    Exit(0);
  Result := SSL_read(FSSL, ABuffer, ACount);
  if Result > 0 then
    FLastIOStatus := tlsIOOk
  else
  begin
    UpdateIOStatus(Result);
    Result := 0;
  end;
end;

function TDextOpenSSLTLSEngine.PlaintextWrite(
  const ABuffer: Pointer; ACount: Integer): Integer;
begin
  if (ACount <= 0) or (ABuffer = nil) then
    Exit(0);
  Result := SSL_write(FSSL, ABuffer, ACount);
  if Result > 0 then
    FLastIOStatus := tlsIOOk
  else
  begin
    UpdateIOStatus(Result);
    Result := 0;
  end;
end;

function TDextOpenSSLTLSEngine.EncryptedOutgoing(
  const ABuffer: Pointer; ACount: Integer): Integer;
begin
  if (ACount <= 0) or (ABuffer = nil) then
    Exit(0);
  Result := BIO_read(FOutputBIO, ABuffer, ACount);
  if Result < 0 then
    Result := 0;
end;

procedure TDextOpenSSLTLSEngine.UpdateNegotiatedALPN;
var
  Data: PByte;
  DataLen: Cardinal;
  ProtocolBytes: TBytes;
begin
  Data := nil;
  DataLen := 0;
  SSL_get0_alpn_selected(FSSL, Data, DataLen);
  if (Data = nil) or (DataLen = 0) then
  begin
    FNegotiatedALPN := '';
    Exit;
  end;
  SetLength(ProtocolBytes, DataLen);
  Move(Data^, ProtocolBytes[0], DataLen);
  FNegotiatedALPN := TEncoding.ASCII.GetString(ProtocolBytes);
end;

function TDextOpenSSLTLSEngine.DoHandshake: TDextTLSEngineStatus;
var
  Ret: Integer;
begin
  if FHandshakeCompleted then
    Exit(tlsHandshakeCompleted);
  Ret := SSL_do_handshake(FSSL);
  if Ret = 1 then
  begin
    FHandshakeCompleted := True;
    FLastIOStatus := tlsIOOk;
    UpdateNegotiatedALPN;
    Exit(tlsHandshakeCompleted);
  end;
  UpdateIOStatus(Ret);
  case FLastIOStatus of
    tlsIONeedRead: Result := tlsHandshakeNeedRead;
    tlsIONeedWrite: Result := tlsHandshakeNeedWrite;
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

function TDextOpenSSLTLSEngine.GetLastIOStatus: TDextTLSIOStatus;
begin
  Result := FLastIOStatus;
end;

function TDextOpenSSLTLSEngine.GetLastErrorCode: NativeUInt;
begin
  Result := FLastErrorCode;
end;

function TDextOpenSSLTLSEngine.GetPendingEncryptedBytes: NativeInt;
begin
  Result := BIO_ctrl(FOutputBIO, BIO_CTRL_PENDING, 0, nil);
end;

function TDextOpenSSLTLSEngine.Shutdown: TDextTLSIOStatus;
var
  Ret: Integer;
begin
  Ret := SSL_shutdown(FSSL);
  if Ret = 1 then
    FLastIOStatus := tlsIOClosed
  else if Ret = 0 then
    FLastIOStatus := tlsIONeedRead
  else
    UpdateIOStatus(Ret);
  Result := FLastIOStatus;
end;

{ TDextOpenSSLContextProvider }

constructor TDextOpenSSLContextProvider.Create(
  const AOptions: TDextTLSOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FLock := TCriticalSection.Create;
end;

destructor TDextOpenSSLContextProvider.Destroy;
begin
  FClientContext := nil;
  FServerContext := nil;
  FLock.Free;
  inherited;
end;

function TDextOpenSSLContextProvider.CreateEngine(
  AMode: TDextTLSMode): IDextTLSEngine;
begin
  FLock.Enter;
  try
    if AMode = tlsmClient then
    begin
      if FClientContext = nil then
        FClientContext := TDextOpenSSLContext.Create(
          FOptions, tlsmClient);
      Result := TDextOpenSSLTLSEngine.Create(
        FOptions, AMode, FClientContext);
    end
    else
    begin
      if FServerContext = nil then
        FServerContext := TDextOpenSSLContext.Create(
          FOptions, tlsmServer);
      Result := TDextOpenSSLTLSEngine.Create(
        FOptions, AMode, FServerContext);
    end;
  finally
    FLock.Leave;
  end;
end;

function TDextOpenSSLContextProvider.GetOptions: TDextTLSOptions;
begin
  Result := FOptions;
end;

end.
