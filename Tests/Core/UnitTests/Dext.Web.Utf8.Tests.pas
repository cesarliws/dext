{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}

unit Dext.Web.Utf8.Tests;

interface

uses
  Dext.Testing,
  Dext.Web.Utf8,
  System.SysUtils;

type
  [TestFixture('Dext Web UTF8 Parser')]
  TWebUtf8Tests = class
  public
    [Test]
    procedure Test_ByteView_Basic;
    [Test]
    procedure Test_Parse_GetRequest;
    [Test]
    procedure Test_Parse_PostRequest_WithBody;
    [Test]
    procedure Test_Parse_Incomplete_NeedMoreData;
    [Test]
    procedure Test_Parse_Header_Overflow;
    [Test]
    procedure Test_Parse_InvalidRequest;
  end;

implementation

{ TWebUtf8Tests }

procedure TWebUtf8Tests.Test_ByteView_Basic;
var
  S: AnsiString;
  View, Sliced: TDextByteView;
begin
  S := 'GET /hello HTTP/1.1';
  View := TDextByteView.Create(PAnsiChar(S), Length(S));

  Should(View.Length).Be(Length(S));
  Should(View.ToUtf8String).Be('GET /hello HTTP/1.1');

  // Test Slice
  Sliced := View.Slice(4, 6);
  Should(Sliced.Length).Be(6);
  Should(Sliced.ToUtf8String).Be('/hello');

  // Test EqualsAsciiCI
  Should(Sliced.EqualsAsciiCI('/hello', 6)).BeTrue;
  Should(Sliced.EqualsAsciiCI('/HELLO', 6)).BeTrue;
  Should(Sliced.EqualsAsciiCI('/hellx', 6)).BeFalse;
  Should(Sliced.EqualsAsciiCI('/helloo', 7)).BeFalse;
end;

procedure TWebUtf8Tests.Test_Parse_GetRequest;
var
  ReqStr: AnsiString;
  View: TDextByteView;
  Req: TDextParsedRequest;
  Status: TDextHttpParseStatus;
  HeaderVal: TDextByteView;
begin
  ReqStr := 'GET /api/users?id=123 HTTP/1.1'#13#10 +
            'Host: localhost:8080'#13#10 +
            'Connection: keep-alive'#13#10 +
            'Accept: */*'#13#10#13#10;

  View := TDextByteView.Create(PAnsiChar(ReqStr), Length(ReqStr));
  try
    Status := TDextHttpParser.ParseRequest(View, Req);

    Should(Ord(Status)).Be(Ord(hpsComplete));
    Should(Req.HttpVersion).Be(1);
    Should(Req.KeepAlive).BeTrue;
    Should(Req.ContentLength).Be(0);

    // Verify Method
    Should(View.Slice(Req.MethodOffset, Req.MethodLength).ToUtf8String).Be('GET');

    // Verify Path & Query
    Should(View.Slice(Req.PathOffset, Req.PathLength).ToUtf8String).Be('/api/users');
    Should(View.Slice(Req.QueryOffset, Req.QueryLength).ToUtf8String).Be('id=123');

    // Verify Headers
    Should(Req.HeaderCount).Be(3);

    // First Header: Host
    HeaderVal := Req.GetHeaderSliceView(PDextHeaderSlice(PByte(Req.Headers))^);
    Should(HeaderVal.ToUtf8String).Be('Host');
    HeaderVal := Req.GetHeaderValueView(PDextHeaderSlice(PByte(Req.Headers))^);
    Should(HeaderVal.ToUtf8String).Be('localhost:8080');

    // Second Header: Connection
    HeaderVal := Req.GetHeaderSliceView(
      PDextHeaderSlice(PByte(Req.Headers) + SizeOf(TDextHeaderSlice))^);
    Should(HeaderVal.ToUtf8String).Be('Connection');
    HeaderVal := Req.GetHeaderValueView(
      PDextHeaderSlice(PByte(Req.Headers) + SizeOf(TDextHeaderSlice))^);
    Should(HeaderVal.ToUtf8String).Be('keep-alive');
  finally
    Req.Clear;
  end;
end;

procedure TWebUtf8Tests.Test_Parse_PostRequest_WithBody;
var
  ReqStr: AnsiString;
  View: TDextByteView;
  Req: TDextParsedRequest;
  Status: TDextHttpParseStatus;
  BodyVal: TDextByteView;
begin
  ReqStr := 'POST /submit HTTP/1.1'#13#10 +
            'Content-Length: 12'#13#10 +
            'Connection: close'#13#10#13#10 +
            'Hello World!';

  View := TDextByteView.Create(PAnsiChar(ReqStr), Length(ReqStr));
  try
    Status := TDextHttpParser.ParseRequest(View, Req);

    Should(Ord(Status)).Be(Ord(hpsComplete));
    Should(Req.HttpVersion).Be(1);
    Should(Req.KeepAlive).BeFalse;
    Should(Req.ContentLength).Be(12);

    // Verify Body
    BodyVal := View.Slice(Req.BodyOffset, Req.BodyLength);
    Should(BodyVal.ToUtf8String).Be('Hello World!');
  finally
    Req.Clear;
  end;
end;

procedure TWebUtf8Tests.Test_Parse_Incomplete_NeedMoreData;
var
  ReqStr: AnsiString;
  View: TDextByteView;
  Req: TDextParsedRequest;
  Status: TDextHttpParseStatus;
begin
  // 1. Partial request line
  ReqStr := 'GET /api/users HT';
  View := TDextByteView.Create(PAnsiChar(ReqStr), Length(ReqStr));
  try
    Status := TDextHttpParser.ParseRequest(View, Req);
    Should(Ord(Status)).Be(Ord(hpsNeedMoreData));
  finally
    Req.Clear;
  end;

  // 2. Complete request line but incomplete headers
  ReqStr := 'GET /api/users HTTP/1.1'#13#10 +
            'Host: localhost';
  View := TDextByteView.Create(PAnsiChar(ReqStr), Length(ReqStr));
  try
    Status := TDextHttpParser.ParseRequest(View, Req);
    Should(Ord(Status)).Be(Ord(hpsNeedMoreData));
  finally
    Req.Clear;
  end;

  // 3. Complete headers but incomplete body
  ReqStr := 'POST /submit HTTP/1.1'#13#10 +
            'Content-Length: 100'#13#10#13#10 +
            'Partial body content';
  View := TDextByteView.Create(PAnsiChar(ReqStr), Length(ReqStr));
  try
    Status := TDextHttpParser.ParseRequest(View, Req);
    Should(Ord(Status)).Be(Ord(hpsNeedMoreData));
  finally
    Req.Clear;
  end;
end;

procedure TWebUtf8Tests.Test_Parse_Header_Overflow;
var
  ReqStr: AnsiString;
  View: TDextByteView;
  Req: TDextParsedRequest;
  Status: TDextHttpParseStatus;
  I: Integer;
begin
  ReqStr := 'GET /overflow HTTP/1.1'#13#10;
  // Append 40 headers (exceeding 32 limit)
  for I := 1 to 40 do
    ReqStr := ReqStr + AnsiString(Format('X-Header-%d: value-%d'#13#10, [I, I]));
  ReqStr := ReqStr + #13#10;

  View := TDextByteView.Create(PAnsiChar(ReqStr), Length(ReqStr));
  try
    Status := TDextHttpParser.ParseRequest(View, Req);

    Should(Ord(Status)).Be(Ord(hpsComplete));
    Should(Req.HeaderCount).Be(40);
    // Headers must have overflowed to heap allocation
    Should(Req.Headers <> @Req.InlineHeaders[0]).BeTrue;
  finally
    Req.Clear;
  end;
end;

procedure TWebUtf8Tests.Test_Parse_InvalidRequest;
var
  ReqStr: AnsiString;
  View: TDextByteView;
  Req: TDextParsedRequest;
  Status: TDextHttpParseStatus;
begin
  // Host missing colon
  ReqStr := 'GET / HTTP/1.1'#13#10 +
            'InvalidHeaderLineNoColon'#13#10#13#10;
  View := TDextByteView.Create(PAnsiChar(ReqStr), Length(ReqStr));
  try
    Status := TDextHttpParser.ParseRequest(View, Req);
    Should(Ord(Status)).Be(Ord(hpsInvalidRequest));
  finally
    Req.Clear;
  end;
end;

end.
