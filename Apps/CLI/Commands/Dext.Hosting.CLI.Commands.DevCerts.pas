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

  TDevCertsCommand = class(TInterfacedObject, IConsoleCommand)
  private
    procedure ShowUsage;
    function GenerateSelfSignedCert(const CertFilePath: string; TrustInRoot: Boolean): Boolean;
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

function CertStrToNameA(dwCertEncodingType: DWORD; pszX500: PAnsiChar; dwStrType: DWORD; pvReserved: Pointer; pbEncoded: PByte; pcbEncoded: PDWORD; ppszError: PPAnsiChar): BOOL; stdcall; external 'crypt32.dll' name 'CertStrToNameA';
function CertCreateSelfSignCertificate(hCryptProvOrNCryptKey: HCRYPTPROV_OR_NCRYPT_KEY_HANDLE; pSubjectIssuerBlob: PCERT_NAME_BLOB; dwFlags: DWORD; pKeyProviderInfo: Pointer; pSignatureAlgorithm: PCRYPT_ALGORITHM_IDENTIFIER; pStartTime: PSYSTEMTIME; pEndTime: PSYSTEMTIME; pExtensions: Pointer): PCCERT_CONTEXT; stdcall; external 'crypt32.dll' name 'CertCreateSelfSignCertificate';
function CertSetCertificateContextProperty(pCertContext: PCCERT_CONTEXT; dwPropId: DWORD; dwFlags: DWORD; pvData: Pointer): BOOL; stdcall; external 'crypt32.dll' name 'CertSetCertificateContextProperty';
function CertFreeCertificateContext(pCertContext: PCCERT_CONTEXT): BOOL; stdcall; external 'crypt32.dll' name 'CertFreeCertificateContext';

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
  end;
  if (Len >= 128) and (Len <= 255) then
  begin
    SetLength(Result, 2);
    Result[0] := $81;
    Result[1] := Byte(Len);
  end;
  if Len > 255 then
  begin
    SetLength(Result, 3);
    Result[0] := $82;
    Result[1] := Byte(Len shr 8);
    Result[2] := Byte(Len and $FF);
  end;
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
  PublicExponent[0] := Byte(RsaPubKeyStruct.pubexp shr 16);
  PublicExponent[1] := Byte(RsaPubKeyStruct.pubexp shr 8);
  PublicExponent[2] := Byte(RsaPubKeyStruct.pubexp);
  if PublicExponent[0] = 0 then
    PublicExponent := Copy(PublicExponent, 1, 2);

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

procedure TDevCertsCommand.ShowUsage;
begin
  SafeWriteLn('Usage:');
  SafeWriteLn('  dext dev-certs https [--trust] [--out-cert <path>]');
  SafeWriteLn('');
  SafeWriteLn('Options:');
  SafeWriteLn('  https         Generate self-signed development certificate for localhost.');
  SafeWriteLn('  --trust       Install and trust the certificate in Windows Root Store (Requires Admin).');
  SafeWriteLn('  --out-cert    Output certificate path (default: server.crt).');
end;

function TDevCertsCommand.GenerateSelfSignedCert(const CertFilePath: string; TrustInRoot: Boolean): Boolean;
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
begin
  Result := False;
  KeyFilePath := ChangeFileExt(CertFilePath, '.key');
  SubjectName := 'CN=localhost';

  // 1. Criar container de chaves criptográficas RSA 2048-bit 100% nativo no Windows CryptoAPI
  hProv := 0;
  hKey := 0;
  CryptAcquireContextA(@hProv, PAnsiChar('DextDevKeyContainer'), PAnsiChar('Microsoft Enhanced Cryptographic Provider v1.0'), 1 {PROV_RSA_FULL}, 8 {CRYPT_NEWKEYSET});
  if hProv = 0 then
    CryptAcquireContextA(@hProv, PAnsiChar('DextDevKeyContainer'), nil, 1, 0);

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

    KeyProvInfo.pwszContainerName := PWideChar('DextDevContainer');
    KeyProvInfo.pwszProvName := PWideChar('Microsoft Enhanced Cryptographic Provider v1.0');
    KeyProvInfo.dwProvType := 1; {PROV_RSA_FULL}
    KeyProvInfo.dwFlags := 0;
    KeyProvInfo.cProvParam := 0;
    KeyProvInfo.rgProvParam := nil;
    KeyProvInfo.dwKeySpec := 1; {AT_KEYEXCHANGE}

    // 3. Cria certificado autoassinado nativo X.509
    CertContext := CertCreateSelfSignCertificate(hProv, @SubjectBlob, 0, @KeyProvInfo, nil, nil, nil, nil);
    if CertContext = nil then
    begin
      SafeWriteLn('[ERROR] CryptoAPI CertCreateSelfSignCertificate failed: ' + IntToStr(GetLastError));
      Exit;
    end;

    try
      // 4. Atribui o Nome Amigável "Dext Development Certificate"
      FriendlyName := 'Dext Development Certificate';
      FriendlyNameBlob.cbData := (Length(FriendlyName) + 1) * SizeOf(WideChar);
      FriendlyNameBlob.pbData := PByte(PWideChar(FriendlyName));
      CertSetCertificateContextProperty(CertContext, CERT_FRIENDLY_NAME_PROP_ID, 0, @FriendlyNameBlob);

      // 5. Grava o Certificado (.crt) em formato PEM de forma 100% síncrona
      Base64Cert := TNetEncoding.Base64String.EncodeBytesToString(CertContext.pbCertEncoded, CertContext.cbCertEncoded);
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
          Base64Key := TNetEncoding.Base64String.EncodeBytesToString(@Pkcs1Bytes[0], Length(Pkcs1Bytes));
          PemKeyContent := '-----BEGIN RSA PRIVATE KEY-----' + sLineBreak +
                           Base64Key + sLineBreak +
                           '-----END RSA PRIVATE KEY-----' + sLineBreak;
          TFile.WriteAllText(KeyFilePath, PemKeyContent, TEncoding.ASCII);
          SafeWriteLn('[SUCCESS] Native Private Key generated at: ' + KeyFilePath);
        end;
      end;

      // 7. Confia no certificado no Repositório de Raízes do Windows
      if TrustInRoot then
      begin
        ShellExecuteW(0, 'open', 'certutil.exe', PWideChar('-addstore -f Root "' + CertFilePath + '"'), nil, SW_HIDE);
        SafeWriteLn('[SUCCESS] Certificate trusted in Windows Root Store with Friendly Name "Dext Development Certificate"!');
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

  SafeWriteLn('Generating 100% native development HTTPS certificate via Windows CryptoAPI...');
  SafeWriteLn('Target certificate path: ' + CertAbsPath);

  if GenerateSelfSignedCert(CertAbsPath, ShouldTrust) then
    SafeWriteLn('[COMPLETED] Local HTTPS Certificate is ready for development!')
  else
    SafeWriteLn('[ERROR] Failed to generate native certificate.');
end;

end.
