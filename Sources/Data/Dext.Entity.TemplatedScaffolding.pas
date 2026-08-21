unit Dext.Entity.TemplatedScaffolding;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Dext.Collections,
  Dext.Entity.Scaffolding,
  Dext.Scaffolding.Models,
  Dext.Entity.Scaffolding.Processor,
  Dext.Templating;

type
  TGenerationMode = (gmSingleFile, gmMultipleFiles);

  TTemplatedEntityGenerator = class
  private
    FEngine: ITemplateEngine;
    function CleanName(const AName: string; ASingularize: Boolean = False): string;
    function SQLTypeToDelphiType(const ASQLType: string; APrecision: Integer = 0; AScale: Integer = 0): string;
    function CreateTableViewModel(const AMeta: TMetaTable): TTableViewModel;
  public
    constructor Create;
    procedure Generate(const ASchema: ISchemaProvider; const ATemplatePath, AOutputDir: string; AMode: TGenerationMode = gmMultipleFiles);
  end;

implementation

uses
  Dext.Utils;

{ TTemplatedEntityGenerator }

constructor TTemplatedEntityGenerator.Create;
begin
  FEngine := TTemplating.CreateEngine;
end;

function TTemplatedEntityGenerator.CleanName(const AName: string; ASingularize: Boolean): string;
var
  Parts: TArray<string>;
  S, Cleaned: string;
begin
  Result := '';
  Cleaned := AName.Replace('"', '').Replace('''', '').Replace('[', '').Replace(']', '');
  
  if Cleaned.Contains('.') then
  begin
    Parts := Cleaned.Split(['.']);
    Cleaned := Parts[High(Parts)];
  end;
  
  Parts := Cleaned.Split(['_', '-', ' '], TStringSplitOptions.ExcludeEmpty);
  for S in Parts do
    if S.Length > 0 then
      Result := Result + UpperCase(S.Chars[0]) + S.Substring(1).ToLower;

  if ASingularize then
  begin
    if Result.EndsWith('ies', True) then
      Result := Result.Substring(0, Result.Length - 3) + 'y'
    else if Result.EndsWith('s', True) and not Result.EndsWith('ss', True) then
      Result := Result.Substring(0, Result.Length - 1);
  end;
end;

function TTemplatedEntityGenerator.SQLTypeToDelphiType(const ASQLType: string; APrecision: Integer; AScale: Integer): string;
var
  S: string;
begin
  S := ASQLType.Trim.ToUpper;

  if S.Contains('JSON') then Exit('string');

  if S.Contains('RAW') or S.Contains('GUID') or S.Contains('UUID') then
  begin
    if (APrecision = 16) or (S = 'RAW(16)') or S.Contains('GUID') or S.Contains('UUID') then
      Exit('TGUID');
    Exit('TBytes');
  end;

  if S.Contains('NUMBER') or S.Contains('NUMERIC') or S.Contains('DECIMAL') then
  begin
    if (APrecision <= 0) and (AScale < 0) then
      Exit('Double');

    if AScale = 0 then
    begin
      if APrecision = 1 then Exit('Boolean')
      else if (APrecision > 0) and (APrecision <= 4) then Exit('SmallInt')
      else if (APrecision > 4) and (APrecision <= 9) then Exit('Integer')
      else Exit('Int64');
    end
    else if AScale > 0 then
    begin
      if (AScale <= 4) and (APrecision <= 18) then Exit('Currency')
      else Exit('Double');
    end;
  end;

  if S.Contains('INT') or S.Contains('SERIAL') or S.Contains('COUNTER') or S.Contains('ROWID') then
  begin
    if S.Contains('64') or S.Contains('BIG') then Exit('Int64');
    if S.Contains('SMALL') or S.Contains('SHORT') or S.Contains('TINY') then Exit('SmallInt');
    Exit('Integer');
  end;

  if S.Contains('BOOL') or S.Contains('BIT') or S.Contains('LOGICAL') then Exit('Boolean');

  if S.Contains('TIMESTAMP') or (S = 'DATE') or (S.Contains('DATE') and S.Contains('TIME')) then Exit('TDateTime');
  if S.Contains('DATE') then Exit('TDate');
  if S.Contains('TIME') then Exit('TTime');

  if S.Contains('FLOAT') or S.Contains('DOUBLE') or S.Contains('REAL') then Exit('Double');

  if S.Contains('BLOB') or S.Contains('BYTEA') or S.Contains('BINARY') or S.Contains('IMAGE') or S.Contains('VARBINARY') or S.Contains('BFILE') then Exit('TBytes');

  Result := 'string';
end;

function TTemplatedEntityGenerator.CreateTableViewModel(const AMeta: TMetaTable): TTableViewModel;
var
  MetaCol: TMetaColumn;
  Col: TColumnViewModel;
  MetaFK: TMetaForeignKey;
  FK: TFKViewModel;
  NavProp: string;
begin
  Result := TTableViewModel.Create;
  Result.Name := AMeta.Name;
  Result.DelphiClassName := 'T' + CleanName(AMeta.Name, True);
  Result.DelphiUnitName := CleanName(AMeta.Name);
  Result.DelphiNamespace := 'Dext.Data.Entities'; // Default namespace for entities
  
  for MetaCol in AMeta.Columns do
  begin
    Col := TColumnViewModel.Create;
    Col.Name := MetaCol.Name;
    Col.DelphiName := CleanName(MetaCol.Name);
    Col.DataType := MetaCol.DataType;
    Col.DelphiType := SQLTypeToDelphiType(MetaCol.DataType, MetaCol.Precision, MetaCol.Scale);
    Col.IsPrimaryKey := MetaCol.IsPrimaryKey;
    Col.IsAutoInc := MetaCol.IsAutoInc;
    Col.IsNullable := MetaCol.IsNullable;
    Col.Length := MetaCol.Length;
    Col.Precision := MetaCol.Precision;
    Col.Scale := MetaCol.Scale;
    Result.Columns.Add(Col);
  end;
  
  for MetaFK in AMeta.ForeignKeys do
  begin
    FK := TFKViewModel.Create;
    FK.Name := MetaFK.Name;
    FK.ColumnName := MetaFK.ColumnName;
    FK.ReferencedTable := MetaFK.ReferencedTable;
    FK.ReferencedClass := 'T' + CleanName(MetaFK.ReferencedTable);
    
    NavProp := CleanName(MetaFK.ColumnName);
    if NavProp.EndsWith('Id', True) then
       NavProp := NavProp.Substring(0, NavProp.Length - 2);
    if (NavProp = '') or SameText(NavProp, 'Id') then
       NavProp := CleanName(MetaFK.ReferencedTable);
       
    FK.PropertyName := NavProp;
    Result.ForeignKeys.Add(FK);
  end;
end;

procedure TTemplatedEntityGenerator.Generate(const ASchema: ISchemaProvider; const ATemplatePath, AOutputDir: string; AMode: TGenerationMode);
var
  TableNames: TArray<string>;
  TableMetaList: IList<TMetaTable>;
  RootModel: TScaffoldViewModel;
  Processor: TScaffoldingMetadataProcessor;
  Context: ITemplateContext;
  TemplateContent: string;
  OutputContent: string;
  TableName: string;
  Meta: TMetaTable;
  TableVM: TTableViewModel;
  FileName: string;
begin
  if not TFile.Exists(ATemplatePath) then
    raise Exception.Create('Template not found: ' + ATemplatePath);
    
  TemplateContent := TFile.ReadAllText(ATemplatePath);
  TableNames := ASchema.GetTables;
  TableMetaList := TCollections.CreateList<TMetaTable>;
  RootModel := TScaffoldViewModel.Create;
  try
    ForceDirectories(AOutputDir);

    // Step 1: Collect all metadata and create initial ViewModels
    for TableName in TableNames do
    begin
      Meta := ASchema.GetTableMetadata(TableName);
      TableMetaList.Add(Meta);
      RootModel.Tables.Add(CreateTableViewModel(Meta));
    end;

    // Step 2: Process Relationships (Join tables, M2M, etc.)
    Processor := TScaffoldingMetadataProcessor.Create(RootModel);
    try
      Processor.Process(TableMetaList.ToArray);
    finally
      Processor.Free;
    end;

    // Step 3: Render and Save
    if AMode = gmMultipleFiles then
    begin
      for TableVM in RootModel.Tables do
      begin
        if TableVM.IsJoinTable then Continue; // Skip Join Tables generation
        
        Context := TTemplating.CreateContext;
        Context.SetObject('Model', TableVM);
        
        OutputContent := FEngine.Render(TemplateContent, Context);
        FileName := TPath.Combine(AOutputDir, TableVM.DelphiUnitName + '.pas');
        TFile.WriteAllText(FileName, OutputContent);
      end;
    end
    else
    begin
      Context := TTemplating.CreateContext;
      Context.SetObject('Model', RootModel);
      
      OutputContent := FEngine.Render(TemplateContent, Context);
      FileName := TPath.Combine(AOutputDir, 'Entities.pas');
      TFile.WriteAllText(FileName, OutputContent);
    end;
  finally
    RootModel.Free;
  end;
end;

end.
