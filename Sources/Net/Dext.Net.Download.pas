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
unit Dext.Net.Download;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.SysUtils;

const
  /// <summary>
  ///   How much of an error payload is kept while the gate is closed. An error
  ///   body is a message, not a payload: buffering it without a ceiling would
  ///   reintroduce the very memory problem streaming downloads exist to remove.
  /// </summary>
  DextDefaultErrorBufferLimit = 1024 * 1024;

type
  /// <summary>
  ///   Raised while the response body is being received, once per chunk.
  /// </summary>
  /// <remarks>
  ///   Called on the thread that performs the request, which for the REST
  ///   client is a worker thread -- a UI progress bar must marshal.
  /// </remarks>
  TDextReceiveProgress = reference to procedure(const AContentLength,
    AReadCount: Int64; var AAbort: Boolean);

  /// <summary>
  ///   Sits between the HTTP engine and the destination the caller handed us,
  ///   so that an error payload never reaches it.
  /// </summary>
  /// <remarks>
  ///   A streaming download writes straight into the caller's stream, which is
  ///   usually a file. That is the whole point -- and also the danger: when the
  ///   server answers 404, the engine writes the error page into it just as
  ///   happily, and what is left on disk is a file of the right name holding
  ///   HTML.
  ///
  ///   The gate starts CLOSED. While closed, everything written is kept in a
  ///   bounded buffer and the destination is not touched at all. It is opened
  ///   only once the status is known to be good, at which point the buffer is
  ///   flushed through and every later write goes straight to the destination.
  ///   If the gate is never opened, the destination is exactly as the caller
  ///   left it and <c>ErrorBytes</c> holds what the server actually said.
  ///
  ///   Seek/Size are forwarded too, because engines use them: the RTL rewinds
  ///   the response stream when it replays a request after a redirect or an
  ///   authentication challenge, and that rewind must not chop bytes the caller
  ///   already had in the file.
  /// </remarks>
  TDextDownloadGate = class(TStream)
  private
    FTarget: TStream;
    /// Where the destination stood when we were created. Everything we do is
    /// relative to this, so resuming into a partially written file works.
    FTargetBase: Int64;
    FOpen: Boolean;
    FBuffer: TMemoryStream;
    FBufferLimit: Int64;
    FDropped: Int64;
    function EnsureBuffer: TMemoryStream;
  protected
    function GetSize: Int64; override;
    procedure SetSize(const NewSize: Int64); override;
  public
    /// <param name="ATarget">
    ///   The caller's destination. Never written to before <c>Open</c>.
    /// </param>
    /// <param name="AErrorBufferLimit">
    ///   Ceiling for the bytes kept while closed. Beyond it the tail is
    ///   dropped and <c>ErrorTruncated</c> becomes True.
    /// </param>
    constructor Create(ATarget: TStream;
      AErrorBufferLimit: Int64 = DextDefaultErrorBufferLimit);
    destructor Destroy; override;

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    /// <summary>
    ///   Lets the bytes through: flushes whatever was buffered into the
    ///   destination and forwards everything from now on. Idempotent.
    /// </summary>
    procedure Open;

    /// <summary>What the server sent while the gate was closed.</summary>
    function ErrorBytes: TBytes;
    /// <summary>True when the error payload hit the ceiling and lost its tail.</summary>
    function ErrorTruncated: Boolean;
    /// <summary>True once <c>Open</c> has been called.</summary>
    property IsOpen: Boolean read FOpen;
    /// <summary>The destination stream this gate protects.</summary>
    property Target: TStream read FTarget;
  end;

implementation

{ TDextDownloadGate }

constructor TDextDownloadGate.Create(ATarget: TStream; AErrorBufferLimit: Int64);
begin
  inherited Create;
  if ATarget = nil then
    raise EArgumentNilException.Create('TDextDownloadGate: target stream is required');
  FTarget := ATarget;
  FTargetBase := ATarget.Position;
  FBufferLimit := AErrorBufferLimit;
  if FBufferLimit < 0 then
    FBufferLimit := 0;
  FOpen := False;
end;

destructor TDextDownloadGate.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

function TDextDownloadGate.EnsureBuffer: TMemoryStream;
begin
  if FBuffer = nil then
    FBuffer := TMemoryStream.Create;
  Result := FBuffer;
end;

procedure TDextDownloadGate.Open;
var
  Buf: TMemoryStream;
begin
  if FOpen then
    Exit;
  FOpen := True;
  if FBuffer = nil then
    Exit;
  // Hand over what arrived before we knew the status was good.
  Buf := FBuffer;
  FBuffer := nil;
  try
    Buf.Position := 0;
    if Buf.Size > 0 then
      FTarget.CopyFrom(Buf, Buf.Size);
  finally
    Buf.Free;
  end;
end;

function TDextDownloadGate.Write(const Buffer; Count: Longint): Longint;
var
  Room: Int64;
  Buf: TMemoryStream;
begin
  if FOpen then
    Exit(FTarget.Write(Buffer, Count));

  Buf := EnsureBuffer;
  Room := FBufferLimit - Buf.Size;
  if Room >= Count then
    Buf.Write(Buffer, Count)
  else
  begin
    // Keep the head, drop the tail: the head is where the message is.
    if Room > 0 then
      Buf.Write(Buffer, Room)
    else
      Room := 0;
    Inc(FDropped, Count - Room);
  end;
  // We always claim the whole write. Reporting a short write would make the
  // engine treat a capped error page as a disk failure.
  Result := Count;
end;

function TDextDownloadGate.Read(var Buffer; Count: Longint): Longint;
begin
  if FOpen then
    Result := FTarget.Read(Buffer, Count)
  else if FBuffer <> nil then
    Result := FBuffer.Read(Buffer, Count)
  else
    Result := 0;
end;

function TDextDownloadGate.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  if FOpen then
  begin
    case Origin of
      soBeginning:
        Result := FTarget.Seek(FTargetBase + Offset, soBeginning) - FTargetBase;
      soCurrent:
        Result := FTarget.Seek(Offset, soCurrent) - FTargetBase;
    else
      Result := FTarget.Seek(Offset, soEnd) - FTargetBase;
    end;
  end
  else
    Result := EnsureBuffer.Seek(Offset, Origin);
end;

function TDextDownloadGate.GetSize: Int64;
begin
  if FOpen then
    Result := FTarget.Size - FTargetBase
  else if FBuffer <> nil then
    Result := FBuffer.Size
  else
    Result := 0;
end;

procedure TDextDownloadGate.SetSize(const NewSize: Int64);
begin
  if FOpen then
    // Relative to where the caller's stream stood: a resumed download must not
    // lose the part that was already on disk.
    FTarget.Size := FTargetBase + NewSize
  else
  begin
    EnsureBuffer.Size := NewSize;
    if NewSize = 0 then
      FDropped := 0;
  end;
end;

function TDextDownloadGate.ErrorBytes: TBytes;
begin
  if (FBuffer = nil) or (FBuffer.Size = 0) then
    Exit(nil);
  SetLength(Result, FBuffer.Size);
  Move(FBuffer.Memory^, Result[0], FBuffer.Size);
end;

function TDextDownloadGate.ErrorTruncated: Boolean;
begin
  Result := FDropped > 0;
end;

end.
