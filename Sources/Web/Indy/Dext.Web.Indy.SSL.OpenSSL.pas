unit Dext.Web.Indy.SSL.OpenSSL;
{$I ..\..\Dext.inc}

interface

uses
  System.SysUtils,
  IdCustomHTTPServer, IdServerIOHandler,
  {$IFDEF DEXT_ENABLE_SSL}
  IdSSL, IdSSLOpenSSL,
  {$ENDIF}
  Dext.Web.Indy.SSL.Interfaces;

type
  { TIndyOpenSSLHandler
    Standard implementation using Indy's IdSSLOpenSSL (OpenSSL 1.0.x/1.1.x). }
  TIndyOpenSSLHandler = class(TInterfacedObject, IIndySSLHandler)
  private
    FCertFile: string;
    FKeyFile: string;
    FRootFile: string;
    // FPassword: string; // If we want to support passwords
  public
    constructor Create(const ACertFile, AKeyFile, ARootFile: string); reintroduce;
    function CreateIOHandler(AServer: TIdCustomHTTPServer): TIdServerIOHandler;
  end;

implementation

{ TIndyOpenSSLHandler }

constructor TIndyOpenSSLHandler.Create(const ACertFile, AKeyFile, ARootFile: string);
begin
  inherited Create;
  FCertFile := ACertFile;
  FKeyFile := AKeyFile;
  FRootFile := ARootFile;
end;

function TIndyOpenSSLHandler.CreateIOHandler(AServer: TIdCustomHTTPServer): TIdServerIOHandler;
{$IFDEF DEXT_ENABLE_SSL}
var
  LIOHandler: TIdServerIOHandlerSSLOpenSSL;
{$ENDIF}
begin
  Result := nil;
  {$IFDEF DEXT_ENABLE_SSL}
  LIOHandler := TIdServerIOHandlerSSLOpenSSL.Create(AServer);
  LIOHandler.SSLOptions.CertFile := FCertFile;
  LIOHandler.SSLOptions.KeyFile := FKeyFile;
  if FRootFile <> '' then
    LIOHandler.SSLOptions.RootCertFile := FRootFile;

  LIOHandler.SSLOptions.Mode := sslmServer;
  LIOHandler.SSLOptions.Method := sslvTLSv1_2;

  Result := LIOHandler;
  {$ELSE}
  // If SSL is not enabled via compiler directive, we could raise an exception or return nil.
  // Returning nil will likely cause the server to run without SSL or fail if it expects one.
  Writeln('WARNING: SSL requested but DEXT_ENABLE_SSL is not defined. Secure IOHandler not created.');
  {$ENDIF}
end;

end.
