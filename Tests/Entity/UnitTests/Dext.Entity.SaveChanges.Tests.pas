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

end.
