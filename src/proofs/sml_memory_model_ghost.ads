------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                     Memory Model Ghost Functions                         --
------------------------------------------------------------------------------

with SML_Types;
with SML_Types.Memory; use SML_Types.Memory;

package SML_Memory_Model_Ghost
  with Ghost, SPARK_Mode
is
   --  Memory usage functions (needed by ghost functions)
   function Memory_Used (Pool : Arena_Pool) return Natural
     with Post =>
       Memory_Used'Result = Node_Memory_Used (Pool) + String_Memory_Used (Pool);
   
   function Node_Memory_Used (Pool : Arena_Pool) return Natural
     with Post => Node_Memory_Used'Result = Pool.Allocated_Nodes * Node_Size_Bytes;
   
   function String_Memory_Used (Pool : Arena_Pool) return Natural
     with Post => String_Memory_Used'Result = Pool.Allocated_Bytes;
   
   --  Check if node index is valid
   function Valid_Node_Index
     (Pool : Arena_Pool; Index : Node_Index) return Boolean
     with Post =>
       Valid_Node_Index'Result =
         (Index > No_Node_Index and then Index < Pool.Next_Node_Index);

   --  Check if string reference is valid
   function Valid_String_Ref
     (Pool : Arena_Pool; Ref : String_Ref) return Boolean
     with Post =>
       Valid_String_Ref'Result =
         (Ref.Start > 0 and then Ref.Start + Ref.Length - 1 <= Pool.Next_String_Pos - 1);

   ---------------------------------------------------------------------------
   --  Ghost Functions for Memory Verification
   ---------------------------------------------------------------------------
   
   --  Check if string is stored at reference
   function String_Stored
     (Pool : Arena_Pool; Ref : String_Ref; Text : String) return Boolean
     with
       Pre => Text'Length = Ref.Length,
       Post =>
         String_Stored'Result =
           (for all I in 1 .. Ref.Length =>
              Pool.Strings (Ref.Start + I - 1) = Text (Text'First + I - 1));
   
   --  Memory usage bounded by input size
   function Memory_Bounded_By_Input
     (Pool : Arena_Pool; Input_Size : Natural) return Boolean
     with
       Post =>
         Memory_Bounded_By_Input'Result =
           (Memory_Used (Pool) <= Input_Size * Memory_Expansion_Factor);
   
   --  Check arena invariants
   function Arena_Invariants (Pool : Arena_Pool) return Boolean
     with
       Post =>
         Arena_Invariants'Result =
           (Pool.Next_Node_Index >= 1
            and then Pool.Next_String_Pos >= 1
            and then Pool.Allocated_Nodes < Pool.Next_Node_Index
            and then Pool.Allocated_Bytes < Pool.Next_String_Pos
            and then Pool.High_Water_Mark >= Pool.Allocated_Bytes);
   
   --  Strict allocation invariant (for proofs that need exact equality)
   function Has_Exact_Allocation_Count (Pool : Arena_Pool) return Boolean
     with
       Post =>
         Has_Exact_Allocation_Count'Result =
           (Pool.Allocated_Nodes = Pool.Next_Node_Index - 1);
   
   ---------------------------------------------------------------------------
   --  Memory Safety Lemmas
   ---------------------------------------------------------------------------
   
   --  Arena allocation never overflows
   procedure Lemma_Arena_No_Overflow (Pool : Arena_Pool)
     with
       Post =>
         Pool.Next_Node_Index <= SML_Types.Max_Document_Nodes + 1
         and then Pool.Next_String_Pos <= SML_Types.Max_String_Storage + 1;
   
   --  All allocated nodes are valid
   procedure Lemma_Allocated_Nodes_Valid (Pool : Arena_Pool)
     with
       Post =>
         (for all I in 1 .. Pool.Next_Node_Index - 1 =>
            Valid_Node_Index (Pool, I));
   
   --  Memory usage is monotonic
   procedure Lemma_Memory_Monotonic (Pool_Before, Pool_After : Arena_Pool)
     with
       Pre =>
         Pool_After.Allocated_Nodes >= Pool_Before.Allocated_Nodes
         and then Pool_After.Allocated_Bytes >= Pool_Before.Allocated_Bytes,
       Post => Memory_Used (Pool_After) >= Memory_Used (Pool_Before);
   
   --  Reset deallocates everything
   procedure Lemma_Reset_Deallocates_All
     (Pool_Before : Arena_Pool; Pool_After : Arena_Pool)
     with
       Pre =>
         Pool_After.Next_Node_Index = 1 and then Pool_After.Allocated_Nodes = 0,
       Post => Memory_Used (Pool_After) = 0;

end SML_Memory_Model_Ghost;
