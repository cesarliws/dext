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
unit Dext.Http.Results;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.DI.Interfaces,
  Dext.Http.Interfaces,
  Dext.Http.Formatters.Interfaces,
  Dext.Http.Formatters.Json, // Default formatter
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
    FCtx: TRttiContext;
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
    constructor Create(const AContent: string; const AContentType: string = 'text/plain'; AStatusCode: Integer = 200);
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

  Results = class
  public
    class function Ok: IResult; overload;
    class function Ok(const AValue: string): IResult; overload;
    class function Ok<T>(const AValue: T): IResult; overload;
    
    class function Created(const AUri: string; const AValue: string): IResult; overload;
    class function Created<T>(const AUri: string; const AValue: T): IResult; overload;

    class function BadRequest: IResult; overload;
    class function BadRequest(const AError: string): IResult; overload;
    
    class function NotFound: IResult; overload;
    class function NotFound(const AMessage: string): IResult; overload;

    class function NoContent: IResult;
    
    class function Json(const AJson: string; AStatusCode: Integer = 200): IResult;
    class function Text(const AContent: string; AStatusCode: Integer = 200): IResult;
    class function StatusCode(ACode: Integer): IResult; overload;
    class function StatusCode(ACode: Integer; const AContent: string): IResult; overload;
  end;

implementation

{ TOutputFormatterContext }

constructor TOutputFormatterContext.Create(const AContext: IHttpContext; ATypeInfo: Pointer; const AObject: TValue);
begin
  inherited Create;
  FContext := AContext;
  FCtx := TRttiContext.Create;
  FObjectType := FCtx.GetType(ATypeInfo);
  FObject := AObject;
end;

destructor TOutputFormatterContext.Destroy;
begin
  FCtx.Free;
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

class function Results.Json(const AJson: string; AStatusCode: Integer): IResult;
begin
  Result := TJsonResult.Create(AJson, AStatusCode);
end;

class function Results.Text(const AContent: string; AStatusCode: Integer): IResult;
begin
  Result := TContentResult.Create(AContent, 'text/plain', AStatusCode);
end;

class function Results.StatusCode(ACode: Integer): IResult;
begin
  Result := TStatusCodeResult.Create(ACode);
end;

class function Results.StatusCode(ACode: Integer; const AContent: string): IResult;
begin
  Result := TJsonResult.Create(AContent, ACode);
end;

end.

