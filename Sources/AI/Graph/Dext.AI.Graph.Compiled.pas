{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Graph - Orquestração de agentes estilo LangGraph        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    TCompiledAgent — resultado de TAgentGraph.Compile().                   }
{    Executa o grafo nó a nó, gerenciando estado e checkpoints.             }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Graph.Compiled;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Dext.AI.Graph.Contracts,
  Dext.AI.Graph.State,
  Dext.AI.Graph.Edge,
  Dext.AI.Graph.Graph,
  Dext.AI.Graph.Checkpointer,
  Dext.AI.Agent.Contracts;

type
  TCompiledAgent = class(TInterfacedObject, ICompiledAgent)
  private
    FNodes:           TDictionary<string, TGraphNode>;
    FEdges:           TList<TEdge>;
    FEntryPoint:      string;
    FInterruptBefore: TArray<string>;
    FContext:         TNodeContext;
    FCheckpointer:    ICheckpointer;
    FMaxIterations:   Integer;
    FHeldState:       TAgentState;

    function ExecuteNode(
      const ANodeName: string;
      const AState:    TAgentState
    ): TAgentState;

    function ResolveNextNode(
      const ACurrentNode: string;
      const AState:       TAgentState
    ): string;

    function ShouldInterrupt(const ANodeName: string): Boolean;
    function GenerateThreadId: string;
    procedure CheckpointSave(const AThreadId: string; AState: TAgentState);
    function CheckpointLoad(const AThreadId: string): TAgentState;
    function ExecuteLoop(AState: TAgentState; ASkipFirstInterrupt: Boolean): TGraphRunResult;
    function DescribePending(AState: TAgentState; const ANode: string): string;
  public
    constructor Create(
      ANodes:           TDictionary<string, TGraphNode>;
      AEdges:           TList<TEdge>;
      const AEntryPoint: string;
      const AInterruptBefore: TArray<string>;
      const AContext:   TNodeContext;
      ACheckpointer:    ICheckpointer;
      AMaxIterations:   Integer
    );
    destructor Destroy; override;

    function Run(
      const AInput:    string;
      const AThreadId: string = ''
    ): TGraphRunResult;

    function Resume(const AThreadId: string): TGraphRunResult;
    procedure Cancel(const AThreadId: string);
    function GetState(const AThreadId: string): TObject;
  end;

implementation

function ReplaceState(var Current: TAgentState; NewState: TAgentState): TAgentState;
begin
  if (Current <> nil) and (Current <> NewState) then
    Current.Free;
  Current := NewState;
  Result := Current;
end;

{ TCompiledAgent }

constructor TCompiledAgent.Create(
  ANodes: TDictionary<string, TGraphNode>;
  AEdges: TList<TEdge>;
  const AEntryPoint: string;
  const AInterruptBefore: TArray<string>;
  const AContext: TNodeContext;
  ACheckpointer: ICheckpointer;
  AMaxIterations: Integer
);
var
  Pair: TPair<string, TGraphNode>;
  Edge: TEdge;
begin
  inherited Create;
  FNodes := TDictionary<string, TGraphNode>.Create;
  if ANodes <> nil then
    for Pair in ANodes do
      FNodes.Add(Pair.Key, Pair.Value);

  FEdges := TList<TEdge>.Create;
  if AEdges <> nil then
    for Edge in AEdges do
      FEdges.Add(Edge);

  FEntryPoint      := AEntryPoint;
  FInterruptBefore := Copy(AInterruptBefore);
  FContext         := AContext;
  FCheckpointer    := ACheckpointer;
  if AMaxIterations <= 0 then
    FMaxIterations := 15
  else
    FMaxIterations := AMaxIterations;
end;

destructor TCompiledAgent.Destroy;
begin
  FHeldState.Free;
  FEdges.Free;
  FNodes.Free;
  inherited;
end;

function TCompiledAgent.GenerateThreadId: string;
begin
  Result := TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').ToLower;
end;

procedure TCompiledAgent.CheckpointSave(const AThreadId: string; AState: TAgentState);
begin
  if (FCheckpointer = nil) or (AState = nil) then
    Exit;
  FCheckpointer.Save(AThreadId, AState.ToJson);
end;

function TCompiledAgent.CheckpointLoad(const AThreadId: string): TAgentState;
begin
  if FCheckpointer = nil then
    raise EGraphError.Create('Checkpointer não configurado');
  Result := TAgentState.FromJson(FCheckpointer.Load(AThreadId));
end;

function TCompiledAgent.ShouldInterrupt(const ANodeName: string): Boolean;
var
  S: string;
  Node: TGraphNode;
begin
  for S in FInterruptBefore do
    if S = ANodeName then
      Exit(True);
  if FNodes.TryGetValue(ANodeName, Node) and Node.RequiresApproval then
    Exit(True);
  Result := False;
end;

function TCompiledAgent.DescribePending(AState: TAgentState; const ANode: string): string;
begin
  if (AState <> nil) and AState.HasPendingCalls then
    Result := Format('Executar tool "%s" no nó %s', [AState.PendingCalls[0].Name, ANode])
  else
    Result := 'Aguardando aprovação para executar o nó ' + ANode;
end;

function TCompiledAgent.ExecuteNode(
  const ANodeName: string;
  const AState: TAgentState
): TAgentState;
var
  Node: TGraphNode;
begin
  if not FNodes.TryGetValue(ANodeName, Node) then
    raise ENodeNotFound.CreateFmt('Nó não encontrado: %s', [ANodeName]);
  if not Assigned(Node.Handler) then
    raise EGraphExecutionError.CreateFmt('Handler ausente no nó "%s"', [ANodeName]);
  Result := Node.Handler(AState, FContext);
  if Result = nil then
    raise EGraphExecutionError.CreateFmt('Nó "%s" retornou estado nulo', [ANodeName]);
end;

function TCompiledAgent.ResolveNextNode(
  const ACurrentNode: string;
  const AState: TAgentState
): string;
var
  Edge: TEdge;
begin
  for Edge in FEdges do
  begin
    if Edge.SourceNode <> ACurrentNode then
      Continue;
    if Edge.Kind = ekFixed then
      Exit(Edge.TargetNode);
    if not Assigned(Edge.Condition) then
      raise EGraphExecutionError.CreateFmt(
        'Edge condicional sem condição a partir de "%s"', [ACurrentNode]);
    Result := Edge.Condition(AState);
    if Result = '' then
      Result := GRAPH_END;
    Exit;
  end;
  Result := GRAPH_END;
end;

function TCompiledAgent.ExecuteLoop(
  AState: TAgentState;
  ASkipFirstInterrupt: Boolean
): TGraphRunResult;
var
  State: TAgentState;
  NewState: TAgentState;
  CurrentNode, NextNode: string;
  I: Integer;
begin
  State := AState;
  Result := Default(TGraphRunResult);
  if State <> nil then
    Result.ThreadId := State.ThreadId;

  try
    for I := 1 to FMaxIterations do
    begin
      if Assigned(FContext.Observer) then
        FContext.Observer.OnIterationStart(I);

      CurrentNode := State.CurrentNode;
      Result.Iterations := State.Iteration;

      if (CurrentNode = GRAPH_END) or (CurrentNode = '') then
      begin
        Result.Status := grsFinished;
        Result.FinalAnswer := State.FinalAnswer;
        if Assigned(FContext.Observer) then
          FContext.Observer.OnFinished(Result.FinalAnswer, Result.Iterations);
        Exit;
      end;

      if (not ASkipFirstInterrupt) and ShouldInterrupt(CurrentNode) then
      begin
        CheckpointSave(State.ThreadId, State);
        Result.Status := grsWaitingApproval;
        Result.ThreadId := State.ThreadId;
        Result.PendingNode := CurrentNode;
        Result.PendingAction := DescribePending(State, CurrentNode);
        Exit;
      end;
      ASkipFirstInterrupt := False;

      try
        NewState := ExecuteNode(CurrentNode, State);
      except
        on E: Exception do
        begin
          Result.Status := grsError;
          Result.ErrorMsg := E.Message;
          Exit;
        end;
      end;
      ReplaceState(State, NewState);
      CheckpointSave(State.ThreadId, State);

      if State.IsDone then
      begin
        Result.Status := grsFinished;
        Result.FinalAnswer := State.FinalAnswer;
        Result.Iterations := State.Iteration;
        if Assigned(FContext.Observer) then
          FContext.Observer.OnFinished(Result.FinalAnswer, Result.Iterations);
        Exit;
      end;

      NextNode := ResolveNextNode(CurrentNode, State);
      NewState := State.WithCurrentNode(NextNode);
      ReplaceState(State, NewState);
      NewState := State.NextIteration;
      ReplaceState(State, NewState);
    end;

    Result.Status := grsError;
    Result.ErrorMsg := 'Limite de iterações atingido';
    Result.Iterations := FMaxIterations;
  finally
    State.Free;
  end;
end;

function TCompiledAgent.Run(
  const AInput: string;
  const AThreadId: string
): TGraphRunResult;
var
  ThreadId: string;
  State: TAgentState;
begin
  if AThreadId = '' then
    ThreadId := GenerateThreadId
  else
    ThreadId := AThreadId;

  if (FCheckpointer <> nil) and FCheckpointer.Exists(ThreadId) then
  begin
    State := CheckpointLoad(ThreadId);
    // Só preserva o estado tal como está quando ele estiver genuinamente
    // pausado num nó de aprovação (aguardando Resume). Em qualquer outro
    // caso — concluído, em GRAPH_END, ou "preso" por um erro de execução
    // anterior — trata como um novo turno, sob risco de descartar
    // silenciosamente o AInput do usuário.
    if State.IsDone or (State.CurrentNode = GRAPH_END) or (State.CurrentNode = '')
      or not ShouldInterrupt(State.CurrentNode) then
    begin
      ReplaceState(State, State.RestartAt(FEntryPoint));
      ReplaceState(State, State.WithMessage(TLLMMessage.User(AInput)));
    end;
  end
  else
  begin
    State := TAgentState.Create(ThreadId);
    if FContext.Config.SystemPrompt <> '' then
      ReplaceState(State, State.WithMessage(TLLMMessage.System(FContext.Config.SystemPrompt)));
    ReplaceState(State, State.WithMessage(TLLMMessage.User(AInput)));
    ReplaceState(State, State.WithCurrentNode(FEntryPoint));
  end;

  Result := ExecuteLoop(State, False);
end;

function TCompiledAgent.Resume(const AThreadId: string): TGraphRunResult;
var
  State: TAgentState;
begin
  if (FCheckpointer = nil) or not FCheckpointer.Exists(AThreadId) then
    raise EGraphError.CreateFmt('Nenhuma execução pausada para a thread %s', [AThreadId]);
  State := CheckpointLoad(AThreadId);
  Result := ExecuteLoop(State, True);
end;

procedure TCompiledAgent.Cancel(const AThreadId: string);
begin
  if FCheckpointer <> nil then
    FCheckpointer.Delete(AThreadId);
end;

function TCompiledAgent.GetState(const AThreadId: string): TObject;
begin
  FreeAndNil(FHeldState);
  if (FCheckpointer = nil) or not FCheckpointer.Exists(AThreadId) then
    Exit(nil);
  FHeldState := CheckpointLoad(AThreadId);
  Result := FHeldState;
end;

end.
