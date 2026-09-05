{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Agent - Multi-Provider LLM Agent                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    The ReAct loop. Provider-agnostic - talks only to ILLMProvider and to  }
{    TMCPToolProvider subclasses, both already part of the Dext framework.  }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Agent.Runner;

interface

uses
  Dext.AI.Agent.Contracts,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Types,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Attributes,
  Dext.Core.Reflection,
  System.Rtti,
  System.SysUtils,
  System.JSON,
  System.Generics.Collections;

type
  TAgentRunner = class
  private
    FProvider:  ILLMProvider;
    FConfig:    TAgentConfig;
    FObserver:  IAgentObserver;
    FProviders: TObjectList<TMCPToolProvider>;

    function BuildToolSchemas: TArray<TToolSchema>;
    function BuildInputSchema(AMethod: TRttiMethod): string;
    function ExecuteTool(const AToolName, AArgsJson: string): string;
    function ToolResultToText(const AResult: TMCPToolResult): string;
  public
    constructor Create(
      AProvider: ILLMProvider;
      const AConfig: TAgentConfig;
      AObserver: IAgentObserver = nil
    );
    destructor Destroy; override;
    procedure RegisterProvider(AProvider: TMCPToolProvider);
    function Run(const AUserInput: string): TAgentResult;
  end;

implementation

{ TAgentRunner }

constructor TAgentRunner.Create(AProvider: ILLMProvider;
  const AConfig: TAgentConfig; AObserver: IAgentObserver);
begin
  inherited Create;
  FProvider  := AProvider;
  FConfig    := AConfig;
  FObserver  := AObserver;
  FProviders := TObjectList<TMCPToolProvider>.Create(True);
end;

destructor TAgentRunner.Destroy;
begin
  FProviders.Free;
  inherited;
end;

procedure TAgentRunner.RegisterProvider(AProvider: TMCPToolProvider);
begin
  FProviders.Add(AProvider);
end;

function TAgentRunner.BuildInputSchema(AMethod: TRttiMethod): string;
var
  Ctx: TRttiContext;
  JSchema, JProps, JParam: TJSONObject;
  JRequired: TJSONArray;
  Attr: TCustomAttribute;
  ParamAttr: MCPParamAttribute;
begin
  Ctx := TRttiContext.Create;
  try
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
  finally
    Ctx.Free;
  end;
end;

function TAgentRunner.BuildToolSchemas: TArray<TToolSchema>;
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
        if ToolAttr = nil then Continue;

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

function TAgentRunner.ToolResultToText(const AResult: TMCPToolResult): string;
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

function TAgentRunner.ExecuteTool(const AToolName, AArgsJson: string): string;
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

function TAgentRunner.Run(const AUserInput: string): TAgentResult;
var
  Messages: TList<TLLMMessage>;
  Schemas: TArray<TToolSchema>;
  Response: TLLMResponse;
  Iteration: Integer;
  TC: TLLMToolCall;
  ToolResultText: string;
begin
  Result := Default(TAgentResult);

  Messages := TList<TLLMMessage>.Create;
  try
    if FConfig.SystemPrompt <> '' then
      Messages.Add(TLLMMessage.System(FConfig.SystemPrompt));
    Messages.Add(TLLMMessage.User(AUserInput));

    Schemas := BuildToolSchemas;

    for Iteration := 1 to FConfig.MaxIterations do
    begin
      if Assigned(FObserver) then
        FObserver.OnIterationStart(Iteration);

      try
        Response := FProvider.Complete(Messages.ToArray, Schemas);
      except
        on E: Exception do
        begin
          Result.Success    := False;
          Result.Iterations := Iteration;
          Result.ErrorMsg   := E.Message;
          Exit;
        end;
      end;

      if Assigned(FObserver) then
        FObserver.OnLLMResponse(Response.Content, Response.StopReason);

      case Response.StopReason of
        srEndTurn:
        begin
          if Assigned(FObserver) then
            FObserver.OnFinished(Response.Content, Iteration);
          Result.FinalAnswer := Response.Content;
          Result.Success     := True;
          Result.Iterations  := Iteration;
          Exit;
        end;

        srToolUse:
        begin
          Messages.Add(TLLMMessage.Assistant(Response.Content, Response.ToolCalls));

          for TC in Response.ToolCalls do
          begin
            if Assigned(FObserver) then
              FObserver.OnToolCall(TC.Name, TC.ArgsJson);

            ToolResultText := ExecuteTool(TC.Name, TC.ArgsJson);

            if Assigned(FObserver) then
              FObserver.OnToolResult(TC.Name, ToolResultText);

            Messages.Add(TLLMMessage.ToolResult(TC.Id, ToolResultText));
          end;
        end;

        srMaxTokens:
        begin
          Result.FinalAnswer := Response.Content;
          Result.Success     := False;
          Result.Iterations  := Iteration;
          Result.ErrorMsg    := 'Limite de tokens atingido';
          Exit;
        end;
      else
        begin
          Result.Success  := False;
          Result.ErrorMsg := 'Erro reportado pelo provider (srError)';
          Exit;
        end;
      end;
    end;

    Result.Success  := False;
    Result.ErrorMsg := 'Limite de iterações atingido';
  finally
    Messages.Free;
  end;
end;

end.
