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
{  Created: 2026-07-16                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Entity.SaveChanges.Tests;

interface

uses
  Data.DB,
  System.Classes,
  System.Rtti,
  System.SysUtils,
  System.TypInfo,
  Dext.Assertions,
  Dext.Collections,
  Dext.Core.Reflection,
  Dext.Entity.Attributes,
  Dext.Entity.Context,
  Dext.Entity.Dialects,
  Dext.Entity.Drivers.Interfaces,
  Dext.Interception,
  Dext.Mocks,
  Dext.Mocks.Matching,
  Dext.Testing.Attributes;

type
{$M+}
  [Table('test_parent')]
  TTestParent = class
  private
    FId: Integer;
    FNome: string;
  public
    [PK]
    property Id: Integer read FId write FId;
    [Column('nome')]
    property Nome: string read FNome write FNome;
  end;

  [Table('test_child')]
  TTestChild = class
  private
    FId: Integer;
    FParentId: Integer;
    FParent: TTestParent;
  public
    [PK]
    property Id: Integer read FId write FId;
    [Column('parent_id')]
    property ParentId: Integer read FParentId write FParentId;
    [ForeignKey('ParentId'), NotMapped]
    property Parent: TTestParent read FParent write FParent;
  end;
{$M-}

  [TestFixture('SaveChanges Transaction and Dependency Ordering Tests')]
  TSaveChangesTests = class
  public
    [Test]
    [Description('Verify SaveChanges does not commit external transaction')]
    procedure TestSaveChangesShouldPreserveExternalTransaction;

    [Test]
    [Description('Verify SaveChanges commits its own transaction')]
    procedure TestSaveChangesShouldCommitOwnTransaction;

    [Test]
    [Description('Verify SaveChanges inserts parent before child topologically')]
    procedure TestSaveChangesShouldInsertTopologically;

    [Test]
    [Description('Verify UseSql<T> hydrates raw SQL rows into typed DTO objects')]
    procedure TestUseSqlGenericDtoHydration;

    [Test]
    [Description('Verify UseSqlFirst<T> hydrates first matching record or returns nil')]
    procedure TestUseSqlFirstGenericDtoHydration;
  end;

implementation

{ TSaveChangesTests }

procedure TSaveChangesTests.TestSaveChangesShouldPreserveExternalTransaction;
var
  Conn: Mock<IDbConnection>;
  Tx: Mock<IDbTransaction>;
  Cmd: Mock<IDbCommand>;
  Ctx: TDbContext;
  Parent: TTestParent;
begin
  Conn := Mock<IDbConnection>.Create;
  Tx := Mock<IDbTransaction>.Create;
  Cmd := Mock<IDbCommand>.Create;

  Conn.Setup.Returns(Tx.Instance).When.BeginTransaction;
  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);
  
  Ctx := TDbContext.Create(Conn.Instance, TSQLiteDialect.Create);
  try
    Ctx.BeginTransaction;
    Should(Ctx.InTransaction).BeTrue;

    Parent := TTestParent.Create;
    Parent.Id := 1;
    Parent.Nome := 'Parent';
    Ctx.Entities<TTestParent>.Add(Parent);
    
    Ctx.SaveChanges;
    
    Should(Ctx.InTransaction).BeTrue;
    Tx.Verify(Times.Never).Commit;
    
    Ctx.Commit;
    Should(Ctx.InTransaction).BeFalse;
    Tx.Verify(Times.Once).Commit;
  finally
    Ctx.Free;
  end;
end;

procedure TSaveChangesTests.TestSaveChangesShouldCommitOwnTransaction;
var
  Conn: Mock<IDbConnection>;
  Tx: Mock<IDbTransaction>;
  Cmd: Mock<IDbCommand>;
  Ctx: TDbContext;
  Parent: TTestParent;
begin
  Conn := Mock<IDbConnection>.Create;
  Tx := Mock<IDbTransaction>.Create;
  Cmd := Mock<IDbCommand>.Create;

  Conn.Setup.Returns(Tx.Instance).When.BeginTransaction;
  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);

  Ctx := TDbContext.Create(Conn.Instance, TSQLiteDialect.Create);
  try
    Parent := TTestParent.Create;
    Parent.Id := 1;
    Parent.Nome := 'Parent';
    Ctx.Entities<TTestParent>.Add(Parent);

    Should(Ctx.InTransaction).BeFalse;

    Ctx.SaveChanges;

    Should(Ctx.InTransaction).BeFalse;
    Tx.Verify(Times.Once).Commit;
  finally
    Ctx.Free;
  end;
end;

procedure TSaveChangesTests.TestSaveChangesShouldInsertTopologically;
var
  Conn: Mock<IDbConnection>;
  Cmd: Mock<IDbCommand>;
  Ctx: TDbContext;
  Parent: TTestParent;
  Child: TTestChild;
  CommandsList: IList<string>;
begin
  Conn := Mock<IDbConnection>.Create;
  Cmd := Mock<IDbCommand>.Create;
  CommandsList := TCollections.CreateList<string>;

  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);
  
  Conn.Setup.Executes(
    procedure(Inv: IInvocation)
    begin
      CommandsList.Add(Inv.Arguments[0].AsString);
      Inv.Result := TValue.From<IDbCommand>(Cmd.Instance);
    end).When.CreateCommand(Arg.Any<string>);

  Ctx := TDbContext.Create(Conn.Instance, TSQLiteDialect.Create);
  try
    Writeln('DIAGNOSTICS:');
    Writeln('TypeInfo(TTestParent): ', Format('%p', [TypeInfo(TTestParent)]));
    Writeln('TTestParent.ClassInfo: ', Format('%p', [TTestParent.ClassInfo]));
    Writeln('Prop Handle: ', Format('%p', [
      TReflection.Context.GetType(TTestChild)
        .GetProperty('Parent').PropertyType.Handle]));

    Parent := TTestParent.Create;
    Parent.Id := 1;
    Parent.Nome := 'Parent';

    Child := TTestChild.Create;
    Child.Id := 1;
    Child.ParentId := 1;
    Child.Parent := Parent;

    Ctx.Entities<TTestChild>.Add(Child);
    Ctx.Entities<TTestParent>.Add(Parent);

    Ctx.SaveChanges;

    Should(CommandsList.Count).BeGreaterOrEqualTo(2);

    Should(CommandsList[0]).Contain('test_parent');
    Should(CommandsList[1]).Contain('test_child');
  finally
    Ctx.Free;
    CommandsList := nil;
  end;
end;

type
  TDtoSummary = class
  private
    FId: Integer;
    FNomeCliente: string;
    FValorTotal: Double;
  public
    property Id: Integer read FId write FId;
    property NomeCliente: string read FNomeCliente write FNomeCliente;
    property ValorTotal: Double read FValorTotal write FValorTotal;
  end;

procedure TSaveChangesTests.TestUseSqlGenericDtoHydration;
var
  Conn: Mock<IDbConnection>;
  Cmd: Mock<IDbCommand>;
  Reader: Mock<IDbReader>;
  Ctx: TDbContext;
  List: IList<TDtoSummary>;
  NextCallCount: Integer;
begin
  Conn := Mock<IDbConnection>.Create;
  Cmd := Mock<IDbCommand>.Create;
  Reader := Mock<IDbReader>.Create;

  NextCallCount := 0;
  Reader.Setup.Executes(
    procedure(Inv: IInvocation)
    begin
      Inc(NextCallCount);
      Inv.Result := TValue.From<Boolean>(NextCallCount = 1);
    end).When.Next;

  Reader.Setup.Returns(3).When.GetColumnCount;
  Reader.Setup.Returns('id').When.GetColumnName(0);
  Reader.Setup.Returns('nome_cliente').When.GetColumnName(1);
  Reader.Setup.Returns('valor_total').When.GetColumnName(2);
  Reader.Setup.Returns(False).When.IsNull(Arg.Any<Integer>);
  Reader.Setup.Returns(101).When.GetValue(0);
  Reader.Setup.Returns('Acme Corp').When.GetValue(1);
  Reader.Setup.Returns(1500.50).When.GetValue(2);

  Cmd.Setup.Returns(Reader.Instance).When.ExecuteQuery;
  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);

  Ctx := TDbContext.Create(Conn.Instance, TSQLiteDialect.Create);
  try
    List := Ctx.SqlQuery<TDtoSummary>('SELECT id, nome_cliente, valor_total FROM faturas WHERE id = :id', [TValue.From<Integer>(101)]);
    try
      Should(List.Count).Be(1);
      Should(List[0].Id).Be(101);
      Should(List[0].NomeCliente).Be('Acme Corp');
      Should(List[0].ValorTotal).Be(1500.50);
    finally
      List := nil;
    end;
  finally
    Ctx.Free;
  end;
end;

procedure TSaveChangesTests.TestUseSqlFirstGenericDtoHydration;
var
  Conn: Mock<IDbConnection>;
  Cmd: Mock<IDbCommand>;
  Reader: Mock<IDbReader>;
  Ctx: TDbContext;
  Item: TDtoSummary;
  NextCallCount: Integer;
begin
  Conn := Mock<IDbConnection>.Create;
  Cmd := Mock<IDbCommand>.Create;
  Reader := Mock<IDbReader>.Create;

  NextCallCount := 0;
  Reader.Setup.Executes(
    procedure(Inv: IInvocation)
    begin
      Inc(NextCallCount);
      Inv.Result := TValue.From<Boolean>(NextCallCount = 1);
    end).When.Next;

  Reader.Setup.Returns(3).When.GetColumnCount;
  Reader.Setup.Returns('id').When.GetColumnName(0);
  Reader.Setup.Returns('nome_cliente').When.GetColumnName(1);
  Reader.Setup.Returns('valor_total').When.GetColumnName(2);
  Reader.Setup.Returns(False).When.IsNull(Arg.Any<Integer>);
  Reader.Setup.Returns(202).When.GetValue(0);
  Reader.Setup.Returns('Globex Inc').When.GetValue(1);
  Reader.Setup.Returns(3200.00).When.GetValue(2);

  Cmd.Setup.Returns(Reader.Instance).When.ExecuteQuery;
  Conn.Setup.Returns(Cmd.Instance).When.CreateCommand(Arg.Any<string>);

  Ctx := TDbContext.Create(Conn.Instance, TSQLiteDialect.Create);
  try
    Item := Ctx.SqlQueryFirst<TDtoSummary>('SELECT id, nome_cliente, valor_total FROM faturas WHERE id = :id', [TValue.From<Integer>(202)]);
    try
      Should(Item).NotBeNil;
      Should(Item.Id).Be(202);
      Should(Item.NomeCliente).Be('Globex Inc');
      Should(Item.ValorTotal).Be(3200.00);
    finally
      Item.Free;
    end;
  finally
    Ctx.Free;
  end;
end;

end.
