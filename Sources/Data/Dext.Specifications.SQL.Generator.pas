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
unit Dext.Specifications.SQL.Generator;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.TypInfo,
  System.Variants,
  Dext.Specifications.Interfaces,
  Dext.Specifications.Types,
  Dext.Entity.Dialects,
  Dext.Entity.Attributes,
  Dext.Entity.Mapping,
  Dext.Entity.TypeConverters,
  Dext.Types.Nullable,
  Dext.Types.UUID;

type
  ISQLColumnMapper = interface
    ['{6C3E8F9A-1B2C-4D5E-9F0A-1B2C3D4E5F6A}']
    function MapColumn(const AName: string): string;
  end;

  /// <summary>
  ///   Translates a Expression Tree into a SQL WHERE clause and Parameters.
  /// </summary>
  TSQLWhereGenerator = class
  private
    FSQL: TStringBuilder;
    FParams: TDictionary<string, TValue>;
    FParamCount: Integer;
    FDialect: ISQLDialect;
    FColumnMapper: ISQLColumnMapper;
    
    procedure Process(const AExpression: IExpression);
    procedure ProcessBinary(const C: TBinaryExpression);
    procedure ProcessLogical(const C: TLogicalExpression);
    procedure ProcessUnary(const C: TUnaryExpression);
    procedure ProcessConstant(const C: TConstantExpression);
    
    function GetNextParamName: string;
    function GetBinaryOpSQL(Op: TBinaryOperator): string;
    function GetLogicalOpSQL(Op: TLogicalOperator): string;
    function GetUnaryOpSQL(Op: TUnaryOperator): string;
    function MapColumn(const AName: string): string;
  public
    constructor Create(ADialect: ISQLDialect; AMapper: ISQLColumnMapper = nil);
    destructor Destroy; override;
    
    function Generate(const AExpression: IExpression): string;
    
    property Params: TDictionary<string, TValue> read FParams;
  end;

  TSQLColumnMapper<T: class> = class(TInterfacedObject, ISQLColumnMapper)
  public
    function MapColumn(const AName: string): string;
  end;

  TSQLGeneratorHelper = class
  public
    class function GetCascadeSQL(AAction: TCascadeAction): string;
    class function GetColumnNameForProperty(ATyp: TRttiType; const APropName: string): string;
    class function GetRelatedTableAndPK(ACtx: TRttiContext; AClass: TClass; out ATable, APK: string): Boolean;
  end;

  /// <summary>
  ///   Generates SQL for CRUD operations (Insert, Update, Delete).
  /// </summary>
  TSQLGenerator<T: class> = class
  private
    FDialect: ISQLDialect;
    FParams: TDictionary<string, TValue>;
    FParamCount: Integer;
    FMap: TEntityMap;
    // Properties to control filtering
    FIgnoreQueryFilters: Boolean;
    FOnlyDeleted: Boolean;
    FSchema: string;

    function GetNextParamName: string;
    function GetTableName: string;
    function GetSoftDeleteFilter: string;
    function GetDiscriminatorFilter: string;
    function GetDiscriminatorValueSQL: string;
    function GetDialectEnum: TDatabaseDialect;

  public
    constructor Create(ADialect: ISQLDialect; AMap: TEntityMap = nil);
    destructor Destroy; override;
    
    property IgnoreQueryFilters: Boolean read FIgnoreQueryFilters write FIgnoreQueryFilters;
    property OnlyDeleted: Boolean read FOnlyDeleted write FOnlyDeleted;
    property Schema: string read FSchema write FSchema;
    
    function GenerateInsert(const AEntity: T): string;
    function GenerateInsertTemplate(out AProps: TList<TPair<TRttiProperty, string>>): string;
    function GenerateUpdate(const AEntity: T): string;
    function GenerateDelete(const AEntity: T): string;
    
    function GenerateSelect(const ASpec: ISpecification<T>): string; overload;
    function GenerateSelect: string; overload;
    function GenerateCount(const ASpec: ISpecification<T>): string; overload;
    function GenerateCount: string; overload;
    function GenerateCreateTable(const ATableName: string): string;
    
    property Params: TDictionary<string, TValue> read FParams;
  end;

implementation

{ TSQLGeneratorHelper }

class function TSQLGeneratorHelper.GetCascadeSQL(AAction: TCascadeAction): string;
begin
  case AAction of
    caCascade: Result := 'CASCADE';
    caSetNull: Result := 'SET NULL';
    caRestrict: Result := 'RESTRICT';
    else Result := 'NO ACTION';
  end;
end;

class function TSQLGeneratorHelper.GetColumnNameForProperty(ATyp: TRttiType; const APropName: string): string;
var
  P: TRttiProperty;
  A: TCustomAttribute;
begin
  Result := APropName; // Default
  P := ATyp.GetProperty(APropName);
  if P <> nil then
  begin
    for A in P.GetAttributes do
    begin
      if A is ColumnAttribute then Exit(ColumnAttribute(A).Name);
    end;
  end;
end;

class function TSQLGeneratorHelper.GetRelatedTableAndPK(ACtx: TRttiContext; AClass: TClass; out ATable, APK: string): Boolean;
var
  RTyp: TRttiType;
  RProp: TRttiProperty;
  RAttr, SubAttr: TCustomAttribute;
begin
  Result := False;
  RTyp := ACtx.GetType(AClass);
  if RTyp = nil then Exit;
  
  // Table Name
  ATable := RTyp.Name;
  for RAttr in RTyp.GetAttributes do
    if RAttr is TableAttribute then
      ATable := TableAttribute(RAttr).Name;
      
  // PK
  for RProp in RTyp.GetProperties do
  begin
    for RAttr in RProp.GetAttributes do
    begin
      if RAttr is PKAttribute then
      begin
        APK := RProp.Name;
        // Check for Column Attribute on PK
        for SubAttr in RProp.GetAttributes do
          if SubAttr is ColumnAttribute then
            APK := ColumnAttribute(SubAttr).Name;
        Exit(True);
      end;
    end;
  end;
  
  // Fallback to 'Id'
  RProp := RTyp.GetProperty('Id');
  if RProp <> nil then
  begin
    APK := 'Id';
    for RAttr in RProp.GetAttributes do
      if RAttr is ColumnAttribute then
        APK := ColumnAttribute(RAttr).Name;
    Exit(True);
  end;
end;

{ TSQLWhereGenerator }

constructor TSQLWhereGenerator.Create(ADialect: ISQLDialect; AMapper: ISQLColumnMapper = nil);
begin
  FSQL := TStringBuilder.Create;
  FParams := TDictionary<string, TValue>.Create;
  FParamCount := 0;
  FDialect := ADialect;
  FColumnMapper := AMapper;
end;

destructor TSQLWhereGenerator.Destroy;
begin
  FSQL.Free;
  FParams.Free;
  inherited;
end;

function TSQLWhereGenerator.MapColumn(const AName: string): string;
begin
  if FColumnMapper <> nil then
    Result := FColumnMapper.MapColumn(AName)
  else
    Result := AName;
end;

function TSQLWhereGenerator.Generate(const AExpression: IExpression): string;
begin
  FSQL.Clear;
  FParams.Clear;
  FParamCount := 0;
  
  if AExpression = nil then
    Exit('');
    
  Process(AExpression);
  Result := FSQL.ToString;
end;

function TSQLWhereGenerator.GetNextParamName: string;
begin
  Inc(FParamCount);
  Result := 'p' + IntToStr(FParamCount);
end;

procedure TSQLWhereGenerator.Process(const AExpression: IExpression);
begin
  if AExpression is TBinaryExpression then
    ProcessBinary(TBinaryExpression(AExpression))
  else if AExpression is TLogicalExpression then
    ProcessLogical(TLogicalExpression(AExpression))
  else if AExpression is TUnaryExpression then
    ProcessUnary(TUnaryExpression(AExpression))
  else if AExpression is TConstantExpression then
    ProcessConstant(TConstantExpression(AExpression))
  else
    raise Exception.Create('Unknown expression type: ' + AExpression.ToString);
end;

procedure TSQLWhereGenerator.ProcessBinary(const C: TBinaryExpression);
var
  ParamName: string;
  ArrayValue: TValue;
  I: Integer;
  ParamNames: TStringBuilder;
  SQLCast: string;
  Converter: ITypeConverter;
  DialectEnum: TDatabaseDialect;
  Quoted: string;
begin
  // Special handling for IN and NOT IN operators
  if (C.BinaryOperator = boIn) or (C.BinaryOperator = boNotIn) then
  begin
    ArrayValue := C.Value;
    
    // Check if value is an array
    if ArrayValue.IsArray then
    begin
      ParamNames := TStringBuilder.Create;
      try
        // Generate parameter for each array element
        for I := 0 to ArrayValue.GetArrayLength - 1 do
        begin
          ParamName := GetNextParamName;
          FParams.Add(ParamName, ArrayValue.GetArrayElement(I));
          
          if I > 0 then
            ParamNames.Append(', ');
          ParamNames.Append(':').Append(ParamName);
        end;
        
        // Generate SQL: (Column IN (:p1, :p2, :p3))
        FSQL.Append('(')
            .Append(FDialect.QuoteIdentifier(MapColumn(C.PropertyName)))
            .Append(' ')
            .Append(GetBinaryOpSQL(C.BinaryOperator))
            .Append(' (')
            .Append(ParamNames.ToString)
            .Append('))');
      finally
        ParamNames.Free;
      end;
    end
    else
    begin
      // Fallback: treat as single value (shouldn't happen, but just in case)
      ParamName := GetNextParamName;
      FParams.Add(ParamName, C.Value);
      
      FSQL.Append('(')
          .Append(FDialect.QuoteIdentifier(MapColumn(C.PropertyName)))
          .Append(' ')
          .Append(GetBinaryOpSQL(C.BinaryOperator))
          .Append(' (:')
          .Append(ParamName)
          .Append('))');
    end;
  end
  else
  begin
    // Standard binary operator handling
    ParamName := GetNextParamName;
    
    // Store parameter value
    FParams.Add(ParamName, C.Value);
    
    // Generate SQL: (Column Op :Param)
    FSQL.Append('(')
        .Append(FDialect.QuoteIdentifier(MapColumn(C.PropertyName)))
        .Append(' ')
        .Append(GetBinaryOpSQL(C.BinaryOperator))
        .Append(' ');

    // Type converter support for SQL casting in WHERE clause
    Converter := TTypeConverterRegistry.Instance.GetConverter(C.Value.TypeInfo);
    
    // Determine Dialect Enum
    DialectEnum := ddUnknown;
    Quoted := FDialect.QuoteIdentifier('t');
    if Quoted.StartsWith('[') then DialectEnum := ddSQLServer
    else if Quoted.StartsWith('`') then DialectEnum := ddMySQL
    else if Quoted.StartsWith('"') then
    begin
       if SameText(FDialect.BooleanToSQL(True), 'TRUE') then DialectEnum := ddPostgreSQL
       else DialectEnum := ddSQLite;
    end;
    
    // Explicit casting for PostgreSQL UUIDs to avoid "operator does not exist" errors
    // Handle TGUID, TUUID types AND string-formatted GUIDs
    if (DialectEnum = ddPostgreSQL) and 
       ((C.Value.TypeInfo = TypeInfo(TGUID)) or 
        (C.Value.TypeInfo = TypeInfo(TUUID)) or
        ((C.Value.Kind in [tkString, tkUString, tkWString]) and
         ((Length(C.Value.AsString) = 36) or (Length(C.Value.AsString) = 38)) and
         (C.Value.AsString.IndexOf('-') > 0))) then
    begin
       SQLCast := ':' + ParamName + '::uuid';
    end
    else if Converter <> nil then
    begin
      SQLCast := Converter.GetSQLCast(':' + ParamName, DialectEnum);
    end
    else
      SQLCast := ':' + ParamName;

    FSQL.Append(SQLCast).Append(')');
  end;
end;

procedure TSQLWhereGenerator.ProcessLogical(const C: TLogicalExpression);
begin
  FSQL.Append('(');
  Process(C.Left);
  FSQL.Append(' ')
      .Append(GetLogicalOpSQL(C.LogicalOperator))
      .Append(' ');
  Process(C.Right);
  FSQL.Append(')');
end;

procedure TSQLWhereGenerator.ProcessUnary(const C: TUnaryExpression);
begin
  if C.UnaryOperator = uoNot then
  begin
    FSQL.Append('(NOT ');
    Process(C.Expression);
    FSQL.Append(')');
  end
  else
  begin
    // IsNull / IsNotNull
    FSQL.Append('(')
        .Append(FDialect.QuoteIdentifier(MapColumn(C.PropertyName)))
        .Append(' ')
        .Append(GetUnaryOpSQL(C.UnaryOperator))
        .Append(')');
  end;
end;

procedure TSQLWhereGenerator.ProcessConstant(const C: TConstantExpression);
begin
  if C.Value then
    FSQL.Append('(1=1)')
  else
    FSQL.Append('(1=0)');
end;

function TSQLWhereGenerator.GetBinaryOpSQL(Op: TBinaryOperator): string;
begin
  case Op of
    boEqual: Result := '=';
    boNotEqual: Result := '<>';
    boGreaterThan: Result := '>';
    boGreaterThanOrEqual: Result := '>=';
    boLessThan: Result := '<';
    boLessThanOrEqual: Result := '<=';
    boLike: Result := 'LIKE';
    boNotLike: Result := 'NOT LIKE';
    boIn: Result := 'IN';
    boNotIn: Result := 'NOT IN';
  else
    Result := '=';
  end;
end;

function TSQLWhereGenerator.GetLogicalOpSQL(Op: TLogicalOperator): string;
begin
  case Op of
    loAnd: Result := 'AND';
    loOr: Result := 'OR';
  else
    Result := 'AND';
  end;
end;

function TSQLWhereGenerator.GetUnaryOpSQL(Op: TUnaryOperator): string;
begin
  case Op of
    uoIsNull: Result := 'IS NULL';
    uoIsNotNull: Result := 'IS NOT NULL';
  else
    Result := '';
  end;
end;



{ TSQLColumnMapper<T> }

function TSQLColumnMapper<T>.MapColumn(const AName: string): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
begin
  Result := AName;
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  Prop := Typ.GetProperty(AName);
  if Prop <> nil then
  begin
    for Attr in Prop.GetAttributes do
    begin
      if Attr is ColumnAttribute then Exit(ColumnAttribute(Attr).Name);
      if Attr is ForeignKeyAttribute then Exit(ForeignKeyAttribute(Attr).ColumnName);
    end;
  end;
end;

{ TSQLGenerator<T> }

constructor TSQLGenerator<T>.Create(ADialect: ISQLDialect; AMap: TEntityMap = nil);
begin
  FDialect := ADialect;
  FMap := AMap;
  FParams := TDictionary<string, TValue>.Create;
  FParamCount := 0;
end;

destructor TSQLGenerator<T>.Destroy;
begin
  FParams.Free;
  inherited;
end;

function TSQLGenerator<T>.GetNextParamName: string;
begin
  Inc(FParamCount);
  Result := 'p' + IntToStr(FParamCount);
end;

function TSQLGenerator<T>.GetTableName: string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Attr: TCustomAttribute;
begin
  if (FMap <> nil) and (FMap.TableName <> '') then
    Exit(FMap.TableName);

  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  Result := Typ.Name;
  
  for Attr in Typ.GetAttributes do
    if Attr is TableAttribute then
      Result := TableAttribute(Attr).Name;

  Result := FDialect.QuoteIdentifier(Result);
  
  if (FSchema <> '') and FDialect.UseSchemaPrefix then
    Result := FDialect.QuoteIdentifier(FSchema) + '.' + Result;
end;

function TSQLGenerator<T>.GetSoftDeleteFilter: string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Attr: TCustomAttribute;
  SoftDeleteAttr: SoftDeleteAttribute;
  Prop: TRttiProperty;
  ColumnName: string;
  ParamName: string;
  PropName: string;
  DeletedVal, NotDeletedVal: Variant;
  IsSoftDelete: Boolean;
  PropMap: TPropertyMap;
begin
  Result := '';
  IsSoftDelete := False;
  PropName := '';
  DeletedVal := True;
  NotDeletedVal := False;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  if Typ = nil then Exit;
  
  // 1. Check Fluent Mapping
  if (FMap <> nil) and FMap.IsSoftDelete then
  begin
    IsSoftDelete := True;
    PropName := FMap.SoftDeleteProp;
    DeletedVal := FMap.SoftDeleteDeletedValue;
    NotDeletedVal := FMap.SoftDeleteNotDeletedValue;
  end
  // 2. Check Attribute
  else
  begin
    for Attr in Typ.GetAttributes do
    begin
      if Attr is SoftDeleteAttribute then
      begin
        SoftDeleteAttr := SoftDeleteAttribute(Attr);
        IsSoftDelete := True;
        PropName := SoftDeleteAttr.ColumnName;
        DeletedVal := SoftDeleteAttr.DeletedValue;
        NotDeletedVal := SoftDeleteAttr.NotDeletedValue;
        Break;
      end;
    end;
  end;
  
  if not IsSoftDelete then Exit;
  
  // Find actual column name
  ColumnName := PropName; // Default to Property Name
  
  for Prop in Typ.GetProperties do
  begin
    if SameText(Prop.Name, PropName) then
    begin
      // Priority 1: Fluent Property Map
      PropMap := nil;
      if (FMap <> nil) and FMap.Properties.TryGetValue(Prop.Name, PropMap) then
      begin
        if PropMap.ColumnName <> '' then
        begin
          ColumnName := PropMap.ColumnName;
          Break;
        end;
      end;
      
      // Priority 2: Column Attribute
      for Attr in Prop.GetAttributes do
      begin
        if Attr is ColumnAttribute then
        begin
          ColumnName := ColumnAttribute(Attr).Name;
          Break;
        end;
      end;
      Break;
    end;
  end;
  
  if FIgnoreQueryFilters then Exit;

  // Generate filter
  ParamName := 'pSoftDelete';
  
  if FOnlyDeleted then
  begin
     FParams.AddOrSetValue(ParamName, TValue.FromVariant(DeletedVal));
     Result := Format('%s = :%s', 
        [FDialect.QuoteIdentifier(ColumnName), ParamName]);
  end
  else
  begin
     // Use literal value for default state to optimize query plan
     var LiteralVal: string;
     
     if VarIsType(NotDeletedVal, varBoolean) then
     begin
       if Boolean(NotDeletedVal) then
         LiteralVal := '1'
       else
         LiteralVal := '0';
     end
     else
     begin
       // For strings, we need quotes. For numbers, we don't.
       // Keep it simple for now, generic VarToStr mostly works for numbers and simple strings might fail if not quoted, 
       // but typically SoftDelete values are numbers or booleans.
       // Safest is to handle string quoting if it looks like a string but not a number.
       // However, let's trust VarToStr for numbers and handle boolean explicitly as it's the current crashboard.
       LiteralVal := VarToStr(NotDeletedVal);
       
       if VarIsType(NotDeletedVal, varString) or VarIsType(NotDeletedVal, varUString) then
         LiteralVal := QuotedStr(LiteralVal);
     end;
  
     // A simplified approach compatible with the previous one:
     // If NotDeletedVal is 0, we treat NULL as 0.
     // Previous logic: COALESCE(Col, NotDeletedVal) = NotDeletedVal (matches NULL and 0)
     
     // Let's stick to the previous implementation as it was tested:
     FParams.AddOrSetValue(ParamName, TValue.FromVariant(NotDeletedVal));
     Result := Format('COALESCE(%s, %s) = :%s', 
       [FDialect.QuoteIdentifier(ColumnName), 
        LiteralVal, 
        ParamName]);
  end;
end;

function TSQLGenerator<T>.GetDiscriminatorValueSQL: string;
begin
  if (FMap <> nil) and (FMap.DiscriminatorValue <> Null) then
  begin
    if VarIsType(FMap.DiscriminatorValue, varString) or VarIsType(FMap.DiscriminatorValue, varUString) then
      Result := QuotedStr(VarToStr(FMap.DiscriminatorValue))
    else
      Result := VarToStr(FMap.DiscriminatorValue);
  end
  else
    Result := 'NULL';
end;

function TSQLGenerator<T>.GetDiscriminatorFilter: string;
begin
  Result := '';
  if (FMap <> nil) and (FMap.InheritanceStrategy = TInheritanceStrategy.TablePerHierarchy) and 
     (FMap.DiscriminatorColumn <> '') and (GetDiscriminatorValueSQL <> 'NULL') then
  begin
    Result := FDialect.QuoteIdentifier(FMap.DiscriminatorColumn) + ' = ' + GetDiscriminatorValueSQL;
    // Note: DiscriminatorColumn should be quoted if needed, but FMap usually has raw name. 
    // Ideally use FDialect.QuoteIdentifier(FMap.DiscriminatorColumn).
    // Let's fix that below.
  end;
end;

function TSQLGenerator<T>.GetDialectEnum: TDatabaseDialect;
var
  QuotedTest: string;
begin
  // Convert ISQLDialect to TDatabaseDialect enum
  // We detect the dialect by checking the quote identifier format
  QuotedTest := FDialect.QuoteIdentifier('test');
  
  if QuotedTest.StartsWith('[') then
    Result := ddSQLServer  // SQL Server uses [brackets]
  else if QuotedTest.StartsWith('`') then
    Result := ddMySQL      // MySQL uses `backticks`
  else if QuotedTest.StartsWith('"') then
  begin
    // Both PostgreSQL and SQLite use double quotes
    // Check BooleanToSQL to differentiate
    var BoolTest := FDialect.BooleanToSQL(True);
    if BoolTest = 'TRUE' then
      Result := ddPostgreSQL  // PostgreSQL uses TRUE/FALSE
    else
      Result := ddSQLite;     // SQLite uses 1/0
  end
  else
    Result := ddUnknown;
end;

function TSQLGenerator<T>.GenerateInsert(const AEntity: T): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ColName, ParamName: string;
  SBCols, SBVals: TStringBuilder;
  IsAutoInc, IsMapped, First: Boolean;
  Val: TValue;
  SQLCast: string;
  Converter: ITypeConverter;
  NullableHelper: TNullableHelper;
  PropMap: TPropertyMap;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBCols := TStringBuilder.Create;
  SBVals := TStringBuilder.Create;
  try
    First := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsMapped := True;
      IsAutoInc := False;
      ColName := Prop.Name;
      
      PropMap := nil;
      if FMap <> nil then
        FMap.Properties.TryGetValue(Prop.Name, PropMap);
        
      if PropMap <> nil then
      begin
        if PropMap.IsIgnored then IsMapped := False;
        if PropMap.IsAutoInc then IsAutoInc := True;
        if PropMap.ColumnName <> '' then ColName := PropMap.ColumnName;
      end;

      for Attr in Prop.GetAttributes do
      begin
        if Attr is NotMappedAttribute then IsMapped := False;
        
        if (PropMap = nil) or not PropMap.IsAutoInc then
          if Attr is AutoIncAttribute then IsAutoInc := True;
          
        if (PropMap = nil) or (PropMap.ColumnName = '') then
        begin
          if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
          if Attr is ForeignKeyAttribute then ColName := ForeignKeyAttribute(Attr).ColumnName;
        end;
      end;
      
      if not IsMapped or IsAutoInc then Continue;
      
      if not First then
      begin
        SBCols.Append(', ');
        SBVals.Append(', ');
      end;
      First := False;
      
      SBCols.Append(FDialect.QuoteIdentifier(ColName));
      
      
      Val := Prop.GetValue(Pointer(AEntity));
      
      // Check for Nullable<T>
      if IsNullable(Val.TypeInfo) then
      begin
        NullableHelper := TNullableHelper.Create(Val.TypeInfo);
        if not NullableHelper.HasValue(Val.GetReferenceToRawData) then
        begin
          // It is NULL.
          SBVals.Append('NULL');
          Continue; // Skip adding parameter
        end
        else
        begin
          // It has value. Extract it.
          Val := NullableHelper.GetValue(Val.GetReferenceToRawData);
        end;
      end;

      ParamName := GetNextParamName;
      
      // Check if there's a type converter that needs SQL casting
      Converter := TTypeConverterRegistry.Instance.GetConverter(Val.TypeInfo);
      if Converter <> nil then
      begin
        SQLCast := Converter.GetSQLCast(':' + ParamName, GetDialectEnum);
        SBVals.Append(SQLCast);
      end
      else
        SBVals.Append(':').Append(ParamName);
        
      FParams.Add(ParamName, Val);
    end;
    
    // Add Discriminator
    if (FMap <> nil) and (FMap.InheritanceStrategy = TInheritanceStrategy.TablePerHierarchy) and 
       (FMap.DiscriminatorColumn <> '') then
    begin
       // Check if already added? (Optimization: explicit loop check or just trust map setup usually implies shadow)
       // For now, simpler: assume shadow property if configured via HasDiscriminator
       // We should ideally check if ColName/Prop above handled it.
       // But HasDiscriminator implies it's metadata driven.
       // If a property maps to it, IsMapped would be true.
       // We can check if SBCols contains the column name... but string search is flaky.
       // Let's rely on standard practice: If users map it properly, they shouldn't use HasDiscriminator with const value?
       // Actually HasDiscriminator SETS the value.
       
       // Safe Add:
       if not SBCols.ToString.Contains(FDialect.QuoteIdentifier(FMap.DiscriminatorColumn)) then
       begin
         if SBCols.Length > 0 then
         begin
           SBCols.Append(', ');
           SBVals.Append(', ');
         end;
         SBCols.Append(FDialect.QuoteIdentifier(FMap.DiscriminatorColumn));
         SBVals.Append(GetDiscriminatorValueSQL);
       end;
    end;

    Result := Format('INSERT INTO %s (%s) VALUES (%s)', 
      [GetTableName, SBCols.ToString, SBVals.ToString]);
      
  finally
    SBCols.Free;
    SBVals.Free;
  end;
end;

function TSQLGenerator<T>.GenerateInsertTemplate(out AProps: TList<TPair<TRttiProperty, string>>): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ColName: string;
  SBCols, SBVals: TStringBuilder;
  IsAutoInc, IsMapped, First: Boolean;
  PropMap: TPropertyMap;
begin
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBCols := TStringBuilder.Create;
  SBVals := TStringBuilder.Create;
  AProps := TList<TPair<TRttiProperty, string>>.Create;
  
  try
    First := True;

    for Prop in Typ.GetProperties do
    begin
      IsMapped := True;
      IsAutoInc := False;
      ColName := Prop.Name;
      
      PropMap := nil;
      if FMap <> nil then
        FMap.Properties.TryGetValue(Prop.Name, PropMap);
        
      if PropMap <> nil then
      begin
        if PropMap.IsIgnored then IsMapped := False;
        if PropMap.IsAutoInc then IsAutoInc := True;
        if PropMap.ColumnName <> '' then ColName := PropMap.ColumnName;
      end;

      for Attr in Prop.GetAttributes do
      begin
        if Attr is NotMappedAttribute then IsMapped := False;
        
        if (PropMap = nil) or not PropMap.IsAutoInc then
          if Attr is AutoIncAttribute then IsAutoInc := True;
          
        if (PropMap = nil) or (PropMap.ColumnName = '') then
        begin
          if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
          if Attr is ForeignKeyAttribute then ColName := ForeignKeyAttribute(Attr).ColumnName;
        end;
      end;
      
      if not IsMapped or IsAutoInc then Continue;
      
      AProps.Add(TPair<TRttiProperty, string>.Create(Prop, ColName));
      
      if not First then
      begin
        SBCols.Append(', ');
        SBVals.Append(', ');
      end;
      First := False;
      
      SBCols.Append(FDialect.QuoteIdentifier(ColName));
      // Use Column Name as Parameter Name for Array DML
      SBVals.Append(':').Append(ColName); 
    end;
    
    Result := Format('INSERT INTO %s (%s) VALUES (%s)', 
      [GetTableName, SBCols.ToString, SBVals.ToString]);
      
  finally
    SBCols.Free;
    SBVals.Free;
    // AProps is returned, caller must free
  end;
end;

function TSQLGenerator<T>.GenerateUpdate(const AEntity: T): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ColName, ParamName, ParamNameNew: string;
  SBSet, SBWhere: TStringBuilder;
  IsPK, IsMapped, IsVersion: Boolean;
  Val: TValue;
  NewVersionVal: Integer;
  FirstSet, FirstWhere: Boolean;
  PropMap: TPropertyMap;
  SQLCastStr: string;
  Converter: ITypeConverter;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBSet := TStringBuilder.Create;
  SBWhere := TStringBuilder.Create;
  try
    FirstSet := True;
    FirstWhere := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsMapped := True;
      IsPK := False;
      IsVersion := False;
      ColName := Prop.Name;
      
      PropMap := nil;
      if FMap <> nil then
        FMap.Properties.TryGetValue(Prop.Name, PropMap);
        
      if PropMap <> nil then
      begin
        if PropMap.IsIgnored then IsMapped := False;
        if PropMap.IsPK then IsPK := True;
        // Version not yet supported in Fluent Mapping explicitly? Assuming no for now or check map.
        if PropMap.ColumnName <> '' then ColName := PropMap.ColumnName;
      end;

      for Attr in Prop.GetAttributes do
      begin
        if Attr is NotMappedAttribute then IsMapped := False;
        
        if (PropMap = nil) or not PropMap.IsPK then
          if Attr is PKAttribute then IsPK := True;
          
        if Attr is VersionAttribute then IsVersion := True; // Version attribute still respected
        
        if (PropMap = nil) or (PropMap.ColumnName = '') then
        begin
          if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
          if Attr is ForeignKeyAttribute then ColName := ForeignKeyAttribute(Attr).ColumnName;
        end;
      end;
      
      if not IsMapped then Continue;
      
      Val := Prop.GetValue(Pointer(AEntity));
      
      if IsVersion then
      begin
        // Optimistic Concurrency Logic
        
        // 1. Add to WHERE clause: Version = :OldVersion
        ParamName := GetNextParamName;
        FParams.Add(ParamName, Val);
        
        if not FirstWhere then SBWhere.Append(' AND ');
        FirstWhere := False;
        SBWhere.Append(FDialect.QuoteIdentifier(ColName)).Append(' = :').Append(ParamName);
        
        // 2. Add to SET clause: Version = :NewVersion (OldVersion + 1)
        ParamNameNew := GetNextParamName;
        if Val.IsEmpty then NewVersionVal := 1 else NewVersionVal := Val.AsInteger + 1;
        FParams.Add(ParamNameNew, NewVersionVal);
        
        if not FirstSet then SBSet.Append(', ');
        FirstSet := False;
        
        SQLCastStr := '';
        Converter := TTypeConverterRegistry.Instance.GetConverter(Prop.PropertyType.Handle);
        if Converter <> nil then
           SQLCastStr := Converter.GetSQLCast(':' + ParamNameNew, GetDialectEnum)
        else
           SQLCastStr := ':' + ParamNameNew;

        SBSet.Append(FDialect.QuoteIdentifier(ColName)).Append(' = ').Append(SQLCastStr);
      end
      else if IsPK then
      begin
        // Primary Key -> WHERE clause
        ParamName := GetNextParamName;
        FParams.Add(ParamName, Val);
        
        if not FirstWhere then SBWhere.Append(' AND ');
        FirstWhere := False;
        
        // Apply ::uuid cast for PostgreSQL if value is GUID/UUID or GUID-like string
        SQLCastStr := ':' + ParamName;
        if (GetDialectEnum = ddPostgreSQL) and
           ((Val.TypeInfo = TypeInfo(TGUID)) or 
            (Val.TypeInfo = TypeInfo(TUUID)) or
            ((Val.Kind in [tkString, tkUString, tkWString]) and
             ((Length(Val.AsString) = 36) or (Length(Val.AsString) = 38)) and
             (Val.AsString.IndexOf('-') > 0))) then
          SQLCastStr := ':' + ParamName + '::uuid';
        
        SBWhere.Append(FDialect.QuoteIdentifier(ColName)).Append(' = ').Append(SQLCastStr);
      end
      else
      begin
        // Standard Column -> SET clause
        ParamName := GetNextParamName;
        FParams.Add(ParamName, Val);
        
        if not FirstSet then SBSet.Append(', ');
        FirstSet := False;
        
        SQLCastStr := '';
        Converter := TTypeConverterRegistry.Instance.GetConverter(Prop.PropertyType.Handle);
        if Converter <> nil then
           SQLCastStr := Converter.GetSQLCast(':' + ParamName, GetDialectEnum)
        else
           SQLCastStr := ':' + ParamName;

        SBSet.Append(FDialect.QuoteIdentifier(ColName)).Append(' = ').Append(SQLCastStr);
      end;
    end;
    
    if SBWhere.Length = 0 then
      raise Exception.Create('Cannot generate UPDATE: No Primary Key defined.');
      
    Result := Format('UPDATE %s SET %s WHERE %s', 
      [GetTableName, SBSet.ToString, SBWhere.ToString]);
      
  finally
    SBSet.Free;
    SBWhere.Free;
  end;
end;

function TSQLGenerator<T>.GenerateDelete(const AEntity: T): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ColName, ParamName: string;
  SBWhere: TStringBuilder;
  IsPK, FirstWhere: Boolean;
  Val: TValue;
  PropMap: TPropertyMap;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBWhere := TStringBuilder.Create;
  try
    FirstWhere := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsPK := False;
      ColName := Prop.Name;
      
      PropMap := nil;
      if FMap <> nil then
        FMap.Properties.TryGetValue(Prop.Name, PropMap);
        
      if PropMap <> nil then
      begin
        if PropMap.IsPK then IsPK := True;
        if PropMap.ColumnName <> '' then ColName := PropMap.ColumnName;
      end;

      for Attr in Prop.GetAttributes do
      begin
        if (PropMap = nil) or not PropMap.IsPK then
          if Attr is PKAttribute then IsPK := True;
          
        if (PropMap = nil) or (PropMap.ColumnName = '') then
          if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
      end;
      
      if not IsPK then Continue;
      
      Val := Prop.GetValue(Pointer(AEntity));
      ParamName := GetNextParamName;
      FParams.Add(ParamName, Val);
      
      if not FirstWhere then SBWhere.Append(' AND ');
      FirstWhere := False;
      
      // Apply ::uuid cast for PostgreSQL if value is GUID/UUID or GUID-like string
      var SQLCastStr := ':' + ParamName;
      if (GetDialectEnum = ddPostgreSQL) and
         ((Val.TypeInfo = TypeInfo(TGUID)) or 
          (Val.TypeInfo = TypeInfo(TUUID)) or
          ((Val.Kind in [tkString, tkUString, tkWString]) and
           ((Length(Val.AsString) = 36) or (Length(Val.AsString) = 38)) and
           (Val.AsString.IndexOf('-') > 0))) then
        SQLCastStr := ':' + ParamName + '::uuid';
      
      SBWhere.Append(FDialect.QuoteIdentifier(ColName)).Append(' = ').Append(SQLCastStr);
    end;
    
    if SBWhere.Length = 0 then
      raise Exception.Create('Cannot generate DELETE: No Primary Key defined.');
      
    Result := Format('DELETE FROM %s WHERE %s', 
      [GetTableName, SBWhere.ToString]);
      
  finally
    SBWhere.Free;
  end;
end;

function TSQLGenerator<T>.GenerateSelect(const ASpec: ISpecification<T>): string;
var
  WhereGen: TSQLWhereGenerator;
  WhereSQL: string;
  SB: TStringBuilder;
  Prop: TRttiProperty;
  ColName: string;
  Attr: TCustomAttribute;
  Ctx: TRttiContext;
  Typ: TRttiType;
  First: Boolean;
  SelectedCols: TArray<string>;
  OrderBy: TArray<IOrderBy>;
  Skip, Take, i: Integer;
  Pair: TPair<string, TValue>;
  IsMapped: Boolean;
  PropMap: TPropertyMap;
  SoftDeleteFilter, DiscriminatorFilter: string;
  SortCol: string;
  P: TRttiProperty;
begin
  FParams.Clear;
  FParamCount := 0;
  
  WhereGen := TSQLWhereGenerator.Create(FDialect, TSQLColumnMapper<T>.Create);
    
  try
    WhereSQL := WhereGen.Generate(ASpec.GetExpression);
    
    // Copy params
    for Pair in WhereGen.Params do
    begin
      FParams.Add(Pair.Key, Pair.Value);
    end;
  finally
    WhereGen.Free;
  end;
  
  SB := TStringBuilder.Create;
  try
    SB.Append('SELECT ');
    
    SelectedCols := ASpec.GetSelectedColumns;
    if Length(SelectedCols) > 0 then
    begin
      // Custom projection
      for i := 0 to High(SelectedCols) do
      begin
        if i > 0 then SB.Append(', ');
        SB.Append(FDialect.QuoteIdentifier(SelectedCols[i]));
      end;
    end
    else
    begin
      // Select all mapped columns
      Ctx := TRttiContext.Create;
      Typ := Ctx.GetType(T);
      First := True;
      
      for Prop in Typ.GetProperties do
      begin
        ColName := Prop.Name;
        IsMapped := True;
        
        PropMap := nil;
        if FMap <> nil then
          FMap.Properties.TryGetValue(Prop.Name, PropMap);
          
        if PropMap <> nil then
        begin
          if PropMap.IsIgnored then IsMapped := False;
          if PropMap.ColumnName <> '' then ColName := PropMap.ColumnName;
        end;

        for Attr in Prop.GetAttributes do
        begin
          if Attr is NotMappedAttribute then IsMapped := False;
          
          if (PropMap = nil) or (PropMap.ColumnName = '') then
          begin
            if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
            if Attr is ForeignKeyAttribute then ColName := ForeignKeyAttribute(Attr).ColumnName;
          end;
        end;
        
        if not IsMapped then Continue;
        
        if not First then SB.Append(', ');
        First := False;
        
        SB.Append(FDialect.QuoteIdentifier(ColName));
      end;
    end;
    
    SB.Append(' FROM ').Append(GetTableName);
    
    // Add soft delete filter
    SoftDeleteFilter := GetSoftDeleteFilter;
    DiscriminatorFilter := GetDiscriminatorFilter;
    
    // Combine filters
    if DiscriminatorFilter <> '' then
    begin
       if SoftDeleteFilter <> '' then
         SoftDeleteFilter := SoftDeleteFilter + ' AND ' + DiscriminatorFilter
       else
         SoftDeleteFilter := DiscriminatorFilter;
    end;
    
    if WhereSQL <> '' then
    begin
      SB.Append(' WHERE ').Append(WhereSQL);
      if SoftDeleteFilter <> '' then
        SB.Append(' AND ').Append(SoftDeleteFilter);
    end
    else if SoftDeleteFilter <> '' then
      SB.Append(' WHERE ').Append(SoftDeleteFilter);
      
    // Order By
    OrderBy := ASpec.GetOrderBy;
    if Length(OrderBy) > 0 then
    begin
      SB.Append(' ORDER BY ');
      for i := 0 to High(OrderBy) do
      begin
        if i > 0 then SB.Append(', ');
        
        SortCol := OrderBy[i].GetPropertyName;
        // Lookup column name (simplified)
        Ctx := TRttiContext.Create;
        Typ := Ctx.GetType(T);
        P := Typ.GetProperty(SortCol);
        if P <> nil then
        begin
           for Attr in P.GetAttributes do
           begin
             if Attr is ColumnAttribute then SortCol := ColumnAttribute(Attr).Name;
             if Attr is ForeignKeyAttribute then SortCol := ForeignKeyAttribute(Attr).ColumnName;
           end;
        end;
        
        SB.Append(FDialect.QuoteIdentifier(SortCol));
        
        if not OrderBy[i].GetAscending then
          SB.Append(' DESC');
      end;
    end;
    
    // Paging
    if ASpec.IsPagingEnabled then
    begin
      // SQL Server requires ORDER BY when using OFFSET/FETCH
      // If no ORDER BY was specified, add a default one ONLY if dialect requires it
      if (Length(OrderBy) = 0) and FDialect.RequiresOrderByForPaging then
      begin
        SB.Append(' ORDER BY ');
        // Use first column or (SELECT NULL) as fallback
        if Length(SelectedCols) > 0 then
          SB.Append(FDialect.QuoteIdentifier(SelectedCols[0]))
        else
          SB.Append('(SELECT NULL)');
      end;
      
      Skip := ASpec.GetSkip;
      Take := ASpec.GetTake;
      Result := SB.ToString + ' ' + FDialect.GeneratePaging(Skip, Take);
    end
    else
    begin
      Result := SB.ToString;
    end;
    
  finally
    SB.Free;
  end;
end;

function TSQLGenerator<T>.GenerateSelect: string;
var
  SB: TStringBuilder;
  Prop: TRttiProperty;
  ColName: string;
  Attr: TCustomAttribute;
  Ctx: TRttiContext;
  Typ: TRttiType;
  First, IsMapped: Boolean;
  PropMap: TPropertyMap;
  SoftDeleteFilter, DiscriminatorFilter: string;
begin
  FParams.Clear;
  FParamCount := 0;

  SB := TStringBuilder.Create;
  try
    SB.Append('SELECT ');

    // Select all mapped columns
    Ctx := TRttiContext.Create;
    Typ := Ctx.GetType(T);
    First := True;

    for Prop in Typ.GetProperties do
    begin
      ColName := Prop.Name;
      IsMapped := True;

      PropMap := nil;
      if FMap <> nil then
        FMap.Properties.TryGetValue(Prop.Name, PropMap);

      if PropMap <> nil then
      begin
        if PropMap.IsIgnored then IsMapped := False;
        if PropMap.ColumnName <> '' then ColName := PropMap.ColumnName;
      end;

      for Attr in Prop.GetAttributes do
      begin
        if Attr is NotMappedAttribute then IsMapped := False;

        if (PropMap = nil) or (PropMap.ColumnName = '') then
        begin
          if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
          if Attr is ForeignKeyAttribute then ColName := ForeignKeyAttribute(Attr).ColumnName;
        end;
      end;

      if not IsMapped then Continue;

      if not First then SB.Append(', ');
      First := False;

      SB.Append(FDialect.QuoteIdentifier(ColName));
    end;

    SB.Append(' FROM ').Append(GetTableName);

    // Add soft delete filter
    SoftDeleteFilter := GetSoftDeleteFilter;
    DiscriminatorFilter := GetDiscriminatorFilter;
    
    if DiscriminatorFilter <> '' then
    begin
       if SoftDeleteFilter <> '' then
         SoftDeleteFilter := ' WHERE ' + SoftDeleteFilter + ' AND ' + DiscriminatorFilter
       else
         SoftDeleteFilter := ' WHERE ' + DiscriminatorFilter;
    end
    else if SoftDeleteFilter <> '' then
       SoftDeleteFilter := ' WHERE ' + SoftDeleteFilter;
       
    SB.Append(SoftDeleteFilter);

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TSQLGenerator<T>.GenerateCount(const ASpec: ISpecification<T>): string;
var
  WhereGen: TSQLWhereGenerator;
  WhereSQL: string;
  SB: TStringBuilder;
  SoftDeleteFilter, DiscriminatorFilter: string;
  Pair: TPair<string, TValue>;
begin
  FParams.Clear;
  FParamCount := 0;
  
  WhereGen := TSQLWhereGenerator.Create(FDialect, TSQLColumnMapper<T>.Create);
    
  try
    WhereSQL := WhereGen.Generate(ASpec.GetExpression);
    
    // Copy params
    for Pair in WhereGen.Params do
    begin
      FParams.Add(Pair.Key, Pair.Value);
    end;
  finally
    WhereGen.Free;
  end;
  
  SB := TStringBuilder.Create;
  try
    SB.Append('SELECT COUNT(*) FROM ').Append(GetTableName);
    
    // Add soft delete filter
    SoftDeleteFilter := GetSoftDeleteFilter;
    DiscriminatorFilter := GetDiscriminatorFilter;
    
    if DiscriminatorFilter <> '' then
    begin
       if SoftDeleteFilter <> '' then
         SoftDeleteFilter := SoftDeleteFilter + ' AND ' + DiscriminatorFilter
       else
         SoftDeleteFilter := DiscriminatorFilter;
    end;
    
    if WhereSQL <> '' then
    begin
      SB.Append(' WHERE ').Append(WhereSQL);
      if SoftDeleteFilter <> '' then
        SB.Append(' AND ').Append(SoftDeleteFilter);
    end
    else if SoftDeleteFilter <> '' then
      SB.Append(' WHERE ').Append(SoftDeleteFilter);
      
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TSQLGenerator<T>.GenerateCount: string;
var
  SoftDeleteFilter, DiscriminatorFilter: string;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Result := 'SELECT COUNT(*) FROM ' + GetTableName;
  
  // Add soft delete filter
  SoftDeleteFilter := GetSoftDeleteFilter;
  DiscriminatorFilter := GetDiscriminatorFilter;
  
  if DiscriminatorFilter <> '' then
  begin
     if SoftDeleteFilter <> '' then
       Result := Result + ' WHERE ' + SoftDeleteFilter + ' AND ' + DiscriminatorFilter
     else
       Result := Result + ' WHERE ' + DiscriminatorFilter;
  end
  else if SoftDeleteFilter <> '' then
    Result := Result + ' WHERE ' + SoftDeleteFilter;
end;

function TSQLGenerator<T>.GenerateCreateTable(const ATableName: string): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ColName, ColType, Body: string;
  SB: TStringBuilder;
  First, IsPK, IsAutoInc, IsMapped, HasAutoInc: Boolean;
  PKCols: TList<string>;
  FKConstraints: TList<string>;
  Constraint: string;
  TypeAttr: TCustomAttribute;
  PropMap: TPropertyMap;
  i: Integer;
  FK: ForeignKeyAttribute;
  FKPropName: string;
  FKColName: string;
  RelatedTable, RelatedPK: string;
  LConstraint: string;
  PropTypeHandle: PTypeInfo;
  Underlying: PTypeInfo;
  IsSoftDeleteColumn: Boolean;
  SoftDeleteDefaultValue: Variant;
  SoftDelAttr: SoftDeleteAttribute;
begin
  SB := TStringBuilder.Create;
  PKCols := TList<string>.Create;
  FKConstraints := TList<string>.Create;
  try
    Ctx := TRttiContext.Create;
    Typ := Ctx.GetType(T);
    First := True;
    HasAutoInc := False;
    
    for Prop in Typ.GetProperties do
    begin
      // 1. Check for Foreign Keys (even if NotMapped)
      for Attr in Prop.GetAttributes do
      begin
        if Attr is ForeignKeyAttribute then
        begin
          FK := ForeignKeyAttribute(Attr);
          FKPropName := FK.ColumnName;
          FKColName := TSQLGeneratorHelper.GetColumnNameForProperty(Typ, FKPropName);
          
          if (Prop.PropertyType.TypeKind = tkClass) and 
             TSQLGeneratorHelper.GetRelatedTableAndPK(Ctx, Prop.PropertyType.AsInstance.MetaclassType, RelatedTable, RelatedPK) then
          begin
             LConstraint := Format('FOREIGN KEY (%s) REFERENCES %s (%s)', 
               [FDialect.QuoteIdentifier(FKColName), 
                FDialect.QuoteIdentifier(RelatedTable), 
                FDialect.QuoteIdentifier(RelatedPK)]);
                
             if FK.OnDelete <> caNoAction then
               LConstraint := LConstraint + ' ON DELETE ' + TSQLGeneratorHelper.GetCascadeSQL(FK.OnDelete);
               
             if FK.OnUpdate <> caNoAction then
               LConstraint := LConstraint + ' ON UPDATE ' + TSQLGeneratorHelper.GetCascadeSQL(FK.OnUpdate);
               
             FKConstraints.Add(LConstraint);
          end;
        end;
      end;
    
      IsMapped := True;
      IsPK := False;
      IsAutoInc := False;
      ColName := Prop.Name;
      
      PropMap := nil;
      if FMap <> nil then
        FMap.Properties.TryGetValue(Prop.Name, PropMap);
        
      if PropMap <> nil then
      begin
        if PropMap.IsIgnored then IsMapped := False;
        if PropMap.IsPK then IsPK := True;
        if PropMap.IsAutoInc then IsAutoInc := True;
        if PropMap.ColumnName <> '' then ColName := PropMap.ColumnName;
      end;
      
      for Attr in Prop.GetAttributes do
      begin
        if Attr is NotMappedAttribute then IsMapped := False;
        // Attributes only apply if not overridden by Fluent (or we can merge, but Fluent usually wins)
        // Here we let Fluent win if defined.
        
        if (PropMap = nil) or not PropMap.IsPK then
          if Attr is PKAttribute then IsPK := True;
          
        if (PropMap = nil) or not PropMap.IsAutoInc then
          if Attr is AutoIncAttribute then IsAutoInc := True;
          
        if (PropMap = nil) or (PropMap.ColumnName = '') then
        begin
          if Attr is ColumnAttribute then ColName := ColumnAttribute(Attr).Name;
          if Attr is ForeignKeyAttribute then ColName := ForeignKeyAttribute(Attr).ColumnName;
        end;
      end;
      
      if not IsMapped then Continue;
      
      if not First then SB.Append(', ');
      First := False;
      
      SB.Append(FDialect.QuoteIdentifier(ColName));
      SB.Append(' ');
      
      PropTypeHandle := Prop.PropertyType.Handle;
      
      // Handle Nullable<T>
      if IsNullable(Prop.PropertyType.Handle) then
      begin
        Underlying := GetUnderlyingType(Prop.PropertyType.Handle);
        if Underlying <> nil then
          PropTypeHandle := Underlying;
      end;
      
      ColType := FDialect.GetColumnType(PropTypeHandle, IsAutoInc);
      SB.Append(ColType);
      
      // Check if this is a soft delete column and add DEFAULT
      IsSoftDeleteColumn := False;
      for TypeAttr in Typ.GetAttributes do
      begin
        if TypeAttr is SoftDeleteAttribute then
        begin
          SoftDelAttr := SoftDeleteAttribute(TypeAttr);
          if SameText(ColName, SoftDelAttr.ColumnName) then
          begin
            IsSoftDeleteColumn := True;
            SoftDeleteDefaultValue := SoftDelAttr.NotDeletedValue;
            Break;
          end;
        end;
      end;
      
      if IsPK then
      begin
        PKCols.Add(FDialect.QuoteIdentifier(ColName));
        if IsAutoInc then
        begin
            SB.Append(' PRIMARY KEY'); // AutoInc implies PK
            HasAutoInc := True;
        end
        else
           SB.Append(' NOT NULL');
      end
      else if IsSoftDeleteColumn then
      begin
        // Add DEFAULT for soft delete column
        SB.Append(' DEFAULT ').Append(VarToStr(SoftDeleteDefaultValue));
      end;
    end;
    
    // Add Composite PK constraint or Single PK constraint (if not AutoInc)
    if (PKCols.Count > 0) and not HasAutoInc then
    begin
      SB.Append(', PRIMARY KEY (');
      for i := 0 to PKCols.Count - 1 do
      begin
        if i > 0 then SB.Append(', ');
        SB.Append(PKCols[i]);
      end;
      SB.Append(')');
    end;
    
    // Add FK Constraints
    for Constraint in FKConstraints do
    begin
      SB.Append(', ').Append(Constraint);
    end;
    
    Body := SB.ToString;
    Result := FDialect.GetCreateTableSQL(ATableName, Body);
  finally
    FKConstraints.Free;
    PKCols.Free;
    SB.Free;
  end;
end;

end.

