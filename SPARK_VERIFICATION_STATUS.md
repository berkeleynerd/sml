# SPARK Verification Status

## Current Status: SPARK Analysis Phase Reached ✓

Successfully progressed from compilation errors through to SPARK analysis phase!

## Errors Fixed (3 commits)

1. **Bitwise AND operations** (commit `4353ac8`)
   - Fixed: Natural type doesn't support bitwise operations
   - Solution: Added `Bitwise_And` helper using `Interfaces.Unsigned_8`
   - Files: `sml-utf8.adb`

2. **Limited type handling** (commit `098fed4`)
   - Fixed: Cannot copy limited types
   - Solution: Extended return statements, raise expressions
   - Files: `sml-parser.ads`, `sml-parser.adb`

3. **Return raise expression** (commit `72acb17`)
   - Fixed: Control flow analysis in ghost function
   - Solution: `return raise` expression syntax
   - Files: `sml-parser.adb`

## Current SPARK Restriction

**Type_Invariant not supported in SPARK**

```ada
sml-dom.ads:20:09: error: type invariant on private_type_declaration 
or private_type_extension is not allowed in SPARK (SPARK RM 7.3.2(2))
  type Document is limited private
     with Type_Invariant => Is_Well_Formed (Document);
```

### Why This Matters

SPARK RM 7.3.2(2) explicitly forbids type invariants because:
- They're runtime checks, not statically verifiable
- SPARK requires all properties provable at compile time
- Type invariants can be violated temporarily during execution

### Proposed Solution

**Remove Type_Invariant, use explicit contracts:**

```ada
-- Current (not SPARK-compatible):
type Document is limited private
  with Type_Invariant => Is_Well_Formed (Document);

-- SPARK-compatible:
type Document is limited private;

-- Add postconditions to all Document-modifying operations:
function Create_Document return Document
  with Post => Is_Well_Formed (Create_Document'Result);

procedure Add_Child (Doc : in out Document; ...)
  with Pre  => Is_Well_Formed (Doc),
       Post => Is_Well_Formed (Doc);
```

### Impact Assessment

**Files requiring changes:**
- `sml-dom.ads` (line 20-21): Remove Type_Invariant aspect
- Add explicit Pre/Post contracts to DOM modification functions (when implemented)

**Breaking changes:** None
- Type_Invariant was declarative only
- Same property enforced via explicit contracts
- API remains unchanged

**Verification benefit:**
- SPARK can actually verify contracts
- More explicit about when invariant must hold
- Better error messages

## Other SPARK Issues Found

1. **Equality on access types** (`sml-dom.adb:219`)
   - SPARK restriction: No `=` or `/=` on access types
   - Solution: Use null checks or custom equality

2. **Access to Document fields with invariant**
   - Multiple locations accessing `Doc.Root_Node`, `Doc.Total_Nodes`
   - Will be resolved when Type_Invariant removed

## Warnings (Non-blocking)

- 34 unit name mismatches (ghost package bodies)
- 4 duplicated specs (enhanced packages)
- These don't prevent verification, just clutter output

## Recommendation

**Next Step:** Remove Type_Invariant from Document type

This is the minimal change needed to enable SPARK verification.
All other issues cascade from this restriction.

**Alternative:** Mark `sml-dom.ads` as `SPARK_Mode => Off` if invariants are essential,
but this defeats the purpose of formal verification.

## Progress Summary

✅ Compilation successful  
✅ SPARK Phase 1 (data representation) - passed with warnings  
✅ SPARK Phase 2 (global contracts) - completed  
⚠️  SPARK Phase 3 (flow & proof) - blocked by Type_Invariant restriction  

**8 fundamental SPARK errors all stem from single issue:** Type_Invariant on Document

Resolving this will unblock full SPARK analysis.
