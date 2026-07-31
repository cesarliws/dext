program RestClientDemo;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  Dext.Utils,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Dext.Net.RestClient,
  Dext.Net.RestRequest,
  Dext.Threading.Async,
  Dext.Threading.CancellationToken,
  User.Entity in 'User.Entity.pas';

type
  // Record DTOs for S20 Testing (Modern DTO Support)
  TUserRecord = record
    id: Integer;
    name: string;
    email: string;
  end;

  TPostRecord = record
    userId: Integer;
    id: Integer;
    title: string;
    body: string;
  end;

  TPost = class
  private
    FId: Integer;
    FTitle: string;
    FBody: string;
    FUserId: Integer;
  public
    property id: Integer read FId write FId;
    property title: string read FTitle write FTitle;
    property body: string read FBody write FBody;
    property userId: Integer read FUserId write FUserId;
  end;

var
  Countdown: TCountdownEvent;

procedure DemoFluentGet;
begin
  Writeln('--- Demo: Fluent GET (Typed) ---');
  Countdown.AddCount;
  
  RestClient('https://jsonplaceholder.typicode.com')
    .Get('/users/1')
    .OnCompleteAsync(
      procedure(Response: IRestResponse)
      begin
        Writeln('--- Demo: Fluent GET (Typed) Response ---');
        Writeln('Status: ', Response.StatusCode);
        Writeln('Content: ', Response.ContentString.Substring(0, 100) + '...');
        Countdown.Signal;
      end)
    .OnExceptionAsync(
      procedure(E: Exception)
      begin
        Writeln('--- Demo: Fluent GET (Typed) Error ---');
        Writeln('Error: ', E.Message);
        Countdown.Signal;
      end)
    .Start;
end;

procedure DemoRequestRequest;
var
  LRestClient: TRestClient;
begin
  Writeln('--- Demo: TRestRequest Builder ---');
  Countdown.AddCount;
  
  LRestClient := TRestClient.Create('https://jsonplaceholder.typicode.com');
  try
    TRestRequest
      .Create(LRestClient, hmPOST, '/posts')
      .Header('X-Custom-Header', 'DextValue')
      .JsonBody('{"title": "foo", "body": "bar", "userId": 1}')
      .Execute
      .OnCompleteAsync(
        procedure(Response: IRestResponse)
        begin
          Writeln('--- Demo: TRestRequest Response ---');
          Writeln('POST Status: ', Response.StatusCode);
          Writeln('POST Response: ', Response.ContentString);
          Countdown.Signal;
        end)
      .OnExceptionAsync(
        procedure(E: Exception)
        begin
          Writeln('--- Demo: TRestRequest Error ---');
          Writeln('Error: ', E.Message);
          Countdown.Signal;
        end)
      .Start;
  finally
    // TRestClient is a record wrapper over interface; no manual Free required.
  end;
end;

procedure DemoS20FluentBuilder;
var
  LUser: TUserRecord;
begin
  Writeln('--- Demo S20: Fluent Builder (Client.Request.Verb) ---');
  
  // Test 1: Request.Get with record deserialization (S20 Requirement)
  LUser := RestClient('https://jsonplaceholder.typicode.com')
    .Request.Get('/users/1')
    .Execute<TUserRecord>
    .Await;
    
  Writeln('Builder GET Result (Record Name): ', LUser.name);

  // Test 2: Request.Post with record body and fluent headers
  Writeln('Testing Builder POST with Record Body...');
  Countdown.AddCount;
  RestClient('https://jsonplaceholder.typicode.com')
    .Request.Post('/posts')
    .Header('X-Framework', 'Dext')
    .Body(LUser) // Testing Body<T> with record
    .Execute
    .OnCompleteAsync(
      procedure(LResp: IRestResponse)
      begin
        Writeln('Builder POST Status: ', LResp.StatusCode);
        Countdown.Signal;
      end)
    .Start;
end;

procedure DemoS20RecordArrays;
var
  LPosts: TArray<TPostRecord>;
begin
  Writeln('--- Demo S20: Record Arrays (BodyArray) ---');
  
  SetLength(LPosts, 2);
  LPosts[0].title := 'Fluent API';
  LPosts[0].body := 'Dext is evolving';
  LPosts[0].userId := 1;
  
  LPosts[1].title := 'S20 Spec';
  LPosts[1].body := 'Implementing records support';
  LPosts[1].userId := 1;

  Countdown.AddCount;
  RestClient('https://jsonplaceholder.typicode.com')
    .Request.Post('/posts')
    .BodyArray<TPostRecord>(LPosts) // Testing specialized BodyArray for collections
    .Execute
    .OnCompleteAsync(
      procedure(LResp: IRestResponse)
      begin
        Writeln('BodyArray POST Status: ', LResp.StatusCode);
        Countdown.Signal;
      end)
    .Start;
end;

procedure DemoS20ShorthandRecords;
var
  LPost: TPostRecord;
  LResp: IRestResponse<TPostRecord>;
begin
  Writeln('--- Demo S20: Shorthand with Records ---');
  
  LPost.title := 'Shorthand';
  LPost.body := 'Directly sending record';
  LPost.userId := 1;

  // Testing shorthand Post<T> with record response
  LResp := RestClient('https://jsonplaceholder.typicode.com')
    .Post<TPostRecord>('/posts', LPost) 
    .Await;
    
  Writeln('Shorthand Result ID: ', LResp.Data.id);
  Writeln;
end;

procedure DemoS20DirectRequest;
begin
  Writeln('--- Demo S20: Direct Request Factory ---');
  
  RestClient('https://jsonplaceholder.typicode.com')
    .Request(hmGET, '/posts/1') // Testing the new overloaded Request(Method, Endpoint)
    .Execute
    .OnCompleteAsync(
      procedure(LResp: IRestResponse)
      begin
        if LResp.IsSuccess then
          Writeln('Direct Request Success! Status: ', LResp.StatusCode)
        else
          Writeln('Direct Request Failed! Status: ', LResp.StatusCode);
        Countdown.Signal;
      end)
    .Start;
  Countdown.AddCount;
end;

procedure DemoWithCancellation;
var
  CancelationTokenSource: TCancellationTokenSource;
begin
  Writeln('--- Demo: Cancellation ---');
  Countdown.AddCount;
  
  CancelationTokenSource := TCancellationTokenSource.Create;
  try
    RestClient('https://jsonplaceholder.typicode.com')
      .Get('/posts')
      .WithCancellation(CancelationTokenSource.Token)
      .OnCompleteAsync(
        procedure(Response: IRestResponse)
        begin
          Writeln('--- Demo: Cancellation Response ---');
          Writeln('Success (should not happen if canceled)');
          Countdown.Signal;
        end)
      .OnExceptionAsync(
        procedure(E: Exception)
        begin
          Writeln('--- Demo: Cancellation Error ---');
          Writeln('Expected Error: ', E.Message);
          Countdown.Signal;
        end)
      .Start;
      
    CancelationTokenSource.Cancel;
    Writeln('Requested Cancellation.');
  finally
    CancelationTokenSource.Free;
  end;
end;

procedure DemoSynchronous;
var
  Response: TPost;
begin
  Writeln('--- Demo: Synchronous Request ---');
  
  try
    Response := RestClient('https://jsonplaceholder.typicode.com')
      .Get<TPost>('/posts/1')
      .Await; // Blocks and runs on current thread
      
    try
      Writeln('--- Demo: Synchronous Response ---');
      Writeln('Synchronous success!');
      Writeln('ID: ', Response.id);
      Writeln('Title: ', Response.title);
    finally
      Response.Free;
    end;
  except
    on E: Exception do
      Writeln('Synchronous Error: ', E.Message);
  end;
end;

procedure DemoSynchronousList;
var
  posts: TList<TPost>;
  p: TPost;
begin
  Writeln('--- Demo: Synchronous List Request (TList) ---');
  Writeln;

  try
    posts := RestClient('https://jsonplaceholder.typicode.com')
      .Get<TList<TPost>>('/posts')
      .Await; // Blocks and runs on current thread

    try
      Writeln('--- Demo: Synchronous TList<TPost> ---');
      Writeln('--- Demo: Synchronous TList Count ' + posts.Count.ToString + ' ---');
      for p in posts do
      begin
        Writeln('Synchronous success (TList)!ID: ', p.id);
      end;
    finally
      if posts <> nil then
      begin
        for p in posts do
          p.Free;
        posts.Free;
      end;
    end;
  except
    on E: Exception do
      Writeln('Synchronous Error: ', E.Message);
  end;
  Writeln;
end;

procedure DemoSynchronousObjectList;
var
  posts: TObjectList<TPost>;
  p: TPost;
begin
  Writeln('--- Demo: Synchronous List Request (TObjectList) ---');
  Writeln;

  try
    posts := RestClient('https://jsonplaceholder.typicode.com')
      .Get<TObjectList<TPost>>('/posts')
      .Await; // Blocks and runs on current thread

    try
      Writeln('--- Demo: Synchronous TObjectList<TPost> ---');
      Writeln('--- Demo: Synchronous TObjectList Count ' + posts.Count.ToString + ' ---');
      for p in posts do
      begin
        Writeln('Synchronous success (TObjectList)!ID: ', p.id);
      end;
    finally
      posts.Free; // OwnsObjects := True por padrão
    end;
  except
    on E: Exception do
      Writeln('Synchronous Error: ', E.Message);
  end;
  Writeln;
end;

procedure DemoContentType;
var
  BodyStream: TStringStream;
  Res: IRestResponse;
begin
  Writeln('--- Demo: ContentType and Request Body ---');
  
  BodyStream := TStringStream.Create('title=foo&body=bar&userId=1', TEncoding.UTF8);
  try
    Res := RestClient('https://jsonplaceholder.typicode.com')
      .ContentType(TDextContentType.ctFormUrlEncoded)
      .Post('/posts', BodyStream)
      .Await;
      
    Writeln('Status with FormUrlEncoded: ', Res.StatusCode);
    Writeln('Response: ', Res.ContentString);
  finally
    BodyStream.Free;
  end;
end;

begin
  try
    Countdown := TCountdownEvent.Create(1);
    try
      DemoFluentGet;
      DemoRequestRequest;
      DemoS20FluentBuilder;
      DemoS20RecordArrays;
      DemoS20ShorthandRecords;
      DemoS20DirectRequest;
      DemoWithCancellation;
      DemoSynchronous;
      DemoSynchronousList;
      DemoSynchronousObjectList;
      DemoContentType;
      
      Writeln('Waiting for tasks...');
      Countdown.Signal; // Finish setup
      Countdown.WaitFor;
    finally
      Countdown.Free;
    end;
    
    ConsolePause;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ConsolePause;
    end;
  end;
end.

