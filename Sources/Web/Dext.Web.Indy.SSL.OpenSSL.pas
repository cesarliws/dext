unit Dext.Web.Indy.SSL.OpenSSL;

{$I Dext.inc}

interface

uses
  System.SysUtils,
  IdCustomHTTPServer, IdServerIOHandler,
  {$IFDEF DEXT_ENABLE_SSL}
  IdSSL, IdSSLOpenSSL,
  {$ENDIF}
  Dext.Web.Indy.SSL.Interfaces;

type
  { TDextIndyOpenSSLHandler
    Standard implementation using Indy's IdSSLOpenSSL (OpenSSL 1.0.x/1.1.x). }
  TDextIndyOpenSSLHandler = class(TInterfacedObject, IIndySSLHandler)
  private
    FCertFile: string;
    FKeyFile: string;
    FRootFile: string;
    procedure OnGetSSLPassword(var APassword: {$IF CompilerVersion < 27}AnsiString{$ELSE}string{$ENDIF});
  public
    constructor Create(const ACertFile, AKeyFile, ARootFile: string); reintroduce;
    function CreateIOHandler(AServer: TIdCustomHTTPServer): TIdServerIOHandler;
  end;

implementation

uses
  Dext.Utils;

{ TDextIndyOpenSSLHandler }

constructor TDextIndyOpenSSLHandler.Create(const ACertFile, AKeyFile, ARootFile: string);
begin
  inherited Create;
  FCertFile := ACertFile;
  FKeyFile := AKeyFile;
  FRootFile := ARootFile;
end;

procedure TDextIndyOpenSSLHandler.OnGetSSLPassword(var APassword: {$IF CompilerVersion < 27}AnsiString{$ELSE}string{$ENDIF});
begin
  APassword := '';
end;

function TDextIndyOpenSSLHandler.CreateIOHandler(AServer: TIdCustomHTTPServer): TIdServerIOHandler;
{$IFDEF DEXT_ENABLE_SSL}
var
  LIOHandler: TIdServerIOHandlerSSLOpenSSL;
{$ENDIF}
begin
  {$IFDEF DEXT_ENABLE_SSL}
  LIOHandler := TIdServerIOHandlerSSLOpenSSL.Create(AServer);
  LIOHandler.SSLOptions.CertFile := FCertFile;
  LIOHandler.SSLOptions.KeyFile := FKeyFile;
  if FRootFile <> '' then
    LIOHandler.SSLOptions.RootCertFile := FRootFile;

  LIOHandler.SSLOptions.Mode := sslmServer;
  LIOHandler.SSLOptions.Method := sslvSSLv23;
  LIOHandler.SSLOptions.SSLVersions := [sslvSSLv23, sslvSSLv3, sslvTLSv1, sslvTLSv1_1, sslvTLSv1_2];
  LIOHandler.SSLOptions.CipherList := '';
  LIOHandler.OnGetPassword := OnGetSSLPassword;

  SafeWriteLn('[HTTPS] Indy OpenSSL IOHandler initialized with Cert: ' + FCertFile + ' Key: ' + FKeyFile);
  Result := LIOHandler;
  {$ELSE}
  SafeWriteLn('[WARN] SSL requested but DEXT_ENABLE_SSL is not defined in Dext.inc, using HTTP.');
  Result := nil;
  {$ENDIF}
end;

end.
