{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025-2026 Cesar Romero & Dext Contributors        }
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
unit Dext.Web.Hubs.Middleware.Tests;

{$I Dext.inc}

interface

procedure RunMiddlewareTests(var APassed, AFailed: Integer);

implementation

uses
  System.Rtti,
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Mocks,
  Dext.Web.Hubs.Hub,
  Dext.Web.Hubs.Middleware,
  Dext.Web.Interfaces,
  Dext.Web.Mocks;

type
  /// <summary>Minimal Hub used only to register a route in the middleware.</summary>
  TProbeHub = class(THub)
  end;

var
  Passed: Integer;
  Failed: Integer;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  if ACondition then
  begin
    Inc(Passed);
    WriteLn('[PASS] ', ATestName);
  end
  else
  begin
    Inc(Failed);
    WriteLn('[FAIL] ', ATestName);
  end;
end;

/// <summary>
/// Builds an IHttpRequest double. Only the members read by THubMiddleware.Handle
/// are configured: method, path and the Upgrade header.
/// </summary>
function CreateRequest(const AMethod, APath, AUpgrade: string): IHttpRequest;
var
  MockRequest: Mock<IHttpRequest>;
  Query: IStringDictionary;
  Headers: IStringDictionary;
begin
  MockRequest := Mock<IHttpRequest>.Create;
  Query := TCollections.CreateStringDictionary(True);
  Headers := TCollections.CreateStringDictionary(True);

  MockRequest.Setup.Returns(TValue.From<IStringDictionary>(Query)).When.GetQuery;
  MockRequest.Setup.Returns(TValue.From<IStringDictionary>(Headers)).When.GetHeaders;
  MockRequest.Setup.Returns(AMethod).When.GetMethod;
  MockRequest.Setup.Returns(APath).When.GetPath;
  MockRequest.Setup.Returns(AUpgrade).When.GetHeader('Upgrade');

  Result := MockRequest.Instance;
end;

function CreateContext(const AMethod, APath, AUpgrade: string): IHttpContext;
begin
  // TMockHttpContext.GetConnection returns nil, exactly like the Indy, DCS and
  // WebBroker contexts, so this is the engine-without-upgrade scenario.
  Result := TMockHttpContext.Create(CreateRequest(AMethod, APath, AUpgrade),
    TMockHttpResponse.Create);
end;

procedure TestUpgradeRequestWithoutServerConnection;
var
  Middleware: THubMiddleware;
  Ctx: IHttpContext;
  NextCalled: Boolean;
  UpgradeHeader: string;
begin
  WriteLn;
  WriteLn('=== THubMiddleware Upgrade Without Connection Tests ===');

  Middleware := THubMiddleware.Create;
  try
    Middleware.MapHub('/hubs/probe', TProbeHub);

    Ctx := CreateContext('GET', '/hubs/probe', 'websocket');
    NextCalled := False;
    Middleware.Handle(Ctx,
      procedure(AContext: IHttpContext)
      begin
        NextCalled := True;
      end);

    Check(Ctx.Response.StatusCode = 426,
      'Upgrade request on engine without connection answers 426');
    Check(not NextCalled,
      'Upgrade request on engine without connection is not forwarded to Next');

    UpgradeHeader := '';
    Ctx.Response.GetHeaders.TryGetValue('Upgrade', UpgradeHeader);
    Check(SameText(UpgradeHeader, 'websocket'),
      '426 response advertises the Upgrade header');
  finally
    Middleware.Free;
  end;
end;

procedure TestRegularRequestStillRouted;
var
  Middleware: THubMiddleware;
  Ctx: IHttpContext;
  NextCalled: Boolean;
begin
  Middleware := THubMiddleware.Create;
  try
    Middleware.MapHub('/hubs/probe', TProbeHub);

    // No Upgrade header: the request must reach the SSE handler, which rejects
    // the missing connection id with 400 instead of touching Connection.
    Ctx := CreateContext('GET', '/hubs/probe', '');
    NextCalled := False;
    Middleware.Handle(Ctx,
      procedure(AContext: IHttpContext)
      begin
        NextCalled := True;
      end);

    Check(Ctx.Response.StatusCode = 400,
      'Plain GET without connection id still answers 400');
    Check(not NextCalled,
      'Plain GET on a mapped hub is not forwarded to Next');

    // A trailing slash must resolve the same hub: MapHub trims it on the
    // registered path, so the request path has to be trimmed as well.
    Ctx := CreateContext('GET', '/hubs/probe/', '');
    NextCalled := False;
    Middleware.Handle(Ctx,
      procedure(AContext: IHttpContext)
      begin
        NextCalled := True;
      end);

    Check(Ctx.Response.StatusCode = 400,
      'Trailing slash still routes to the hub');
    Check(not NextCalled,
      'Trailing slash is not forwarded to Next');

    // Unmapped path keeps flowing through the pipeline.
    Ctx := CreateContext('GET', '/api/other', '');
    NextCalled := False;
    Middleware.Handle(Ctx,
      procedure(AContext: IHttpContext)
      begin
        NextCalled := True;
      end);

    Check(NextCalled, 'Unmapped path is forwarded to Next');
  finally
    Middleware.Free;
  end;
end;

procedure RunMiddlewareTests(var APassed, AFailed: Integer);
begin
  Passed := 0;
  Failed := 0;

  TestUpgradeRequestWithoutServerConnection;
  TestRegularRequestStillRouted;

  APassed := APassed + Passed;
  AFailed := AFailed + Failed;
end;

end.
