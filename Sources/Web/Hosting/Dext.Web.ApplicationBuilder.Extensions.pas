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
  Dext.Web.Interfaces,
  Dext.Web.HandlerInvoker,
  Dext.Web.ModelBinding;

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
      
    class function MapPost<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapPost<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapPost<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 

    class function MapPost<TResult>(App: IApplicationBuilder; const Path: string;
        Handler: THandlerResultFunc<TResult>): IApplicationBuilder; overload;

    class function MapPut<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapPut<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapPut<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder; overload; 

    class function MapDelete<T, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder; overload;
    class function MapDelete<T1, T2, TResult>(App: IApplicationBuilder; const Path: string;
      Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder; overload;
    class function MapDelete<T1, T2, T3, TResult>(App: IApplicationBuilder; const Path: string;
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
  end;

implementation

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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T>(Handler);
      finally
        Invoker.Free;
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2>(Handler);
      finally
        Invoker.Free;
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3>(Handler);
      finally
        Invoker.Free;
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T>(Handler);
      finally
        Invoker.Free;
      end;
    end);
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2>(Handler);
      finally
        Invoker.Free;
      end;
    end);
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3>(Handler);
      finally
        Invoker.Free;
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T>(Handler);
      finally
        Invoker.Free;
      end;
    end);
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2>(Handler);
      finally
        Invoker.Free;
      end;
    end);
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3>(Handler);
      finally
        Invoker.Free;
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T>(Handler);
      finally
        Invoker.Free;
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2>(Handler);
      finally
        Invoker.Free;
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
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGet<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGet<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGet<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPost<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPost<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPost<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;


class function TApplicationBuilderExtensions.MapPut<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPut<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDelete<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDelete<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapGet<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('GET', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPost<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('POST', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapPut<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('PUT', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

class function TApplicationBuilderExtensions.MapDelete<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := App.MapEndpoint('DELETE', Path,
    procedure(Ctx: IHttpContext)
    var
      Invoker: THandlerInvoker;
      Binder: IModelBinder;
    begin
      Binder := TModelBinder.Create;
      Invoker := THandlerInvoker.Create(Ctx, Binder);
      try
        Invoker.Invoke<T1, T2, T3, TResult>(Handler);
      finally
        Invoker.Free;
      end;
    end);
end;

// Legacy R-suffix aliases implementation

class function TApplicationBuilderExtensions.MapGetR<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := MapGet<TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGetR<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := MapGet<T, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGetR<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := MapGet<T1, T2, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapGetR<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := MapGet<T1, T2, T3, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPostR<TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<TResult>): IApplicationBuilder;
begin
  Result := MapPost<TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPostR<T, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T, TResult>): IApplicationBuilder;
begin
  Result := MapPost<T, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPostR<T1, T2, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, TResult>): IApplicationBuilder;
begin
  Result := MapPost<T1, T2, TResult>(App, Path, Handler);
end;

class function TApplicationBuilderExtensions.MapPostR<T1, T2, T3, TResult>(App: IApplicationBuilder;
  const Path: string; Handler: THandlerResultFunc<T1, T2, T3, TResult>): IApplicationBuilder;
begin
  Result := MapPost<T1, T2, T3, TResult>(App, Path, Handler);
end;

end.
