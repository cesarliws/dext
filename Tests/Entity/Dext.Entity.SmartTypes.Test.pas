unit Dext.Entity.SmartTypes.Test;

interface

uses
  System.SysUtils,
  System.Rtti,
  Dext.Assertions,
  Dext.Collections,
  Dext.Core.Reflection,
  Dext.Core.SmartTypes,
  Dext.Entity.Query,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Base,
  Dext.Specifications.Types,
  Dext.Entity.Prototype;

type
  TSmartTypesTest = class
  public
    procedure Run;
    procedure TestExplicitCasts;
    procedure TestAsMethods;
    procedure TestAssertions;
    procedure TestThenIncludePath;
    procedure TestEmptyNullPropWrapping;
  end;

  TTestOrderItem = class
  private
    FId: Prop<Integer>;
    FProductID: Prop<Integer>;
  public
    property Id: Prop<Integer> read FId write FId;
    property ProductID: Prop<Integer> read FProductID write FProductID;
  end;

  TTestOrder = class
  private
    FId: Prop<Integer>;
    FItems: Prop<IList<TTestOrderItem>>;
  public
    property Id: Prop<Integer> read FId write FId;
    property Items: Prop<IList<TTestOrderItem>> read FItems write FItems;
  end;

  TTestUser = class
  private
    FId: Prop<Integer>;
    FOrder: Prop<TTestOrder>;
  public
    property Id: Prop<Integer> read FId write FId;
    property Order: Prop<TTestOrder> read FOrder write FOrder;
  end;

implementation

{ TSmartTypesTest }

procedure TSmartTypesTest.Run;
begin
  WriteLn('Testing SmartTypes (Prop<T>) and Query Enhancements...');
  TestExplicitCasts;
  TestAsMethods;
  TestAssertions;
  TestThenIncludePath;
  TestEmptyNullPropWrapping;
end;

procedure TSmartTypesTest.TestExplicitCasts;
var
  IntProp: Prop<Integer>;
  StrProp: Prop<string>;
  NumStrProp: Prop<string>;
begin
  Write('  - Explicit Casts: ');
  
  IntProp := 10;
  Should(Integer(IntProp)).Be(10);
  Should(string(IntProp)).Be('10'); // Intelligent cast via RTTI/ToString

  StrProp := 'Dext';
  Should(string(StrProp)).Be('Dext');
  
  NumStrProp := '123';
  Should(Integer(NumStrProp)).Be(123); // Intelligent cast String -> Integer
  
  WriteLn('✅');
end;

procedure TSmartTypesTest.TestAsMethods;
var
  Age: Prop<Integer>;
  Price: Prop<Double>;
begin
  Write('  - AsXXX Methods: ');
  
  Age := 25;
  Should(Age.AsInteger).Be(25);
  Should(Age.AsString).Be('25');
  Should(Age.AsType<Int64>).Be(25);
  
  Price := 1500.50;
  Should(Price.AsDouble).Be(1500.50);
  Should(Price.AsString).StartWith('1500');
  
  WriteLn('✅');
end;

procedure TSmartTypesTest.TestAssertions;
var
  S: StringType;
  I: IntType;
begin
  Write('  - Smart Assertions: ');
  
  S := 'Framework';
  Should(S).StartWith('Frame');
  Should(S).NotBeEmpty;
  
  I := 100;
  Should(I).BeGreaterThan(50);
  Should(I).Be(100);
  
  WriteLn('✅');
end;

procedure TSmartTypesTest.TestThenIncludePath;
var
  Query: TFluentQuery<TTestUser>;
  Spec: ISpecification<TTestUser>;
  U: TTestUser;
begin
  Write('  - ThenInclude Paths: ');
  
  U := Prototype.Entity<TTestUser>;
  
  Spec := TSpecification<TTestUser>.Create;
  Query := TFluentQuery<TTestUser>.Create(nil, Spec);

  // Now we can use the cleaner syntax with inference and recursion!
  Query
    .Include(U.Order)
    .ThenInclude(U.Order.Value.Items)
    ;
    
  Should(Length(Spec.GetIncludes)).Be(1);
  // Correct path should be "Order.Items"
  Should(Spec.GetIncludes[0]).Be('Order.Items');
  
  WriteLn('✅');

  // Cleanup
  Query := Default(TFluentQuery<TTestUser>);
  Spec := nil;
end;

procedure TSmartTypesTest.TestEmptyNullPropWrapping;
var
  StrProp: Prop<string>;
  Val: TValue;
  TargetVal: TValue;
begin
  Write('  - Empty/Null Prop Wrapping: ');
  StrProp := 'Initial';
  TValue.Make(@StrProp, TypeInfo(Prop<string>), TargetVal);
  Val := TValue.Empty;
  
  TReflection.TryWrapProp(TargetVal, Val);
  StrProp := TargetVal.AsType<Prop<string>>;
  
  Should(string(StrProp)).Be('');
  WriteLn('✅');
end;

end.
