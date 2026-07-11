{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}
unit Dext.Grpc.Codec;

interface

uses
  System.SysUtils,
  Dext.Core.Span;

type
  /// <summary>
  ///   Reader / Writer for gRPC Length-Prefixed Messages (LPM).
  /// </summary>
  TGrpcMessageCodec = record
  public
    class function TryDecode(const Buffer: TBytes; var Offset: Integer;
      var Compressed: Boolean; out MsgBytes: TBytes): Boolean; overload; static;
    class function TryDecode(const Buffer: TBytes; var Offset: Integer;
      var Compressed: Boolean; out MsgSpan: TByteSpan): Boolean; overload; static;
    class function Encode(const MsgBytes: TBytes;
      Compress: Boolean = False): TBytes; overload; static;
    class function Encode(const MsgSpan: TByteSpan;
      Compress: Boolean = False): TBytes; overload; static;
  end;

implementation

{ TGrpcMessageCodec }

class function TGrpcMessageCodec.TryDecode(const Buffer: TBytes;
  var Offset: Integer; var Compressed: Boolean;
  out MsgBytes: TBytes): Boolean;
var
  MsgSpan: TByteSpan;
begin
  Result := TGrpcMessageCodec.TryDecode(Buffer, Offset, Compressed, MsgSpan);
  if Result then
  begin
    SetLength(MsgBytes, MsgSpan.Length);
    if MsgSpan.Length > 0 then
      Move(MsgSpan.Data^, MsgBytes[0], MsgSpan.Length);
  end;
end;

class function TGrpcMessageCodec.TryDecode(const Buffer: TBytes;
  var Offset: Integer; var Compressed: Boolean;
  out MsgSpan: TByteSpan): Boolean;
var
  Available: Integer;
  MsgLen: Cardinal;
begin
  Result := False;
  MsgSpan := TByteSpan.Create(nil, 0);
  Available := Length(Buffer) - Offset;
  if Available < 5 then
    Exit;

  Compressed := Buffer[Offset] <> 0;

  MsgLen := (Cardinal(Buffer[Offset + 1]) shl 24) or
            (Cardinal(Buffer[Offset + 2]) shl 16) or
            (Cardinal(Buffer[Offset + 3]) shl 8)  or
             Cardinal(Buffer[Offset + 4]);

  if Available < 5 + Integer(MsgLen) then
    Exit;

  if MsgLen > 0 then
    MsgSpan := TByteSpan.Create(@Buffer[Offset + 5], MsgLen);

  Inc(Offset, 5 + MsgLen);
  Result := True;
end;

class function TGrpcMessageCodec.Encode(const MsgBytes: TBytes;
  Compress: Boolean): TBytes;
begin
  if Length(MsgBytes) > 0 then
    Result := TGrpcMessageCodec.Encode(TByteSpan.Create(@MsgBytes[0], Length(MsgBytes)), Compress)
  else
    Result := TGrpcMessageCodec.Encode(TByteSpan.Create(nil, 0), Compress);
end;

class function TGrpcMessageCodec.Encode(const MsgSpan: TByteSpan;
  Compress: Boolean): TBytes;
var
  MsgLen: Cardinal;
begin
  MsgLen := MsgSpan.Length;
  SetLength(Result, 5 + MsgLen);

  if Compress then
    Result[0] := 1
  else
    Result[0] := 0;

  Result[1] := Byte(MsgLen shr 24);
  Result[2] := Byte(MsgLen shr 16);
  Result[3] := Byte(MsgLen shr 8);
  Result[4] := Byte(MsgLen);

  if MsgLen > 0 then
    Move(MsgSpan.Data^, Result[5], MsgLen);

class function TGrpcMessageCodec.EncodeInto(const MsgSpan: TByteSpan; var Dest: TBytes; AOffset: Integer; Compress: Boolean): Integer;
var
  MsgLen: Cardinal;
begin
  MsgLen := MsgSpan.Length;
  if AOffset < 0 then AOffset := 0;
  SetLength(Dest, AOffset + 5 + MsgLen);
  Dest[AOffset] := Ord(Compress);
  Dest[AOffset + 1] := Byte(MsgLen shr 24);
  Dest[AOffset + 2] := Byte(MsgLen shr 16);
  Dest[AOffset + 3] := Byte(MsgLen shr 8);
  Dest[AOffset + 4] := Byte(MsgLen);
  if MsgLen > 0 then Move(MsgSpan.Data^, Dest[AOffset + 5], MsgLen);
  Result := 5 + MsgLen;
end;
end;

end.
