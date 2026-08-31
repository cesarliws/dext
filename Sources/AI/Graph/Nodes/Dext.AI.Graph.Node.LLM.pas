{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Graph - Orquestração de agentes estilo LangGraph        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    TLLMNode — nó padrão que chama o provider LLM (call_model).            }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Graph.Node.LLM;

interface

uses
  Dext.AI.Graph.Contracts,
  Dext.AI.Graph.State,
  Dext.AI.Graph.Graph,
  Dext.AI.Agent.Contracts,
  System.SysUtils;

type
  TLLMNode = class
  private
    FToolSchemas: TArray<TToolSchema>;
  public
    constructor Create(const AToolSchemas: TArray<TToolSchema>);
    function GetAsHandler: TNodeHandler;
    function Execute(
      const AState: TAgentState;
      const ACtx:   TNodeContext
    ): TAgentState;

    property AsHandler: TNodeHandler read GetAsHandler;
  end;

function DefaultShouldContinue(const AState: TAgentState): string;

implementation

function StopReasonToString(AReason: TLLMStopReason): string;
begin
  case AReason of
    srEndTurn:   Result := 'srEndTurn';
    srToolUse:   Result := 'srToolUse';
    srMaxTokens: Result := 'srMaxTokens';
    srError:     Result := 'srError';
  else
    Result := 'unknown';
  end;
end;

{ TLLMNode }

constructor TLLMNode.Create(const AToolSchemas: TArray<TToolSchema>);
begin
  inherited Create;
  FToolSchemas := Copy(AToolSchemas);
end;

function TLLMNode.GetAsHandler: TNodeHandler;
begin
  Result :=
    function(const AState: TAgentState; const ACtx: TNodeContext): TAgentState
    begin
      Result := Self.Execute(AState, ACtx);
    end;
end;

function TLLMNode.Execute(
  const AState: TAgentState;
  const ACtx: TNodeContext
): TAgentState;
var
  Response: TLLMResponse;
  AssistantMsg: TLLMMessage;
  Intermediate: TAgentState;
begin
  if ACtx.Provider = nil then
    raise EGraphExecutionError.Create('Provider LLM ausente no contexto do nó');

  Response := ACtx.Provider.Complete(AState.Messages, FToolSchemas);

  if Assigned(ACtx.Observer) then
    ACtx.Observer.OnLLMResponse(Response.Content, Response.StopReason);

  case Response.StopReason of
    srEndTurn:
    begin
      AssistantMsg := TLLMMessage.Assistant(Response.Content);
      Intermediate := AState.WithMessage(AssistantMsg);
      try
        Result := Intermediate.AsDone(Response.Content);
      finally
        Intermediate.Free;
      end;
    end;
    srToolUse:
    begin
      AssistantMsg := TLLMMessage.Assistant(Response.Content, Response.ToolCalls);
      Intermediate := AState.WithMessage(AssistantMsg);
      try
        Result := Intermediate.WithPendingCalls(Response.ToolCalls);
      finally
        Intermediate.Free;
      end;
    end;
  else
    Result := AState.AsDone('[Error: ' + StopReasonToString(Response.StopReason) + ']');
  end;
end;

function DefaultShouldContinue(const AState: TAgentState): string;
begin
  if AState.HasPendingCalls then
    Result := 'execute_tools'
  else
    Result := GRAPH_END;
end;

end.
