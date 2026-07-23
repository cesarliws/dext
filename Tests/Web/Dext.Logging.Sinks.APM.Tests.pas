unit Dext.Logging.Sinks.APM.Tests;

{$I Dext.inc}

interface

uses
  Dext.Testing.Attributes,
  Dext.Assertions,
  Dext.Logging,
  Dext.Logging.Async,
  Dext.Logging.RingBuffer,
  Dext.Logging.Sinks,
  Dext.Logging.Sinks.APM,
  Dext.Types.UUID,
  System.SysUtils,
  System.Classes,
  Dext.Json,
  Dext.Json.Types,
  System.DateUtils,
  Dext.WebHost,
  Dext.Web.Interfaces,
  System.SyncObjs;

type
  [TestFixture('APM Log Sinks and Telemetry Pipeline Tests')]
  TAPMSinksTests = class
  private
    type
      TMockTelemetrySink = class(TBatchingTelemetrySink)
      private
        FReceivedBatches: TArray<TArray<TLogEntry>>;
        FLock: TObject;
      protected
        procedure SendBatch(const Batch: TArray<TLogEntry>); override;
      public
        constructor Create(const Options: TBatchOptions);
        destructor Destroy; override;
        property ReceivedBatches: TArray<TArray<TLogEntry>> read FReceivedBatches;
      end;
  public
    [Test('Should batch logs correctly in TBatchingTelemetrySink based on size')]
    procedure Test_Batching_Telemetry_Sink_Trigger;
    
    [Test('Should send CLEF formatted JSON lines to Seq endpoint using local mock server')]
    procedure Test_Seq_CLEF_Formatting;
    
    [Test('Should send OTLP JSON formatted logs to OTel endpoint using local mock server')]
    procedure Test_OTLP_Logs_Payload;
  end;

implementation

{ TAPMSinksTests.TMockTelemetrySink }

constructor TAPMSinksTests.TMockTelemetrySink.Create(const Options: TBatchOptions);
begin
  inherited Create(Options);
  FLock := TObject.Create;
  SetLength(FReceivedBatches, 0);
end;

destructor TAPMSinksTests.TMockTelemetrySink.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TAPMSinksTests.TMockTelemetrySink.SendBatch(const Batch: TArray<TLogEntry>);
begin
  TMonitor.Enter(FLock);
  try
    SetLength(FReceivedBatches, Length(FReceivedBatches) + 1);
    FReceivedBatches[High(FReceivedBatches)] := Batch;
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TAPMSinksTests }

procedure TAPMSinksTests.Test_Batching_Telemetry_Sink_Trigger;
var
  Sink: TMockTelemetrySink;
  Entry: TLogEntry;
  I: Integer;
begin
  Sink := TMockTelemetrySink.Create(TBatchOptions.Default.BatchSize(5).FlushInterval(10000));
  try
    // Emit 4 entries (less than 5 batch size)
    for I := 1 to 4 do
    begin
      Entry := Default(TLogEntry);
      Entry.TimeStamp := Now;
      Entry.Level := TLogLevel.Information;
      Entry.FormattedMessage := 'Log ' + IntToStr(I);
      Sink.Emit(Entry);
    end;

    // Check no batch is sent yet
    Should(Length(Sink.ReceivedBatches)).Be(0);

    // Emit the 5th entry
    Entry := Default(TLogEntry);
    Entry.TimeStamp := Now;
    Entry.Level := TLogLevel.Information;
    Entry.FormattedMessage := 'Log 5';
    Sink.Emit(Entry);

    // Give it a tiny bit of time for the async task to execute
    Sleep(250);

    // Verify batch of 5 was received
    Should(Length(Sink.ReceivedBatches)).Be(1);
    if Length(Sink.ReceivedBatches) > 0 then
      Should(Length(Sink.ReceivedBatches[0])).Be(5);
  finally
    Sink.Free;
  end;
end;

procedure TAPMSinksTests.Test_Seq_CLEF_Formatting;
var
  Builder: IWebHostBuilder;
  Host: IWebHost;
  Sink: ILogSink;
  Entry: TLogEntry;
  ReceivedPayload: string;
  Lock: TCriticalSection;
begin
  Lock := TCriticalSection.Create;
  ReceivedPayload := '';

  Builder := TWebHost.CreateDefaultBuilder
    .UseUrls('http://127.0.0.1:0');

  Builder.Configure(procedure(App: IApplicationBuilder)
    begin
      App.MapPost('/api/events/raw',
        procedure(Ctx: IHttpContext)
        var
          Stream: TStream;
          Reader: TStreamReader;
        begin
          Stream := Ctx.Request.Body;
          if Stream <> nil then
          begin
            Reader := TStreamReader.Create(Stream, TEncoding.UTF8);
            try
              Lock.Enter;
              try
                ReceivedPayload := Reader.ReadToEnd;
              finally
                Lock.Leave;
              end;
            finally
              Reader.Free;
            end;
          end;
          Ctx.Response.ContentType := 'application/json';
          Ctx.Response.Write('{"status":"ok"}');
        end
      );
    end);

  Host := Builder.Build;
  Host.Start;
  try
    // Use dynamic sink creator which delegates to registered Net APM sink
    Sink := TTelemetrySinkRegistry.CreateSeq(
      'http://localhost:' + Host.Port.ToString,
      'test-api-key',
      TBatchOptions.Default.BatchSize(1).FlushInterval(100)
    );

    Entry := Default(TLogEntry);
    Entry.TimeStamp := EncodeDateTime(2026, 6, 6, 12, 0, 0, 0);
    Entry.Level := TLogLevel.Warning;
    Entry.FormattedMessage := 'Warning message for Seq';
    Entry.TraceId := TUUID.Null;
    Entry.SpanId := TUUID.Null;

    Sink.Emit(Entry);
    Sink.Flush;

    // Allow time for async task
    Sleep(250);

    Lock.Enter;
    try
      Should(ReceivedPayload).NotBeEmpty;
      Should(ReceivedPayload).Contain('"@l":"Warning"');
      Should(ReceivedPayload).Contain('"@m":"Warning message for Seq"');
    finally
      Lock.Leave;
    end;
  finally
    Sink := nil;
    Host.Stop;
    Lock.Free;
  end;
end;

procedure TAPMSinksTests.Test_OTLP_Logs_Payload;
var
  Builder: IWebHostBuilder;
  Host: IWebHost;
  Sink: ILogSink;
  Entry: TLogEntry;
  ReceivedPayload: string;
  Lock: TCriticalSection;
  JO: IDextJsonObject;
  ResourceLogs, ScopeLogs, LogRecords: IDextJsonArray;
  Resource, Scope, LogRec, Body: IDextJsonObject;
begin
  Lock := TCriticalSection.Create;
  ReceivedPayload := '';

  Builder := TWebHost.CreateDefaultBuilder
    .UseUrls('http://127.0.0.1:0');

  Builder.Configure(procedure(App: IApplicationBuilder)
    begin
      App.MapPost('/v1/logs',
        procedure(Ctx: IHttpContext)
        var
          Stream: TStream;
          Reader: TStreamReader;
        begin
          Stream := Ctx.Request.Body;
          if Stream <> nil then
          begin
            Reader := TStreamReader.Create(Stream, TEncoding.UTF8);
            try
              Lock.Enter;
              try
                ReceivedPayload := Reader.ReadToEnd;
              finally
                Lock.Leave;
              end;
            finally
              Reader.Free;
            end;
          end;
          Ctx.Response.ContentType := 'application/json';
          Ctx.Response.Write('{"status":"ok"}');
        end
      );
    end);

  Host := Builder.Build;
  Host.Start;
  try
    Sink := TTelemetrySinkRegistry.CreateOTLP(
      'http://localhost:' + Host.Port.ToString,
      'test-service',
      'prod',
      True, // Export Logs
      False, // Export Traces
      TBatchOptions.Default.BatchSize(1).FlushInterval(100)
    );

    Entry := Default(TLogEntry);
    Entry.TimeStamp := EncodeDateTime(2026, 6, 6, 12, 0, 0, 0);
    Entry.Level := TLogLevel.Information;
    Entry.FormattedMessage := 'Test Message OTel';
    Entry.TraceId := TUUID.Null;
    Entry.SpanId := TUUID.Null;

    Sink.Emit(Entry);
    Sink.Flush;

    // Allow time for async task
    Sleep(250);

    Lock.Enter;
    try
      Should(ReceivedPayload).NotBeEmpty;
      
      JO := TDextJson.Provider.Parse(ReceivedPayload) as IDextJsonObject;
      Should(JO).NotBeNil;
      ResourceLogs := JO.GetArray('resourceLogs');
      Should(ResourceLogs).NotBeNil;
      Should(ResourceLogs.Count).Be(1);

      Resource := ResourceLogs.GetObject(0).GetObject('resource');
      Should(Resource).NotBeNil;

      ScopeLogs := ResourceLogs.GetObject(0).GetArray('scopeLogs');
      Should(ScopeLogs).NotBeNil;
      Should(ScopeLogs.Count).Be(1);

      Scope := ScopeLogs.GetObject(0).GetObject('scope');
      Should(Scope.GetString('name')).Be('dext.logger');

      LogRecords := ScopeLogs.GetObject(0).GetArray('logRecords');
      Should(LogRecords).NotBeNil;
      Should(LogRecords.Count).Be(1);

      LogRec := LogRecords.GetObject(0);
      Should(LogRec.GetString('severityText')).Be('Info');
      
      Body := LogRec.GetObject('body');
      Should(Body.GetString('stringValue')).Be('Test Message OTel');
    finally
      Lock.Leave;
    end;
  finally
    Sink := nil;
    Host.Stop;
    Lock.Free;
  end;
end;

end.
