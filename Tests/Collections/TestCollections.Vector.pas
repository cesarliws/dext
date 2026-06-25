unit TestCollections.Vector;

interface

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Core.Span,
  Dext.Collections.Vector;

type
  [TestFixture('Collections - Vector')]
  TVectorTests = class
  public
    [Test]
    procedure Add_ShouldStoreValue;
    [Test]
    procedure Add_ShouldTriggerHeapAllocationAfterSVO;
    [Test]
    procedure Clear_ShouldResetCountAndFreeHeap;
    [Test]
    procedure ToArray_ShouldCopyData;
  end;

implementation

{ TVectorTests }

procedure TVectorTests.Add_ShouldStoreValue;
var
  V: TVector<Integer>;
begin
  V.Add(10);
  Should(V.Count).Be(1);
  Should(V[0]).Be(10);
end;

procedure TVectorTests.Add_ShouldTriggerHeapAllocationAfterSVO;
var
  V: TVector<Integer>;
  I: Integer;
begin
  // SVO_BUFFER_SIZE in TVector is 64 bytes. For Integers (4 bytes), SVO supports 16 items.
  for I := 1 to 20 do
    V.Add(I);
    
  Should(V.Count).Be(20);
  Should(V[19]).Be(20);
  Should(V.Capacity).BeGreaterThan(16); // Heap transitioned
end;

procedure TVectorTests.Clear_ShouldResetCountAndFreeHeap;
var
  V: TVector<Integer>;
begin
  V.Add(1);
  V.Clear;
  Should(V.Count).Be(0);
  Should(V.Capacity).Be(16);
end;

procedure TVectorTests.ToArray_ShouldCopyData;
var
  V: TVector<Integer>;
  Arr: TArray<Integer>;
begin
  V.Add(10);
  V.Add(20);
  Arr := V.ToArray;
  
  Should(Length(Arr)).Be(2);
  Should(Arr[0]).Be(10);
  Should(Arr[1]).Be(20);
end;

end.
