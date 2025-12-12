unit Settings.Endpoints;

interface

uses
  Dext.Web,
  System.Classes,
  System.NetEncoding,
  System.IOUtils,
  System.SysUtils;

type
  TSettingsEndpoints = class
  public
    class procedure Map(App: IApplicationBuilder);
  private
    class function GenerateSuccessNotification(const Message: string): string;
    class function GenerateErrorNotification(const Message: string): string;
  private
    class function CheckAuth(Context: IHttpContext): Boolean;
  end;

implementation

function GetFilePath(const RelativePath: string): string;
begin
  // Executable runs from Output\ directory, files are in Dext.Starter.Admin\
  Result := IncludeTrailingPathDelimiter(GetCurrentDir) + '..\Dext.Starter.Admin\' + RelativePath;
end;

{ TSettingsEndpoints }

class function TSettingsEndpoints.CheckAuth(Context: IHttpContext): Boolean;
begin
  Result := (Context.User <> nil) and 
            (Context.User.Identity <> nil) and 
            (Context.User.Identity.IsAuthenticated);
            
  if not Result then
    Context.Response.StatusCode := 401;
end;

class function TSettingsEndpoints.GenerateSuccessNotification(const Message: string): string;
begin
  Result := Format(
    '<div class="bg-green-100 border-l-4 border-green-500 text-green-700 p-4 mb-4" role="alert">' +
    '  <p class="font-bold">Success</p>' +
    '  <p>%s</p>' +
    '</div>',
    [Message]);
end;

class function TSettingsEndpoints.GenerateErrorNotification(const Message: string): string;
begin
  Result := Format(
    '<div class="bg-red-100 border-l-4 border-red-500 text-red-700 p-4 mb-4" role="alert">' +
    '  <p class="font-bold">Error</p>' +
    '  <p>%s</p>' +
    '</div>',
    [Message]);
end;

class procedure TSettingsEndpoints.Map(App: IApplicationBuilder);
begin
  // GET /settings - Return settings page
  App.MapGet('/settings',
    procedure(Context: IHttpContext)
    begin
      if not CheckAuth(Context) then Exit; // Auth Check
      
      var Html := TFile.ReadAllText(GetFilePath('wwwroot\views\settings.html'));
      var Res: IResult := TContentResult.Create(Html, 'text/html');
      Res.Execute(Context);
    end);

  // POST /settings/profile - Update profile
  App.MapPost('/settings/profile',
    procedure(Context: IHttpContext)
    var
      Notification: string;
      SettingsHtml: string;
      Body, Name, Email: string;
      Reader: TStreamReader;
    begin
      if not CheckAuth(Context) then Exit; // Auth Check
      
      // Read body stream
      if Context.Request.Body <> nil then
      begin
        Context.Request.Body.Position := 0;
        Reader := TStreamReader.Create(Context.Request.Body, TEncoding.UTF8, False);
        try
          Body := Reader.ReadToEnd;
        finally
          Reader.Free;
        end;
      end
      else
        Body := '';
      
      // Parse URL-encoded form data
      Name := '';
      Email := '';
      
      var Params := Body.Split(['&']);
      for var Param in Params do
      begin
        var Parts := Param.Split(['=']);
        if Length(Parts) = 2 then
        begin
          var Key := TNetEncoding.URL.Decode(Parts[0]);
          var Value := TNetEncoding.URL.Decode(Parts[1]);
          
          if SameText(Key, 'name') then Name := Value
          else if SameText(Key, 'email') then Email := Value;
        end;
      end;
      
      // Here you would normally update the user in the database
      // For now, we'll just acknowledge the update with the submitted name
      
      Notification := GenerateSuccessNotification(Format('Profile updated for %s (%s)!', [Name, Email]));
      SettingsHtml := TFile.ReadAllText(GetFilePath('wwwroot\views\settings.html'));
      
      // Update values in HTML to reflect changes (simple string replace for demo)
      // In a real app with a template engine, this would be cleaner
      SettingsHtml := SettingsHtml.Replace('value="Admin User"', Format('value="%s"', [Name]));
      SettingsHtml := SettingsHtml.Replace('value="admin@dext.com"', Format('value="%s"', [Email]));
      
      // Prepend notification to settings HTML
      var Html := Notification + SettingsHtml;
      
      var Res: IResult := TContentResult.Create(Html, 'text/html');
      Res.Execute(Context);
    end);

  // POST /settings/password - Change password
  App.MapPost('/settings/password',
    procedure(Context: IHttpContext)
    var
      Notification: string;
      SettingsHtml: string;
      Body, CurrentPassword, NewPassword, ConfirmPassword: string;
      Reader: TStreamReader;
    begin
      if not CheckAuth(Context) then Exit; // Auth Check
      
      // Read body stream
      if Context.Request.Body <> nil then
      begin
        Context.Request.Body.Position := 0;
        Reader := TStreamReader.Create(Context.Request.Body, TEncoding.UTF8, False);
        try
          Body := Reader.ReadToEnd;
        finally
          Reader.Free;
        end;
      end
      else
        Body := '';
      
      // Parse URL-encoded form data
      CurrentPassword := '';
      NewPassword := '';
      ConfirmPassword := '';
      
      var Params := Body.Split(['&']);
      for var Param in Params do
      begin
        var Parts := Param.Split(['=']);
        if Length(Parts) = 2 then
        begin
          var Key := TNetEncoding.URL.Decode(Parts[0]);
          var Value := TNetEncoding.URL.Decode(Parts[1]);
          
          if SameText(Key, 'current_password') then CurrentPassword := Value
          else if SameText(Key, 'new_password') then NewPassword := Value
          else if SameText(Key, 'confirm_password') then ConfirmPassword := Value;
        end;
      end;
      
      // Validation
      if NewPassword <> ConfirmPassword then
      begin
        Notification := GenerateErrorNotification('New passwords do not match');
      end
      else if Length(NewPassword) < 6 then
      begin
        Notification := GenerateErrorNotification('Password must be at least 6 characters');
      end
      else
      begin
        // Success
        Notification := GenerateSuccessNotification('Password updated successfully!');
      end;
      
      SettingsHtml := TFile.ReadAllText(GetFilePath('wwwroot\views\settings.html'));
      
      // Prepend notification to settings HTML
      var Html := Notification + SettingsHtml;
      
      var Res: IResult := TContentResult.Create(Html, 'text/html');
      Res.Execute(Context);
    end);
end;

end.
