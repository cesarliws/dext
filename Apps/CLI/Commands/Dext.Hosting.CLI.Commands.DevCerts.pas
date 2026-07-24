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
  Winapi.Windows,
  Dext.Hosting.CLI.Args,
  Dext.Utils;

type
  TDevCertsCommand = class(TInterfacedObject, IConsoleCommand)
  private
    procedure ShowUsage;
    function RunPowerShell(const Command: string): Boolean;
  public
    function GetName: string;
    function GetDescription: string;
    procedure Execute(const Args: TCommandLineArgs);
  end;

implementation

{ TDevCertsCommand }

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

function TDevCertsCommand.RunPowerShell(const Command: string): Boolean;
var
  ProcInfo: TProcessInformation;
  StartInfo: TStartupInfo;
  CmdLine: string;
  ExitCode: DWORD;
begin
  FillChar(StartInfo, SizeOf(StartInfo), 0);
  StartInfo.cb := SizeOf(StartInfo);
  StartInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartInfo.wShowWindow := SW_HIDE;

  CmdLine := 'powershell -NoProfile -ExecutionPolicy Bypass -Command "' + Command + '"';
  UniqueString(CmdLine);

  if not CreateProcess(nil, PChar(CmdLine), nil, nil, False, 0, nil, nil, StartInfo, ProcInfo) then
    Exit(False);

  WaitForSingleObject(ProcInfo.hProcess, INFINITE);
  GetExitCodeProcess(ProcInfo.hProcess, ExitCode);

  CloseHandle(ProcInfo.hProcess);
  CloseHandle(ProcInfo.hThread);

  Result := (ExitCode = 0);
end;

procedure TDevCertsCommand.Execute(const Args: TCommandLineArgs);
var
  CertFile: string;
  ShouldTrust: Boolean;
  PSCommand: string;
  CertAbsPath: string;
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

  SafeWriteLn('Generating development HTTPS certificate...');

  PSCommand := '$cert = New-SelfSignedCertificate -DnsName "localhost", "127.0.0.1" ' +
               '-CertStoreLocation "cert:\CurrentUser\My" -FriendlyName "Dext HTTPS Development Certificate" ' +
               '-KeyExportPolicy Exportable -KeySpec Signature; ' +
               '$certPath = "cert:\CurrentUser\My\" + $cert.Thumbprint; ' +
               'Export-Certificate -Cert $certPath -FilePath "' + CertFile + '" | Out-Null; ';

  SafeWriteLn('Creating certificate for localhost using PowerShell New-SelfSignedCertificate...');
  if not RunPowerShell(PSCommand) then
  begin
    SafeWriteLn('[ERROR] Failed to generate self-signed certificate.');
    Exit;
  end;

  CertAbsPath := TPath.GetFullPath(CertFile);
  SafeWriteLn('[SUCCESS] Certificate generated: ' + CertAbsPath);

  if ShouldTrust then
  begin
    SafeWriteLn('Trusting certificate in Windows Root Store (Trusted Root Certification Authorities)...');
    PSCommand := 'Import-Certificate -FilePath "' + CertAbsPath + '" -CertStoreLocation Cert:\LocalMachine\Root';
    if RunPowerShell(PSCommand) then
      SafeWriteLn('[SUCCESS] Certificate successfully trusted in Windows Root Store!')
    else
      SafeWriteLn('[WARN] Could not trust certificate automatically. Run dext CLI as Administrator.');
  end;
end;

end.
