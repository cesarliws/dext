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
  Dext.Http.Indy, WinApi.Windows;

var
  GServerStopping: Boolean;

function ConsoleCtrlHandler(dwCtrlType: DWORD): BOOL; stdcall;
begin
  if (dwCtrlType = CTRL_C_EVENT) or (dwCtrlType = CTRL_BREAK_EVENT) then
  begin
    GServerStopping := True;
    Result := True;
  end
  else
    Result := False;
end;

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
  // Ignorar autenticaÃ§Ã£o do Indy para permitir que o Middleware do Dext trate (ex: Bearer Token)
  // Se nÃ£o fizermos isso, o Indy levanta uma exceÃ§Ã£o "Unsupported authorization scheme" para esquemas desconhecidos
  Handled := True;
end;

destructor TIndyWebServer.Destroy;
begin
  Stop;
  FHTTPServer.Free;
  FPipeline := nil; // Explicitly break cycle/release reference
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
      // Tratamento de erro genÃ©rico
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

    GServerStopping := False;
    SetConsoleCtrlHandler(@ConsoleCtrlHandler, True);
    try
      while FHTTPServer.Active and (not GServerStopping) do
      begin
        Sleep(100);
        // Also check if any key pressed to exit?
        // For now, Ctrl+C is the standard way.
      end;
    finally
      SetConsoleCtrlHandler(@ConsoleCtrlHandler, False);
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

