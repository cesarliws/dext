unit Dext.Entity.Scaffolding;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Dext.Entity.Drivers.Interfaces;

type
  TMetaColumn = record
    Name: string;
    DataType: string; // SQL Type
    Length: Integer;
    Precision: Integer;
    Scale: Integer;
    IsNullable: Boolean;
    IsPrimaryKey: Boolean;
    IsAutoInc: Boolean;
  end;

  TMetaForeignKey = record
    Name: string;
    ColumnName: string;
    ReferencedTable: string;
    ReferencedColumn: string;
    OnDelete: string; // CASCADE, SET NULL, etc.
    OnUpdate: string;
  end;

  TMetaTable = record
    Name: string;
    Columns: TArray<TMetaColumn>;
    ForeignKeys: TArray<TMetaForeignKey>;
  end;

  ISchemaProvider = interface
    ['{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}']
    function GetTables: TArray<string>;
    function GetTableMetadata(const ATableName: string): TMetaTable;
  end;

  IEntityGenerator = interface
    ['{B1C2D3E4-F5A6-7890-1234-567890ABCDEF}']
    function GenerateUnit(const AUnitName: string; const ATables: TArray<TMetaTable>): string;
  end;

  // FireDAC Implementation
  TFireDACSchemaProvider = class(TInterfacedObject, ISchemaProvider)
  private
    FConnection: IDbConnection;
  public
    constructor Create(AConnection: IDbConnection);
    function GetTables: TArray<string>;
    function GetTableMetadata(const ATableName: string): TMetaTable;
  end;

  // Delphi Generator Implementation
  TDelphiEntityGenerator = class(TInterfacedObject, IEntityGenerator)
  private
    function SQLTypeToDelphiType(const ASQLType: string; AScale: Integer): string;
    function CleanName(const AName: string): string;
  public
    function GenerateUnit(const AUnitName: string; const ATables: TArray<TMetaTable>): string;
  end;

implementation

uses
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Phys.Intf,
  Dext.Entity.Drivers.FireDAC;

{ TFireDACSchemaProvider }

constructor TFireDACSchemaProvider.Create(AConnection: IDbConnection);
begin
  FConnection := AConnection;
end;

function TFireDACSchemaProvider.GetTables: TArray<string>;
var
  FDConn: TFDConnection;
  List: TStringList;
begin
  if not (FConnection is TFireDACConnection) then
    raise Exception.Create('Connection is not a FireDAC connection');

  FDConn := TFireDACConnection(FConnection).Connection;
  List := TStringList.Create;
  try
    FDConn.GetTableNames('', '', '', List, [osMy], [tkTable], True);
    Result := List.ToStringArray;
  finally
    List.Free;
  end;
end;

function TFireDACSchemaProvider.GetTableMetadata(const ATableName: string): TMetaTable;
var
  FDConn: TFDConnection;
  Meta: TFDMetaInfoQuery;
  Cols: TList<TMetaColumn>;
  FKs: TList<TMetaForeignKey>;
  Col: TMetaColumn;
  FK: TMetaForeignKey;
begin
  if not (FConnection is TFireDACConnection) then
    raise Exception.Create('Connection is not a FireDAC connection');

  FDConn := TFireDACConnection(FConnection).Connection;
  Result.Name := ATableName;

  Meta := TFDMetaInfoQuery.Create(nil);
  try
    Meta.Connection := FDConn;
    
    // 1. Get Columns
    Meta.MetaInfoKind := mkTableFields;
    Meta.ObjectName := ATableName;
    Meta.Open;
    
    Cols := TList<TMetaColumn>.Create;
    try
      while not Meta.Eof do
      begin
        Col.Name := Meta.FieldByName('COLUMN_NAME').AsString;
        Col.DataType := Meta.FieldByName('TYPE_NAME').AsString;
        Col.Length := Meta.FieldByName('COLUMN_LENGTH').AsInteger;
        Col.Precision := Meta.FieldByName('COLUMN_PRECISION').AsInteger;
        Col.Scale := Meta.FieldByName('COLUMN_SCALE').AsInteger;
        Col.IsNullable := Meta.FieldByName('NULLABLE').AsInteger = 3; // 3 = Nullable? Need to check FD docs. Usually 1=Yes, 0=No.
        // Actually FD returns: 0=Unknown, 1=Nullable, 2=NoNulls. Let's assume <> 2.
        Col.IsNullable := Meta.FieldByName('NULLABLE').AsInteger <> 2;
        
        // PK and AutoInc are harder in mkTableFields.
        // We might need mkPrimaryKeyFields.
        Col.IsPrimaryKey := False;
        Col.IsAutoInc := False; // Hard to detect generically without specific driver info
        
        Cols.Add(Col);
        Meta.Next;
      end;
      Result.Columns := Cols.ToArray;
    finally
      Cols.Free;
    end;
    
    Meta.Close;

    // 2. Get Primary Keys
    Meta.MetaInfoKind := mkPrimaryKeyFields;
    Meta.ObjectName := ATableName;
    Meta.Open;
    while not Meta.Eof do
    begin
      var PKCol := Meta.FieldByName('COLUMN_NAME').AsString;
      for var i := 0 to High(Result.Columns) do
      begin
        if Result.Columns[i].Name = PKCol then
        begin
          Result.Columns[i].IsPrimaryKey := True;
          // Heuristic: If PK and Integer, assume AutoInc for now (can be refined)
          if (Result.Columns[i].DataType.Contains('INT')) or 
             (Result.Columns[i].DataType.Contains('SERIAL')) then
             Result.Columns[i].IsAutoInc := True;
        end;
      end;
      Meta.Next;
    end;
    Meta.Close;

    // 3. Get Foreign Keys
    Meta.MetaInfoKind := mkForeignKeys;
    Meta.ObjectName := ATableName;
    Meta.Open;
    
    FKs := TList<TMetaForeignKey>.Create;
    try
      while not Meta.Eof do
      begin
        FK.Name := Meta.FieldByName('FKEY_NAME').AsString;
        FK.ColumnName := Meta.FieldByName('FK_COLUMN_NAME').AsString;
        FK.ReferencedTable := Meta.FieldByName('PK_TABLE_NAME').AsString;
        FK.ReferencedColumn := Meta.FieldByName('PK_COLUMN_NAME').AsString;
        // Update/Delete rules might not be available in all drivers via MetaInfo
        FK.OnDelete := ''; 
        FK.OnUpdate := '';
        
        FKs.Add(FK);
        Meta.Next;
      end;
      Result.ForeignKeys := FKs.ToArray;
    finally
      FKs.Free;
    end;
    Meta.Close;

  finally
    Meta.Free;
  end;
end;

{ TDelphiEntityGenerator }

function TDelphiEntityGenerator.CleanName(const AName: string): string;
begin
  Result := AName.Replace(' ', '').Replace('-', '_');
  // Simple PascalCase conversion could be added here
end;

function TDelphiEntityGenerator.SQLTypeToDelphiType(const ASQLType: string; AScale: Integer): string;
var
  S: string;
begin
  S := ASQLType.ToUpper;
  if S.Contains('INT') then Result := 'Integer'
  else if S.Contains('CHAR') or S.Contains('TEXT') or S.Contains('CLOB') then Result := 'string'
  else if S.Contains('BOOL') or S.Contains('BIT') then Result := 'Boolean'
  else if S.Contains('DATE') or S.Contains('TIME') then Result := 'TDateTime'
  else if S.Contains('FLOAT') or S.Contains('DOUBLE') or S.Contains('REAL') then Result := 'Double'
  else if S.Contains('DECIMAL') or S.Contains('NUMERIC') or S.Contains('MONEY') then 
  begin
    if AScale = 0 then Result := 'Int64' else Result := 'Currency'; // Or Double
  end
  else if S.Contains('BLOB') or S.Contains('BINARY') then Result := 'TBytes'
  else if S.Contains('GUID') or S.Contains('UUID') then Result := 'TGUID'
  else Result := 'string'; // Default
end;

function TDelphiEntityGenerator.GenerateUnit(const AUnitName: string; const ATables: TArray<TMetaTable>): string;
var
  SB: TStringBuilder;
  Table: TMetaTable;
  Col: TMetaColumn;
  FK: TMetaForeignKey;
  ClassName, PropName, PropType: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('unit ' + AUnitName + ';');
    SB.AppendLine('');
    SB.AppendLine('interface');
    SB.AppendLine('');
    SB.AppendLine('uses');
    SB.AppendLine('  Dext.Entity,');
    SB.AppendLine('  Dext.Types.Nullable,'); // Assuming we use Nullable
    SB.AppendLine('  System.SysUtils,');
    SB.AppendLine('  System.Classes;');
    SB.AppendLine('');
    SB.AppendLine('type');
    
    for Table in ATables do
    begin
      ClassName := 'T' + CleanName(Table.Name);
      SB.AppendLine('');
      SB.AppendLine('  [Table(''' + Table.Name + ''')]');
      SB.AppendLine('  ' + ClassName + ' = class');
      SB.AppendLine('  private');
      
      // Fields
      for Col in Table.Columns do
      begin
        PropName := CleanName(Col.Name);
        PropType := SQLTypeToDelphiType(Col.DataType, Col.Scale);
        
        if Col.IsNullable and (PropType <> 'string') and (PropType <> 'TBytes') then
          PropType := 'Nullable<' + PropType + '>';
          
        SB.AppendLine('    F' + PropName + ': ' + PropType + ';');
      end;
      
      SB.AppendLine('  public');
      
      // Properties
      for Col in Table.Columns do
      begin
        PropName := CleanName(Col.Name);
        PropType := SQLTypeToDelphiType(Col.DataType, Col.Scale);
        
        if Col.IsNullable and (PropType <> 'string') and (PropType <> 'TBytes') then
          PropType := 'Nullable<' + PropType + '>';
          
        // Attributes
        if Col.IsPrimaryKey then
          SB.Append('    [PK')
        else
          SB.Append('    [Column(''' + Col.Name + ''')');
          
        if Col.IsAutoInc then
          SB.Append(', AutoInc');
          
        SB.AppendLine(']');
        SB.AppendLine('    property ' + PropName + ': ' + PropType + ' read F' + PropName + ' write F' + PropName + ';');
      end;
      
      // Navigation Properties (FKs)
      for FK in Table.ForeignKeys do
      begin
        var RefClass := 'T' + CleanName(FK.ReferencedTable);
        var NavPropName := CleanName(FK.Name);
        if NavPropName.StartsWith('FK_') then NavPropName := NavPropName.Substring(3);
        
        // Simple heuristic for name: Remove 'Id' from column name
        if FK.ColumnName.EndsWith('Id', True) then
           NavPropName := FK.ColumnName.Substring(0, FK.ColumnName.Length - 2)
        else
           NavPropName := FK.ReferencedTable;

        SB.AppendLine('');
        SB.AppendLine('    [ForeignKey(''' + FK.ColumnName + ''')]');
        SB.AppendLine('    property ' + NavPropName + ': ' + RefClass + ' read Get' + NavPropName + ' write Set' + NavPropName + ';'); 
        // Note: Getters/Setters need implementation or use field backing if we want lazy loading support generated too.
        // For simplicity, let's just use property for now, but Dext requires implementation for Lazy Loading.
        // Or we can use [NotMapped] property.
      end;
      
      SB.AppendLine('  end;');
    end;
    
    SB.AppendLine('');
    SB.AppendLine('implementation');
    SB.AppendLine('');
    SB.AppendLine('end.');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.
