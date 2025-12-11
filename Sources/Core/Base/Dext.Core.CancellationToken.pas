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
{  Created: 2025-12-08                                                      }
{                                                                           }
{***************************************************************************}
unit Dext.Core.CancellationToken;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils;

type
  /// <summary>
  ///   Interface for a cancellation token.
  ///   Represents a token that can be monitored for cancellation.
  ///   Implemented as an interface for automatic memory management via reference counting.
  /// </summary>
  ICancellationToken = interface(IInterface)
    ['{F774136C-B0E3-40A6-A223-9D5C93C39794}']
    /// <summary>
    ///   Indicates whether cancellation has been requested.
    /// </summary>
    function GetIsCancellationRequested: Boolean;
    /// <summary>
    ///   Indicates whether cancellation has been requested.
    /// </summary>
    property IsCancellationRequested: Boolean read GetIsCancellationRequested;

    /// <summary>
    ///   Throws an exception if cancellation has been requested.
    /// </summary>
    /// <exception cref="EOperationCancelled">
    ///   Thrown when cancellation has been requested.
    /// </exception>
    procedure ThrowIfCancellationRequested;

    /// <summary>
    ///   Waits for the cancellation signal.
    ///   Allows a thread to wait passively for the cancellation signal.
    /// </summary>
    function WaitForCancellation(Timeout: Cardinal = INFINITE): TWaitResult;
  end;

  // Concrete class that implements the ICancellationToken interface.
  TCancellationToken = class(TInterfacedObject, ICancellationToken)
  strict private
    FCancellationEvent: TEvent; // Reference to the Source's TEvent
    FIsCancellationRequestedFunc: TFunc<Boolean>;
  public
    // Constructor receives the function to check the state and the Source's TEvent
    constructor Create(IsCancellationRequestedFunc: TFunc<Boolean>;
      CancellationEvent: TEvent);

    function GetIsCancellationRequested: Boolean;
    function WaitForCancellation(Timeout: Cardinal): TWaitResult;
    procedure ThrowIfCancellationRequested;

    property IsCancellationRequested: Boolean read GetIsCancellationRequested;
  end;

  /// <summary>
  ///   Signals to an ICancellationToken that it should be canceled.
  /// </summary>
  TCancellationTokenSource = class
  strict private
    FIsCancellationRequested: Boolean;
    // Internal event to signal cancellation
    FEvent: TEvent;
    // Stores the token's interface
    FToken: ICancellationToken;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Communicates a request for cancellation.
    /// </summary>
    procedure Cancel;
    /// <summary>
    ///   Resets the cancellation state to not-cancelled.
    /// </summary>
    procedure Reset;
    /// <summary>
    ///   Returns the ICancellationToken associated with this source.
    /// </summary>
    function GetToken: ICancellationToken;
    /// <summary>
    ///   Indicates whether cancellation has been requested for this source.
    /// </summary>
    property IsCancellationRequested: Boolean read FIsCancellationRequested;
    property Token: ICancellationToken read GetToken;
  end;

implementation

{ TCancellationTokenSource }

constructor TCancellationTokenSource.Create;
begin
  inherited Create;
  FIsCancellationRequested := False;
  // Manual reset event, initially non-signaled
  FEvent := TEvent.Create(nil, True, False, '');
  // Create the token, passing the check logic and the event.
  // This avoids a reference cycle.
  FToken := TCancellationToken.Create(
    // Anonymous function that checks the Source's state
    function: Boolean
    begin
      Result := FIsCancellationRequested;
    end,
    // Pass the event so the token can wait on it
    FEvent
  );
end;

destructor TCancellationTokenSource.Destroy;
begin
  Cancel;
  // FToken is an interface and will be released when there are no more
  // external references. FEvent must be freed explicitly.
  FEvent.Free;
  inherited;
end;

procedure TCancellationTokenSource.Reset;
begin
  FIsCancellationRequested := False
end;

procedure TCancellationTokenSource.Cancel;
begin
  if not FIsCancellationRequested then
  begin
    FIsCancellationRequested := True;
    // Signal the cancellation event for any waiting threads
    FEvent.SetEvent;
  end;
end;

function TCancellationTokenSource.GetToken: ICancellationToken;
begin
  // Return the unique instance of the token's interface
  Result := FToken;
end;

{ TCancellationToken }

constructor TCancellationToken.Create(IsCancellationRequestedFunc:
  TFunc<Boolean>; CancellationEvent: TEvent);
begin
  inherited Create;
  FIsCancellationRequestedFunc := IsCancellationRequestedFunc;
  // Direct (strong) reference to the Source's TEvent
  FCancellationEvent := CancellationEvent;
end;

function TCancellationToken.GetIsCancellationRequested: Boolean;
begin
  // Call the lambda to check the Source's state
  Result := FIsCancellationRequestedFunc();
end;

procedure TCancellationToken.ThrowIfCancellationRequested;
begin
  if (not Assigned(Self)) or GetIsCancellationRequested then
    raise EOperationCancelled.Create('Operation cancelled!');
end;

function TCancellationToken.WaitForCancellation(Timeout: Cardinal): TWaitResult;
begin
  // Wait on the Source's TEvent to be notified of cancellation
  Result := FCancellationEvent.WaitFor(Timeout);
end;

end.

