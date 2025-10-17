------------------------------------------------------------------------------
--  SML.Memory_Model Package Specification
--  Concrete Memory Management Model for SML Library
--  SPARK Ada Implementation with Formal Memory Safety
------------------------------------------------------------------------------

with SML_Memory_Model_Types; use SML_Memory_Model_Types;
with SML_Memory_Model_Ghost;

package SML.Memory_Model
  with SPARK_Mode => On
is

   --  This package provides concrete memory management operations for the SML
   --  library using arena allocation. All types are defined in
   --  SML_Memory_Model_Types, and ghost functions are in SML_Memory_Model_Ghost.

   ---------------------------------------------------------------------------
   --  Allocation Functions
   ---------------------------------------------------------------------------

   --  Allocate a new node in the arena (SPARK-compatible procedure)
   procedure Allocate_Node
     (Pool : in out Arena_Pool; Kind : Node_Kind; Index : out Node_Index)
   with
     Pre =>
       Pool.Next_Node_Index <= Max_Document_Nodes
       and then Can_Allocate_Node (Pool),
     Post =>
       Index > No_Node_Index
       and then Pool.Next_Node_Index > Pool.Next_Node_Index'Old
       and then Pool.Allocated_Nodes > Pool.Allocated_Nodes'Old;

   --  Allocate string storage in the arena (SPARK-compatible procedure)
   procedure Allocate_String
     (Pool : in out Arena_Pool; Text : String; Ref : out String_Ref)
   with
     Pre =>
       Text'Length <= Max_String_Storage
       and then Can_Allocate_String (Pool, Text'Length),
     Post =>
       Ref.Length = Text'Length
       and then Pool.Next_String_Pos >= Pool.Next_String_Pos'Old + Text'Length;

   --  Check if node allocation is possible
   function Can_Allocate_Node (Pool : Arena_Pool) return Boolean
   with
     Post =>
       Can_Allocate_Node'Result = (Pool.Next_Node_Index <= Max_Document_Nodes);

   --  Check if string allocation is possible
   function Can_Allocate_String
     (Pool : Arena_Pool; Size : Natural) return Boolean
   with
     Post =>
       Can_Allocate_String'Result
       = (Size <= Max_String_Storage - Pool.Next_String_Pos + 1);

   ---------------------------------------------------------------------------
   --  Memory Accounting Functions
   ---------------------------------------------------------------------------

   --  Get total memory used by arena
   function Memory_Used (Pool : Arena_Pool) return Natural
   with
     Post =>
       Memory_Used'Result
       = Node_Memory_Used (Pool) + String_Memory_Used (Pool);

   --  Memory used by nodes
   function Node_Memory_Used (Pool : Arena_Pool) return Natural
   with
     Post => Node_Memory_Used'Result = Pool.Allocated_Nodes * Node_Size_Bytes;

   --  Memory used by strings
   function String_Memory_Used (Pool : Arena_Pool) return Natural
   with Post => String_Memory_Used'Result = Pool.Allocated_Bytes;

   --  Get remaining capacity
   function Remaining_Node_Capacity (Pool : Arena_Pool) return Natural
   with
     Post =>
       Remaining_Node_Capacity'Result
       = Max_Document_Nodes - Pool.Allocated_Nodes;

   function Remaining_String_Capacity (Pool : Arena_Pool) return Natural
   with
     Post =>
       Remaining_String_Capacity'Result
       = Max_String_Storage - Pool.Allocated_Bytes;

   ---------------------------------------------------------------------------
   --  Deallocation and Reset
   ---------------------------------------------------------------------------

   --  Reset arena to empty state (deallocates all)
   procedure Reset_Arena (Pool : in out Arena_Pool)
   with
     Post =>
       Pool.Next_Node_Index = 1
       and then Pool.Next_String_Pos = 1
       and then Pool.Allocated_Nodes = 0
       and then Pool.Allocated_Bytes = 0;

   --  No individual deallocation (arena model)
   --  Entire arena is freed when Document is finalized

   ---------------------------------------------------------------------------
   --  String Operations
   ---------------------------------------------------------------------------

   --  Store string in arena
   procedure Store_String
     (Pool : in out Arena_Pool; Ref : String_Ref; Text : String)
   with
     Pre =>
       Text'Length = Ref.Length
       and then Ref.Start > 0
       and then Ref.Start + Ref.Length - 1 <= Max_String_Storage
       and then Ref.Start + Ref.Length - 1 <= Pool.Next_String_Pos,
     Post => SML_Memory_Model_Ghost.String_Stored (Pool, Ref, Text);

   --  Retrieve string from arena
   function Get_String (Pool : Arena_Pool; Ref : String_Ref) return String
   with
     Pre => Valid_String_Ref (Pool, Ref),
     Post => Get_String'Result'Length = Ref.Length;

   --  Check if string reference is valid
   function Valid_String_Ref
     (Pool : Arena_Pool; Ref : String_Ref) return Boolean
   with
     Post =>
       Valid_String_Ref'Result
       = (Ref.Length = 0
          or else (Ref.Start > 0
                   and then Ref.Start + Ref.Length - 1
                            <= Pool.Next_String_Pos - 1));

   ---------------------------------------------------------------------------
   --  Ghost Functions for Proofs
   ---------------------------------------------------------------------------
   --  These are now implemented in SML_Memory_Model_Ghost (no Import needed)

   function String_Stored
     (Pool : Arena_Pool; Ref : String_Ref; Text : String) return Boolean
     renames SML_Memory_Model_Ghost.String_Stored;

   function Memory_Bounded_By_Input
     (Pool : Arena_Pool; Input_Size : Natural) return Boolean
     renames SML_Memory_Model_Ghost.Memory_Bounded_By_Input;

   function Arena_Invariants (Pool : Arena_Pool) return Boolean
     renames SML_Memory_Model_Ghost.Arena_Invariants;

   function Has_Exact_Allocation_Count (Pool : Arena_Pool) return Boolean
     renames SML_Memory_Model_Ghost.Has_Exact_Allocation_Count;

   ---------------------------------------------------------------------------
   --  Memory Safety Lemmas
   ---------------------------------------------------------------------------

   procedure Lemma_Arena_No_Overflow (Pool : Arena_Pool)
     renames SML_Memory_Model_Ghost.Lemma_Arena_No_Overflow;

   procedure Lemma_Allocated_Nodes_Valid (Pool : Arena_Pool)
     renames SML_Memory_Model_Ghost.Lemma_Allocated_Nodes_Valid;

   procedure Lemma_Memory_Monotonic (Pool_Before, Pool_After : Arena_Pool)
     renames SML_Memory_Model_Ghost.Lemma_Memory_Monotonic;

   procedure Lemma_Reset_Deallocates_All
     (Pool_Before : Arena_Pool; Pool_After : Arena_Pool)
     renames SML_Memory_Model_Ghost.Lemma_Reset_Deallocates_All;

   ---------------------------------------------------------------------------
   --  Node Access Functions
   ---------------------------------------------------------------------------

   --  Get node from arena
   function Get_Node (Pool : Arena_Pool; Index : Node_Index) return Node
   with Pre => Valid_Node_Index (Pool, Index);

   --  Update node in arena (preserves allocation counts)
   procedure Set_Node (Pool : in out Arena_Pool; Index : Node_Index; N : Node)
   with Pre => Valid_Node_Index (Pool, Index);

   --  Check if node index is valid
   function Valid_Node_Index
     (Pool : Arena_Pool; Index : Node_Index) return Boolean
   with
     Post =>
       Valid_Node_Index'Result
       = (Index > No_Node_Index and then Index < Pool.Next_Node_Index);

end SML.Memory_Model;