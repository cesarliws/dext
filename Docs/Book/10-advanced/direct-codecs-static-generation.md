# Direct Codecs & Static Generation

S54 adds a reusable codec layer for DTOs marked with `[GrpcMessage]` and `[ProtoMember]`.

## Usage

Generate a `.proto` file:

```bash
dext codecs proto --unit C:\path\MyContract.pas --out C:\path\MyContract.proto
```

Generate static Pascal readers and writers:

```bash
dext codecs generate --unit C:\path\MyContract.pas --out C:\path\MyContract.DextCodecs.pas
```

The generator covers:

- native scalar fields
- `string` and `TBytes`
- nested classes
- `IList<T>` with scalar and object elements

## Current limits

- The contract must use stable `[GrpcMessage]` and `[ProtoMember]` tags.
- The static path only handles the native types supported by Dext's shared type model.
- Generic collections outside `IList<T>` still follow the RTTI fallback.
- Direct offset access depends on a physical backing field, so calculated properties remain on the RTTI path.

## Why it matters

The same metadata layer can now feed:

- gRPC / protobuf
- REST / JSON
- ORM hydration
- remote `TEntityDataSet` sync

---

[← README](README.md) | [Networking →](../12-networking/grpc.md)
