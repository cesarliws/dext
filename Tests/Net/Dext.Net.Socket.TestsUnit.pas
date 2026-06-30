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
{  Author:  Cesar Romero & Antigravity AI                                   }
{  Created: 2026-06-29                                                      }
{                                                                           }
{  Unit and integration tests for raw TCP/UDP socket exposing.              }
{                                                                           }
{***************************************************************************}
unit Dext.Net.Socket.TestsUnit;

interface

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Net.Tcp,
  Dext.Net.Udp,
  Dext.Core.Span;

type
  [TestFixture('Dext.Net TCP')]
  TDextTcpTests = class
  public
    [Test]
    procedure Tcp_Echo_ShouldRoundTripBytes;
  end;

  [TestFixture('Dext.Net UDP')]
  TDextUdpTests = class
  public
    [Test]
    procedure Udp_Echo_ShouldRoundTripPacket;
  end;

implementation

procedure TDextTcpTests.Tcp_Echo_ShouldRoundTripBytes;
var
  server: TDextTcpServer;
  client: TDextTcpClient;
  sent: TBytes;
  received: TBytes;
  readCount: Integer;
begin
  server := TDextTcpServer.Create;
  try
    server.OnDataSpan :=
      procedure(const AConnection: ITcpConnection; const AData: TByteSpan)
      begin
        AConnection.Send(AData);
      end;

    server.Bind('127.0.0.1', 0);
    server.Start;

    client := TDextTcpClient.Create;
    try
      client.Connect('127.0.0.1', server.ListenPort);
      sent := TBytes.Create($44, $65, $78, $74);
      client.Send(sent);

      SetLength(received, Length(sent));
      readCount := client.Receive(received, 2000);

      Should(readCount).Be(Length(sent));
      Should(received[0]).Be(sent[0]);
      Should(received[1]).Be(sent[1]);
      Should(received[2]).Be(sent[2]);
      Should(received[3]).Be(sent[3]);
    finally
      client.Free;
    end;
  finally
    server.Free;
  end;
end;

procedure TDextUdpTests.Udp_Echo_ShouldRoundTripPacket;
var
  server: TDextUdpServer;
  client: TDextUdpClient;
  sent: TBytes;
  received: TUdpPacket;
  ok: Boolean;
begin
  server := TDextUdpServer.Create;
  try
    server.OnPacketSpanReceived :=
      procedure(const APacket: TUdpSpanPacket)
      begin
        server.SendTo(APacket.RemoteAddress, APacket.RemotePort, APacket.Data);
      end;

    server.Bind('127.0.0.1', 0);
    server.Start;

    client := TDextUdpClient.Create;
    try
      sent := TBytes.Create($55, $44, $50);
      client.Send('127.0.0.1', server.ListenPort, sent);
      ok := client.Receive(received, 2000);

      Should(ok).BeTrue;
      Should(Length(received.Data)).Be(Length(sent));
      Should(received.Data[0]).Be(sent[0]);
      Should(received.Data[1]).Be(sent[1]);
      Should(received.Data[2]).Be(sent[2]);
    finally
      client.Free;
    end;
  finally
    server.Free;
  end;
end;

initialization
  TTestRunner.RegisterFixture(TDextTcpTests);
  TTestRunner.RegisterFixture(TDextUdpTests);

end.
