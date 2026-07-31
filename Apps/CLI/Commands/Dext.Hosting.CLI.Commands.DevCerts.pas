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
{  Created: 2026-07-23                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Hosting.CLI.Commands.DevCerts;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.NetEncoding,
  Winapi.Windows,
  Winapi.ShellAPI,
  Dext.Hosting.CLI.Args,
  Dext.Utils;

type
  PCCERT_CONTEXT = Pointer;
  HCERTSTORE = THandle;
  HCRYPTPROV_OR_NCRYPT_KEY_HANDLE = ULONG_PTR;
  HCRYPTPROV = ULONG_PTR;
  PHCRYPTPROV = ^HCRYPTPROV;
  HCRYPTKEY = ULONG_PTR;
  PHCRYPTKEY = ^HCRYPTKEY;

  CRYPT_ALGORITHM_IDENTIFIER = record
    pszObjId: PAnsiChar;
    Parameters: record
      cbData: DWORD;
      pbData: PByte;
    end;
  end;
  PCRYPT_ALGORITHM_IDENTIFIER = ^CRYPT_ALGORITHM_IDENTIFIER;

  CRYPT_OBJID_BLOB = record
    cbData: DWORD;
    pbData: PByte;
  end;

  CERT_NAME_BLOB = CRYPT_OBJID_BLOB;
  PCERT_NAME_BLOB = ^CERT_NAME_BLOB;

  SYSTEMTIME = record
    wYear: WORD;
    wMonth: WORD;
    wDayOfWeek: WORD;
    wDay: WORD;
    wHour: WORD;
    wMinute: WORD;
    wSecond: WORD;
    wMilliseconds: WORD;
  end;
  PSYSTEMTIME = ^SYSTEMTIME;

  CERT_PUBLIC_KEY_INFO = record
    Algorithm: CRYPT_ALGORITHM_IDENTIFIER;
    PublicKey: record
      cbData: DWORD;
      pbData: PByte;
      cUnusedBits: DWORD;
    end;
  end;

  CERT_INFO = record
    dwVersion: DWORD;
    SerialNumber: CRYPT_OBJID_BLOB;
    SignatureAlgorithm: CRYPT_ALGORITHM_IDENTIFIER;
    Issuer: CERT_NAME_BLOB;
    NotBefore: FILETIME;
    NotAfter: FILETIME;
    Subject: CERT_NAME_BLOB;
    SubjectPublicKeyInfo: CERT_PUBLIC_KEY_INFO;
    IssuerUniqueId: record
      cbData: DWORD;
      pbData: PByte;
      cUnusedBits: DWORD;
    end;
    SubjectUniqueId: record
      cbData: DWORD;
      pbData: PByte;
      cUnusedBits: DWORD;
    end;
    cExtension: DWORD;
    rgExtension: Pointer;
  end;
  PCERT_INFO = ^CERT_INFO;

  CRYPT_KEY_PROV_INFO = record
    pwszContainerName: LPCWSTR;
    pwszProvName: LPCWSTR;
    dwProvType: DWORD;
    dwFlags: DWORD;
    cProvParam: DWORD;
    rgProvParam: Pointer;
    dwKeySpec: DWORD;
  end;

  CERT_CONTEXT = record
    dwCertEncodingType: DWORD;
    pbCertEncoded: PByte;
    cbCertEncoded: DWORD;
    pCertInfo: PCERT_INFO;
    hCertStore: HCERTSTORE;
  end;
  PCERT_CONTEXT = ^CERT_CONTEXT;

  CERT_EXTENSION = record
    pszObjId: PAnsiChar;
    fCritical: BOOL;
    Value: CRYPT_OBJID_BLOB;
  end;
  PCERT_EXTENSION = ^CERT_EXTENSION;

  CERT_EXTENSIONS = record
    cExtension: DWORD;
    rgExtension: PCERT_EXTENSION;
  end;
  PCERT_EXTENSIONS = ^CERT_EXTENSIONS;

  CERT_ALT_NAME_ENTRY = record
    dwAltNameChoice: DWORD;
    case Integer of
      0: (pwszDNSName: PWideChar);
      1: (pwszURL: PWideChar);
  end;
  PCERT_ALT_NAME_ENTRY = ^CERT_ALT_NAME_ENTRY;

  CERT_ALT_NAME_INFO = record
    cAltEntry: DWORD;
    rgAltEntry: PCERT_ALT_NAME_ENTRY;
  end;
  PCERT_ALT_NAME_INFO = ^CERT_ALT_NAME_INFO;

  TDevCertsCommand = class(TInterfacedObject, IConsoleCommand)
  private
    procedure ShowUsage;
    procedure RunElevatedAndWait(const Executable, Parameters: string);
    function GenerateSelfSignedCert(const CertFilePath: string;
      TrustInRoot: Boolean; const BindingMode, BindingIp: string;
      BindingPort: Word; const BindingStore, BindingAppId: string): Boolean;
    function EncodeAsn1Length(Len: Integer): TBytes;
    function EncodeAsn1Sequence(const Content: TBytes): TBytes;
    function EncodeAsn1Integer(const Value: TBytes): TBytes;
    function BuildRSAPrivateKeyPKCS1(const KeyBlob: TBytes): TBytes;
  public
    function GetName: string;
    function GetDescription: string;
    procedure Execute(const Args: TCommandLineArgs);
  end;

const
  PKCS_7_ASN_ENCODING = $00010000;
  X509_ASN_ENCODING   = $00000001;
  MY_ENCODING_TYPE    = PKCS_7_ASN_ENCODING or X509_ASN_ENCODING;
  CERT_FRIENDLY_NAME_PROP_ID = 1;
  szOID_SUBJECT_ALT_NAME2 = '2.5.29.17';
  CERT_ALT_NAME_DNS_NAME = 3;
  X509_ALTERNATE_NAME = PAnsiChar(12);

function CryptEncodeObjectEx(dwCertEncodingType: DWORD; lpszStructType: PAnsiChar; pvStructInfo: Pointer; dwFlags: DWORD; pEncodePara: Pointer; pvEncoded: Pointer; pcbEncoded: PDWORD): BOOL; stdcall; external 'crypt32.dll' name 'CryptEncodeObjectEx';
function CertStrToNameA(dwCertEncodingType: DWORD; pszX500: PAnsiChar; dwStrType: DWORD; pvReserved: Pointer; pbEncoded: PByte; pcbEncoded: PDWORD; ppszError: PPAnsiChar): BOOL; stdcall; external 'crypt32.dll' name 'CertStrToNameA';
function CertCreateSelfSignCertificate(hCryptProvOrNCryptKey: HCRYPTPROV_OR_NCRYPT_KEY_HANDLE; pSubjectIssuerBlob: PCERT_NAME_BLOB; dwFlags: DWORD; pKeyProviderInfo: Pointer; pSignatureAlgorithm: PCRYPT_ALGORITHM_IDENTIFIER; pStartTime: PSYSTEMTIME; pEndTime: PSYSTEMTIME; pExtensions: Pointer): PCCERT_CONTEXT; stdcall; external 'crypt32.dll' name 'CertCreateSelfSignCertificate';
function CertSetCertificateContextProperty(pCertContext: PCCERT_CONTEXT; dwPropId: DWORD; dwFlags: DWORD; pvData: Pointer): BOOL; stdcall; external 'crypt32.dll' name 'CertSetCertificateContextProperty';
function CertGetCertificateContextProperty(pCertContext: PCCERT_CONTEXT; dwPropId: DWORD; pvData: Pointer; pcbData: PDWORD): BOOL; stdcall; external 'crypt32.dll' name 'CertGetCertificateContextProperty';
function CertFreeCertificateContext(pCertContext: PCCERT_CONTEXT): BOOL; stdcall; external 'crypt32.dll' name 'CertFreeCertificateContext';
function CertOpenStore(lpszStoreProvider: PAnsiChar; dwMsgAndCertEncodingType: DWORD; hCryptProv: ULONG_PTR; dwFlags: DWORD; pvPara: Pointer): HCERTSTORE; stdcall; external 'crypt32.dll' name 'CertOpenStore';
function CertAddCertificateContextToStore(hCertStore: HCERTSTORE; pCertContext: PCCERT_CONTEXT; dwAddDisposition: DWORD; ppStoreContext: Pointer): BOOL; stdcall; external 'crypt32.dll' name 'CertAddCertificateContextToStore';
function CertCloseStore(hCertStore: HCERTSTORE; dwFlags: DWORD): BOOL; stdcall; external 'crypt32.dll' name 'CertCloseStore';
function PFXExportCertStoreEx(hStore: HCERTSTORE; pPFX: PCERT_NAME_BLOB; szPassword: PWideChar; pvReserved: Pointer; dwFlags: DWORD): BOOL; stdcall; external 'crypt32.dll' name 'PFXExportCertStoreEx';

function CryptAcquireContextA(phProv: PHCRYPTPROV; pszContainer: PAnsiChar; pszProvider: PAnsiChar; dwProvType: DWORD; dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll' name 'CryptAcquireContextA';
function CryptGenKey(hProv: HCRYPTPROV; Algid: DWORD; dwFlags: DWORD; phKey: PHCRYPTKEY): BOOL; stdcall; external 'advapi32.dll' name 'CryptGenKey';
function CryptExportKey(hKey: HCRYPTKEY; hExpKey: HCRYPTKEY; dwBlobType: DWORD; dwFlags: DWORD; pbData: PByte; pdwDataLen: PDWORD): BOOL; stdcall; external 'advapi32.dll' name 'CryptExportKey';
function CryptDestroyKey(hKey: HCRYPTKEY): BOOL; stdcall; external 'advapi32.dll' name 'CryptDestroyKey';
function CryptReleaseContext(hProv: HCRYPTPROV; dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll' name 'CryptReleaseContext';

implementation

{ ASN.1 ASN1 Structures formatting for OpenSSL/PKCS#1 }

function TDevCertsCommand.EncodeAsn1Length(Len: Integer): TBytes;
begin
  if Len < 128 then
  begin
    SetLength(Result, 1);
    Result[0] := Byte(Len);
  end
  else if Len <= 255 then
  begin
    SetLength(Result, 2);
    Result[0] := $81;
    Result[1] := Byte(Len);
  end
  else
  begin
    SetLength(Result, 3);
    Result[0] := $82;
    Result[1] := Byte(Len shr 8);
    Result[2] := Byte(Len and $FF);
  end;
end;

function BuildSanExtensionAsn1: TBytes;
var
  Dns1, Dns2, Entries: TBytes;
  StrBytes1, StrBytes2: TBytes;
begin
  // DNS:localhost -> context tag 0x82
  StrBytes1 := TEncoding.ASCII.GetBytes('localhost');
  SetLength(Dns1, 2 + Length(StrBytes1));
  Dns1[0] := $82;
  Dns1[1] := Byte(Length(StrBytes1));
  Move(StrBytes1[0], Dns1[2], Length(StrBytes1));

  // DNS:127.0.0.1 -> context tag 0x82
  StrBytes2 := TEncoding.ASCII.GetBytes('127.0.0.1');
  SetLength(Dns2, 2 + Length(StrBytes2));
  Dns2[0] := $82;
  Dns2[1] := Byte(Length(StrBytes2));
  Move(StrBytes2[0], Dns2[2], Length(StrBytes2));

  Entries := Concat(Dns1, Dns2);
  
  // Tag SEQUENCE 0x30
  SetLength(Result, 2 + Length(Entries));
  Result[0] := $30;
  Result[1] := Byte(Length(Entries));
  Move(Entries[0], Result[2], Length(Entries));
end;

function TDevCertsCommand.EncodeAsn1Sequence(const Content: TBytes): TBytes;
var
  LenBytes: TBytes;
begin
  LenBytes := EncodeAsn1Length(Length(Content));
  SetLength(Result, 1 + Length(LenBytes) + Length(Content));
  Result[0] := $30; { SEQUENCE tag }
  Move(LenBytes[0], Result[1], Length(LenBytes));
  Move(Content[0], Result[1 + Length(LenBytes)], Length(Content));
end;

function TDevCertsCommand.EncodeAsn1Integer(const Value: TBytes): TBytes;
var
  LenBytes: TBytes;
  Pad: Integer;
  TotalLen: Integer;
begin
  Pad := 0;
  if (Length(Value) > 0) and ((Value[0] and $80) <> 0) then
    Pad := 1;

  TotalLen := Length(Value) + Pad;
  LenBytes := EncodeAsn1Length(TotalLen);

  SetLength(Result, 1 + Length(LenBytes) + TotalLen);
  Result[0] := $02; { INTEGER tag }
  Move(LenBytes[0], Result[1], Length(LenBytes));
  if Pad = 1 then
    Result[1 + Length(LenBytes)] := 0;
  Move(Value[0], Result[1 + Length(LenBytes) + Pad], Length(Value));
end;

function ReverseBytes(const B: TBytes): TBytes;
var
  I, L: Integer;
begin
  L := Length(B);
  SetLength(Result, L);
  for I := 0 to L - 1 do
    Result[I] := B[L - 1 - I];
end;

function TDevCertsCommand.BuildRSAPrivateKeyPKCS1(const KeyBlob: TBytes): TBytes;
type
  BLOBHEADER = record
    bType: BYTE;
    bVersion: BYTE;
    reserved: WORD;
    aiKeyAlg: DWORD;
  end;
  RSAPUBKEY = record
    magic: DWORD;
    bitlen: DWORD;
    pubexp: DWORD;
  end;
var
  Header: BLOBHEADER;
  RsaPubKeyStruct: RSAPUBKEY;
  BitLen: Integer;
  ByteLen: Integer;
  HalfLen: Integer;
  Offset: Integer;

  Modulus, PublicExponent, PrivateExponent, Prime1, Prime2, Exponent1, Exponent2, Coefficient: TBytes;
  VersionInt: TBytes;
  AsnContent: TBytes;

  function SubBytes(StartIdx, Count: Integer): TBytes;
  begin
    if (StartIdx < 0) or (StartIdx + Count > Length(KeyBlob)) then
    begin
      SetLength(Result, 0);
      Exit;
    end;
    SetLength(Result, Count);
    Move(KeyBlob[StartIdx], Result[0], Count);
    Result := ReverseBytes(Result);
  end;

begin
  Move(KeyBlob[0], Header, SizeOf(BLOBHEADER));
  Move(KeyBlob[SizeOf(BLOBHEADER)], RsaPubKeyStruct, SizeOf(RSAPUBKEY));

  BitLen := RsaPubKeyStruct.bitlen;
  ByteLen := BitLen div 8;
  HalfLen := ByteLen div 2;

  Offset := SizeOf(BLOBHEADER) + SizeOf(RSAPUBKEY);

  Modulus := SubBytes(Offset, ByteLen); Inc(Offset, ByteLen);
  Prime1 := SubBytes(Offset, HalfLen); Inc(Offset, HalfLen);
  Prime2 := SubBytes(Offset, HalfLen); Inc(Offset, HalfLen);
  Exponent1 := SubBytes(Offset, HalfLen); Inc(Offset, HalfLen);
  Exponent2 := SubBytes(Offset, HalfLen); Inc(Offset, HalfLen);
  Coefficient := SubBytes(Offset, HalfLen); Inc(Offset, HalfLen);
  PrivateExponent := SubBytes(Offset, ByteLen);

  SetLength(PublicExponent, 3);
  PublicExponent[0] := $01;
  PublicExponent[1] := $00;
  PublicExponent[2] := $01;

  SetLength(VersionInt, 1);
  VersionInt[0] := 0;

  AsnContent := Concat(
    EncodeAsn1Integer(VersionInt),
    EncodeAsn1Integer(Modulus),
    EncodeAsn1Integer(PublicExponent),
    EncodeAsn1Integer(PrivateExponent),
    EncodeAsn1Integer(Prime1),
    EncodeAsn1Integer(Prime2),
    EncodeAsn1Integer(Exponent1),
    EncodeAsn1Integer(Exponent2),
    EncodeAsn1Integer(Coefficient)
  );

  Result := EncodeAsn1Sequence(AsnContent);
end;

{ TDevCertsCommand Implementation }

function TDevCertsCommand.GetName: string;
begin
  Result := 'dev-certs';
end;

function TDevCertsCommand.GetDescription: string;
begin
  Result := 'Generates and manages local development SSL certificates (like dotnet dev-certs).';
end;

procedure TDevCertsCommand.RunElevatedAndWait(const Executable,
  Parameters: string);
var
  Info: TShellExecuteInfo;
  ExitCode: DWORD;
begin
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  Info.fMask := SEE_MASK_NOCLOSEPROCESS;
  Info.Wnd := 0;
  Info.lpVerb := 'runas';
  Info.lpFile := PChar(Executable);
  Info.lpParameters := PChar(Parameters);
  Info.nShow := SW_HIDE;
  if not ShellExecuteEx(@Info) then
    RaiseLastOSError;
  try
    WaitForSingleObject(Info.hProcess, INFINITE);
    if not GetExitCodeProcess(Info.hProcess, ExitCode) then
      RaiseLastOSError;
    if ExitCode <> 0 then
      raise EOSError.CreateFmt('%s failed with exit code %d',
        [Executable, ExitCode]);
  finally
    CloseHandle(Info.hProcess);
  end;
end;

procedure TDevCertsCommand.ShowUsage;
begin
  SafeWriteLn('Usage:');
  SafeWriteLn('  dext dev-certs https [--trust] [--out-cert <path>]');
  SafeWriteLn('      [--bind|--update-binding|--remove-binding]');
  SafeWriteLn('      [--ip <address>] [--port <port>] [--store <name>] [--appid <guid>]');
  SafeWriteLn('');
  SafeWriteLn('Options:');
  SafeWriteLn('  https         Generate self-signed development certificate for localhost.');
  SafeWriteLn('  --trust       Install and trust the certificate in Windows Root Store (Requires Admin).');
  SafeWriteLn('  --out-cert    Output certificate path (default: server.crt).');
  SafeWriteLn('  --bind        Create an http.sys binding; fails if it already exists.');
  SafeWriteLn('  --update-binding  Replace an existing http.sys binding.');
  SafeWriteLn('  --remove-binding  Remove the selected binding without generating a certificate.');
  SafeWriteLn('  --ip          Binding IPv4 address (default: 0.0.0.0).');
  SafeWriteLn('  --port        Binding TCP port (default: 8080).');
  SafeWriteLn('  --store       Windows certificate store (default: MY).');
  SafeWriteLn('  --appid       Binding owner GUID.');
end;

function TDevCertsCommand.GenerateSelfSignedCert(const CertFilePath: string;
  TrustInRoot: Boolean; const BindingMode, BindingIp: string;
  BindingPort: Word; const BindingStore, BindingAppId: string): Boolean;
var
  SubjectName: string;
  SubjectBlob: CERT_NAME_BLOB;
  CertContext: PCERT_CONTEXT;
  EncodedName: TBytes;
  EncodedNameLen: DWORD;
  FriendlyName: string;
  FriendlyNameBlob: CRYPT_OBJID_BLOB;
  KeyFilePath: string;
  Base64Cert: string;
  PemCertContent: string;
  PemKeyContent: string;
  hProv: HCRYPTPROV;
  hKey: HCRYPTKEY;
  KeyBlob: TBytes;
  KeyBlobLen: DWORD;
  Base64Key: string;
  Pkcs1Bytes: TBytes;
  KeyProvInfo: CRYPT_KEY_PROV_INFO;
  EncodedSanBytes: TBytes;
  SanExt: CERT_EXTENSION;
  CertExtStruct: CERT_EXTENSIONS;
  PfxFilePath: string;
  hMemStore: HCERTSTORE;
  PfxBlob: CRYPT_OBJID_BLOB;
  PfxBytes: TBytes;
  SigAlg: CRYPT_ALGORITHM_IDENTIFIER;
  HashBytes: array[0..19] of Byte;
  HashLen: DWORD;
  ThumbprintStr: string;
  I: Integer;
begin
  Result := False;
  KeyFilePath := ChangeFileExt(CertFilePath, '.key');
  SubjectName := 'CN=localhost';

  // 1. Criar container de chaves criptográficas RSA 2048-bit 100% nativo no Windows CryptoAPI (PROV_RSA_AES para suporte a SHA-256)
  hProv := 0;
  hKey := 0;
  CryptAcquireContextA(@hProv, PAnsiChar('DextDevKeyContainer'), PAnsiChar('Microsoft Enhanced RSA and AES Cryptographic Provider'), 24 {PROV_RSA_AES}, 8 {CRYPT_NEWKEYSET});
  if hProv = 0 then
    CryptAcquireContextA(@hProv, PAnsiChar('DextDevKeyContainer'), nil, 24 {PROV_RSA_AES}, 0);

  if hProv <> 0 then
  begin
    CryptGenKey(hProv, 1 {AT_KEYEXCHANGE}, $08000000 {2048-bit} or 1 {EXPORTABLE}, @hKey);
  end;

  if hKey = 0 then
  begin
    SafeWriteLn('[ERROR] Native CryptoAPI CryptGenKey failed: ' + IntToStr(GetLastError));
    Exit;
  end;

  try
    // 2. Prepara Subject CN=localhost
    EncodedNameLen := 0;
    if not CertStrToNameA(MY_ENCODING_TYPE, PAnsiChar(AnsiString(SubjectName)), 3, nil, nil, @EncodedNameLen, nil) then
      Exit;

    SetLength(EncodedName, EncodedNameLen);
    if not CertStrToNameA(MY_ENCODING_TYPE, PAnsiChar(AnsiString(SubjectName)), 3, nil, @EncodedName[0], @EncodedNameLen, nil) then
      Exit;

    SubjectBlob.cbData := EncodedNameLen;
    SubjectBlob.pbData := @EncodedName[0];

    KeyProvInfo.pwszContainerName := PWideChar('DextDevKeyContainer');
    KeyProvInfo.pwszProvName := PWideChar('Microsoft Enhanced RSA and AES Cryptographic Provider');
    KeyProvInfo.dwProvType := 24; {PROV_RSA_AES}
    KeyProvInfo.dwFlags := 0;
    KeyProvInfo.cProvParam := 0;
    KeyProvInfo.rgProvParam := nil;
    KeyProvInfo.dwKeySpec := 1; {AT_KEYEXCHANGE}

    // Prepara Algoritmo de Assinatura SHA-256 (exigido por Chrome, Edge, Firefox)
    FillChar(SigAlg, SizeOf(SigAlg), 0);
    SigAlg.pszObjId := PAnsiChar('1.2.840.113549.1.1.11'); {szOID_RSA_SHA256RSA}

    // Prepara Extensão SAN (Subject Alternative Name) nativa ASN.1
    EncodedSanBytes := BuildSanExtensionAsn1;
    SanExt.pszObjId := PAnsiChar('2.5.29.17');
    SanExt.fCritical := False;
    SanExt.Value.cbData := Length(EncodedSanBytes);
    SanExt.Value.pbData := @EncodedSanBytes[0];

    CertExtStruct.cExtension := 1;
    CertExtStruct.rgExtension := @SanExt;

    // 3. Cria certificado autoassinado nativo X.509 SHA-256 com extensão SAN
    CertContext := CertCreateSelfSignCertificate(hProv, @SubjectBlob, 0, @KeyProvInfo, @SigAlg, nil, nil, @CertExtStruct);
    if CertContext = nil then
    begin
      SafeWriteLn('[ERROR] CryptoAPI CertCreateSelfSignCertificate failed: ' + IntToStr(GetLastError));
      Exit;
    end;

    try
      // 4. Atribui o Nome Amigável "Dext Development Certificate" e a Chave Privada
      FriendlyName := 'Dext Development Certificate';
      FriendlyNameBlob.cbData := (Length(FriendlyName) + 1) * SizeOf(WideChar);
      FriendlyNameBlob.pbData := PByte(PWideChar(FriendlyName));
      CertSetCertificateContextProperty(CertContext, CERT_FRIENDLY_NAME_PROP_ID, 0, @FriendlyNameBlob);
      CertSetCertificateContextProperty(CertContext, 2 {CERT_KEY_PROV_INFO_PROP_ID}, 0, @KeyProvInfo);

      // 5. Grava o Certificado (.crt) em formato PEM de forma 100% síncrona
      Base64Cert := TNetEncoding.Base64.EncodeBytesToString(CertContext.pbCertEncoded, CertContext.cbCertEncoded);
      PemCertContent := '-----BEGIN CERTIFICATE-----' + sLineBreak +
                        Base64Cert + sLineBreak +
                        '-----END CERTIFICATE-----' + sLineBreak;
      TFile.WriteAllText(CertFilePath, PemCertContent, TEncoding.ASCII);
      SafeWriteLn('[SUCCESS] Native Certificate X.509 generated at: ' + CertFilePath);

      // 6. Exporta a Chave Privada RSA (.key) em formato PKCS#1 OpenSSL nativo de forma 100% síncrona
      KeyBlobLen := 0;
      if CryptExportKey(hKey, 0, 7 {PRIVATEKEYBLOB}, 0, nil, @KeyBlobLen) then
      begin
        SetLength(KeyBlob, KeyBlobLen);
        if CryptExportKey(hKey, 0, 7, 0, @KeyBlob[0], @KeyBlobLen) then
        begin
          Pkcs1Bytes := BuildRSAPrivateKeyPKCS1(KeyBlob);
          Base64Key := TNetEncoding.Base64.EncodeBytesToString(@Pkcs1Bytes[0], Length(Pkcs1Bytes));
          PemKeyContent := '-----BEGIN RSA PRIVATE KEY-----' + sLineBreak +
                           Base64Key + sLineBreak +
                           '-----END RSA PRIVATE KEY-----' + sLineBreak;
          TFile.WriteAllText(KeyFilePath, PemKeyContent, TEncoding.ASCII);
          SafeWriteLn('[SUCCESS] Native Private Key generated at: ' + KeyFilePath);
        end;
      end;

      // 6b. Exporta o arquivo PKCS#12 (.pfx) nativo no Windows CryptoAPI (necessário para http.sys / Schannel)
      PfxFilePath := ChangeFileExt(CertFilePath, '.pfx');
      hMemStore := CertOpenStore(PAnsiChar(2) {CERT_STORE_PROV_MEMORY}, 0, 0, 0, nil);
      if hMemStore <> 0 then
      begin
        try
          if CertAddCertificateContextToStore(hMemStore, CertContext, 3 {CERT_STORE_ADD_REPLACE_EXISTING}, nil) then
          begin
            PfxBlob.cbData := 0;
            PfxBlob.pbData := nil;
            if PFXExportCertStoreEx(hMemStore, @PfxBlob, PWideChar('dba'), nil, 4 {EXPORT_PRIVATE_KEYS}) then
            begin
              GetMem(PfxBlob.pbData, PfxBlob.cbData);
              try
                if PFXExportCertStoreEx(hMemStore, @PfxBlob, PWideChar('dba'), nil, 4) then
                begin
                  SetLength(PfxBytes, PfxBlob.cbData);
                  Move(PfxBlob.pbData^, PfxBytes[0], PfxBlob.cbData);
                  TFile.WriteAllBytes(PfxFilePath, PfxBytes);
                  SafeWriteLn('[SUCCESS] Native PKCS#12 Bundle generated at: ' + PfxFilePath);
                end;
              finally
                FreeMem(PfxBlob.pbData);
              end;
            end;
          end;
        finally
          CertCloseStore(hMemStore, 0);
        end;
      end;

      // Trust and certificate-store installation are separate from binding.
      if TrustInRoot then
      begin
        RunElevatedAndWait('certutil.exe',
          '-addstore -f Root "' + CertFilePath + '"');
        SafeWriteLn('[SUCCESS] Certificate trusted in Windows Root Store.');
      end;

      if BindingMode <> '' then
      begin
        RunElevatedAndWait('certutil.exe', Format(
          '-p dba -importpfx -f %s "%s"', [BindingStore, PfxFilePath]));
        SafeWriteLn('[SUCCESS] Certificate imported into Windows store ' +
          BindingStore + '.');

        // Provisioning is explicit because changing http.sys bindings requires
        // administrative ownership outside normal application startup.
        HashLen := SizeOf(HashBytes);
        if (BindingMode <> '') and
           CertGetCertificateContextProperty(CertContext,
             3 {CERT_SHA1_HASH_PROP_ID}, @HashBytes[0], @HashLen) then
        begin
          ThumbprintStr := '';
          for I := 0 to 19 do
            ThumbprintStr := ThumbprintStr + IntToHex(HashBytes[I], 2);

          if SameText(BindingMode, 'update') then
            RunElevatedAndWait('netsh.exe',
              Format('http delete sslcert ipport=%s:%d',
                [BindingIp, BindingPort]));
          RunElevatedAndWait('netsh.exe', Format(
              'http add sslcert ipport=%s:%d certhash=%s appid=%s certstorename=%s',
              [BindingIp, BindingPort, ThumbprintStr, BindingAppId, BindingStore]));
          SafeWriteLn(Format(
            '[http.sys] Requested %s binding for %s:%d (store %s, AppId %s).',
            [BindingMode, BindingIp, BindingPort, BindingStore, BindingAppId]));
        end;
      end;

      Result := True;
    finally
      CertFreeCertificateContext(CertContext);
    end;
  finally
    if hKey <> 0 then CryptDestroyKey(hKey);
    if hProv <> 0 then CryptReleaseContext(hProv, 0);
  end;
end;

procedure TDevCertsCommand.Execute(const Args: TCommandLineArgs);
var
  CertAbsPath: string;
  CertFile: string;
  ShouldTrust: Boolean;
  SubCommand: string;
  BindingMode: string;
  BindingIp: string;
  BindingStore: string;
  BindingAppId: string;
  BindingPort: Integer;
begin
  if (Args.Values.Count = 0) then
  begin
    ShowUsage;
    Exit;
  end;

  SubCommand := Args.Values[0];
  if SameText(SubCommand, 'help') then
  begin
    ShowUsage;
    Exit;
  end;

  if not SameText(SubCommand, 'https') then
  begin
    SafeWriteLn('Unknown subcommand: ' + SubCommand);
    ShowUsage;
    Exit;
  end;

  ShouldTrust := Args.HasOption('trust');
  CertFile := Args.GetOption('out-cert', 'server.crt');
  CertAbsPath := TPath.GetFullPath(CertFile);
  BindingMode := '';
  if Args.HasOption('bind') then
    BindingMode := 'add';
  if Args.HasOption('update-binding') then
  begin
    if BindingMode <> '' then
      raise EArgumentException.Create('Use only one binding action');
    BindingMode := 'update';
  end;
  if Args.HasOption('remove-binding') then
  begin
    if BindingMode <> '' then
      raise EArgumentException.Create('Use only one binding action');
    BindingMode := 'remove';
  end;
  BindingIp := Args.GetOption('ip', '0.0.0.0');
  BindingPort := StrToIntDef(Args.GetOption('port', '8080'), 0);
  if (BindingPort < 1) or (BindingPort > High(Word)) then
    raise EArgumentOutOfRangeException.Create('Port must be between 1 and 65535');
  BindingStore := Args.GetOption('store', 'MY');
  BindingAppId := Args.GetOption('appid',
    '{4f3b2c10-8a9b-4d7e-8f12-3456789abcde}');
  try
    StringToGUID(BindingAppId);
  except
    raise EArgumentException.Create('--appid must be a valid GUID');
  end;

  if SameText(BindingMode, 'remove') then
  begin
    RunElevatedAndWait('netsh.exe',
      Format('http delete sslcert ipport=%s:%d', [BindingIp, BindingPort]));
    SafeWriteLn(Format('[http.sys] Requested binding removal for %s:%d.',
      [BindingIp, BindingPort]));
    Exit;
  end;

  SafeWriteLn('Generating 100% native development HTTPS certificate via Windows CryptoAPI...');
  SafeWriteLn('Target certificate path: ' + CertAbsPath);

  if GenerateSelfSignedCert(CertAbsPath, ShouldTrust, BindingMode, BindingIp,
    Word(BindingPort), BindingStore, BindingAppId) then
    SafeWriteLn('[COMPLETED] Local HTTPS Certificate is ready for development!')
  else
    SafeWriteLn('[ERROR] Failed to generate native certificate.');
end;

end.
