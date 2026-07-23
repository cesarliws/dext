unit Dext.Entity.DbType.Test;

interface

uses
  System.SysUtils,
  System.Rtti,
  Data.DB,
  System.TypInfo,
  System.Generics.Collections,
  Dext.Collections.Dict,
  Dext.Entity.Attributes,
  Dext.Entity.Mapping,
  Dext.Entity.Dialects,
  Dext.Specifications.SQL.Generator;

type
  [Table('db_type_test')]
  TDbTypeEntity = class
  private
    FId: Integer;
    FDateOnly: TDateTime;
    FDecimalVal: Currency;
  public
    [PK, AutoInc]
    property Id: Integer read FId write FId;

    [DbType(ftDate)]
    property DateOnly: TDateTime read FDateOnly write FDateOnly;

    [DbType(ftFMTBcd)]
    property DecimalVal: Currency read FDecimalVal write FDecimalVal;
  end;

  TDbTypeTest = class
  private
    procedure Log(const Msg: string);
  public
    procedure Run;
  end;

implementation

{ TDbTypeTest }

procedure TDbTypeTest.Log(const Msg: string);
begin
  WriteLn(Msg);
end;

procedure TDbTypeTest.Run;
var
  Generator: TSQLGenerator<TDbTypeEntity>;
  Entity: TDbTypeEntity;
  Dialect: ISQLDialect;
  ParamType: TFieldType;
  Found: Boolean;
  Pair: Dext.Collections.Dict.TPair<string, TValue>;
  Typ: TFieldType;
  DateParamName, DecimalParamName: string;
  HasDate, HasBcd: Boolean;
begin
  Log('[DB]  Testing [DbType] Attribute Propagation');
  Log('=========================================');

  Dialect := TSQLiteDialect.Create;
  Generator := TSQLGenerator<TDbTypeEntity>.Create(Dialect);
  try
    Entity := TDbTypeEntity.Create;
    try
      Entity.Id := 1;
      Entity.DateOnly := Now;
      Entity.DecimalVal := 123.45;

      // 1. Test Insert Generation
      Generator.GenerateInsert(Entity);

      Log('Testing ParamTypes collection after GenerateInsert:');

      // We need to find which parameter name corresponds to which property.
      // Parameters are named p1, p2, etc. in order of properties.
      // Order in class: DateOnly, DecimalVal (Id is AutoInc, usually skipped in basic insert if not specified,
      // but GenerateInsert uses skipped AutoInc logic).

      for Pair in Generator.Params do
      begin
        Found := Generator.ParamTypes.TryGetValue(Pair.Key, ParamType);
        if Found then
          Log(Format('   Parameter %s: Type %s', [Pair.Key, GetEnumName(TypeInfo(TFieldType), Ord(ParamType))]))
        else
          Log(Format('   Parameter %s: No explicit type', [Pair.Key]));
      end;

      // Asserting specific types
      // DateOnly should have ftDate
      // DecimalVal should have ftFMTBcd

      DateParamName := '';
      DecimalParamName := '';

      // Simple discovery for this test (knowing p1, p2 order)
      // Actually, order depends on RTTI. p1 is usually DateOnly, p2 is DecimalVal.
      // Better: check if ftDate and ftFMTBcd are present at all in ParamTypes.

      HasDate := False;
      HasBcd := False;

      for Typ in Generator.ParamTypes.Values do
      begin
        if Typ = ftDate then HasDate := True;
        if Typ = ftFMTBcd then HasBcd := True;
      end;

      if HasDate then Log('   [PASS] ftDate found in ParamTypes') else Log('   [FAIL] ftDate NOT found in ParamTypes');
      if HasBcd then Log('   [PASS] ftFMTBcd found in ParamTypes') else Log('   [FAIL] ftFMTBcd NOT found in ParamTypes');

      // 2. Test Update Generation
      Generator.GenerateUpdate(Entity);
      Log('Testing ParamTypes collection after GenerateUpdate:');

      HasDate := False;
      HasBcd := False;
      for Typ in Generator.ParamTypes.Values do
      begin
        if Typ = ftDate then HasDate := True;
        if Typ = ftFMTBcd then HasBcd := True;
      end;

      if HasDate then Log('   [PASS] ftDate found in ParamTypes') else Log('   [FAIL] ftDate NOT found in ParamTypes');
      if HasBcd then Log('   [PASS] ftFMTBcd found in ParamTypes') else Log('   [FAIL] ftFMTBcd NOT found in ParamTypes');

    finally
      Entity.Free;
    end;
  finally
    Generator.Free;
  end;
end;

end.
