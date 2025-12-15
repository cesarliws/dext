# 🏗️ ORM Metadata Architecture: The `TEntityType<T>` System

## 🎯 Objective
Migrate the Dext ORM from a **Reflection-on-Demand** model (using standard RTTI lookup at runtime for every operation) to a **Metadata Cache / Type Model** system. This aims to drastically improve performance during object hydration (DataSet -> Object) and provide a robust foundation for validation, DTO mapping, and schema generation.

---

## 🛑 Current Problem
1.  **Performance Bottleneck**: `TRttiProperty.GetValue` and `SetValue` are expensive operations when called thousands of times inside a loop (e.g., fetching 10k rows).
2.  **Repetitive Lookup**: Converters (e.g., `IntToBool`) are often resolved repeatedly for the same property type.
3.  **Fragmented Logic**: Validation attributes, mapping attributes, and value conversion logic are resolved in different places.

## 💡 Proposed Solution: `TEntityType<T>`

We propose a static, generic-based metadata system that acts as a central registry for all entity capabilities.

### 1. `TPropertyMeta` (The "Heart" of a Property)
Instead of just holding a property name or a simple `TPropExpression`, this class effectively becomes the "smart descriptor" of a mapped property.

```pascal
type
  TValueAccessor = reference to function(Instance: TObject): TValue;
  TValueMutator = reference to procedure(Instance: TObject; const Value: TValue);

  TPropertyMeta = class
  private
    FName: string;
    FColumnName: string;
    FTypeInfo: PTypeInfo;
    FConverter: IValueConverter; // Cached instance
    FIsPK: Boolean;
    FIsFK: Boolean;
    
    // Optimized Accessors (compiled/method pointers)
    FGetter: TValueAccessor;
    FSetter: TValueMutator;
    
    // Validation Metadata
    FValidationAttributes: TArray<TCustomAttribute>;
  public
    // ... Properties ...
    
    // Fast Access (bypasses RTTI lookup overhead)
    function GetValue(Instance: TObject): TValue; inline;
    procedure SetValue(Instance: TObject; const Value: TValue); inline;
    
    // Expression Building (for Queries)
    function Eq(const Value: TValue): IPredicate;
    function Gt(const Value: TValue): IPredicate;
    // ...
  end;
```

### 2. `TEntityType<T>` (The Central Registry)
A generic class that uses `class var` to hold metadata. This ensures type safety and allows "compile-time" access styles.

```pascal
type
  TEntityType<T: class> = class
  public
    // The Global Model Definition for this type
    class var Meta: TEntityModel; 
    
    // Static Properties for Fluent API usage
    // These are initialized once and reused forever.
    class var Id: TPropertyMeta;
    class var Name: TPropertyMeta;
    class var Email: TPropertyMeta;
    class var CreatedAt: TPropertyMeta;
    
    // Initialization Hook
    class constructor Create;
  end;
```

---

## 🚀 Implementation Strategy

### Phase 1: Definition & Initialization
1.  Define the `TPropertyMeta` class to support holding `IValueConverter` and `TCustomAttribute` arrays.
2.  Implement the **Model Builder Pipeline**:
    - When `TEntityType<T>` is touched for the first time, its `class constructor` runs.
    - It triggers a `ModelBuilder.Scan<T>()`.
    - This scanner inspects RTTI **once**.
    - It populates `TEntityType<T>.Meta` and assigns the individual `class var` fields (using RTTI to set the static fields of `TEntityType<T>` itself!).

### Phase 2: Fast Accessors (The Performance Boost)
Instead of storing `TRttiProperty`, we generate or link optimized accessors.
- **Getters/Setters**: We can potentially use `MethodAddress` or highly optimized delegates that avoid the full RTTI stack validation for every call.

### Phase 3: Hydrator Integration
Refactor `TDextEntityHydrator` to use `TEntityType<T>` instead of raw RTTI.

**Before:**
```pascal
for Key in Dataset.Fields do
  Prop := Context.GetType(T).GetProperty(Key); // Slow RTTI lookup
  Prop.SetValue(Instance, ...); // Slow RTTI Set
```

**After:**
```pascal
// Iterate over the PRE-CACHED properties
for PropMeta in TEntityType<T>.Meta.Properties do 
begin
  // Direct converter usage
  Val := PropMeta.Converter.Convert(Dataset.FieldByName(PropMeta.Column).Value);
  // Fast Setter
  PropMeta.SetValue(Instance, Val);
end;
```

---

## ✅ Benefits summary

1.  **Performance**: Hydration speed could increase by order of magnitude (10x+) by eliminating repeated RTTI lookups and conversions.
2.  **Centralization**: One place to inspect what an Entity "looks like". Useful for Swagger generation, Migration diffing, and Validation.
3.  **Type Safety**: The `TEntityType<T>` pattern ensures we are always talking about the properties of `T`, not a string that might misspell a property name.
