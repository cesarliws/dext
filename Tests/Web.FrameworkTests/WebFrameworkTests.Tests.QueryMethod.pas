unit WebFrameworkTests.Tests.QueryMethod;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.Net.HttpClient,
  System.Net.URLClient,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.HandlerInvoker,
  Dext.Web.Interfaces,
  Dext.Web.Results,
  Dext.OpenAPI.Extensions,
  Dext.Net.RestClient,
  Dext.Net.RestRequest,
  Dext.Mocks,
  Dext.Web.Mocks,
  Dext.Caching,
  WebFrameworkTests.Tests.Base;

type
  TQueryPayload = record
    Query: string;
    Limit: Integer;
  end;

  TQueryMethodTest = class(TBaseTest)
  protected
    procedure ConfigureHost(const Builder: IWebHostBuilder); override;
  public
    procedure Run; override;
  end;

implementation

uses
  Dext.Json;

{ Class Helper to access private GenerateCacheKey for testing }
type
  TResponseCacheMiddlewareHelper = class helper for TResponseCacheMiddleware
  public
    function TestGenerateCacheKey(AContext: IHttpContext): string;
  end;

function TResponseCacheMiddlewareHelper.TestGenerateCacheKey(AContext: IHttpContext): string;
begin
  Result := Self.GenerateCacheKey(AContext);
end;

{ TQueryMethodTest }

function GetHeaderValue(const Resp: System.Net.HttpClient.IHTTPResponse; const Name: string): string;
var
  Header: TNameValuePair;
begin
  Result := '';
  for Header in Resp.Headers do
  begin
    if SameText(Header.Name, Name) then
    begin
      Result := Header.Value;
      Exit;
    end;
  end;
end;

procedure TQueryMethodTest.ConfigureHost(const Builder: IWebHostBuilder);
begin
  inherited;
  Builder.Configure(procedure(App: IApplicationBuilder)
    var
      QueryHandler: THandlerResultFunc<IResult>;
      BindHandler: THandlerResultFunc<TQueryPayload, IResult>;
    begin
      QueryHandler := function: IResult
        begin
          Result := Results.Ok('QUERY OK');
        end;

      TApplicationBuilderExtensions.MapQueryResult<IResult>(
        App,
        '/test/query',
        QueryHandler
      );
      
      TEndpointMetadataExtensions.AcceptsQuery(App, ['application/jsonpath', 'application/sql']);

      BindHandler := function(Payload: TQueryPayload): IResult
        begin
          if (Payload.Query = 'active') and (Payload.Limit = 10) then
            Result := Results.Ok('BIND OK')
          else
            Result := Results.BadRequest('BIND FAILED');
        end;

      TApplicationBuilderExtensions.MapQueryResult<TQueryPayload, IResult>(
        App,
        '/test/query-bind',
        BindHandler
      );
    end);
end;

procedure TQueryMethodTest.Run;
var
  Client: TRestClient;
  Resp: IRestResponse;
  Payload: TQueryPayload;
  RawResp: System.Net.HttpClient.IHTTPResponse;
  AllowHeader, AcceptQueryHeader: string;
  MockReq1, MockReq2: Mock<IHttpRequest>;
  Ctx1, Ctx2: IHttpContext;
  Cache: TResponseCacheMiddleware;
  Key1, Key2: string;
  Stream1, Stream2: TStringStream;
  EmptyCookies, EmptyHeaders, EmptyQuery: IStringDictionary;
  EmptyRoute: TRouteValueDictionary;
begin
  Log('Running HTTP QUERY Method Tests...');

  // Test simple QUERY using TRestClient
  Client := TRestClient.Create(GetBaseUrl);
  Resp := Client.Query('/test/query').Await;
  AssertTrue(Resp.StatusCode = 200, 'QUERY /test/query returned 200', 'QUERY /test/query returned ' + Resp.StatusCode.ToString);
  AssertEqual('QUERY OK', Resp.ContentString, 'QUERY Body');

  // Test QUERY using TRestRequest fluent builder
  Payload.Query := 'active';
  Payload.Limit := 10;
  Resp := Client.Request.Query('/test/query-bind').Body(Payload).Execute.Await;
  AssertTrue(Resp.StatusCode = 200, 'QUERY /test/query-bind returned 200', 'QUERY /test/query-bind returned ' + Resp.StatusCode.ToString);
  AssertEqual('BIND OK', Resp.ContentString, 'QUERY Bind Body');

  // Test OPTIONS request to check Allow headers containing QUERY
  RawResp := FClient.Options(GetBaseUrl + '/test/query');
  AssertTrue(RawResp.StatusCode = 200, 'OPTIONS returned 200', 'OPTIONS returned ' + RawResp.StatusCode.ToString);
  
  AllowHeader := GetHeaderValue(RawResp, 'Allow');
  AssertTrue(AllowHeader.Contains('QUERY'), 'Allow header contains QUERY', 'Allow header: ' + AllowHeader);
  
  AcceptQueryHeader := GetHeaderValue(RawResp, 'Accept-Query');
  AssertTrue(AcceptQueryHeader.Contains('application/jsonpath'), 'Accept-Query contains jsonpath', 'Accept-Query: ' + AcceptQueryHeader);

  // Test Cache Key Generation for QUERY requests
  Cache := TResponseCacheMiddleware.Create(TResponseCacheOptions.Create(60));
  try
    Stream1 := TStringStream.Create('{"query":"active"}', TEncoding.UTF8);
    Stream2 := TStringStream.Create('{"query":"inactive"}', TEncoding.UTF8);
    try
      EmptyHeaders := TCollections.CreateStringDictionary(True);
      EmptyCookies := TCollections.CreateStringDictionary(True);
      EmptyQuery := TCollections.CreateStringDictionary(True);
      EmptyRoute.Clear;

      MockReq1 := Mock<IHttpRequest>.Create;
      MockReq1.Setup.Returns(System.Rtti.TValue.From<string>('QUERY')).When.GetMethod;
      MockReq1.Setup.Returns(System.Rtti.TValue.From<string>('/api/test')).When.GetPath;
      MockReq1.Setup.Returns(System.Rtti.TValue.From<TStream>(Stream1)).When.GetBody;
      MockReq1.Setup.Returns(System.Rtti.TValue.From<IStringDictionary>(EmptyHeaders)).When.GetHeaders;
      MockReq1.Setup.Returns(System.Rtti.TValue.From<IStringDictionary>(EmptyCookies)).When.GetCookies;
      MockReq1.Setup.Returns(System.Rtti.TValue.From<IStringDictionary>(EmptyQuery)).When.GetQuery;
      MockReq1.Setup.Returns(System.Rtti.TValue.From<TRouteValueDictionary>(EmptyRoute)).When.GetRouteParams;

      MockReq2 := Mock<IHttpRequest>.Create;
      MockReq2.Setup.Returns(System.Rtti.TValue.From<string>('QUERY')).When.GetMethod;
      MockReq2.Setup.Returns(System.Rtti.TValue.From<string>('/api/test')).When.GetPath;
      MockReq2.Setup.Returns(System.Rtti.TValue.From<TStream>(Stream2)).When.GetBody;
      MockReq2.Setup.Returns(System.Rtti.TValue.From<IStringDictionary>(EmptyHeaders)).When.GetHeaders;
      MockReq2.Setup.Returns(System.Rtti.TValue.From<IStringDictionary>(EmptyCookies)).When.GetCookies;
      MockReq2.Setup.Returns(System.Rtti.TValue.From<IStringDictionary>(EmptyQuery)).When.GetQuery;
      MockReq2.Setup.Returns(System.Rtti.TValue.From<TRouteValueDictionary>(EmptyRoute)).When.GetRouteParams;

      Ctx1 := TMockHttpContext.Create(MockReq1.Instance, TMockHttpResponse.Create);
      Ctx2 := TMockHttpContext.Create(MockReq2.Instance, TMockHttpResponse.Create);

      Key1 := Cache.TestGenerateCacheKey(Ctx1);
      Key2 := Cache.TestGenerateCacheKey(Ctx2);

      AssertTrue(Key1 <> Key2, 'Cache keys for different QUERY request bodies must be different', 'Key1: ' + Key1 + ', Key2: ' + Key2);
    finally
      Stream1.Free;
      Stream2.Free;
    end;
  finally
    Cache.Free;
  end;
end;

end.
