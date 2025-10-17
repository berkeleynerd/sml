------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--               Memory Model Ghost Package - Formal Verification           --
------------------------------------------------------------------------------

package body SML_Memory_Model_Ghost
with
   SPARK_Mode => On
is

   ---------------------------------------------------------------------------
   --  Ghost Function Implementations
   ---------------------------------------------------------------------------

   function String_Stored
     (Pool : Arena_Pool; Ref : String_Ref; Text : String) return Boolean
   is
   begin
      if Text'Length /= Ref.Length then
         return False;
      end if;

      for I in 1 .. Ref.Length loop
         if Pool.Strings (Ref.Start + I - 1) /= Text (Text'First + I - 1) then
            return False;
         end if;
      end loop;

      return True;
   end String_Stored;

   function Memory_Bounded_By_Input
     (Pool : Arena_Pool; Input_Size : Natural) return Boolean
   is
   begin
      return (Pool.Allocated_Nodes * Node_Size_Bytes + Pool.Allocated_Bytes)
             <= Input_Size * Memory_Expansion_Factor;
   end Memory_Bounded_By_Input;

   function Arena_Invariants (Pool : Arena_Pool) return Boolean is
   begin
      return
        Pool.Next_Node_Index >= 1
        and then Pool.Next_String_Pos >= 1
        and then Pool.Allocated_Nodes < Pool.Next_Node_Index
        and then Pool.Allocated_Bytes < Pool.Next_String_Pos
        and then Pool.High_Water_Mark >= Pool.Allocated_Bytes;
   end Arena_Invariants;

   function Has_Exact_Allocation_Count (Pool : Arena_Pool) return Boolean is
   begin
      return Pool.Allocated_Nodes = Pool.Next_Node_Index - 1;
   end Has_Exact_Allocation_Count;

   ---------------------------------------------------------------------------
   --  Lemma Implementations
   ---------------------------------------------------------------------------

   procedure Lemma_Arena_No_Overflow (Pool : Arena_Pool) is
      pragma Unreferenced (Pool);
   begin
      null;  -- Lemma body; proved by contracts
   end Lemma_Arena_No_Overflow;

   procedure Lemma_Allocated_Nodes_Valid (Pool : Arena_Pool) is
      pragma Unreferenced (Pool);
   begin
      null;  -- Lemma body; proved by contracts
   end Lemma_Allocated_Nodes_Valid;

   procedure Lemma_Memory_Monotonic (Pool_Before, Pool_After : Arena_Pool) is
      pragma Unreferenced (Pool_Before, Pool_After);
   begin
      null;  -- Lemma body; proved by contracts
   end Lemma_Memory_Monotonic;

   procedure Lemma_Reset_Deallocates_All
     (Pool_Before : Arena_Pool; Pool_After : Arena_Pool)
   is
      pragma Unreferenced (Pool_Before, Pool_After);
   begin
      null;  -- Lemma body; proved by contracts
   end Lemma_Reset_Deallocates_All;

end SML_Memory_Model_Ghost;