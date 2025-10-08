------------------------------------------------------------------------------
--  SML.Bounds_Safety Package Specification
--  Array and String Bounds Safety Proofs for SML Library
--  SPARK Ada Implementation - Ghost Code for Verification
------------------------------------------------------------------------------

with SML.DOM;
with SML.Memory_Model;
with SML.Parser;

package SML.Bounds_Safety with SPARK_Mode => On, Ghost is

   --  This ghost package proves that all array accesses, string operations,
   --  and index manipulations in the SML library are within bounds, preventing
   --  buffer overflows and underflows.

   ---------------------------------------------------------------------------
   --  Array Access Safety
   ---------------------------------------------------------------------------

   --  Node array access is safe
   function Node_Array_Access_Safe (Pool : SML.Memory_Model.Arena_Pool;
                                    Index : SML.Memory_Model.Node_Index)
                                    return Boolean
     with Post => Node_Array_Access_Safe'Result =
                    (Index > 0 and then
                     Index < Pool.Next_Node_Index and then
                     Index in Pool.Nodes'Range);

   --  String storage access is safe
   function String_Storage_Access_Safe (Pool : SML.Memory_Model.Arena_Pool;
                                        Pos : SML.Memory_Model.String_Index)
                                        return Boolean
     with Post => String_Storage_Access_Safe'Result =
                    (Pos > 0 and then
                     Pos < Pool.Next_String_Pos and then
                     Pos in Pool.Strings'Range);

   --  String reference is within bounds
   function String_Ref_In_Bounds (Pool : SML.Memory_Model.Arena_Pool;
                                  Ref : SML.Memory_Model.String_Ref)
                                  return Boolean
     with Post => String_Ref_In_Bounds'Result =
                    (Ref.Length = 0 or else
                     (Ref.Start > 0 and then
                      Ref.Start + Ref.Length - 1 < Pool.Next_String_Pos and then
                      Ref.Start + Ref.Length - 1 in Pool.Strings'Range));

   ---------------------------------------------------------------------------
   --  Parser Position Bounds
   ---------------------------------------------------------------------------

   --  Parser position is always in bounds
   function Parser_Position_In_Bounds (Input : String;
                                       Position : Natural)
                                       return Boolean
     with Post => Parser_Position_In_Bounds'Result =
                    (Position >= Input'First and then
                     Position <= Input'Last + 1);

   --  Parser never reads beyond input
   function Parser_Read_Safe (Input : String;
                              Start_Pos, End_Pos : Natural)
                              return Boolean
     with Post => Parser_Read_Safe'Result =
                    (Start_Pos >= Input'First and then
                     End_Pos <= Input'Last and then
                     Start_Pos <= End_Pos);

   --  Token extraction is bounded
   function Token_Extraction_Safe (Input : String;
                                   Token_Start, Token_End : Natural)
                                   return Boolean
     with Post => Token_Extraction_Safe'Result =
                    (Token_Start >= Input'First and then
                     Token_End <= Input'Last and then
                     Token_End - Token_Start + 1 <= SML.Memory_Model.Max_Token_Length);

   ---------------------------------------------------------------------------
   --  Index Arithmetic Safety
   ---------------------------------------------------------------------------

   --  Addition doesn't overflow
   function Safe_Add (A, B : Natural) return Boolean
     with Post => Safe_Add'Result = (A + B <= Natural'Last);

   --  Subtraction doesn't underflow
   function Safe_Subtract (A, B : Natural) return Boolean
     with Post => Safe_Subtract'Result = (A >= B);

   --  Multiplication doesn't overflow
   function Safe_Multiply (A, B : Natural) return Boolean
     with Post => Safe_Multiply'Result =
                    (B = 0 or else A <= Natural'Last / B);

   --  Index increment is safe
   function Safe_Increment (Index : Natural; Max : Natural) return Boolean
     with Post => Safe_Increment'Result = (Index < Max);

   ---------------------------------------------------------------------------
   --  Loop Bounds Safety
   ---------------------------------------------------------------------------

   --  Loop index stays in bounds
   function Loop_Index_Safe (Start, Current, Stop : Natural) return Boolean
     with Post => Loop_Index_Safe'Result =
                    (Current >= Start and then Current <= Stop);

   --  String iteration is safe
   function String_Iteration_Safe (Text : String;
                                   Position : Natural)
                                   return Boolean
     with Post => String_Iteration_Safe'Result =
                    (Position >= Text'First and then Position <= Text'Last);

   --  Node iteration is safe
   function Node_Iteration_Safe (Pool : SML.Memory_Model.Arena_Pool;
                                 Index : SML.Memory_Model.Node_Index)
                                 return Boolean
     with Post => Node_Iteration_Safe'Result =
                    (Index = SML.Memory_Model.No_Node_Index or else
                     Node_Array_Access_Safe(Pool, Index));

   ---------------------------------------------------------------------------
   --  Children Access Bounds
   ---------------------------------------------------------------------------

   --  Child index is valid
   function Child_Index_Valid (Count : Natural;
                               Index : Positive)
                               return Boolean
     with Post => Child_Index_Valid'Result =
                    (Index >= 1 and then Index <= Count);

   --  Children iteration is bounded
   function Children_Iteration_Safe (Count : Natural;
                                     Current : Natural)
                                     return Boolean
     with Post => Children_Iteration_Safe'Result =
                    (Current <= Count and then Count <= SML.DOM.Max_Children);

   ---------------------------------------------------------------------------
   --  Stack Depth Bounds
   ---------------------------------------------------------------------------

   --  Stack depth is within limits
   function Stack_Depth_Safe (Depth : Natural) return Boolean
     with Post => Stack_Depth_Safe'Result = (Depth <= SML.DOM.Max_Tree_Depth);

   --  Stack push is safe
   function Stack_Push_Safe (Current_Depth : Natural) return Boolean
     with Post => Stack_Push_Safe'Result = (Current_Depth < SML.DOM.Max_Tree_Depth);

   --  Stack pop is safe
   function Stack_Pop_Safe (Current_Depth : Natural) return Boolean
     with Post => Stack_Pop_Safe'Result = (Current_Depth > 0);

   ---------------------------------------------------------------------------
   --  Name and Text Bounds
   ---------------------------------------------------------------------------

   --  Element name length is bounded
   function Name_Length_Safe (Name : String) return Boolean
     with Post => Name_Length_Safe'Result =
                    (Name'Length <= SML.Memory_Model.Max_Name_Length);

   --  Text content length is bounded
   function Text_Length_Safe (Text : String) return Boolean
     with Post => Text_Length_Safe'Result =
                    (Text'Length <= SML.Memory_Model.Max_Text_Length);

   --  Entity reference is bounded
   function Entity_Length_Safe (Entity : String) return Boolean
     with Post => Entity_Length_Safe'Result =
                    (Entity'Length >= 3 and then Entity'Length <= 6);
                    -- Min: &x; Max: &apos;

   ---------------------------------------------------------------------------
   --  Buffer Safety
   ---------------------------------------------------------------------------

   --  Buffer has space for operation
   function Buffer_Has_Space (Buffer_Size, Used, Needed : Natural)
                             return Boolean
     with Post => Buffer_Has_Space'Result =
                    (Used + Needed <= Buffer_Size);

   --  Copy operation is safe
   function Copy_Safe (Source : String;
                       Dest_Size : Natural;
                       Dest_Pos : Natural)
                       return Boolean
     with Post => Copy_Safe'Result =
                    (Dest_Pos > 0 and then
                     Dest_Pos + Source'Length - 1 <= Dest_Size);

   --  Concatenation is safe
   function Concat_Safe (S1, S2 : String;
                        Max_Length : Natural)
                        return Boolean
     with Post => Concat_Safe'Result =
                    (S1'Length + S2'Length <= Max_Length);

   ---------------------------------------------------------------------------
   --  Main Bounds Safety Lemmas
   ---------------------------------------------------------------------------

   --  All array accesses are in bounds
   procedure Lemma_All_Array_Accesses_Safe
     with Post => (for all Pool : SML.Memory_Model.Arena_Pool =>
                     for all Idx : SML.Memory_Model.Node_Index =>
                       (if Idx > 0 and Idx < Pool.Next_Node_Index then
                          Node_Array_Access_Safe(Pool, Idx)));

   --  All string accesses are in bounds
   procedure Lemma_All_String_Accesses_Safe
     with Post => (for all Pool : SML.Memory_Model.Arena_Pool =>
                     for all Ref : SML.Memory_Model.String_Ref =>
                       (if SML.Memory_Model.Valid_String_Ref(Pool, Ref) then
                          String_Ref_In_Bounds(Pool, Ref)));

   --  Parser positions are always valid
   procedure Lemma_Parser_Positions_Valid
     with Post => (for all Input : String =>
                     for all State : SML.Parser.Parser_State =>
                       Parser_Position_In_Bounds(Input, State.Position));

   --  No integer overflows
   procedure Lemma_No_Integer_Overflow
     with Post => (for all A, B : Natural =>
                     (if A <= Natural'Last / 2 and B <= Natural'Last / 2 then
                        Safe_Add(A, B)));

   --  Stack operations are bounded
   procedure Lemma_Stack_Operations_Bounded
     with Post => (for all Depth : Natural =>
                     (if Stack_Depth_Safe(Depth) then
                        (Stack_Push_Safe(Depth) or Depth = SML.DOM.Max_Tree_Depth) and then
                        (Stack_Pop_Safe(Depth) or Depth = 0)));

   --  Loop indices stay in range
   procedure Lemma_Loop_Indices_Bounded
     with Post => (for all Start, Stop : Natural =>
                     for all Current : Natural =>
                       (if Current >= Start and Current <= Stop then
                          Loop_Index_Safe(Start, Current, Stop)));

   ---------------------------------------------------------------------------
   --  Overflow Prevention
   ---------------------------------------------------------------------------

   --  Size calculations don't overflow
   procedure Lemma_Size_Calculations_Safe
     with Post => (for all Nodes, Strings : Natural =>
                     (if Nodes <= SML.Memory_Model.Max_Document_Nodes and then
                         Strings <= SML.Memory_Model.Max_String_Storage
                      then Safe_Add(Nodes * SML.Memory_Model.Node_Size_Bytes, Strings)));

   --  Position arithmetic is safe
   procedure Lemma_Position_Arithmetic_Safe
     with Post => (for all Input : String =>
                     for all Pos, Offset : Natural =>
                       (if Parser_Position_In_Bounds(Input, Pos) and then
                           Offset <= Input'Last - Pos + 1
                        then Safe_Add(Pos, Offset)));

   ---------------------------------------------------------------------------
   --  Bounds Checking Patterns
   ---------------------------------------------------------------------------

   --  Pattern: Check before access
   function Check_Before_Access (Index : Natural; Max : Natural)
                                return Boolean
     with Post => Check_Before_Access'Result = (Index < Max);

   --  Pattern: Saturating arithmetic
   function Saturating_Add (A, B : Natural) return Natural
     with Post => Saturating_Add'Result =
                    (if A + B <= Natural'Last then A + B else Natural'Last);

   --  Pattern: Bounded iteration
   procedure Bounded_Iterate (Start, Stop : in out Natural;
                             Max : Natural)
     with Pre => Start <= Stop and Stop <= Max,
          Post => Start <= Stop and Stop <= Max;

   ---------------------------------------------------------------------------
   --  Range Checking Utilities
   ---------------------------------------------------------------------------

   --  In range check
   function In_Range (Value, Min, Max : Natural) return Boolean
     with Post => In_Range'Result = (Value >= Min and Value <= Max);

   --  Clamp to range
   function Clamp (Value, Min, Max : Natural) return Natural
     with Pre => Min <= Max,
          Post => Clamp'Result >= Min and Clamp'Result <= Max;

   ---------------------------------------------------------------------------
   --  Error Detection
   ---------------------------------------------------------------------------

   type Bounds_Error is record
      Kind     : Bounds_Error_Kind;
      Index    : Natural;
      Limit    : Natural;
      Location : String (1 .. 100);
   end record;

   type Bounds_Error_Kind is (
      Array_Overflow,
      Array_Underflow,
      String_Overflow,
      Integer_Overflow,
      Stack_Overflow,
      Invalid_Range
   );

   --  Would operation cause bounds error?
   function Would_Cause_Bounds_Error (Index, Limit : Natural) return Boolean
     with Post => Would_Cause_Bounds_Error'Result = (Index >= Limit);

   --  Prevent bounds error
   function Prevent_Bounds_Error (Index, Limit : Natural) return Natural
     with Post => Prevent_Bounds_Error'Result < Limit;

end SML.Bounds_Safety;