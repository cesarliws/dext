unit DbSeeder;

interface

uses
  System.SysUtils,
  System.Hash,
  Dext.DI.Interfaces,
  Dext.Entity,
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

uses
  Dext.Logging.Global;

{ TDbSeeder }

constructor TDbSeeder.Create(const AServiceProvider: Dext.DI.Interfaces.IServiceProvider);
begin
  FServiceProvider := AServiceProvider;
end;

procedure TDbSeeder.Seed;
var
  Scope: IServiceScope;
  SvcType: TServiceType;
  DbObj: TObject;
  Db: TAppDbContext;
  Admin: TUser;
  AdminSettings: TUserSettings;
  C1, C2, C3: TCustomer;
begin
  try
    Log.Info('[*] Seeding Database...');
    
    // Create a scope to resolve Scoped services (DbContext)
    Scope := FServiceProvider.CreateScope;
    
    // Resolve DbContext using manual resolution
    SvcType := TServiceType.FromClass(TAppDbContext);
    DbObj := Scope.ServiceProvider.GetService(SvcType);
    if DbObj = nil then
    begin
      Log.Error('[ERROR] TAppDbContext could not be resolved');
      Exit;
    end;
    Db := DbObj as TAppDbContext;
    
    // Register entities in FCache (required for EnsureCreated to work)
    Log.Info('[*] Registering entities...');
    Db.Entities<TUser>;
    Db.Entities<TUserSettings>;
    Db.Entities<TCustomer>;
    Db.Entities<TOrder>;
    
    // Migrate/EnsureCreated
    Log.Info('[*] Creating schema...');
    Db.EnsureCreated;
    Log.Info('[OK] Database schema created/verified.');
    
    // Seed Data
    if Db.Entities<TUser>.ToList.Count = 0 then
    begin
      Admin := TUser.Create;
      Admin.Username := 'admin';
      Admin.PasswordHash := THashSHA2.GetHashString('admin'); // Hash the password!
      Admin.Role := 'Admin';
      Db.Entities<TUser>.Add(Admin);
      
      // Add default settings for admin
      AdminSettings := TUserSettings.Create;
      AdminSettings.UserId := 1; // Will be assigned after Admin is saved
      AdminSettings.EmailNotifications := True;
      AdminSettings.DarkMode := False;
      AdminSettings.AutoSave := True;
      Db.Entities<TUserSettings>.Add(AdminSettings);
      
      C1 := TCustomer.Create; C1.Name := 'Alice Corp'; C1.Email := 'alice@corp.com'; C1.Status := TCustomerStatus.Active; C1.TotalSpent := 1200;
      C2 := TCustomer.Create; C2.Name := 'Bob Ltd'; C2.Email := 'bob@ltd.com'; C2.Status := TCustomerStatus.Inactive; C2.TotalSpent := 0;
      C3 := TCustomer.Create; C3.Name := 'Dext'; C3.Email := 'dext.dotpas@gmail.com'; C3.Status := TCustomerStatus.Active; C3.TotalSpent := 100;
      Db.Entities<TCustomer>.Add(C1);
      Db.Entities<TCustomer>.Add(C2);
      Db.Entities<TCustomer>.Add(C3);
      
      Db.SaveChanges;
      Log.Info('[OK] Database seeded!');
    end
    else
    begin
      Log.Info('[OK] Database already exists.');
    end;
  except
    on E: Exception do
      Log.Error('[ERROR] Seeding DB: {Message}', [E.Message]);
  end;
end;

end.
