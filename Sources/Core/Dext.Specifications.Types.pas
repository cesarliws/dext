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
unit Dext.Specifications.Types;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Specifications.Interfaces,
  Dext.Specifications.OrderBy;

type
  TAbstractExpression = class(TInterfacedObject, IExpression)
  public
    function ToString: string; override;
  end;

  /// <summary>
  ///   Represents a binary operator (Left Op Right).
  ///   e.g., Age > 18, Name = 'John'
  /// </summary>
  TBinaryOperator = (boEqual, boNotEqual, boGreaterThan, boGreaterThanOrEqual, 
    boLessThan, boLessThanOrEqual, boLike, boNotLike, boIn, boNotIn);

  TBinaryExpression = class(TAbstractExpression)
  private
    FPropertyName: string;
    FValue: TValue;
    FOperator: TBinaryOperator;
  public
    constructor Create(const APropertyName: string; AOperator: TBinaryOperator; const AValue: TValue);
    property PropertyName: string read FPropertyName;
    property Value: TValue read FValue;
    property BinaryOperator: TBinaryOperator read FOperator;
    function ToString: string; override;
  end;

  /// <summary>
  ///   Represents a logical operation (AND, OR).
  /// </summary>
  TLogicalOperator = (loAnd, loOr);

  TLogicalExpression = class(TAbstractExpression)
  private
    FLeft: IExpression;
    FRight: IExpression;
    FOperator: TLogicalOperator;
  public
    constructor Create(const ALeft, ARight: IExpression; AOperator: TLogicalOperator);
    property Left: IExpression read FLeft;
    property Right: IExpression read FRight;
    property LogicalOperator: TLogicalOperator read FOperator;
    function ToString: string; override;
  end;

  /// <summary>
  ///   Represents a unary operation (NOT, IsNull, IsNotNull).
  /// </summary>
  TUnaryOperator = (uoNot, uoIsNull, uoIsNotNull);

  TUnaryExpression = class(TAbstractExpression)
  private
    FExpression: IExpression; // For NOT
    FPropertyName: string;  // For IsNull/IsNotNull
    FOperator: TUnaryOperator;
  public
    constructor Create(const AExpression: IExpression); overload; // For NOT
    constructor Create(const APropertyName: string; AOperator: TUnaryOperator); overload; // For IsNull
    
    property Expression: IExpression read FExpression;
    property PropertyName: string read FPropertyName;
    property UnaryOperator: TUnaryOperator read FOperator;
    function ToString: string; override;
  end;

  /// <summary>
  ///   Represents a constant value (True/False) for always matching/not matching.
  /// </summary>
  TConstantExpression = class(TAbstractExpression)
  private
    FValue: Boolean;
  public
    constructor Create(AValue: Boolean);
    property Value: Boolean read FValue;
    function ToString: string; override;
  end;
  /// <summary>
  ///   Helper record to build expressions fluently.
  ///   Usage: PropExpression('Age') > 18
  /// </summary>
  TPropExpression = record
  public
    type
      /// <summary>
      ///   Represents an intermediate expression in the expression tree.
      ///   Has implicit conversion to IExpression.
      /// </summary>
      TExpression = record
      private
        FExpression: IExpression;
      public
        class operator Implicit(const Value: IExpression): TExpression;
        class operator Implicit(const Value: TExpression): IExpression;
        
        // Logical Operators (AND, OR, NOT) - return IExpression like Spring4D
        class operator LogicalAnd(const Left, Right: TExpression): IExpression;
        class operator LogicalOr(const Left, Right: TExpression): IExpression;
        class operator LogicalNot(const Value: TExpression): IExpression;
      end;
    var
      FName: string;
  public
    constructor Create(const AName: string);
    // Comparison Operators
    class operator Equal(const Left: TPropExpression; const Right: TValue): TExpression;
    class operator NotEqual(const Left: TPropExpression; const Right: TValue): TExpression;
    class operator GreaterThan(const Left: TPropExpression; const Right: TValue): TExpression;
    class operator GreaterThanOrEqual(const Left: TPropExpression; const Right: TValue): TExpression;
    class operator LessThan(const Left: TPropExpression; const Right: TValue): TExpression;
    class operator LessThanOrEqual(const Left: TPropExpression; const Right: TValue): TExpression;
    class operator Implicit(const Value: TPropExpression): string;
    // Special Methods (Like, In, etc)
    function Like(const Pattern: string): IExpression;
    function NotLike(const Pattern: string): IExpression;
    function StartsWith(const Value: string): IExpression;
    function EndsWith(const Value: string): IExpression;
    function Contains(const Value: string): IExpression;
    
    function &In(const Values: TArray<string>): IExpression; overload;
    function &In(const Values: TArray<Integer>): IExpression; overload;
    function NotIn(const Values: TArray<string>): IExpression; overload;
    function NotIn(const Values: TArray<Integer>): IExpression; overload;
    
    function IsNull: IExpression;
    function IsNotNull: IExpression;
    
    // Between as a method (not operator) like Spring4D
    function Between(const Lower, Upper: Variant): IExpression;
    
    // OrderBy support
    function Asc: IOrderBy;
    function Desc: IOrderBy;
    property Name: string read FName;
  end;

implementation

{ TAbstractExpression }

function TAbstractExpression.ToString: string;
begin
  Result := ClassName;
end;

{ TBinaryExpression }

constructor TBinaryExpression.Create(const APropertyName: string;
  AOperator: TBinaryOperator; const AValue: TValue);
begin
  inherited Create;
  FPropertyName := APropertyName;
  FOperator := AOperator;
  FValue := AValue;
end;

function TBinaryExpression.ToString: string;
begin
  Result := Format('(%s %d %s)', [FPropertyName, Ord(FOperator), FValue.ToString]);
end;

{ TLogicalExpression }

constructor TLogicalExpression.Create(const ALeft, ARight: IExpression;
  AOperator: TLogicalOperator);
begin
  inherited Create;
  FLeft := ALeft;
  FRight := ARight;
  FOperator := AOperator;
end;

function TLogicalExpression.ToString: string;
var
  OpStr: string;
begin
  if FOperator = loAnd then OpStr := 'AND' else OpStr := 'OR';
  Result := Format('(%s %s %s)', [FLeft.ToString, OpStr, FRight.ToString]);
end;

{ TUnaryExpression }

constructor TUnaryExpression.Create(const AExpression: IExpression);
begin
  inherited Create;
  FOperator := uoNot;
  FExpression := AExpression;
end;

constructor TUnaryExpression.Create(const APropertyName: string;
  AOperator: TUnaryOperator);
begin
  inherited Create;
  FPropertyName := APropertyName;
  FOperator := AOperator;
end;

function TUnaryExpression.ToString: string;
begin
  if FOperator = uoNot then
    Result := Format('(NOT %s)', [FExpression.ToString])
  else if FOperator = uoIsNull then
    Result := Format('(%s IS NULL)', [FPropertyName])
  else
    Result := Format('(%s IS NOT NULL)', [FPropertyName]);
end;

{ TConstantExpression }

constructor TConstantExpression.Create(AValue: Boolean);
begin
  inherited Create;
  FValue := AValue;
end;

function TConstantExpression.ToString: string;
begin
  Result := BoolToStr(FValue, True);
end;

{ TPropExpression.TExpression }

class operator TPropExpression.TExpression.Implicit(const Value: IExpression): TExpression;
begin
  Result.FExpression := Value;
end;

class operator TPropExpression.TExpression.Implicit(const Value: TExpression): IExpression;
begin
  Result := Value.FExpression;
end;

class operator TPropExpression.TExpression.LogicalAnd(const Left, Right: TExpression): IExpression;
begin
  Result := TLogicalExpression.Create(Left.FExpression, Right.FExpression, loAnd);
end;

class operator TPropExpression.TExpression.LogicalOr(const Left, Right: TExpression): IExpression;
begin
  Result := TLogicalExpression.Create(Left.FExpression, Right.FExpression, loOr);
end;

class operator TPropExpression.TExpression.LogicalNot(const Value: TExpression): IExpression;
begin
  Result := TUnaryExpression.Create(Value.FExpression);
end;

{ TPropExpression }

constructor TPropExpression.Create(const AName: string);
begin
  FName := AName;
end;

class operator TPropExpression.Equal(const Left: TPropExpression; const Right: TValue): TExpression;
begin
  Result.FExpression := TBinaryExpression.Create(Left.FName, boEqual, Right);
end;

class operator TPropExpression.NotEqual(const Left: TPropExpression; const Right: TValue): TExpression;
begin
  Result.FExpression := TBinaryExpression.Create(Left.FName, boNotEqual, Right);
end;

class operator TPropExpression.GreaterThan(const Left: TPropExpression; const Right: TValue): TExpression;
begin
  Result.FExpression := TBinaryExpression.Create(Left.FName, boGreaterThan, Right);
end;

class operator TPropExpression.GreaterThanOrEqual(const Left: TPropExpression; const Right: TValue): TExpression;
begin
  Result.FExpression := TBinaryExpression.Create(Left.FName, boGreaterThanOrEqual, Right);
end;

class operator TPropExpression.LessThan(const Left: TPropExpression; const Right: TValue): TExpression;
begin
  Result.FExpression := TBinaryExpression.Create(Left.FName, boLessThan, Right);
end;

class operator TPropExpression.LessThanOrEqual(const Left: TPropExpression; const Right: TValue): TExpression;
begin
  Result.FExpression := TBinaryExpression.Create(Left.FName, boLessThanOrEqual, Right);
end;

function TPropExpression.Like(const Pattern: string): IExpression;
begin
  Result := TBinaryExpression.Create(FName, boLike, Pattern);
end;

function TPropExpression.NotLike(const Pattern: string): IExpression;
begin
  Result := TBinaryExpression.Create(FName, boNotLike, Pattern);
end;

function TPropExpression.StartsWith(const Value: string): IExpression;
begin
  Result := Like(Value + '%');
end;

function TPropExpression.EndsWith(const Value: string): IExpression;
begin
  Result := Like('%' + Value);
end;

function TPropExpression.Contains(const Value: string): IExpression;
begin
  Result := Like('%' + Value + '%');
end;

function TPropExpression.&In(const Values: TArray<string>): IExpression;
var
  Val: TValue;
begin
  Val := TValue.From<TArray<string>>(Values);
  Result := TBinaryExpression.Create(FName, boIn, Val);
end;

class operator TPropExpression.Implicit(const Value: TPropExpression): string;
begin
  Result := Value.Name;
end;

function TPropExpression.&In(const Values: TArray<Integer>): IExpression;
var
  Val: TValue;
begin
  Val := TValue.From<TArray<Integer>>(Values);
  Result := TBinaryExpression.Create(FName, boIn, Val);
end;

function TPropExpression.NotIn(const Values: TArray<string>): IExpression;
var
  Val: TValue;
begin
  Val := TValue.From<TArray<string>>(Values);
  Result := TBinaryExpression.Create(FName, boNotIn, Val);
end;

function TPropExpression.NotIn(const Values: TArray<Integer>): IExpression;
var
  Val: TValue;
begin
  Val := TValue.From<TArray<Integer>>(Values);
  Result := TBinaryExpression.Create(FName, boNotIn, Val);
end;

function TPropExpression.IsNull: IExpression;
begin
  Result := TUnaryExpression.Create(FName, uoIsNull);
end;

function TPropExpression.IsNotNull: IExpression;
begin
  Result := TUnaryExpression.Create(FName, uoIsNotNull);
end;

function TPropExpression.Between(const Lower, Upper: Variant): IExpression;
begin
  // (Prop >= Lower) AND (Prop <= Upper)
  // Create expressions manually to avoid operator ambiguity
  var LowerCrit: IExpression := TBinaryExpression.Create(FName, boGreaterThanOrEqual, TValue.FromVariant(Lower));
  var UpperCrit: IExpression := TBinaryExpression.Create(FName, boLessThanOrEqual, TValue.FromVariant(Upper));
  Result := TLogicalExpression.Create(LowerCrit, UpperCrit, loAnd);
end;

function TPropExpression.Asc: IOrderBy;
begin
  Result := TOrderBy.Create(FName, True);
end;

function TPropExpression.Desc: IOrderBy;
begin
  Result := TOrderBy.Create(FName, False);
end;

end.

