unit Settings.Dto;

interface

uses
  Dext.Web;

type
  TSettingsProfileDto = record
    Name: string;
    Email: string;
  end;

  TSettingsPasswordDto = record
    CurrentPassword: string;
    NewPassword: string;
    ConfirmPassword: string;
  end;
  
  TSettingsAppDto = record
    EmailNotifications: Boolean;
    DarkMode: Boolean;
    AutoSave: Boolean;
  end;

implementation

end.
