unit Dext.Entity.DefaultValue.Tests;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Variants,
  Dext.Collections,
  Dext.Assertions,
  Dext.Testing.Attributes,
  Dext.Mocks,
  Dext.Mocks.Matching,
  Dext.Entity.Attributes,
  Dext.Entity.Context,
  Dext.Entity.Drivers.Interfaces,
  Dext.Entity.Dialects,
  Dext.Types.Nullable;

type
  [Table('default_value_entities')]
  TDefaultValueEntity = class
  private
    FId: Integer;
    FStatus: string;
    FAge: Integer;
    FScore: Nullable<Double>;
  public
    [PrimaryKey]
    property Id: Integer read FId write FId;

    [DefaultValue('Ativo')]
    property Status: string read FStatus write FStatus;

    [DefaultValue(18)]
    property Age: Integer read FAge write FAge;

    [DefaultValue(100.0)]
    property Score: Nullable<Double> read FScore write FScore;
  end;

  [TestFixture('Entity DefaultValue Hydration')]
  TEntityDefaultValueTests = class
  public
    [Test]
    procedure Should_Apply_Default_Values_When_Database_Returns_Null;

    [Test]
    procedure Should_Ignore_Default_Values_When_Database_Returns_Data;
  end;

implementation

procedure TEntityDefaultValueTests.Should_Apply_Default_Values_When_Database_Returns_Null;
var
  Conn: Mock<IDbConnection>;
  Cmd: Mock<IDbCommand>;
  Reader: Mock<IDbReader>;
  Ctx: TDbContext;
  Items: IList<TDefaultValueEntity>;
begin
  Conn := Mock<IDbConnection>.Create;
  Cmd := Mock<IDbCommand>.Create;
  Reader := Mock<IDbReader>.Create;

  Reader.Setup.ReturnsInSequence([True, False]).When.Next;
  Reader.Setup.Returns(4).When.GetColumnCount;
  Reader.Setup.Returns('Id').When.GetColumnName(0);
  Reader.Setup.Returns('Status').When.GetColumnName(1);
  Reader.Setup.Returns('Age').When.GetColumnName(2);
  Reader.Setup.Returns('Score').When.GetColumnName(3);

  // DB returns ID but alles else is NULL
  Reader.Setup.Returns(TValue.From<Integer>(1)).When.GetValue(0);
  Reader.Setup.Returns(TValue.Empty).When.GetValue(1);
  Reader.Setup.Returns(TValue.Empty).When.GetValue(2);
  Reader.Setup.Returns(TValue.Empty).When.GetValue(3);

  Reader.Setup.Returns(False).When.IsNull(0);
  Reader.Setup.Returns(True).When.IsNull(1);
  Reader.Setup.Returns(True).When.IsNull(2);
  Reader.Setup.Returns(True).When.IsNull(3);
  Reader.Setup.Returns(1).When.GetInt32(0);

  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);
  Cmd.Setup.Returns(Reader.Instance).When.ExecuteQuery;

  Ctx := TDbContext.Create(Conn.Instance, TSQLiteDialect.Create);
  try
    Items := Ctx.Entities<TDefaultValueEntity>.ToList;
    Should(Items.Count).Be(1);
    Should(Items[0].Id).Be(1);
    Should(Items[0].Status).Be('Ativo');
    Should(Items[0].Age).Be(18);
    Should(Items[0].Score.HasValue).BeTrue;
    Should(Items[0].Score.Value).Be(100.0);
  finally
    Items := nil;
    Ctx.Free;
  end;
end;

procedure TEntityDefaultValueTests.Should_Ignore_Default_Values_When_Database_Returns_Data;
var
  Conn: Mock<IDbConnection>;
  Cmd: Mock<IDbCommand>;
  Reader: Mock<IDbReader>;
  Ctx: TDbContext;
  Items: IList<TDefaultValueEntity>;
begin
  Conn := Mock<IDbConnection>.Create;
  Cmd := Mock<IDbCommand>.Create;
  Reader := Mock<IDbReader>.Create;

  Reader.Setup.ReturnsInSequence([True, False]).When.Next;
  Reader.Setup.Returns(4).When.GetColumnCount;
  Reader.Setup.Returns('Id').When.GetColumnName(0);
  Reader.Setup.Returns('Status').When.GetColumnName(1);
  Reader.Setup.Returns('Age').When.GetColumnName(2);
  Reader.Setup.Returns('Score').When.GetColumnName(3);

  // DB returns explicit data
  Reader.Setup.Returns(TValue.From<Integer>(2)).When.GetValue(0);
  Reader.Setup.Returns(TValue.From<string>('Inativo')).When.GetValue(1);
  Reader.Setup.Returns(TValue.From<Integer>(25)).When.GetValue(2);
  Reader.Setup.Returns(TValue.From<Double>(50.5)).When.GetValue(3);

  Reader.Setup.Returns(False).When.IsNull(0);
  Reader.Setup.Returns(False).When.IsNull(1);
  Reader.Setup.Returns(False).When.IsNull(2);
  Reader.Setup.Returns(False).When.IsNull(3);
  Reader.Setup.Returns(2).When.GetInt32(0);
  Reader.Setup.Returns('Inativo').When.GetString(1);
  Reader.Setup.Returns(25).When.GetInt32(2);

  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);
  Cmd.Setup.Returns(Reader.Instance).When.ExecuteQuery;

  Ctx := TDbContext.Create(Conn.Instance, TSQLiteDialect.Create);
  try
    Items := Ctx.Entities<TDefaultValueEntity>.ToList;
    Should(Items.Count).Be(1);
    Should(Items[0].Id).Be(2);
    Should(Items[0].Status).Be('Inativo');
    Should(Items[0].Age).Be(25);
    Should(Items[0].Score.HasValue).BeTrue;
    Should(Items[0].Score.Value).Be(50.5);
  finally
    Items := nil;
    Ctx.Free;
  end;
end;

end.
