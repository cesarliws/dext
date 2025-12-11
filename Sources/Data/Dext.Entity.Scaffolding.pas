{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
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

  TMappingStyle = (msAttributes, msFluent);

  IEntityGenerator = interface
    ['{B1C2D3E4-F5A6-7890-1234-567890ABCDEF}']
    function GenerateUnit(const AUnitName: string; const ATables: TArray<TMetaTable>; AMappingStyle: TMappingStyle = msAttributes): string;
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
    function CleanMappingName(const AName: string): string;
  public
    function GenerateUnit(const AUnitName: string; const ATables: TArray<TMetaTable>; AMappingStyle: TMappingStyle = msAttributes): string;
  end;

implementation

uses
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Phys.Intf,
  FireDAC.Stan.Intf, // Needed for mkTableFields constants if used, or just rely on strings
  System.StrUtils,
  Dext.Entity,
  Dext.Entity.Drivers.FireDAC,
  Dext.Types.Lazy,
  Dext.Types.Nullable;

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

    // Filter out system tables
    for var i := List.Count - 1 downto 0 do
    begin
       if List[i].StartsWith('pg_catalog.', True) or 
          List[i].StartsWith('information_schema.', True) or
          List[i].StartsWith('sys.', True) then
          List.Delete(i);
    end;

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
    Meta.TableKinds := [tkTable];
    Meta.ObjectScopes := [osMy, osOther, osSystem];
    
    // Debug
    Writeln('Debug: Fetching columns for table "' + ATableName + '"');
    
    // Try Configuration A: ObjectName = TableName (Standard)
    Meta.BaseObjectName := '';
    Meta.ObjectName := ATableName;
    try
      Meta.Open;
    except
      on E: Exception do
      begin
        Writeln('Debug: Config A (ObjectName) failed: ' + E.Message);
        // Try Configuration B: BaseObjectName = TableName (SQLite specific?)
        Meta.Close;
        Meta.BaseObjectName := ATableName;
        Meta.ObjectName := '%'; 
        try
           Meta.Open;
        except
           on E2: Exception do
           begin
              Writeln('Debug: Config B (BaseObject+Wildcard) failed: ' + E2.Message);
              // Try Configuration C: Both
              Meta.Close;
              Meta.BaseObjectName := ATableName;
              Meta.ObjectName := ATableName;
              Meta.Open;
           end;
        end;
      end;
    end;
    
    Cols := TList<TMetaColumn>.Create;
    try
      while not Meta.Eof do
      begin
        Col.Name := Meta.FieldByName('COLUMN_NAME').AsString;
        Col.DataType := Meta.FieldByName('COLUMN_TYPENAME').AsString; 
        Col.Length := Meta.FieldByName('COLUMN_LENGTH').AsInteger; 
        Col.Precision := Meta.FieldByName('COLUMN_PRECISION').AsInteger;
        Col.Scale := Meta.FieldByName('COLUMN_SCALE').AsInteger;
        
        // FireDAC Nullable: 1=Nullable, 0=NoNulls, 2=Unknown. We treat 1 as Nullable.
        if Meta.FindField('IS_NULLABLE') <> nil then
          Col.IsNullable := Meta.FieldByName('IS_NULLABLE').AsString = 'YES'
        else if Meta.FindField('NULLABLE') <> nil then
          Col.IsNullable := Meta.FieldByName('NULLABLE').AsInteger = 1
        else
          Col.IsNullable := True; // Default to nullable if unknown
        
        Col.IsPrimaryKey := False;
        Col.IsAutoInc := False; 
        
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
    Meta.BaseObjectName := ATableName;
    Meta.ObjectName := '%';
    Meta.Open;
    while not Meta.Eof do
    begin
      var PKCol := Meta.FieldByName('COLUMN_NAME').AsString;
      for var i := 0 to High(Result.Columns) do
      begin
        if Result.Columns[i].Name = PKCol then
        begin
          Result.Columns[i].IsPrimaryKey := True;
          // Heuristic: If PK and Integer, assume AutoInc for now.
          // Ideally we should check specific driver attributes or identity columns.
          if (Result.Columns[i].DataType.Contains('INT')) or 
             (Result.Columns[i].DataType.Contains('SERIAL')) or
             (Result.Columns[i].DataType.Contains('IDENTITY')) then
             Result.Columns[i].IsAutoInc := True;
        end;
      end;
      Meta.Next;
    end;
    Meta.Close;

    // 3. Get Foreign Keys (Step 1: Identify FKs)
    Meta.MetaInfoKind := mkForeignKeys;
    
    // Try Configuration A: ObjectName = TableName (Standard)
    Meta.BaseObjectName := '';
    Meta.ObjectName := ATableName;
    try
      Meta.Open;
    except
      on E: Exception do
      begin
        Writeln('Debug: FK Config A (ObjectName) failed: ' + E.Message);
        // Try Configuration B: BaseObjectName = TableName (SQLite specific?)
        Meta.Close;
        Meta.BaseObjectName := ATableName;
        Meta.ObjectName := '%'; 
        try
           Meta.Open;
        except
           on E2: Exception do
           begin
              Writeln('Debug: FK Config B (BaseObject+Wildcard) failed: ' + E2.Message);
              // Try Configuration C: Both
              Meta.Close;
              Meta.BaseObjectName := ATableName;
              Meta.ObjectName := ATableName;
              Meta.Open;
           end;
        end;
      end;
    end;
    
    FKs := TList<TMetaForeignKey>.Create;
    try
      if not Meta.Eof then
      begin
         Writeln('Debug: Available fields in mkForeignKeys:');
         for var i := 0 to Meta.FieldCount - 1 do
           Writeln('  - ' + Meta.Fields[i].FieldName);
      end;

      while not Meta.Eof do
      begin
        FK.Name := Meta.FieldByName('FKEY_NAME').AsString;
        // Try to find the referenced table name defensively
        if Meta.FindField('PK_TABLE_NAME') <> nil then
          FK.ReferencedTable := Meta.FieldByName('PK_TABLE_NAME').AsString
        else if Meta.FindField('PKEY_TABLE_NAME') <> nil then
           FK.ReferencedTable := Meta.FieldByName('PKEY_TABLE_NAME').AsString
        else if Meta.FindField('REFERENCED_TABLE_NAME') <> nil then
           FK.ReferencedTable := Meta.FieldByName('REFERENCED_TABLE_NAME').AsString
        else
           FK.ReferencedTable := 'UNKNOWN_TABLE';
           
        // Note: FK_COLUMN_NAME is not available here
        FKs.Add(FK);
        Meta.Next;
      end;
    finally
      Meta.Close;
    end;

    // 4. Get FK Columns (Step 2: Get Details)
    Meta.MetaInfoKind := mkForeignKeyFields;
    for var i := 0 to FKs.Count - 1 do
    begin
       FK := FKs[i];
       
       // For mkForeignKeyFields, BaseObjectName is TableName, ObjectName is FK Name
       Meta.BaseObjectName := ATableName;
       Meta.ObjectName := FK.Name; 
       
       try
         Meta.Open;
         
         // Debug: List fields for the first FK to identify correct names
         if (i = 0) and (not Meta.Eof) then 
         begin
            Writeln('Debug: Available fields in mkForeignKeyFields:');
            for var k := 0 to Meta.FieldCount - 1 do
               Writeln('  - ' + Meta.Fields[k].FieldName);
         end;

         if not Meta.Eof then
         begin
           // Defensive check for FK Column Name
           if Meta.FindField('FK_COLUMN_NAME') <> nil then
             FK.ColumnName := Meta.FieldByName('FK_COLUMN_NAME').AsString
           else if Meta.FindField('FKEY_COLUMN_NAME') <> nil then
             FK.ColumnName := Meta.FieldByName('FKEY_COLUMN_NAME').AsString
           else if Meta.FindField('COLUMN_NAME') <> nil then
             FK.ColumnName := Meta.FieldByName('COLUMN_NAME').AsString
           else
             FK.ColumnName := 'UNKNOWN_COL';

           // Defensive check for Referenced Column Name
           if Meta.FindField('PK_COLUMN_NAME') <> nil then
             FK.ReferencedColumn := Meta.FieldByName('PK_COLUMN_NAME').AsString
           else if Meta.FindField('PKEY_COLUMN_NAME') <> nil then
             FK.ReferencedColumn := Meta.FieldByName('PKEY_COLUMN_NAME').AsString
           else if Meta.FindField('REFERENCED_COLUMN_NAME') <> nil then
             FK.ReferencedColumn := Meta.FieldByName('REFERENCED_COLUMN_NAME').AsString
           else
             FK.ReferencedColumn := 'UNKNOWN_REF_COL';
             
           FKs[i] := FK; // Update record in list
         end;
       except
         on E: Exception do
           Writeln('Debug: Failed to fetch columns for FK ' + FK.Name + ': ' + E.Message);
       end;
       Meta.Close;
    end;

    Result.ForeignKeys := FKs.ToArray;
    FKs.Free;
  finally
    Meta.Free;
  end;
end;

{ TDelphiEntityGenerator }

function TDelphiEntityGenerator.CleanName(const AName: string): string;
var
  Parts: TArray<string>;
  S: string;
  CleanedName: string;
begin
  Result := '';
  // Remove quotes and brackets
  CleanedName := AName.Replace('"', '').Replace('''', '').Replace('[', '').Replace(']', '');
  
  // Handle dot notation (Catalog.Schema.Table or Schema.Table)
  // Take the last part as the table name
  if CleanedName.Contains('.') then
  begin
    Parts := CleanedName.Split(['.']);
    if Length(Parts) > 0 then
      CleanedName := Parts[High(Parts)];
  end;
  
  // Split by common delimiters
  Parts := CleanedName.Split(['_', '-', ' '], TStringSplitOptions.ExcludeEmpty);
  for S in Parts do
  begin
    if S.Length > 0 then
      // Capitalize first letter, lowercase the rest (PascalCase)
      Result := Result + UpperCase(S.Chars[0]) + S.Substring(1).ToLower;
  end;
end;

function TDelphiEntityGenerator.SQLTypeToDelphiType(const ASQLType: string; AScale: Integer): string;
var
  S: string;
begin
  S := ASQLType.ToUpper;
  if S.Contains('INT') then Result := 'Integer'
  else if S.Contains('BIGINT') then Result := 'Int64'
  else if S.Contains('SMALLINT') or S.Contains('TINYINT') then Result := 'Integer'
  else if S.Contains('CHAR') or S.Contains('TEXT') or S.Contains('CLOB') then Result := 'string'
  else if S.Contains('BOOL') or S.Contains('BIT') then Result := 'Boolean'
  else if S.Contains('DATE') or S.Contains('TIME') then Result := 'TDateTime'
  else if S.Contains('FLOAT') or S.Contains('DOUBLE') or S.Contains('REAL') then Result := 'Double'
  else if S.Contains('DECIMAL') or S.Contains('NUMERIC') or S.Contains('MONEY') then 
  begin
    if AScale = 0 then Result := 'Int64' else Result := 'Currency'; 
  end
  else if S.Contains('BLOB') or S.Contains('BINARY') or S.Contains('IMAGE') or S.Contains('VARBINARY') then Result := 'TBytes'
  else if S.Contains('GUID') or S.Contains('UUID') then Result := 'TGUID'
  else Result := 'string'; // Default
end;



function TDelphiEntityGenerator.CleanMappingName(const AName: string): string;
begin
  Result := AName.Replace('"', '').Replace('''', '').Replace('[', '').Replace(']', '').Replace('..', '.');
end;

function TDelphiEntityGenerator.GenerateUnit(const AUnitName: string; const ATables: TArray<TMetaTable>; AMappingStyle: TMappingStyle = msAttributes): string;
var
  SB: TStringBuilder;
  Table: TMetaTable;
  Col: TMetaColumn;
  FK: TMetaForeignKey;
  ClassName, PropName, FieldName, DelphiType: string;
  RefClass, NavPropName: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('unit ' + AUnitName + ';');
    SB.AppendLine('');
    SB.AppendLine('interface');
    SB.AppendLine('');
    SB.AppendLine('uses');
    SB.AppendLine('  Dext.Entity,');
    if AMappingStyle = msFluent then
       SB.AppendLine('  Dext.Entity.Mapping,');
    SB.AppendLine('  Dext.Types.Nullable,');
    SB.AppendLine('  Dext.Types.Lazy,');
    SB.AppendLine('  Dext.Persistence,'); // Added Dext.Persistence
    SB.AppendLine('  System.SysUtils,');
    SB.AppendLine('  System.Classes;');
    SB.AppendLine('');
    SB.AppendLine('type');
    SB.AppendLine('');

    // Forward declarations
    for Table in ATables do
    begin
      ClassName := 'T' + CleanName(Table.Name);
      SB.AppendLine('  ' + ClassName + ' = class;');
    end;
    SB.AppendLine('');

    // Clean table name for mapping (remove quotes/brackets)


    for Table in ATables do
    begin
      ClassName := 'T' + CleanName(Table.Name);
      var MappingName := CleanMappingName(Table.Name);
      
      if AMappingStyle = msAttributes then
         SB.AppendLine('  [Table(''' + MappingName + ''')]');
         
      SB.AppendLine('  ' + ClassName + ' = class');
      SB.AppendLine('  private');
      
      // Fields
      for Col in Table.Columns do
      begin
        FieldName := 'F' + CleanName(Col.Name);
        DelphiType := SQLTypeToDelphiType(Col.DataType, Col.Scale);
        
        if Col.IsNullable and (DelphiType <> 'string') and (DelphiType <> 'TBytes') then
          DelphiType := 'Nullable<' + DelphiType + '>';
          
        SB.AppendLine('    ' + FieldName + ': ' + DelphiType + ';');
      end;
      
      // Navigation Fields (Lazy Loading)
      for FK in Table.ForeignKeys do
      begin
        RefClass := 'T' + CleanName(FK.ReferencedTable);
        
        // Derive NavPropName from Column Name (e.g. address_id -> Address)
        NavPropName := CleanName(FK.ColumnName);
        if NavPropName.EndsWith('Id', True) then
           NavPropName := NavPropName.Substring(0, NavPropName.Length - 2);
           
        // Fallback to Referenced Table Name if column name is generic (e.g. just "Id" or empty)
        if (NavPropName = '') or SameText(NavPropName, 'Id') then
           NavPropName := CleanName(FK.ReferencedTable);

        // Avoid collision with the FK column property itself
        if SameText(NavPropName, CleanName(FK.ColumnName)) then 
           NavPropName := NavPropName + 'Ref';

        SB.AppendLine('    F' + NavPropName + ': ILazy<' + RefClass + '>;'); 
      end;
      
      // Getters/Setters for Navigation Properties
      if Length(Table.ForeignKeys) > 0 then
      begin
        SB.AppendLine('');
        for FK in Table.ForeignKeys do
        begin
          RefClass := 'T' + CleanName(FK.ReferencedTable);
          
          NavPropName := CleanName(FK.ColumnName);
          if NavPropName.EndsWith('Id', True) then
             NavPropName := NavPropName.Substring(0, NavPropName.Length - 2);
             
          if (NavPropName = '') or SameText(NavPropName, 'Id') then
             NavPropName := CleanName(FK.ReferencedTable);

          if SameText(NavPropName, CleanName(FK.ColumnName)) then 
             NavPropName := NavPropName + 'Ref';
          
          SB.AppendLine('    function Get' + NavPropName + ': ' + RefClass + ';');
          SB.AppendLine('    procedure Set' + NavPropName + '(const Value: ' + RefClass + ');');
        end;
      end;

      SB.AppendLine('  public');
      
      // Properties
      for Col in Table.Columns do
      begin
        PropName := CleanName(Col.Name);
        FieldName := 'F' + PropName;
        DelphiType := SQLTypeToDelphiType(Col.DataType, Col.Scale);
        
        if Col.IsNullable and (DelphiType <> 'string') and (DelphiType <> 'TBytes') then
          DelphiType := 'Nullable<' + DelphiType + '>';

        // Attributes (Only if msAttributes)
        if AMappingStyle = msAttributes then
        begin
            var HasAttribute := False;
            SB.Append('    ');
            if Col.IsPrimaryKey then 
            begin
              SB.Append('[PK] ');
              HasAttribute := True;
            end;
            if Col.IsAutoInc then 
            begin
              SB.Append('[AutoInc] ');
              HasAttribute := True;
            end;
            
            if not SameText(Col.Name, PropName) then
            begin
               SB.Append('[Column(''' + Col.Name + ''')] ');
               HasAttribute := True;
            end;
            
            if HasAttribute then
            begin
              SB.AppendLine('');
              SB.Append('    ');
            end;
        end
        else
        begin
           SB.Append('    ');
        end;
        
        SB.AppendLine('property ' + PropName + ': ' + DelphiType + ' read ' + FieldName + ' write ' + FieldName + ';');
      end;
      
      // Navigation Properties (FKs)
      for FK in Table.ForeignKeys do
      begin
        RefClass := 'T' + CleanName(FK.ReferencedTable);
        
        NavPropName := CleanName(FK.ColumnName);
        if NavPropName.EndsWith('Id', True) then
           NavPropName := NavPropName.Substring(0, NavPropName.Length - 2);
           
        if (NavPropName = '') or SameText(NavPropName, 'Id') then
           NavPropName := CleanName(FK.ReferencedTable);

        if SameText(NavPropName, CleanName(FK.ColumnName)) then 
           NavPropName := NavPropName + 'Ref';

        if AMappingStyle = msAttributes then
        begin
           SB.AppendLine('    [ForeignKey(''' + FK.ColumnName + ''')]');
        end;
        
        SB.AppendLine('    property ' + NavPropName + ': ' + RefClass + ' read Get' + NavPropName + ' write Set' + NavPropName + ';'); 
      end;
      
      SB.AppendLine('  end;');
      SB.AppendLine('');
    end;
    
    // Metadata Classes (TPropExpression)
    for Table in ATables do
    begin
       ClassName := 'T' + CleanName(Table.Name);
       var EntityClassName := CleanName(Table.Name) + 'Entity';
       
       SB.AppendLine('  ' + EntityClassName + ' = class');
       SB.AppendLine('  public');
       
       // Properties
       for Col in Table.Columns do
       begin
          PropName := CleanName(Col.Name);
          SB.AppendLine('    class var ' + PropName + ': TPropExpression;');
       end;
       
       // Navigation Properties
       for FK in Table.ForeignKeys do
       begin
          NavPropName := CleanName(FK.ColumnName);
          if NavPropName.EndsWith('Id', True) then
             NavPropName := NavPropName.Substring(0, NavPropName.Length - 2);
          if (NavPropName = '') or SameText(NavPropName, 'Id') then
             NavPropName := CleanName(FK.ReferencedTable);
          if SameText(NavPropName, CleanName(FK.ColumnName)) then 
             NavPropName := NavPropName + 'Ref';
             
          SB.AppendLine('    class var ' + NavPropName + ': TPropExpression;');
       end;
       
       SB.AppendLine('');
       SB.AppendLine('    class constructor Create;');
       SB.AppendLine('  end;');
       SB.AppendLine('');
    end;

    // Fluent Mapping Registration
    if AMappingStyle = msFluent then
    begin
       SB.AppendLine('procedure RegisterMappings(ModelBuilder: TModelBuilder);');
       SB.AppendLine('');
    end;
    
    SB.AppendLine('implementation');
    SB.AppendLine('');
    
    // Fluent Mapping Implementation
    if AMappingStyle = msFluent then
    begin
       SB.AppendLine('procedure RegisterMappings(ModelBuilder: TModelBuilder);');
       SB.AppendLine('begin');
       for Table in ATables do
       begin
          ClassName := 'T' + CleanName(Table.Name);
          var MappingName := CleanMappingName(Table.Name);
          
          SB.AppendLine('  ModelBuilder.Entity<' + ClassName + '>');
          SB.AppendLine('    .Table(''' + MappingName + ''')');
          
          for Col in Table.Columns do
          begin
             PropName := CleanName(Col.Name);
             
             if Col.IsPrimaryKey then
                SB.AppendLine('    .HasKey(''' + PropName + ''')');
                
             if not SameText(Col.Name, PropName) then
                SB.AppendLine('    .Prop(''' + PropName + ''').Column(''' + Col.Name + ''')');
          end;
          
          // Foreign Keys
          for FK in Table.ForeignKeys do
          begin
             NavPropName := CleanName(FK.ColumnName);
             if NavPropName.EndsWith('Id', True) then
                NavPropName := NavPropName.Substring(0, NavPropName.Length - 2);
             if (NavPropName = '') or SameText(NavPropName, 'Id') then
                NavPropName := CleanName(FK.ReferencedTable);
             if SameText(NavPropName, CleanName(FK.ColumnName)) then 
                NavPropName := NavPropName + 'Ref';
                
             SB.AppendLine('    .Prop(''' + NavPropName + ''').HasForeignKey(''' + FK.ColumnName + ''')');
          end;
          
          SB.AppendLine('    ;'); // End chain
          SB.AppendLine('');
       end;
       SB.AppendLine('end;');
       SB.AppendLine('');
    end;
    
    // Metadata Implementation
    for Table in ATables do
    begin
       ClassName := 'T' + CleanName(Table.Name);
       var EntityClassName := CleanName(Table.Name) + 'Entity';
       
       SB.AppendLine('class constructor ' + EntityClassName + '.Create;');
       SB.AppendLine('begin');
       
       // Properties
       for Col in Table.Columns do
       begin
          PropName := CleanName(Col.Name);
          SB.AppendLine('  ' + PropName + ' := TPropExpression.Create(''' + PropName + ''');');
       end;
       
       // Navigation Properties
       for FK in Table.ForeignKeys do
       begin
          NavPropName := CleanName(FK.ColumnName);
          if NavPropName.EndsWith('Id', True) then
             NavPropName := NavPropName.Substring(0, NavPropName.Length - 2);
          if (NavPropName = '') or SameText(NavPropName, 'Id') then
             NavPropName := CleanName(FK.ReferencedTable);
          if SameText(NavPropName, CleanName(FK.ColumnName)) then 
             NavPropName := NavPropName + 'Ref';
             
          SB.AppendLine('  ' + NavPropName + ' := TPropExpression.Create(''' + NavPropName + ''');');
       end;
       
       SB.AppendLine('end;');
       SB.AppendLine('');
    end;
    
    // Implementation of Getters/Setters
    for Table in ATables do
    begin
      ClassName := 'T' + CleanName(Table.Name);
      
      for FK in Table.ForeignKeys do
      begin
        RefClass := 'T' + CleanName(FK.ReferencedTable);
        
        NavPropName := CleanName(FK.ColumnName);
        if NavPropName.EndsWith('Id', True) then
           NavPropName := NavPropName.Substring(0, NavPropName.Length - 2);
           
        if (NavPropName = '') or SameText(NavPropName, 'Id') then
           NavPropName := CleanName(FK.ReferencedTable);

        if SameText(NavPropName, CleanName(FK.ColumnName)) then 
           NavPropName := NavPropName + 'Ref';
        
        // Getter
        SB.AppendLine('function ' + ClassName + '.Get' + NavPropName + ': ' + RefClass + ';');
        SB.AppendLine('begin');
        SB.AppendLine('  if F' + NavPropName + ' <> nil then');
        SB.AppendLine('    Result := F' + NavPropName + '.Value');
        SB.AppendLine('  else');
        SB.AppendLine('    Result := nil;');
        SB.AppendLine('end;');
        SB.AppendLine('');
        
        // Setter
        SB.AppendLine('procedure ' + ClassName + '.Set' + NavPropName + '(const Value: ' + RefClass + ');');
        SB.AppendLine('begin');
        SB.AppendLine('  F' + NavPropName + ' := TValueLazy<' + RefClass + '>.Create(Value);');
        SB.AppendLine('end;');
        SB.AppendLine('');
      end;
    end;

    SB.AppendLine('end.');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.

