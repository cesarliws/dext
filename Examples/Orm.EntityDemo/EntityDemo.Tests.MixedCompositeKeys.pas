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
begin
  Log('?? Running Mixed Composite Key Tests...');
  var Entity := TMixedKeyEntity.Create;
  Entity.Key1 := 10;
  Entity.Key2 := 'ABC';
  Entity.Value := 'Test Value';

  try
    FContext.Entities<TMixedKeyEntity>.Add(Entity);
    FContext.SaveChanges;
    
    // This expects Find to handle array of Variant
    var Found := FContext.Entities<TMixedKeyEntity>.Find([10, 'ABC']);
    
    AssertTrue(Found <> nil, 'Found entity by mixed keys', 'Entity not found');
    if Found <> nil then
    begin
        AssertTrue(Found.Value = 'Test Value', 'Value matches', Found.Value);
        AssertTrue(Found.Key1 = 10, 'Key1 matches', IntToStr(Found.Key1));
        AssertTrue(Found.Key2 = 'ABC', 'Key2 matches', Found.Key2);
    end;
  finally
    // Entity needs to be freed manually because composite key entities are not currently managed by IdentityMap after insertion
    Entity.Free;
  end;
end;

end.
