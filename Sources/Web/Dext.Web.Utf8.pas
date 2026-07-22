unit Dext.Web.Utf8;

interface

uses
  SysUtils;

type
  TDextByteView = record
  private
    FData: PByte;
    FLength: Integer;
  public
    constructor Create(AData: Pointer; ALength: Integer);
    function Slice(AOffset, ALength: Integer): TDextByteView; inline;
    function EqualsAsciiCI(AValue: PAnsiChar; ALength: Integer): Boolean; inline;
    function ToUtf8String: string;
    property Data: PByte read FData;
    property Length: Integer read FLength;
  end;

  TDextHeaderSlice = record
    NameOffset: Integer;
    NameLength: Word;
    ValueOffset: Integer;
    ValueLength: Integer;
    KnownHeaderId: SmallInt;
  end;

  PDextHeaderSlice = ^TDextHeaderSlice;

  TDextParsedRequest = record
    Buffer: TDextByteView;
    MethodOffset: Integer;
    MethodLength: Byte;
    PathOffset: Integer;
    PathLength: Integer;
    QueryOffset: Integer;
    QueryLength: Integer;
    BodyOffset: Integer;
    BodyLength: Integer;
    ContentLength: Int64;
    HeaderCount: Word;
    Headers: Pointer;
    InlineHeaders: array[0..31] of TDextHeaderSlice;
    KeepAlive: Boolean;
    HttpVersion: Byte;
    ParseEndOffset: Integer;
    procedure Init(const ABuffer: TDextByteView);
    procedure Clear;
    function GetHeaderSliceView(const AHeader: TDextHeaderSlice): TDextByteView;
    function GetHeaderValueView(const AHeader: TDextHeaderSlice): TDextByteView;
  end;

  TDextHttpParseStatus = (
    hpsComplete,
    hpsNeedMoreData,
    hpsHeadersTooLarge,
    hpsBodyTooLarge,
    hpsInvalidRequest
  );

  TDextHttpParser = class
  public
    class function ParseRequest(const ABuffer: TDextByteView;
      var ARequest: TDextParsedRequest): TDextHttpParseStatus; static;
  end;

implementation

{ TDextByteView }

constructor TDextByteView.Create(AData: Pointer; ALength: Integer);
begin
  FData := PByte(AData);
  FLength := ALength;
end;

function TDextByteView.Slice(AOffset, ALength: Integer): TDextByteView;
begin
  if (AOffset < 0) or (ALength < 0) or (AOffset + ALength > FLength) then
    raise EArgumentOutOfRangeException.Create('Slice bounds invalid');
  Result.FData := FData + AOffset;
  Result.FLength := ALength;
end;

function TDextByteView.EqualsAsciiCI(AValue: PAnsiChar; ALength: Integer): Boolean;
var
  I: Integer;
  C1, C2: Byte;
begin
  if FLength <> ALength then
    Exit(False);
  for I := 0 to FLength - 1 do
  begin
    C1 := FData[I];
    C2 := Byte(AValue[I]);
    if (C1 >= 65) and (C1 <= 90) then
      Inc(C1, 32);
    if (C2 >= 65) and (C2 <= 90) then
      Inc(C2, 32);
    if C1 <> C2 then
      Exit(False);
  end;
  Result := True;
end;

function TDextByteView.ToUtf8String: string;
var
  Temp: RawByteString;
begin
  if FLength <= 0 then
    Exit('');
  SetString(Temp, PAnsiChar(FData), FLength);
  SetCodePage(Temp, 65001, False);
  Result := string(Temp);
end;

{ TDextParsedRequest }

procedure TDextParsedRequest.Init(const ABuffer: TDextByteView);
begin
  Self := Default(TDextParsedRequest);
  Buffer := ABuffer;
  Headers := @InlineHeaders[0];
  KeepAlive := True; // Default for HTTP/1.1
end;

procedure TDextParsedRequest.Clear;
begin
  if (Headers <> nil) and (Headers <> @InlineHeaders[0]) then
    FreeMem(Headers);
  Headers := nil;
  HeaderCount := 0;
end;

function TDextParsedRequest.GetHeaderSliceView(
  const AHeader: TDextHeaderSlice): TDextByteView;
begin
  Result := Buffer.Slice(AHeader.NameOffset, AHeader.NameLength);
end;

function TDextParsedRequest.GetHeaderValueView(
  const AHeader: TDextHeaderSlice): TDextByteView;
begin
  Result := Buffer.Slice(AHeader.ValueOffset, AHeader.ValueLength);
end;

{ TDextHttpParser }

class function TDextHttpParser.ParseRequest(const ABuffer: TDextByteView;
  var ARequest: TDextParsedRequest): TDextHttpParseStatus;
var
  P, PStart, PEnd: PByte;
  PathEnd, QueryStart: PByte;
  LineStart, ColonPos, ValueStart, ValueEnd: PByte;
  HeaderSlice: PDextHeaderSlice;
  HVal: TDextByteView;
  TempInt: Int64;
  C1: Byte;
  I: Integer;
begin
  ARequest.Init(ABuffer);
  P := ABuffer.Data;
  PStart := P;
  PEnd := P + ABuffer.Length;

  // 1. Method
  while (P < PEnd) and (P^ <> 32) do
    Inc(P);
  if P >= PEnd then
    Exit(hpsNeedMoreData);
  ARequest.MethodOffset := 0;
  ARequest.MethodLength := P - PStart;
  Inc(P); // skip SP

  // 2. Path and Query
  PStart := P;
  QueryStart := nil;
  while (P < PEnd) and (P^ <> 32) do
  begin
    if (P^ = 63) and (QueryStart = nil) then
      QueryStart := P;
    Inc(P);
  end;
  if P >= PEnd then
    Exit(hpsNeedMoreData);

  PathEnd := P;
  if QueryStart <> nil then
  begin
    ARequest.PathOffset := PStart - ABuffer.Data;
    ARequest.PathLength := QueryStart - PStart;
    ARequest.QueryOffset := (QueryStart + 1) - ABuffer.Data;
    ARequest.QueryLength := PathEnd - (QueryStart + 1);
  end
  else
  begin
    ARequest.PathOffset := PStart - ABuffer.Data;
    ARequest.PathLength := PathEnd - PStart;
    ARequest.QueryOffset := 0;
    ARequest.QueryLength := 0;
  end;
  Inc(P); // skip SP

  // 3. HTTP Version
  PStart := P;
  while (P < PEnd) and (P^ <> 13) and (P^ <> 10) do
    Inc(P);
  if P >= PEnd then
    Exit(hpsNeedMoreData);

  // Check version string (e.g. "HTTP/1.1")
  if (P - PStart >= 8) and (PStart[0] = 72) and (PStart[1] = 84) and
     (PStart[2] = 84) and (PStart[3] = 80) and (PStart[4] = 47) then
  begin
    if (PStart[5] = 49) and (PStart[6] = 46) and (PStart[7] = 49) then
      ARequest.HttpVersion := 1
    else if (PStart[5] = 49) and (PStart[6] = 46) and (PStart[7] = 48) then
    begin
      ARequest.HttpVersion := 0;
      ARequest.KeepAlive := False; // Default for HTTP/1.0
    end
    else
      ARequest.HttpVersion := 1;
  end
  else
    ARequest.HttpVersion := 1;

  if P^ = 13 then
  begin
    Inc(P);
    if P >= PEnd then
      Exit(hpsNeedMoreData);
  end;
  if P^ <> 10 then
    Exit(hpsInvalidRequest);
  Inc(P); // skip LF

  // 4. Headers
  while True do
  begin
    if P >= PEnd then
      Exit(hpsNeedMoreData);

    // Empty line indicates end of headers
    if (P^ = 13) then
    begin
      Inc(P);
      if P >= PEnd then
        Exit(hpsNeedMoreData);
      if P^ = 10 then
      begin
        Inc(P);
        Break;
      end
      else
        Exit(hpsInvalidRequest);
    end
    else if P^ = 10 then
    begin
      Inc(P);
      Break;
    end;

    // We have a header line
    LineStart := P;
    ColonPos := nil;
    while (P < PEnd) and (P^ <> 13) and (P^ <> 10) do
    begin
      if (P^ = 58) and (ColonPos = nil) then
        ColonPos := P;
      Inc(P);
    end;
    if P >= PEnd then
      Exit(hpsNeedMoreData);

    if ColonPos = nil then
      Exit(hpsInvalidRequest);

    // Make sure we have a valid header slice capacity
    if ARequest.HeaderCount >= 32 then
    begin
      if ARequest.Headers = @ARequest.InlineHeaders[0] then
      begin
        // Allocate 128 elements overflow array
        GetMem(ARequest.Headers, 128 * SizeOf(TDextHeaderSlice));
        Move(ARequest.InlineHeaders[0], ARequest.Headers^,
          32 * SizeOf(TDextHeaderSlice));
      end;
    end;

    HeaderSlice := PDextHeaderSlice(PByte(ARequest.Headers) +
      ARequest.HeaderCount * SizeOf(TDextHeaderSlice));

    HeaderSlice.NameOffset := LineStart - ABuffer.Data;
    HeaderSlice.NameLength := ColonPos - LineStart;

    // Value begins after colon, skipping spaces/tabs
    ValueStart := ColonPos + 1;
    while (ValueStart < P) and ((ValueStart^ = 32) or (ValueStart^ = 9)) do
      Inc(ValueStart);

    ValueEnd := P;
    // Trim trailing spaces/tabs
    while (ValueEnd > ValueStart) and
      (((ValueEnd - 1)^ = 32) or ((ValueEnd - 1)^ = 9)) do
      Dec(ValueEnd);

    HeaderSlice.ValueOffset := ValueStart - ABuffer.Data;
    HeaderSlice.ValueLength := ValueEnd - ValueStart;
    HeaderSlice.KnownHeaderId := 0;

    // Detect known headers
    HVal := ARequest.GetHeaderSliceView(HeaderSlice^);
    if HVal.EqualsAsciiCI('content-length', 14) then
    begin
      HeaderSlice.KnownHeaderId := 1;
      // Parse Content-Length value
      TempInt := 0;
      for I := 0 to HeaderSlice.ValueLength - 1 do
      begin
        C1 := ABuffer.Data[HeaderSlice.ValueOffset + I];
        if (C1 >= 48) and (C1 <= 57) then
          TempInt := TempInt * 10 + (C1 - 48)
        else
          Exit(hpsInvalidRequest);
      end;
      ARequest.ContentLength := TempInt;
    end
    else if HVal.EqualsAsciiCI('connection', 10) then
    begin
      HeaderSlice.KnownHeaderId := 2;
      HVal := ARequest.GetHeaderValueView(HeaderSlice^);
      if HVal.EqualsAsciiCI('keep-alive', 10) then
        ARequest.KeepAlive := True
      else if HVal.EqualsAsciiCI('close', 5) then
        ARequest.KeepAlive := False;
    end;

    Inc(ARequest.HeaderCount);

    if P^ = 13 then
      Inc(P); // skip CR
    Inc(P); // skip LF
  end;

  ARequest.ParseEndOffset := P - ABuffer.Data;
  ARequest.BodyOffset := ARequest.ParseEndOffset;

  // 5. Body Length and completeness check
  if ARequest.ContentLength > 0 then
  begin
    ARequest.BodyLength := ARequest.ContentLength;
    if ABuffer.Length - ARequest.BodyOffset < ARequest.BodyLength then
      Exit(hpsNeedMoreData);
  end
  else
  begin
    ARequest.BodyLength := 0;
  end;

  Result := hpsComplete;
end;

end.
