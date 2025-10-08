------------------------------------------------------------------------------
--  SML.Memory_Model Package Specification
--  Concrete Memory Management Model for SML Library
--  SPARK Ada Implementation with Formal Memory Safety
------------------------------------------------------------------------------

limited with SML.DOM;

package SML.Memory_Model with SPARK_Mode => On is

   --  This package defines the concrete memory management model for the SML
   --  library using arena allocation. All nodes and strings are allocated
   --  from fixed-size pools to enable bounded memory proofs.

   ---------------------------------------------------------------------------
   --  Memory Bounds and Constants
   ---------------------------------------------------------------------------

   --  Maximum nodes based on document limits
   Max_Document_Nodes : constant Natural := 1_000_000;

   --  Maximum string storage (assumes average 100 chars per node)
   Max_String_Storage : constant Natural := 100_000_000;  -- 100MB

   --  Maximum size for element names
   Max_Name_Length : constant Natural := 100;

   --  Maximum size for text content per node
   Max_Text_Length : constant Natural := 10_000;

   --  Memory expansion factor (worst case)
   Memory_Expansion_Factor : constant Positive := 10;

   --  Size of a node in bytes (approximate)
   Node_Size_Bytes : constant Natural := 64;

   ---------------------------------------------------------------------------
   --  Node Storage Types
   ---------------------------------------------------------------------------

   --  Node index type for array-based allocation
   subtype Node_Index is Natural range 0 .. Max_Document_Nodes;

   --  Invalid node index constant
   No_Node_Index : constant Node_Index := 0;

   --  Node kind enumeration (matching DOM)
   type Node_Kind is (Element, Text);

   ---------------------------------------------------------------------------
   --  String Storage Types
   ---------------------------------------------------------------------------

   --  String storage index
   subtype String_Index is Natural range 0 .. Max_String_Storage;

   --  Character array for string storage
   type String_Storage is array (String_Index range <>) of Character;

   --  String reference within pool
   type String_Ref is record
      Start  : String_Index;    -- Starting position in pool
      Length : Natural;          -- Length of string
   end record
     with Predicate => Length <= Max_String_Storage and then
                       (if Length > 0 then Start > 0 and Start <= Max_String_Storage);

   --  Null string reference
   Null_String_Ref : constant String_Ref := (Start => 0, Length => 0);

   ---------------------------------------------------------------------------
   --  Node Type Definition
   ---------------------------------------------------------------------------

   --  Maximum children per element (local constant to avoid circular dependency)
   Max_Children_Local : constant Natural := 10000;

   --  Node structure with bounded storage (discriminated record with default)
   type Node (Kind : Node_Kind := Element) is record
      Parent_Index      : Node_Index;
      First_Child_Index : Node_Index;
      Next_Sibling_Index : Node_Index;

      --  Content based on kind discriminant
      case Kind is
         when Element =>
            Element_Name_Ref : String_Ref;
            Num_Children     : Natural;
         when Text =>
            Text_Content_Ref : String_Ref;
      end case;
   end record
     with Predicate =>
       (case Kind is
          when Element => Num_Children <= Max_Children_Local,
          when Text => First_Child_Index = No_Node_Index);

   --  Array of nodes for arena allocation (defined after Node type)
   type Node_Array is array (Node_Index range <>) of aliased Node;

   ---------------------------------------------------------------------------
   --  Arena Allocator Type
   ---------------------------------------------------------------------------

   --  Arena-based memory pool for nodes and strings
   type Arena_Pool is limited record
      --  Node storage
      Nodes           : Node_Array (1 .. Max_Document_Nodes);
      Next_Node_Index : Node_Index;

      --  String storage
      Strings         : String_Storage (1 .. Max_String_Storage);
      Next_String_Pos : String_Index;

      --  Ghost fields for memory accounting (Ghost documented in comments)
      Allocated_Nodes : Natural;
      Allocated_Bytes : Natural;
      High_Water_Mark : Natural;  -- Maximum allocation reached
   end record
     with Predicate =>
       Next_Node_Index <= Max_Document_Nodes + 1 and then
       Next_String_Pos <= Max_String_Storage + 1 and then
       Allocated_Nodes = Next_Node_Index - 1 and then
       Allocated_Bytes <= Max_String_Storage;

   ---------------------------------------------------------------------------
   --  Allocation Functions
   ---------------------------------------------------------------------------

   --  Allocate a new node in the arena (SPARK-compatible procedure)
   procedure Allocate_Node (Pool : in out Arena_Pool;
                            Kind : Node_Kind;
                            Index : out Node_Index)
     with Pre => Pool.Next_Node_Index <= Max_Document_Nodes and then
                 Can_Allocate_Node (Pool),
          Post => Index > No_Node_Index and then
                  Pool.Next_Node_Index > Pool.Next_Node_Index'Old and then
                  Pool.Allocated_Nodes > Pool.Allocated_Nodes'Old;

   --  Allocate string storage in the arena (SPARK-compatible procedure)
   procedure Allocate_String (Pool : in out Arena_Pool;
                              Text : String;
                              Ref : out String_Ref)
     with Pre => Text'Length <= Max_String_Storage and then
                 Can_Allocate_String (Pool, Text'Length),
          Post => Ref.Length = Text'Length and then
                  Pool.Next_String_Pos >= Pool.Next_String_Pos'Old + Text'Length;

   --  Check if node allocation is possible
   function Can_Allocate_Node (Pool : Arena_Pool) return Boolean
     with Post => Can_Allocate_Node'Result =
                    (Pool.Next_Node_Index <= Max_Document_Nodes);

   --  Check if string allocation is possible
   function Can_Allocate_String (Pool : Arena_Pool;
                                 Size : Natural) return Boolean
     with Post => Can_Allocate_String'Result =
                    (Size <= Max_String_Storage - Pool.Next_String_Pos + 1);

   ---------------------------------------------------------------------------
   --  Memory Accounting Functions
   ---------------------------------------------------------------------------

   --  Get total memory used by arena
   function Memory_Used (Pool : Arena_Pool) return Natural
     with Post => Memory_Used'Result =
                    Node_Memory_Used(Pool) + String_Memory_Used(Pool);

   --  Memory used by nodes
   function Node_Memory_Used (Pool : Arena_Pool) return Natural
     with Post => Node_Memory_Used'Result =
                    Pool.Allocated_Nodes * Node_Size_Bytes;

   --  Memory used by strings
   function String_Memory_Used (Pool : Arena_Pool) return Natural
     with Post => String_Memory_Used'Result = Pool.Allocated_Bytes;

   --  Get remaining capacity
   function Remaining_Node_Capacity (Pool : Arena_Pool) return Natural
     with Post => Remaining_Node_Capacity'Result =
                    Max_Document_Nodes - Pool.Allocated_Nodes;

   function Remaining_String_Capacity (Pool : Arena_Pool) return Natural
     with Post => Remaining_String_Capacity'Result =
                    Max_String_Storage - Pool.Allocated_Bytes;

   ---------------------------------------------------------------------------
   --  Deallocation and Reset
   ---------------------------------------------------------------------------

   --  Reset arena to empty state (deallocates all)
   procedure Reset_Arena (Pool : in out Arena_Pool)
     with Post => Pool.Next_Node_Index = 1 and then
                  Pool.Next_String_Pos = 1 and then
                  Pool.Allocated_Nodes = 0 and then
                  Pool.Allocated_Bytes = 0;

   --  No individual deallocation (arena model)
   --  Entire arena is freed when Document is finalized

   ---------------------------------------------------------------------------
   --  String Operations
   ---------------------------------------------------------------------------

   --  Store string in arena
   procedure Store_String (Pool : in out Arena_Pool;
                          Ref : String_Ref;
                          Text : String)
     with Pre => Text'Length = Ref.Length and then
                 Ref.Start > 0 and then
                 Ref.Start + Ref.Length - 1 <= Max_String_Storage and then
                 Ref.Start + Ref.Length - 1 <= Pool.Next_String_Pos,
          Post => String_Stored(Pool, Ref, Text);

   --  Retrieve string from arena
   function Get_String (Pool : Arena_Pool; Ref : String_Ref) return String
     with Pre => Valid_String_Ref(Pool, Ref),
          Post => Get_String'Result'Length = Ref.Length;

   --  Check if string reference is valid
   function Valid_String_Ref (Pool : Arena_Pool;
                              Ref : String_Ref) return Boolean
     with Post => Valid_String_Ref'Result =
                    (Ref.Length = 0 or else
                     (Ref.Start > 0 and then
                      Ref.Start + Ref.Length - 1 <= Pool.Next_String_Pos - 1));

   ---------------------------------------------------------------------------
   --  Ghost Functions for Proofs
   ---------------------------------------------------------------------------

   --  Check if string is stored at reference
   function String_Stored (Pool : Arena_Pool;
                           Ref : String_Ref;
                           Text : String) return Boolean
     with Ghost,
          Pre => Text'Length = Ref.Length,
          Post => String_Stored'Result =
                    (for all I in 1 .. Ref.Length =>
                       Pool.Strings(Ref.Start + I - 1) = Text(Text'First + I - 1));

   --  Memory usage bounded by input size
   function Memory_Bounded_By_Input (Pool : Arena_Pool;
                                     Input_Size : Natural) return Boolean
     with Ghost,
          Post => Memory_Bounded_By_Input'Result =
                    (Memory_Used(Pool) <= Input_Size * Memory_Expansion_Factor);

   --  Check arena invariants
   function Arena_Invariants (Pool : Arena_Pool) return Boolean
     with Ghost,
          Post => Arena_Invariants'Result =
                    (Pool.Next_Node_Index >= 1 and then
                     Pool.Next_String_Pos >= 1 and then
                     Pool.Allocated_Nodes < Pool.Next_Node_Index and then
                     Pool.Allocated_Bytes < Pool.Next_String_Pos and then
                     Pool.High_Water_Mark >= Pool.Allocated_Bytes);

   ---------------------------------------------------------------------------
   --  Node Access Functions
   ---------------------------------------------------------------------------

   --  Get node from arena
   function Get_Node (Pool : Arena_Pool; Index : Node_Index) return Node
     with Pre => Valid_Node_Index (Pool, Index);

   --  Update node in arena (preserves allocation counts)
   procedure Set_Node (Pool : in out Arena_Pool;
                      Index : Node_Index;
                      N : Node)
     with Pre => Valid_Node_Index (Pool, Index);

   --  Check if node index is valid
   function Valid_Node_Index (Pool : Arena_Pool;
                              Index : Node_Index) return Boolean
     with Post => Valid_Node_Index'Result =
                    (Index > No_Node_Index and then Index < Pool.Next_Node_Index);

   ---------------------------------------------------------------------------
   --  Memory Safety Lemmas
   ---------------------------------------------------------------------------

   --  Arena allocation never overflows
   procedure Lemma_Arena_No_Overflow (Pool : Arena_Pool)
     with Ghost,
          Post => Pool.Next_Node_Index <= Max_Document_Nodes + 1 and then
                  Pool.Next_String_Pos <= Max_String_Storage + 1;

   --  All allocated nodes are valid
   procedure Lemma_Allocated_Nodes_Valid (Pool : Arena_Pool)
     with Ghost,
          Post => (for all I in 1 .. Pool.Next_Node_Index - 1 =>
                     Valid_Node_Index(Pool, I));

   --  Memory usage is monotonic
   procedure Lemma_Memory_Monotonic (Pool_Before, Pool_After : Arena_Pool)
     with Ghost,
          Pre => Pool_After.Allocated_Nodes >= Pool_Before.Allocated_Nodes and then
                 Pool_After.Allocated_Bytes >= Pool_Before.Allocated_Bytes,
          Post => Memory_Used(Pool_After) >= Memory_Used(Pool_Before);

   --  Reset deallocates everything (property, not executable lemma)
   procedure Lemma_Reset_Deallocates_All (Pool_Before : Arena_Pool;
                                          Pool_After : Arena_Pool)
     with Ghost,
          Pre => Pool_After.Next_Node_Index = 1 and then
                 Pool_After.Allocated_Nodes = 0,
          Post => Memory_Used (Pool_After) = 0;

end SML.Memory_Model;