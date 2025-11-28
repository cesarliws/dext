unit Dext.Specifications.Criteria;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types;

type
  /// <summary>
  ///   Helper record to build criteria expressions fluently.
  ///   Usage: Prop('Age') > 18
  /// </summary>
  TProp = record
  private
    type
      /// <summary>
      ///   Represents an intermediate expression in the criteria tree.
      ///   Has implicit conversion to ICriterion.
      /// </summary>
      TExpr = record
      private
        FCriterion: ICriterion;
      public
        class operator Implicit(const Value: ICriterion): TExpr;
        class operator Implicit(const Value: TExpr): ICriterion;
        
        // Logical Operators (AND, OR, NOT)
        class operator LogicalAnd(const Left, Right: TExpr): TExpr;
        class operator LogicalOr(const Left, Right: TExpr): TExpr;
        class operator LogicalNot(const Value: TExpr): TExpr;
      end;
      
    var
      FName: string;
      
  public
    constructor Create(const AName: string);
    
    // Comparison Operators
    class operator Equal(const Left: TProp; const Right: TValue): TExpr;
    class operator NotEqual(const Left: TProp; const Right: TValue): TExpr;
    class operator GreaterThan(const Left: TProp; const Right: TValue): TExpr;
    class operator GreaterThanOrEqual(const Left: TProp; const Right: TValue): TExpr;
    class operator LessThan(const Left: TProp; const Right: TValue): TExpr;
    class operator LessThanOrEqual(const Left: TProp; const Right: TValue): TExpr;
    
    // Special Methods (Like, In, etc)
    function Like(const Pattern: string): ICriterion;
    function &In(const Values: TArray<string>): ICriterion; overload;
    function &In(const Values: TArray<Integer>): ICriterion; overload;
    function IsNull: ICriterion;
    function IsNotNull: ICriterion;
  end;

  /// <summary>
  ///   Global helper to create a property expression.
  /// </summary>
  function Prop(const AName: string): TProp;

implementation

function Prop(const AName: string): TProp;
begin
  Result := TProp.Create(AName);
end;

{ TProp.TExpr }

class operator TProp.TExpr.Implicit(const Value: ICriterion): TExpr;
begin
  Result.FCriterion := Value;
end;

class operator TProp.TExpr.Implicit(const Value: TExpr): ICriterion;
begin
  Result := Value.FCriterion;
end;

class operator TProp.TExpr.LogicalAnd(const Left, Right: TExpr): TExpr;
begin
  Result.FCriterion := TLogicalCriterion.Create(Left.FCriterion, Right.FCriterion, loAnd);
end;

class operator TProp.TExpr.LogicalOr(const Left, Right: TExpr): TExpr;
begin
  Result.FCriterion := TLogicalCriterion.Create(Left.FCriterion, Right.FCriterion, loOr);
end;

class operator TProp.TExpr.LogicalNot(const Value: TExpr): TExpr;
begin
  Result.FCriterion := TUnaryCriterion.Create(Value.FCriterion);
end;

{ TProp }

constructor TProp.Create(const AName: string);
begin
  FName := AName;
end;

class operator TProp.Equal(const Left: TProp; const Right: TValue): TExpr;
begin
  Result.FCriterion := TBinaryCriterion.Create(Left.FName, boEqual, Right);
end;

class operator TProp.NotEqual(const Left: TProp; const Right: TValue): TExpr;
begin
  Result.FCriterion := TBinaryCriterion.Create(Left.FName, boNotEqual, Right);
end;

class operator TProp.GreaterThan(const Left: TProp; const Right: TValue): TExpr;
begin
  Result.FCriterion := TBinaryCriterion.Create(Left.FName, boGreaterThan, Right);
end;

class operator TProp.GreaterThanOrEqual(const Left: TProp; const Right: TValue): TExpr;
begin
  Result.FCriterion := TBinaryCriterion.Create(Left.FName, boGreaterThanOrEqual, Right);
end;

class operator TProp.LessThan(const Left: TProp; const Right: TValue): TExpr;
begin
  Result.FCriterion := TBinaryCriterion.Create(Left.FName, boLessThan, Right);
end;

class operator TProp.LessThanOrEqual(const Left: TProp; const Right: TValue): TExpr;
begin
  Result.FCriterion := TBinaryCriterion.Create(Left.FName, boLessThanOrEqual, Right);
end;

function TProp.Like(const Pattern: string): ICriterion;
begin
  Result := TBinaryCriterion.Create(FName, boLike, Pattern);
end;

function TProp.&In(const Values: TArray<string>): ICriterion;
var
  Val: TValue;
begin
  Val := TValue.From<TArray<string>>(Values);
  Result := TBinaryCriterion.Create(FName, boIn, Val);
end;

function TProp.&In(const Values: TArray<Integer>): ICriterion;
var
  Val: TValue;
begin
  Val := TValue.From<TArray<Integer>>(Values);
  Result := TBinaryCriterion.Create(FName, boIn, Val);
end;

function TProp.IsNull: ICriterion;
begin
  Result := TUnaryCriterion.Create(FName, uoIsNull);
end;

function TProp.IsNotNull: ICriterion;
begin
  Result := TUnaryCriterion.Create(FName, uoIsNotNull);
end;

end.
