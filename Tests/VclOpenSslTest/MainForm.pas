unit MainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  System.Hash,
  System.NetEncoding,
  IdGlobal,
  IdHashSHA,
  IdHMAC,
  IdHMACSHA1,
  IdSSLOpenSSL;

type
  TfrmMain = class(TForm)
    pnlTop: TPanel;
    btnTestIndyOpenSSL: TButton;
    btnTestSystemHash: TButton;
    btnTestWindowsCNG: TButton;
    memoLogs: TMemo;
    lblTitle: TLabel;
    procedure btnTestIndyOpenSSLClick(Sender: TObject);
    procedure btnTestSystemHashClick(Sender: TObject);
    procedure btnTestWindowsCNGClick(Sender: TObject);
  private
    procedure Log(const Msg: string);
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.Log(const Msg: string);
begin
  memoLogs.Lines.Add(FormatDateTime('hh:nn:ss.zzz', Now) + ' - ' + Msg);
end;

procedure TfrmMain.btnTestIndyOpenSSLClick(Sender: TObject);
var
  hmac: TIdHMACSHA256;
  keyBytes, dataBytes, hashBytes: TIdBytes;
  key, data, base64Hash: string;
begin
  Log('--- Starting Indy/OpenSSL HMAC-SHA256 Test ---');
  try
    if not TIdHashSHA256.IsAvailable then
    begin
      Log('Indy TIdHashSHA256 is NOT available. Attempting to load OpenSSL...');
      try
        LoadOpenSSLLibrary;
        Log('LoadOpenSSLLibrary succeeded.');
      except
        on E: Exception do
        begin
          Log('Failed to load OpenSSL: ' + E.Message);
          Exit;
        end;
      end;
    end
    else
    begin
      Log('OpenSSL is already available.');
    end;

    key := 'my-secret-key';
    data := 'my-data-to-sign';

    hmac := TIdHMACSHA256.Create;
    try
      keyBytes := IndyTextEncoding_UTF8.GetBytes(key);
      dataBytes := IndyTextEncoding_UTF8.GetBytes(data);
      hmac.Key := keyBytes;
      hashBytes := hmac.HashValue(dataBytes);
      base64Hash := TNetEncoding.Base64.EncodeBytesToString(hashBytes);
      Log('HMAC-SHA256 Base64: ' + base64Hash);
    finally
      hmac.Free;
    end;
  except
    on E: Exception do
    begin
      Log('Error during Indy/OpenSSL test: ' + E.Message);
    end;
  end;
end;

procedure TfrmMain.btnTestSystemHashClick(Sender: TObject);
var
  hashBytes: TBytes;
  key, data, base64Hash: string;
begin
  Log('--- Starting System.Hash HMAC-SHA256 Test ---');
  try
    key := 'my-secret-key';
    data := 'my-data-to-sign';

    hashBytes := THashSHA2.GetHMACAsBytes(
      TEncoding.UTF8.GetBytes(data),
      TEncoding.UTF8.GetBytes(key)
    );
    base64Hash := TNetEncoding.Base64.EncodeBytesToString(hashBytes);
    Log('HMAC-SHA256 Base64: ' + base64Hash);
  except
    on E: Exception do
    begin
      Log('Error during System.Hash test: ' + E.Message);
    end;
  end;
end;

// Windows CNG HMAC-SHA256 implementation loaded dynamically
function WindowsCNGHMACSHA256(const AKey, AData: string; out AError: string): string;
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
  dataBytes: TBytes;
  resultBytes: TBytes;
begin
  Result := '';
  AError := '';
  hAlg := 0;
  hHash := 0;
  pbHashObject := nil;
  pbHash := nil;

  hBCrypt := LoadLibrary('bcrypt.dll');
  if hBCrypt = 0 then
  begin
    AError := 'Could not load bcrypt.dll';
    Exit;
  end;

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
    begin
      AError := 'Missing functions in bcrypt.dll';
      Exit;
    end;

    status := BCryptOpenAlgorithmProvider(hAlg, BCRYPT_SHA256_ALGORITHM, nil, BCRYPT_ALG_HANDLE_HMAC_FLAG);
    if status <> STATUS_SUCCESS then
    begin
      AError := Format('BCryptOpenAlgorithmProvider failed with status: 0x%x', [status]);
      Exit;
    end;

    status := BCryptGetProperty(hAlg, BCRYPT_OBJECT_LENGTH, @cbHashObject, SizeOf(cbHashObject), cbResult, 0);
    if status <> STATUS_SUCCESS then
    begin
      AError := Format('BCryptGetProperty ObjectLength failed with status: 0x%x', [status]);
      Exit;
    end;

    status := BCryptGetProperty(hAlg, BCRYPT_HASH_LENGTH, @cbHash, SizeOf(cbHash), cbResult, 0);
    if status <> STATUS_SUCCESS then
    begin
      AError := Format('BCryptGetProperty HashLength failed with status: 0x%x', [status]);
      Exit;
    end;

    GetMem(pbHashObject, cbHashObject);
    GetMem(pbHash, cbHash);

    keyBytes := TEncoding.UTF8.GetBytes(AKey);
    dataBytes := TEncoding.UTF8.GetBytes(AData);

    status := BCryptCreateHash(hAlg, hHash, pbHashObject, cbHashObject, PByte(keyBytes), Length(keyBytes), 0);
    if status <> STATUS_SUCCESS then
    begin
      AError := Format('BCryptCreateHash failed with status: 0x%x', [status]);
      Exit;
    end;

    status := BCryptHashData(hHash, PByte(dataBytes), Length(dataBytes), 0);
    if status <> STATUS_SUCCESS then
    begin
      AError := Format('BCryptHashData failed with status: 0x%x', [status]);
      Exit;
    end;

    status := BCryptFinishHash(hHash, pbHash, cbHash, 0);
    if status <> STATUS_SUCCESS then
    begin
      AError := Format('BCryptFinishHash failed with status: 0x%x', [status]);
      Exit;
    end;

    SetLength(resultBytes, cbHash);
    Move(pbHash^, resultBytes[0], cbHash);
    Result := TNetEncoding.Base64.EncodeBytesToString(resultBytes);

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

procedure TfrmMain.btnTestWindowsCNGClick(Sender: TObject);
var
  key, data, base64Hash, errorMsg: string;
begin
  Log('--- Starting Windows CNG HMAC-SHA256 Test ---');
  key := 'my-secret-key';
  data := 'my-data-to-sign';

  base64Hash := WindowsCNGHMACSHA256(key, data, errorMsg);
  if errorMsg <> '' then
    Log('Error: ' + errorMsg)
  else
    Log('HMAC-SHA256 Base64: ' + base64Hash);
end;

end.
