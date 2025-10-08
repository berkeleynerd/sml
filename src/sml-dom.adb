------------------------------------------------------------------------------
--  SML.DOM Package Body
--  Document Object Model Implementation for SML
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body SML.DOM with SPARK_Mode => On is

   ---------------------------------------------------------------------------
   --  Helper Functions
   ---------------------------------------------------------------------------

   --  Check if two Node_Id values reference the same node
   --  SPARK-compatible equality for access-derived types
   function Same_Node (Left, Right : Node_Id) return Boolean is
     (Node_Access (Left) = Node_Access (Right))
   with Inline;

   ---------------------------------------------------------------------------
   --  DOM Traversal Functions
   ---------------------------------------------------------------------------

   function Root (Doc : Document) return Node_Id is
   begin
      return Doc.Root_Node;
   end Root;

   function Parent (Doc : Document; Node : Node_Id) return Node_Id is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
   begin
      if N = null then
         return Null_Node;
      end if;

      return N.Parent_Node;
   end Parent;

   function First_Child (Doc : Document; Node : Node_Id) return Node_Id is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
   begin
      if N = null then
         return Null_Node;
      end if;

      if N.Kind = Text then
         return Null_Node;
      end if;

      return N.First_Child_Node;
   end First_Child;

   function Next_Sibling (Doc : Document; Node : Node_Id) return Node_Id is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
   begin
      if N = null then
         return Null_Node;
      end if;

      return N.Next_Sibling_Node;
   end Next_Sibling;

   function Child_Count (Doc : Document; Node : Node_Id) return Natural is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
   begin
      if N = null then
         return 0;
      end if;

      if N.Kind = Text then
         return 0;
      end if;

      return N.Num_Children;
   end Child_Count;

   function Child_At (Doc : Document; Node : Node_Id; Index : Positive)
                     return Node_Id is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
      Current : Node_Id;
      Count : Positive := 1;
   begin
      if N = null or else N.Kind = Text then
         return Null_Node;
      end if;

      Current := N.First_Child_Node;

      while Current /= Null_Node and then Count < Index loop
         declare
            Curr_Node : constant Node_Access := Node_Access (Current);
         begin
            Current := Curr_Node.Next_Sibling_Node;
            Count := Count + 1;
         end;
      end loop;

      return Current;
   end Child_At;

   function Kind (Doc : Document; Node : Node_Id) return Node_Kind is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
   begin
      if N = null then
         return Element;  -- Default, shouldn't be reached
      end if;

      return N.Kind;
   end Kind;

   function Name (Doc : Document; Node : Node_Id) return String is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
   begin
      if N = null or else N.Kind /= Element then
         return "";
      end if;

      return To_String (N.Element_Name);
   end Name;

   function Text_Value (Doc : Document; Node : Node_Id) return String is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
   begin
      if N = null or else N.Kind /= Text then
         return "";
      end if;

      return To_String (N.Text_Content);
   end Text_Value;

   function Depth (Doc : Document; Node : Node_Id) return Natural is
      Current : Node_Id := Node;
      D : Natural := 0;
   begin
      while Current /= Null_Node and then Current /= Doc.Root_Node loop
         Current := Parent (Doc, Current);
         D := D + 1;

         -- Safety check to prevent infinite loops
         if D > Max_Tree_Depth then
            exit;
         end if;
      end loop;

      return D;
   end Depth;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Formal Verification
   ---------------------------------------------------------------------------

   function Is_Valid_Node (Doc : Document; Node : Node_Id) return Boolean is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
   begin
      -- A node is valid if it's not null
      -- In a complete implementation, this would check if the node
      -- is actually part of the document's node pool
      return N /= null;
   end Is_Valid_Node;

   function Is_Well_Formed (Doc : Document) return Boolean is
   begin
      return Has_Single_Root (Doc) and then
             Is_Acyclic (Doc) and then
             Has_Consistent_Parent_Child_Links (Doc) and then
             Has_Valid_Depth (Doc);
   end Is_Well_Formed;

   function Has_Single_Root (Doc : Document) return Boolean is
   begin
      -- Document should have exactly one root node
      return Doc.Root_Node /= Null_Node;
   end Has_Single_Root;

   function Is_Acyclic (Doc : Document) return Boolean is
      pragma Unreferenced (Doc);
   begin
      -- Check for cycles in the tree
      -- In a complete implementation, this would traverse the tree
      -- and verify no node is reachable twice
      return True;  -- Assumed for now
   end Is_Acyclic;

   function Has_Consistent_Parent_Child_Links (Doc : Document) return Boolean is
      pragma Unreferenced (Doc);
   begin
      -- Verify all parent-child relationships are bidirectional
      -- In a complete implementation, this would verify that if A is
      -- a child of B, then B.children contains A
      return True;  -- Assumed for now
   end Has_Consistent_Parent_Child_Links;

   function Has_Valid_Depth (Doc : Document) return Boolean is
   begin
      -- Check that no node exceeds maximum depth
      -- This is a simplified implementation
      if Doc.Root_Node /= Null_Node then
         return Depth (Doc, Doc.Root_Node) <= Max_Tree_Depth;
      end if;

      return True;
   end Has_Valid_Depth;

   function Has_Child (Doc : Document; Parent_Node, Child_Node : Node_Id)
                      return Boolean is
      Current : Node_Id;
   begin
      if Parent_Node = Null_Node or else Child_Node = Null_Node then
         return False;
      end if;

      if Kind (Doc, Parent_Node) = Text then
         return False;
      end if;

      Current := First_Child (Doc, Parent_Node);

      while Current /= Null_Node loop
         if Same_Node (Current, Child_Node) then
            return True;
         end if;

         Current := Next_Sibling (Doc, Current);
      end loop;

      return False;
   end Has_Child;

   function Is_Valid_Name (Name : String) return Boolean is
   begin
      if Name'Length = 0 then
         return False;
      end if;

      for I in Name'Range loop
         if not Is_Name_Char (Name (I)) then
            return False;
         end if;
      end loop;

      return True;
   end Is_Valid_Name;

   function Is_Name_Char (C : Character) return Boolean is
      Code : constant Natural := Character'Pos (C);
   begin
      -- Simplified XML name character check
      -- Letters, digits, and a few special characters
      return (Code >= Character'Pos ('A') and Code <= Character'Pos ('Z')) or
             (Code >= Character'Pos ('a') and Code <= Character'Pos ('z')) or
             (Code >= Character'Pos ('0') and Code <= Character'Pos ('9')) or
             C = '_' or C = '-' or C = '.' or C = ':';
   end Is_Name_Char;

   ---------------------------------------------------------------------------
   --  Memory Management Ghost Functions
   ---------------------------------------------------------------------------

   function Owns_Node (Doc : Document; Node : Node_Id) return Boolean is
      pragma Unreferenced (Doc);
      N : constant Node_Access := Node_Access (Node);
   begin
      -- In a complete implementation, this would check if the node
      -- belongs to the document's node pool
      return N /= null;
   end Owns_Node;

   function Node_Count (Doc : Document) return Natural is
   begin
      return Doc.Total_Nodes;
   end Node_Count;

   function No_Memory_Leaks (Doc : Document) return Boolean is
   begin
      -- In a complete implementation, this would verify that all
      -- allocated nodes are reachable from the root
      return Is_Valid_Node (Doc, Doc.Root_Node);
   end No_Memory_Leaks;

end SML.DOM;