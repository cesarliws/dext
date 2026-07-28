---
name: dext-collections
description: Use Dext generic collections — IList<T>, IDictionary<K,V>, IOrderedDictionary<K,V>, IChannel<T>, IFrozenList<T>, LINQ operations, ownership semantics, and thread-safe concurrency patterns.
---

# Dext Collections

## Core Imports

```pascal
uses
  Dext.Collections,            // IList<T>, IDictionary<K,V>, IOrderedDictionary<K,V>, IChannel<T>, TCollections
  Dext.Collections.OrderedDict,// IOrderedDictionary<K,V>, TOrderedDictionary<K,V>
  Dext.Collections.Frozen;     // IFrozenList<T>, IFrozenDictionary<K,V>
```

## Why Dext Collections Instead of `System.Generics.Collections`?

Dext Collections were completely rebuilt from the ground up for the extreme demands of backend throughput.

| Feature | `IList<T>` / `IDictionary<K,V>` (Dext) | `TList<T>` / `TDictionary<K,V>` (RTL) |
| ------- | ------------------------------------- | ------------------------------------- |
| **Memory Management** | Automatic via ARC interfaces | Manual `.Free` required |
| **Compilation Speed** | Fast (**Code Folding / TRawList**) | Slow (Heavy Generic Code Bloat) |
| **Dictionary Model** | Open Addressing / Linear Probing (No Cache Misses) | Chaining (Slower memory fragmentation) |
| **Insertion Order** | Native `IOrderedDictionary<K,V>` | No native support |
| **Iteration & Querying** | Built-in fluent LINQ (`.Where`, `.Select`, etc.) | Manual `for` loops required |
| **Hardware Accel.** | Uses SIMD / AVX where possible | CPU single-instruction only |
| **Multi-Thread (Reads)**| Lock-Free (`Frozen Collections`) | `TCriticalSection` bottlenecks |
| **Multi-Thread (Pipes)**| Go-style Lock-Free Channels (`IChannel<T>`) | Thread-locking / TMonitor |
| **Zero-Allocation** | Natively handles `Vector` and `Span` slices | Endless memory copies |

## Architecture: The Performance Sniper

Dext Collections use four massive architectural pillars:

1. **Binary Code Folding (`TRawList`, `TRawDictionary`, `TRawOrderedDict`)**: The backend shares non-generic raw memory engines for generic lists and maps, dropping compile times by up to **60%** on huge projects since the compiler doesn't duplicate generic binaries.
2. **Open Addressing Dictionaries (`TRawDictionary`)**: Traditional RTL maps scatter pointers causing cache misses. Dext groups Hash Metadata contiguously for CPU cache alignment, performing up to **6.6x faster** in lookups.
3. **Zero-Allocation (Vector + Span)**: Manipulate memory slices and huge payloads directly without copying arrays or overloading the memory manager.
4. **SIMD Processor Acceleration**: Heavy structural scans utilize _Single Instruction, Multiple Data_ to process large byte blocks in a single CPU cycle.

## Creating Collections

Instantiate collections using the `TCollections` factory. Always refer to collections by their interface type.

```pascal
// Object list — OWNS the objects (auto-frees them when list dies or they are removed)
var Users: IList<TUser> := TCollections.CreateObjectList<TUser>;

// Primitive list (no ownership concept)
var Numbers := TCollections.CreateList<Integer>;

// Non-owning list — stores references, does NOT free objects
var RefList := TCollections.CreateList<TUser>(False); 

// Insertion-Ordered Dictionary (O(1) lookups + insertion-order iteration)
var OrderedHistory := TCollections.CreateOrderedDictionary<string, TOrder>;
```

### Ownership Semantics & ORM Rule

| Factory | Owns Objects/Values? | When to Use |
| ------- | --------------------- | ----------- |
| `CreateObjectList<T>` | `True` | You create objects and want the list to own and free them |
| `CreateList<T>(False)`| `False` | **ORM Rule**: Always use `False` for entity collections (`DbContext` manages them) |
| `CreateOrderedDictionary<K,V>(True)` | `True` | Owned object values in ordered dictionaries |

## Basic Operations

```pascal
var Users := TCollections.CreateObjectList<TUser>;

// Add & Access
Users.Add(User1);
Users.AddRange([User2, User3]);
var First := Users[0]; // Or Users.First;

// Remove
Users.Remove(User1);    // By reference
Users.Delete(0);        // By index
Users.Clear;            // Remove all (frees objects if OwnsObjects=True)
```

## Ordered Dictionary (`IOrderedDictionary<K,V>`)

```pascal
var Dict := TCollections.CreateOrderedDictionary<string, Integer>;
Dict.Add('Alpha', 100);
Dict.Add('Beta', 200);

// Positional access
Writeln(Dict.KeyAt(0));   // Output: Alpha
Writeln(Dict.ValueAt(0)); // Output: 100

// Iterates in exact insertion order ('Alpha' then 'Beta')
for var Pair in Dict do
  Writeln(Pair.Key, ': ', Pair.Value);
```

## LINQ Operations

Use `Prototype.Entity<T>` for strongly-typed fluent lambda expressions. Dext iterators are **lazy** — `.Where` and `.Select` don't copy data until you materialize them with `.ToList` or `.ToArray`.

```pascal
uses
  Dext.Entity.Prototype; // Prototype.Entity<T>

var u := Prototype.Entity<TUser>;

// Filter and Project
var Admins := Users.Where(u.Role = 'admin').ToList;
var AdultNames := Users.Where(u.Age >= 18).Select<string>(u.Name).ToList;

// Check existence
if Users.Any(u.Role = 'admin') then 
  WriteLn('Has admins');

// First match
var VIP := Users.FirstOrDefault(u.IsVip); // Returns nil if not found
```

## Multi-Threading Patterns

### 1. Frozen Collections (Lock-Free Reads) 🧊

Instead of fighting `TCriticalSection` bottlenecks inside backend services, construct your lists/dictionaries and freeze them. They become permanently immutable, allowing unlimited, lock-free parallel reads scaling optimally across all CPU cores.

```pascal
uses Dext.Collections.Frozen;

var 
  ReadOnlyUsers: IFrozenList<TUser>;
begin
  var Builder := TCollections.CreateList<TUser>;
  // Populate builder freely in single-thread ...
  
  // Freeze and share! Immutable and Lock-Free across all threads forever.
  ReadOnlyUsers := Builder.ToFrozenList;
end;
```

### 2. Channels (`IChannel<T>`) — Lock-Free Comms 🚀

For moving data between threads, use Go-inspired Channels instead of queues wrapped in heavy thread locks.

```pascal
uses Dext.Collections;

// Bounded channel creates Backpressure, blocking producer when full to avoid memory floods 
var Chan: IChannel<TOrder> := TChannel<TOrder>.CreateBounded(100);

// Producer Thread
TTask.Run(procedure
  begin
    Chan.Write(Order1);
    Chan.Write(Order2);
    Chan.Close;  // Signal that production is done
  end);

// Consumer Thread (Zero manual locking)
TTask.Run(procedure
  begin
    while Chan.IsOpen do
      ProcessOrder(Chan.Read); // Blocks gracefully if empty
  end);
```

## Common Mistakes

| Wrong | Correct |
|-------|---------|
| `var List: TList<TUser>` | `var List: IList<TUser>` |
| `TList<TUser>.Create` | `TCollections.CreateList<TUser>` |
| `List.Free` | Not needed — interface-managed automatically |
| `CreateObjectList` for ORM child collections | `CreateList(False)` — DbContext owns the lifecycle |
| `.Where(...)` without `.ToList` | Must call `.ToList` or loop it to materialise the iterator |
| Using standard `TDictionary` in high load | Use `TCollections.CreateDictionary<K, V>` or `CreateOrderedDictionary<K, V>` |
