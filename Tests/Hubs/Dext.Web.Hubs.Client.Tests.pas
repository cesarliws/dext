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
unit Dext.Web.Hubs.Client.Tests;

interface

procedure RunClientTests(var APassed, AFailed: Integer);

implementation

uses
  System.SysUtils,
  System.Rtti,
  Dext.Web.Hubs.Interfaces,
  Dext.Web.Hubs.Client.Types,
  Dext.Web.Hubs.Client;

var
  LocalPassed: Integer = 0;
  LocalFailed: Integer = 0;

procedure Check(Condition: Boolean; const TestName: string);
begin
  if Condition then
  begin
    Inc(LocalPassed);
    WriteLn('[PASS] ', TestName);
  end
  else
  begin
    Inc(LocalFailed);
    WriteLn('[FAIL] ', TestName);
  end;
end;

procedure TestConnectionBuilder;
var
  Conn: IDextHubConnection;
begin
  Conn := TDextHubConnectionBuilder.New
    .WithUrl('http://localhost:8080/hubs/test')
    .WithTransport(ctWebSocket)
    .WithHeader('Authorization', 'Bearer token123')
    .WithQueryParam('client', 'desktop')
    .Build;

  Check(Conn <> nil, 'Builder returns connection');
  Check(Conn.State = csDisconnected, 'Initial state is csDisconnected');
end;

procedure TestCallbackRegistry;
var
  Registry: THubCallbackRegistry;
  CallCount1, CallCount2: Integer;
  Proc1: TProc<string>;
  Proc2: TProc<string, string>;
begin
  Registry := THubCallbackRegistry.Create;
  try
    CallCount1 := 0;
    CallCount2 := 0;

    Proc1 := procedure(Val: string)
      begin
        Check(Val = 'Hello', 'OnTest1 callback value matches');
        Inc(CallCount1);
      end;

    Proc2 := procedure(Val1, Val2: string)
      begin
        Check(Val1 = 'First', 'OnTest2 callback arg1 matches');
        Check(Val2 = 'Second', 'OnTest2 callback arg2 matches');
        Inc(CallCount2);
      end;

    Registry.RegisterCallback('OnTest1', TValue.From<TProc<string>>(Proc1));
    Registry.RegisterCallback('OnTest2', TValue.From<TProc<string, string>>(Proc2));

    Registry.Dispatch('OnTest1', [TValue.From('Hello')]);
    Registry.Dispatch('ontest2', [TValue.From('First'), TValue.From('Second')]);

    Check(CallCount1 = 1, 'OnTest1 invoked once');
    Check(CallCount2 = 1, 'OnTest2 invoked once');
  finally
    Registry.Free;
  end;
end;

procedure RunClientTests(var APassed, AFailed: Integer);
begin
  WriteLn;
  WriteLn('=== Delphi Hub Client Tests ===');
  LocalPassed := 0;
  LocalFailed := 0;

  TestConnectionBuilder;
  TestCallbackRegistry;

  APassed := APassed + LocalPassed;
  AFailed := AFailed + LocalFailed;
end;

end.
