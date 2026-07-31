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
unit Dext.Web.Indy.Server;
{$I Dext.inc}

interface

uses
  System.Classes, System.SysUtils, System.SyncObjs, IdHTTPServer, IdContext, IdCustomHTTPServer, IdCustomTCPServer, IdThread, IdServerIOHandler, IdException,
  Dext.Web.Interfaces, Dext.DI.Interfaces, Dext.Web.Indy.SSL.Interfaces, Dext.Hosting.ApplicationLifetime;

type
  TDextIndyWebServer = class(TInterfacedObject, IWebHost)
  private
    FHTTPServer: TIdHTTPServer;
    FPipeline: TRequestDelegate;
    FServices: IServiceProvider;
    FPort: Integer;
    FSSLHandler: IIndySSLHandler;
    FSSLEnabled: Boolean; // Tracks if SSL was successfully configured
    FLock: TCriticalSection;

    procedure ConfigureSecureServer;

    procedure HandleCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure HandleParseAuthentication(AContext: TIdContext;
      const AAuthType, AAuthData: string; var VUsername, VPassword: string; var Handled: Boolean);
    procedure HandleQuerySSLPort(APort: Word; var VUseSSL: Boolean);
    procedure HandleListenException(AThread: TIdListenerThread; AException: Exception);
    procedure HandleConnectException(AContext: TIdContext; AException: Exception);
  public
    constructor Create(APort: Integer; APipeline: TRequestDelegate; const AServices: IServiceProvider;
      const ASSLHandler: IIndySSLHandler = nil);
    destructor Destroy; override;

    function GetPort: Integer;
    procedure Run;
    procedure Start;
    procedure Stop;
  end;

implementation

uses
  Dext.Utils,
  Dext.Web.Indy,
{$IFDEF MSWINDOWS}
  Winapi.Windows
{$ENDIF}
{$IFDEF POSIX}
  Posix.Signal
{$ENDIF}
  ;

var
  GServerStopping: Boolean;

{$IFDEF MSWINDOWS}
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
{$ENDIF}

{$IFDEF POSIX}
procedure SignalHandler(Signal: Integer); cdecl;
begin
  GServerStopping := True;
end;
{$ENDIF}

{ TDextIndyWebServer }

constructor TDextIndyWebServer.Create(APort: Integer; APipeline: TRequestDelegate;
  const AServices: IServiceProvider; const ASSLHandler: IIndySSLHandler);
begin
  inherited Create;
  FPort := APort;
  FPipeline := APipeline;
  FServices := AServices;
  FSSLHandler := ASSLHandler;
  FSSLEnabled := False; // Default: no SSL

  FHTTPServer := TIdHTTPServer.Create(nil);
  FHTTPServer.DefaultPort := FPort;
  FHTTPServer.OnCommandOther := HandleCommandGet;
  FHTTPServer.OnCommandGet := HandleCommandGet;
  FHTTPServer.OnParseAuthentication := HandleParseAuthentication;
  FHTTPServer.OnListenException := HandleListenException;
  FHTTPServer.OnException := HandleConnectException;
  FHTTPServer.ParseParams := True;
  FHTTPServer.KeepAlive := True;
  FHTTPServer.ServerSoftware := 'Dext Web Server/1.0';

  FLock := System.SyncObjs.TCriticalSection.Create;

  if FSSLHandler <> nil then
    ConfigureSecureServer;
end;

procedure TDextIndyWebServer.ConfigureSecureServer;
var
  SSLIOHandler: TIdServerIOHandler;
begin
  if FSSLHandler <> nil then
  begin
    try
      SSLIOHandler := FSSLHandler.CreateIOHandler(FHTTPServer);
      if SSLIOHandler <> nil then
      begin
        FHTTPServer.IOHandler := SSLIOHandler;
        FHTTPServer.OnQuerySSLPort := HandleQuerySSLPort;
        FSSLEnabled := True; // Mark SSL as successfully configured
      end
      else
        SafeWriteLn('[WARN] SSL requested but IOHandler creation returned nil. Using HTTP.');
    except
      on E: Exception do
      begin
        SafeWriteLn('[ERROR] Failed to configure HTTPS: ' + E.Message);
        SafeWriteLn('[INFO] Falling back to HTTP.');
        FSSLEnabled := False;
      end;
    end;
  end;
end;

procedure TDextIndyWebServer.HandleParseAuthentication(AContext: TIdContext;
  const AAuthType, AAuthData: string; var VUsername, VPassword: string; var Handled: Boolean);
begin
  // Ignorar autenticação do Indy para permitir que o Middleware do Dext trate (ex: Bearer Token)
  // Se não fizermos isso, o Indy levanta uma exceção "Unsupported authorization scheme" para esquemas desconhecidos
  Handled := True;
end;

procedure TDextIndyWebServer.HandleQuerySSLPort(APort: Word; var VUseSSL: Boolean);
begin
  VUseSSL := FSSLEnabled;
end;

procedure TDextIndyWebServer.HandleListenException(AThread: TIdListenerThread; AException: Exception);
begin
  SafeWriteLn('[HTTPS Error] SSL/TLS Listen Exception: ' + AException.Message);
end;

procedure TDextIndyWebServer.HandleConnectException(AContext: TIdContext; AException: Exception);
begin
  if not (AException is EIdConnClosedGracefully) then
    SafeWriteLn('[HTTPS Error] SSL Handshake/Connection Exception: ' + AException.ClassName + ': ' + AException.Message);
end;

destructor TDextIndyWebServer.Destroy;
begin
  Stop;
  FHTTPServer.Free;
  FLock.Free;
  FPipeline := nil; // Explicitly break cycle/release reference
  inherited Destroy;
end;

procedure TDextIndyWebServer.HandleCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  DextContext: IHttpContext;
begin
  try
    // Criar contexto Dext a partir do request Indy
    DextContext := TDextIndyHttpContext.Create(AContext, ARequestInfo, AResponseInfo, FServices);

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

function TDextIndyWebServer.GetPort: Integer;
begin
  Result := FPort;
end;

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}
procedure TDextIndyWebServer.Start;
var
  Protocol: string;
begin
  if not FHTTPServer.Active then
  begin
    FHTTPServer.Active := True;

    // Capture actual port if dynamic port (0) was requested
    if (FPort = 0) and (FHTTPServer.Bindings.Count > 0) then
      FPort := FHTTPServer.Bindings[0].Port;

    Protocol := 'http';
    if FSSLEnabled then
      Protocol := 'https';

    SafeWriteLn(Format('Dext server running on %s://localhost:%d', [Protocol, FPort]));
    if FSSLEnabled then
      SafeWriteLn('HTTPS Enabled.');
  end;
end;

procedure TDextIndyWebServer.Run;
var
  LifetimeIntf: IInterface;
  Lifetime: IHostApplicationLifetime;
begin
  Start;

  // Check for automated test mode
  if FindCmdLineSwitch('no-wait', ['-', '/'], True) then
  begin
     SafeWriteLn('🤖 Automated test mode: Server started successfully. Exiting run loop.');
     Exit;
  end;

  SafeWriteLn('Press Ctrl+C to stop the server...');

  GServerStopping := False;
{$IFDEF MSWINDOWS}
  SetConsoleCtrlHandler(@ConsoleCtrlHandler, True);
{$ENDIF}
{$IFDEF POSIX}
  signal(SIGINT, @SignalHandler);
  signal(SIGTERM, @SignalHandler);
{$ENDIF}
  // Get Lifetime Service to observe external stop requests
  LifetimeIntf := FServices.GetServiceAsInterface(TServiceType.FromInterface(IHostApplicationLifetime));
  Lifetime := nil;
  if LifetimeIntf <> nil then
      Lifetime := LifetimeIntf as IHostApplicationLifetime;

  try
    while FHTTPServer.Active and (not GServerStopping) do
    begin
      Sleep(100);

      // Check for programatic shutdown request
      if (Lifetime <> nil) and (Lifetime.ApplicationStopping.IsCancellationRequested) then
      begin
         GServerStopping := True;
      end;
    end;
  finally
    // Use Stop() to ensure aggressive cleanup (socket force-close)
    // happens for Console apps too, preventing hangs on exit.
    if FHTTPServer.Active then
      Stop;

{$IFDEF MSWINDOWS}
    SetConsoleCtrlHandler(@ConsoleCtrlHandler, False);
{$ENDIF}
  end;
end;

procedure TDextIndyWebServer.Stop;
var
  LContexts: TList;
  i: Integer;
  Ctx: TIdContext;
begin
  FLock.Enter;
  try
    // Signal graceful stop
    GServerStopping := True;

    // 1. Aggressively close all sockets to unblock any stuck threads (SSE, etc)
    if (FHTTPServer <> nil) and FHTTPServer.Active then
    begin
      try
        LContexts := FHTTPServer.Contexts.LockList;
        try
          for i := LContexts.Count - 1 downto 0 do
          begin
            Ctx := TIdContext(LContexts[i]);

            // Force close the socket handle.
            // This causes an immediate EIdSocketError or similar in the worker thread,
            // breaking it out of blocking I/O calls.
            if (Ctx.Binding <> nil) and Ctx.Binding.HandleAllocated then
            begin
               try
                 Ctx.Binding.CloseSocket;
               except
                 // Ignore errors closing socket, we just want to ensure it's closed
               end;
            end;
          end;
        finally
          FHTTPServer.Contexts.UnlockList;
        end;
      except
        on E: Exception do
          SafeWriteLn('Error forcing socket close: ' + E.Message);
      end;

      // 2. Deactivate the server
      try
        FHTTPServer.Active := False;
      except
        // Silence exceptions during shutdown
      end;

      Sleep(200);
    end;
  finally
    FLock.Leave;
  end;
end;

end.
