unit Dext.Entity.SmartTypes.Tests;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Rtti,
  Dext.Assertions,
  Dext.Testing.Attributes,
  Dext.Core.Reflection,
  Dext.Core.SmartTypes,
  Dext.Types.Nullable,
  Dext.Entity.Attributes,
  Dext.Entity.TypeSystem,
  Dext.Entity.Prototype,
  Dext.Entity.Query,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Base,
  Dext.Specifications.Types;

type
  [Table('plain_users')]
  TPlainTestUser = class
  private
    FId: Integer;
    FName: string;
    FEmail: string;
  public
    [PK, AutoInc] property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Email: string read FEmail write FEmail;
  end;

  TPlainTestUserType = class(TEntityType<TPlainTestUser>)
  public
    class var Name: TPropExpression;
    class constructor Create;
  end;

  [Table('nullable_only_users')]
  TNullableOnlyTestUser = class
  private
    FId: Integer;
    FName: Nullable<string>;
  public
    [PK, AutoInc] property Id: Integer read FId write FId;
    property Name: Nullable<string> read FName write FName;
  end;

  [Table('smart_prop_entities')]
  TSmartPropTestEntity = class
  private
    FId: Prop<Integer>;
    FAktif: Prop<string>;
  public
    [PK, AutoInc] property Id: Prop<Integer> read FId write FId;
    property Aktif: Prop<string> read FAktif write FAktif;
  end;

  [TestFixture('SmartTypes (Prop<T>) Tests')]
  TSmartTypesTests = class
  public
    [Test]
    [Description('Verify explicit casts from Prop<T> to common types')]
    procedure TestExplicitCasts;

    [Test]
    [Description('Verify fluent .AsXXXX methods for conversion')]
    procedure TestAsMethods;

    [Test]
    [Description('Verify generic .As<T> conversion')]
    procedure TestGenericAs;

    [Test]
    [Description('Verify assertions working directly with Prop<T>')]
    procedure TestSmartAssertions;

    [Test]
    [Description('Verify assertions working with Nullable<T>')]
    procedure TestNullableAssertions;

    [Test]
    [Description('Verify that calling Prototype.Entity on a plain entity raises an exception')]
    procedure TestPlainEntityPrototypeRaisesException;

    [Test]
    [Description('Verify that calling Prototype.Entity on an entity with only Nullable properties raises an exception')]
    procedure TestNullableOnlyEntityPrototypeRaisesException;

    [Test]
    [Description('Verify that a query return-all doesn''t trigger prototype validation exception')]
    procedure TestPlainEntityQueryAllWorks;

    [Test]
    [Description('Verify that querying plain entities using metadata class works')]
    procedure TestPlainEntityTypeQueryWorks;

    [Test]
    [Description('Issue #155: Verify empty/null value wrapping on Prop<T> resets FValue to empty')]
    procedure Test_Issue155_EmptyNullPropWrapping;
  end;

  [TestFixture('SmartTypes Combinatorial Matrix')]
  TSmartTypesMatrixTests = class
  private
    procedure CheckType<T>(const Value: T; const ExpectedStr: string;
      TestConversionBack: Boolean = True);
  public
    [Test]
    procedure Test_All_Fundament_Types_Consistency;
  end;

implementation

{ TSmartTypesMatrixTests }

procedure TSmartTypesMatrixTests.CheckType<T>(const Value: T; const
  ExpectedStr: string; TestConversionBack: Boolean = True);
var
  P: Prop<T>;
  expect, actual: Variant;
begin
  P := Value;
  Should(P.AsString).Be(ExpectedStr);
  Should(Nullable<T>(P).HasValue).BeTrue;

  if not TestConversionBack then Exit;

  expect := TValue.From<T>(T(P)).AsVariant;
  actual := TValue.From<T>(Value).AsVariant;
  // Test conversion back to T using Variant as bridge for generics
  Should(expect).Be(actual);
end;

procedure TSmartTypesMatrixTests.Test_All_Fundament_Types_Consistency;
var
  G: TGuid;
  D: TDateTime;
begin
  // String
  CheckType<string>('Dext', 'Dext');
  
  // Integer
  CheckType<Integer>(123, '123');
  
  // Int64
  CheckType<Int64>(9223372036854775807, '9223372036854775807');
  
  // Double
  CheckType<Double>(123.45, '123.45');
  
  // Boolean
  CheckType<Boolean>(True, 'True');
  CheckType<Boolean>(False, 'False');
  
  // DateTime
  D := EncodeDateTime(2025, 12, 19, 14, 30, 0, 0);
  CheckType<TDateTime>(D, DateTimeToStr(D));
  
  // Currency
  CheckType<Currency>(1234.56, '1234.56');
  
  // Guid
  G := TGuid.Create('{D6A5D5A1-949B-4B7C-9F8A-E7C1D1B1B1B1}');
  CheckType<TGuid>(G, GUIDToString(G), False);
end;

{ TSmartTypesTests }

procedure TSmartTypesTests.TestExplicitCasts;
var
  IntProp: Prop<Integer>;
  StrProp: Prop<string>;
  NumStrProp: Prop<string>;
  BoolProp: Prop<Boolean>;
begin
  IntProp := 10;
  Should(Integer(IntProp)).Be(10);
  Should(string(IntProp)).Be('10');

  StrProp := 'Dext';
  Should(string(StrProp)).Be('Dext');
  
  NumStrProp := '123';
  Should(Integer(NumStrProp)).Be(123);
  
  BoolProp := True;
  Should(Boolean(BoolProp)).BeTrue;
  Should(string(BoolProp)).BeEquivalentTo('True');
end;

procedure TSmartTypesTests.TestAsMethods;
var
  Age: Prop<Integer>;
  Price: Prop<Double>;
begin
  Age := 25;
  Should(Age.AsInteger).Be(25);
  Should(Age.AsString).Be('25');
  
  Price := 1500.50;
  Should(Price.AsDouble).Be(1500.50);
  Should(Price.AsString).StartWith('1500');
end;

procedure TSmartTypesTests.TestGenericAs;
var
  Value: Prop<Integer>;
begin
  Value := 100;
  Should(Value.AsType<Int64>()).Be(100);
end;

procedure TSmartTypesTests.TestSmartAssertions;
var
  S: StringType;
  I: IntType;
begin
  S := 'Framework';
  Should(S).StartWith('Frame');
  Should(S).NotBeEmpty;
  
  I := 100;
  Should(I).BeGreaterThan(50);
  Should(I).Be(100);
end;

procedure TSmartTypesTests.TestNullableAssertions;
var
  N: Nullable<Integer>;
  D: Nullable<TDateTime>;
begin
  N := 42;
  Should(N).Be(42);
  
  D := Now;
  ShouldDate(D).BeToday;
  
  // Test failure case (Manual check if needed, but here we just verify success)
  N.Clear;
  // Should(N).Be(0); // This would call Assert.Fail as expected
end;

procedure TSmartTypesTests.TestPlainEntityPrototypeRaisesException;
begin
  Should(procedure
    begin
      Prototype.Entity<TPlainTestUser>;
    end).Throw(Exception)
        .ThrowWithMessageContaining('does not contain any Smart Properties');
end;

procedure TSmartTypesTests.TestNullableOnlyEntityPrototypeRaisesException;
begin
  Should(procedure
    begin
      Prototype.Entity<TNullableOnlyTestUser>;
    end).Throw(Exception)
        .ThrowWithMessageContaining('does not contain any Smart Properties');
end;

procedure TSmartTypesTests.TestPlainEntityQueryAllWorks;
var
  Query: TFluentQuery<TPlainTestUser>;
  Spec: ISpecification<TPlainTestUser>;
begin
  Spec := TSpecification<TPlainTestUser>.Create;
  Query := TFluentQuery<TPlainTestUser>.Create(nil, Spec);
  
  Query.Skip(10);

  Query := Default(TFluentQuery<TPlainTestUser>);
  Spec := nil;
end;

procedure TSmartTypesTests.TestPlainEntityTypeQueryWorks;
var
  Query: TFluentQuery<TPlainTestUser>;
  Spec: ISpecification<TPlainTestUser>;
begin
  Spec := TSpecification<TPlainTestUser>.Create;
  Query := TFluentQuery<TPlainTestUser>.Create(nil, Spec);

  Query.Where(TPlainTestUserType.Name = 'John');

  Query := Default(TFluentQuery<TPlainTestUser>);
  Spec := nil;
end;

procedure TSmartTypesTests.Test_Issue155_EmptyNullPropWrapping;
var
  Entity: TSmartPropTestEntity;
  Prop: TRttiProperty;
  RType: TRttiType;
  Val: TValue;
begin
  Entity := TSmartPropTestEntity.Create;
  try
    Entity.Aktif := 'InitialValue';
    RType := TReflection.Context.GetType(TSmartPropTestEntity);
    Prop := RType.GetProperty('Aktif');
    Val := TValue.Empty;

    TReflection.SetValue(Entity, Prop, Val);
    Should(string(Entity.Aktif)).Be('');
  finally
    Entity.Free;
  end;
end;


{ TPlainTestUserType }

class constructor TPlainTestUserType.Create;
begin
  Name := TPropExpression.Create('Name');
end;

initialization
  // Fixtures are registered in the main runner
end.
