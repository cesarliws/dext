unit WebFrameworkTests.Tests.Base;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.WebHost,
  Dext.DI.Interfaces,
  Dext.Http.Interfaces,
  System.Net.HttpClient;

type
  TBaseTest = class
  protected
    FPort: Integer;
    FClient: THttpClient;
    FHost: IWebHost;
    FServerThread: TThread; // Explicit thread management
    
    procedure Log(const Msg: string);
    procedure LogSuccess(const Msg: string);
    procedure LogError(const Msg: string);
    procedure AssertTrue(Condition: Boolean; const SuccessMsg, FailMsg: string);
    procedure AssertEqual(const Expected, Actual: string; const Context: string);
    
    procedure Setup; virtual;
    procedure TearDown; virtual;
    
    /// <summary>
    ///  Configures the web host builder. Override to add services/middleware.
    /// </summary>
    procedure ConfigureHost(const Builder: IWebHostBuilder); virtual;

    function GetBaseUrl: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run; virtual; abstract;
  end;

  TBaseTestClass = class of TBaseTest;

implementation

{ TBaseTest }

constructor TBaseTest.Create;
begin
  inherited;
  FPort := 8081; // Default test port
  FClient := THttpClient.Create;
  Setup;
end;

destructor TBaseTest.Destroy;
begin
  TearDown;
  FClient.Free;
  inherited;
end;

procedure TBaseTest.Setup;
var
  Builder: IWebHostBuilder;
  HostRef: IWebHost; // Explicitly capture FHost for thread safety
begin
  WriteLn('🔧 Setting up test...');
  Builder := TDextWebHost.CreateDefaultBuilder
    .UseUrls('http://localhost:' + FPort.ToString);
    
  ConfigureHost(Builder);
  
  FHost := Builder.Build;
  
  Builder := nil; // Force release
  
  // Run the server in a background thread because Run() is blocking
  FServerThread := TThread.CreateAnonymousThread(procedure
    begin
      try
        // Keep a reference to prevent premature destruction if FHost is cleared elsewhere
        HostRef := FHost; 
        if HostRef <> nil then
          HostRef.Run;
      except
        // Ignore errors during shutdown or startup in background
      end;
    end);
    
  FServerThread.FreeOnTerminate := False; // We will manage lifecycle
  FServerThread.Start;
  
  // Give it a moment to start
  Sleep(200);
end;

procedure TBaseTest.ConfigureHost(const Builder: IWebHostBuilder);
begin
  // Default implementation does nothing
end;

procedure TBaseTest.TearDown;
begin
  if Assigned(FHost) then
  begin
    FHost.Stop;
  end;
  
  if Assigned(FServerThread) then
  begin
    FServerThread.WaitFor;
    FreeAndNil(FServerThread);
  end;
  
  FHost := nil;
end;

function TBaseTest.GetBaseUrl: string;
begin
  Result := Format('http://localhost:%d', [FPort]);
end;

procedure TBaseTest.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

procedure TBaseTest.LogSuccess(const Msg: string);
begin
  WriteLn('   ✅ ' + Msg);
end;

procedure TBaseTest.LogError(const Msg: string);
begin
  WriteLn('   ❌ ' + Msg);
end;

procedure TBaseTest.AssertTrue(Condition: Boolean; const SuccessMsg, FailMsg: string);
begin
  if Condition then
    LogSuccess(SuccessMsg)
  else
    LogError(FailMsg);
end;

procedure TBaseTest.AssertEqual(const Expected, Actual: string; const Context: string);
begin
  if Expected = Actual then
    LogSuccess(Format('%s: Expected "%s" and got "%s"', [Context, Expected, Actual]))
  else
    LogError(Format('%s: Expected "%s" BUT got "%s"', [Context, Expected, Actual]));
end;

end.
