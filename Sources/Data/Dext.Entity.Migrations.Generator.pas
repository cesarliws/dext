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
unit Dext.Entity.Migrations.Generator;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.StrUtils,
  System.TypInfo,
  Dext.Entity.Migrations.Operations,
  Dext.Entity.Migrations.Serializers.Json,
  Dext.Json,
  Dext.Json.Types;

type
  TMigrationGenerator = class
  private
    class function GenerateOperation(Op: TMigrationOperation): string;
    class function GenerateColumnDefinition(Col: TColumnDefinition; const Indent: string): string;
    class function GenerateCreateTable(Op: TCreateTableOperation): string;
    class function GenerateAddColumn(Op: TAddColumnOperation): string;
    class function GenerateCreateIndex(Op: TCreateIndexOperation): string;
    class function GenerateAddForeignKey(Op: TAddForeignKeyOperation): string;
    class function GenerateDropTable(Op: TDropTableOperation): string;
    class function GenerateDropColumn(Op: TDropColumnOperation): string;
    class function QuoteString(const S: string): string;
  public
    class function GenerateUnit(const AUnitName, AClassName: string; Ops: TObjectList<TMigrationOperation>): string;
    class function GenerateJson(const AId, ADescription, AAuthor: string; Ops: TObjectList<TMigrationOperation>): string;
  end;

implementation

{ TMigrationGenerator }

class function TMigrationGenerator.GenerateJson(const AId, ADescription, AAuthor: string;
  Ops: TObjectList<TMigrationOperation>): string;
var
  Provider: IDextJsonProvider;
  Obj: IDextJsonObject;
  OpsJson: string;
  OpsNode: IDextJsonNode;
begin
  Provider := TDextJson.Provider;
  Obj := Provider.CreateObject;
  
  Obj.SetString('id', AId);
  Obj.SetString('description', ADescription);
  Obj.SetString('author', AAuthor);
  Obj.SetString('created_at', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
  
  // Use the serializer to get the operations array
  // Since Serialize returns a string, we parse it back to inject it into our main object
  // This is a bit round-trip but keeps the serializer clean.
  OpsJson := TMigrationJsonSerializer.Serialize(Ops);
  OpsNode := Provider.Parse(OpsJson);
  
  if (OpsNode <> nil) and (OpsNode.GetNodeType = jntArray) then
    Obj.SetArray('operations', OpsNode as IDextJsonArray);
    
  Result := Obj.ToJson(True);
end;

class function TMigrationGenerator.GenerateUnit(const AUnitName, AClassName: string;
  Ops: TObjectList<TMigrationOperation>): string;
var
  SB: TStringBuilder;
  Op: TMigrationOperation;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('unit ' + AUnitName + ';');
    SB.AppendLine('');
    SB.AppendLine('interface');
    SB.AppendLine('');
    SB.AppendLine('uses');
    SB.AppendLine('  Dext.Entity.Migrations;');
    SB.AppendLine('');
    SB.AppendLine('type');
    SB.AppendLine('  ' + AClassName + ' = class(TInterfacedObject, IMigration)');
    SB.AppendLine('  public');
    SB.AppendLine('    function GetId: string;');
    SB.AppendLine('    procedure Up(Builder: TSchemaBuilder);');
    SB.AppendLine('    procedure Down(Builder: TSchemaBuilder);');
    SB.AppendLine('  end;');
    SB.AppendLine('');
    SB.AppendLine('implementation');
    SB.AppendLine('');
    SB.AppendLine('{ ' + AClassName + ' }');
    SB.AppendLine('');
    
    // GetId
    SB.AppendLine('function ' + AClassName + '.GetId: string;');
    SB.AppendLine('begin');
    // Extract ID from ClassName or UnitName? Usually ClassName is TMigration_Timestamp_Name
    // Let's assume the ID is the part after TMigration_
    var ID := AClassName;
    if ID.StartsWith('TMigration_', True) then
      ID := ID.Substring(11);
    SB.AppendLine('  Result := ''' + ID + ''';');
    SB.AppendLine('end;');
    SB.AppendLine('');

    // Up
    SB.AppendLine('procedure ' + AClassName + '.Up(Builder: TSchemaBuilder);');
    SB.AppendLine('begin');
    for Op in Ops do
    begin
      var Code := GenerateOperation(Op);
      if Code <> '' then
        SB.AppendLine('  ' + Code);
    end;
    SB.AppendLine('end;');
    SB.AppendLine('');

    // Down
    SB.AppendLine('procedure ' + AClassName + '.Down(Builder: TSchemaBuilder);');
    SB.AppendLine('begin');
    SB.AppendLine('  // TODO: Implement Down migration');
    // Generating Down logic requires the inverse operations or the previous state.
    // For now, we leave it as a TODO or we could try to reverse simple operations.
    SB.AppendLine('end;');
    SB.AppendLine('');
    
    SB.AppendLine('initialization');
    SB.AppendLine('  RegisterMigration(' + AClassName + '.Create);');
    SB.AppendLine('');
    SB.AppendLine('end.');

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TMigrationGenerator.GenerateOperation(Op: TMigrationOperation): string;
begin
  case Op.OperationType of
    otCreateTable: Result := GenerateCreateTable(TCreateTableOperation(Op));
    otDropTable: Result := GenerateDropTable(TDropTableOperation(Op));
    otAddColumn: Result := GenerateAddColumn(TAddColumnOperation(Op));
    otDropColumn: Result := GenerateDropColumn(TDropColumnOperation(Op));
    otCreateIndex: Result := GenerateCreateIndex(TCreateIndexOperation(Op));
    otAddForeignKey: Result := GenerateAddForeignKey(TAddForeignKeyOperation(Op));
    // TODO: Implement others
    else Result := '// Unsupported operation: ' + GetEnumName(TypeInfo(TOperationType), Integer(Op.OperationType));
  end;
end;

class function TMigrationGenerator.GenerateCreateTable(Op: TCreateTableOperation): string;
var
  SB: TStringBuilder;
  Col: TColumnDefinition;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('Builder.CreateTable(' + QuoteString(Op.Name) + ', procedure(T: TTableBuilder)');
    SB.AppendLine('');
    SB.AppendLine('  begin');
    
    for Col in Op.Columns do
    begin
      SB.AppendLine(GenerateColumnDefinition(Col, '    '));
    end;
    
    // Primary Key (if defined separately)
    if Length(Op.PrimaryKey) > 0 then
    begin
      SB.Append('    T.PrimaryKey([');
      for var i := 0 to High(Op.PrimaryKey) do
      begin
        if i > 0 then SB.Append(', ');
        SB.Append(QuoteString(Op.PrimaryKey[i]));
      end;
      SB.AppendLine(']);');
    end;
    
    SB.Append('  end);');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TMigrationGenerator.GenerateColumnDefinition(Col: TColumnDefinition; const Indent: string): string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append(Indent + 'T.Column(' + QuoteString(Col.Name) + ', ' + QuoteString(Col.ColumnType));
    
    if (Col.Precision > 0) then
      SB.Append(', ' + Col.Precision.ToString + ', ' + Col.Scale.ToString)
    else if (Col.Length > 0) then
      SB.Append(', ' + Col.Length.ToString);
      
    SB.Append(')'); // Close Column(
    
    if not Col.IsNullable then
      SB.Append('.NotNull');
      
    if Col.IsPrimaryKey then
      SB.Append('.PrimaryKey');
      
    if Col.IsIdentity then
      SB.Append('.Identity');
      
    if Col.DefaultValue <> '' then
      SB.Append('.Default(' + QuoteString(Col.DefaultValue) + ')');
      
    SB.Append(';');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TMigrationGenerator.GenerateAddColumn(Op: TAddColumnOperation): string;
var
  Col: TColumnDefinition;
begin
  Col := Op.Column;
  Result := Format('Builder.AddColumn(%s, %s, %s', 
    [QuoteString(Op.TableName), QuoteString(Col.Name), QuoteString(Col.ColumnType)]);
    
  if Col.Length > 0 then
    Result := Result + ', ' + Col.Length.ToString
  else
    Result := Result + ', 0';
    
  if Col.IsNullable then
    Result := Result + ', True'
  else
    Result := Result + ', False';
    
  Result := Result + ');';
end;

class function TMigrationGenerator.GenerateDropTable(Op: TDropTableOperation): string;
begin
  Result := 'Builder.DropTable(' + QuoteString(Op.Name) + ');';
end;

class function TMigrationGenerator.GenerateDropColumn(Op: TDropColumnOperation): string;
begin
  Result := Format('Builder.DropColumn(%s, %s);', [QuoteString(Op.TableName), QuoteString(Op.Name)]);
end;

class function TMigrationGenerator.GenerateCreateIndex(Op: TCreateIndexOperation): string;
var
  Cols: string;
begin
  Cols := '';
  for var i := 0 to High(Op.Columns) do
  begin
    if i > 0 then Cols := Cols + ', ';
    Cols := Cols + QuoteString(Op.Columns[i]);
  end;
  
  Result := Format('Builder.CreateIndex(%s, %s, [%s], %s);',
    [QuoteString(Op.Table), QuoteString(Op.Name), Cols, BoolToStr(Op.IsUnique, True)]);
end;

class function TMigrationGenerator.GenerateAddForeignKey(Op: TAddForeignKeyOperation): string;
begin
  // Assuming single column FK for now based on Builder API
  if (Length(Op.Columns) > 0) and (Length(Op.ReferencedColumns) > 0) then
  begin
    Result := Format('Builder.AddForeignKey(%s, %s, %s, %s, %s);',
      [QuoteString(Op.Table), QuoteString(Op.Name), 
       QuoteString(Op.Columns[0]), 
       QuoteString(Op.ReferencedTable), 
       QuoteString(Op.ReferencedColumns[0])]);
  end
  else
    Result := '// Unsupported composite FK in generator yet';
end;

class function TMigrationGenerator.QuoteString(const S: string): string;
begin
  Result := '''' + S.Replace('''', '''''') + '''';
end;

end.

