unit Dext.Web.Features.Tests;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.SysUtils,
  Dext.Testing.Attributes,
  Dext.Assertions,
  Dext.Auth.JWT,
  Dext.Net.RestClient,
  Dext.Net.RestRequest,
  Dext.Net.Authentication,
  Dext.Resilience,
  Dext.Web.Interfaces,
  Dext.WebHost,
  System.SyncObjs,
  Dext.Web.Controllers,
  Dext.Web.Routing.Attributes;

type
  [TestFixture('Web Extension Features Tests (Phase 3)')]
  TWebFeaturesTests = class
  public
    [Test('T.3 - Should validate JWT generation and parsing correctly (Item B.3)')]
    procedure TestJwtBuilderAndValidation;

    [Test('T.3 - Should support Multipart Form Data adding correctly (Item C.1)')]
    procedure TestMultipartFormData;

    [Test('Should validate conditional query parameters in TRestRequest')]
    procedure TestConditionalQueryParams;

    [Test('Should retrieve and parse OAuth2 Client Credentials token using local mock server')]
    procedure TestOAuth2ClientCredentialsProvider;

    [Test('Should catch RestClient connection exception safely without Access Violation (Issue #129)')]
    procedure TestRestClientExceptionHandling;

    [Test('Should catch RestClient connection exception using fluent OnException (Issue #129)')]
    procedure TestRestClientFluentExceptionHandling;

    [Test('Should stream response using chunked transfer encoding and SSE pattern')]
    procedure TestChunkedResponseAndSSE;

    [Test('Should return binary response correctly without hanging')]
    procedure TestBinaryResponseStream;

    [Test('Should compress response body when compression middleware is used on Native Server (HTTP.sys)')]
    procedure TestNativeServerCompression;

    [Test('Should preserve and emit repeated Set-Cookie headers on Native Server (Issue #189)')]
    procedure TestNativeServerRepeatedCookies;

    [Test('Should immediately dispatch semantic results using Results(Ctx) contextual helper')]
    procedure TestContextualResults;
  end;

  [ApiController, Route('/gzip-controller')]
  TGzipTestController = class
  public
    [HttpGet]
    function GetLargeHtml: IResult;

    [HttpGet, Route('/direct')]
    procedure GetDirect(const Ctx: IHttpContext);
  end;

implementation

uses
  IdTCPClient,
  Dext.Web.Indy,
  Dext.Web.Middleware.Compression,
  Dext,
  Dext.Web,
  Dext.Web.Results,
  Dext.Server.Engine.Types,
  Dext.Net.Engine,
  Dext.Utils,
  System.TypInfo,
  System.Rtti;

type
  TTRestRequestHack = record
    Data: IRestRequestData;
  end;

{ TGzipTestController }

function TGzipTestController.GetLargeHtml: IResult;
begin
  Result := Results.Html(StringOfChar('A', 40000) + '<h1>Hello World from Controller!</h1>' + StringOfChar('B', 7000));
end;

procedure TGzipTestController.GetDirect(const Ctx: IHttpContext);
begin
  Ctx.Response.SetContentType('text/html');
  Ctx.Response.Write(StringOfChar('A', 40000) + '<h1>Hello World from Direct Controller!</h1>' + StringOfChar('B', 7000));
end;

{ TWebFeaturesTests }

procedure TWebFeaturesTests.TestJwtBuilderAndValidation;
var
  Handler: IJwtTokenHandler;
  Token: string;
  Result: TJwtValidationResult;
begin
  Handler := TJwtTokenHandler.Create('MySuperSecretKeyForJWT123', 'DextIssuer', 'DextAudience', 120);
  
  // Generate
  Token := Handler.GenerateToken([TClaim.Create('user_id', '12345')]);
  Should(Token).NotBeEmpty;
  Should(Token).Contain('.'); // Should have 3 parts
  
  // Validate
  Result := Handler.ValidateToken(Token);
  Should(Result.IsValid).BeTrue;
  Should(Length(Result.Claims)).BeGreaterThan(0);
end;

procedure TWebFeaturesTests.TestMultipartFormData;
var
  Client: TRestClient;
  Req: TRestRequest;
  ReqData: IRestRequestData;
  Stream: TStream;
  StrStream: TStringStream;
  BodyText: string;
begin
  Client := TRestClient.Create;
  Req := Client.Request(hmPOST, '/api/test')
    .AddFormField('name', 'value')
    .AddFormField('config', '{"debug":true}', 'application/json');

  ReqData := TTRestRequestHack(Req).Data;
  Should(ReqData.HasMultipartData).BeTrue;

  Stream := ReqData.BuildMultipartBody;
  try
    Should(Stream).NotBeNil;
    StrStream := TStringStream.Create('', TEncoding.UTF8);
    try
      StrStream.CopyFrom(Stream, 0);
      BodyText := StrStream.DataString;
    finally
      StrStream.Free;
    end;
  finally
    Stream.Free;
  end;

  // Assert standard field is present and correct
  Should(BodyText).Contain('Content-Disposition: form-data; name="name"');
  Should(BodyText).Contain('value');

  // Assert field with custom Content-Type is present and correct
  Should(BodyText).Contain('Content-Disposition: form-data; name="config"');
  Should(BodyText).Contain('Content-Type: application/json');
  Should(BodyText).Contain('{"debug":true}');
end;

procedure TWebFeaturesTests.TestConditionalQueryParams;
var
  Client: TRestClient;
  Req: TRestRequest;
  FullUrl: string;
begin
  Client := TRestClient.Create;

  // 1. QueryParamIfNotEmpty
  Req := Client.Request(hmGET, '/api/users')
    .QueryParamIfNotEmpty('status', 'active')
    .QueryParamIfNotEmpty('search', '')
    .QueryParamIfNotEmpty('filter', '   '); // Blank, should be skipped
  Should(Req.GetFullUrl).Be('/api/users?status=active');

  // 2. QueryParam (with Default)
  Req := Client.Request(hmGET, '/api/users')
    .QueryParam('page', '2', '1')      // Value is present
    .QueryParam('limit', '', '10')     // Value empty, use default
    .QueryParam('sort', '   ', 'name') // Value blank, use default
    .QueryParam('group', '', '   ');   // Both blank, should skip
  FullUrl := Req.GetFullUrl;
  Should(FullUrl).StartWith('/api/users?');
  Should(FullUrl).Contain('page=2');
  Should(FullUrl).Contain('limit=10');
  Should(FullUrl).Contain('sort=name');

  // 3. QueryParamIf
  Req := Client.Request(hmGET, '/api/users')
    .QueryParamIf('flagged', 'true', True)
    .QueryParamIf('deleted', 'true', False);
  Should(Req.GetFullUrl).Be('/api/users?flagged=true');

  // 4. Overloaded QueryParam (with Boolean Condition)
  Req := Client.Request(hmGET, '/api/users')
    .QueryParam('flagged', 'true', True)
    .QueryParam('deleted', 'true', False);
  Should(Req.GetFullUrl).Be('/api/users?flagged=true');
end;

procedure TWebFeaturesTests.TestOAuth2ClientCredentialsProvider;
var
  Builder: IWebHostBuilder;
  Host: IWebHost;
  Provider: TOAuth2ClientCredentialsProvider;
  HeaderVal: string;
begin
  // 1. Create and configure a local ephemeral HTTP server
  Builder := TWebHost.CreateDefaultBuilder
    .UseUrls('http://127.0.0.1:0'); // Dynamic port selection

  Builder.Configure(procedure(App: IApplicationBuilder)
    begin
      App.MapPost('/oauth/token',
        procedure(Ctx: IHttpContext)
        begin
          Ctx.Response.ContentType := 'application/json';
          Ctx.Response.Write('{"access_token":"mock-token-abc-123","expires_in":3600}');
        end
      );
    end);

  Host := Builder.Build;
  Host.Start;
  try
    // 2. Act: Instantiating provider targeting the local server
    Provider := TOAuth2ClientCredentialsProvider.Create(
      'http://localhost:' + Host.Port.ToString + '/oauth/token',
      'test-client-id',
      'test-client-secret'
    );
    try
      try
        HeaderVal := Provider.GetHeaderValue;
        Should(HeaderVal).Be('Bearer mock-token-abc-123');
      except
        on E: Exception do
        begin
          WriteLn('OAuth2 EXCEPTION: ' + E.ClassName + ': ' + E.Message);
          raise;
        end;
      end;
    finally
      Provider.Free;
    end;
  finally
    Host.Stop;
  end;
end;

procedure TWebFeaturesTests.TestRestClientExceptionHandling;
var
  Resp: IRestResponse;
  Caught: Boolean;
  ErrorMsg: string;
  ErrorClass: string;
begin
  Caught := False;
  try
    Resp := RestClient('http://127.0.0.1:9999')
      .Timeout(2000)
      .Get('/posts')
      .Await;
  except
    on E: Exception do
    begin
      Caught := True;
      ErrorMsg := E.Message;
      ErrorClass := E.ClassName;
    end;
  end;

  Should(Caught).BeTrue;
  Should(ErrorMsg).NotBeEmpty;
  Should(ErrorClass).NotBeEmpty;
end;

procedure TWebFeaturesTests.TestRestClientFluentExceptionHandling;
var
  Caught: Boolean;
  ErrorMsg: string;
  ErrorClass: string;
  Timeout: Integer;
begin
  Caught := False;
  RestClient('http://127.0.0.1:9999')
    .Timeout(2000)
    .Get('/posts')
    .OnException(procedure(E: Exception)
      begin
        Caught := True;
        ErrorMsg := E.Message;
        ErrorClass := E.ClassName;
      end)
    .Start;

  // Since OnException queues to the main thread, we must pump the main thread queue
  Timeout := 0;
  while (not Caught) and (Timeout < 5000) do
  begin
    CheckSynchronize(10);
    Inc(Timeout, 10);
    Sleep(10);
  end;

  Should(Caught).BeTrue;
  Should(ErrorMsg).NotBeEmpty;
  Should(ErrorClass).NotBeEmpty;
end;

procedure TWebFeaturesTests.TestChunkedResponseAndSSE;
var
  Builder: IWebHostBuilder;
  Host: IWebHost;
  Resp: IRestResponse;
begin
  Builder := TWebHost.CreateDefaultBuilder
    .UseUrls('http://127.0.0.1:0');

  Builder.Configure(procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/sse-test',
        procedure(Ctx: IHttpContext)
        var
          IndyResp: TDextIndyHttpResponse;
        begin
          Ctx.Response.SetContentType('text/event-stream');
          Ctx.Response.AddHeader('Cache-Control', 'no-cache');
          Ctx.Response.AddHeader('Connection', 'keep-alive');
          
          if Ctx.Response is TDextIndyHttpResponse then
          begin
            IndyResp := TDextIndyHttpResponse(Ctx.Response);
            IndyResp.BeginStreamingResponse;
            
            Ctx.Response.Write('event: test'#10'data: hello'#10#10);
            IndyResp.Flush;
            
            Ctx.Response.Write('event: test'#10'data: world'#10#10);
            IndyResp.EndStreamingResponse;
          end;
        end
      );
    end);

  Host := Builder.Build;
  Host.Start;
  try
    Resp := RestClient('http://localhost:' + Host.Port.ToString)
      .Get('/sse-test')
      .Await;
      
    Should(Resp.StatusCode).Be(200);
    Should(Resp.ContentString).Be('event: test'#10'data: hello'#10#10'event: test'#10'data: world'#10#10);
    Should(Resp.GetHeader('Transfer-Encoding')).Be('chunked');
  finally
    Host.Stop;
  end;
end;

procedure TWebFeaturesTests.TestBinaryResponseStream;
var
  Builder: IWebHostBuilder;
  Host: IWebHost;
  Resp: IRestResponse;
  BinaryData: TBytes;
  I: Integer;
begin
  SetLength(BinaryData, 32000);
  for I := 0 to High(BinaryData) do
    BinaryData[I] := I mod 256;

  Builder := TWebHost.CreateDefaultBuilder
    .UseUrls('http://127.0.0.1:0');

  Builder.Configure(procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/binary-test',
        procedure(Ctx: IHttpContext)
        var
          Chunk1, Chunk2: TBytes;
        begin
          SetLength(Chunk1, 16000);
          Move(BinaryData[0], Chunk1[0], 16000);
          SetLength(Chunk2, 16000);
          Move(BinaryData[16000], Chunk2[0], 16000);
          
          Ctx.Response.SetContentType('application/octet-stream');
          Ctx.Response.SetContentLength(Length(BinaryData));
          Ctx.Response.Write(Chunk1);
          Ctx.Response.Write(Chunk2);
        end
      );
    end);

  Host := Builder.Build;
  Host.Start;
  try
    Resp := RestClient('http://localhost:' + Host.Port.ToString)
      .Get('/binary-test')
      .Await;
      
    Should(Resp.StatusCode).Be(200);
    Should(Resp.ContentStream.Size).Be(Length(BinaryData));
    
    var ReceivedBytes: TBytes;
    SetLength(ReceivedBytes, Resp.ContentStream.Size);
    Resp.ContentStream.Position := 0;
    if Length(ReceivedBytes) > 0 then
      Resp.ContentStream.ReadBuffer(ReceivedBytes[0], Length(ReceivedBytes));
    Should(CompareMem(@ReceivedBytes[0], @BinaryData[0], Length(BinaryData))).BeTrue;
  finally
    Host.Stop;
  end;
end;

procedure TWebFeaturesTests.TestNativeServerCompression;
var
  Builder: IWebHostBuilder;
  Host: IWebHost;
  Resp: IRestResponse;
begin
  TGzipTestController.Create.Free; // Force linker to keep TGzipTestController

  Builder := TWebHost.CreateDefaultBuilder
    .UseUrls('http://127.0.0.1:60455');
  (Builder as TWebHostBuilder).ConfigureServicesExtended(procedure(Services: TDextServices)
    begin
      Services.AddControllers;
    end);

  Builder.Configure(procedure(App: IApplicationBuilder)
    begin
      App.UseMiddleware(TCompressionMiddleware);
    end);

  var Options: TServerEngineOptions;
  Host := Builder.Build;
  (Host as IWebApplication).MapControllers;
  Options := TServerEngineOptions.Default.WithBindAddress('127.0.0.1');
  (Host as IWebApplication).UseNativeServer(Options);
  Host.Start;
  try
    try
      // 1. Test standard Controller Action (returns IResult)
      Resp := RestClient('http://localhost:' + Host.Port.ToString)
        .Header('Accept-Encoding', 'gzip')
        .Get('/gzip-controller')
        .Await;

      WriteLn('CLIENT RECEIVED (Standard): Status=' + Resp.StatusCode.ToString + ', Content-Length=' + Resp.ContentStream.Size.ToString);
      Should(Resp.StatusCode).Be(200);
      Should(Resp.GetHeader('Content-Encoding')).Be('gzip');
      Should(Resp.RawContentStream.Size).BeLessThan(4000); // Verify it is compressed on the wire

      // 2. Test direct write Controller Action (writes directly to Ctx.Response)
      Resp := RestClient('http://localhost:' + Host.Port.ToString)
        .Header('Accept-Encoding', 'gzip')
        .Get('/gzip-controller/direct')
        .Await;

      WriteLn('CLIENT RECEIVED (Direct): Status=' + Resp.StatusCode.ToString + ', Content-Length=' + Resp.ContentStream.Size.ToString);
      Should(Resp.StatusCode).Be(200);
      Should(Resp.GetHeader('Content-Encoding')).Be('gzip');
      Should(Resp.RawContentStream.Size).BeLessThan(4000); // Verify it is compressed on the wire
    except
      on E: Exception do
      begin
        raise Exception.Create('CRASH: ' + E.ClassName + ': ' + E.Message + sLineBreak + E.StackTrace);
      end;
    end;
  finally
    Host.Stop;
  end;
end;

procedure TWebFeaturesTests.TestNativeServerRepeatedCookies;
var
  Builder: IWebHostBuilder;
  Host: IWebHost;
  Options: TServerEngineOptions;
  CookieHeaders: TArray<string>;
  I: Integer;
  Cookie1Found, Cookie2Found, Cookie3Found: Boolean;
  Client: TIdTCPClient;
  RawLine: string;
begin
  Builder := TWebHost.CreateDefaultBuilder
    .UseUrls('http://127.0.0.1:60456');

  Builder.Configure(procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/cookie-test', procedure(Ctx: IHttpContext)
        var
          Opt1, Opt2, Opt3: TCookieOptions;
        begin
          Opt1 := TCookieOptions.Default;
          Opt1.HttpOnly := True;
          Opt1.Path := '/';

          Opt2 := TCookieOptions.Default;
          Opt2.Path := '/';

          Opt3 := TCookieOptions.Default;

          Ctx.Response.AppendCookie('session_id', 'abc123xyz', Opt1);
          Ctx.Response.AppendCookie('csrf_token', 'token_456', Opt2);
          Ctx.Response.AppendCookie('theme', 'dark', Opt3);
          Ctx.Response.Write('cookies-set');
        end);
    end);

  Host := Builder.Build;
  Options := TServerEngineOptions.Default.WithBindAddress('127.0.0.1');
  (Host as IWebApplication).UseNativeServer(Options);
  Host.Start;
  try
    // Send raw HTTP request via TCP to avoid HttpClient cookie manager stripping Set-Cookie headers
    Client := TIdTCPClient.Create(nil);
    try
      Client.Host := '127.0.0.1';
      Client.Port := Host.Port;
      Client.ConnectTimeout := 3000;
      Client.ReadTimeout := 3000;
      Client.Connect;

      Client.Socket.WriteLn('GET /cookie-test HTTP/1.1');
      Client.Socket.WriteLn('Host: 127.0.0.1:' + Host.Port.ToString);
      Client.Socket.WriteLn('Connection: close');
      Client.Socket.WriteLn('');

      RawLine := Client.Socket.ReadLn;
      Should(RawLine).Contain('200');

      SetLength(CookieHeaders, 0);
      repeat
        RawLine := Client.Socket.ReadLn;
        if SameText(Copy(RawLine, 1, 11), 'Set-Cookie:') then
        begin
          SetLength(CookieHeaders, Length(CookieHeaders) + 1);
          CookieHeaders[High(CookieHeaders)] := Trim(Copy(RawLine, 12, MaxInt));
        end;
      until RawLine = '';

      Should(Length(CookieHeaders)).Be(3);

      Cookie1Found := False;
      Cookie2Found := False;
      Cookie3Found := False;

      for I := 0 to High(CookieHeaders) do
      begin
        if Pos('session_id=abc123xyz', CookieHeaders[I]) > 0 then
          Cookie1Found := True;
        if Pos('csrf_token=token_456', CookieHeaders[I]) > 0 then
          Cookie2Found := True;
        if Pos('theme=dark', CookieHeaders[I]) > 0 then
          Cookie3Found := True;
      end;

      Should(Cookie1Found).BeTrue;
      Should(Cookie2Found).BeTrue;
      Should(Cookie3Found).BeTrue;
    finally
      Client.Free;
    end;
  finally
    Host.Stop;
  end;
end;

procedure TWebFeaturesTests.TestContextualResults;
var
  Builder: IWebHostBuilder;
  Host: IWebHost;
  Resp: IRestResponse;
begin
  Builder := TWebHost.CreateDefaultBuilder
    .UseUrls('http://127.0.0.1:18099');

  Builder.Configure(
    procedure(App: IApplicationBuilder)
    begin
      App.MapGet('/test-ok',
        procedure(Ctx: IHttpContext)
        begin
          Results.Context(Ctx).Ok('{"message": "success"}');
        end);

      App.MapGet('/test-bad-request',
        procedure(Ctx: IHttpContext)
        begin
          Results.Context(Ctx).BadRequest('Invalid ID');
        end);

      App.MapGet('/test-not-found',
        procedure(Ctx: IHttpContext)
        begin
          Results.Context(Ctx).NotFound('Invoice not found');
        end);
    end);

  Host := Builder.Build;
  Host.Start;
  try
    // 1. Test Ok
    Resp := RestClient('http://127.0.0.1:' + Host.Port.ToString)
      .Get('/test-ok')
      .Await;
    Should(Resp.StatusCode).Be(200);
    Should(Resp.ContentString).Contain('success');

    // 2. Test BadRequest
    Resp := RestClient('http://127.0.0.1:' + Host.Port.ToString)
      .Get('/test-bad-request')
      .Await;
    Should(Resp.StatusCode).Be(400);
    Should(Resp.ContentString).Contain('Invalid ID');

    // 3. Test NotFound
    Resp := RestClient('http://127.0.0.1:' + Host.Port.ToString)
      .Get('/test-not-found')
      .Await;
    Should(Resp.StatusCode).Be(404);
    Should(Resp.ContentString).Contain('Invoice not found');
  finally
    Host.Stop;
  end;
end;

initialization
  TGzipTestController.ClassName;

end.
