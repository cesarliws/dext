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
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-07-23                                                      }
{                                                                           }
{  Unified SSL/TLS abstraction layer for Dext Framework.                     }
{                                                                           }
{***************************************************************************}
unit Dext.Net.Security;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.SysUtils;

type
  /// <summary>Supported TLS protocol versions.</summary>
  TDextTLSVersion = (tls1_0, tls1_1, tls1_2, tls1_3);
  TDextTLSVersions = set of TDextTLSVersion;

  /// <summary>Operating mode for TLS engine.</summary>
  TDextTLSMode = (tlsmClient, tlsmServer);

  /// <summary>Unified SSL/TLS configuration options record.</summary>
  TDextTLSOptions = record
    Enabled: Boolean;
    Mode: TDextTLSMode;
    CertFile: string;
    KeyFile: string;
    RootCertFile: string;
    CertHash: string;
    StoreName: string;
    Protocols: TDextTLSVersions;
    VerifyServerCertificate: Boolean;
    ALPNProtocols: TArray<string>;
    Provider: string; // 'Auto', 'OpenSSL', 'HttpSys', 'Indy'

    class function DefaultClient: TDextTLSOptions; static;
    class function DefaultServer(const ACertFile, AKeyFile: string): TDextTLSOptions; static;
  end;

  /// <summary>Status of asynchronous TLS engine processing.</summary>
  TDextTLSEngineStatus = (
    tlsHandshakeNeedRead,
    tlsHandshakeNeedWrite,
    tlsHandshakeCompleted,
    tlsDataReady,
    tlsError
  );

  /// <summary>
  ///   Core abstraction for asynchronous, memory-based TLS engine (Memory BIOs).
  ///   Decouples network IO from encryption logic.
  /// </summary>
  IDextTLSEngine = interface
    ['{F5C6D7E8-F9A0-4B1C-8D2E-3F4A5B6C7D8E}']
    /// <summary>Processes raw encrypted incoming network data into the engine.</summary>
    function EncryptedIncoming(const ABuffer: Pointer; ACount: Integer): Integer;
    /// <summary>Reads decrypted plaintext payload out of the engine.</summary>
    function PlaintextRead(const ABuffer: Pointer; ACount: Integer): Integer;
    /// <summary>Writes plaintext payload into the engine for encryption.</summary>
    function PlaintextWrite(const ABuffer: Pointer; ACount: Integer): Integer;
    /// <summary>Reads encrypted outgoing network payload ready to be sent over socket.</summary>
    function EncryptedOutgoing(const ABuffer: Pointer; ACount: Integer): Integer;

    /// <summary>Drives the TLS handshake process forward.</summary>
    function DoHandshake: TDextTLSEngineStatus;
    /// <summary>Returns true if the TLS handshake has completed.</summary>
    function IsHandshakeCompleted: Boolean;
    /// <summary>Returns negotiated ALPN protocol if present (e.g. 'h2', 'http/1.1').</summary>
    function GetNegotiatedALPN: string;
  end;

  /// <summary>
  ///   Factory interface to initialize SSL/TLS Contexts.
  /// </summary>
  IDextTLSContextProvider = interface
    ['{E4D3C2B1-A0F9-4E8D-7C6B-5A4F3E2D1C0B}']
    function CreateEngine(AMode: TDextTLSMode): IDextTLSEngine;
    function GetOptions: TDextTLSOptions;
  end;

  /// <summary>
  ///   Stream wrapper that provides transparent TLS encryption over standard TStream.
  /// </summary>
  IDextTLSStream = interface
    ['{D3C2B1A0-F9E8-4D7C-6B5A-4F3E2D1C0B9A}']
    function GetUnderlyingStream: TStream;
    function Read(const ABuffer: Pointer; ACount: Longint): Longint;
    function Write(const ABuffer: Pointer; ACount: Longint): Longint;
  end;

implementation

{ TDextTLSOptions }

class function TDextTLSOptions.DefaultClient: TDextTLSOptions;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Enabled := True;
  Result.Mode := tlsmClient;
  Result.Protocols := [tls1_2, tls1_3];
  Result.VerifyServerCertificate := True;
  Result.Provider := 'Auto';
end;

class function TDextTLSOptions.DefaultServer(const ACertFile, AKeyFile: string): TDextTLSOptions;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Enabled := True;
  Result.Mode := tlsmServer;
  Result.CertFile := ACertFile;
  Result.KeyFile := AKeyFile;
  Result.Protocols := [tls1_2, tls1_3];
  Result.StoreName := 'MY';
  Result.Provider := 'Auto';
end;

end.
