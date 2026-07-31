unit Dext.Web.Indy.SSL.Taurus;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  IdCustomHTTPServer, IdServerIOHandler,
  {$IFDEF DEXT_ENABLE_TAURUS_TLS}
  TaurusTLS,
  {$ENDIF}
  Dext.Web.Indy.SSL.Interfaces;

type
  { TDextIndyTaurusSSLHandler
    Implementation using Taurus TLS (OpenSSL 1.1.x / 3.x support for Indy). }
  TDextIndyTaurusSSLHandler = class(TInterfacedObject, IIndySSLHandler)
  private
    FCertFile: string;
    FKeyFile: string;
    FRootFile: string;
  public
    constructor Create(const ACertFile, AKeyFile, ARootFile: string);
    function CreateIOHandler(AServer: TIdCustomHTTPServer): TIdServerIOHandler;
  end;

implementation

uses
  Dext.Utils;

{ TDextIndyTaurusSSLHandler }

constructor TDextIndyTaurusSSLHandler.Create(const ACertFile, AKeyFile, ARootFile: string);
begin
  inherited Create;
  FCertFile := ACertFile;
  FKeyFile := AKeyFile;
  FRootFile := ARootFile;
end;

function TDextIndyTaurusSSLHandler.CreateIOHandler(AServer: TIdCustomHTTPServer): TIdServerIOHandler;
{$IFDEF DEXT_ENABLE_TAURUS_TLS}
var
  LIOHandler: TTaurusTLSServerIOHandler;
{$ENDIF}
begin
  {$IFDEF DEXT_ENABLE_TAURUS_TLS}
  LIOHandler := TTaurusTLSServerIOHandler.Create(AServer);
  LIOHandler.DefaultCert.PublicKey := FCertFile;
  LIOHandler.DefaultCert.PrivateKey := FKeyFile;
  if FRootFile <> '' then
    LIOHandler.DefaultCert.RootKey := FRootFile;

  SafeWriteLn('[HTTPS] Taurus TLS Server IOHandler initialized with Cert: ' + FCertFile + ' Key: ' + FKeyFile);

  Result := LIOHandler;
  {$ELSE}
  Result := nil;
  SafeWriteLn('WARNING: Taurus TLS requested but DEXT_ENABLE_TAURUS_TLS is not defined.');
  {$ENDIF}
end;

end.
