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
unit Dext.Net.Redis.Tests;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Core.Span,
  Dext.Net.Tcp,
  Dext.Net.Redis,
  Dext.Collections.Channels,
  Dext.Caching,
  Dext.Caching.Redis;

type
  [TestFixture('Dext.Net Redis Parser')]
  TDextRedisParserTests = class
  public
    [Test]
    procedure Parser_ShouldParseSimpleString;
    [Test]
    procedure Parser_ShouldParseError;
    [Test]
    procedure Parser_ShouldParseInteger;
    [Test]
    procedure Parser_ShouldParseBulkString;
    [Test]
    procedure Parser_ShouldParseArray;
    [Test]
    procedure Parser_ShouldParseRESP3Null;
    [Test]
    procedure Parser_ShouldParseRESP3Boolean;
  end;

  [TestFixture('Dext.Net Redis Client')]
  TDextRedisClientTests = class
  public
    [Test]
    procedure Client_ShouldExecuteBasicCommandsWithMockServer;
    [Test]
    procedure Client_ShouldSupportPubSubWithMockServer;
  end;

  [TestFixture('Dext.Net Redis Cache Store')]
  TDextRedisCacheStoreTests = class
  public
    [Test]
    procedure CacheStore_ShouldGetAndSetKeys;
    [Test]
    procedure CacheStore_ShouldClearKeys;
  end;

implementation

{ TDextRedisParserTests }

procedure TDextRedisParserTests.Parser_ShouldParseSimpleString;
var
  Buffer: TBytes;
  Span: TByteSpan;
  Val: TDextRedisValue;
  Consumed: Integer;
begin
  Buffer := TEncoding.UTF8.GetBytes('+OK'#13#10);
  Span := TByteSpan.FromBytes(Buffer);
  Should(TDextRedisParser.TryParse(Span, Val, Consumed)).BeTrue;
  Should(Consumed).Be(5);
  Should(Val.ValueType).Be(TDextRedisValueType.rvSimpleString);
  Should(Val.AsString).Be('OK');
end;

procedure TDextRedisParserTests.Parser_ShouldParseError;
var
  Buffer: TBytes;
  Span: TByteSpan;
  Val: TDextRedisValue;
  Consumed: Integer;
begin
  Buffer := TEncoding.UTF8.GetBytes('-ERR something went wrong'#13#10);
  Span := TByteSpan.FromBytes(Buffer);
  Should(TDextRedisParser.TryParse(Span, Val, Consumed)).BeTrue;
  Should(Consumed).Be(27);
  Should(Val.ValueType).Be(TDextRedisValueType.rvError);
  Should(Val.AsString).Be('ERR something went wrong');
end;

procedure TDextRedisParserTests.Parser_ShouldParseInteger;
var
  Buffer: TBytes;
  Span: TByteSpan;
  Val: TDextRedisValue;
  Consumed: Integer;
begin
  Buffer := TEncoding.UTF8.GetBytes(':42'#13#10);
  Span := TByteSpan.FromBytes(Buffer);
  Should(TDextRedisParser.TryParse(Span, Val, Consumed)).BeTrue;
  Should(Consumed).Be(5);
  Should(Val.ValueType).Be(TDextRedisValueType.rvInteger);
  Should(Val.AsInteger).Be(42);
end;

procedure TDextRedisParserTests.Parser_ShouldParseBulkString;
var
  Buffer: TBytes;
  Span: TByteSpan;
  Val: TDextRedisValue;
  Consumed: Integer;
begin
  Buffer := TEncoding.UTF8.GetBytes('$6'#13#10'foobar'#13#10);
  Span := TByteSpan.FromBytes(Buffer);
  Should(TDextRedisParser.TryParse(Span, Val, Consumed)).BeTrue;
  Should(Consumed).Be(12);
  Should(Val.ValueType).Be(TDextRedisValueType.rvBulkString);
  Should(Val.AsString).Be('foobar');
end;

procedure TDextRedisParserTests.Parser_ShouldParseArray;
var
  Buffer: TBytes;
  Span: TByteSpan;
  Val: TDextRedisValue;
  Consumed: Integer;
begin
  Buffer := TEncoding.UTF8.GetBytes('*2'#13#10'$3'#13#10'foo'#13#10'$3'#13#10'bar'#13#10);
  Span := TByteSpan.FromBytes(Buffer);
  Should(TDextRedisParser.TryParse(Span, Val, Consumed)).BeTrue;
  Should(Consumed).Be(22);
  Should(Val.ValueType).Be(TDextRedisValueType.rvArray);
  Should(Length(Val.AsArray)).Be(2);
  Should(Val.AsArray[0].AsString).Be('foo');
  Should(Val.AsArray[1].AsString).Be('bar');
end;

procedure TDextRedisParserTests.Parser_ShouldParseRESP3Null;
var
  Buffer: TBytes;
  Span: TByteSpan;
  Val: TDextRedisValue;
  Consumed: Integer;
begin
  Buffer := TEncoding.UTF8.GetBytes('_'#13#10);
  Span := TByteSpan.FromBytes(Buffer);
  Should(TDextRedisParser.TryParse(Span, Val, Consumed)).BeTrue;
  Should(Consumed).Be(3);
  Should(Val.ValueType).Be(TDextRedisValueType.rvNull);
  Should(Val.IsNull).BeTrue;
end;

procedure TDextRedisParserTests.Parser_ShouldParseRESP3Boolean;
var
  Buffer: TBytes;
  Span: TByteSpan;
  Val: TDextRedisValue;
  Consumed: Integer;
begin
  Buffer := TEncoding.UTF8.GetBytes('#t'#13#10);
  Span := TByteSpan.FromBytes(Buffer);
  Should(TDextRedisParser.TryParse(Span, Val, Consumed)).BeTrue;
  Should(Consumed).Be(4);
  Should(Val.ValueType).Be(TDextRedisValueType.rvBoolean);
  Should(Val.AsBoolean).BeTrue;
end;

{ TDextRedisClientTests }

procedure TDextRedisClientTests.Client_ShouldExecuteBasicCommandsWithMockServer;
var
  Server: TDextTcpServer;
  Client: TDextRedisClient;
  Res: string;
  Ok: Boolean;
begin
  Server := TDextTcpServer.Create;
  try
    Server.OnDataSpan :=
      procedure(const AConnection: ITcpConnection; const AData: TByteSpan)
      var
        Request: string;
        Response: TBytes;
      begin
        Request := AData.ToString;
        if Request.Contains('GET') then
          Response := TEncoding.UTF8.GetBytes('$7'#13#10'myvalue'#13#10)
        else if Request.Contains('SET') then
          Response := TEncoding.UTF8.GetBytes('+OK'#13#10)
        else
          Response := TEncoding.UTF8.GetBytes('-ERR Unknown Command'#13#10);
        AConnection.Send(Response);
      end;
    
    Server.Bind('127.0.0.1', 0);
    Server.Start;

    Client := TDextRedisClient.Create('127.0.0.1', Server.ListenPort);
    try
      Res := Client.Get('mykey');
      Should(Res).Be('myvalue');

      Ok := Client.SetVal('mykey', 'newval');
      Should(Ok).BeTrue;
    finally
      Client.Free;
    end;
  finally
    Server.Free;
  end;
end;

procedure TDextRedisClientTests.Client_ShouldSupportPubSubWithMockServer;
var
  Server: TDextTcpServer;
  Client: TDextRedisClient;
  Chan: IChannel<TDextRedisMessage>;
  Msg: TDextRedisMessage;
  ActiveConn: ITcpConnection;
  Response: TBytes;
begin
  Server := TDextTcpServer.Create;
  try
    ActiveConn := nil;
    Server.OnConnect :=
      procedure(const AConnection: ITcpConnection)
      begin
        ActiveConn := AConnection;
      end;

    Server.OnDataSpan :=
      procedure(const AConnection: ITcpConnection; const AData: TByteSpan)
      var
        Request: string;
        Response: TBytes;
      begin
        Request := AData.ToString;
        if Request.Contains('SUBSCRIBE') then
        begin
          Response := TEncoding.UTF8.GetBytes('*3'#13#10'$9'#13#10'subscribe'#13#10'$6'#13#10'mychan'#13#10':1'#13#10);
          AConnection.Send(Response);
        end;
      end;
    
    Server.Bind('127.0.0.1', 0);
    Server.Start;

    Client := TDextRedisClient.Create('127.0.0.1', Server.ListenPort);
    try
      Chan := Client.Subscribe('mychan');
      
      // Wait briefly for connection registration
      Sleep(200);

      Should(ActiveConn).NotBeNil;
      
      // Push message from the mock server
      Response := TEncoding.UTF8.GetBytes('*3'#13#10'$7'#13#10'message'#13#10'$6'#13#10'mychan'#13#10'$5'#13#10'hello'#13#10);
      ActiveConn.Send(Response);

      // Now read from channel (should block until received or time out if it fails)
      Msg := Chan.Read;
      Should(Msg.Channel).Be('mychan');
      Should(Msg.Payload).Be('hello');
    finally
      Client.Free;
    end;
  finally
    Server.Free;
  end;
end;

{ TDextRedisCacheStoreTests }

procedure TDextRedisCacheStoreTests.CacheStore_ShouldGetAndSetKeys;
var
  Server: TDextTcpServer;
  Cache: ICacheStore;
  ResValue: string;
begin
  Server := TDextTcpServer.Create;
  try
    Server.OnDataSpan :=
      procedure(const AConnection: ITcpConnection; const AData: TByteSpan)
      var
        Request: string;
        Response: TBytes;
      begin
        Request := AData.ToString;
        if Request.Contains('GET') then
        begin
          if Request.Contains('dext:cache:mykey') then
            Response := TEncoding.UTF8.GetBytes('$12'#13#10'cached_value'#13#10)
          else
            Response := TEncoding.UTF8.GetBytes('$-1'#13#10);
        end
        else if Request.Contains('SET') then
        begin
          Response := TEncoding.UTF8.GetBytes('+OK'#13#10);
        end
        else
          Response := TEncoding.UTF8.GetBytes('-ERR Unknown'#13#10);
        AConnection.Send(Response);
      end;

    Server.Bind('127.0.0.1', 0);
    Server.Start;

    Cache := TRedisCacheStore.Create('127.0.0.1', Server.ListenPort);
    
    Should(Cache.TryGet('mykey', ResValue)).BeTrue;
    Should(ResValue).Be('cached_value');

    Cache.SetValue('otherkey', 'val', 10);
  finally
    Server.Free;
  end;
end;

procedure TDextRedisCacheStoreTests.CacheStore_ShouldClearKeys;
var
  Server: TDextTcpServer;
  Cache: ICacheStore;
  Cleared: Boolean;
begin
  Server := TDextTcpServer.Create;
  try
    Cleared := False;
    Server.OnDataSpan :=
      procedure(const AConnection: ITcpConnection; const AData: TByteSpan)
      var
        Request: string;
        Response: TBytes;
      begin
        Request := AData.ToString;
        if Request.Contains('FLUSHDB') then
        begin
          Cleared := True;
          Response := TEncoding.UTF8.GetBytes('+OK'#13#10);
        end
        else
          Response := TEncoding.UTF8.GetBytes('-ERR Unknown'#13#10);
        AConnection.Send(Response);
      end;

    Server.Bind('127.0.0.1', 0);
    Server.Start;

    Cache := TRedisCacheStore.Create('127.0.0.1', Server.ListenPort);
    Cache.Clear;
    Should(Cleared).BeTrue;
  finally
    Server.Free;
  end;
end;

initialization
  TTestRunner.RegisterFixture(TDextRedisParserTests);
  TTestRunner.RegisterFixture(TDextRedisClientTests);
  TTestRunner.RegisterFixture(TDextRedisCacheStoreTests);

end.
