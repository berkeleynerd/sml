------------------------------------------------------------------------------
--  SML.DOM Package Specification
--  Document Object Model for Simple Markup Language (SML)
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML.Memory_Model;
with SML.UTF8;

package SML.DOM
  with SPARK_Mode => On
is

   --  SML.DOM: Defines the Document Object Model (DOM) tree structure for SML,
   --  a strict subset of XML. Only Element and Text nodes are supported.
   --  All types are opaque to ensure safety and maintain invariants.
   --  The API provides read-only traversal of the DOM tree.

   --  Node_Kind enumerates the two permitted node types in SML
   type Node_Kind is (Element, Text);

   --  Forward declaration of primary DOM types (opaque to users)
   --  INVARIANT: All Document values satisfy Is_Well_Formed
   --  (enforced via contracts)
   type Document is limited private;

   --  Node_Id is a discrete index (defined in private section)
   --  Opaque to users but internally uses SML.Memory_Model.Node_Index
   type Node_Id is private;

   --  A constant representing an invalid or null node reference
   Null_Node : constant Node_Id;

   --  Maximum depth of DOM tree to prevent stack overflow
   Max_Tree_Depth : constant Natural := 1000;

   --  Maximum number of children per element
   Max_Children : constant Natural := 10000;

   ---------------------------------------------------------------------------
   --  DOM Traversal Functions
   ---------------------------------------------------------------------------

   --  Returns the root element node of the given Document
   function Root (Doc : Document) return Node_Id
   with
     Post =>
       (if Root'Result /= Null_Node then Kind (Doc, Root'Result) = Element),
     Global => null;

   --  Returns the parent of a given node
   function Parent (Doc : Document; Node : Node_Id) return Node_Id
   with
     Pre => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
     Post =>
       (if Parent'Result /= Null_Node
        then
          Kind (Doc, Parent'Result) = Element
          and then Has_Child (Doc, Parent'Result, Node)),
     Subprogram_Variant => (Structural => Node),
     Global => null;

   --  Returns the first child of a given Element node
   function First_Child (Doc : Document; Node : Node_Id) return Node_Id
   with
     Pre => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
     Post =>
       (if First_Child'Result /= Null_Node
        then Parent (Doc, First_Child'Result) = Node),
     Subprogram_Variant => (Structural => Node),
     Global => null;

   --  Returns the next sibling of a given node
   function Next_Sibling (Doc : Document; Node : Node_Id) return Node_Id
   with
     Pre => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
     Post =>
       (if Next_Sibling'Result /= Null_Node
        then Parent (Doc, Next_Sibling'Result) = Parent (Doc, Node)),
     Subprogram_Variant => (Structural => Node),
     Global => null;

   --  Returns the number of child nodes of a given Element node
   function Child_Count (Doc : Document; Node : Node_Id) return Natural
   with
     Pre => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
     Post =>
       (if Kind (Doc, Node) = Text then Child_Count'Result = 0
        else Child_Count'Result <= Max_Children),
     Global => null;

   --  Returns the Index-th child of a given Element node (1-based index)
   function Child_At
     (Doc : Document; Node : Node_Id; Index : Positive) return Node_Id
   with
     Pre =>
       Node /= Null_Node
       and then Is_Valid_Node (Doc, Node)
       and then Kind (Doc, Node) = Element
       and then Index <= Child_Count (Doc, Node),
     Post => Parent (Doc, Child_At'Result) = Node,
     Global => null;

   --  Returns the kind of the given node (Element or Text)
   function Kind (Doc : Document; Node : Node_Id) return Node_Kind
   with
     Pre => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
     Global => null;

   --  Returns the tag name of an Element node as a string
   function Name (Doc : Document; Node : Node_Id) return String
   with
     Pre =>
       Node /= Null_Node
       and then Is_Valid_Node (Doc, Node)
       and then Kind (Doc, Node) = Element,
     Post => Name'Result'Length > 0 and then Is_Valid_Name (Name'Result),
     Global => null;

   --  Returns the text content of a Text node
   function Text_Value (Doc : Document; Node : Node_Id) return String
   with
     Pre =>
       Node /= Null_Node
       and then Is_Valid_Node (Doc, Node)
       and then Kind (Doc, Node) = Text,
     Post => SML.UTF8.Is_Valid_UTF8 (Text_Value'Result),
     Global => null;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Formal Verification
   ---------------------------------------------------------------------------
   --  These are implemented in SML.DOM.Proof

   --  Checks if a node belongs to the given document
   function Is_Valid_Node (Doc : Document; Node : Node_Id) return Boolean
     with Ghost, Import, Global => null;

   --  Checks structural well-formedness of a Document's DOM tree
   function Is_Well_Formed (Doc : Document) return Boolean
     with
       Ghost,
       Import,
       Global => null,
       Post =>
         Is_Well_Formed'Result =
           (Has_Single_Root (Doc)
            and then Is_Acyclic (Doc)
            and then Has_Consistent_Parent_Child_Links (Doc)
            and then Has_Valid_Depth (Doc));

   --  Document has exactly one root element
   function Has_Single_Root (Doc : Document) return Boolean
     with Ghost, Import, Global => null;

   --  Document tree contains no cycles
   function Is_Acyclic (Doc : Document) return Boolean
     with Ghost, Import, Global => null;

   --  Parent-child relationships are bidirectional
   function Has_Consistent_Parent_Child_Links (Doc : Document) return Boolean
     with Ghost, Import, Global => null;

   --  All nodes have depth <= Max_Tree_Depth
   function Has_Valid_Depth (Doc : Document) return Boolean
     with Ghost, Import, Global => null;

   --  Checks if a string is a valid element/attribute name
   function Is_Valid_Name (Name : String) return Boolean
     with Ghost, Import, Global => null;

   --  Checks if Parent_Node has Child_Node as a child
   function Has_Child
     (Doc : Document; Parent_Node, Child_Node : Node_Id) return Boolean
     with
       Ghost,
       Import,
       Pre =>
         Parent_Node /= Null_Node
         and then Child_Node /= Null_Node
         and then Is_Valid_Node (Doc, Parent_Node)
         and then Is_Valid_Node (Doc, Child_Node),
       Subprogram_Variant => (Structural => Parent_Node),
       Global => null;

   --  Returns the depth of a node in the tree (root has depth 0)
   function Depth (Doc : Document; Node : Node_Id) return Natural
     with
       Ghost,
       Import,
       Pre => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
       Post => Depth'Result <= Max_Tree_Depth,
       Global => null;

   ---------------------------------------------------------------------------
   --  Memory Management Ghost Functions
   ---------------------------------------------------------------------------

   --  All allocated nodes are reachable from the root
   function All_Nodes_Reachable (Doc : Document) return Boolean
     with Ghost, Import, Global => null;

   --  No unreachable nodes exist in the pool
   function No_Memory_Leaks (Doc : Document) return Boolean
     with Ghost, Import, Global => null;

   --  String storage is managed correctly
   function String_Storage_Valid (Doc : Document) return Boolean
     with Ghost, Import, Global => null;

private
   ---------------------------------------------------------------------------
   --  Internal Representation - Index-Based for SPARK Compatibility
   ---------------------------------------------------------------------------

   --  Node_Id is a discrete index type derived from Memory_Model
   --  (SPARK-compatible). Allows equality, quantified expressions,
   --  and full verification
   type Node_Id is new SML.Memory_Model.Node_Index;

   --  The Null_Node constant (index 0 is reserved as invalid)
   Null_Node : constant Node_Id := Node_Id (SML.Memory_Model.No_Node_Index);

   --  Document structure using arena-based allocation
   --  All nodes stored in fixed-size array pool for bounded memory
   type Document is limited record
      --  Arena pool for node and string storage
      Pool : SML.Memory_Model.Arena_Pool;

      --  Root node index (0 = no root)
      Root_Node : Node_Id := Null_Node;

      --  Ghost field for proof purposes
      Total_Nodes : Natural := 0;
   end record
   with
     Type_Invariant =>
       Pool.Next_Node_Index >= 1
       and then Pool.Next_Node_Index <= SML.Memory_Model.Max_Document_Nodes + 1
       and then Pool.Allocated_Nodes = Pool.Next_Node_Index - 1
       and then Pool.Next_String_Pos >= 1
       and then Pool.Next_String_Pos <= SML.Memory_Model.Max_String_Storage + 1
       and then Pool.Allocated_Bytes <= SML.Memory_Model.Max_String_Storage;

   --  Note: Node type is defined in SML.Memory_Model
   --  Node structure:
   --    - Parent_Index, First_Child_Index, Next_Sibling_Index (Node_Index)
   --    - Element_Name_Ref or Text_Content_Ref (String_Ref)
   --    - Num_Children (Natural, Element only)

end SML.DOM;
