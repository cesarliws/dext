// Dext.Http.Mocks.pas
unit Dext.Http.Mocks;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  System.TypInfo,
  Dext.DI.Interfaces,
  Dext.Http.Indy,
  Dext.Http.Interfaces,
  Dext.Auth.Identity;

type
  TMockHttpRequest = class(TInterfacedObject, IHttpRequest)
  private
    FMethod: string;
    FPath: string;
    FQueryParams: TStrings;
    FBodyStream: TStream;
    FRouteParams: TDictionary<string, string>;
    FHeaders: TDictionary<string, string>;
    FRemoteIpAddress: string;
  public
    constructor Create(const AQueryString: string; const AMethod: string = 'GET'; const APath: string = '/api/test');
    destructor Destroy; override;

    // IHttpRequest
    function GetMethod: string;
    function GetPath: string;
    function GetQuery: TStrings;
    function GetBody: TStream;
    function GetRouteParams: TDictionary<string, string>;
    function GetHeaders: TDictionary<string, string>; virtual;
    function GetRemoteIpAddress: string;

    property RemoteIpAddress: string read FRemoteIpAddress write FRemoteIpAddress;
  end;

  TMockHttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FStatusCode: Integer;
    FContentType: string;
    FContentText: string;
    FCustomHeaders: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;

    // IHttpResponse
    function GetStatusCode: Integer;
    function Status(AValue: Integer): IHttpResponse;
    procedure SetStatusCode(AValue: Integer);
    procedure SetContentType(const AValue: string);
    procedure SetContentLength(const AValue: Int64);
    procedure Write(const AContent: string); overload;
    procedure Write(const ABuffer: TBytes); overload;
    procedure Json(const AJson: string);
    procedure AddHeader(const AName, AValue: string);

    // Propriedades para teste
    property StatusCode: Integer read FStatusCode;
    property ContentText: string read FContentText;
  end;

  TMockHttpContext = class(TInterfacedObject, IHttpContext)
  private
    FRequest: IHttpRequest;
    FResponse: IHttpResponse;
    FServices: IServiceProvider;
    FUser: IClaimsPrincipal;
  public
    constructor Create(ARequest: IHttpRequest; AResponse: IHttpResponse;
      AServices: IServiceProvider = nil);

    // IHttpContext
    function GetRequest: IHttpRequest;

    function GetResponse: IHttpResponse;
    procedure SetResponse(const AValue: IHttpResponse);

    function GetServices: IServiceProvider; virtual;
    procedure SetServices(const AValue: IServiceProvider);

    function GetUser: IClaimsPrincipal;
    procedure SetUser(const AValue: IClaimsPrincipal);

    procedure SetRouteParams(const AParams: TDictionary<string, string>);
  end;

  TMockHttpRequestWithHeaders = class(TMockHttpRequest)
  private
    FCustomHeaders: TDictionary<string, string>;
  public
    constructor CreateWithHeaders(const AQueryString: string;
      const AHeaders: TDictionary<string, string>);
    destructor Destroy; override;
    function GetHeaders: TDictionary<string, string>; override;
  end;

  TMockHttpContextWithServices = class(TMockHttpContext)
  private
    FCustomServices: IServiceProvider;
  public
    constructor CreateWithServices(ARequest: IHttpRequest;
      AResponse: IHttpResponse; AServices: IServiceProvider);
    function GetServices: IServiceProvider; override;
  end;

  TMockFactory = class
  public
    class function CreateHttpContextWithHeaders(const AQueryString: string; const
      AHeaders: TDictionary<string, string>): IHttpContext;
    class function CreateHttpContextWithServices(const AQueryString: string; const
      AServices: IServiceProvider): IHttpContext;
    class function CreateHttpContext(const AQueryString: string): IHttpContext; static;
    class function CreateHttpContextWithRoute(const AQueryString: string; const
      ARouteParams: TDictionary<string, string>): IHttpContext; static;
  end;

implementation

{ TMockHttpRequest }

constructor TMockHttpRequest.Create(const AQueryString: string; const AMethod: string = 'GET'; const APath: string = '/api/test');
var
  I, PosEqual: Integer;
  ParamList: TStringList;
  Key, Value: string;
begin
  inherited Create;
  FMethod := AMethod;
  FPath := APath;

  FRouteParams := TDictionary<string, string>.Create;

  // ✅ CORREÇÃO: Parse manual garantido
  FQueryParams := TStringList.Create;

  if AQueryString <> '' then
  begin
    // ✅ SEPARAR path de query string
    var QueryPart := AQueryString;
    var PosQuery := Pos('?', AQueryString);
    if PosQuery > 0 then
      QueryPart := Copy(AQueryString, PosQuery + 1, MaxInt);

    ParamList := TStringList.Create;
    try
      ParamList.Delimiter := '&';
      ParamList.StrictDelimiter := True;
      ParamList.DelimitedText := QueryPart; // ✅ Só a parte depois do ?

      for I := 0 to ParamList.Count - 1 do
      begin
        PosEqual := Pos('=', ParamList[I]);
        if PosEqual > 0 then
        begin
          Key := Copy(ParamList[I], 1, PosEqual - 1);
          Value := Copy(ParamList[I], PosEqual + 1, MaxInt);
          FQueryParams.Values[Key] := Value;
        end;
      end;
    finally
      ParamList.Free;
    end;
  end;

  // Inicializar outros campos
  FHeaders := TDictionary<string, string>.Create;
  FBodyStream := TMemoryStream.Create;
  FRemoteIpAddress := '127.0.0.1'; // Default mock IP

  // ✅ DEBUG: Log do que foi parseado
  Writeln('Mock Request Created:');
  Writeln('  QueryString: ', AQueryString);
  Writeln('  Parsed params: ', FQueryParams.Count);
  for I := 0 to FQueryParams.Count - 1 do
    Writeln('    ', FQueryParams.Names[I], ' = ', FQueryParams.ValueFromIndex[I]);
end;

destructor TMockHttpRequest.Destroy;
begin
  FQueryParams.Free;
  FRouteParams.Free;
  FHeaders.Free;
  FBodyStream.Free;
  inherited Destroy;
end;

function TMockHttpRequest.GetMethod: string;
begin
  Result := FMethod;
end;

function TMockHttpRequest.GetPath: string;
begin
  Result := FPath;
end;

function TMockHttpRequest.GetQuery: TStrings;
begin
  Result := FQueryParams; // ✅ AGORA NÃO É MAIS NIL!
end;

function TMockHttpRequest.GetBody: TStream;
begin
  Result := FBodyStream;
end;

function TMockHttpRequest.GetRouteParams: TDictionary<string, string>;
begin
  Writeln('🔍 GetRouteParams Debug:');
  Writeln('  Returning FRouteParams count: ', FRouteParams.Count);
  Result := FRouteParams;
end;

function TMockHttpRequest.GetHeaders: TDictionary<string, string>;
begin
  Result := FHeaders;
end;

function TMockHttpRequest.GetRemoteIpAddress: string;
begin
  Result := FRemoteIpAddress;
end;

{ TMockHttpResponse }

constructor TMockHttpResponse.Create;
begin
  inherited Create;
  FStatusCode := 200;
  FContentType := 'text/plain';
  FCustomHeaders := TDictionary<string, string>.Create;
end;

destructor TMockHttpResponse.Destroy;
begin
  FCustomHeaders.Free;
  inherited Destroy;
end;

function TMockHttpResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TMockHttpResponse.Status(AValue: Integer): IHttpResponse;
begin
  FStatusCode := AValue;
  Result := Self;
end;

procedure TMockHttpResponse.SetStatusCode(AValue: Integer);
begin
  FStatusCode := AValue;
end;

procedure TMockHttpResponse.SetContentType(const AValue: string);
begin
  FContentType := AValue;
end;

procedure TMockHttpResponse.SetContentLength(const AValue: Int64);
begin
  // Mock implementation - ignore
end;

procedure TMockHttpResponse.Write(const AContent: string);
begin
  FContentText := AContent;
end;

procedure TMockHttpResponse.Write(const ABuffer: TBytes);
begin
  FContentText := TEncoding.UTF8.GetString(ABuffer);
end;

procedure TMockHttpResponse.Json(const AJson: string);
begin
  FContentText := AJson;
  FContentType := 'application/json';
end;

procedure TMockHttpResponse.AddHeader(const AName, AValue: string);
begin
  FCustomHeaders.AddOrSetValue(AName, AValue);
end;

{ TMockHttpContext }

constructor TMockHttpContext.Create(ARequest: IHttpRequest; AResponse: IHttpResponse;
  AServices: IServiceProvider);
begin
  inherited Create;
  FRequest := ARequest;
  FResponse := AResponse;
  FServices := AServices;
end;

function TMockHttpContext.GetRequest: IHttpRequest;
begin
  Result := FRequest;
end;

function TMockHttpContext.GetResponse: IHttpResponse;
begin
  Result := FResponse;
end;

procedure TMockHttpContext.SetResponse(const AValue: IHttpResponse);
begin
  FResponse := AValue;
end;

function TMockHttpContext.GetServices: IServiceProvider;
begin
  Result := FServices;
end;

function TMockHttpContext.GetUser: IClaimsPrincipal;
begin
  Result := FUser;
end;

procedure TMockHttpContext.SetUser(const AValue: IClaimsPrincipal);
begin
  FUser := AValue;
end;

procedure TMockHttpContext.SetRouteParams(const AParams: TDictionary<string, string>);
var
  MockRequest: TMockHttpRequest;
  Param: TPair<string, string>;
begin
  Writeln('🔍 SetRouteParams Debug:');
  Writeln('  Input params count: ', AParams.Count);
  for Param in AParams do
    Writeln('  ', Param.Key, ' = ', Param.Value);

  // ✅ CORREÇÃO SIMPLES: Cast direto já que sabemos que é TMockHttpRequest
  try
    MockRequest := TMockHttpRequest(FRequest);
    MockRequest.FRouteParams.Clear;
    for Param in AParams do
    begin
      MockRequest.FRouteParams.Add(Param.Key, Param.Value);
    end;

    Writeln('  ✅ After injection - FRouteParams count: ', MockRequest.FRouteParams.Count);
  except
    on E: Exception do
    begin
      Writeln('❌ ERROR in SetRouteParams: ', E.Message);
    end;
  end;
end;

procedure TMockHttpContext.SetServices(const AValue: IServiceProvider);
begin
  FServices := AValue;
end;

//procedure TMockHttpContext.SetRouteParams(const AParams: TDictionary<string, string>);
//var
//  Param: TPair<string, string>;
//begin
//  if FRequest is TMockHttpRequest then
//  begin
//    var MockRequest := TMockHttpRequest(FRequest);
//    MockRequest.FRouteParams.Clear;
//    for Param in AParams do
//      MockRequest.FRouteParams.Add(Param.Key, Param.Value);
//  end;
//end;

//procedure TMockHttpContext.SetRouteParams(const AParams: TDictionary<string, string>);
//var
//  IndyRequest: TIndyHttpRequest;
//  Param: TPair<string, string>;
//begin
//  Writeln('🔍 SetRouteParams Debug:');
//  Writeln('  Input params count: ', AParams.Count);
//  for Param in AParams do
//    Writeln('  ', Param.Key, ' = ', Param.Value);
//
//  if FRequest is TIndyHttpRequest then
//  begin
//    IndyRequest := TIndyHttpRequest(FRequest);
//    IndyRequest.GetRouteParams.Clear;
//    for Param in AParams do
//    begin
//      IndyRequest.GetRouteParams.Add(Param.Key, Param.Value);
//    end;
//
//    Writeln('  After injection - FRouteParams count: ', IndyRequest.GetRouteParams.Count);
//  end
//  else
//  begin
//    Writeln('❌ ERROR: FRequest is not TIndyHttpRequest');
//  end;
//end;

{ TMockFactory }

class function TMockFactory.CreateHttpContext(const AQueryString: string): IHttpContext;
var
  Request: IHttpRequest;
  Response: IHttpResponse;
begin
  Request := TMockHttpRequest.Create(AQueryString);
  Response := TMockHttpResponse.Create;
  Result := TMockHttpContext.Create(Request, Response);
end;

//class function TMockFactory.CreateHttpContextWithRoute(const AQueryString: string;
//  const ARouteParams: TDictionary<string, string>): IHttpContext;
//begin
//  Result := CreateHttpContext(AQueryString);
//  (Result as TMockHttpContext).SetRouteParams(ARouteParams);
//end;

class function TMockFactory.CreateHttpContextWithRoute(const AQueryString: string;
  const ARouteParams: TDictionary<string, string>): IHttpContext;
var
  Request: IHttpRequest;
  Response: IHttpResponse;
begin
  Request := TMockHttpRequest.Create(AQueryString);
  Response := TMockHttpResponse.Create;
  Result := TMockHttpContext.Create(Request, Response);

  // Injeta os route params
  (Result as TMockHttpContext).SetRouteParams(ARouteParams);
end;

class function TMockFactory.CreateHttpContextWithHeaders(const AQueryString:
  string; const AHeaders: TDictionary<string, string>): IHttpContext;
var
  Request: IHttpRequest;
  Response: IHttpResponse;
begin
  Request := TMockHttpRequestWithHeaders.CreateWithHeaders(AQueryString, AHeaders);
  Response := TMockHttpResponse.Create;
  Result := TMockHttpContext.Create(Request, Response);
end;

class function TMockFactory.CreateHttpContextWithServices(const AQueryString:
  string; const AServices: IServiceProvider): IHttpContext;
var
  Request: IHttpRequest;
  Response: IHttpResponse;
begin
  Request := TMockHttpRequest.Create(AQueryString);
  Response := TMockHttpResponse.Create;
  Result := TMockHttpContextWithServices.CreateWithServices(Request, Response, AServices);
end;

{ TMockHttpRequestWithHeaders }

constructor TMockHttpRequestWithHeaders.CreateWithHeaders(const AQueryString: string;
  const AHeaders: TDictionary<string, string>);
begin
  inherited Create(AQueryString);

  // Clonar os headers fornecidos
  FCustomHeaders := TDictionary<string, string>.Create;
  for var Header in AHeaders do
  begin
    // Headers são case-insensitive, normalizar para lowercase
    FCustomHeaders.Add(Header.Key.ToLower, Header.Value);
  end;
end;

destructor TMockHttpRequestWithHeaders.Destroy;
begin
  FCustomHeaders.Free;
  inherited Destroy;
end;

function TMockHttpRequestWithHeaders.GetHeaders: TDictionary<string, string>;
begin
  Result := FCustomHeaders;
end;

{ TMockHttpContextWithServices }

constructor TMockHttpContextWithServices.CreateWithServices(ARequest: IHttpRequest;
  AResponse: IHttpResponse; AServices: IServiceProvider);
begin
  inherited Create(ARequest, AResponse, AServices);
  FCustomServices := AServices;
end;

function TMockHttpContextWithServices.GetServices: IServiceProvider;
begin
  Result := FCustomServices;
end;

end.
