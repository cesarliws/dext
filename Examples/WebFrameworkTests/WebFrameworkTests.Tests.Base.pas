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
begin
  WriteLn('🔧 Setting up test...');
  var Builder := TDextWebHost.CreateDefaultBuilder
    .UseUrls('http://localhost:' + FPort.ToString);
    
  ConfigureHost(Builder);
  
  FHost := Builder.Build;
  
  // Run the server in a background thread because Run() is blocking
  TThread.CreateAnonymousThread(procedure
    begin
      try
        FHost.Run;
      except
        // Ignore errors during shutdown or startup in background
      end;
    end).Start;
  
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
    FHost := nil;
  end;
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
