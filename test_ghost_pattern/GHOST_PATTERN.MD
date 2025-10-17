# Ghost Pattern Implementation Guide for Ada/SPARK

## When to Use This Pattern

Apply this pattern when you encounter:
- **Circular dependency errors** between main packages and their ghost child packages
- **Unproved verification conditions** where gnatprove cannot see ghost implementations
- **Import pragma failures** when ghost functions are declared but not visible to the prover

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

## Application Example

For a library with multiple components:
```
SML.DOM.Proof         → SML_DOM_Ghost
SML.Memory_Model.Proof → SML_Memory_Model_Ghost
SML.UTF8.Proof        → SML_UTF8_Ghost

+ Create: SML_Types.DOM, SML_Types.Memory_Model, etc.
```

This pattern enables formal verification while maintaining clean architecture and avoiding the Ada language limitation of circular dependencies with ghost child packages.