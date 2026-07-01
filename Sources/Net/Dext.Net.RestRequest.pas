{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
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
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-01-21                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Net.RestRequest;

interface

uses
  System.Classes,
  System.IOUtils,
  System.NetEncoding,
  System.SysUtils,
  Dext.Threading.Async,
  Dext.Threading.CancellationToken,
  Dext.Net.RestClient,
  Dext.Collections.Dict,
  Dext.Collections;

type
  { Internal forward declarations }
  IRestRequestData = interface;

  /// <summary>
  ///   Fluent builder for constructing complex REST operations.
  ///   Uses an internal interface for safe state management and asynchronous support.
  /// </summary>
  TRestRequest = record
  private
    FData: IRestRequestData;
    function GetData: IRestRequestData;
  public
    constructor Create(AClient: TRestClient; AMethod: TDextHttpMethod; const AEndpoint: string);
    function GetFullUrl: string;

    // Configuração
    /// <summary>Adds a custom HTTP header to the request.</summary>
    /// <param name="AName">The header name (e.g., 'Authorization').</param>
    /// <param name="AValue">The header value.</param>
    function Header(const AName, AValue: string): TRestRequest;
    /// <summary>Adds a query parameter (Query String) to the URL.</summary>
    /// <param name="AName">The parameter name.</param>
    /// <param name="AValue">The parameter value.</param>
    function QueryParam(const AName, AValue: string): TRestRequest; overload;
    /// <summary>Adds a query parameter only when Trim(AValue) is not empty.</summary>
    function QueryParamIfNotEmpty(const AName, AValue: string): TRestRequest;
    /// <summary>
    ///   Uses AValue when non-empty; otherwise uses Trim(ADefault).
    ///   Skips the parameter when both are empty.
    /// </summary>
    function QueryParam(const AName, AValue, ADefault: string): TRestRequest; overload;
    /// <summary>Adds a query parameter only when AInclude is True.</summary>
    function QueryParamIf(const AName, AValue: string; AInclude: Boolean): TRestRequest;
    /// <summary>Adds a query parameter only when AInclude is True.</summary>
    function QueryParam(const AName, AValue: string; AInclude: Boolean): TRestRequest; overload;
    /// <summary>Defines the request body from a Stream.</summary>
    /// <param name="ABody">The stream containing the payload.</param>
    /// <param name="AOwns">If true, the stream will be freed after the request completes.</param>
    function Body(ABody: TStream; AOwns: Boolean = False): TRestRequest; overload;
    /// <summary>Defines the request body by serializing the value T (class or record) to JSON.</summary>
    /// <param name="ABody">The object or record to serialize.</param>
    function Body<T>(const ABody: T): TRestRequest; overload;
    /// <summary>
    ///   Serializes a TArray of records R to a JSON array and sets it as the request body.
    ///   For a single record DTO, use: Body(MyRecord).
    /// </summary>
    /// <param name="ABody">The array of records to serialize.</param>
    function BodyArray<R: record>(const ABody: TArray<R>): TRestRequest;
    /// <summary>Defines a raw JSON string as the request body.</summary>
    /// <param name="AJson">The raw JSON content.</param>
    function JsonBody(const AJson: string): TRestRequest;
    /// <summary>Adds a form field to a multipart/form-data payload.</summary>
    /// <param name="AName">The field name.</param>
    /// <param name="AValue">The field value.</param>
    /// <param name="AContentType">Optional content type of the field.</param>
    function AddFormField(const AName, AValue: string; const AContentType: string = ''): TRestRequest;
    /// <summary>Adds a file (from disk path) to a multipart/form-data payload.</summary>
    function AddFile(const AFieldName, AFilePath: string): TRestRequest; overload;
    /// <summary>Adds a file (from disk path) with explicit content type.</summary>
    function AddFile(const AFieldName, AFilePath, AContentType: string): TRestRequest; overload;
    /// <summary>Adds a file from bytes to a multipart/form-data payload.</summary>
    function AddFile(const AFieldName, AFileName: string; const AContent: TBytes;
      const AContentType: string = 'application/octet-stream'): TRestRequest; overload;
    /// <summary>Adds a file from stream to a multipart/form-data payload.</summary>
    function AddFile(const AFieldName, AFileName: string; AStream: TStream;
      AOwnsStream: Boolean = False; const AContentType: string = 'application/octet-stream'): TRestRequest; overload;
    /// <summary>Associates a cancellation token with the execution of this request.</summary>
    function Cancellation(AToken: ICancellationToken): TRestRequest;

    // Execução
    /// <summary>Executes the request asynchronously and returns the raw response.</summary>
    /// <returns>An async builder for IRestResponse.</returns>
    function Execute: TAsyncBuilder<IRestResponse>; overload;
    /// <summary>Executes the request and deserializes the JSON result to type T (class, record or TArray).</summary>
    /// <returns>An async builder for the typed result.</returns>
    function Execute<T>: TAsyncBuilder<T>; overload;
    /// <summary>Executes the request and returns the body content as a string.</summary>
    /// <returns>An async builder for the content string.</returns>
    function ExecuteAsString: TAsyncBuilder<string>;
  end;

  /// <summary>
  ///   Lightweight factory record returned by TRestClientRequestHelper.Request.
  ///   Carries the originating TRestClient and provides verb-named fluent builder entry points.
  ///   Keeps TRestClient root namespace clean: Get/Post fire-and-forget;
  ///   Request.Get/Post/etc enter Builder Mode.
  /// </summary>
  TRestRequestFactory = record
  private
    FClient: TRestClient;
  public
    /// <summary>Creates a GET builder for the given endpoint.</summary>
    function Get(const AEndpoint: string = ''): TRestRequest;
    /// <summary>Creates a POST builder for the given endpoint.</summary>
    function Post(const AEndpoint: string = ''): TRestRequest;
    /// <summary>Creates a PUT builder for the given endpoint.</summary>
    function Put(const AEndpoint: string = ''): TRestRequest;
    /// <summary>Creates a DELETE builder for the given endpoint.</summary>
    function Delete(const AEndpoint: string = ''): TRestRequest;
    /// <summary>Creates a PATCH builder for the given endpoint.</summary>
    function Patch(const AEndpoint: string = ''): TRestRequest;
    /// <summary>Creates a QUERY builder for the given endpoint.</summary>
    function Query(const AEndpoint: string = ''): TRestRequest;
  end;

  /// <summary>
  ///   Record helper that extends TRestClient with the fluent Request factory.
  ///   Lives in Dext.Net.RestRequest to avoid a circular unit dependency:
  ///   RestRequest already imports RestClient; RestClient must not import RestRequest.
  ///   Activate by adding Dext.Net.RestRequest to your uses clause.
  ///   Usage: Client.Request.Post('/users').Body(Dto).Execute;
  /// </summary>
  TRestClientRequestHelper = record helper for TRestClient
    /// <summary>Returns a TRestRequestFactory bound to this client instance.</summary>
    function Request: TRestRequestFactory; overload;
    /// <summary>Directly creates a TRestRequest builder for a specific method and endpoint.</summary>
    function Request(AMethod: TDextHttpMethod; const AEndpoint: string): TRestRequest; overload;
  end;

  { Internal state interface }
  IRestRequestData = interface
    ['{D1E2F3A4-B5C6-4D7E-8F9A-0B1C2D3E4F5A}']
    function GetClient: TRestClient;
    function GetMethod: TDextHttpMethod;
    function GetEndpoint: string;
    function GetHeaders: IDictionary<string, string>;
    function GetQueryParams: IDictionary<string, string>;
    function GetBody: TStream;
    function GetToken: ICancellationToken;
    function GetOwnsBody: Boolean;
    function HasMultipartData: Boolean;
    function BuildMultipartBody: TStream;
    function GetMultipartBoundary: string;

    procedure SetBody(ABody: TStream; AOwns: Boolean);
    procedure SetToken(AToken: ICancellationToken);
    procedure AddMultipartField(const AName, AValue: string; const AContentType: string = '');
    procedure AddMultipartFile(const AFieldName, AFileName: string; const AData: TBytes;
      const AContentType: string);
    function DetachBody: TStream;
  end;

implementation

uses
  Dext.Json;

type
  TMultipartPartKind = (mpField, mpFile);

  TMultipartPart = record
    Kind: TMultipartPartKind;
    Name: string;
    Value: string;
    FileName: string;
    ContentType: string;
    Data: TBytes;
  end;

  TMultipartFormDataBuilder = class
  private
    FBoundary: string;
    FParts: IList<TMultipartPart>;
    class function NewBoundary: string; static;
    class procedure WriteUtf8(AStream: TStream; const AText: string); static;
  public
    constructor Create;
    function HasParts: Boolean;
    procedure AddField(const AName, AValue: string; const AContentType: string = '');
    procedure AddFile(const AFieldName, AFileName: string; const AData: TBytes;
      const AContentType: string);
    function BuildBody: TStream;
    property Boundary: string read FBoundary;
  end;

  TRestRequestData = class(TInterfacedObject, IRestRequestData)
  private
    FClient: TRestClient;
    FMethod: TDextHttpMethod;
    FEndpoint: string;
    FHeaders: IDictionary<string, string>;
    FQueryParams: IDictionary<string, string>;
    FBody: TStream;
    FToken: ICancellationToken;
    FOwnsBody: Boolean;
    FMultipartBuilder: TMultipartFormDataBuilder;
  public
    constructor Create(AClient: TRestClient; AMethod: TDextHttpMethod; const AEndpoint: string);
    destructor Destroy; override;

    function GetClient: TRestClient;
    function GetMethod: TDextHttpMethod;
    function GetEndpoint: string;
    function GetHeaders: IDictionary<string, string>;
    function GetQueryParams: IDictionary<string, string>;
    function GetBody: TStream;
    function GetToken: ICancellationToken;
    function GetOwnsBody: Boolean;
    function HasMultipartData: Boolean;
    function BuildMultipartBody: TStream;
    function GetMultipartBoundary: string;

    procedure SetBody(ABody: TStream; AOwns: Boolean);
    procedure SetToken(AToken: ICancellationToken);
    procedure AddMultipartField(const AName, AValue: string; const AContentType: string = '');
    procedure AddMultipartFile(const AFieldName, AFileName: string; const AData: TBytes;
      const AContentType: string);
    function DetachBody: TStream;
  end;

{ TMultipartFormDataBuilder }

constructor TMultipartFormDataBuilder.Create;
begin
  inherited Create;
  FBoundary := NewBoundary;
  FParts := TCollections.CreateList<TMultipartPart>;
end;

class function TMultipartFormDataBuilder.NewBoundary: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := '----DextBoundary' + GUIDToString(G).Replace('{', '').Replace('}', '');
end;

class procedure TMultipartFormDataBuilder.WriteUtf8(AStream: TStream; const AText: string);
var
  B: TBytes;
begin
  B := TEncoding.UTF8.GetBytes(AText);
  if Length(B) > 0 then
    AStream.WriteBuffer(B[0], Length(B));
end;

function TMultipartFormDataBuilder.HasParts: Boolean;
begin
  Result := (FParts <> nil) and (FParts.Count > 0);
end;

procedure TMultipartFormDataBuilder.AddField(const AName, AValue: string; const AContentType: string);
var
  Part: TMultipartPart;
begin
  Part.Kind := mpField;
  Part.Name := AName;
  Part.Value := AValue;
  Part.FileName := '';
  Part.ContentType := AContentType;
  Part.Data := nil;
  FParts.Add(Part);
end;

procedure TMultipartFormDataBuilder.AddFile(const AFieldName, AFileName: string;
  const AData: TBytes; const AContentType: string);
var
  Part: TMultipartPart;
begin
  Part.Kind := mpFile;
  Part.Name := AFieldName;
  Part.Value := '';
  Part.FileName := AFileName;
  Part.ContentType := AContentType;
  Part.Data := Copy(AData);
  FParts.Add(Part);
end;

function TMultipartFormDataBuilder.BuildBody: TStream;
var
  Part: TMultipartPart;
  BoundaryLine: string;
  PartContentType: string;
begin
  Result := TMemoryStream.Create;
  BoundaryLine := '--' + FBoundary + #13#10;

  for Part in FParts do
  begin
    WriteUtf8(Result, BoundaryLine);
    case Part.Kind of
      mpField:
        begin
          WriteUtf8(Result, Format('Content-Disposition: form-data; name="%s"'#13#10, [Part.Name]));
          if Part.ContentType <> '' then
            WriteUtf8(Result, 'Content-Type: ' + Part.ContentType + #13#10);
          WriteUtf8(Result, #13#10);
          WriteUtf8(Result, Part.Value + #13#10);
        end;
      mpFile:
        begin
          PartContentType := Part.ContentType;
          if PartContentType = '' then
            PartContentType := 'application/octet-stream';
          WriteUtf8(Result,
            Format('Content-Disposition: form-data; name="%s"; filename="%s"'#13#10,
            [Part.Name, Part.FileName]));
          WriteUtf8(Result, 'Content-Type: ' + PartContentType + #13#10#13#10);
          if Length(Part.Data) > 0 then
            Result.WriteBuffer(Part.Data[0], Length(Part.Data));
          WriteUtf8(Result, #13#10);
        end;
    end;
  end;

  WriteUtf8(Result, '--' + FBoundary + '--'#13#10);
  Result.Position := 0;
end;

  { TRestRequestData }

constructor TRestRequestData.Create(AClient: TRestClient; AMethod: TDextHttpMethod;
  const AEndpoint: string);
begin
  inherited Create;
  FClient := AClient;
  FMethod := AMethod;
  FEndpoint := AEndpoint;
  FHeaders := TCollections.CreateDictionary<string, string>;
  FQueryParams := TCollections.CreateDictionary<string, string>;
end;

destructor TRestRequestData.Destroy;
begin
  // FQueryParams is ARC
  if FOwnsBody then
    FBody.Free;
  FMultipartBuilder.Free;
  inherited;
end;

function TRestRequestData.GetBody: TStream;
begin
  Result := FBody;
end;

function TRestRequestData.GetClient: TRestClient;
begin
  Result := FClient;
end;

function TRestRequestData.GetEndpoint: string;
begin
  Result := FEndpoint;
end;

function TRestRequestData.GetHeaders: IDictionary<string, string>;
begin
  Result := FHeaders;
end;

function TRestRequestData.GetMethod: TDextHttpMethod;
begin
  Result := FMethod;
end;

function TRestRequestData.GetOwnsBody: Boolean;
begin
  Result := FOwnsBody;
end;

function TRestRequestData.HasMultipartData: Boolean;
begin
  Result := (FMultipartBuilder <> nil) and FMultipartBuilder.HasParts;
end;

function TRestRequestData.BuildMultipartBody: TStream;
begin
  if not HasMultipartData then
    Exit(nil);
  Result := FMultipartBuilder.BuildBody;
end;

function TRestRequestData.GetMultipartBoundary: string;
begin
  if FMultipartBuilder <> nil then
    Result := FMultipartBuilder.Boundary
  else
    Result := '';
end;

function TRestRequestData.GetQueryParams: IDictionary<string, string>;
begin
  Result := FQueryParams;
end;

function TRestRequestData.GetToken: ICancellationToken;
begin
  Result := FToken;
end;

procedure TRestRequestData.SetBody(ABody: TStream; AOwns: Boolean);
begin
  if FOwnsBody and Assigned(FBody) and (FBody <> ABody) then
    FBody.Free;
  FBody := ABody;
  FOwnsBody := AOwns;
  FreeAndNil(FMultipartBuilder);
end;

procedure TRestRequestData.SetToken(AToken: ICancellationToken);
begin
  FToken := AToken;
end;

procedure TRestRequestData.AddMultipartField(const AName, AValue: string;
  const AContentType: string);
begin
  if FMultipartBuilder = nil then
    FMultipartBuilder := TMultipartFormDataBuilder.Create;
  FMultipartBuilder.AddField(AName, AValue, AContentType);
end;

procedure TRestRequestData.AddMultipartFile(const AFieldName, AFileName: string;
  const AData: TBytes; const AContentType: string);
begin
  if FMultipartBuilder = nil then
    FMultipartBuilder := TMultipartFormDataBuilder.Create;
  FMultipartBuilder.AddFile(AFieldName, AFileName, AData, AContentType);
end;

function TRestRequestData.DetachBody: TStream;
begin
  Result := FBody;
  FBody := nil;
  FOwnsBody := False;
end;

{ TRestRequest }

constructor TRestRequest.Create(AClient: TRestClient; AMethod: TDextHttpMethod;
  const AEndpoint: string);
begin
  FData := TRestRequestData.Create(AClient, AMethod, AEndpoint);
end;

function TRestRequest.GetData: IRestRequestData;
begin
  if not Assigned(FData) then
    raise EDextRestException.Create('RestRequest not initialized');
  Result := FData;
end;

function TRestRequest.GetFullUrl: string;
var
  Url: string;
  First: Boolean;
  Data: IRestRequestData;
  Pair: TPair<string, string>;
begin
  Data := GetData;
  Url := Data.GetEndpoint;
  if Data.GetQueryParams.Count > 0 then
  begin
    First := not Url.Contains('?');
    for Pair in Data.GetQueryParams do
    begin
      if First then
        Url := Url + '?'
      else
        Url := Url + '&';
      Url := Url + TNetEncoding.Url.Encode(Pair.Key) + '=' +
        TNetEncoding.Url.Encode(Pair.Value);
      First := False;
    end;
  end;
  Result := Url;
end;

function TRestRequest.Header(const AName, AValue: string): TRestRequest;
begin
  GetData.GetHeaders.AddOrSetValue(AName, AValue);
  Result := Self;
end;

function IsBlank(const AText: string): Boolean;
var
  C: Char;
begin
  for C in AText do
    if C > ' ' then
      Exit(False);
  Result := True;
end;

function TRestRequest.QueryParam(const AName, AValue: string): TRestRequest;
begin
  GetData.GetQueryParams.AddOrSetValue(AName, AValue);
  Result := Self;
end;

function TRestRequest.QueryParamIfNotEmpty(const AName, AValue: string): TRestRequest;
begin
  if not IsBlank(AValue) then
    Result := QueryParam(AName, AValue)
  else
    Result := Self;
end;

function TRestRequest.QueryParam(const AName, AValue, ADefault: string): TRestRequest;
begin
  if not IsBlank(AValue) then
    Result := QueryParam(AName, AValue)
  else if not IsBlank(ADefault) then
    Result := QueryParam(AName, Trim(ADefault))
  else
    Result := Self;
end;

function TRestRequest.QueryParamIf(const AName, AValue: string; AInclude: Boolean): TRestRequest;
begin
  if AInclude then
    Result := QueryParam(AName, AValue)
  else
    Result := Self;
end;

function TRestRequest.QueryParam(const AName, AValue: string; AInclude: Boolean): TRestRequest;
begin
  Result := QueryParamIf(AName, AValue, AInclude);
end;

function TRestRequest.Body(ABody: TStream; AOwns: Boolean): TRestRequest;
begin
  GetData.SetBody(ABody, AOwns);
  Result := Self;
end;

function TRestRequest.Body<T>(const ABody: T): TRestRequest;
var
  Json: string;
begin
  Json := TDextJson.Serialize<T>(ABody);
  Result := JsonBody(Json);
end;

function TRestRequest.BodyArray<R>(const ABody: TArray<R>): TRestRequest;
begin
  Result := JsonBody(TDextJson.Serialize<TArray<R>>(ABody));
end;

function TRestRequest.JsonBody(const AJson: string): TRestRequest;
begin
  GetData.SetBody(TStringStream.Create(AJson, TEncoding.UTF8), True);
  GetData.GetHeaders.AddOrSetValue('Content-Type', 'application/json');
  Result := Self;
end;

function TRestRequest.AddFormField(const AName, AValue: string; const AContentType: string): TRestRequest;
begin
  GetData.AddMultipartField(AName, AValue, AContentType);
  Result := Self;
end;

function TRestRequest.AddFile(const AFieldName, AFilePath: string): TRestRequest;
begin
  Result := AddFile(AFieldName, AFilePath, 'application/octet-stream');
end;

function TRestRequest.AddFile(const AFieldName, AFilePath, AContentType: string): TRestRequest;
var
  Bytes: TBytes;
begin
  Bytes := TFile.ReadAllBytes(AFilePath);
  GetData.AddMultipartFile(AFieldName, TPath.GetFileName(AFilePath), Bytes, AContentType);
  Result := Self;
end;

function TRestRequest.AddFile(const AFieldName, AFileName: string; const AContent: TBytes;
  const AContentType: string): TRestRequest;
begin
  GetData.AddMultipartFile(AFieldName, AFileName, AContent, AContentType);
  Result := Self;
end;

function TRestRequest.AddFile(const AFieldName, AFileName: string; AStream: TStream;
  AOwnsStream: Boolean; const AContentType: string): TRestRequest;
var
  Bytes: TBytes;
  OriginalPosition: Int64;
begin
  if AStream = nil then
    raise EDextRestException.Create('AddFile stream cannot be nil');

  OriginalPosition := AStream.Position;
  try
    AStream.Position := 0;
    SetLength(Bytes, AStream.Size);
    if AStream.Size > 0 then
      AStream.ReadBuffer(Bytes[0], AStream.Size);
  finally
    if not AOwnsStream then
      AStream.Position := OriginalPosition;
    if AOwnsStream then
      AStream.Free;
  end;

  GetData.AddMultipartFile(AFieldName, AFileName, Bytes, AContentType);
  Result := Self;
end;

function TRestRequest.Cancellation(AToken: ICancellationToken): TRestRequest;
begin
  GetData.SetToken(AToken);
  Result := Self;
end;

function TRestRequest.Execute: TAsyncBuilder<IRestResponse>;
var
  Data: IRestRequestData;
  Client: TRestClient;
  Body: TStream;
  OwnsBody: Boolean;
begin
  Data := GetData;
  Client := Data.GetClient;

  if Data.HasMultipartData then
  begin
    Body := Data.BuildMultipartBody;
    OwnsBody := True;
    Data.GetHeaders.AddOrSetValue('Content-Type',
      'multipart/form-data; boundary=' + Data.GetMultipartBoundary);
  end
  else
  begin
    OwnsBody := Data.GetOwnsBody;
    if OwnsBody then
      Body := Data.DetachBody
    else
      Body := Data.GetBody;
  end;

  Result := Client.ExecuteAsync(Data.GetMethod, GetFullUrl, Body, OwnsBody,
    Data.GetHeaders);

  if Assigned(Data.GetToken) then
    Result := Result.WithCancellation(Data.GetToken);
end;

function TRestRequest.ExecuteAsString: TAsyncBuilder<string>;
begin
  Result := Execute.ThenBy<string>(
    TFunc<IRestResponse, string>(
      function(LResp: IRestResponse): string
      begin
        Result := LResp.ContentString;
      end
    )
  );
end;

function TRestRequest.Execute<T>: TAsyncBuilder<T>;
begin
  Result := Execute.ThenBy<T>(
    TFunc<IRestResponse, T>(
      function(LResp: IRestResponse): T
      begin
        Result := TDextJson.Deserialize<T>(LResp.ContentString);
      end
    )
  );
end;

{ TRestRequestFactory }

function TRestRequestFactory.Get(const AEndpoint: string): TRestRequest;
begin
  Result := TRestRequest.Create(FClient, hmGET, AEndpoint);
end;

function TRestRequestFactory.Post(const AEndpoint: string): TRestRequest;
begin
  Result := TRestRequest.Create(FClient, hmPOST, AEndpoint);
end;

function TRestRequestFactory.Put(const AEndpoint: string): TRestRequest;
begin
  Result := TRestRequest.Create(FClient, hmPUT, AEndpoint);
end;

function TRestRequestFactory.Delete(const AEndpoint: string): TRestRequest;
begin
  Result := TRestRequest.Create(FClient, hmDELETE, AEndpoint);
end;

function TRestRequestFactory.Patch(const AEndpoint: string): TRestRequest;
begin
  Result := TRestRequest.Create(FClient, hmPATCH, AEndpoint);
end;

function TRestRequestFactory.Query(const AEndpoint: string): TRestRequest;
begin
  Result := TRestRequest.Create(FClient, hmQUERY, AEndpoint);
end;

{ TRestClientRequestHelper }

function TRestClientRequestHelper.Request: TRestRequestFactory;
begin
  Result.FClient := Self;
end;

function TRestClientRequestHelper.Request(AMethod: TDextHttpMethod;
  const AEndpoint: string): TRestRequest;
begin
  Result := TRestRequest.Create(Self, AMethod, AEndpoint);
end;

end.

