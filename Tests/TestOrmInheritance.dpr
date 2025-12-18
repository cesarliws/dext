program TestOrmInheritance;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  Dext,
  Dext.Entity.Mapping,
  Dext.Specifications.SQL.Generator,
  Dext.Entity.Dialects;

type
  { Base Class }
  TAnimal = class
  private
    FId: Integer;
    FName: string;
  public
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
  end;

  { Derived Class (TPH) }
  TDog = class(TAnimal)
  private
    FBreed: string;
  public
    property Breed: string read FBreed write FBreed;
  end;

  TCat = class(TAnimal)
  private
    FColor: string;
  public
    property Color: string read FColor write FColor;
  end;

  { Configuration }
  TAnimalConfig = class(TEntityTypeConfiguration<TAnimal>)
  public
    procedure Configure(Builder: IEntityTypeBuilder<TAnimal>); override;
  end;

  TDogConfig = class(TEntityTypeConfiguration<TDog>)
  public
    procedure Configure(Builder: IEntityTypeBuilder<TDog>); override;
  end;

  TCatConfig = class(TEntityTypeConfiguration<TCat>)
  public
    procedure Configure(Builder: IEntityTypeBuilder<TCat>); override;
  end;

{ TAnimalConfig }
procedure TAnimalConfig.Configure(Builder: IEntityTypeBuilder<TAnimal>);
begin
  Builder.ToTable('Animals');
  Builder.HasKey('Id');
  Builder.Prop('Name').HasMaxLength(100);
  
  // TPH Configuration: Discriminator Column is 'Type'
  // Base class mapping doesn't necessarily set discriminator value for itself unless it's abstract or instantiated.
  // But Dext requires Discriminator setup here for children to inherit?
  // Actually, HasDiscriminator is usually called on Base specific config or specific type.
  // Let's assume we configure it here for the hierarchy?
  // No, Builder<T> is for T.
  // We need to configure inheritance strategy on root?
end;

{ TDogConfig }
procedure TDogConfig.Configure(Builder: IEntityTypeBuilder<TDog>);
begin
  // Set Discriminator Value for Dog
  Builder.HasDiscriminator('Type', 'Dog');
end;

{ TCatConfig }
procedure TCatConfig.Configure(Builder: IEntityTypeBuilder<TCat>);
begin
  Builder.HasDiscriminator('Type', 'Cat');
end;

var
  ModelBuilder: TModelBuilder;
  DogGenerator: TSQLGenerator<TDog>;
  CatGenerator: TSQLGenerator<TCat>;
  SQL: string;
  Dialect: ISQLDialect;
begin
  try
    Writeln('Testing ORM Inheritance (TPH)...');

    // Setup Model
    ModelBuilder := TModelBuilder.Create;
    try
      ModelBuilder.ApplyConfiguration<TAnimal>(TAnimalConfig.Create);
      ModelBuilder.ApplyConfiguration<TDog>(TDogConfig.Create);
      ModelBuilder.ApplyConfiguration<TCat>(TCatConfig.Create);

      Dialect := TSQLiteDialect.Create; // Use SQLite for generated SQL check

      // Test Dog Insert (should include Type='Dog')
      Writeln('Generating Dog Insert...');
      DogGenerator := TSQLGenerator<TDog>.Create(Dialect, ModelBuilder.GetMap(TypeInfo(TDog)));
      try
        var Dog := TDog.Create;
        Dog.Id := 1;
        Dog.Name := 'Rex';
        Dog.Breed := 'German Shepherd';
        
        SQL := DogGenerator.GenerateInsert(Dog);
        Writeln('SQL: ' + SQL);
        
        if (SQL.Contains('"Type"')) and (SQL.Contains('''Dog''')) then
          Writeln('[PASS] Discriminator column and value present.')
        else
          Writeln('[FAIL] Discriminator missing.');
          
        Dog.Free;
      finally
        DogGenerator.Free;
      end;

      // Test Cat Select (should include WHERE Type='Cat')
      Writeln('Generating Cat Select...');
      CatGenerator := TSQLGenerator<TCat>.Create(Dialect, ModelBuilder.GetMap(TypeInfo(TCat)));
      try
        SQL := CatGenerator.GenerateSelect;
        Writeln('SQL: ' + SQL);
        
        if (SQL.Contains('WHERE "Type" = ''Cat''')) then
           Writeln('[PASS] Discriminator filter present.')
        else
           Writeln('[FAIL] Discriminator filter missing.');

      finally
        CatGenerator.Free;
      end;
      
    finally
      ModelBuilder.Free;
    end;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  ReadLn;
end.
