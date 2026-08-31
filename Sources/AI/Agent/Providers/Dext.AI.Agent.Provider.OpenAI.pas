{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Agent - Multi-Provider LLM Agent                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    ILLMProvider implementation for OpenAI's Chat Completions API.         }
{    POST https://api.openai.com/v1/chat/completions                       }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Agent.Provider.OpenAI;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.NetConsts,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Generics.Collections,
  Dext.AI.Agent.Contracts;

type
  TOpenAIProvider = class(TInterfacedObject, ILLMProvider)
  private
    FApiKey:    string;
    FModel:     string;
    FMaxTokens: Integer;
    FEndpoint:  string;

    function BuildRequestBody(const AMessages: TArray<TLLMMessage>;
      const ATools: TArray<TToolSchema>): TJSONObject;
    function BuildMessageJSON(const AMessage: TLLMMessage): TJSONObject;
    function BuildToolJSON(const ATool: TToolSchema): TJSONObject;
    function ParseResponse(const ABody: string): TLLMResponse;
    function MapFinishReason(const AReason: string): TLLMStopReason;
  public
    constructor Create(const AApiKey, AModel: string; AMaxTokens: Integer);

    function Complete(
      const AMessages: TArray<TLLMMessage>;
      const ATools:    TArray<TToolSchema>
    ): TLLMResponse;
    function ProviderName: string;
    function ModelName: string;
  end;

implementation

{ TOpenAIProvider }

constructor TOpenAIProvider.Create(const AApiKey, AModel: string; AMaxTokens: Integer);
begin
  inherited Create;
  FApiKey    := AApiKey;
  FModel     := AModel;
  FMaxTokens := AMaxTokens;
  FEndpoint  := 'https://api.openai.com/v1/chat/completions';
end;

function TOpenAIProvider.ProviderName: string;
begin
  Result := 'openai';
end;

function TOpenAIProvider.ModelName: string;
begin
  Result := FModel;
end;

function TOpenAIProvider.BuildMessageJSON(const AMessage: TLLMMessage): TJSONObject;
var
  ToolCallsArr: TJSONArray;
  TC: TLLMToolCall;
  TCObj, FnObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  case AMessage.Role of
    lrSystem:
    begin
      Result.AddPair('role', 'system');
      Result.AddPair('content', AMessage.Content);
    end;
    lrUser:
    begin
      Result.AddPair('role', 'user');
      Result.AddPair('content', AMessage.Content);
    end;
    lrAssistant:
    begin
      Result.AddPair('role', 'assistant');
      if Length(AMessage.ToolCalls) > 0 then
      begin
        if AMessage.Content <> '' then
          Result.AddPair('content', AMessage.Content)
        else
          Result.AddPair('content', TJSONNull.Create);

        ToolCallsArr := TJSONArray.Create;
        for TC in AMessage.ToolCalls do
        begin
          TCObj := TJSONObject.Create;
          TCObj.AddPair('id', TC.Id);
          TCObj.AddPair('type', 'function');
          FnObj := TJSONObject.Create;
          FnObj.AddPair('name', TC.Name);
          FnObj.AddPair('arguments', TC.ArgsJson);
          TCObj.AddPair('function', FnObj);
          ToolCallsArr.Add(TCObj);
        end;
        Result.AddPair('tool_calls', ToolCallsArr);
      end
      else
        Result.AddPair('content', AMessage.Content);
    end;
    lrToolResult:
    begin
      Result.AddPair('role', 'tool');
      Result.AddPair('tool_call_id', AMessage.ToolCallId);
      Result.AddPair('content', AMessage.Content);
    end;
  end;
end;

function TOpenAIProvider.BuildToolJSON(const ATool: TToolSchema): TJSONObject;
var
  FnObj: TJSONObject;
  Params: TJSONValue;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'function');

  FnObj := TJSONObject.Create;
  FnObj.AddPair('name', ATool.Name);
  FnObj.AddPair('description', ATool.Description);

  Params := TJSONObject.ParseJSONValue(ATool.InputSchema);
  if Params = nil then
    Params := TJSONObject.Create;
  FnObj.AddPair('parameters', Params);

  Result.AddPair('function', FnObj);
end;

function TOpenAIProvider.BuildRequestBody(const AMessages: TArray<TLLMMessage>;
  const ATools: TArray<TToolSchema>): TJSONObject;
var
  MsgsArr, ToolsArr: TJSONArray;
  Msg: TLLMMessage;
  Tool: TToolSchema;
begin
  Result := TJSONObject.Create;
  Result.AddPair('model', FModel);
  Result.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));

  MsgsArr := TJSONArray.Create;
  for Msg in AMessages do
    MsgsArr.Add(BuildMessageJSON(Msg));
  Result.AddPair('messages', MsgsArr);

  if Length(ATools) > 0 then
  begin
    ToolsArr := TJSONArray.Create;
    for Tool in ATools do
      ToolsArr.Add(BuildToolJSON(Tool));
    Result.AddPair('tools', ToolsArr);
  end;
end;

function TOpenAIProvider.MapFinishReason(const AReason: string): TLLMStopReason;
begin
  if AReason = 'stop' then
    Result := srEndTurn
  else if AReason = 'tool_calls' then
    Result := srToolUse
  else if AReason = 'length' then
    Result := srMaxTokens
  else
    Result := srError;
end;

function TOpenAIProvider.ParseResponse(const ABody: string): TLLMResponse;
var
  Root, Choice, Message, Usage, FnObj, TCObj: TJSONObject;
  Choices, ToolCallsArr: TJSONArray;
  FinishReason: string;
  ToolCalls: TArray<TLLMToolCall>;
  I: Integer;
  TC: TLLMToolCall;
  ContentVal: TJSONValue;
begin
  Result := Default(TLLMResponse);

  Root := TJSONObject.ParseJSONValue(ABody) as TJSONObject;
  if Root = nil then
    raise ELLMProviderError.CreateFmt('OpenAI: resposta inválida: %s', [ABody]);
  try
    Choices := Root.GetValue<TJSONArray>('choices', nil);
    if (Choices = nil) or (Choices.Count = 0) then
      raise ELLMProviderError.CreateFmt('OpenAI: resposta sem choices: %s', [ABody]);

    Choice := Choices.Items[0] as TJSONObject;
    FinishReason := Choice.GetValue<string>('finish_reason', '');
    Message := Choice.GetValue<TJSONObject>('message', nil);
    if Message = nil then
      raise ELLMProviderError.CreateFmt('OpenAI: choice sem message: %s', [ABody]);

    ContentVal := Message.GetValue('content');
    if (ContentVal <> nil) and not (ContentVal is TJSONNull) then
      Result.Content := ContentVal.Value;

    // 'tool_calls' is absent on a plain-text final answer - GetValue<T> with a
    // default is required here, the 1-arg overload raises EJSONException instead
    // of returning nil when the key is missing.
    ToolCallsArr := Message.GetValue<TJSONArray>('tool_calls', nil);
    if ToolCallsArr <> nil then
    begin
      SetLength(ToolCalls, ToolCallsArr.Count);
      for I := 0 to ToolCallsArr.Count - 1 do
      begin
        TCObj := ToolCallsArr.Items[I] as TJSONObject;
        FnObj := TCObj.GetValue<TJSONObject>('function', nil);
        TC := Default(TLLMToolCall);
        TC.Id       := TCObj.GetValue<string>('id', '');
        TC.Name     := FnObj.GetValue<string>('name', '');
        TC.ArgsJson := FnObj.GetValue<string>('arguments', '{}');
        ToolCalls[I] := TC;
      end;
      Result.ToolCalls := ToolCalls;
    end;

    Result.StopReason := MapFinishReason(FinishReason);

    Usage := Root.GetValue<TJSONObject>('usage', nil);
    if Usage <> nil then
    begin
      Result.InputTokens  := Usage.GetValue<Integer>('prompt_tokens', 0);
      Result.OutputTokens := Usage.GetValue<Integer>('completion_tokens', 0);
    end;
  finally
    Root.Free;
  end;
end;

function TOpenAIProvider.Complete(const AMessages: TArray<TLLMMessage>;
  const ATools: TArray<TToolSchema>): TLLMResponse;
var
  HttpClient: THTTPClient;
  Body: TJSONObject;
  Stream: TStringStream;
  Response: IHTTPResponse;
begin
  if FApiKey = '' then
    raise ELLMProviderError.Create('OpenAI: API key não configurada.');

  HttpClient := THTTPClient.Create;
  try
    HttpClient.ConnectionTimeout := 120000;
    HttpClient.ResponseTimeout   := 120000;
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
    HttpClient.ContentType := 'application/json';

    Body := BuildRequestBody(AMessages, ATools);
    try
      Stream := TStringStream.Create(Body.ToJSON, TEncoding.UTF8);
      try
        Response := HttpClient.Post(FEndpoint, Stream, nil,
          [TNetHeader.Create('Content-Type', 'application/json')]);
      finally
        Stream.Free;
      end;
    finally
      Body.Free;
    end;

    if Response.StatusCode <> 200 then
      raise ELLMProviderError.CreateFmt('OpenAI HTTP %d: %s',
        [Response.StatusCode, Response.ContentAsString(TEncoding.UTF8)]);

    Result := ParseResponse(Response.ContentAsString(TEncoding.UTF8));
  finally
    HttpClient.Free;
  end;
end;

end.
