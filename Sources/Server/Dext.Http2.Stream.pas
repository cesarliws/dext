{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
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
{  Created: 2026-06-18                                                      }
{                                                                           }
{  HTTP/2 stream state machine and flow control (RFC 9113 §5).              }
{  Uses an ordered array of streams with binary search for O(log n) lookup.}
{                                                                           }
{***************************************************************************}
unit Dext.Http2.Stream;

{$I Dext.inc}
{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.SysUtils,
  Dext.Http2.Hpack,
  Dext.Http2.Framing;

type
  /// <summary>
  ///   HTTP/2 stream lifecycle states (RFC 9113 §5.1).
  /// </summary>
  THttp2StreamState = (
    ssIdle,
    ssOpen,
    ssHalfClosedRemote,   // Client sent END_STREAM; server may still send
    ssHalfClosedLocal,    // Server sent END_STREAM; client may still send
    ssReservedRemote,     // Reserved by server push (parse only)
    ssReservedLocal,      // Reserved by server push (not generated)
    ssClosed
  );

  /// <summary>
  ///   Represents the accumulated state for a single HTTP/2 stream.
  ///   Streams are created on first HEADERS frame receipt and destroyed on close.
  /// </summary>
  TDextHttp2Stream = class
  private
    FStreamId: Cardinal;
    FState: THttp2StreamState;
    FRecvWindowSize: Integer;
    FSendWindowSize: Integer;
    FHeaders: TNameValuePairs;
    FHeadersComplete: Boolean;
    FHeaderBlockBuffer: TBytes;   // accumulates CONTINUATION fragments
    FHeaderBlockLen: Integer;
    FDataBuffer: TBytes;          // accumulated DATA payload
    FDataLen: Integer;
    FEndStreamReceived: Boolean;
    FErrorCode: Cardinal;
  public
    /// <summary>Creates a new stream in Idle state.</summary>
    /// <param name="AStreamId">The HTTP/2 stream identifier.</param>
    /// <param name="AInitialWindowSize">Initial send/recv flow control window size.</param>
    constructor Create(AStreamId: Cardinal; AInitialWindowSize: Integer);

    // ------------------------------------------------------------------
    //  State transitions
    // ------------------------------------------------------------------

    /// <summary>
    ///   Transitions stream from Idle to Open upon receiving a HEADERS frame.
    ///   Raises EInvalidOperation if not in Idle state.
    /// </summary>
    procedure Open;

    /// <summary>
    ///   Records that the remote peer has sent END_STREAM, closing its send side.
    ///   Transitions: Open → HalfClosedRemote, HalfClosedLocal → Closed.
    /// </summary>
    procedure RemoteEndStream;

    /// <summary>
    ///   Records that the local side has sent END_STREAM.
    ///   Transitions: Open → HalfClosedLocal, HalfClosedRemote → Closed.
    /// </summary>
    procedure LocalEndStream;

    /// <summary>Resets the stream to Closed state (RST_STREAM received or sent).</summary>
    procedure Reset(AErrorCode: Cardinal = 0);

    // ------------------------------------------------------------------
    //  Header accumulation (supports CONTINUATION frames)
    // ------------------------------------------------------------------

    /// <summary>Appends a raw header block fragment to the internal buffer.</summary>
    procedure AppendHeaderFragment(AData: PByte; ALen: Integer);

    /// <summary>
    ///   Finalizes header accumulation: decodes the buffer via HPACK.
    ///   Returns False if decoding fails.
    /// </summary>
    function FinalizeHeaders(ADecoder: THpackDecoder): Boolean;

    // ------------------------------------------------------------------
    //  Data accumulation
    // ------------------------------------------------------------------

    /// <summary>Appends DATA payload bytes to the internal data buffer.</summary>
    procedure AppendData(AData: PByte; ALen: Integer);

    // ------------------------------------------------------------------
    //  Flow control
    // ------------------------------------------------------------------

    /// <summary>
    ///   Consumes ABytes from the send window.
    ///   Returns False if the window would go negative (caller must not send).
    /// </summary>
    function ConsumeSendWindow(ABytes: Integer): Boolean;

    /// <summary>Increases the send window by AIncrement bytes (WINDOW_UPDATE received).</summary>
    procedure IncreaseSendWindow(AIncrement: Integer);

    /// <summary>Decreases the recv window as DATA is received from client.</summary>
    procedure ConsumeRecvWindow(ABytes: Integer);

    /// <summary>Resets the recv window (after sending WINDOW_UPDATE to client).</summary>
    procedure RefillRecvWindow(ABytes: Integer);

    // ------------------------------------------------------------------
    //  Properties
    // ------------------------------------------------------------------

    /// <summary>The unique stream identifier.</summary>
    property StreamId: Cardinal read FStreamId;
    /// <summary>Current stream lifecycle state.</summary>
    property State: THttp2StreamState read FState;
    /// <summary>Decoded request/response headers (available after FinalizeHeaders).</summary>
    property Headers: TNameValuePairs read FHeaders;
    /// <summary>True when the header block has been completely received and decoded.</summary>
    property HeadersComplete: Boolean read FHeadersComplete;
    /// <summary>Accumulated request body bytes.</summary>
    property DataBuffer: TBytes read FDataBuffer;
    /// <summary>Valid bytes in DataBuffer.</summary>
    property DataLen: Integer read FDataLen;
    /// <summary>True when the client has sent END_STREAM on this stream.</summary>
    property EndStreamReceived: Boolean read FEndStreamReceived;
    /// <summary>Current receive flow-control window size.</summary>
    property RecvWindowSize: Integer read FRecvWindowSize;
    /// <summary>Current send flow-control window size.</summary>
    property SendWindowSize: Integer read FSendWindowSize;
    /// <summary>Error code set on Reset (0 = no error).</summary>
    property ErrorCode: Cardinal read FErrorCode;
  end;

  /// <summary>
  ///   Maps stream identifiers to TDextHttp2Stream instances.
  ///   Uses a sorted array for cache-friendly O(log n) lookup via binary search.
  ///   Stream IDs are monotonically increasing so insertions are mostly O(1)
  ///   (append to end). Max concurrent streams is bounded by SETTINGS.
  /// </summary>
  TDextHttp2StreamMap = class
  private
    FIds: array of Cardinal;
    FStreams: array of TDextHttp2Stream;
    FCount: Integer;
    FInitialWindowSize: Integer;
    function BinarySearch(AId: Cardinal): Integer;
  public
    constructor Create(AInitialWindowSize: Integer = 65535);
    destructor Destroy; override;

    /// <summary>
    ///   Creates and registers a new stream with the given ID.
    ///   Raises EInvalidOperation if a stream with the same ID already exists.
    /// </summary>
    function OpenStream(AStreamId: Cardinal): TDextHttp2Stream;

    /// <summary>Looks up a stream by ID. Returns nil if not found.</summary>
    function Find(AStreamId: Cardinal): TDextHttp2Stream;

    /// <summary>
    ///   Removes and frees a stream by ID.
    ///   Does nothing if the stream is not found.
    /// </summary>
    procedure Remove(AStreamId: Cardinal);

    /// <summary>Returns the number of currently registered streams.</summary>
    function Count: Integer;

    /// <summary>Returns the stream at index AIndex (0-based, for iteration).</summary>
    function GetAt(AIndex: Integer): TDextHttp2Stream;

    /// <summary>Updates the initial window size for newly created streams.</summary>
    procedure SetInitialWindowSize(ASize: Integer);

    /// <summary>Applies a delta to all currently open stream send windows (RFC 9113 §6.9.2).</summary>
    procedure ApplyWindowSizeDelta(ADelta: Integer);

    /// <summary>Removes and frees all streams with State = ssClosed.</summary>
    procedure PurgeClosed;
  end;

implementation

{ TDextHttp2Stream }

constructor TDextHttp2Stream.Create(AStreamId: Cardinal; AInitialWindowSize: Integer);
begin
  inherited Create;
  FStreamId          := AStreamId;
  FState             := THttp2StreamState.ssIdle;
  FRecvWindowSize    := AInitialWindowSize;
  FSendWindowSize    := AInitialWindowSize;
  FHeadersComplete   := False;
  FHeaderBlockLen    := 0;
  FDataLen           := 0;
  FEndStreamReceived := False;
  FErrorCode         := 0;
end;

procedure TDextHttp2Stream.Open;
begin
  if FState <> THttp2StreamState.ssIdle then
    raise EInvalidOperation.CreateFmt(
      'Stream %d: cannot Open from state %d', [FStreamId, Ord(FState)]);
  FState := THttp2StreamState.ssOpen;
end;

procedure TDextHttp2Stream.RemoteEndStream;
begin
  FEndStreamReceived := True;
  case FState of
    THttp2StreamState.ssOpen:
      FState := THttp2StreamState.ssHalfClosedRemote;
    THttp2StreamState.ssHalfClosedLocal:
      FState := THttp2StreamState.ssClosed;
  end;
end;

procedure TDextHttp2Stream.LocalEndStream;
begin
  case FState of
    THttp2StreamState.ssOpen:
      FState := THttp2StreamState.ssHalfClosedLocal;
    THttp2StreamState.ssHalfClosedRemote:
      FState := THttp2StreamState.ssClosed;
  end;
end;

procedure TDextHttp2Stream.Reset(AErrorCode: Cardinal);
begin
  FState     := THttp2StreamState.ssClosed;
  FErrorCode := AErrorCode;
end;

procedure TDextHttp2Stream.AppendHeaderFragment(AData: PByte; ALen: Integer);
begin
  if FHeaderBlockLen + ALen > Length(FHeaderBlockBuffer) then
    SetLength(FHeaderBlockBuffer, FHeaderBlockLen + ALen + 256);
  if ALen > 0 then
    Move(AData^, FHeaderBlockBuffer[FHeaderBlockLen], ALen);
  Inc(FHeaderBlockLen, ALen);
end;

function TDextHttp2Stream.FinalizeHeaders(ADecoder: THpackDecoder): Boolean;
begin
  Result := ADecoder.Decode(@FHeaderBlockBuffer[0], FHeaderBlockLen, FHeaders);
  FHeadersComplete := Result;
end;

procedure TDextHttp2Stream.AppendData(AData: PByte; ALen: Integer);
begin
  if FDataLen + ALen > Length(FDataBuffer) then
    SetLength(FDataBuffer, FDataLen + ALen + 512);
  if ALen > 0 then
    Move(AData^, FDataBuffer[FDataLen], ALen);
  Inc(FDataLen, ALen);
end;

function TDextHttp2Stream.ConsumeSendWindow(ABytes: Integer): Boolean;
begin
  Result := FSendWindowSize >= ABytes;
  if Result then
    Dec(FSendWindowSize, ABytes);
end;

procedure TDextHttp2Stream.IncreaseSendWindow(AIncrement: Integer);
begin
  Inc(FSendWindowSize, AIncrement);
end;

procedure TDextHttp2Stream.ConsumeRecvWindow(ABytes: Integer);
begin
  Dec(FRecvWindowSize, ABytes);
end;

procedure TDextHttp2Stream.RefillRecvWindow(ABytes: Integer);
begin
  Inc(FRecvWindowSize, ABytes);
end;

{ TDextHttp2StreamMap }

constructor TDextHttp2StreamMap.Create(AInitialWindowSize: Integer);
begin
  inherited Create;
  FCount             := 0;
  FInitialWindowSize := AInitialWindowSize;
end;

destructor TDextHttp2StreamMap.Destroy;
var
  i: Integer;
begin
  for i := 0 to FCount - 1 do
    FStreams[i].Free;
  inherited;
end;

function TDextHttp2StreamMap.BinarySearch(AId: Cardinal): Integer;
var
  lo, hi, mid: Integer;
begin
  lo := 0;
  hi := FCount - 1;
  while lo <= hi do
  begin
    mid := (lo + hi) shr 1;
    if FIds[mid] = AId then Exit(mid);
    if FIds[mid] < AId then lo := mid + 1
    else hi := mid - 1;
  end;
  Result := -(lo + 1); // not found: return insertion point as negative
end;

function TDextHttp2StreamMap.OpenStream(AStreamId: Cardinal): TDextHttp2Stream;
var
  idx: Integer;
  insertAt: Integer;
  stream: TDextHttp2Stream;
begin
  idx := BinarySearch(AStreamId);
  if idx >= 0 then
    raise EInvalidOperation.CreateFmt('HTTP/2: stream %d already exists', [AStreamId]);

  insertAt := -(idx + 1);
  stream := TDextHttp2Stream.Create(AStreamId, FInitialWindowSize);

  // Grow arrays if needed
  if FCount >= Length(FIds) then
  begin
    SetLength(FIds, FCount + 16);
    SetLength(FStreams, FCount + 16);
  end;

  // Shift right to maintain sorted order
  if insertAt < FCount then
  begin
    Move(FIds[insertAt], FIds[insertAt + 1], (FCount - insertAt) * SizeOf(Cardinal));
    Move(FStreams[insertAt], FStreams[insertAt + 1], (FCount - insertAt) * SizeOf(Pointer));
  end;

  FIds[insertAt]     := AStreamId;
  FStreams[insertAt] := stream;
  Inc(FCount);
  Result := stream;
end;

function TDextHttp2StreamMap.Find(AStreamId: Cardinal): TDextHttp2Stream;
var
  idx: Integer;
begin
  idx := BinarySearch(AStreamId);
  if idx >= 0 then
    Result := FStreams[idx]
  else
    Result := nil;
end;

procedure TDextHttp2StreamMap.Remove(AStreamId: Cardinal);
var
  idx: Integer;
begin
  idx := BinarySearch(AStreamId);
  if idx < 0 then Exit;
  FStreams[idx].Free;
  // Shift left
  if idx < FCount - 1 then
  begin
    Move(FIds[idx + 1], FIds[idx], (FCount - idx - 1) * SizeOf(Cardinal));
    Move(FStreams[idx + 1], FStreams[idx], (FCount - idx - 1) * SizeOf(Pointer));
  end;
  Dec(FCount);
end;

function TDextHttp2StreamMap.Count: Integer;
begin
  Result := FCount;
end;

function TDextHttp2StreamMap.GetAt(AIndex: Integer): TDextHttp2Stream;
begin
  if (AIndex < 0) or (AIndex >= FCount) then
    raise EArgumentOutOfRangeException.CreateFmt('StreamMap index %d out of range', [AIndex]);
  Result := FStreams[AIndex];
end;

procedure TDextHttp2StreamMap.SetInitialWindowSize(ASize: Integer);
begin
  FInitialWindowSize := ASize;
end;

procedure TDextHttp2StreamMap.ApplyWindowSizeDelta(ADelta: Integer);
var
  i: Integer;
begin
  for i := 0 to FCount - 1 do
    FStreams[i].IncreaseSendWindow(ADelta);
end;

procedure TDextHttp2StreamMap.PurgeClosed;
var
  i: Integer;
begin
  i := 0;
  while i < FCount do
  begin
    if FStreams[i].State = THttp2StreamState.ssClosed then
      Remove(FStreams[i].StreamId)
    else
      Inc(i);
  end;
end;

end.
