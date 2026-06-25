unit TestCollections.PersonList;

interface

uses
  System.SysUtils,
  Dext.Testing,
  Dext.Collections;

type
  TPerson = class
  private
    FId: Integer;
    FName: string;
  public
    constructor Create(AId: Integer; const AName: string);
    property Id: Integer read FId;
    property Name: string read FName;
  end;

  [TestFixture('List - Class TPerson Operations')]
  TListPersonTests = class
  public
    [Test]
    procedure Add_Person_ShouldIncreaseCount;

    [Test]
    procedure Add_Person_In_The_Middle_ShouldHaveRightPosition;

    [Test]
    procedure Remove_Person_ShouldUpdateList;

    [Test]
    procedure Find_Person_ByName_ShouldWork;

    [Test]
    procedure Clear_OwnsObjects_ShouldFreePersons;
  end;

implementation

{ TPerson }

constructor TPerson.Create(AId: Integer; const AName: string);
begin
  inherited Create;
  FId := AId;
  FName := AName;
end;

{ TListPersonTests }

procedure TListPersonTests.Add_Person_In_The_Middle_ShouldHaveRightPosition;
var
  List: IList<TPerson>;
begin
  List := TCollections.CreateList<TPerson>(True); // OwnsObjects = True
  List.Add(TPerson.Create(1, 'First One'));
  List.Add(TPerson.Create(3, 'Last One'));

  Should(List.Count).Be(2);
  Should(List[0].Id).Be(1);
  Should(List[1].Id).Be(3);

  List.Insert(1, TPerson.Create(2, 'Second One'));
  Should(List.Count).Be(3);
  Should(List[0].Id).Be(1);
  Should(List[1].Id).Be(2);
  Should(List[2].Id).Be(3);
end;

procedure TListPersonTests.Add_Person_ShouldIncreaseCount;
var
  List: IList<TPerson>;
begin
  List := TCollections.CreateList<TPerson>(True); // OwnsObjects = True
  List.Add(TPerson.Create(1, 'John Doe'));
  List.Add(TPerson.Create(2, 'Jane Doe'));

  Should(List.Count).Be(2);
  Should(List[0].Name).Be('John Doe');
  Should(List[1].Name).Be('Jane Doe');
end;

procedure TListPersonTests.Remove_Person_ShouldUpdateList;
var
  List: IList<TPerson>;
  P1, P2: TPerson;
begin
  List := TCollections.CreateList<TPerson>(True);
  P1 := TPerson.Create(1, 'John Doe');
  P2 := TPerson.Create(2, 'Jane Doe');
  List.Add(P1);
  List.Add(P2);

  // When removing P1, it will be freed because OwnsObjects is True.
  // So we shouldn't access P1 after this.
  List.Remove(P1); 

  Should(List.Count).Be(1);
  Should(List[0].Id).Be(2);
end;

procedure TListPersonTests.Find_Person_ByName_ShouldWork;
var
  List: IList<TPerson>;
  Found: TPerson;
begin
  List := TCollections.CreateList<TPerson>(True);
  List.Add(TPerson.Create(1, 'John Doe'));
  List.Add(TPerson.Create(2, 'Jane Doe'));
  List.Add(TPerson.Create(3, 'Bob Smith'));

  Found := List.Where(function(P: TPerson): Boolean
    begin
      Result := P.Name = 'Jane Doe';
    end).First;

  Should(Found).NotBeNil;
  Should(Found.Id).Be(2);
end;

procedure TListPersonTests.Clear_OwnsObjects_ShouldFreePersons;
var
  List: IList<TPerson>;
begin
  List := TCollections.CreateList<TPerson>(True);
  List.Add(TPerson.Create(1, 'John Doe'));
  List.Add(TPerson.Create(2, 'Jane Doe'));
  
  List.Clear;
  Should(List.Count).Be(0);
end;

end.
