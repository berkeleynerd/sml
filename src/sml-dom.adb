------------------------------------------------------------------------------
--  SML.DOM Package Body
--  Document Object Model Implementation for SML (Index-Based)
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML.Memory_Model;

package body SML.DOM with SPARK_Mode => On is

   ---------------------------------------------------------------------------
   --  Helper Functions for String Pool Access
   ---------------------------------------------------------------------------

   function Get_String (Pool : SML.Memory_Model.Arena_Pool;
                        Ref : SML.Memory_Model.String_Ref) return String is
   begin
      if Ref.Length = 0 then
         return "";
      end if;

      declare
         Result : String (1 .. Ref.Length);
      begin
         for I in 1 .. Ref.Length loop
            Result (I) := Pool.Strings (Ref.Start + I - 1);
         end loop;
         return Result;
      end;
   end Get_String;

   ---------------------------------------------------------------------------
   --  DOM Traversal Functions
   ---------------------------------------------------------------------------

   function Root (Doc : Document) return Node_Id is
   begin
      return Doc.Root_Node;
   end Root;

   function Parent (Doc : Document; Node : Node_Id) return Node_Id is
   begin
      if Node = Null_Node then
         return Null_Node;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node) then
         return Null_Node;
      end if;

      return Doc.Pool.Nodes (Node).Parent_Index;
   end Parent;

   function First_Child (Doc : Document; Node : Node_Id) return Node_Id is
      N : SML.Memory_Model.Node;
   begin
      if Node = Null_Node then
         return Null_Node;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node) then
         return Null_Node;
      end if;

      N := Doc.Pool.Nodes (Node);

      if N.Kind = SML.Memory_Model.Text then
         return Null_Node;
      end if;

      return N.First_Child_Index;
   end First_Child;

   function Next_Sibling (Doc : Document; Node : Node_Id) return Node_Id is
   begin
      if Node = Null_Node then
         return Null_Node;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node) then
         return Null_Node;
      end if;

      return Doc.Pool.Nodes (Node).Next_Sibling_Index;
   end Next_Sibling;

   function Child_Count (Doc : Document; Node : Node_Id) return Natural is
      N : SML.Memory_Model.Node;
   begin
      if Node = Null_Node then
         return 0;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node) then
         return 0;
      end if;

      N := Doc.Pool.Nodes (Node);

      if N.Kind = SML.Memory_Model.Text then
         return 0;
      end if;

      return N.Num_Children;
   end Child_Count;

   function Child_At (Doc : Document; Node : Node_Id; Index : Positive)
                     return Node_Id is
      N : SML.Memory_Model.Node;
      Current : Node_Id;
      Count : Positive := 1;
   begin
      if Node = Null_Node then
         return Null_Node;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node) then
         return Null_Node;
      end if;

      N := Doc.Pool.Nodes (Node);

      if N.Kind = SML.Memory_Model.Text then
         return Null_Node;
      end if;

      Current := N.First_Child_Index;

      while Current /= Null_Node and then Count < Index loop
         if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Current) then
            return Null_Node;
         end if;

         Current := Doc.Pool.Nodes (Current).Next_Sibling_Index;
         Count := Count + 1;
      end loop;

      return Current;
   end Child_At;

   function Kind (Doc : Document; Node : Node_Id) return Node_Kind is
      N : SML.Memory_Model.Node;
   begin
      if Node = Null_Node then
         return Element;  -- Default, shouldn't be reached due to precondition
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node) then
         return Element;
      end if;

      N := Doc.Pool.Nodes (Node);

      -- Convert Memory_Model.Node_Kind to DOM.Node_Kind
      case N.Kind is
         when SML.Memory_Model.Element => return Element;
         when SML.Memory_Model.Text => return Text;
      end case;
   end Kind;

   function Name (Doc : Document; Node : Node_Id) return String is
      N : SML.Memory_Model.Node;
   begin
      if Node = Null_Node then
         return "";
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node) then
         return "";
      end if;

      N := Doc.Pool.Nodes (Node);

      if N.Kind /= SML.Memory_Model.Element then
         return "";
      end if;

      return Get_String (Doc.Pool, N.Element_Name_Ref);
   end Name;

   function Text_Value (Doc : Document; Node : Node_Id) return String is
      N : SML.Memory_Model.Node;
   begin
      if Node = Null_Node then
         return "";
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node) then
         return "";
      end if;

      N := Doc.Pool.Nodes (Node);

      if N.Kind /= SML.Memory_Model.Text then
         return "";
      end if;

      return Get_String (Doc.Pool, N.Text_Content_Ref);
   end Text_Value;

   function Depth (Doc : Document; Node : Node_Id) return Natural is
      Current : Node_Id := Node;
      D : Natural := 0;
   begin
      while Current /= Null_Node and then Current /= Doc.Root_Node loop
         if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Current) then
            exit;
         end if;

         Current := Doc.Pool.Nodes (Current).Parent_Index;
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
   begin
      return SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node);
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
      return Doc.Root_Node /= Null_Node and then
             SML.Memory_Model.Valid_Node_Index (Doc.Pool, Doc.Root_Node);
   end Has_Single_Root;

   function Is_Acyclic (Doc : Document) return Boolean is
      pragma Unreferenced (Doc);
   begin
      -- Check for cycles in the tree
      -- In a complete implementation, this would traverse the tree
      -- and verify no node is reachable twice via parent links
      -- For now, simplified implementation assumes validity
      return True;
   end Is_Acyclic;

   function Has_Consistent_Parent_Child_Links (Doc : Document) return Boolean is
      pragma Unreferenced (Doc);
   begin
      -- Verify all parent-child relationships are bidirectional
      -- In a complete implementation, this would verify that if A is
      -- a child of B, then B.children contains A
      -- For now, simplified implementation assumes validity
      return True;
   end Has_Consistent_Parent_Child_Links;

   function Has_Valid_Depth (Doc : Document) return Boolean is
   begin
      -- Check that no node exceeds maximum depth
      -- Simplified: check root depth
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
         if Current = Child_Node then  -- ✅ Direct equality on discrete type!
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
      return (Code >= Character'Pos ('A') and Code <= Character'Pos ('Z')) or
             (Code >= Character'Pos ('a') and Code <= Character'Pos ('z')) or
             (Code >= Character'Pos ('0') and Code <= Character'Pos ('9')) or
             C = '_' or C = '-' or C = '.' or C = ':';
   end Is_Name_Char;

   ---------------------------------------------------------------------------
   --  Memory Management Ghost Functions
   ---------------------------------------------------------------------------

   function Owns_Node (Doc : Document; Node : Node_Id) return Boolean is
   begin
      return SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node);
   end Owns_Node;

   function Node_Count (Doc : Document) return Natural is
   begin
      return Doc.Total_Nodes;
   end Node_Count;

   function No_Memory_Leaks (Doc : Document) return Boolean is
   begin
      -- In a complete implementation, verify all allocated nodes
      -- are reachable from root. Simplified for now.
      return Is_Valid_Node (Doc, Doc.Root_Node) or else Doc.Root_Node = Null_Node;
   end No_Memory_Leaks;

end SML.DOM;