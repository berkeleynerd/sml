------------------------------------------------------------------------------
--  SML.DOM Enhanced Package Specification
--  Document Object Model with Memory Safety for Simple Markup Language (SML)
--  SPARK Ada Implementation with Bounded Memory and Ownership Tracking
------------------------------------------------------------------------------

with SML.Memory_Model;
with SML.Ownership;
with SML.Memory_Accounting;
with SML.Null_Safety;
with SML.Bounds_Safety;

package SML.DOM_Enhanced with SPARK_Mode => On is

   --  This enhanced DOM package integrates with the memory safety
   --  architecture, using arena-based allocation and ownership tracking
   --  to provide formally verified memory safety guarantees.

   --  Node_Kind enumerates the two permitted node types in SML
   type Node_Kind is (Element, Text);

   --  Forward declaration of primary DOM types (opaque to users)
   type Document is limited private
     with Type_Invariant => Is_Well_Formed (Document) and then
                            Memory_Safe (Document);

   --  Node reference using safe index type
   subtype Node_Id is SML.Memory_Model.Node_Index;

   --  A constant representing an invalid or null node reference
   Null_Node : constant Node_Id := SML.Memory_Model.No_Node_Index;

   --  Maximum depth of DOM tree to prevent stack overflow
   Max_Tree_Depth : constant Natural := 1000;

   --  Maximum number of children per element
   Max_Children : constant Natural := 10000;

   ---------------------------------------------------------------------------
   --  Document Creation and Management
   ---------------------------------------------------------------------------

   --  Create a new empty document with bounded memory
   function Create_Document (Max_Input_Size : Natural) return Document
     with Pre  => Max_Input_Size > 0 and then
                   Max_Input_Size <= SML.Memory_Model.Max_String_Storage / 10,
          Post => Is_Well_Formed (Create_Document'Result) and then
                  Memory_Safe (Create_Document'Result) and then
                  Total_Memory (Create_Document'Result) = 0;

   --  Finalize document, releasing all memory
   procedure Finalize_Document (Doc : in out Document)
     with Post => Total_Memory (Doc) = 0 and then
                  All_Nodes_Released (Doc);

   ---------------------------------------------------------------------------
   --  DOM Traversal Functions with Safety Contracts
   ---------------------------------------------------------------------------

   --  Returns the root element node of the given Document
   function Root (Doc : Document) return Node_Id
     with Post => (if Root'Result /= Null_Node then
                     Kind (Doc, Root'Result) = Element and then
                     SML.Null_Safety.Not_Null (Root'Result) and then
                     SML.Memory_Model.Valid_Node_Index (Doc.Pool, Root'Result)),
          Global => null;

   --  Returns the parent of a given node
   function Parent (Doc : Document; Node : Node_Id) return Node_Id
     with Pre  => SML.Null_Safety.Operation_Null_Safe (
                     SML.Null_Safety.Get_Parent, Node) and then
                   (if Node /= Null_Node then
                      Is_Valid_Node (Doc, Node)),
          Post => (if Parent'Result /= Null_Node then
                     Kind (Doc, Parent'Result) = Element and then
                     Has_Child (Doc, Parent'Result, Node) and then
                     SML.Memory_Model.Valid_Node_Index (Doc.Pool, Parent'Result)),
          Global => null;

   --  Returns the first child of a given Element node
   function First_Child (Doc : Document; Node : Node_Id) return Node_Id
     with Pre  => SML.Null_Safety.Operation_Null_Safe (
                     SML.Null_Safety.Get_First_Child, Node) and then
                   (if Node /= Null_Node then
                      Is_Valid_Node (Doc, Node)),
          Post => (if First_Child'Result /= Null_Node then
                     Parent (Doc, First_Child'Result) = Node and then
                     SML.Memory_Model.Valid_Node_Index (Doc.Pool, First_Child'Result)),
          Global => null;

   --  Returns the next sibling of a given node
   function Next_Sibling (Doc : Document; Node : Node_Id) return Node_Id
     with Pre  => SML.Null_Safety.Operation_Null_Safe (
                     SML.Null_Safety.Get_Next_Sibling, Node) and then
                   (if Node /= Null_Node then
                      Is_Valid_Node (Doc, Node)),
          Post => (if Next_Sibling'Result /= Null_Node then
                     Parent (Doc, Next_Sibling'Result) = Parent (Doc, Node) and then
                     SML.Memory_Model.Valid_Node_Index (Doc.Pool, Next_Sibling'Result)),
          Global => null;

   --  Returns the number of child nodes of a given Element node
   function Child_Count (Doc : Document; Node : Node_Id) return Natural
     with Pre  => Node /= Null_Node and then
                   Is_Valid_Node (Doc, Node) and then
                   SML.Null_Safety.Precondition_Prevents_Null (
                     SML.Null_Safety.Get_Child_Count, Node),
          Post => (if Kind (Doc, Node) = Text then Child_Count'Result = 0
                   else Child_Count'Result <= Max_Children),
          Global => null;

   --  Returns the Index-th child of a given Element node (1-based index)
   function Child_At (Doc : Document; Node : Node_Id; Index : Positive)
                     return Node_Id
     with Pre  => Node /= Null_Node and then
                   Is_Valid_Node (Doc, Node) and then
                   Kind (Doc, Node) = Element and then
                   Index <= Child_Count (Doc, Node) and then
                   SML.Bounds_Safety.Child_Index_Valid (Child_Count (Doc, Node), Index),
          Post => Parent (Doc, Child_At'Result) = Node and then
                  SML.Memory_Model.Valid_Node_Index (Doc.Pool, Child_At'Result),
          Global => null;

   --  Returns the kind of the given node (Element or Text)
   function Kind (Doc : Document; Node : Node_Id) return Node_Kind
     with Pre  => Node /= Null_Node and then
                   Is_Valid_Node (Doc, Node) and then
                   SML.Null_Safety.Precondition_Prevents_Null (
                     SML.Null_Safety.Get_Kind, Node),
          Global => null;

   --  Returns the tag name of an Element node as a string
   function Name (Doc : Document; Node : Node_Id) return String
     with Pre  => Node /= Null_Node and then
                   Is_Valid_Node (Doc, Node) and then
                   Kind (Doc, Node) = Element and then
                   SML.Null_Safety.Precondition_Prevents_Null (
                     SML.Null_Safety.Get_Name, Node),
          Post => Name'Result'Length > 0 and then
                  Name'Result'Length <= SML.Memory_Model.Max_Name_Length and then
                  Is_Valid_Name (Name'Result) and then
                  SML.Bounds_Safety.Name_Length_Safe (Name'Result),
          Global => null;

   --  Returns the text content of a Text node
   function Text_Value (Doc : Document; Node : Node_Id) return String
     with Pre  => Node /= Null_Node and then
                   Is_Valid_Node (Doc, Node) and then
                   Kind (Doc, Node) = Text and then
                   SML.Null_Safety.Precondition_Prevents_Null (
                     SML.Null_Safety.Get_Text, Node),
          Post => Is_Valid_UTF8 (Text_Value'Result) and then
                  Text_Value'Result'Length <= SML.Memory_Model.Max_Text_Length and then
                  SML.Bounds_Safety.Text_Length_Safe (Text_Value'Result),
          Global => null;

   --  Returns the depth of a node in the tree (root has depth 0)
   function Depth (Doc : Document; Node : Node_Id) return Natural
     with Pre  => Node /= Null_Node and then
                   Is_Valid_Node (Doc, Node) and then
                   SML.Null_Safety.Precondition_Prevents_Null (
                     SML.Null_Safety.Get_Depth, Node),
          Post => Depth'Result <= Max_Tree_Depth and then
                  SML.Bounds_Safety.Stack_Depth_Safe (Depth'Result),
          Ghost,
          Global => null;

   ---------------------------------------------------------------------------
   --  Memory Safety Functions
   ---------------------------------------------------------------------------

   --  Get total memory used by document
   function Total_Memory (Doc : Document) return Natural
     with Post => Total_Memory'Result =
                    SML.Memory_Accounting.Total_Memory_Used (Doc.Pool),
          Global => null;

   --  Check if document can allocate more nodes
   function Can_Allocate (Doc : Document; Nodes : Natural) return Boolean
     with Post => Can_Allocate'Result =
                    SML.Memory_Accounting.Can_Allocate_More (Doc.Pool, Nodes),
          Global => null;

   --  Get memory pressure level
   function Memory_Pressure (Doc : Document)
                           return SML.Memory_Accounting.Memory_Pressure
     with Post => Memory_Pressure'Result =
                    SML.Memory_Accounting.Get_Memory_Pressure (Doc.Pool),
          Global => null;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Formal Verification
   ---------------------------------------------------------------------------

   --  Checks if a node belongs to the given document
   function Is_Valid_Node (Doc : Document; Node : Node_Id) return Boolean
     with Ghost,
          Global => null,
          Post => Is_Valid_Node'Result =
                    (SML.Memory_Model.Valid_Node_Index (Doc.Pool, Node) and then
                     SML.Ownership.Owned_By (Doc.Pool, Node, Doc.Doc_Id));

   --  Checks structural well-formedness of a Document's DOM tree
   function Is_Well_Formed (Doc : Document) return Boolean
     with Ghost,
          Global => null,
          Post => Is_Well_Formed'Result =
                    (Has_Single_Root (Doc) and then
                     Is_Acyclic (Doc) and then
                     Has_Consistent_Parent_Child_Links (Doc) and then
                     Has_Valid_Depth (Doc) and then
                     SML.Ownership.No_Cycles (Doc.Pool));

   --  Checks memory safety of document
   function Memory_Safe (Doc : Document) return Boolean
     with Ghost,
          Global => null,
          Post => Memory_Safe'Result =
                    (SML.Ownership.No_Orphans (Doc.Pool, Root (Doc), Doc.Doc_Id) and then
                     SML.Ownership.No_Leaks (Doc.Pool) and then
                     SML.Null_Safety.No_Null_In_Tree (Doc.Pool, Root (Doc)) and then
                     SML.Memory_Accounting.Memory_Bounded_By_Input (
                       Doc.Pool, Doc.Max_Input_Size));

   --  All nodes have been released
   function All_Nodes_Released (Doc : Document) return Boolean
     with Ghost,
          Global => null,
          Post => All_Nodes_Released'Result =
                    (Doc.Pool.Allocated_Nodes = 0);

   --  Document has exactly one root element
   function Has_Single_Root (Doc : Document) return Boolean
     with Ghost,
          Global => null;

   --  Document tree contains no cycles
   function Is_Acyclic (Doc : Document) return Boolean
     with Ghost,
          Global => null,
          Post => Is_Acyclic'Result = SML.Ownership.No_Cycles (Doc.Pool);

   --  All parent-child relationships are bidirectional and consistent
   function Has_Consistent_Parent_Child_Links (Doc : Document) return Boolean
     with Ghost,
          Global => null;

   --  No node exceeds maximum depth
   function Has_Valid_Depth (Doc : Document) return Boolean
     with Ghost,
          Global => null,
          Post => Has_Valid_Depth'Result =
                    (for all N in Node_Id =>
                       (if Is_Valid_Node (Doc, N) then
                          Depth (Doc, N) <= Max_Tree_Depth and then
                          SML.Ownership.Depth_Bounded (Doc.Pool, N, Max_Tree_Depth)));

   --  Checks if Parent_Node has Child_Node as a child
   function Has_Child (Doc : Document; Parent_Node, Child_Node : Node_Id)
                      return Boolean
     with Ghost,
          Pre => Parent_Node /= Null_Node and then Child_Node /= Null_Node
                 and then Is_Valid_Node (Doc, Parent_Node)
                 and then Is_Valid_Node (Doc, Child_Node),
          Global => null,
          Post => Has_Child'Result =
                    SML.Ownership.Is_Child_Of (Doc.Pool, Parent_Node, Child_Node);

   --  Checks if a string is a valid element name
   function Is_Valid_Name (Name : String) return Boolean
     with Ghost,
          Global => null,
          Post => Is_Valid_Name'Result =
                    (Name'Length > 0 and then
                     Name'Length <= SML.Memory_Model.Max_Name_Length and then
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
   --  Memory Management Lemmas
   ---------------------------------------------------------------------------

   --  Allocation preserves memory safety
   procedure Lemma_Allocation_Preserves_Safety (Doc : in out Document;
                                                New_Node : Node_Id)
     with Ghost,
          Pre  => Memory_Safe (Doc) and then
                  SML.Memory_Model.Valid_Node_Index (Doc.Pool, New_Node),
          Post => Memory_Safe (Doc);

   --  Finalization releases all memory
   procedure Lemma_Finalization_Complete (Doc : Document)
     with Ghost,
          Pre  => All_Nodes_Released (Doc),
          Post => Total_Memory (Doc) = 0;

   --  Memory is bounded by input size
   procedure Lemma_Memory_Bounded (Doc : Document)
     with Ghost,
          Post => Total_Memory (Doc) <=
                    SML.Memory_Accounting.Max_Memory_For_Input (Doc.Max_Input_Size);

private
   ---------------------------------------------------------------------------
   --  Internal Representation using Arena Allocation
   ---------------------------------------------------------------------------

   --  Document structure with arena-based memory management
   type Document is limited record
      --  Arena pool for all allocations
      Pool : SML.Memory_Model.Arena_Pool;

      --  Root node index
      Root_Node : Node_Id := Null_Node;

      --  Document ID for ownership tracking
      Doc_Id : SML.Ownership.Document_Id;

      --  Maximum input size for memory bounds
      Max_Input_Size : Natural;

      --  Ghost fields for verification
      Total_Nodes : Natural := 0 with Ghost;
      Finalized : Boolean := False with Ghost;
   end record
     with Predicate =>
       Doc_Id /= SML.Ownership.No_Document and then
       (if Root_Node /= Null_Node then
          SML.Memory_Model.Valid_Node_Index (Pool, Root_Node));

end SML.DOM_Enhanced;