unit Settings.Endpoints;

interface

uses
  Dext.Web,
  Settings.Dto,
  Settings.Service,
  Dext.Web.Results,
  System.SysUtils;

type
  TSettingsEndpoints = class
  public
    class procedure Map(App: TDextAppBuilder);
  end;

implementation

uses
  AppResponseConsts,
  Dext.Auth.JWT,
  Dext.Auth.Identity;

function GenerateSuccessNotification(const Msg: string): string;
begin
  Result := Format(HTML_NOTIFICATION_SUCCESS, [Msg]);
end;

function GenerateErrorNotification(const Msg: string): string;
begin
  Result := Format(HTML_NOTIFICATION_ERROR, [Msg]);
end;

// Helper to get UserId from JWT claims in context
function GetUserIdFromContext(Context: IHttpContext): Integer;
var
  Claim: TClaim;
begin
  // Get sub claim from JWT (userId stored as "sub" in our JWT)
  if Context.User <> nil then
  begin
    Claim := Context.User.FindClaim(TClaimTypes.NameIdentifier);
    Result := StrToIntDef(Claim.Value, 0);
  end
  else
    Result := 0;
end;

{ TSettingsEndpoints }

class procedure TSettingsEndpoints.Map(App: TDextAppBuilder);
begin
  // GET /settings - Return settings page with user data
  App.MapGet<ISettingsService, IHttpContext, IResult>('/settings',
    function(Service: ISettingsService; Context: IHttpContext): IResult
    var
      UserId: Integer;
      Profile: TUserProfile;
      AppSettings: TAppSettings;
      Html: string;
    begin
      UserId := GetUserIdFromContext(Context);
      Profile := Service.GetProfile(UserId);
      AppSettings := Service.GetAppSettings(UserId);
      
      Html := Results.ReadViewFile('settings.html');
      
      // Replace profile placeholders
      Html := Html.Replace('value="Admin User"', Format('value="%s"', [Profile.Name]));
      Html := Html.Replace('value="admin@dext.com"', Format('value="%s"', [Profile.Email]));
      Html := Html.Replace('value="Administrator"', Format('value="%s"', [Profile.Role]));
      
      // Replace app settings checkboxes
      if AppSettings.EmailNotifications then
        Html := Html.Replace('id="emailNotifications"', 'id="emailNotifications" checked')
      else
        Html := Html.Replace('id="emailNotifications" checked', 'id="emailNotifications"');
        
      if AppSettings.DarkMode then
        Html := Html.Replace('id="darkMode"', 'id="darkMode" checked')
      else
        Html := Html.Replace('id="darkMode" checked', 'id="darkMode"');
        
      if AppSettings.AutoSave then
        Html := Html.Replace('id="autoSave"', 'id="autoSave" checked')
      else
        Html := Html.Replace('id="autoSave" checked', 'id="autoSave"');
      
      // Hide danger zone for admin
      if not Service.CanDeleteAccount(UserId) then
        Html := Html.Replace('id="dangerZone"', 'id="dangerZone" style="display:none"');
      
      Result := Results.Html(Html);
    end);

  // POST /settings/profile - Update profile
  App.MapPost<ISettingsService, TSettingsProfileDto, IHttpContext, IResult>('/settings/profile',
    function(Service: ISettingsService; Dto: TSettingsProfileDto; Context: IHttpContext): IResult
    var
      UserId: Integer;
      Notification: string;
    begin
      UserId := GetUserIdFromContext(Context);
      Service.UpdateProfile(UserId, Dto.Name, Dto.Email);
      
      Notification := GenerateSuccessNotification(Format('Profile updated for %s!', [Dto.Name]));
      
      Context.Response.AddHeader('HX-Trigger', '{"showToast": {"message": "Profile saved!", "type": "success"}}');
      Result := Results.Html(Notification);
    end);

  // POST /settings/app - Update application settings
  App.MapPost<ISettingsService, TSettingsAppDto, IHttpContext, IResult>('/settings/app',
    function(Service: ISettingsService; Dto: TSettingsAppDto; Context: IHttpContext): IResult
    var
      UserId: Integer;
      Notification: string;
    begin
      UserId := GetUserIdFromContext(Context);
      Service.UpdateAppSettings(UserId, Dto);
      
      Notification := GenerateSuccessNotification('Application settings saved!');
      
      Context.Response.AddHeader('HX-Trigger', '{"showToast": {"message": "Settings saved!", "type": "success"}}');
      Result := Results.Html(Notification);
    end);

  // POST /settings/password - Change password
  App.MapPost<ISettingsService, TSettingsPasswordDto, IHttpContext, IResult>('/settings/password',
    function(Service: ISettingsService; Dto: TSettingsPasswordDto; Context: IHttpContext): IResult
    var
      UserId: Integer;
      Error: string;
      Notification: string;
    begin
      UserId := GetUserIdFromContext(Context);
      
      if Service.UpdatePassword(UserId, Dto.CurrentPassword, Dto.NewPassword, Dto.ConfirmPassword, Error) then
      begin
        Notification := GenerateSuccessNotification('Password updated successfully!');
        Context.Response.AddHeader('HX-Trigger', '{"showToast": {"message": "Password changed!", "type": "success"}}');
      end
      else
      begin
        Notification := GenerateErrorNotification(Error);
        Context.Response.AddHeader('HX-Trigger', '{"showToast": {"message": "' + Error + '", "type": "error"}}');
      end;
      
      Result := Results.Html(Notification);
    end);
    
  // POST /settings/delete-account - Delete account (non-admin only)
  App.MapPost<ISettingsService, IHttpContext, IResult>('/settings/delete-account',
    function(Service: ISettingsService; Context: IHttpContext): IResult
    var
      UserId: Integer;
    begin
      UserId := GetUserIdFromContext(Context);
      
      if not Service.CanDeleteAccount(UserId) then
      begin
        Context.Response.AddHeader('HX-Trigger', '{"showToast": {"message": "Admin accounts cannot be deleted", "type": "error"}}');
        Exit(Results.Html(GenerateErrorNotification('Admin accounts cannot be deleted')));
      end;
      
      Service.DeleteAccount(UserId);
      
      // Redirect to login after deletion
      Context.Response.AddHeader('HX-Redirect', '/auth/login');
      Result := Results.Ok;
    end);
end;

end.
