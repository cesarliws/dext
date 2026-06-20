unit Dext.Web.Middleware.Compression;

interface

uses
  System.Classes,
  System.Math,
  System.Rtti,
  System.SysUtils,
  System.ZLib,
  Dext.Web.Interfaces, Dext.Web.Builder, Dext.Collections.Dict;

type
  TCompressionMiddleware = class(TMiddleware)
  public
    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate); override;
  end;

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
    function Status(AValue: Integer): IHttpResponse;
    procedure SetStatusCode(AValue: Integer);
    procedure SetContentType(const AValue: string);
    procedure SetContentLength(const AValue: Int64);
    procedure Flush;
    procedure Write(const AContent: string); overload;
    procedure Write(const ABuffer: TBytes); overload;
    procedure Write(const AStream: TStream); overload;
    procedure Json(const AJson: string); overload;
    procedure Json(const AValue: TValue); overload;
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

{ TCompressionMiddleware }

procedure TCompressionMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  AcceptEncoding: string;
  BufferedResponse: TBufferedResponse;
  OriginalResponse: IHttpResponse;
  CompressedStream: TMemoryStream;
  ZStream: TZCompressionStream;
  OutBuffer: TBytes;
begin
  AcceptEncoding := AContext.Request.GetHeader('Accept-Encoding').ToLower;
  
  if (Pos('gzip', AcceptEncoding) = 0) then
  begin
    ANext(AContext);
    Exit;
  end;

  OriginalResponse := AContext.Response;
  BufferedResponse := TBufferedResponse.Create(OriginalResponse);
  try
    AContext.Response := BufferedResponse;
    
    ANext(AContext);
    
    // Perform compression
    if BufferedResponse.Buffer.Size > 0 then
    begin
      CompressedStream := TMemoryStream.Create;
      try
        ZStream := TZCompressionStream.Create(CompressedStream, TZCompressionLevel.zcDefault, 15 + 16); // 15+16 = GZIP mode
        try
          BufferedResponse.Buffer.Position := 0;
          ZStream.CopyFrom(BufferedResponse.Buffer, BufferedResponse.Buffer.Size);
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
    end;
  finally
    AContext.Response := OriginalResponse;
    // BufferedResponse will be freed by interface refcount if we are careful, 
    // but here it's a local object. TBufferedResponse is TInterfacedObject.
  end;
end;

end.
