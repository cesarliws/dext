{***************************************************************************}
{                                                                           }
{           Dext Framework - Collections Unit Tests                         }
{                                                                           }
{           Tests for IList<T>, TList<T>, TCollections.CreateList<T>        }
{                                                                           }
{***************************************************************************}
unit TestCollections.Lists;

interface

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Collections;

type
  TManagedRecord = record
    S: string;
    I: Integer;
  end;

  // Helper class for ownership tests
  TDummyObject = class
  private
    FValue: Integer;
    class var InstanceCount: Integer;
  public
    constructor Create(AValue: Integer);
    destructor Destroy; override;
    property Value: Integer read FValue;
  end;

  // Simple interface for interface tests
  IValueHolder = interface
    ['{B1A2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetValue: Integer;
    property Value: Integer read GetValue;
  end;

  TValueHolder = class(TInterfacedObject, IValueHolder)
  private
    FValue: Integer;
    function GetValue: Integer;
  public
    constructor Create(AValue: Integer);
  end;

  /// <summary>Basic list operations: Add, Remove, Count, Clear, IndexOf, Contains</summary>
  [TestFixture('List - Basic Operations')]
  TListBasicTests = class
  public
    [Test]
    procedure Add_ShouldIncreaseCount;

    [Test]
    procedure Remove_ShouldDecreaseCount;

    [Test]
    procedure Clear_ShouldResetCount;

    [Test]
    procedure IndexOf_ShouldFindItem;

    [Test]
    procedure IndexOf_ShouldReturnMinusOneForMissing;

    [Test]
    procedure Contains_ShouldReturnTrueForExisting;

    [Test]
    procedure Contains_ShouldReturnFalseForMissing;

    [Test]
    procedure GetItem_ShouldReturnCorrectValue;

    [Test]
    procedure SetItem_ShouldUpdateValue;

    [Test]
    procedure Delete_ShouldRemoveByIndex;

    [Test]
    procedure RemoveAt_ShouldRemoveByIndex;

    [Test]
    procedure Extract_ShouldRemoveAndReturnItem;

    [Test]
    procedure First_ShouldReturnFirstItem;

    [Test]
    procedure Last_ShouldReturnLastItem;

    [Test]
    procedure First_EmptyList_ShouldRaise;

    [Test]
    procedure Last_EmptyList_ShouldRaise;

    [Test]
    procedure ToArray_ShouldReturnAllItems;

    [Test]
    procedure AddRange_ShouldAddMultipleItems;

    [Test]
    procedure Insert_ShouldShiftItems;

    [Test]
    procedure Insert_AtBeginning_ShouldWork;

    [Test]
    procedure Insert_AtEnd_ShouldWork;
  end;

  /// <summary>List with records containing managed fields (strings)</summary>
  [TestFixture('List - Managed Records')]
  TListManagedRecordTests = class
  public
    [Test]
    procedure Add_ShouldStoreManagedRecord;

    [Test]
    procedure Clear_ShouldFinalizeManagedRecords;
  end;

  /// <summary>List operations with string elements (managed type)</summary>
  [TestFixture('List - String Elements')]
  TListStringTests = class
  public
    [Test]
    procedure Add_StringsShouldBeStored;

    [Test]
    procedure Remove_StringShouldWork;

    [Test]
    procedure Clear_ShouldFinalizeStrings;

    [Test]
    procedure IndexOf_StringShouldMatch;

    [Test]
    procedure ForIn_ShouldIterateStrings;

    [Test]
    procedure ToArray_ShouldCopyStrings;
  end;

  /// <summary>List operations with interface elements (ref-counted)</summary>
  [TestFixture('List - Interface Elements')]
  TListInterfaceTests = class
  public
    [Test]
    procedure Add_InterfaceShouldBeRefCounted;

    [Test]
    procedure Clear_ShouldReleaseInterfaces;

    [Test]
    procedure ForIn_ShouldIterateInterfaces;
  end;

  /// <summary>OwnsObjects behavior</summary>
  [TestFixture('List - Ownership')]
  TListOwnershipTests = class
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure OwnsObjects_ShouldFreeOnRemove;

    [Test]
    procedure OwnsObjects_ShouldFreeOnClear;

    [Test]
    procedure NoOwnership_ShouldNotFreeOnClear;

    [Test]
    procedure Extract_ShouldNotFreeObject;
  end;

  /// <summary>For..in enumerator behavior</summary>
  [TestFixture('List - Enumerator')]
  TListEnumeratorTests = class
  public
    [Test]
    procedure ForIn_EmptyListShouldNotIterate;

    [Test]
    procedure ForIn_ShouldVisitAllItems;

    [Test]
    procedure ForIn_SingleItemShouldWork;
  end;

  /// <summary>LINQ-style extensions: Where, Any, All, ForEach</summary>
  [TestFixture('List - LINQ Extensions')]
  TListLinqTests = class
  public
    [Test]
    procedure Where_ShouldFilterItems;

    [Test]
    procedure Any_ShouldReturnTrueIfMatch;

    [Test]
    procedure Any_ShouldReturnFalseIfNoMatch;

    [Test]
    procedure All_ShouldReturnTrueIfAllMatch;

    [Test]
    procedure All_ShouldReturnFalseIfNotAllMatch;

    [Test]
    procedure ForEach_ShouldVisitAllItems;
  end;

  /// <summary>Tests for the non-generic IObjectList interface mapping</summary>
  [TestFixture('List - IObjectList Interface')]
  TListIObjectListTests = class
  public
    [Test]
    procedure Cast_ToIObjectList_ShouldBeValid;
    [Test]
    procedure IObjectList_Add_ShouldWork;
    [Test]
    procedure IObjectList_GetItem_ShouldWork;
    [Test]
    procedure IObjectList_IndexOf_ShouldWork;
    [Test]
    procedure IObjectList_Insert_ShouldWork;
    [Test]
    procedure IObjectList_Delete_ShouldWork;
  end;

implementation

{ TDummyObject }

constructor TDummyObject.Create(AValue: Integer);
begin
  inherited Create;
  FValue := AValue;
  Inc(InstanceCount);
end;

destructor TDummyObject.Destroy;
begin
  Dec(InstanceCount);
  inherited;
end;

{ TValueHolder }

constructor TValueHolder.Create(AValue: Integer);
begin
  inherited Create;
  FValue := AValue;
end;

function TValueHolder.GetValue: Integer;
begin
  Result := FValue;
end;

{ TListBasicTests }

procedure TListBasicTests.Add_ShouldIncreaseCount;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  Should(L.Count).Be(0);
  L.Add(10);
  Should(L.Count).Be(1);
  L.Add(20);
  Should(L.Count).Be(2);
  L.Add(30);
  Should(L.Count).Be(3);
end;

procedure TListBasicTests.Remove_ShouldDecreaseCount;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(10);
  L.Add(20);
  L.Add(30);
  L.Remove(20);
  Should(L.Count).Be(2);
  Should(L.Contains(20)).BeFalse;
end;

procedure TListBasicTests.Clear_ShouldResetCount;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(1);
  L.Add(2);
  L.Add(3);
  L.Clear;
  Should(L.Count).Be(0);
end;

procedure TListBasicTests.IndexOf_ShouldFindItem;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(100);
  L.Add(200);
  L.Add(300);
  Should(L.IndexOf(200)).Be(1);
end;

procedure TListBasicTests.IndexOf_ShouldReturnMinusOneForMissing;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(100);
  Should(L.IndexOf(999)).Be(-1);
end;

procedure TListBasicTests.Contains_ShouldReturnTrueForExisting;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(42);
  Should(L.Contains(42)).BeTrue;
end;

procedure TListBasicTests.Contains_ShouldReturnFalseForMissing;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(42);
  Should(L.Contains(99)).BeFalse;
end;

procedure TListBasicTests.GetItem_ShouldReturnCorrectValue;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(10);
  L.Add(20);
  L.Add(30);
  Should(L[0]).Be(10);
  Should(L[1]).Be(20);
  Should(L[2]).Be(30);
end;

procedure TListBasicTests.SetItem_ShouldUpdateValue;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(10);
  L[0] := 99;
  Should(L[0]).Be(99);
end;

procedure TListBasicTests.Delete_ShouldRemoveByIndex;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(10);
  L.Add(20);
  L.Add(30);
  L.Delete(1); // Remove 20
  Should(L.Count).Be(2);
  Should(L[0]).Be(10);
  Should(L[1]).Be(30);
end;

procedure TListBasicTests.RemoveAt_ShouldRemoveByIndex;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(10);
  L.Add(20);
  L.Add(30);
  L.RemoveAt(0); // Remove 10
  Should(L.Count).Be(2);
  Should(L[0]).Be(20);
end;

procedure TListBasicTests.Extract_ShouldRemoveAndReturnItem;
var
  L: IList<Integer>;
  V: Integer;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(10);
  L.Add(20);
  V := L.Extract(10);
  Should(V).Be(10);
  Should(L.Count).Be(1);
  Should(L.Contains(10)).BeFalse;
end;

procedure TListBasicTests.First_ShouldReturnFirstItem;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(10);
  L.Add(20);
  Should(L.First).Be(10);
end;

procedure TListBasicTests.Last_ShouldReturnLastItem;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(10);
  L.Add(20);
  Should(L.Last).Be(20);
end;

procedure TListBasicTests.First_EmptyList_ShouldRaise;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  Should(
    procedure
    begin
      L.First;
    end
  ).Throw<Exception>;
end;

procedure TListBasicTests.Last_EmptyList_ShouldRaise;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  Should(
    procedure
    begin
      L.Last;
    end
  ).Throw<Exception>;
end;

procedure TListBasicTests.ToArray_ShouldReturnAllItems;
var
  L: IList<Integer>;
  Arr: TArray<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(1);
  L.Add(2);
  L.Add(3);
  Arr := L.ToArray;
  Should(Length(Arr)).Be(3);
  Should(Arr[0]).Be(1);
  Should(Arr[1]).Be(2);
  Should(Arr[2]).Be(3);
end;

procedure TListBasicTests.AddRange_ShouldAddMultipleItems;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.AddRange([10, 20, 30, 40, 50]);
  Should(L.Count).Be(5);
  Should(L[4]).Be(50);
end;

procedure TListBasicTests.Insert_ShouldShiftItems;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(1);
  L.Add(3);
  L.Insert(1, 2);
  Should(L.Count).Be(3);
  Should(L[0]).Be(1);
  Should(L[1]).Be(2);
  Should(L[2]).Be(3);
end;

procedure TListBasicTests.Insert_AtBeginning_ShouldWork;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(2);
  L.Insert(0, 1);
  Should(L[0]).Be(1);
  Should(L[1]).Be(2);
end;

procedure TListBasicTests.Insert_AtEnd_ShouldWork;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(1);
  L.Insert(1, 2);
  Should(L[1]).Be(2);
end;

{ TListManagedRecordTests }

procedure TListManagedRecordTests.Add_ShouldStoreManagedRecord;
var
  L: IList<TManagedRecord>;
  R: TManagedRecord;
begin
  L := TCollections.CreateList<TManagedRecord>;
  R.S := 'Recursive';
  R.I := 42;
  L.Add(R);
  Should(L.Count).Be(1);
  Should(L[0].S).Be('Recursive');
end;

procedure TListManagedRecordTests.Clear_ShouldFinalizeManagedRecords;
var
  L: IList<TManagedRecord>;
  R: TManagedRecord;
begin
  L := TCollections.CreateList<TManagedRecord>;
  R.S := 'Will be finalized';
  L.Add(R);
  L.Clear;
  Should(L.Count).Be(0);
  // No memory leak = success (checked via FastMM if active)
end;

{ TListStringTests }

procedure TListStringTests.Add_StringsShouldBeStored;
var
  L: IList<string>;
begin
  L := TCollections.CreateList<string>;
  L.Add('Hello');
  L.Add('World');
  Should(L.Count).Be(2);
  Should(L[0]).Be('Hello');
  Should(L[1]).Be('World');
end;

procedure TListStringTests.Remove_StringShouldWork;
var
  L: IList<string>;
begin
  L := TCollections.CreateList<string>;
  L.Add('Alpha');
  L.Add('Beta');
  L.Add('Gamma');
  L.Remove('Beta');
  Should(L.Count).Be(2);
  Should(L.Contains('Beta')).BeFalse;
end;

procedure TListStringTests.Clear_ShouldFinalizeStrings;
var
  L: IList<string>;
begin
  L := TCollections.CreateList<string>;
  L.Add('Test1');
  L.Add('Test2');
  L.Clear;
  Should(L.Count).Be(0);
  // No crash = strings were properly finalized
end;

procedure TListStringTests.IndexOf_StringShouldMatch;
var
  L: IList<string>;
begin
  L := TCollections.CreateList<string>;
  L.Add('Apple');
  L.Add('Banana');
  L.Add('Cherry');
  Should(L.IndexOf('Banana')).Be(1);
  Should(L.IndexOf('Grape')).Be(-1);
end;

procedure TListStringTests.ForIn_ShouldIterateStrings;
var
  L: IList<string>;
  Concat: string;
  S: string;
begin
  L := TCollections.CreateList<string>;
  L.Add('A');
  L.Add('B');
  L.Add('C');
  Concat := '';
  for S in L do
    Concat := Concat + S;
  Should(Concat).Be('ABC');
end;

procedure TListStringTests.ToArray_ShouldCopyStrings;
var
  L: IList<string>;
  Arr: TArray<string>;
begin
  L := TCollections.CreateList<string>;
  L.Add('X');
  L.Add('Y');
  Arr := L.ToArray;
  Should(Length(Arr)).Be(2);
  Should(Arr[0]).Be('X');
  Should(Arr[1]).Be('Y');
end;

{ TListInterfaceTests }

procedure TListInterfaceTests.Add_InterfaceShouldBeRefCounted;
var
  L: IList<IValueHolder>;
  V: IValueHolder;
begin
  L := TCollections.CreateList<IValueHolder>;
  V := TValueHolder.Create(42);
  L.Add(V);
  Should(L.Count).Be(1);
  Should(L[0].Value).Be(42);
end;

procedure TListInterfaceTests.Clear_ShouldReleaseInterfaces;
var
  L: IList<IValueHolder>;
begin
  L := TCollections.CreateList<IValueHolder>;
  L.Add(TValueHolder.Create(1));
  L.Add(TValueHolder.Create(2));
  L.Clear;
  Should(L.Count).Be(0);
  // No leak = interfaces were properly released
end;

procedure TListInterfaceTests.ForIn_ShouldIterateInterfaces;
var
  L: IList<IValueHolder>;
  Sum: Integer;
  V: IValueHolder;
begin
  L := TCollections.CreateList<IValueHolder>;
  L.Add(TValueHolder.Create(10));
  L.Add(TValueHolder.Create(20));
  L.Add(TValueHolder.Create(30));
  Sum := 0;
  for V in L do
    Sum := Sum + V.Value;
  Should(Sum).Be(60);
end;

{ TListOwnershipTests }

procedure TListOwnershipTests.Setup;
begin
  TDummyObject.InstanceCount := 0;
end;

procedure TListOwnershipTests.OwnsObjects_ShouldFreeOnRemove;
var
  L: IList<TDummyObject>;
  Obj: TDummyObject;
begin
  L := TCollections.CreateList<TDummyObject>(True);
  Obj := TDummyObject.Create(1);
  L.Add(Obj);
  Should(TDummyObject.InstanceCount).Be(1);
  L.Remove(Obj);
  Should(TDummyObject.InstanceCount).Be(0);
end;

procedure TListOwnershipTests.OwnsObjects_ShouldFreeOnClear;
var
  L: IList<TDummyObject>;
begin
  L := TCollections.CreateList<TDummyObject>(True);
  L.Add(TDummyObject.Create(1));
  L.Add(TDummyObject.Create(2));
  L.Add(TDummyObject.Create(3));
  Should(TDummyObject.InstanceCount).Be(3);
  L.Clear;
  Should(TDummyObject.InstanceCount).Be(0);
end;

procedure TListOwnershipTests.NoOwnership_ShouldNotFreeOnClear;
var
  L: IList<TDummyObject>;
  Obj1, Obj2: TDummyObject;
begin
  L := TCollections.CreateList<TDummyObject>(False);
  Obj1 := TDummyObject.Create(1);
  Obj2 := TDummyObject.Create(2);
  try
    L.Add(Obj1);
    L.Add(Obj2);
    L.Clear;
    Should(TDummyObject.InstanceCount).Be(2); // Still alive
  finally
    Obj1.Free;
    Obj2.Free;
  end;
end;

procedure TListOwnershipTests.Extract_ShouldNotFreeObject;
var
  L: IList<TDummyObject>;
  Obj: TDummyObject;
  Extracted: TDummyObject;
begin
  L := TCollections.CreateList<TDummyObject>(True);
  Obj := TDummyObject.Create(42);
  L.Add(Obj);
  Extracted := L.Extract(Obj);
  try
    Should(TDummyObject.InstanceCount).Be(1); // Still alive
    Should(Extracted.Value).Be(42);
    Should(L.Count).Be(0);
  finally
    Extracted.Free;
  end;
end;

{ TListEnumeratorTests }

procedure TListEnumeratorTests.ForIn_EmptyListShouldNotIterate;
var
  L: IList<Integer>;
  Count: Integer;
  V: Integer;
begin
  L := TCollections.CreateList<Integer>;
  Count := 0;
  for V in L do
    Inc(Count);
  Should(Count).Be(0);
end;

procedure TListEnumeratorTests.ForIn_ShouldVisitAllItems;
var
  L: IList<Integer>;
  Sum: Integer;
  V: Integer;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(1);
  L.Add(2);
  L.Add(3);
  L.Add(4);
  L.Add(5);
  Sum := 0;
  for V in L do
    Sum := Sum + V;
  Should(Sum).Be(15);
end;

procedure TListEnumeratorTests.ForIn_SingleItemShouldWork;
var
  L: IList<Integer>;
  Sum: Integer;
  V: Integer;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(42);
  Sum := 0;
  for V in L do
    Sum := Sum + V;
  Should(Sum).Be(42);
end;

{ TListLinqTests }

procedure TListLinqTests.Where_ShouldFilterItems;
var
  L, Filtered: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(1);
  L.Add(2);
  L.Add(3);
  L.Add(4);
  L.Add(5);
  Filtered := L.Where(
    function(V: Integer): Boolean
    begin
      Result := V > 3;
    end);
  Should(Filtered.Count).Be(2);
  Should(Filtered[0]).Be(4);
  Should(Filtered[1]).Be(5);
end;

procedure TListLinqTests.Any_ShouldReturnTrueIfMatch;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(1);
  L.Add(2);
  L.Add(3);
  Should(L.Any(
    function(V: Integer): Boolean
    begin
      Result := V = 2;
    end)).BeTrue;
end;

procedure TListLinqTests.Any_ShouldReturnFalseIfNoMatch;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(1);
  L.Add(2);
  Should(L.Any(
    function(V: Integer): Boolean
    begin
      Result := V = 99;
    end)).BeFalse;
end;

procedure TListLinqTests.All_ShouldReturnTrueIfAllMatch;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(2);
  L.Add(4);
  L.Add(6);
  Should(L.All(
    function(V: Integer): Boolean
    begin
      Result := V mod 2 = 0;
    end)).BeTrue;
end;

procedure TListLinqTests.All_ShouldReturnFalseIfNotAllMatch;
var
  L: IList<Integer>;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(2);
  L.Add(3);
  L.Add(4);
  Should(L.All(
    function(V: Integer): Boolean
    begin
      Result := V mod 2 = 0;
    end)).BeFalse;
end;

procedure TListLinqTests.ForEach_ShouldVisitAllItems;
var
  L: IList<Integer>;
  Sum: Integer;
begin
  L := TCollections.CreateList<Integer>;
  L.Add(10);
  L.Add(20);
  L.Add(30);
  Sum := 0;
  L.ForEach(
    procedure(V: Integer)
    begin
      Sum := Sum + V;
    end);
  Should(Sum).Be(60);
end;

{ TListIObjectListTests }

procedure TListIObjectListTests.Cast_ToIObjectList_ShouldBeValid;
var
  L: IList<TDummyObject>;
begin
  L := TCollections.CreateList<TDummyObject>;
  Should(Supports(L, IObjectList)).BeTrue;
  Should(L as IObjectList).NotBeNil;
end;

procedure TListIObjectListTests.IObjectList_Add_ShouldWork;
var
  L: IList<TDummyObject>;
  OI: IObjectList;
  D: TDummyObject;
begin
  L := TCollections.CreateList<TDummyObject>(True);
  OI := L as IObjectList;
  D := TDummyObject.Create(10);
  OI.Add(D);
  Should(L.Count).Be(1);
  Should(L[0].Value).Be(10);
end;

procedure TListIObjectListTests.IObjectList_GetItem_ShouldWork;
var
  L: IList<TDummyObject>;
  OI: IObjectList;
  D: TDummyObject;
begin
  L := TCollections.CreateList<TDummyObject>(True);
  D := TDummyObject.Create(10);
  L.Add(D);
  OI := L as IObjectList;
  Should(OI.GetItem(0)).BeEquivalentTo(D);
end;

procedure TListIObjectListTests.IObjectList_IndexOf_ShouldWork;
var
  L: IList<TDummyObject>;
  OI: IObjectList;
  D: TDummyObject;
begin
  L := TCollections.CreateList<TDummyObject>(True);
  D := TDummyObject.Create(10);
  L.Add(D);
  OI := L as IObjectList;
  Should(OI.IndexOf(D)).Be(0);
end;

procedure TListIObjectListTests.IObjectList_Insert_ShouldWork;
var
  L: IList<TDummyObject>;
  OI: IObjectList;
  D1, D2: TDummyObject;
begin
  L := TCollections.CreateList<TDummyObject>(True);
  D1 := TDummyObject.Create(1);
  D2 := TDummyObject.Create(2);
  L.Add(D1);
  OI := L as IObjectList;
  OI.Insert(0, D2);
  Should(L.Count).Be(2);
  Should(L[0]).BeEquivalentTo(D2);
  Should(L[1]).BeEquivalentTo(D1);
end;

procedure TListIObjectListTests.IObjectList_Delete_ShouldWork;
var
  L: IList<TDummyObject>;
  OI: IObjectList;
begin
  L := TCollections.CreateList<TDummyObject>(True);
  L.Add(TDummyObject.Create(1));
  L.Add(TDummyObject.Create(2));
  OI := L as IObjectList;
  OI.Delete(0);
  Should(L.Count).Be(1);
  Should(OI.GetItem(0)).BeEquivalentTo(TDummyObject(OI.GetItem(0))); // Just check valid ref
  Should(TDummyObject(OI.GetItem(0)).Value).Be(2);
end;

end.
