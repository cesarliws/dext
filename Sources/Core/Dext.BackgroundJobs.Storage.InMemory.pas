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

unit Dext.BackgroundJobs.Storage.InMemory;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Dext.BackgroundJobs.Intf;

type
  TInMemoryJobStorage = class(TInterfacedObject, IJobStorage)
  private
    FJobs: TThreadList<TJobInfo>;
  public
    class constructor Create;
    constructor Create;
    destructor Destroy; override;

    function Enqueue(const AJobType, AMethodName, AParamsJson: string; const AQueue: string = 'default'): string;
    function Schedule(const AJobType, AMethodName, AParamsJson: string; const AQueue: string; const AEnqueueAt: TDateTime): string;
    function GetNextJob(const AQueue: string; out AJob: TJobInfo): Boolean;
    procedure UpdateJobState(const AJobId: string; const AState: TJobState; const AErrorMessage: string = '');
    procedure RecordHeartbeat(const AJobId: string);
  end;

implementation

uses
  Dext.BackgroundJobs.Config;

{ TInMemoryJobStorage }

constructor TInMemoryJobStorage.Create;
begin
  inherited Create;
  FJobs := TThreadList<TJobInfo>.Create;
end;

destructor TInMemoryJobStorage.Destroy;
begin
  FJobs.Free;
  inherited;
end;

function TInMemoryJobStorage.Enqueue(const AJobType, AMethodName, AParamsJson: string; const AQueue: string): string;
begin
  Result := TGuid.NewGuid.ToString;
  var Job: TJobInfo;
  Job.Id := Result;
  Job.JobType := AJobType;
  Job.MethodName := AMethodName;
  Job.ParamsJson := AParamsJson;
  Job.State := jsEnqueued;
  Job.Queue := AQueue;
  Job.CreatedAt := Now;
  Job.EnqueueAt := Job.CreatedAt;
  Job.AttemptCount := 0;
  Job.LastHeartbeat := 0;
  Job.ErrorLog := '';
  
  FJobs.Add(Job);
end;

function TInMemoryJobStorage.Schedule(const AJobType, AMethodName, AParamsJson: string; const AQueue: string; const AEnqueueAt: TDateTime): string;
begin
  Result := TGuid.NewGuid.ToString;
  var Job: TJobInfo;
  Job.Id := Result;
  Job.JobType := AJobType;
  Job.MethodName := AMethodName;
  Job.ParamsJson := AParamsJson;
  Job.State := jsEnqueued;
  Job.Queue := AQueue;
  Job.CreatedAt := Now;
  Job.EnqueueAt := AEnqueueAt;
  Job.AttemptCount := 0;
  Job.LastHeartbeat := 0;
  Job.ErrorLog := '';
  
  FJobs.Add(Job);
end;

function TInMemoryJobStorage.GetNextJob(const AQueue: string; out AJob: TJobInfo): Boolean;
var
  List: TList<TJobInfo>;
  I: Integer;
  LNow: TDateTime;
  Job: TJobInfo;
begin
  Result := False;
  LNow := Now;
  List := FJobs.LockList;
  try
    for I := 0 to List.Count - 1 do
    begin
      Job := List[I];
      WriteLn(Format('  [InMemory Debug] Job: ID=%s, Queue=%s (exp=%s), State=%d (exp=%d), EnqueueAt=%f, LNow=%f',
        [Job.Id, Job.Queue, AQueue, Ord(Job.State), Ord(jsEnqueued), Job.EnqueueAt, LNow]));
      if (Job.Queue = AQueue) and (Job.State = jsEnqueued) and (Job.EnqueueAt <= LNow + (1.0 / 86400.0)) then
      begin
        Job.State := jsProcessing;
        Job.LastHeartbeat := LNow;
        List[I] := Job;
        AJob := Job;
        Exit(True);
      end;
    end;
  finally
    FJobs.UnlockList;
  end;
end;

procedure TInMemoryJobStorage.UpdateJobState(const AJobId: string; const AState: TJobState; const AErrorMessage: string);
var
  List: TList<TJobInfo>;
  I: Integer;
  Job: TJobInfo;
begin
  List := FJobs.LockList;
  try
    for I := 0 to List.Count - 1 do
    begin
      Job := List[I];
      if Job.Id = AJobId then
      begin
        Job.State := AState;
        if AState = jsFailed then
        begin
          Job.ErrorLog := AErrorMessage;
          Job.AttemptCount := Job.AttemptCount + 1;
        end;
        List[I] := Job;
        Break;
      end;
    end;
  finally
    FJobs.UnlockList;
  end;
end;

procedure TInMemoryJobStorage.RecordHeartbeat(const AJobId: string);
var
  List: TList<TJobInfo>;
  I: Integer;
  Job: TJobInfo;
begin
  List := FJobs.LockList;
  try
    for I := 0 to List.Count - 1 do
    begin
      Job := List[I];
      if Job.Id = AJobId then
      begin
        Job.LastHeartbeat := Now;
        List[I] := Job;
        Break;
      end;
    end;
  finally
    FJobs.UnlockList;
  end;
end;

class constructor TInMemoryJobStorage.Create;
begin
  TJobStorageRegistry.RegisterProvider('InMemory',
    function(const AConnectionString: string): TObject
    begin
      Result := TInMemoryJobStorage.Create;
    end);
end;

end.
