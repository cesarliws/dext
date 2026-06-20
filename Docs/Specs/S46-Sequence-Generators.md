# Spec S46: Database Sequence Generators & HiLo Pre-Allocation

**Status: ✅ Finalized**

## 1. Overview & Context

Currently, the Dext ORM bulk insert optimization falls back to a slow, row-by-row insert path for entities configured with `[AutoInc]` primary keys. This fallback is necessary because the framework must retrieve the generated database ID for each inserted row to keep the in-memory object instance synchronized (hydrated).

To unlock high-performance bulk inserts for auto-generated primary keys, Dext requires a client-side pre-allocation strategy. By introducing **Database Sequence Generators** combined with the **HiLo Optimizer** (similar to Hibernate's pooled generators and Entity Framework Core's `UseHiLo`), the ORM can request a block of IDs from a database sequence in a single call, assign the primary keys in memory, and perform bulk inserts using optimized Array DML (FireDAC `ExecuteBatch`).

---

## 2. Industry Reference Architecture

### A. Hibernate / JPA (Java)
Hibernate uses `@SequenceGenerator` combined with `SequenceStyleGenerator` and an `allocationSize` optimizer:
```java
@Id
@GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "seq_user")
@SequenceGenerator(name = "seq_user", sequenceName = "SEQ_USER_ID", allocationSize = 50)
private Long id;
```
* **HiLo / Pooled Optimizers:** Instead of calling `NEXT VALUE FOR SEQ_USER_ID` for every single insert, the client requests the next sequence value, treats it as a range boundary, and increment IDs in memory up to `allocationSize` times before requesting the next block.

### B. Entity Framework Core (.NET)
EF Core leverages database-level sequences with the HiLo pattern:
```csharp
protected override void OnModelCreating(ModelBuilder modelBuilder)
{
    modelBuilder.ForNpgsqlUseSequenceHiLo("seq_user_id");
}
```
* The EF Core database provider queries the sequence to fetch a block generator, allowing multiple inserts to complete without round-trips for key generation.

---

## 3. Proposed Dext Design

### A. Attributes
We will introduce `[Sequence]` and `[HiLo]` attributes for property-level configuration.

```pascal
unit Dext.Entity.Attributes;

interface

type
  [AttributeUsage(tarProperty)]
  SequenceAttribute = class(TCustomAttribute)
  private
    FSequenceName: string;
    FAllocationSize: Integer;
  public
    constructor Create(const ASequenceName: string; AAllocationSize: Integer = 50);
    property SequenceName: string read FSequenceName;
    property AllocationSize: Integer read FAllocationSize;
  end;
```

### B. Fluent API Configuration
```pascal
modelBuilder.Entity<TUser>
  .Property(u => u.Id)
  .UseSequence('SEQ_USER_ID', 100);
```

### C. The HiLo Optimizer Engine
We need a thread-safe registry to manage sequence allocation pools in memory.

```pascal
type
  TSequenceRange = class
  public
    Low: Int64;
    High: Int64;
    Current: Int64;
    function NextId(out AId: Int64): Boolean;
  end;

  TSequenceManager = class
  private
    FCurrentRanges: TDictionary<string, TSequenceRange>;
    FLock: TCriticalSection;
    function FetchNextRangeFromDb(const ASeqName: string; AAllocSize: Integer; AContext: TDbContext): TSequenceRange;
  public
    constructor Create;
    destructor Destroy; override;
    function GenerateId(const ASeqName: string; AAllocSize: Integer; AContext: TDbContext): Int64;
  end;
```

#### The Algorithmic Step (Pooled-Lo Pattern):
1. Client requests a new ID for `SEQ_USER_ID` with `AllocationSize = 50`.
2. If the current in-memory range is empty or exhausted (`Current > High`):
   - Query the database sequence: `SELECT NEXT VALUE FOR SEQ_USER_ID` (returns, say, `101`).
   - The database sequence increments by `50` on the server-side, or the client multiplies the value depending on the database sequence increment setting.
   - For PostgreSQL/Oracle/Firebird, we define the sequence increment size equal to the allocation size (`INCREMENT BY 50`).
   - The fetched value `101` becomes `Low` and `High` becomes `101 + 50 - 1` (150).
   - In-memory `Current` is set to `101`.
3. Client returns `Current` and increments it (`Current := Current + 1`).
4. Subsequent inserts retrieve the ID from memory instantly, incurring zero database latency.

---

## 4. Database Support & SQL Generation

Different database dialects support sequences differently:
* **PostgreSQL:** `SELECT nextval('seq_name')`
* **Oracle:** `SELECT seq_name.NEXTVAL FROM dual`
* **Firebird:** `SELECT NEXT VALUE FOR seq_name FROM rdb$database`
* **MariaDB / MySQL (8.0+):** `SELECT NEXTVAL(seq_name)`
* **SQLite:** Sequences are not natively supported, so a fallback table-based sequence emulator (similar to EF Core's SQLite fallback) will be implemented.

---

## 5. Integration into SaveChanges

During the `SaveChanges` queue analysis:
1. Before partitioning inserts, check if the entity's primary key uses `[Sequence]`.
2. If so, iterate through the entities in the insert queue, request IDs from the `TSequenceManager`, and write the generated IDs directly to the entities.
3. Because the entities now have their primary keys assigned:
   - `IsBulkInsertSafe` evaluates to `True` (since there is no `AutoInc` dependency).
   - The insert queue bypasses the slow row-by-row path and is executed as a bulk insert using FireDAC `ExecuteBatch`.

---

## 6. Effort & Implementation Plan

| Phase | Description | Estimated Effort |
|---|---|---|
| **Phase 1: Metadata & Config** | Define `SequenceAttribute` and build Fluent API metadata parsing. | 1 Day |
| **Phase 2: Optimizer Engine** | Implement thread-safe `TSequenceManager` with the Pooled-Lo allocation algorithm. | 1.5 Days |
| **Phase 3: Dialect support** | Add SQL templates to `ISQLDialect` for sequence retrieval across Firebird, PostgreSQL, MySQL, and Oracle. | 1 Day |
| **Phase 4: SaveChanges Hook** | Hook ID generation prior to SaveChanges partitioning. Mark sequenced entities safe for bulk inserts. | 1 Day |
| **Phase 5: Verification** | Add integration tests with database sequences in SQLite, Firebird, and PG. | 1.5 Days |

**Total Estimated Effort:** ~6 Days
