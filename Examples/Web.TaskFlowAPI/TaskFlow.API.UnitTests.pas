unit TaskFlow.API.UnitTests;

interface

procedure RunUnitTests;

implementation

uses
  System.SysUtils,
  TaskFlow.Domain,
  TaskFlow.Repository.Mock,
  TaskFlow.Repository.Interfaces;

procedure RunUnitTests;
var
  Repo: ITaskRepository;
  Task: TTask;
begin
  WriteLn('');
  WriteLn('🔬 UNIT TESTS (No HTTP required)');
  WriteLn('================================');

  Repo := TTaskRepositoryMock.Create;

  try
    // Teste 1: Criação de task
    Write('1. Task creation... ');
    Task := TTask.CreateQuick('Unit Test Task', tpHigh);
    Task := Repo.CreateTask(Task);
    if Task.Id > 0 then
      WriteLn('✅ ID=', Task.Id)
    else
      WriteLn('❌ Failed');

    // Teste 2: Busca por ID
    Write('2. Get by ID... ');
    var FoundTask := Repo.GetById(Task.Id);
    if FoundTask.Id = Task.Id then
      WriteLn('✅ Found')
    else
      WriteLn('❌ Not found');

    // Teste 3: Filtro por status
    Write('3. Filter by status... ');
    var CompletedTasks := Repo.GetTasksByStatus(tsCompleted);
    WriteLn('✅ Found ', Length(CompletedTasks), ' completed tasks');

    // Teste 4: Estatísticas
    Write('4. Statistics... ');
    var Stats := Repo.GetTasksStats;
    WriteLn('✅ Total: ', Stats.TotalTasks, ', Completed: ', Stats.CompletedCount);

    // Teste 5: Enum conversion
    Write('5. Enum conversion... ');
    var Status := TTaskStatus.tsInProgress;
    var StatusStr := Status.ToString;
    var ConvertedStatus: TTaskStatus;

    if TTaskStatus.TryFromString(StatusStr, ConvertedStatus) and (ConvertedStatus = Status) then
      WriteLn('✅ Round-trip conversion works')
    else
      WriteLn('❌ Conversion failed');

    WriteLn('');
    WriteLn('🎉 UNIT TESTS COMPLETED!');

  except
    on E: Exception do
      WriteLn('❌ Unit test error: ', E.Message);
  end;
end;

end.
