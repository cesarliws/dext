unit Dext.Http.Indy.Server;

interface

uses
  System.Classes, System.SysUtils, IdHTTPServer, IdContext, IdCustomHTTPServer,
  Dext.Http.Interfaces, Dext.DI.Interfaces;

type
  TIndyWebServer = class(TInterfacedObject, IWebHost)
  private
    FHTTPServer: TIdHTTPServer;
    FPipeline: TRequestDelegate;
    FServices: IServiceProvider;
    FPort: Integer;

    procedure HandleCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure HandleParseAuthentication(AContext: TIdContext;
      const AAuthType, AAuthData: string; var VUsername, VPassword: string; var Handled: Boolean);
  public
    constructor Create(APort: Integer; APipeline: TRequestDelegate; const AServices: IServiceProvider);
    destructor Destroy; override;

    procedure Run;
    procedure Stop;
  end;

implementation

uses
  Dext.Http.Indy;

{ TIndyWebServer }

constructor TIndyWebServer.Create(APort: Integer; APipeline: TRequestDelegate;
  const AServices: IServiceProvider);
begin
  inherited Create;
  FPort := APort;
  FPipeline := APipeline;
  FServices := AServices;

  FHTTPServer := TIdHTTPServer.Create(nil);
  FHTTPServer.DefaultPort := FPort;
  FHTTPServer.OnCommandOther := HandleCommandGet;
  FHTTPServer.OnCommandGet := HandleCommandGet;
  FHTTPServer.OnParseAuthentication := HandleParseAuthentication;
  FHTTPServer.ParseParams := True;
  FHTTPServer.KeepAlive := True;
  FHTTPServer.ServerSoftware := 'Dext Web Server/1.0';
end;

procedure TIndyWebServer.HandleParseAuthentication(AContext: TIdContext;
  const AAuthType, AAuthData: string; var VUsername, VPassword: string; var Handled: Boolean);
begin
  // Ignorar autenticação do Indy para permitir que o Middleware do Dext trate (ex: Bearer Token)
  // Se não fizermos isso, o Indy levanta uma exceção "Unsupported authorization scheme" para esquemas desconhecidos
  Handled := True;
end;

destructor TIndyWebServer.Destroy;
begin
  Stop;
  FHTTPServer.Free;
  inherited Destroy;
end;

procedure TIndyWebServer.HandleCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  DextContext: IHttpContext;
begin
  try
    // Criar contexto Dext a partir do request Indy
    DextContext := TIndyHttpContext.Create(ARequestInfo, AResponseInfo, FServices);

    // Executar pipeline Dext
    FPipeline(DextContext);

  except
    on E: Exception do
    begin
      // Tratamento de erro genérico
      AResponseInfo.ResponseNo := 500;
      AResponseInfo.ContentText := 'Internal Server Error: ' + E.Message;
      AResponseInfo.ContentType := 'text/plain; charset=utf-8';
    end;
  end;
end;

procedure TIndyWebServer.Run;
begin
  if not FHTTPServer.Active then
  begin
    FHTTPServer.Active := True;
    Writeln(Format('Dext server running on http://localhost:%d', [FPort]));
    Writeln('Press Ctrl+C to stop the server...');

    // Manter o servidor rodando até ser explicitamente parado
    while FHTTPServer.Active do
    begin
      Sleep(100);
    end;
  end;
end;

procedure TIndyWebServer.Stop;
begin
  if FHTTPServer.Active then
  begin
    FHTTPServer.Active := False;
    Writeln('Dext server stopped.');
  end;
end;

end.
