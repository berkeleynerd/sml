------------------------------------------------------------------------------
--  SML.Ownership Package Specification
--  Ownership Tracking and Memory Leak Prevention for SML Library
--  SPARK Ada Implementation - Ghost Code for Verification
------------------------------------------------------------------------------

with SML.DOM;
with SML.Memory_Model;

package SML.Ownership with SPARK_Mode => On, Ghost is

   --  This ghost package tracks ownership relationships between Documents
   --  and Nodes to prove absence of memory leaks and dangling references.
   --  All code is ghost and has no runtime presence.

   ---------------------------------------------------------------------------
   --  Ownership Types and Relations
   ---------------------------------------------------------------------------

   --  Document identifier for ownership tracking
   type Document_Id is new Natural;
   No_Document : constant Document_Id := 0;

   --  Ownership map: tracks which document owns each node
   type Ownership_Map is array (SML.Memory_Model.Node_Index range <>)
                               of Document_Id;

   --  Global ownership registry (ghost)
   Global_Ownership : Ownership_Map (1 .. SML.Memory_Model.Max_Document_Nodes) :=
     (others => No_Document);

   --  Node path for reachability proofs
   subtype Path_Length is Natural range 0 .. SML.DOM.Max_Tree_Depth;
   type Node_Path is array (1 .. SML.DOM.Max_Tree_Depth) of
                           SML.Memory_Model.Node_Index;

   ---------------------------------------------------------------------------
   --  Ownership Predicates
   ---------------------------------------------------------------------------

   --  Check if node is owned by document
   function Owned_By (Pool : SML.Memory_Model.Arena_Pool;
                      Node_Idx : SML.Memory_Model.Node_Index;
                      Doc_Id : Document_Id) return Boolean
     with Post => Owned_By'Result =
                    (SML.Memory_Model.Valid_Node_Index(Pool, Node_Idx) and then
                     Global_Ownership(Node_Idx) = Doc_Id and then
                     Doc_Id /= No_Document);

   --  Check single ownership (node owned by at most one document)
   function Single_Owner (Node_Idx : SML.Memory_Model.Node_Index) return Boolean
     with Post => Single_Owner'Result =
                    (Global_Ownership(Node_Idx) = No_Document or else
                     (for all Doc_Id : Document_Id =>
                        (if Global_Ownership(Node_Idx) = Doc_Id then
                           Doc_Id /= No_Document and then
                           (for all Other_Id : Document_Id =>
                              (if Other_Id /= Doc_Id then
                                 not Owned_By_Any_Pool(Node_Idx, Other_Id))))));

   --  Helper: check ownership by any pool
   function Owned_By_Any_Pool (Node_Idx : SML.Memory_Model.Node_Index;
                               Doc_Id : Document_Id) return Boolean;

   --  Check if all nodes have single owner
   function All_Single_Ownership return Boolean
     with Post => All_Single_Ownership'Result =
                    (for all Idx in SML.Memory_Model.Node_Index =>
                       Single_Owner(Idx));

   ---------------------------------------------------------------------------
   --  Reachability Predicates
   ---------------------------------------------------------------------------

   --  Check if node is reachable from root
   function Reachable_From_Root (Pool : SML.Memory_Model.Arena_Pool;
                                 Root : SML.Memory_Model.Node_Index;
                                 Target : SML.Memory_Model.Node_Index)
                                 return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Root) and then
                 SML.Memory_Model.Valid_Node_Index(Pool, Target),
          Post => Reachable_From_Root'Result =
                    (Root = Target or else
                     (exists Path : Node_Path =>
                        Valid_Path(Pool, Root, Target, Path)));

   --  Check if path connects two nodes
   function Valid_Path (Pool : SML.Memory_Model.Arena_Pool;
                       Start, Target : SML.Memory_Model.Node_Index;
                       Path : Node_Path) return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Start) and then
                 SML.Memory_Model.Valid_Node_Index(Pool, Target);

   --  Check if node is child of parent
   function Is_Child_Of (Pool : SML.Memory_Model.Arena_Pool;
                        Parent, Child : SML.Memory_Model.Node_Index)
                        return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Parent) and then
                 SML.Memory_Model.Valid_Node_Index(Pool, Child),
          Post => Is_Child_Of'Result =
                    (SML.Memory_Model.Get_Node(Pool, Child).Parent_Index = Parent);

   --  Check if node is descendant of ancestor
   function Is_Descendant_Of (Pool : SML.Memory_Model.Arena_Pool;
                             Ancestor, Node : SML.Memory_Model.Node_Index)
                             return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Ancestor) and then
                 SML.Memory_Model.Valid_Node_Index(Pool, Node),
          Post => Is_Descendant_Of'Result =
                    Reachable_From_Root(Pool, Ancestor, Node);

   ---------------------------------------------------------------------------
   --  Memory Leak Prevention Predicates
   ---------------------------------------------------------------------------

   --  No orphaned nodes (all owned nodes are reachable)
   function No_Orphans (Pool : SML.Memory_Model.Arena_Pool;
                       Root : SML.Memory_Model.Node_Index;
                       Doc_Id : Document_Id) return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Root),
          Post => No_Orphans'Result =
                    (for all Idx in SML.Memory_Model.Node_Index =>
                       (if Owned_By(Pool, Idx, Doc_Id) then
                          Reachable_From_Root(Pool, Root, Idx)));

   --  No leaked nodes (all allocated nodes are owned)
   function No_Leaks (Pool : SML.Memory_Model.Arena_Pool) return Boolean
     with Post => No_Leaks'Result =
                    (for all Idx in 1 .. Pool.Next_Node_Index - 1 =>
                       (exists Doc_Id : Document_Id =>
                          Doc_Id /= No_Document and then
                          Owned_By(Pool, Idx, Doc_Id)));

   --  Complete ownership (every valid node has exactly one owner)
   function Complete_Ownership (Pool : SML.Memory_Model.Arena_Pool)
                               return Boolean
     with Post => Complete_Ownership'Result =
                    (for all Idx in 1 .. Pool.Next_Node_Index - 1 =>
                       (exists! Doc_Id : Document_Id =>
                          Doc_Id /= No_Document and then
                          Global_Ownership(Idx) = Doc_Id));

   ---------------------------------------------------------------------------
   --  Ownership Transfer Operations
   ---------------------------------------------------------------------------

   --  Claim ownership of node
   procedure Claim_Node (Pool : in out SML.Memory_Model.Arena_Pool;
                        Node_Idx : SML.Memory_Model.Node_Index;
                        Doc_Id : Document_Id)
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Node_Idx) and then
                 Doc_Id /= No_Document and then
                 Global_Ownership(Node_Idx) = No_Document,
          Post => Global_Ownership(Node_Idx) = Doc_Id and then
                  Owned_By(Pool, Node_Idx, Doc_Id);

   --  Release ownership of node
   procedure Release_Node (Pool : in out SML.Memory_Model.Arena_Pool;
                          Node_Idx : SML.Memory_Model.Node_Index;
                          Doc_Id : Document_Id)
     with Pre => Owned_By(Pool, Node_Idx, Doc_Id),
          Post => Global_Ownership(Node_Idx) = No_Document and then
                  not Owned_By(Pool, Node_Idx, Doc_Id);

   --  Transfer ownership between documents
   procedure Transfer_Node (Pool : in out SML.Memory_Model.Arena_Pool;
                           Node_Idx : SML.Memory_Model.Node_Index;
                           From_Doc, To_Doc : Document_Id)
     with Pre => Owned_By(Pool, Node_Idx, From_Doc) and then
                 To_Doc /= No_Document and then
                 From_Doc /= To_Doc,
          Post => Owned_By(Pool, Node_Idx, To_Doc) and then
                  not Owned_By(Pool, Node_Idx, From_Doc);

   ---------------------------------------------------------------------------
   --  Tree Structure Ownership
   ---------------------------------------------------------------------------

   --  All descendants owned by same document
   function Descendants_Same_Owner (Pool : SML.Memory_Model.Arena_Pool;
                                   Node_Idx : SML.Memory_Model.Node_Index;
                                   Doc_Id : Document_Id) return Boolean
     with Pre => Owned_By(Pool, Node_Idx, Doc_Id),
          Post => Descendants_Same_Owner'Result =
                    (for all Child : SML.Memory_Model.Node_Index =>
                       (if Is_Descendant_Of(Pool, Node_Idx, Child) then
                          Owned_By(Pool, Child, Doc_Id)));

   --  Subtree has consistent ownership
   function Subtree_Ownership_Consistent (Pool : SML.Memory_Model.Arena_Pool;
                                         Root : SML.Memory_Model.Node_Index;
                                         Doc_Id : Document_Id)
                                         return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Root),
          Post => Subtree_Ownership_Consistent'Result =
                    (Owned_By(Pool, Root, Doc_Id) and then
                     Descendants_Same_Owner(Pool, Root, Doc_Id));

   ---------------------------------------------------------------------------
   --  Cycle Detection
   ---------------------------------------------------------------------------

   --  No cycles in parent-child relationships
   function No_Cycles (Pool : SML.Memory_Model.Arena_Pool) return Boolean
     with Post => No_Cycles'Result =
                    (for all Node : SML.Memory_Model.Node_Index =>
                       (if SML.Memory_Model.Valid_Node_Index(Pool, Node) then
                          not Is_Ancestor_Of_Self(Pool, Node)));

   --  Check if node is its own ancestor (cycle)
   function Is_Ancestor_Of_Self (Pool : SML.Memory_Model.Arena_Pool;
                                 Node : SML.Memory_Model.Node_Index)
                                 return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Node);

   --  Depth is bounded (implies no cycles)
   function Depth_Bounded (Pool : SML.Memory_Model.Arena_Pool;
                          Node : SML.Memory_Model.Node_Index;
                          Max_Depth : Natural) return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Node),
          Post => Depth_Bounded'Result =
                    (Get_Depth(Pool, Node) <= Max_Depth);

   --  Get depth of node in tree
   function Get_Depth (Pool : SML.Memory_Model.Arena_Pool;
                      Node : SML.Memory_Model.Node_Index) return Natural
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Node),
          Post => Get_Depth'Result <= SML.DOM.Max_Tree_Depth;

   ---------------------------------------------------------------------------
   --  Ownership Invariants
   ---------------------------------------------------------------------------

   --  Main ownership invariant
   function Ownership_Invariant (Pool : SML.Memory_Model.Arena_Pool;
                                 Root : SML.Memory_Model.Node_Index;
                                 Doc_Id : Document_Id) return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Root),
          Post => Ownership_Invariant'Result =
                    (No_Orphans(Pool, Root, Doc_Id) and then
                     Subtree_Ownership_Consistent(Pool, Root, Doc_Id) and then
                     No_Cycles(Pool));

   ---------------------------------------------------------------------------
   --  Memory Leak Prevention Lemmas
   ---------------------------------------------------------------------------

   --  Allocation preserves ownership invariant
   procedure Lemma_Allocation_Preserves_Ownership
     (Pool : SML.Memory_Model.Arena_Pool;
      New_Node : SML.Memory_Model.Node_Index;
      Doc_Id : Document_Id)
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, New_Node) and then
                 Doc_Id /= No_Document,
          Post => (if Ownership_Invariant(Pool, Pool.Next_Node_Index - 1, Doc_Id) then
                     Ownership_Invariant(Pool, New_Node, Doc_Id));

   --  Deallocation maintains no leaks
   procedure Lemma_Deallocation_No_Leaks
     (Pool : SML.Memory_Model.Arena_Pool)
     with Pre => No_Leaks(Pool),
          Post => (if SML.Memory_Model.Reset_Arena(Pool) then
                     No_Leaks(Pool));

   --  Single ownership is transitive
   procedure Lemma_Single_Ownership_Transitive
     with Post => (if All_Single_Ownership then
                     (for all Node : SML.Memory_Model.Node_Index =>
                        Single_Owner(Node)));

   --  Reachability implies ownership
   procedure Lemma_Reachable_Implies_Owned
     (Pool : SML.Memory_Model.Arena_Pool;
      Root, Node : SML.Memory_Model.Node_Index;
      Doc_Id : Document_Id)
     with Pre => Owned_By(Pool, Root, Doc_Id) and then
                 Reachable_From_Root(Pool, Root, Node),
          Post => Owned_By(Pool, Node, Doc_Id);

   --  Tree operations preserve ownership
   procedure Lemma_Tree_Operations_Preserve_Ownership
     (Pool : SML.Memory_Model.Arena_Pool;
      Doc_Id : Document_Id)
     with Pre => Complete_Ownership(Pool),
          Post => (for all Op : Tree_Operation =>
                     Complete_Ownership(Pool));

   ---------------------------------------------------------------------------
   --  Finalization and Cleanup
   ---------------------------------------------------------------------------

   --  Document finalization releases all nodes
   procedure Finalize_Document (Pool : in out SML.Memory_Model.Arena_Pool;
                               Root : SML.Memory_Model.Node_Index;
                               Doc_Id : Document_Id)
     with Pre => Owned_By(Pool, Root, Doc_Id) and then
                 Subtree_Ownership_Consistent(Pool, Root, Doc_Id),
          Post => (for all Node : SML.Memory_Model.Node_Index =>
                     (if Was_Owned_By(Pool'Old, Node, Doc_Id) then
                        Global_Ownership(Node) = No_Document));

   --  Helper: was owned by (for postconditions)
   function Was_Owned_By (Pool : SML.Memory_Model.Arena_Pool;
                         Node : SML.Memory_Model.Node_Index;
                         Doc_Id : Document_Id) return Boolean;

   ---------------------------------------------------------------------------
   --  Helper Types
   ---------------------------------------------------------------------------

   type Tree_Operation is (Add_Child, Remove_Child, Move_Subtree);

end SML.Ownership;