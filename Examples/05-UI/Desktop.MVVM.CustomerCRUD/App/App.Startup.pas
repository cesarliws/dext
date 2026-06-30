{***************************************************************************}
{                                                                           }
{           Dext Framework - Example                                        }
{                                                                           }
{           App Startup - DI Container Configuration                        }
{                                                                           }
{***************************************************************************}
unit App.Startup;

interface

uses
  System.SysUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Customer.Entity,
  Customer.Service,
  Customer.Controller,
  Customer.Context,
  Dext, Dext.DI.Interfaces,
  Dext.Configuration.Interfaces,
  Dext.Configuration.Yaml,
  Dext.Configuration.Binder, // Added for TConfigurationBinder
  Dext.Entity,
  Dext.UI.Navigator.Interfaces,
  Dext.UI.Navigator;

type
  /// <summary>
  /// Application startup and DI configuration
  /// </summary>
  TAppStartup = class
  private
    class var FServices: TDextServices;
    class var FProvider: IServiceProvider;
    class var FLogger: ILogger;
    class var FConfig: IConfiguration;
    class var FNavigator: INavigator;
    
    class procedure SeedDemoData;
  public
    class procedure Configure;
    class procedure Shutdown;
    
    class function GetCustomerService: ICustomerService;
    class function GetLogger: ILogger;
    class function GetCustomerController: ICustomerController;
    class function GetNavigator: INavigator;
  end;

implementation

{ TAppStartup }

class procedure TAppStartup.Configure;
begin
  // Load Configuration from YAML with in-memory defaults
  FConfig := TYamlConfigurationBuilder.Create
    .AddValues([
      TPair<string, string>.Create('Database:DriverName', 'SQLite'),
      TPair<string, string>.Create('Database:Params:Database', 'customers.db'),
      TPair<string, string>.Create('Database:Naming', 'snake_case')
    ])
    .AddYamlFile('appsettings.yaml', True) // True = Optional
    .Build;

  // Create DI Container using the fluent wrapper
  FServices := TDextServices.New;
  
  // Register Logger as a singleton instance
  FLogger := TConsoleLogger.Create('CustomerCRUD');
  FServices.AddSingleton<ILogger>(FLogger);
  
  // Register DB Context from configuration
  FServices.AddDbContext<TCustomerContext>(
    procedure(Options: TDbContextOptions)
    begin
      TConfigurationBinder.Bind(FConfig.GetSection('Database'), Options);
    end
  );
  
  // Register Customer Service
  FServices.AddSingleton<ICustomerService, TCustomerService>;
  
  // Register Controller
  FServices.AddTransient<ICustomerController, TCustomerController>;
  
  // Build provider
  FProvider := FServices.BuildServiceProvider;
  
  // Create Navigator singleton (configured in MainForm)
  FNavigator := TNavigator.Create(FProvider);
  
  FLogger.Info('Application configured successfully (YAML + DB + Navigator)');
  
  // Seed demo data
  SeedDemoData;
end;

class procedure TAppStartup.SeedDemoData;
var
  Service: ICustomerService;
  Customer: TCustomer;
begin
  Service := GetCustomerService;
  
  // Note: Objects added to the DbContext are managed by the IdentityMap.
  // Do NOT free them manually or the IdentityMap will have dangling pointers.
  
  Customer := TCustomer.Create;
  Customer.Name := 'John Doe';
  Customer.Email := 'john.doe@example.com';
  Customer.Phone := '+1 555-1234';
  Customer.Document := '123.456.789-00';
  Customer.Active := True;
  Service.Save(Customer);
  
  Customer := TCustomer.Create;
  Customer.Name := 'Jane Smith';
  Customer.Email := 'jane.smith@example.com';
  Customer.Phone := '+1 555-5678';
  Customer.Document := '987.654.321-00';
  Customer.Active := True;
  Service.Save(Customer);
  
  Customer := TCustomer.Create;
  Customer.Name := 'Bob Johnson';
  Customer.Email := 'bob.johnson@example.com';
  Customer.Phone := '+1 555-9999';
  Customer.Document := '111.222.333-44';
  Customer.Active := False;
  Service.Save(Customer);
  
  FLogger.Info('Demo data seeded: 3 customers');
end;

class procedure TAppStartup.Shutdown;
begin
  FLogger.Info('Application shutting down');
  FNavigator := nil;
  FProvider := nil;
  FServices := Default(TDextServices);
end;

class function TAppStartup.GetCustomerService: ICustomerService;
begin
  Result := TDextServices.GetService<ICustomerService>(FProvider);
end;

class function TAppStartup.GetLogger: ILogger;
begin
  Result := FLogger;
end;

class function TAppStartup.GetCustomerController: ICustomerController;
begin
  Result := TDextServices.GetService<ICustomerController>(FProvider);
end;

class function TAppStartup.GetNavigator: INavigator;
begin
  Result := FNavigator;
end;

end.
