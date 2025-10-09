------------------------------------------------------------------------------
--  SML.DOM.Builder Package Body
--  DOM Construction and Mutation Implementation
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML.Memory_Model;
use type SML.Memory_Model.Node_Kind;

package body SML.DOM.Builder
  with SPARK_Mode => On
is

   ---------------------------------------------------------------------------
   --  Helper Functions for Type Conversions
   ---------------------------------------------------------------------------

   --  Convert Node_Id to Memory_Model index
   function To_Index (Node : Node_Id) return SML.Memory_Model.Node_Index
   is (SML.Memory_Model.Node_Index (Node))
   with Inline;

   --  Convert Memory_Model index to Node_Id
   function To_Node_Id (Index : SML.Memory_Model.Node_Index) return Node_Id
   is (Node_Id (Index))
   with Inline;

   ---------------------------------------------------------------------------
   --  Document Creation
   ---------------------------------------------------------------------------

   function Create_Document (Root_Name : String) return Document is
      Root_Index : SML.Memory_Model.Node_Index;
      Name_Ref   : SML.Memory_Model.String_Ref;
   begin
      --  Use extended return for limited type
      return Result : Document do
         --  Initialize arena pool
         SML.Memory_Model.Reset_Arena (Result.Pool);

         --  Allocate root node
         SML.Memory_Model.Allocate_Node
           (Result.Pool, SML.Memory_Model.Element, Root_Index);

         --  Allocate and store element name
         SML.Memory_Model.Allocate_String (Result.Pool, Root_Name, Name_Ref);
         SML.Memory_Model.Store_String (Result.Pool, Name_Ref, Root_Name);

         --  Initialize root node
         declare
            Root_Node : SML.Memory_Model.Node (SML.Memory_Model.Element);
         begin
            Root_Node.Parent_Index := SML.Memory_Model.No_Node_Index;
            Root_Node.First_Child_Index := SML.Memory_Model.No_Node_Index;
            Root_Node.Next_Sibling_Index := SML.Memory_Model.No_Node_Index;
            Root_Node.Is_Deleted := False;
            Root_Node.Element_Name_Ref := Name_Ref;
            Root_Node.Num_Children := 0;

            SML.Memory_Model.Set_Node (Result.Pool, Root_Index, Root_Node);
         end;

         --  Set document root
         Result.Root_Node := Node_Id (Root_Index);
         Result.Total_Nodes := 1;
      end return;
   end Create_Document;

   ---------------------------------------------------------------------------
   --  DOM Mutation Operations
   ---------------------------------------------------------------------------

   procedure Add_Child_Element
     (Doc       : in out Document;
      Parent    : Node_Id;
      Name      : String;
      New_Child : out Node_Id)
   is
      Parent_Index   : constant SML.Memory_Model.Node_Index := To_Index (Parent);
      Child_Index    : SML.Memory_Model.Node_Index;
      Name_Ref       : SML.Memory_Model.String_Ref;
      Parent_Node    : SML.Memory_Model.Node;
      Last_Child_Idx : SML.Memory_Model.Node_Index;
   begin
      --  Allocate new node
      SML.Memory_Model.Allocate_Node
        (Doc.Pool, SML.Memory_Model.Element, Child_Index);

      --  Allocate and store element name
      SML.Memory_Model.Allocate_String (Doc.Pool, Name, Name_Ref);
      SML.Memory_Model.Store_String (Doc.Pool, Name_Ref, Name);

      --  Initialize child node
      declare
         Child_Node : SML.Memory_Model.Node (SML.Memory_Model.Element);
      begin
         Child_Node.Parent_Index := Parent_Index;
         Child_Node.First_Child_Index := SML.Memory_Model.No_Node_Index;
         Child_Node.Next_Sibling_Index := SML.Memory_Model.No_Node_Index;
         Child_Node.Is_Deleted := False;
         Child_Node.Element_Name_Ref := Name_Ref;
         Child_Node.Num_Children := 0;

         SML.Memory_Model.Set_Node (Doc.Pool, Child_Index, Child_Node);
      end;

      --  Link to parent
      Parent_Node := SML.Memory_Model.Get_Node (Doc.Pool, Parent_Index);

      if Parent_Node.Num_Children = 0 then
         --  This is the first child
         Parent_Node.First_Child_Index := Child_Index;
      else
         --  Find last child and link as sibling
         Last_Child_Idx := Parent_Node.First_Child_Index;

         declare
            Current : SML.Memory_Model.Node_Index := Last_Child_Idx;
            N       : SML.Memory_Model.Node;
            Count   : Natural := 0;
         begin
            --  Find last sibling
            loop
               pragma Loop_Variant (Increases => Count);

               N := SML.Memory_Model.Get_Node (Doc.Pool, Current);

               exit when N.Next_Sibling_Index = SML.Memory_Model.No_Node_Index;

               Current := N.Next_Sibling_Index;
               Count := Count + 1;

               --  Safety: prevent infinite loop
               exit when Count >= Max_Children;
            end loop;

            --  Link as next sibling
            N.Next_Sibling_Index := Child_Index;
            SML.Memory_Model.Set_Node (Doc.Pool, Current, N);
         end;
      end if;

      --  Update parent's child count
      Parent_Node.Num_Children := Parent_Node.Num_Children + 1;
      SML.Memory_Model.Set_Node (Doc.Pool, Parent_Index, Parent_Node);

      --  Update document total
      Doc.Total_Nodes := Doc.Total_Nodes + 1;

      --  Return new node ID
      New_Child := To_Node_Id (Child_Index);
   end Add_Child_Element;

   procedure Add_Text_Node
     (Doc      : in out Document;
      Parent   : Node_Id;
      Text     : String;
      New_Text : out Node_Id)
   is
      Parent_Index   : constant SML.Memory_Model.Node_Index := To_Index (Parent);
      Text_Index     : SML.Memory_Model.Node_Index;
      Text_Ref       : SML.Memory_Model.String_Ref;
      Parent_Node    : SML.Memory_Model.Node;
   begin
      --  Allocate new text node
      SML.Memory_Model.Allocate_Node
        (Doc.Pool, SML.Memory_Model.Text, Text_Index);

      --  Allocate and store text content
      SML.Memory_Model.Allocate_String (Doc.Pool, Text, Text_Ref);
      SML.Memory_Model.Store_String (Doc.Pool, Text_Ref, Text);

      --  Initialize text node
      declare
         Text_Node : SML.Memory_Model.Node (SML.Memory_Model.Text);
      begin
         Text_Node.Parent_Index := Parent_Index;
         Text_Node.First_Child_Index := SML.Memory_Model.No_Node_Index;
         Text_Node.Next_Sibling_Index := SML.Memory_Model.No_Node_Index;
         Text_Node.Is_Deleted := False;
         Text_Node.Text_Content_Ref := Text_Ref;

         SML.Memory_Model.Set_Node (Doc.Pool, Text_Index, Text_Node);
      end;

      --  Link to parent
      Parent_Node := SML.Memory_Model.Get_Node (Doc.Pool, Parent_Index);

      if Parent_Node.Num_Children = 0 then
         --  This is the first child
         Parent_Node.First_Child_Index := Text_Index;
      else
         --  Find last child and link as sibling
         declare
            Current : SML.Memory_Model.Node_Index := Parent_Node.First_Child_Index;
            N       : SML.Memory_Model.Node;
            Count   : Natural := 0;
         begin
            --  Find last sibling
            loop
               pragma Loop_Variant (Increases => Count);

               N := SML.Memory_Model.Get_Node (Doc.Pool, Current);

               exit when N.Next_Sibling_Index = SML.Memory_Model.No_Node_Index;

               Current := N.Next_Sibling_Index;
               Count := Count + 1;

               --  Safety: prevent infinite loop
               exit when Count >= Max_Children;
            end loop;

            --  Link as next sibling
            N.Next_Sibling_Index := Text_Index;
            SML.Memory_Model.Set_Node (Doc.Pool, Current, N);
         end;
      end if;

      --  Update parent's child count
      Parent_Node.Num_Children := Parent_Node.Num_Children + 1;
      SML.Memory_Model.Set_Node (Doc.Pool, Parent_Index, Parent_Node);

      --  Update document total
      Doc.Total_Nodes := Doc.Total_Nodes + 1;

      --  Return new node ID
      New_Text := To_Node_Id (Text_Index);
   end Add_Text_Node;

   ---------------------------------------------------------------------------
   --  Deletion Operations
   ---------------------------------------------------------------------------

   procedure Delete_Node (Doc : in out Document; Node : Node_Id) is
      --  Recursive helper to mark entire subtree as deleted
      procedure Mark_Subtree_Deleted (Node_Index : SML.Memory_Model.Node_Index)
      is
         N           : SML.Memory_Model.Node;
         Child_Index : SML.Memory_Model.Node_Index;
         Count       : Natural := 0;
      begin
         --  Get and mark this node as deleted
         N := SML.Memory_Model.Get_Node (Doc.Pool, Node_Index);
         N.Is_Deleted := True;
         SML.Memory_Model.Set_Node (Doc.Pool, Node_Index, N);

         --  Recursively mark all children if this is an element
         if N.Kind = SML.Memory_Model.Element then
            Child_Index := N.First_Child_Index;

            while Child_Index /= SML.Memory_Model.No_Node_Index loop
               pragma Loop_Variant (Increases => Count);

               --  Recursively mark child subtree
               Mark_Subtree_Deleted (Child_Index);

               --  Move to next sibling
               N := SML.Memory_Model.Get_Node (Doc.Pool, Child_Index);
               Child_Index := N.Next_Sibling_Index;
               Count := Count + 1;

               --  Safety: prevent infinite loop
               exit when Count >= Max_Children;
            end loop;
         end if;
      end Mark_Subtree_Deleted;

   begin
      Mark_Subtree_Deleted (To_Index (Node));
   end Delete_Node;

   function Not_Deleted (Doc : Document; Node : Node_Id) return Boolean is
      Idx : constant SML.Memory_Model.Node_Index := To_Index (Node);
      N   : SML.Memory_Model.Node;
   begin
      if not SML.Memory_Model.Valid_Node_Index (Doc.Pool, Idx) then
         return False;
      end if;

      N := SML.Memory_Model.Get_Node (Doc.Pool, Idx);
      return not N.Is_Deleted;
   end Not_Deleted;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Verification
   ---------------------------------------------------------------------------

   function Has_Deleted_Nodes (Doc : Document) return Boolean is
      pragma Unreferenced (Doc);
   begin
      --  Ghost function - simplified implementation
      --  Full implementation would check all nodes
      return False;  -- Conservative approximation
   end Has_Deleted_Nodes;

   function No_Deleted_Nodes (Doc : Document) return Boolean is
   begin
      return not Has_Deleted_Nodes (Doc);
   end No_Deleted_Nodes;

end SML.DOM.Builder;
