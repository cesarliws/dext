// Dext.Web.Mocks.pas
unit Dext.Web.Mocks;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Rtti,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.Auth.Identity,
  Dext.Mocks,
  Dext.Mocks.Matching,
  Dext.Web.Results,
  Dext.Json,
  Dext.Server.Engine.Interfaces;

type
  TMockHttpRequest = class
  public
    class function CreateInternal(const AQueryString: string; ABody: TStream): IHttpRequest; static;
    class function Create(const AQueryString: string): IHttpRequest; static;
  end;

  TMockHttpResponse = class
  public
    class function Create: IHttpResponse; static;
  end;

  TMockHttpContext = class
  public
    class function Create(ARequest: IHttpRequest; AResponse: IHttpResponse; AServices: IServiceProvider = nil): IHttpContext; static;
  end;

  TMockFactory = class
  public
    class function CreateHttpContext(const AQueryString: string): IHttpContext; static;
    class function CreateHttpContextWithBody(const AQueryString: string; ABody: TStream): IHttpContext; static;
    class function CreateHttpContextWithHeaders(const AQueryString: string; const AHeaders: IDictionary<string, string>): IHttpContext; overload;
    class function CreateHttpContextWithHeaders(const AQueryString: string; const AHeaders: IStringDictionary): IHttpContext; overload;
    class function CreateHttpContextWithRoute(const AQueryString: string; const ARouteParams: IDictionary<string, string>): IHttpContext; static;
    class function CreateHttpContextWithServices(const AQueryString: string; const AServices: IServiceProvider): IHttpContext; static;
  end;

var
  SharedEmptyStream: TMemoryStream;

implementation

type
  TStatefulMockResponse = class(TInterfacedObject, IHttpResponse)
  private
    FStatusCode: Integer;
    FContentType: string;
    FHeaders: IStringDictionary;
  public
    constructor Create;

    function GetHtmx: IHtmxResponse;
    function GetHeaders: IStringDictionary;

    function GetContentType: string;
    function GetStatusCode: Integer;
    function Status(AValue: Integer): IHttpResponse;

    procedure AddHeader(const AName, AValue: string);
    procedure AppendCookie(const AName, AValue: string); overload;
    procedure AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions); overload;
    procedure DeleteCookie(const AName: string);
    procedure Json(const AJson: string); overload;
    procedure Json(const AValue: TValue); overload;
    procedure SetContentLength(const AValue: Int64);
    procedure SetContentType(const AValue: string);
    procedure SetStatusCode(AValue: Integer);
    procedure Flush;
    procedure Write(const ABuffer: TBytes); overload;
    procedure Write(const AContent: string); overload;
    procedure Write(const AStream: TStream); overload;

    procedure Redirect(const AUrl: string; APermanent: Boolean = False);
    procedure Unauthorized(const AMessage: string = '');
    procedure Forbidden(const AMessage: string = '');
    procedure BadRequest(const AMessage: string = '');
    procedure NotFound(const AMessage: string = '');

    property ContentType: string read GetContentType write SetContentType;
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
  end;

  TStatefulMockHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
    FServices: IServiceProvider;
    FUser: IClaimsPrincipal;
    FItems: IDictionary<string, TValue>;
  public
    constructor Create(ARequest: IHttpRequest; AResponse: IHttpResponse; AServices: IServiceProvider);

    function GetConnection: IDextServerConnection;
    function GetItems: IDictionary<string, TValue>;
    function GetRequest: IHttpRequest;
    function GetResponse: IHttpResponse;
    function GetServices: IServiceProvider;
    function GetUser: IClaimsPrincipal;
    function GetSession: IStreamableSession;

    procedure SetResponse(const AValue: IHttpResponse);
    procedure SetServices(const AValue: IServiceProvider);
    procedure SetUser(const AValue: IClaimsPrincipal);
    property Items: IDictionary<string, TValue> read GetItems;

    property Connection: IDextServerConnection read GetConnection;
    property Request: IHttpRequest read GetRequest;
    property Response: IHttpResponse read GetResponse write SetResponse;
    property Services: IServiceProvider read GetServices write SetServices;
    property User: IClaimsPrincipal read GetUser write SetUser;
  end;

{ Helper }

procedure ParseQueryStringInto(const AQueryString: string; out ADict: IStringDictionary);
var
  I, PosEqual: Integer;
  Key, Value, QueryPart: string;
  ParamList: TStringList;
  PosQuery: Integer;
begin
  ADict := TCollections.CreateStringDictionary(True); // Case-insensitive
  if AQueryString = '' then Exit;

  QueryPart := AQueryString;
  PosQuery := Pos('?', AQueryString);
  if PosQuery > 0 then
    QueryPart := Copy(AQueryString, PosQuery + 1, MaxInt);

  ParamList := TStringList.Create;
  try
    ParamList.Delimiter := '&';
    ParamList.StrictDelimiter := True;
    ParamList.DelimitedText := QueryPart;
    for I := 0 to ParamList.Count - 1 do
    begin
      PosEqual := Pos('=', ParamList[I]);
      if PosEqual > 0 then
      begin
        Key := Copy(ParamList[I], 1, PosEqual - 1);
        Value := Copy(ParamList[I], PosEqual + 1, MaxInt);
        ADict.AddOrSetValue(Key, Value);
      end
      else
        ADict.AddOrSetValue(ParamList[I], '');
    end;
  finally
    ParamList.Free;
  end;
end;

{ TMockHttpRequest }

class function TMockHttpRequest.CreateInternal(const AQueryString: string; ABody: TStream): IHttpRequest;
var
  BodyToUse: TStream;
  EmptyCookies: IStringDictionary;
  EmptyHeaders: IStringDictionary;
  EmptyRoute: TRouteValueDictionary;
  MockReq: Mock<IHttpRequest>;
  QueryParams: IStringDictionary;
begin
  MockReq := Mock<IHttpRequest>.Create;
  
  BodyToUse := ABody;
  if BodyToUse = nil then
    BodyToUse := SharedEmptyStream;

  ParseQueryStringInto(AQueryString, QueryParams);
  EmptyHeaders := TCollections.CreateStringDictionary(True);
  EmptyCookies := TCollections.CreateStringDictionary(True);
  EmptyRoute.Clear; 

  MockReq.Setup.Returns(TValue.From<IStringDictionary>(QueryParams)).When.GetQuery;
  MockReq.Setup.Returns(TValue.From<IStringDictionary>(EmptyHeaders)).When.GetHeaders;
  MockReq.Setup.Returns(TValue.From<IStringDictionary>(EmptyCookies)).When.GetCookies;
  MockReq.Setup.Returns(TValue.From<TRouteValueDictionary>(EmptyRoute)).When.GetRouteParams;
  
  // Default values
  MockReq.Setup.Returns(TValue.From<string>('GET')).When.GetMethod;
  MockReq.Setup.Returns(TValue.From<string>('/api/test')).When.GetPath;
  MockReq.Setup.Returns(TValue.From<string>('127.0.0.1')).When.GetRemoteIpAddress;
  MockReq.Setup.Returns(TValue.From<TStream>(BodyToUse)).When.GetBody;

  Result := MockReq.Instance;
end;

class function TMockHttpRequest.Create(const AQueryString: string): IHttpRequest;
begin
  Result := CreateInternal(AQueryString, nil);
end;

{ TMockHttpResponse }

class function TMockHttpResponse.Create: IHttpResponse;
begin
  Result := TStatefulMockResponse.Create;
end;

{ TStatefulMockResponse }

constructor TStatefulMockResponse.Create;
begin
  inherited Create;
  FStatusCode := 200;
  FContentType := 'text/plain';
  FHeaders := TCollections.CreateStringDictionary(True);
end;

function TStatefulMockResponse.GetHtmx: IHtmxResponse;
begin
  Result := THtmxResponse.Create(Self);
end;

function TStatefulMockResponse.GetHeaders: IStringDictionary;
begin
  Result := FHeaders;
end;

function TStatefulMockResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TStatefulMockResponse.GetContentType: string;
begin
  Result := FContentType;
end;

function TStatefulMockResponse.Status(AValue: Integer): IHttpResponse;
begin
  FStatusCode := AValue;
  Result := Self;
end;

procedure TStatefulMockResponse.SetStatusCode(AValue: Integer);
begin
  FStatusCode := AValue;
end;

procedure TStatefulMockResponse.SetContentType(const AValue: string);
begin
  FContentType := AValue;
end;

procedure TStatefulMockResponse.SetContentLength(const AValue: Int64);
begin
end;

procedure TStatefulMockResponse.Flush;
begin
end;

procedure TStatefulMockResponse.Write(const AContent: string);
begin
end;

procedure TStatefulMockResponse.Write(const ABuffer: TBytes);
begin
end;

procedure TStatefulMockResponse.Write(const AStream: TStream);
begin
end;

procedure TStatefulMockResponse.Json(const AJson: string);
begin
  FContentType := 'application/json';
end;

procedure TStatefulMockResponse.Json(const AValue: TValue);
begin
  FContentType := 'application/json';
end;

procedure TStatefulMockResponse.AddHeader(const AName, AValue: string);
begin
  FHeaders.AddOrSetValue(AName, AValue);
end;

procedure TStatefulMockResponse.AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions);
begin
end;

procedure TStatefulMockResponse.AppendCookie(const AName, AValue: string);
begin
end;

procedure TStatefulMockResponse.DeleteCookie(const AName: string);
begin
end;

procedure TStatefulMockResponse.Redirect(const AUrl: string; APermanent: Boolean);
begin
  if APermanent then
    FStatusCode := 301
  else
    FStatusCode := 302;
  FHeaders.AddOrSetValue('Location', AUrl);
end;

procedure TStatefulMockResponse.Unauthorized(const AMessage: string);
begin
  FStatusCode := 401;
end;

procedure TStatefulMockResponse.Forbidden(const AMessage: string);
begin
  FStatusCode := 403;
end;

procedure TStatefulMockResponse.BadRequest(const AMessage: string);
begin
  FStatusCode := 400;
end;

procedure TStatefulMockResponse.NotFound(const AMessage: string);
begin
  FStatusCode := 404;
end;

{ TMockHttpContext }

class function TMockHttpContext.Create(ARequest: IHttpRequest; AResponse: IHttpResponse;
  AServices: IServiceProvider): IHttpContext;
begin
  Result := TStatefulMockHttpContext.Create(ARequest, AResponse, AServices);
end;

{ TStatefulMockHttpContext }

constructor TStatefulMockHttpContext.Create(ARequest: IHttpRequest; AResponse: IHttpResponse;
  AServices: IServiceProvider);
begin
  inherited Create;
  FRequest := ARequest;
  FResponse := AResponse;
  FServices := AServices;
  FItems := TCollections.CreateDictionary<string, TValue>;
end;

function TStatefulMockHttpContext.GetConnection: IDextServerConnection;
begin
  Result := nil;
end;

function TStatefulMockHttpContext.GetRequest: IHttpRequest;
begin
  Result := FRequest;
end;

function TStatefulMockHttpContext.GetResponse: IHttpResponse;
begin
  Result := FResponse;
end;

procedure TStatefulMockHttpContext.SetResponse(const AValue: IHttpResponse);
begin
  FResponse := AValue;
end;

function TStatefulMockHttpContext.GetServices: IServiceProvider;
begin
  Result := FServices;
end;

procedure TStatefulMockHttpContext.SetServices(const AValue: IServiceProvider);
begin
  FServices := AValue;
end;

function TStatefulMockHttpContext.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

function TStatefulMockHttpContext.GetSession: IStreamableSession;
begin
  Result := nil;
end;

procedure TStatefulMockHttpContext.SetUser(const AValue: IClaimsPrincipal);
begin
  FUser := AValue;
end;

function TStatefulMockHttpContext.GetItems: IDictionary<string, TValue>;
begin
  Result := FItems;
end;

{ TMockFactory }

class function TMockFactory.CreateHttpContext(const AQueryString: string): IHttpContext;
begin
  Result := CreateHttpContextWithServices(AQueryString, nil);
end;

class function TMockFactory.CreateHttpContextWithServices(const AQueryString: string;
  const AServices: IServiceProvider): IHttpContext;
begin
  Result := TMockHttpContext.Create(TMockHttpRequest.Create(AQueryString), TMockHttpResponse.Create, AServices);
end;

class function TMockFactory.CreateHttpContextWithHeaders(const AQueryString: string;
  const AHeaders: IStringDictionary): IHttpContext;
var
  EmptyCookies: IStringDictionary;
  EmptyRoute: TRouteValueDictionary;
  MockReq: Mock<IHttpRequest>;
  QueryParams: IStringDictionary;
begin
  MockReq := Mock<IHttpRequest>.Create;
  
  ParseQueryStringInto(AQueryString, QueryParams);
  EmptyCookies := TCollections.CreateStringDictionary(True);
  EmptyRoute.Clear;

  MockReq.Setup.Returns(TValue.From<IStringDictionary>(QueryParams)).When.GetQuery;
  MockReq.Setup.Returns(TValue.From<IStringDictionary>(AHeaders)).When.GetHeaders;
  MockReq.Setup.Returns(TValue.From<IStringDictionary>(EmptyCookies)).When.GetCookies;
  MockReq.Setup.Returns(TValue.From<TRouteValueDictionary>(EmptyRoute)).When.GetRouteParams;
  
  MockReq.Setup.Returns(TValue.From<string>('GET')).When.GetMethod;
  MockReq.Setup.Returns(TValue.From<string>('/api/test')).When.GetPath;
  MockReq.Setup.Returns(TValue.From<string>('127.0.0.1')).When.GetRemoteIpAddress;
  MockReq.Setup.Returns(TValue.From<TStream>(SharedEmptyStream)).When.GetBody;

  Result := TMockHttpContext.Create(MockReq.Instance, TMockHttpResponse.Create, nil);
end;

class function TMockFactory.CreateHttpContextWithHeaders(const AQueryString: string;
  const AHeaders: IDictionary<string, string>): IHttpContext;
var
  NewHeaders: IStringDictionary;
  Pair: TPair<string, string>;
begin
  NewHeaders := TCollections.CreateStringDictionary(True);
  for Pair in AHeaders do
    NewHeaders.AddOrSetValue(Pair.Key, Pair.Value);
  Result := CreateHttpContextWithHeaders(AQueryString, NewHeaders);
end;

class function TMockFactory.CreateHttpContextWithRoute(const AQueryString: string;
  const ARouteParams: IDictionary<string, string>): IHttpContext;
var
  EmptyCookies: IStringDictionary;
  EmptyHeaders: IStringDictionary;
  MockReq: Mock<IHttpRequest>;
  Pair: TPair<string, string>;
  QueryParams: IStringDictionary;
  RouteValDict: TRouteValueDictionary;
begin
  MockReq := Mock<IHttpRequest>.Create;
  
  ParseQueryStringInto(AQueryString, QueryParams);
  EmptyHeaders := TCollections.CreateStringDictionary(True);
  EmptyCookies := TCollections.CreateStringDictionary(True);
  
  RouteValDict.Clear;
  for Pair in ARouteParams do
    RouteValDict.Add(Pair.Key, Pair.Value);

  // Set up standard getters
  MockReq.Setup.Returns(TValue.From<IStringDictionary>(QueryParams)).When.GetQuery;
  MockReq.Setup.Returns(TValue.From<IStringDictionary>(EmptyHeaders)).When.GetHeaders;
  MockReq.Setup.Returns(TValue.From<IStringDictionary>(EmptyCookies)).When.GetCookies;
  MockReq.Setup.Returns(TValue.From<TRouteValueDictionary>(RouteValDict)).When.GetRouteParams;
  MockReq.Setup.Returns(TValue.From<string>('GET')).When.GetMethod;
  MockReq.Setup.Returns(TValue.From<string>('/api/test')).When.GetPath;
  MockReq.Setup.Returns(TValue.From<string>('127.0.0.1')).When.GetRemoteIpAddress;
  MockReq.Setup.Returns(TValue.From<TStream>(SharedEmptyStream)).When.GetBody;

  Result := TMockHttpContext.Create(MockReq.Instance, TMockHttpResponse.Create, nil);
end;

class function TMockFactory.CreateHttpContextWithBody(const AQueryString: string; ABody: TStream): IHttpContext;
begin
  Result := TMockHttpContext.Create(TMockHttpRequest.CreateInternal(AQueryString, ABody), TMockHttpResponse.Create, nil);
end;

initialization
  SharedEmptyStream := TMemoryStream.Create;

finalization
  SharedEmptyStream.Free;

end.
