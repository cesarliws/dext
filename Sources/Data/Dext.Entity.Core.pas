{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.Core;

interface

uses
  Dext.Collections.Base,
  Dext.Collections,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Collections.Dict,
  Dext.Entity.TypeSystem,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Naming,
  Dext.Entity.Query,
  Dext.Core.SmartTypes, // Add SmartTypes unit
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types,
  Dext.MultiTenancy,
  Dext.Threading.Async,
  Dext.Entity.Mapping;

type
  EOptimisticConcurrencyException = class(Exception);

  TEntityState = (esDetached, esUnchanged, esAdded, esDeleted, esModified);

  /// <summary>
  ///   Tracks the state of entities in the context.
  /// </summary>
  IChangeTracker = interface
    ['{954BAFF5-3022-4AB8-AE14-A111295B3903}']
    procedure Track(const AEntity: TObject; AState: TEntityState);
    procedure Remove(const AEntity: TObject);
    function GetState(const AEntity: TObject): TEntityState;
    function HasChanges: Boolean;
    procedure AcceptAllChanges;
    procedure Clear;
    function GetTrackedEntities: IDictionary<TObject, TEntityState>;
  end;

  /// <summary>
  ///   Non-generic base interface for DbSets.
  ///   Allows access to DbSet operations without knowing the generic type at compile time.
  /// </summary>
  IDbSet = interface
    ['{CC8B4D83-96E0-42F7-9B33-D8DD06919316}']
    function FindObject(const AId: Variant): TObject; overload;
    function FindObject(const AId: Integer): TObject; overload;
    function Add(const AEntity: TObject): IDbSet;
    function GetTableName: string;
    function GetEntityType: PTypeInfo;
    function GenerateCreateTableScript: string;
    procedure Clear;
    procedure DetachAll;
    procedure Detach(const AEntity: TObject);
    
    // Non-generic query support
    function ListObjects(const AExpression: IExpression): IList<TObject>;

    // Tracking Methods (Consistent with IDbSet<T>)
    procedure Update(const AEntity: TObject);
    procedure Remove(const AEntity: TObject);
    
    // Internal Persistence Methods (called by SaveChanges)
    procedure PersistAdd(const AEntity: TObject);
    procedure PersistAddRange(const AEntities: TArray<TObject>);
    procedure PersistUpdate(const AEntity: TObject);
    procedure PersistRemove(const AEntity: TObject);
    
    function GetEntityId(const AEntity: TObject): string;
    
    // Many-to-Many link management (non-generic versions for TTrackingList)
    procedure LinkManyToMany(const AEntity: TObject; const APropertyName: string; const ARelatedEntity: TObject);
    procedure UnlinkManyToMany(const AEntity: TObject; const APropertyName: string; const ARelatedEntity: TObject);
    
    property EntityType: PTypeInfo read GetEntityType;
  end;

  /// <summary>
  ///   Represents a collection of entities mapped to a database table.
  /// </summary>
  IDbSet<T: class> = interface(IDbSet)
    // CRUD
    function Add(const AEntity: T): IDbSet<T>; overload;
    function Add(const ABuilder: TFunc<IEntityBuilder<T>, T>): IDbSet<T>; overload;
    function Update(const AEntity: T): IDbSet<T>;
    function Remove(const AEntity: T): IDbSet<T>;
    function Detach(const AEntity: T): IDbSet<T>; overload;
    function GetItem(Index: Integer): T;

    property Items[Index: Integer]: T read GetItem; default;

    // Bulk Operations
    procedure AddRange(const AEntities: TArray<T>); overload;
    procedure AddRange(const AEntities: IEnumerable<T>); overload;

    procedure UpdateRange(const AEntities: TArray<T>); overload;
    procedure UpdateRange(const AEntities: IEnumerable<T>); overload;
    
    procedure RemoveRange(const AEntities: TArray<T>); overload;
    procedure RemoveRange(const AEntities: IEnumerable<T>); overload;

    // Queries via Specifications
    function Find(const AId: Variant): T; overload;
    function Find(const AId: Integer): T; overload;
    function Find(const AId: array of Integer): T; overload;
    function Find(const AId: array of Variant): T; overload;

    function ToList: IList<T>; overload;
    function ToList(const ASpec: ISpecification<T>): IList<T>;  overload;
    function ToListAsync: TAsyncBuilder<IList<T>>;

    // Inline Queries (aceita IExpression diretamente)
    function ToList(const AExpression: IExpression): IList<T>; overload;
    function FirstOrDefault(const AExpression: IExpression): T; overload;
    function FirstOrDefault(const ASpec: ISpecification<T>): T; overload;
    function Any(const AExpression: IExpression): Boolean; overload;
    function Count(const AExpression: IExpression): Integer; overload;
    function Count(const ASpec: ISpecification<T>): Integer; overload;
    function Any(const ASpec: ISpecification<T>): Boolean; overload;
    
    // Smart Properties Support
    function Where(const APredicate: TQueryPredicate<T>): TFluentQuery<T>; overload;
    function Where(const AValue: BooleanExpression): TFluentQuery<T>; overload;
    function Where(const AExpression: TFluentExpression): TFluentQuery<T>; overload;
    function Where(const AExpression: IExpression): TFluentQuery<T>; overload;
    
    /// <summary>
    ///  Creates a LINQ query based on a raw SQL query.
    ///  If the SQL is a stored procedure, you cannot compose over it (Where, OrderBy won't work).
    ///  If the SQL is a SELECT statement, depending on the provider, you might be able to compose.
    ///  Parameter array is positional: first value binds the first :placeholder in the SQL (e.g. PostgreSQL
    ///  :UserId, :TenantId), matching FireDAC parameter order.
    /// </summary>
    function FromSql(const ASql: string; const AParams: array of TValue): TFluentQuery<T>; overload;
    function FromSql(const ASql: string): TFluentQuery<T>; overload;

    // Lazy Queries (Deferred Execution) - Returns TFluentQuery<T>
    /// <summary>
    ///   Returns a lazy query that executes only when enumerated.
    ///   Call .ToList() to force execution and materialize results.
    /// </summary>
    function Query(const ASpec: ISpecification<T>): TFluentQuery<T>; overload;
    function Query(const AExpression: IExpression): TFluentQuery<T>; overload;
    function QueryAll: TFluentQuery<T>;
    
    /// <summary>
    ///   Returns a query configured to not track entities (read-only).
    /// </summary>
    function AsNoTracking: TFluentQuery<T>;

    // Soft Delete Control
    function IgnoreQueryFilters: IDbSet<T>;
    function OnlyDeleted: IDbSet<T>;
    function HardDelete(const AEntity: T): IDbSet<T>;
    function Restore(const AEntity: T): IDbSet<T>;

    // Offline Locking
    function TryLock(const AEntity: T; const AToken: string; ADurationMinutes: Integer = 30): Boolean;
    function Unlock(const AEntity: T): Boolean;

    // Many-to-Many Direct Management
    procedure LinkManyToMany(const AEntity: T; const APropertyName: string; const ARelatedEntity: TObject);
    procedure UnlinkManyToMany(const AEntity: T; const APropertyName: string; const ARelatedEntity: TObject);
    procedure SyncManyToMany(const AEntity: T; const APropertyName: string; const ARelatedEntities: TArray<TObject>);

    /// <summary>
    ///   Returns a streaming iterator that reuses a single object instance (Flyweight pattern).
    ///   Perfect for high-performance view rendering.
    /// </summary>
    function RequestStreamingIterator(const ASpec: ISpecification<T>): IEnumerator<T>;
  end;

  ICollectionEntry = interface
    ['{A1B2C3D4-E5F6-4789-0123-456789ABCDEF}']
    procedure Load;
  end;

  IReferenceEntry = interface
    ['{B2C3D4E5-F6A7-4890-1234-567890BCDEFF}']
    procedure Load;
  end;

  IPropertyEntry = interface
    ['{D4E5F6A7-B8C9-4A12-3456-789012DEF012}']
    function GetCurrentValue: TValue;
    procedure SetCurrentValue(const AValue: TValue);
    function GetIsModified: Boolean;
    procedure SetIsModified(const AValue: Boolean);
    property CurrentValue: TValue read GetCurrentValue write SetCurrentValue;
    property IsModified: Boolean read GetIsModified write SetIsModified;
  end;

  IEntityEntry = interface
    ['{C3D4E5F6-A7B8-4901-2345-678901CDEF01}']
    function Collection(const APropName: string): ICollectionEntry;
    function Reference(const APropName: string): IReferenceEntry;
    function Member(const APropName: string): IPropertyEntry;
  end;

  /// <summary>
  ///   Represents a session with the database.
  /// </summary>
  IDbContext = interface
    ['{631803BB-AEDD-4453-B2CC-D44C7AFDD9F1}']
    function Connection: IDbConnection;
    function Dialect: ISQLDialect;
    function NamingStrategy: INamingStrategy;
    
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
    ///   Returns True if the schema was created, False if it already existed.
    /// </summary>
    function EnsureCreated: Boolean;

    /// <summary>
    ///   Saves all changes made in this context to the database.
    /// </summary>
    function SaveChanges: Integer;
    function SaveChangesAsync: TAsyncBuilder<Integer>;

    /// <summary>
    ///   Clears the ChangeTracker and IdentityMap of all DbSets.
    ///   Detaches all entities.
    /// </summary>
    procedure Clear;

    /// <summary>
    ///   Detaches all entities from the context without destroying them.
    ///   The caller becomes responsible for freeing the entities.
    /// </summary>
    procedure DetachAll;

    /// <summary>
    ///   Detaches a specific entity from the context.
    /// </summary>
    procedure Detach(const AEntity: TObject);

    /// <summary>
    ///   Executes a stored procedure and maps output parameters and return values
    ///   back to the provided DTO object using [DbParam] attributes.
    /// </summary>
    procedure ExecuteProcedure(const ADto: TObject);

    /// <summary>
    ///   Access the Change Tracker.
    /// </summary>
    function ChangeTracker: IChangeTracker;
    
    /// <summary>
    ///   Retrieves the mapping object for a specific type (TEntityMap).
    ///   Returns nil if no mapping is defined.
    /// </summary>
    function GetMapping(AType: PTypeInfo): TObject;
    
    function Entry(const AEntity: TObject): IEntityEntry;
    
    /// <summary>
    ///  Tracks internal framework objects (like proxy managers) that need to be
    ///  freed when the context is destroyed.
    /// </summary>
    procedure TrackProxy(const AProxy: TObject);
    
    // Tenancy
    function GetTenantProvider: ITenantProvider;
    property TenantProvider: ITenantProvider read GetTenantProvider;

    function GetModelBuilder: TModelBuilder;
    property ModelBuilder: TModelBuilder read GetModelBuilder;

    procedure SetOnLog(const AValue: TProc<string>);
    function GetOnLog: TProc<string>;
    property OnLog: TProc<string> read GetOnLog write SetOnLog;
  end;

/// <summary>
///   Unwraps Nullable<T> values and validates if FK is valid (non-zero for integers, non-empty for strings)
/// </summary>
function TryUnwrapAndValidateFK(var AValue: TValue; AContext: TRttiContext): Boolean;

implementation

function TryUnwrapAndValidateFK(var AValue: TValue; AContext: TRttiContext): Boolean;
var
  RType: TRttiType;
  TypeName: string;
  Fields: TArray<TRttiField>;
  HasValueField, ValueField: TRttiField;
  HasValue: Boolean;
  Instance: Pointer;
begin
  Result := False;
  
  // Handle Nullable<T> unwrapping
  if AValue.Kind = tkRecord then
  begin
    RType := AContext.GetType(AValue.TypeInfo);
    if RType <> nil then
    begin
      TypeName := RType.Name;
      
      // Check if it's a Nullable<T> by name
      if TypeName.StartsWith('Nullable<') or TypeName.StartsWith('TNullable') then
      begin
        // Access fields directly since GetProperty won't work for generic records
        Fields := RType.GetFields;
        HasValueField := nil;
        ValueField := nil;
        
        // Find fHasValue and fValue fields
        for var Field in Fields do
        begin
          if Field.Name.ToLower.Contains('hasvalue') then
            HasValueField := Field
          else if Field.Name.ToLower = 'fvalue' then
            ValueField := Field;
        end;
        
        if (HasValueField <> nil) and (ValueField <> nil) then
        begin
          Instance := AValue.GetReferenceToRawData;
          
          // Check HasValue - it can be a string (Spring4D) or Boolean
          var HasValueVal := HasValueField.GetValue(Instance);
          if HasValueVal.Kind = tkUString then
            HasValue := HasValueVal.AsString <> ''
          else if HasValueVal.Kind = tkEnumeration then
            HasValue := HasValueVal.AsBoolean
          else
            HasValue := False;
            
          if not HasValue then Exit; // Null, nothing to load
          
          // Get the actual value
          AValue := ValueField.GetValue(Instance);
        end
        else
          Exit; // Couldn't find fields, treat as invalid
      end;
    end;
  end;

  if AValue.IsEmpty then Exit;

  // Validate based on type
  if AValue.Kind in [tkInteger, tkInt64] then
    Result := AValue.AsInt64 <> 0
  else if AValue.Kind in [tkString, tkUString, tkWString, tkLString] then
    Result := AValue.AsString <> ''
  else
    Result := True; // For other types like GUID, assume valid if not empty
end;

end.

