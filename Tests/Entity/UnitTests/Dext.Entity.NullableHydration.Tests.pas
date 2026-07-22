unit Dext.Entity.NullableHydration.Tests;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Rtti,
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
  [Table('nullable_entities')]
  TNullableHydrationEntity = class
  private
    FId: Integer;
    FName: string;
    FAge: Nullable<Integer>;
    FUpdatedAt: Nullable<TDateTime>;
  public
    [PrimaryKey]
    property Id: Integer read FId write FId;
    property Name: string read FName write FName;
    property Age: Nullable<Integer> read FAge write FAge;
    property UpdatedAt: Nullable<TDateTime> read FUpdatedAt write FUpdatedAt;
  end;

  [TestFixture('Entity Nullable Hydration')]
  TEntityNullableHydrationTests = class
  public
    [Test]
    procedure Should_Keep_Nullable_Properties_Empty_When_Reader_Returns_Null;

    [Test]
    procedure Should_Hydrate_Nullable_Properties_When_Reader_Returns_Value;
  end;

implementation

procedure TEntityNullableHydrationTests.Should_Keep_Nullable_Properties_Empty_When_Reader_Returns_Null;
var
  Conn: Mock<IDbConnection>;
  Cmd: Mock<IDbCommand>;
  Reader: Mock<IDbReader>;
  Ctx: TDbContext;
  Items: IList<TNullableHydrationEntity>;
begin
  Conn := Mock<IDbConnection>.Create;
  Cmd := Mock<IDbCommand>.Create;
  Reader := Mock<IDbReader>.Create;

  Reader.Setup.ReturnsInSequence([True, False]).When.Next;
  Reader.Setup.Returns(4).When.GetColumnCount;
  Reader.Setup.Returns('Id').When.GetColumnName(0);
  Reader.Setup.Returns('Name').When.GetColumnName(1);
  Reader.Setup.Returns('Age').When.GetColumnName(2);
  Reader.Setup.Returns('UpdatedAt').When.GetColumnName(3);
  Reader.Setup.Returns(TValue.From<Integer>(1)).When.GetValue(0);
  Reader.Setup.Returns(TValue.From<string>('Alice')).When.GetValue(1);
  Reader.Setup.Returns(TValue.Empty).When.GetValue(2);
  Reader.Setup.Returns(TValue.Empty).When.GetValue(3);

  Reader.Setup.Returns(False).When.IsNull(0);
  Reader.Setup.Returns(False).When.IsNull(1);
  Reader.Setup.Returns(True).When.IsNull(2);
  Reader.Setup.Returns(True).When.IsNull(3);
  Reader.Setup.Returns(1).When.GetInt32(0);
  Reader.Setup.Returns('Alice').When.GetString(1);

  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);
  Cmd.Setup.Returns(Reader.Instance).When.ExecuteQuery;

  Ctx := TDbContext.Create(Conn.Instance, TSQLiteDialect.Create);
  try
    Items := Ctx.Entities<TNullableHydrationEntity>.ToList;
    Should(Items.Count).Be(1);
    Should(Items[0].Id).Be(1);
    Should(Items[0].Name).Be('Alice');
    Should(Items[0].Age.HasValue).BeFalse;
    Should(Items[0].UpdatedAt.HasValue).BeFalse;
  finally
    Items := nil;
    Ctx.Free;
  end;
end;

procedure TEntityNullableHydrationTests.Should_Hydrate_Nullable_Properties_When_Reader_Returns_Value;
var
  Conn: Mock<IDbConnection>;
  Cmd: Mock<IDbCommand>;
  Reader: Mock<IDbReader>;
  Ctx: TDbContext;
  Items: IList<TNullableHydrationEntity>;
  ExpectedDate: TDateTime;
begin
  ExpectedDate := EncodeDate(2026, 3, 31) + EncodeTime(10, 15, 0, 0);

  Conn := Mock<IDbConnection>.Create;
  Cmd := Mock<IDbCommand>.Create;
  Reader := Mock<IDbReader>.Create;

  Reader.Setup.ReturnsInSequence([True, False]).When.Next;
  Reader.Setup.Returns(4).When.GetColumnCount;
  Reader.Setup.Returns('Id').When.GetColumnName(0);
  Reader.Setup.Returns('Name').When.GetColumnName(1);
  Reader.Setup.Returns('Age').When.GetColumnName(2);
  Reader.Setup.Returns('UpdatedAt').When.GetColumnName(3);
  Reader.Setup.Returns(TValue.From<Integer>(2)).When.GetValue(0);
  Reader.Setup.Returns(TValue.From<string>('Bob')).When.GetValue(1);
  Reader.Setup.Returns(TValue.From<Integer>(42)).When.GetValue(2);
  Reader.Setup.Returns(TValue.From<TDateTime>(ExpectedDate)).When.GetValue(3);

  Reader.Setup.Returns(False).When.IsNull(0);
  Reader.Setup.Returns(False).When.IsNull(1);
  Reader.Setup.Returns(False).When.IsNull(2);
  Reader.Setup.Returns(False).When.IsNull(3);
  Reader.Setup.Returns(2).When.GetInt32(0);
  Reader.Setup.Returns('Bob').When.GetString(1);

  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);
  Cmd.Setup.Returns(Reader.Instance).When.ExecuteQuery;

  Ctx := TDbContext.Create(Conn.Instance, TSQLiteDialect.Create);
  try
    Items := Ctx.Entities<TNullableHydrationEntity>.ToList;
    Should(Items.Count).Be(1);
    Should(Items[0].Id).Be(2);
    Should(Items[0].Name).Be('Bob');
    Should(Items[0].Age.HasValue).BeTrue;
    Should(Items[0].Age.Value).Be(42);
    Should(Items[0].UpdatedAt.HasValue).BeTrue;
    Should(Items[0].UpdatedAt.Value).Be(ExpectedDate);
  finally
    Items := nil;
    Ctx.Free;
  end;
end;

end.
