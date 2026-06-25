unit TestCollections.Algorithms;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Collections.Comparers,
  Dext.Testing,
  Dext.Collections.Algorithms,
  Dext.Collections.Simd;

type
  [TestFixture('Collections - Algorithms')]
  TAlgorithmsTests = class
  public
    [Test]
    procedure Sort_ShouldSortIntegersCorrectly;
    [Test]
    procedure Sort_ShouldSortStringsCorrectly;
    [Test]
    procedure IndexOf_ShouldFindExistingElement;
    [Test]
    procedure IndexOfByte_ShouldUseFastPath;
    [Test]
    procedure BinarySearch_ShouldFindExistingElement;
    [Test]
    procedure BinarySearch_ShouldReturnFalseIfNotFound;
  end;

implementation

{ TAlgorithmsTests }

procedure TAlgorithmsTests.Sort_ShouldSortIntegersCorrectly;
var
  Arr: TArray<Integer>;
begin
  Arr := [5, 2, 9, 1, 5, 6];
  TDextSort.Sort<Integer>(Arr, TComparer<Integer>.Default);
  Should(Arr[0]).Be(1);
  Should(Arr[1]).Be(2);
  Should(Arr[2]).Be(5);
  Should(Arr[3]).Be(5);
  Should(Arr[4]).Be(6);
  Should(Arr[5]).Be(9);
end;

procedure TAlgorithmsTests.Sort_ShouldSortStringsCorrectly;
var
  Arr: TArray<string>;
begin
  Arr := ['banana', 'apple', 'cherry', 'date'];
  TDextSort.Sort<string>(Arr, TComparer<string>.Default);
  Should(Arr[0]).Be('apple');
  Should(Arr[1]).Be('banana');
  Should(Arr[2]).Be('cherry');
  Should(Arr[3]).Be('date');
end;

procedure TAlgorithmsTests.IndexOf_ShouldFindExistingElement;
var
  Arr: TArray<Integer>;
  Idx: Integer;
begin
  Arr := [10, 20, 30, 40];
  Idx := TDextSearch.IndexOf<Integer>(Arr, 30);
  Should(Idx).Be(2);
  
  Idx := TDextSearch.IndexOf<Integer>(Arr, 50);
  Should(Idx).Be(-1);
end;

procedure TAlgorithmsTests.IndexOfByte_ShouldUseFastPath;
var
  Arr: TArray<Byte>;
  Idx: Integer;
begin
  Arr := [10, 20, 30, 255];
  Idx := TDextSearch.IndexOf<Byte>(Arr, 255);
  Should(Idx).Be(3);
end;

procedure TAlgorithmsTests.BinarySearch_ShouldFindExistingElement;
var
  Arr: TArray<Integer>;
  Found: Boolean;
  FoundIdx: Integer;
begin
  Arr := [10, 20, 30, 40, 50]; // Must be sorted
  Found := TDextSearch.BinarySearch<Integer>(Arr, 30, FoundIdx);
  Should(Found).BeTrue;
  Should(FoundIdx).Be(2);
end;

procedure TAlgorithmsTests.BinarySearch_ShouldReturnFalseIfNotFound;
var
  Arr: TArray<Integer>;
  Found: Boolean;
  FoundIdx: Integer;
begin
  Arr := [10, 20, 30, 40, 50];
  Found := TDextSearch.BinarySearch<Integer>(Arr, 35, FoundIdx);
  Should(Found).BeFalse;
  Should(FoundIdx).Be(3); // The index where it should be inserted
end;

end.
