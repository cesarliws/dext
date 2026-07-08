# 📑 S53: Cloud Object Storage & Essential Services Specification

**Status:** 📝 Draft  
**Owner:** Cesar Romero & Engineering Team  
**Reviewers:** Architecture Team, Community  
**Created:** 2026-07-08  
**Last Updated:** 2026-07-08  
**Dependencies:** S20 (Fluent REST & HTTP Engine)

---

## 1. Goal

Establish a unified, high-performance, and asynchronous cloud storage interface 
(`IDextStorageProvider`) supporting **S3-Compatible Object Storage** (AWS S3, 
Oracle Cloud Infrastructure - OCI, MinIO, Cloudflare R2) and laying out the 
architecture for native Azure Blob Storage. 

Additionally, this spec maps the future cloud integrations backlog (Queues, 
Email, Document DBs) to serve as a guideline for enterprise contributions.

---

## 2. Technical Architecture: Storage Provider

To prevent vendor lock-in, Dext exposes a generic storage interface. 
Applications write code against the interface, and the concrete provider is 
configured at startup via dependency injection.

```
                  ┌──────────────────────┐
                  │ IDextStorageProvider │
                  └──────────────────────┘
                             ▲
              ┌──────────────┴──────────────┐
              │                             │
 ┌────────────────────────┐    ┌────────────────────────┐
 │ TDextS3StorageProvider │    │ TDextAzureBlobProvider │
 └────────────────────────┘    └────────────────────────┘
  (AWS, OCI, MinIO, R2)            (Azure Storage Accounts)
```

### 2.1 Unified Storage Interface

```pascal
type
  TDextStorageObject = record
    Key: string;
    Size: Int64;
    LastModified: TDateTime;
    ContentType: string;
  end;

  IDextStorageProvider = interface
    ['{F6253457-3B2D-4E90-95B7-1BE526EAF3D1}']
    function UploadAsync(
      const ABucket, AKey: string; 
      Stream: TStream;
      const AContentType: string = ''
    ): ITask<Boolean>;
    
    function DownloadAsync(
      const ABucket, AKey: string; 
      Stream: TStream
    ): ITask<Boolean>;
    
    function DeleteAsync(
      const ABucket, AKey: string
    ): ITask<Boolean>;
    
    function ListObjectsAsync(
      const ABucket: string; 
      const APrefix: string = ''
    ): ITask<TArray<TDextStorageObject>>;
    
    function GetPresignedUrl(
      const ABucket, AKey: string; 
      ExpiryMinutes: Integer
    ): string;
  end;
```

---

## 3. Phase 1: S3-Compatible Client (AWS, OCI, MinIO)

The S3 implementation must support:
1. **Path-Style vs Virtual-Hosted-Style addressing**:
   - *Path-Style*: `https://endpoint.com/bucket-name/key` (default for MinIO/OCI).
   - *Virtual-Hosted*: `https://bucket-name.endpoint.com/key` (default for AWS S3).
2. **Signature Version 4 (SigV4)**: Implementing AWS request signing protocol.

### Config Interface

```pascal
type
  TDextS3Config = record
    AccessKey: string;
    SecretKey: string;
    Region: string;
    Endpoint: string; // Custom endpoint (e.g. Oracle OCI, MinIO)
    UsePathStyle: Boolean;
  end;
```

---

## 4. Phase 2 & Enterprise Cloud Backlog

The following abstractions are planned for future waves:

### 4.1 Cloud Messaging (Queues)
* **Goal**: High-throughput message queuing.
* **Interface**: `IDextQueueProvider`
* **Implementations**:
  - `TDextServiceBusProvider` (Azure Service Bus)
  - `TDextSqsProvider` (AWS SQS)

### 4.2 Transactional Email
* **Goal**: SMTP-free transactional email delivery.
* **Interface**: `IDextEmailProvider`
* **Implementations**:
  - `TDextSendGridProvider` (SendGrid API)
  - `TDextSesProvider` (AWS SES API)

### 4.3 Managed Document DBs (NoSQL)
* **Goal**: Schema-less JSON/BSON document management.
* **Interface**: `IDextDocumentDbProvider`
* **Implementations**:
  - `TDextMongoAtlasProvider` (MongoDB Atlas wire protocol integration)
  - `TDextCosmosDbProvider` (Azure Cosmos DB NoSQL API)

---

## 5. Verification Plan

### Automated Tests
- Mock integration tests validating AWS Signature V4 generator.
- Local integration tests using MinIO container.
- Oracle Cloud OCI Object Storage compatibility tests.

### Manual Verification
- Benchmarking upload speeds of bulk files (fiscal PDFs/XMLs) comparing Dext 
  S3 client with default AWS Python/C# SDKs.
