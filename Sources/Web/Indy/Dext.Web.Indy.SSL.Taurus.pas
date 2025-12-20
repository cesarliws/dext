unit Dext.Web.Indy.SSL.Taurus;
{$I ..\..\Dext.inc}

interface

uses
  System.SysUtils,
  IdCustomHTTPServer, IdServerIOHandler,
  {$IFDEF DEXT_ENABLE_TAURUS_TLS}
  TaurusTLS,
  {$ENDIF}
  Dext.Web.Indy.SSL.Interfaces;

type
  { TIndyTaurusSSLHandler
    Implementation using Taurus TLS (OpenSSL 1.1.x / 3.x support for Indy). }
  TIndyTaurusSSLHandler = class(TInterfacedObject, IIndySSLHandler)
  private
    FCertFile: string;
    FKeyFile: string;
    FRootFile: string;
  public
    constructor Create(const ACertFile, AKeyFile, ARootFile: string);
    function CreateIOHandler(AServer: TIdCustomHTTPServer): TIdServerIOHandler;
  end;

implementation

{ TIndyTaurusSSLHandler }

constructor TIndyTaurusSSLHandler.Create(const ACertFile, AKeyFile, ARootFile: string);
begin
  inherited Create;
  FCertFile := ACertFile;
  FKeyFile := AKeyFile;
  FRootFile := ARootFile;
end;

function TIndyTaurusSSLHandler.CreateIOHandler(AServer: TIdCustomHTTPServer): TIdServerIOHandler;
{$IFDEF DEXT_ENABLE_TAURUS_TLS}
var
  LIOHandler: TTaurusTLSServerIOHandler;
{$ENDIF}
begin
  Result := nil;
  {$IFDEF DEXT_ENABLE_TAURUS_TLS}
  LIOHandler := TTaurusTLSServerIOHandler.Create(AServer);
  LIOHandler.SSLOptions.CertFile := FCertFile;
  LIOHandler.SSLOptions.KeyFile := FKeyFile;
  if FRootFile <> '' then
    LIOHandler.SSLOptions.RootCertFile := FRootFile;

  // Additional Taurus specific configurations if needed
  
  Result := LIOHandler;
  {$ELSE}
  Writeln('WARNING: Taurus TLS requested but DEXT_ENABLE_TAURUS_TLS is not defined.');
  {$ENDIF}
end;

end.
