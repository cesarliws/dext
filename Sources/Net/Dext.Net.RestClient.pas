{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-01-21                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Net.RestClient;

interface

uses
  System.Classes,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Rtti,
  System.SyncObjs,
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Http.Request,
  Dext.Net.Authentication,
  Dext.Net.ConnectionPool,
  Dext.Threading.Async,
  Dext.Threading.CancellationToken;

 type
  /// <summary>
  ///   Supported HTTP Methods.
  /// </summary>
  TDextHttpMethod = (hmGET, hmPOST, hmPUT, hmDELETE, hmPATCH, hmHEAD, hmOPTIONS);

  /// <summary>
  ///   Content-Type for requests.
  /// </summary>
  TDextContentType = (ctJson, ctXml, ctFormUrlEncoded, ctMultipartFormData, ctBinary, ctText);

  /// <summary>
  ///   Interface for a REST Response.
  /// </summary>
  IRestResponse = interface
    ['{B1A2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    function GetStatusCode: Integer;
    function GetStatusText: string;
    function GetContentStream: TStream;
    function GetContentString: string;
    function GetHeader(const AName: string): string;
    
    property StatusCode: Integer read GetStatusCode;
    property StatusText: string read GetStatusText;
    property ContentStream: TStream read GetContentStream;
    property ContentString: string read GetContentString;
  end;

  /// <summary>
  ///   Interface for a Typed REST Response.
  /// </summary>
  IRestResponse<T> = interface(IRestResponse)
    ['{C1D2E3F4-A5B6-4C7D-8E9F-0A1B2C3D4E5F}']
    function GetData: T;
    property Data: T read GetData;
  end;

  { Internal Implementation Classes - Must be in interface for Generic Visibility }

  TRestResponse = class(TInterfacedObject, IRestResponse)
  private
    FStatusCode: Integer;
    FStatusText: string;
    FContentStream: TMemoryStream;
  protected
    function GetStatusCode: Integer;
    function GetStatusText: string;
    function GetContentStream: TStream;
    function GetContentString: string;
    function GetHeader(const AName: string): string;
  public
    constructor Create(AStatusCode: Integer; const AStatusText: string; AStream: TStream);
    destructor Destroy; override;
  end;

  TRestResponse<T> = class(TRestResponse, IRestResponse<T>)
  private
    FData: T;
  protected
    function GetData: T;
  public
    constructor Create(AStatusCode: Integer; const AStatusText: string; AStream: TStream; AData: T);
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Internal interface for Client Implementation.
  /// </summary>
  IRestClient = interface
    ['{A3B4C5D6-E7F8-49A0-B1C2-D3E4F5A6B7C8}']
    function BaseUrl(const AValue: string): IRestClient;
    function Timeout(AValue: Integer): IRestClient;
    function Retry(AValue: Integer): IRestClient;
    function Auth(AProvider: IAuthenticationProvider): IRestClient;
    function Header(const AName, AValue: string): IRestClient;
    function ContentType(AValue: TDextContentType): IRestClient;
    
    function ExecuteAsync(AMethod: TDextHttpMethod; const AEndpoint: string; 
      const ABody: TStream = nil; AOwnsBody: Boolean = False;
      AHeaders: IDictionary<string, string> = nil): TAsyncBuilder<IRestResponse>;
  end;

  TRestClientImpl = class(TInterfacedObject, IRestClient)
  private
    FBaseUrl: string;
    FTimeout: Integer;
    FMaxRetries: Integer;
    FHeaders: IDictionary<string, string>;
    FContentType: TDextContentType;
    FAuthProvider: IAuthenticationProvider;
    FPool: TConnectionPool;
    FLock: TCriticalSection;
    
    function GetFullUrl(const AEndpoint: string): string;
  public
    constructor Create(const ABaseUrl: string = '');

    destructor Destroy; override;

    function BaseUrl(const AValue: string): IRestClient;
    function Timeout(AValue: Integer): IRestClient;
    function Retry(AValue: Integer): IRestClient;
    function Auth(AProvider: IAuthenticationProvider): IRestClient;
    function Header(const AName, AValue: string): IRestClient;
    function ContentType(AValue: TDextContentType): IRestClient;

    function ExecuteAsync(AMethod: TDextHttpMethod; const AEndpoint: string; 
      const ABody: TStream = nil; AOwnsBody: Boolean = False;
      AHeaders: IDictionary<string, string> = nil): TAsyncBuilder<IRestResponse>;
  end;

  /// <summary>
  ///   Specialised async builder returned by the REST client's untyped HTTP operations.
  ///   Wraps TAsyncBuilder&lt;IRestResponse&gt; and adds ToList&lt;T&gt; for JSON-array endpoints.
  /// </summary>
  TRestAsyncBuilder = record
  private
    FInner: TAsyncBuilder<IRestResponse>;
  public
    constructor Create(const AInner: TAsyncBuilder<IRestResponse>);

    /// <summary>
    ///   Deserialises the JSON-array response body into IList&lt;T&gt;.
    ///   Usage: RestClient('...').Get('/items').ToList&lt;TItem&gt;.Await
    /// </summary>
    function ToList<T: class>: TAsyncBuilder<IList<T>>;

    // ---- Forward the full TAsyncBuilder<IRestResponse> surface ----
    function ThenBy<U>(const AFunc: TFunc<IRestResponse, U>): TAsyncBuilder<U>; overload;
    function ThenBy(const AProc: TProc<IRestResponse>): TRestAsyncBuilder; overload;
    function OnComplete(const AProc: TProc<IRestResponse>): TRestAsyncBuilder;
    function OnCompleteAsync(const AProc: TProc<IRestResponse>): TRestAsyncBuilder;
    function OnException(const AProc: TProc<Exception>): TRestAsyncBuilder;
    function OnExceptionAsync(const AProc: TProc<Exception>): TRestAsyncBuilder;
    function WithCancellation(const AToken: ICancellationToken): TRestAsyncBuilder;
    function Start: IAsyncTask;
    function Await: IRestResponse;

    /// <summary>Implicit conversion – keeps existing code that stores the result
    ///   as TAsyncBuilder&lt;IRestResponse&gt; working without changes.</summary>
    class operator Implicit(const ABuilder: TRestAsyncBuilder): TAsyncBuilder<IRestResponse>;
  end;

  /// <summary>
  ///   Fluent REST Client - Record Pattern to support Generics.
  /// </summary>
  TRestClient = record
  private
    FInstance: IRestClient;
    class var FSharedPool: TConnectionPool;
    class destructor Destroy;
  public
    class function Create(const ABaseUrl: string = ''): TRestClient; static;

    // Fluent Configuration
    function BaseUrl(const AValue: string): TRestClient;
    function Timeout(AValue: Integer): TRestClient;
    function Retry(AValue: Integer): TRestClient;
    function BearerToken(const AToken: string): TRestClient;
    function BasicAuth(const AUsername, APassword: string): TRestClient;
    function ApiKey(const AName, AValue: string; AInHeader: Boolean = True): TRestClient;
    function Auth(AProvider: IAuthenticationProvider): TRestClient;
    function Header(const AName, AValue: string): TRestClient;
    function ContentType(AValue: TDextContentType): TRestClient;

    // HTTP Operations
    function Get(const AEndpoint: string = ''): TRestAsyncBuilder; overload;
    function Get<T: class>(const AEndpoint: string = ''): TAsyncBuilder<T>; overload;
    function GetList<T: class>(const AEndpoint: string = ''): TAsyncBuilder<IList<T>>;
    
    function Post(const AEndpoint: string = ''): TAsyncBuilder<IRestResponse>; overload;
    function Post(const AEndpoint: string; const ABody: TStream): TAsyncBuilder<IRestResponse>; overload;
    function Post<TRes: class>(const AEndpoint: string; const ABody: TRes): TAsyncBuilder<IRestResponse<TRes>>; overload;
    
    function Put(const AEndpoint: string = ''): TAsyncBuilder<IRestResponse>; overload;
    function Put(const AEndpoint: string; const ABody: TStream): TAsyncBuilder<IRestResponse>; overload;
    function Put<TRes: class>(const AEndpoint: string; const ABody: TRes): TAsyncBuilder<IRestResponse<TRes>>; overload;
    function Put<T: class>(const AEndpoint: string = ''): TAsyncBuilder<T>; overload;

    
    function Delete(const AEndpoint: string = ''): TAsyncBuilder<IRestResponse>; overload;
    function Delete<T: class>(const AEndpoint: string = ''): TAsyncBuilder<T>; overload;
    
    function ExecuteAsync(AMethod: TDextHttpMethod; const AEndpoint: string; 
      const ABody: TStream = nil; AOwnsBody: Boolean = False;
      AHeaders: IDictionary<string, string> = nil): TAsyncBuilder<IRestResponse>;

    /// <summary>
    ///   Executes a request defined by a THttpRequestInfo object (from .http parser).
    /// </summary>
    function Execute(RequestInfo: THttpRequestInfo): TAsyncBuilder<IRestResponse>;

    property Instance: IRestClient read FInstance;
  end;

  /// <summary>
  ///   Exception for REST Client errors.
  /// </summary>
  EDextRestException = class(Exception);

function RestClient(const ABaseUrl: string = ''): TRestClient;

implementation

uses
  System.Math,
  Dext.Json;

function RestClient(const ABaseUrl: string = ''): TRestClient;
begin
  Result := TRestClient.Create(ABaseUrl);
end;

{ TRestResponse }

constructor TRestResponse.Create(AStatusCode: Integer; const AStatusText: string; AStream: TStream);
begin
  inherited Create;
  FStatusCode := AStatusCode;
  FStatusText := AStatusText;
  FContentStream := TMemoryStream.Create;
  if Assigned(AStream) then
  begin
    AStream.Position := 0;
    FContentStream.CopyFrom(AStream, AStream.Size);
    FContentStream.Position := 0;
  end;
end;

destructor TRestResponse.Destroy;
begin
  FContentStream.Free;
  inherited;
end;

function TRestResponse.GetContentStream: TStream;
begin
  Result := FContentStream;
end;

function TRestResponse.GetContentString: string;
begin
  if FContentStream.Size = 0 then Exit('');
  
  FContentStream.Position := 0;
  var LBytes: TBytes;
  SetLength(LBytes, FContentStream.Size);
  FContentStream.ReadBuffer(LBytes[0], FContentStream.Size);
  Result := TEncoding.UTF8.GetString(LBytes);
end;

function TRestResponse.GetHeader(const AName: string): string;
begin
  Result := '';
end;

function TRestResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

function TRestResponse.GetStatusText: string;
begin
  Result := FStatusText;
end;

{ TRestResponse<T> }

constructor TRestResponse<T>.Create(AStatusCode: Integer; const AStatusText: string; AStream: TStream; AData: T);
begin
  inherited Create(AStatusCode, AStatusText, AStream);
  FData := AData;
end;

destructor TRestResponse<T>.Destroy;
begin
  if TValue.From<T>(FData).IsObject then
    TValue.From<T>(FData).AsObject.Free;
  inherited;
end;

function TRestResponse<T>.GetData: T;
begin
  Result := FData;
end;

{ TRestClientImpl }

constructor TRestClientImpl.Create(const ABaseUrl: string);
begin
  inherited Create;
  FBaseUrl := ABaseUrl;
  FTimeout := 30000;
  FHeaders := TCollections.CreateDictionary<string, string>;
  FContentType := ctJson;
  FPool := TConnectionPool(TRestClient.FSharedPool);
  FLock := TCriticalSection.Create;
end;

destructor TRestClientImpl.Destroy;
begin
  // FHeaders is ARC
  FLock.Free;
  inherited;
end;


function TRestClientImpl.GetFullUrl(const AEndpoint: string): string;

begin
  if FBaseUrl = '' then Exit(AEndpoint);
  
  Result := FBaseUrl;
  if (AEndpoint <> '') then
  begin
    if not Result.EndsWith('/') and not AEndpoint.StartsWith('/') then
      Result := Result + '/';
    Result := Result + AEndpoint;
  end;
end;

function TRestClientImpl.BaseUrl(const AValue: string): IRestClient;
begin
  FBaseUrl := AValue;
  Result := Self;
end;

function TRestClientImpl.Auth(AProvider: IAuthenticationProvider): IRestClient;
begin
  FAuthProvider := AProvider;
  Result := Self;
end;

function TRestClientImpl.ContentType(AValue: TDextContentType): IRestClient;
begin
  FContentType := AValue;
  Result := Self;
end;

function TRestClientImpl.Header(const AName, AValue: string): IRestClient;
begin
  FLock.Enter;
  try
    FHeaders.AddOrSetValue(AName, AValue);
  finally
    FLock.Leave;
  end;
  Result := Self;
end;

function TRestClientImpl.Retry(AValue: Integer): IRestClient;
begin
  FMaxRetries := AValue;
  Result := Self;
end;

function TRestClientImpl.Timeout(AValue: Integer): IRestClient;
begin
  FTimeout := AValue;
  Result := Self;
end;

function TRestClientImpl.ExecuteAsync(AMethod: TDextHttpMethod; const AEndpoint: string; 
  const ABody: TStream; AOwnsBody: Boolean; AHeaders: IDictionary<string, string>): TAsyncBuilder<IRestResponse>;
var
  Url: string;
  Retries: Integer;
  Headers: TNetHeaders;
  Timeout: Integer;
  Auth: IAuthenticationProvider;
begin
  Url := GetFullUrl(AEndpoint);
  Retries := FMaxRetries;
  Timeout := FTimeout;
  Auth := FAuthProvider;
  
  // Snapshot headers (Thread Safety)
  var LHeadList := TList<TNetHeader>.Create;
  try
    FLock.Enter;
    try
      for var LPair in FHeaders do
        LHeadList.Add(TNetHeader.Create(LPair.Key, LPair.Value));
    finally
      FLock.Leave;
    end;
      
    if Assigned(Auth) then
    begin
       if Auth is TApiKeyAuthProvider then
         LHeadList.Add(TNetHeader.Create(TApiKeyAuthProvider(Auth).Key, Auth.GetHeaderValue))
       else
         LHeadList.Add(TNetHeader.Create('Authorization', Auth.GetHeaderValue));
    end;

    if Assigned(AHeaders) then
    begin
      for var LPair in AHeaders do
        LHeadList.Add(TNetHeader.Create(LPair.Key, LPair.Value));
    end;
    
    Headers := LHeadList.ToArray;
  finally
    LHeadList.Free;
  end;
  
  Result := TAsyncTask.Run<IRestResponse>(
    TFunc<IRestResponse>(
      function: IRestResponse
      var
        HttpClient: THttpClient;
        Response: IHTTPResponse;
        Attempt: Integer;
        LastError: Exception;
        MethodStr: string;
      begin
        try
          Attempt := 0;
          LastError := nil;
          
          while Attempt <= Retries do
          begin
            HttpClient := TConnectionPool(TRestClient.FSharedPool).Acquire;
            try
              HttpClient.ConnectionTimeout := Timeout;
              HttpClient.SendTimeout := Timeout;
              HttpClient.ResponseTimeout := Timeout;
              
              case AMethod of
                hmGET:    MethodStr := 'GET';
                hmPOST:   MethodStr := 'POST';
                hmPUT:    MethodStr := 'PUT';
                hmDELETE: MethodStr := 'DELETE';
                hmPATCH:  MethodStr := 'PATCH';
                hmHEAD:   MethodStr := 'HEAD';
                hmOPTIONS:MethodStr := 'OPTIONS';
                else MethodStr := '';
              end;

              try
                Response := HttpClient.Execute(MethodStr, Url, ABody, nil, Headers) as IHTTPResponse;
                Result := TRestResponse.Create(Response.StatusCode, Response.StatusText, Response.ContentStream);
                Exit;
              except
                on E: Exception do
                begin
                  LastError := E;
                  Inc(Attempt);
                  if Attempt > Retries then Break;
                  Sleep(Trunc(Power(2, Attempt) * 100));
                end;
              end;
            finally
              TConnectionPool(TRestClient.FSharedPool).Release(HttpClient);
            end;
          end;
          
          if Assigned(LastError) then raise LastError;
        finally
          if AOwnsBody and Assigned(ABody) then
            ABody.Free;
        end;
      end
    )
  );
end;

{ TRestAsyncBuilder }

constructor TRestAsyncBuilder.Create(const AInner: TAsyncBuilder<IRestResponse>);
begin
  FInner := AInner;
end;

function TRestAsyncBuilder.ToList<T>: TAsyncBuilder<IList<T>>;
begin
  Result := FInner.ThenBy<IList<T>>(
    function(LRes: IRestResponse): IList<T>
    begin
      Result := TDextJson.Deserialize<IList<T>>(LRes.ContentString);
    end
  );
end;

function TRestAsyncBuilder.ThenBy<U>(const AFunc: TFunc<IRestResponse, U>): TAsyncBuilder<U>;
begin
  Result := FInner.ThenBy<U>(AFunc);
end;

function TRestAsyncBuilder.ThenBy(const AProc: TProc<IRestResponse>): TRestAsyncBuilder;
begin
  Result := TRestAsyncBuilder.Create(FInner.ThenBy(AProc));
end;

function TRestAsyncBuilder.OnComplete(const AProc: TProc<IRestResponse>): TRestAsyncBuilder;
begin
  Result := TRestAsyncBuilder.Create(FInner.OnComplete(AProc));
end;

function TRestAsyncBuilder.OnCompleteAsync(const AProc: TProc<IRestResponse>): TRestAsyncBuilder;
begin
  Result := TRestAsyncBuilder.Create(FInner.OnCompleteAsync(AProc));
end;

function TRestAsyncBuilder.OnException(const AProc: TProc<Exception>): TRestAsyncBuilder;
begin
  Result := TRestAsyncBuilder.Create(FInner.OnException(AProc));
end;

function TRestAsyncBuilder.OnExceptionAsync(const AProc: TProc<Exception>): TRestAsyncBuilder;
begin
  Result := TRestAsyncBuilder.Create(FInner.OnExceptionAsync(AProc));
end;

function TRestAsyncBuilder.WithCancellation(const AToken: ICancellationToken): TRestAsyncBuilder;
begin
  Result := TRestAsyncBuilder.Create(FInner.WithCancellation(AToken));
end;

function TRestAsyncBuilder.Start: IAsyncTask;
begin
  Result := FInner.Start;
end;

function TRestAsyncBuilder.Await: IRestResponse;
begin
  Result := FInner.Await;
end;

class operator TRestAsyncBuilder.Implicit(const ABuilder: TRestAsyncBuilder): TAsyncBuilder<IRestResponse>;
begin
  Result := ABuilder.FInner;
end;

{ TRestClient }

class destructor TRestClient.Destroy;
begin
  FSharedPool.Free;
end;

class function TRestClient.Create(const ABaseUrl: string): TRestClient;
begin
  // Thread-safe pool initialization
  if not Assigned(FSharedPool) then
  begin
    var LNewPool := TConnectionPool.Create;
    if TInterlocked.CompareExchange(Pointer(FSharedPool), Pointer(LNewPool), nil) <> nil then
      LNewPool.Free;
  end;
  Result.FInstance := TRestClientImpl.Create(ABaseUrl);
end;

function TRestClient.BaseUrl(const AValue: string): TRestClient;
begin
  FInstance.BaseUrl(AValue);
  Result := Self;
end;

function TRestClient.BearerToken(const AToken: string): TRestClient;
begin
  FInstance.Auth(TBearerAuthProvider.Create(AToken));
  Result := Self;
end;

function TRestClient.BasicAuth(const AUsername, APassword: string): TRestClient;
begin
  FInstance.Auth(TBasicAuthProvider.Create(AUsername, APassword));
  Result := Self;
end;

function TRestClient.ApiKey(const AName, AValue: string; AInHeader: Boolean): TRestClient;
begin
  if AInHeader then
    FInstance.Auth(TApiKeyAuthProvider.Create(AName, AValue));
  Result := Self;
end;

function TRestClient.Auth(AProvider: IAuthenticationProvider): TRestClient;
begin
  FInstance.Auth(AProvider);
  Result := Self;
end;

function TRestClient.ContentType(AValue: TDextContentType): TRestClient;
begin
  FInstance.ContentType(AValue);
  Result := Self;
end;

function TRestClient.Header(const AName, AValue: string): TRestClient;
begin
  FInstance.Header(AName, AValue);
  Result := Self;
end;

function TRestClient.Retry(AValue: Integer): TRestClient;
begin
  FInstance.Retry(AValue);
  Result := Self;
end;

function TRestClient.Timeout(AValue: Integer): TRestClient;
begin
  FInstance.Timeout(AValue);
  Result := Self;
end;

function TRestClient.Get(const AEndpoint: string): TRestAsyncBuilder;
begin
  Result := TRestAsyncBuilder.Create(ExecuteAsync(hmGET, AEndpoint));
end;

function TRestClient.GetList<T>(const AEndpoint: string): TAsyncBuilder<IList<T>>;
begin
  Result := Get(AEndpoint).ToList<T>;
end;

function TRestClient.Get<T>(const AEndpoint: string): TAsyncBuilder<T>;
var
  Builder: TAsyncBuilder<IRestResponse>;
begin
  Builder := Get(AEndpoint);
  Result := Builder.ThenBy<T>(
    TFunc<IRestResponse, T>(
      function(LRes: IRestResponse): T
      begin
        Result := TDextJson.Deserialize<T>(LRes.ContentString);
      end
    )
  );
end;

function TRestClient.Post(const AEndpoint: string): TAsyncBuilder<IRestResponse>;
begin
  Result := ExecuteAsync(hmPOST, AEndpoint);
end;

function TRestClient.Post(const AEndpoint: string; const ABody: TStream): TAsyncBuilder<IRestResponse>;
begin
  Result := ExecuteAsync(hmPOST, AEndpoint, ABody);
end;

function TRestClient.Post<TRes>(const AEndpoint: string; const ABody: TRes): TAsyncBuilder<IRestResponse<TRes>>;
var
  Stream: TStringStream;
  Builder: TAsyncBuilder<IRestResponse>;
begin
  Stream := TStringStream.Create(TDextJson.Serialize(ABody), TEncoding.UTF8);
  Builder := ExecuteAsync(hmPOST, AEndpoint, Stream, True);
  Result := Builder.ThenBy<IRestResponse<TRes>>(
      TFunc<IRestResponse, IRestResponse<TRes>>(
        function(Base: IRestResponse): IRestResponse<TRes>
        begin
          Result := TRestResponse<TRes>.Create(Base.StatusCode, Base.StatusText, Base.ContentStream,
            TDextJson.Deserialize<TRes>(Base.ContentString));
        end
      )
  );
end;

function TRestClient.Put(const AEndpoint: string): TAsyncBuilder<IRestResponse>;
begin
  Result := ExecuteAsync(hmPUT, AEndpoint);
end;

function TRestClient.Put(const AEndpoint: string; const ABody: TStream): TAsyncBuilder<IRestResponse>;
begin
  Result := ExecuteAsync(hmPUT, AEndpoint, ABody);
end;

function TRestClient.Put<TRes>(const AEndpoint: string; const ABody: TRes): TAsyncBuilder<IRestResponse<TRes>>;
var
  Stream: TStringStream;
  Builder: TAsyncBuilder<IRestResponse>;
begin
  Stream := TStringStream.Create(TDextJson.Serialize(ABody), TEncoding.UTF8);
  Builder := ExecuteAsync(hmPUT, AEndpoint, Stream, True);
  Result := Builder.ThenBy<IRestResponse<TRes>>(
      TFunc<IRestResponse, IRestResponse<TRes>>(
        function(Base: IRestResponse): IRestResponse<TRes>
        begin
          Result := TRestResponse<TRes>.Create(Base.StatusCode, Base.StatusText, Base.ContentStream,
            TDextJson.Deserialize<TRes>(Base.ContentString));
        end
      )
  );
end;

function TRestClient.Put<T>(const AEndpoint: string): TAsyncBuilder<T>;
var
  Builder: TAsyncBuilder<IRestResponse>;
begin
  Builder := Put(AEndpoint);
  Result := Builder.ThenBy<T>(
    TFunc<IRestResponse, T>(
      function(LRes: IRestResponse): T
      begin
        Result := TDextJson.Deserialize<T>(LRes.ContentString);
      end
    )
  );
end;

function TRestClient.Delete(const AEndpoint: string): TAsyncBuilder<IRestResponse>;
begin
  Result := ExecuteAsync(hmDELETE, AEndpoint);
end;

function TRestClient.Delete<T>(const AEndpoint: string): TAsyncBuilder<T>;
var
  Builder: TAsyncBuilder<IRestResponse>;
begin
  Builder := Delete(AEndpoint);
  Result := Builder.ThenBy<T>(
    TFunc<IRestResponse, T>(
      function(LRes: IRestResponse): T
      begin
        Result := TDextJson.Deserialize<T>(LRes.ContentString);
      end
    )
  );
end;

function TRestClient.Execute(RequestInfo: THttpRequestInfo): TAsyncBuilder<IRestResponse>;
var
  Method: TDextHttpMethod;
  BodyStream: TStringStream;
begin
  if RequestInfo = nil then
    raise Exception.Create('RequestInfo cannot be nil');

  // Map Method String to Enum
  if SameText(RequestInfo.Method, 'GET') then Method := hmGET
  else if SameText(RequestInfo.Method, 'POST') then Method := hmPOST
  else if SameText(RequestInfo.Method, 'PUT') then Method := hmPUT
  else if SameText(RequestInfo.Method, 'DELETE') then Method := hmDELETE
  else if SameText(RequestInfo.Method, 'PATCH') then Method := hmPATCH
  else if SameText(RequestInfo.Method, 'HEAD') then Method := hmHEAD
  else if SameText(RequestInfo.Method, 'OPTIONS') then Method := hmOPTIONS
  else raise Exception.Create('Unsupported HTTP Method: ' + RequestInfo.Method);

  // Prepare Body
  BodyStream := nil;
  if RequestInfo.Body <> '' then
    BodyStream := TStringStream.Create(RequestInfo.Body, TEncoding.UTF8);

  // Execute
  Result := ExecuteAsync(Method, RequestInfo.Url, BodyStream, True, RequestInfo.Headers);
end;

function TRestClient.ExecuteAsync(AMethod: TDextHttpMethod; const AEndpoint: string; 
  const ABody: TStream; AOwnsBody: Boolean; AHeaders: IDictionary<string, string>): TAsyncBuilder<IRestResponse>;
begin
  Result := FInstance.ExecuteAsync(AMethod, AEndpoint, ABody, AOwnsBody, AHeaders);
end;


end.
