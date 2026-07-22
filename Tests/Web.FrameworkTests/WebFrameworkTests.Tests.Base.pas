unit WebFrameworkTests.Tests.Base;

{$OVERFLOWCHECKS OFF}
{$RANGECHECKS OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient,
  Dext.WebHost,
  Dext.DI.Interfaces,
  Dext.Web.Interfaces;

type
  TBaseTest = class
  protected
    FPort: Integer;
    FClient: THttpClient;
    FHost: IWebHost;
    FServerThread: TThread; // Explicit thread management
    FServerError: string;

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
  FPort := 0; // Dynamic port support (S08)
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
  Retries: Integer;
  Success: Boolean;
  Resp: System.Net.HttpClient.IHTTPResponse;
begin
  WriteLn('🔧 Setting up test...');
  Builder := TDextWebHost.CreateDefaultBuilder
    .UseUrls('http://127.0.0.1:' + FPort.ToString);

  ConfigureHost(Builder);

  FHost := Builder.Build;

  Builder := nil; // Force release

  FServerError := '';
  FServerThread := TThread.CreateAnonymousThread(procedure
    var
      StackFrame: PNativeUInt;
      ReturnAddr: NativeUInt;
      Depth: Integer;
      StackStr: string;
    begin
      try
        // Keep a reference to prevent premature destruction
        HostRef := FHost;
        if HostRef <> nil then
        begin
          // Use Start instead of Run because Run might exit prematurely
          // if the 'no-wait' command line switch is present.
          HostRef.Start;
        end;
      except
        on E: Exception do
        begin
          StackStr := '';
          asm
            MOV StackFrame, EBP
          end;
          Depth := 0;
          while (StackFrame <> nil) and (Depth < 10) do
          begin
            try
              ReturnAddr := PNativeUInt(NativeUInt(StackFrame) + 4)^;
              if ReturnAddr > HInstance then
                StackStr := StackStr + Format(' -> %p', [Pointer(ReturnAddr - HInstance)]);
              StackFrame := PNativeUInt(StackFrame^);
            except
              Break;
            end;
            Inc(Depth);
          end;
          FServerError := E.ClassName + ': ' + E.Message + ' RVA: ' + Format('%p', [Pointer(NativeUInt(ExceptAddr) - HInstance)]) + ' Stack: ' + StackStr;
        end;
      end;
    end);

  FServerThread.FreeOnTerminate := False;
  FServerThread.Start;

  // Wait for the server port to be assigned (in case of dynamic port 0)
  Retries := 0;
  while (FHost <> nil) and (FHost.Port = 0) and (Retries < 50) and (FServerError = '') do
  begin
    TThread.Sleep(100);
    Inc(Retries);
  end;

  if (FHost <> nil) then
    FPort := FHost.Port;

  // Robust wait for server to start
  Retries := 0;
  Success := False;
  while (Retries < 50) and (not Success) and (FServerError = '') do
  begin
    try
      // Try to connect to the base URL
      Resp := FClient.Get(GetBaseUrl + '/');
      if Resp <> nil then
      begin
        Success := True;
        Break;
      end;
    except
      // Server not yet active
    end;

    Sleep(100);
    Inc(Retries);
  end;

  if FServerError <> '' then
    raise Exception.Create('Server failed to start: ' + FServerError);

  if not Success then
    raise Exception.Create('Server start timeout after 5 seconds at ' + GetBaseUrl);
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
  Result := Format('http://127.0.0.1:%d', [FPort]);
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
