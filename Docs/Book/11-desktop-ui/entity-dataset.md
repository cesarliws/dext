# Entity DataSet

The **`TEntityDataSet`** is a high-performance memory dataset designed to connect your **Dext ORM Entity Lists** directly to Delphi's classic data-aware Visual components (`TDataSource`, `TDBGrid`, `TDBEdit`) and reporting tools (`FastReport`, `ReportBuilder`).

Instead of replicating the entire memory space, **`TEntityDataSet`** uses memory offsets via `TEntityMap` maps from Dext to provide extreme performance and zero-allocation loading.

---

## 🚀 Loading Data

You can populate the dataset using an array of generic or domain objects, or loading directly from a **JSON ByteSpan** payload in memory.

### Loading from an Object List

```pascal
var
  Users: TArray<TUser>;
begin
  Users := Context.Users.ToList; // Fetch from Context
  
  DataSet.Load(Users, TUser); // Smart binding
  DataSource.DataSet := DataSet;
end;
```

### Loading directly from Utf8 JSON Buffer

```pascal
var
  JsonBytes: TBytes;
  Span: TByteSpan;
begin
  JsonBytes := TEncoding.UTF8.GetBytes(Payload);
  Span := TByteSpan.Create(JsonBytes);

  DataSet.LoadFromUtf8Json(Span, TUser);
end;
```

---

## 🔍 Filters and Searching

The dataset handles sorting and filtering purely in memory using the fast query framework of Dext.

### Expression Filtering 

You can set filtering natively using familiar string tokens:

```pascal
DataSet.Filter := 'Score > 100';
DataSet.Filtered := True;
```

### Quick Lookups

```pascal
if DataSet.Locate('Name', 'Cesar', []) then
  ShowMessage('Found!');
```

---

## 🎨 Design-Time Experience

The **`TEntityDataSet`** is tightly integrated with the Delphi IDE. By using the **`TEntityDataProvider`**, it can scan your source code and synchronize metadata without requiring full project compilation.

### Component Verbs

Right-click the component in the Form Designer to access these productivity tools:

1.  **Sync Fields (Scan + Update)**: 
    *   Adds new fields found in your entity class.
    *   Updates metadata (DisplayLabel, DisplayFormat, Visibility) from code attributes.
    *   **Preserves** your manual IDE customizations (Alignment, Font, etc.) for existing fields.
2.  **Refresh Entity (Re-Scan + Rebuild)**: 
    *   Performs a clean sweep.
    *   Deletes all current fields and rebuilds them strictly based on the current Entity metadata.
    *   Use this when you want a "Hard Reset" or when switching between unrelated entities.

### Automatic Stabilization

Dext ensures that the design-time state doesn't pollute your source files:
- **Persistence Safety:** The `Active` property is automatically handled so that it's never saved as `True` in the DFM, preventing "Connection Error" popups when opening forms.
- **Smart Cleanup:** Changing the `EntityClassName` property automatically triggers a full field rebuild to prevent metadata contamination.

## 💾 Change Tracking & Remote Sync

The dataset natively records insertions, updates, and deletions, making
it easy to synchronize changes with a remote REST API.

### Native Change Log

When a user edits, inserts, or deletes records, `TEntityDataSet` tracks
these actions automatically in the `Changes` property.

```pascal
var
  Change: TEntityChange;
begin
  for Change in DataSet.Changes do
  begin
    case Change.State of
      ersInserted: // New record
      ersModified: // Modified (Change.DirtyFields list available)
      ersDeleted:  // Tombstone (Change.Key primary key map available)
    end;
  end;
end;
```

After successfully saving changes, call `AcceptChanges` to clear the log:

```pascal
DataSet.AcceptChanges;
```

### Auto-Generated REST Endpoints

On the server, you can map the entity directly to create agreed endpoints:

```pascal
App.MapEntityDataSet<TCustomer>('/api/customers', TMyDbContext);
```

This registers the conventional routes:
- `GET /api/customers` to fetch the entity list.
- `POST /api/customers/apply` to apply the change-log payload.

---

## 🏆 Key Features

- **Zero Allocation on Value Loading:** Value reading maps to memory offsets accurately.
- **DML Memory Mode:** Append, Edit, and Delete fully operational inside the dataset structures.
- **Component Palette Ready:** Support for dropping statically at design-time for persistent `TFields`.

---

## 🛠️ Troubleshooting

### Name Conflicts with Devart EntityDAC

If you already have **EntityDAC** by Devart installed in your Delphi IDE, you might encounter a conflict when trying to install the `Dext.EF.Design.bpl` package. Both libraries use components with identical names (`TEntityDataProvider` and `TEntityDataSet`), and the Delphi IDE does not allow installing different components with the same name.

**How to resolve this:**

1. **Are you building a Desktop application?**
   If you are building Web APIs, Daemons, or Console applications, you don't actually need to install the `Dext.EF.Design.bpl` package. You can simply use Dext entirely through code without any issues. The design-time package is only meant to provide drag-and-drop components for VCL/FMX Forms.

2. **Are you using Devart and Dext in the same Desktop project?**
   If you intend to use both ORMs visually in the same project, this limitation from the Delphi IDE will prevent having both installed at the same time. 

3. **Using only Dext for your Desktop UI:**
   If you just want to use Dext, you can temporarily disable the Devart package:
   * In the Delphi IDE, go to **Component > Install Packages**.
   * Find the Devart EntityDAC packages in the list and **uncheck** them.
   * Click **Save**.
   * You can now safely install the `Dext.EF.Design.bpl` package and use `TEntityDataSet` and `TEntityDataProvider` on your forms.

4. **Coexistence via Prefixing (Experimental):**
   If you need to have both libraries installed simultaneously (e.g., during a migration phase), you can enable the naming prefix:
   * Open `Sources\Dext.inc`.
   * Uncomment `{$DEFINE DEXT_USE_ENTITY_PREFIX}`.
   * Rebuild the framework.
   * The components will be registered as **`TDextEntityDataSet`** and **`TDextEntityDataProvider`**.

