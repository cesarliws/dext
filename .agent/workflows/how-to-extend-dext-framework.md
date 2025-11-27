---
description: How to extend the Dext framework with new middleware and fluent APIs
---

# How to Extend Dext Framework

This guide explains how to extend the Dext framework by adding new middleware, services, and fluent API extensions. The framework is designed to be extensible through the `Dext.pas` unit, which acts as a central facade.

## 1. Create Your Middleware or Service

First, implement your core logic in a separate unit.

### Example: Custom Logging Middleware

```pascal
unit My.Custom.Logging;

interface

uses
  Dext.Http.Interfaces, System.SysUtils;

type
  TCustomLoggingMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FNext: TRequestDelegate;
  public
    constructor Create(Next: TRequestDelegate);
    procedure Invoke(Context: IHttpContext);
  end;

implementation

constructor TCustomLoggingMiddleware.Create(Next: TRequestDelegate);
begin
  FNext := Next;
end;

procedure TCustomLoggingMiddleware.Invoke(Context: IHttpContext);
begin
  WriteLn('📝 Request: ' + Context.Request.Path);
  FNext(Context);
  WriteLn('📝 Response: ' + IntToStr(Context.Response.StatusCode));
end;

end.
```

## 2. Extend the Fluent API

To make your new feature easy to use, extend the `TDextAppBuilder` or `TDextServices` records using a helper.

### Option A: Modify `Dext.pas` (Recommended for Core Features)

If you are contributing to the core framework, add your methods directly to `TDextAppBuilderHelper` or `TDextServicesHelper` in `Dext.pas`.

```pascal
// In Dext.pas

type
  TDextAppBuilderHelper = record helper for TDextAppBuilder
  public
    // ... existing methods ...
    function UseCustomLogging: TDextAppBuilder;
  end;

implementation

function TDextAppBuilderHelper.UseCustomLogging: TDextAppBuilder;
begin
  // Use the Unwrap method to access the underlying IApplicationBuilder
  Self.Unwrap.UseMiddleware(TCustomLoggingMiddleware);
  Result := Self;
end;
```

### Option B: Create a Separate Helper (Recommended for Plugins/User Code)

If you are creating a plugin or extending Dext in your own project without modifying the core, create a new unit with a helper.

```pascal
unit My.Custom.Extensions;

interface

uses
  Dext, // Include the main facade
  My.Custom.Logging;

type
  // Define a new helper for TDextAppBuilder
  TMyCustomExtensions = record helper for TDextAppBuilder
  public
    function UseCustomLogging: TDextAppBuilder;
  end;

implementation

function TMyCustomExtensions.UseCustomLogging: TDextAppBuilder;
begin
  // Use Middleware
  Self.UseMiddleware(TCustomLoggingMiddleware);
  Result := Self;
end;

end.
```

## 3. Usage

Now you can use your new extension fluently in your application setup.

```pascal
uses
  Dext,
  My.Custom.Extensions; // If using Option B

begin
  var App := TDextApplication.Create;
  
  App.Builder
    .UseCustomLogging // Your new fluent method!
    .UseCors(corsOptions)
    .Build;
    
  App.Run;
end.
```

## Key Concepts

- **`TDextAppBuilder`**: A record wrapper around `IApplicationBuilder`. It is the target for all middleware configuration extensions.
- **`TDextServices`**: A record wrapper around `IServiceCollection`. It is the target for all service registration extensions.
- **`Unwrap`**: Both wrappers provide an `Unwrap` method to access the underlying interface if needed.
- **`Dext.pas`**: The central unit that exports all core types and helpers. Always try to keep it clean and use it as the main entry point.
