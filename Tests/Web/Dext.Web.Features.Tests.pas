unit Dext.Web.Features.Tests;

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
  System.SyncObjs;

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
  end;

implementation

uses
  Dext.Web.Indy;

type
  TTRestRequestHack = record
    Data: IRestRequestData;
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
    .UseUrls('http://localhost:0'); // Dynamic port selection

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
      HeaderVal := Provider.GetHeaderValue;

      // 3. Assert
      Should(HeaderVal).Be('Bearer mock-token-abc-123');
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
    .UseUrls('http://localhost:0');

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
    .UseUrls('http://localhost:0');

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

end.
