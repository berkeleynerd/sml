# Ghost Pattern Implementation Guide for Ada/SPARK

## When to Use This Pattern

Apply this pattern when you encounter:
- **Circular dependency errors** between main packages and their ghost child packages
- **Unproved verification conditions** where gnatprove cannot see ghost implementations
- **Import pragma failures** when ghost functions are declared but not visible to the prover

## Two Variants of the Ghost Pattern

### Variant 1: Simple (2-Package Pattern)

**Use when:** Ghost functions don't need opaque types from the main package

**Structure:**
```
Main_Package → Ghost_Package
```

**Characteristics:**
- Ghost functions operate on standard types (String, Natural, Boolean)
- No inspection of private record fields
- Ghost package is self-contained
- Example: SML.UTF8, SML.Entities

**Example:**
```ada
-- SML_UTF8_Ghost doesn't reference SML.UTF8
package SML_UTF8_Ghost with Ghost is
   function Is_Normalized (Text : String) return Boolean;
   -- Only uses String type
end SML_UTF8_Ghost;
```

### Variant 2: Complex (3-Package Pattern)

**Use when:** Ghost functions need access to opaque types or internal structures

**Structure:**
```
Main → Types ← Ghost
  ↓              ↑
  └──────────────┘
```

**Characteristics:**
- Ghost functions traverse internal data structures
- Ghost functions inspect private record fields
- Types defined in private section need to be extracted
- Example: SML.Memory_Model, SML.DOM (future)

**Example:**
```ada
-- Types package with shared definitions
package SML_Memory_Model_Types with SPARK_Mode is
   type Arena_Pool is limited record
      Nodes : ...;
      Strings : ...;
   end record;
end SML_Memory_Model_Types;

-- Ghost package depends only on Types
with SML_Memory_Model_Types;
package SML_Memory_Model_Ghost with Ghost is
   function Arena_Invariants (Pool : Arena_Pool) return Boolean;
   -- Inspects Pool.Nodes array
end SML_Memory_Model_Ghost;
```

### Decision Rule

**Start with the simple 2-package pattern.** If you encounter circular dependency:
```
error: Ghost_Package depends on Main_Package
error: Main_Package depends on Ghost_Package
```

Then switch to the 3-package pattern with types extraction.

## Why This Pattern Works

Traditional child ghost packages create circular dependencies:
```
Package.Ghost depends on Package (as child)
Package uses Package.Ghost in contracts
→ CIRCULAR DEPENDENCY
```

The solution uses **three separate packages** to break the cycle:
```
Main → Types ← Ghost
  ↓              ↑
  └──────────────┘
```
- Main depends on Types and Ghost
- Ghost depends only on Types
- Types depends on nothing

## How to Implement

### 1. Identify Packages Needing Ghost Functions
Look for packages with:
- Complex verification conditions
- Proof-specific helper functions
- Abstract properties needing ghost implementations

### 2. Extract Shared Types
Create a separate `*_Types` package:
```ada
package Example_Types with SPARK_Mode is
   type Counter is record
      Value : Natural;
      Max   : Natural;
   end record;
end Example_Types;
```

### 3. Create Separate Ghost Package
**Critical**: Use a separate package, NOT a child package:
```ada
-- WRONG: package Example.Ghost
-- RIGHT: package Example_Ghost

with Example_Types; use Example_Types;

package Example_Ghost
  with Ghost, SPARK_Mode  -- Ghost aspect is mandatory
is
   function Is_Valid (C : Counter) return Boolean;
end Example_Ghost;
```

### 4. Update Main Package
Reference both Types and Ghost packages:
```ada
with Example_Types; use Example_Types;
with Example_Ghost;  -- No circular dependency!

package Example with SPARK_Mode is
   procedure Increment (C : in out Counter)
     with Post => Example_Ghost.Value_Increased (C'Old, C);
end Example;
```

### 5. Refactoring Checklist
When converting existing code:

**Rename ghost packages:**
- `Package.Proof` → `Package_Ghost`
- `Package.Ghost` → `Package_Ghost`
- Remove child relationship

**Move type declarations:**
- From main package → `Package_Types`
- Update all references

**Remove Import pragmas:**
- Ghost functions no longer need Import
- Prover can now see implementations

**Verify with gnatprove:**
```bash
gnatprove -P project.gpr --report=all
grep -i "_ghost" obj/gnatprove/gnatprove.out
```

## Success Indicators

✅ Ghost packages analyzed by gnatprove
✅ No circular dependency errors
✅ Previously unproved VCs now verified
✅ Output shows: `*_Ghost at *_ghost.ads:* flow analyzed`

## Common Pitfalls

❌ **Don't use child packages for ghost code**
❌ **Don't forget the Ghost aspect on the package**
❌ **Don't mix ghost and non-ghost code in same package**
❌ **Don't include implementation details in Types package**

## Real-World Application: SML Library Refactoring

### Completed Refactorings

**✅ Phase 1: SML.Memory_Model (3-package pattern)**
- Created `SML_Memory_Model_Types` with Arena_Pool, Node, String_Ref
- Created `SML_Memory_Model_Ghost` with ghost functions
- Updated all dependent files (DOM, Builder, Parser)
- **Learnings:** Complex types with internal arrays require extraction

**✅ Phase 2: SML.UTF8 (2-package pattern)**
- Created `SML_UTF8_Ghost` (self-contained)
- No types extraction needed
- **Learnings:** String predicates don't need main package access

**✅ Phase 3: SML.Entities (2-package pattern)**
- Created `SML_Entities_Ghost` (self-contained)
- Kept Standard_Entity type in main package (public, not opaque)
- **Learnings:** Public enums don't cause circular dependencies

### Remaining Work

**⏸️ Phase 4: SML.DOM (requires 3-package pattern)**
- **Challenge:** Document and Node_Id are opaque types in private section
- **Solution:** Extract `SML_DOM_Types` with Document, Node_Id, Node_Kind
- **Complexity:** High - Document contains Arena_Pool, many dependent packages
- **Estimated effort:** 2-3 hours

**⏸️ Phase 5: SML.DOM.Parser (likely 2-package pattern)**
- Can likely use 2-package pattern after DOM is done
- Parser_State is in private section but ghost functions may not need it
- **Estimated effort:** 30-45 minutes

**⏸️ Phase 6: SML.DOM.Builder (likely 2-package pattern)**
- Ghost functions track deletion (simple boolean checks)
- Can reuse SML_DOM_Types if needed
- **Estimated effort:** 30-45 minutes

### Key Lessons Learned

1. **Try simple first:** Always attempt 2-package pattern before extracting types
2. **Circular dependency = need types:** If ghost package must reference main package types, extract them
3. **Public types are OK:** Ghost packages can use public types from main package without circular dependency
4. **Opaque types need extraction:** Types in private sections cause circular dependencies if ghost code needs them

This pattern enables formal verification while maintaining clean architecture and avoiding the Ada language limitation of circular dependencies with ghost child packages.