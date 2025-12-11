program Orm.SpecificationDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types,
  Dext.Specifications.Expression,
  Dext.Specifications.Base,
  Dext.Specifications.SQL.Generator,
  Dext.Entity.Dialects;

type
  // Domain Entity
  TProduct = class
    Id: Integer;
    Name: string;
    Price: Currency;
    IsActive: Boolean;
    Category: string;
  end;

  // Specification: "Expensive Active Products"
  TExpensiveProductsSpec = class(TSpecification<TProduct>)
  public
    constructor Create(MinPrice: Currency); reintroduce;
  end;

  // Specification: "Products by Category"
  TProductsByCategorySpec = class(TSpecification<TProduct>)
  public
    constructor Create(const Category: string); reintroduce;
  end;

{ TExpensiveProductsSpec }

constructor TExpensiveProductsSpec.Create(MinPrice: Currency);
begin
  inherited Create;
  
  // ✨ The Magic Syntax!
  Where( (Prop('Price') > MinPrice) and (Prop('IsActive') = True) );
end;

{ TProductsByCategorySpec }

constructor TProductsByCategorySpec.Create(const Category: string);
begin
  inherited Create;
  Where( Prop('Category') = Category );
end;

procedure RunDemo;
var
  Spec1, Spec2: ISpecification<TProduct>;
  Generator: TSQLWhereGenerator;
  Dialect: ISQLDialect;
  SQL: string;
  Param: TPair<string, TValue>;
begin
  WriteLn('🚀 Dext Specifications Demo');
  WriteLn('===========================');
  WriteLn;

  Dialect := TSQLiteDialect.Create;
  Generator := TSQLWhereGenerator.Create(Dialect);
  try
    // 1. Use Expensive Products Spec
    WriteLn('1. Building "Expensive Active Products" Spec (Price > 100)...');
    Spec1 := TExpensiveProductsSpec.Create(100.00);
    
    SQL := Generator.Generate(Spec1.GetExpression);
    WriteLn('   Criteria Tree: ', Spec1.GetExpression.ToString);
    WriteLn('   Generated SQL (SQLite): WHERE ', SQL);
    WriteLn('   Parameters:');
    for Param in Generator.Params do
      WriteLn('     :', Param.Key, ' = ', Param.Value.ToString);
      
    WriteLn;

    // 2. Use Category Spec
    WriteLn('2. Building "Electronics" Category Spec...');
    Spec2 := TProductsByCategorySpec.Create('Electronics');
    
    SQL := Generator.Generate(Spec2.GetExpression);
    WriteLn('   Criteria Tree: ', Spec2.GetExpression.ToString);
    WriteLn('   Generated SQL (SQLite): WHERE ', SQL);
    WriteLn('   Parameters:');
    for Param in Generator.Params do
      WriteLn('     :', Param.Key, ' = ', Param.Value.ToString);
      
    WriteLn;
    
    WriteLn('✨ Success! The expression tree was translated to SQL correctly.');
    
  finally
    Generator.Free;
  end;
end;

begin
  try
    RunDemo;
    // ReadLn; // Commented out for automated testing
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
