{***************************************************************************}
{           Dext Framework                                                  }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
{***************************************************************************}
unit Dext.Logging.Sinks.Sidecar;

interface

uses
  System.Classes,
  System.DateUtils,
  System.Generics.Collections,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.NetConsts,
  System.SyncObjs,
  System.SysUtils,
  System.TypInfo,
  Dext.Logging,
  Dext.Logging.Async,
  Dext.Logging.RingBuffer,
  Dext.Logging.Telemetry,
  Dext.Types.UUID,
  Dext.Utils;

type
  TSidecarOptions = class
  public
    Port: Integer;
    Enabled: Boolean;
    constructor Create;
  end;

  /// <summary>
  ///   Sink that sends logs to Dext Sidecar via HTTP.
  /// </summary>
  TSidecarSink = class(TInterfacedObject, ILogSink)
  private
    FUrl: string;
    FClient: THTTPClient;
    FBuffer: TStringBuilder;
    FLock: TObject;
    FFlushTimer: TThread; // Background flusher
    FCount: Integer;
    
    procedure FlushInternal;
  public
    constructor Create(const ABaseUrl: string = 'http://localhost:5000');
    destructor Destroy; override;
    
    procedure Emit(const Entry: TLogEntry);
    procedure Flush;
  end;
  
  // Simple Flush Timer to ensure logs are sent even if low volume
  TSidecarFlushTimer = class(TThread)
  private
    FSink: TSidecarSink;
  public
    constructor Create(ASink: TSidecarSink);
    procedure Execute; override;
  end;

  /// <summary>
  ///   Observer that sends telemetry events (Spans) to Dext Sidecar via HTTP.
  /// </summary>
  TSidecarTelemetryObserver = class(TInterfacedObject, ITelemetryObserver)
  private
    FUrl: string;
    FClient: THTTPClient;
  public
    constructor Create(const ABaseUrl: string = 'http://localhost:5000');
    destructor Destroy; override;
    procedure OnEvent(const AEvent: TTelemetryEvent);
  end;

  /// <summary>
  ///   Background thread that periodically collects system health and registry metrics
  ///   and flushes them to the Dext Sidecar via HTTP.
  /// </summary>
  TSidecarMetricsExporter = class(TThread)
  private
    FUrl: string;
    FClient: THTTPClient;
    FLastProcessTime: Int64;
    FLastSystemTime: Int64;
    function GetProcessCpuUsage: Double;
    function GetProcessMemory(out AWorkingSet, APrivateBytes: Int64): Boolean;
    function GetProcessThreadCount: Integer;
    function GetActiveDbConnections: Integer;
  public
    constructor Create(const ABaseUrl: string = 'http://localhost:3030');
    destructor Destroy; override;
    procedure Execute; override;
  end;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.PsAPI,
  Winapi.TlHelp32,
  {$ENDIF}
  Dext.Telemetry.Metrics;

{ TSidecarOptions }

constructor TSidecarOptions.Create;
begin
  Port := 3030;
  Enabled := False;
end;

{ TSidecarSink }

constructor TSidecarSink.Create(const ABaseUrl: string);
begin
  inherited Create;
  FUrl := ABaseUrl + '/api/telemetry/logs';
  FClient := THTTPClient.Create;
  FClient.ContentType := 'application/json';
  FClient.ConnectionTimeout := 500;
  FClient.ResponseTimeout := 1000;
  
  FBuffer := TStringBuilder.Create;
  FLock := TObject.Create;
  FCount := 0;
  
  FFlushTimer := TSidecarFlushTimer.Create(Self);
end;

destructor TSidecarSink.Destroy;
begin
  if FFlushTimer <> nil then
  begin
    FFlushTimer.Terminate;
    FFlushTimer.WaitFor;
    FFlushTimer.Free;
  end;
  
  FlushInternal; // Send remaining
  
  FClient.Free;
  FBuffer.Free;
  FLock.Free;
  inherited;
end;

procedure TSidecarSink.Emit(const Entry: TLogEntry);
var
  AppName: string;
begin
  TMonitor.Enter(FLock);
  try
    // Format as JSON Object in a list
    // If buffer is empty, start list
    if FCount = 0 then
      FBuffer.Append('[');
    
    if FCount > 0 then
      FBuffer.Append(',');
      
    AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');

    FBuffer.Append('{');
    FBuffer.Append('"ts":"').Append(DateToISO8601(Entry.TimeStamp, False)).Append('",');
    FBuffer.Append('"lvl":"').Append(GetEnumName(TypeInfo(TLogLevel), Integer(Entry.Level))).Append('",');
    FBuffer.Append('"app":"').Append(AppName.Replace('\', '\\').Replace('"', '\"')).Append('",');
    
    if not Entry.TraceId.IsEmpty then
      FBuffer.Append('"traceId":"').Append(Entry.TraceId.ToString).Append('",');
      
    if not Entry.SpanId.IsEmpty then
      FBuffer.Append('"spanId":"').Append(Entry.SpanId.ToString).Append('",');
      
    // ThreadID
    FBuffer.Append('"tid":').Append(Entry.ThreadID).Append(',');
    
    FBuffer.Append('"msg":"').Append(Entry.FormattedMessage.Replace('\', '\\').Replace('"', '\"').Replace(#13, '\r').Replace(#10, '\n')).Append('"');
    FBuffer.Append('}');
    
    Inc(FCount);
    
    // Auto-flush on count or size
    if (FCount >= 50) or (FBuffer.Length > 64 * 1024) then
      FlushInternal;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TSidecarSink.Flush;
begin
  TMonitor.Enter(FLock);
  try
    FlushInternal;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TSidecarSink.FlushInternal;
var
  Payload: TStringStream;
begin
  if FCount = 0 then Exit;
  
  FBuffer.Append(']'); // Close list
  
  try
    Payload := TStringStream.Create(FBuffer.ToString, TEncoding.UTF8);
    try
      // Fire and Forget? Or wait?
      // Since we are in Consumer Thread (or Timer), blocking is bad but necessary for HTTP.
      // 50 logs won't take long.
      try
        FClient.Post(FUrl, Payload);
        SafeWriteLn('>> [SidecarSink] Batch sent successfully');
      except
        on E: Exception do SafeWriteLn('>> [SidecarSink] Failed: ' + E.Message);
      end;
    finally
      Payload.Free;
    end;
  except
    // ignore
  end;
  
  // Reset
  FBuffer.Clear;
  FCount := 0;
end;

{ TSidecarFlushTimer }

constructor TSidecarFlushTimer.Create(ASink: TSidecarSink);
begin
  inherited Create(False);
  FSink := ASink;
end;

procedure TSidecarFlushTimer.Execute;
begin
  while not Terminated do
  begin
    Sleep(1000); // 1 second
    if not Terminated then
      FSink.Flush;
  end;
end;

{ TSidecarTelemetryObserver }

constructor TSidecarTelemetryObserver.Create(const ABaseUrl: string);
begin
  inherited Create;
  FUrl := ABaseUrl + '/api/telemetry/events';
  FClient := THTTPClient.Create;
  FClient.ContentType := 'application/json';
  FClient.ConnectionTimeout := 500;
  FClient.ResponseTimeout := 1000;
end;

destructor TSidecarTelemetryObserver.Destroy;
begin
  FClient.Free;
  inherited;
end;

procedure TSidecarTelemetryObserver.OnEvent(const AEvent: TTelemetryEvent);
var
  JO: TJSONObject;
  JsonStr: string;
  TraceIdVal, SpanIdVal, AppName: string;
  LUrl: string;
begin
  TraceIdVal := AEvent.TraceId;
  SpanIdVal := AEvent.SpanId;
  
  if TraceIdVal = '' then
    TraceIdVal := TUUID.NewV7.ToString;
  if SpanIdVal = '' then
    SpanIdVal := TUUID.NewV7.ToString;
    
  AppName := ChangeFileExt(ExtractFileName(ParamStr(0)), '');

  JO := TJSONObject.Create;
  try
    JO.AddPair('name', AEvent.Name);
    JO.AddPair('ts', DateToISO8601(AEvent.Timestamp, False));
    if Assigned(AEvent.Data) then
      JO.AddPair('data', AEvent.Data.Clone as TJSONObject);
    JO.AddPair('cat', AEvent.Category);
    JO.AddPair('dur', TJSONNumber.Create(AEvent.DurationMs));
    JO.AddPair('status', AEvent.Status);
    JO.AddPair('error', AEvent.ErrorMessage);
    JO.AddPair('traceId', TraceIdVal);
    JO.AddPair('spanId', SpanIdVal);
    JO.AddPair('parentId', AEvent.ParentId);
    JO.AddPair('app', AppName);
    
    JsonStr := JO.ToJSON;
  finally
    JO.Free;
  end;

  LUrl := FUrl;
  TThread.CreateAnonymousThread(procedure
    var
      LClient: THTTPClient;
      LPayload: TStringStream;
    begin
      LClient := THTTPClient.Create;
      try
        LClient.ContentType := 'application/json';
        LClient.ConnectionTimeout := 1000;
        LClient.ResponseTimeout := 2000;
        LPayload := TStringStream.Create(JsonStr, TEncoding.UTF8);
        try
          try
            LClient.Post(LUrl, LPayload);
          except
            // Silent fail in background thread
          end;
        finally
          LPayload.Free;
        end;
      finally
        LClient.Free;
      end;
    end).Start;
end;

{ TSidecarMetricsExporter }

constructor TSidecarMetricsExporter.Create(const ABaseUrl: string);
begin
  inherited Create(False);
  FUrl := ABaseUrl + '/api/telemetry/metrics';
  FClient := THTTPClient.Create;
  FClient.ContentType := 'application/json';
  FClient.ConnectionTimeout := 500;
  FClient.ResponseTimeout := 1000;
  FLastProcessTime := 0;
  FLastSystemTime := 0;
end;

destructor TSidecarMetricsExporter.Destroy;
begin
  FClient.Free;
  inherited;
end;

function TSidecarMetricsExporter.GetActiveDbConnections: Integer;
begin
  if Assigned(Dext.Telemetry.Metrics.GActiveDbConnectionsFunc) then
    Result := Dext.Telemetry.Metrics.GActiveDbConnectionsFunc()
  else
    Result := 0;
end;

function TSidecarMetricsExporter.GetProcessCpuUsage: Double;
begin
  Result := 0.0;
  {$IFDEF MSWINDOWS}
  var CreationTime, ExitTime, KernelTime, UserTime: TFileTime;
  var SystemIdleTime, SystemKernelTime, SystemUserTime: TFileTime;
  var CurrentProcessTime, CurrentSystemTime: Int64;
  var DiffProcess, DiffSystem: Int64;
  
  if GetProcessTimes(GetCurrentProcess, CreationTime, ExitTime, KernelTime, UserTime) and
     Winapi.Windows.GetSystemTimes(SystemIdleTime, SystemKernelTime, SystemUserTime) then
  begin
    CurrentProcessTime := (Int64(KernelTime.dwHighDateTime) shl 32 or KernelTime.dwLowDateTime) +
                         (Int64(UserTime.dwHighDateTime) shl 32 or UserTime.dwLowDateTime);
    CurrentSystemTime  := (Int64(SystemKernelTime.dwHighDateTime) shl 32 or SystemKernelTime.dwLowDateTime) +
                         (Int64(SystemUserTime.dwHighDateTime) shl 32 or SystemUserTime.dwLowDateTime);
                         
    if (FLastProcessTime > 0) and (FLastSystemTime > 0) then
    begin
      DiffProcess := CurrentProcessTime - FLastProcessTime;
      DiffSystem  := CurrentSystemTime - FLastSystemTime;
      if DiffSystem > 0 then
        Result := (DiffProcess * 100.0) / DiffSystem;
    end;
    FLastProcessTime := CurrentProcessTime;
    FLastSystemTime  := CurrentSystemTime;
  end;
  {$ENDIF}
end;

function TSidecarMetricsExporter.GetProcessMemory(out AWorkingSet, APrivateBytes: Int64): Boolean;
begin
  AWorkingSet := 0;
  APrivateBytes := 0;
  Result := False;
  {$IFDEF MSWINDOWS}
  var PMC: TProcessMemoryCountersEx;
  PMC.cb := SizeOf(PMC);
  if GetProcessMemoryInfo(GetCurrentProcess, @PMC, SizeOf(PMC)) then
  begin
    AWorkingSet := PMC.WorkingSetSize;
    {$IF CompilerVersion >= 36.0}
    APrivateBytes := PMC.PrivateUsage;
    {$ELSE}
    APrivateBytes := PMC.PrivateUsge;
    {$IFEND}
    Result := True;
  end;
  {$ENDIF}
end;

function TSidecarMetricsExporter.GetProcessThreadCount: Integer;
begin
  Result := 0;
  {$IFDEF MSWINDOWS}
  var hSnap: THandle;
  var pe: TThreadEntry32;
  hSnap := CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if hSnap <> INVALID_HANDLE_VALUE then
  try
    pe.dwSize := SizeOf(pe);
    if Thread32First(hSnap, pe) then
    repeat
      if pe.th32OwnerProcessID = GetCurrentProcessId then
        Inc(Result);
    until not Thread32Next(hSnap, pe);
  finally
    CloseHandle(hSnap);
  end;
  {$ENDIF}
end;

procedure TSidecarMetricsExporter.Execute;
var
  Cpu: Double;
  i: Integer;
  Item: TJSONValue;
  MetricsArr, ImportedArr: TJSONArray;
  MetricsStr: string;
  Payload: TJSONObject;
  Stream: TStringStream;
  SystemObj: TJSONObject;
  Threads, DbConn: Integer;
  WS, Priv: Int64;
begin
  while not Terminated do
  begin
    // Gather metrics every 5 seconds
    for i := 0 to 49 do
    begin
      if Terminated then Break;
      Sleep(100);
    end;
    if Terminated then Break;
    
    Cpu := GetProcessCpuUsage;
    WS := 0;
    Priv := 0;
    GetProcessMemory(WS, Priv);
    Threads := GetProcessThreadCount;
    DbConn := GetActiveDbConnections;
    
    // Flush the custom/automatically gathered HTTP & SQL metrics
    MetricsStr := TMetrics.Flush;
    
    Payload := TJSONObject.Create;
    try
      Payload.AddPair('timestamp', DateToISO8601(Now, False));
      Payload.AddPair('app', ChangeFileExt(ExtractFileName(ParamStr(0)), ''));
      
      SystemObj := TJSONObject.Create;
      SystemObj.AddPair('cpu', TJSONNumber.Create(Cpu));
      SystemObj.AddPair('memory_working_set', TJSONNumber.Create(WS));
      SystemObj.AddPair('memory_private', TJSONNumber.Create(Priv));
      SystemObj.AddPair('threads', TJSONNumber.Create(Threads));
      SystemObj.AddPair('db_connections', TJSONNumber.Create(DbConn));
      Payload.AddPair('system', SystemObj);
      
      MetricsArr := TJSONArray.Create;
      if (MetricsStr <> '') and (MetricsStr <> '[]') then
      begin
        try
          ImportedArr := TJSONObject.ParseJSONValue(MetricsStr) as TJSONArray;
          if ImportedArr <> nil then
          try
            for i := 0 to ImportedArr.Count - 1 do
            begin
              Item := ImportedArr.Items[i];
              MetricsArr.AddElement(Item.Clone as TJSONValue);
            end;
          finally
            ImportedArr.Free;
          end;
        except
          // ignore parsing error
        end;
      end;
      Payload.AddPair('metrics', MetricsArr);
      
      Stream := TStringStream.Create(Payload.ToJSON, TEncoding.UTF8);
      try
        try
          FClient.Post(FUrl, Stream);
        except
          // ignore network failure
        end;
      finally
        Stream.Free;
      end;
      
    finally
      Payload.Free;
    end;
  end;
end;

end.
