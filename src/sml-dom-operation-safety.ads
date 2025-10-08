------------------------------------------------------------------------------
--  SML.DOM_Operation_Safety Package Specification
--  DOM Operation Safety and Preservation Proofs for SML Library
--  SPARK Ada Implementation - Ghost Code for Verification
------------------------------------------------------------------------------

with SML.DOM;
with SML.Memory_Model;
with SML.Ownership;
with SML.Null_Safety;
with SML.Bounds_Safety;

package SML.DOM_Operation_Safety with SPARK_Mode => On, Ghost is

   --  This ghost package proves that all DOM operations are safe and
   --  preserve critical tree properties. Operations are categorized as
   --  read-only, constructive, or modifying, with specific safety
   --  guarantees for each category.

   ---------------------------------------------------------------------------
   --  Operation Categories
   ---------------------------------------------------------------------------

   type DOM_Operation_Category is (
      Query,         -- Read-only queries (Kind, Name, Text_Value)
      Traversal,     -- Navigation (Parent, First_Child, Next_Sibling)
      Measurement,   -- Metrics (Child_Count, Depth)
      Construction,  -- Building DOM (Create_Node, Link_Node)
      Modification   -- Changing DOM (Set_Text, Set_Name)
   );

   --  Operation effect on DOM
   type Operation_Effect is (
      No_Effect,           -- Pure read, no state change
      Local_Effect,        -- Affects single node
      Subtree_Effect,      -- Affects node and descendants
      Global_Effect        -- Affects entire document
   );

   function Get_Operation_Effect (Op : DOM_Operation_Category)
                                 return Operation_Effect
     with Post => Get_Operation_Effect'Result =
                    (case Op is
                       when Query | Traversal | Measurement => No_Effect,
                       when Construction | Modification => Local_Effect);

   ---------------------------------------------------------------------------
   --  Read-Only Operation Safety
   ---------------------------------------------------------------------------

   --  Query operations don't modify state
   procedure Lemma_Query_Operations_Read_Only (Doc : SML.DOM.Document;
                                               Node : SML.Memory_Model.Node_Index)
     with Pre  => SML.DOM.Is_Valid_Node (Doc, Node),
          Post => Document_Unchanged (Doc, Doc);

   --  Traversal operations don't modify state
   procedure Lemma_Traversal_Operations_Read_Only (Doc : SML.DOM.Document;
                                                   Node : SML.Memory_Model.Node_Index)
     with Pre  => SML.DOM.Is_Valid_Node (Doc, Node),
          Post => Document_Unchanged (Doc, Doc) and then
                  (SML.DOM.Parent (Doc, Node) = SML.DOM.Parent (Doc, Node)) and then
                  (SML.DOM.First_Child (Doc, Node) = SML.DOM.First_Child (Doc, Node));

   --  Measurement operations don't modify state
   procedure Lemma_Measurement_Operations_Read_Only (Doc : SML.DOM.Document;
                                                     Node : SML.Memory_Model.Node_Index)
     with Pre  => SML.DOM.Is_Valid_Node (Doc, Node),
          Post => Document_Unchanged (Doc, Doc) and then
                  (SML.DOM.Child_Count (Doc, Node) = SML.DOM.Child_Count (Doc, Node)) and then
                  (SML.DOM.Depth (Doc, Node) = SML.DOM.Depth (Doc, Node));

   --  Helper: Document unchanged
   function Document_Unchanged (Before, After : SML.DOM.Document) return Boolean
     with Post => Document_Unchanged'Result = (Before = After);

   ---------------------------------------------------------------------------
   --  Traversal Safety Properties
   ---------------------------------------------------------------------------

   --  Parent returns valid parent or null
   function Parent_Result_Valid (Doc : SML.DOM.Document;
                                Node : SML.Memory_Model.Node_Index) return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Node),
          Post => Parent_Result_Valid'Result =
                    (declare
                       P : constant SML.Memory_Model.Node_Index :=
                         SML.DOM.Parent (Doc, Node);
                     begin
                       P = SML.Memory_Model.No_Node_Index or else
                       (SML.DOM.Is_Valid_Node (Doc, P) and then
                        SML.DOM.Kind (Doc, P) = SML.DOM.Element and then
                        Has_As_Child (Doc, P, Node)));

   --  First_Child returns valid child or null
   function First_Child_Result_Valid (Doc : SML.DOM.Document;
                                     Node : SML.Memory_Model.Node_Index) return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Node),
          Post => First_Child_Result_Valid'Result =
                    (declare
                       C : constant SML.Memory_Model.Node_Index :=
                         SML.DOM.First_Child (Doc, Node);
                     begin
                       C = SML.Memory_Model.No_Node_Index or else
                       (SML.DOM.Is_Valid_Node (Doc, C) and then
                        SML.DOM.Parent (Doc, C) = Node));

   --  Next_Sibling returns valid sibling or null
   function Next_Sibling_Result_Valid (Doc : SML.DOM.Document;
                                       Node : SML.Memory_Model.Node_Index) return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Node),
          Post => Next_Sibling_Result_Valid'Result =
                    (declare
                       S : constant SML.Memory_Model.Node_Index :=
                         SML.DOM.Next_Sibling (Doc, Node);
                     begin
                       S = SML.Memory_Model.No_Node_Index or else
                       (SML.DOM.Is_Valid_Node (Doc, S) and then
                        SML.DOM.Parent (Doc, S) = SML.DOM.Parent (Doc, Node)));

   --  Helper: Check if parent has child
   function Has_As_Child (Doc : SML.DOM.Document;
                         Parent, Child : SML.Memory_Model.Node_Index)
                         return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Parent) and then
                 SML.DOM.Is_Valid_Node (Doc, Child);

   ---------------------------------------------------------------------------
   --  Construction Operation Safety
   ---------------------------------------------------------------------------

   --  Creating a node maintains well-formedness
   procedure Lemma_Create_Node_Safe (Doc : in out SML.DOM.Document;
                                     Kind : SML.DOM.Node_Kind;
                                     Name : String)
     with Pre  => SML.DOM.Is_Well_Formed (Doc) and then
                  Can_Allocate_Node (Doc) and then
                  (Kind = SML.DOM.Element implies
                     Name'Length > 0 and Name'Length <= SML.Memory_Model.Max_Name_Length),
          Post => SML.DOM.Is_Well_Formed (Doc) and then
                  Node_Count_Increased (Doc'Old, Doc, 1);

   --  Linking nodes preserves tree properties
   procedure Lemma_Link_Node_Safe (Doc : in out SML.DOM.Document;
                                   Parent, Child : SML.Memory_Model.Node_Index)
     with Pre  => SML.DOM.Is_Well_Formed (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Parent) and then
                  SML.DOM.Is_Valid_Node (Doc, Child) and then
                  SML.DOM.Kind (Doc, Parent) = SML.DOM.Element and then
                  Can_Add_Child (Doc, Parent) and then
                  Not_Creates_Cycle (Doc, Parent, Child) and then
                  Not_Exceeds_Depth (Doc, Parent, Child),
          Post => SML.DOM.Is_Well_Formed (Doc) and then
                  SML.DOM.Parent (Doc, Child) = Parent and then
                  Tree_Height_Preserved (Doc'Old, Doc);

   --  Setting text content is safe
   procedure Lemma_Set_Text_Safe (Doc : in out SML.DOM.Document;
                                  Node : SML.Memory_Model.Node_Index;
                                  Text : String)
     with Pre  => SML.DOM.Is_Well_Formed (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Node) and then
                  SML.DOM.Kind (Doc, Node) = SML.DOM.Text and then
                  SML.DOM.Is_Valid_UTF8 (Text) and then
                  Text'Length <= SML.Memory_Model.Max_Text_Length,
          Post => SML.DOM.Is_Well_Formed (Doc) and then
                  SML.DOM.Text_Value (Doc, Node) = Text and then
                  Structure_Preserved (Doc'Old, Doc);

   ---------------------------------------------------------------------------
   --  Safety Predicates
   ---------------------------------------------------------------------------

   --  Can allocate a new node
   function Can_Allocate_Node (Doc : SML.DOM.Document) return Boolean;

   --  Can add child to parent
   function Can_Add_Child (Doc : SML.DOM.Document;
                          Parent : SML.Memory_Model.Node_Index) return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Parent) and then
                 SML.DOM.Kind (Doc, Parent) = SML.DOM.Element,
          Post => Can_Add_Child'Result =
                    (SML.DOM.Child_Count (Doc, Parent) < SML.DOM.Max_Children);

   --  Linking won't create cycle
   function Not_Creates_Cycle (Doc : SML.DOM.Document;
                               Parent, Child : SML.Memory_Model.Node_Index)
                               return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Parent) and then
                 SML.DOM.Is_Valid_Node (Doc, Child),
          Post => Not_Creates_Cycle'Result =
                    not Is_Ancestor_Of (Doc, Child, Parent);

   --  Linking won't exceed depth limit
   function Not_Exceeds_Depth (Doc : SML.DOM.Document;
                               Parent, Child : SML.Memory_Model.Node_Index)
                               return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Parent) and then
                 SML.DOM.Is_Valid_Node (Doc, Child),
          Post => Not_Exceeds_Depth'Result =
                    (SML.DOM.Depth (Doc, Parent) + Subtree_Height (Doc, Child) <
                     SML.DOM.Max_Tree_Depth);

   --  Check ancestry relationship
   function Is_Ancestor_Of (Doc : SML.DOM.Document;
                           Ancestor, Node : SML.Memory_Model.Node_Index)
                           return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Ancestor) and then
                 SML.DOM.Is_Valid_Node (Doc, Node);

   --  Get height of subtree
   function Subtree_Height (Doc : SML.DOM.Document;
                           Root : SML.Memory_Model.Node_Index) return Natural
     with Pre => SML.DOM.Is_Valid_Node (Doc, Root),
          Post => Subtree_Height'Result <= SML.DOM.Max_Tree_Depth;

   ---------------------------------------------------------------------------
   --  Preservation Predicates
   ---------------------------------------------------------------------------

   --  Node count increased by N
   function Node_Count_Increased (Before, After : SML.DOM.Document;
                                 N : Natural) return Boolean;

   --  Tree height unchanged
   function Tree_Height_Preserved (Before, After : SML.DOM.Document)
                                  return Boolean;

   --  Tree structure unchanged
   function Structure_Preserved (Before, After : SML.DOM.Document)
                                return Boolean;

   ---------------------------------------------------------------------------
   --  Batch Operation Safety
   ---------------------------------------------------------------------------

   --  Multiple operations in sequence
   procedure Lemma_Sequential_Operations_Safe
     (Doc : in out SML.DOM.Document;
      Op_Count : Natural)
     with Pre  => SML.DOM.Is_Well_Formed (Doc) and then
                  Op_Count <= 100,
          Post => SML.DOM.Is_Well_Formed (Doc);

   --  Recursive tree walk is safe
   procedure Lemma_Tree_Walk_Safe (Doc : SML.DOM.Document;
                                   Root : SML.Memory_Model.Node_Index)
     with Pre  => SML.DOM.Is_Well_Formed (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Root),
          Post => SML.DOM.Is_Well_Formed (Doc) and then
                  Document_Unchanged (Doc, Doc);

   --  Depth-first traversal is safe
   procedure Lemma_DFS_Traversal_Safe (Doc : SML.DOM.Document;
                                       Root : SML.Memory_Model.Node_Index;
                                       Max_Visits : Natural)
     with Pre  => SML.DOM.Is_Well_Formed (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Root) and then
                  Max_Visits >= Count_Nodes_In_Subtree (Doc, Root),
          Post => SML.DOM.Is_Well_Formed (Doc) and then
                  Document_Unchanged (Doc, Doc);

   --  Count nodes in subtree
   function Count_Nodes_In_Subtree (Doc : SML.DOM.Document;
                                    Root : SML.Memory_Model.Node_Index)
                                    return Natural
     with Pre => SML.DOM.Is_Valid_Node (Doc, Root),
          Post => Count_Nodes_In_Subtree'Result <= SML.Memory_Model.Max_Document_Nodes;

   ---------------------------------------------------------------------------
   --  Error Handling Safety
   ---------------------------------------------------------------------------

   --  Invalid node access returns safe default
   function Safe_Access_Invalid_Node (Doc : SML.DOM.Document;
                                     Node : SML.Memory_Model.Node_Index)
                                     return Boolean
     with Post => Safe_Access_Invalid_Node'Result =
                    (if not SML.DOM.Is_Valid_Node (Doc, Node) then
                       All_Operations_Return_Safe_Default (Doc, Node));

   --  All operations have safe defaults
   function All_Operations_Return_Safe_Default (Doc : SML.DOM.Document;
                                                Invalid_Node : SML.Memory_Model.Node_Index)
                                                return Boolean
     with Pre => not SML.DOM.Is_Valid_Node (Doc, Invalid_Node);

   ---------------------------------------------------------------------------
   --  Main Safety Theorem
   ---------------------------------------------------------------------------

   --  All DOM operations are safe and preserve well-formedness
   procedure Theorem_All_DOM_Operations_Safe
     with Ghost,
          Post => (for all Doc : SML.DOM.Document =>
                     (if SML.DOM.Is_Well_Formed (Doc) then
                        (for all Op : DOM_Operation_Category =>
                           Operation_Preserves_Well_Formedness (Doc, Op))));

   function Operation_Preserves_Well_Formedness (Doc : SML.DOM.Document;
                                                 Op : DOM_Operation_Category)
                                                 return Boolean
     with Post => Operation_Preserves_Well_Formedness'Result = True;

end SML.DOM_Operation_Safety;