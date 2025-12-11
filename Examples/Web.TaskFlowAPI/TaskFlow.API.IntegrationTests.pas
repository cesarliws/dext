unit TaskFlow.API.IntegrationTests;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Classes,
  TaskFlow.Domain,
  TaskFlow.Repository.Interfaces,
  TaskFlow.Repository.Mock;

procedure TestAllEndpoints;
procedure TestEndpoint(const Description, URL, Method: string; Content: string = ''; Headers: TNetHeaders = []);

implementation

//procedure TestAllEndpoints;
//var
//  HttpClient: THTTPClient;
//  Response: IHTTPResponse;
//  JSONContent: TJSONObject;
//  Headers: TNetHeaders;
//  ContentStream: TStringStream;
//begin
//  WriteLn('');
//  WriteLn('🔬 INTEGRATION TESTS');
//  WriteLn('===================');
//
//  HttpClient := THTTPClient.Create;
//
//  try
//    // TESTE 1: GET /api/tasks
//    WriteLn('1. Testing GET /api/tasks...');
//    Response := HttpClient.Get('http://localhost:8080/api/tasks');
//    WriteLn('   Status: ', Response.StatusCode, ' - ', Response.StatusText);
//    if Response.StatusCode = 200 then
//      WriteLn('   ✅ Success! Content: ', Copy(Response.ContentAsString, 1, 100), '...');
//
//    // TESTE 2: GET /api/tasks/1
//    WriteLn('2. Testing GET /api/tasks/1...');
//    Response := HttpClient.Get('http://localhost:8080/api/tasks/1');
//    WriteLn('   Status: ', Response.StatusCode, ' - ', Response.StatusText);
//    if Response.StatusCode = 200 then
//      WriteLn('   ✅ Task found!')
//    else if Response.StatusCode = 404 then
//      WriteLn('   ℹ️  Task not found (expected for some IDs)');
//
//    // TESTE 3: POST /api/tasks
//    WriteLn('3. Testing POST /api/tasks...');
//    JSONContent := TJSONObject.Create;
//    try
//      JSONContent.AddPair('title', 'Nova Tarefa via API');
//      JSONContent.AddPair('description', 'Criada através do teste de integração');
//      JSONContent.AddPair('priority', 'high');
//      JSONContent.AddPair('dueDate', FormatDateTime('yyyy-mm-dd', Now + 5));
//
//      // Configurar headers para JSON
//      SetLength(Headers, 1);
//      Headers[0] := TNameValuePair.Create('Content-Type', 'application/json');
//
//      ContentStream := TStringStream.Create(JSONContent.ToString, TEncoding.UTF8);
//      try
//        Response := HttpClient.Post('http://localhost:8080/api/tasks', ContentStream, nil, Headers);
//        WriteLn('   Status: ', Response.StatusCode, ' - ', Response.StatusText);
//        if Response.StatusCode in [200, 201] then
//        begin
//          WriteLn('   ✅ Task created successfully!');
//          WriteLn('   Response: ', Copy(Response.ContentAsString, 1, 200));
//        end;
//      finally
//        ContentStream.Free;
//      end;
//    finally
//      JSONContent.Free;
//    end;
//
//    // TESTE 4: GET /api/tasks/stats
//    WriteLn('4. Testing GET /api/tasks/stats...');
//    Response := HttpClient.Get('http://localhost:8080/api/tasks/stats');
//    WriteLn('   Status: ', Response.StatusCode, ' - ', Response.StatusText);
//    if Response.StatusCode = 200 then
//      WriteLn('   ✅ Stats retrieved!');
//
//    // TESTE 5: GET /api/tasks/overdue
//    WriteLn('5. Testing GET /api/tasks/overdue...');
//    Response := HttpClient.Get('http://localhost:8080/api/tasks/overdue');
//    WriteLn('   Status: ', Response.StatusCode, ' - ', Response.StatusText);
//    if Response.StatusCode = 200 then
//      WriteLn('   ✅ Overdue tasks retrieved!');
//
//    // TESTE 6: GET /api/tasks/search com query parameters
//    WriteLn('6. Testing GET /api/tasks/search?status=completed...');
//    Response := HttpClient.Get('http://localhost:8080/api/tasks/search?status=completed');
//    WriteLn('   Status: ', Response.StatusCode, ' - ', Response.StatusText);
//    if Response.StatusCode = 200 then
//      WriteLn('   ✅ Search with query params working!');
//
//    WriteLn('');
//    WriteLn('🎉 INTEGRATION TESTS COMPLETED!');
//
//  except
//    on E: Exception do
//      WriteLn('❌ Test error: ', E.Message);
//  end;
//
//  HttpClient.Free;
//end;

procedure TestEndpoint(const Description, URL, Method: string; Content: string
  = ''; Headers: TNetHeaders = []);
var
  HttpClient: THTTPClient;
  Response: IHTTPResponse;
  ContentStream: TStringStream;
begin
  Write(Description, '... ');

  HttpClient := THTTPClient.Create;
  try
    try
      if (Method = 'POST') and (Content <> '') then
      begin
        ContentStream := TStringStream.Create(Content, TEncoding.UTF8);
        try
          Response := HttpClient.Post(URL, ContentStream, nil, Headers);
        finally
          ContentStream.Free;
        end;
      end
      else
        Response := HttpClient.Get(URL);

      if Response.StatusCode in [200, 201] then
        WriteLn('✅ ', Response.StatusCode)
      else
        WriteLn('❌ ', Response.StatusCode, ' - ', Response.StatusText);

    except
      on E: ENetHTTPClientException do
        WriteLn('❌ HTTP Error: ', E.Message);
      on E: Exception do
        WriteLn('❌ Error: ', E.Message);
    end;

  finally
    HttpClient.Free;
  end;
end;

procedure TestAllEndpoints;
var
  Headers: TNetHeaders;
  JSONContent: string;
begin
  WriteLn('');
  WriteLn('🔬 INTEGRATION TESTS');
  WriteLn('===================');

  // Configurar headers para JSON
  SetLength(Headers, 1);
  Headers[0] := TNameValuePair.Create('Content-Type', 'application/json');

  JSONContent := '{"title":"Teste API","description":"Testando POST","priority":"medium","dueDate":"2024-12-31"}';

  TestEndpoint('1. GET /api/tasks', 'http://localhost:8080/api/tasks', 'GET');
  TestEndpoint('2. GET /api/tasks/1', 'http://localhost:8080/api/tasks/1', 'GET');
  TestEndpoint('3. POST /api/tasks', 'http://localhost:8080/api/tasks', 'POST', JSONContent, Headers);
  TestEndpoint('4. GET /api/tasks/stats', 'http://localhost:8080/api/tasks/stats', 'GET');
  TestEndpoint('5. GET /api/tasks/overdue', 'http://localhost:8080/api/tasks/overdue', 'GET');
  TestEndpoint('6. GET /api/tasks/search', 'http://localhost:8080/api/tasks/search?status=completed', 'GET');

  WriteLn('');
  WriteLn('🎉 INTEGRATION TESTS COMPLETED!');
end;

end.
