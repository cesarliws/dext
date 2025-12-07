# Dext Fluent Async API

The **Dext Fluent Async API** (`Dext.Threading.Async`) provides a modern, fluent interface for handling asynchronous operations in Delphi. It simplifies complex threading scenarios, pipeline chaining, error handling, and UI synchronization, making your code cleaner and more robust.

## 🚀 Key Features

*   **Fluent Interface**: Chain operations naturally using `ThenBy`, `OnComplete`, and `OnException`.
*   **Pipeline Execution**: Pass results from one background task to the next automatically.
*   **Automatic UI Synchronization**: Callbacks (`OnComplete`, `OnException`) are automatically marshaled to the Main Thread, making UI updates safe and easy.
*   **Cancellation Support**: Integrated support for `ICancellationToken` to cancel running pipelines gracefully.
*   **Exception Handling**: robust error handling that captures exceptions from background threads and delivers them to the main thread.

## 📦 Getting Started

Add the unit to your usage clause:
```pascal
uses
  Dext.Threading.Async;
```

### 1. Simple Asynchronous Task
Run a function in a background thread and handle the result on the main thread.

```pascal
TAsyncTask.Run<Integer>(
  function: Integer
  begin
    // This runs in a background thread
    Sleep(1000); 
    Result := 42; 
  end)
.OnComplete(
  procedure(Value: Integer)
  begin
    // This runs on the MAIN THREAD
    ShowMessage('Result: ' + Value.ToString);
  end)
.Start;
```

### 2. Chaining Operations (The Pipeline)
You can chain multiple operations. The result of one step is passed as the input to the next.

```pascal
TAsyncTask.Run<Integer>(
  function: Integer
  begin
    // Step 1: Expensive calculation
    Result := 10; 
  end)
.ThenBy<Integer>(
  function(Input: Integer): Integer
  begin
    // Step 2: Transform the data
    Result := Input * 2; // Returns 20
  end)
.ThenBy<string>(
  function(Input: Integer): string
  begin
    // Step 3: Format result
    Result := 'Final Value: ' + Input.ToString;
  end)
.OnComplete(
  procedure(Result: string)
  begin
    // Final Output on UI
    Label1.Caption := Result;
  end)
.Start;
```

### 3. Handling Exceptions
If an exception occurs at any step in the pipeline, execution stops, and the `OnException` callback is triggered on the main thread.

```pascal
TAsyncTask.Run<Integer>(
  function: Integer
  begin
    raise Exception.Create('Database connection failed!');
  end)
.ThenBy<string>(
  function(Input: Integer): string
  begin
    // This will NOT run
    Result := 'Success';
  end)
.OnException(
  procedure(E: Exception)
  begin
    // Handle error safely on Main Thread
    ShowMessage('Error: ' + E.Message);
  end)
.Start;
```

### 4. Cancellation Support
You can cancel a running pipeline using a `TCancellationTokenSource`.

```pascal
var
  CTS: TCancellationTokenSource; // from Dext.Core.CancellationToken
begin
  CTS := TCancellationTokenSource.Create;
  
  TAsyncTask.Run<Integer>(
    function: Integer
    begin
      // Simulating long work
      Sleep(5000); 
      Result := 100;
    end)
  .WithCancellation(CTS.Token) // Attach token
  .OnComplete(
    procedure(Val: Integer)
    begin
      ShowMessage('Completed');
    end)
  .OnException(
    procedure(E: Exception)
    begin
      if E is EOperationCancelled then
        ShowMessage('Task was cancelled!')
      else
        ShowMessage('Error: ' + E.Message);
    end)
  .Start;
  
  // Call this elsewhere to cancel
  CTS.Cancel;
end;
```

### 5. Using Procedures (Void Tasks)
You can also run tasks that don't return a value.

```pascal
TAsyncTask.Run(
  procedure
  begin
    // Do some background work
    Log('Working...');
  end)
.ThenBy(
  procedure(Success: Boolean) // Receives Success boolean
  begin
    Log('Work done');
  end)
.Start;
```

## ⚠️ Important Notes

1.  **Start()**: You must call `.Start` at the end of the chain to begin execution.
2.  **Thread Safety**: Code inside `.Run` and `.ThenBy` runs in a **Background Thread**. Do not access UI components directly from these methods.
3.  **UI Updates**: Code inside `.OnComplete` and `.OnException` runs in the **Main Thread**. This is the only safe place to update the UI.
4.  **TAsyncTask<T>**: Returns an `IAsyncTask` interface (which inherits from `ITask`). You can hold a reference to it if needed.

---
*Built with ❤️ for the Dext Framework.*
