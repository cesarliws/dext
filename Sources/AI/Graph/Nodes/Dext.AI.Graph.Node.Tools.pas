{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Graph - Orquestração de agentes estilo LangGraph        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    TToolsNode — nó padrão que executa as tool calls pendentes (ToolNode). }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Graph.Node.Tools;

interface

uses
  Dext.AI.Graph.State,
  Dext.AI.Graph.Graph,
  Dext.AI.Agent.Contracts,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Attributes,
  Dext.AI.MCP.Types,
  Dext.AI.MCP.Protocol,
  System.Rtti,
  System.JSON,
  System.SysUtils,
  System.Generics.Collections;

type
  TToolsNode = class
  private
    FProviders: TObjectList<TMCPToolProvider>;

    function ExecuteSingleTool(
      const AToolName, AArgsJson: string
    ): string;

    function BuildInputSchema(AMethod: TRttiMethod): string;
    function BuildToolSchemas: TArray<TToolSchema>;
    function ToolResultToText(const AResult: TMCPToolResult): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterProvider(AProvider: TMCPToolProvider);
    function GetToolSchemas: TArray<TToolSchema>;
    function GetAsHandler: TNodeHandler;
    function Execute(
      const AState: TAgentState;
      const ACtx:   TNodeContext
    ): TAgentState;

    property AsHandler: TNodeHandler read GetAsHandler;
  end;

implementation

uses
  System.Classes;

{ TToolsNode }

constructor TToolsNode.Create;
begin
  inherited Create;
  FProviders := TObjectList<TMCPToolProvider>.Create(True);
end;

destructor TToolsNode.Destroy;
begin
  FProviders.Free;
  inherited;
end;

procedure TToolsNode.RegisterProvider(AProvider: TMCPToolProvider);
begin
  if AProvider <> nil then
    FProviders.Add(AProvider);
end;

function TToolsNode.GetAsHandler: TNodeHandler;
begin
  Result :=
    function(const AState: TAgentState; const ACtx: TNodeContext): TAgentState
    begin
      Result := Self.Execute(AState, ACtx);
    end;
end;

function TToolsNode.GetToolSchemas: TArray<TToolSchema>;
begin
  Result := BuildToolSchemas;
end;

function TToolsNode.BuildInputSchema(AMethod: TRttiMethod): string;
var
  JSchema, JProps, JParam: TJSONObject;
  JRequired: TJSONArray;
  Attr: TCustomAttribute;
  ParamAttr: MCPParamAttribute;
begin
  JProps    := TJSONObject.Create;
  JRequired := TJSONArray.Create;

  for Attr in AMethod.GetAttributes do
    if Attr is MCPParamAttribute then
    begin
      ParamAttr := MCPParamAttribute(Attr);

      JParam := TJSONObject.Create;
      JParam.AddPair('description', ParamAttr.Description);
      case ParamAttr.ParamType of
        ptString:  JParam.AddPair('type', 'string');
        ptInteger: JParam.AddPair('type', 'integer');
        ptNumber:  JParam.AddPair('type', 'number');
        ptBoolean: JParam.AddPair('type', 'boolean');
      end;
      JProps.AddPair(ParamAttr.Name, JParam);

      if ParamAttr.Required then
        JRequired.Add(ParamAttr.Name);
    end;

  JSchema := TJSONObject.Create;
  try
    JSchema.AddPair('type', 'object');
    JSchema.AddPair('properties', JProps);
    if JRequired.Count > 0 then
      JSchema.AddPair('required', JRequired)
    else
      JRequired.Free;
    Result := JSchema.ToJSON;
  finally
    JSchema.Free;
  end;
end;

function TToolsNode.BuildToolSchemas: TArray<TToolSchema>;
var
  Ctx: TRttiContext;
  Provider: TMCPToolProvider;
  Method: TRttiMethod;
  ToolAttr: MCPToolAttribute;
  Schemas: TList<TToolSchema>;
  Schema: TToolSchema;
begin
  Ctx := TRttiContext.Create;
  Schemas := TList<TToolSchema>.Create;
  try
    for Provider in FProviders do
      for Method in Ctx.GetType(Provider.ClassType).GetMethods do
      begin
        ToolAttr := Method.GetAttribute<MCPToolAttribute>;
        if ToolAttr = nil then
          Continue;

        Schema := Default(TToolSchema);
        Schema.Name        := ToolAttr.Name;
        Schema.Description := ToolAttr.Description;
        Schema.InputSchema := BuildInputSchema(Method);
        Schemas.Add(Schema);
      end;

    Result := Schemas.ToArray;
  finally
    Schemas.Free;
    Ctx.Free;
  end;
end;

function TToolsNode.ToolResultToText(const AResult: TMCPToolResult): string;
var
  Item: TMCPContent;
  Parts: TStringBuilder;
begin
  Parts := TStringBuilder.Create;
  try
    for Item in AResult.Content do
      if Item.ContentType = mctText then
      begin
        if Parts.Length > 0 then
          Parts.Append(sLineBreak);
        Parts.Append(Item.TextValue);
      end;

    Result := Parts.ToString;
    if AResult.IsError then
      Result := '[Error] ' + Result;
  finally
    Parts.Free;
  end;
end;

function TToolsNode.ExecuteSingleTool(
  const AToolName, AArgsJson: string
): string;
var
  Ctx: TRttiContext;
  Provider: TMCPToolProvider;
  RttiType: TRttiType;
  Method: TRttiMethod;
  ToolAttr: MCPToolAttribute;
  JArgs: TJSONObject;
  InvokeResult: TValue;
begin
  Ctx := TRttiContext.Create;
  try
    JArgs := TJSONObject.ParseJSONValue(AArgsJson) as TJSONObject;
    if JArgs = nil then
      JArgs := TJSONObject.Create;
    try
      for Provider in FProviders do
      begin
        RttiType := Ctx.GetType(Provider.ClassType);
        for Method in RttiType.GetMethods do
        begin
          ToolAttr := Method.GetAttribute<MCPToolAttribute>;
          if (ToolAttr = nil) or (ToolAttr.Name <> AToolName) then
            Continue;

          try
            Provider.BeforeCall(AToolName, JArgs);
            InvokeResult := Method.Invoke(Provider, [TValue.From<TJSONObject>(JArgs)]);
            Provider.AfterCall(AToolName);
            Exit(ToolResultToText(InvokeResult.AsType<TMCPToolResult>));
          except
            on E: Exception do
              Exit('[Error] ' + E.Message);
          end;
        end;
      end;

      Result := '[Error: Tool not found: ' + AToolName + ']';
    finally
      JArgs.Free;
    end;
  finally
    Ctx.Free;
  end;
end;

function TToolsNode.Execute(
  const AState: TAgentState;
  const ACtx: TNodeContext
): TAgentState;
var
  NewState: TAgentState;
  TC: TLLMToolCall;
  ToolResultText: string;
  Old: TAgentState;
begin
  NewState := AState;
  for TC in AState.PendingCalls do
  begin
    if Assigned(ACtx.Observer) then
      ACtx.Observer.OnToolCall(TC.Name, TC.ArgsJson);

    ToolResultText := ExecuteSingleTool(TC.Name, TC.ArgsJson);

    if Assigned(ACtx.Observer) then
      ACtx.Observer.OnToolResult(TC.Name, ToolResultText);

    Old := NewState;
    NewState := NewState.WithMessage(TLLMMessage.ToolResult(TC.Id, ToolResultText));
    if (Old <> AState) and (Old <> NewState) then
      Old.Free;
  end;

  Old := NewState;
  NewState := NewState.ClearPendingCalls;
  if (Old <> AState) and (Old <> NewState) then
    Old.Free;

  Result := NewState;
end;

end.
