{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Graph - Orquestração de agentes estilo LangGraph        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    TAgentState — estado imutável que flui pelo grafo.                     }
{    Cada With* retorna uma NOVA instância. Nenhum método muta Self.        }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Graph.State;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Dext.AI.Agent.Contracts;

type
  TAgentState = class
  private
    FMessages:     TArray<TLLMMessage>;
    FPendingCalls: TArray<TLLMToolCall>;
    FCurrentNode:  string;
    FIteration:    Integer;
    FIsDone:       Boolean;
    FFinalAnswer:  string;
    FMetadata:     TDictionary<string, string>;
    FThreadId:     string;

    constructor CreateInternal(
      const AMessages:     TArray<TLLMMessage>;
      const APendingCalls: TArray<TLLMToolCall>;
      const ACurrentNode:  string;
      AIteration:          Integer;
      AIsDone:             Boolean;
      const AFinalAnswer:  string;
      AMetadata:           TDictionary<string, string>;
      const AThreadId:     string
    );
    function CloneMetadata: TDictionary<string, string>;
    function CloneMessages: TArray<TLLMMessage>;
    function ClonePendingCalls: TArray<TLLMToolCall>;
  public
    constructor Create(const AThreadId: string = '');
    destructor Destroy; override;

    function WithMessage(const AMsg: TLLMMessage): TAgentState;
    function WithMessages(const AMsgs: TArray<TLLMMessage>): TAgentState;
    function WithPendingCalls(const ACalls: TArray<TLLMToolCall>): TAgentState;
    function ClearPendingCalls: TAgentState;
    function WithCurrentNode(const ANode: string): TAgentState;
    function WithIteration(AIteration: Integer): TAgentState;
    function NextIteration: TAgentState;
    function AsDone(const AAnswer: string): TAgentState;
    function WithMeta(const AKey, AValue: string): TAgentState;
    function RestartAt(const ANode: string): TAgentState;

    function ToJson: string;
    class function FromJson(const AJson: string): TAgentState; static;

    property Messages:     TArray<TLLMMessage>  read FMessages;
    property PendingCalls: TArray<TLLMToolCall> read FPendingCalls;
    property CurrentNode:  string               read FCurrentNode;
    property Iteration:    Integer              read FIteration;
    property IsDone:       Boolean              read FIsDone;
    property FinalAnswer:  string               read FFinalAnswer;
    property ThreadId:     string               read FThreadId;

    function HasPendingCalls: Boolean;
    function LastMessage: TLLMMessage;
    function GetMeta(const AKey: string; const ADefault: string = ''): string;
  end;

implementation

function RoleToName(ARole: TLLMRole): string;
begin
  case ARole of
    lrSystem:     Result := 'system';
    lrUser:       Result := 'user';
    lrAssistant:  Result := 'assistant';
    lrToolResult: Result := 'tool';
  else
    Result := 'user';
  end;
end;

function NameToRole(const AName: string): TLLMRole;
var
  LName: string;
begin
  LName := AName.ToLower;
  if LName = 'system' then
    Result := lrSystem
  else if LName = 'assistant' then
    Result := lrAssistant
  else if (LName = 'tool') or (LName = 'toolresult') then
    Result := lrToolResult
  else
    Result := lrUser;
end;

function MessageToJson(const AMsg: TLLMMessage): TJSONObject;
var
  JCalls: TJSONArray;
  JCall: TJSONObject;
  TC: TLLMToolCall;
begin
  Result := TJSONObject.Create;
  Result.AddPair('role', RoleToName(AMsg.Role));
  Result.AddPair('content', AMsg.Content);
  Result.AddPair('toolCallId', AMsg.ToolCallId);
  JCalls := TJSONArray.Create;
  for TC in AMsg.ToolCalls do
  begin
    JCall := TJSONObject.Create;
    JCall.AddPair('id', TC.Id);
    JCall.AddPair('name', TC.Name);
    JCall.AddPair('argsJson', TC.ArgsJson);
    JCalls.Add(JCall);
  end;
  Result.AddPair('toolCalls', JCalls);
end;

function JsonToMessage(AObj: TJSONObject): TLLMMessage;
var
  JCalls: TJSONArray;
  JCallObj: TJSONObject;
  TC: TLLMToolCall;
  Calls: TArray<TLLMToolCall>;
  I: Integer;
begin
  Result := Default(TLLMMessage);
  Result.Role       := NameToRole(AObj.GetValue<string>('role', 'user'));
  Result.Content    := AObj.GetValue<string>('content', '');
  Result.ToolCallId := AObj.GetValue<string>('toolCallId', '');
  JCalls := AObj.GetValue('toolCalls') as TJSONArray;
  if JCalls = nil then
    Exit;
  SetLength(Calls, JCalls.Count);
  for I := 0 to JCalls.Count - 1 do
  begin
    JCallObj := JCalls.Items[I] as TJSONObject;
    TC := Default(TLLMToolCall);
    TC.Id       := JCallObj.GetValue<string>('id', '');
    TC.Name     := JCallObj.GetValue<string>('name', '');
    TC.ArgsJson := JCallObj.GetValue<string>('argsJson', '');
    Calls[I] := TC;
  end;
  Result.ToolCalls := Calls;
end;

function ToolCallToJson(const ATC: TLLMToolCall): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', ATC.Id);
  Result.AddPair('name', ATC.Name);
  Result.AddPair('argsJson', ATC.ArgsJson);
end;

function JsonToToolCall(AObj: TJSONObject): TLLMToolCall;
begin
  Result := Default(TLLMToolCall);
  Result.Id       := AObj.GetValue<string>('id', '');
  Result.Name     := AObj.GetValue<string>('name', '');
  Result.ArgsJson := AObj.GetValue<string>('argsJson', '');
end;

{ TAgentState }

constructor TAgentState.Create(const AThreadId: string);
begin
  inherited Create;
  FThreadId := AThreadId;
  FMetadata := TDictionary<string, string>.Create;
end;

constructor TAgentState.CreateInternal(
  const AMessages:     TArray<TLLMMessage>;
  const APendingCalls: TArray<TLLMToolCall>;
  const ACurrentNode:  string;
  AIteration:          Integer;
  AIsDone:             Boolean;
  const AFinalAnswer:  string;
  AMetadata:           TDictionary<string, string>;
  const AThreadId:     string
);
begin
  inherited Create;
  FMessages     := AMessages;
  FPendingCalls := APendingCalls;
  FCurrentNode  := ACurrentNode;
  FIteration    := AIteration;
  FIsDone       := AIsDone;
  FFinalAnswer  := AFinalAnswer;
  FThreadId     := AThreadId;
  if AMetadata <> nil then
    FMetadata := AMetadata
  else
    FMetadata := TDictionary<string, string>.Create;
end;

destructor TAgentState.Destroy;
begin
  FMetadata.Free;
  inherited;
end;

function TAgentState.CloneMetadata: TDictionary<string, string>;
var
  Pair: TPair<string, string>;
begin
  Result := TDictionary<string, string>.Create;
  if FMetadata = nil then
    Exit;
  for Pair in FMetadata do
    Result.AddOrSetValue(Pair.Key, Pair.Value);
end;

function TAgentState.CloneMessages: TArray<TLLMMessage>;
begin
  Result := Copy(FMessages);
end;

function TAgentState.ClonePendingCalls: TArray<TLLMToolCall>;
begin
  Result := Copy(FPendingCalls);
end;

function TAgentState.WithMessage(const AMsg: TLLMMessage): TAgentState;
var
  Msgs: TArray<TLLMMessage>;
begin
  Msgs := CloneMessages;
  SetLength(Msgs, Length(Msgs) + 1);
  Msgs[High(Msgs)] := AMsg;
  Result := TAgentState.CreateInternal(
    Msgs, ClonePendingCalls, FCurrentNode, FIteration, FIsDone,
    FFinalAnswer, CloneMetadata, FThreadId);
end;

function TAgentState.WithMessages(const AMsgs: TArray<TLLMMessage>): TAgentState;
begin
  Result := TAgentState.CreateInternal(
    Copy(AMsgs), ClonePendingCalls, FCurrentNode, FIteration, FIsDone,
    FFinalAnswer, CloneMetadata, FThreadId);
end;

function TAgentState.WithPendingCalls(const ACalls: TArray<TLLMToolCall>): TAgentState;
begin
  Result := TAgentState.CreateInternal(
    CloneMessages, Copy(ACalls), FCurrentNode, FIteration, FIsDone,
    FFinalAnswer, CloneMetadata, FThreadId);
end;

function TAgentState.ClearPendingCalls: TAgentState;
begin
  Result := TAgentState.CreateInternal(
    CloneMessages, nil, FCurrentNode, FIteration, FIsDone,
    FFinalAnswer, CloneMetadata, FThreadId);
end;

function TAgentState.WithCurrentNode(const ANode: string): TAgentState;
begin
  Result := TAgentState.CreateInternal(
    CloneMessages, ClonePendingCalls, ANode, FIteration, FIsDone,
    FFinalAnswer, CloneMetadata, FThreadId);
end;

function TAgentState.WithIteration(AIteration: Integer): TAgentState;
begin
  Result := TAgentState.CreateInternal(
    CloneMessages, ClonePendingCalls, FCurrentNode, AIteration, FIsDone,
    FFinalAnswer, CloneMetadata, FThreadId);
end;

function TAgentState.NextIteration: TAgentState;
begin
  Result := WithIteration(FIteration + 1);
end;

function TAgentState.AsDone(const AAnswer: string): TAgentState;
begin
  Result := TAgentState.CreateInternal(
    CloneMessages, ClonePendingCalls, FCurrentNode, FIteration, True,
    AAnswer, CloneMetadata, FThreadId);
end;

function TAgentState.WithMeta(const AKey, AValue: string): TAgentState;
var
  Meta: TDictionary<string, string>;
begin
  Meta := CloneMetadata;
  Meta.AddOrSetValue(AKey, AValue);
  Result := TAgentState.CreateInternal(
    CloneMessages, ClonePendingCalls, FCurrentNode, FIteration, FIsDone,
    FFinalAnswer, Meta, FThreadId);
end;

function TAgentState.RestartAt(const ANode: string): TAgentState;
begin
  Result := TAgentState.CreateInternal(
    CloneMessages, nil, ANode, 0, False, '', CloneMetadata, FThreadId);
end;

function TAgentState.HasPendingCalls: Boolean;
begin
  Result := Length(FPendingCalls) > 0;
end;

function TAgentState.LastMessage: TLLMMessage;
begin
  if Length(FMessages) = 0 then
    Result := Default(TLLMMessage)
  else
    Result := FMessages[High(FMessages)];
end;

function TAgentState.GetMeta(const AKey: string; const ADefault: string): string;
begin
  if (FMetadata = nil) or not FMetadata.TryGetValue(AKey, Result) then
    Result := ADefault;
end;

function TAgentState.ToJson: string;
var
  Root: TJSONObject;
  JMsgs, JCalls: TJSONArray;
  JMeta: TJSONObject;
  Msg: TLLMMessage;
  TC: TLLMToolCall;
  Pair: TPair<string, string>;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('threadId', FThreadId);
    Root.AddPair('currentNode', FCurrentNode);
    Root.AddPair('iteration', TJSONNumber.Create(FIteration));
    Root.AddPair('isDone', TJSONBool.Create(FIsDone));
    Root.AddPair('finalAnswer', FFinalAnswer);

    JMsgs := TJSONArray.Create;
    for Msg in FMessages do
      JMsgs.Add(MessageToJson(Msg));
    Root.AddPair('messages', JMsgs);

    JCalls := TJSONArray.Create;
    for TC in FPendingCalls do
      JCalls.Add(ToolCallToJson(TC));
    Root.AddPair('pendingCalls', JCalls);

    JMeta := TJSONObject.Create;
    if FMetadata <> nil then
      for Pair in FMetadata do
        JMeta.AddPair(Pair.Key, Pair.Value);
    Root.AddPair('metadata', JMeta);

    Result := Root.ToJSON;
  finally
    Root.Free;
  end;
end;

class function TAgentState.FromJson(const AJson: string): TAgentState;
var
  Root: TJSONObject;
  JMsgs, JCalls: TJSONArray;
  JMeta: TJSONObject;
  JVal: TJSONValue;
  Msgs: TArray<TLLMMessage>;
  Calls: TArray<TLLMToolCall>;
  Meta: TDictionary<string, string>;
  I: Integer;
  Pair: TJSONPair;
begin
  Root := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Root = nil then
    raise EArgumentException.Create('JSON de estado inválido');
  try
    JMsgs := Root.GetValue('messages') as TJSONArray;
    if JMsgs <> nil then
    begin
      SetLength(Msgs, JMsgs.Count);
      for I := 0 to JMsgs.Count - 1 do
        Msgs[I] := JsonToMessage(JMsgs.Items[I] as TJSONObject);
    end;

    JCalls := Root.GetValue('pendingCalls') as TJSONArray;
    if JCalls <> nil then
    begin
      SetLength(Calls, JCalls.Count);
      for I := 0 to JCalls.Count - 1 do
        Calls[I] := JsonToToolCall(JCalls.Items[I] as TJSONObject);
    end;

    Meta := TDictionary<string, string>.Create;
    JMeta := Root.GetValue('metadata') as TJSONObject;
    if JMeta <> nil then
      for Pair in JMeta do
      begin
        JVal := Pair.JsonValue;
        if JVal <> nil then
          Meta.AddOrSetValue(Pair.JsonString.Value, JVal.Value);
      end;

    Result := TAgentState.CreateInternal(
      Msgs,
      Calls,
      Root.GetValue<string>('currentNode', ''),
      Root.GetValue<Integer>('iteration', 0),
      Root.GetValue<Boolean>('isDone', False),
      Root.GetValue<string>('finalAnswer', ''),
      Meta,
      Root.GetValue<string>('threadId', '')
    );
  finally
    Root.Free;
  end;
end;

end.
