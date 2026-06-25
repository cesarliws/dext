# Dext HTTP/2 - gRPC Unary Example & Test

This directory demonstrates how to run a mockup gRPC unary request over plain-text HTTP/2 (`h2c`) against the Dext HTTP/2 implementation.

## How it works

gRPC mandates HTTP/2 transport where:
1. **Request Headers**: A `HEADERS` frame is sent with `content-type: application/grpc`.
2. **Request Body**: A `DATA` frame containing a 5-byte Length-Prefixed Message header (`1-byte compressed flag` + `4-byte big-endian length`) followed by the Protobuf payload.
3. **Response Headers**: HTTP status `200` and `content-type: application/grpc`.
4. **Response Body**: Length-Prefixed message response body.
5. **Trailers**: A trailing `HEADERS` frame containing status (`grpc-status`, `grpc-message`) and `END_STREAM`.

---

## Running the Mock gRPC Unary Test

Since gRPC relies on strict binary packaging and HTTP/2 prior-knowledge, standard tools need custom configuration. We have prepared two ways to execute this test:

### Option A: Using `test_grpc.ps1` (PowerShell)

A PowerShell script `test_grpc.ps1` is provided to generate the binary payload and dispatch it over HTTP/2.

1. Start the example server:
   ```powershell
   cd Examples\02-Web\Web.Http2Framing
   ..\..\Output\Web.Http2FramingExample.exe
   ```
2. In another terminal, load the required assembly and run the test script:
   ```powershell
   powershell -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Net.Http; & .\test_grpc.ps1"
   ```

### Option B: Using `curl` (Recommended)

Using the built-in script helpers or direct command line, you can generate the binary file and pipe it to `curl`:

1. Start the example server:
   ```powershell
   cd Examples\02-Web\Web.Http2Framing
   ..\..\Output\Web.Http2FramingExample.exe
   ```
2. Open another terminal and generate the binary payload file:
   ```powershell
   powershell -ExecutionPolicy Bypass -Command "`$payload = [System.Text.Encoding]::UTF8.GetBytes('DelphiDeveloper'); `$msg = New-Object byte[] (5 + `$payload.Length); `$msg[0] = 0; `$msg[1] = 0; `$msg[2] = 0; `$msg[3] = 0; `$msg[4] = [byte](`$payload.Length); [System.Array]::Copy(`$payload, 0, `$msg, 5, `$payload.Length); [System.IO.File]::WriteAllBytes('grpc_request.bin', `$msg)"
   ```
3. Send the request using `curl` with HTTP/2 prior knowledge and binary data:
   ```cmd
   curl.exe --http2-prior-knowledge -H "content-type: application/grpc" -X POST http://localhost:8443/grpc.mock.MockService/MockMethod --data-binary @grpc_request.bin --output grpc_response.bin --trace-ascii trace_grpc.log
   ```

---

## Verifying the Output

Upon successful execution, the HTTP/2 framing exchange trace will be outputted to `trace_grpc.log`. 

- **Request body (`trace_grpc.log`)**:
  ```
  => Send data, 20 bytes (0x14)
  0000: .....DelphiDeveloper
  ```
- **Response status & content-type (`trace_grpc.log`)**:
  ```
  <= Recv header, 13 bytes (0xd)
  0000: HTTP/2 200 
  <= Recv header, 32 bytes (0x20)
  0000: content-type: application/grpc
  ```
- **Response body (`trace_grpc.log`)**:
  ```
  <= Recv data, 49 bytes (0x31)
  0000: ....,Hello, DelphiDeveloper! (Mock gRPC Response)
  ```
- **Response trailers (`trace_grpc.log`)**:
  ```
  <= Recv header, 16 bytes (0x10)
  0000: grpc-status: 0
  <= Recv header, 18 bytes (0x12)
  0000: grpc-message: OK
  ```
