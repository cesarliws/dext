{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025-2026 Cesar Romero & Dext Contributors        }
{                                                                           }
{           Licensed under the Apache License, Version 2.0 (the "License"); }
{           you may not use this file except in compliance with the License.}
{           You may obtain a copy of the License at                         }
{                                                                           }
{               http://www.apache.org/licenses/LICENSE-2.0                  }
{                                                                           }
{           Unless required by applicable law or agreed to in writing,      }
{           software distributed under the License is distributed on an     }
{           "AS IS\" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,    }
{           either express or implied. See the License for the specific     }
{           language governing permissions and limitations under the        }
{           License.                                                        }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2026-01-06                                                      }
{                                                                           }
{  Description:                                                             }
{    Types, records and helper classes for Dext.Web.Hubs.                       }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Hubs.Types;

{$I Dext.inc}

interface

uses
  System.Rtti,
  System.SysUtils;

type
  /// <summary>
  /// Explicitly allows a public Hub method to be invoked by a remote client.
  /// Public methods without this attribute remain server-side only.
  /// </summary>
  HubMethodAttribute = class(TCustomAttribute);

  /// <summary>
  /// Transport information in negotiate response.
  /// </summary>
  TTransportInfo = record
    Transport: string;
    TransferFormats: TArray<string>;
    
    class function SSE: TTransportInfo; static;
    class function LongPolling: TTransportInfo; static;
    class function WebSockets: TTransportInfo; static;
  end;
  
  /// <summary>
  /// Negotiate response sent to clients during connection handshake.
  /// </summary>
  TNegotiateResponse = record
    ConnectionId: string;
    ConnectionToken: string;
    NegotiateVersion: Integer;
    AvailableTransports: TArray<TTransportInfo>;
    
    function ToJson: string;
    class function Create(const AConnectionId: string): TNegotiateResponse;
      overload; static;
    class function Create(const AConnectionId: string;
      ASupportsWebSockets: Boolean): TNegotiateResponse; overload; static;
  end;
  
  /// <summary>
  /// Hub invocation request from client.
  /// </summary>
  TInvocationRequest = record
    InvocationId: string;
    Target: string;
    Arguments: TArray<string>; // JSON strings to be parsed
    
    class function FromJson(const Json: string): TInvocationRequest; static;
  end;
  
  /// <summary>
  /// Hub invocation result to client.
  /// </summary>
  TInvocationResult = record
    InvocationId: string;
    ResultValue: string; // Renamed from 'Result' to avoid conflict
    Error: string;
    
    function ToJson: string;
    class function Success(const AInvocationId, AResult: string): TInvocationResult; static;
    class function Failure(const AInvocationId, AError: string): TInvocationResult; static;
  end;
  
  /// <summary>
  /// Options for Hub configuration.
  /// </summary>
  THubOptions = record
    /// <summary>Enable detailed error messages to clients (dev only)</summary>
    EnableDetailedErrors: Boolean;
    /// <summary>Timeout for client connection in seconds</summary>
    ClientTimeoutInterval: Integer;
    /// <summary>Keep-alive ping interval in seconds</summary>
    KeepAliveInterval: Integer;
    /// <summary>Maximum message size in bytes</summary>
    MaximumReceiveMessageSize: Int64;
    /// <summary>Enabled transports</summary>
    EnabledTransports: TArray<string>;
    /// <summary>
    ///   When True (the default) only methods annotated with HubMethod can be
    ///   invoked by a remote client. Set it to False to restore the previous
    ///   behaviour, where every public method reachable through RTTI was
    ///   invokable, while annotating an existing Hub.
    /// </summary>
    RequireHubMethodAttribute: Boolean;
    
    class function Default: THubOptions; static;
  end;
  
  /// <summary>
  /// Exception for Hub-related errors.
  /// </summary>
  EHubException = class(Exception);
  
  /// <summary>
  /// Exception when connection is not found.
  /// </summary>
  EConnectionNotFoundException = class(EHubException);
  
  /// <summary>
  /// Exception when Hub method is not found.
  /// </summary>
  EHubMethodNotFoundException = class(EHubException);
  
  /// <summary>
  /// Exception when invocation fails.
  /// </summary>
  EHubInvocationException = class(EHubException);

  /// <summary>
  /// Exception when a Hub request exceeds the configured receive limit.
  /// </summary>
  EHubPayloadTooLargeException = class(EHubException);

implementation

uses
  System.JSON,
  System.Generics.Collections;

{ TTransportInfo }

class function TTransportInfo.SSE: TTransportInfo;
begin
  Result.Transport := 'ServerSentEvents';
  Result.TransferFormats := ['Text'];
end;

class function TTransportInfo.LongPolling: TTransportInfo;
begin
  Result.Transport := 'LongPolling';
  Result.TransferFormats := ['Text'];
end;

class function TTransportInfo.WebSockets: TTransportInfo;
begin
  Result.Transport := 'WebSockets';
  Result.TransferFormats := ['Text', 'Binary'];
end;

{ TNegotiateResponse }

class function TNegotiateResponse.Create(const AConnectionId: string): TNegotiateResponse;
begin
  Result := Create(AConnectionId, False);
end;

class function TNegotiateResponse.Create(const AConnectionId: string;
  ASupportsWebSockets: Boolean): TNegotiateResponse;
begin
  Result.ConnectionId := AConnectionId;
  Result.ConnectionToken := AConnectionId; // For now, same as ConnectionId
  Result.NegotiateVersion := 1;
  if ASupportsWebSockets then
    Result.AvailableTransports := [TTransportInfo.WebSockets, TTransportInfo.SSE]
  else
    Result.AvailableTransports := [TTransportInfo.SSE];
end;

function TNegotiateResponse.ToJson: string;
var
  Json, Transport: TJSONObject;
  Transports, Formats: TJSONArray;
  TInfo: TTransportInfo;
  Fmt: string;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('connectionId', ConnectionId);
    Json.AddPair('connectionToken', ConnectionToken);
    Json.AddPair('negotiateVersion', TJSONNumber.Create(NegotiateVersion));
    
    Transports := TJSONArray.Create;
    for TInfo in AvailableTransports do
    begin
      Transport := TJSONObject.Create;
      Transport.AddPair('transport', TInfo.Transport);
      
      Formats := TJSONArray.Create;
      for Fmt in TInfo.TransferFormats do
        Formats.Add(Fmt);
      Transport.AddPair('transferFormats', Formats);
      
      Transports.AddElement(Transport);
    end;
    Json.AddPair('availableTransports', Transports);
    
    Result := Json.ToJSON;
  finally
    Json.Free;
  end;
end;

{ TInvocationRequest }

class function TInvocationRequest.FromJson(const Json: string): TInvocationRequest;
var
  JObj: TJSONObject;
  JArgs: TJSONArray;
  I: Integer;
begin
  Result := Default(TInvocationRequest);
  JObj := TJSONObject.ParseJSONValue(Json) as TJSONObject;
  if JObj = nil then
    raise EHubException.Create('Invalid JSON in invocation request');
    
  try
    Result.InvocationId := JObj.GetValue<string>('invocationId', '');
    Result.Target := JObj.GetValue<string>('target', '');
    
    if JObj.TryGetValue<TJSONArray>('arguments', JArgs) then
    begin
      SetLength(Result.Arguments, JArgs.Count);
      for I := 0 to JArgs.Count - 1 do
        Result.Arguments[I] := JArgs.Items[I].ToJSON;
    end;
  finally
    JObj.Free;
  end;
end;

{ TInvocationResult }

class function TInvocationResult.Success(const AInvocationId, AResult: string): TInvocationResult;
begin
  Result.InvocationId := AInvocationId;
  Result.ResultValue := AResult;
  Result.Error := '';
end;

class function TInvocationResult.Failure(const AInvocationId, AError: string): TInvocationResult;
begin
  Result.InvocationId := AInvocationId;
  Result.ResultValue := '';
  Result.Error := AError;
end;

function TInvocationResult.ToJson: string;
var
  Json: TJSONObject;
  Output: string;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('type', TJSONNumber.Create(3)); // Completion
    if InvocationId <> '' then
      Json.AddPair('invocationId', InvocationId);
    
    if Error <> '' then
      Json.AddPair('error', Error)
    else if ResultValue <> '' then
      Json.AddPair('result', TJSONObject.ParseJSONValue(ResultValue));
      
    Output := Json.ToJSON;
  finally
    Json.Free;
  end;
  Result := Output;
end;

{ THubOptions }

class function THubOptions.Default: THubOptions;
begin
  Result.EnableDetailedErrors := False;
  Result.ClientTimeoutInterval := 30;
  Result.KeepAliveInterval := 15;
  Result.MaximumReceiveMessageSize := 32 * 1024; // 32KB
  Result.EnabledTransports := ['WebSockets', 'ServerSentEvents'];
  Result.RequireHubMethodAttribute := True;
end;

end.
