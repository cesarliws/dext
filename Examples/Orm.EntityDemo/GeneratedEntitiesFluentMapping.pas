unit GeneratedEntitiesFluentMapping;

interface

uses
  Dext.Entity,
  Dext.Entity.Mapping,
  Dext.Types.Nullable,
  Dext.Types.Lazy,
  Dext.Entity,
  System.SysUtils,
  System.Classes;

type

  TAddresses = class;
  TArticles = class;
  TDocuments = class;
  TMixedKeys = class;
  TOrderItems = class;
  TProducts = class;
  TTasks = class;
  TUsers = class;
  TUsersWithProfile = class;
  TUserProfiles = class;

  TAddresses = class
  private
    FId: Nullable<Integer>;
    FStreet: string;
    FCity: string;
  public
    property Id: Nullable<Integer> read FId write FId;
    property Street: string read FStreet write FStreet;
    property City: string read FCity write FCity;
  end;

  TArticles = class
  private
    FId: Nullable<Integer>;
    FTitle: string;
    FSummary: string;
    FBody: string;
    FWordCount: Nullable<Integer>;
  public
    property Id: Nullable<Integer> read FId write FId;
    property Title: string read FTitle write FTitle;
    property Summary: string read FSummary write FSummary;
    property Body: string read FBody write FBody;
    property WordCount: Nullable<Integer> read FWordCount write FWordCount;
  end;

  TDocuments = class
  private
    FId: Nullable<Integer>;
    FTitle: string;
    FContentType: string;
    FContent: string;
    FFileSize: Nullable<Integer>;
  public
    property Id: Nullable<Integer> read FId write FId;
    property Title: string read FTitle write FTitle;
    property ContentType: string read FContentType write FContentType;
    property Content: string read FContent write FContent;
    property FileSize: Nullable<Integer> read FFileSize write FFileSize;
  end;

  TMixedKeys = class
  private
    FKey1: Nullable<Integer>;
    FKey2: string;
    FValue: string;
  public
    property Key1: Nullable<Integer> read FKey1 write FKey1;
    property Key2: string read FKey2 write FKey2;
    property Value: string read FValue write FValue;
  end;

  TOrderItems = class
  private
    FOrderId: Nullable<Integer>;
    FProductId: Nullable<Integer>;
    FQuantity: Nullable<Integer>;
    FPrice: Nullable<Double>;
  public
    property OrderId: Nullable<Integer> read FOrderId write FOrderId;
    property ProductId: Nullable<Integer> read FProductId write FProductId;
    property Quantity: Nullable<Integer> read FQuantity write FQuantity;
    property Price: Nullable<Double> read FPrice write FPrice;
  end;

  TProducts = class
  private
    FId: Nullable<Integer>;
    FName: string;
    FPrice: Nullable<Double>;
    FVersion: Nullable<Integer>;
  public
    property Id: Nullable<Integer> read FId write FId;
    property Name: string read FName write FName;
    property Price: Nullable<Double> read FPrice write FPrice;
    property Version: Nullable<Integer> read FVersion write FVersion;
  end;

  TTasks = class
  private
    FId: Nullable<Integer>;
    FTitle: string;
    FDescription: string;
    FIsCompleted: Nullable<Integer>;
    FIsDeleted: Nullable<Integer>;
  public
    property Id: Nullable<Integer> read FId write FId;
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property IsCompleted: Nullable<Integer> read FIsCompleted write FIsCompleted;
    property IsDeleted: Nullable<Integer> read FIsDeleted write FIsDeleted;
  end;

  TUsers = class
  private
    FId: Nullable<Integer>;
    FFullName: string;
    FAge: Nullable<Integer>;
    FEmail: string;
    FCity: string;
    FAddressId: Nullable<Integer>;
    FAddress: ILazy<TAddresses>;

    function GetAddress: TAddresses;
    procedure SetAddress(const Value: TAddresses);
  public
    property Id: Nullable<Integer> read FId write FId;
    property FullName: string read FFullName write FFullName;
    property Age: Nullable<Integer> read FAge write FAge;
    property Email: string read FEmail write FEmail;
    property City: string read FCity write FCity;
    property AddressId: Nullable<Integer> read FAddressId write FAddressId;
    property Address: TAddresses read GetAddress write SetAddress;
  end;

  TUsersWithProfile = class
  private
    FId: Nullable<Integer>;
    FName: string;
    FEmail: string;
    FProfileId: Nullable<Integer>;
    FProfile: ILazy<TUserProfiles>;

    function GetProfile: TUserProfiles;
    procedure SetProfile(const Value: TUserProfiles);
  public
    property Id: Nullable<Integer> read FId write FId;
    property Name: string read FName write FName;
    property Email: string read FEmail write FEmail;
    property ProfileId: Nullable<Integer> read FProfileId write FProfileId;
    property Profile: TUserProfiles read GetProfile write SetProfile;
  end;

  TUserProfiles = class
  private
    FId: Nullable<Integer>;
    FUserId: Nullable<Integer>;
    FBio: string;
    FAvatar: string;
    FPreferences: string;
  public
    property Id: Nullable<Integer> read FId write FId;
    property UserId: Nullable<Integer> read FUserId write FUserId;
    property Bio: string read FBio write FBio;
    property Avatar: string read FAvatar write FAvatar;
    property Preferences: string read FPreferences write FPreferences;
  end;

  AddressesEntity = class
  public
    class var Id: TPropExpression;
    class var Street: TPropExpression;
    class var City: TPropExpression;

    class constructor Create;
  end;

  ArticlesEntity = class
  public
    class var Id: TPropExpression;
    class var Title: TPropExpression;
    class var Summary: TPropExpression;
    class var Body: TPropExpression;
    class var WordCount: TPropExpression;

    class constructor Create;
  end;

  DocumentsEntity = class
  public
    class var Id: TPropExpression;
    class var Title: TPropExpression;
    class var ContentType: TPropExpression;
    class var Content: TPropExpression;
    class var FileSize: TPropExpression;

    class constructor Create;
  end;

  MixedKeysEntity = class
  public
    class var Key1: TPropExpression;
    class var Key2: TPropExpression;
    class var Value: TPropExpression;

    class constructor Create;
  end;

  OrderItemsEntity = class
  public
    class var OrderId: TPropExpression;
    class var ProductId: TPropExpression;
    class var Quantity: TPropExpression;
    class var Price: TPropExpression;

    class constructor Create;
  end;

  ProductsEntity = class
  public
    class var Id: TPropExpression;
    class var Name: TPropExpression;
    class var Price: TPropExpression;
    class var Version: TPropExpression;

    class constructor Create;
  end;

  TasksEntity = class
  public
    class var Id: TPropExpression;
    class var Title: TPropExpression;
    class var Description: TPropExpression;
    class var IsCompleted: TPropExpression;
    class var IsDeleted: TPropExpression;

    class constructor Create;
  end;

  UsersEntity = class
  public
    class var Id: TPropExpression;
    class var FullName: TPropExpression;
    class var Age: TPropExpression;
    class var Email: TPropExpression;
    class var City: TPropExpression;
    class var AddressId: TPropExpression;
    class var Address: TPropExpression;

    class constructor Create;
  end;

  UsersWithProfileEntity = class
  public
    class var Id: TPropExpression;
    class var Name: TPropExpression;
    class var Email: TPropExpression;
    class var ProfileId: TPropExpression;
    class var Profile: TPropExpression;

    class constructor Create;
  end;

  UserProfilesEntity = class
  public
    class var Id: TPropExpression;
    class var UserId: TPropExpression;
    class var Bio: TPropExpression;
    class var Avatar: TPropExpression;
    class var Preferences: TPropExpression;

    class constructor Create;
  end;

procedure RegisterMappings(ModelBuilder: TModelBuilder);

implementation

procedure RegisterMappings(ModelBuilder: TModelBuilder);
begin
  ModelBuilder.Entity<TAddresses>
    .Table('addresses')
    .HasKey('Id')
    ;

  ModelBuilder.Entity<TArticles>
    .Table('articles')
    .HasKey('Id')
    .Prop('WordCount').Column('word_count')
    ;

  ModelBuilder.Entity<TDocuments>
    .Table('documents')
    .HasKey('Id')
    .Prop('ContentType').Column('content_type')
    .Prop('FileSize').Column('file_size')
    ;

  ModelBuilder.Entity<TMixedKeys>
    .Table('mixed_keys')
    .HasKey('Key1')
    .Prop('Key1').Column('key_1')
    .HasKey('Key2')
    .Prop('Key2').Column('key_2')
    ;

  ModelBuilder.Entity<TOrderItems>
    .Table('order_items')
    .HasKey('OrderId')
    .Prop('OrderId').Column('order_id')
    .HasKey('ProductId')
    .Prop('ProductId').Column('product_id')
    ;

  ModelBuilder.Entity<TProducts>
    .Table('products')
    .HasKey('Id')
    ;

  ModelBuilder.Entity<TTasks>
    .Table('tasks')
    .HasKey('Id')
    .Prop('IsCompleted').Column('is_completed')
    .Prop('IsDeleted').Column('is_deleted')
    ;

  ModelBuilder.Entity<TUsers>
    .Table('users')
    .HasKey('Id')
    .Prop('FullName').Column('full_name')
    .Prop('AddressId').Column('address_id')
    .Prop('Address').HasForeignKey('address_id')
    ;

  ModelBuilder.Entity<TUsersWithProfile>
    .Table('users_with_profile')
    .HasKey('Id')
    .Prop('ProfileId').Column('profile_id')
    .Prop('Profile').HasForeignKey('profile_id')
    ;

  ModelBuilder.Entity<TUserProfiles>
    .Table('user_profiles')
    .HasKey('Id')
    .Prop('UserId').Column('user_id')
    ;

end;

class constructor AddressesEntity.Create;
begin
  Id := TPropExpression.Create('Id');
  Street := TPropExpression.Create('Street');
  City := TPropExpression.Create('City');
end;

class constructor ArticlesEntity.Create;
begin
  Id := TPropExpression.Create('Id');
  Title := TPropExpression.Create('Title');
  Summary := TPropExpression.Create('Summary');
  Body := TPropExpression.Create('Body');
  WordCount := TPropExpression.Create('WordCount');
end;

class constructor DocumentsEntity.Create;
begin
  Id := TPropExpression.Create('Id');
  Title := TPropExpression.Create('Title');
  ContentType := TPropExpression.Create('ContentType');
  Content := TPropExpression.Create('Content');
  FileSize := TPropExpression.Create('FileSize');
end;

class constructor MixedKeysEntity.Create;
begin
  Key1 := TPropExpression.Create('Key1');
  Key2 := TPropExpression.Create('Key2');
  Value := TPropExpression.Create('Value');
end;

class constructor OrderItemsEntity.Create;
begin
  OrderId := TPropExpression.Create('OrderId');
  ProductId := TPropExpression.Create('ProductId');
  Quantity := TPropExpression.Create('Quantity');
  Price := TPropExpression.Create('Price');
end;

class constructor ProductsEntity.Create;
begin
  Id := TPropExpression.Create('Id');
  Name := TPropExpression.Create('Name');
  Price := TPropExpression.Create('Price');
  Version := TPropExpression.Create('Version');
end;

class constructor TasksEntity.Create;
begin
  Id := TPropExpression.Create('Id');
  Title := TPropExpression.Create('Title');
  Description := TPropExpression.Create('Description');
  IsCompleted := TPropExpression.Create('IsCompleted');
  IsDeleted := TPropExpression.Create('IsDeleted');
end;

class constructor UsersEntity.Create;
begin
  Id := TPropExpression.Create('Id');
  FullName := TPropExpression.Create('FullName');
  Age := TPropExpression.Create('Age');
  Email := TPropExpression.Create('Email');
  City := TPropExpression.Create('City');
  AddressId := TPropExpression.Create('AddressId');
  Address := TPropExpression.Create('Address');
end;

class constructor UsersWithProfileEntity.Create;
begin
  Id := TPropExpression.Create('Id');
  Name := TPropExpression.Create('Name');
  Email := TPropExpression.Create('Email');
  ProfileId := TPropExpression.Create('ProfileId');
  Profile := TPropExpression.Create('Profile');
end;

class constructor UserProfilesEntity.Create;
begin
  Id := TPropExpression.Create('Id');
  UserId := TPropExpression.Create('UserId');
  Bio := TPropExpression.Create('Bio');
  Avatar := TPropExpression.Create('Avatar');
  Preferences := TPropExpression.Create('Preferences');
end;

function TUsers.GetAddress: TAddresses;
begin
  if FAddress <> nil then
    Result := FAddress.Value
  else
    Result := nil;
end;

procedure TUsers.SetAddress(const Value: TAddresses);
begin
  FAddress := TValueLazy<TAddresses>.Create(Value);
end;

function TUsersWithProfile.GetProfile: TUserProfiles;
begin
  if FProfile <> nil then
    Result := FProfile.Value
  else
    Result := nil;
end;

procedure TUsersWithProfile.SetProfile(const Value: TUserProfiles);
begin
  FProfile := TValueLazy<TUserProfiles>.Create(Value);
end;

end.
