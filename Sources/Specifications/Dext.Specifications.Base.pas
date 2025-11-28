unit Dext.Specifications.Base;

interface

uses
  System.Generics.Collections,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types;

type
  /// <summary>
  ///   Base class for Specifications.
  ///   Inherit from this class to define reusable query logic.
  /// </summary>
  TSpecification<T> = class(TInterfacedObject, ISpecification<T>)
  protected
    FCriteria: ICriterion;
    FIncludes: TList<string>;
    FOrderBy: TList<IOrderBy>;
    FSkip: Integer;
    FTake: Integer;
    FIsPagingEnabled: Boolean;
    
    // Fluent Builders
    procedure Where(const ACriteria: ICriterion);
    procedure AddInclude(const APath: string);
    procedure ApplyPaging(ASkip, ATake: Integer);
    
    // Implementation of ISpecification<T>
    function GetCriteria: ICriterion;
    function GetIncludes: TArray<string>;
    function GetOrderBy: TArray<IOrderBy>;
    function GetSkip: Integer;
    function GetTake: Integer;
    function IsPagingEnabled: Boolean;
  public
    constructor Create; virtual;
    destructor Destroy; override;
  end;

implementation

{ TSpecification<T> }

constructor TSpecification<T>.Create;
begin
  inherited;
  FIncludes := TList<string>.Create;
  FOrderBy := TList<IOrderBy>.Create;
  FCriteria := nil; // Empty criteria matches all
end;

destructor TSpecification<T>.Destroy;
begin
  FIncludes.Free;
  FOrderBy.Free;
  inherited;
end;

procedure TSpecification<T>.Where(const ACriteria: ICriterion);
begin
  if FCriteria = nil then
    FCriteria := ACriteria
  else
    // Combine with AND
    FCriteria := TLogicalCriterion.Create(FCriteria, ACriteria, loAnd);
end;

procedure TSpecification<T>.AddInclude(const APath: string);
begin
  FIncludes.Add(APath);
end;

procedure TSpecification<T>.ApplyPaging(ASkip, ATake: Integer);
begin
  FSkip := ASkip;
  FTake := ATake;
  FIsPagingEnabled := True;
end;

function TSpecification<T>.GetCriteria: ICriterion;
begin
  Result := FCriteria;
end;

function TSpecification<T>.GetIncludes: TArray<string>;
begin
  Result := FIncludes.ToArray;
end;

function TSpecification<T>.GetOrderBy: TArray<IOrderBy>;
begin
  Result := FOrderBy.ToArray;
end;

function TSpecification<T>.GetSkip: Integer;
begin
  Result := FSkip;
end;

function TSpecification<T>.GetTake: Integer;
begin
  Result := FTake;
end;

function TSpecification<T>.IsPagingEnabled: Boolean;
begin
  Result := FIsPagingEnabled;
end;

end.
