unit EntityDemo.Entities;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Dext.Persistence,
  Dext.Collections, // Add Collections
  Dext.Specifications.Base,
  Dext.Types.Nullable;

type
  TUser = class; // Forward declaration

  [Table('addresses')]
  TAddress = class
  private
    FId: Integer;
    FStreet: string;
    FCity: string;
    FUsers: Lazy<IList<TUser>>; // Changed to IList
    function GetUsers: IList<TUser>; // Changed to IList
  public
    constructor Create; virtual;
    destructor Destroy; override;
    class function NewInstance: TObject; override;

    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Street: string read FStreet write FStreet;
    property City: string read FCity write FCity;
    
    [NotMapped]
    property Users: IList<TUser> read GetUsers; // Changed to IList
  end;

  [Table('users')]
  TUser = class
  private
    FId: Integer;
    FName: string;
    FAge: Integer;
    FEmail: string;
    FCity: string;
    FAddressId: Nullable<Integer>;
    FAddress: Lazy<TAddress>;
    function GetAddress: TAddress;
    procedure SetAddress(const Value: TAddress);
  public
    constructor Create; overload;
    constructor Create(const AName: string; AAge: Integer); overload;
    destructor Destroy; override;

    [PK, AutoInc]
    property Id: Integer read FId write FId;

    [Column('full_name')]
    property Name: string read FName write FName;

    property Age: Integer read FAge write FAge;
    property Email: string read FEmail write FEmail;
    property City: string read FCity write FCity;
    
    [Column('address_id')]
    property AddressId: Nullable<Integer> read FAddressId write FAddressId;

    [ForeignKey('AddressId', caCascade), NotMapped]  // CASCADE on delete
    property Address: TAddress read GetAddress write SetAddress;
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

  [Table('mixed_keys')]
  TMixedKeyEntity = class
  private
    FKey1: Integer;
    FKey2: string;
    FValue: string;
  public
    [PK, Column('key_1')]
    property Key1: Integer read FKey1 write FKey1;

    [PK, Column('key_2')]
    property Key2: string read FKey2 write FKey2;

    property Value: string read FValue write FValue;
  end;

  // 🔬 Lazy Loading Test Entities

  /// <summary>
  ///   Entity for testing lazy loading of BLOB data (TBytes)
  ///   Use case: PDFs, images, binary files
  /// </summary>
  [Table('documents')]
  TDocument = class
  private
    FId: Integer;
    FTitle: string;
    FContentType: string;
    FContent: TBytes;
    FFileSize: Integer;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    property Title: string read FTitle write FTitle;
    
    [Column('content_type')]
    property ContentType: string read FContentType write FContentType;
    
    /// <summary>
    ///   BLOB field - lazy loaded to avoid loading large data unnecessarily
    /// </summary>
    property Content: TBytes read FContent write FContent;
    
    [Column('file_size')]
    property FileSize: Integer read FFileSize write FFileSize;
  end;

  /// <summary>
  ///   Entity for testing lazy loading of large text (TEXT/CLOB)
  ///   Use case: Articles, descriptions, HTML content
  /// </summary>
  [Table('articles')]
  TArticle = class
  private
    FId: Integer;
    FTitle: string;
    FSummary: string;
    FBody: string;
    FWordCount: Integer;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    property Title: string read FTitle write FTitle;
    
    /// <summary>
    ///   Short summary - always loaded
    /// </summary>
    property Summary: string read FSummary write FSummary;
    
    /// <summary>
    ///   Large text field - should be lazy loaded
    /// </summary>
    property Body: string read FBody write FBody;
    
    [Column('word_count')]
    property WordCount: Integer read FWordCount write FWordCount;
  end;

  /// <summary>
  ///   Entity with lazy-loaded reference (1:1)
  ///   Use case: User profile with optional detailed info
  /// </summary>
  [Table('user_profiles')]
  TUserProfile = class
  private
    FId: Integer;
    FUserId: Integer;
    FBio: string;
    FAvatar: TBytes;
    FPreferences: string; // JSON
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    [Column('user_id')]
    property UserId: Integer read FUserId write FUserId;
    
    /// <summary>
    ///   Short bio text
    /// </summary>
    property Bio: string read FBio write FBio;
    
    /// <summary>
    ///   Avatar image - BLOB, lazy loaded
    /// </summary>
    property Avatar: TBytes read FAvatar write FAvatar;
    
    /// <summary>
    ///   User preferences as JSON string
    /// </summary>
    property Preferences: string read FPreferences write FPreferences;
  end;

  /// <summary>
  ///   Extended User entity with lazy-loaded profile
  /// </summary>
  [Table('users_with_profile')]
  TUserWithProfile = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
    FProfileId: Nullable<Integer>;
    FProfile: Lazy<TUserProfile>;
    function GetProfile: TUserProfile;
    procedure SetProfile(const Value: TUserProfile);
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    property Name: string read FName write FName;
    property Email: string read FEmail write FEmail;
    
    [Column('profile_id')]
    property ProfileId: Nullable<Integer> read FProfileId write FProfileId;
    
    /// <summary>
    ///   Lazy-loaded profile reference (1:1)
    /// </summary>
    [ForeignKey('ProfileId'), NotMapped]
    property Profile: TUserProfile read GetProfile write SetProfile;
  end;

  /// <summary>
  ///   Task entity with soft delete support
  /// </summary>
  [Table('tasks'), SoftDelete('IsDeleted')]
  TTask = class
  private
    FId: Integer;
    FTitle: string;
    FDescription: string;
    FIsCompleted: Boolean;
    FIsDeleted: Boolean;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    
    [Column('is_completed')]
    property IsCompleted: Boolean read FIsCompleted write FIsCompleted;
    
    [Column('is_deleted')]
    property IsDeleted: Boolean read FIsDeleted write FIsDeleted;
  public
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Entity for testing Fluent API Soft Delete (No attribute)
  /// </summary>
  [Table('fluent_soft_delete')]
  TFluentSoftDelete = class
  private
    FId: Integer;
    FName: string;
    FIsRemoved: Boolean;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    
    // logic: IsRemoved = True (Deleted)
    property IsRemoved: Boolean read FIsRemoved write FIsRemoved;
  end;



  // 🧬 Metadata Implementation (TypeOf)
  UserEntity = class
  public
    class var Id: TPropExpression;
    class var Name: TPropExpression;
    class var Age: TPropExpression;
    class var Email: TPropExpression;
    class var City: TPropExpression;
    class var AddressId: TPropExpression;
    class var Address: TPropExpression;

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
  inherited Create;
  // Initialize FUsers with empty list
  // This is needed for manually created entities (not from DB)
  // For entities from DB, TLazyInjector will replace this with TLazyLoader
  FUsers := Lazy<IList<TUser>>.CreateFrom(TCollections.CreateObjectList<TUser>(False), True);
end;

destructor TAddress.Destroy;
begin
  // FUsers is managed. If it holds an interface, ARC handles it.
  // If lazy created a value, Lazy destructor might free it if not interface?
  // Lazy<T> implementation handles interface/object distinction usually?
  // Actually, Dext.Types.Lazy might need check.
  // Generally, if T is interface, Delphi manages it.
  inherited;
end;

class function TAddress.NewInstance: TObject;
begin
  Result := inherited NewInstance;
end;

function TAddress.GetUsers: IList<TUser>;
begin
  Result := FUsers.Value;
end;

{ TUser }

function TUser.GetAddress: TAddress;
begin
  Result := FAddress.Value;
end;

procedure TUser.SetAddress(const Value: TAddress);
begin
  // When setting manually, we wrap it in a Lazy that is already created
  FAddress := Lazy<TAddress>.CreateFrom(Value);
end;

constructor TUser.Create;
begin
  inherited Create;
end;

constructor TUser.Create(const AName: string; AAge: Integer);
begin
  Create;
  FName := AName;
  FAge := AAge;
end;

destructor TUser.Destroy;
begin
  inherited;
end;

{ UserEntity }

class constructor UserEntity.Create;
begin
  Id := TPropExpression.Create('Id');
  Name := TPropExpression.Create('full_name');
  Age := TPropExpression.Create('Age');
  Email := TPropExpression.Create('Email');
  City := TPropExpression.Create('City');
  AddressId := TPropExpression.Create('AddressId');
  Address := TPropExpression.Create('Address');
end;

{ TAdultUsersSpec }

constructor TAdultUsersSpec.Create;
begin
  inherited Create;
  Where(UserEntity.Age >= 18);
end;

{ TUserWithProfile }

function TUserWithProfile.GetProfile: TUserProfile;
begin
  Result := FProfile.Value;
end;

procedure TUserWithProfile.SetProfile(const Value: TUserProfile);
begin
  FProfile := Lazy<TUserProfile>.CreateFrom(Value);
end;

{ TTask - Soft Delete Test Entity }

// No implementation needed for TTask (simple entity)

destructor TTask.Destroy;
begin
  if Title <> '' then
    WriteLn('    🗑️ TTask Destroyed: ' + Title)
  else
    WriteLn('    🗑️ TTask Destroyed: (No Title)');
  inherited;
end;

end.
