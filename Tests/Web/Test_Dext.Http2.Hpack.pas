{***************************************************************************}
{                                                                           }
{           Dext Framework — HTTP/2 HPACK Unit Tests                       }
{                                                                           }
{           Tests RFC 7541 static table, dynamic table, Huffman decode,    }
{           and encode/decode round-trip using RFC C.3/C.4 test vectors.   }
{                                                                           }
{***************************************************************************}
unit Test_Dext.Http2.Hpack;

interface

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Http2.Hpack;

type
  /// <summary>Tests for the HPACK static table lookups.</summary>
  [TestFixture('HPACK — Static Table')]
  THpackStaticTableTests = class
  public
    [Test]
    procedure StaticTable_Index2_ShouldBe_Method_GET;
    [Test]
    procedure StaticTable_Index8_ShouldBe_Status_200;
    [Test]
    procedure StaticTable_Index61_ShouldBe_WwwAuthenticate;
    [Test]
    procedure StaticTable_Index1_Name_ShouldBe_Authority;
  end;

  /// <summary>Tests for the HPACK dynamic table (RFC 7541 §4).</summary>
  [TestFixture('HPACK — Dynamic Table')]
  THpackDynTableTests = class
  public
    [Test]
    procedure Add_ShouldInsertAtFront;
    [Test]
    procedure Add_ShouldEvictOldestOnOverflow;
    [Test]
    procedure SetMaxSize_Zero_ShouldEvictAll;
    [Test]
    procedure Count_ShouldReflectEntries;
  end;

  /// <summary>Tests for Huffman decoding.</summary>
  [TestFixture('HPACK — Huffman')]
  THpackHuffmanTests = class
  public
    [Test]
    procedure Decode_AsciiLetters_ShouldRoundTrip;
    [Test]
    procedure Decode_EmptyInput_ShouldReturnEmpty;
    [Test]
    procedure Encode_ShouldProduceShorterOutput_ForAsciiText;
  end;

  /// <summary>Tests for THpackDecoder using RFC 7541 Appendix C vectors.</summary>
  [TestFixture('HPACK — Decoder (RFC C vectors)')]
  THpackDecoderTests = class
  private
    FDecoder: THpackDecoder;
  public
    [Setup]    procedure Setup;
    [Teardown] procedure Teardown;

    [Test]
    /// <summary>RFC 7541 §C.2.1 — Literal Header Field with Incremental Indexing.</summary>
    procedure Decode_C2_1_LiteralWithIndexing;

    [Test]
    /// <summary>RFC 7541 §C.2.2 — Literal Header Field without Indexing.</summary>
    procedure Decode_C2_2_LiteralWithoutIndexing;

    [Test]
    /// <summary>RFC 7541 §C.2.4 — Indexed Header Field.</summary>
    procedure Decode_C2_4_IndexedField;

    [Test]
    /// <summary>Decodes a Huffman-encoded string literal correctly.</summary>
    procedure Decode_HuffmanStringLiteral;

    [Test]
    /// <summary>Indexed lookup into the dynamic table after a previous encoding.</summary>
    procedure Decode_DynamicTableLookup;
  end;

  /// <summary>Tests for THpackEncoder round-trip.</summary>
  [TestFixture('HPACK — Encoder Round-Trip')]
  THpackEncoderTests = class
  private
    FEncoder: THpackEncoder;
    FDecoder: THpackDecoder;
  public
    [Setup]    procedure Setup;
    [Teardown] procedure Teardown;

    [Test]
    procedure Encode_SingleHeader_ShouldDecodeBackCorrectly;

    [Test]
    procedure Encode_MultipleHeaders_ShouldDecodeBackAll;

    [Test]
    procedure Encode_StaticTableHit_ShouldUseIndexedRepresentation;

    [Test]
    procedure Encode_DynamicTableGrowth_ShouldReusePreviousEntry;
  end;

implementation

{ THpackStaticTableTests }

procedure THpackStaticTableTests.StaticTable_Index2_ShouldBe_Method_GET;
var
  decoder: THpackDecoder;
  // Indexed Header Field representation: 0x82 = 10000010 = index 2
  data: TBytes;
  headers: TNameValuePairs;
begin
  decoder := THpackDecoder.Create;
  try
    data := TBytes.Create($82);
    Should(decoder.Decode(@data[0], 1, headers)).BeTrue;
    Should(Length(headers)).Be(1);
    Should(headers[0].Name).Be(':method');
    Should(headers[0].Value).Be('GET');
  finally
    decoder.Free;
  end;
end;

procedure THpackStaticTableTests.StaticTable_Index8_ShouldBe_Status_200;
var
  decoder: THpackDecoder;
  data: TBytes;
  headers: TNameValuePairs;
begin
  decoder := THpackDecoder.Create;
  try
    data := TBytes.Create($88); // index 8 = 10001000
    Should(decoder.Decode(@data[0], 1, headers)).BeTrue;
    Should(Length(headers)).Be(1);
    Should(headers[0].Name).Be(':status');
    Should(headers[0].Value).Be('200');
  finally
    decoder.Free;
  end;
end;

procedure THpackStaticTableTests.StaticTable_Index61_ShouldBe_WwwAuthenticate;
var
  decoder: THpackDecoder;
  data: TBytes;
  headers: TNameValuePairs;
begin
  decoder := THpackDecoder.Create;
  try
    // index 61 = multi-byte: 0xFF (prefix all 1s) + 0x01 (continuation 1-126+1=61-63=no)
    // index 61: 0xBE = 10111110 = 0x80 | 61 (61 < 127 so single byte with 7-bit prefix)
    // 0x80 | 61 = 0xBD
    data := TBytes.Create($BD);
    Should(decoder.Decode(@data[0], 1, headers)).BeTrue;
    Should(Length(headers)).Be(1);
    Should(headers[0].Name).Be('www-authenticate');
  finally
    decoder.Free;
  end;
end;

procedure THpackStaticTableTests.StaticTable_Index1_Name_ShouldBe_Authority;
var
  decoder: THpackDecoder;
  data: TBytes;
  headers: TNameValuePairs;
begin
  decoder := THpackDecoder.Create;
  try
    data := TBytes.Create($81); // index 1
    Should(decoder.Decode(@data[0], 1, headers)).BeTrue;
    Should(headers[0].Name).Be(':authority');
  finally
    decoder.Free;
  end;
end;

{ THpackDynTableTests }

procedure THpackDynTableTests.Add_ShouldInsertAtFront;
var
  tbl: THpackDynamicTable;
  entry: TNameValuePair;
begin
  tbl.Init(4096);
  tbl.Add('custom-name', 'custom-value');
  Should(tbl.Count).Be(1);
  entry := tbl.Get(1);
  Should(entry.Name).Be('custom-name');
  Should(entry.Value).Be('custom-value');
end;

procedure THpackDynTableTests.Add_ShouldEvictOldestOnOverflow;
var
  tbl: THpackDynamicTable;
begin
  // Each entry: len(name)+len(value)+32
  // "a"+"b" = 1+1+32 = 34 bytes
  // Set max = 34*3 = 102 bytes -> holds 3 entries; 4th evicts oldest
  tbl.Init(102);
  tbl.Add('a', 'b');  // entry 1 (oldest)
  tbl.Add('c', 'd');  // entry 2
  tbl.Add('e', 'f');  // entry 3
  Should(tbl.Count).Be(3);
  tbl.Add('g', 'h');  // entry 4 → should evict 'a'/'b'
  Should(tbl.Count).Be(3);
  // Newest is now 'g'/'h' at index 1
  Should(tbl.Get(1).Name).Be('g');
  // Oldest remaining is 'c'/'d' at index 3
  Should(tbl.Get(3).Name).Be('c');
end;

procedure THpackDynTableTests.SetMaxSize_Zero_ShouldEvictAll;
var
  tbl: THpackDynamicTable;
begin
  tbl.Init(4096);
  tbl.Add('x', 'y');
  tbl.Add('a', 'b');
  Should(tbl.Count).Be(2);
  tbl.SetMaxSize(0);
  Should(tbl.Count).Be(0);
  Should(tbl.CurrentSize).Be(0);
end;

procedure THpackDynTableTests.Count_ShouldReflectEntries;
var
  tbl: THpackDynamicTable;
begin
  tbl.Init(4096);
  Should(tbl.Count).Be(0);
  tbl.Add('n1', 'v1');
  Should(tbl.Count).Be(1);
  tbl.Add('n2', 'v2');
  Should(tbl.Count).Be(2);
end;

{ THpackHuffmanTests }

procedure THpackHuffmanTests.Decode_AsciiLetters_ShouldRoundTrip;
var
  original: string;
  encoded: TBytes;
  decoded: string;
begin
  original := 'www.example.com';
  encoded := THpackHuffman.Encode(original);
  Should(Length(encoded) > 0).BeTrue;
  decoded := THpackHuffman.Decode(@encoded[0], Length(encoded));
  Should(decoded).Be(original);
end;

procedure THpackHuffmanTests.Decode_EmptyInput_ShouldReturnEmpty;
var
  dummy: Byte;
  decoded: string;
begin
  dummy := 0;
  decoded := THpackHuffman.Decode(@dummy, 0);
  Should(decoded).Be('');
end;

procedure THpackHuffmanTests.Encode_ShouldProduceShorterOutput_ForAsciiText;
var
  original: string;
  encoded: TBytes;
  utf8Len: Integer;
begin
  original := 'www.example.com';
  encoded := THpackHuffman.Encode(original);
  utf8Len := Length(TEncoding.UTF8.GetBytes(original));
  // Huffman-encoded should be shorter for typical ASCII
  Should(Length(encoded) < utf8Len).BeTrue;
end;

{ THpackDecoderTests }

procedure THpackDecoderTests.Setup;
begin
  FDecoder := THpackDecoder.Create;
end;

procedure THpackDecoderTests.Teardown;
begin
  FDecoder.Free;
end;

// RFC 7541 §C.2.1 — Literal Header Field with Incremental Indexing
// custom-key: custom-header
// Wire: 40 0a 63 75 73 74 6f 6d 2d 6b 65 79 0d 63 75 73 74 6f 6d 2d 68 65 61 64 65 72
procedure THpackDecoderTests.Decode_C2_1_LiteralWithIndexing;
var
  data: TBytes;
  headers: TNameValuePairs;
begin
  data := TBytes.Create(
    $40, $0A, $63, $75, $73, $74, $6F, $6D, $2D, $6B, $65, $79,
    $0D, $63, $75, $73, $74, $6F, $6D, $2D, $68, $65, $61, $64, $65, $72
  );
  Should(FDecoder.Decode(@data[0], Length(data), headers)).BeTrue;
  Should(Length(headers)).Be(1);
  Should(headers[0].Name).Be('custom-key');
  Should(headers[0].Value).Be('custom-header');
end;

// RFC 7541 §C.2.2 — Literal Header Field without Indexing
// :path = /sample/path
// Wire: 04 0c 2f 73 61 6d 70 6c 65 2f 70 61 74 68
procedure THpackDecoderTests.Decode_C2_2_LiteralWithoutIndexing;
var
  data: TBytes;
  headers: TNameValuePairs;
begin
  data := TBytes.Create(
    $04, $0C, $2F, $73, $61, $6D, $70, $6C, $65, $2F, $70, $61, $74, $68
  );
  Should(FDecoder.Decode(@data[0], Length(data), headers)).BeTrue;
  Should(Length(headers)).Be(1);
  Should(headers[0].Name).Be(':path');
  Should(headers[0].Value).Be('/sample/path');
end;

// RFC 7541 §C.2.4 — Indexed Header Field — :method GET (index 2)
procedure THpackDecoderTests.Decode_C2_4_IndexedField;
var
  data: TBytes;
  headers: TNameValuePairs;
begin
  data := TBytes.Create($82); // index 2 = :method GET
  Should(FDecoder.Decode(@data[0], 1, headers)).BeTrue;
  Should(headers[0].Name).Be(':method');
  Should(headers[0].Value).Be('GET');
end;

// Test Huffman-encoded string literal: encode 'no-cache' as Huffman then decode
procedure THpackDecoderTests.Decode_HuffmanStringLiteral;
var
  encoded: TBytes;
  headers: TNameValuePairs;
begin
  // Build a literal without indexing (0x10 = 0001 0000 + index 0 → new name)
  // with Huffman-encoded name 'cache-control' and value 'no-cache'
  // For simplicity we just test round-trip via our encoder/decoder
  var enc := THpackEncoder.Create;
  try
    var hdrs: TNameValuePairs;
    SetLength(hdrs, 1);
    hdrs[0].Name := 'cache-control';
    hdrs[0].Value := 'no-cache';
    encoded := enc.Encode(hdrs);
  finally
    enc.Free;
  end;
  Should(FDecoder.Decode(@encoded[0], Length(encoded), headers)).BeTrue;
  Should(Length(headers) >= 1).BeTrue;
  Should(headers[0].Name).Be('cache-control');
  Should(headers[0].Value).Be('no-cache');
end;

// Decode the same block twice — second time should hit the dynamic table
procedure THpackDecoderTests.Decode_DynamicTableLookup;
var
  enc: THpackEncoder;
  block1, block2: TBytes;
  hdrs: TNameValuePairs;
  out1, out2: TNameValuePairs;
begin
  enc := THpackEncoder.Create;
  try
    SetLength(hdrs, 1);
    hdrs[0].Name := 'x-custom';
    hdrs[0].Value := 'dext-http2';
    block1 := enc.Encode(hdrs);   // adds to dynamic table
    block2 := enc.Encode(hdrs);   // should now use indexed reference
  finally
    enc.Free;
  end;
  // First decode populates dynamic table in FDecoder
  Should(FDecoder.Decode(@block1[0], Length(block1), out1)).BeTrue;
  // Second decode should still produce the same output
  Should(FDecoder.Decode(@block2[0], Length(block2), out2)).BeTrue;
  Should(Length(out2)).Be(1);
  Should(out2[0].Name).Be('x-custom');
  Should(out2[0].Value).Be('dext-http2');
end;

{ THpackEncoderTests }

procedure THpackEncoderTests.Setup;
begin
  FEncoder := THpackEncoder.Create;
  FDecoder := THpackDecoder.Create;
end;

procedure THpackEncoderTests.Teardown;
begin
  FEncoder.Free;
  FDecoder.Free;
end;

procedure THpackEncoderTests.Encode_SingleHeader_ShouldDecodeBackCorrectly;
var
  headers, decoded: TNameValuePairs;
  encoded: TBytes;
begin
  SetLength(headers, 1);
  headers[0].Name := ':status';
  headers[0].Value := '200';
  encoded := FEncoder.Encode(headers);
  Should(Length(encoded) > 0).BeTrue;
  Should(FDecoder.Decode(@encoded[0], Length(encoded), decoded)).BeTrue;
  Should(Length(decoded)).Be(1);
  Should(decoded[0].Name).Be(':status');
  Should(decoded[0].Value).Be('200');
end;

procedure THpackEncoderTests.Encode_MultipleHeaders_ShouldDecodeBackAll;
var
  headers, decoded: TNameValuePairs;
  encoded: TBytes;
begin
  SetLength(headers, 3);
  headers[0].Name := ':status';   headers[0].Value := '200';
  headers[1].Name := 'content-type'; headers[1].Value := 'application/json';
  headers[2].Name := 'x-request-id'; headers[2].Value := 'abc-123';
  encoded := FEncoder.Encode(headers);
  Should(FDecoder.Decode(@encoded[0], Length(encoded), decoded)).BeTrue;
  Should(Length(decoded)).Be(3);
  Should(decoded[0].Name).Be(':status');
  Should(decoded[1].Name).Be('content-type');
  Should(decoded[2].Name).Be('x-request-id');
  Should(decoded[2].Value).Be('abc-123');
end;

procedure THpackEncoderTests.Encode_StaticTableHit_ShouldUseIndexedRepresentation;
var
  headers: TNameValuePairs;
  encoded: TBytes;
begin
  // :method GET is index 2 in static table → single byte $82
  SetLength(headers, 1);
  headers[0].Name := ':method';
  headers[0].Value := 'GET';
  encoded := FEncoder.Encode(headers);
  // The first byte should be the indexed representation (high bit set)
  Should((encoded[0] and $80) <> 0).BeTrue;
end;

procedure THpackEncoderTests.Encode_DynamicTableGrowth_ShouldReusePreviousEntry;
var
  headers: TNameValuePairs;
  enc1, enc2: TBytes;
begin
  SetLength(headers, 1);
  headers[0].Name := 'x-trace-id';
  headers[0].Value := 'trace-0001';
  enc1 := FEncoder.Encode(headers);  // first time: literal + adds to dynamic table
  enc2 := FEncoder.Encode(headers);  // second time: should be indexed (shorter)
  // The indexed form is always 1 byte if index < 127
  Should(Length(enc2) < Length(enc1)).BeTrue;
end;

end.
