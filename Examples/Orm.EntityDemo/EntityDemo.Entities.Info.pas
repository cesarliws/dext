unit EntityDemo.Entities.Info;

interface

uses
  System.TypInfo,
  Dext.Entity.TypeSystem,
  Dext.Types.Nullable,
  EntityDemo.Entities;

type
  TUserType = class(TEntityType<TUser>)
  public
    class var Id: TProp<Integer>;
    class var Name: TProp<string>;
    class var Age: TProp<Integer>;
    class var Email: TProp<string>;
    class var City: TProp<string>;
    class var AddressId: TProp<Nullable<Integer>>;
    // Navigation property
    // class var Address: TProp<TAddress>; 
    class constructor Create;
  end;

  TAddressType = class(TEntityType<TAddress>)
  public
    class var Id: TProp<Integer>;
    class var Street: TProp<string>;
    class var City: TProp<string>;
    class constructor Create;
  end;

  TProductType = class(TEntityType<TProduct>)
  public
    class var Id: TProp<Integer>;
    class var Name: TProp<string>;
    class var Price: TProp<Double>;
    class var Version: TProp<Integer>;
    class constructor Create;
  end;

  // Other entities skipped for brevity in this showcase, 
  // but would be generated similarly by a full parser.

implementation

{ TUserType }

class constructor TUserType.Create;
begin
  // We don't call inherited here because TEntityType<T>.Create is a class constructor too and runs automatically.
  // We use TypeInfo(TUser) directly to avoid dependency on execution order regarding EntityTypeInfo.
  
  Id := TPropertyInfo.Create('Id', GetPropInfo(TypeInfo(TUser), 'Id'), TypeInfo(Integer));
  Name := TPropertyInfo.Create('Name', GetPropInfo(TypeInfo(TUser), 'Name'), TypeInfo(string));
  Age := TPropertyInfo.Create('Age', GetPropInfo(TypeInfo(TUser), 'Age'), TypeInfo(Integer));
  Email := TPropertyInfo.Create('Email', GetPropInfo(TypeInfo(TUser), 'Email'), TypeInfo(string));
  City := TPropertyInfo.Create('City', GetPropInfo(TypeInfo(TUser), 'City'), TypeInfo(string));
  AddressId := TPropertyInfo.Create('AddressId', GetPropInfo(TypeInfo(TUser), 'AddressId'), TypeInfo(Nullable<Integer>));
end;

{ TAddressType }

class constructor TAddressType.Create;
begin
  Id := TPropertyInfo.Create('Id', GetPropInfo(TypeInfo(TAddress), 'Id'), TypeInfo(Integer));
  Street := TPropertyInfo.Create('Street', GetPropInfo(TypeInfo(TAddress), 'Street'), TypeInfo(string));
  City := TPropertyInfo.Create('City', GetPropInfo(TypeInfo(TAddress), 'City'), TypeInfo(string));
end;

{ TProductType }

class constructor TProductType.Create;
begin
  Id := TPropertyInfo.Create('Id', GetPropInfo(TypeInfo(TProduct), 'Id'), TypeInfo(Integer));
  Name := TPropertyInfo.Create('Name', GetPropInfo(TypeInfo(TProduct), 'Name'), TypeInfo(string));
  Price := TPropertyInfo.Create('Price', GetPropInfo(TypeInfo(TProduct), 'Price'), TypeInfo(Double));
  Version := TPropertyInfo.Create('Version', GetPropInfo(TypeInfo(TProduct), 'Version'), TypeInfo(Integer));
end;

end.
