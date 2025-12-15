unit DbSeeder;

interface

uses
  System.SysUtils,
  System.Hash,
  Dext.DI.Interfaces,
  Dext.DI.Extensions,
  Dext.Persistence,
  DbContext,
  User,
  UserSettings,
  Customer,
  Order;

type
  TDbSeeder = class
  private
    FServiceProvider: Dext.DI.Interfaces.IServiceProvider;
  public
    constructor Create(const AServiceProvider: Dext.DI.Interfaces.IServiceProvider);
    procedure Seed;
  end;

implementation

{ TDbSeeder }

constructor TDbSeeder.Create(const AServiceProvider: Dext.DI.Interfaces.IServiceProvider);
begin
  FServiceProvider := AServiceProvider;
end;

procedure TDbSeeder.Seed;
begin
  try
    Writeln('[*] Seeding Database...');
    
    // Create a scope to resolve Scoped services (DbContext)
    var Scope := FServiceProvider.CreateScope;
    
    // Resolve DbContext using manual resolution
    var SvcType := TServiceType.FromClass(TAppDbContext);
    var DbObj := Scope.ServiceProvider.GetService(SvcType);
    if DbObj = nil then
    begin
      Writeln('[ERROR] TAppDbContext could not be resolved');
      Exit;
    end;
    var Db := DbObj as TAppDbContext;
    
    // Register entities in FCache (required for EnsureCreated to work)
    Writeln('[*] Registering entities...');
    Db.Entities<TUser>;
    Db.Entities<TUserSettings>;
    Db.Entities<TCustomer>;
    Db.Entities<TOrder>;
    
    // Migrate/EnsureCreated
    Writeln('[*] Creating schema...');
    Db.EnsureCreated;
    Writeln('[OK] Database schema created/verified.');
    
    // Seed Data
    if Db.Entities<TUser>.List.Count = 0 then
    begin
      var Admin := TUser.Create;
      Admin.Username := 'admin';
      Admin.PasswordHash := THashSHA2.GetHashString('admin'); // Hash the password!
      Admin.Role := 'Admin';
      Db.Entities<TUser>.Add(Admin);
      
      // Add default settings for admin
      var AdminSettings := TUserSettings.Create;
      AdminSettings.UserId := 1; // Will be assigned after Admin is saved
      AdminSettings.EmailNotifications := True;
      AdminSettings.DarkMode := False;
      AdminSettings.AutoSave := True;
      Db.Entities<TUserSettings>.Add(AdminSettings);
      
      var C1 := TCustomer.Create; C1.Name := 'Alice Corp'; C1.Email := 'alice@corp.com'; C1.Status := TCustomerStatus.Active; C1.TotalSpent := 1200;
      var C2 := TCustomer.Create; C2.Name := 'Bob Ltd'; C2.Email := 'bob@ltd.com'; C2.Status := TCustomerStatus.Inactive; C2.TotalSpent := 0;
      var C3 := TCustomer.Create; C3.Name := 'Cesar Romero Silva'; C3.Email := 'cesarliws@gmail.com'; C3.Status := TCustomerStatus.Active; C3.TotalSpent := 100;
      Db.Entities<TCustomer>.Add(C1);
      Db.Entities<TCustomer>.Add(C2);
      Db.Entities<TCustomer>.Add(C3);
      
      Db.SaveChanges;
      Writeln('[OK] Database seeded!');
    end
    else
    begin
      Writeln('[OK] Database already exists.');
    end;
  except
    on E: Exception do
      Writeln('[ERROR] Seeding DB: ' + E.Message);
  end;
end;

end.
