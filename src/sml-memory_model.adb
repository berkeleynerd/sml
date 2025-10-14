------------------------------------------------------------------------------
--  SML.Memory_Model Package Body
--  Memory Management Implementation
--  SPARK Ada Implementation
------------------------------------------------------------------------------

package body SML.Memory_Model
  with SPARK_Mode => On
is

   --  Allocation procedures (SPARK-compatible)

   procedure Allocate_Node
     (Pool : in out Arena_Pool; Kind : Node_Kind; Index : out Node_Index) is
      pragma Unreferenced (Kind);
   begin
      Index := Pool.Next_Node_Index;
      --  Node discriminant is set during array initialization
      --  Individual assignment after allocation if needed
      Pool.Next_Node_Index := Pool.Next_Node_Index + 1;
      Pool.Allocated_Nodes := Pool.Allocated_Nodes + 1;
   end Allocate_Node;

   procedure Allocate_String
     (Pool : in out Arena_Pool; Text : String; Ref : out String_Ref)
   is
      Start_Pos : constant String_Index := Pool.Next_String_Pos;
   begin
      Ref := (Start => Start_Pos, Length => Text'Length);

      if Text'Length > 0 then
         for I in Text'Range loop
            Pool.Strings (Start_Pos + (I - Text'First)) := Text (I);
         end loop;
         Pool.Next_String_Pos := Pool.Next_String_Pos + Text'Length;
         Pool.Allocated_Bytes := Pool.Allocated_Bytes + Text'Length;
      end if;
   end Allocate_String;

   --  Check functions

   function Can_Allocate_Node (Pool : Arena_Pool) return Boolean is
   begin
      return Pool.Next_Node_Index <= Max_Document_Nodes;
   end Can_Allocate_Node;

   function Can_Allocate_String
     (Pool : Arena_Pool; Size : Natural) return Boolean is
   begin
      return Size <= Max_String_Storage - Pool.Next_String_Pos + 1;
   end Can_Allocate_String;

   --  Memory accounting

   function Memory_Used (Pool : Arena_Pool) return Natural is
   begin
      return Node_Memory_Used (Pool) + String_Memory_Used (Pool);
   end Memory_Used;

   function Node_Memory_Used (Pool : Arena_Pool) return Natural is
   begin
      return Pool.Allocated_Nodes * Node_Size_Bytes;
   end Node_Memory_Used;

   function String_Memory_Used (Pool : Arena_Pool) return Natural is
   begin
      return Pool.Allocated_Bytes;
   end String_Memory_Used;

   function Remaining_Node_Capacity (Pool : Arena_Pool) return Natural is
   begin
      return Max_Document_Nodes - Pool.Allocated_Nodes;
   end Remaining_Node_Capacity;

   function Remaining_String_Capacity (Pool : Arena_Pool) return Natural is
   begin
      return Max_String_Storage - Pool.Allocated_Bytes;
   end Remaining_String_Capacity;

   --  Reset

   procedure Reset_Arena (Pool : in out Arena_Pool) is
   begin
      --  Reset allocation counters first to satisfy predicate
      Pool.Allocated_Nodes := 0;
      Pool.Allocated_Bytes := 0;
      Pool.High_Water_Mark := 0;
      --  Then reset indices (predicate: Allocated_Nodes <= Next_Node_Index)
      Pool.Next_Node_Index := 1;
      Pool.Next_String_Pos := 1;
   end Reset_Arena;

   --  String operations

   procedure Store_String
     (Pool : in out Arena_Pool; Ref : String_Ref; Text : String) is
   begin
      if Text'Length > 0 and then Ref.Start > 0 then
         for I in 1 .. Text'Length loop
            Pool.Strings (Ref.Start + I - 1) := Text (Text'First + I - 1);
         end loop;
      end if;
   end Store_String;

   function Get_String (Pool : Arena_Pool; Ref : String_Ref) return String is
      Result : String (1 .. Ref.Length) := (others => ' ');
   begin
      if Ref.Length = 0 then
         return "";
      end if;

      for I in 1 .. Ref.Length loop
         Result (I) := Pool.Strings (Ref.Start + I - 1);
      end loop;

      return Result;
   end Get_String;

   function Valid_String_Ref
     (Pool : Arena_Pool; Ref : String_Ref) return Boolean is
   begin
      return
        Ref.Length = 0
        or else (Ref.Start > 0
                 and then Ref.Start + Ref.Length - 1
                          <= Pool.Next_String_Pos - 1);
   end Valid_String_Ref;

   --  Ghost functions

   function String_Stored
     (Pool : Arena_Pool; Ref : String_Ref; Text : String) return Boolean is
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
     (Pool : Arena_Pool; Input_Size : Natural) return Boolean is
   begin
      return Memory_Used (Pool) <= Input_Size * Memory_Expansion_Factor;
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

   --  Node access

   function Get_Node (Pool : Arena_Pool; Index : Node_Index) return Node is
   begin
      return Pool.Nodes (Index);
   end Get_Node;

   procedure Set_Node (Pool : in out Arena_Pool; Index : Node_Index; N : Node)
   is
   begin
      Pool.Nodes (Index) := N;
   end Set_Node;

   function Valid_Node_Index
     (Pool : Arena_Pool; Index : Node_Index) return Boolean is
   begin
      return Index > No_Node_Index and then Index < Pool.Next_Node_Index;
   end Valid_Node_Index;

   --  Lemmas (ghost, minimal implementations)

   procedure Lemma_Arena_No_Overflow (Pool : Arena_Pool) is
      pragma Unreferenced (Pool);
   begin
      null;
   end Lemma_Arena_No_Overflow;

   procedure Lemma_Allocated_Nodes_Valid (Pool : Arena_Pool) is
      pragma Unreferenced (Pool);
   begin
      null;
   end Lemma_Allocated_Nodes_Valid;

   procedure Lemma_Memory_Monotonic (Pool_Before, Pool_After : Arena_Pool) is
      pragma Unreferenced (Pool_Before, Pool_After);
   begin
      null;
   end Lemma_Memory_Monotonic;

   procedure Lemma_Reset_Deallocates_All
     (Pool_Before : Arena_Pool; Pool_After : Arena_Pool)
   is
      pragma Unreferenced (Pool_Before, Pool_After);
   begin
      null;
   end Lemma_Reset_Deallocates_All;

end SML.Memory_Model;
