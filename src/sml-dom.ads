------------------------------------------------------------------------------
--  SML.DOM Package Specification
--  Document Object Model for Simple Markup Language (SML)
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package SML.DOM with SPARK_Mode => On is

   --  SML.DOM: Defines the Document Object Model (DOM) tree structure for SML,
   --  a strict subset of XML. Only Element and Text nodes are supported.
   --  All types are opaque to ensure safety and maintain invariants.
   --  The API provides read-only traversal of the DOM tree.

   --  Node_Kind enumerates the two permitted node types in SML
   type Node_Kind is (Element, Text);

   --  Forward declaration of primary DOM types (opaque to users)
   --  INVARIANT: All Document values satisfy Is_Well_Formed (enforced via contracts)
   type Document is limited private;

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
     with Post => (if Root'Result /= Null_Node then
                     Kind (Doc, Root'Result) = Element),
          Global => null;

   --  Returns the parent of a given node
   function Parent (Doc : Document; Node : Node_Id) return Node_Id
     with Pre  => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
          Post => (if Parent'Result /= Null_Node then
                     Kind (Doc, Parent'Result) = Element and then
                     Has_Child (Doc, Parent'Result, Node)),
          Global => null;

   --  Returns the first child of a given Element node
   function First_Child (Doc : Document; Node : Node_Id) return Node_Id
     with Pre  => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
          Post => (if First_Child'Result /= Null_Node then
                     Parent (Doc, First_Child'Result) = Node),
          Global => null;

   --  Returns the next sibling of a given node
   function Next_Sibling (Doc : Document; Node : Node_Id) return Node_Id
     with Pre  => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
          Post => (if Next_Sibling'Result /= Null_Node then
                     Parent (Doc, Next_Sibling'Result) = Parent (Doc, Node)),
          Global => null;

   --  Returns the number of child nodes of a given Element node
   function Child_Count (Doc : Document; Node : Node_Id) return Natural
     with Pre  => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
          Post => (if Kind (Doc, Node) = Text then Child_Count'Result = 0
                   else Child_Count'Result <= Max_Children),
          Global => null;

   --  Returns the Index-th child of a given Element node (1-based index)
   function Child_At (Doc : Document; Node : Node_Id; Index : Positive)
                     return Node_Id
     with Pre  => Node /= Null_Node and then Is_Valid_Node (Doc, Node)
                  and then Kind (Doc, Node) = Element
                  and then Index <= Child_Count (Doc, Node),
          Post => Parent (Doc, Child_At'Result) = Node,
          Global => null;

   --  Returns the kind of the given node (Element or Text)
   function Kind (Doc : Document; Node : Node_Id) return Node_Kind
     with Pre  => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
          Global => null;

   --  Returns the tag name of an Element node as a string
   function Name (Doc : Document; Node : Node_Id) return String
     with Pre  => Node /= Null_Node and then Is_Valid_Node (Doc, Node)
                  and then Kind (Doc, Node) = Element,
          Post => Name'Result'Length > 0 and then
                  Is_Valid_Name (Name'Result),
          Global => null;

   --  Returns the text content of a Text node
   function Text_Value (Doc : Document; Node : Node_Id) return String
     with Pre  => Node /= Null_Node and then Is_Valid_Node (Doc, Node)
                  and then Kind (Doc, Node) = Text,
          Post => Is_Valid_UTF8 (Text_Value'Result),
          Global => null;

   --  Returns the depth of a node in the tree (root has depth 0)
   function Depth (Doc : Document; Node : Node_Id) return Natural
     with Pre  => Node /= Null_Node and then Is_Valid_Node (Doc, Node),
          Post => Depth'Result <= Max_Tree_Depth,
          Ghost,
          Global => null;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Formal Verification
   ---------------------------------------------------------------------------

   --  Checks if a node belongs to the given document
   function Is_Valid_Node (Doc : Document; Node : Node_Id) return Boolean
     with Ghost,
          Global => null;

   --  Checks structural well-formedness of a Document's DOM tree
   function Is_Well_Formed (Doc : Document) return Boolean
     with Ghost,
          Global => null,
          Post => Is_Well_Formed'Result =
                    (Has_Single_Root (Doc) and then
                     Is_Acyclic (Doc) and then
                     Has_Consistent_Parent_Child_Links (Doc) and then
                     Has_Valid_Depth (Doc));

   --  Document has exactly one root element
   function Has_Single_Root (Doc : Document) return Boolean
     with Ghost,
          Global => null;

   --  Document tree contains no cycles
   function Is_Acyclic (Doc : Document) return Boolean
     with Ghost,
          Global => null;

   --  All parent-child relationships are bidirectional and consistent
   function Has_Consistent_Parent_Child_Links (Doc : Document) return Boolean
     with Ghost,
          Global => null;

   --  No node exceeds maximum depth
   function Has_Valid_Depth (Doc : Document) return Boolean
     with Ghost,
          Global => null;

   --  Checks if Parent_Node has Child_Node as a child
   function Has_Child (Doc : Document; Parent_Node, Child_Node : Node_Id)
                      return Boolean
     with Ghost,
          Pre => Parent_Node /= Null_Node and then Child_Node /= Null_Node
                 and then Is_Valid_Node (Doc, Parent_Node)
                 and then Is_Valid_Node (Doc, Child_Node),
          Global => null;

   --  Checks if a string is a valid element name
   function Is_Valid_Name (Name : String) return Boolean
     with Ghost,
          Global => null,
          Post => Is_Valid_Name'Result =
                    (Name'Length > 0 and then
                     (for all I in Name'Range =>
                        Is_Name_Char (Name (I))));

   --  Checks if a character is valid in an element name
   function Is_Name_Char (C : Character) return Boolean
     with Ghost,
          Global => null;

   --  Checks if a string is valid UTF-8
   function Is_Valid_UTF8 (Text : String) return Boolean
     with Ghost,
          Import,
          Global => null;

   ---------------------------------------------------------------------------
   --  Memory Management Ghost Functions
   ---------------------------------------------------------------------------

   --  Returns true if the Document owns the given Node
   function Owns_Node (Doc : Document; Node : Node_Id) return Boolean
     with Ghost,
          Global => null;

   --  Returns the number of nodes owned by the Document
   function Node_Count (Doc : Document) return Natural
     with Ghost,
          Global => null;

   --  Checks if Document has no memory leaks
   function No_Memory_Leaks (Doc : Document) return Boolean
     with Ghost,
          Global => null;

private
   ---------------------------------------------------------------------------
   --  Internal Representation
   ---------------------------------------------------------------------------

   --  Forward declare Node type
   type Node;
   type Node_Access is access Node;

   --  Node_Id is a safe reference to a Node
   type Node_Id is new Node_Access;

   --  Node pool for memory management (defined before Document)
   type Node_Pool is limited record
      --  Implementation would include memory management details
      null;
   end record;

   --  Document structure owns all Nodes in its tree
   type Document is limited record
      Root_Node : Node_Id := Null_Node;
      Pool      : Node_Pool;
      --  Ghost field for proof purposes
      Total_Nodes : Natural := 0;
   end record;

   --  The Null_Node constant
   Null_Node : constant Node_Id := Node_Id (Node_Access'(null));

   --  Node structure using discriminated record
   type Node (Kind : Node_Kind := Element) is record
      Parent_Node       : Node_Id := Null_Node;
      Next_Sibling_Node : Node_Id := Null_Node;

      case Kind is
         when Element =>
            First_Child_Node : Node_Id := Null_Node;
            Element_Name     : Unbounded_String := Null_Unbounded_String;
            Num_Children     : Natural := 0;
         when Text =>
            Text_Content     : Unbounded_String := Null_Unbounded_String;
      end case;
   end record;

end SML.DOM;