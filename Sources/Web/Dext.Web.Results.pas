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
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Results;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Math,
  System.IOUtils,
  System.Rtti,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.Web.Formatters.Interfaces,
  Dext.Web.Formatters.Json, // Default formatter
  Dext.Web.View,
  Dext.Entity.Core,
  Dext.Entity.Query,
  Dext.Json,
  Dext.Http.StatusCodes,
  Dext.Validation,
  Dext.Core.Activator;

type
  /// <summary>
  ///   Abstract base class for <see cref="IResult"/> implementations.
  /// </summary>
  TResult = class(TInterfacedObject, IResult)
  protected
    procedure Execute(AContext: IHttpContext); virtual; abstract;
  end;

  TOutputFormatterContext = class(TInterfacedObject, IOutputFormatterContext)
  private
    FContext: IHttpContext;
    FObjectType: TRttiType;
    FObject: TValue;
  public
    constructor Create(const AContext: IHttpContext; ATypeInfo: Pointer; const AObject: TValue);
    destructor Destroy; override;
    function GetHttpContext: IHttpContext;
    function GetObjectType: TRttiType;
    function GetObject: TValue;
  end;

  /// <summary>
  ///   Result that returns JSON formatted content.
  /// </summary>
  TJsonResult = class(TResult)
  private
    FJson: string;
    FStatusCode: Integer;
  public
    constructor Create(const AJson: string; AStatusCode: Integer = 200);
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Simple result that returns only the HTTP status code (e.g. 204 NoContent, 401 Unauthorized).
  /// </summary>
  TStatusCodeResult = class(TResult)
  private
    FStatusCode: Integer;
  public
    constructor Create(AStatusCode: Integer);
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Result that returns textual content with a specific Content-Type (e.g. XML, Plain Text).
  /// </summary>
  TContentResult = class(TResult)
  private
    FContent: string;
    FContentType: string;
    FStatusCode: Integer;
  public
    constructor Create(const AContent: string; const AContentType: string = 'text/plain'; AStatusCode: Integer = 200);
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Generic result that uses content negotiation to format an object.
  ///   Attempts to find a registered formatter (JSON, XML) that accepts type T.
  /// </summary>
  TObjectResult<T> = class(TResult)
  private
    FValue: T;
    FStatusCode: Integer;
  public
    constructor Create(const AValue: T; AStatusCode: Integer = 200);
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Result that streams the content of a Stream to the HTTP response.
  /// </summary>
  TStreamResult = class(TResult)
  private
    FStream: TStream;
    FContentType: string;
    FStatusCode: Integer;
  public
    constructor Create(const AStream: TStream; const AContentType: string; AStatusCode: Integer = 200);
    destructor Destroy; override;
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Result that performs an HTTP redirect (301, 302, 307, 308).
  /// </summary>
  TRedirectResult = class(TResult)
  private
    FUrl: string;
    FPermanent: Boolean;
    FPreserveMethod: Boolean;
    FLocalOnly: Boolean;
  public
    constructor Create(const AUrl: string; APermanent: Boolean = False; APreserveMethod: Boolean = False; ALocalOnly: Boolean = False);
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Result that sends a physical file to the response.
  /// </summary>
  TFileResult = class(TResult)
  private
    FPath: string;
    FContentType: string;
    FDownloadName: string;
  public
    constructor Create(const APath: string; const AContentType: string = ''; const ADownloadName: string = '');
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Result that returns a standardized validation error response (RFC 7807).
  /// </summary>
  TValidationProblemResult = class(TResult)
  private
    FValidation: TValidationResult;
  public
    constructor Create(const AValidation: TValidationResult);
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Result that triggers an authentication challenge.
  /// </summary>
  TChallengeResult = class(TResult)
  private
    FScheme: string;
  public
    constructor Create(const AScheme: string = '');
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Result that returns a 403 Forbidden.
  /// </summary>
  TForbidResult = class(TResult)
  private
    FScheme: string;
  public
    constructor Create(const AScheme: string = '');
    procedure Execute(AContext: IHttpContext); override;
  end;

  /// <summary>
  ///   Implementation of the HTMX fluent interface.
  /// </summary>
  THtmxResponse = class(TInterfacedObject, IHtmxResponse)
  private
    [Weak] FResponse: IHttpResponse;
  public
    constructor Create(const AResponse: IHttpResponse);
    function Trigger(const AEvent: string): IHtmxResponse; overload;
    function Trigger(const AEvent: string; const APayload: string): IHtmxResponse; overload;
    function Retarget(const ASelector: string): IHtmxResponse;
    function Reswap(const ASwap: string): IHtmxResponse;
    function Redirect(const AUrl: string): IHtmxResponse;
    function Refresh: IHtmxResponse;
    function Reselect(const ASelector: string): IHtmxResponse;
    function PushUrl(const AUrl: string): IHtmxResponse;
    function ReplaceUrl(const AUrl: string): IHtmxResponse;
    function Location(const AUrl: string): IHtmxResponse;
  end;

  /// <summary>
  ///   Static helper class (Factory) for creating common HTTP results.
  ///   Mainly used in Minimal APIs and Controllers to return standardized responses.
  /// </summary>
  Results = class
  private
    class var FViewsPath: string;
    class var FAppPath: string;
    class function GetFullViewPath(const ARelativePath: string): string;
  public
    /// <summary>Sets the root directory for View files (HTML).</summary>
    class procedure SetViewsPath(const APath: string);
    
    /// <summary>Sets the application root path for resolving relative paths.</summary>
    class procedure SetAppPath(const APath: string);
    
    /// <summary>Returns 200 OK.</summary>
    class function Ok: IResult; overload;
    /// <summary>Returns 200 OK with string body or pre-formatted JSON.</summary>
    class function Ok(const AValue: string): IResult; overload;
    /// <summary>Returns 200 OK with the object serialized via Content Negotiation.</summary>
    class function Ok<T>(const AValue: T): IResult; overload;
    
    /// <summary>Returns 201 Created.</summary>
    class function Created(const AUri: string): IResult; overload;
    /// <summary>Returns 201 Created with the URI of the created resource.</summary>
    class function Created(const AUri: string; const AValue: string): IResult; overload;
    /// <summary>Returns 201 Created with the object serialized via Content Negotiation.</summary>
    class function Created<T>(const AUri: string; const AValue: T): IResult; overload;

    /// <summary>Returns 400 Bad Request.</summary>
    class function BadRequest: IResult; overload;
    /// <summary>Returns 400 Bad Request with an error message.</summary>
    class function BadRequest(const AError: string): IResult; overload;
    /// <summary>Returns 400 Bad Request with a serialized error object.</summary>
    class function BadRequest<T>(const AError: T): IResult; overload;
    
    /// <summary>Returns 404 Not Found.</summary>
    class function NotFound: IResult; overload;
    /// <summary>Returns 404 Not Found with a detailed message.</summary>
    class function NotFound(const AMessage: string): IResult; overload;

    /// <summary>Returns 204 No Content.</summary>
    class function NoContent: IResult;
    
    /// <summary>Returns 401 Unauthorized.</summary>
    class function Unauthorized: IResult; overload;
    /// <summary>Returns 401 Unauthorized with a detailed message.</summary>
    class function Unauthorized(const AMessage: string): IResult; overload;
    /// <summary>Returns 401 Unauthorized with a serialized object.</summary>
    class function Unauthorized<T>(const AValue: T): IResult; overload;

    /// <summary>Returns 403 Forbidden.</summary>
    class function Forbidden: IResult; overload;
    /// <summary>Returns 403 Forbidden with a detailed message.</summary>
    class function Forbidden(const AMessage: string): IResult; overload;
    /// <summary>Returns 403 Forbidden with a serialized object.</summary>
    class function Forbidden<T>(const AValue: T): IResult; overload;

    /// <summary>Returns 500 Internal Server Error with a friendly message.</summary>
    class function InternalServerError(const AMessage: string): IResult; overload;
    /// <summary>Returns 500 Internal Server Error from a captured exception.</summary>
    class function InternalServerError(const E: Exception): IResult; overload;
    
    /// <summary>
    ///   Returns a standardized error response (RFC 7807).
    /// </summary>
    /// <param name="ADetail">Detailed error message.</param>
    /// <param name="AStatusCode">HTTP status code (default 500).</param>
    class function Problem(const ADetail: string; AStatusCode: Integer = 500): IResult; overload;
    
    /// <summary>Returns a standardized validation error response (RFC 7807).</summary>
    class function ValidationProblem(const AValidation: TValidationResult): IResult;
    
    /// <summary>Alias for Problem/InternalServerError.</summary>
    class function Fail(const AMessage: string; AStatusCode: Integer = 500): IResult;
    
    /// <summary>Returns a 302 Found redirect.</summary>
    class function Redirect(const AUrl: string; APermanent: Boolean = False; APreserveMethod: Boolean = False): IResult;
    /// <summary>Returns a 302 Found redirect to a local URL.</summary>
    class function LocalRedirect(const AUrl: string; APermanent: Boolean = False; APreserveMethod: Boolean = False): IResult;
    
    /// <summary>Returns a file result from a physical path.</summary>
    class function SendFile(const APath: string; const AContentType: string = ''; const ADownloadName: string = ''): IResult;
    
    /// <summary>Triggers an authentication challenge.</summary>
    class function Challenge(const AScheme: string = ''): IResult;
    /// <summary>Returns a 403 Forbidden result.</summary>
    class function Forbid(const AScheme: string = ''): IResult;
    
    /// <summary>Alias for InternalServerError.</summary>
    class function InternalError(const E: Exception): IResult; overload;
    class function InternalError(const AMessage: string): IResult; overload;

    /// <summary>Returns an explicit JSON result.</summary>
    class function Json(const AJson: string; AStatusCode: Integer = 200): IResult; overload;
    /// <summary>Serializes the object directly to JSON, ignoring full Content Negotiation.</summary>
    class function Json<T>(const AValue: T; AStatusCode: Integer = 200): IResult; overload;
    /// <summary>Returns content as plain text (text/plain).</summary>
    class function Text(const AContent: string; AStatusCode: Integer = 200): IResult;
    /// <summary>Returns content as pure HTML (text/html).</summary>
    class function Html(const AHtml: string; AStatusCode: Integer = 200): IResult;
    /// <summary>Returns generic content with a custom Content-Type.</summary>
    class function Content(const AContent: string; const AContentType: string; AStatusCode: Integer = 200): IResult;
    /// <summary>Sends a Stream (file, memory) to the response.</summary>
    class function Stream(const AStream: TStream; const AContentType: string; AStatusCode: Integer = 200): IResult;
    
    /// <summary>Renders a View file (HTML) located on the server.</summary>
    class function HtmlFromFile(const ARelativePath: string; AStatusCode: Integer = 200): IResult;
    
    /// <summary>Reads the content of a View for manual string manipulation.</summary>
    class function ReadViewFile(const ARelativePath: string): string;

    /// <summary>Returns an arbitrary HTTP status code.</summary>
    class function StatusCode(ACode: Integer): IResult; overload;
    class function StatusCode(ACode: Integer; const AContent: string): IResult; overload;
    
    /// <summary>Renders a dynamic View using the Dext template engine.</summary>
    class function View(const AViewName: string): TDextViewResult; overload;
    /// <summary>Renders a dynamic View linked to a database query.</summary>
    class function View<T: class>(const AViewName: string; const AQuery: TFluentQuery<T>): TDextViewResult; overload;
    /// <summary>Renders a dynamic View linked to a model object (Model).</summary>
    class function View(const AViewName: string; AData: TObject; AOwns: Boolean = False): TDextViewResult; overload;
    
    /// <summary>Renders only the fragment (Content) of a View, ignoring the Layout.</summary>
    class function ViewPart(const AViewName: string): TDextViewResult; overload;
    class function ViewPart<T: class>(const AViewName: string; const AQuery: TFluentQuery<T>): TDextViewResult; overload;
    class function ViewPart(const AViewName: string; AData: TObject; AOwns: Boolean = False): TDextViewResult; overload;
  end;

implementation

{ TOutputFormatterContext }

constructor TOutputFormatterContext.Create(const AContext: IHttpContext; ATypeInfo: Pointer; const AObject: TValue);
begin
  inherited Create;
  FContext := AContext;
  // Use the global RTTI context from TActivator to ensure efficient type lookups.
  FObjectType := TActivator.GetRttiContext.GetType(ATypeInfo);
  FObject := AObject;
  FObject := AObject;
end;

destructor TOutputFormatterContext.Destroy;
begin
  FContext := nil;
  inherited;
end;

function TOutputFormatterContext.GetHttpContext: IHttpContext;
begin
  Result := FContext;
end;

function TOutputFormatterContext.GetObject: TValue;
begin
  Result := FObject;
end;

function TOutputFormatterContext.GetObjectType: TRttiType;
begin
  Result := FObjectType;
end;

{ TJsonResult }

constructor TJsonResult.Create(const AJson: string; AStatusCode: Integer);
begin
  inherited Create;
  FJson := AJson;
  FStatusCode := AStatusCode;
end;

procedure TJsonResult.Execute(AContext: IHttpContext);
begin
  AContext.Response.StatusCode := FStatusCode;
  AContext.Response.Json(FJson);
end;

{ TStatusCodeResult }

constructor TStatusCodeResult.Create(AStatusCode: Integer);
begin
  inherited Create;
  FStatusCode := AStatusCode;
end;

procedure TStatusCodeResult.Execute(AContext: IHttpContext);
begin
  AContext.Response.StatusCode := FStatusCode;
end;

{ TContentResult }

constructor TContentResult.Create(const AContent, AContentType: string; AStatusCode: Integer);
begin
  inherited Create;
  FContent := AContent;
  FContentType := AContentType;
  // Ensure charset is set for text types
  if (FContentType.ToLower.StartsWith('text/') or FContentType.ToLower.Contains('javascript') or FContentType.ToLower.Contains('json'))
     and not FContentType.ToLower.Contains('charset=') then
  begin
    FContentType := FContentType + '; charset=utf-8';
  end;
  FStatusCode := AStatusCode;
end;

procedure TContentResult.Execute(AContext: IHttpContext);
begin
  AContext.Response.StatusCode := FStatusCode;
  AContext.Response.SetContentType(FContentType);
  AContext.Response.Write(FContent);
end;

{ TObjectResult<T> }

constructor TObjectResult<T>.Create(const AValue: T; AStatusCode: Integer);
begin
  inherited Create;
  FValue := AValue;
  FStatusCode := AStatusCode;
end;

procedure TObjectResult<T>.Execute(AContext: IHttpContext);
var
  Ctx: IOutputFormatterContext;
  Formatter: IOutputFormatter;
  Selector: IOutputFormatterSelector;
  Formatters: TArray<IOutputFormatter>;
  SelectorObj: IInterface;
  RegistryObj: IInterface;
  Registry: IOutputFormatterRegistry;
begin
  AContext.Response.StatusCode := FStatusCode;
  Ctx := TOutputFormatterContext.Create(AContext, TypeInfo(T), TValue.From<T>(FValue));
  
  Formatter := nil;
  
  // 1. Resolve Selector
  if AContext.Services <> nil then
  begin
    SelectorObj := AContext.Services.GetServiceAsInterface(TServiceType.FromInterface(TypeInfo(IOutputFormatterSelector)));
    if SelectorObj <> nil then
    begin
       Selector := SelectorObj as IOutputFormatterSelector;

       // 2. Resolve Formatters via Registry
       RegistryObj := AContext.Services.GetServiceAsInterface(TServiceType.FromInterface(TypeInfo(IOutputFormatterRegistry)));
       if RegistryObj <> nil then
       begin
          Registry := RegistryObj as IOutputFormatterRegistry;
          Formatters := Registry.GetAll;
          
          if Length(Formatters) > 0 then
            Formatter := Selector.SelectFormatter(Ctx, Formatters);
       end;
    end;
  end;

  // 3. Fallback to JSON default if no selector or no match
  if Formatter = nil then
    Formatter := TJsonOutputFormatter.Create;
    
  if Formatter.CanWriteResult(Ctx) then
    Formatter.Write(Ctx);
end;

{ TStreamResult }

constructor TStreamResult.Create(const AStream: TStream; const AContentType: string; AStatusCode: Integer);
begin
  inherited Create;
  FStream := AStream;
  FContentType := AContentType;
  FStatusCode := AStatusCode;
end;

destructor TStreamResult.Destroy;
begin
  FStream.Free;
  inherited;
end;

procedure TStreamResult.Execute(AContext: IHttpContext);
begin
  AContext.Response.StatusCode := FStatusCode;
  AContext.Response.SetContentType(FContentType);
  // Rewind stream if possible
  if FStream.Position > 0 then
    FStream.Position := 0;
  AContext.Response.Write(FStream);
end;

{ Results }

class function Results.Ok: IResult;
begin
  Result := TStatusCodeResult.Create(200);
end;

class function Results.Ok(const AValue: string): IResult;
begin
  Result := TContentResult.Create(AValue, 'text/plain', HttpStatus.OK);
end;

class function Results.Ok<T>(const AValue: T): IResult;
begin
  Result := TObjectResult<T>.Create(AValue, HttpStatus.OK);
end;

class function Results.Created(const AUri: string): IResult;
begin
  Result := TStatusCodeResult.Create(HttpStatus.Created);
end;

class function Results.Created(const AUri, AValue: string): IResult;
begin
  Result := TJsonResult.Create(AValue, HttpStatus.Created);
end;

class function Results.Created<T>(const AUri: string; const AValue: T): IResult;
begin
  Result := TObjectResult<T>.Create(AValue, HttpStatus.Created);
end;

class function Results.BadRequest: IResult;
begin
  Result := TStatusCodeResult.Create(HttpStatus.BadRequest);
end;

class function Results.BadRequest(const AError: string): IResult;
begin
  Result := TJsonResult.Create(Format('{"error": "%s"}', [AError]), HttpStatus.BadRequest);
end;

class function Results.BadRequest<T>(const AError: T): IResult;
begin
  Result := TObjectResult<T>.Create(AError, HttpStatus.BadRequest);
end;

class function Results.NotFound: IResult;
begin
  Result := TStatusCodeResult.Create(HttpStatus.NotFound);
end;

class function Results.NotFound(const AMessage: string): IResult;
begin
  Result := TJsonResult.Create(Format('{"error": "%s"}', [AMessage]), HttpStatus.NotFound);
end;

class function Results.NoContent: IResult;
begin
  Result := TStatusCodeResult.Create(HttpStatus.NoContent);
end;

class function Results.Unauthorized: IResult;
begin
  Result := TStatusCodeResult.Create(HttpStatus.Unauthorized);
end;

class function Results.Unauthorized(const AMessage: string): IResult;
begin
  Result := TJsonResult.Create(Format('{"error": "%s"}', [AMessage]), HttpStatus.Unauthorized);
end;

class function Results.Unauthorized<T>(const AValue: T): IResult;
begin
  Result := TObjectResult<T>.Create(AValue, HttpStatus.Unauthorized);
end;

class function Results.Forbidden: IResult;
begin
  Result := TStatusCodeResult.Create(HttpStatus.Forbidden);
end;

class function Results.Forbidden(const AMessage: string): IResult;
begin
  Result := TJsonResult.Create(Format('{"error": "%s"}', [AMessage]), HttpStatus.Forbidden);
end;

class function Results.Forbidden<T>(const AValue: T): IResult;
begin
  Result := TObjectResult<T>.Create(AValue, HttpStatus.Forbidden);
end;

class function Results.InternalServerError(const AMessage: string): IResult;
begin
  Result := TJsonResult.Create(Format('{"error": "%s"}', [AMessage]), 500);
end;

class function Results.InternalServerError(const E: Exception): IResult;
begin
  Result := TJsonResult.Create(
    Format('{"error": "%s", "type": "%s"}', [E.Message, E.ClassName]), 500);
end;

class function Results.InternalError(const E: Exception): IResult;
begin
  Result := InternalServerError(E);
end;

class function Results.InternalError(const AMessage: string): IResult;
begin
  Result := InternalServerError(AMessage);
end;

class function Results.Problem(const ADetail: string; AStatusCode: Integer): IResult;
var
  Builder: TJsonBuilder;
begin
  Builder := TJsonBuilder.NewBuilder
    .Add('type', 'https://tools.ietf.org/html/rfc7231#section-6.6.1')
    .Add('title', HttpStatus.GetReasonPhrase(AStatusCode))
    .Add('status', AStatusCode)
    .Add('detail', ADetail);
  try
    Result := TJsonResult.Create(Builder.ToString, AStatusCode);
  finally
    Builder.Free;
  end;
end;

class function Results.ValidationProblem(const AValidation: TValidationResult): IResult;
begin
  Result := TValidationProblemResult.Create(AValidation);
end;

class function Results.Fail(const AMessage: string; AStatusCode: Integer): IResult;
begin
  Result := Problem(AMessage, AStatusCode);
end;

class function Results.Redirect(const AUrl: string; APermanent, APreserveMethod: Boolean): IResult;
begin
  Result := TRedirectResult.Create(AUrl, APermanent, APreserveMethod, False);
end;

class function Results.LocalRedirect(const AUrl: string; APermanent, APreserveMethod: Boolean): IResult;
begin
  Result := TRedirectResult.Create(AUrl, APermanent, APreserveMethod, True);
end;

class function Results.SendFile(const APath, AContentType, ADownloadName: string): IResult;
begin
  Result := TFileResult.Create(APath, AContentType, ADownloadName);
end;

class function Results.Challenge(const AScheme: string): IResult;
begin
  Result := TChallengeResult.Create(AScheme);
end;

class function Results.Forbid(const AScheme: string): IResult;
begin
  Result := TForbidResult.Create(AScheme);
end;

class function Results.Json(const AJson: string; AStatusCode: Integer): IResult;
begin
  Result := TJsonResult.Create(AJson, AStatusCode);
end;

class function Results.Json<T>(const AValue: T; AStatusCode: Integer): IResult;
begin
  Result := TObjectResult<T>.Create(AValue, AStatusCode);
end;

class function Results.Text(const AContent: string; AStatusCode: Integer): IResult;
begin
  Result := TContentResult.Create(AContent, 'text/plain', AStatusCode);
end;

class function Results.Html(const AHtml: string; AStatusCode: Integer = 200): IResult;
begin
  Result := TContentResult.Create(AHtml, 'text/html', AStatusCode);
end;

class function Results.Content(const AContent: string; const AContentType: string; AStatusCode: Integer = 200): IResult;
begin
  Result := TContentResult.Create(AContent, AContentType, AStatusCode);
end;

class function Results.Stream(const AStream: TStream; const AContentType: string; AStatusCode: Integer): IResult;
begin
  Result := TStreamResult.Create(AStream, AContentType, AStatusCode);
end;

class function Results.StatusCode(ACode: Integer): IResult;
begin
  Result := TStatusCodeResult.Create(ACode);
end;

class function Results.StatusCode(ACode: Integer; const AContent: string): IResult;
begin
  Result := TJsonResult.Create(AContent, ACode);
end;

class function Results.View(const AViewName: string): TDextViewResult;
begin
  Result := TViewResult.Create(AViewName);
end;

class function Results.View<T>(const AViewName: string; const AQuery: TFluentQuery<T>): TDextViewResult;
begin
  Result := View(AViewName).WithQuery<T>('Model', AQuery);
end;

class function Results.View(const AViewName: string; AData: TObject; AOwns: Boolean): TDextViewResult;
begin
  Result := View(AViewName).WithData('Model', AData, AOwns);
end;

class function Results.ViewPart(const AViewName: string): TDextViewResult;
begin
  Result := View(AViewName).WithLayout('');
end;

class function Results.ViewPart<T>(const AViewName: string; const AQuery: TFluentQuery<T>): TDextViewResult;
begin
  Result := ViewPart(AViewName).WithQuery<T>('Model', AQuery);
end;

class function Results.ViewPart(const AViewName: string; AData: TObject; AOwns: Boolean): TDextViewResult;
begin
  Result := ViewPart(AViewName).WithData('Model', AData, AOwns).WithLayout('');
end;

class procedure Results.SetViewsPath(const APath: string);
begin
  FViewsPath := APath;
end;

class procedure Results.SetAppPath(const APath: string);
begin
  FAppPath := APath;
end;

class function Results.GetFullViewPath(const ARelativePath: string): string;
var
  ViewPath: string;
begin
  // If ViewsPath is an absolute path, use it directly
  if (FViewsPath <> '') and TPath.IsPathRooted(FViewsPath) then
    ViewPath := FViewsPath
  else
  begin
    // Combine with app path or executable directory
    if FAppPath <> '' then
      ViewPath := FAppPath
    else
      ViewPath := ExtractFilePath(ParamStr(0));
      
    // Combine with views path if set
    if FViewsPath <> '' then
      ViewPath := TPath.Combine(ViewPath, FViewsPath);
  end;
    
  // Ensure views path ends with path delimiter
  ViewPath := IncludeTrailingPathDelimiter(ViewPath);
  
  // Remove leading path separator from relative path if present
  if (Length(ARelativePath) > 0) and CharInSet(ARelativePath[1], ['\', '/']) then
    Result := ViewPath + Copy(ARelativePath, 2, MaxInt)
  else
    Result := ViewPath + ARelativePath;
end;

class function Results.HtmlFromFile(const ARelativePath: string; AStatusCode: Integer): IResult;
var
  FullPath: string;
  Content: string;
begin
  FullPath := GetFullViewPath(ARelativePath);
  
  if TFile.Exists(FullPath) then
  begin
    Content := TFile.ReadAllText(FullPath, TEncoding.UTF8);
    Result := TContentResult.Create(Content, 'text/html', AStatusCode);
  end
  else
    Result := TContentResult.Create(
      Format('<html><body><h1>View Not Found</h1><p>%s</p></body></html>', [FullPath]), 
      'text/html', 404);
end;

class function Results.ReadViewFile(const ARelativePath: string): string;
var
  FullPath: string;
begin
  FullPath := GetFullViewPath(ARelativePath);
  
  if TFile.Exists(FullPath) then
    Result := TFile.ReadAllText(FullPath, TEncoding.UTF8)
  else
    Result := Format('<html><body><h1>View Not Found</h1><p>%s</p></body></html>', [FullPath]);
end;

{ TRedirectResult }

constructor TRedirectResult.Create(const AUrl: string; APermanent, APreserveMethod, ALocalOnly: Boolean);
begin
  inherited Create;
  FUrl := AUrl;
  FPermanent := APermanent;
  FPreserveMethod := APreserveMethod;
  FLocalOnly := ALocalOnly;
end;

procedure TRedirectResult.Execute(AContext: IHttpContext);
var
  Code: Integer;
begin
  if FLocalOnly and FUrl.StartsWith('http', True) then
  begin
    AContext.Response.StatusCode := HttpStatus.BadRequest;
    AContext.Response.Write('Local redirect allowed only for relative URLs.');
    Exit;
  end;

  if FPermanent then
    Code := IfThen(FPreserveMethod, HttpStatus.PermanentRedirect, HttpStatus.MovedPermanently)
  else
    Code := IfThen(FPreserveMethod, HttpStatus.TemporaryRedirect, HttpStatus.Found);

  AContext.Response.StatusCode := Code;
  AContext.Response.AddHeader('Location', FUrl);
end;

{ TFileResult }

constructor TFileResult.Create(const APath, AContentType, ADownloadName: string);
begin
  inherited Create;
  FPath := APath;
  FContentType := AContentType;
  FDownloadName := ADownloadName;
end;

procedure TFileResult.Execute(AContext: IHttpContext);
var
  Mime: string;
  Ext: string;
  Stream: TFileStream;
begin
  if not TFile.Exists(FPath) then
  begin
    AContext.Response.StatusCode := HttpStatus.NotFound;
    Exit;
  end;

  Mime := FContentType;
  if Mime = '' then
  begin
    Ext := TPath.GetExtension(FPath).ToLower;
    if Ext = '.pdf' then Mime := 'application/pdf'
    else if Ext = '.png' then Mime := 'image/png'
    else if Ext = '.jpg' then Mime := 'image/jpeg'
    else if Ext = '.jpeg' then Mime := 'image/jpeg'
    else if Ext = '.zip' then Mime := 'application/zip'
    else if Ext = '.txt' then Mime := 'text/plain'
    else if Ext = '.html' then Mime := 'text/html'
    else if Ext = '.json' then Mime := 'application/json'
    else Mime := 'application/octet-stream';
  end;

  AContext.Response.SetContentType(Mime);
  if FDownloadName <> '' then
    AContext.Response.AddHeader('Content-Disposition', 'attachment; filename="' + FDownloadName + '"');

  Stream := TFileStream.Create(FPath, fmOpenRead or fmShareDenyWrite);
  try
    AContext.Response.Write(Stream);
  finally
    Stream.Free;
  end;
end;

{ TValidationProblemResult }

constructor TValidationProblemResult.Create(const AValidation: TValidationResult);
begin
  inherited Create;
  FValidation := AValidation;
end;

procedure TValidationProblemResult.Execute(AContext: IHttpContext);
var
  Builder: TJsonBuilder;
  Err: TValidationError;
begin
  AContext.Response.StatusCode := HttpStatus.BadRequest;
  Builder := TJsonBuilder.NewBuilder
    .Add('type', 'https://tools.ietf.org/html/rfc7231#section-6.5.1')
    .Add('title', 'One or more validation errors occurred.')
    .Add('status', HttpStatus.BadRequest);

  Builder.AddObject('errors');
  for Err in FValidation.Errors do
    Builder.Add(Err.FieldName, Err.ErrorMessage);
  Builder.EndObject;
  try
    AContext.Response.Json(Builder.ToString);
  finally
    Builder.Free;
  end;
end;

{ TChallengeResult }

constructor TChallengeResult.Create(const AScheme: string);
begin
  inherited Create;
  FScheme := AScheme;
end;

procedure TChallengeResult.Execute(AContext: IHttpContext);
begin
  // Standard challenge triggers 401. 
  // Middlewares like JWT or BasicAuth will catch this if they are configured.
  AContext.Response.StatusCode := HttpStatus.Unauthorized;
  if FScheme <> '' then
    AContext.Response.AddHeader('WWW-Authenticate', FScheme);
end;

{ TForbidResult }

constructor TForbidResult.Create(const AScheme: string);
begin
  inherited Create;
  FScheme := AScheme;
end;

procedure TForbidResult.Execute(AContext: IHttpContext);
begin
  AContext.Response.StatusCode := HttpStatus.Forbidden;
end;

{ THtmxResponse }

constructor THtmxResponse.Create(const AResponse: IHttpResponse);
begin
  inherited Create;
  FResponse := AResponse;
end;

function THtmxResponse.PushUrl(const AUrl: string): IHtmxResponse;
begin
  FResponse.AddHeader('HX-Push-Url', AUrl);
  Result := Self;
end;

function THtmxResponse.Redirect(const AUrl: string): IHtmxResponse;
begin
  FResponse.AddHeader('HX-Redirect', AUrl);
  Result := Self;
end;

function THtmxResponse.Refresh: IHtmxResponse;
begin
  FResponse.AddHeader('HX-Refresh', 'true');
  Result := Self;
end;

function THtmxResponse.ReplaceUrl(const AUrl: string): IHtmxResponse;
begin
  FResponse.AddHeader('HX-Replace-Url', AUrl);
  Result := Self;
end;

function THtmxResponse.Reselect(const ASelector: string): IHtmxResponse;
begin
  FResponse.AddHeader('HX-Reselect', ASelector);
  Result := Self;
end;

function THtmxResponse.Reswap(const ASwap: string): IHtmxResponse;
begin
  FResponse.AddHeader('HX-Reswap', ASwap);
  Result := Self;
end;

function THtmxResponse.Retarget(const ASelector: string): IHtmxResponse;
begin
  FResponse.AddHeader('HX-Retarget', ASelector);
  Result := Self;
end;

function THtmxResponse.Trigger(const AEvent: string): IHtmxResponse;
begin
  FResponse.AddHeader('HX-Trigger', AEvent);
  Result := Self;
end;

function THtmxResponse.Trigger(const AEvent, APayload: string): IHtmxResponse;
begin
  FResponse.AddHeader('HX-Trigger', Format('{"%s": %s}', [AEvent, APayload]));
  Result := Self;
end;

function THtmxResponse.Location(const AUrl: string): IHtmxResponse;
begin
  FResponse.AddHeader('HX-Location', AUrl);
  Result := Self;
end;

end.
