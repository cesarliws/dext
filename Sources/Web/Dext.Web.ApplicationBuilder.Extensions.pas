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
unit Dext.Web.ApplicationBuilder.Extensions;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Web.Interfaces,
  Dext.Web.HandlerInvoker,
  Dext.Web.ModelBinding,
  Dext.OpenAPI.Types,
  Dext.OpenAPI.Generator;

type
  TApplicationBuilderExtensions = class
  public
    /// <summary>
    ///   Maps a POST request to a handler with 1 argument.
    /// </summary>
    class function MapPost<T>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T>): IApplicationBuilder; overload;
      
    class function MapPost<T1, T2>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2>): IApplicationBuilder; overload;

    class function MapPost<T1, T2, T3>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder; overload;

    /// <summary>
    ///   Maps a GET request to a handler with 1 argument.
    /// </summary>
    class function MapGet<T>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T>): IApplicationBuilder; overload;
      
    class function MapGet<T1, T2>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2>): IApplicationBuilder; overload;

    class function MapGet<T1, T2, T3>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder; overload;

    /// <summary>
    ///   Maps a PUT request to a handler with 1 argument.
    /// </summary>
    class function MapPut<T>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T>): IApplicationBuilder; overload;
      
    class function MapPut<T1, T2>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2>): IApplicationBuilder; overload;

    class function MapPut<T1, T2, T3>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder; overload;

    /// <summary>
    ///   Maps a DELETE request to a handler with 1 argument.
    /// </summary>
    class function MapDelete<T>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T>): IApplicationBuilder; overload;
      
    class function MapDelete<T1, T2>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2>): IApplicationBuilder; overload;

    class function MapDelete<T1, T2, T3>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder; overload;

    // Extensions for handlers returning IResult
    class function MapGet<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapGet<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapGet<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapGet<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 
      
    class function MapPost<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapPost<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapPost<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapPost<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 

    class function MapPut<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapPut<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapPut<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapPut<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 

    class function MapDelete<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapDelete<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapDelete<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapDelete<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 

    class function MapGetResult<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapGetResult<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapGetResult<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapGetResult<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 
      
    class function MapPostResult<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapPostResult<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapPostResult<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapPostResult<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 

    class function MapPutResult<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapPutResult<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapPutResult<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapPutResult<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 

    class function MapDeleteResult<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapDeleteResult<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapDeleteResult<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapDeleteResult<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 

    // Legacy R-suffix aliases (deprecated - use MapGet/MapPost with TResult instead)
    class function MapGetR<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapGetR<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapGetR<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapGetR<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    class function MapPostR<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapPostR<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapPostR<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapPostR<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    // === QUERY methods ===
    class function MapQuery<T>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T>): IApplicationBuilder; overload;
    class function MapQuery<T1, T2>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2>): IApplicationBuilder; overload;
    class function MapQuery<T1, T2, T3>(App: IApplicationBuilder; const Path: string; 
      Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder; overload;

    class function MapQuery<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapQuery<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapQuery<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapQuery<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    class function MapQueryResult<TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    class function MapQueryResult<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapQueryResult<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapQueryResult<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;
  end;

  TDextAppBuilderHelper = record helper for TAppBuilder
  public
    // 1 Argument Handlers
    function MapGet<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder; overload;
    function MapPost<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder; overload;
    function MapPut<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder; overload;
    function MapDelete<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder; overload;

    // handlers returning IResult explicitly
    function MapGet<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapGet<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapGet<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapGet<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    function MapPost<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapPost<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapPost<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapPost<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;
    
    function MapPut<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapPut<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapPut<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapPut<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    function MapDelete<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapDelete<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapDelete<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapDelete<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    function MapQuery<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder; overload;
    function MapQuery<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): IApplicationBuilder; overload;
    function MapQuery<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder; overload;

    function MapQuery<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapQuery<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapQuery<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapQuery<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    function MapGetResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapGetResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapGetResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapGetResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    function MapPostResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapPostResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapPostResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapPostResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;
    
    function MapPutResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapPutResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapPutResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapPutResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    function MapDeleteResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapDeleteResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapDeleteResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapDeleteResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    function MapQueryResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;
    function MapQueryResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    function MapQueryResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    function MapQueryResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload;

    /// <summary>
    ///  Marks the last registered route as requiring authorization (defaults to 'Basic').
    /// </summary>
    function RequireAuthorization: IApplicationBuilder; overload;
    function RequireAuthorization(const AScheme: string): IApplicationBuilder; overload;
    function RequireAuthorization(const ASchemes: array of string): IApplicationBuilder; overload;
    /// <summary>
    ///   Configures the supported query media types for the last registered HTTP QUERY endpoint.
    /// </summary>
    /// <param name="AMediaTypes">An array of media type strings (e.g. 'application/jsonpath').</param>
    /// <returns>The application builder instance for chaining.</returns>
    function AcceptsQuery(const AMediaTypes: array of string): IApplicationBuilder;

    // Middleware Extensions
    function UseSwagger: IApplicationBuilder; overload;
    function UseSwagger(const AOptions: TOpenAPIOptions): IApplicationBuilder; overload;
    function UseSwagger(const ABuilder: TOpenAPIBuilder): IApplicationBuilder; overload;

    function UseExceptionHandler: TAppBuilder; overload;
    function UseDeveloperExceptionPage: TAppBuilder; overload;
    function UseHttpLogging: TAppBuilder; overload;
  end;


procedure UpdateRouteMetadata(App: IApplicationBuilder; RequestType: PTypeInfo; ResponseType: PTypeInfo);

implementation

uses
  Dext.OpenAPI.Extensions,
  Dext.Swagger.Middleware,
  Dext.Web.Middleware.Extensions;

{ TDextAppBuilderHelper }

function TDextAppBuilderHelper.MapGet<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapGet<T>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPost<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPost<T>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPut<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPut<T>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapDelete<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapDelete<T>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapGet<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapGetResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapGet<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapGetResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapGet<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapGetResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapGet<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapGetResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPost<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPostResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPost<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPostResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPost<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPostResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPost<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPostResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPut<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPutResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPut<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPutResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPut<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPutResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPut<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPutResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapDelete<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapDeleteResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapDelete<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapDeleteResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapDelete<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapDeleteResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapDelete<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapDeleteResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapGetResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapGetResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapGetResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapGetResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapGetResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapGetResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapGetResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapGetResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPostResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPostResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPostResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPostResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPostResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPostResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPostResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPostResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPutResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPutResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPutResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPutResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPutResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPutResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapPutResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapPutResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapDeleteResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapDeleteResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapDeleteResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapDeleteResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapDeleteResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapDeleteResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapDeleteResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapDeleteResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQuery<T>(const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQuery<T>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQuery<T1, T2>(const Path: string; Handler: THandlerProc<T1, T2>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQuery<T1, T2>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQuery<T1, T2, T3>(const Path: string; Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQuery<T1, T2, T3>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQuery<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQueryResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQuery<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQueryResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQuery<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQueryResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQuery<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQueryResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQueryResult<TResult>(const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQueryResult<TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQueryResult<T, TResult>(const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQueryResult<T, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQueryResult<T1, T2, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQueryResult<T1, T2, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.MapQueryResult<T1, T2, T3, TResult>(const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := TApplicationBuilderExtensions.MapQueryResult<T1, T2, T3, TResult>(Self.Unwrap, Path, Handler);
end;

function TDextAppBuilderHelper.RequireAuthorization: IApplicationBuilder;
begin
  Result := TEndpointMetadataExtensions.RequireAuthorization(Self.Unwrap, ['Basic']);
end;

function TDextAppBuilderHelper.RequireAuthorization(const AScheme: string): IApplicationBuilder;
begin
  Result := TEndpointMetadataExtensions.RequireAuthorization(Self.Unwrap, AScheme);
end;

function TDextAppBuilderHelper.RequireAuthorization(const ASchemes: array of string): IApplicationBuilder;
begin
  Result := TEndpointMetadataExtensions.RequireAuthorization(Self.Unwrap, ASchemes);
end;

function TDextAppBuilderHelper.AcceptsQuery(const AMediaTypes: array of string): IApplicationBuilder;
begin
  Result := TEndpointMetadataExtensions.AcceptsQuery(Self.Unwrap, AMediaTypes);
end;

function TDextAppBuilderHelper.UseSwagger: IApplicationBuilder;
begin
  Result := TSwaggerExtensions.UseSwagger(Self.Unwrap);
end;

function TDextAppBuilderHelper.UseSwagger(const AOptions: TOpenAPIOptions): IApplicationBuilder;
begin
  Result := TSwaggerExtensions.UseSwagger(Self.Unwrap, AOptions);
end;

function TDextAppBuilderHelper.UseSwagger(const ABuilder: TOpenAPIBuilder): IApplicationBuilder;
begin
  Result := TSwaggerExtensions.UseSwagger(Self.Unwrap, ABuilder.Build);
end;

function TDextAppBuilderHelper.UseExceptionHandler: TAppBuilder;
begin
  TApplicationBuilderMiddlewareExtensions.UseExceptionHandler(Self.Unwrap);
  Result := Self;
end;

function TDextAppBuilderHelper.UseDeveloperExceptionPage: TAppBuilder;
begin
  TApplicationBuilderMiddlewareExtensions.UseDeveloperExceptionPage(Self.Unwrap);
  Result := Self;
end;

function TDextAppBuilderHelper.UseHttpLogging: TAppBuilder;
begin
  TApplicationBuilderMiddlewareExtensions.UseHttpLogging(Self.Unwrap);
  Result := Self;
end;


procedure UpdateRouteMetadata(App: IApplicationBuilder; RequestType: PTypeInfo; ResponseType: PTypeInfo);
var
  Routes: TArray<TEndpointMetadata>;
  Metadata: TEndpointMetadata;
begin
  Routes := App.GetRoutes;
  if Length(Routes) > 0 then
  begin
    Metadata := Routes[High(Routes)];
    if RequestType <> nil then Metadata.RequestType := RequestType;
    if ResponseType <> nil then Metadata.ResponseType := ResponseType;
    App.UpdateLastRouteMetadata(Metadata);
  end;
end;

{ TApplicationBuilderExtensions }

class function TApplicationBuilderExtensions.MapGet<T>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGet<T1, T2>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGet<T1, T2, T3>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPost<T>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T>(Handler);
      finally
        Invoker.Release;
      end;
    end);
  UpdateRouteMetadata(App, TypeInfo(T), nil);
end;

class function TApplicationBuilderExtensions.MapPost<T1, T2>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2>(Handler);
      finally
        Invoker.Release;
      end;
    end);
  UpdateRouteMetadata(App, TypeInfo(T1), nil);
end;

class function TApplicationBuilderExtensions.MapPost<T1, T2, T3>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPut<T>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T>(Handler);
      finally
        Invoker.Release;
      end;
    end);
  UpdateRouteMetadata(App, TypeInfo(T), nil);
end;

class function TApplicationBuilderExtensions.MapPut<T1, T2>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2>(Handler);
      finally
        Invoker.Release;
      end;
    end);
  UpdateRouteMetadata(App, TypeInfo(T1), nil);
end;

class function TApplicationBuilderExtensions.MapPut<T1, T2, T3>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDelete<T>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDelete<T1, T2>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDelete<T1, T2, T3>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGet<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := MapGetResult<TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGet<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := MapGetResult<T, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGet<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := MapGetResult<T1, T2, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGet<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := MapGetResult<T1, T2, T3, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPost<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := MapPostResult<TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPost<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := MapPostResult<T, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPost<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := MapPostResult<T1, T2, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPost<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := MapPostResult<T1, T2, T3, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPut<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := MapPutResult<TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPut<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := MapPutResult<T, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPut<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := MapPutResult<T1, T2, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPut<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := MapPutResult<T1, T2, T3, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapDelete<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := MapDeleteResult<TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapDelete<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := MapDeleteResult<T, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapDelete<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := MapDeleteResult<T1, T2, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapDelete<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := MapDeleteResult<T1, T2, T3, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGetResult<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGetResult<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGetResult<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPostResult<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
  UpdateRouteMetadata(App, TypeInfo(T), TypeInfo(TResult));
end;

class function TApplicationBuilderExtensions.MapPostResult<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPostResult<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;


class function TApplicationBuilderExtensions.MapPutResult<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPutResult<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPutResult<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDeleteResult<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDeleteResult<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDeleteResult<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGetResult<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPostResult<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPutResult<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDeleteResult<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapQuery<T>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('QUERY', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapQuery<T1, T2>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('QUERY', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapQuery<T1, T2, T3>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerProc<T1, T2, T3>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('QUERY', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapQuery<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := MapQueryResult<TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapQuery<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := MapQueryResult<T, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapQuery<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := MapQueryResult<T1, T2, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapQuery<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := MapQueryResult<T1, T2, T3, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapQueryResult<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('QUERY', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapQueryResult<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('QUERY', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapQueryResult<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('QUERY', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapQueryResult<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('QUERY', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Default;
      Invoker := THandlerInvoker.Acquire(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3, TResult>(Handler);
      finally
        Invoker.Release;
      end;
    end);
end;

// Legacy R-suffix aliases implementation

class function TApplicationBuilderExtensions.MapGetR<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := MapGetResult<TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGetR<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := MapGetResult<T, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGetR<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := MapGetResult<T1, T2, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGetR<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := MapGetResult<T1, T2, T3, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPostR<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := MapPostResult<TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPostR<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := MapPostResult<T, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPostR<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := MapPostResult<T1, T2, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPostR<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := MapPostResult<T1, T2, T3, TResult>(App, Path, Handler);
end;

end.
