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
  Dext.Types.Nullable;

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

    function GetNextParamName: string;
    function GetTableName: string;
    function GetSoftDeleteFilter: string;

  public
    constructor Create(ADialect: ISQLDialect; AMap: TEntityMap = nil);
    destructor Destroy; override;
    
    property IgnoreQueryFilters: Boolean read FIgnoreQueryFilters write FIgnoreQueryFilters;
    property OnlyDeleted: Boolean read FOnlyDeleted write FOnlyDeleted;
    
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
  RAttr: TCustomAttribute;
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
        for var SubAttr in RProp.GetAttributes do
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
        .Append(' :')
        .Append(ParamName)
        .Append(')');
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
      Exit(TableAttribute(Attr).Name);
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
      var PropMap: TPropertyMap := nil;
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

function TSQLGenerator<T>.GenerateInsert(const AEntity: T): string;
var
  Ctx: TRttiContext;
  Typ: TRttiType;
  Prop: TRttiProperty;
  Attr: TCustomAttribute;
  ColName, ParamName: string;
  SBCols, SBVals: TStringBuilder;
  IsAutoInc, IsMapped: Boolean;
  Val: TValue;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBCols := TStringBuilder.Create;
  SBVals := TStringBuilder.Create;
  try
    var First := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsMapped := True;
      IsAutoInc := False;
      ColName := Prop.Name;
      
      var PropMap: TPropertyMap := nil;
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
        var Helper := TNullableHelper.Create(Val.TypeInfo);
        if not Helper.HasValue(Val.GetReferenceToRawData) then
        begin
          // It is NULL.
          SBVals.Append('NULL');
          Continue; // Skip adding parameter
        end
        else
        begin
          // It has value. Extract it.
          Val := Helper.GetValue(Val.GetReferenceToRawData);
        end;
      end;

      ParamName := GetNextParamName;
      SBVals.Append(':').Append(ParamName);
      FParams.Add(ParamName, Val);
    end;
    
    Result := Format('INSERT INTO %s (%s) VALUES (%s)', 
      [FDialect.QuoteIdentifier(GetTableName), SBCols.ToString, SBVals.ToString]);
      
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
  IsAutoInc, IsMapped: Boolean;
begin
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBCols := TStringBuilder.Create;
  SBVals := TStringBuilder.Create;
  AProps := TList<TPair<TRttiProperty, string>>.Create;
  
  try
    var First := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsMapped := True;
      IsAutoInc := False;
      ColName := Prop.Name;
      
      var PropMap: TPropertyMap := nil;
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
      [FDialect.QuoteIdentifier(GetTableName), SBCols.ToString, SBVals.ToString]);
      
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
begin
  FParams.Clear;
  FParamCount := 0;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBSet := TStringBuilder.Create;
  SBWhere := TStringBuilder.Create;
  try
    var FirstSet := True;
    var FirstWhere := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsMapped := True;
      IsPK := False;
      IsVersion := False;
      ColName := Prop.Name;
      
      var PropMap: TPropertyMap := nil;
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
        SBSet.Append(FDialect.QuoteIdentifier(ColName)).Append(' = :').Append(ParamNameNew);
      end
      else if IsPK then
      begin
        // Primary Key -> WHERE clause
        ParamName := GetNextParamName;
        FParams.Add(ParamName, Val);
        
        if not FirstWhere then SBWhere.Append(' AND ');
        FirstWhere := False;
        SBWhere.Append(FDialect.QuoteIdentifier(ColName)).Append(' = :').Append(ParamName);
      end
      else
      begin
        // Standard Column -> SET clause
        ParamName := GetNextParamName;
        FParams.Add(ParamName, Val);
        
        if not FirstSet then SBSet.Append(', ');
        FirstSet := False;
        SBSet.Append(FDialect.QuoteIdentifier(ColName)).Append(' = :').Append(ParamName);
      end;
    end;
    
    if SBWhere.Length = 0 then
      raise Exception.Create('Cannot generate UPDATE: No Primary Key defined.');
      
    Result := Format('UPDATE %s SET %s WHERE %s', 
      [FDialect.QuoteIdentifier(GetTableName), SBSet.ToString, SBWhere.ToString]);
      
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
  IsPK: Boolean;
  Val: TValue;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Ctx := TRttiContext.Create;
  Typ := Ctx.GetType(T);
  
  SBWhere := TStringBuilder.Create;
  try
    var FirstWhere := True;
    
    for Prop in Typ.GetProperties do
    begin
      IsPK := False;
      ColName := Prop.Name;
      
      var PropMap: TPropertyMap := nil;
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
      SBWhere.Append(FDialect.QuoteIdentifier(ColName)).Append(' = :').Append(ParamName);
    end;
    
    if SBWhere.Length = 0 then
      raise Exception.Create('Cannot generate DELETE: No Primary Key defined.');
      
    Result := Format('DELETE FROM %s WHERE %s', 
      [FDialect.QuoteIdentifier(GetTableName), SBWhere.ToString]);
      
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
  Skip, Take: Integer;
begin
  FParams.Clear;
  FParamCount := 0;
  
  WhereGen := TSQLWhereGenerator.Create(FDialect, TSQLColumnMapper<T>.Create);
    
  try
    WhereSQL := WhereGen.Generate(ASpec.GetExpression);
    
    // Copy params
    for var Pair in WhereGen.Params do
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
      for var i := 0 to High(SelectedCols) do
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
        var IsMapped := True;
        
        var PropMap: TPropertyMap := nil;
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
    
    SB.Append(' FROM ').Append(FDialect.QuoteIdentifier(GetTableName));
    
    // Add soft delete filter
    var SoftDeleteFilter := GetSoftDeleteFilter;
    
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
      for var i := 0 to High(OrderBy) do
      begin
        if i > 0 then SB.Append(', ');
        
        var SortCol := OrderBy[i].GetPropertyName;
        // Lookup column name (simplified)
        Ctx := TRttiContext.Create;
        Typ := Ctx.GetType(T);
        var P := Typ.GetProperty(SortCol);
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
  First: Boolean;
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
      var IsMapped := True;

      var PropMap: TPropertyMap := nil;
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

    SB.Append(' FROM ').Append(FDialect.QuoteIdentifier(GetTableName));

    // Add soft delete filter
    var SoftDeleteFilter := GetSoftDeleteFilter;
    if SoftDeleteFilter <> '' then
      SB.Append(' WHERE ').Append(SoftDeleteFilter);

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
begin
  FParams.Clear;
  FParamCount := 0;
  
  WhereGen := TSQLWhereGenerator.Create(FDialect, TSQLColumnMapper<T>.Create);
    
  try
    WhereSQL := WhereGen.Generate(ASpec.GetExpression);
    
    // Copy params
    for var Pair in WhereGen.Params do
    begin
      FParams.Add(Pair.Key, Pair.Value);
    end;
  finally
    WhereGen.Free;
  end;
  
  SB := TStringBuilder.Create;
  try
    SB.Append('SELECT COUNT(*) FROM ').Append(FDialect.QuoteIdentifier(GetTableName));
    
    // Add soft delete filter
    var SoftDeleteFilter := GetSoftDeleteFilter;
    
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
  SoftDeleteFilter: string;
begin
  FParams.Clear;
  FParamCount := 0;
  
  Result := 'SELECT COUNT(*) FROM ' + FDialect.QuoteIdentifier(GetTableName);
  
  // Add soft delete filter
  SoftDeleteFilter := GetSoftDeleteFilter;
  if SoftDeleteFilter <> '' then
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
  IsPK, IsAutoInc, IsMapped, HasAutoInc: Boolean;
  First: Boolean;
  PKCols: TList<string>;
  FKConstraints: TList<string>;
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
          var FK := ForeignKeyAttribute(Attr);
          var FKPropName := FK.ColumnName;
          var FKColName := TSQLGeneratorHelper.GetColumnNameForProperty(Typ, FKPropName);
          var RelatedTable, RelatedPK: string;
          
          if (Prop.PropertyType.TypeKind = tkClass) and 
             TSQLGeneratorHelper.GetRelatedTableAndPK(Ctx, Prop.PropertyType.AsInstance.MetaclassType, RelatedTable, RelatedPK) then
          begin
             var Constraint := Format('FOREIGN KEY (%s) REFERENCES %s (%s)', 
               [FDialect.QuoteIdentifier(FKColName), 
                FDialect.QuoteIdentifier(RelatedTable), 
                FDialect.QuoteIdentifier(RelatedPK)]);
                
             if FK.OnDelete <> caNoAction then
               Constraint := Constraint + ' ON DELETE ' + TSQLGeneratorHelper.GetCascadeSQL(FK.OnDelete);
               
             if FK.OnUpdate <> caNoAction then
               Constraint := Constraint + ' ON UPDATE ' + TSQLGeneratorHelper.GetCascadeSQL(FK.OnUpdate);
               
             FKConstraints.Add(Constraint);
          end;
        end;
      end;
    
      IsMapped := True;
      IsPK := False;
      IsAutoInc := False;
      ColName := Prop.Name;
      
      var PropMap: TPropertyMap := nil;
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
      
      var PropTypeHandle := Prop.PropertyType.Handle;
      
      // Handle Nullable<T>
      if IsNullable(Prop.PropertyType.Handle) then
      begin
        var Underlying := GetUnderlyingType(Prop.PropertyType.Handle);
        if Underlying <> nil then
          PropTypeHandle := Underlying;
      end;
      
      ColType := FDialect.GetColumnType(PropTypeHandle, IsAutoInc);
      SB.Append(ColType);
      
      // Check if this is a soft delete column and add DEFAULT
      var IsSoftDeleteColumn := False;
      var SoftDeleteDefaultValue: Variant;
      for var TypeAttr in Typ.GetAttributes do
      begin
        if TypeAttr is SoftDeleteAttribute then
        begin
          var SoftDelAttr := SoftDeleteAttribute(TypeAttr);
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
      for var i := 0 to PKCols.Count - 1 do
      begin
        if i > 0 then SB.Append(', ');
        SB.Append(PKCols[i]);
      end;
      SB.Append(')');
    end;
    
    // Add FK Constraints
    for var Constraint in FKConstraints do
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

