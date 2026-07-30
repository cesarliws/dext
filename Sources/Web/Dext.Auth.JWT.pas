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
unit Dext.Auth.JWT;

{$I Dext.inc}

interface

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.Classes,
  System.DateUtils,
  System.Hash,
  System.JSON,
  System.NetEncoding,
  System.Rtti,
  System.SysUtils,
  IdGlobal,
  IdHashSHA,
  IdHMAC,
  IdHMACSHA1,
  IdSSLOpenSSL,
  Dext.Core.Span,
  Dext.Collections;

type
  /// <summary>
  ///   Represents a claim (key-value pair) in a JWT token.
  /// </summary>
  TClaim = record
    /// <summary>The type/key of the claim.</summary>
    ClaimType: string;
    /// <summary>The value of the claim.</summary>
    Value: string;
    /// <summary>Creates a new Claim record.</summary>
    constructor Create(const AType, AValue: string);
  end;

  /// <summary>
  ///   JWT token validation result.
  /// </summary>
  TJwtValidationResult = record
    /// <summary>Indicates whether the validation succeeded.</summary>
    IsValid: Boolean;
    /// <summary>Contains the error description if validation failed.</summary>
    ErrorMessage: string;
    /// <summary>Claims extracted from the verified token.</summary>
    Claims: TArray<TClaim>;
  end;

  /// <summary>
  ///   JWT token handler contract, allowing for generation and validation.
  /// </summary>
  IJwtTokenHandler = interface
    ['{A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D}']
    /// <summary>Generates a token with specified claims signed with HMAC-SHA256.</summary>
    function GenerateToken(const AClaims: TArray<TClaim>): string;
    /// <summary>Validates and decodes the given JWT token.</summary>
    function ValidateToken(const AToken: string): TJwtValidationResult;
    /// <summary>Gets the claims of a token without checking signature. Use with caution.</summary>
    function GetClaims(const AToken: string): TArray<TClaim>;
    
    /// <summary>Secret key getter.</summary>
    function GetSecretKey: string;
    /// <summary>Secret key setter.</summary>
    procedure SetSecretKey(const Value: string);
    /// <summary>Issuer getter.</summary>
    function GetIssuer: string;
    /// <summary>Issuer setter.</summary>
    procedure SetIssuer(const Value: string);
    /// <summary>Audience getter.</summary>
    function GetAudience: string;
    /// <summary>Audience setter.</summary>
    procedure SetAudience(const Value: string);
    /// <summary>Expiration time in minutes getter.</summary>
    function GetExpirationMinutes: Integer;
    /// <summary>Expiration time in minutes setter.</summary>
    procedure SetExpirationMinutes(const Value: Integer);
    
    /// <summary>Secret key used to sign and verify tokens.</summary>
    property SecretKey: string read GetSecretKey write SetSecretKey;
    /// <summary>Issuer of the token.</summary>
    property Issuer: string read GetIssuer write SetIssuer;
    /// <summary>Target audience of the token.</summary>
    property Audience: string read GetAudience write SetAudience;
    /// <summary>Token lifespan in minutes.</summary>
    property ExpirationMinutes: Integer read GetExpirationMinutes write SetExpirationMinutes;
  end;

  /// <summary>
  ///   JWT configuration options (Secret, Issuer, Audience, Algorithm, PublicKey).
  /// </summary>
  TJwtOptions = record
  public
    /// <summary>Secret key used for signing and validating HS256 tokens.</summary>
    SecretKey: string;
    /// <summary>Token issuer (iss claim).</summary>
    Issuer: string;
    /// <summary>Token audience (aud claim).</summary>
    Audience: string;
    /// <summary>Token expiration time in minutes.</summary>
    ExpirationMinutes: Integer;
    /// <summary>Algorithm used (HS256, RS256).</summary>
    Algorithm: string;
    /// <summary>Base64 encoded public key or modulus/exponent for RS256 validation.</summary>
    PublicKey: string;

    /// <summary>Creates default JWT options.</summary>
    class function Create(const ASecretKey: string): TJwtOptions; static;
  end;

  /// <summary>
  ///   Fluent builder for creating TJwtOptions objects.
  /// </summary>
  TJwtOptionsBuilder = record
  private
    FOptions: TJwtOptions;
    FInitialized: Boolean;
    procedure EnsureInitialized(const ASecretKey: string = '');
  public
    /// <summary>Creates a new JWT options builder with the given secret.</summary>
    class function Create(const ASecretKey: string): TJwtOptionsBuilder; static;
    /// <summary>Sets the token issuer.</summary>
    function Issuer(const AIssuer: string): TJwtOptionsBuilder;
    /// <summary>Sets the token audience.</summary>
    function Audience(const AAudience: string): TJwtOptionsBuilder;
    /// <summary>Sets the token expiration in minutes.</summary>
    function ExpirationMinutes(AMinutes: Integer): TJwtOptionsBuilder;
    /// <summary>Sets the signing algorithm.</summary>
    function Algorithm(const AAlg: string): TJwtOptionsBuilder;
    /// <summary>Sets the public key for asymmetric validation.</summary>
    function PublicKey(const APubKey: string): TJwtOptionsBuilder;

    /// <summary>Sets the token issuer (deprecated).</summary>
    function WithIssuer(const AIssuer: string): TJwtOptionsBuilder; deprecated 'Use Issuer instead';
    /// <summary>Sets the token audience (deprecated).</summary>
    function WithAudience(const AAudience: string): TJwtOptionsBuilder; deprecated 'Use Audience instead';
    /// <summary>Sets the token expiration (deprecated).</summary>
    function WithExpirationMinutes(AMinutes: Integer): TJwtOptionsBuilder; deprecated 'Use ExpirationMinutes instead';

    /// <summary>Builds and returns the JWT options.</summary>
    function Build: TJwtOptions;
    /// <summary>Implicit conversion to TJwtOptions.</summary>
    class operator Implicit(const ABuilder: TJwtOptionsBuilder): TJwtOptions;
  end;

  /// <summary>Delegate for configuring JWT options via builder.</summary>
  TJwtBuilderProc = reference to procedure(var Builder: TJwtOptionsBuilder);

  /// <summary>Helper for implicit conversion of TJwtOptions to TValue.</summary>
  TJwtOptionsHelper = record helper for TJwtOptions
  public
    /// <summary>Converts a TJwtOptions instance implicitly to TValue.</summary>
    class operator Implicit(const AValue: TJwtOptions): TValue;
  end;

  /// <summary>
  ///   Default implementation of the JWT token handler using HS256 and RS256.
  /// </summary>
  TJwtTokenHandler = class(TInterfacedObject, IJwtTokenHandler)
  private
    FSecretKey: string;
    FIssuer: string;
    FAudience: string;
    FExpirationMinutes: Integer;
    FAlgorithm: string;
    FPublicKey: string;
    FBase64: TBase64Encoding;
    class function ToBase64Url(const ABase64: string): string; static;

    function Base64UrlEncode(const AInput: string): string;
    function Base64UrlDecode(const AInput: string): string;
    function CreateSignature(const AHeader, APayload: string): string;
    function VerifySignature(const AToken: string): Boolean;
    
    function GetSecretKey: string;
    procedure SetSecretKey(const Value: string);
    function GetIssuer: string;
    procedure SetIssuer(const Value: string);
    function GetAudience: string;
    procedure SetAudience(const Value: string);
    function GetExpirationMinutes: Integer;
    procedure SetExpirationMinutes(const Value: Integer);
  public
    /// <summary>Initializes a new instance of the token handler.</summary>
    constructor Create(const ASecretKey: string; const AIssuer: string = '';
      const AAudience: string = ''; AExpirationMinutes: Integer = 60); overload;
    /// <summary>Initializes a new instance of the token handler with full options.</summary>
    constructor Create(const AOptions: TJwtOptions); overload;
    /// <summary>Destroys the token handler instance.</summary>
    destructor Destroy; override;

    /// <summary>Generates a JWT token with the specified claims.</summary>
    function GenerateToken(const AClaims: TArray<TClaim>): string;
    /// <summary>Validates a JWT token and returns the claims if valid.</summary>
    function ValidateToken(const AToken: string): TJwtValidationResult;
    /// <summary>Extracts claims from a token without full validation.</summary>
    function GetClaims(const AToken: string): TArray<TClaim>;

    /// <summary>Secret key.</summary>
    property SecretKey: string read GetSecretKey write SetSecretKey;
    /// <summary>Token issuer.</summary>
    property Issuer: string read GetIssuer write SetIssuer;
    /// <summary>Token audience.</summary>
    property Audience: string read GetAudience write SetAudience;
    /// <summary>Expiration time in minutes.</summary>
    property ExpirationMinutes: Integer read GetExpirationMinutes write SetExpirationMinutes;
    /// <summary>Algorithm.</summary>
    property Algorithm: string read FAlgorithm write FAlgorithm;
    /// <summary>Public Key.</summary>
    property PublicKey: string read FPublicKey write FPublicKey;
  end;

implementation

uses
  System.StrUtils;

{ TClaim }

constructor TClaim.Create(const AType, AValue: string);
begin
  ClaimType := AType;
  Value := AValue;
end;

{ TJwtTokenHandler }

constructor TJwtTokenHandler.Create(const ASecretKey, AIssuer, AAudience: string;
  AExpirationMinutes: Integer);
begin
  inherited Create;
  FSecretKey := ASecretKey;
  FIssuer := AIssuer;
  FAudience := AAudience;
  FExpirationMinutes := AExpirationMinutes;
  FAlgorithm := 'HS256';
  FPublicKey := '';
  FBase64 := TBase64Encoding.Create(0);
end;

constructor TJwtTokenHandler.Create(const AOptions: TJwtOptions);
begin
  inherited Create;
  FSecretKey := AOptions.SecretKey;
  FIssuer := AOptions.Issuer;
  FAudience := AOptions.Audience;
  FExpirationMinutes := AOptions.ExpirationMinutes;
  FAlgorithm := AOptions.Algorithm;
  FPublicKey := AOptions.PublicKey;
  if FAlgorithm = '' then
    FAlgorithm := 'HS256';
  FBase64 := TBase64Encoding.Create(0);
end;

class function TJwtTokenHandler.ToBase64Url(const ABase64: string): string;
var
  i, j, len: Integer;
begin
  len := Length(ABase64);
  SetLength(Result, len);
  j := 1;
  for i := 1 to len do
  begin
    case ABase64[i] of
      '+':
        begin
          Result[j] := '-';
          Inc(j);
        end;
      '/':
        begin
          Result[j] := '_';
          Inc(j);
        end;
      '=':
        ; // skip padding
    else
      Result[j] := ABase64[i];
      Inc(j);
    end;
  end;
  SetLength(Result, j - 1);
end;

function TJwtTokenHandler.Base64UrlEncode(const AInput: string): string;
var
  bytes: TBytes;
begin
  bytes := TEncoding.UTF8.GetBytes(AInput);
  Result := ToBase64Url(FBase64.EncodeBytesToString(bytes));
end;

function TJwtTokenHandler.Base64UrlDecode(const AInput: string): string;
var
  base64: string;
  bytes: TBytes;
  padding: Integer;
begin
  base64 := AInput;
  base64 := base64.Replace('-', '+', [rfReplaceAll]);
  base64 := base64.Replace('_', '/', [rfReplaceAll]);
  
  padding := 4 - (Length(base64) mod 4);
  if padding < 4 then
    base64 := base64 + StringOfChar('=', padding);
  
  bytes := TNetEncoding.Base64.DecodeStringToBytes(base64);
  Result := TEncoding.UTF8.GetString(bytes);
end;

{$IFDEF MSWINDOWS}
type
  TBCryptRsaKeyBlob = record
    Magic: Cardinal;
    BitLength: Cardinal;
    cbPublicExp: Cardinal;
    cbModulus: Cardinal;
    cbPrime1: Cardinal;
    cbPrime2: Cardinal;
  end;

  TBCryptPkcs1PaddingInfo = record
    pszAlgId: LPCWSTR;
  end;

// Windows CNG helper function to compute HMAC-SHA256
function BCryptHMACSHA256(const AKey, AHeader, APayload: string; out ABytes: TBytes): Boolean;
const
  BCRYPT_SHA256_ALGORITHM = 'SHA256';
  BCRYPT_ALG_HANDLE_HMAC_FLAG = $00000008;
  BCRYPT_OBJECT_LENGTH = 'ObjectLength';
  BCRYPT_HASH_LENGTH = 'HashLength';
  STATUS_SUCCESS = HRESULT($00000000);
type
  TBCryptOpenAlgorithmProvider = function(out phAlgorithm: THandle; pszAlgId: LPCWSTR; pszImplementation: LPCWSTR; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptCloseAlgorithmProvider = function(hAlgorithm: THandle; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptGetProperty = function(hObject: THandle; pszProperty: LPCWSTR; pbOutput: PByte; cbOutput: ULONG; out pcbResult: ULONG; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptCreateHash = function(hAlgorithm: THandle; out phHash: THandle; pbHashObject: PByte; cbHashObject: ULONG; pbSecret: PByte; cbSecret: ULONG; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptHashData = function(hHash: THandle; pbInput: PByte; cbInput: ULONG; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptFinishHash = function(hHash: THandle; pbOutput: PByte; cbOutput: ULONG; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptDestroyHash = function(hHash: THandle): HRESULT; stdcall;
var
  hBCrypt: HMODULE;
  BCryptOpenAlgorithmProvider: TBCryptOpenAlgorithmProvider;
  BCryptCloseAlgorithmProvider: TBCryptCloseAlgorithmProvider;
  BCryptGetProperty: TBCryptGetProperty;
  BCryptCreateHash: TBCryptCreateHash;
  BCryptHashData: TBCryptHashData;
  BCryptFinishHash: TBCryptFinishHash;
  BCryptDestroyHash: TBCryptDestroyHash;

  hAlg: THandle;
  hHash: THandle;
  status: HRESULT;
  cbResult: Cardinal;
  cbHashObject: Cardinal;
  cbHash: Cardinal;
  pbHashObject: PByte;
  pbHash: PByte;
  keyBytes: TBytes;
  headerBytes: TBytes;
  dotByte: Byte;
  payloadBytes: TBytes;
begin
  Result := False;
  BCryptCloseAlgorithmProvider := nil;
  BCryptDestroyHash := nil;

  hAlg := 0;
  hHash := 0;
  pbHashObject := nil;
  pbHash := nil;

  hBCrypt := LoadLibrary('bcrypt.dll');
  if hBCrypt = 0 then
    Exit;

  try
    @BCryptOpenAlgorithmProvider := GetProcAddress(hBCrypt, 'BCryptOpenAlgorithmProvider');
    @BCryptCloseAlgorithmProvider := GetProcAddress(hBCrypt, 'BCryptCloseAlgorithmProvider');
    @BCryptGetProperty := GetProcAddress(hBCrypt, 'BCryptGetProperty');
    @BCryptCreateHash := GetProcAddress(hBCrypt, 'BCryptCreateHash');
    @BCryptHashData := GetProcAddress(hBCrypt, 'BCryptHashData');
    @BCryptFinishHash := GetProcAddress(hBCrypt, 'BCryptFinishHash');
    @BCryptDestroyHash := GetProcAddress(hBCrypt, 'BCryptDestroyHash');

    if not Assigned(BCryptOpenAlgorithmProvider) or not Assigned(BCryptCloseAlgorithmProvider) or
       not Assigned(BCryptGetProperty) or not Assigned(BCryptCreateHash) or
       not Assigned(BCryptHashData) or not Assigned(BCryptFinishHash) or
       not Assigned(BCryptDestroyHash) then
      Exit;

    status := BCryptOpenAlgorithmProvider(hAlg, BCRYPT_SHA256_ALGORITHM, nil, BCRYPT_ALG_HANDLE_HMAC_FLAG);
    if status <> STATUS_SUCCESS then
      Exit;

    status := BCryptGetProperty(hAlg, BCRYPT_OBJECT_LENGTH, @cbHashObject, SizeOf(cbHashObject), cbResult, 0);
    if status <> STATUS_SUCCESS then
      Exit;

    status := BCryptGetProperty(hAlg, BCRYPT_HASH_LENGTH, @cbHash, SizeOf(cbHash), cbResult, 0);
    if status <> STATUS_SUCCESS then
      Exit;

    GetMem(pbHashObject, cbHashObject);
    GetMem(pbHash, cbHash);

    keyBytes := TEncoding.UTF8.GetBytes(AKey);
    headerBytes := TEncoding.UTF8.GetBytes(AHeader);
    dotByte := Ord('.');
    payloadBytes := TEncoding.UTF8.GetBytes(APayload);

    status := BCryptCreateHash(hAlg, hHash, pbHashObject, cbHashObject, PByte(keyBytes), Length(keyBytes), 0);
    if status <> STATUS_SUCCESS then
      Exit;

    status := BCryptHashData(hHash, PByte(headerBytes), Length(headerBytes), 0);
    if status <> STATUS_SUCCESS then
      Exit;

    status := BCryptHashData(hHash, @dotByte, 1, 0);
    if status <> STATUS_SUCCESS then
      Exit;

    status := BCryptHashData(hHash, PByte(payloadBytes), Length(payloadBytes), 0);
    if status <> STATUS_SUCCESS then
      Exit;

    status := BCryptFinishHash(hHash, pbHash, cbHash, 0);
    if status <> STATUS_SUCCESS then
      Exit;

    SetLength(ABytes, cbHash);
    Move(pbHash^, ABytes[0], cbHash);
    Result := True;

  finally
    if hHash <> 0 then
      BCryptDestroyHash(hHash);
    if hAlg <> 0 then
      BCryptCloseAlgorithmProvider(hAlg, 0);
    if pbHashObject <> nil then
      FreeMem(pbHashObject);
    if pbHash <> nil then
      FreeMem(pbHash);
    FreeLibrary(hBCrypt);
  end;
end;

// Windows CNG helper function to verify RS256 signatures
function BCryptVerifyRS256(const APublicKeyPemOrModulusExponent, AHeader, APayload, ASignatureB64Url: string): Boolean;
const
  BCRYPT_SHA256_ALGORITHM = 'SHA256';
  BCRYPT_RSA_ALGORITHM = 'RSA';
  BCRYPT_PAD_PKCS1 = $00000002;
  STATUS_SUCCESS = HRESULT($00000000);
type
  TBCryptOpenAlgorithmProvider = function(out phAlgorithm: THandle; pszAlgId: LPCWSTR; pszImplementation: LPCWSTR; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptCloseAlgorithmProvider = function(hAlgorithm: THandle; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptImportKeyPair = function(hAlgorithm: THandle; hPubKey: THandle; pszBlobType: LPCWSTR; out phKey: THandle; pbInput: PByte; cbInput: ULONG; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptDestroyKey = function(hKey: THandle): HRESULT; stdcall;
  TBCryptCreateHash = function(hAlgorithm: THandle; out phHash: THandle; pbHashObject: PByte; cbHashObject: ULONG; pbSecret: PByte; cbSecret: ULONG; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptHashData = function(hHash: THandle; pbInput: PByte; cbInput: ULONG; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptFinishHash = function(hHash: THandle; pbOutput: PByte; cbOutput: ULONG; dwFlags: ULONG): HRESULT; stdcall;
  TBCryptDestroyHash = function(hHash: THandle): HRESULT; stdcall;
  TBCryptVerifySignature = function(hKey: THandle; pPaddingInfo: Pointer; pbHash: PByte; cbHash: ULONG; pbSignature: PByte; cbSignature: ULONG; dwFlags: ULONG): HRESULT; stdcall;
var
  hBCrypt: HMODULE;
  BCryptOpenAlgorithmProvider: TBCryptOpenAlgorithmProvider;
  BCryptCloseAlgorithmProvider: TBCryptCloseAlgorithmProvider;
  BCryptImportKeyPair: TBCryptImportKeyPair;
  BCryptDestroyKey: TBCryptDestroyKey;
  BCryptCreateHash: TBCryptCreateHash;
  BCryptHashData: TBCryptHashData;
  BCryptFinishHash: TBCryptFinishHash;
  BCryptDestroyHash: TBCryptDestroyHash;
  BCryptVerifySignature: TBCryptVerifySignature;

  hRsaAlg: THandle;
  hHashAlg: THandle;
  hKey: THandle;
  hHash: THandle;
  status: HRESULT;
  sigBytes: TBytes;
  signedData: string;
  dataBytes: TBytes;
  hashBytes: TBytes;
  paddingInfo: TBCryptPkcs1PaddingInfo;
  
  // Public key parsing
  nBytes: TBytes;
  eBytes: TBytes;
  blobBytes: TBytes;
  blobHeader: TBCryptRsaKeyBlob;
  keyJson: TJSONObject;
  base64UrlStr: string;
begin
  Result := False;
  BCryptCloseAlgorithmProvider := nil;
  BCryptDestroyKey := nil;
  BCryptDestroyHash := nil;

  hRsaAlg := 0;
  hHashAlg := 0;
  hKey := 0;
  hHash := 0;

  hBCrypt := LoadLibrary('bcrypt.dll');
  if hBCrypt = 0 then
    Exit;

  try
    @BCryptOpenAlgorithmProvider := GetProcAddress(hBCrypt, 'BCryptOpenAlgorithmProvider');
    @BCryptCloseAlgorithmProvider := GetProcAddress(hBCrypt, 'BCryptCloseAlgorithmProvider');
    @BCryptImportKeyPair := GetProcAddress(hBCrypt, 'BCryptImportKeyPair');
    @BCryptDestroyKey := GetProcAddress(hBCrypt, 'BCryptDestroyKey');
    @BCryptCreateHash := GetProcAddress(hBCrypt, 'BCryptCreateHash');
    @BCryptHashData := GetProcAddress(hBCrypt, 'BCryptHashData');
    @BCryptFinishHash := GetProcAddress(hBCrypt, 'BCryptFinishHash');
    @BCryptDestroyHash := GetProcAddress(hBCrypt, 'BCryptDestroyHash');
    @BCryptVerifySignature := GetProcAddress(hBCrypt, 'BCryptVerifySignature');

    if not Assigned(BCryptOpenAlgorithmProvider) or not Assigned(BCryptCloseAlgorithmProvider) or
       not Assigned(BCryptImportKeyPair) or not Assigned(BCryptDestroyKey) or
       not Assigned(BCryptCreateHash) or not Assigned(BCryptHashData) or
       not Assigned(BCryptFinishHash) or not Assigned(BCryptDestroyHash) or
       not Assigned(BCryptVerifySignature) then
      Exit;

    // Parse Public Key JSON (JWK format) or raw base64 PEM
    nBytes := nil;
    eBytes := nil;
    if APublicKeyPemOrModulusExponent.Trim.StartsWith('{') then
    begin
      try
        keyJson := TJSONObject.ParseJSONValue(APublicKeyPemOrModulusExponent) as TJSONObject;
        if keyJson <> nil then
        begin
          try
            if keyJson.Values['n'] <> nil then
            begin
              base64UrlStr := keyJson.Values['n'].Value;
              base64UrlStr := base64UrlStr.Replace('-', '+', [rfReplaceAll]).Replace('_', '/', [rfReplaceAll]);
              while Length(base64UrlStr) mod 4 <> 0 do
                base64UrlStr := base64UrlStr + '=';
              nBytes := TNetEncoding.Base64.DecodeStringToBytes(base64UrlStr);
            end;
            if keyJson.Values['e'] <> nil then
            begin
              base64UrlStr := keyJson.Values['e'].Value;
              base64UrlStr := base64UrlStr.Replace('-', '+', [rfReplaceAll]).Replace('_', '/', [rfReplaceAll]);
              while Length(base64UrlStr) mod 4 <> 0 do
                base64UrlStr := base64UrlStr + '=';
              eBytes := TNetEncoding.Base64.DecodeStringToBytes(base64UrlStr);
            end;
          finally
            keyJson.Free;
          end;
        end;
      except
        Exit;
      end;
    end;

    if (Length(nBytes) = 0) or (Length(eBytes) = 0) then
      Exit; // Could not parse RSA Modulus/Exponent

    // Construct BCRYPT_RSAKEY_BLOB
    blobHeader.Magic := $31415352; // 'RSA1'
    blobHeader.BitLength := Length(nBytes) * 8;
    blobHeader.cbPublicExp := Length(eBytes);
    blobHeader.cbModulus := Length(nBytes);
    blobHeader.cbPrime1 := 0;
    blobHeader.cbPrime2 := 0;

    SetLength(blobBytes, SizeOf(TBCryptRsaKeyBlob) + Length(eBytes) + Length(nBytes));
    Move(blobHeader, blobBytes[0], SizeOf(TBCryptRsaKeyBlob));
    Move(eBytes[0], blobBytes[SizeOf(TBCryptRsaKeyBlob)], Length(eBytes));
    Move(nBytes[0], blobBytes[SizeOf(TBCryptRsaKeyBlob) + Length(eBytes)], Length(nBytes));

    // Initialize algorithm provider and import key
    status := BCryptOpenAlgorithmProvider(hRsaAlg, BCRYPT_RSA_ALGORITHM, nil, 0);
    if status <> STATUS_SUCCESS then
      Exit;

    status := BCryptImportKeyPair(hRsaAlg, 0, 'RSAPUBLICBLOB', hKey, @blobBytes[0], Length(blobBytes), 0);
    if status <> STATUS_SUCCESS then
      Exit;

    // Hash the JWT Header + Payload
    status := BCryptOpenAlgorithmProvider(hHashAlg, BCRYPT_SHA256_ALGORITHM, nil, 0);
    if status <> STATUS_SUCCESS then
      Exit;

    status := BCryptCreateHash(hHashAlg, hHash, nil, 0, nil, 0, 0);
    if status <> STATUS_SUCCESS then
      Exit;

    signedData := AHeader + '.' + APayload;
    dataBytes := TEncoding.UTF8.GetBytes(signedData);
    status := BCryptHashData(hHash, PByte(dataBytes), Length(dataBytes), 0);
    if status <> STATUS_SUCCESS then
      Exit;

    SetLength(hashBytes, 32); // SHA256 digest size
    status := BCryptFinishHash(hHash, @hashBytes[0], 32, 0);
    if status <> STATUS_SUCCESS then
      Exit;

    // Verify signature
    base64UrlStr := ASignatureB64Url;
    base64UrlStr := base64UrlStr.Replace('-', '+', [rfReplaceAll]).Replace('_', '/', [rfReplaceAll]);
    while Length(base64UrlStr) mod 4 <> 0 do
      base64UrlStr := base64UrlStr + '=';
    sigBytes := TNetEncoding.Base64.DecodeStringToBytes(base64UrlStr);

    paddingInfo.pszAlgId := 'SHA256';
    status := BCryptVerifySignature(hKey, @paddingInfo, @hashBytes[0], 32, @sigBytes[0], Length(sigBytes), BCRYPT_PAD_PKCS1);
    Result := status = STATUS_SUCCESS;

  finally
    if hKey <> 0 then
      BCryptDestroyKey(hKey);
    if hRsaAlg <> 0 then
      BCryptCloseAlgorithmProvider(hRsaAlg, 0);
    if hHashAlg <> 0 then
      BCryptCloseAlgorithmProvider(hHashAlg, 0);
    if hHash <> 0 then
      BCryptDestroyHash(hHash);
    FreeLibrary(hBCrypt);
  end;
end;
{$ENDIF}

function TJwtTokenHandler.CreateSignature(const AHeader, APayload: string): string;
var
  data: string;
  base64Hash: string;
  hashBytes: TBytes;
  {$IFNDEF DEXT_HAS_SYSTEM_HASH}
  hmac: TIdHMACSHA256;
  idHash: TIdBytes;
  {$ENDIF}
begin
  if FAlgorithm = 'RS256' then
    raise ENotSupportedException.Create('RS256 token generation is not supported. Use RS256 for validation only.');

  {$IFDEF MSWINDOWS}
  // 1. Try Windows CNG API first
  if BCryptHMACSHA256(FSecretKey, AHeader, APayload, hashBytes) then
  begin
    base64Hash := TNetEncoding.Base64.EncodeBytesToString(hashBytes);
    Result := ToBase64Url(base64Hash);
    Exit;
  end;
  {$ENDIF}

  // Fallback to System.Hash or Indy/OpenSSL
  data := AHeader + '.' + APayload;

  {$IFDEF DEXT_HAS_SYSTEM_HASH}
  // 2. Use native Delphi System.Hash (Delphi XE8+)
  hashBytes := THashSHA2.GetHMACAsBytes(
    TEncoding.UTF8.GetBytes(data),
    TEncoding.UTF8.GetBytes(FSecretKey)
  );
  base64Hash := TNetEncoding.Base64.EncodeBytesToString(hashBytes);
  {$ELSE}
  // 3. Fallback to Indy/OpenSSL for older Delphi versions
  if not TIdHashSHA256.IsAvailable then
    LoadOpenSSLLibrary;
  
  hmac := TIdHMACSHA256.Create;
  try
    hmac.Key := IndyTextEncoding_UTF8.GetBytes(FSecretKey);
    idHash := hmac.HashValue(IndyTextEncoding_UTF8.GetBytes(data));
    base64Hash := TNetEncoding.Base64.EncodeBytesToString(idHash);
  finally
    hmac.Free;
  end;
  {$ENDIF}
    
  Result := ToBase64Url(base64Hash);
end;

destructor TJwtTokenHandler.Destroy;
begin
  FBase64.Free;
  inherited;
end;

function TJwtTokenHandler.GetSecretKey: string;
begin
  Result := FSecretKey;
end;

procedure TJwtTokenHandler.SetSecretKey(const Value: string);
begin
  FSecretKey := Value;
end;

function TJwtTokenHandler.GetIssuer: string;
begin
  Result := FIssuer;
end;

procedure TJwtTokenHandler.SetIssuer(const Value: string);
begin
  FIssuer := Value;
end;

function TJwtTokenHandler.GetAudience: string;
begin
  Result := FAudience;
end;

procedure TJwtTokenHandler.SetAudience(const Value: string);
begin
  FAudience := Value;
end;

function TJwtTokenHandler.GetExpirationMinutes: Integer;
begin
  Result := FExpirationMinutes;
end;

procedure TJwtTokenHandler.SetExpirationMinutes(const Value: Integer);
begin
  FExpirationMinutes := Value;
end;

{ TJwtOptions }

class function TJwtOptions.Create(const ASecretKey: string): TJwtOptions;
begin
  Result.SecretKey := ASecretKey;
  Result.Issuer := '';
  Result.Audience := '';
  Result.ExpirationMinutes := 60;
  Result.Algorithm := 'HS256';
  Result.PublicKey := '';
end;

{ TJwtOptionsBuilder }
 
procedure TJwtOptionsBuilder.EnsureInitialized(const ASecretKey: string);
begin
  if not FInitialized then
  begin
    FOptions := TJwtOptions.Create(ASecretKey);
    FInitialized := True;
  end;
end;

class function TJwtOptionsBuilder.Create(const ASecretKey: string): TJwtOptionsBuilder;
begin
  Result.FOptions := TJwtOptions.Create(ASecretKey);
  Result.FInitialized := True;
end;

function TJwtOptionsBuilder.Issuer(const AIssuer: string): TJwtOptionsBuilder;
begin
  EnsureInitialized;
  FOptions.Issuer := AIssuer;
  Result := Self;
end;

function TJwtOptionsBuilder.Audience(const AAudience: string): TJwtOptionsBuilder;
begin
  EnsureInitialized;
  FOptions.Audience := AAudience;
  Result := Self;
end;

function TJwtOptionsBuilder.ExpirationMinutes(AMinutes: Integer): TJwtOptionsBuilder;
begin
  EnsureInitialized;
  FOptions.ExpirationMinutes := AMinutes;
  Result := Self;
end;

function TJwtOptionsBuilder.Algorithm(const AAlg: string): TJwtOptionsBuilder;
begin
  EnsureInitialized;
  FOptions.Algorithm := AAlg;
  Result := Self;
end;

function TJwtOptionsBuilder.PublicKey(const APubKey: string): TJwtOptionsBuilder;
begin
  EnsureInitialized;
  FOptions.PublicKey := APubKey;
  Result := Self;
end;

function TJwtOptionsBuilder.WithIssuer(const AIssuer: string): TJwtOptionsBuilder;
begin
  Result := Issuer(AIssuer);
end;

function TJwtOptionsBuilder.WithAudience(const AAudience: string): TJwtOptionsBuilder;
begin
  Result := Audience(AAudience);
end;

function TJwtOptionsBuilder.WithExpirationMinutes(AMinutes: Integer): TJwtOptionsBuilder;
begin
  Result := ExpirationMinutes(AMinutes);
end;

function TJwtOptionsBuilder.Build: TJwtOptions;
begin
  EnsureInitialized;
  Result := FOptions;
end;

class operator TJwtOptionsBuilder.Implicit(const ABuilder: TJwtOptionsBuilder): TJwtOptions;
begin
  Result := ABuilder.FOptions;
end;

{ TJwtOptionsHelper }

class operator TJwtOptionsHelper.Implicit(const AValue: TJwtOptions): TValue;
begin
  Result := TValue.From<TJwtOptions>(AValue);
end;

function TJwtTokenHandler.GenerateToken(const AClaims: TArray<TClaim>): string;
var
  headerStr, payloadStr, signature: string;
  claim: TClaim;
  expirationTime: TDateTime;
  payloadJson: TStringBuilder;
begin
  headerStr := Base64UrlEncode('{"alg":"HS256","typ":"JWT"}');

  payloadJson := TStringBuilder.Create;
  try
    payloadJson.Append('{');
    
    if FIssuer <> '' then
      payloadJson.AppendFormat('"iss":"%s",', [FIssuer]);
    
    if FAudience <> '' then
      payloadJson.AppendFormat('"aud":"%s",', [FAudience]);
    
    payloadJson.AppendFormat('"iat":%d,', [DateTimeToUnix(Now)]);
    
    expirationTime := IncMinute(Now, FExpirationMinutes);
    payloadJson.AppendFormat('"exp":%d', [DateTimeToUnix(expirationTime)]);
    
    for claim in AClaims do
      payloadJson.AppendFormat(',"%s":"%s"', [claim.ClaimType, claim.Value]);
    
    payloadJson.Append('}');
    payloadStr := payloadJson.ToString;
    payloadStr := Base64UrlEncode(payloadStr);
  finally
    payloadJson.Free;
  end;

  signature := CreateSignature(headerStr, payloadStr);
  Result := headerStr + '.' + payloadStr + '.' + signature;
end;

function TJwtTokenHandler.VerifySignature(const AToken: string): Boolean;
var
  dot1, dot2: Integer;
  header, payload, signature: string;
  expectedSignature: string;
begin
  dot1 := AToken.IndexOf('.');
  if dot1 < 0 then
    Exit(False);
  
  dot2 := AToken.IndexOf('.', dot1 + 1);
  if dot2 < 0 then
    Exit(False);
    
  if AToken.IndexOf('.', dot2 + 1) >= 0 then
    Exit(False);

  header := AToken.Substring(0, dot1);
  payload := AToken.Substring(dot1 + 1, dot2 - dot1 - 1);
  signature := AToken.Substring(dot2 + 1);
  
  if FAlgorithm = 'RS256' then
  begin
    {$IFDEF MSWINDOWS}
    Result := BCryptVerifyRS256(FPublicKey, header, payload, signature);
    {$ELSE}
    raise ENotSupportedException.Create('RS256 validation is only supported on Windows CNG currently.');
    {$ENDIF}
  end
  else
  begin
    expectedSignature := CreateSignature(header, payload);
    Result := signature = expectedSignature;
  end;
end;

function TJwtTokenHandler.GetClaims(const AToken: string): TArray<TClaim>;
var
  dot1, dot2: Integer;
  payloadJson: string;
  payloadObj: TJSONObject;
  pair: TJSONPair;
  claimsList: IList<TClaim>;
  claim: TClaim;
begin
  SetLength(Result, 0);
  
  dot1 := AToken.IndexOf('.');
  if dot1 < 0 then
    Exit;
  
  dot2 := AToken.IndexOf('.', dot1 + 1);
  if dot2 < 0 then
    Exit;
  
  try
    payloadJson := Base64UrlDecode(AToken.Substring(dot1 + 1, dot2 - dot1 - 1));
    payloadObj := TJSONObject.ParseJSONValue(payloadJson) as TJSONObject;
    if payloadObj = nil then
      Exit;
    
    try
      claimsList := TCollections.CreateList<TClaim>;
      for pair in payloadObj do
      begin
        claim.ClaimType := pair.JsonString.Value;
        if pair.JsonValue is TJSONString then
          claim.Value := TJSONString(pair.JsonValue).Value
        else if pair.JsonValue is TJSONNumber then
          claim.Value := TJSONNumber(pair.JsonValue).ToString
        else if pair.JsonValue is TJSONBool then
          claim.Value := BoolToStr(TJSONBool(pair.JsonValue).AsBoolean, True)
        else
          claim.Value := pair.JsonValue.ToString;
        
        claimsList.Add(claim);
      end;
      
      Result := claimsList.ToArray;
    finally
      payloadObj.Free;
    end;
  except
    SetLength(Result, 0);
  end;
end;

function TJwtTokenHandler.ValidateToken(const AToken: string): TJwtValidationResult;
var
  claims: TArray<TClaim>;
  claim: TClaim;
  expClaim: string;
  expTime: Int64;
  issuerFound, audienceFound: Boolean;
begin
  Result.IsValid := False;
  Result.ErrorMessage := '';
  SetLength(Result.Claims, 0);
  
  if not VerifySignature(AToken) then
  begin
    Result.ErrorMessage := 'Invalid signature';
    Exit;
  end;
  
  claims := GetClaims(AToken);
  if Length(claims) = 0 then
  begin
    Result.ErrorMessage := 'Invalid token format';
    Exit;
  end;
  
  expClaim := '';
  for claim in claims do
  begin
    if claim.ClaimType = 'exp' then
    begin
      expClaim := claim.Value;
      Break;
    end;
  end;
  
  if expClaim <> '' then
  begin
    expTime := StrToInt64Def(expClaim, 0);
    if expTime > 0 then
    begin
      if DateTimeToUnix(Now) > expTime then
      begin
        Result.ErrorMessage := 'Token expired';
        Exit;
      end;
    end;
  end;
  
  if FIssuer <> '' then
  begin
    issuerFound := False;
    for claim in claims do
    begin
      if (claim.ClaimType = 'iss') and (claim.Value = FIssuer) then
      begin
        issuerFound := True;
        Break;
      end;
    end;
    
    if not issuerFound then
    begin
      Result.ErrorMessage := 'Invalid issuer';
      Exit;
    end;
  end;
  
  if FAudience <> '' then
  begin
    audienceFound := False;
    for claim in claims do
    begin
      if (claim.ClaimType = 'aud') and (claim.Value = FAudience) then
      begin
        audienceFound := True;
        Break;
      end;
    end;
    
    if not audienceFound then
    begin
      Result.ErrorMessage := 'Invalid audience';
      Exit;
    end;
  end;
  
  Result.IsValid := True;
  Result.Claims := claims;
end;

end.
