unit Dext.Specifications.Fluent;

interface

uses
  Dext.Specifications.Base,
  Dext.Specifications.Interfaces,
  Dext.Specifications.OrderBy;

type
  /// <summary>
  ///   Managed record for fluent specification building with automatic cleanup.
  ///   Usage: Specification.Where<TUser>(UserEntity.Age >= 18)
  /// </summary>
  TSpecificationBuilder<T: class> = record
  private
    FSpec: TSpecification<T>;
    function GetSpec: TSpecification<T>;
  public
    class operator Implicit(const Value: TSpecificationBuilder<T>): ISpecification<T>;
    
    // Fluent methods
    function Where(const ACriterion: ICriterion): TSpecificationBuilder<T>;
    function OrderBy(const APropertyName: string; AAscending: Boolean = True): TSpecificationBuilder<T>; overload;
    function OrderBy(const AOrderBy: IOrderBy): TSpecificationBuilder<T>; overload;
    function Skip(ACount: Integer): TSpecificationBuilder<T>;
    function Take(ACount: Integer): TSpecificationBuilder<T>;
    function Include(const APath: string): TSpecificationBuilder<T>;
    
    property Spec: TSpecification<T> read GetSpec;
  end;

  /// <summary>
  ///   Static factory for creating specification builders
  /// </summary>
  Specification = record
    class function Where<T: class>(const ACriterion: ICriterion): TSpecificationBuilder<T>; static;
    class function OrderBy<T: class>(const APropertyName: string; AAscending: Boolean = True): TSpecificationBuilder<T>; static;
    class function All<T: class>: TSpecificationBuilder<T>; static;
  end;

implementation

{ TSpecificationBuilder<T> }

function TSpecificationBuilder<T>.GetSpec: TSpecification<T>;
begin
  if FSpec = nil then
    FSpec := TSpecification<T>.Create;
  Result := FSpec;
end;

class operator TSpecificationBuilder<T>.Implicit(const Value: TSpecificationBuilder<T>): ISpecification<T>;
begin
  Result := Value.GetSpec as ISpecification<T>;
end;

function TSpecificationBuilder<T>.Where(const ACriterion: ICriterion): TSpecificationBuilder<T>;
begin
  GetSpec.Where(ACriterion);
  Result := Self;
end;

function TSpecificationBuilder<T>.OrderBy(const APropertyName: string; AAscending: Boolean): TSpecificationBuilder<T>;
begin
  // Create OrderBy using TOrderBy
  GetSpec.AddOrderBy(TOrderBy.Create(APropertyName, AAscending));
  Result := Self;
end;

// Overload accepting IOrderBy directly
function TSpecificationBuilder<T>.OrderBy(const AOrderBy: IOrderBy): TSpecificationBuilder<T>;
begin
  GetSpec.AddOrderBy(AOrderBy);
  Result := Self;
end;

function TSpecificationBuilder<T>.Skip(ACount: Integer): TSpecificationBuilder<T>;
begin
  GetSpec.ApplyPaging(ACount, GetSpec.GetTake);
  Result := Self;
end;

function TSpecificationBuilder<T>.Take(ACount: Integer): TSpecificationBuilder<T>;
begin
  GetSpec.ApplyPaging(GetSpec.GetSkip, ACount);
  Result := Self;
end;

function TSpecificationBuilder<T>.Include(const APath: string): TSpecificationBuilder<T>;
begin
  GetSpec.AddInclude(APath);
  Result := Self;
end;

{ Specification }

class function Specification.Where<T>(const ACriterion: ICriterion): TSpecificationBuilder<T>;
begin
  Result.Where(ACriterion);
end;

class function Specification.OrderBy<T>(const APropertyName: string; AAscending: Boolean): TSpecificationBuilder<T>;
begin
  Result.OrderBy(APropertyName, AAscending);
end;

class function Specification.All<T>: TSpecificationBuilder<T>;
begin
  // Returns empty builder (all records)
end;

end.
