unit Dext.Entity.Core;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Specifications.Interfaces;

type
  /// <summary>
  ///   Represents a collection of entities mapped to a database table.
  /// </summary>
  IDbSet<T: class> = interface
    ['{30000000-0000-0000-0000-000000000001}']
    
    // CRUD
    procedure Add(const AEntity: T);
    procedure Update(const AEntity: T);
    procedure Remove(const AEntity: T);
    function Find(const AId: Variant): T;
    
    // Queries via Specifications
    function List(const ASpec: ISpecification<T>): TList<T>; overload;
    function List: TList<T>; overload; // All
    function FirstOrDefault(const ASpec: ISpecification<T>): T;
    
    function Any(const ASpec: ISpecification<T>): Boolean;
    function Count(const ASpec: ISpecification<T>): Integer;
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
    
    // Note: Generic factory methods (Entities<T>) are implemented in the concrete class TDbContext
    // because Delphi interfaces have limited support for generic methods.
  end;

implementation

end.
