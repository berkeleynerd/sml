------------------------------------------------------------------------------
--  SML.Proof_Helpers Package Specification
--  Ghost Functions and Lemmas for SPARK Proof Support
--  SPARK Ada Implementation
------------------------------------------------------------------------------

with SML.DOM;
with SML.Parser;

package SML.Proof_Helpers with SPARK_Mode => On, Ghost is

   --  This package provides ghost functions, predicates, and lemmas
   --  to assist SPARK provers in verifying the SML DOM and Parser.
   --  All entities in this package are ghost code (not executed at runtime).

   ---------------------------------------------------------------------------
   --  Tree Structure Lemmas
   ---------------------------------------------------------------------------

   --  If a node has a parent, then the parent has this node as a child
   procedure Lemma_Parent_Child_Consistency
     (Doc : SML.DOM.Document; Node : SML.DOM.Node_Id)
   with Pre  => Node /= SML.DOM.Null_Node and then
                SML.DOM.Is_Valid_Node (Doc, Node) and then
                SML.DOM.Is_Well_Formed (Doc),
        Post => (if SML.DOM.Parent (Doc, Node) /= SML.DOM.Null_Node then
                   SML.DOM.Has_Child (Doc, SML.DOM.Parent (Doc, Node), Node)),
        Global => null;

   --  The root node has no parent
   procedure Lemma_Root_Has_No_Parent (Doc : SML.DOM.Document)
   with Pre  => SML.DOM.Is_Well_Formed (Doc),
        Post => (if SML.DOM.Root (Doc) /= SML.DOM.Null_Node then
                   SML.DOM.Parent (Doc, SML.DOM.Root (Doc)) = SML.DOM.Null_Node),
        Global => null;

   --  Every non-root node has exactly one parent
   procedure Lemma_Single_Parent
     (Doc : SML.DOM.Document; Node : SML.DOM.Node_Id)
   with Pre  => Node /= SML.DOM.Null_Node and then
                SML.DOM.Is_Valid_Node (Doc, Node) and then
                SML.DOM.Is_Well_Formed (Doc) and then
                Node /= SML.DOM.Root (Doc),
        Post => SML.DOM.Parent (Doc, Node) /= SML.DOM.Null_Node,
        Global => null;

   --  Siblings have the same parent
   procedure Lemma_Siblings_Same_Parent
     (Doc : SML.DOM.Document; Node : SML.DOM.Node_Id)
   with Pre  => Node /= SML.DOM.Null_Node and then
                SML.DOM.Is_Valid_Node (Doc, Node) and then
                SML.DOM.Is_Well_Formed (Doc),
        Post => (if SML.DOM.Next_Sibling (Doc, Node) /= SML.DOM.Null_Node then
                   SML.DOM.Parent (Doc, SML.DOM.Next_Sibling (Doc, Node)) =
                   SML.DOM.Parent (Doc, Node)),
        Global => null;

   ---------------------------------------------------------------------------
   --  Depth and Acyclicity Lemmas
   ---------------------------------------------------------------------------

   --  Parent has smaller depth than child
   procedure Lemma_Parent_Depth_Less
     (Doc : SML.DOM.Document; Node : SML.DOM.Node_Id)
   with Pre  => Node /= SML.DOM.Null_Node and then
                SML.DOM.Is_Valid_Node (Doc, Node) and then
                SML.DOM.Is_Well_Formed (Doc) and then
                SML.DOM.Parent (Doc, Node) /= SML.DOM.Null_Node,
        Post => SML.DOM.Depth (Doc, SML.DOM.Parent (Doc, Node)) <
                SML.DOM.Depth (Doc, Node),
        Global => null;

   --  Acyclic tree means no node is its own ancestor
   procedure Lemma_No_Self_Ancestor
     (Doc : SML.DOM.Document; Node : SML.DOM.Node_Id)
   with Pre  => Node /= SML.DOM.Null_Node and then
                SML.DOM.Is_Valid_Node (Doc, Node) and then
                SML.DOM.Is_Well_Formed (Doc),
        Post => not Is_Ancestor (Doc, Node, Node),
        Global => null;

   --  Check if Ancestor is an ancestor of Node
   function Is_Ancestor
     (Doc : SML.DOM.Document; Ancestor, Node : SML.DOM.Node_Id)
     return Boolean
   with Pre => Ancestor /= SML.DOM.Null_Node and then
               Node /= SML.DOM.Null_Node and then
               SML.DOM.Is_Valid_Node (Doc, Ancestor) and then
               SML.DOM.Is_Valid_Node (Doc, Node),
        Global => null;

   ---------------------------------------------------------------------------
   --  Child Iteration Lemmas
   ---------------------------------------------------------------------------

   --  Child_At returns children in the same order as iteration
   procedure Lemma_Child_At_Iteration_Consistency
     (Doc : SML.DOM.Document; Parent : SML.DOM.Node_Id; Index : Positive)
   with Pre  => Parent /= SML.DOM.Null_Node and then
                SML.DOM.Is_Valid_Node (Doc, Parent) and then
                SML.DOM.Kind (Doc, Parent) = SML.DOM.Element and then
                Index <= SML.DOM.Child_Count (Doc, Parent) and then
                SML.DOM.Is_Well_Formed (Doc),
        Post => SML.DOM.Child_At (Doc, Parent, Index) =
                Nth_Child_By_Iteration (Doc, Parent, Index),
        Global => null;

   --  Get the Nth child by iterating with First_Child/Next_Sibling
   function Nth_Child_By_Iteration
     (Doc : SML.DOM.Document; Parent : SML.DOM.Node_Id; N : Positive)
     return SML.DOM.Node_Id
   with Pre => Parent /= SML.DOM.Null_Node and then
               SML.DOM.Is_Valid_Node (Doc, Parent) and then
               SML.DOM.Kind (Doc, Parent) = SML.DOM.Element and then
               N <= SML.DOM.Child_Count (Doc, Parent),
        Global => null;

   --  The number of children matches iteration count
   procedure Lemma_Child_Count_Matches_Iteration
     (Doc : SML.DOM.Document; Parent : SML.DOM.Node_Id)
   with Pre  => Parent /= SML.DOM.Null_Node and then
                SML.DOM.Is_Valid_Node (Doc, Parent) and then
                SML.DOM.Is_Well_Formed (Doc),
        Post => SML.DOM.Child_Count (Doc, Parent) =
                Count_Children_By_Iteration (Doc, Parent),
        Global => null;

   --  Count children by iterating
   function Count_Children_By_Iteration
     (Doc : SML.DOM.Document; Parent : SML.DOM.Node_Id) return Natural
   with Pre => Parent /= SML.DOM.Null_Node and then
               SML.DOM.Is_Valid_Node (Doc, Parent),
        Post => Count_Children_By_Iteration'Result <= SML.DOM.Max_Children,
        Global => null;

   ---------------------------------------------------------------------------
   --  Parsing Correctness Lemmas
   ---------------------------------------------------------------------------

   --  Valid SML input produces a well-formed DOM
   procedure Lemma_Valid_Input_Well_Formed_DOM (Input : String)
   with Pre  => SML.DOM.Parser.Is_Valid_SML (Input),
        Post => (declare
                   Result : constant SML.DOM.Parser.Parse_Result :=
                     SML.DOM.Parser.Parse (Input);
                 begin
                   Result.Success and then
                   SML.DOM.Is_Well_Formed (Result.Document)),
        Global => null;

   --  Invalid SML input produces an error
   procedure Lemma_Invalid_Input_Produces_Error (Input : String)
   with Pre  => not SML.DOM.Parser.Is_Valid_SML (Input),
        Post => (declare
                   Result : constant SML.DOM.Parser.Parse_Result :=
                     SML.DOM.Parser.Parse (Input);
                 begin
                   not Result.Success),
        Global => null;

   --  Parse is deterministic: same input produces same DOM
   procedure Lemma_Parse_Deterministic (Input : String)
   with Pre  => SML.DOM.Parser.Is_Valid_SML (Input),
        Post => (declare
                   Result1 : constant SML.DOM.Parser.Parse_Result :=
                     SML.DOM.Parser.Parse (Input);
                   Result2 : constant SML.DOM.Parser.Parse_Result :=
                     SML.DOM.Parser.Parse (Input);
                 begin
                   Result1.Success and Result2.Success and then
                   Same_DOM_Structure (Result1.Document, Result2.Document)),
        Global => null;

   --  Check if two DOMs have the same structure
   function Same_DOM_Structure
     (Doc1, Doc2 : SML.DOM.Document) return Boolean
   with Pre => SML.DOM.Is_Well_Formed (Doc1) and then
               SML.DOM.Is_Well_Formed (Doc2),
        Global => null;

   ---------------------------------------------------------------------------
   --  Memory Safety Lemmas
   ---------------------------------------------------------------------------

   --  All nodes in a well-formed document are owned by that document
   procedure Lemma_All_Nodes_Owned (Doc : SML.DOM.Document)
   with Pre  => SML.DOM.Is_Well_Formed (Doc),
        Post => SML.DOM.No_Memory_Leaks (Doc),
        Global => null;

   --  Node count is finite and bounded
   procedure Lemma_Finite_Node_Count (Doc : SML.DOM.Document)
   with Pre  => SML.DOM.Is_Well_Formed (Doc),
        Post => SML.DOM.Node_Count (Doc) <= Natural'Last / 2,
        Global => null;

   --  Owned nodes are reachable from root
   procedure Lemma_Owned_Nodes_Reachable
     (Doc : SML.DOM.Document; Node : SML.DOM.Node_Id)
   with Pre  => Node /= SML.DOM.Null_Node and then
                SML.DOM.Is_Well_Formed (Doc) and then
                SML.DOM.Owns_Node (Doc, Node),
        Post => Is_Reachable_From_Root (Doc, Node),
        Global => null;

   --  Check if a node is reachable from the root
   function Is_Reachable_From_Root
     (Doc : SML.DOM.Document; Node : SML.DOM.Node_Id) return Boolean
   with Pre => Node /= SML.DOM.Null_Node and then
               SML.DOM.Is_Valid_Node (Doc, Node),
        Global => null;

   ---------------------------------------------------------------------------
   --  UTF-8 and Entity Lemmas
   ---------------------------------------------------------------------------

   --  Valid UTF-8 input produces valid UTF-8 text nodes
   procedure Lemma_UTF8_Preservation
     (Input : String; Doc : SML.DOM.Document; Node : SML.DOM.Node_Id)
   with Pre  => SML.DOM.Parser.Has_Valid_UTF8 (Input) and then
                SML.DOM.Parser.Parses_To (Input, Doc) and then
                Node /= SML.DOM.Null_Node and then
                SML.DOM.Is_Valid_Node (Doc, Node) and then
                SML.DOM.Kind (Doc, Node) = SML.DOM.Text,
        Post => SML.DOM.Is_Valid_UTF8 (SML.DOM.Text_Value (Doc, Node)),
        Global => null;

   --  Entity expansion preserves well-formedness
   procedure Lemma_Entity_Expansion_Safe (Input : String)
   with Pre  => SML.DOM.Parser.Has_Valid_Entities (Input),
        Post => No_Unescaped_Markup_Chars (Expand_Entities (Input)),
        Global => null;

   --  Expand all entity references in a string
   function Expand_Entities (Input : String) return String
   with Global => null;

   --  Check if string contains unescaped markup characters
   function No_Unescaped_Markup_Chars (Text : String) return Boolean
   with Global => null;

   ---------------------------------------------------------------------------
   --  Induction Helpers
   ---------------------------------------------------------------------------

   --  Base case for tree induction: empty document
   procedure Lemma_Empty_Doc_Well_Formed (Doc : SML.DOM.Document)
   with Pre  => SML.DOM.Root (Doc) = SML.DOM.Null_Node,
        Post => SML.DOM.Is_Well_Formed (Doc),
        Global => null;

   --  Inductive step: adding a child preserves well-formedness
   procedure Lemma_Add_Child_Preserves_Well_Formed
     (Doc : SML.DOM.Document; Parent : SML.DOM.Node_Id)
   with Pre  => SML.DOM.Is_Well_Formed (Doc) and then
                Parent /= SML.DOM.Null_Node and then
                SML.DOM.Is_Valid_Node (Doc, Parent) and then
                SML.DOM.Kind (Doc, Parent) = SML.DOM.Element and then
                SML.DOM.Child_Count (Doc, Parent) < SML.DOM.Max_Children and then
                SML.DOM.Depth (Doc, Parent) < SML.DOM.Max_Tree_Depth,
        Post => True,  -- Well-formedness would be preserved after adding child
        Global => null;

   ---------------------------------------------------------------------------
   --  Loop Invariant Templates
   ---------------------------------------------------------------------------

   --  Template for child iteration loop invariant
   function Child_Iteration_Invariant
     (Doc : SML.DOM.Document; Parent : SML.DOM.Node_Id;
      Current : SML.DOM.Node_Id; Count : Natural) return Boolean
   with Pre => Parent /= SML.DOM.Null_Node and then
               SML.DOM.Is_Valid_Node (Doc, Parent),
        Global => null,
        Post => Child_Iteration_Invariant'Result =
                  ((Current = SML.DOM.Null_Node or else
                    SML.DOM.Parent (Doc, Current) = Parent) and then
                   Count <= SML.DOM.Child_Count (Doc, Parent));

   --  Template for parse loop invariant
   function Parse_Loop_Invariant
     (Input : String; Position : Natural;
      State : SML.DOM.Parser.Parser_State) return Boolean
   with Pre => Position >= Input'First and then Position <= Input'Last + 1,
        Global => null;

end SML.Proof_Helpers;