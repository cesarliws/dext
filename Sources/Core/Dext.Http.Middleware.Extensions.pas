unit Dext.Http.Middleware.Extensions;

interface

uses
  System.Rtti,
  Dext.Http.Interfaces,
  Dext.Http.Middleware,
  Dext.Logging;

type
  TApplicationBuilderMiddlewareExtensions = class
  public
    class function UseHttpLogging(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload;
    class function UseHttpLogging(const ABuilder: IApplicationBuilder; const AOptions: THttpLoggingOptions): IApplicationBuilder; overload;
    
    class function UseExceptionHandler(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload;
    class function UseExceptionHandler(const ABuilder: IApplicationBuilder; const AOptions: TExceptionHandlerOptions): IApplicationBuilder; overload;
  end;

implementation

uses
  Dext.DI.Extensions;

{ TApplicationBuilderMiddlewareExtensions }

class function TApplicationBuilderMiddlewareExtensions.UseHttpLogging(const ABuilder: IApplicationBuilder): IApplicationBuilder;
begin
  Result := UseHttpLogging(ABuilder, THttpLoggingOptions.Default);
end;

class function TApplicationBuilderMiddlewareExtensions.UseHttpLogging(const ABuilder: IApplicationBuilder; const AOptions: THttpLoggingOptions): IApplicationBuilder;
begin
  var LLogger := TServiceProviderExtensions.GetRequiredService<ILogger>(ABuilder.GetServiceProvider);
  Result := ABuilder.UseMiddleware(THttpLoggingMiddleware, [TValue.From(LLogger), TValue.From(AOptions)]);
end;

class function TApplicationBuilderMiddlewareExtensions.UseExceptionHandler(const ABuilder: IApplicationBuilder): IApplicationBuilder;
begin
  Result := UseExceptionHandler(ABuilder, TExceptionHandlerOptions.Production);
end;

class function TApplicationBuilderMiddlewareExtensions.UseExceptionHandler(const ABuilder: IApplicationBuilder; const AOptions: TExceptionHandlerOptions): IApplicationBuilder;
begin
  var LLogger := TServiceProviderExtensions.GetRequiredService<ILogger>(ABuilder.GetServiceProvider);
  Result := ABuilder.UseMiddleware(TExceptionHandlerMiddleware, [TValue.From(LLogger), TValue.From(AOptions)]);
end;

end.
