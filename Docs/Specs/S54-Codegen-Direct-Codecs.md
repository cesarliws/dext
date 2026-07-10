# S54: Direct Codecs & Static Code Generation

**Status:** Runtime Finalized; IDE Expert DX Deferred to S15  
**Owner:** Cesar Romero & Engineering Team  
**Created:** 2026-07-08  
**Depends on:** S02, S07, S15, S18, S20, S51  
**Enables:** high-performance gRPC, REST/JSON, ORM hydration, and EntityDataSet remote sync

---

## 0. Active Task List

This section tracks the concrete implementation slices that are being worked on or have already been closed. Keep it updated as the S54 evolves.

- [x] Build `Dext.Core.TypeModel` and the shared `TDextFieldPlan` model.
- [x] Add `Dext.Core.DirectAccess` helpers for safe offset reads and writes.
- [x] Move protobuf serialization to direct-offset mode for supported primitives, strings, nested objects, and lists.
- [x] Move `TDextJson` onto the shared codec plan for direct field access.
- [x] Move ORM hydration/materialization onto the shared codec plan for direct field access.
- [x] Add codec registry support for generated protobuf readers/writers and gRPC invokers.
- [x] Add CLI support for `codecs generate` and `.proto` export.
- [x] Add unit coverage for RTTI, direct, and generated protobuf compatibility.
- [x] Add unit coverage for JSON roundtrip and ORM converter roundtrip using nested objects and lists.
- [x] Add benchmark comparison cases for RTTI vs direct vs generated protobuf modes.
- [x] Capture updated baseline numbers in HISTORICAL_RESULTS.md after running the S54 benchmarks.
- [x] Extend the generated codec path for broader nested-list and SmartProp/Nullable edge cases.
  - Covers `Nullable<T>`, `Prop<T>`, `Nullable<IList<T>>`, `IList<Nullable<T>>`, `IList<Prop<T>>`, nested object lists, `TGUID`, `TUUID`, and matching `.proto` repeated type normalization.
- [ ] Expand the IDE Expert surface for codec eligibility, fallback diagnostics, and generation status.

### 0.1 Deferred Expert DX Scope

The S54 runtime and CLI generation work are considered finalized. IDE Expert work is intentionally deferred to a dedicated S15/S54 integration session so the UX can be designed as a cohesive developer experience instead of a thin wrapper over the CLI.

The Expert should provide:

- Codec discovery for `[GrpcMessage]`, `[ProtoMember]`, `[GrpcService]`, `[GrpcMethod]`, ORM `[Table]` entities, JSON DTOs, and REST request/response models.
- A Codecs dashboard grouped by project, unit, type, and service.
- Per-type status: RTTI fallback, direct-offset eligible, generated codec available, generated codec stale, unsupported, or error.
- Per-member diagnostics explaining fallback reasons, including custom getter/setter, converter attached, unsupported native kind, missing proto tag, ambiguous list element type, unsupported SmartProp/Nullable shape, non-field-backed property, and ownership ambiguity.
- A preview of generated Pascal codec units and `.proto` output before writing files.
- A deterministic regeneration workflow that calls `dext codecs generate` instead of implementing codegen inside the Expert.
- Buttons/actions for generate selected type, generate project codecs, export proto, open generated file, open diagnostics, and run S54 benchmarks.
- Integration with benchmark history, showing the latest local run and whether historical baselines are present in `Benchmarks/HISTORICAL_RESULTS.md`.
- Clear display of generated file paths, include paths, package requirements, and units that must be added to initialization.
- A "why not generated?" explanation for every type that remains on RTTI fallback.
- A "safe direct access" explanation for every member using offsets, including managed type assignment notes for strings/interfaces/dynamic arrays.
- A dry-run mode that reports planned changes without touching source files.
- YAML or project metadata persistence for reviewed generation settings, output folders, target modes, and excluded types.
- Git-friendly deterministic formatting and regeneration markers.
- Background execution with progress, compiler-style diagnostics, cancellation, and copied CLI command line for reproducibility.
- Compatibility checks for multiple Delphi targets, especially Win32/Win64 and older package folders.
- A one-click path from failed diagnostics to documentation explaining the relevant rule and recommended fix.

---
## 1. Context

S02 delivered the first complete gRPC/Protocol Buffers layer for Dext:

- `Dext.Serialization.Protobuf` maps `[GrpcMessage]` and `[ProtoMember]` classes to protobuf payloads.
- `Dext.Web.Grpc.Server` dispatches code-first services marked with `[GrpcService]` and `[GrpcMethod]`.
- `Dext.Entity.GrpcProvider` bridges gRPC calls to `TEntityDataSet` providers.
- The `Grpc.EntityDataSet.Demo` example validates the end-to-end path with `TCompany`, `FetchAll`, `ApplyChanges`, telemetry traces, and native server hosting.

The current runtime design is intentionally simple and correct enough for a first implementation, but the traces show a large Win32 penalty when serializing/deserializing 10,000 objects:

- Win64: `gRPC.Client.Deserialize` around 46 ms and `gRPC.Server.Serialize` around 20 ms.
- Win32: `gRPC.Fetch` around 1472 ms for the same logical workload.

The bottleneck is not protobuf itself. The hot path still crosses RTTI and `TValue` for every field access:

```pascal
Val := Handler.GetValue(Obj);
SerializeField(Stream, Key, Val);
...
Decoded := DeserializeField(Stream, WireType, Prop.PropertyType.Handle);
Handler.SetValue(Obj, Decoded);
```

For 10,000 objects with 5 mapped fields, this means 50,000 reads plus 50,000 writes through `TValue`, `TRttiProperty`, interface dispatch, conversion, and temporary managed values. Win64 masks part of that cost through register passing and better code generation. Win32 pays the full boxing/unboxing and stack-frame cost.

---

## 2. Goal

Create a reusable Dext codec architecture that can run in three tiers:

1. **RTTI compatible path:** current behavior, used as fallback and for dynamic scenarios.
2. **Direct offset path:** runtime-generated metadata reads/writes fields directly by memory offset when safe.
3. **Static generated path:** CLI/Expert-generated Pascal units contain strongly typed readers and writers with no RTTI and no `TValue` in the steady-state path.

The same metadata model must serve:

- gRPC/protobuf message serialization.
- REST/JSON serialization and model binding.
- ORM hydration/materialization.
- `TEntityDataSet` load/apply sync.
- Future binary transports such as MessagePack.

---

## 3. Current Implementation Assessment

### 3.1 Strengths

- S02 has a small and understandable surface: attributes, protobuf serializer, gRPC dispatcher, client/provider, and demo.
- The protobuf codec already handles primitive scalars, strings, booleans, nested classes, lists via `IObjectList`, and `TBytes`.
- `TGrpcMessageCodec` correctly isolates the 5-byte gRPC length-prefixed frame from the protobuf payload.
- Telemetry spans around encode/decode/serialize/deserialize give the exact hooks needed for benchmark-driven optimization.
- S07 already centralized reflection metadata through `TReflection`, `TTypeMetadata`, and `IPropertyHandler`.
- ORM metadata already has fields that point toward this design: `TPropertyMap.FieldOffset`, `FieldValueOffset`, `PropertyType`, and cached `TRttiProperty`.
- S15 already defines the IDE Expert as a visual shell that can call `dext.exe`, which is the right split for code generation.

### 3.2 Gaps

- `TProtobufSerializer` caches only tag-to-handler maps. It does not cache wire type, field kind, default behavior, encoded tag bytes, offsets, or specialized read/write functions.
- All property reads and writes still flow through `IPropertyHandler.GetValue/SetValue` and `TValue`.
- `DeserializeField` allocates `TValue` even when the target is a primitive field that could be written directly.
- Unknown field skipping is local to protobuf and should become a shared binary reader concern.
- Field order comes from dictionary keys, which is acceptable semantically but not ideal for deterministic output or CPU-cache-friendly iteration.
- There is no codec registry that lets gRPC/REST/ORM choose an optimized codec for a type.
- Service invocation still uses `TRttiMethod.Invoke`, so after protobuf is optimized the next hotspot will be method dispatch.
- The generic `TEntitygRpcProvider<T>` is still a basic bridge. The example uses a custom provider and HTTP POST via `THTTPClient`, not the final HTTP/2 streaming transport.

---

## 4. Design Principles

1. **Correctness first:** generated and direct codecs must produce the same wire format as the RTTI serializer.
2. **One metadata model:** do not create separate reflection maps for protobuf, JSON, ORM, and DataSet.
3. **Opt-in unsafe paths:** direct memory offsets are only used for proven-safe members.
4. **Generated code is an acceleration layer:** runtime reflection remains the compatibility baseline.
5. **Stable public API:** existing `[GrpcMessage]`, `[ProtoMember]`, `TDextJson`, `TEntityDataSet`, and ORM APIs continue to work.
6. **Benchmark gates:** every phase needs Win32 and Win64 measurements, not only correctness tests.

---

## 5. Core Abstractions

### 5.1 Native Field Kind

Introduce a compact native type enum independent from Delphi RTTI names:

```pascal
type
  TDextNativeKind = (
    nkUnknown,
    nkInt32,
    nkInt64,
    nkUInt32,
    nkUInt64,
    nkBoolean,
    nkSingle,
    nkDouble,
    nkDateTime,
    nkString,
    nkBytes,
    nkGuid,
    nkUuid,
    nkEnum,
    nkObject,
    nkList
  );
```

This becomes the shared bridge between protobuf wire type, JSON scalar behavior, ORM field type, dataset field creation, and direct memory access.

### 5.2 Field Access Plan

Add a plan record/class that represents a mapped member in a codec-friendly form:

```pascal
type
  TDextAccessMode = (amRtti, amDirectField, amGenerated);

  PDextFieldPlan = ^TDextFieldPlan;
  TDextFieldPlan = record
    Name: string;
    ExternalName: string;
    ProtoTag: Integer;
    NativeKind: TDextNativeKind;
    TypeInfo: PTypeInfo;
    ElementType: PTypeInfo;
    WireType: Byte;
    Offset: NativeInt;
    ValueOffset: NativeInt;
    HasValueOffset: NativeInt;
    IsNullable: Boolean;
    IsList: Boolean;
    IsObject: Boolean;
    AccessMode: TDextAccessMode;
    Handler: IPropertyHandler;
  end;
```

Important distinction:

- `Offset` points to the physical field when the member is a field or a property backed by a discoverable field.
- `ValueOffset` points inside SmartProp/Nullable records when the Dext wrapper is the physical field.
- `Handler` remains available for fallback and for properties with custom getters/setters.

### 5.3 Type Codec Plan

```pascal
type
  IDextTypeCodecPlan = interface
    ['{75C0DA38-9C8B-4B62-88A1-5849B3E6079F}']
    function GetTypeInfo: PTypeInfo;
    function GetFields: TArray<TDextFieldPlan>;
    function HasDirectAccess: Boolean;
    function HasGeneratedCodec: Boolean;
  end;
```

`TReflection.GetMetadata` should remain the base source, but a new `Dext.Core.TypeModel` unit should expose codec-oriented plans so Web/Data/Core do not couple directly to protobuf.

---

## 6. Direct Offset Runtime Path

### 6.1 Safe Eligibility Rules

Direct offset access is allowed when all are true:

- The member maps to a real instance field.
- The field type is a supported primitive, string, bytes, enum, object reference, list interface/object, `TGUID`, `TUUID`, or Dext Nullable/SmartProp with known inner layout.
- No custom getter/setter logic is required.
- No converter is attached that changes the logical value.
- The field is not a calculated property.
- The type is not a packed/aligned layout that the planner cannot validate.

Fallback to RTTI when any rule fails.

### 6.2 Direct Read/Write Helpers

Add pointer-level helpers in a low-level unit, for example `Dext.Core.DirectAccess`:

```pascal
type
  TDextDirectAccess = record
    class function ReadInt32(Instance: TObject; Offset: NativeInt): Integer; static; inline;
    class procedure WriteInt32(Instance: TObject; Offset: NativeInt; Value: Integer); static; inline;
    class function ReadString(Instance: TObject; Offset: NativeInt): string; static; inline;
    class procedure WriteString(Instance: TObject; Offset: NativeInt; const Value: string); static; inline;
  end;
```

Managed types must use assignment, not raw `Move`, so reference counts stay correct:

```pascal
PString(PByte(Instance) + Offset)^ := Value;
```

### 6.3 Protobuf Fast Serializer

Create a plan-driven serializer beside the current one:

```pascal
type
  TProtobufCodecMode = (pcmAuto, pcmRtti, pcmDirect, pcmGenerated);

  TProtobufSerializer = class
  public
    class function Serialize(Obj: TObject; Mode: TProtobufCodecMode = pcmAuto): TBytes; static;
    class procedure Deserialize(const Bytes: TBytes; Obj: TObject; Mode: TProtobufCodecMode = pcmAuto); static;
  end;
```

`pcmAuto` selection:

1. generated codec if registered;
2. direct offset codec if all required field plans are safe;
3. current RTTI serializer.

---

## 7. Static Generated Codecs

### 7.1 Generated Unit Shape

For a source unit containing `TCompany`, generate:

```pascal
unit Grpc.EntityDataSet.Demo.Main.Form.DextCodecs;

interface

uses
  Dext.Codecs.Registry,
  Dext.Serialization.Protobuf,
  Grpc.EntityDataSet.Demo.Main.Form;

procedure RegisterDextCodecs;

implementation

procedure Write_TCompany(Writer: TProtobufWriter; Obj: TCompany);
begin
  Writer.WriteInt32(1, Obj.Id);
  Writer.WriteString(2, Obj.Name);
  Writer.WriteString(3, Obj.Country);
  Writer.WriteBool(4, Obj.Active);
end;

procedure Read_TCompany(Reader: TProtobufReader; Obj: TCompany);
begin
  while Reader.ReadField do
    case Reader.Tag of
      1: Obj.Id := Reader.ReadInt32;
      2: Obj.Name := Reader.ReadString;
      3: Obj.Country := Reader.ReadString;
      4: Obj.Active := Reader.ReadBool;
    else
      Reader.SkipField;
    end;
end;

procedure RegisterDextCodecs;
begin
  TDextCodecRegistry.RegisterProtobuf<TCompany>(Write_TCompany, Read_TCompany);
end;

initialization
  RegisterDextCodecs;

end.
```

This path avoids RTTI metadata lookup, `IPropertyHandler`, `TValue`, dictionary iteration, and dynamic method/property invocation during serialization.

### 7.2 Registry

```pascal
type
  TProtobufWriteProc = procedure(Writer: TProtobufWriter; Obj: TObject);
  TProtobufReadProc = procedure(Reader: TProtobufReader; Obj: TObject);

  TDextCodecRegistry = class
  public
    class procedure RegisterProtobuf(AType: PTypeInfo;
      AWrite: TProtobufWriteProc; ARead: TProtobufReadProc);
    class function TryGetProtobuf(AType: PTypeInfo;
      out AWrite: TProtobufWriteProc; out ARead: TProtobufReadProc): Boolean;
  end;
```

Typed generic overloads can wrap the object-based storage API for better call sites.

### 7.3 CLI and Expert Flow

The Expert should not implement parsing/generation itself. It should call the CLI:

```text
dext codecs generate --project Grpc.EntityDataSet.Demo.dproj --target grpc,json,orm
dext codecs generate --unit Domain.Entities.pas --out Generated\Domain.Entities.DextCodecs.pas
dext proto export --project MyApp.dproj --out proto
```

S15 remains the visual UX:

- discover `[GrpcMessage]`, `[Entity]`, `[Table]`, DTOs, and REST models;
- show which types are eligible for generated/direct codecs;
- show warnings for fallback members;
- write config into YAML for GitOps review;
- call `dext.exe` to generate code.

---

## 8. Shared Use by REST and ORM

### 8.1 REST/JSON

`TDextJson` already has serialization plans. S54 should evolve those plans to use the shared `TDextFieldPlan`.

Expected changes:

- Object serialization reads primitive fields by offset where safe.
- Object population writes primitive fields by offset where safe.
- Generated JSON codecs can share the same static plan as protobuf but target JSON writers/readers.
- `JsonNameAttribute`, case style, `JsonIgnoreAttribute`, and `NotMappedAttribute` remain JSON-specific decorations over the shared field model.

### 8.2 ORM Hydration

ORM materialization should consume the same native field model:

- database column -> `TPropertyMap` -> `TDextFieldPlan`;
- direct assignment for primitives and strings;
- converter path remains fallback;
- SmartProp/Nullable value and has-value offsets are written directly when validated.

This directly benefits `TDbSet<T>` hydration, DataAPI, `TEntityDataSet.Load<T>`, and remote sync apply/fetch.

### 8.3 EntityDataSet

`TEntityDataSet` should not need to understand protobuf. It should benefit indirectly through faster provider payload materialization, faster object-to-dataset loading through field plans, and faster change extraction through field plans.

---

## 9. Service Invocation Fast Path

After protobuf field access is optimized, `TRttiMethod.Invoke` becomes visible. Add a second generated layer for services:

```pascal
type
  TGrpcMethodInvoker = function(Service: TObject; Request: TObject): TObject;
```

Generated example:

```pascal
function Invoke_CompanyService_FetchAll(Service: TObject; Request: TObject): TObject;
begin
  Result := TCompanyService(Service).FetchAll(TCompanyQueryRequest(Request));
end;
```

`TDextGrpcDispatcher` should prefer registered invokers and keep `TRttiMethod.Invoke` as fallback.

---

## 10. Implementation Roadmap


### 10.0 Remaining Work

The S54 runtime, CLI generator, direct codecs, generated protobuf path, JSON adoption, ORM hydration adoption, benchmark coverage, and edge-case support are finalized for the current implementation scope.

The only remaining S54-related work is the IDE Expert DX surface, intentionally deferred to a dedicated S15/S54 integration session. That session should use the deferred Expert DX scope in section 0.1 as its design checklist.

### Phase 1: Measurement and Guardrails

- Add benchmark cases to S18 for Win32 and Win64: protobuf, JSON, ORM hydration, and `TEntityDataSet.Load<T>` with 10,000 objects/rows.
- Store baseline traces for RTTI mode.
- Add compatibility tests comparing generated/direct/RTTI protobuf bytes.

### Phase 2: Type Model

- Create `Dext.Core.TypeModel`.
- Add `TDextNativeKind`, `TDextFieldPlan`, and `IDextTypeCodecPlan`.
- Build plans from `TReflection.GetMetadata`, `TPropertyMap`, and attributes.
- Detect direct-offset eligibility.
- Expose diagnostics explaining why a field uses fallback.

### Phase 3: Protobuf Reader/Writer Refactor

- Extract stream primitives from `TProtobufSerializer` into `TProtobufReader` and `TProtobufWriter`.
- Precompute tag bytes and wire type per field.
- Preserve the current public API.
- Add `TProtobufCodecMode`.

### Phase 4: Direct Offset Protobuf

- Implement direct primitive/string/bool/float/date/bytes reads and writes.
- Keep nested object/list handling plan-based but initially allow fallback inside nested types.
- Run Win32/Win64 benchmarks against S02 demo data.

### Phase 5: Codec Registry

- Add `TDextCodecRegistry`.
- Add generated-code hook points in protobuf and gRPC dispatcher.
- Add service method invoker registry.

### Phase 6: CLI Code Generator

- Add `dext codecs generate`.
- Reuse `DelphiAST` and existing metadata parsers.
- Generate Pascal units for protobuf codecs first.
- Generate `.proto` export from the same model.
- Add deterministic formatting and regeneration markers.

### Phase 7: IDE Expert Integration

- Extend S15 Dext Studio with a Codecs tab.
- Show type eligibility, fallback reasons, generated output paths, and benchmark status.
- Call CLI in a background process and report messages to the IDE.

### Phase 8: JSON and ORM Adoption

- Adapt `TDextJson` plan building to consume `TDextFieldPlan`.
- Add generated JSON codecs.
- Migrate ORM hydration/materialization hot paths to the shared field model.
- Keep converters and custom accessors on fallback paths.

---

## 11. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Direct offsets bypass custom property logic | Use direct mode only for fields or field-backed properties explicitly proven safe. |
| Managed type corruption | Use typed assignment helpers for strings/interfaces/dynamic arrays; never raw-copy managed values. |
| Cross-version Delphi RTTI differences | Keep RTTI fallback and validate offsets in tests per compiler target. |
| Generated code drift | Regenerate deterministically from YAML/project metadata and compare in CI. |
| Too many metadata systems | Make `Dext.Core.TypeModel` the only shared codec plan; protobuf/JSON/ORM decorate it, not duplicate it. |
| Premature unsafe optimization | Gate each phase with S18 benchmark and compatibility tests. |

---

## 12. Acceptance Criteria

- [x] Current S02 public APIs remain source-compatible.
- [x] RTTI, direct, and generated protobuf paths produce equivalent payloads.
- [x] Win32 protobuf fetch for the 10,000-object demo improves by at least 5x over the current RTTI path.
- [x] Win64 protobuf serialization/deserialization improves by at least 2x or shows no regression.
- [x] JSON serialization can use the shared field plan without changing `TDextJson` public API.
- [x] ORM hydration can use the shared field plan while preserving converters and SmartProp/Nullable behavior.
- [x] CLI can generate Pascal protobuf codecs and `.proto` files from code-first classes.
- [ ] IDE Expert can surface generation status and fallback diagnostics without doing codegen internally. Deferred to the S15/S54 Expert DX session.

---

## 13. Recommended First Implementation Slice

Start with the narrowest slice:

1. `TCompany` from `Grpc.EntityDataSet.Demo`.
2. Primitive fields only: `Integer`, `string`, `Boolean`.
3. Protobuf direct offset mode only.
4. No generated code yet.
5. Benchmark Win32 and Win64 before expanding.

This validates the core hypothesis with minimal blast radius. Once proven, lift the implementation into `Dext.Core.TypeModel` and generalize it for code generation, JSON, and ORM.
