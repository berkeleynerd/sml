------------------------------------------------------------------------------
--  SML.DOM Package Body
--  Document Object Model for Simple Markup Language (SML)
--  Core Implementation File
------------------------------------------------------------------------------

package body SML.DOM
  with SPARK_Mode => On
is
   use type SML.Memory_Model.Node_Kind;

   ---------------------------------------------------------------------------
   --  Internal Helper Functions
   ---------------------------------------------------------------------------

   --  Convert Node_Id to internal Node_Index
   --  INLINE optimization: frequently called in traversal operations
   function To_Index (Node : Node_Id) return SML.Memory_Model.Node_Index
     with Inline
   is
   begin
      return SML.Memory_Model.Node_Index (Node);
   end To_Index;

   --  Convert internal Node_Index to public Node_Id
   --  INLINE optimization: used in all navigation functions
   function To_Node_Id (Idx : SML.Memory_Model.Node_Index) return Node_Id
     with Inline
   is
   begin
      if Idx = SML.Memory_Model.No_Node_Index then
         return Null_Node;
      else
         return Node_Id (Idx);
      end if;
   end To_Node_Id;

   ---------------------------------------------------------------------------
   --  Document API Implementation
   ---------------------------------------------------------------------------

   function Root (Doc : Document) return Node_Id is
   begin
      return Doc.Root_Node;
   end Root;

   function Total_Nodes (Doc : Document) return Natural is
   begin
      return Doc.Total_Nodes;
   end Total_Nodes;

   ---------------------------------------------------------------------------
   --  Node Navigation Implementation
   ---------------------------------------------------------------------------

   function Parent (Doc : Document; Node : Node_Id) return Node_Id is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      --  Precondition ensures node is valid
      N := SML.Memory_Model.Get_Node (Doc.Pool, Idx);
      return To_Node_Id (N.Parent_Index);
   end Parent;

   function First_Child (Doc : Document; Node : Node_Id) return Node_Id is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      --  Precondition ensures node is valid
      N := SML.Memory_Model.Get_Node (Doc.Pool, Idx);
      return To_Node_Id (N.First_Child_Index);
   end First_Child;

   function Next_Sibling (Doc : Document; Node : Node_Id) return Node_Id is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      --  Precondition ensures node is valid
      N := SML.Memory_Model.Get_Node (Doc.Pool, Idx);
      return To_Node_Id (N.Next_Sibling_Index);
   end Next_Sibling;

   function Child_Count (Doc : Document; Node : Node_Id) return Natural is
      Idx     : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N       : SML.Memory_Model.Node;
      Current : SML.Memory_Model.Node_Index;
      Count   : Natural := 0;
   begin
      --  Precondition ensures node is valid
      N := SML.Memory_Model.Get_Node (Doc.Pool, Idx);

      --  Text nodes have no children by definition
      if N.Kind = SML.Memory_Model.Text then
         return 0;
      end if;

      --  Count children by traversing sibling chain
      Current := N.First_Child_Index;
      while Current /= SML.Memory_Model.No_Node_Index loop
         pragma Loop_Variant (Increases => Count);
         pragma Loop_Invariant (Count < Max_Children);

         Count := Count + 1;
         exit when Count >= Max_Children;  -- Safety bound

         declare
            Child : constant SML.Memory_Model.Node :=
              SML.Memory_Model.Get_Node (Doc.Pool, Current);
         begin
            Current := Child.Next_Sibling_Index;
         end;
      end loop;

      return Count;
   end Child_Count;

   function Child_At
     (Doc : Document; Node : Node_Id; Index : Positive) return Node_Id
   is
      Idx     : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N       : SML.Memory_Model.Node;
      Current : SML.Memory_Model.Node_Index;
      Count   : Natural := 0;
   begin
      --  Precondition ensures node is valid and Index is in range
      N := SML.Memory_Model.Get_Node (Doc.Pool, Idx);

      --  Navigate to the Index'th child
      Current := N.First_Child_Index;
      while Current /= SML.Memory_Model.No_Node_Index loop
         pragma Loop_Variant (Increases => Count);
         pragma Loop_Invariant
           (Count < Index and then Count < Child_Count (Doc, Node));

         Count := Count + 1;
         if Count = Index then
            return To_Node_Id (Current);
         end if;

         declare
            Child : constant SML.Memory_Model.Node :=
              SML.Memory_Model.Get_Node (Doc.Pool, Current);
         begin
            Current := Child.Next_Sibling_Index;
         end;
      end loop;

      --  This should be unreachable if precondition is satisfied
      return Null_Node;
   end Child_At;

   ---------------------------------------------------------------------------
   --  Node Properties Implementation
   ---------------------------------------------------------------------------

   function Kind (Doc : Document; Node : Node_Id) return Node_Kind is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      --  Precondition ensures node is valid
      N := SML.Memory_Model.Get_Node (Doc.Pool, Idx);

      --  Convert internal kind to public enum
      case N.Kind is
         when SML.Memory_Model.Element =>
            return Element;
         when SML.Memory_Model.Text =>
            return Text;
      end case;
   end Kind;

   function Name (Doc : Document; Node : Node_Id) return String is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      --  Precondition ensures node is valid Element
      N := SML.Memory_Model.Get_Node (Doc.Pool, Idx);

      --  Safety: Verify node is actually an element
      if N.Kind /= SML.Memory_Model.Element then
         return "";  -- Should not happen with precondition
      end if;

      --  Return element name from string pool
      return SML.Memory_Model.Get_String (Doc.Pool, N.Element_Name_Ref);
   end Name;

   function Text_Value (Doc : Document; Node : Node_Id) return String is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      --  Precondition ensures node is valid Text
      N := SML.Memory_Model.Get_Node (Doc.Pool, Idx);

      --  Safety: Verify node is actually text
      if N.Kind /= SML.Memory_Model.Text then
         return "";  -- Should not happen with precondition
      end if;

      --  Return text content from string pool
      return SML.Memory_Model.Get_String (Doc.Pool, N.Text_Content_Ref);
   end Text_Value;

   ---------------------------------------------------------------------------
   --  Extended Query Functions
   ---------------------------------------------------------------------------

   function Find_Child_Element
     (Doc : Document; Parent_Node : Node_Id; Name : String) return Node_Id
   is
      Current : Node_Id;
   begin
      --  Walk through children looking for matching element
      Current := First_Child (Doc, Parent_Node);
      while Current /= Null_Node loop
         pragma Loop_Variant (Decreases => Natural (Current));
         pragma Loop_Invariant
           (if Current /= Null_Node then Parent (Doc, Current) = Parent_Node);

         --  Check if this child matches
         if Kind (Doc, Current) = Element
           and then SML.DOM.Name (Doc, Current) = Name
         then
            return Current;
         end if;

         --  Move to next sibling
         Current := Next_Sibling (Doc, Current);
      end loop;

      return Null_Node;
   end Find_Child_Element;

   function Has_Child_Elements (Doc : Document; Node : Node_Id) return Boolean
   is
      Current : Node_Id;
   begin
      --  Look for at least one element child
      Current := First_Child (Doc, Node);
      while Current /= Null_Node loop
         pragma Loop_Variant (Decreases => Natural (Current));

         if Kind (Doc, Current) = Element then
            return True;
         end if;

         Current := Next_Sibling (Doc, Current);
      end loop;

      return False;
   end Has_Child_Elements;

   function Count_Child_Elements
     (Doc : Document; Node : Node_Id) return Natural
   is
      Current : Node_Id;
      Count   : Natural := 0;
   begin
      --  Count only element children (skip text nodes)
      Current := First_Child (Doc, Node);
      while Current /= Null_Node and then Count < Max_Children loop
         pragma Loop_Variant (Decreases => Natural (Current));
         pragma Loop_Invariant (Count <= Max_Children);

         if Kind (Doc, Current) = Element then
            Count := Count + 1;
         end if;

         Current := Next_Sibling (Doc, Current);
      end loop;

      return Count;
   end Count_Child_Elements;

   function Element_Count (Doc : Document) return Natural is
      Count : Natural := 0;
   begin
      --  Count all element nodes in document
      for I in 1 .. SML.Memory_Model.Node_Index (Doc.Total_Nodes) loop
         pragma Loop_Invariant (Count <= Natural (I));

         declare
            Idx : constant SML.Memory_Model.Node_Index :=
              SML.Memory_Model.Node_Index (I);
         begin
            if SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
               declare
                  N : constant SML.Memory_Model.Node :=
                    SML.Memory_Model.Get_Node (Doc.Pool, Idx);
               begin
                  if N.Kind = SML.Memory_Model.Element
                    and then not N.Is_Deleted
                  then
                     Count := Count + 1;
                  end if;
               end;
            end if;
         end;
      end loop;

      return Count;
   end Element_Count;

   function Text_Count (Doc : Document) return Natural is
      Count : Natural := 0;
   begin
      --  Count all text nodes in document
      for I in 1 .. SML.Memory_Model.Node_Index (Doc.Total_Nodes) loop
         pragma Loop_Invariant (Count <= Natural (I));

         declare
            Idx : constant SML.Memory_Model.Node_Index :=
              SML.Memory_Model.Node_Index (I);
         begin
            if SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
               declare
                  N : constant SML.Memory_Model.Node :=
                    SML.Memory_Model.Get_Node (Doc.Pool, Idx);
               begin
                  if N.Kind = SML.Memory_Model.Text and then not N.Is_Deleted
                  then
                     Count := Count + 1;
                  end if;
               end;
            end if;
         end;
      end loop;

      return Count;
   end Text_Count;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Formal Verification
   ---------------------------------------------------------------------------
   --  All ghost function implementations have been moved to SML.DOM.Proof

end SML.DOM;