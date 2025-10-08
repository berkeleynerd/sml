# Loop Variant Reference Guide for SML Library

## Overview

This document provides a comprehensive reference for implementing loop variants to prove termination in the SPARK Ada SML library. All loops must have formally proven termination using `pragma Loop_Variant`.

## Table of Contents

1. [Basic Loop Variant Patterns](#basic-loop-variant-patterns)
2. [Package-Specific Implementations](#package-specific-implementations)
3. [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)
4. [SPARK Proof Strategies](#spark-proof-strategies)
5. [Quick Reference](#quick-reference)

## Basic Loop Variant Patterns

### Pattern 1: Simple Forward String Iteration

```ada
procedure Process_String (Text : String) is
   Pos : Natural := Text'First;
begin
   while Pos <= Text'Last loop
      pragma Loop_Variant (Decreases => Text'Last - Pos + 1);
      pragma Loop_Invariant (Pos >= Text'First and Pos <= Text'Last + 1);

      -- Process character at Pos
      Process_Char (Text (Pos));

      -- Advance position
      Pos := Pos + 1;
   end loop;
end Process_String;
```

### Pattern 2: Backward String Iteration

```ada
procedure Process_Backward (Text : String) is
   Pos : Natural := Text'Last;
begin
   while Pos >= Text'First loop
      pragma Loop_Variant (Decreases => Pos - Text'First + 1);
      pragma Loop_Invariant (Pos >= Text'First - 1 and Pos <= Text'Last);

      -- Process character at Pos
      Process_Char (Text (Pos));

      -- Move backward
      exit when Pos = Text'First;  -- Prevent underflow
      Pos := Pos - 1;
   end loop;
end Process_Backward;
```

### Pattern 3: Variable Step Size (UTF-8)

```ada
function Validate_UTF8 (Text : String) return Boolean is
   Pos : Natural := Text'First;
   Step : Natural;
begin
   while Pos <= Text'Last loop
      pragma Loop_Variant (Decreases => Text'Last - Pos + 1);
      pragma Loop_Invariant (
         Pos >= Text'First and Pos <= Text'Last + 1 and
         Pos > Pos'Loop_Entry  -- Progress guarantee
      );

      -- Get sequence length (1-4 bytes)
      Step := UTF8_Sequence_Length (Text, Pos);

      if Step = 0 then
         return False;  -- Invalid UTF-8
      end if;

      -- Advance by sequence length
      Pos := Pos + Step;

      pragma Assert (Pos > Pos'Old);  -- Help prover
   end loop;

   return True;
end Validate_UTF8;
```

### Pattern 4: Nested Loops (Lexicographic)

```ada
procedure Process_Matrix (M : Matrix_Type) is
begin
   for I in M'Range(1) loop
      for J in M'Range(2) loop
         pragma Loop_Variant (
            Decreases => M'Last(1) - I,
            Decreases => M'Last(2) - J
         );

         Process_Element (M (I, J));
      end loop;
   end loop;
end Process_Matrix;
```

### Pattern 5: While Loop with Multiple Exit Conditions

```ada
procedure Find_Pattern (Text : String; Pattern : String) is
   Pos : Natural := Text'First;
   Found : Boolean := False;
begin
   while Pos <= Text'Last - Pattern'Length + 1 and not Found loop
      pragma Loop_Variant (Decreases => Text'Last - Pos + 1);
      pragma Loop_Invariant (
         Pos >= Text'First and
         Pos <= Text'Last - Pattern'Length + 2 and
         not Found
      );

      if Text (Pos .. Pos + Pattern'Length - 1) = Pattern then
         Found := True;
      else
         Pos := Pos + 1;
      end if;
   end loop;
end Find_Pattern;
```

## Package-Specific Implementations

### SML.UTF8 Package

#### Is_Valid_UTF8 Implementation

```ada
function Is_Valid_UTF8 (Text : String) return Boolean is
   Pos : Natural := Text'First;
   Seq_Len : Natural;
begin
   while Pos <= Text'Last loop
      pragma Loop_Variant (Decreases => Text'Last - Pos + 1);
      pragma Loop_Invariant (
         Pos >= Text'First and Pos <= Text'Last + 1 and
         (for all I in Text'First .. Pos - 1 => Is_Valid_UTF8_At (Text, I))
      );

      Seq_Len := UTF8_Sequence_Length (Text, Pos);

      if Seq_Len = 0 or else Pos + Seq_Len - 1 > Text'Last then
         return False;
      end if;

      -- Validate continuation bytes
      for I in Pos + 1 .. Pos + Seq_Len - 1 loop
         pragma Loop_Variant (Decreases => Pos + Seq_Len - 1 - I);

         if not Is_Continuation_Byte (Text (I)) then
            return False;
         end if;
      end loop;

      Pos := Pos + Seq_Len;
      pragma Assert (Pos > Pos'Old and Seq_Len >= 1);
   end loop;

   return True;
end Is_Valid_UTF8;
```

#### UTF8_Length Implementation

```ada
function UTF8_Length (Text : String) return Natural is
   Pos : Natural := Text'First;
   Count : Natural := 0;
   Seq_Len : Natural;
begin
   while Pos <= Text'Last loop
      pragma Loop_Variant (Decreases => Text'Last - Pos + 1);
      pragma Loop_Invariant (
         Pos >= Text'First and Pos <= Text'Last + 1 and
         Count <= Pos - Text'First and
         Count <= Text'Length
      );

      Seq_Len := UTF8_Sequence_Length (Text, Pos);
      pragma Assert (Seq_Len in 1 .. 4);

      Count := Count + 1;
      Pos := Pos + Seq_Len;
   end loop;

   return Count;
end UTF8_Length;
```

### SML.Entities Package

#### Expand_Entities Implementation

```ada
function Expand_Entities (Text : String) return String is
   Result : String (1 .. Text'Length);
   Src_Pos : Natural := Text'First;
   Dst_Pos : Natural := 1;
   Entity_Len : Natural;
begin
   while Src_Pos <= Text'Last loop
      pragma Loop_Variant (Decreases => Text'Last - Src_Pos + 1);
      pragma Loop_Invariant (
         Src_Pos >= Text'First and Src_Pos <= Text'Last + 1 and
         Dst_Pos >= 1 and Dst_Pos <= Src_Pos - Text'First + 1 and
         Dst_Pos <= Result'Last + 1
      );

      if Text (Src_Pos) = '&' and then Has_Valid_Entity_At (Text, Src_Pos) then
         -- Replace entity with character
         Entity_Len := Entity_Length_At (Text, Src_Pos);
         Result (Dst_Pos) := Get_Entity_Char (Text, Src_Pos);
         Dst_Pos := Dst_Pos + 1;
         Src_Pos := Src_Pos + Entity_Len;

         pragma Assert (Entity_Len >= 3);  -- Min: &x;
      else
         -- Copy regular character
         Result (Dst_Pos) := Text (Src_Pos);
         Dst_Pos := Dst_Pos + 1;
         Src_Pos := Src_Pos + 1;
      end if;
   end loop;

   return Result (1 .. Dst_Pos - 1);
end Expand_Entities;
```

#### Check_Entities Implementation

```ada
function Check_Entities (Text : String) return Entity_Check_Result is
   Pos : Natural := Text'First;
   Max_Lookahead : constant := 6;  -- &apos; is longest
begin
   while Pos <= Text'Last loop
      pragma Loop_Variant (Decreases => Text'Last - Pos + 1);
      pragma Loop_Invariant (
         Pos >= Text'First and Pos <= Text'Last + 1 and
         (for all I in Text'First .. Pos - 1 =>
            (Text (I) /= '&' or else Has_Valid_Entity_At (Text, I)))
      );

      if Text (Pos) = '&' then
         if not Has_Valid_Entity_At (Text, Pos) then
            -- Found invalid entity
            return (Valid => False,
                   Error_Kind => Determine_Error (Text, Pos),
                   Error_Position => Pos);
         end if;

         -- Skip valid entity
         Pos := Pos + Entity_Length_At (Text, Pos);
      else
         Pos := Pos + 1;
      end if;
   end loop;

   return (Valid => True, Error_Kind => No_Error, Error_Position => 0);
end Check_Entities;
```

### SML.Parser Package

#### Main Parse Loop

```ada
procedure Parse_Internal (Input : String; State : in out Parser_State) is
   Pos : Natural := Input'First;
begin
   while Pos <= Input'Last and not State.Has_Error loop
      pragma Loop_Variant (
         Decreases => Input'Last - Pos + 1,
         Decreases => Max_Tree_Depth - State.Stack_Depth
      );
      pragma Loop_Invariant (
         Pos >= Input'First and Pos <= Input'Last + 1 and
         State.Stack_Depth <= Max_Tree_Depth and
         Is_Valid_Partial_State (State)
      );

      -- Skip whitespace
      Pos := Skip_Whitespace (Input, Pos);

      if Pos > Input'Last then
         exit;
      end if;

      if Input (Pos) = '<' then
         if Pos < Input'Last and then Input (Pos + 1) = '/' then
            -- Closing tag
            Pos := Process_Closing_Tag (Input, Pos, State);
            pragma Assert (State.Stack_Depth < State.Stack_Depth'Old or
                          State.Has_Error);
         else
            -- Opening tag
            Pos := Process_Opening_Tag (Input, Pos, State);
            pragma Assert (State.Stack_Depth > State.Stack_Depth'Old or
                          State.Stack_Depth = State.Stack_Depth'Old or
                          State.Has_Error);
         end if;
      else
         -- Text content
         Pos := Process_Text (Input, Pos, State);
      end if;

      pragma Assert (Pos > Pos'Old or State.Has_Error);
   end loop;
end Parse_Internal;
```

### SML.DOM Package

#### Child_Count Implementation

```ada
function Child_Count (Doc : Document; Node : Node_Id) return Natural is
   Count : Natural := 0;
   Current : Node_Id;
begin
   if Kind (Doc, Node) = Text then
      return 0;
   end if;

   Current := First_Child (Doc, Node);

   while Current /= Null_Node loop
      pragma Loop_Variant (Decreases => Max_Children - Count);
      pragma Loop_Invariant (
         Count <= Max_Children and
         Is_Valid_Node (Doc, Current)
      );

      Count := Count + 1;

      exit when Count = Max_Children;  -- Safety bound

      Current := Next_Sibling (Doc, Current);
   end loop;

   return Count;
end Child_Count;
```

#### Depth Calculation

```ada
function Depth (Doc : Document; Node : Node_Id) return Natural is
   Current : Node_Id := Node;
   D : Natural := 0;
begin
   while Current /= Null_Node and then Parent (Doc, Current) /= Null_Node loop
      pragma Loop_Variant (Decreases => Max_Tree_Depth - D);
      pragma Loop_Invariant (
         D <= Max_Tree_Depth and
         Is_Valid_Node (Doc, Current)
      );

      Current := Parent (Doc, Current);
      D := D + 1;

      exit when D = Max_Tree_Depth;  -- Safety bound
   end loop;

   return D;
end Depth;
```

## Common Pitfalls and Solutions

### Pitfall 1: Unsigned Type Underflow

**Problem:**
```ada
-- WRONG: Can cause underflow
while Pos >= Text'First loop
   pragma Loop_Variant (Decreases => Pos);  -- Fails when Pos = 0
   Pos := Pos - 1;
end loop;
```

**Solution:**
```ada
-- CORRECT: Prevent underflow
while Pos >= Text'First loop
   pragma Loop_Variant (Decreases => Pos - Text'First + 1);

   -- Process...

   exit when Pos = Text'First;
   Pos := Pos - 1;
end loop;
```

### Pitfall 2: Variable Step Without Progress Guarantee

**Problem:**
```ada
-- WRONG: Step might be 0
while Pos <= Text'Last loop
   pragma Loop_Variant (Decreases => Text'Last - Pos + 1);
   Step := Compute_Step (...);  -- Might return 0
   Pos := Pos + Step;  -- No progress if Step = 0!
end loop;
```

**Solution:**
```ada
-- CORRECT: Ensure minimum progress
while Pos <= Text'Last loop
   pragma Loop_Variant (Decreases => Text'Last - Pos + 1);

   Step := Compute_Step (...);

   if Step = 0 then
      Step := 1;  -- Minimum progress
      -- Or handle error and exit
   end if;

   Pos := Pos + Step;
   pragma Assert (Pos > Pos'Old);
end loop;
```

### Pitfall 3: Missing Invariant for Variant

**Problem:**
```ada
-- WRONG: Variant without supporting invariant
while Condition loop
   pragma Loop_Variant (Decreases => Measure);
   -- No invariant to bound Measure
end loop;
```

**Solution:**
```ada
-- CORRECT: Invariant supports variant
while Condition loop
   pragma Loop_Variant (Decreases => Measure);
   pragma Loop_Invariant (
      Measure >= 0 and Measure <= Initial_Measure
   );
end loop;
```

### Pitfall 4: Complex Exit Conditions

**Problem:**
```ada
-- WRONG: Multiple exits without proper variant
loop
   exit when Condition_1;
   -- Process...
   exit when Condition_2;
   -- Process...
   pragma Loop_Variant (Decreases => Measure);  -- May not decrease on all paths
end loop;
```

**Solution:**
```ada
-- CORRECT: Ensure variant decreases on all non-exit paths
loop
   pragma Loop_Variant (Decreases => Measure);
   pragma Loop_Invariant (Measure >= 0);

   exit when Condition_1;

   -- Process ensures progress
   Process_Step;
   pragma Assert (Measure < Measure'Old);

   exit when Condition_2;
end loop;
```

## SPARK Proof Strategies

### Strategy 1: Incremental Proof

1. Start with simple variant: `pragma Loop_Variant (Decreases => X);`
2. Add invariants as needed by failed proofs
3. Add assertions to help prover
4. Use `--level=1` first, then increase

### Strategy 2: Helper Assertions

```ada
while Pos <= Text'Last loop
   pragma Loop_Variant (Decreases => Text'Last - Pos + 1);

   Old_Pos : constant Natural := Pos;  -- Remember old value

   -- Complex processing...
   Pos := New_Position (...);

   pragma Assert (Pos > Old_Pos);  -- Help prover see progress
   pragma Assert (Pos - Old_Pos >= Min_Step);  -- Minimum progress
end loop;
```

### Strategy 3: Ghost Variables

```ada
procedure Process_With_Ghost (Text : String) is
   Pos : Natural := Text'First;
   Processed : Natural := 0 with Ghost;  -- Ghost counter
begin
   while Pos <= Text'Last loop
      pragma Loop_Variant (Decreases => Text'Last - Pos + 1);
      pragma Loop_Invariant (
         Processed = Pos - Text'First and
         Processed <= Text'Length
      );

      -- Process...
      Pos := Pos + 1;
      Processed := Processed + 1;
   end loop;

   pragma Assert (Processed = Text'Length);
end Process_With_Ghost;
```

### Strategy 4: Lemma Calls

```ada
while Pos <= Text'Last loop
   pragma Loop_Variant (Decreases => Text'Last - Pos + 1);

   -- Complex UTF-8 processing
   Seq_Len := UTF8_Sequence_Length (Text, Pos);

   -- Call lemma to establish bounds
   Lemma_UTF8_Sequence_Bounded (Text, Pos);
   pragma Assert (Seq_Len in 1 .. 4);

   Pos := Pos + Seq_Len;
end loop;
```

## Quick Reference

### Loop Variant Types

| Variant Type | Use Case | Example |
|-------------|----------|---------|
| `Decreases` | Forward iteration | `Decreases => Limit - Counter` |
| `Increases` | Backward iteration | `Increases => Counter - Start` |
| Lexicographic | Nested loops | `Decreases => Outer, Decreases => Inner` |

### Common Measures

| Operation | Measure | Notes |
|-----------|---------|-------|
| String scan forward | `Text'Last - Pos + 1` | Standard pattern |
| String scan backward | `Pos - Text'First + 1` | Prevent underflow |
| Tree depth-first | `Unvisited_Nodes` | Track visited set |
| Tree breadth-first | `Total_Nodes - Processed` | Level-by-level |
| Stack operations | `Max_Depth - Current_Depth` | Bounded stack |
| Queue operations | `Queue_Capacity - Queue_Size` | Bounded queue |

### Minimum Progress Requirements

| Data Type | Minimum Step | Maximum Step |
|-----------|-------------|--------------|
| ASCII text | 1 | 1 |
| UTF-8 text | 1 | 4 |
| Entity reference | 3 (`&x;`) | 6 (`&apos;`) |
| XML tag | 3 (`<a>`) | Unbounded |
| Tree level | 1 | 1 |

### SPARK Pragmas for Loops

```ada
pragma Loop_Variant (...);           -- Termination measure
pragma Loop_Invariant (...);         -- Maintained property
pragma Assert (...);                 -- Helper assertion
pragma Assume (...);                 -- Last resort (needs justification)
pragma Annotate (GNATprove, ...);   -- Prover hints
```

## Conclusion

Every loop in the SML library must have:

1. **A decreasing variant** that reaches zero
2. **Supporting invariants** that bound the variant
3. **Progress guarantees** (minimum step > 0)
4. **Safety bounds** to prevent overflow/underflow

Following these patterns ensures all loops in the SML library have formally proven termination at SPARK level 4.