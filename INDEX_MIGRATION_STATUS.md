# Index-Based Migration Status

## Current Status: Partially Migrated - Compilation Errors

### ✅ Successfully Completed

1. **Specification Migration** (sml-dom.ads)
   - ✅ Added SML.Memory_Model dependency
   - ✅ Changed Node_Id to `type Node_Id is new Memory_Model.Node_Index`
   - ✅ Replaced Document record to use Arena_Pool
   - ✅ Maintained API compatibility (type remains private)

2. **Implementation Rewrite** (sml-dom.adb)
   - ✅ Rewrote all traversal functions for array access
   - ✅ Added Get_String helper for String_Ref extraction
   - ✅ Removed access type dependencies
   - ✅ Added To_Index/To_Node_Id conversion helpers

3. **Dependency Management**
   - ✅ Fixed circular dependency with `limited with SML.DOM`
   - ✅ Renamed sml-memory-model.* to sml-memory_model.* (naming convention)

### ⚠️ Remaining Issues

#### Critical Errors in SML.Memory_Model Specification

**1. Functions with in/out parameters** (SPARK E0015)
```ada
function Allocate_Node (Pool : in out Arena_Pool; ...) return Node_Index
function Allocate_String (Pool : in out Arena_Pool; ...) return String_Ref
```
**Problem**: SPARK doesn't allow functions to modify parameters  
**Solution**: Convert to procedures with out parameter for result

**2. Ghost aspects on record fields** (3 instances)
```ada
Allocated_Nodes : Natural with Ghost;  -- Line 117
Allocated_Bytes : Natural with Ghost;  -- Line 118
High_Water_Mark : Natural with Ghost;  -- Line 119
```
**Problem**: Ghost aspect cannot apply to record components  
**Solution**: Remove Ghost aspects (fields still usable for proof)

**3. Forward declaration conflicts**
```ada
type Node; -- Line 51 (forward)
type Node is record ... end record; -- Line 82 (full)
```
**Problem**: Discriminated record can't use forward declaration this way  
**Solution**: Remove forward declaration, define directly

**4. Type equality in contracts**
```ada
Pool.Nodes(Index) = N  -- Line 269, 276
```
**Problem**: Discriminated record equality in contracts  
**Solution**: Use field-by-field comparison or remove from contract

**5. 'Old attribute on limited types**
```ada
Pool'Old.Allocated_Nodes  -- Lines 277, 278
```
**Problem**: 'Old doesn't work on limited types  
**Solution**: Use explicit old_* parameters or restructure

#### Moderate Issues in sml-dom.adb

**Type conversion needed** (50+ locations):
All Node_Id comparisons and assignments need To_Index/To_Node_Id wrappers
- Currently partially done (Parent function updated)
- Remaining: 9 more functions

**Node_Kind mismatch**:
```ada
SML.Memory_Model.Node_Kind vs SML.DOM.Node_Kind
```
Both define (Element, Text) but as different types
Need conversion functions or unification

## Estimated Remaining Effort

| Task | Complexity | Time | Status |
|------|------------|------|--------|
| Fix Memory_Model specification | High | 60 min | Not started |
| Update all sml-dom.adb functions | Medium | 45 min | 10% done |
| Fix Node_Kind type mismatch | Low | 15 min | Not started |
| Test compilation | Low | 5 min | Blocked |
| Run SPARK verification | Low | 10 min | Blocked |
| **Total** | | **~2 hours** | **10%** |

## Decision Point

Given the substantial issues in Memory_Model specification and the extensive work remaining:

### Option A: Complete the Migration (2+ hours)
- Fix all Memory_Model specification errors
- Complete sml-dom.adb type conversions
- Achieve full SPARK compatibility

### Option B: Rollback to Simpler Approach
- Revert to access-based design
- Mark sml-dom.adb as SPARK_Mode => Off
- Keep other packages SPARK-verified
- Document limitation

### Option C: Use DOM_Enhanced as Primary
- Keep both sml-dom.ads (simple) and sml-dom-enhanced.ads (verified)
- Update Parser to use DOM_Enhanced
- Maintain two APIs

## Recommendation

**Option A** if goal is complete SPARK verification (requires 2+ hours focus)  
**Option B** if timeline is constrained (30 minutes, pragmatic)  
**Option C** if want both simple and verified APIs (1 hour, architectural)

Current git state has all migration work saved. Can rollback or continue.
