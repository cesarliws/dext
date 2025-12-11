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
unit Dext.Filters.BuiltIn;

interface

uses
  System.SysUtils,
  System.DateUtils,
  Dext.Filters,
  Dext.Http.Interfaces,
  Dext.Http.Results;

type
  /// <summary>
  ///   Logs action execution time and details.
  /// </summary>
  LogActionAttribute = class(ActionFilterAttribute)
  private
    FStartTime: TDateTime;
  public
    procedure OnActionExecuting(AContext: IActionExecutingContext); override;
    procedure OnActionExecuted(AContext: IActionExecutedContext); override;
  end;

  /// <summary>
  ///   Validates that the request has a specific header.
  /// </summary>
  RequireHeaderAttribute = class(ActionFilterAttribute)
  private
    FHeaderName: string;
    FErrorMessage: string;
  public
    constructor Create(const AHeaderName: string; const AErrorMessage: string = '');
    procedure OnActionExecuting(AContext: IActionExecutingContext); override;
  end;

  /// <summary>
  ///   Sets response cache headers.
  /// </summary>
  ResponseCacheAttribute = class(ActionFilterAttribute)
  private
    FDuration: Integer; // seconds
    FLocation: string;  // 'public', 'private', 'no-cache'
  public
    constructor Create(ADuration: Integer; const ALocation: string = 'public');
    procedure OnActionExecuted(AContext: IActionExecutedContext); override;
  end;

  /// <summary>
  ///   Validates model state (can be extended).
  /// </summary>
  ValidateModelAttribute = class(ActionFilterAttribute)
  public
    procedure OnActionExecuting(AContext: IActionExecutingContext); override;
  end;

  /// <summary>
  ///   Adds custom headers to the response.
  /// </summary>
  AddHeaderAttribute = class(ActionFilterAttribute)
  private
    FHeaderName: string;
    FHeaderValue: string;
  public
    constructor Create(const AName, AValue: string);
    procedure OnActionExecuted(AContext: IActionExecutedContext); override;
  end;

implementation

uses
  Dext.Logging;

{ LogActionAttribute }

procedure LogActionAttribute.OnActionExecuting(AContext: IActionExecutingContext);
begin
  FStartTime := Now;
  WriteLn(Format('[ActionFilter] Executing: %s.%s (%s %s)', 
    [AContext.ActionDescriptor.ControllerName,
     AContext.ActionDescriptor.ActionName,
     AContext.ActionDescriptor.HttpMethod,
     AContext.ActionDescriptor.Route]));
end;

procedure LogActionAttribute.OnActionExecuted(AContext: IActionExecutedContext);
var
  ElapsedMs: Int64;
begin
  ElapsedMs := MilliSecondsBetween(Now, FStartTime);
  
  if Assigned(AContext.Exception) then
  begin
    WriteLn(Format('[ActionFilter] Executed: %s.%s - EXCEPTION: %s (took %d ms)', 
      [AContext.ActionDescriptor.ControllerName,
       AContext.ActionDescriptor.ActionName,
       AContext.Exception.Message,
       ElapsedMs]));
  end
  else
  begin
    WriteLn(Format('[ActionFilter] Executed: %s.%s - SUCCESS (took %d ms)', 
      [AContext.ActionDescriptor.ControllerName,
       AContext.ActionDescriptor.ActionName,
       ElapsedMs]));
  end;
end;

{ RequireHeaderAttribute }

constructor RequireHeaderAttribute.Create(const AHeaderName: string; 
  const AErrorMessage: string);
begin
  inherited Create;
  FHeaderName := AHeaderName;
  FErrorMessage := AErrorMessage;
  
  if FErrorMessage.IsEmpty then
    FErrorMessage := Format('Missing required header: %s', [FHeaderName]);
end;

procedure RequireHeaderAttribute.OnActionExecuting(AContext: IActionExecutingContext);
var
  HeaderValue: string;
begin
  if not AContext.HttpContext.Request.Headers.TryGetValue(FHeaderName, HeaderValue) then
  begin
    // Short-circuit: return 400 Bad Request
    AContext.Result := Results.BadRequest(
      Format('{"error":"%s"}', [FErrorMessage])
    );
  end;
end;

{ ResponseCacheAttribute }

constructor ResponseCacheAttribute.Create(ADuration: Integer; const ALocation: string);
begin
  inherited Create;
  FDuration := ADuration;
  FLocation := ALocation;
end;

procedure ResponseCacheAttribute.OnActionExecuted(AContext: IActionExecutedContext);
var
  CacheControl: string;
begin
  if not Assigned(AContext.Exception) then
  begin
    CacheControl := Format('%s, max-age=%d', [FLocation, FDuration]);
    AContext.HttpContext.Response.AddHeader('Cache-Control', CacheControl);
  end;
end;

{ ValidateModelAttribute }

procedure ValidateModelAttribute.OnActionExecuting(AContext: IActionExecutingContext);
begin
  // Placeholder: In a real implementation, this would check model validation errors
  // For now, it's a no-op since validation happens in model binding
  // You could extend this to add custom validation logic
end;

{ AddHeaderAttribute }

constructor AddHeaderAttribute.Create(const AName, AValue: string);
begin
  inherited Create;
  FHeaderName := AName;
  FHeaderValue := AValue;
end;

procedure AddHeaderAttribute.OnActionExecuted(AContext: IActionExecutedContext);
begin
  if not Assigned(AContext.Exception) then
  begin
    AContext.HttpContext.Response.AddHeader(FHeaderName, FHeaderValue);
  end;
end;

end.



