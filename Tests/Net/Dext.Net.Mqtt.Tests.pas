{***************************************************************************}
{                                                                           }
{           Dext Framework                                                  }
{                                                                           }
{           Copyright (C) 2025 Cesar Romero & Dext Contributors             }
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
unit Dext.Net.Mqtt.Tests;

interface

uses
  System.SysUtils,
  System.Classes,
  Dext.Testing,
  Dext.Testing.Fluent,
  Dext.Net.Mqtt;

type
  [TestFixture('Dext.Net MQTT')]
  TDextMqttTests = class
  public
    [Test]
    procedure Trie_ShouldMatchExactTopics;
    [Test]
    procedure Trie_ShouldMatchWildcards;
    [Test]
    procedure Client_Broker_ShouldPublishSubscribe;
  end;

implementation

procedure TDextMqttTests.Trie_ShouldMatchExactTopics;
var
  trie: TDextMqttTopicTrie;
  matches: TArray<string>;
begin
  trie := TDextMqttTopicTrie.Create;
  try
    trie.AddSubscription('sensors/kitchen/temp', 'clientA');
    trie.AddSubscription('sensors/bedroom/temp', 'clientB');

    matches := trie.MatchTopic('sensors/kitchen/temp');
    Should(Length(matches)).Be(1);
    Should(matches[0]).Be('clientA');

    matches := trie.MatchTopic('sensors/bedroom/temp');
    Should(Length(matches)).Be(1);
    Should(matches[0]).Be('clientB');

    matches := trie.MatchTopic('sensors/kitchen/humidity');
    Should(Length(matches)).Be(0);
  finally
    trie.Free;
  end;
end;

procedure TDextMqttTests.Trie_ShouldMatchWildcards;
var
  trie: TDextMqttTopicTrie;
  matches: TArray<string>;
begin
  trie := TDextMqttTopicTrie.Create;
  try
    // Single level wildcard (+)
    trie.AddSubscription('sensors/+/temp', 'clientPlus');
    // Multi level wildcard (#)
    trie.AddSubscription('sensors/#', 'clientHash');

    matches := trie.MatchTopic('sensors/kitchen/temp');
    Should(Length(matches)).Be(2); // Matches both + and #

    matches := trie.MatchTopic('sensors/garden/humidity');
    Should(Length(matches)).Be(1); // Matches # only
    Should(matches[0]).Be('clientHash');
  finally
    trie.Free;
  end;
end;

procedure TDextMqttTests.Client_Broker_ShouldPublishSubscribe;
var
  server: TDextMqttServer;
  client: TDextMqttClient;
  receivedMessage: TMqttMessage;
  msgReceived: Boolean;
  i: Integer;
begin
  server := TDextMqttServer.Create;
  try
    server.Bind('127.0.0.1', 0);
    server.Start;

    client := TDextMqttClient.Create;
    try
      client.Connect('127.0.0.1', server.ListenPort, 'testClient');

      msgReceived := False;
      client.OnMessageReceived :=
        procedure(const AMessage: TMqttMessage)
        begin
          receivedMessage := AMessage;
          msgReceived := True;
        end;

      client.Subscribe('test/topic');
      Sleep(100); // Give subscription registration time

      client.Publish('test/topic', TBytes.Create($4D, $51, $54, $54));

      // Wait for dispatch
      for i := 1 to 20 do
      begin
        if msgReceived then Break;
        Sleep(50);
      end;

      Should(msgReceived).BeTrue;
      Should(receivedMessage.Topic).Be('test/topic');
      Should(Length(receivedMessage.Payload)).Be(4);
      Should(receivedMessage.Payload[0]).Be($4D);
      Should(receivedMessage.Payload[1]).Be($51);
      Should(receivedMessage.Payload[2]).Be($54);
      Should(receivedMessage.Payload[3]).Be($54);
    finally
      client.Free;
    end;
  finally
    server.Free;
  end;
end;

initialization
  TTestRunner.RegisterFixture(TDextMqttTests);

end.
