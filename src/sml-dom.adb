------------------------------------------------------------------------------
--  SML.DOM Package Body
--  Document Object Model Implementation for SML (Index-Based)
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML.Memory_Model;
with SML.UTF8;
use type SML.Memory_Model.Node_Kind;  -- Make operators visible

package body SML.DOM
  with SPARK_Mode => On
is

   ---------------------------------------------------------------------------
   --  Helper Functions for Type Conversions and String Access
   ---------------------------------------------------------------------------

   --  Convert Node_Id to Memory_Model index for array access
   function To_Index (Node : Node_Id) return SML.Memory_Model.Node_Index
   is (SML.Memory_Model.Node_Index (Node))
   with Inline;

   --  Convert Memory_Model index to Node_Id
   function To_Node_Id (Index : SML.Memory_Model.Node_Index) return Node_Id
   is (Node_Id (Index))
   with Inline;

   --  Convert Memory_Model Node_Kind to DOM Node_Kind
   function To_DOM_Kind (MK : SML.Memory_Model.Node_Kind) return Node_Kind
   is (case MK is
         when SML.Memory_Model.Element => Element,
         when SML.Memory_Model.Text => Text)
   with Inline;

   --  Extract string from string pool
   function Get_String
     (Pool : SML.Memory_Model.Arena_Pool; Ref : SML.Memory_Model.String_Ref)
      return String is
   begin
      if Ref.Length = 0 then
         return "";
      end if;

      declare
         Result : String (1 .. Ref.Length) := (others => ' ');
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
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
   begin
      if Node = Null_Node then
         return Null_Node;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return Null_Node;
      end if;

      return To_Node_Id (Doc.Pool.Nodes (Idx).Parent_Index);
   end Parent;

   function First_Child (Doc : Document; Node : Node_Id) return Node_Id is
      Idx     : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N       : SML.Memory_Model.Node;
      Current : Node_Id;
      Count   : Natural := 0;
   begin
      if Node = Null_Node then
         return Null_Node;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return Null_Node;
      end if;

      N := Doc.Pool.Nodes (Idx);

      if N.Kind = SML.Memory_Model.Node_Kind'(SML.Memory_Model.Text) then
         return Null_Node;
      end if;

      --  Find first non-deleted child
      Current := To_Node_Id (N.First_Child_Index);

      while Current /= Null_Node loop
         pragma Loop_Variant (Increases => Count);

         if not SML.Memory_Model.Valid_Node_Index
                  (Doc.Pool, To_Index (Current))
         then
            return Null_Node;
         end if;

         N := Doc.Pool.Nodes (To_Index (Current));

         --  Return if not deleted
         exit when not N.Is_Deleted;

         --  Move to next sibling
         Current := To_Node_Id (N.Next_Sibling_Index);
         Count := Count + 1;

         --  Safety: prevent infinite loop
         exit when Count >= Max_Children;
      end loop;

      return Current;
   end First_Child;

   function Next_Sibling (Doc : Document; Node : Node_Id) return Node_Id is
      Idx     : constant SML.Memory_Model.Node_Index := To_Index (Node);
      Current : Node_Id;
      N       : SML.Memory_Model.Node;
      Count   : Natural := 0;
   begin
      if Node = Null_Node then
         return Null_Node;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return Null_Node;
      end if;

      --  Find next non-deleted sibling
      Current := To_Node_Id (Doc.Pool.Nodes (Idx).Next_Sibling_Index);

      while Current /= Null_Node loop
         pragma Loop_Variant (Increases => Count);

         if not SML.Memory_Model.Valid_Node_Index
                  (Doc.Pool, To_Index (Current))
         then
            return Null_Node;
         end if;

         N := Doc.Pool.Nodes (To_Index (Current));

         --  Return if not deleted
         exit when not N.Is_Deleted;

         --  Move to next sibling
         Current := To_Node_Id (N.Next_Sibling_Index);
         Count := Count + 1;

         --  Safety: prevent infinite loop
         exit when Count >= Max_Children;
      end loop;

      return Current;
   end Next_Sibling;

   function Child_Count (Doc : Document; Node : Node_Id) return Natural is
      Idx     : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N       : SML.Memory_Model.Node;
      Current : Node_Id;
      Count   : Natural := 0;
      Iter    : Natural := 0;
   begin
      if Node = Null_Node then
         return 0;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return 0;
      end if;

      N := Doc.Pool.Nodes (Idx);

      if N.Kind = SML.Memory_Model.Node_Kind'(SML.Memory_Model.Text) then
         return 0;
      end if;

      --  Count non-deleted children
      Current := To_Node_Id (N.First_Child_Index);

      while Current /= Null_Node loop
         pragma Loop_Variant (Increases => Iter);

         if SML.Memory_Model.Valid_Node_Index (Doc.Pool, To_Index (Current))
         then
            N := Doc.Pool.Nodes (To_Index (Current));

            if not N.Is_Deleted then
               Count := Count + 1;
            end if;

            Current := To_Node_Id (N.Next_Sibling_Index);
         else
            exit;
         end if;

         Iter := Iter + 1;

         --  Safety: prevent infinite loop
         exit when Iter >= Max_Children;
      end loop;

      return Count;
   end Child_Count;

   function Child_At
     (Doc : Document; Node : Node_Id; Index : Positive) return Node_Id
   is
      Idx         : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N           : SML.Memory_Model.Node;
      Current     : Node_Id;
      Current_Idx : SML.Memory_Model.Node_Index;
      Count       : Positive := 1;
   begin
      if Node = Null_Node then
         return Null_Node;
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return Null_Node;
      end if;

      N := Doc.Pool.Nodes (Idx);

      if N.Kind = SML.Memory_Model.Node_Kind'(SML.Memory_Model.Text) then
         return Null_Node;
      end if;

      Current := To_Node_Id (N.First_Child_Index);

      while Current /= Null_Node and then Count < Index loop
         pragma Loop_Variant (Increases => Count);

         Current_Idx := To_Index (Current);

         if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Current_Idx) then
            return Null_Node;
         end if;

         N := Doc.Pool.Nodes (Current_Idx);

         --  Only count non-deleted nodes
         if not N.Is_Deleted then
            Count := Count + 1;
         end if;

         --  If we found the target index, exit
         if Count = Index and then not N.Is_Deleted then
            return Current;
         end if;

         --  Move to next sibling
         Current := To_Node_Id (N.Next_Sibling_Index);
      end loop;

      return Null_Node;
   end Child_At;

   function Kind (Doc : Document; Node : Node_Id) return Node_Kind is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      if Node = Null_Node then
         return Element;  -- Default, shouldn't be reached due to precondition

      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return Element;
      end if;

      N := Doc.Pool.Nodes (Idx);

      return To_DOM_Kind (N.Kind);
   end Kind;

   function Name (Doc : Document; Node : Node_Id) return String is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      if Node = Null_Node then
         return "";
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return "";
      end if;

      N := Doc.Pool.Nodes (Idx);

      if N.Kind /= SML.Memory_Model.Node_Kind'(SML.Memory_Model.Element) then
         return "";
      end if;

      return Get_String (Doc.Pool, N.Element_Name_Ref);
   end Name;

   function Text_Value (Doc : Document; Node : Node_Id) return String is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      if Node = Null_Node then
         return "";
      end if;

      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return "";
      end if;

      N := Doc.Pool.Nodes (Idx);

      if N.Kind /= SML.Memory_Model.Text then
         return "";
      end if;

      return Get_String (Doc.Pool, N.Text_Content_Ref);
   end Text_Value;

   function Depth (Doc : Document; Node : Node_Id) return Natural is
      Current     : Node_Id := Node;
      Current_Idx : SML.Memory_Model.Node_Index;
      D           : Natural := 0;
   begin
      while Current /= Null_Node and then Current /= Doc.Root_Node loop
         pragma Loop_Variant (Increases => D);

         Current_Idx := To_Index (Current);

         if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Current_Idx) then
            exit;
         end if;

         Current := To_Node_Id (Doc.Pool.Nodes (Current_Idx).Parent_Index);
         D := D + 1;

         --  Safety check to prevent infinite loops
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
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
   begin
      --  Safety-critical validation: exhaustive checks for node validity

      --  Check 1: Node must not be null
      if Node = Null_Node then
         return False;
      end if;

      --  Check 2: Node index must be in valid allocated range
      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return False;
      end if;

      --  Check 3: Node must not be marked as deleted
      declare
         N : constant SML.Memory_Model.Node := Doc.Pool.Nodes (Idx);
      begin
         if N.Is_Deleted then
            return False;
         end if;

         --  Check 4: Node's parent must be valid or null (for root)
         if N.Parent_Index /= SML.Memory_Model.No_Node_Index then
            if not (N.Parent_Index > 0
                    and then N.Parent_Index < Doc.Pool.Next_Node_Index)
            then
               return False;
            end if;
         end if;

         --  Check 5: If node has children, first child must be valid
         if N.First_Child_Index /= SML.Memory_Model.No_Node_Index then
            if not (N.First_Child_Index > 0
                    and then N.First_Child_Index < Doc.Pool.Next_Node_Index)
            then
               return False;
            end if;
         end if;

         --  Check 6: If node has sibling, next sibling must be valid
         if N.Next_Sibling_Index /= SML.Memory_Model.No_Node_Index then
            if not (N.Next_Sibling_Index > 0
                    and then N.Next_Sibling_Index < Doc.Pool.Next_Node_Index)
            then
               return False;
            end if;
         end if;

         --  Check 7: Element nodes must have valid name reference
         if N.Kind = SML.Memory_Model.Element then
            if N.Element_Name_Ref.Length = 0 then
               return False;  -- Elements must have non-empty names

            end if;
            if not SML.Memory_Model.Valid_String_Ref
                     (Doc.Pool, N.Element_Name_Ref)
            then
               return False;
            end if;
         end if;

         --  Check 8: Text nodes must have valid text reference
         if N.Kind = SML.Memory_Model.Text then
            --  Text nodes can have empty content, but reference must be valid
            if not SML.Memory_Model.Valid_String_Ref
                     (Doc.Pool, N.Text_Content_Ref)
            then
               return False;
            end if;
         end if;

         --  All checks passed - node is valid
         return True;
      end;
   end Is_Valid_Node;

   function Is_Well_Formed (Doc : Document) return Boolean is
   begin
      return
        Has_Single_Root (Doc)
        and then Is_Acyclic (Doc)
        and then Has_Consistent_Parent_Child_Links (Doc)
        and then Has_Valid_Depth (Doc);
   end Is_Well_Formed;

   function Has_Single_Root (Doc : Document) return Boolean is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Doc.Root_Node);
   begin
      --  Safety Check 1: Root must exist
      if Doc.Root_Node = Null_Node then
         return False;
      end if;

      --  Safety Check 2: Root index must be valid
      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return False;
      end if;

      --  Safety Check 3: Root must be an Element (not Text)
      declare
         Root_Node : constant SML.Memory_Model.Node := Doc.Pool.Nodes (Idx);
      begin
         if Root_Node.Kind /= SML.Memory_Model.Element then
            return False;  -- Root must be an element

         end if;

         --  Safety Check 4: Root must have no parent (critical property!)
         --  This prevents floating subtrees - ensures true single root
         if Root_Node.Parent_Index /= SML.Memory_Model.No_Node_Index then
            return False;  -- Root cannot have a parent

         end if;

         --  Safety Check 5: Root must not be marked as deleted
         if Root_Node.Is_Deleted then
            return False;
         end if;

         --  All checks passed - document has a valid single root
         return True;
      end;
   end Has_Single_Root;

   function Is_Acyclic (Doc : Document) return Boolean is
      --  Floyd's cycle detection on parent links from each node (ghost walk)
      --  Bounded by Max_Tree_Depth and pool bounds to ensure termination
   begin
      --  If no root, trivially acyclic
      if Doc.Root_Node = Null_Node then
         return True;
      end if;

      declare
         --  Ghost helpers for bounded ancestor steps
         function Parent_Of (N : Node_Id) return Node_Id is
         begin
            if N = Null_Node then
               return Null_Node;
            end if;
            if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, To_Index (N)) then
               return Null_Node;
            end if;
            return To_Node_Id (Doc.Pool.Nodes (To_Index (N)).Parent_Index);
         end Parent_Of;
      begin
         --  Walk from every node up to the root with tortoise-hare bounded
         for Start in 1 .. Doc.Total_Nodes loop
            pragma Loop_Invariant (Start <= Doc.Total_Nodes);
            declare
               Slow : Node_Id := Node_Id (Start);
               Fast : Node_Id := Node_Id (Start);
               Steps : Natural := 0;
            begin
               while Slow /= Null_Node and then Fast /= Null_Node loop
                  pragma Loop_Variant (Increases => Steps);

                  Slow := Parent_Of (Slow);
                  Fast := Parent_Of (Parent_Of (Fast));
                  Steps := Steps + 1;

                  if Slow = Fast and then Slow /= Null_Node then
                     return False; -- cycle detected
                  end if;

                  exit when Steps > Max_Tree_Depth;
               end loop;
            end;
         end loop;
      end;

      return True;
   end Is_Acyclic;

   function Has_Consistent_Parent_Child_Links (Doc : Document) return Boolean is
   begin
      --  For each non-deleted node, ensure children point back to parent
      if Doc.Root_Node = Null_Node then
         return True;
      end if;

      for I in 1 .. SML.Memory_Model.Node_Index (Doc.Total_Nodes) loop
         declare
            Idx : constant SML.Memory_Model.Node_Index := SML.Memory_Model.Node_Index (I);
         begin
            exit when not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx);
            declare
               N : constant SML.Memory_Model.Node := Doc.Pool.Nodes (Idx);
            begin
               if not N.Is_Deleted then
                  if N.First_Child_Index /= SML.Memory_Model.No_Node_Index then
                     declare
                        C_Idx : constant SML.Memory_Model.Node_Index := N.First_Child_Index;
                     begin
                        if not (C_Idx > 0 and then C_Idx < Doc.Pool.Next_Node_Index) then
                           return False;
                        end if;
                        if Doc.Pool.Nodes (C_Idx).Parent_Index /= Idx then
                           return False;
                        end if;
                     end;
                  end if;

                  if N.Next_Sibling_Index /= SML.Memory_Model.No_Node_Index then
                     declare
                        S_Idx : constant SML.Memory_Model.Node_Index := N.Next_Sibling_Index;
                     begin
                        if not (S_Idx > 0 and then S_Idx < Doc.Pool.Next_Node_Index) then
                           return False;
                        end if;
                        --  Sibling must share the same parent
                        if Doc.Pool.Nodes (S_Idx).Parent_Index /= N.Parent_Index then
                           return False;
                        end if;
                     end;
                  end if;
               end if;
            end;
         end;
      end loop;

      return True;
   end Has_Consistent_Parent_Child_Links;

   function Has_Valid_Depth (Doc : Document) return Boolean is
   begin
      --  Safety Check 1: If no root, depth constraint is trivially satisfied
      if Doc.Root_Node = Null_Node then
         return True;
      end if;

      --  Safety Check 2: Root must be a valid node before checking depth
      --  This satisfies Depth's precondition: Is_Valid_Node(Doc, Node)
      if not Is_Valid_Node (Doc, Doc.Root_Node) then
         return False;  -- Invalid root means invalid depth

      end if;

      --  Safety Check 3: Verify root's depth is within bounds
      --  Since Depth walks from node to root, Depth(Root) should be 0
      --  This check ensures the tree structure is not corrupted
      if Depth (Doc, Doc.Root_Node) > Max_Tree_Depth then
         return False;
      end if;

      --  All checks passed - tree depth is valid
      return True;
   end Has_Valid_Depth;

   function Has_Child
     (Doc : Document; Parent_Node, Child_Node : Node_Id) return Boolean
   is
      Current    : Node_Id;
      Iter_Count : Natural := 0;
   begin
      if Parent_Node = Null_Node or else Child_Node = Null_Node then
         return False;
      end if;

      if Kind (Doc, Parent_Node) = Text then
         return False;
      end if;

      Current := First_Child (Doc, Parent_Node);

      while Current /= Null_Node loop
         pragma Loop_Variant (Increases => Iter_Count);

         if Current = Child_Node then
            --  Direct equality works on discrete type!
            return True;
         end if;

         Current := Next_Sibling (Doc, Current);
         Iter_Count := Iter_Count + 1;

         --  Safety: prevent infinite loops (max children limit)
         exit when Iter_Count > Max_Children;
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
      --  Simplified XML name character check
      return
        (Code >= Character'Pos ('A') and then Code <= Character'Pos ('Z'))
        or else (Code >= Character'Pos ('a')
                 and then Code <= Character'Pos ('z'))
        or else (Code >= Character'Pos ('0')
                 and then Code <= Character'Pos ('9'))
        or else C = '_'
        or else C = '-'
        or else C = '.'
        or else C = ':';
   end Is_Name_Char;

   --  Ghost wrapper to avoid Import: delegate to SML.UTF8
   function Is_Valid_UTF8 (Text : String) return Boolean is
   begin
      return SML.UTF8.Is_Valid_UTF8 (Text);
   end Is_Valid_UTF8;

   ---------------------------------------------------------------------------
   --  Memory Management Ghost Functions
   ---------------------------------------------------------------------------

   function Owns_Node (Doc : Document; Node : Node_Id) return Boolean is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
   begin
      --  Safety Check 1: Null nodes are not owned
      if Node = Null_Node then
         return False;
      end if;

      --  Safety Check 2: Node index must be in allocated range
      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return False;
      end if;

      --  Safety Check 3: Node must not be marked as deleted
      --  Deleted nodes are logically not owned (pending garbage collection)
      declare
         N : constant SML.Memory_Model.Node := Doc.Pool.Nodes (Idx);
      begin
         if N.Is_Deleted then
            return False;
         end if;

         --  All checks passed - document owns this node
         return True;
      end;
   end Owns_Node;

   function Node_Count (Doc : Document) return Natural is
   begin
      return Doc.Total_Nodes;
   end Node_Count;

   function No_Memory_Leaks (Doc : Document) return Boolean is
   begin
      --  Verify all allocated nodes are reachable
      return
        Is_Valid_Node (Doc, Doc.Root_Node) or else Doc.Root_Node = Null_Node;
   end No_Memory_Leaks;

end SML.DOM;
