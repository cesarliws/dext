unit Dext.Specifications.Types;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Specifications.Interfaces;

type
  TAbstractCriterion = class(TInterfacedObject, ICriterion)
  public
    function ToString: string; override;
  end;

  /// <summary>
  ///   Represents a binary operator (Left Op Right).
  ///   e.g., Age > 18, Name = 'John'
  /// </summary>
  TBinaryOperator = (boEqual, boNotEqual, boGreaterThan, boGreaterThanOrEqual, 
    boLessThan, boLessThanOrEqual, boLike, boNotLike, boIn, boNotIn);

  TBinaryCriterion = class(TAbstractCriterion)
  private
    FPropertyName: string;
    FValue: TValue;
    FOperator: TBinaryOperator;
  public
    constructor Create(const APropertyName: string; AOperator: TBinaryOperator; const AValue: TValue);
    property PropertyName: string read FPropertyName;
    property Value: TValue read FValue;
    property Operator: TBinaryOperator read FOperator;
    function ToString: string; override;
  end;

  /// <summary>
  ///   Represents a logical operation (AND, OR).
  /// </summary>
  TLogicalOperator = (loAnd, loOr);

  TLogicalCriterion = class(TAbstractCriterion)
  private
    FLeft: ICriterion;
    FRight: ICriterion;
    FOperator: TLogicalOperator;
  public
    constructor Create(const ALeft, ARight: ICriterion; AOperator: TLogicalOperator);
    property Left: ICriterion read FLeft;
    property Right: ICriterion read FRight;
    property Operator: TLogicalOperator read FOperator;
    function ToString: string; override;
  end;

  /// <summary>
  ///   Represents a unary operation (NOT, IsNull, IsNotNull).
  /// </summary>
  TUnaryOperator = (uoNot, uoIsNull, uoIsNotNull);

  TUnaryCriterion = class(TAbstractCriterion)
  private
    FCriterion: ICriterion; // For NOT
    FPropertyName: string;  // For IsNull/IsNotNull
    FOperator: TUnaryOperator;
  public
    constructor Create(const ACriterion: ICriterion); overload; // For NOT
    constructor Create(const APropertyName: string; AOperator: TUnaryOperator); overload; // For IsNull
    
    property Criterion: ICriterion read FCriterion;
    property PropertyName: string read FPropertyName;
    property Operator: TUnaryOperator read FOperator;
    function ToString: string; override;
  end;

  /// <summary>
  ///   Represents a constant value (True/False) for always matching/not matching.
  /// </summary>
  TConstantCriterion = class(TAbstractCriterion)
  private
    FValue: Boolean;
  public
    constructor Create(AValue: Boolean);
    property Value: Boolean read FValue;
    function ToString: string; override;
  end;

implementation

{ TAbstractCriterion }

function TAbstractCriterion.ToString: string;
begin
  Result := ClassName;
end;

{ TBinaryCriterion }

constructor TBinaryCriterion.Create(const APropertyName: string;
  AOperator: TBinaryOperator; const AValue: TValue);
begin
  inherited Create;
  FPropertyName := APropertyName;
  FOperator := AOperator;
  FValue := AValue;
end;

function TBinaryCriterion.ToString: string;
begin
  Result := Format('(%s %d %s)', [FPropertyName, Ord(FOperator), FValue.ToString]);
end;

{ TLogicalCriterion }

constructor TLogicalCriterion.Create(const ALeft, ARight: ICriterion;
  AOperator: TLogicalOperator);
begin
  inherited Create;
  FLeft := ALeft;
  FRight := ARight;
  FOperator := AOperator;
end;

function TLogicalCriterion.ToString: string;
var
  OpStr: string;
begin
  if FOperator = loAnd then OpStr := 'AND' else OpStr := 'OR';
  Result := Format('(%s %s %s)', [FLeft.ToString, OpStr, FRight.ToString]);
end;

{ TUnaryCriterion }

constructor TUnaryCriterion.Create(const ACriterion: ICriterion);
begin
  inherited Create;
  FOperator := uoNot;
  FCriterion := ACriterion;
end;

constructor TUnaryCriterion.Create(const APropertyName: string;
  AOperator: TUnaryOperator);
begin
  inherited Create;
  FPropertyName := APropertyName;
  FOperator := AOperator;
end;

function TUnaryCriterion.ToString: string;
begin
  if FOperator = uoNot then
    Result := Format('(NOT %s)', [FCriterion.ToString])
  else if FOperator = uoIsNull then
    Result := Format('(%s IS NULL)', [FPropertyName])
  else
    Result := Format('(%s IS NOT NULL)', [FPropertyName]);
end;

{ TConstantCriterion }

constructor TConstantCriterion.Create(AValue: Boolean);
begin
  inherited Create;
  FValue := AValue;
end;

function TConstantCriterion.ToString: string;
begin
  Result := BoolToStr(FValue, True);
end;

end.
