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
{  Created: 2026-06-17                                                      }
{                                                                           }
{  Configuration options and types for native server engines.               }
{                                                                           }
{***************************************************************************}
unit Dext.Server.Engine.Types;

interface

uses
  System.SysUtils;

{$SCOPEDENUMS ON}

type
  /// <summary>
  ///   Configuration options for the Dext high-performance server engines.
  /// </summary>
  TServerEngineOptions = record
    /// <summary>Number of I/O worker threads. 0 means auto-detect (CPU count).</summary>
    IoThreadCount: Integer;
    /// <summary>Size of the receive buffer per connection in bytes (default: 8192).</summary>
    ReceiveBufferSize: Integer;
    /// <summary>Maximum concurrent connections. 0 means unlimited.</summary>
    MaxConnections: Integer;
    /// <summary>Graceful shutdown drain timeout in milliseconds (default: 5000).</summary>
    ShutdownTimeoutMs: Integer;
    /// <summary>Enable Keep-Alive (default: True).</summary>
    KeepAlive: Boolean;
    /// <summary>Keep-Alive timeout in seconds (default: 120).</summary>
    KeepAliveTimeoutSec: Integer;
    /// <summary>The IP address or host to bind the server to (default: '0.0.0.0').</summary>
    BindAddress: string;
    /// <summary>Max threads for task executor (default: 0 - inline).</summary>
    MaxExecutorThreads: Integer;
    /// <summary>Max queue capacity for task executor (default: 1024).</summary>
    MaxQueueCapacity: Integer;
    /// <summary>Outstanding Http.Sys receives per I/O worker (default: 2).</summary>
    OutstandingReceiveDepth: Integer;
    /// <summary>Maximum accepted native request-header buffer size.</summary>
    MaxRequestHeaderSize: Integer;
    /// <summary>Maximum accepted request body size.</summary>
    MaxRequestBodySize: Int64;
    /// <summary>Enable HTTPS/SSL on the server engine (default: False).</summary>
    UseHttps: Boolean;

    /// <summary>Creates a default configuration options record.</summary>
    class function Default: TServerEngineOptions; static;
  end;

  /// <summary>
  ///   Fluent helper for TServerEngineOptions to chain configurations.
  /// </summary>
  TServerEngineOptionsHelper = record helper for TServerEngineOptions
    /// <summary>Configures the number of worker I/O threads.</summary>
    /// <param name="ACount">Number of threads (0 for CPU count auto-detection).</param>
    function WithIoThreads(ACount: Integer): TServerEngineOptions;
    /// <summary>Configures the connection socket read/receive buffer size.</summary>
    /// <param name="ASize">Buffer size in bytes.</param>
    function WithReceiveBufferSize(ASize: Integer): TServerEngineOptions;
    /// <summary>Configures the maximum concurrent connections limit.</summary>
    /// <param name="AConnections">Connections limit (0 for unlimited).</param>
    function WithMaxConnections(AConnections: Integer): TServerEngineOptions;
    /// <summary>Configures the graceful shutdown timeout.</summary>
    /// <param name="ATimeoutMs">Timeout duration in milliseconds.</param>
    function WithShutdownTimeout(ATimeoutMs: Integer): TServerEngineOptions;
    /// <summary>Configures keep-alive socket configuration.</summary>
    /// <param name="AEnable">True to enable keep-alive.</param>
    /// <param name="ATimeoutSec">Keep-alive timeout in seconds.</param>
    function WithKeepAlive(AEnable: Boolean; ATimeoutSec: Integer = 120): TServerEngineOptions;
    /// <summary>Configures the server bind address (e.g. '0.0.0.0', '127.0.0.1', or '+').</summary>
    /// <param name="AAddress">The bind address string.</param>
    function WithBindAddress(const AAddress: string): TServerEngineOptions;
    /// <summary>Configures max threads for request executor pool.</summary>
    function WithMaxExecutorThreads(ACount: Integer): TServerEngineOptions;
    /// <summary>Configures max queue capacity for request executor.</summary>
    function WithMaxQueueCapacity(ACapacity: Integer): TServerEngineOptions;
    /// <summary>Configures outstanding Http.Sys receives per worker (1..8).</summary>
    function WithOutstandingReceiveDepth(
      ADepth: Integer): TServerEngineOptions;
    /// <summary>Configures native request header and body size limits.</summary>
    function WithRequestSizeLimits(AHeaderBytes: Integer;
      ABodyBytes: Int64): TServerEngineOptions;
  end;

  /// <summary>
  ///   Common low-level HTTP parsing helper utilities for raw byte buffers.
  /// </summary>
  TDextHttpParserCommon = record
  public
    class function FindByte(const ABuffer: TBytes; AStart, AEnd: Integer; AByte: Byte): Integer; static; inline;
    class function FindCRLF(const ABuffer: TBytes; AStart, AEnd: Integer): Integer; static; inline;
    class function CompareBytesCI(const ABuffer: TBytes; AStart, ALen: Integer; const AStr: string): Boolean; static; inline;
  end;

implementation

{ TServerEngineOptions }

class function TServerEngineOptions.Default: TServerEngineOptions;
begin
  Result.IoThreadCount := 0;
  Result.ReceiveBufferSize := 8192;
  Result.MaxConnections := 0;
  Result.ShutdownTimeoutMs := 5000;
  Result.KeepAlive := True;
  Result.KeepAliveTimeoutSec := 120;
  Result.BindAddress := '0.0.0.0';
  Result.MaxExecutorThreads := 0;
  Result.MaxQueueCapacity := 1024;
  Result.OutstandingReceiveDepth := 2;
  Result.MaxRequestHeaderSize := 64 * 1024;
  Result.MaxRequestBodySize := 16 * 1024 * 1024;
  Result.UseHttps := False;
end;

{ TServerEngineOptionsHelper }

function TServerEngineOptionsHelper.WithIoThreads(ACount: Integer): TServerEngineOptions;
begin
  Self.IoThreadCount := ACount;
  Result := Self;
end;

function TServerEngineOptionsHelper.WithReceiveBufferSize(ASize: Integer): TServerEngineOptions;
begin
  Self.ReceiveBufferSize := ASize;
  Result := Self;
end;

function TServerEngineOptionsHelper.WithMaxConnections(AConnections: Integer): TServerEngineOptions;
begin
  Self.MaxConnections := AConnections;
  Result := Self;
end;

function TServerEngineOptionsHelper.WithShutdownTimeout(ATimeoutMs: Integer): TServerEngineOptions;
begin
  Self.ShutdownTimeoutMs := ATimeoutMs;
  Result := Self;
end;

function TServerEngineOptionsHelper.WithKeepAlive(AEnable: Boolean; ATimeoutSec: Integer): TServerEngineOptions;
begin
  Self.KeepAlive := AEnable;
  Self.KeepAliveTimeoutSec := ATimeoutSec;
  Result := Self;
end;

function TServerEngineOptionsHelper.WithBindAddress(
  const AAddress: string): TServerEngineOptions;
begin
  Self.BindAddress := AAddress;
  Result := Self;
end;

function TServerEngineOptionsHelper.WithMaxExecutorThreads(
  ACount: Integer): TServerEngineOptions;
begin
  Self.MaxExecutorThreads := ACount;
  Result := Self;
end;

function TServerEngineOptionsHelper.WithMaxQueueCapacity(
  ACapacity: Integer): TServerEngineOptions;
begin
  Self.MaxQueueCapacity := ACapacity;
  Result := Self;
end;

function TServerEngineOptionsHelper.WithOutstandingReceiveDepth(
  ADepth: Integer): TServerEngineOptions;
begin
  if ADepth < 1 then
    ADepth := 1
  else if ADepth > 8 then
    ADepth := 8;
  Self.OutstandingReceiveDepth := ADepth;
  Result := Self;
end;

function TServerEngineOptionsHelper.WithRequestSizeLimits(
  AHeaderBytes: Integer; ABodyBytes: Int64): TServerEngineOptions;
begin
  Self.MaxRequestHeaderSize := AHeaderBytes;
  Self.MaxRequestBodySize := ABodyBytes;
  Result := Self;
end;

{ TDextHttpParserCommon }

class function TDextHttpParserCommon.FindByte(const ABuffer: TBytes; AStart, AEnd: Integer; AByte: Byte): Integer;
var
  I: Integer;
begin
  for I := AStart to AEnd - 1 do
    if ABuffer[I] = AByte then
      Exit(I);
  Result := -1;
end;

class function TDextHttpParserCommon.FindCRLF(const ABuffer: TBytes; AStart, AEnd: Integer): Integer;
var
  I: Integer;
begin
  for I := AStart to AEnd - 2 do
    if (ABuffer[I] = 13) and (ABuffer[I+1] = 10) then
      Exit(I);
  Result := -1;
end;

class function TDextHttpParserCommon.CompareBytesCI(const ABuffer: TBytes; AStart, ALen: Integer; const AStr: string): Boolean;
var
  I: Integer;
  B1, B2: Byte;
  PStr: PChar;
begin
  if ALen <> Length(AStr) then Exit(False);
  PStr := PChar(AStr);
  for I := 0 to ALen - 1 do
  begin
    B1 := ABuffer[AStart + I];
    B2 := Ord(PStr[I]);
    if (B1 >= 65) and (B1 <= 90) then B1 := B1 + 32;
    if (B2 >= 65) and (B2 <= 90) then B2 := B2 + 32;
    if B1 <> B2 then Exit(False);
  end;
  Result := True;
end;

end.
