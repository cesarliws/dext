program Core.TestHttpParser;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Dext.Http.Request,
  Dext.Http.Parser,
  Dext.Http.Executor,
  Dext.Net.RestClient,
  Dext.Net.ConnectionPool,
  Dext.Net.Authentication,
  Dext.Threading.Async,
  Dext.Threading.CancellationToken,
  Dext.Utils,
  Dext.Json;

const
  SAMPLE_HTTP_CONTENT =
    '### Variables' + sLineBreak +
    '@baseUrl = https://jsonplaceholder.typicode.com' + sLineBreak +
    '@contentType = application/json' + sLineBreak +
    '' + sLineBreak +
    '### Get all posts' + sLineBreak +
    'GET {{baseUrl}}/posts' + sLineBreak +
    'Accept: {{contentType}}' + sLineBreak +
    '' + sLineBreak +
    '### Create a new post' + sLineBreak +
    'POST {{baseUrl}}/posts' + sLineBreak +
    'Content-Type: {{contentType}}' + sLineBreak +
    '' + sLineBreak +
    '{' + sLineBreak +
    '  "title": "Dext Framework",' + sLineBreak +
    '  "body": "Testing HTTP client",' + sLineBreak +
    '  "userId": 1' + sLineBreak +
    '}' + sLineBreak +
    '' + sLineBreak +
    '### Get user by ID' + sLineBreak +
    'GET {{baseUrl}}/users/1' + sLineBreak;

procedure TestParseVariables;
var
  Collection: THttpRequestCollection;
  V: THttpVariable;
begin
  WriteLn('=== Test: Parse Variables ===');
  Collection := THttpRequestParser.Parse(SAMPLE_HTTP_CONTENT);
  try
    WriteLn('Variables found: ', Collection.Variables.Count);
    for V in Collection.Variables do
      WriteLn('  @', V.Name, ' = ', V.Value);
      
    if Collection.Variables.Count = 2 then
      WriteLn('[PASS] Correct number of variables')
    else
      WriteLn('[FAIL] Expected 2 variables, got ', Collection.Variables.Count);
  finally
    Collection.Free;
  end;
  WriteLn;
end;

procedure TestParseRequests;
var
  Collection: THttpRequestCollection;
  R: THttpRequestInfo;
begin
  WriteLn('=== Test: Parse Requests ===');
  Collection := THttpRequestParser.Parse(SAMPLE_HTTP_CONTENT);
  try
    WriteLn('Requests found: ', Collection.Requests.Count);
    for R in Collection.Requests do
    begin
      WriteLn('  [', R.Method, '] ', R.Name);
      WriteLn('       URL: ', R.Url);
      WriteLn('       Headers: ', R.Headers.Count);
      if R.Body <> '' then
        WriteLn('       Body: ', Copy(R.Body, 1, 50), '...');
    end;
    
    if Collection.Requests.Count = 3 then
      WriteLn('[PASS] Correct number of requests')
    else
      WriteLn('[FAIL] Expected 3 requests, got ', Collection.Requests.Count);
  finally
    Collection.Free;
  end;
  WriteLn;
end;

procedure TestInterpolateVariables;
var
  Collection: THttpRequestCollection;
  Request: THttpRequestInfo;
  OriginalUrl, ResolvedUrl: string;
begin
  WriteLn('=== Test: Interpolate Variables ===');
  Collection := THttpRequestParser.Parse(SAMPLE_HTTP_CONTENT);
  try
    Request := Collection.Requests[0];
    OriginalUrl := Request.Url;
    WriteLn('Original URL: ', OriginalUrl);
    
    THttpRequestParser.ResolveRequest(Request, Collection.Variables);
    ResolvedUrl := Request.Url;
    WriteLn('Resolved URL: ', ResolvedUrl);
    
    if ResolvedUrl = 'https://jsonplaceholder.typicode.com/posts' then
      WriteLn('[PASS] Variable interpolation works correctly')
    else
      WriteLn('[FAIL] Expected https://jsonplaceholder.typicode.com/posts');
  finally
    Collection.Free;
  end;
  WriteLn;
end;

procedure TestFindByName;
var
  Collection: THttpRequestCollection;
  Request: THttpRequestInfo;
begin
  WriteLn('=== Test: Find By Name ===');
  Collection := THttpRequestParser.Parse(SAMPLE_HTTP_CONTENT);
  try
    Request := Collection.FindByName('Create a new post');
    if Assigned(Request) then
    begin
      WriteLn('Found: ', Request.Method, ' ', Request.Name);
      WriteLn('[PASS] Request found by name');
    end
    else
      WriteLn('[FAIL] Request not found');
    
    Request := Collection.FindByName('Non-existent');
    if not Assigned(Request) then
      WriteLn('[PASS] Non-existent request returns nil')
    else
      WriteLn('[FAIL] Should return nil for non-existent request');
  finally
    Collection.Free;
  end;
  WriteLn;
end;

procedure TestExecuteRequest;
var
  Collection: THttpRequestCollection;
  Request: THttpRequestInfo;
  Result: THttpExecutionResult;
begin
  WriteLn('=== Test: Execute Request (Live API) ===');
  WriteLn('Calling https://jsonplaceholder.typicode.com/posts...');
  
  Collection := THttpRequestParser.Parse(SAMPLE_HTTP_CONTENT);
  try
    Request := Collection.FindByName('Get all posts');
    if Assigned(Request) then
    begin
      Result := THttpExecutor.ExecuteSync(Request, Collection.Variables);
      
      WriteLn('Status: ', Result.StatusCode, ' ', Result.StatusText);
      WriteLn('Duration: ', Result.DurationMs, 'ms');
      WriteLn('Body length: ', Length(Result.ResponseBody), ' chars');
      WriteLn('Body preview: ', Copy(Result.ResponseBody, 1, 100), '...');
      
      if Result.StatusCode = 200 then
        WriteLn('[PASS] API call successful')
      else
        WriteLn('[FAIL] Expected status 200, got ', Result.StatusCode);
        
      if Result.ErrorMessage <> '' then
        WriteLn('Error: ', Result.ErrorMessage);
    end
    else
      WriteLn('[FAIL] Request not found');
  finally
    Collection.Free;
  end;
  WriteLn;
end;

procedure TestParseFromFile;
var
  Collection: THttpRequestCollection;
  FilePath: string;
  LDir: string;
  R: THttpRequestInfo;
begin
  WriteLn('=== Test: Parse From File ===');
  FilePath := ExtractFilePath(ParamStr(0)) + '..\..\Examples\example-api.http';
  
  if not FileExists(FilePath) then
  begin
    LDir := ExtractFilePath(ParamStr(0));
    while (Length(LDir) > 3) and not TDirectory.Exists(TPath.Combine(LDir, 'Examples')) do
      LDir := TPath.GetDirectoryName(LDir);
    FilePath := TPath.Combine(LDir, 'Examples\example-api.http');
  end;
  
  if FileExists(FilePath) then
  begin
    Collection := THttpRequestParser.ParseFile(FilePath);
    try
      WriteLn('Parsed file: ', FilePath);
      WriteLn('Variables: ', Collection.Variables.Count);
      WriteLn('Requests: ', Collection.Requests.Count);
      
      for R in Collection.Requests do
        WriteLn('  - [', R.Method, '] ', R.Name);
      
      if Collection.Requests.Count > 0 then
        WriteLn('[PASS] File parsed successfully')
      else
        WriteLn('[FAIL] No requests parsed');
    finally
      Collection.Free;
    end;
  end
  else
    WriteLn('[SKIP] Example file not found');
  WriteLn;
end;

begin
  try
    WriteLn('========================================');
    WriteLn('   Dext HTTP Parser Test Suite');
    WriteLn('========================================');
    WriteLn;
    
    TestParseVariables;
    TestParseRequests;
    TestInterpolateVariables;
    TestFindByName;
    TestParseFromFile;
    TestExecuteRequest;
    
    WriteLn('========================================');
    WriteLn('   All tests completed!');
    WriteLn('========================================');
    
  except
    on E: Exception do
      Writeln('Error: ', E.ClassName, ': ', E.Message);
  end;
  
  WriteLn;
  WriteLn('Press Enter to exit...');
  ConsolePause;
end.
