unit User;

interface

uses
  Dext.Entity; // Correct unit

type
  [Table('AppUsers')]
  TUser = class
  private
    FId: Integer;
    FUsername: string;
    FPasswordHash: string;
    FRole: string;
  public
    [PK, AutoInc] // Correct attributes based on EntityDemo
    property Id: Integer read FId write FId;
    
    [Column('username')] // Best practice
    property Username: string read FUsername write FUsername;
    
    [Column('password_hash')]
    property PasswordHash: string read FPasswordHash write FPasswordHash; 
    
    [Column('role')]
    property Role: string read FRole write FRole; 
  end;

implementation

end.
