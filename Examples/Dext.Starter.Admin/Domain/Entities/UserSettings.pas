unit UserSettings;

interface

uses
  Dext.Persistence;

type
  [Table('UserSettings')]
  TUserSettings = class
  private
    FId: Integer;
    FUserId: Integer;
    FEmailNotifications: Boolean;
    FDarkMode: Boolean;
    FAutoSave: Boolean;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    [Column('user_id')]
    property UserId: Integer read FUserId write FUserId;
    
    [Column('email_notifications')]
    property EmailNotifications: Boolean read FEmailNotifications write FEmailNotifications;
    
    [Column('dark_mode')]
    property DarkMode: Boolean read FDarkMode write FDarkMode;
    
    [Column('auto_save')]
    property AutoSave: Boolean read FAutoSave write FAutoSave;
  end;

implementation

end.
