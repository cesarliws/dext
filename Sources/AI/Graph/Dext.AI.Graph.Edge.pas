{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Graph - Orquestração de agentes estilo LangGraph        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    TEdge, TEdgeRoute e TEdgeCondition — edges do grafo.                   }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Graph.Edge;

interface

uses
  System.SysUtils,
  Dext.AI.Graph.Contracts,
  Dext.AI.Graph.State;

type
  TEdgeCondition = reference to function(
    const AState: TAgentState
  ): string;

  TEdgeRoute = record
    TargetNode: string;
  public
    class function To_(const ANode: string): TEdgeRoute; static;
    class function ToEnd: TEdgeRoute; static;
  end;

  TEdgeKind = (ekFixed, ekConditional);

  TEdge = record
    Kind:        TEdgeKind;
    SourceNode:  string;
    TargetNode:  string;
    Condition:   TEdgeCondition;
    Routes:      TArray<TEdgeRoute>;
  public
    class function Fixed(
      const ASource, ATarget: string
    ): TEdge; static;

    class function Conditional(
      const ASource:    string;
      ACondition:       TEdgeCondition;
      const ARoutes:    TArray<TEdgeRoute>
    ): TEdge; static;
  end;

implementation

{ TEdgeRoute }

class function TEdgeRoute.To_(const ANode: string): TEdgeRoute;
begin
  Result.TargetNode := ANode;
end;

class function TEdgeRoute.ToEnd: TEdgeRoute;
begin
  Result.TargetNode := GRAPH_END;
end;

{ TEdge }

class function TEdge.Fixed(const ASource, ATarget: string): TEdge;
begin
  Result := Default(TEdge);
  Result.Kind       := ekFixed;
  Result.SourceNode := ASource;
  Result.TargetNode := ATarget;
end;

class function TEdge.Conditional(
  const ASource: string;
  ACondition: TEdgeCondition;
  const ARoutes: TArray<TEdgeRoute>
): TEdge;
begin
  Result := Default(TEdge);
  Result.Kind       := ekConditional;
  Result.SourceNode := ASource;
  Result.Condition  := ACondition;
  Result.Routes     := ARoutes;
end;

end.
