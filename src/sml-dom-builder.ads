------------------------------------------------------------------------------
--  SML.DOM.Builder Package Specification
--  DOM Construction and Mutation for Simple Markup Language (SML)
--  SPARK Ada Implementation with Formal Verification Support
--  Child Package with Privileged Access to DOM Internals
------------------------------------------------------------------------------

package SML.DOM.Builder
  with SPARK_Mode => On
is

   --  SML.DOM.Builder: Provides programmatic DOM construction and mutation.
   --  Supports adding elements/text and logical deletion (tombstone pattern).
   --  Memory is allocated from bounded arena pools for SPARK compatibility.

   ---------------------------------------------------------------------------
   --  Document Creation
   ---------------------------------------------------------------------------

   --  Create a new document with specified root element name
   function Create_Document (Root_Name : String) return Document
   with
     Pre =>
       Root_Name'Length > 0
       and then Root_Name'Length <= 100
       and then Is_Valid_Name (Root_Name),
     Post =>
       Is_Well_Formed (Create_Document'Result)
       and then Root (Create_Document'Result) /= Null_Node
       and then Name (Create_Document'Result,
                      Root (Create_Document'Result)) = Root_Name,
     Global => null;

   ---------------------------------------------------------------------------
   --  DOM Mutation Operations
   ---------------------------------------------------------------------------

   --  Add a child element to a parent element
   procedure Add_Child_Element
     (Doc       : in out Document;
      Parent    : Node_Id;
      Name      : String;
      New_Child : out Node_Id)
   with
     Pre =>
       Is_Well_Formed (Doc)
       and then Parent /= Null_Node
       and then Is_Valid_Node (Doc, Parent)
       and then Kind (Doc, Parent) = Element
       and then Not_Deleted (Doc, Parent)
       and then Is_Valid_Name (Name)
       and then Name'Length > 0
       and then Name'Length <= 100
       and then Child_Count (Doc, Parent) < Max_Children,
     Post =>
       Is_Well_Formed (Doc)
       and then New_Child /= Null_Node
       and then Is_Valid_Node (Doc, New_Child)
       and then Kind (Doc, New_Child) = Element
       and then SML.DOM.Parent (Doc, New_Child) = Parent
       and then Not_Deleted (Doc, New_Child);

   --  Add a text node to a parent element
   procedure Add_Text_Node
     (Doc      : in out Document;
      Parent   : Node_Id;
      Text     : String;
      New_Text : out Node_Id)
   with
     Pre =>
       Is_Well_Formed (Doc)
       and then Parent /= Null_Node
       and then Is_Valid_Node (Doc, Parent)
       and then Kind (Doc, Parent) = Element
       and then Not_Deleted (Doc, Parent)
       and then Text'Length <= 10_000
       and then Child_Count (Doc, Parent) < Max_Children,
     Post =>
       Is_Well_Formed (Doc)
       and then New_Text /= Null_Node
       and then Is_Valid_Node (Doc, New_Text)
       and then Kind (Doc, New_Text) = Text
       and then Not_Deleted (Doc, New_Text);

   ---------------------------------------------------------------------------
   --  Deletion Operations
   ---------------------------------------------------------------------------

   --  Mark a node and all its descendants as deleted (logical deletion)
   --  Node storage is not reclaimed until document is compacted
   procedure Delete_Node (Doc : in out Document; Node : Node_Id)
   with
     Pre =>
       Is_Well_Formed (Doc)
       and then Node /= Null_Node
       and then Is_Valid_Node (Doc, Node)
       and then Node /= Root (Doc),  -- Cannot delete root
     Post =>
       Is_Well_Formed (Doc)
       and then Not_Deleted (Doc, Root (Doc));  -- Root never deleted

   --  Check if a node is not deleted
   function Not_Deleted (Doc : Document; Node : Node_Id) return Boolean
   with
     Pre => Is_Valid_Node (Doc, Node),
     Global => null;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Verification
   ---------------------------------------------------------------------------

   --  Check if document has any deleted nodes
   function Has_Deleted_Nodes (Doc : Document) return Boolean
   with Ghost, Global => null;

   --  Check if all nodes in document are not deleted
   function No_Deleted_Nodes (Doc : Document) return Boolean
   with
     Ghost,
     Global => null,
     Post => No_Deleted_Nodes'Result = not Has_Deleted_Nodes (Doc);

end SML.DOM.Builder;
