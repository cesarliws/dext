unit Dext.Persistence;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  Dext.Entity.Core,
  Dext.Entity.DbSet,
  Dext.Entity.Attributes,
  Dext.Entity.Query,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Fluent,
  Dext.Entity.Grouping,
  Dext.Entity.Joining,
  Dext.Types.Lazy;

type
  // Core Interfaces
  IDbContext = Dext.Entity.Core.IDbContext;
  IDbSet = Dext.Entity.Core.IDbSet;
  
  // Exceptions
  EOptimisticConcurrencyException = Dext.Entity.Core.EOptimisticConcurrencyException;


  IExpression = Dext.Specifications.Interfaces.IExpression;
  
  // Specification Builder Helper (Static Class)
  Specification = Dext.Specifications.Fluent.Specification;

  // Query Helpers
  TQueryGrouping = Dext.Entity.Grouping.TQuery;
  TQueryJoin = Dext.Entity.Joining.TJoining;

  // Atributes
  TableAttribute = Dext.Entity.Attributes.TableAttribute;
  ColumnAttribute = Dext.Entity.Attributes.ColumnAttribute;
  PKAttribute = Dext.Entity.Attributes.PKAttribute;
  NotMappedAttribute = Dext.Entity.Attributes.NotMappedAttribute;
  VersionAttribute = Dext.Entity.Attributes.VersionAttribute;
  ForeignKeyAttribute = Dext.Entity.Attributes.ForeignKeyAttribute;

  Lazy<T> = record
  private
    FInstance: ILazy<T>;
    function GetIsValueCreated: Boolean;
    function GetValue: T;
  public
    class function Create: Lazy<T>; overload; static;
    constructor Create(const AValueFactory: TFunc<T>); overload;
    constructor CreateFrom(const AValue: T);

    class operator Implicit(const Value: Lazy<T>): T;
    class operator Implicit(const Value: T): Lazy<T>;
    class operator Implicit(const ValueFactory: TFunc<T>): Lazy<T>;

    property IsValueCreated: Boolean read GetIsValueCreated;
    property Value: T read GetValue;
  end;


const
  caNoAction = Dext.Entity.Attributes.TCascadeAction.caNoAction;
  caCascade = Dext.Entity.Attributes.TCascadeAction.caCascade;
  caSetNull = Dext.Entity.Attributes.TCascadeAction.caSetNull;
  caRestrict = Dext.Entity.Attributes.TCascadeAction.caRestrict;

implementation

{ Lazy<T> }

class function Lazy<T>.Create: Lazy<T>;
begin
  // Default constructor returns empty/default
  Result.FInstance := TValueLazy<T>.Create(Default(T));
end;

constructor Lazy<T>.Create(const AValueFactory: TFunc<T>);
begin
  FInstance := TLazy<T>.Create(AValueFactory);
end;

constructor Lazy<T>.CreateFrom(const AValue: T);
begin
  FInstance := TValueLazy<T>.Create(AValue);
end;

function Lazy<T>.GetIsValueCreated: Boolean;
begin
  if FInstance <> nil then
    Result := FInstance.IsValueCreated
  else
    Result := False;
end;

function Lazy<T>.GetValue: T;
begin
  if FInstance <> nil then
    Result := FInstance.Value
  else
    Result := Default(T);
end;

class operator Lazy<T>.Implicit(const Value: Lazy<T>): T;
begin
  Result := Value.Value;
end;

class operator Lazy<T>.Implicit(const Value: T): Lazy<T>;
begin
  Result.CreateFrom(Value);
end;

class operator Lazy<T>.Implicit(const ValueFactory: TFunc<T>): Lazy<T>;
begin
  Result.Create(ValueFactory);
end;


end.
