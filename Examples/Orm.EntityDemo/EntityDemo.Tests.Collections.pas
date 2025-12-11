unit EntityDemo.Tests.Collections;

interface

uses
  System.SysUtils,
  Dext.Collections,
  Dext.Specifications.Expression,
  Dext.Specifications.Types, // For operators
  EntityDemo.Tests.Base;

type
  TCollectionsTest = class(TBaseTest)
  public
    // Internal test class
    type
      TPerson = class
      private
        FName: string;
        FAge: Integer;
        FCity: string;
      public
        constructor Create(const AName: string; AAge: Integer; const ACity: string = 'New York');
        property Name: string read FName;
        property Age: Integer read FAge;
        property City: string read FCity;
      end;

    procedure Run; override;
    procedure TestExpressions;
  end;

implementation

{ TCollectionsTest }

procedure TCollectionsTest.Run;
var
  LList: IList<Integer>;
  LFiltered: IList<Integer>;
begin
  Log('🚀 Running Collections Tests...');
  Log('=============================');

  // Test 1: Basic List Operations
  Log('📝 Testing Basic List Operations...');
  LList := TSmartList<Integer>.Create;
  LList.Add(1);
  LList.Add(2);
  LList.Add(3);

  AssertTrue(LList.Count = 3, 'Count is 3', 'Count mismatch');
  AssertTrue(LList[0] = 1, 'Item[0] is 1', 'Item mismatch');
  AssertTrue(LList.Contains(2), 'Contains(2) is True', 'Contains mismatch');

  LList.Remove(2);
  AssertTrue(LList.Count = 2, 'Count is 2 after remove', 'Count mismatch after remove');
  AssertTrue(not LList.Contains(2), 'Contains(2) is False', 'Contains mismatch after remove');


  // Test 2: Functional Methods
  Log('🔍 Testing Functional Methods...');
  LList.Clear;
  LList.AddRange([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

  // Where
  LFiltered := LList.Where(function(I: Integer): Boolean
    begin
      Result := (I mod 2) = 0;
    end);

  AssertTrue(LFiltered.Count = 5, 'Filtered count is 5 (evens)', 'Filtered count mismatch');
  AssertTrue(LFiltered.All(function(I: Integer): Boolean
    begin
      Result := (I mod 2) = 0;
    end), 'All items are even', 'Filter logic mismatch');

  // First / Any
  AssertTrue(LList.First = 1, 'First is 1', 'First mismatch');
  AssertTrue(LList.Any(function(I: Integer): Boolean begin Result := I > 9 end), 'Any(>9) is True', 'Any mismatch');
  AssertTrue(not LList.Any(function(I: Integer): Boolean begin Result := I > 10 end), 'Any(>10) is False', 'Any mismatch');

  Log('');

  TestExpressions;
end;

procedure TCollectionsTest.TestExpressions;
var
  LList: IList<TPerson>;
  LFiltered: IList<TPerson>;
  P: TPerson;
begin
  Log('🧠 Testing Expression Evaluation...');

  LList := TCollections.CreateObjectList<TPerson>;
  LList.Add(TPerson.Create('John', 25));
  LList.Add(TPerson.Create('Jane', 30, 'London'));
  LList.Add(TPerson.Create('Bob', 20));
  LList.Add(TPerson.Create('Alice', 35, 'London'));
  LList.Add(TPerson.Create('Mike', 40));

  // 1. Where(Age > 25)
  Log('   - Testing Where(Age > 25)');
  LFiltered := LList.Where(Prop('Age') > 25);
  AssertTrue(LFiltered.Count = 3, 'Filtered count is 3 (Jane, Alice, Mike)', 'Where expression mismatch');

  // 2. First(Name = 'Bob')
  Log('   - Testing First(Name = "Bob")');
  P := LList.First(Prop('Name') = 'Bob');
  AssertTrue(P.Name = 'Bob', 'Found Bob', 'First expression mismatch');

  // 3. Any(City = 'London')
  Log('   - Testing Any(City = "London")');
  AssertTrue(LList.Any(Prop('City') = 'London'), 'Found someone in London', 'Any expression mismatch');

  // 4. All(Age >= 20)
  Log('   - Testing All(Age >= 20)');
  AssertTrue(LList.All(Prop('Age') >= 20), 'Everyone is adult', 'All expression mismatch');

  // 5. Complex Expression: (City = 'London') AND (Age > 30)
  Log('   - Testing Complex: (City="London") AND (Age > 30)');

  // Using parenthesis to force evaluation order and operator precedence
  // Prop returned by `Prop` function is TPropExpression.
  // Equality returns TPropExpression.TExpression.
  // We need to make sure `and` works on two TExpressions.

  var Expr := (Prop('City') = 'London') and (Prop('Age') > 30);
  LFiltered := LList.Where(Expr);

  AssertTrue(LFiltered.Count = 1, 'Found 1 (Alice)', 'Complex expression mismatch');
  AssertTrue(LFiltered.First.Name = 'Alice', 'It is Alice', 'Complex expression items mismatch');
  for P in LList do P.Free;
end;

{ TCollectionsTest.TPerson }

constructor TCollectionsTest.TPerson.Create(const AName: string; AAge: Integer; const ACity: string);
begin
  FName := AName;
  FAge := AAge;
  FCity := ACity;
end;

end.
