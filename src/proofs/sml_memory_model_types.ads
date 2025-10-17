------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                Memory Model Types - Shared Type Definitions              --
------------------------------------------------------------------------------

package SML_Memory_Model_Types
  with SPARK_Mode => On
is

   ---------------------------------------------------------------------------
   --  Memory Bounds and Constants
   ---------------------------------------------------------------------------

   --  Maximum nodes based on stack-safe document limits
   Max_Document_Nodes : constant Natural := 2_000;

   --  Maximum string storage (200KB for text content)
   Max_String_Storage : constant Natural := 200_000;

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
   with
     Predicate =>
       Length <= Max_String_Storage
       and then (if Length > 0
                 then Start > 0 and then Start <= Max_String_Storage);

   --  Null string reference
   Null_String_Ref : constant String_Ref := (Start => 0, Length => 0);

   ---------------------------------------------------------------------------
   --  Node Type Definition
   ---------------------------------------------------------------------------

   --  Maximum children per element
   --  (local constant to avoid circular dependency)
   Max_Children_Local : constant Natural := 10000;

   --  Node structure with bounded storage (discriminated record with default)
   type Node (Kind : Node_Kind := Element) is record
      Parent_Index       : Node_Index;
      First_Child_Index  : Node_Index;
      Next_Sibling_Index : Node_Index;
      Is_Deleted         : Boolean := False;  -- Logical deletion flag

      --  Content based on kind discriminant
      case Kind is
         when Element =>
            Element_Name_Ref : String_Ref;
            Num_Children     : Natural;

         when Text =>
            Text_Content_Ref : String_Ref;
      end case;
   end record
   with
     Predicate =>
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
      Next_Node_Index : Node_Index := 1;

      --  String storage
      Strings         : String_Storage (1 .. Max_String_Storage);
      Next_String_Pos : String_Index := 1;

      --  Ghost fields for memory accounting
      Allocated_Nodes : Natural := 0;
      Allocated_Bytes : Natural := 0;
      High_Water_Mark : Natural := 0;  -- Maximum allocation reached
   end record
   with
     Relaxed_Initialization,
     Predicate =>
       Next_Node_Index <= Max_Document_Nodes + 1
       and then Next_String_Pos <= Max_String_Storage + 1
       and then Allocated_Nodes <= Next_Node_Index
       and then Allocated_Bytes <= Max_String_Storage;

end SML_Memory_Model_Types;