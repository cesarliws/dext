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
{                                                                           }
{  Author:  Cesar Romero                                                    }
{  Created: 2026-02-24                                                      }
{                                                                           }
{  Unit Tests for Dext.Collections                                          }
{  Covers: IList<T>, TList<T>, IDextDictionary<K,V>, TDextDictionary<K,V>, }
{  TRawList, TRawDictionary, TCollections factory, enumerators              }
{                                                                           }
{***************************************************************************}
program TestCollections;

{$APPTYPE CONSOLE}

uses
  Dext.MM,
  System.SysUtils,
  Dext.Utils,
  Dext.Testing,
  Dext.Collections,
  Dext.Collections.Dict,
  Dext.Collections.RawOrderedDict in '..\..\Sources\Core\Dext.Collections.RawOrderedDict.pas',
  Dext.Collections.OrderedDict in '..\..\Sources\Core\Dext.Collections.OrderedDict.pas',
  TestCollections.RawList in 'TestCollections.RawList.pas',
  TestCollections.Lists in 'TestCollections.Lists.pas',
  TestCollections.Dictionaries in 'TestCollections.Dictionaries.pas',
  TestCollections.OrderedDictionaries in 'TestCollections.OrderedDictionaries.pas',
  TestCollections.Factory in 'TestCollections.Factory.pas',
  TestCollections.Frozen in 'TestCollections.Frozen.pas',
  TestCollections.Vector in 'TestCollections.Vector.pas',
  TestCollections.Concurrent in 'TestCollections.Concurrent.pas',
  TestCollections.Channels in 'TestCollections.Channels.pas',
  TestCollections.Algorithms in 'TestCollections.Algorithms.pas',
  TestCollections.Comparers in 'TestCollections.Comparers.pas',
  TestCollections.QueuesAndStacks in 'TestCollections.QueuesAndStacks.pas',
  TestCollections.Robustness in 'TestCollections.Robustness.pas',
  TestCollections.PersonList in 'TestCollections.PersonList.pas';

begin
  SetConsoleCharSet;
  try
    WriteLn;
    WriteLn('=== Dext.Collections Unit Tests ===');
    WriteLn;

    RunTests(
      TTest.Configure
        .Verbose
        .RegisterFixtures([
          TRawListTests,
          TListBasicTests,
          TestCollections.Lists.TListStringTests,
          TListInterfaceTests,
          TListOwnershipTests,
          TListEnumeratorTests,
          TListLinqTests,
          TListIObjectListTests,
          TListManagedRecordTests,
          TDictionaryBasicTests,
          TDictionaryStringKeyTests,
          TDictionaryOwnershipTests,
          TDictionaryStressTests,
          TDictionaryEnumeratorTests,
          TDictionaryInterfaceTests,
          TDictionaryManagedRecordTests,
          TDictionaryFloatKeyTests,
          TOrderedDictBasicTests,
          TOrderedDictOrderTests,
          TOrderedDictEdgeTests,
          TOrderedDictTypeTests,
          TOrderedDictOwnershipTests,
          TOrderedDictStressTests,
          TCollectionsFactoryTests,
          TFactoryTests,
          TFrozenDictionaryTests,
          TVectorTests,
          TConcurrentDictionaryTests,
          TChannelTests,
          TAlgorithmsTests,
          TComparerTests,
          TTestQueuesAndStacks,
          TRobustnessTests,
          TListPersonTests
        ]));
  except
    on E: Exception do
    begin
      WriteLn('FATAL ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
  ConsolePause;
end.
