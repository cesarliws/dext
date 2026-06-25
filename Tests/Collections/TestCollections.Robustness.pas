unit TestCollections.Robustness;

interface

uses
  System.SysUtils,
  System.TypInfo,
  System.Math,
  Dext.Collections,
  Dext.Collections.Comparers,
  Dext.Collections.Dict,
  Dext.Collections.HashSet,
  Dext.Testing;

type
  // Record for padding and equality tests
  TPaddedRecord = record
    A: Byte;
    // 3 bytes padding
    B: Integer;
  end;

  // Interface for MI tests
  IMyInterface1 = interface
    ['{11111111-1111-1111-1111-111111111111}']
    function GetStr1: string;
  end;

  IMyInterface2 = interface
    ['{22222222-2222-2222-2222-222222222222}']
    function GetStr2: string;
  end;

  TMyMIObject = class(TInterfacedObject, IMyInterface1, IMyInterface2)
    function GetStr1: string;
    function GetStr2: string;
  end;

  [TestFixture('Collections - Robustness')]
  TRobustnessTests = class
  public
    [Test]
    procedure Sort_UnsignedIntegers_ShouldSortCorrectly;
    [Test]
    procedure Sort_UInt64_ShouldSortCorrectly;
    
    [Test]
    procedure Equals_PaddedRecords_ShouldMatchIfBinaryEqual;
    
    [Test]
    procedure IndexOf_InterfacesWithMI_ShouldFindCorrectIdentity;
    
    [Test]
    procedure IndexOf_FloatsWithNaN_ShouldBehaveCorrectly;
    
    [Test]
    procedure List_SortWithAnonymousFunction_ShouldWork;
    [Test]
    procedure IndexedSort_ShouldReturnSortedIndices;

    [Test]
    procedure Dictionary_InterfacesWithMI_ShouldFindCorrectIdentity;
    [Test]
    procedure Dictionary_UnsignedKeys_ShouldHandleLargeValues;
    
    [Test]
    procedure HashSet_InterfacesWithMI_ShouldFindCorrectIdentity;
    [Test]
    procedure HashSet_UnsignedValues_ShouldHandleLargeValues;
  end;

implementation

{ TMyMIObject }

function TMyMIObject.GetStr1: string; begin Result := '1'; end;
function TMyMIObject.GetStr2: string; begin Result := '2'; end;

{ TRobustnessTests }

procedure TRobustnessTests.Sort_UnsignedIntegers_ShouldSortCorrectly;
var
  L: IList<Cardinal>;
begin
  L := TCollections.CreateList<Cardinal>;
  // Test wrap around values for unsigned check
  L.Add($FFFFFFFF);
  L.Add(0);
  L.Add($7FFFFFFF);
  L.Add(1);
  
  L.Sort;
  
  Should(L[0]).Be(0);
  Should(L[1]).Be(1);
  Should(L[2]).Be($7FFFFFFF);
  Should(L[3]).Be($FFFFFFFF);
end;

procedure TRobustnessTests.Sort_UInt64_ShouldSortCorrectly;
var
  L: IList<UInt64>;
begin
  L := TCollections.CreateList<UInt64>;
  L.Add($FFFFFFFFFFFFFFFF);
  L.Add(0);
  L.Add($7FFFFFFFFFFFFFFF);
  
  L.Sort;
  
  Should(L[0]).Be(0);
  Should(L[1]).Be($7FFFFFFFFFFFFFFF);
  Should(L[2]).Be($FFFFFFFFFFFFFFFF);
end;

procedure TRobustnessTests.Equals_PaddedRecords_ShouldMatchIfBinaryEqual;
var
  L: IList<TPaddedRecord>;
  R1, R2: TPaddedRecord;
begin
  L := TCollections.CreateList<TPaddedRecord>;
  
  FillChar(R1, SizeOf(TPaddedRecord), 0);
  R1.A := 1;
  R1.B := 100;
  
  FillChar(R2, SizeOf(TPaddedRecord), 0);
  R2.A := 1;
  R2.B := 100;
  
  L.Add(R1);
  Should(L.Contains(R2)).BeTrue;
  Should(L.IndexOf(R2)).Be(0);
end;

procedure TRobustnessTests.IndexOf_InterfacesWithMI_ShouldFindCorrectIdentity;
var
  L: IList<IMyInterface2>;
  Obj: TMyMIObject;
  Intf1: IMyInterface1;
  Intf2: IMyInterface2;
begin
  Obj := TMyMIObject.Create;
  Intf1 := Obj; // Pointer to IMyInterface1 slot
  Intf2 := Obj; // Pointer to IMyInterface2 slot (different if MI)
  
  L := TCollections.CreateList<IMyInterface2>;
  L.Add(Intf2);
  
  // Even if we cast manually or pass the object, equality should work 
  // because the comparer desreferences and checks identity properly.
  Should(L.Contains(Intf2)).BeTrue;
  Should(L.IndexOf(Intf2)).Be(0);
end;

procedure TRobustnessTests.IndexOf_FloatsWithNaN_ShouldBehaveCorrectly;
var
  L: IList<Double>;
  N: Double;
begin
  L := TCollections.CreateList<Double>;
  N := Nan;
  L.Add(1.0);
  L.Add(N);
  L.Add(2.0);
  
  // Standard IEEE behavior: NaN <> NaN.
  // In collections, we usually expect IndexOf(NaN) to fail unless the comparer treats it specially.
  // Our current implementation uses '=' which for Double returns false for NaN.
  Should(L.IndexOf(N)).Be(-1); 
end;

procedure TRobustnessTests.List_SortWithAnonymousFunction_ShouldWork;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.AddRange([10, 5, 8, 2]);
  
  // Using anonymous function (verifies SortRaw overload with reference-to-function)
  L.Sort(TComparer<Integer>.Construct(
    function(const L, R: Integer): Integer
    begin
      Result := R - L; // Reverse sort
    end));
    
  Should(L[0]).Be(10);
  Should(L[1]).Be(8);
  Should(L[2]).Be(5);
  Should(L[3]).Be(2);
end;

procedure TRobustnessTests.IndexedSort_ShouldReturnSortedIndices;
var
  L: IList<string>;
  Indices: TArray<Integer>;
begin
  L := TCollections.CreateList<string>;
  L.AddRange(['C', 'A', 'B']);
  
  Indices := L.IndexedSort; // Uses InternalSortIndices
  
  Should(Length(Indices)).Be(3);
  Should(Indices[0]).Be(1); // 'A' is at index 1
  Should(Indices[1]).Be(2); // 'B' is at index 2
  Should(Indices[2]).Be(0); // 'C' is at index 0
  
  // Validate data didn't move
  Should(L[0]).Be('C');
end;

procedure TRobustnessTests.Dictionary_InterfacesWithMI_ShouldFindCorrectIdentity;
var
  D: IDictionary<IMyInterface1, string>;
  Obj: TMyMIObject;
  Intf1: IMyInterface1;
  Intf2: IMyInterface2;
begin
  Obj := TMyMIObject.Create;
  Intf1 := Obj;
  Intf2 := Obj; // Pointer to a different slot on the same object
  
  D := TCollections.CreateDictionary<IMyInterface1, string>;
  D.Add(Intf1, 'Found');
  
  // Try finding using a different interface slot of the same object.
  // We need a variable of IMyInterface1 pointing to the same object ID.
  Should(D.ContainsKey(IMyInterface1(Obj))).BeTrue;
  Should(D[IMyInterface1(Obj)]).Be('Found');
end;

procedure TRobustnessTests.Dictionary_UnsignedKeys_ShouldHandleLargeValues;
var
  D: IDictionary<Cardinal, string>;
  D64: IDictionary<UInt64, string>;
begin
  D := TCollections.CreateDictionary<Cardinal, string>;
  D.Add($FFFFFFFF, 'Max');
  D.Add($7FFFFFFF, 'Mid');
  
  Should(D[$FFFFFFFF]).Be('Max');
  Should(D.ContainsKey($FFFFFFFF)).BeTrue;
  
  D64 := TCollections.CreateDictionary<UInt64, string>;
  D64.Add($FFFFFFFFFFFFFFFF, 'Max64');
  
  Should(D64[$FFFFFFFFFFFFFFFF]).Be('Max64');
  Should(D64.ContainsKey($FFFFFFFFFFFFFFFF)).BeTrue;
end;

procedure TRobustnessTests.HashSet_InterfacesWithMI_ShouldFindCorrectIdentity;
var
  S: IHashSet<IMyInterface1>;
  Obj: TMyMIObject;
  Intf1: IMyInterface1;
  Intf2: IMyInterface2;
begin
  Obj := TMyMIObject.Create;
  Intf1 := Obj;
  Intf2 := Obj;
  
  S := TCollections.CreateHashSet<IMyInterface1>;
  S.Add(Intf1);
  
  Should(S.Contains(IMyInterface1(Obj))).BeTrue;
end;

procedure TRobustnessTests.HashSet_UnsignedValues_ShouldHandleLargeValues;
var
  S: IHashSet<UInt64>;
begin
  S := TCollections.CreateHashSet<UInt64>;
  S.Add($FFFFFFFFFFFFFFFF);
  S.Add(0);
  
  Should(S.Contains($FFFFFFFFFFFFFFFF)).BeTrue;
  Should(S.Contains(0)).BeTrue;
end;

end.
