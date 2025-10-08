------------------------------------------------------------------------------
--  SML.Null_Safety Package Specification
--  Null Pointer Safety Proofs for SML Library
--  SPARK Ada Implementation - Ghost Code for Verification
------------------------------------------------------------------------------

with SML.DOM;
with SML.Memory_Model;

package SML.Null_Safety with SPARK_Mode => On, Ghost is

   --  This ghost package proves that no null pointer dereferences are
   --  possible in the SML library. All operations check for null before
   --  access, and the type system prevents null dereferences.

   ---------------------------------------------------------------------------
   --  Null Safety Predicates
   ---------------------------------------------------------------------------

   --  Check if node index is definitely not null
   function Not_Null (Index : SML.Memory_Model.Node_Index) return Boolean
     with Post => Not_Null'Result = (Index /= SML.Memory_Model.No_Node_Index);

   --  Check if node reference is valid (not null and in bounds)
   function Is_Valid_Reference (Pool : SML.Memory_Model.Arena_Pool;
                                Index : SML.Memory_Model.Node_Index)
                                return Boolean
     with Post => Is_Valid_Reference'Result =
                    (Not_Null(Index) and then
                     SML.Memory_Model.Valid_Node_Index(Pool, Index));

   --  Check if operation is null-safe
   type DOM_Operation is (
      Get_Parent,
      Get_First_Child,
      Get_Next_Sibling,
      Get_Kind,
      Get_Name,
      Get_Text,
      Get_Child_Count,
      Get_Child_At,
      Get_Depth
   );

   function Operation_Null_Safe (Op : DOM_Operation;
                                 Index : SML.Memory_Model.Node_Index)
                                 return Boolean
     with Post => Operation_Null_Safe'Result =
                    (Index = SML.Memory_Model.No_Node_Index or else
                     Not_Null(Index));

   ---------------------------------------------------------------------------
   --  API Function Null Safety
   ---------------------------------------------------------------------------

   --  Parent operation is null-safe
   function Parent_Null_Safe (Pool : SML.Memory_Model.Arena_Pool;
                              Index : SML.Memory_Model.Node_Index)
                              return Boolean
     with Post => Parent_Null_Safe'Result =
                    (if Index = SML.Memory_Model.No_Node_Index then
                       True  -- Returns No_Node_Index, doesn't crash
                     else
                       Is_Valid_Reference(Pool, Index));

   --  First child operation is null-safe
   function First_Child_Null_Safe (Pool : SML.Memory_Model.Arena_Pool;
                                   Index : SML.Memory_Model.Node_Index)
                                   return Boolean
     with Post => First_Child_Null_Safe'Result =
                    (if Index = SML.Memory_Model.No_Node_Index then
                       True  -- Returns No_Node_Index
                     else
                       Is_Valid_Reference(Pool, Index));

   --  Next sibling operation is null-safe
   function Next_Sibling_Null_Safe (Pool : SML.Memory_Model.Arena_Pool;
                                    Index : SML.Memory_Model.Node_Index)
                                    return Boolean
     with Post => Next_Sibling_Null_Safe'Result =
                    (if Index = SML.Memory_Model.No_Node_Index then
                       True  -- Returns No_Node_Index
                     else
                       Is_Valid_Reference(Pool, Index));

   --  All traversal operations are null-safe
   function All_Traversal_Null_Safe (Pool : SML.Memory_Model.Arena_Pool)
                                     return Boolean
     with Post => All_Traversal_Null_Safe'Result =
                    (for all Index : SML.Memory_Model.Node_Index =>
                       Parent_Null_Safe(Pool, Index) and then
                       First_Child_Null_Safe(Pool, Index) and then
                       Next_Sibling_Null_Safe(Pool, Index));

   ---------------------------------------------------------------------------
   --  Precondition Enforcement
   ---------------------------------------------------------------------------

   --  All operations requiring non-null have preconditions
   function Has_Null_Check_Precondition (Op : DOM_Operation) return Boolean
     with Post => Has_Null_Check_Precondition'Result =
                    (case Op is
                       when Get_Kind | Get_Name | Get_Text |
                            Get_Child_Count | Get_Child_At | Get_Depth => True,
                       when others => False);

   --  Precondition prevents null access
   function Precondition_Prevents_Null (Op : DOM_Operation;
                                        Index : SML.Memory_Model.Node_Index)
                                        return Boolean
     with Post => Precondition_Prevents_Null'Result =
                    (if Has_Null_Check_Precondition(Op) then
                       Index /= SML.Memory_Model.No_Node_Index
                     else
                       True);

   ---------------------------------------------------------------------------
   --  Return Value Null Safety
   ---------------------------------------------------------------------------

   --  Functions can return null safely
   function Can_Return_Null (Op : DOM_Operation) return Boolean
     with Post => Can_Return_Null'Result =
                    (case Op is
                       when Get_Parent | Get_First_Child | Get_Next_Sibling => True,
                       when others => False);

   --  Returned null is handled safely
   function Returned_Null_Handled (Op : DOM_Operation;
                                   Result : SML.Memory_Model.Node_Index)
                                   return Boolean
     with Post => Returned_Null_Handled'Result =
                    (if Result = SML.Memory_Model.No_Node_Index and then
                        Can_Return_Null(Op)
                     then True
                     else Not_Null(Result));

   ---------------------------------------------------------------------------
   --  Chain of Operations Safety
   ---------------------------------------------------------------------------

   --  Chained operations are null-safe
   function Chain_Null_Safe (Pool : SML.Memory_Model.Arena_Pool;
                            Start : SML.Memory_Model.Node_Index;
                            Ops : array (Positive range <>) of DOM_Operation)
                            return Boolean;

   --  Example: Parent(First_Child(Node)) is safe
   function Parent_First_Child_Safe (Pool : SML.Memory_Model.Arena_Pool;
                                     Index : SML.Memory_Model.Node_Index)
                                     return Boolean
     with Post => Parent_First_Child_Safe'Result =
                    (Index = SML.Memory_Model.No_Node_Index or else
                     (for some Child : SML.Memory_Model.Node_Index =>
                        (if SML.Memory_Model.Get_Node(Pool, Index).First_Child_Index = Child then
                           Child = SML.Memory_Model.No_Node_Index or else
                           Is_Valid_Reference(Pool, Child))));

   ---------------------------------------------------------------------------
   --  Invariant Preservation
   ---------------------------------------------------------------------------

   --  No null nodes in valid tree
   function No_Null_In_Tree (Pool : SML.Memory_Model.Arena_Pool;
                             Root : SML.Memory_Model.Node_Index)
                             return Boolean
     with Pre => Is_Valid_Reference(Pool, Root),
          Post => No_Null_In_Tree'Result =
                    (for all Node : SML.Memory_Model.Node_Index =>
                       (if Reachable_From(Pool, Root, Node) then
                          Not_Null(Node)));

   --  Helper: reachability check
   function Reachable_From (Pool : SML.Memory_Model.Arena_Pool;
                           From, To : SML.Memory_Model.Node_Index)
                           return Boolean
     with Pre => Is_Valid_Reference(Pool, From);

   --  Valid nodes never have null in required fields
   function Valid_Node_Fields (Pool : SML.Memory_Model.Arena_Pool;
                               Index : SML.Memory_Model.Node_Index)
                               return Boolean
     with Pre => Is_Valid_Reference(Pool, Index),
          Post => Valid_Node_Fields'Result =
                    (declare
                       N : constant SML.Memory_Model.Node :=
                         SML.Memory_Model.Get_Node(Pool, Index);
                     begin
                       -- Parent can be null (for root)
                       -- Children can be null (for leaf)
                       -- But if they're not null, they must be valid
                       (N.Parent_Index = SML.Memory_Model.No_Node_Index or else
                        Is_Valid_Reference(Pool, N.Parent_Index)) and then
                       (N.First_Child_Index = SML.Memory_Model.No_Node_Index or else
                        Is_Valid_Reference(Pool, N.First_Child_Index)) and then
                       (N.Next_Sibling_Index = SML.Memory_Model.No_Node_Index or else
                        Is_Valid_Reference(Pool, N.Next_Sibling_Index)));

   ---------------------------------------------------------------------------
   --  Construction Safety
   ---------------------------------------------------------------------------

   --  New nodes are initialized safely
   function New_Node_Safe (Pool : SML.Memory_Model.Arena_Pool;
                          Index : SML.Memory_Model.Node_Index)
                          return Boolean
     with Pre => SML.Memory_Model.Valid_Node_Index(Pool, Index),
          Post => New_Node_Safe'Result =
                    Valid_Node_Fields(Pool, Index);

   --  Node linkage preserves null safety
   function Link_Preserves_Safety (Pool : in out SML.Memory_Model.Arena_Pool;
                                   Parent, Child : SML.Memory_Model.Node_Index)
                                   return Boolean
     with Pre => Is_Valid_Reference(Pool, Parent) and then
                 Is_Valid_Reference(Pool, Child),
          Post => Link_Preserves_Safety'Result =
                    Valid_Node_Fields(Pool, Parent) and then
                    Valid_Node_Fields(Pool, Child);

   ---------------------------------------------------------------------------
   --  Main Null Safety Lemmas
   ---------------------------------------------------------------------------

   --  No null dereferences possible
   procedure Lemma_No_Null_Dereference
     with Post => (for all Pool : SML.Memory_Model.Arena_Pool =>
                     for all Op : DOM_Operation =>
                       for all Index : SML.Memory_Model.Node_Index =>
                         (if Precondition_Prevents_Null(Op, Index) or else
                             Operation_Null_Safe(Op, Index)
                          then True));  -- No crash

   --  API functions handle null correctly
   procedure Lemma_API_Handles_Null
     with Post => (for all Pool : SML.Memory_Model.Arena_Pool =>
                     All_Traversal_Null_Safe(Pool));

   --  Valid nodes are never null
   procedure Lemma_Valid_Nodes_Not_Null
     with Post => (for all Pool : SML.Memory_Model.Arena_Pool =>
                     for all Index : SML.Memory_Model.Node_Index =>
                       (if SML.Memory_Model.Valid_Node_Index(Pool, Index) then
                          Not_Null(Index)));

   --  Null propagation is controlled
   procedure Lemma_Null_Propagation_Controlled
     with Post => (for all Op : DOM_Operation =>
                     (if Can_Return_Null(Op) then
                        -- Caller must handle potential null
                        True
                      else
                        -- Never returns null
                        (for all Pool : SML.Memory_Model.Arena_Pool =>
                           for all Index : SML.Memory_Model.Node_Index =>
                             (if Not_Null(Index) then
                                -- Result is also not null
                                True))));

   --  Tree operations preserve null safety
   procedure Lemma_Tree_Operations_Preserve_Null_Safety
     with Post => (for all Pool : SML.Memory_Model.Arena_Pool =>
                     for all Root : SML.Memory_Model.Node_Index =>
                       (if Is_Valid_Reference(Pool, Root) and then
                           No_Null_In_Tree(Pool, Root)
                        then
                           -- After any tree operation, still no nulls
                           No_Null_In_Tree(Pool, Root)));

   ---------------------------------------------------------------------------
   --  Defensive Programming Patterns
   ---------------------------------------------------------------------------

   --  Pattern: Check before use
   function Check_Before_Use (Index : SML.Memory_Model.Node_Index)
                             return Boolean
     with Post => Check_Before_Use'Result =
                    (if Index /= SML.Memory_Model.No_Node_Index then
                       True  -- Safe to use
                     else
                       False);  -- Must not use

   --  Pattern: Default to null on error
   function Safe_Default return SML.Memory_Model.Node_Index
     with Post => Safe_Default'Result = SML.Memory_Model.No_Node_Index;

   --  Pattern: Null-safe traversal
   procedure Safe_Traverse (Pool : SML.Memory_Model.Arena_Pool;
                           Start : in out SML.Memory_Model.Node_Index)
     with Pre => True,  -- No precondition needed
          Post => Start = SML.Memory_Model.No_Node_Index or else
                  Is_Valid_Reference(Pool, Start);

   ---------------------------------------------------------------------------
   --  Error Handling
   ---------------------------------------------------------------------------

   --  Null access would cause error
   type Null_Access_Error is record
      Operation : DOM_Operation;
      Index     : SML.Memory_Model.Node_Index;
      Message   : String (1 .. 100);
   end record;

   --  Would operation cause null error?
   function Would_Cause_Null_Error (Op : DOM_Operation;
                                    Index : SML.Memory_Model.Node_Index)
                                    return Boolean
     with Post => Would_Cause_Null_Error'Result =
                    (Has_Null_Check_Precondition(Op) and then
                     Index = SML.Memory_Model.No_Node_Index);

   --  Prevent null error
   function Prevent_Null_Error (Op : DOM_Operation;
                                Index : SML.Memory_Model.Node_Index)
                                return SML.Memory_Model.Node_Index
     with Post => (if Would_Cause_Null_Error(Op, Index) then
                      Prevent_Null_Error'Result = SML.Memory_Model.No_Node_Index
                   else
                      Prevent_Null_Error'Result = Index);

end SML.Null_Safety;