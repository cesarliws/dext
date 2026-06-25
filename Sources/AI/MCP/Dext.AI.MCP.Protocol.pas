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
{    MCP (Model Context Protocol) core types and JSON-RPC 2.0 helpers.      }
{                                                                           }
{    The MCP protocol uses JSON-RPC 2.0 as its message format.              }
{    Supports: initialize, ping, tools/list, tools/call                     }
{                                                                           }
{  Reference: https://spec.modelcontextprotocol.io                          }
{                                                                           }
{***************************************************************************}
unit Dext.AI.MCP.Protocol;

interface

uses
  System.SysUtils,
  System.JSON,
  Dext.AI.MCP.Types;

const
  MCP_JSONRPC_VERSION  = '2.0';
  MCP_PROTOCOL_VERSION = '2025-03-26';

  // JSON-RPC 2.0 standard error codes
  JSONRPC_PARSE_ERROR      = -32700;
  JSONRPC_INVALID_REQUEST  = -32600;
  JSONRPC_METHOD_NOT_FOUND = -32601;
  JSONRPC_INVALID_PARAMS   = -32602;
  JSONRPC_INTERNAL_ERROR   = -32603;

  // MCP-specific error codes
  MCP_ERROR_TOOL_NOT_FOUND     = -32000;
  MCP_ERROR_TOOL_EXEC_FAILED   = -32001;
  MCP_ERROR_RESOURCE_NOT_FOUND = -32002;
  MCP_ERROR_PROMPT_NOT_FOUND   = -32003;
  MCP_ERROR_SESSION_NOT_FOUND  = -32004;

type
  /// <summary>
  /// Supported JSON schema types for tool parameters.
  /// </summary>
  TMCPParamType = (
    ptString,
    ptInteger,
    ptNumber,
    ptBoolean,
    ptObject,
    ptArray
  );

  /// <summary>
  /// Describes a single input parameter for an MCP tool.
  /// </summary>
  TMCPToolParam = record
    Name: string;
    Description: string;
    ParamType: TMCPParamType;
    Required: Boolean;

    class function Create(
      const AName, ADescription: string;
      AType: TMCPParamType = ptString;
      ARequired: Boolean = True): TMCPToolParam; static;

    /// <summary>Returns the JSON Schema type string.</summary>
    function TypeName: string;
  end;

  /// <summary>
  /// Legacy tool handler callback - returns a plain string.
  /// The string can be plain text or a JSON payload; it is sent as text content.
  /// New code should prefer TMCPToolResultCallback (rich content + error flag).
  /// </summary>
  TMCPToolCallback = reference to function(const Args: TJSONObject): string;

  /// <summary>
  /// Full definition of an MCP tool (name, description, params, handlers).
  ///
  /// ResultCallback takes precedence over Callback when both are set.
  /// Use ResultCallback for rich content (image, audio, embedded resource)
  /// or for explicit isError signalling.
  /// </summary>
  TMCPToolDef = record
    Name: string;
    Description: string;
    Params: TArray<TMCPToolParam>;
    Callback: TMCPToolCallback;            // legacy string callback
    ResultCallback: TMCPToolResultCallback; // rich result callback (preferred)
  end;

  /// <summary>
  /// JSON-RPC 2.0 response builder.
  /// All methods produce a self-contained JSON string ready to send.
  /// </summary>
  TJsonRpc = class
  public
    /// <summary>
    /// Builds a success response.
    /// ResultJson is a raw JSON string that will be embedded as the "result" value.
    /// </summary>
    class function Success(const Id: TJSONValue; const ResultJson: string): string; overload;

    /// <summary>
    /// Builds a success response from an already-parsed TJSONValue.
    /// The value is cloned - caller retains ownership of ResultObj.
    /// </summary>
    class function Success(const Id: TJSONValue; const ResultObj: TJSONValue): string; overload;

    /// <summary>
    /// Builds an error response.
    /// </summary>
    class function Error(const Id: TJSONValue; Code: Integer; const Msg: string): string;

    /// <summary>
    /// Extracts the "id" field from a JSON-RPC request object.
    /// Returns nil if not present (i.e. it is a notification).
    /// </summary>
    class function GetId(const Req: TJSONObject): TJSONValue;
  end;

implementation

{ TMCPToolParam }

class function TMCPToolParam.Create(const AName, ADescription: string;
  AType: TMCPParamType; ARequired: Boolean): TMCPToolParam;
begin
  Result.Name        := AName;
  Result.Description := ADescription;
  Result.ParamType   := AType;
  Result.Required    := ARequired;
end;

function TMCPToolParam.TypeName: string;
begin
  case ParamType of
    ptString:  Result := 'string';
    ptInteger: Result := 'integer';
    ptNumber:  Result := 'number';
    ptBoolean: Result := 'boolean';
    ptObject:  Result := 'object';
    ptArray:   Result := 'array';
  else
    Result := 'string';
  end;
end;

{ TJsonRpc }

class function TJsonRpc.Success(const Id: TJSONValue; const ResultJson: string): string;
var
  ResultVal: TJSONValue;
begin
  ResultVal := TJSONObject.ParseJSONValue(ResultJson);
  if ResultVal = nil then
    ResultVal := TJSONString.Create(ResultJson);
  try
    Result := Success(Id, ResultVal);
  finally
    ResultVal.Free;
  end;
end;

class function TJsonRpc.Success(const Id: TJSONValue; const ResultObj: TJSONValue): string;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('jsonrpc', MCP_JSONRPC_VERSION);

    if Id <> nil then
      Obj.AddPair('id', Id.Clone as TJSONValue)
    else
      Obj.AddPair('id', TJSONNull.Create);

    if ResultObj <> nil then
      Obj.AddPair('result', ResultObj.Clone as TJSONValue)
    else
      Obj.AddPair('result', TJSONObject.Create);

    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

class function TJsonRpc.Error(const Id: TJSONValue; Code: Integer; const Msg: string): string;
var
  Obj, ErrObj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('jsonrpc', MCP_JSONRPC_VERSION);

    if Id <> nil then
      Obj.AddPair('id', Id.Clone as TJSONValue)
    else
      Obj.AddPair('id', TJSONNull.Create);

    ErrObj := TJSONObject.Create;
    ErrObj.AddPair('code', TJSONNumber.Create(Code));
    ErrObj.AddPair('message', Msg);
    Obj.AddPair('error', ErrObj);

    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

class function TJsonRpc.GetId(const Req: TJSONObject): TJSONValue;
begin
  if Req = nil then
    Exit(nil);
  Result := Req.GetValue('id');
end;

end.
