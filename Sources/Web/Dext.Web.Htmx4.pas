unit Dext.Web.Htmx4;

interface

uses
  System.SysUtils,
  Dext.Web.Interfaces;

type
  /// <summary>Describes how HTMX 4 intends to consume an HTTP response.</summary>
  THtmx4RequestType = (hrtNone, hrtPartial, hrtFull);

  /// <summary>
  ///   Read-only view of the HTMX 4 request headers carried by an IHttpRequest.
  /// </summary>
  THtmx4Request = record
  private
    FRequest: IHttpRequest;
    function GetHeader(const AName: string): string;
    function GetIsHtmx: Boolean;
    function GetIsPartial: Boolean;
    function GetIsFull: Boolean;
    function GetRequestType: THtmx4RequestType;
    function GetSource: string;
    function GetTarget: string;
    function GetCurrentUrl: string;
    function GetIsBoosted: Boolean;
    function GetIsHistoryRestore: Boolean;
  public
    constructor Create(const ARequest: IHttpRequest);

    property IsHtmx: Boolean read GetIsHtmx;
    property IsPartial: Boolean read GetIsPartial;
    property IsFull: Boolean read GetIsFull;
    property RequestType: THtmx4RequestType read GetRequestType;
    property Source: string read GetSource;
    property Target: string read GetTarget;
    property CurrentUrl: string read GetCurrentUrl;
    property IsBoosted: Boolean read GetIsBoosted;
    property IsHistoryRestore: Boolean read GetIsHistoryRestore;
  end;

  /// <summary>Builds one or more HTMX 4 &lt;hx-partial&gt; response elements.</summary>
  THtmx4Partials = class
  private
    FBuilder: TStringBuilder;
    FHasPartials: Boolean;
    class function EscapeAttribute(const AValue: string): string; static;
    procedure AppendPartial(const ATargetAttribute, ATarget, AHtml, ASwap: string);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Adds a partial addressed by an hx-target CSS selector.</summary>
    function Target(const ASelector, AHtml: string;
      const ASwap: string = ''): THtmx4Partials;
    /// <summary>Adds a partial addressed by its id shorthand.</summary>
    function Id(const AId, AHtml: string;
      const ASwap: string = ''): THtmx4Partials;
    /// <summary>Returns the generated HTML without changing ownership.</summary>
    function ToHtml: string;
    /// <summary>Returns the generated partial response as Dext's standard HTML result.</summary>
    function AsResult(AStatusCode: Integer = 200): IResult;
  end;

  /// <summary>Factory for HTMX 4 request inspection and multi-target responses.</summary>
  Htmx4 = class
  public
    class function Request(const AContext: IHttpContext): THtmx4Request; static;
    class function Partials: THtmx4Partials; static;
  end;

implementation

uses
  Dext.Web.Results;

{ THtmx4Request }

constructor THtmx4Request.Create(const ARequest: IHttpRequest);
begin
  FRequest := ARequest;
end;

function THtmx4Request.GetHeader(const AName: string): string;
begin
  if FRequest = nil then
    Exit('');

  if FRequest.Headers = nil then
    Exit('');

  Result := FRequest.Headers.GetValue(AName);
end;

function THtmx4Request.GetIsHtmx: Boolean;
begin
  Result := SameText(GetHeader('HX-Request'), 'true');
end;

function THtmx4Request.GetRequestType: THtmx4RequestType;
var
  RequestTypeHeader: string;
begin
  Result := hrtNone;
  if not IsHtmx then
    Exit;

  RequestTypeHeader := GetHeader('HX-Request-Type');
  if SameText(RequestTypeHeader, 'partial') then
    Result := hrtPartial
  else if SameText(RequestTypeHeader, 'full') then
    Result := hrtFull;
end;

function THtmx4Request.GetIsPartial: Boolean;
begin
  Result := RequestType = hrtPartial;
end;

function THtmx4Request.GetIsFull: Boolean;
begin
  Result := RequestType = hrtFull;
end;

function THtmx4Request.GetSource: string;
begin
  Result := GetHeader('HX-Source');
end;

function THtmx4Request.GetTarget: string;
begin
  Result := GetHeader('HX-Target');
end;

function THtmx4Request.GetCurrentUrl: string;
begin
  Result := GetHeader('HX-Current-URL');
end;

function THtmx4Request.GetIsBoosted: Boolean;
begin
  Result := SameText(GetHeader('HX-Boosted'), 'true');
end;

function THtmx4Request.GetIsHistoryRestore: Boolean;
begin
  Result := SameText(GetHeader('HX-History-Restore-Request'), 'true');
end;

{ THtmx4Partials }

constructor THtmx4Partials.Create;
begin
  inherited Create;
  FBuilder := TStringBuilder.Create;
end;

destructor THtmx4Partials.Destroy;
begin
  FBuilder.Free;
  inherited Destroy;
end;

class function THtmx4Partials.EscapeAttribute(const AValue: string): string;
begin
  Result := AValue.Replace('&', '&amp;')
    .Replace(Char(34), '&quot;')
    .Replace('<', '&lt;')
    .Replace('>', '&gt;');
end;

procedure THtmx4Partials.AppendPartial(const ATargetAttribute, ATarget, AHtml,
  ASwap: string);
begin
  if ATarget = '' then
    raise Exception.Create('An HTMX partial target cannot be empty.');

  if FHasPartials then
    FBuilder.Append(sLineBreak);

  FBuilder.Append('<hx-partial ')
    .Append(ATargetAttribute)
    .Append('=')
    .Append(Char(34))
    .Append(EscapeAttribute(ATarget))
    .Append(Char(34));

  if ASwap <> '' then
    FBuilder.Append(' hx-swap=')
      .Append(Char(34))
      .Append(EscapeAttribute(ASwap))
      .Append(Char(34));

  FBuilder.Append('>')
    .Append(AHtml)
    .Append('</hx-partial>');
  FHasPartials := True;
end;

function THtmx4Partials.Target(const ASelector, AHtml, ASwap: string): THtmx4Partials;
begin
  AppendPartial('hx-target', ASelector, AHtml, ASwap);
  Result := Self;
end;

function THtmx4Partials.Id(const AId, AHtml, ASwap: string): THtmx4Partials;
begin
  AppendPartial('id', AId, AHtml, ASwap);
  Result := Self;
end;

function THtmx4Partials.ToHtml: string;
begin
  Result := FBuilder.ToString;
end;

function THtmx4Partials.AsResult(AStatusCode: Integer): IResult;
begin
  Result := Results.Html(ToHtml, AStatusCode);
end;

{ Htmx4 }

class function Htmx4.Request(const AContext: IHttpContext): THtmx4Request;
begin
  if AContext = nil then
    Exit(THtmx4Request.Create(nil));

  Result := THtmx4Request.Create(AContext.Request);
end;

class function Htmx4.Partials: THtmx4Partials;
begin
  Result := THtmx4Partials.Create;
end;

end.
