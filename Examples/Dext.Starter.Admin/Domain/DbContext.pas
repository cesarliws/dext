unit DbContext;

interface

uses
  Dext.Persistence,
  Dext.Entity.Mapping,  // For TModelBuilder
  User,
  UserSettings,
  Customer,
  Order;

type
  {$M+}
  TAppDbContext = class(TDbContext)
  protected
    procedure OnModelCreating(Builder: TModelBuilder); override;
  end;

implementation

{ TAppDbContext }

procedure TAppDbContext.OnModelCreating(Builder: TModelBuilder);
begin
  inherited;
  // Register all entities
  Builder.Entity<TUser>;
  Builder.Entity<TUserSettings>;
  Builder.Entity<TCustomer>;
  Builder.Entity<TOrder>;
end;

end.
