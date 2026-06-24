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

function TServerEngineOptionsHelper.WithBindAddress(const AAddress: string): TServerEngineOptions;
begin
  Self.BindAddress := AAddress;
  Result := Self;
end;

end.
