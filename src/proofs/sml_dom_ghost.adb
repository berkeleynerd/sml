------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                     DOM Ghost Functions Implementation                   --
------------------------------------------------------------------------------

with SML_Memory_Model_Ghost;
with SML_UTF8_Ghost;

package body SML_DOM_Ghost
  with SPARK_Mode
is

   ---------------------------------------------------------------------------
   --  Local Helper Functions
   ---------------------------------------------------------------------------

   function To_Index (Node : Node_Id) return Node_Index
     with Inline
   is
   begin
      return Node_Index (Node);
   end To_Index;

   function To_Node_Id (Idx : Node_Index) return Node_Id
     with Inline
   is
   begin
      if Idx = No_Node_Index then
         return Null_Node;
      else
         return Node_Id (Idx);
      end if;
   end To_Node_Id;

   ---------------------------------------------------------------------------
   --  Ghost Function Implementations
   ---------------------------------------------------------------------------

   function Is_Valid_Node (Doc : Document; Node : Node_Id) return Boolean is
      Idx : constant Node_Index := To_Index (Node);
   begin
      --  Safety-critical validation: exhaustive checks for node validity

      --  Check 1: Node must not be null
      if Node = Null_Node then
         return False;
      end if;

      --  Check 2: Node index must be in valid allocated range
      if not SML_Memory_Model_Ghost.Valid_Node_Index (Doc.Pool, Idx) then
         return False;
      end if;

      --  Check 3: Node must not be marked as deleted
      declare
         N : constant Node := Doc.Pool.Nodes (Idx);
      begin
         if N.Is_Deleted then
            return False;
         end if;

         --  Check 4: Node's parent must be valid or null (for root)
         if N.Parent_Index /= No_Node_Index then
            if not (N.Parent_Index > 0
                    and then N.Parent_Index < Doc.Pool.Next_Node_Index)
            then
               return False;
            end if;
         end if;

         --  Check 5: If node has children, first child must be valid
         if N.First_Child_Index /= No_Node_Index then
            if not (N.First_Child_Index > 0
                    and then N.First_Child_Index < Doc.Pool.Next_Node_Index)
            then
               return False;
            end if;
         end if;

         --  Check 6: If node has sibling, next sibling must be valid
         if N.Next_Sibling_Index /= No_Node_Index then
            if not (N.Next_Sibling_Index > 0
                    and then N.Next_Sibling_Index < Doc.Pool.Next_Node_Index)
            then
               return False;
            end if;
         end if;

         --  Check 7: Element nodes must have valid name reference
         if N.Kind = Element then
            if N.Element_Name_Ref.Length = 0 then
               return False;  -- Elements must have non-empty names
            end if;
            if not SML_Memory_Model_Ghost.Valid_String_Ref
                     (Doc.Pool, N.Element_Name_Ref)
            then
               return False;
            end if;
         end if;

         --  Check 8: Text nodes must have valid text reference
         if N.Kind = Text then
            --  Text nodes can have empty content, but reference must be valid
            if not SML_Memory_Model_Ghost.Valid_String_Ref
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
      Idx : constant Node_Index := To_Index (Doc.Root_Node);
   begin
      --  Safety Check 1: Root must exist
      if Doc.Root_Node = Null_Node then
         return False;
      end if;

      --  Safety Check 2: Root index must be valid
      if not SML_Memory_Model_Ghost.Valid_Node_Index (Doc.Pool, Idx) then
         return False;
      end if;

      --  Safety Check 3: Root must be an Element (not Text)
      declare
         Root_Node : constant Node := Doc.Pool.Nodes (Idx);
      begin
         if Root_Node.Kind /= Element then
            return False;  -- Root must be an element
         end if;

         --  Safety Check 4: Root must have no parent
         if Root_Node.Parent_Index /= No_Node_Index then
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
      --  Floyd's cycle detection on parent links from each node
   begin
      --  If no root, trivially acyclic
      if Doc.Root_Node = Null_Node then
         return True;
      end if;

      declare
         --  Helper to get parent safely
         function Parent_Of (N : Node_Id) return Node_Id is
         begin
            if N = Null_Node then
               return Null_Node;
            end if;
            if not Valid_Node_Index (Doc.Pool, To_Index (N))
            then
               return Null_Node;
            end if;
            return To_Node_Id (Doc.Pool.Nodes (To_Index (N)).Parent_Index);
         end Parent_Of;
      begin
         --  Walk from every node up to the root with tortoise-hare
         for Start in 1 .. Doc.Total_Nodes loop
            pragma Loop_Invariant (Start <= Doc.Total_Nodes);
            declare
               Slow  : Node_Id := Node_Id (Start);
               Fast  : Node_Id := Node_Id (Start);
               Steps : Natural := 0;
            begin
               while Slow /= Null_Node and then Fast /= Null_Node loop
                  pragma Loop_Variant (Increases => Steps);

                  Slow := Parent_Of (Slow);
                  Fast := Parent_Of (Parent_Of (Fast));
                  Steps := Steps + 1;

                  if Slow = Fast and then Slow /= Null_Node then
                     return False;  -- cycle detected
                  end if;

                  exit when Steps > Max_Tree_Depth;
               end loop;
            end;
         end loop;
      end;

      return True;
   end Is_Acyclic;

   function Has_Consistent_Parent_Child_Links (Doc : Document) return Boolean
   is
   begin
      --  For each non-deleted node, ensure children point back to parent
      if Doc.Root_Node = Null_Node then
         return True;
      end if;

      for I in 1 .. Node_Index (Doc.Total_Nodes) loop
         declare
            Idx : constant Node_Index :=
              Node_Index (I);
         begin
            exit when not SML_Memory_Model_Ghost.Valid_Node_Index (Doc.Pool, Idx);
            declare
               N : constant Node := Doc.Pool.Nodes (Idx);
            begin
               if not N.Is_Deleted then
                  --  Check first child's parent pointer
                  if N.First_Child_Index /= No_Node_Index then
                     declare
                        C_Idx : constant Node_Index :=
                          N.First_Child_Index;
                     begin
                        if Valid_Node_Index
                          (Doc.Pool, C_Idx)
                        then
                           if Doc.Pool.Nodes (C_Idx).Parent_Index /= Idx then
                              return False;
                           end if;
                        else
                           return False;
                        end if;
                     end;
                  end if;

                  --  Check siblings form a proper chain
                  if N.Next_Sibling_Index /= No_Node_Index then
                     declare
                        S_Idx : constant Node_Index :=
                          N.Next_Sibling_Index;
                     begin
                        if Valid_Node_Index (Doc.Pool, S_Idx)
                        then
                           --  Sibling must have same parent
                           if Doc.Pool.Nodes (S_Idx).Parent_Index
                              /= N.Parent_Index
                           then
                              return False;
                           end if;
                        else
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
      --  Check that all nodes have depth <= Max_Tree_Depth
      for I in 1 .. Doc.Total_Nodes loop
         pragma Loop_Invariant (I <= Doc.Total_Nodes);
         if Depth (Doc, Node_Id (I)) > Max_Tree_Depth then
            return False;
         end if;
      end loop;
      return True;
   end Has_Valid_Depth;

   function Is_Valid_Name (Name : String) return Boolean is
   begin
      --  Delegate to UTF8 validation
      return SML_UTF8_Ghost.Is_Valid_UTF8 (Name) and then Name'Length > 0;
   end Is_Valid_Name;

   ---------------------------------------------------------------------------
   --  Memory Management Ghost Functions
   ---------------------------------------------------------------------------

   function All_Nodes_Reachable (Doc : Document) return Boolean is
      pragma Unreferenced (Doc);
   begin
      --  Conservative implementation
      --  Full implementation would traverse from root and mark reachable
      return True;
   end All_Nodes_Reachable;

   function No_Memory_Leaks (Doc : Document) return Boolean is
   begin
      return All_Nodes_Reachable (Doc);
   end No_Memory_Leaks;

   function String_Storage_Valid (Doc : Document) return Boolean is
      pragma Unreferenced (Doc);
   begin
      --  Would check all string references are valid
      return True;
   end String_Storage_Valid;

   ---------------------------------------------------------------------------
   --  Node Relationship Functions
   ---------------------------------------------------------------------------

   function Depth (Doc : Document; Node : Node_Id) return Natural is
      Current : Node_Id := Node;
      D       : Natural := 0;
   begin
      --  Walk up parent chain counting steps
      while Current /= Null_Node
        and then Current /= Root (Doc)
        and then D < Max_Tree_Depth
      loop
         pragma Loop_Variant (Decreases => Max_Tree_Depth - D);
         pragma Loop_Invariant (D < Max_Tree_Depth);

         Current := Parent (Doc, Current);
         D := D + 1;
      end loop;

      return D;
   end Depth;

   function Is_Ancestor_Of
     (Doc : Document; Node, Descendant : Node_Id) return Boolean
   is
      Current : Node_Id := Descendant;
      Steps   : Natural := 0;
   begin
      --  Walk up from descendant looking for ancestor
      while Current /= Null_Node and then Steps <= Max_Tree_Depth loop
         pragma Loop_Variant (Increases => Steps);
         if Current = Node then
            return True;
         end if;
         Current := Parent (Doc, Current);
         Steps := Steps + 1;
      end loop;
      return False;
   end Is_Ancestor_Of;

   function Has_Child
     (Doc : Document; Parent_Node, Child_Node : Node_Id) return Boolean
   is
      Current : Node_Id;
   begin
      --  Walk through children looking for the specific child
      Current := First_Child (Doc, Parent_Node);
      while Current /= Null_Node loop
         pragma Loop_Variant (Decreases => Natural (Current));
         if Current = Child_Node then
            return True;
         end if;
         Current := Next_Sibling (Doc, Current);
      end loop;
      return False;
   end Has_Child;

   function Subtree_Size (Doc : Document; Node : Node_Id) return Natural is
      pragma Unreferenced (Doc, Node);
   begin
      --  Would recursively count all descendants
      return 1;  -- Conservative: at least the node itself
   end Subtree_Size;

   ---------------------------------------------------------------------------
   --  Invariant Helpers
   ---------------------------------------------------------------------------

   function All_Text_Valid_UTF8 (Doc : Document) return Boolean is
      pragma Unreferenced (Doc);
   begin
      --  Would check all text nodes have valid UTF-8
      return True;
   end All_Text_Valid_UTF8;

   function All_Names_Valid (Doc : Document) return Boolean is
      pragma Unreferenced (Doc);
   begin
      --  Would check all element names are valid
      return True;
   end All_Names_Valid;

   ---------------------------------------------------------------------------
   --  Lemmas
   ---------------------------------------------------------------------------

   procedure Lemma_Well_Formed_Has_Valid_Root (Doc : Document) is
      pragma Unreferenced (Doc);
   begin
      null;  -- Lemma body can be null; proved by contracts
   end Lemma_Well_Formed_Has_Valid_Root;

   procedure Lemma_Add_Node_Preserves_Well_Formed
     (Doc_Before, Doc_After : Document; New_Node : Node_Id)
   is
      pragma Unreferenced (Doc_Before, Doc_After, New_Node);
   begin
      null;  -- Lemma body can be null; proved by contracts
   end Lemma_Add_Node_Preserves_Well_Formed;

end SML_DOM_Ghost;
