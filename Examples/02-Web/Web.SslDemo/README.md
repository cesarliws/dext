# Dext SSL/HTTPS Example

This example demonstrates how to enable and configure SSL (HTTPS) in a Dext Web application using either the **Native Windows Kernel (`http.sys`)** or **Socket-based Engines (Indy/OpenSSL/Taurus)**.

---

## 🚀 Engine Options: HttpSys vs Socket Engines

| Feature | Windows `http.sys` Native Server | Socket Engines (Indy / OpenSSL / Taurus) |
|---|---|---|
| **TLS Processing** | Processed natively inside **Windows Kernel (SChannel)** | Processed inside **User-Mode Application** |
| **Performance** | Ultra High (Zero-Copy Kernel mode) | High |
| **Certificates** | Managed by Windows Certificate Store | Specified via `.crt` / `.key` file paths |
| **HTTPS Setup** | Requires port binding (`dext dev-certs` or `netsh`) | Managed directly inside `appsettings.json` |

---

## 1. Native Windows Kernel Server (`http.sys`) Setup

When running with `.UseNativeServer` on Windows, `http.sys` delegates TLS decryption directly to the OS Kernel (SChannel).

### Option A: Automated Setup via Dext CLI (Recommended)

Run the Dext CLI in your terminal as Administrator to generate certificates, trust them in Windows, and bind the HTTPS port in the Kernel automatically:

```bash
dext dev-certs https --trust
```

Output:
```text
Generating 100% native development HTTPS certificate via Windows CryptoAPI...
[SUCCESS] Native Certificate X.509 generated at: server.crt
[SUCCESS] Native Private Key generated at: server.key
[SUCCESS] Native PKCS#12 Bundle generated at: server.pfx
[SUCCESS] Certificate trusted in Windows Root & My Store!
[SUCCESS] http.sys Kernel SSL binding completed for port 8080!
[COMPLETED] Local HTTPS Certificate is ready for development!
```

---

### Option B: Manual Setup (Windows Admin Command Prompt)

If you prefer to configure the Kernel binding manually:

1. **Import the PKCS#12 (`.pfx`) Bundle with Private Key into `LocalMachine\My`:**
   ```powershell
   Import-PfxCertificate -FilePath "server.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password (ConvertTo-SecureString "dba" -AsPlainText -Force)
   ```

2. **Bind the Certificate Hash to your Port in Windows Kernel via `netsh`:**
   ```cmd
   netsh http add sslcert ipport=0.0.0.0:8080 certhash=YOUR_SHA1_THUMBPRINT appid={4f3b2c10-8a9b-4d7e-8f12-3456789abcde}
   ```
   *Replace `YOUR_SHA1_THUMBPRINT` with your 40-character certificate thumbprint (without spaces).*

3. **Verify the Kernel binding:**
   ```cmd
   netsh http show sslcert ipport=0.0.0.0:8080
   ```

---

## 2. Configuration (`appsettings.json`)

```json
{
  "Server": {
    "Port": 8080,
    "UseHttps": "true",
    "SslProvider": "HttpSys",
    "SslCertHash": "3CBD4DEA9E9415FA7D3A24A380F6964CE38B83EA",
    "SslCert": "server.crt",
    "SslKey": "server.key"
  }
}
```

---

## 3. Running the Example

1. Open your terminal as **Administrator** (required by Windows for `http.sys` HTTPS listeners).
2. Execute `Web.SslDemo.exe`.
3. Open `https://localhost:8080` in your web browser!

---

## References & Further Reading

- [Dext Framework Documentation](../../README.md)
- [Microsoft Windows Http.sys Kernel Architecture](https://learn.microsoft.com/en-us/windows/win32/http/http-server-api-portal)
