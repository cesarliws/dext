unit EntityDemo.Entities;

interface

uses
  System.Generics.Collections,
  Dext.Entity.Attributes,
  Dext.Specifications.Base,
  Dext.Specifications.Expression,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types;

type
  TUser = class; // Forward declaration

  [Table('addresses')]
  TAddress = class
  private
    FId: Integer;
    FStreet: string;
    FCity: string;
    FUsers: TList<TUser>;
  public
    constructor Create;
    destructor Destroy; override;

    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Street: string read FStreet write FStreet;
    property City: string read FCity write FCity;
    
    property Users: TList<TUser> read FUsers;
  end;

  [Table('users')]
  TUser = class
  private
    FId: Integer;
    FName: string;
    FAge: Integer;
    FEmail: string;
    FCity: string;
    FAddressId: Integer;
    FAddress: TAddress;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;

    [Column('full_name')]
    property Name: string read FName write FName;

    property Age: Integer read FAge write FAge;
    property Email: string read FEmail write FEmail;
    property City: string read FCity write FCity;
    
    [Column('address_id')]
    property AddressId: Integer read FAddressId write FAddressId;

    [ForeignKey('AddressId', caCascade)]  // CASCADE on delete
    property Address: TAddress read FAddress write FAddress;
  end;

  [Table('order_items')]
  TOrderItem = class
  private
    FOrderId: Integer;
    FProductId: Integer;
    FQuantity: Integer;
    FPrice: Double;
  public
    [PK, Column('order_id')]
    property OrderId: Integer read FOrderId write FOrderId;

    [PK,Column('product_id')]
    property ProductId: Integer read FProductId write FProductId;

    property Quantity: Integer read FQuantity write FQuantity;
    property Price: Double read FPrice write FPrice;
  end;

  [Table('products')]
  TProduct = class
  private
    FId: Integer;
    FName: string;
    FPrice: Double;
    FVersion: Integer;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Price: Double read FPrice write FPrice;
    
    [Version]
    property Version: Integer read FVersion write FVersion;
  end;

  // 🧬 Metadata Implementation (TypeOf)
  UserEntity = class
  public
    class var Id: TProperty;
    class var Name: TProperty;
    class var Age: TProperty;
    class var Email: TProperty;
    class var City: TProperty;
    class var AddressId: TProperty;
    class var Address: TProperty;

    class constructor Create;
  end;

  // Specification using Metadata
  TAdultUsersSpec = class(TSpecification<TUser>)
  public
    constructor Create; override;
  end;

implementation

{ TAddress }

constructor TAddress.Create;
begin
  FUsers := TList<TUser>.Create;
end;

destructor TAddress.Destroy;
begin
  FUsers.Free;
  inherited;
end;

{ UserEntity }

class constructor UserEntity.Create;
begin
  Id := TProperty.Create('Id');
  Name := TProperty.Create('full_name'); // Use column name from [Column('full_name')]
  Age := TProperty.Create('Age');
  Email := TProperty.Create('Email');
  City := TProperty.Create('City');
  AddressId := TProperty.Create('AddressId');
  Address := TProperty.Create('Address');
end;

{ TAdultUsersSpec }

constructor TAdultUsersSpec.Create;
begin
  inherited Create;
  // Now we can use the typed metadata!
  Where(UserEntity.Age >= 18);
end;

end.
