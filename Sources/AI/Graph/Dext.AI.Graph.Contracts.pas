{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Graph - Orquestração de agentes estilo LangGraph        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    Tipos, constantes e interfaces base do Dext.AI.Graph.                  }
{    Equivalente ao core do LangGraph (StateGraph / CompiledGraph).         }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Graph.Contracts;

interface

uses
  System.SysUtils,
  Dext.AI.Agent.Contracts,
  Dext.AI.Graph.State;

const
  GRAPH_END   = '__end__';
  GRAPH_START = '__start__';

type
  TGraphRunStatus = (
    grsRunning,
    grsFinished,
    grsWaitingApproval,
    grsError,
    grsCancelled
  );

  TGraphRunResult = record
    Status:        TGraphRunStatus;
    FinalAnswer:   string;
    ThreadId:      string;
    Iterations:    Integer;
    ErrorMsg:      string;
    PendingNode:   string;
    PendingAction: string;
  end;

  // Contexto de execução compartilhado, injetado em cada nó do grafo.
  TNodeContext = record
    Provider:  ILLMProvider;
    Config:    TAgentConfig;
    Observer:  IAgentObserver;
  end;

  // Handler de nó: recebe o estado atual e devolve o novo estado.
  // Declarado aqui (não em Dext.AI.Graph.Graph) porque ICompiledAgent.AsNode
  // precisa expor esse tipo, e Contracts não pode depender de Graph.
  TNodeHandler = reference to function(
    const AState: TAgentState;
    const ACtx:   TNodeContext
  ): TAgentState;

  ICompiledAgent = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    function Run(
      const AInput:    string;
      const AThreadId: string = ''
    ): TGraphRunResult;

    function Resume(const AThreadId: string): TGraphRunResult;
    procedure Cancel(const AThreadId: string);
    function GetState(const AThreadId: string): TObject;

    // Adapta este grafo compilado para ser usado como um nó comum de um
    // grafo pai (subgraph-as-node). O estado é passado direto — sem
    // tradução — pois TAgentState já é o mesmo tipo em ambos os grafos.
    // Grafos com RequireApproval/InterruptBefore levantam EGraphCompileError
    // aqui: aprovação humana aninhada não é suportada (v1).
    function AsNode: TNodeHandler;
  end;

  ICheckpointer = interface
    ['{D4E5F6A7-B8C9-0123-DEFA-234567890123}']
    procedure Save(const AThreadId: string; const AStateJson: string);
    function  Load(const AThreadId: string): string;
    function  Exists(const AThreadId: string): Boolean;
    procedure Delete(const AThreadId: string);
  end;

  EGraphError          = class(Exception);
  EGraphCompileError   = class(EGraphError);
  EGraphExecutionError = class(EGraphError);
  ENodeNotFound        = class(EGraphError);
  ECycleDetected       = class(EGraphError);

implementation

end.
