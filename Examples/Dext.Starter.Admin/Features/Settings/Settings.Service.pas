unit Settings.Service;

interface

uses
  System.SysUtils,
  DbContext,
  User,
  UserSettings,
  Settings.Dto;

type
  TUserProfile = record
    Name: string;
    Email: string;
    Role: string;
  end;

  TAppSettings = record
    EmailNotifications: Boolean;
    DarkMode: Boolean;
    AutoSave: Boolean;
  end;

  ISettingsService = interface
    ['{C1D2E3F4-A5B6-47C8-9D0E-1F2A3B4C5D6E}']
    function GetProfile(UserId: Integer): TUserProfile;
    procedure UpdateProfile(UserId: Integer; const Name, Email: string);
    
    function GetAppSettings(UserId: Integer): TAppSettings;
    procedure UpdateAppSettings(UserId: Integer; const Settings: TSettingsAppDto);
    
    function UpdatePassword(UserId: Integer; const Current, New, Confirm: string; out Error: string): Boolean;
    function CanDeleteAccount(UserId: Integer): Boolean;
    procedure DeleteAccount(UserId: Integer);
  end;

  TSettingsService = class(TInterfacedObject, ISettingsService)
  private
    FDb: TAppDbContext;
  public
    constructor Create(Db: TAppDbContext);
    
    function GetProfile(UserId: Integer): TUserProfile;
    procedure UpdateProfile(UserId: Integer; const Name, Email: string);
    
    function GetAppSettings(UserId: Integer): TAppSettings;
    procedure UpdateAppSettings(UserId: Integer; const Settings: TSettingsAppDto);
    
    function UpdatePassword(UserId: Integer; const Current, New, Confirm: string; out Error: string): Boolean;
    function CanDeleteAccount(UserId: Integer): Boolean;
    procedure DeleteAccount(UserId: Integer);
  end;

implementation

uses
  System.Hash,
  Dext.Collections;

{ TSettingsService }

constructor TSettingsService.Create(Db: TAppDbContext);
begin
  FDb := Db;
end;

function TSettingsService.GetProfile(UserId: Integer): TUserProfile;
var
  U: TUser;
begin
  U := FDb.Entities<TUser>.Find(UserId);
  if U <> nil then
  begin
    Result.Name := U.Username;
    Result.Email := U.Username + '@dext.com'; // Example - no email field in User
    Result.Role := U.Role;
  end
  else
  begin
    Result.Name := 'Unknown';
    Result.Email := '';
    Result.Role := 'User';
  end;
end;

procedure TSettingsService.UpdateProfile(UserId: Integer; const Name, Email: string);
var
  U: TUser;
begin
  U := FDb.Entities<TUser>.Find(UserId);
  if U <> nil then
  begin
    U.Username := Name;
    // Note: TUser doesn't have Email field, would need to add it
    FDb.SaveChanges;
  end;
end;

function TSettingsService.GetAppSettings(UserId: Integer): TAppSettings;
var
  Settings: TUserSettings;
  AllSettings: IList<TUserSettings>;
  S: TUserSettings;
begin
  // Find settings for this user
  Settings := nil;
  AllSettings := FDb.Entities<TUserSettings>.List;
  for S in AllSettings do
  begin
    if S.UserId = UserId then
    begin
      Settings := S;
      Break;
    end;
  end;
  
  if Settings <> nil then
  begin
    Result.EmailNotifications := Settings.EmailNotifications;
    Result.DarkMode := Settings.DarkMode;
    Result.AutoSave := Settings.AutoSave;
  end
  else
  begin
    // Default settings
    Result.EmailNotifications := True;
    Result.DarkMode := False;
    Result.AutoSave := True;
  end;
end;

procedure TSettingsService.UpdateAppSettings(UserId: Integer; const Settings: TSettingsAppDto);
var
  ExistingSettings: TUserSettings;
  AllSettings: IList<TUserSettings>;
  S: TUserSettings;
begin
  // Find existing settings
  ExistingSettings := nil;
  AllSettings := FDb.Entities<TUserSettings>.List;
  for S in AllSettings do
  begin
    if S.UserId = UserId then
    begin
      ExistingSettings := S;
      Break;
    end;
  end;
  
  if ExistingSettings = nil then
  begin
    // Create new settings
    ExistingSettings := TUserSettings.Create;
    ExistingSettings.UserId := UserId;
    FDb.Entities<TUserSettings>.Add(ExistingSettings);
  end;
  
  ExistingSettings.EmailNotifications := Settings.EmailNotifications;
  ExistingSettings.DarkMode := Settings.DarkMode;
  ExistingSettings.AutoSave := Settings.AutoSave;
  
  FDb.SaveChanges;
end;

function TSettingsService.UpdatePassword(UserId: Integer; const Current, New, Confirm: string; out Error: string): Boolean;
var
  U: TUser;
  CurrentHash: string;
begin
  if New <> Confirm then
  begin
    Error := 'New passwords do not match';
    Exit(False);
  end;
  
  if Length(New) < 6 then
  begin
    Error := 'Password must be at least 6 characters';
    Exit(False);
  end;
  
  U := FDb.Entities<TUser>.Find(UserId);
  if U = nil then
  begin
    Error := 'User not found';
    Exit(False);
  end;
  
  // Verify current password
  CurrentHash := THashSHA2.GetHashString(Current);
  if U.PasswordHash <> CurrentHash then
  begin
    Error := 'Current password is incorrect';
    Exit(False);
  end;
  
  // Update password
  U.PasswordHash := THashSHA2.GetHashString(New);
  FDb.SaveChanges;
  
  Error := '';
  Result := True;
end;

function TSettingsService.CanDeleteAccount(UserId: Integer): Boolean;
var
  U: TUser;
begin
  U := FDb.Entities<TUser>.Find(UserId);
  if U <> nil then
    Result := not SameText(U.Role, 'Admin')
  else
    Result := False;
end;

procedure TSettingsService.DeleteAccount(UserId: Integer);
var
  U: TUser;
begin
  U := FDb.Entities<TUser>.Find(UserId);
  if (U <> nil) and (not SameText(U.Role, 'Admin')) then
  begin
    FDb.Entities<TUser>.Remove(U);
    FDb.SaveChanges;
  end;
end;

end.
