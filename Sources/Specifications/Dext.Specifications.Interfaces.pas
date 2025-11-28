unit Dext.Specifications.Interfaces;

interface

uses
  System.Rtti,
  System.Generics.Collections;

type
  TMatchMode = (mmExact, mmStart, mmEnd, mmAnywhere);

  /// <summary>
  ///   Represents a criterion in a query (e.g., "Age > 18").
  /// </summary>
  ICriterion = interface
    ['{10000000-0000-0000-0000-000000000001}']
    function ToString: string; // For debugging/logging
  end;

  /// <summary>
  ///   Represents an order by clause.
  /// </summary>
  IOrderBy = interface
    ['{10000000-0000-0000-0000-000000000002}']
    function GetPropertyName: string;
    function GetAscending: Boolean;
  end;

  /// <summary>
  ///   Base interface for specifications.
  ///   Encapsulates query logic for an entity type T.
  /// </summary>
  ISpecification<T> = interface
    ['{10000000-0000-0000-0000-000000000003}']
    function GetCriteria: ICriterion;
    function GetIncludes: TArray<string>;
    function GetOrderBy: TArray<IOrderBy>;
    function GetSkip: Integer;
    function GetTake: Integer;
    function IsPagingEnabled: Boolean;
  end;

  /// <summary>
  ///   Visitor interface for traversing the criteria tree.
  ///   This is used by the ORM/Repository to translate criteria to SQL.
  /// </summary>
  ICriteriaVisitor = interface
    ['{10000000-0000-0000-0000-000000000004}']
    procedure Visit(const ACriterion: ICriterion);
  end;

implementation

end.
