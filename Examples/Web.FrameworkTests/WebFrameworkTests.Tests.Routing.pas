unit WebFrameworkTests.Tests.Routing;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Web.ApplicationBuilder.Extensions,
  Dext.Web.HandlerInvoker,
  Dext.Web.Interfaces,
  Dext.Web.Results,
  WebFrameworkTests.Tests.Base;

type
  TRoutingTest = class(TBaseTest)
  protected
    procedure ConfigureHost(const Builder: IWebHostBuilder); override;
  public
    procedure Run; override;
  end;

implementation

{ TRoutingTest }

procedure TRoutingTest.ConfigureHost(const Builder: IWebHostBuilder);
begin
  inherited;
  Builder.Configure(procedure(App: IApplicationBuilder)
    var
      GetHandler: THandlerResultFunc<IResult>;
      PostHandler: THandlerResultFunc<IResult>;
      ParamHandler: THandlerProc<string, IHttpContext>;
    begin
      // Define handlers explicitly to help Delphi's compiler with generic resolution
      
      GetHandler := function: IResult
        begin
          Result := Results.Ok('GET OK');
        end;
        
      TApplicationBuilderExtensions.MapGetR<IResult>(
        App,
        '/test/get',
        GetHandler
      );

      PostHandler := function: IResult
        begin
          Result := Results.Ok('POST OK');
        end;

      TApplicationBuilderExtensions.MapPostR<IResult>(
        App,
        '/test/post',
        PostHandler
      );
      
      ParamHandler := procedure(Value: string; Ctx: IHttpContext)
        begin
          Ctx.Response.Write(Value);
        end;

      TApplicationBuilderExtensions.MapGet<string, IHttpContext>(
          App,
          '/test/param/{value}',
          ParamHandler
        );
    end);
end;

procedure TRoutingTest.Run;
begin
  Log('Running Routing Tests...');

  // Test GET
  var Resp := FClient.Get(GetBaseUrl + '/test/get');
  AssertTrue(Resp.StatusCode = 200, 'GET /test/get returned 200', 'GET /test/get returned ' + Resp.StatusCode.ToString);
  AssertEqual('GET OK', Resp.ContentAsString, 'GET Body');
  
  // Test POST
  // Explicitly use TStream(nil) to resolve overload ambiguity
  Resp := FClient.Post(GetBaseUrl + '/test/post', TStream(nil));
  AssertTrue(Resp.StatusCode = 200, 'POST /test/post returned 200', 'POST /test/post returned ' + Resp.StatusCode.ToString);
  AssertEqual('POST OK', Resp.ContentAsString, 'POST Body');

  // Test Param
  Resp := FClient.Get(GetBaseUrl + '/test/param/hello');
  AssertTrue(Resp.StatusCode = 200, 'GET /test/param/hello returned 200', 'GET /test/param/hello returned ' + Resp.StatusCode.ToString);
  AssertEqual('hello', Resp.ContentAsString, 'Param Body');
end;

end.
