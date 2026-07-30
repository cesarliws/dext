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
unit TRestClient_Streaming_Tests;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Net.Download,
  Dext.Net.RestClient,
  Dext.Net.RestRequest;

type
  [TestFixture('TRestClient streaming download (S58)')]
  TDextDownloadGateTests = class
  public
    [Test]
    procedure ClosedGate_ShouldLeaveTargetUntouched;
    [Test]
    procedure Open_ShouldFlushBufferedBytesThenForward;
    [Test]
    procedure Resume_ShouldHonourTargetPosition;
    [Test]
    procedure Replay_ShouldNotDropPreExistingBytes;
    [Test]
    procedure ErrorPayload_ShouldBeCapped;
    [Test]
    procedure EmptySuccess_ShouldWriteNothing;

    // --- la superficie pubblica del client ---
    [Test]
    procedure ExecuteIntoAsync_ShouldRejectANilTarget;
    [Test]
    procedure OnReceive_ShouldBeStoredOnTheClient;
    [Test]
    procedure OnReceive_OnTheRequest_ShouldReplaceTheClientOne;
  end;

implementation

type
  /// Stesso accesso al campo privato usato da Tests\Web (TTRestRequestHack):
  /// il builder e' un record che tiene lo stato in un'interfaccia.
  TRestRequestPeek = record
    Data: IRestRequestData;
  end;

function TextOf(AStream: TMemoryStream): string;
var
  Bytes: TBytes;
begin
  SetLength(Bytes, AStream.Size);
  if AStream.Size > 0 then
    Move(AStream.Memory^, Bytes[0], AStream.Size);
  Result := TEncoding.UTF8.GetString(Bytes);
end;

procedure WriteText(AStream: TStream; const AText: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(AText);
  AStream.WriteBuffer(Bytes[0], Length(Bytes));
end;

{ TDextDownloadGateTests }

/// The 404 case: what the server said must not end up in the caller's file.
procedure TDextDownloadGateTests.ClosedGate_ShouldLeaveTargetUntouched;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  Gate := TDextDownloadGate.Create(Target);
  try
    WriteText(Gate, '{"error":"not found"}');

    Should(Integer(Target.Size)).Be(0);
    Should(Gate.IsOpen).BeFalse;
    Should(Length(Gate.ErrorBytes)).Be(21);
    Should(Gate.ErrorTruncated).BeFalse;
  finally
    Gate.Free;
    Target.Free;
  end;
end;

/// Bytes that arrived before the status was known are not lost.
procedure TDextDownloadGateTests.Open_ShouldFlushBufferedBytesThenForward;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  Gate := TDextDownloadGate.Create(Target);
  try
    WriteText(Gate, 'HEAD');
    Should(Integer(Target.Size)).Be(0);

    Gate.Open;
    Should(Integer(Target.Size)).Be(4);

    WriteText(Gate, 'TAIL');
    Should(TextOf(Target)).Be('HEADTAIL');
  finally
    Gate.Free;
    Target.Free;
  end;
end;

/// A resumed download appends instead of overwriting.
procedure TDextDownloadGateTests.Resume_ShouldHonourTargetPosition;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  try
    WriteText(Target, 'ALREADY-ON-DISK:');
    Gate := TDextDownloadGate.Create(Target);
    try
      Gate.Open;
      WriteText(Gate, 'REST');

      Should(TextOf(Target)).Be('ALREADY-ON-DISK:REST');
      // Size is what THIS transfer wrote, not what the file holds.
      Should(Integer(Gate.Size)).Be(4);
    finally
      Gate.Free;
    end;
  finally
    Target.Free;
  end;
end;

/// What the RTL does when it replays a request after a redirect or an
/// authentication challenge: it rewinds the response stream. That rewind must
/// stop at the bytes the caller already had.
procedure TDextDownloadGateTests.Replay_ShouldNotDropPreExistingBytes;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  try
    WriteText(Target, 'ALREADY-ON-DISK:');
    Gate := TDextDownloadGate.Create(Target);
    try
      Gate.Open;
      WriteText(Gate, 'FIRST-ATTEMPT');

      Gate.Size := 0;
      Gate.Position := 0;
      Should(Integer(Target.Size)).Be(16);

      WriteText(Gate, 'AGAIN');
      Should(TextOf(Target)).Be('ALREADY-ON-DISK:AGAIN');
    finally
      Gate.Free;
    end;
  finally
    Target.Free;
  end;
end;

/// An error body is a message, not a payload: buffering it must have a ceiling.
procedure TDextDownloadGateTests.ErrorPayload_ShouldBeCapped;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
  Big: TBytes;
begin
  Target := TMemoryStream.Create;
  Gate := TDextDownloadGate.Create(Target, 100);
  try
    SetLength(Big, 250);
    FillChar(Big[0], Length(Big), Ord('x'));
    Gate.WriteBuffer(Big[0], Length(Big));

    Should(Length(Gate.ErrorBytes)).Be(100);
    Should(Gate.ErrorTruncated).BeTrue;
    Should(Integer(Target.Size)).Be(0);
  finally
    Gate.Free;
    Target.Free;
  end;
end;

/// A 2xx with no body never fires the engine's progress callback, so the gate
/// is opened on the status instead. That must not invent bytes.
procedure TDextDownloadGateTests.EmptySuccess_ShouldWriteNothing;
var
  Target: TMemoryStream;
  Gate: TDextDownloadGate;
begin
  Target := TMemoryStream.Create;
  Gate := TDextDownloadGate.Create(Target);
  try
    Gate.Open;

    Should(Integer(Target.Size)).Be(0);
    Should(Length(Gate.ErrorBytes)).Be(0);
  finally
    Gate.Free;
    Target.Free;
  end;
end;

/// Uno stream di destinazione non e' opzionale: senza, non c'e' streaming.
procedure TDextDownloadGateTests.ExecuteIntoAsync_ShouldRejectANilTarget;
var
  Client: TRestClient;
  Failed: Boolean;
begin
  Client := TRestClient.Create('http://localhost:1');
  Failed := False;
  try
    Client.Instance.ExecuteIntoAsync(hmGET, '/x', nil);
  except
    on E: EArgumentNilException do
      Failed := True;
  end;
  Should(Failed).BeTrue;
end;

/// L'handler globale si posa sul client e si rilegge da li'.
procedure TDextDownloadGateTests.OnReceive_ShouldBeStoredOnTheClient;
var
  Client: TRestClient;
begin
  Client := TRestClient.Create('http://localhost:1');
  Should(Assigned(Client.Instance.ReceiveHandler)).BeFalse;

  Client.OnReceive(
    procedure(const AContentLength, AReadCount: Int64; var AAbort: Boolean)
    begin
    end);

  Should(Assigned(Client.Instance.ReceiveHandler)).BeTrue;
end;

/// Quello di richiesta SOSTITUISCE quello del client: non si sommano, e il
/// globale resta al suo posto per le altre richieste.
procedure TDextDownloadGateTests.OnReceive_OnTheRequest_ShouldReplaceTheClientOne;
var
  Client: TRestClient;
  Req: TRestRequest;
  Chiamato: string;
  Abort: Boolean;
  Handler, Globale: TRestReceiveAnonEvent;
begin
  Chiamato := '';
  Client := TRestClient.Create('http://localhost:1');
  Client.OnReceive(
    procedure(const AContentLength, AReadCount: Int64; var AAbort: Boolean)
    begin
      Chiamato := 'client';
    end);

  Req := Client.Request(hmGET, '/x').OnReceive(
    procedure(const AContentLength, AReadCount: Int64; var AAbort: Boolean)
    begin
      Chiamato := 'richiesta';
    end);

  // Quello che verrebbe usato per QUESTA richiesta.
  Handler := TRestRequestPeek(Req).Data.GetReceiveHandler;
  Should(Assigned(Handler)).BeTrue;
  Abort := False;
  Handler(0, 0, Abort);
  Should(Chiamato).Be('richiesta');

  // Il globale non e' stato toccato.
  Chiamato := '';
  Globale := Client.Instance.ReceiveHandler;
  Globale(0, 0, Abort);
  Should(Chiamato).Be('client');
end;

end.
