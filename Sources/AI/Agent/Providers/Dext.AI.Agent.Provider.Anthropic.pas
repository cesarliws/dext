{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Dext.AI.Agent - Multi-Provider LLM Agent                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    ILLMProvider implementation for the Anthropic Messages API.            }
{    POST https://api.anthropic.com/v1/messages                            }
{                                                                           }
{    Anthropic requires every tool_result produced in reaction to a single  }
{    assistant turn to be sent back as ONE user message whose content is    }
{    an array of tool_result blocks. The Runner appends one lrToolResult    }
{    TLLMMessage per tool call, so this provider coalesces any run of       }
{    consecutive lrToolResult messages into a single user message when      }
{    building the request body.                                            }
{                                                                           }
{***************************************************************************}
unit Dext.AI.Agent.Provider.Anthropic;

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
  TAnthropicProvider = class(TInterfacedObject, ILLMProvider)
  private
    FApiKey:    string;
    FModel:     string;
    FMaxTokens: Integer;
    FEndpoint:  string;

    function BuildRequestBody(const AMessages: TArray<TLLMMessage>;
      const ATools: TArray<TToolSchema>): TJSONObject;
    function BuildToolJSON(const ATool: TToolSchema): TJSONObject;
    function ParseResponse(const ABody: string): TLLMResponse;
    function MapStopReason(const AReason: string): TLLMStopReason;
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

{ TAnthropicProvider }

constructor TAnthropicProvider.Create(const AApiKey, AModel: string; AMaxTokens: Integer);
begin
  inherited Create;
  FApiKey    := AApiKey;
  FModel     := AModel;
  FMaxTokens := AMaxTokens;
  FEndpoint  := 'https://api.anthropic.com/v1/messages';
end;

function TAnthropicProvider.ProviderName: string;
begin
  Result := 'anthropic';
end;

function TAnthropicProvider.ModelName: string;
begin
  Result := FModel;
end;

function TAnthropicProvider.BuildToolJSON(const ATool: TToolSchema): TJSONObject;
var
  Schema: TJSONValue;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', ATool.Name);
  Result.AddPair('description', ATool.Description);

  Schema := TJSONObject.ParseJSONValue(ATool.InputSchema);
  if Schema = nil then
    Schema := TJSONObject.Create;
  Result.AddPair('input_schema', Schema);
end;

function TAnthropicProvider.BuildRequestBody(const AMessages: TArray<TLLMMessage>;
  const ATools: TArray<TToolSchema>): TJSONObject;
var
  MsgsArr, ToolsArr: TJSONArray;
  ContentArr: TJSONArray;
  MsgObj, ContentBlock: TJSONObject;
  I, J: Integer;
  Msg: TLLMMessage;
  TC: TLLMToolCall;
  Tool: TToolSchema;
  ArgsVal: TJSONValue;
begin
  Result := TJSONObject.Create;
  Result.AddPair('model', FModel);
  Result.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));

  MsgsArr := TJSONArray.Create;

  I := 0;
  while I < Length(AMessages) do
  begin
    Msg := AMessages[I];

    case Msg.Role of
      lrSystem:
      begin
        Result.AddPair('system', Msg.Content);
        Inc(I);
      end;

      lrUser:
      begin
        MsgObj := TJSONObject.Create;
        MsgObj.AddPair('role', 'user');
        MsgObj.AddPair('content', Msg.Content);
        MsgsArr.Add(MsgObj);
        Inc(I);
      end;

      lrAssistant:
      begin
        MsgObj := TJSONObject.Create;
        MsgObj.AddPair('role', 'assistant');
        ContentArr := TJSONArray.Create;

        if Msg.Content <> '' then
        begin
          ContentBlock := TJSONObject.Create;
          ContentBlock.AddPair('type', 'text');
          ContentBlock.AddPair('text', Msg.Content);
          ContentArr.Add(ContentBlock);
        end;

        for TC in Msg.ToolCalls do
        begin
          ContentBlock := TJSONObject.Create;
          ContentBlock.AddPair('type', 'tool_use');
          ContentBlock.AddPair('id', TC.Id);
          ContentBlock.AddPair('name', TC.Name);
          ArgsVal := TJSONObject.ParseJSONValue(TC.ArgsJson);
          if ArgsVal = nil then
            ArgsVal := TJSONObject.Create;
          ContentBlock.AddPair('input', ArgsVal);
          ContentArr.Add(ContentBlock);
        end;

        MsgObj.AddPair('content', ContentArr);
        MsgsArr.Add(MsgObj);
        Inc(I);
      end;

      lrToolResult:
      begin
        // Coalesce this run of consecutive tool-result messages into a
        // single {"role":"user","content":[tool_result, tool_result, ...]}
        MsgObj := TJSONObject.Create;
        MsgObj.AddPair('role', 'user');
        ContentArr := TJSONArray.Create;

        J := I;
        while (J < Length(AMessages)) and (AMessages[J].Role = lrToolResult) do
        begin
          ContentBlock := TJSONObject.Create;
          ContentBlock.AddPair('type', 'tool_result');
          ContentBlock.AddPair('tool_use_id', AMessages[J].ToolCallId);
          ContentBlock.AddPair('content', AMessages[J].Content);
          ContentArr.Add(ContentBlock);
          Inc(J);
        end;

        MsgObj.AddPair('content', ContentArr);
        MsgsArr.Add(MsgObj);
        I := J;
      end;
    else
      Inc(I);
    end;
  end;

  Result.AddPair('messages', MsgsArr);

  if Length(ATools) > 0 then
  begin
    ToolsArr := TJSONArray.Create;
    for Tool in ATools do
      ToolsArr.Add(BuildToolJSON(Tool));
    Result.AddPair('tools', ToolsArr);
  end;
end;

function TAnthropicProvider.MapStopReason(const AReason: string): TLLMStopReason;
begin
  if AReason = 'end_turn' then
    Result := srEndTurn
  else if AReason = 'tool_use' then
    Result := srToolUse
  else if AReason = 'max_tokens' then
    Result := srMaxTokens
  else
    Result := srError;
end;

function TAnthropicProvider.ParseResponse(const ABody: string): TLLMResponse;
var
  Root, Usage, Block: TJSONObject;
  ContentArr: TJSONArray;
  I: Integer;
  BlockType: string;
  TextBuf: TStringBuilder;
  ToolCalls: TList<TLLMToolCall>;
  TC: TLLMToolCall;
begin
  Result := Default(TLLMResponse);

  Root := TJSONObject.ParseJSONValue(ABody) as TJSONObject;
  if Root = nil then
    raise ELLMProviderError.CreateFmt('Anthropic: resposta inválida: %s', [ABody]);
  try
    ContentArr := Root.GetValue<TJSONArray>('content', nil);
    if ContentArr = nil then
      raise ELLMProviderError.CreateFmt('Anthropic: resposta sem content: %s', [ABody]);

    TextBuf   := TStringBuilder.Create;
    ToolCalls := TList<TLLMToolCall>.Create;
    try
      for I := 0 to ContentArr.Count - 1 do
      begin
        Block := ContentArr.Items[I] as TJSONObject;
        BlockType := Block.GetValue<string>('type', '');

        if BlockType = 'text' then
          TextBuf.Append(Block.GetValue<string>('text', ''))
        else if BlockType = 'tool_use' then
        begin
          TC := Default(TLLMToolCall);
          TC.Id   := Block.GetValue<string>('id', '');
          TC.Name := Block.GetValue<string>('name', '');
          if Block.GetValue('input') <> nil then
            TC.ArgsJson := Block.GetValue('input').ToJSON
          else
            TC.ArgsJson := '{}';
          ToolCalls.Add(TC);
        end;
      end;

      Result.Content   := TextBuf.ToString;
      Result.ToolCalls := ToolCalls.ToArray;
    finally
      TextBuf.Free;
      ToolCalls.Free;
    end;

    Result.StopReason := MapStopReason(Root.GetValue<string>('stop_reason', ''));

    Usage := Root.GetValue<TJSONObject>('usage', nil);
    if Usage <> nil then
    begin
      Result.InputTokens  := Usage.GetValue<Integer>('input_tokens', 0);
      Result.OutputTokens := Usage.GetValue<Integer>('output_tokens', 0);
    end;
  finally
    Root.Free;
  end;
end;

function TAnthropicProvider.Complete(const AMessages: TArray<TLLMMessage>;
  const ATools: TArray<TToolSchema>): TLLMResponse;
var
  HttpClient: THTTPClient;
  Body: TJSONObject;
  Stream: TStringStream;
  Response: IHTTPResponse;
begin
  if FApiKey = '' then
    raise ELLMProviderError.Create('Anthropic: API key não configurada.');

  HttpClient := THTTPClient.Create;
  try
    HttpClient.ConnectionTimeout := 120000;
    HttpClient.ResponseTimeout   := 120000;
    HttpClient.CustomHeaders['x-api-key'] := FApiKey;
    HttpClient.CustomHeaders['anthropic-version'] := '2023-06-01';
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
      raise ELLMProviderError.CreateFmt('Anthropic HTTP %d: %s',
        [Response.StatusCode, Response.ContentAsString(TEncoding.UTF8)]);

    Result := ParseResponse(Response.ContentAsString(TEncoding.UTF8));
  finally
    HttpClient.Free;
  end;
end;

end.
