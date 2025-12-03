unit EntityDemo.Tests.Scaffolding;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Dext.Entity,
  Dext.Entity.Scaffolding,
  EntityDemo.Tests.Base;

type
  TScaffoldingTest = class(TBaseTest)
  public
    procedure Run; override;
  end;

implementation

procedure TScaffoldingTest.Run;
var
  Provider: ISchemaProvider;
  Generator: IEntityGenerator;
  Tables: TArray<string>;
  TableMeta: TMetaTable;
  MetaList: TArray<TMetaTable>;
  Code: string;
begin
  Log('🏗️ Running Scaffolding Tests...');
  
  // Ensure database exists and has schema
  Setup;
  
  // 1. Test Schema Provider
  Provider := TFireDACSchemaProvider.Create(FContext.Connection);
  
  Tables := Provider.GetTables;
  Log(Format('   Found %d tables.', [Length(Tables)]));
  
  SetLength(MetaList, Length(Tables));
  
  for var i := 0 to High(Tables) do
  begin
    Log('   - Table: ' + Tables[i]);
    TableMeta := Provider.GetTableMetadata(Tables[i]);
    MetaList[i] := TableMeta;
    
    Log(Format('     Columns: %d', [Length(TableMeta.Columns)]));
    for var Col in TableMeta.Columns do
    begin
      var Flags := '';
      if Col.IsPrimaryKey then Flags := Flags + ' [PK]';
      if Col.IsAutoInc then Flags := Flags + ' [AutoInc]';
      if Col.IsNullable then Flags := Flags + ' [Null]';
      Log(Format('       %s (%s)%s', [Col.Name, Col.DataType, Flags]));
    end;
    
    Log(Format('     FKs: %d', [Length(TableMeta.ForeignKeys)]));
    for var FK in TableMeta.ForeignKeys do
      Log(Format('       %s -> %s.%s', [FK.ColumnName, FK.ReferencedTable, FK.ReferencedColumn]));
  end;
  
  // 2. Test Generator
  Generator := TDelphiEntityGenerator.Create;
  Code := Generator.GenerateUnit('GeneratedEntities', MetaList);
  
  Log('   Generated Code Preview (First 500 chars):');
  Log(Copy(Code, 1, 500));
  
  // Save to file for inspection
  var FileName := 'GeneratedEntities.pas';
  TFile.WriteAllText(FileName, Code);
  Log('   Saved to ' + FileName);
  
  Log('');
end;

end.
