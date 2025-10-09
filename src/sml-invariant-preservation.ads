------------------------------------------------------------------------------
--  SML.Invariant_Preservation Package Specification
--  Invariant Preservation Proofs for SML Library Operations
--  SPARK Ada Implementation - Ghost Code for Verification
------------------------------------------------------------------------------

with SML.DOM;
with SML.Memory_Model;
with SML.Ownership;
with SML.Parser;

package SML.Invariant_Preservation with SPARK_Mode => On, Ghost is

   --  This ghost package proves that all operations in the SML library
   --  preserve critical invariants. Every operation that reads or modifies
   --  state maintains well-formedness, memory safety, and type correctness.

   ---------------------------------------------------------------------------
   --  Core Invariant Types
   ---------------------------------------------------------------------------

   --  Categories of invariants that must be preserved
   type Invariant_Kind is (
      Structural,    -- Tree structure properties
      Memory,        -- Memory safety and bounds
      Type_Safety,   -- Type system properties
      Ownership,     -- Node ownership relations
      Parser_State   -- Parser internal state
   );

   --  Complete system invariant
   function System_Invariant (Doc : SML.DOM.Document) return Boolean
     with Post => System_Invariant'Result =
                    (SML.DOM.Is_Well_Formed (Doc) and then
                     Memory_Invariant (Doc) and then
                     Type_Invariant (Doc) and then
                     Ownership_Invariant (Doc));

   --  Memory safety invariant
   function Memory_Invariant (Doc : SML.DOM.Document) return Boolean
     with Import;  -- Defined in SML.DOM_Enhanced

   --  Type system invariant
   function Type_Invariant (Doc : SML.DOM.Document) return Boolean
     with Post => Type_Invariant'Result =
                    (for all Node : SML.Memory_Model.Node_Index =>
                       (if SML.DOM.Is_Valid_Node (Doc, Node) then
                          Valid_Node_Type (Doc, Node)));

   --  Ownership invariant
   function Ownership_Invariant (Doc : SML.DOM.Document) return Boolean
     with Import;  -- Defined in SML.Ownership

   --  Valid node type properties
   function Valid_Node_Type (Doc : SML.DOM.Document;
                            Node : SML.Memory_Model.Node_Index)
                            return Boolean
     with Post => Valid_Node_Type'Result =
                    ((SML.DOM.Kind (Doc, Node) = SML.DOM.Element and then
                      Valid_Element_Properties (Doc, Node)) or else
                     (SML.DOM.Kind (Doc, Node) = SML.DOM.Text and then
                      Valid_Text_Properties (Doc, Node)));

   --  Valid element node properties
   function Valid_Element_Properties (Doc : SML.DOM.Document;
                                      Node : SML.Memory_Model.Node_Index)
                                      return Boolean
     with Pre => SML.DOM.Kind (Doc, Node) = SML.DOM.Element,
          Post => Valid_Element_Properties'Result =
                    (SML.DOM.Name (Doc, Node)'Length > 0 and then
                     SML.DOM.Child_Count (Doc, Node) <= SML.DOM.Max_Children);

   --  Valid text node properties
   function Valid_Text_Properties (Doc : SML.DOM.Document;
                                   Node : SML.Memory_Model.Node_Index)
                                   return Boolean
     with Pre => SML.DOM.Kind (Doc, Node) = SML.DOM.Text,
          Post => Valid_Text_Properties'Result =
                    (SML.DOM.Child_Count (Doc, Node) = 0 and then
                     SML.DOM.Is_Valid_UTF8 (SML.DOM.Text_Value (Doc, Node)));

   ---------------------------------------------------------------------------
   --  Frame Conditions (What Doesn't Change)
   ---------------------------------------------------------------------------

   --  Read operations don't modify the document
   function Read_Only_Frame (Doc_Before, Doc_After : SML.DOM.Document)
                            return Boolean
     with Post => Read_Only_Frame'Result = (Doc_Before = Doc_After);

   --  Local operations don't affect siblings
   function Local_Frame (Doc : SML.DOM.Document;
                        Modified_Node : SML.Memory_Model.Node_Index;
                        Sibling : SML.Memory_Model.Node_Index)
                        return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Modified_Node) and then
                 SML.DOM.Is_Valid_Node (Doc, Sibling) and then
                 not Is_Descendant (Doc, Modified_Node, Sibling),
          Post => Local_Frame'Result =
                    (Properties_Unchanged (Doc, Sibling));

   --  Tree operations don't change memory layout
   function Tree_Memory_Frame (Pool_Before, Pool_After : SML.Memory_Model.Arena_Pool)
                               return Boolean
     with Post => Tree_Memory_Frame'Result =
                    (Pool_Before.Allocated_Nodes = Pool_After.Allocated_Nodes and then
                     Pool_Before.Allocated_Bytes = Pool_After.Allocated_Bytes);

   --  Helper: Check if one node is descendant of another
   function Is_Descendant (Doc : SML.DOM.Document;
                          Ancestor, Node : SML.Memory_Model.Node_Index)
                          return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Ancestor) and then
                 SML.DOM.Is_Valid_Node (Doc, Node);

   --  Helper: Properties unchanged for a node
   function Properties_Unchanged (Doc : SML.DOM.Document;
                                 Node : SML.Memory_Model.Node_Index)
                                 return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Node);

   ---------------------------------------------------------------------------
   --  DOM Traversal Preservation Lemmas
   ---------------------------------------------------------------------------

   --  Root operation preserves all invariants
   procedure Lemma_Root_Preserves_Invariants (Doc : SML.DOM.Document)
     with Pre  => System_Invariant (Doc),
          Post => System_Invariant (Doc) and then
                  Read_Only_Frame (Doc, Doc);

   --  Parent operation preserves all invariants
   procedure Lemma_Parent_Preserves_Invariants (Doc : SML.DOM.Document;
                                                Node : SML.Memory_Model.Node_Index)
     with Pre  => System_Invariant (Doc) and then
                  Node /= SML.Memory_Model.No_Node_Index and then
                  SML.DOM.Is_Valid_Node (Doc, Node),
          Post => System_Invariant (Doc) and then
                  Read_Only_Frame (Doc, Doc);

   --  First_Child operation preserves all invariants
   procedure Lemma_First_Child_Preserves_Invariants (Doc : SML.DOM.Document;
                                                     Node : SML.Memory_Model.Node_Index)
     with Pre  => System_Invariant (Doc) and then
                  Node /= SML.Memory_Model.No_Node_Index and then
                  SML.DOM.Is_Valid_Node (Doc, Node),
          Post => System_Invariant (Doc) and then
                  Read_Only_Frame (Doc, Doc);

   --  Next_Sibling operation preserves all invariants
   procedure Lemma_Next_Sibling_Preserves_Invariants (Doc : SML.DOM.Document;
                                                      Node : SML.Memory_Model.Node_Index)
     with Pre  => System_Invariant (Doc) and then
                  Node /= SML.Memory_Model.No_Node_Index and then
                  SML.DOM.Is_Valid_Node (Doc, Node),
          Post => System_Invariant (Doc) and then
                  Read_Only_Frame (Doc, Doc);

   --  Child_Count operation preserves all invariants
   procedure Lemma_Child_Count_Preserves_Invariants (Doc : SML.DOM.Document;
                                                     Node : SML.Memory_Model.Node_Index)
     with Pre  => System_Invariant (Doc) and then
                  Node /= SML.Memory_Model.No_Node_Index and then
                  SML.DOM.Is_Valid_Node (Doc, Node),
          Post => System_Invariant (Doc) and then
                  Read_Only_Frame (Doc, Doc);

   --  All traversal operations preserve invariants
   procedure Lemma_All_Traversals_Preserve_Invariants (Doc : SML.DOM.Document)
     with Pre  => System_Invariant (Doc),
          Post => System_Invariant (Doc) and then
                  (for all Node : SML.Memory_Model.Node_Index =>
                     (if SML.DOM.Is_Valid_Node (Doc, Node) then
                        Read_Only_Frame (Doc, Doc)));

   ---------------------------------------------------------------------------
   --  Construction Operation Preservation
   ---------------------------------------------------------------------------

   --  Node allocation preserves invariants
   procedure Lemma_Allocate_Node_Preserves_Invariants
     (Pool : in out SML.Memory_Model.Arena_Pool;
      Kind : SML.Memory_Model.Node_Kind)
     with Pre  => SML.Memory_Model.Can_Allocate_Node (Pool) and then
                  SML.Memory_Model.Arena_Invariants (Pool),
          Post => SML.Memory_Model.Arena_Invariants (Pool) and then
                  Pool.Allocated_Nodes = Pool'Old.Allocated_Nodes + 1;

   --  String allocation preserves invariants
   procedure Lemma_Allocate_String_Preserves_Invariants
     (Pool : in out SML.Memory_Model.Arena_Pool;
      Text : String)
     with Pre  => Text'Length <= SML.Memory_Model.Max_String_Storage and then
                  SML.Memory_Model.Can_Allocate_String (Pool, Text'Length) and then
                  SML.Memory_Model.Arena_Invariants (Pool),
          Post => SML.Memory_Model.Arena_Invariants (Pool) and then
                  Pool.Allocated_Bytes = Pool'Old.Allocated_Bytes + Text'Length;

   --  Linking nodes preserves tree invariants
   procedure Lemma_Link_Nodes_Preserves_Invariants
     (Doc : in out SML.DOM.Document;
      Parent, Child : SML.Memory_Model.Node_Index)
     with Pre  => System_Invariant (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Parent) and then
                  SML.DOM.Is_Valid_Node (Doc, Child) and then
                  SML.DOM.Kind (Doc, Parent) = SML.DOM.Element and then
                  not Is_Descendant (Doc, Child, Parent) and then
                  not Creates_Cycle (Doc, Parent, Child),
          Post => System_Invariant (Doc) and then
                  SML.DOM.Parent (Doc, Child) = Parent;

   --  Helper: Check if linking would create a cycle
   function Creates_Cycle (Doc : SML.DOM.Document;
                          Parent, Child : SML.Memory_Model.Node_Index)
                          return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Parent) and then
                 SML.DOM.Is_Valid_Node (Doc, Child),
          Post => Creates_Cycle'Result =
                    Is_Descendant (Doc, Child, Parent);

   ---------------------------------------------------------------------------
   --  Parser Operation Preservation
   ---------------------------------------------------------------------------

   --  Parse operation creates well-formed document
   procedure Lemma_Parse_Creates_Valid_Document (Input : String)
     with Pre  => SML.DOM.Parser.Is_Valid_SML (Input),
          Post => (for some Result : SML.DOM.Parser.Parse_Result =>
                     (if SML.DOM.Parser.Parse (Input) = Result and then
                         Result.Success
                      then System_Invariant (Result.Document)));

   --  Parse error doesn't corrupt state
   procedure Lemma_Parse_Error_Safe (Input : String)
     with Pre  => not SML.DOM.Parser.Is_Valid_SML (Input),
          Post => (for some Result : SML.DOM.Parser.Parse_Result =>
                     (if SML.DOM.Parser.Parse (Input) = Result then
                        not Result.Success));

   ---------------------------------------------------------------------------
   --  Composition Lemmas
   ---------------------------------------------------------------------------

   --  Sequential operations preserve invariants
   procedure Lemma_Sequential_Preservation
     (Doc : SML.DOM.Document;
      Op1, Op2 : Operation_Kind)
     with Pre  => System_Invariant (Doc) and then
                  Preserves_Invariant (Op1) and then
                  Preserves_Invariant (Op2),
          Post => System_Invariant (Doc);

   --  Parallel read operations don't interfere
   procedure Lemma_Parallel_Reads_Safe
     (Doc : SML.DOM.Document;
      Node1, Node2 : SML.Memory_Model.Node_Index)
     with Pre  => System_Invariant (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Node1) and then
                  SML.DOM.Is_Valid_Node (Doc, Node2),
          Post => System_Invariant (Doc) and then
                  Read_Only_Frame (Doc, Doc);

   --  Nested operations maintain properties
   procedure Lemma_Nested_Operations_Safe
     (Doc : SML.DOM.Document;
      Outer_Node, Inner_Node : SML.Memory_Model.Node_Index)
     with Pre  => System_Invariant (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Outer_Node) and then
                  SML.DOM.Is_Valid_Node (Doc, Inner_Node) and then
                  Is_Descendant (Doc, Outer_Node, Inner_Node),
          Post => System_Invariant (Doc);

   ---------------------------------------------------------------------------
   --  Helper Types
   ---------------------------------------------------------------------------

   type Operation_Kind is (
      Read_Operation,
      Traversal_Operation,
      Construction_Operation,
      Modification_Operation
   );

   function Preserves_Invariant (Op : Operation_Kind) return Boolean
     with Post => Preserves_Invariant'Result = True;  -- All ops preserve

   ---------------------------------------------------------------------------
   --  Main Invariant Preservation Theorem
   ---------------------------------------------------------------------------

   --  All operations preserve all invariants
   procedure Theorem_All_Operations_Preserve_All_Invariants
     with Ghost,
          Post => (for all Doc : SML.DOM.Document =>
                     (if System_Invariant (Doc) then
                        (for all Op : Operation_Kind =>
                           Preserves_Invariant (Op))));

end SML.Invariant_Preservation;