unit Dext.Web.Lifecycle.Tests;

// =============================================================================
// IWebApplication has a single-use lifecycle.
//
// Teardown releases the service collection and the configuration on purpose, to
// break the circular references captured by closures. Anything that tries to
// come back in afterwards -- Start, Run, or Setup directly -- would rebuild the
// provider from a collection that no longer exists.
//
// Before the guard that read address 0 and surfaced as an access violation,
// which says nothing about what to do. Now it refuses with a sentence that
// does: create a new instance.
// =============================================================================

interface

uses
  System.SysUtils,
  System.Classes, // EInvalidOperation
  Dext.Testing.Attributes,
  Dext.Assertions,
  Dext.Web,
  Dext.Web.Interfaces;

type
  [TestFixture('WebApplication single-use lifecycle')]
  TWebApplicationLifecycleTests = class
  public
    [Test('Starting a stopped application is refused, not an access violation')]
    procedure TestRestartIsRefused;
    [Test('The refusal says how to proceed')]
    procedure TestRefusalMessageIsActionable;
    [Test('A fresh instance starts normally after another one was stopped')]
    procedure TestFreshInstanceWorks;
  end;

implementation

procedure TWebApplicationLifecycleTests.TestRestartIsRefused;
var
  App: IWebApplication;
  Raised: Boolean;
begin
  App := WebApplication;
  App.Start(0);
  Should(App.Port).BeGreaterThan(0);
  App.Stop;

  Raised := False;
  try
    App.Start(0); // used to raise EAccessViolation here
  except
    on E: EInvalidOperation do
      Raised := True;
  end;
  Should(Raised).BeTrue;
end;

procedure TWebApplicationLifecycleTests.TestRefusalMessageIsActionable;
var
  App: IWebApplication;
  Msg: string;
begin
  // A refusal that only says "invalid operation" leaves the caller stuck. The
  // message has to name the way out, because there is one and it is short.
  App := WebApplication;
  App.Start(0);
  App.Stop;

  Msg := '';
  try
    App.Start(0);
  except
    on E: EInvalidOperation do
      Msg := E.Message;
  end;
  Should(Msg.Contains('cannot be restarted')).BeTrue;
  Should(Msg.Contains('new instance')).BeTrue;
end;

procedure TWebApplicationLifecycleTests.TestFreshInstanceWorks;
var
  First, Second: IWebApplication;
begin
  // The other half of the contract: refusing to restart must not mean the
  // process is done serving. A new instance has to come up normally.
  First := WebApplication;
  First.Start(0);
  First.Stop;
  First := nil;

  Second := WebApplication;
  try
    Second.Start(0);
    Should(Second.Port).BeGreaterThan(0);
    Second.Stop;
  finally
    Second := nil;
  end;
end;

end.
