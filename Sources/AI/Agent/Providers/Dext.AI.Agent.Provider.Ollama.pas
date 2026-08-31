{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Agent - Multi-Provider LLM Agent                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    ILLMProvider implementation for a local Ollama server (OpenAI-style    }
{    chat endpoint, no API key required).                                   }
{    POST <BaseUrl>/api/chat                                                }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Agent.Provider.Ollama;

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
  TOllamaProvider = class(TInterfacedObject, ILLMProvider)
  private
    FBaseUrl:   string;
    FModel:     string;
    FMaxTokens: Integer;

    function BuildRequestBody(const AMessages: TArray<TLLMMessage>;
      const ATools: TArray<TToolSchema>): TJSONObject;
    function BuildMessageJSON(const AMessage: TLLMMessage): TJSONObject;
    function BuildToolJSON(const ATool: TToolSchema): TJSONObject;
    function ParseResponse(const ABody: string): TLLMResponse;
    function MapDoneReason(const AReason: string): TLLMStopReason;
  public
    constructor Create(const ABaseUrl, AModel: string; AMaxTokens: Integer);

    function Complete(
      const AMessages: TArray<TLLMMessage>;
      const ATools:    TArray<TToolSchema>
    ): TLLMResponse;
    function ProviderName: string;
    function ModelName: string;
  end;

implementation

{ TOllamaProvider }

constructor TOllamaProvider.Create(const ABaseUrl, AModel: string; AMaxTokens: Integer);
begin
  inherited Create;
  FBaseUrl   := ABaseUrl.TrimRight(['/']);
  FModel     := AModel;
  FMaxTokens := AMaxTokens;
end;

function TOllamaProvider.ProviderName: string;
begin
  Result := 'ollama';
end;

function TOllamaProvider.ModelName: string;
begin
  Result := FModel;
end;

function TOllamaProvider.BuildMessageJSON(const AMessage: TLLMMessage): TJSONObject;
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
      Result.AddPair('content', AMessage.Content);

      if Length(AMessage.ToolCalls) > 0 then
      begin
        ToolCallsArr := TJSONArray.Create;
        for TC in AMessage.ToolCalls do
        begin
          TCObj := TJSONObject.Create;
          FnObj := TJSONObject.Create;
          FnObj.AddPair('name', TC.Name);
          FnObj.AddPair('arguments', TC.ArgsJson);
          TCObj.AddPair('function', FnObj);
          ToolCallsArr.Add(TCObj);
        end;
        Result.AddPair('tool_calls', ToolCallsArr);
      end;
    end;
    lrToolResult:
    begin
      Result.AddPair('role', 'tool');
      Result.AddPair('tool_call_id', AMessage.ToolCallId);
      Result.AddPair('content', AMessage.Content);
    end;
  end;
end;

function TOllamaProvider.BuildToolJSON(const ATool: TToolSchema): TJSONObject;
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

function TOllamaProvider.BuildRequestBody(const AMessages: TArray<TLLMMessage>;
  const ATools: TArray<TToolSchema>): TJSONObject;
var
  MsgsArr, ToolsArr: TJSONArray;
  Msg: TLLMMessage;
  Tool: TToolSchema;
begin
  Result := TJSONObject.Create;
  Result.AddPair('model', FModel);
  Result.AddPair('stream', TJSONBool.Create(False));

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

function TOllamaProvider.MapDoneReason(const AReason: string): TLLMStopReason;
begin
  if AReason = 'stop' then
    Result := srEndTurn
  else if AReason = 'tool_calls' then
    Result := srToolUse
  else
    Result := srError;
end;

function TOllamaProvider.ParseResponse(const ABody: string): TLLMResponse;
var
  Root, Message, TCObj, FnObj: TJSONObject;
  ToolCallsArr: TJSONArray;
  ToolCalls: TArray<TLLMToolCall>;
  I: Integer;
  TC: TLLMToolCall;
  ArgsVal: TJSONValue;
begin
  Result := Default(TLLMResponse);

  Root := TJSONObject.ParseJSONValue(ABody) as TJSONObject;
  if Root = nil then
    raise ELLMProviderError.CreateFmt('Ollama: resposta inválida: %s', [ABody]);
  try
    Message := Root.GetValue<TJSONObject>('message', nil);
    if Message = nil then
      raise ELLMProviderError.CreateFmt('Ollama: resposta sem message: %s', [ABody]);

    Result.Content := Message.GetValue<string>('content', '');

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
        TC.Id := 'ollama-call-' + IntToStr(I);
        TC.Name := FnObj.GetValue<string>('name', '');

        ArgsVal := FnObj.GetValue('arguments');
        if ArgsVal <> nil then
          TC.ArgsJson := ArgsVal.ToJSON
        else
          TC.ArgsJson := '{}';

        ToolCalls[I] := TC;
      end;
      Result.ToolCalls := ToolCalls;
    end;

    Result.StopReason := MapDoneReason(Root.GetValue<string>('done_reason', ''));
    Result.InputTokens  := 0;
    Result.OutputTokens := 0;
  finally
    Root.Free;
  end;
end;

function TOllamaProvider.Complete(const AMessages: TArray<TLLMMessage>;
  const ATools: TArray<TToolSchema>): TLLMResponse;
var
  HttpClient: THTTPClient;
  Body: TJSONObject;
  Stream: TStringStream;
  Response: IHTTPResponse;
begin
  HttpClient := THTTPClient.Create;
  try
    HttpClient.ConnectionTimeout := 120000;
    HttpClient.ResponseTimeout   := 120000;
    HttpClient.ContentType := 'application/json';

    Body := BuildRequestBody(AMessages, ATools);
    try
      Stream := TStringStream.Create(Body.ToJSON, TEncoding.UTF8);
      try
        Response := HttpClient.Post(FBaseUrl + '/api/chat', Stream, nil,
          [TNetHeader.Create('Content-Type', 'application/json')]);
      finally
        Stream.Free;
      end;
    finally
      Body.Free;
    end;

    if Response.StatusCode <> 200 then
      raise ELLMProviderError.CreateFmt('Ollama HTTP %d: %s',
        [Response.StatusCode, Response.ContentAsString(TEncoding.UTF8)]);

    Result := ParseResponse(Response.ContentAsString(TEncoding.UTF8));
  finally
    HttpClient.Free;
  end;
end;

end.
