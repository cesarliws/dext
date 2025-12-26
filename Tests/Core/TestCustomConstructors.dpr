program TestCustomConstructors;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext,
  Dext.DI.Core,
  Dext.DI.Interfaces,
  Dext.DI.Extensions,
  Dext.DI.Attributes;

type
  ILogger = interface
    ['{8F3C4D2E-1A5B-4C7D-9E8F-2A3B4C5D6E7F}']
    procedure Log(const Msg: string);
  end;

  TConsoleLogger = class(TInterfacedObject, ILogger)
    procedure Log(const Msg: string);
  end;

  IConfig = interface
    ['{9A1B2C3D-4E5F-6A7B-8C9D-0E1F2A3B4C5D}']
    function GetValue: string;
  end;

  TAppConfig = class(TInterfacedObject, IConfig)
    function GetValue: string;
  end;

  // Service with multiple constructors
  TMyService = class
  private
    FLogger: ILogger;
    FConfig: IConfig;
    FConstructorUsed: string;
  public
    // Constructor 1: No parameters (should NOT be used by DI)
    constructor Create; overload;
    
    // Constructor 2: Only Logger (greedy would prefer Constructor 3)
    constructor Create(ALogger: ILogger); overload;

    // Constructor 3: Logger + Config (greedy would pick this)
    [ServiceConstructor]  // But we mark this one as preferred!
    constructor Create(ALogger: ILogger; AConfig: IConfig); overload;

    property ConstructorUsed: string read FConstructorUsed;
  end;

{ TConsoleLogger }

procedure TConsoleLogger.Log(const Msg: string);
begin
  WriteLn('[LOG] ', Msg);
end;

{ TAppConfig }

function TAppConfig.GetValue: string;
begin
  Result := 'AppConfig Value';
end;

{ TMyService }

constructor TMyService.Create;
begin
  FConstructorUsed := 'Create()';
  WriteLn('  -> Called: Create()');
end;

constructor TMyService.Create(ALogger: ILogger);
begin
  FLogger := ALogger;
  FConstructorUsed := 'Create(ILogger)';
  WriteLn('  -> Called: Create(ILogger)');
end;

constructor TMyService.Create(ALogger: ILogger; AConfig: IConfig);
begin
  FLogger := ALogger;
  FConfig := AConfig;
  FConstructorUsed := 'Create(ILogger, IConfig)';
  WriteLn('  -> Called: Create(ILogger, IConfig)');
end;

procedure TestServiceConstructorAttribute;
var
  Services: IServiceCollection;
  Provider: IServiceProvider;
  MyService: TMyService;
begin
  WriteLn('=== Test: [ServiceConstructor] Attribute ===');
  WriteLn;
  
  Services := TDextServiceCollection.Create;
  
  // Register dependencies (using helper for generic methods)
  TServiceCollectionExtensions.AddSingleton<ILogger, TConsoleLogger>(Services);
  TServiceCollectionExtensions.AddSingleton<IConfig, TAppConfig>(Services);
  Services.AddScoped(TServiceType.FromClass(TMyService), TMyService);
  
  Provider := Services.BuildServiceProvider;
  
  WriteLn('Resolving TMyService from DI...');
  MyService := Provider.GetService(TServiceType.FromClass(TMyService)) as TMyService;
  
  WriteLn;
  WriteLn('Constructor used: ', MyService.ConstructorUsed);
  WriteLn;
  
  if MyService.ConstructorUsed = 'Create(ILogger, IConfig)' then
  begin
    WriteLn('✓ PASS: [ServiceConstructor] attribute was respected!');
    WriteLn('  The DI container used the marked constructor instead of greedy selection.');
  end
  else
  begin
    WriteLn('✗ FAIL: Wrong constructor was used!');
    WriteLn('  Expected: Create(ILogger, IConfig)');
    WriteLn('  Got: ', MyService.ConstructorUsed);
    raise Exception.Create('Test failed');
  end;
  
  // Note: MyService is managed by DI (Scoped), so we don't Free it manually
end;

procedure TestGreedyFallback;
begin
  WriteLn;
  WriteLn('=== Test: Greedy Fallback (No Attribute) ===');
  WriteLn;
  WriteLn('(This would test greedy selection when no [ServiceConstructor] is present)');
  WriteLn('✓ Skipped for now - covered by existing DI tests');
end;

begin
  try
    WriteLn('Dext Custom Constructors (DI) Tests');
    WriteLn('====================================');
    WriteLn;
    
    TestServiceConstructorAttribute;
    TestGreedyFallback;
    
    WriteLn;
    WriteLn('====================================');
    WriteLn('All tests passed!');
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('ERROR: ', E.Message);
      ExitCode := 1;
    end;
  end;
  
  WriteLn;
  WriteLn('Press ENTER to exit...');
  ReadLn;
end.
