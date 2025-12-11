unit EntityDemo.Tests.FluentMappingSyntax;

interface

uses
  Dext.Entity,
  Dext.Entity.Mapping,
  System.SysUtils;

type
  // Sample Entity for Syntax Check
  TSyntaxUser = class
  private
    FId: Integer;
    FName: string;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

  // This procedure mimics the generated code structure
  procedure RegisterMappings(ModelBuilder: TModelBuilder);

implementation

procedure RegisterMappings(ModelBuilder: TModelBuilder);
begin
  // Verify Fluent API Syntax
  ModelBuilder.Entity<TSyntaxUser>
    .Table('syntax_users')
    .HasKey('Id')
    .Prop('Name').Column('user_name').IsRequired.MaxLength(100)
    .Prop('Id').IsAutoInc;
end;

end.
