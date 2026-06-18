{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2026 Cesar Romero & Dext Contributors             }
{                                                                           }
{***************************************************************************}
unit Dext.Logging.Sinks.APM;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  Dext.Collections,
  Dext.Logging,
  Dext.Logging.Async,
  Dext.Logging.RingBuffer,
  Dext.Logging.Sinks,
  Dext.Types.UUID,
  Dext.Net.RestClient,
  Dext.Threading.Async;

type
  /// <summary>
  ///   Base class for asynchronous batch-forwarding telemetry sinks.
  /// </summary>
  TBatchingTelemetrySink = class(TInterfacedObject, ILogSink)
  private
    FQueue: IList<TLogEntry>;
    FLock: TObject;
    FBatchSize: Integer;
    FFlushIntervalMs: Integer;
    FLastFlushTime: TDateTime;
    FActiveTask: IAsyncTask;
    procedure FlushInternal;
  protected
    procedure Emit(const Entry: TLogEntry); virtual;
    procedure Flush; virtual;
    procedure SendBatch(const Batch: TArray<TLogEntry>); virtual; abstract;
  public
    constructor Create(const Options: TBatchOptions);
    destructor Destroy; override;
  end;

  /// <summary>
  ///   Logger Sink sending logs to Seq via raw CLEF json lines.
  /// </summary>
  TSeqLogSink = class(TBatchingTelemetrySink)
  private
    FUrl: string;
    FApiKey: string;
  protected
    procedure SendBatch(const Batch: TArray<TLogEntry>); override;
  public
    constructor Create(const AUrl, AApiKey: string; const AOptions: TBatchOptions);
  end;

  /// <summary>
  ///   Logger Sink sending telemetry logs and traces to OpenTelemetry Collector / SigNoz / Datadog.
  /// </summary>
  TOTLPTelemetrySink = class(TBatchingTelemetrySink)
  private
    FUrl: string;
    FServiceName: string;
    FEnvironment: string;
    FExportLogs: Boolean;
    FExportTraces: Boolean;
  protected
    function BuildLogsPayload(const Batch: TArray<TLogEntry>): string;
    procedure SendBatch(const Batch: TArray<TLogEntry>); override;
  public
    constructor Create(const AUrl: string; const AServiceName, AEnvironment: string;
      AExportLogs, AExportTraces: Boolean; const AOptions: TBatchOptions);
  end;

implementation

{ TBatchingTelemetrySink }

constructor TBatchingTelemetrySink.Create(const Options: TBatchOptions);
begin
  inherited Create;
  FQueue := TCollections.CreateList<TLogEntry>;
  FLock := TObject.Create;
  FBatchSize := Options.GetBatchSize;
  if FBatchSize <= 0 then
    FBatchSize := 100;
  FFlushIntervalMs := Options.GetFlushIntervalMs;
  if FFlushIntervalMs <= 0 then
    FFlushIntervalMs := 5000;
  FLastFlushTime := Now;
end;

destructor TBatchingTelemetrySink.Destroy;
begin
  Flush;
  FLock.Free;
  inherited;
end;

procedure TBatchingTelemetrySink.Emit(const Entry: TLogEntry);
var
  TriggerFlush: Boolean;
begin
  TriggerFlush := False;
  TMonitor.Enter(FLock);
  try
    FQueue.Add(Entry);
    if (FQueue.Count >= FBatchSize) or (MilliSecondsBetween(Now, FLastFlushTime) >= FFlushIntervalMs) then
      TriggerFlush := True;
  finally
    TMonitor.Exit(FLock);
  end;

  if TriggerFlush then
    Flush;
end;

procedure TBatchingTelemetrySink.Flush;
var
  LTask: IAsyncTask;
begin
  TMonitor.Enter(FLock);
  try
    FlushInternal;
    LTask := FActiveTask;
  finally
    TMonitor.Exit(FLock);
  end;

  if LTask <> nil then
    LTask.Wait;
end;

procedure TBatchingTelemetrySink.FlushInternal;
var
  BatchCopy: TArray<TLogEntry>;
begin
  if FQueue.Count = 0 then Exit;
  BatchCopy := FQueue.ToArray;
  FQueue.Clear;
  FLastFlushTime := Now;

  FActiveTask := TAsyncTask.Run(
    procedure
    begin
      try
        try
          SendBatch(BatchCopy);
        except
          // Protect pipeline from logging service crashes
        end;
      finally
        TMonitor.Enter(FLock);
        try
          FActiveTask := nil;
        finally
          TMonitor.Exit(FLock);
        end;
      end;
    end
  ).Start;
end;

{ TSeqLogSink }

constructor TSeqLogSink.Create(const AUrl, AApiKey: string; const AOptions: TBatchOptions);
begin
  inherited Create(AOptions);
  FUrl := AUrl;
  FApiKey := AApiKey;
end;

procedure TSeqLogSink.SendBatch(const Batch: TArray<TLogEntry>);
var
  SB: TStringBuilder;
  Entry: TLogEntry;
  Payload: string;
  Client: TRestClient;
  LvlStr: string;
  Stream: TStringStream;
begin
  if Length(Batch) = 0 then Exit;

  SB := TStringBuilder.Create;
  try
    for Entry in Batch do
    begin
      case Entry.Level of
        TLogLevel.Trace: LvlStr := 'Verbose';
        TLogLevel.Debug: LvlStr := 'Debug';
        TLogLevel.Information: LvlStr := 'Information';
        TLogLevel.Warning: LvlStr := 'Warning';
        TLogLevel.Error: LvlStr := 'Error';
        TLogLevel.Critical: LvlStr := 'Fatal';
        else LvlStr := 'Information';
      end;

      SB.Append('{"@t":"').Append(DateToISO8601(TTimeZone.Local.ToUniversalTime(Entry.TimeStamp), True)).Append('",');
      SB.Append('"@l":"').Append(LvlStr).Append('",');
      SB.Append('"@m":"').Append(Entry.FormattedMessage.Replace('\', '\\').Replace('"', '\"').Replace(#13, '\r').Replace(#10, '\n')).Append('"');
      if not Entry.TraceId.IsEmpty then
        SB.Append(',"TraceId":"').Append(Entry.TraceId.ToString).Append('"');
      if not Entry.SpanId.IsEmpty then
        SB.Append(',"SpanId":"').Append(Entry.SpanId.ToString).Append('"');
      SB.Append('}').Append(#10);
    end;
    Payload := SB.ToString;
  finally
    SB.Free;
  end;

  Client := TRestClient.Create(FUrl);
  if FApiKey <> '' then
    Client.Header('X-Seq-ApiKey', FApiKey);
  Client.Header('Content-Type', 'application/vnd.serilog.clef');
  Stream := TStringStream.Create(Payload, TEncoding.UTF8);
  try
    try
      Client.Post('/api/events/raw', Stream).Await;
    except
      // swallow outbound http errors to prevent telemetry sink failure
    end;
  finally
    Stream.Free;
  end;
end;

{ TOTLPTelemetrySink }

constructor TOTLPTelemetrySink.Create(const AUrl: string; const AServiceName, AEnvironment: string;
  AExportLogs, AExportTraces: Boolean; const AOptions: TBatchOptions);
begin
  inherited Create(AOptions);
  FUrl := AUrl;
  FServiceName := AServiceName;
  FEnvironment := AEnvironment;
  FExportLogs := AExportLogs;
  FExportTraces := AExportTraces;
end;

function TOTLPTelemetrySink.BuildLogsPayload(const Batch: TArray<TLogEntry>): string;
var
  SB: TStringBuilder;
  I: Integer;
  Entry: TLogEntry;
  LUnixTimeNano: Int64;
  SevNum: Integer;
  SevText: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('{');
    SB.Append('"resourceLogs": [{');
    SB.Append('"resource": {');
    SB.Append('"attributes": [');
    SB.Append('{"key": "service.name", "value": {"stringValue": "').Append(FServiceName).Append('"}},');
    SB.Append('{"key": "deployment.environment", "value": {"stringValue": "').Append(FEnvironment).Append('"}}');
    SB.Append(']');
    SB.Append('},');
    SB.Append('"scopeLogs": [{');
    SB.Append('"scope": {"name": "dext.logger"},');
    SB.Append('"logRecords": [');

    for I := 0 to Length(Batch) - 1 do
    begin
      Entry := Batch[I];
      if I > 0 then SB.Append(',');

      LUnixTimeNano := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Entry.TimeStamp), False) * 1000000000 +
                       MilliSecondOf(Entry.TimeStamp) * 1000000;

      case Entry.Level of
        TLogLevel.Trace: begin SevNum := 1; SevText := 'Trace'; end;
        TLogLevel.Debug: begin SevNum := 5; SevText := 'Debug'; end;
        TLogLevel.Information: begin SevNum := 9; SevText := 'Info'; end;
        TLogLevel.Warning: begin SevNum := 13; SevText := 'Warn'; end;
        TLogLevel.Error: begin SevNum := 17; SevText := 'Error'; end;
        TLogLevel.Critical: begin SevNum := 21; SevText := 'Fatal'; end;
        else begin SevNum := 9; SevText := 'Info'; end;
      end;

      SB.Append('{');
      SB.Append('"timeUnixNano": "').Append(IntToStr(LUnixTimeNano)).Append('",');
      SB.Append('"severityNumber": ').Append(SevNum).Append(',');
      SB.Append('"severityText": "').Append(SevText).Append('",');
      SB.Append('"body": {"stringValue": "').Append(Entry.FormattedMessage.Replace('\', '\\').Replace('"', '\"').Replace(#13, '\r').Replace(#10, '\n')).Append('"}');
      
      if not Entry.TraceId.IsEmpty then
        SB.Append(',"traceId": "').Append(Entry.TraceId.ToString.Replace('-', '')).Append('"');
      if not Entry.SpanId.IsEmpty then
        SB.Append(',"spanId": "').Append(Entry.SpanId.ToString.Replace('-', '').Substring(0, 16)).Append('"');

      SB.Append('}');
    end;

    SB.Append(']');
    SB.Append('}]');
    SB.Append('}]');
    SB.Append('}');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure TOTLPTelemetrySink.SendBatch(const Batch: TArray<TLogEntry>);
var
  Payload: string;
  Client: TRestClient;
  Stream: TStringStream;
begin
  if Length(Batch) = 0 then Exit;

  if FExportLogs then
  begin
    Payload := BuildLogsPayload(Batch);
    Client := TRestClient.Create(FUrl);
    Client.ContentTypeJson;
    Stream := TStringStream.Create(Payload, TEncoding.UTF8);
    try
      try
        Client.Post('/v1/logs', Stream).Await;
      except
        // swallow outbound http errors to prevent telemetry sink failure
      end;
    finally
      Stream.Free;
    end;
  end;
end;

function CreateSeqSink(const AUrl, AApiKey: string; const AOptions: TBatchOptions): ILogSink;
begin
  Result := TSeqLogSink.Create(AUrl, AApiKey, AOptions);
end;

function CreateOTLPSink(const AUrl, AServiceName, AEnvironment: string; AExportLogs, AExportTraces: Boolean; const AOptions: TBatchOptions): ILogSink;
begin
  Result := TOTLPTelemetrySink.Create(AUrl, AServiceName, AEnvironment, AExportLogs, AExportTraces, AOptions);
end;

var
  GSeqCreator: TSeqSinkCreator;
  GOTLPCreator: TOTLPSinkCreator;

initialization
  GSeqCreator := CreateSeqSink;
  TTelemetrySinkRegistry.RegisterSeqCreator(GSeqCreator);

  GOTLPCreator := CreateOTLPSink;
  TTelemetrySinkRegistry.RegisterOTLPCreator(GOTLPCreator);

end.
