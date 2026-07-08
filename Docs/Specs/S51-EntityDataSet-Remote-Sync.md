# 📑 S51: EntityDataSet Remote Sync Specification

**Status:** ✅ Implemented  
**Owner:** Cesar Romero & Engineering Team  
**Reviewers:** Architecture Team  
**Created:** 2026-07-07  
**Last Updated:** 2026-07-07
**Dependencies:** S02 (gRPC), S20 (Fluent REST)

---

## 1. Goal

Provide an out-of-the-box client-server synchronization mechanism for
TEntityDataSet, allowing client applications to load, track modifications
(DML operations), and persist changes back to the server.

---

## 2. Architecture & Design

The solution consists of three main components:

1. **Native Change-Log (Client)**: Tracks row states (Insert, Update, Delete)
   inside `TEntityDataSet` without relying on fragile external event slots.
2. **REST agreed endpoints (Server)**: Auto-registers routes to fetch datasets
   and apply the accumulated delta payloads.
3. **Transport Optimization (Network)**: Decompresses gzip/deflate response
   streams transparently in `TRestClient`.

---

## 3. Wire Contract

### 3.1. Delta Payload (Client to Server)

```json
{
  "entity": "TCustomer",
  "changes": [
    {
      "state": "inserted",
      "values": { "Name": "New Customer", "Score": 100 }
    },
    {
      "state": "modified",
      "key": { "Id": 42 },
      "values": { "Score": 105 }
    },
    {
      "state": "deleted",
      "key": { "Id": 43 }
    }
  ]
}
```

### 3.2. Response Envelope (Server to Client)

```json
[
  {
    "index": 0,
    "success": true,
    "errorMessage": "",
    "keys": { "Id": 44 }
  }
]
```

---

## 4. Backlog & Future Phases (Phase 2)

The following items are defined for Phase 2:

1. **Local Rollback (`RejectChanges`)**: Add native support to discard
   uncommitted client modifications.
2. **Binary Content Negotiation**: Support `application/x-dext-rows` using
   the zero-copy `TByteSpan` reader to bypass JSON parsing overhead.
3. **gRPC Provider Mapping**: Bridge the dataset sync provider interfaces
   to the gRPC dispatcher (`TEntitygRpcProvider<T>`).
