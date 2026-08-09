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
{  Author:  Cesar Romero                                                    }
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.Middleware.Compression;

{$I Dext.inc}

interface

uses
  System.Classes,
  System.Math,
  System.Rtti,
  System.SysUtils,
  System.ZLib,
  Dext.Web.Interfaces, Dext.Entity.Core, Dext.Entity.FastQuery, Dext.Web.Builder, Dext.Collections.Dict;

type
  /// <summary>
  ///   Options for configuring HTTP response compression middleware (GZip / Brotli).
  /// </summary>
  TCompressionOptions = record
  public
    /// <summary> Enables response compression for HTTPS requests (disabled by default for CRIME/BREACH mitigation). </summary>
    EnableForHttps: Boolean;
    /// <summary> Minimum response body size in bytes required to trigger compression. </summary>
    MinimumResponseBodySize: Int64;
    /// <summary> List of MIME types eligible for response compression. </summary>
    MimeTypes: TArray<string>;
    /// <summary> Creates default compression options. </summary>
    class function Create: TCompressionOptions; static;
    /// <summary> Determines whether the specified MIME type is eligible for compression. </summary>
    function IsMimeTypeCompressible(const AMimeType: string): Boolean;
  end;

  /// <summary>
  ///   Fluent builder for creating TCompressionOptions.
  /// </summary>
  TCompressionBuilder = record
  private
    FOptions: TCompressionOptions;
    FInitialized: Boolean;
    procedure EnsureInitialized;
  public
    /// <summary> Creates a new fluent compression options builder. </summary>
    class function Create: TCompressionBuilder; static;
    /// <summary> Sets whether compression is enabled for HTTPS requests. </summary>
    function EnableForHttps(AValue: Boolean = True): TCompressionBuilder;
    /// <summary> Sets minimum response body size threshold for compression. </summary>
    function MinimumSize(ASize: Int64): TCompressionBuilder;
    /// <summary> Configures allowed MIME types for compression. </summary>
    function MimeTypes(const AMimeTypes: TArray<string>): TCompressionBuilder;
    /// <summary> Builds and returns configured TCompressionOptions. </summary>
    function Build: TCompressionOptions;
    /// <summary> Implicit conversion operator from builder to options. </summary>
    class operator Implicit(const ABuilder: TCompressionBuilder): TCompressionOptions;
  end;

  /// <summary>
  ///   Middleware that compresses HTTP responses using GZip or Deflate encoding.
  /// </summary>
  TCompressionMiddleware = class(TMiddleware)
  private
    FOptions: TCompressionOptions;
  public
    /// <summary> Initializes a new compression middleware with default options. </summary>
    constructor Create; overload;
    /// <summary> Initializes a new compression middleware with custom options. </summary>
    constructor Create(const AOptions: TCompressionOptions); overload;
    /// <summary> Processes request and compresses response payload if eligible. </summary>
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

/// <summary>
///   Factory function returning a fluent TCompressionBuilder instance.
/// </summary>
function CompressionOptions: TCompressionBuilder;

implementation

uses
  Dext.Json;

type
  TBufferedResponse = class(TInterfacedObject, IHttpResponse)
  private
    FInner: IHttpResponse;
    FBuffer: TMemoryStream;
  public
    constructor Create(const AInner: IHttpResponse);
    destructor Destroy; override;

    function GetHtmx: IHtmxResponse;
    function GetHeaders: IStringDictionary;

    function GetStatusCode: Integer;
    function GetContentType: string;
    function Status(AValue: Integer): IHttpResponse; overload;
    function Status(AValue: Integer; const AMessage: string): IHttpResponse; overload;
    procedure SetStatusCode(AValue: Integer);
    procedure SetContentType(const AValue: string);
    procedure SetContentLength(const AValue: Int64);
    procedure Flush;
    procedure Write(const AContent: string); overload;
    procedure Write(const ABuffer: TBytes); overload;
    procedure Write(const AStream: TStream); overload;
    procedure SendJsonUtf8(const AUtf8Json: RawByteString); overload;
    procedure SendJsonUtf8(const ABuffer: TBytes); overload;
    function GetOutputStream: TStream;
    procedure Json(const AJson: string); overload;
    procedure Json(const AValue: TValue); overload;
    procedure WriteJson(const AValue: TValue); overload;
    procedure WriteJson(ACode: Integer; const AValue: TValue); overload;
    procedure WriteJson(const AQuery: IDextFastQuery); overload;
    procedure WriteJson(ACode: Integer; const AQuery: IDextFastQuery); overload;
    {$IFDEF DEXT_ENABLE_ENTITY}
    procedure WriteJson(const AStream: IDbSetFastStream); overload;
    procedure WriteJson(ACode: Integer; const AStream: IDbSetFastStream); overload;
    {$ENDIF}
    procedure AddHeader(const AName, AValue: string);
    procedure AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions); overload;
    procedure AppendCookie(const AName, AValue: string); overload;
    procedure DeleteCookie(const AName: string);
    procedure Redirect(const AUrl: string; APermanent: Boolean = False);
    procedure Unauthorized(const AMessage: string = '');
    procedure Forbidden(const AMessage: string = '');
    procedure BadRequest(const AMessage: string = '');
    procedure NotFound(const AMessage: string = '');
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
    property ContentType: string read GetContentType write SetContentType;
    property Buffer: TMemoryStream read FBuffer;
  end;

{ TBufferedResponse }

constructor TBufferedResponse.Create(const AInner: IHttpResponse);
begin
  inherited Create;
  FInner := AInner;
  FBuffer := TMemoryStream.Create;
end;

destructor TBufferedResponse.Destroy;
begin
  FBuffer.Free;
  inherited;
end;

procedure TBufferedResponse.AddHeader(const AName, AValue: string); begin FInner.AddHeader(AName, AValue); end;
procedure TBufferedResponse.AppendCookie(const AName, AValue: string; const AOptions: TCookieOptions); begin FInner.AppendCookie(AName, AValue, AOptions); end;
procedure TBufferedResponse.AppendCookie(const AName, AValue: string); begin FInner.AppendCookie(AName, AValue); end;
procedure TBufferedResponse.DeleteCookie(const AName: string); begin FInner.DeleteCookie(AName); end;
procedure TBufferedResponse.Redirect(const AUrl: string; APermanent: Boolean); begin FInner.Redirect(AUrl, APermanent); end;
procedure TBufferedResponse.Unauthorized(const AMessage: string); begin FInner.Unauthorized(AMessage); end;
procedure TBufferedResponse.Forbidden(const AMessage: string); begin FInner.Forbidden(AMessage); end;
procedure TBufferedResponse.BadRequest(const AMessage: string); begin FInner.BadRequest(AMessage); end;
procedure TBufferedResponse.NotFound(const AMessage: string); begin FInner.NotFound(AMessage); end;
function TBufferedResponse.GetHtmx: IHtmxResponse; begin Result := FInner.Htmx; end;
function TBufferedResponse.GetHeaders: IStringDictionary; begin Result := FInner.Headers; end;
function TBufferedResponse.GetStatusCode: Integer; begin Result := FInner.StatusCode; end;
function TBufferedResponse.GetContentType: string; begin Result := FInner.ContentType; end;
procedure TBufferedResponse.Json(const AJson: string);
begin
  SetContentType('application/json; charset=utf-8');
  Write(AJson);
end;

procedure TBufferedResponse.Json(const AValue: TValue);
begin
  Json(Dext.Json.TDextJson.Serialize(AValue));
end;
procedure TBufferedResponse.SetContentLength(const AValue: Int64); begin FInner.SetContentLength(AValue); end;
procedure TBufferedResponse.Flush; begin FInner.Flush; end;
procedure TBufferedResponse.SetContentType(const AValue: string); begin FInner.SetContentType(AValue); end;
procedure TBufferedResponse.SetStatusCode(AValue: Integer); begin FInner.StatusCode := AValue; end;
function TBufferedResponse.Status(AValue: Integer): IHttpResponse; begin FInner.Status(AValue); Result := Self; end;
function TBufferedResponse.Status(AValue: Integer; const AMessage: string): IHttpResponse; begin FInner.Status(AValue, AMessage); Result := Self; end;
procedure TBufferedResponse.WriteJson(const AValue: TValue); begin FInner.WriteJson(AValue); end;
procedure TBufferedResponse.WriteJson(ACode: Integer; const AValue: TValue); begin FInner.WriteJson(ACode, AValue); end;
procedure TBufferedResponse.WriteJson(const AQuery: IDextFastQuery); begin FInner.WriteJson(AQuery); end;
procedure TBufferedResponse.WriteJson(ACode: Integer; const AQuery: IDextFastQuery); begin FInner.WriteJson(ACode, AQuery); end;
{$IFDEF DEXT_ENABLE_ENTITY}
procedure TBufferedResponse.WriteJson(const AStream: IDbSetFastStream); begin FInner.WriteJson(AStream); end;
procedure TBufferedResponse.WriteJson(ACode: Integer; const AStream: IDbSetFastStream); begin FInner.WriteJson(ACode, AStream); end;
{$ENDIF}
procedure TBufferedResponse.Write(const AContent: string);
var
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes(AContent);
  FBuffer.WriteBuffer(Bytes[0], Length(Bytes));
end;
procedure TBufferedResponse.Write(const ABuffer: TBytes);
begin
  if Length(ABuffer) > 0 then
    FBuffer.WriteBuffer(ABuffer[0], Length(ABuffer));
end;

procedure TBufferedResponse.Write(const AStream: TStream);
begin
  if (AStream <> nil) and (AStream.Size > 0) then
  begin
    AStream.Position := 0;
    FBuffer.CopyFrom(AStream, AStream.Size);
  end;
end;

procedure TBufferedResponse.SendJsonUtf8(const AUtf8Json: RawByteString);
begin
  SetContentType('application/json; charset=utf-8');
  if Length(AUtf8Json) > 0 then
    FBuffer.WriteBuffer(AUtf8Json[1], Length(AUtf8Json));
end;

procedure TBufferedResponse.SendJsonUtf8(const ABuffer: TBytes);
begin
  SetContentType('application/json; charset=utf-8');
  if Length(ABuffer) > 0 then
    FBuffer.WriteBuffer(ABuffer[0], Length(ABuffer));
end;

function TBufferedResponse.GetOutputStream: TStream;
begin
  SetContentType('application/json; charset=utf-8');
  Result := FBuffer;
end;


function CompressionOptions: TCompressionBuilder;
begin
  Result := TCompressionBuilder.Create;
end;

{ TCompressionOptions }

class function TCompressionOptions.Create: TCompressionOptions;
begin
  Result.EnableForHttps := False; // Security default (mitigate BREACH attack)
  Result.MinimumResponseBodySize := 1024; // Default 1KB
  Result.MimeTypes := [
    'text/html',
    'text/css',
    'text/plain',
    'application/javascript',
    'application/json',
    'application/xml',
    'text/xml',
    'image/svg+xml'
  ];
end;

function TCompressionOptions.IsMimeTypeCompressible(const AMimeType: string): Boolean;
var
  Mime: string;
  Item: string;
begin
  if Length(MimeTypes) = 0 then
    Exit(True);

  Mime := AMimeType.ToLower;
  for Item in MimeTypes do
  begin
    if (Item = '*') or (Pos(Item.ToLower, Mime) > 0) then
      Exit(True);
  end;
  Result := False;
end;

{ TCompressionBuilder }

class function TCompressionBuilder.Create: TCompressionBuilder;
begin
  Result.FOptions := TCompressionOptions.Create;
  Result.FInitialized := True;
end;

procedure TCompressionBuilder.EnsureInitialized;
begin
  if not FInitialized then
  begin
    FOptions := TCompressionOptions.Create;
    FInitialized := True;
  end;
end;

function TCompressionBuilder.EnableForHttps(AValue: Boolean): TCompressionBuilder;
begin
  EnsureInitialized;
  FOptions.EnableForHttps := AValue;
  Result := Self;
end;

function TCompressionBuilder.MinimumSize(ASize: Int64): TCompressionBuilder;
begin
  EnsureInitialized;
  FOptions.MinimumResponseBodySize := ASize;
  Result := Self;
end;

function TCompressionBuilder.MimeTypes(const AMimeTypes: TArray<string>): TCompressionBuilder;
begin
  EnsureInitialized;
  FOptions.MimeTypes := AMimeTypes;
  Result := Self;
end;

function TCompressionBuilder.Build: TCompressionOptions;
begin
  EnsureInitialized;
  Result := FOptions;
end;

class operator TCompressionBuilder.Implicit(const ABuilder: TCompressionBuilder): TCompressionOptions;
begin
  Result := ABuilder.Build;
end;

{ TCompressionMiddleware }

constructor TCompressionMiddleware.Create;
begin
  inherited Create;
  FOptions := TCompressionOptions.Create;
end;

constructor TCompressionMiddleware.Create(const AOptions: TCompressionOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

procedure TCompressionMiddleware.Invoke(
  AContext: IHttpContext;
  ANext: TRequestDelegate
);
var
  AcceptEncoding: string;
  BufferedResponse: TBufferedResponse;
  BufferedResponseIntf: IHttpResponse;
  OriginalResponse: IHttpResponse;
  CompressedStream: TMemoryStream;
  ZStream: TZCompressionStream;
  OutBuffer: TBytes;
  ContentType: string;
begin
  // HTTPS BREACH Protection check
  if ((AContext.Request.GetHeader('X-Forwarded-Proto').ToLower = 'https') or
      (AContext.Request.GetHeader('X-Forwarded-Ssl').ToLower = 'on')) and 
     (not FOptions.EnableForHttps) then
  begin
    ANext(AContext);
    Exit;
  end;

  AcceptEncoding := AContext.Request.GetHeader('Accept-Encoding').ToLower;
  
  if (Pos('gzip', AcceptEncoding) = 0) then
  begin
    ANext(AContext);
    Exit;
  end;

  OriginalResponse := AContext.Response;
  BufferedResponse := TBufferedResponse.Create(OriginalResponse);
  BufferedResponseIntf := BufferedResponse;
  try
    AContext.Response := BufferedResponseIntf;
    
    ANext(AContext);
    
    // Check minimum response size threshold and MIME type
    ContentType := BufferedResponse.ContentType;
    if (BufferedResponse.Buffer.Size >= FOptions.MinimumResponseBodySize) and
       FOptions.IsMimeTypeCompressible(ContentType) then
    begin
      CompressedStream := TMemoryStream.Create;
      try
        ZStream := TZCompressionStream.Create(
          CompressedStream,
          TZCompressionLevel.zcDefault,
          15 + 16
        ); // 15+16 = GZIP mode
        try
          BufferedResponse.Buffer.Position := 0;
          ZStream.CopyFrom(
            BufferedResponse.Buffer,
            BufferedResponse.Buffer.Size
          );
        finally
          ZStream.Free;
        end;

        OriginalResponse.AddHeader('Content-Encoding', 'gzip');
        OriginalResponse.SetContentLength(CompressedStream.Size);
        
        CompressedStream.Position := 0;
        OutBuffer := nil;
        SetLength(OutBuffer, CompressedStream.Size);
        CompressedStream.ReadBuffer(OutBuffer[0], CompressedStream.Size);
        OriginalResponse.Write(OutBuffer);
      finally
        CompressedStream.Free;
      end;
    end
    else if BufferedResponse.Buffer.Size > 0 then
    begin
      // Write uncompressed buffer directly
      BufferedResponse.Buffer.Position := 0;
      SetLength(OutBuffer, BufferedResponse.Buffer.Size);
      BufferedResponse.Buffer.ReadBuffer(OutBuffer[0], BufferedResponse.Buffer.Size);
      OriginalResponse.Write(OutBuffer);
    end;
  finally
    AContext.Response := OriginalResponse;
    BufferedResponseIntf := nil;
  end;
end;

end.
