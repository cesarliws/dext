# Dext SSL/HTTPS Example

This example demonstrates how to enable and configure SSL (HTTPS) in a Dext Web application.

## Prerequisites

1.  **Dext.inc**: Ensure `DEXT_ENABLE_SSL` is defined in `Sources\Dext.inc`.
2.  **Libraries**:
    *   For **OpenSSL (Default)**: You need `libeay32.dll` and `ssleay32.dll` (OpenSSL 1.0.2u or compatible) in your application's folder.
    *   For **Taurus TLS**: You need the Taurus TLS libraries and correct OpenSSL 1.1.x/3.x DLLs as specified by the Taurus project. Ensure `DEXT_ENABLE_TAURUS_TLS` is defined in `Dext.inc`.
3.  **Certificates**: You need a certificate file (`.crt` or `.pem`) and a private key file (`.key`). For local testing, you can generate self-signed ones.

## Configuration

SSL is configured via the `Server` section in `appsettings.json`:

```json
{
  "Server": {
    "Port": 8080,
    "UseHttps": "true",
    "SslProvider": "OpenSSL",
    "SslCert": "server.crt",
    "SslKey": "server.key",
    "SslRootCert": ""
  }
}
```

### Settings Description
*   `UseHttps`: `true` to enable SSL, `false` for HTTP only.
*   `SslProvider`: 
    *   `OpenSSL` (Default): Uses Indy's native OpenSSL 1.0.x implementation.
    *   `Taurus`: Uses the Taurus TLS implementation (supports OpenSSL 1.1x / 3.x).
*   `SslCert`: Path to your certificate file.
*   `SslKey`: Path to your private key file.
*   `SslRootCert`: (Optional) Path to the root certificate/bundle.

## Self-Signed Certificate Generation (Quick Tip)

You can use OpenSSL to generate a self-signed certificate for testing:

```bash
openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes
```

## Running the Example

1.  Build the project.
2.  Ensure the DLLs and `.crt`/`.key` files are in the same directory as the executable.
3.  Run the application.
4.  Access `https://localhost:8080`.
