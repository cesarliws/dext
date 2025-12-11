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
unit Dext.Filters;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Http.Interfaces,
  Dext.Http.Results;

type
  /// <summary>
  ///   Descriptor for an action (controller method).
  /// </summary>
  TActionDescriptor = record
    ControllerName: string;
    ActionName: string;
    HttpMethod: string;
    Route: string;
  end;

  /// <summary>
  ///   Context for action execution (before action runs).
  /// </summary>
  IActionExecutingContext = interface
    ['{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}']
    function GetHttpContext: IHttpContext;
    function GetActionDescriptor: TActionDescriptor;
    function GetResult: IResult;
    procedure SetResult(const AValue: IResult);
    
    property HttpContext: IHttpContext read GetHttpContext;
    property ActionDescriptor: TActionDescriptor read GetActionDescriptor;
    property Result: IResult read GetResult write SetResult;
  end;

  /// <summary>
  ///   Context for action executed (after action runs).
  /// </summary>
  IActionExecutedContext = interface
    ['{B2C3D4E5-F6A7-8901-2345-67890ABCDEF1}']
    function GetHttpContext: IHttpContext;
    function GetActionDescriptor: TActionDescriptor;
    function GetResult: IResult;
    procedure SetResult(const AValue: IResult);
    function GetException: Exception;
    function GetExceptionHandled: Boolean;
    procedure SetExceptionHandled(const AValue: Boolean);
    
    property HttpContext: IHttpContext read GetHttpContext;
    property ActionDescriptor: TActionDescriptor read GetActionDescriptor;
    property Result: IResult read GetResult write SetResult;
    property Exception: Exception read GetException;
    property ExceptionHandled: Boolean read GetExceptionHandled write SetExceptionHandled;
  end;

  /// <summary>
  ///   Base interface for action filters.
  /// </summary>
  IActionFilter = interface
    ['{C3D4E5F6-A7B8-9012-3456-7890ABCDEF12}']
    procedure OnActionExecuting(AContext: IActionExecutingContext);
    procedure OnActionExecuted(AContext: IActionExecutedContext);
  end;

  /// <summary>
  ///   Base attribute for action filters.
  ///   Derive from this to create custom filter attributes.
  ///   Note: Implements IInterface manually because attributes are managed by RTTI.
  /// </summary>
  ActionFilterAttribute = class(TCustomAttribute, IActionFilter)
  protected
    // IInterface - Manual implementation (no reference counting)
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    procedure OnActionExecuting(AContext: IActionExecutingContext); virtual;
    procedure OnActionExecuted(AContext: IActionExecutedContext); virtual;
  end;

  /// <summary>
  ///   Implementation of IActionExecutingContext.
  /// </summary>
  TActionExecutingContext = class(TInterfacedObject, IActionExecutingContext)
  private
    FHttpContext: IHttpContext;
    FActionDescriptor: TActionDescriptor;
    FResult: IResult;
  public
    constructor Create(AHttpContext: IHttpContext; const ADescriptor: TActionDescriptor);
    
    function GetHttpContext: IHttpContext;
    function GetActionDescriptor: TActionDescriptor;
    function GetResult: IResult;
    procedure SetResult(const AValue: IResult);
    property Result: IResult read GetResult write SetResult;
  end;

  /// <summary>
  ///   Implementation of IActionExecutedContext.
  /// </summary>
  TActionExecutedContext = class(TInterfacedObject, IActionExecutedContext)
  private
    FHttpContext: IHttpContext;
    FActionDescriptor: TActionDescriptor;
    FResult: IResult;
    FException: Exception;
    FExceptionHandled: Boolean;
  public
    constructor Create(AHttpContext: IHttpContext; const ADescriptor: TActionDescriptor;
      AResult: IResult; AException: Exception);
    
    function GetHttpContext: IHttpContext;
    function GetActionDescriptor: TActionDescriptor;
    function GetResult: IResult;
    procedure SetResult(const AValue: IResult);
    function GetException: Exception;
    function GetExceptionHandled: Boolean;
    procedure SetExceptionHandled(const AValue: Boolean);
    property ExceptionHandled: Boolean read GetExceptionHandled write SetExceptionHandled;
  end;


implementation

{ ActionFilterAttribute }

procedure ActionFilterAttribute.OnActionExecuting(AContext: IActionExecutingContext);
begin
  // Base implementation does nothing
end;

procedure ActionFilterAttribute.OnActionExecuted(AContext: IActionExecutedContext);
begin
  // Base implementation does nothing
end;

// IInterface implementation - Dummy (no reference counting)
// Attributes are managed by RTTI, not by reference counting
function ActionFilterAttribute.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function ActionFilterAttribute._AddRef: Integer;
begin
  Result := -1; // Disable reference counting
end;

function ActionFilterAttribute._Release: Integer;
begin
  Result := -1; // Disable reference counting
end;

{ TActionExecutingContext }

constructor TActionExecutingContext.Create(AHttpContext: IHttpContext; 
  const ADescriptor: TActionDescriptor);
begin
  inherited Create;
  FHttpContext := AHttpContext;
  FActionDescriptor := ADescriptor;
  FResult := nil;
end;

function TActionExecutingContext.GetHttpContext: IHttpContext;
begin
  Result := FHttpContext;
end;

function TActionExecutingContext.GetActionDescriptor: TActionDescriptor;
begin
  Result := FActionDescriptor;
end;

function TActionExecutingContext.GetResult: IResult;
begin
  Result := FResult;
end;

procedure TActionExecutingContext.SetResult(const AValue: IResult);
begin
  FResult := AValue;
end;

{ TActionExecutedContext }

constructor TActionExecutedContext.Create(AHttpContext: IHttpContext; 
  const ADescriptor: TActionDescriptor; AResult: IResult; AException: Exception);
begin
  inherited Create;
  FHttpContext := AHttpContext;
  FActionDescriptor := ADescriptor;
  FResult := AResult;
  FException := AException;
  FExceptionHandled := False;
end;

function TActionExecutedContext.GetHttpContext: IHttpContext;
begin
  Result := FHttpContext;
end;

function TActionExecutedContext.GetActionDescriptor: TActionDescriptor;
begin
  Result := FActionDescriptor;
end;

function TActionExecutedContext.GetResult: IResult;
begin
  Result := FResult;
end;

procedure TActionExecutedContext.SetResult(const AValue: IResult);
begin
  FResult := AValue;
end;

function TActionExecutedContext.GetException: Exception;
begin
  Result := FException;
end;

function TActionExecutedContext.GetExceptionHandled: Boolean;
begin
  Result := FExceptionHandled;
end;

procedure TActionExecutedContext.SetExceptionHandled(const AValue: Boolean);
begin
  FExceptionHandled := AValue;
end;

end.

