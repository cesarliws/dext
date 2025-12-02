unit Dext.Entity.Core;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Query,
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces;

type
  EOptimisticConcurrencyException = class(Exception);

  TEntityState = (esDetached, esUnchanged, esAdded, esDeleted, esModified);

  /// <summary>
  ///   Tracks the state of entities in the context.
  /// </summary>
  IChangeTracker = interface
    ['{30000000-0000-0000-0000-000000000003}']
    procedure Track(const AEntity: TObject; AState: TEntityState);
    function GetState(const AEntity: TObject): TEntityState;
    function HasChanges: Boolean;
    procedure AcceptAllChanges;
    procedure Clear;
    function GetTrackedEntities: TEnumerable<TPair<TObject, TEntityState>>;
  end;

  /// <summary>
  ///   Non-generic base interface for DbSets.
  ///   Allows access to DbSet operations without knowing the generic type at compile time.
  /// </summary>
  IDbSet = interface
    ['{30000000-0000-0000-0000-000000000000}']
    function FindObject(const AId: Variant): TObject;
    procedure Add(const AEntity: TObject);
    function GetTableName: string;
    function GenerateCreateTableScript: string;
    procedure Clear;
    
    // Non-generic query support
    function ListObjects(const AExpression: IExpression): TList<TObject>;
    
    // Internal Persistence Methods (called by SaveChanges)
    procedure PersistAdd(const AEntity: TObject);
    procedure PersistUpdate(const AEntity: TObject);
    procedure PersistRemove(const AEntity: TObject);
    
    function GetEntityId(const AEntity: TObject): string;
  end;

  /// <summary>
  ///   Represents a collection of entities mapped to a database table.
  /// </summary>
  IDbSet<T: class> = interface(IDbSet)
    ['{30000000-0000-0000-0000-000000000001}']
    
    // CRUD
    procedure Add(const AEntity: T);
    procedure Update(const AEntity: T);
    procedure Remove(const AEntity: T);
    function Find(const AId: Variant): T; overload;
    function Find(const AId: array of Integer): T; overload;

    // Bulk Operations
    procedure AddRange(const AEntities: TArray<T>); overload;
    procedure AddRange(const AEntities: TEnumerable<T>); overload;
    
    procedure UpdateRange(const AEntities: TArray<T>); overload;
    procedure UpdateRange(const AEntities: TEnumerable<T>); overload;
    
    procedure RemoveRange(const AEntities: TArray<T>); overload;
    procedure RemoveRange(const AEntities: TEnumerable<T>); overload;

    // Queries via Specifications
    function List: TList<T>; overload;
    function List(const ASpec: ISpecification<T>): TList<T>;  overload;

    // Inline Queries (aceita IExpression diretamente)
    function List(const AExpression: IExpression): TList<T>; overload;
    function FirstOrDefault(const AExpression: IExpression): T; overload;
    function Any(const AExpression: IExpression): Boolean; overload;
    function Count(const AExpression: IExpression): Integer; overload;
    
    // Lazy Queries (Deferred Execution) - Returns TFluentQuery<T>
    /// <summary>
    ///   Returns a lazy query that executes only when enumerated.
    ///   Call .ToList() to force execution and materialize results.
    /// </summary>
    function Query(const ASpec: ISpecification<T>): TFluentQuery<T>; overload;
    function Query(const AExpression: IExpression): TFluentQuery<T>; overload;
    function QueryAll: TFluentQuery<T>;
  end;

  ICollectionEntry = interface
    ['{A1B2C3D4-E5F6-4789-0123-456789ABCDEF}']
    procedure Load;
  end;

  IReferenceEntry = interface
    ['{B2C3D4E5-F6A7-4890-1234-567890BCDEFF}']
    procedure Load;
  end;

  IEntityEntry = interface
    ['{C3D4E5F6-A7B8-4901-2345-678901CDEF01}']
    function Collection(const APropName: string): ICollectionEntry;
    function Reference(const APropName: string): IReferenceEntry;
  end;

  /// <summary>
  ///   Represents a session with the database.
  /// </summary>
  IDbContext = interface
    ['{30000000-0000-0000-0000-000000000002}']
    function Connection: IDbConnection;
    function Dialect: ISQLDialect;
    
    // Transaction Management
    procedure BeginTransaction;
    procedure Commit;
    procedure Rollback;
    function InTransaction: Boolean;
    
    /// <summary>
    ///   Get a non-generic DbSet for the specified entity type.
    /// </summary>
    function DataSet(AEntityType: PTypeInfo): IDbSet;
    
    /// <summary>
    ///   Ensures that the database schema exists.
    ///   Creates tables for all registered entities if they don't exist.
    /// </summary>
    procedure EnsureCreated;

    /// <summary>
    ///   Saves all changes made in this context to the database.
    /// </summary>
    function SaveChanges: Integer;

    /// <summary>
    ///   Clears the ChangeTracker and IdentityMap of all DbSets.
    ///   Detaches all entities.
    /// </summary>
    procedure Clear;

    /// <summary>
    ///   Access the Change Tracker.
    /// </summary>
    function ChangeTracker: IChangeTracker;
    
    function Entry(const AEntity: TObject): IEntityEntry;
  end;

implementation

end.
