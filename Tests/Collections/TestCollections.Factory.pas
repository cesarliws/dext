{***************************************************************************}
{                                                                           }
{           Dext Framework - Collections Unit Tests                         }
{                                                                           }
{           Tests for TElementCategoryHelper (Code Folding Classifier)      }
{                                                                           }
{***************************************************************************}
unit TestCollections.Factory;

interface

uses
  System.SysUtils,
  System.TypInfo,
  Dext.Testing,
  Dext.Collections.Factory;

type
  TManagedRecord = record
    S: string;
    I: Integer;
  end;

  TPlainRecord = record
    A, B, C: Integer;
  end;

  IMyIntf = interface
    ['{12345678-1234-1234-1234-123456789012}']
  end;

  [TestFixture('Collections - Type Factory (Code Folding)')]
  TFactoryTests = class
  public
    [Test]
    procedure Classify_Integer_ShouldBeUnmanaged4;

    [Test]
    procedure Classify_Byte_ShouldBeUnmanaged1;

    [Test]
    procedure Classify_Int64_ShouldBeUnmanaged8;

    [Test]
    procedure Classify_String_ShouldBeString;

    [Test]
    procedure Classify_Interface_ShouldBeInterface;

    [Test]
    procedure Classify_Class_ShouldBeReference;

    [Test]
    procedure Classify_PlainRecord_ShouldBeUnmanagedN;

    [Test]
    procedure Classify_ManagedRecord_ShouldBeManagedRecord;

    [Test]
    procedure IsManaged_ShouldReturnTrueForStringsAndInterfaces;

    [Test]
    procedure IsManaged_ShouldReturnFalseForIntegers;

    [Test]
    procedure IsReference_ShouldReturnTrueForClassesAndInterfaces;
  end;

implementation

{ TFactoryTests }

procedure TFactoryTests.Classify_Integer_ShouldBeUnmanaged4;
begin
  Should(TElementCategoryHelper.Classify(TypeInfo(Integer), SizeOf(Integer)))
    .Be(ecUnmanaged4);
end;

procedure TFactoryTests.Classify_Byte_ShouldBeUnmanaged1;
begin
  Should(TElementCategoryHelper.Classify(TypeInfo(Byte), SizeOf(Byte)))
    .Be(ecUnmanaged1);
end;

procedure TFactoryTests.Classify_Int64_ShouldBeUnmanaged8;
begin
  Should(TElementCategoryHelper.Classify(TypeInfo(Int64), SizeOf(Int64)))
    .Be(ecUnmanaged8);
end;

procedure TFactoryTests.Classify_String_ShouldBeString;
begin
  Should(TElementCategoryHelper.Classify(TypeInfo(string), SizeOf(string)))
    .Be(ecString);
end;

procedure TFactoryTests.Classify_Interface_ShouldBeInterface;
begin
  Should(TElementCategoryHelper.Classify(TypeInfo(IMyIntf), SizeOf(IMyIntf)))
    .Be(ecInterface);
end;

procedure TFactoryTests.Classify_Class_ShouldBeReference;
begin
  Should(TElementCategoryHelper.Classify(TypeInfo(TObject), SizeOf(TObject)))
    .Be(ecObject);
end;

procedure TFactoryTests.Classify_PlainRecord_ShouldBeUnmanagedN;
begin
  Should(TElementCategoryHelper.Classify(TypeInfo(TPlainRecord), SizeOf(TPlainRecord)))
    .Be(ecUnmanagedN);
end;

procedure TFactoryTests.Classify_ManagedRecord_ShouldBeManagedRecord;
begin
  Should(TElementCategoryHelper.Classify(TypeInfo(TManagedRecord), SizeOf(TManagedRecord)))
    .Be(ecManagedRecord);
end;

procedure TFactoryTests.IsManaged_ShouldReturnTrueForStringsAndInterfaces;
begin
  Should(TElementCategoryHelper.IsManaged(ecString)).BeTrue;
  Should(TElementCategoryHelper.IsManaged(ecInterface)).BeTrue;
  Should(TElementCategoryHelper.IsManaged(ecManagedRecord)).BeTrue;
end;

procedure TFactoryTests.IsManaged_ShouldReturnFalseForIntegers;
begin
  Should(TElementCategoryHelper.IsManaged(ecUnmanaged4)).BeFalse;
end;

procedure TFactoryTests.IsReference_ShouldReturnTrueForClassesAndInterfaces;
begin
  Should(TElementCategoryHelper.IsReference(ecObject)).BeTrue;
  Should(TElementCategoryHelper.IsReference(ecInterface)).BeTrue;
  Should(TElementCategoryHelper.IsReference(ecString)).BeFalse;
end;

end.
