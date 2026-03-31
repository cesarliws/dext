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
  System.IOUtils,
  System.Rtti,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces,
  Dext.Web.Formatters.Interfaces,
  Dext.Web.Formatters.Json, // Default formatter
  Dext.Web.View,
  Dext.Entity.Core,
  Dext.Entity.Query,
  Dext.Json;

type
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

  TJsonResult = class(TResult)
  private
    FJson: string;
    FStatusCode: Integer;
  public
    constructor Create(const AJson: string; AStatusCode: Integer = 200);
    procedure Execute(AContext: IHttpContext); override;
  end;

  TStatusCodeResult = class(TResult)
  private
    FStatusCode: Integer;
  public
    constructor Create(AStatusCode: Integer);
    procedure Execute(AContext: IHttpContext); override;
  end;

  TContentResult = class(TResult)
  private
    FContent: string;
    FContentType: string;
    FStatusCode: Integer;
  public
    constructor Create(const AContent: string; const AContentType: string = 'text/plain; charset=utf-8'; AStatusCode: Integer = 200);
    procedure Execute(AContext: IHttpContext); override;
  end;

  TObjectResult<T> = class(TResult)
  private
    FValue: T;
    FStatusCode: Integer;
  public
    constructor Create(const AValue: T; AStatusCode: Integer = 200);
    procedure Execute(AContext: IHttpContext); override;
  end;

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

  Results = class
  private
    class var FViewsPath: string;
    class var FAppPath: string;
    class function GetFullViewPath(const ARelativePath: string): string;
  public
    /// <summary>
    ///   Sets the root directory for view files (relative to app path or absolute).
    ///   Example: 'wwwroot\views' or 'C:\MyApp\views'
    /// </summary>
    class procedure SetViewsPath(const APath: string);
    
    /// <summary>
    ///   Sets the application root path (used for resolving relative paths).
    ///   If not set, uses the executable's directory.
    /// </summary>
    class procedure SetAppPath(const APath: string);
    
    class function Ok: IResult; overload;
    class function Ok(const AValue: string): IResult; overload;
    class function Ok<T>(const AValue: T): IResult; overload;
    
    class function Created(const AUri: string; const AValue: string): IResult; overload;
    class function Created<T>(const AUri: string; const AValue: T): IResult; overload;

    class function BadRequest: IResult; overload;
    class function BadRequest(const AError: string): IResult; overload;
    class function BadRequest<T>(const AError: T): IResult; overload;
    
    class function NotFound: IResult; overload;
    class function NotFound(const AMessage: string): IResult; overload;

    class function NoContent: IResult;
    
    class function Unauthorized: IResult; overload;
    class function Unauthorized(const AMessage: string): IResult; overload;
    class function Unauthorized<T>(const AValue: T): IResult; overload;

    class function Forbidden: IResult; overload;
    class function Forbidden(const AMessage: string): IResult; overload;
    class function Forbidden<T>(const AValue: T): IResult; overload;

    class function InternalServerError(const AMessage: string): IResult; overload;
    class function InternalServerError(const E: Exception): IResult; overload;
    
    /// <summary>
    ///   Alias for InternalServerError - accepts an Exception directly.
    ///   Usage: Result := Results.InternalError(E);
    /// </summary>
    class function InternalError(const E: Exception): IResult; overload;
    class function InternalError(const AMessage: string): IResult; overload;

    class function Json(const AJson: string; AStatusCode: Integer = 200): IResult; overload;
    class function Json<T>(const AValue: T; AStatusCode: Integer = 200): IResult; overload;
    /// <summary>
    ///   Plain text response with Content-Type text/plain; charset=utf-8.
    /// </summary>
    class function Text(const AContent: string; AStatusCode: Integer = 200): IResult;
    /// <summary>
    ///   HTML document or fragment with Content-Type text/html; charset=utf-8.
    /// </summary>
    class function Html(const AHtml: string; AStatusCode: Integer = 200): IResult;
    /// <summary>
    ///   Raw string body with the given Content-Type. Include charset in AContentType for text
    ///   (e.g. text/xml; charset=utf-8) so browsers and Indy encode Unicode correctly.
    /// </summary>
    class function Content(const AContent: string; const AContentType: string; AStatusCode: Integer = 200): IResult;
    /// <summary>
    ///   Sends AStream as the body. Caller owns the stream until Execute runs; TStreamResult frees it.
    /// </summary>
    class function Stream(const AStream: TStream; const AContentType: string; AStatusCode: Integer = 200): IResult;
    
    /// <summary>
    ///   Returns HTML read from disk as UTF-8 (BOM allowed) with Content-Type text/html; charset=utf-8.
    ///   Path is resolved via GetFullViewPath (SetViewsPath / SetAppPath).
    /// </summary>
    class function HtmlFromFile(const ARelativePath: string; AStatusCode: Integer = 200): IResult;
    
    /// <summary>
    ///   Reads a view file as UTF-8 and returns its text, or a small HTML error snippet if missing.
    /// </summary>
    class function ReadViewFile(const ARelativePath: string): string;

    class function StatusCode(ACode: Integer): IResult; overload;
    class function StatusCode(ACode: Integer; const AContent: string): IResult; overload;
    
    class function View(const AViewName: string): TDextViewResult; overload;
    class function View<T: class>(const AViewName: string; const AQuery: TFluentQuery<T>): TDextViewResult; overload;
    class function View(const AViewName: string; AData: TObject; AOwns: Boolean = False): TDextViewResult; overload;
    
    class function ViewPart(const AViewName: string): TDextViewResult; overload;
    class function ViewPart<T: class>(const AViewName: string; const AQuery: TFluentQuery<T>): TDextViewResult; overload;
    class function ViewPart(const AViewName: string; AData: TObject; AOwns: Boolean = False): TDextViewResult; overload;
  end;

implementation

function ResultsHtmlEscape(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

{ TOutputFormatterContext }

constructor TOutputFormatterContext.Create(const AContext: IHttpContext; ATypeInfo: Pointer; const AObject: TValue);
var
  Ctx: TRttiContext;
begin
  inherited Create;
  FContext := AContext;
  // Use stack-local TRttiContext to avoid holding a reference to the global RTTI pool.
  // The TRttiType pointer remains valid as long as the pool exists.
  Ctx := TRttiContext.Create;
  try
    FObjectType := Ctx.GetType(ATypeInfo);
  finally
    Ctx.Free;
  end;
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
begin
  AContext.Response.StatusCode := FStatusCode;
  Ctx := TOutputFormatterContext.Create(AContext, TypeInfo(T), TValue.From<T>(FValue));
  
  Formatter := nil;
  
  // 1. Resolve Selector
  if AContext.Services <> nil then
  begin
    var SelectorObj := AContext.Services.GetServiceAsInterface(TServiceType.FromInterface(TypeInfo(IOutputFormatterSelector)));
    if SelectorObj <> nil then
    begin
       Selector := SelectorObj as IOutputFormatterSelector;

       // 2. Resolve Formatters via Registry
       var RegistryObj := AContext.Services.GetServiceAsInterface(TServiceType.FromInterface(TypeInfo(IOutputFormatterRegistry)));
       if RegistryObj <> nil then
       begin
          var Registry := RegistryObj as IOutputFormatterRegistry;
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
  // Optimization: String is likely raw content or JSON, but to be safe for API, treat as object?
  // No, typical Results.Ok("some string") expects text/plain or json string?
  // Current behavior was Json. Let's keep it compatible but strictly it should be generic.
  // Overload ambiguity: Ok("text") vs Ok<string>("text").
  // Let's assume non-generic overload implies direct string content (Json result in old code).
  Result := TJsonResult.Create(AValue, 200);
end;

class function Results.Ok<T>(const AValue: T): IResult;
begin
  Result := TObjectResult<T>.Create(AValue, 200);
end;

class function Results.Created(const AUri, AValue: string): IResult;
begin
  // TODO: Set Location header
  Result := TJsonResult.Create(AValue, 201);
end;

class function Results.Created<T>(const AUri: string; const AValue: T): IResult;
begin
  Result := TObjectResult<T>.Create(AValue, 201);
end;

class function Results.BadRequest: IResult;
begin
  Result := TStatusCodeResult.Create(400);
end;

class function Results.BadRequest(const AError: string): IResult;
begin
  Result := TJsonResult.Create(Format('{"error": "%s"}', [AError]), 400);
end;

class function Results.BadRequest<T>(const AError: T): IResult;
begin
  Result := TObjectResult<T>.Create(AError, 400);
end;

class function Results.NotFound: IResult;
begin
  Result := TStatusCodeResult.Create(404);
end;

class function Results.NotFound(const AMessage: string): IResult;
begin
  Result := TJsonResult.Create(Format('{"error": "%s"}', [AMessage]), 404);
end;

class function Results.NoContent: IResult;
begin
  Result := TStatusCodeResult.Create(204);
end;

class function Results.Unauthorized: IResult;
begin
  Result := TStatusCodeResult.Create(401);
end;

class function Results.Unauthorized(const AMessage: string): IResult;
begin
  Result := TJsonResult.Create(Format('{"error": "%s"}', [AMessage]), 401);
end;

class function Results.Unauthorized<T>(const AValue: T): IResult;
begin
  Result := TObjectResult<T>.Create(AValue, 401);
end;

class function Results.Forbidden: IResult;
begin
  Result := TStatusCodeResult.Create(403);
end;

class function Results.Forbidden(const AMessage: string): IResult;
begin
  Result := TJsonResult.Create(Format('{"error": "%s"}', [AMessage]), 403);
end;

class function Results.Forbidden<T>(const AValue: T): IResult;
begin
  Result := TObjectResult<T>.Create(AValue, 403);
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
  Result := TContentResult.Create(AContent, 'text/plain; charset=utf-8', AStatusCode);
end;

class function Results.Html(const AHtml: string; AStatusCode: Integer = 200): IResult;
begin
  Result := TContentResult.Create(AHtml, 'text/html; charset=utf-8', AStatusCode);
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
    Result := TContentResult.Create(Content, 'text/html; charset=utf-8', AStatusCode);
  end
  else
    Result := TContentResult.Create(
      Format('<html><head><meta charset="utf-8"/></head><body><h1>View Not Found</h1><p>%s</p></body></html>',
        [ResultsHtmlEscape(FullPath)]),
      'text/html; charset=utf-8', 404);
end;

class function Results.ReadViewFile(const ARelativePath: string): string;
var
  FullPath: string;
begin
  FullPath := GetFullViewPath(ARelativePath);
  
  if TFile.Exists(FullPath) then
    Result := TFile.ReadAllText(FullPath, TEncoding.UTF8)
  else
    Result := Format('<html><head><meta charset="utf-8"/></head><body><h1>View Not Found</h1><p>%s</p></body></html>',
      [ResultsHtmlEscape(FullPath)]);
end;

end.
