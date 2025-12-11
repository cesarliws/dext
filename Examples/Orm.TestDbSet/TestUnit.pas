unit TestUnit;

interface

procedure RunTest;

implementation

uses
  System.SysUtils,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.UI.Intf,
  FireDAC.ConsoleUI.Wait,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Core,
  Dext.Entity.Drivers.FireDAC,
  Dext.Entity.DbSet,
  Dext.Entity.Dialects,
  Dext.Entity.Attributes,
  Dext.Entity;

type
  [Table('People')]
  TPerson = class
  private
    FId: Integer;
    FName: string;
    FAge: Integer;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Age: Integer read FAge write FAge;
  end;

procedure RunTest;
var
  FDConn: TFDConnection;
  Conn: IDbConnection;
  Ctx: TDbContext;
  SetPerson: IDbSet<TPerson>;
  P: TPerson;
  FoundP: TPerson;
begin
  Writeln('Starting Test...');
  
  FDConn := TFDConnection.Create(nil);
  try
    FDConn.DriverName := 'SQLite';
    FDConn.Params.Values['Database'] := ':memory:';
    FDConn.LoginPrompt := False;
    Conn := TFireDACConnection.Create(FDConn, True); 
    
    Ctx := TDbContext.Create(Conn, TSQLiteDialect.Create);
    P := nil;
    try
      Conn.Connect;
      Writeln('Connected.');
      
      SetPerson := Ctx.Entities<TPerson>;
      Ctx.EnsureCreated;
      Writeln('Table Created.');
      
      P := TPerson.Create;
      P.Name := 'John Doe';
      P.Age := 30;
      
      SetPerson.Add(P);
      Writeln('Person Added. ID: ' + IntToStr(P.Id));
      
      if P.Id = 0 then
        Writeln('ERROR: ID should be auto-incremented!');
        
      FoundP := SetPerson.Find(P.Id);
      if FoundP <> nil then
      begin
        Writeln('Person Found: ' + FoundP.Name);
        if FoundP.Name <> 'John Doe' then Writeln('ERROR: Name mismatch');
      end
      else
        Writeln('ERROR: Person not found');
        
      P.Age := 31;
      SetPerson.Update(P);
      Writeln('Person Updated.');
      
      SetPerson.Remove(P);
      Writeln('Person Removed.');
      
      FoundP := SetPerson.Find(P.Id);
      if FoundP = nil then
        Writeln('Person correctly removed (not found).')
      else
        Writeln('ERROR: Person still exists!');
        
    finally
      P.Free;
      Ctx.Free;
    end;
    
  except
    on E: Exception do
      Writeln('EXCEPTION: ' + E.ClassName + ': ' + E.Message);
  end;
end;

end.
