unit Settings.Endpoints;

interface

uses
  Dext.Web,
  Admin.Utils,
  Settings.Dto,
  Dext.Web.Results, // Added
  System.Classes,
  System.NetEncoding,
  System.IOUtils,
  System.SysUtils;

type
  TSettingsEndpoints = class
  public
    class procedure Map(App: TDextAppBuilder);
  end;

implementation

uses
  AppResponseConsts;

function GenerateSuccessNotification(const Msg: string): string;
begin
  Result := Format(
    '<div class="alert alert-success alert-dismissible fade show" role="alert">' +
    '  %s' +
    '  <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>' +
    '</div>', [Msg]);
end;

function GenerateErrorNotification(const Msg: string): string;
begin
  Result := Format(
    '<div class="alert alert-danger alert-dismissible fade show" role="alert">' +
    '  %s' +
    '  <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>' +
    '</div>', [Msg]);
end;

{ TSettingsEndpoints }

class procedure TSettingsEndpoints.Map(App: TDextAppBuilder);
begin
  // GET /settings - Return settings page
  App.MapGet('/settings',
    procedure(Context: IHttpContext)
    begin
      var Html := TFile.ReadAllText(GetFilePath('wwwroot\views\settings.html'));
      var Res: IResult := Results.Html(Html);
      Res.Execute(Context);
    end);

  // POST /settings/profile - Update profile
  // Using Model Binding (JSON from HTMX json-enc)
  App.MapPost<TSettingsProfileDto, IHttpContext, IResult>('/settings/profile',
    function(Dto: TSettingsProfileDto; Context: IHttpContext): IResult
    var
      Notification: string;
      SettingsHtml: string;
    begin
      // Logic uses Dto fields directly
      
      Notification := GenerateSuccessNotification(Format('Profile updated for %s (%s)!', [Dto.Name, Dto.Email]));
      SettingsHtml := TFile.ReadAllText(GetFilePath('wwwroot\views\settings.html'));
      SettingsHtml := SettingsHtml.Replace('value="Admin User"', Format('value="%s"', [Dto.Name]));
      SettingsHtml := SettingsHtml.Replace('value="admin@dext.com"', Format('value="%s"', [Dto.Email]));
      
      var Html := Notification + SettingsHtml;
      Result := Results.Html(Html);
      
      // Send HTMX trigger to update UI if needed, or just return HTML is fine here
    end);

  // POST /settings/password - Change password
  // Using Model Binding
  App.MapPost<TSettingsPasswordDto, IHttpContext, IResult>('/settings/password',
    function(Dto: TSettingsPasswordDto; Context: IHttpContext): IResult
    var
      Notification: string;
      SettingsHtml: string;
    begin
      if Dto.NewPassword <> Dto.ConfirmPassword then
        Notification := GenerateErrorNotification('New passwords do not match')
      else if Length(Dto.NewPassword) < 6 then
        Notification := GenerateErrorNotification('Password must be at least 6 characters')
      else
        Notification := GenerateSuccessNotification('Password updated successfully!');
      
      SettingsHtml := TFile.ReadAllText(GetFilePath('wwwroot\views\settings.html'));
      var Html := Notification + SettingsHtml;
      Result := Results.Html(Html);
    end);
end;

end.
