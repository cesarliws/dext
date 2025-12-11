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
  System.Generics.Collections,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Collections,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Entity.Naming, // Add Naming unit
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
    procedure Remove(const AEntity: TObject);
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
  end;

  /// <summary>
  ///   Represents a collection of entities mapped to a database table.
  /// </summary>
  IDbSet<T: class> = interface(IDbSet)
    // CRUD
    procedure Add(const AEntity: T);
    procedure Update(const AEntity: T);
    procedure Remove(const AEntity: T);
    procedure Detach(const AEntity: T); overload;

    // Bulk Operations
    procedure AddRange(const AEntities: TArray<T>); overload;
    procedure AddRange(const AEntities: TEnumerable<T>); overload;

    procedure UpdateRange(const AEntities: TArray<T>); overload;
    procedure UpdateRange(const AEntities: TEnumerable<T>); overload;
    
    procedure RemoveRange(const AEntities: TArray<T>); overload;
    procedure RemoveRange(const AEntities: TEnumerable<T>); overload;

    // Queries via Specifications
    function Find(const AId: Variant): T; overload;
    function Find(const AId: array of Integer): T; overload;
    function Find(const AId: array of Variant): T; overload;

    function List: IList<T>; overload;
    function List(const ASpec: ISpecification<T>): IList<T>;  overload;

    // Inline Queries (aceita IExpression diretamente)
    function List(const AExpression: IExpression): IList<T>; overload;
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
    
    /// <summary>
    ///   Returns a query configured to not track entities (read-only).
    /// </summary>
    function AsNoTracking: TFluentQuery<T>;

    // Soft Delete Control
    function IgnoreQueryFilters: IDbSet<T>;
    function OnlyDeleted: IDbSet<T>;
    procedure HardDelete(const AEntity: T);
    procedure Restore(const AEntity: T);
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
    ///   Detaches all entities from the context without destroying them.
    ///   The caller becomes responsible for freeing the entities.
    /// </summary>
    procedure DetachAll;

    /// <summary>
    ///   Detaches a specific entity from the context.
    /// </summary>
    procedure Detach(const AEntity: TObject);

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

