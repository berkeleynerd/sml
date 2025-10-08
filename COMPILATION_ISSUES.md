# Compilation Issues Found

## Issues in sml-dom.ads

### Error 1: Lines 148 and 199 - Quantified Expression on Private Type
**Problem**: Quantified expressions (`for all N in Node_Id`) cannot iterate over a private type.
**Lines**: 148, 199
**Fix Needed**: These ghost postconditions need to be restructured since Node_Id is private (an access type).
**Proposed Solution**: Either:
- Remove these specific postconditions
- Change to a different verification approach that doesn't iterate over all possible Node_Id values
- Add a discrete range type for valid node indices

### Error 2: Line 215 - Invalid Private Declaration Context  
**Problem**: `type Node_Pool is limited private;` appears in wrong section
**Proposed Solution**: Move to proper private section or remove forward declaration

### Error 3: Line 223 - Ghost Aspect on Record Field
**Problem**: Ghost aspect cannot be applied to record components in this way
**Proposed Solution**: Use pragma Ghost on the field or restructure

## Style Warnings in sml-dom.adb
- Missing spaces around operators (multiple locations)
- Need "and then" / "or else" for boolean short-circuit operators
- Redundant with clause

These style issues can be fixed without changing the interface.
