unit Dext.Web.PathBase.Tests;

interface

uses
  System.Classes,
  System.SysUtils,
  Dext.Collections.Dict,
  Dext.Testing.Attributes,
  Dext.Assertions,
  Dext.Web,
  Dext.Web.Interfaces,
  Dext.Web.PathBase,
  Dext.Web.Mocks,
  Dext.Net.RestClient,
  Dext.Server.Native,
  Dext.Server.Engine.Interfaces,
  Dext.Server.Engine.Types;

type
  [TestFixture('Base Path Middleware & URL Building Tests')]
  TPathBaseTests = class
  public
    [Test('Should strip path base and populate Request.PathBase')]
    procedure TestPathBaseStripping;

    [Test('Should strip path base when request equals path base exactly')]
    procedure TestPathBaseExactMatch;

    [Test('Should not strip path base on non-segment boundary')]
    procedure TestPathBaseNonBoundary;

    [Test('Should format absolute app URLs via ToAppUrl')]
    procedure TestToAppUrl;

    [Test('Should serve real HTTP.sys requests under base path')]
    procedure TestRealHttpSysBasePathIntegration;
  end;

implementation

type
  TMockRawRequest = class(TInterfacedObject, IDextRawRequest)
  private
    FPath: string;
  public
    constructor Create(const APath: string);
    function GetMethod: string;
    function GetPath: string;
    function GetQueryString: string;
    function GetHeader(const AName: string): string;
    procedure PopulateHeaders(ADict: TDictionary<string, string>);
    function GetContentLength: Int64;
    function GetBodyStream: TStream;
  end;

{ TMockRawRequest }

constructor TMockRawRequest.Create(const APath: string);
begin
  inherited Create;
  FPath := APath;
end;

function TMockRawRequest.GetMethod: string; begin Result := 'GET'; end;
function TMockRawRequest.GetPath: string; begin Result := FPath; end;
function TMockRawRequest.GetQueryString: string; begin Result := ''; end;
function TMockRawRequest.GetHeader(const AName: string): string; begin Result := ''; end;
procedure TMockRawRequest.PopulateHeaders(ADict: TDictionary<string, string>); begin end;
function TMockRawRequest.GetContentLength: Int64; begin Result := 0; end;
function TMockRawRequest.GetBodyStream: TStream; begin Result := nil; end;

{ TPathBaseTests }

procedure TPathBaseTests.TestPathBaseStripping;
var
  RawReq: IDextRawRequest;
  Req: IHttpRequest;
  Ctx: IHttpContext;
  Middleware: IMiddleware;
begin
  RawReq := TMockRawRequest.Create('/myapp/login');
  Req := TDextNativeHttpRequest.Create(RawReq, '127.0.0.1');
  Ctx := TMockHttpContext.Create(Req, nil, nil);
  Middleware := TDextPathBaseMiddleware.Create('/myapp');

  Middleware.Invoke(Ctx,
    procedure(C: IHttpContext)
    begin
      Should(C.Request.PathBase).Be('/myapp');
      Should(C.Request.Path).Be('/login');
    end);
end;

procedure TPathBaseTests.TestPathBaseExactMatch;
var
  RawReq: IDextRawRequest;
  Req: IHttpRequest;
  Ctx: IHttpContext;
  Middleware: IMiddleware;
begin
  RawReq := TMockRawRequest.Create('/myapp');
  Req := TDextNativeHttpRequest.Create(RawReq, '127.0.0.1');
  Ctx := TMockHttpContext.Create(Req, nil, nil);
  Middleware := TDextPathBaseMiddleware.Create('/myapp');

  Middleware.Invoke(Ctx,
    procedure(C: IHttpContext)
    begin
      Should(C.Request.PathBase).Be('/myapp');
      Should(C.Request.Path).Be('/');
    end);
end;

procedure TPathBaseTests.TestPathBaseNonBoundary;
var
  RawReq: IDextRawRequest;
  Req: IHttpRequest;
  Ctx: IHttpContext;
  Middleware: IMiddleware;
begin
  RawReq := TMockRawRequest.Create('/myappother/login');
  Req := TDextNativeHttpRequest.Create(RawReq, '127.0.0.1');
  Ctx := TMockHttpContext.Create(Req, nil, nil);
  Middleware := TDextPathBaseMiddleware.Create('/myapp');

  Middleware.Invoke(Ctx,
    procedure(C: IHttpContext)
    begin
      Should(C.Request.PathBase).Be('');
      Should(C.Request.Path).Be('/myappother/login');
    end);
end;

procedure TPathBaseTests.TestToAppUrl;
var
  RawReq: IDextRawRequest;
  Req: IHttpRequest;
begin
  RawReq := TMockRawRequest.Create('/myapp/swagger');
  Req := TDextNativeHttpRequest.Create(RawReq, '127.0.0.1');
  Req.SetPathBase('/myapp');

  Should(Req.ToAppUrl('/swagger')).Be('/myapp/swagger');
  Should(Req.ToAppUrl('swagger')).Be('/myapp/swagger');
  Should(Req.ToAppUrl('')).Be('/myapp');

  Req.SetPathBase('');
  Should(Req.ToAppUrl('/swagger')).Be('/swagger');
end;

procedure TPathBaseTests.TestRealHttpSysBasePathIntegration;
var
  App: IWebApplication;
  Resp: IRestResponse;
  Options: TServerEngineOptions;
begin
  App := WebApplication;
  try
    App.UsePathBase('/testapp');
    App.GetApplicationBuilder.Use(
      procedure(Ctx: IHttpContext; Next: TRequestDelegate)
      begin
        if Ctx.Request.Path = '/ping' then
          Ctx.Response.Write('PathBase=' + Ctx.Request.PathBase +
            ',Path=' + Ctx.Request.Path)
        else
          Next(Ctx);
      end);
    Options := TServerEngineOptions.Default.WithBindAddress('127.0.0.1');
    App.UseNativeServer(Options);
    App.Start(9095);
    try
      Should(App.Port).Be(9095);

      Resp := RestClient('http://127.0.0.1:' + App.Port.ToString)
        .Get('/testapp/ping')
        .Await;

      Should(Resp.StatusCode).Be(200);
      Should(Resp.ContentString).Be('PathBase=/testapp,Path=/ping');
    finally
      App.Stop;
    end;
  finally
    App := nil;
  end;
end;

end.
