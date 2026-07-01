unit EntityDemo.Tests.MixedCompositeKeys;

interface

uses
  System.SysUtils,
  System.Variants,
  EntityDemo.Tests.Base,
  EntityDemo.Entities;

type
  TMixedCompositeKeyTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

procedure TMixedCompositeKeyTest.Run;
var
  Entity: TMixedKeyEntity;
  Found: TMixedKeyEntity;
begin
  Log('🔑 Running Mixed Composite Key Tests...');
  Entity := TMixedKeyEntity.Create;
  Entity.Key1 := 10;
  Entity.Key2 := 'ABC';
  Entity.Value := 'Test Value';

  FContext.Entities<TMixedKeyEntity>.Add(Entity);
  FContext.SaveChanges;

  // This expects Find to handle array of Variant
  Found := FContext.Entities<TMixedKeyEntity>.Find([10, 'ABC']);

  AssertTrue(Found <> nil, 'Found entity by mixed keys', 'Entity not found');
  if Found <> nil then
  begin
      AssertTrue(Found.Value = 'Test Value', 'Value matches', Found.Value);
      AssertTrue(Found.Key1 = 10, 'Key1 matches', IntToStr(Found.Key1));
      AssertTrue(Found.Key2 = 'ABC', 'Key2 matches', Found.Key2);
  end;
end;

end.
