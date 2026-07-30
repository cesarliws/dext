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
unit Dext.Net.Download.Tests;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Net.Download;

type
  [TestFixture('Dext.Net streaming download')]
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
  end;

implementation

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

end.
