# Direct Codecs & Static Generation

S54 adds a shared codec planning layer used by protobuf, JSON, ORM hydration, and future generated codecs. The goal is to remove hot-path `TValue` and RTTI calls when a DTO or entity can be described by a validated field plan.

The runtime has three tiers:

- **RTTI fallback**: the compatibility path for dynamic or unsupported members.
- **Direct-offset codecs**: reads and writes validated physical fields through `Dext.Core.DirectAccess`.
- **Generated codecs**: Pascal readers, writers, and gRPC invokers registered in `TDextCodecRegistry`.

## Generate a `.proto`

```bash
dext codecs export-proto --unit C:\path\MyContract.pas --out C:\path\MyContract.proto
```

## Generate Pascal codecs

```bash
dext codecs generate --unit C:\path\MyContract.pas --out C:\path\MyContract.DextCodecs.pas
```

Add the generated unit to the application or package so its initialization section can register the codecs.

## Supported DTO Shape

The generator is designed for controlled Dext DTO/code-first contracts:

```pascal
uses
  Dext.Collections,
  Dext.Grpc.Attributes,
  Dext.Types.Nullable,
  Dext.Types.UUID;

type
  [GrpcMessage]
  TCustomerDto = class
  private
    FId: Integer;
    FName: string;
    FExternalId: TUUID;
    FTags: IList<Nullable<Integer>>;
  public
    [ProtoMember(1)]
    property Id: Integer read FId write FId;
    [ProtoMember(2)]
    property Name: string read FName write FName;
    [ProtoMember(3)]
    property ExternalId: TUUID read FExternalId write FExternalId;
    [ProtoMember(4)]
    property Tags: IList<Nullable<Integer>> read FTags write FTags;
  end;
```

Currently covered shapes include native scalars, `string`, `TBytes`, `TGUID`, `TUUID`, nested `[GrpcMessage]` classes, `IList<T>`, `Nullable<T>`, `Prop<T>`, `Nullable<IList<T>>`, `IList<Nullable<T>>`, and `IList<Prop<T>>`.

## Direct-Offset Safety

Direct access is only used when `TDextTypeModel` validates a physical backing field and the native kind is supported. Managed types such as `string`, interfaces, dynamic arrays, object references, GUIDs, and UUIDs are assigned through typed helpers so reference counts and ownership rules remain intact.

Calculated properties, custom getters/setters, unsupported wrappers, ambiguous lists, and members with converters remain on the fallback path.

## Where It Helps

- **gRPC / protobuf**: generated readers/writers and direct protobuf mode avoid repeated RTTI calls.
- **JSON**: `TDextJson` can reuse the shared field plan for supported direct fields.
- **ORM hydration**: entity materialization can use the same plan while preserving converters and SmartProp/Nullable behavior.
- **EntityDataSet sync**: protobuf payloads benefit from the same object/list handling.

The largest gains are expected on Win32, where `TValue` and RTTI invocation costs are much higher. Win64 gains are workload-dependent and should be measured with the S54 benchmarks.

## Current Limits

- The CLI generator is pragmatic, not a full Delphi parser.
- Prefer DTOs with field-backed properties and stable `[ProtoMember]` tags.
- List ownership must be explicit and compatible with Dext Collections.
- `Lazy<T>` is not treated as a serializable data shape.
- Generated JSON codecs are a future optimization; JSON currently benefits from the shared direct plan.
- The IDE Expert surface is deferred and should provide eligibility/fallback diagnostics before broader generation is enabled.

---

[← README](README.md) | [Networking →](../12-networking/grpc.md)
