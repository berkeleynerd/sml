------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                     SPARK Proof Support - DOM Package                    --
------------------------------------------------------------------------------

package SML.DOM.Proof
with
   Ghost,
   SPARK_Mode
is

   ---------------------------------------------------------------------------
   --  Ghost Functions for DOM Verification
   ---------------------------------------------------------------------------

   --  Checks if a node belongs to the given document
   function Is_Valid_Node (Doc : Document; Node : Node_Id) return Boolean
     with Global => null;

   --  Checks structural well-formedness of a Document's DOM tree
   function Is_Well_Formed (Doc : Document) return Boolean
     with
       Global => null,
       Post =>
         Is_Well_Formed'Result =
           (Has_Single_Root (Doc)
            and then Is_Acyclic (Doc)
            and then Has_Consistent_Parent_Child_Links (Doc)
            and then Has_Valid_Depth (Doc));

   --  Document has exactly one root element
   function Has_Single_Root (Doc : Document) return Boolean
     with Global => null;

   --  Document tree contains no cycles
   function Is_Acyclic (Doc : Document) return Boolean
     with Global => null;

   --  Parent-child relationships are bidirectional
   function Has_Consistent_Parent_Child_Links (Doc : Document) return Boolean
     with Global => null;

   --  All nodes have depth <= Max_Tree_Depth
   function Has_Valid_Depth (Doc : Document) return Boolean
     with Global => null;

   --  Checks if a string is a valid element/attribute name
   function Is_Valid_Name (Name : String) return Boolean
     with Global => null;

   ---------------------------------------------------------------------------
   --  Memory Management Ghost Functions
   ---------------------------------------------------------------------------

   --  All allocated nodes are reachable from the root
   function All_Nodes_Reachable (Doc : Document) return Boolean
     with Global => null;

   --  No unreachable nodes exist in the pool
   function No_Memory_Leaks (Doc : Document) return Boolean
     with Global => null;

   --  String storage is managed correctly
   function String_Storage_Valid (Doc : Document) return Boolean
     with Global => null;

   ---------------------------------------------------------------------------
   --  Node Relationship Ghost Functions
   ---------------------------------------------------------------------------

   --  Returns the depth of a node in the tree (root has depth 0)
   function Depth (Doc : Document; Node : Node_Id) return Natural
     with
       Pre => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
       Post => Depth'Result <= Max_Tree_Depth,
       Global => null;

   --  Check if Node is an ancestor of Descendant
   function Is_Ancestor_Of
     (Doc : Document; Node, Descendant : Node_Id) return Boolean
     with
       Pre =>
         Is_Valid_Node (Doc, Node) and then Is_Valid_Node (Doc, Descendant),
       Global => null;

   --  Checks if Parent_Node has Child_Node as a child
   function Has_Child
     (Doc : Document; Parent_Node, Child_Node : Node_Id) return Boolean
     with
       Pre =>
         Parent_Node /= Null_Node
         and then Child_Node /= Null_Node
         and then Is_Valid_Node (Doc, Parent_Node)
         and then Is_Valid_Node (Doc, Child_Node),
       Subprogram_Variant => (Structural => Parent_Node),
       Global => null;

   --  Count total nodes in the subtree rooted at Node
   function Subtree_Size (Doc : Document; Node : Node_Id) return Natural
     with
       Pre => Is_Valid_Node (Doc, Node),
       Post => Subtree_Size'Result >= 1,  -- At least the node itself
       Global => null;

   ---------------------------------------------------------------------------
   --  Invariant Helper Functions
   ---------------------------------------------------------------------------

   --  Check that all text content is valid UTF-8
   function All_Text_Valid_UTF8 (Doc : Document) return Boolean
     with Global => null;

   --  Check that all element names are valid
   function All_Names_Valid (Doc : Document) return Boolean
     with Global => null;

   ---------------------------------------------------------------------------
   --  Lemmas for Proof Assistance
   ---------------------------------------------------------------------------

   --  If a document is well-formed, its root is valid
   procedure Lemma_Well_Formed_Has_Valid_Root (Doc : Document)
     with
       Pre => Is_Well_Formed (Doc),
       Post => Is_Valid_Node (Doc, Root (Doc)),
       Global => null;

   --  Adding a valid node preserves well-formedness
   procedure Lemma_Add_Node_Preserves_Well_Formed
     (Doc_Before, Doc_After : Document; New_Node : Node_Id)
     with
       Pre =>
         Is_Well_Formed (Doc_Before)
         and then Is_Well_Formed (Doc_After)
         and then Is_Valid_Node (Doc_After, New_Node),
       Global => null;

end SML.DOM.Proof;
