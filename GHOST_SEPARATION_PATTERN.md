# Ghost Code Separation Pattern for SML Library

## Recommended Approach: Child Ghost Packages

After analyzing the SML library's ghost code, I recommend using **child ghost packages** for separation. This approach maintains locality while providing clean separation.

## Implementation Pattern

### 1. For Each Package with Ghost Code

Create a corresponding `.Proof` child package:

```ada
-- Original package
package SML.X with SPARK_Mode is
   -- Regular declarations
end SML.X;

-- Ghost child package  
package SML.X.Proof with Ghost, SPARK_Mode is
   -- All ghost declarations moved here
end SML.X.Proof;
```

### 2. Proposed Package Structure

```
src/
├── sml.ads                      (no ghost code)
├── sml-dom.ads/.adb            (runtime code only)
├── sml-dom-proof.ads/.adb      (ghost code)
├── sml-dom-parser.ads/.adb     (runtime code only)
├── sml-dom-parser-proof.ads/.adb (ghost code)
├── sml-dom-builder.ads/.adb    (runtime code only)
├── sml-dom-builder-proof.ads/.adb (ghost code)
├── sml-memory_model.ads/.adb   (runtime code only)
├── sml-memory_model-proof.ads/.adb (ghost code)
├── sml-utf8.ads/.adb           (runtime code only)
├── sml-utf8-proof.ads/.adb     (ghost code)
├── sml-entities.ads/.adb       (runtime code only)
├── sml-entities-proof.ads/.adb (ghost code)
├── sml-schema.ads/.adb         (runtime code only)
└── sml-schema-proof.ads/.adb   (ghost code)
```

### 3. Contract Updates

Main packages reference ghost functions via qualified names:

```ada
-- Before (ghost in same package)
function Create_Document return Document
  with Post => Is_Well_Formed (Create_Document'Result);

-- After (ghost in child package)  
with SML.DOM.Proof;
...
function Create_Document return Document
  with Post => SML.DOM.Proof.Is_Well_Formed (Create_Document'Result);
```

### 4. Special Cases

#### Ghost Types
For the parser's `Parser_State` ghost type, keep it in the main package but mark as Ghost:

```ada
-- In sml-dom-parser.ads
type Parser_State is private with Ghost;

-- In private part
private
   type Parser_State is record ... end record with Ghost;
```

#### Shared Ghost Functions
If ghost functions are needed across packages, consider:
- `SML.Proof_Common` - shared ghost utilities
- Or duplicate simple predicates where needed

### 5. Benefits

1. **Clean Separation**: Ghost code physically separated from runtime
2. **Easy Exclusion**: Can exclude `*-proof.ads/adb` from production builds
3. **Maintains Locality**: Ghost code stays near what it specifies  
4. **No Circular Dependencies**: Child packages naturally avoid cycles
5. **SPARK Compatible**: Full proof checking maintained

### 6. Migration Steps

1. Create `-proof.ads` for each package with ghost code
2. Move ghost function declarations to new spec
3. Create `-proof.adb` and move implementations
4. Update all contracts to use qualified names
5. Run gnatprove to verify proofs still pass
6. Update build configuration to optionally exclude ghost packages

### 7. Example Files Created

- `src/sml-dom-proof.ads` - Ghost functions for DOM
- `src/sml-dom-proof.adb` - Ghost implementations
- `GHOST_SEPARATION_EXAMPLE.ads` - Shows updated contracts

## Alternative Patterns (Not Recommended)

### Centralized Ghost Package
A single `SML.Proof_Utils` would require complex visibility management and lose locality.

### Subunits
Older Ada feature that doesn't provide as clean separation as child packages.

## Conclusion

The child ghost package pattern provides the best balance of:
- Clean code organization
- Maintainability  
- SPARK compatibility
- Build flexibility

This approach scales well and follows modern Ada best practices.
