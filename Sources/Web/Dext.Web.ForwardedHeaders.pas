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
{  Author:  Cesar Romero & Antigravity                                      }
{  Created: 2026-08-10                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Web.ForwardedHeaders;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  Dext.Collections,
  Dext.Web.Interfaces;

type
  /// <summary>
  ///   Flags indicating which forwarded headers to process.
  /// </summary>
  TForwardedHeaderFlag = (fhXForwardedFor, fhXForwardedProto, fhXForwardedHost);
  TForwardedHeaderFlags = set of TForwardedHeaderFlag;

  /// <summary>
  ///   Options for configuring the Forwarded Headers middleware. Default is Zero Trust (empty lists).
  /// </summary>
  TForwardedHeadersOptions = class
  private
    FKnownProxies: IList<string>;
    FKnownNetworks: IList<string>;
    FForwardedHeaders: TForwardedHeaderFlags;
    FForwardLimit: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    property KnownProxies: IList<string> read FKnownProxies;
    property KnownNetworks: IList<string> read FKnownNetworks;
    property ForwardedHeaders: TForwardedHeaderFlags read FForwardedHeaders write FForwardedHeaders;
    property ForwardLimit: Integer read FForwardLimit write FForwardLimit;
  end;

  /// <summary>
  ///   Fluent builder for TForwardedHeadersOptions.
  /// </summary>
  TForwardedHeadersBuilder = record
  private
    FOptions: TForwardedHeadersOptions;
    procedure EnsureOptions;
  public
    class function Create: TForwardedHeadersBuilder; static;
    function KnownProxy(const AProxy: string): TForwardedHeadersBuilder;
    function KnownProxies(const AProxies: array of string): TForwardedHeadersBuilder;
    function KnownNetwork(const ACidr: string): TForwardedHeadersBuilder;
    function KnownNetworks(const ACidrs: array of string): TForwardedHeadersBuilder;
    function ForwardedHeaders(const AFlags: TForwardedHeaderFlags): TForwardedHeadersBuilder;
    function ForwardLimit(const ALimit: Integer): TForwardedHeadersBuilder;
    function Build: TForwardedHeadersOptions;
    class operator Implicit(const ABuilder: TForwardedHeadersBuilder): TForwardedHeadersOptions;
  end;

  /// <summary>
  ///   Extension methods for adding Forwarded Headers middleware to the application pipeline.
  /// </summary>
  TApplicationBuilderForwardedHeadersExtensions = class
  public
    class function UseForwardedHeaders(const ABuilder: IApplicationBuilder): IApplicationBuilder; overload; static;
    class function UseForwardedHeaders(const ABuilder: IApplicationBuilder; const AOptions: TForwardedHeadersOptions): IApplicationBuilder; overload; static;
    class function UseForwardedHeaders(const ABuilder: IApplicationBuilder; const AForwardedBuilder: TForwardedHeadersBuilder): IApplicationBuilder; overload; static;
    class function UseForwardedHeaders(const ABuilder: IApplicationBuilder; AConfigurator: TProc<TForwardedHeadersBuilder>): IApplicationBuilder; overload; static;
  end;

  /// <summary>
  ///   Middleware to parse and apply X-Forwarded-* headers from trusted reverse proxies using official IMiddleware contract.
  /// </summary>
  TDextForwardedHeadersMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FOptions: TForwardedHeadersOptions;
    function IPv4ToCardinal(const AIPStr: string; out AIPVal: Cardinal): Boolean;
    function MatchIPv4Subnet(const AIPStr, CIDRStr: string): Boolean;
    function IsProxyTrusted(const AIP: string): Boolean;
    function SanitizeHost(const AHostHeader: string): string;
  public
    constructor Create(AOptions: TForwardedHeadersOptions = nil);
    destructor Destroy; override;

    procedure Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
  end;

function ForwardedHeadersOptions: TForwardedHeadersBuilder;

implementation

{ TForwardedHeadersOptions }

constructor TForwardedHeadersOptions.Create;
begin
  inherited Create;
  // ZERO TRUST BY DEFAULT: No proxies or networks are trusted unless explicitly configured
  FKnownProxies := TCollections.CreateList<string>;
  FKnownNetworks := TCollections.CreateList<string>;
  FForwardedHeaders := [fhXForwardedFor, fhXForwardedProto, fhXForwardedHost];
  FForwardLimit := 1;
end;

destructor TForwardedHeadersOptions.Destroy;
begin
  FKnownProxies := nil;
  FKnownNetworks := nil;
  inherited Destroy;
end;

{ TDextForwardedHeadersMiddleware }

constructor TDextForwardedHeadersMiddleware.Create(AOptions: TForwardedHeadersOptions);
begin
  inherited Create;
  if AOptions <> nil then
    FOptions := AOptions
  else
    FOptions := TForwardedHeadersOptions.Create;
end;

destructor TDextForwardedHeadersMiddleware.Destroy;
begin
  FOptions.Free;
  inherited Destroy;
end;

function TDextForwardedHeadersMiddleware.IPv4ToCardinal(const AIPStr: string; out AIPVal: Cardinal): Boolean;
var
  Parts: TArray<string>;
  v1, v2, v3, v4: Integer;
begin
  Result := False;
  AIPVal := 0;
  Parts := AIPStr.Split(['.']);
  if Length(Parts) <> 4 then
    Exit;

  if TryStrToInt(Parts[0], v1) and (v1 >= 0) and (v1 <= 255) and
     TryStrToInt(Parts[1], v2) and (v2 >= 0) and (v2 <= 255) and
     TryStrToInt(Parts[2], v3) and (v3 >= 0) and (v3 <= 255) and
     TryStrToInt(Parts[3], v4) and (v4 >= 0) and (v4 <= 255) then
  begin
    AIPVal := (Cardinal(v1) shl 24) or (Cardinal(v2) shl 16) or (Cardinal(v3) shl 8) or Cardinal(v4);
    Result := True;
  end;
end;

function TDextForwardedHeadersMiddleware.MatchIPv4Subnet(const AIPStr, CIDRStr: string): Boolean;
var
  SlashPos: Integer;
  BaseIPStr, MaskBitsStr: string;
  IPVal, BaseVal, MaskVal: Cardinal;
  MaskBits: Integer;
begin
  SlashPos := Pos('/', CIDRStr);
  if SlashPos = 0 then
    Exit(SameText(AIPStr, CIDRStr));

  BaseIPStr := Copy(CIDRStr, 1, SlashPos - 1);
  MaskBitsStr := Copy(CIDRStr, SlashPos + 1, Length(CIDRStr));

  if not TryStrToInt(MaskBitsStr, MaskBits) or (MaskBits < 0) or (MaskBits > 32) then
    Exit(False);

  if not IPv4ToCardinal(AIPStr, IPVal) or not IPv4ToCardinal(BaseIPStr, BaseVal) then
    Exit(False);

  if MaskBits = 0 then
    MaskVal := 0
  else
    MaskVal := $FFFFFFFF shl (32 - MaskBits);

  Result := (IPVal and MaskVal) = (BaseVal and MaskVal);
end;

function TDextForwardedHeadersMiddleware.IsProxyTrusted(const AIP: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  if FOptions = nil then
    Exit;

  if (FOptions.KnownProxies <> nil) and (FOptions.KnownProxies.Count > 0) then
  begin
    for i := 0 to FOptions.KnownProxies.Count - 1 do
    begin
      if SameText(AIP, FOptions.KnownProxies[i]) then
        Exit(True);
    end;
  end;

  if (FOptions.KnownNetworks <> nil) and (FOptions.KnownNetworks.Count > 0) then
  begin
    for i := 0 to FOptions.KnownNetworks.Count - 1 do
    begin
      if MatchIPv4Subnet(AIP, FOptions.KnownNetworks[i]) then
        Exit(True);
    end;
  end;
end;

function TDextForwardedHeadersMiddleware.SanitizeHost(const AHostHeader: string): string;
var
  TrimmedHost: string;
  ColonPos: Integer;
  ch: Char;
begin
  TrimmedHost := Trim(AHostHeader);
  TrimmedHost := StringReplace(TrimmedHost, #13, '', [rfReplaceAll]);
  TrimmedHost := StringReplace(TrimmedHost, #10, '', [rfReplaceAll]);

  ColonPos := Pos('/', TrimmedHost);
  if ColonPos > 0 then
    TrimmedHost := Copy(TrimmedHost, 1, ColonPos - 1);

  for ch in TrimmedHost do
  begin
    if not (CharInSet(ch, ['a'..'z', 'A'..'Z', '0'..'9', '.', '-', ':', '[', ']'])) then
      Exit('');
  end;

  Result := TrimmedHost;
end;

procedure TDextForwardedHeadersMiddleware.Invoke(AContext: IHttpContext; ANext: TRequestDelegate);
var
  Req: IHttpRequest;
  ForwardedFeature: IForwardedHeadersFeature;
  RemoteIP: string;
  ForwardedFor, ForwardedProto, ForwardedHost: string;
  IPParts: TArray<string>;
  TargetClientIP: string;
  SanitizedHostStr: string;
  i, ProcessedCount: Integer;
begin
  if Assigned(AContext) and Assigned(AContext.Request) then
  begin
    Req := AContext.Request;
    if not Supports(Req, IForwardedHeadersFeature, ForwardedFeature) then
    begin
      if Assigned(ANext) then
        ANext(AContext);
      Exit;
    end;

    RemoteIP := Req.RemoteIpAddress;

    if IsProxyTrusted(RemoteIP) then
    begin
      if (fhXForwardedFor in FOptions.ForwardedHeaders) and Assigned(Req.Headers) and Req.Headers.TryGetValue('X-Forwarded-For', ForwardedFor) then
      begin
        IPParts := ForwardedFor.Split([',']);
        ProcessedCount := 0;
        TargetClientIP := '';

        for i := High(IPParts) downto Low(IPParts) do
        begin
          TargetClientIP := Trim(IPParts[i]);
          Inc(ProcessedCount);

          if (FOptions.ForwardLimit > 0) and (ProcessedCount >= FOptions.ForwardLimit) then
            Break;
        end;

        if not TargetClientIP.IsEmpty then
          ForwardedFeature.SetRemoteIpAddress(TargetClientIP);
      end;

      if (fhXForwardedProto in FOptions.ForwardedHeaders) and Assigned(Req.Headers) and Req.Headers.TryGetValue('X-Forwarded-Proto', ForwardedProto) then
      begin
        if SameText(Trim(ForwardedProto), 'https') then
          ForwardedFeature.SetIsHttps(True)
        else if SameText(Trim(ForwardedProto), 'http') then
          ForwardedFeature.SetIsHttps(False);
      end;

      if (fhXForwardedHost in FOptions.ForwardedHeaders) and Assigned(Req.Headers) and Req.Headers.TryGetValue('X-Forwarded-Host', ForwardedHost) then
      begin
        if not ForwardedHost.IsEmpty then
        begin
          SanitizedHostStr := SanitizeHost(ForwardedHost);
          if not SanitizedHostStr.IsEmpty then
            ForwardedFeature.SetHost(SanitizedHostStr);
        end;
      end;
    end;
  end;

  if Assigned(ANext) then
    ANext(AContext);
end;

{ TForwardedHeadersBuilder }

procedure TForwardedHeadersBuilder.EnsureOptions;
begin
  if FOptions = nil then
    FOptions := TForwardedHeadersOptions.Create;
end;

class function TForwardedHeadersBuilder.Create: TForwardedHeadersBuilder;
begin
  Result := Default(TForwardedHeadersBuilder);
  Result.EnsureOptions;
end;

function TForwardedHeadersBuilder.KnownProxy(const AProxy: string): TForwardedHeadersBuilder;
begin
  EnsureOptions;
  if not AProxy.IsEmpty then
    FOptions.KnownProxies.Add(AProxy);
  Result := Self;
end;

function TForwardedHeadersBuilder.KnownProxies(const AProxies: array of string): TForwardedHeadersBuilder;
var
  Proxy: string;
begin
  EnsureOptions;
  for Proxy in AProxies do
    if not Proxy.IsEmpty then
      FOptions.KnownProxies.Add(Proxy);
  Result := Self;
end;

function TForwardedHeadersBuilder.KnownNetwork(const ACidr: string): TForwardedHeadersBuilder;
begin
  EnsureOptions;
  if not ACidr.IsEmpty then
    FOptions.KnownNetworks.Add(ACidr);
  Result := Self;
end;

function TForwardedHeadersBuilder.KnownNetworks(const ACidrs: array of string): TForwardedHeadersBuilder;
var
  Cidr: string;
begin
  EnsureOptions;
  for Cidr in ACidrs do
    if not Cidr.IsEmpty then
      FOptions.KnownNetworks.Add(Cidr);
  Result := Self;
end;

function TForwardedHeadersBuilder.ForwardedHeaders(const AFlags: TForwardedHeaderFlags): TForwardedHeadersBuilder;
begin
  EnsureOptions;
  FOptions.ForwardedHeaders := AFlags;
  Result := Self;
end;

function TForwardedHeadersBuilder.ForwardLimit(const ALimit: Integer): TForwardedHeadersBuilder;
begin
  EnsureOptions;
  FOptions.ForwardLimit := ALimit;
  Result := Self;
end;

function TForwardedHeadersBuilder.Build: TForwardedHeadersOptions;
begin
  EnsureOptions;
  Result := FOptions;
end;

class operator TForwardedHeadersBuilder.Implicit(const ABuilder: TForwardedHeadersBuilder): TForwardedHeadersOptions;
begin
  Result := ABuilder.Build;
end;

function ForwardedHeadersOptions: TForwardedHeadersBuilder;
begin
  Result := TForwardedHeadersBuilder.Create;
end;

{ TApplicationBuilderForwardedHeadersExtensions }

class function TApplicationBuilderForwardedHeadersExtensions.UseForwardedHeaders(
  const ABuilder: IApplicationBuilder): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TDextForwardedHeadersMiddleware.Create(TForwardedHeadersOptions.Create));
end;

class function TApplicationBuilderForwardedHeadersExtensions.UseForwardedHeaders(
  const ABuilder: IApplicationBuilder; const AOptions: TForwardedHeadersOptions): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TDextForwardedHeadersMiddleware.Create(AOptions));
end;

class function TApplicationBuilderForwardedHeadersExtensions.UseForwardedHeaders(
  const ABuilder: IApplicationBuilder; const AForwardedBuilder: TForwardedHeadersBuilder): IApplicationBuilder;
begin
  Result := ABuilder.UseMiddleware(TDextForwardedHeadersMiddleware.Create(AForwardedBuilder.Build));
end;

class function TApplicationBuilderForwardedHeadersExtensions.UseForwardedHeaders(
  const ABuilder: IApplicationBuilder; AConfigurator: TProc<TForwardedHeadersBuilder>): IApplicationBuilder;
var
  Builder: TForwardedHeadersBuilder;
begin
  Builder := TForwardedHeadersBuilder.Create;
  if Assigned(AConfigurator) then
    AConfigurator(Builder);
  Result := ABuilder.UseMiddleware(TDextForwardedHeadersMiddleware.Create(Builder.Build));
end;

end.
