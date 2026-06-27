unit Dext.Core.SmartTypes.Combinatorial.Tests;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Variants,
  Dext.Assertions,
  Dext.Testing.Attributes,
  Dext.Core.SmartTypes,
  Dext.Types.Nullable,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types;

type
  [TestFixture('SmartTypes Combinatorial Matrix')]
  TSmartTypesCombinatorialTests = class
  private
    procedure TestTypeStability<T>(const AValue: T; const AExpectStr: string);
    procedure TestArithmetic<T>(const A, B: Prop<T>; const ExpectedSum: T);
  public
    [Test]
    procedure Test_StringType_Stability;
    [Test]
    procedure Test_IntType_Stability;
    [Test]
    procedure Test_Int64Type_Stability;
    [Test]
    procedure Test_BoolType_Stability;
    [Test]
    procedure Test_FloatType_Stability;
    [Test]
    procedure Test_CurrencyType_Stability;
    [Test]
    procedure Test_DateTimeType_Stability;
    [Test]
    procedure Test_DateType_Stability;
    [Test]
    procedure Test_TimeType_Stability;

    [Test]
    procedure Test_QueryMode_Expression_Generation;
    [Test]
    procedure Test_Arithmetic_Operations;
    [Test]
    procedure Test_Nullable_Interop;
    [Test]
    procedure Test_Variant_Interop;
    [Test]
    procedure Test_All_Arithmetic_Operators;
    [Test]
    procedure Test_All_Comparison_Operators;
    [Test]
    procedure Test_Logical_Operators;
    [Test]
    procedure Test_Helper_Methods;
  end;

implementation

uses
  System.DateUtils,
  Dext.Core.ValueConverters;

{ TSmartTypesCombinatorialTests }

procedure TSmartTypesCombinatorialTests.TestTypeStability<T>(const AValue: T; const AExpectStr: string);
var
  P: Prop<T>;
  V: TValue;
begin
  P := AValue;
  
  // Implicit cast to T
  V := TValue.From<T>(T(P));
  Should(V.AsVariant).Be(TValue.From<T>(AValue).AsVariant);
  
  // Explicit cast to string
  Should(string(P)).Be(AExpectStr);
  
  // AsString method
  Should(P.AsString).Be(AExpectStr);
  
  // ToString method
  Should(P.ToString).Be(AExpectStr);

  // Runtime comparison
  Should(P = AValue).BeTrue;
  Should(P <> AValue).BeFalse;
end;

procedure TSmartTypesCombinatorialTests.TestArithmetic<T>(const A, B: Prop<T>; const ExpectedSum: T);
var
  Sum: Prop<T>;
begin
  Sum := A + B;
  Should(TValue.From<T>(Sum.Value).AsVariant).Be(TValue.From<T>(ExpectedSum).AsVariant);
  
  Sum := A + B.Value;
  Should(TValue.From<T>(Sum.Value).AsVariant).Be(TValue.From<T>(ExpectedSum).AsVariant);
end;

procedure TSmartTypesCombinatorialTests.Test_StringType_Stability;
begin
  TestTypeStability<string>('Dext Framework', 'Dext Framework');
end;

procedure TSmartTypesCombinatorialTests.Test_IntType_Stability;
begin
  TestTypeStability<Integer>(1234, '1234');
end;

procedure TSmartTypesCombinatorialTests.Test_Int64Type_Stability;
begin
  TestTypeStability<Int64>(9223372036854775807, '9223372036854775807');
end;

procedure TSmartTypesCombinatorialTests.Test_BoolType_Stability;
begin
  TestTypeStability<Boolean>(True, 'True');
  TestTypeStability<Boolean>(False, 'False');
end;

procedure TSmartTypesCombinatorialTests.Test_FloatType_Stability;
var
  V: Double;
begin
  // Using Invariant to avoid decimal separator issues in tests
  V := 1234.56;
  TestTypeStability<Double>(V, TValueConverter.Convert<string>(V));
end;

procedure TSmartTypesCombinatorialTests.Test_CurrencyType_Stability;
var
  V: Currency;
begin
  V := 99.99;
  TestTypeStability<Currency>(V, TValueConverter.Convert<string>(V));
end;

procedure TSmartTypesCombinatorialTests.Test_DateTimeType_Stability;
var
  D: TDateTime;
begin
  D := EncodeDateTime(2025, 12, 19, 14, 30, 0, 0);
  TestTypeStability<TDateTime>(D, TValueConverter.Convert<string>(D));
end;

procedure TSmartTypesCombinatorialTests.Test_DateType_Stability;
var
  D: TDate;
begin
  D := EncodeDate(2025, 12, 19);
  TestTypeStability<TDate>(D, TValueConverter.Convert<string>(D));
end;

procedure TSmartTypesCombinatorialTests.Test_TimeType_Stability;
var
  T: TTime;
begin
  T := EncodeTime(14, 30, 0, 0);
  TestTypeStability<TTime>(T, TValueConverter.Convert<string>(T));
end;

procedure TSmartTypesCombinatorialTests.Test_QueryMode_Expression_Generation;
var
  P: Prop<Integer>;
  Expr: BooleanExpression;
begin
  // Create a pseudo-query mode prop
  P := Prop<Integer>.FromInfo(TPropInfo.Create('Age'));
  
  Should(P.IsQueryMode).BeTrue;
  Should(P.Name).Be('Age');
  
  Expr := P > 18;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TBinaryExpression).BeTrue;
  Should(TBinaryExpression(Expr.Expression).BinaryOperator).Be(boGreaterThan);
end;

procedure TSmartTypesCombinatorialTests.Test_Arithmetic_Operations;
begin
  TestArithmetic<Integer>(10, 20, 30);
  TestArithmetic<Double>(10.5, 4.5, 15.0);
  TestArithmetic<Int64>(1000, 2000, 3000);
end;

procedure TSmartTypesCombinatorialTests.Test_Nullable_Interop;
var
  P: Prop<Integer>;
  N: Nullable<Integer>;
begin
  P := 42;
  N := P;
  Should(N.HasValue).BeTrue;
  Should(N.Value).Be(42);
  
  N.Clear;
  P := N;
  Should(P.Value).Be(0);
end;

procedure TSmartTypesCombinatorialTests.Test_Variant_Interop;
var
  P: Prop<string>;
  V: Variant;
begin
  P := 'Vibe';
  V := P;
  Should(string(V)).Be('Vibe');
  
  V := 'NewVibe';
  P := V;
  Should(P.Value).Be('NewVibe');
end;

procedure TSmartTypesCombinatorialTests.Test_All_Arithmetic_Operators;
var
  A, B: Prop<Double>;
  Expr: Prop<Double>;
begin
  // Runtime Mode
  A := 20.0;
  B := 5.0;
  Should((A - B).Value).Be(15.0);
  Should((A * B).Value).Be(100.0);
  Should((A / B).Value).Be(4.0);
  Should((-B).Value).Be(-5.0);
  Should((+B).Value).Be(5.0);
  Should((100.0 - B).Value).Be(95.0);
  Should((100.0 / B).Value).Be(20.0);
  Should((100.0 * B).Value).Be(500.0);

  // Query Mode
  A := Prop<Double>.FromInfo(TPropInfo.Create('Age'));
  B := Prop<Double>.FromInfo(TPropInfo.Create('Salary'));

  Expr := A - B;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TArithmeticExpression).BeTrue;
  Should(TArithmeticExpression(Expr.Expression).ArithmeticOperator).Be(aoSubtract);

  Expr := A * 10;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TArithmeticExpression).BeTrue;
  Should(TArithmeticExpression(Expr.Expression).ArithmeticOperator).Be(aoMultiply);

  Expr := 100 / A;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TArithmeticExpression).BeTrue;
  Should(TArithmeticExpression(Expr.Expression).ArithmeticOperator).Be(aoDivide);

  Expr := -A;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TArithmeticExpression).BeTrue;
  Should(TArithmeticExpression(Expr.Expression).ArithmeticOperator).Be(aoMultiply); // mapped as A * -1
end;

procedure TSmartTypesCombinatorialTests.Test_All_Comparison_Operators;
var
  A, B: Prop<Integer>;
  Expr: BooleanExpression;
begin
  // Runtime Mode
  A := 10;
  B := 20;
  Should(A = 10).BeTrue;
  Should(A <> 10).BeFalse;
  Should(A < B).BeTrue;
  Should(A <= 10).BeTrue;
  Should(B > A).BeTrue;
  Should(B >= 20).BeTrue;

  // Query Mode
  A := Prop<Integer>.FromInfo(TPropInfo.Create('Age'));
  B := Prop<Integer>.FromInfo(TPropInfo.Create('Salary'));

  Expr := A = B;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TBinaryExpression).BeTrue;
  Should(TBinaryExpression(Expr.Expression).BinaryOperator).Be(boEqual);

  Expr := A <> 18;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TBinaryExpression).BeTrue;
  Should(TBinaryExpression(Expr.Expression).BinaryOperator).Be(boNotEqual);

  Expr := A >= 21;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TBinaryExpression).BeTrue;
  Should(TBinaryExpression(Expr.Expression).BinaryOperator).Be(boGreaterThanOrEqual);

  Expr := 16 < A;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TBinaryExpression).BeTrue;
  Should(TBinaryExpression(Expr.Expression).BinaryOperator).Be(boGreaterThan); // 16 < A is equivalent to A > 16
end;

procedure TSmartTypesCombinatorialTests.Test_Logical_Operators;
var
  A, B: Prop<Boolean>;
  Expr: BooleanExpression;
begin
  // Runtime Mode
  A := True;
  B := False;
  Should(Boolean(not A)).BeFalse;
  Should(Boolean(A and B)).BeFalse;
  Should(Boolean(A or B)).BeTrue;

  // Query Mode
  A := Prop<Boolean>.FromInfo(TPropInfo.Create('IsActive'));

  Expr := not A;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TBinaryExpression).BeTrue;
  Should(TBinaryExpression(Expr.Expression).BinaryOperator).Be(boEqual); // not A maps to A = False

  Expr := A and True;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TLogicalExpression).BeTrue;
  Should(TLogicalExpression(Expr.Expression).LogicalOperator).Be(loAnd);
end;

procedure TSmartTypesCombinatorialTests.Test_Helper_Methods;
var
  StrProp: Prop<string>;
  IntProp: Prop<Integer>;
  Expr: BooleanExpression;
  Arr: TArray<Integer>;
  Order: IOrderBy;
begin
  // Runtime Mode
  StrProp := 'Cesar Romero';
  Should(Boolean(StrProp.StartsWith('Cesar'))).BeTrue;
  Should(Boolean(StrProp.Contains('Romero'))).BeTrue;
  Should(Boolean(StrProp.EndsWith('o'))).BeTrue;
  Should(Boolean(StrProp.Like('%Romero%'))).BeTrue;

  IntProp := 10;
  SetLength(Arr, 3);
  Arr[0] := 5; Arr[1] := 10; Arr[2] := 15;
  Should(Boolean(IntProp.&In(Arr))).BeTrue;
  Should(Boolean(IntProp.NotIn(Arr))).BeFalse;
  Should(Boolean(IntProp.Between(5, 15))).BeTrue;
  Should(Boolean(IntProp.IsNull)).BeFalse;
  Should(Boolean(IntProp.IsNotNull)).BeTrue;

  // Query Mode
  StrProp := Prop<string>.FromInfo(TPropInfo.Create('Name'));
  IntProp := Prop<Integer>.FromInfo(TPropInfo.Create('Age'));

  Expr := StrProp.StartsWith('Cesar');
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TBinaryExpression).BeTrue;
  Should(TBinaryExpression(Expr.Expression).BinaryOperator).Be(boLike);

  Expr := IntProp.&In(Arr);
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TBinaryExpression).BeTrue;
  Should(TBinaryExpression(Expr.Expression).BinaryOperator).Be(boIn);

  Expr := IntProp.IsNull;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TUnaryExpression).BeTrue;
  Should(TUnaryExpression(Expr.Expression).UnaryOperator).Be(uoIsNull);

  Expr := IntProp.IsNotNull;
  Should(Expr.Expression).NotBeNil;
  Should(Expr.Expression is TUnaryExpression).BeTrue;
  Should(TUnaryExpression(Expr.Expression).UnaryOperator).Be(uoIsNotNull);

  Order := IntProp.Asc;
  Should(Order).NotBeNil;
  Should(Order.GetPropertyName).Be('Age');
  Should(Order.GetAscending).BeTrue;

  Order := IntProp.Desc;
  Should(Order).NotBeNil;
  Should(Order.GetAscending).BeFalse;
end;

initialization
end.
