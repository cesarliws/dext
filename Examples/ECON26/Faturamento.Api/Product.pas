unit Product;

interface

uses
  Dext,
  Dext.Entity,
  Dext.Core.SmartTypes,
  Dext.Web,
  Dext.Web.DataApi;

type
  TBuscaProduto = record
    [FromQuery]
    Termo: string;
  end;

  [Table('Products'), DataApi('/api/products')]
  TProduct = class
  private
    FId: IntType;
    FName: StringType;
    FPrice: CurrencyType;
    FActive: BoolType;
    FCost: CurrencyType;
  public
    [PK, AutoInc]
    property Id: IntType read FId write FId;
    property Name: StringType read FName write FName;
    property Price: CurrencyType read FPrice write FPrice;
    property Active: BoolType read FActive write FActive;
    [JsonIgnore]
    property Cost: CurrencyType read FCost write FCost;
  end;

implementation

end.
