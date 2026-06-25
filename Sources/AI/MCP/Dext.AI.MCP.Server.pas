{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Description:                                                             }
{    Native MCP (Model Context Protocol) server - protocol 2025-03-26.      }
{                                                                           }
{  Transports:                                                              }
{    mtStreamable - HTTP Streamable (MCP 2025-03-26, recommended)           }
{      POST /mcp           ? synchronous JSON-RPC response                  }
{      DELETE /mcp         ? close session                                  }
{      GET  /mcp/sse       ? SSE notification stream (optional)             }
{      Claude Code config: url = http://host/mcp                            }
{                                                                           }
{    mtSSE  - legacy SSE transport (MCP 2024-11-05, backward-compat)        }
{      GET  /sse           ? SSE stream (endpoint event ? message events)   }
{      POST /message       ? enqueue message, returns 202                   }
{      Claude Desktop config: url = http://host/sse                         }
{                                                                           }
{    mtStdio - stdin/stdout (Claude Desktop process integration)            }
{                                                                           }
{  Capabilities (MCP 2025-03-26):                                           }
{    - tools        (list + call)                                           }
{    - resources    (list + read)                  - when resources added   }
{    - prompts      (list + get)                   - when prompts added     }
{                                                                           }
{  Quick start:                                                             }
{    var Server := TMCPServer.Create('my-server');                          }
{    Server.Tool('hello')                                                   }
{      .Description('Say hello')                                            }
{      .Param('name', 'Person name', ptString)                              }
{      .OnCallResult(function(Args: TJSONObject): TMCPToolResult            }
{        begin Result := TMCPToolResult.Text('Hello, ' +                    }
{          Args.GetValue<string>('name', 'World') + '!'); end);             }
{    Server.Run(mtStreamable, 'http://localhost:3031');                     }
{                                                                           }
{***************************************************************************}
unit Dext.AI.MCP.Server;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.SyncObjs,
  System.DateUtils,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.AI.MCP.Protocol,
  Dext.AI.MCP.Types,
  Dext.AI.MCP.Tools,
  Dext.AI.MCP.Resources,
  Dext.AI.MCP.Prompts,
  Dext.Web.Interfaces,
  Dext.Web.Sessions.Streamable,
  Dext.WebHost,
  Dext.DI.Interfaces;


type
  /// <summary>
  /// MCP transport selection.
  ///   mtStreamable - HTTP Streamable, recommended for MCP 2025-03-26.
  ///   mtSSE        - Legacy SSE transport (older Claude Desktop / agents).
  ///   mtStdio      - stdin/stdout for Claude Desktop process launch.
  /// </summary>
  TMCPTransport = (mtStreamable, mtSSE, mtStdio);



  // ---------------------------------------------------------------------------
  // TMCPServer - main entry point
  // ---------------------------------------------------------------------------

  /// <summary>
  /// Native MCP server supporting Tools, Resources, and Prompts.
  ///
  /// Recommended usage pattern:
  ///
  ///   var Server := TMCPServer.Create('erp-server', '2.0.0');
  ///
  ///   // Fluent tools
  ///   Server.Tool('get-customer')
  ///     .Description('Fetches customer by CPF')
  ///     .Param('cpf', 'Customer CPF', ptString)
  ///     .OnCallResult(function(Args: TJSONObject): TMCPToolResult
  ///       begin ... end);
  ///
  ///   // RTTI provider (preferred for large tool sets)
  ///   Server.RegisterProvider(TERPTools.Create);
  ///
  ///   // Resources
  ///   Server.Resource('config://app', 'App Config')
  ///     .Description('Current application settings as JSON')
  ///     .MimeType('application/json')
  ///     .OnRead(function(const Uri: string): TMCPResourceContents
  ///       begin Result := TMCPResourceContents.TextResource(Uri, GetConfig); end);
  ///
  ///   // Prompts
  ///   Server.Prompt('review-invoice', 'Reviews an invoice for errors')
  ///     .Arg('invoice_id', 'Invoice number')
  ///     .OnGet(function(Args: TJSONObject): TMCPPromptResult
  ///       begin ... end);
  ///
  ///   Server.Run(mtStreamable, 'http://localhost:3031');
  /// </summary>
  TMCPServer = class
  private
    FName: string;
    FVersion: string;
    FRegistry: TMCPToolRegistry;
    FResources: TMCPResourceRegistry;
    FPrompts: TMCPPromptRegistry;
    FSessions: IStreamableSessionManager;
    FHost: IWebHost;
    FShuttingDown: Boolean;

    // ---- JSON-RPC dispatch ----
    function Dispatch(const Body: string; const SessionId: string = ''): string; reintroduce; overload;
    function HandleInitialize(const Id: TJSONValue; const Params: TJSONObject;
      out ANewSessionId: string): string;
    function HandlePing(const Id: TJSONValue): string;
    function HandleToolsList(const Id: TJSONValue): string;
    function HandleToolsCall(const Id: TJSONValue;
      const Params: TJSONObject): string;
    function HandleResourcesList(const Id: TJSONValue): string;
    function HandleResourcesRead(const Id: TJSONValue;
      const Params: TJSONObject): string;
    function HandlePromptsList(const Id: TJSONValue): string;
    function HandlePromptsGet(const Id: TJSONValue;
      const Params: TJSONObject): string;

    // ---- HTTP route handlers (Streamable) ----
    procedure RouteStreamablePost(Ctx: IHttpContext);
    procedure RouteStreamableDelete(Ctx: IHttpContext);

    // ---- HTTP route handlers (legacy SSE) ----
    procedure RouteSSE(Ctx: IHttpContext);
    procedure RouteMessage(Ctx: IHttpContext);

    // ---- Stdio loop ----
    procedure RunStdioLoop;

    // ---- Helpers ----
    class function ReadBody(Ctx: IHttpContext): string; static;
    class function ToolResultToJSON(const CallResult: string): TJSONObject; static;
    class procedure AddCORSHeaders(const Response: IHttpResponse); static;
    procedure LogDebug(const AMsg: string);
  public
    constructor Create(const AName: string; const AVersion: string = '1.0.0');
    destructor Destroy; override;

    // ---- Tool registration ----

    /// <summary>Fluent builder for a new tool.</summary>
    function Tool(const AName: string): IMCPToolBuilder;

    /// <summary>
    /// Registers all [MCPTool], [MCPResource], [MCPPrompt] methods on AProvider.
    /// The server takes ownership of AProvider.
    /// </summary>
    procedure RegisterProvider(AProvider: TMCPToolProvider);

    // ---- Resource registration ----

    /// <summary>Fluent builder for a new resource.</summary>
    function Resource(const AUri, AName: string): IMCPResourceBuilder;

    // ---- Prompt registration ----

    /// <summary>Fluent builder for a new prompt template.</summary>
    function Prompt(const AName,
      ADescription: string): IMCPPromptBuilder;

    // ---- Lifecycle ----

    /// <summary>
    /// Starts the server.
    ///   mtStreamable - non-blocking HTTP (recommended, MCP 2025-03-26)
    ///   mtSSE        - non-blocking HTTP (legacy)
    ///   mtStdio      - blocking stdin loop
    /// </summary>
    procedure Run(ATransport: TMCPTransport = mtStreamable;
      const AUrl: string = 'http://localhost:3031');

    /// <summary>Stops the HTTP server. No-op for stdio.</summary>
    procedure Stop;

    property Name: string read FName;
    property Version: string read FVersion;
    property Registry: TMCPToolRegistry read FRegistry;
    property Resources: TMCPResourceRegistry read FResources;
    property Prompts: TMCPPromptRegistry read FPrompts;
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.Rtti,
  IdStack,
  IdIOHandler,
  IdException,
  Dext.Web.Indy;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function StreamToString(AStream: TStream): string;
var
  SS: TStringStream;
begin
  if (AStream = nil) or (AStream.Size = 0) then
    Exit('');
  AStream.Position := 0;
  SS := TStringStream.Create('', TEncoding.UTF8);
  try
    SS.CopyFrom(AStream, AStream.Size);
    Result := SS.DataString;
  finally
    SS.Free;
  end;
end;

procedure WriteSSEEvent(const Response: IHttpResponse;
  const EventType, Data: string);
begin
  Response.Write('event: ' + EventType + #10 + 'data: ' + Data + #10#10);
end;

procedure WriteSSEComment(const Response: IHttpResponse;
  const Comment: string);
begin
  Response.Write(': ' + Comment + #10#10);
end;

procedure ConfigureSSEResponse(const Response: IHttpResponse);
begin
  Response.SetContentType('text/event-stream');
  Response.AddHeader('Cache-Control', 'no-cache');
  Response.AddHeader('Connection', 'keep-alive');
  Response.AddHeader('X-Accel-Buffering', 'no');
  Response.AddHeader('Access-Control-Allow-Origin', '*');
end;

// ---------------------------------------------------------------------------
// TMCPServer - helpers
// ---------------------------------------------------------------------------

class function TMCPServer.ReadBody(Ctx: IHttpContext): string;
begin
  Result := StreamToString(Ctx.Request.Body);
end;

class function TMCPServer.ToolResultToJSON(
  const CallResult: string): TJSONObject;
var
  ContentArr: TJSONArray;
  ContentItem: TJSONObject;
begin
  ContentItem := TJSONObject.Create;
  ContentItem.AddPair('type', 'text');
  ContentItem.AddPair('text', CallResult);

  ContentArr := TJSONArray.Create;
  ContentArr.Add(ContentItem);

  Result := TJSONObject.Create;
  Result.AddPair('content', ContentArr);
end;

class procedure TMCPServer.AddCORSHeaders(const Response: IHttpResponse);
begin
  Response.AddHeader('Access-Control-Allow-Origin', '*');
  Response.AddHeader('Access-Control-Allow-Methods',
    'GET, POST, DELETE, OPTIONS');
  Response.AddHeader('Access-Control-Allow-Headers',
    'Content-Type, Mcp-Session-Id');
end;

procedure TMCPServer.LogDebug(const AMsg: string);
begin
{$IFDEF MSWINDOWS}
  OutputDebugString(PChar('[MCP] ' + AMsg));
{$ENDIF}
end;

// ---------------------------------------------------------------------------
// TMCPServer - JSON-RPC dispatch
// ---------------------------------------------------------------------------

function TMCPServer.Dispatch(const Body: string;
  const SessionId: string): string;
var
  Req: TJSONObject;
  Method: string;
  Id, Params: TJSONValue;
  IgnoredSessionId: string;
begin
  Result := '';

  if Body = '' then
    Exit(TJsonRpc.Error(nil, JSONRPC_INVALID_REQUEST, 'Empty request body'));

  Req := TJSONObject.ParseJSONValue(Body) as TJSONObject;
  if Req = nil then
    Exit(TJsonRpc.Error(nil, JSONRPC_PARSE_ERROR, 'Failed to parse JSON'));

  try
    Id     := TJsonRpc.GetId(Req);
    Method := Req.GetValue<string>('method', '');
    Params := Req.GetValue('params');

    if Method = 'notifications/initialized' then
      Exit('');

    // initialize via SSE or stdio - creates a session; session ID not needed here
    if Method = 'initialize' then
    begin
      IgnoredSessionId := '';
      Exit(HandleInitialize(Id, Params as TJSONObject, IgnoredSessionId));
    end
    else if Method = 'ping' then
      Exit(HandlePing(Id))
    else if Method = 'tools/list' then
      Exit(HandleToolsList(Id))
    else if Method = 'tools/call' then
      Exit(HandleToolsCall(Id, Params as TJSONObject))
    else if Method = 'resources/list' then
      Exit(HandleResourcesList(Id))
    else if Method = 'resources/read' then
      Exit(HandleResourcesRead(Id, Params as TJSONObject))
    else if Method = 'prompts/list' then
      Exit(HandlePromptsList(Id))
    else if Method = 'prompts/get' then
      Exit(HandlePromptsGet(Id, Params as TJSONObject))
    else
    begin
      if Id <> nil then
        Result := TJsonRpc.Error(Id, JSONRPC_METHOD_NOT_FOUND,
          'Method not found: ' + Method);
    end;
  finally
    Req.Free;
  end;
end;

function TMCPServer.HandleInitialize(const Id: TJSONValue;
  const Params: TJSONObject; out ANewSessionId: string): string;
var
  ResultObj, ServerInfo, Caps: TJSONObject;
  ToolsCap, ResourcesCap, PromptsCap: TJSONObject;
begin
  // Create a session for this client
  ANewSessionId := FSessions.CreateSession.Id;

  ServerInfo := TJSONObject.Create;
  ServerInfo.AddPair('name', FName);
  ServerInfo.AddPair('version', FVersion);

  // Advertise capabilities based on what is registered
  ToolsCap := TJSONObject.Create;
  ToolsCap.AddPair('listChanged', TJSONFalse.Create);

  Caps := TJSONObject.Create;
  Caps.AddPair('tools', ToolsCap);

  if FResources.Count > 0 then
  begin
    ResourcesCap := TJSONObject.Create;
    ResourcesCap.AddPair('subscribe', TJSONFalse.Create);
    ResourcesCap.AddPair('listChanged', TJSONFalse.Create);
    Caps.AddPair('resources', ResourcesCap);
  end;

  if FPrompts.Count > 0 then
  begin
    PromptsCap := TJSONObject.Create;
    PromptsCap.AddPair('listChanged', TJSONFalse.Create);
    Caps.AddPair('prompts', PromptsCap);
  end;

  ResultObj := TJSONObject.Create;
  ResultObj.AddPair('protocolVersion', MCP_PROTOCOL_VERSION);
  ResultObj.AddPair('capabilities', Caps);
  ResultObj.AddPair('serverInfo', ServerInfo);

  try
    Result := TJsonRpc.Success(Id, ResultObj);
  finally
    ResultObj.Free;
  end;
end;

function TMCPServer.HandlePing(const Id: TJSONValue): string;
var
  Empty: TJSONObject;
begin
  Empty := TJSONObject.Create;
  try
    Result := TJsonRpc.Success(Id, Empty);
  finally
    Empty.Free;
  end;
end;

function TMCPServer.HandleToolsList(const Id: TJSONValue): string;
var
  ResultObj: TJSONObject;
  ToolsArr: TJSONArray;
begin
  ToolsArr  := FRegistry.BuildToolsArray;
  ResultObj := TJSONObject.Create;
  try
    ResultObj.AddPair('tools', ToolsArr);
    Result := TJsonRpc.Success(Id, ResultObj);
  finally
    ResultObj.Free;
  end;
end;

function TMCPServer.HandleToolsCall(const Id: TJSONValue;
  const Params: TJSONObject): string;
var
  ToolName: string;
  Def: TMCPToolDef;
  ArgsVal: TJSONValue;
  ArgsObj: TJSONObject;
  OwnArgs: Boolean;
  CallResult: string;
  RichResult: TMCPToolResult;
  Content: TJSONObject;
begin
  if Params = nil then
    Exit(TJsonRpc.Error(Id, JSONRPC_INVALID_PARAMS, 'Missing params'));

  ToolName := Params.GetValue<string>('name', '');
  if ToolName = '' then
    Exit(TJsonRpc.Error(Id, JSONRPC_INVALID_PARAMS, 'Missing tool name'));

  if not FRegistry.TryGetTool(ToolName, Def) then
    Exit(TJsonRpc.Error(Id, MCP_ERROR_TOOL_NOT_FOUND,
      'Tool not found: ' + ToolName));

  ArgsVal := Params.GetValue('arguments');
  if (ArgsVal <> nil) and (ArgsVal is TJSONObject) then
  begin
    ArgsObj  := ArgsVal as TJSONObject;
    OwnArgs  := False;
  end
  else
  begin
    ArgsObj  := TJSONObject.Create;
    OwnArgs  := True;
  end;

  try
    // ResultCallback (rich) takes precedence over legacy Callback (string)
    if Assigned(Def.ResultCallback) then
    begin
      try
        RichResult := Def.ResultCallback(ArgsObj);
      except
        on E: Exception do
          Exit(TJsonRpc.Error(Id, MCP_ERROR_TOOL_EXEC_FAILED,
            'Tool execution failed: ' + E.Message));
      end;

      Content := RichResult.ToJSON;
      try
        Result := TJsonRpc.Success(Id, Content);
      finally
        Content.Free;
      end;
    end
    else if Assigned(Def.Callback) then
    begin
      try
        CallResult := Def.Callback(ArgsObj);
      except
        on E: Exception do
          Exit(TJsonRpc.Error(Id, MCP_ERROR_TOOL_EXEC_FAILED,
            'Tool execution failed: ' + E.Message));
      end;

      Content := ToolResultToJSON(CallResult);
      try
        Result := TJsonRpc.Success(Id, Content);
      finally
        Content.Free;
      end;
    end
    else
      Result := TJsonRpc.Error(Id, MCP_ERROR_TOOL_EXEC_FAILED,
        'Tool has no callback: ' + ToolName);
  finally
    if OwnArgs then ArgsObj.Free;
  end;
end;

function TMCPServer.HandleResourcesList(const Id: TJSONValue): string;
var
  ResultObj: TJSONObject;
  ResArr: TJSONArray;
begin
  ResArr    := FResources.BuildResourcesArray;
  ResultObj := TJSONObject.Create;
  try
    ResultObj.AddPair('resources', ResArr);
    Result := TJsonRpc.Success(Id, ResultObj);
  finally
    ResultObj.Free;
  end;
end;

function TMCPServer.HandleResourcesRead(const Id: TJSONValue;
  const Params: TJSONObject): string;
var
  Uri: string;
  Contents: TMCPResourceContents;
  ResultObj: TJSONObject;
  ContentsArr: TJSONArray;
begin
  if Params = nil then
    Exit(TJsonRpc.Error(Id, JSONRPC_INVALID_PARAMS, 'Missing params'));

  Uri := Params.GetValue<string>('uri', '');
  if Uri = '' then
    Exit(TJsonRpc.Error(Id, JSONRPC_INVALID_PARAMS, 'Missing uri'));

  if not FResources.TryRead(Uri, Contents) then
    Exit(TJsonRpc.Error(Id, MCP_ERROR_RESOURCE_NOT_FOUND,
      'Resource not found: ' + Uri));

  ContentsArr := TJSONArray.Create;
  ContentsArr.Add(Contents.ToJSON);

  ResultObj := TJSONObject.Create;
  try
    ResultObj.AddPair('contents', ContentsArr);
    Result := TJsonRpc.Success(Id, ResultObj);
  finally
    ResultObj.Free;
  end;
end;

function TMCPServer.HandlePromptsList(const Id: TJSONValue): string;
var
  ResultObj: TJSONObject;
  PromptsArr: TJSONArray;
begin
  PromptsArr := FPrompts.BuildPromptsArray;
  ResultObj  := TJSONObject.Create;
  try
    ResultObj.AddPair('prompts', PromptsArr);
    Result := TJsonRpc.Success(Id, ResultObj);
  finally
    ResultObj.Free;
  end;
end;

function TMCPServer.HandlePromptsGet(const Id: TJSONValue;
  const Params: TJSONObject): string;
var
  PromptName: string;
  ArgsVal: TJSONValue;
  ArgsObj: TJSONObject;
  OwnArgs: Boolean;
  PromptResult: TMCPPromptResult;
  ResultObj: TJSONObject;
begin
  if Params = nil then
    Exit(TJsonRpc.Error(Id, JSONRPC_INVALID_PARAMS, 'Missing params'));

  PromptName := Params.GetValue<string>('name', '');
  if PromptName = '' then
    Exit(TJsonRpc.Error(Id, JSONRPC_INVALID_PARAMS, 'Missing prompt name'));

  ArgsVal := Params.GetValue('arguments');
  if (ArgsVal <> nil) and (ArgsVal is TJSONObject) then
  begin
    ArgsObj := ArgsVal as TJSONObject;
    OwnArgs := False;
  end
  else
  begin
    ArgsObj := TJSONObject.Create;
    OwnArgs := True;
  end;

  try
    if not FPrompts.TryGet(PromptName, ArgsObj, PromptResult) then
      Exit(TJsonRpc.Error(Id, MCP_ERROR_PROMPT_NOT_FOUND,
        'Prompt not found: ' + PromptName));

    ResultObj := PromptResult.ToJSON;
    try
      Result := TJsonRpc.Success(Id, ResultObj);
    finally
      ResultObj.Free;
    end;
  finally
    if OwnArgs then ArgsObj.Free;
  end;
end;

// ---------------------------------------------------------------------------
// TMCPServer - HTTP Streamable transport (MCP 2025-03-26)
// ---------------------------------------------------------------------------

procedure TMCPServer.RouteStreamablePost(Ctx: IHttpContext);
var
  SessionId, Body, Response, Method, NewSessionId: string;
  ReqObj: TJSONObject;
  Id: TJSONValue;
  Params: TJSONObject;
begin
  // CORS preflight
  if Ctx.Request.Method = 'OPTIONS' then
  begin
    AddCORSHeaders(Ctx.Response);
    Ctx.Response.StatusCode := 204;
    Exit;
  end;

  AddCORSHeaders(Ctx.Response);

  // Session ID from header (absent on first initialize)
  SessionId := Ctx.Request.GetHeader('Mcp-Session-Id');
  Body      := ReadBody(Ctx);

  // Peek at the method without consuming the body
  Method  := '';
  ReqObj  := TJSONObject.ParseJSONValue(Body) as TJSONObject;
  if ReqObj <> nil then
  begin
    try
      Method := ReqObj.GetValue<string>('method', '');

      if Method = 'initialize' then
      begin
        // Handle initialize directly so we can capture the new session ID
        Id     := TJsonRpc.GetId(ReqObj);
        Params := ReqObj.GetValue('params') as TJSONObject;

        NewSessionId := '';
        Response     := HandleInitialize(Id, Params, NewSessionId);

        Ctx.Response.AddHeader('Mcp-Session-Id', NewSessionId);
      end
      else
      begin
        // Validate session for all other methods
        if (SessionId <> '') and (FSessions.GetSession(SessionId) = nil) then
        begin
          Ctx.Response.StatusCode := 404;
          Ctx.Response.SetContentType('application/json');
          Ctx.Response.Write(TJsonRpc.Error(nil, MCP_ERROR_SESSION_NOT_FOUND,
            'Session not found: ' + SessionId));
          Exit;
        end;

        Response := Dispatch(Body, SessionId);
      end;
    finally
      ReqObj.Free;
    end;
  end
  else
    Response := TJsonRpc.Error(nil, JSONRPC_PARSE_ERROR, 'Failed to parse JSON');

  if Response <> '' then
  begin
    Ctx.Response.StatusCode := 200;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write(Response);
  end
  else
    Ctx.Response.StatusCode := 202; // notification - no response body
end;

procedure TMCPServer.RouteStreamableDelete(Ctx: IHttpContext);
var
  SessionId: string;
  Session: IStreamableSession;
begin
  AddCORSHeaders(Ctx.Response);

  SessionId := Ctx.Request.GetHeader('Mcp-Session-Id');
  if SessionId = '' then
    Ctx.Request.Query.TryGetValue('sessionId', SessionId);

  if SessionId <> '' then
  begin
    Session := FSessions.GetSession(SessionId);
    if Session <> nil then
    begin
      FSessions.DestroySession(SessionId);
    end;
  end;

  Ctx.Response.StatusCode := 200;
end;

// ---------------------------------------------------------------------------
// TMCPServer - legacy SSE transport handlers
// ---------------------------------------------------------------------------

procedure TMCPServer.RouteSSE(Ctx: IHttpContext);
var
  Session: IStreamableSession;
  EvtName, Msg: string;
  KeepAlive: Integer;
begin
  Session := FSessions.CreateSession;
  try
    ConfigureSSEResponse(Ctx.Response);

    { Switch the Indy response to chunked Transfer-Encoding. Without this,
      Response.Write accumulates into FResponseInfo.ContentText and nothing
      reaches the client until the handler returns - which for SSE is
      "never" (the loop below runs until shutdown). The Flush after the
      first event releases headers + the endpoint event so the client can
      start POSTing to /message. }
    if Ctx.Response is TDextIndyHttpResponse then
      TDextIndyHttpResponse(Ctx.Response).BeginStreamingResponse;

    WriteSSEEvent(Ctx.Response, 'endpoint',
      '/message?sessionId=' + Session.Id);

    if Ctx.Response is TDextIndyHttpResponse then
      TDextIndyHttpResponse(Ctx.Response).Flush;

    KeepAlive := 0;

    while not FShuttingDown do
    begin
      try
        while Session.HasEvents and not FShuttingDown do
        begin
          if Session.TryDequeueEvent(EvtName, Msg) then
            WriteSSEEvent(Ctx.Response, EvtName, Msg);
        end;

        Inc(KeepAlive);
        if KeepAlive >= 150 then
        begin
          if (Ctx.Response is TDextIndyHttpResponse)
             and not TDextIndyHttpResponse(Ctx.Response).IsClientConnected then
            Break;

          WriteSSEComment(Ctx.Response, 'ping - ' +
            FormatDateTime('YYYY-MM-DD HH:NN:SS.ZZZ', Now));
          KeepAlive := 0;
        end;
      except
        on EIdSocketError do
          Break;
        on EIdConnClosedGracefully do
          Break;
      end;

      Sleep(100);
    end;
  finally
    if Ctx.Response is TDextIndyHttpResponse then
      TDextIndyHttpResponse(Ctx.Response).EndStreamingResponse;
    FSessions.DestroySession(Session.Id);
  end;
end;

procedure TMCPServer.RouteMessage(Ctx: IHttpContext);
var
  SessionId, Body, Response: string;
  Session: IStreamableSession;
begin
  if Ctx.Request.Method = 'OPTIONS' then
  begin
    AddCORSHeaders(Ctx.Response);
    Ctx.Response.StatusCode := 204;
    Exit;
  end;

  AddCORSHeaders(Ctx.Response);

  if not Ctx.Request.Query.TryGetValue('sessionId', SessionId) then
    SessionId := Ctx.Request.GetQueryParam('sessionId');

  Session := FSessions.GetSession(SessionId);
  if Session = nil then
  begin
    Ctx.Response.StatusCode := 400;
    Ctx.Response.SetContentType('application/json');
    Ctx.Response.Write('{"error":"Unknown sessionId"}');
    Exit;
  end;

  Body     := ReadBody(Ctx);
  Response := Dispatch(Body, SessionId);

  if Response <> '' then
    Session.SendSseEvent('message', Response);

  Ctx.Response.StatusCode := 202;
end;

// ---------------------------------------------------------------------------
// TMCPServer - stdio transport
// ---------------------------------------------------------------------------

procedure TMCPServer.RunStdioLoop;
var
  Line, Response: string;
begin
  while not EOF(Input) do
  begin
    Readln(Line);
    Line := Line.Trim;
    if Line = '' then Continue;

    Response := Dispatch(Line);
    if Response <> '' then
      Writeln(Response);
  end;
end;

// ---------------------------------------------------------------------------
// TMCPServer - public API
// ---------------------------------------------------------------------------

constructor TMCPServer.Create(const AName: string; const AVersion: string);
begin
  inherited Create;
  FName      := AName;
  FVersion   := AVersion;
  FRegistry  := TMCPToolRegistry.Create;
  FResources := TMCPResourceRegistry.Create;
  FPrompts   := TMCPPromptRegistry.Create;
  FSessions  := TInMemoryStreamableSessionManager.Create;
  FShuttingDown := False;
end;

destructor TMCPServer.Destroy;
begin
  Stop;
  FSessions  := nil;
  FPrompts.Free;
  FResources.Free;
  FRegistry.Free;
  inherited;
end;

function TMCPServer.Tool(const AName: string): IMCPToolBuilder;
begin
  Result := FRegistry.Register(AName);
end;

procedure TMCPServer.RegisterProvider(AProvider: TMCPToolProvider);
begin
  // Register tools - the registry takes ownership of AProvider
  FRegistry.RegisterProvider(AProvider);

  // Scan the same provider for [MCPResource] and [MCPPrompt] methods.
  // Both registries use TReflection.Context (the shared, properly managed
  // RTTI context) to avoid creating orphan pool tokens.
  FResources.ScanProvider(AProvider);
  FPrompts.ScanProvider(AProvider);
end;

function TMCPServer.Resource(const AUri, AName: string): IMCPResourceBuilder;
begin
  Result := FResources.Register(AUri, AName);
end;

function TMCPServer.Prompt(const AName,
  ADescription: string): IMCPPromptBuilder;
begin
  Result := FPrompts.Register(AName, ADescription);
end;

procedure TMCPServer.Run(ATransport: TMCPTransport; const AUrl: string);
begin
  if ATransport = mtStdio then
  begin
    RunStdioLoop;
    Exit;
  end;

  FHost := TWebHostBuilder.CreateDefault(nil)
    .UseUrls(AUrl)
    .ConfigureServices(procedure(Services: IServiceCollection)
      begin
        // Add application services here if needed.
      end)
    .Configure(procedure(App: IApplicationBuilder)
      begin
        if ATransport = mtStreamable then
        begin
          // MCP 2025-03-26 HTTP Streamable transport
          App.MapPost('/mcp',
            procedure(Ctx: IHttpContext)
            begin
              RouteStreamablePost(Ctx);
            end);

          App.MapEndpoint('DELETE', '/mcp',
            procedure(Ctx: IHttpContext)
            begin
              RouteStreamableDelete(Ctx);
            end);

          App.MapEndpoint('OPTIONS', '/mcp',
            procedure(Ctx: IHttpContext)
            begin
              AddCORSHeaders(Ctx.Response);
              Ctx.Response.StatusCode := 204;
            end);
        end
        else // mtSSE - legacy transport
        begin
          App.MapGet('/sse',
            procedure(Ctx: IHttpContext)
            begin
              RouteSSE(Ctx);
            end);

          App.MapPost('/message',
            procedure(Ctx: IHttpContext)
            begin
              RouteMessage(Ctx);
            end);

          App.MapEndpoint('OPTIONS', '/message',
            procedure(Ctx: IHttpContext)
            begin
              RouteMessage(Ctx);
            end);
        end;

        // Health endpoint available in both HTTP transports
        App.MapGet('/health',
          procedure(Ctx: IHttpContext)
          begin
            Ctx.Response.SetContentType('application/json');
            Ctx.Response.Write(Format(
              '{"status":"ok","server":"%s","version":"%s",' +
              '"protocol":"%s","tools":%d,"resources":%d,"prompts":%d}',
              [FName, FVersion, MCP_PROTOCOL_VERSION,
               FRegistry.Count, FResources.Count, FPrompts.Count]));
          end);
      end)
    .Build;

  FHost.Start;

  if ATransport = mtStreamable then
    LogDebug(Format('%s v%s listening at %s (Streamable, MCP %s)',
      [FName, FVersion, AUrl, MCP_PROTOCOL_VERSION]))
  else
    LogDebug(Format('%s v%s listening at %s (SSE legacy)',
      [FName, FVersion, AUrl]));
end;

procedure TMCPServer.Stop;
begin
  FShuttingDown := True;

  if FHost <> nil then
  begin
    try
      FHost.Stop;
    except
      // Swallow shutdown errors
    end;
    FHost := nil;
  end;
end;

end.
