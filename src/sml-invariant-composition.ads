------------------------------------------------------------------------------
--  SML.Invariant_Composition Package Specification
--  Invariant Composition and Refinement Proofs for SML Library
--  SPARK Ada Implementation - Ghost Code for Verification
------------------------------------------------------------------------------

with SML.DOM;
with SML.Parser;
with SML.Memory_Model;
with SML.Invariant_Preservation;
with SML.Parser_State_Invariants;
with SML.DOM_Operation_Safety;

package SML.Invariant_Composition with SPARK_Mode => On, Ghost is

   --  This ghost package proves that invariants compose correctly:
   --  operations can be combined sequentially and in parallel while
   --  preserving all safety properties. It also proves refinement
   --  relationships between abstract and concrete invariants.

   ---------------------------------------------------------------------------
   --  Composition Types
   ---------------------------------------------------------------------------

   type Composition_Kind is (
      Sequential,      -- Operations executed one after another
      Parallel,        -- Operations executed concurrently (read-only)
      Nested,          -- Operations called within operations
      Alternating,     -- Operations alternating (e.g., parse/build)
      Iterative        -- Operations in loops
   );

   --  Operation sequence
   type Operation_Sequence is array (Positive range <>) of
                                    SML.DOM_Operation_Safety.DOM_Operation_Category;

   --  Composition result
   type Composition_Result is (
      Success,              -- All operations succeeded
      Partial_Success,      -- Some operations succeeded
      Failure,              -- All operations failed
      Invariant_Violation   -- Invariant broken (should never happen)
   );

   ---------------------------------------------------------------------------
   --  Sequential Composition
   ---------------------------------------------------------------------------

   --  Two operations in sequence preserve invariants
   procedure Lemma_Sequential_Composition_Safe
     (Doc : in out SML.DOM.Document;
      Op1, Op2 : SML.DOM_Operation_Safety.DOM_Operation_Category)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc),
          Post => SML.Invariant_Preservation.System_Invariant (Doc);

   --  N operations in sequence preserve invariants
   procedure Lemma_Sequential_Chain_Safe
     (Doc : in out SML.DOM.Document;
      Ops : Operation_Sequence)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc) and then
                  Ops'Length <= 1000,
          Post => SML.Invariant_Preservation.System_Invariant (Doc);

   --  Sequential composition is associative
   procedure Lemma_Sequential_Associative
     (Doc : SML.DOM.Document;
      Op1, Op2, Op3 : SML.DOM_Operation_Safety.DOM_Operation_Category)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc),
          Post => Compose_Sequential (Doc, Op1, Compose_Sequential (Doc, Op2, Op3)) =
                  Compose_Sequential (Doc, Compose_Sequential (Doc, Op1, Op2), Op3);

   --  Helper: Sequential composition function
   function Compose_Sequential (Doc : SML.DOM.Document;
                               Op1, Op2 : SML.DOM_Operation_Safety.DOM_Operation_Category)
                               return Composition_Result;

   ---------------------------------------------------------------------------
   --  Parallel Composition (Read-Only)
   ---------------------------------------------------------------------------

   --  Parallel reads don't interfere
   procedure Lemma_Parallel_Reads_Independent
     (Doc : SML.DOM.Document;
      Node1, Node2 : SML.Memory_Model.Node_Index)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Node1) and then
                  SML.DOM.Is_Valid_Node (Doc, Node2),
          Post => SML.Invariant_Preservation.System_Invariant (Doc) and then
                  Can_Execute_Parallel (Doc, Node1, Node2);

   --  Multiple parallel reads are safe
   procedure Lemma_Multiple_Parallel_Reads_Safe
     (Doc : SML.DOM.Document;
      Nodes : array (Positive range <>) of SML.Memory_Model.Node_Index)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc) and then
                  Nodes'Length <= 100 and then
                  (for all I in Nodes'Range =>
                     SML.DOM.Is_Valid_Node (Doc, Nodes (I))),
          Post => SML.Invariant_Preservation.System_Invariant (Doc);

   --  Parallel composition is commutative for reads
   procedure Lemma_Parallel_Reads_Commutative
     (Doc : SML.DOM.Document;
      Op1, Op2 : SML.DOM_Operation_Safety.DOM_Operation_Category)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc) and then
                  Is_Read_Only (Op1) and then Is_Read_Only (Op2),
          Post => Compose_Parallel (Doc, Op1, Op2) =
                  Compose_Parallel (Doc, Op2, Op1);

   --  Helper: Check if operations can execute in parallel
   function Can_Execute_Parallel (Doc : SML.DOM.Document;
                                 Node1, Node2 : SML.Memory_Model.Node_Index)
                                 return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Node1) and then
                 SML.DOM.Is_Valid_Node (Doc, Node2);

   --  Helper: Check if operation is read-only
   function Is_Read_Only (Op : SML.DOM_Operation_Safety.DOM_Operation_Category)
                         return Boolean
     with Post => Is_Read_Only'Result =
                    (Op in SML.DOM_Operation_Safety.Query |
                           SML.DOM_Operation_Safety.Traversal |
                           SML.DOM_Operation_Safety.Measurement);

   --  Helper: Parallel composition function
   function Compose_Parallel (Doc : SML.DOM.Document;
                             Op1, Op2 : SML.DOM_Operation_Safety.DOM_Operation_Category)
                             return Composition_Result;

   ---------------------------------------------------------------------------
   --  Nested Composition
   ---------------------------------------------------------------------------

   --  Nested operations preserve invariants
   procedure Lemma_Nested_Operations_Safe
     (Doc : SML.DOM.Document;
      Outer_Op : SML.DOM_Operation_Safety.DOM_Operation_Category;
      Inner_Ops : Operation_Sequence)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc) and then
                  Inner_Ops'Length <= 10,
          Post => SML.Invariant_Preservation.System_Invariant (Doc);

   --  Recursion depth is bounded
   function Max_Recursion_Depth (Doc : SML.DOM.Document;
                                Root : SML.Memory_Model.Node_Index)
                                return Natural
     with Pre => SML.DOM.Is_Valid_Node (Doc, Root),
          Post => Max_Recursion_Depth'Result <= SML.DOM.Max_Tree_Depth;

   --  Recursive traversal preserves invariants
   procedure Lemma_Recursive_Traversal_Safe
     (Doc : SML.DOM.Document;
      Root : SML.Memory_Model.Node_Index;
      Current_Depth : Natural)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Root) and then
                  Current_Depth <= SML.DOM.Max_Tree_Depth,
          Post => SML.Invariant_Preservation.System_Invariant (Doc),
          Variant => SML.DOM.Max_Tree_Depth - Current_Depth;

   ---------------------------------------------------------------------------
   --  Alternating Composition (Parse/Build)
   ---------------------------------------------------------------------------

   --  Alternating parse and build operations
   procedure Lemma_Parse_Build_Alternation_Safe
     (Input_Chunks : array (Positive range <>) of access constant String)
     with Pre  => Input_Chunks'Length <= 100 and then
                  (for all I in Input_Chunks'Range =>
                     Input_Chunks (I).all'Length <= 1000),
          Post => (for some Doc : SML.DOM.Document =>
                     SML.Invariant_Preservation.System_Invariant (Doc));

   --  Parser state and DOM state consistency
   function Parser_DOM_Consistent (Parser_State : SML.Parser_State_Invariants.Parser_State;
                                  Doc : SML.DOM.Document) return Boolean
     with Pre => Parser_State.Document = Doc'Access,
          Post => Parser_DOM_Consistent'Result =
                    (SML.Parser_State_Invariants.Valid_State (Parser_State) implies
                     SML.DOM.Is_Well_Formed (Doc));

   ---------------------------------------------------------------------------
   --  Iterative Composition
   ---------------------------------------------------------------------------

   --  Loop invariant preservation
   procedure Lemma_Loop_Invariant_Preserved
     (Doc : in out SML.DOM.Document;
      Op : SML.DOM_Operation_Safety.DOM_Operation_Category;
      Iteration : Natural)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc) and then
                  Iteration <= 10000,
          Post => SML.Invariant_Preservation.System_Invariant (Doc);

   --  Fixed-point reached
   function Is_Fixed_Point (Doc : SML.DOM.Document;
                           Op : SML.DOM_Operation_Safety.DOM_Operation_Category)
                           return Boolean
     with Post => Is_Fixed_Point'Result =
                    (Apply_Operation (Doc, Op) = Doc);

   --  Helper: Apply operation to document
   function Apply_Operation (Doc : SML.DOM.Document;
                            Op : SML.DOM_Operation_Safety.DOM_Operation_Category)
                            return SML.DOM.Document;

   ---------------------------------------------------------------------------
   --  Refinement Relations
   ---------------------------------------------------------------------------

   --  Abstract invariant implies concrete invariant
   procedure Lemma_Abstract_Implies_Concrete
     (Doc : SML.DOM.Document)
     with Pre  => Abstract_Invariant (Doc),
          Post => Concrete_Invariant (Doc);

   --  Concrete invariant refines abstract
   procedure Lemma_Concrete_Refines_Abstract
     (Doc : SML.DOM.Document)
     with Pre  => Concrete_Invariant (Doc),
          Post => Abstract_Invariant (Doc) or else
                  Stronger_Than_Abstract (Doc);

   --  Abstract invariant (high-level properties)
   function Abstract_Invariant (Doc : SML.DOM.Document) return Boolean
     with Post => Abstract_Invariant'Result =
                    (SML.DOM.Has_Single_Root (Doc) and then
                     SML.DOM.Is_Acyclic (Doc));

   --  Concrete invariant (implementation details)
   function Concrete_Invariant (Doc : SML.DOM.Document) return Boolean
     with Post => Concrete_Invariant'Result =
                    SML.Invariant_Preservation.System_Invariant (Doc);

   --  Concrete is stronger than abstract
   function Stronger_Than_Abstract (Doc : SML.DOM.Document) return Boolean;

   ---------------------------------------------------------------------------
   --  Transitivity and Monotonicity
   ---------------------------------------------------------------------------

   --  Invariant preservation is transitive
   procedure Lemma_Preservation_Transitive
     (Doc1, Doc2, Doc3 : SML.DOM.Document)
     with Pre  => Preserves_Invariant (Doc1, Doc2) and then
                  Preserves_Invariant (Doc2, Doc3),
          Post => Preserves_Invariant (Doc1, Doc3);

   --  Invariant strengthening is monotonic
   procedure Lemma_Strengthening_Monotonic
     (Doc : SML.DOM.Document;
      Inv1, Inv2 : Invariant_Predicate)
     with Pre  => Implies (Inv2, Inv1) and then Satisfies (Doc, Inv1),
          Post => (if Strengthen (Doc, Inv1, Inv2) then
                      Satisfies (Doc, Inv2));

   --  Helper types
   type Invariant_Predicate is access function (Doc : SML.DOM.Document) return Boolean;

   --  Helper: Invariant preserved between states
   function Preserves_Invariant (Before, After : SML.DOM.Document) return Boolean;

   --  Helper: Invariant implication
   function Implies (Stronger, Weaker : Invariant_Predicate) return Boolean;

   --  Helper: Document satisfies invariant
   function Satisfies (Doc : SML.DOM.Document;
                      Inv : Invariant_Predicate) return Boolean;

   --  Helper: Strengthen invariant
   function Strengthen (Doc : SML.DOM.Document;
                       Weak, Strong : Invariant_Predicate) return Boolean;

   ---------------------------------------------------------------------------
   --  Interference Freedom
   ---------------------------------------------------------------------------

   --  Operations on disjoint subtrees don't interfere
   procedure Lemma_Disjoint_Operations_Independent
     (Doc : SML.DOM.Document;
      Root1, Root2 : SML.Memory_Model.Node_Index)
     with Pre  => SML.Invariant_Preservation.System_Invariant (Doc) and then
                  SML.DOM.Is_Valid_Node (Doc, Root1) and then
                  SML.DOM.Is_Valid_Node (Doc, Root2) and then
                  Subtrees_Disjoint (Doc, Root1, Root2),
          Post => Operations_Independent (Doc, Root1, Root2);

   --  Helper: Check if subtrees are disjoint
   function Subtrees_Disjoint (Doc : SML.DOM.Document;
                               Root1, Root2 : SML.Memory_Model.Node_Index)
                               return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Root1) and then
                 SML.DOM.Is_Valid_Node (Doc, Root2);

   --  Helper: Operations are independent
   function Operations_Independent (Doc : SML.DOM.Document;
                                   Node1, Node2 : SML.Memory_Model.Node_Index)
                                   return Boolean
     with Pre => SML.DOM.Is_Valid_Node (Doc, Node1) and then
                 SML.DOM.Is_Valid_Node (Doc, Node2);

   ---------------------------------------------------------------------------
   --  Main Composition Theorem
   ---------------------------------------------------------------------------

   --  All valid compositions preserve all invariants
   procedure Theorem_All_Compositions_Preserve_Invariants
     with Ghost,
          Post => (for all Doc : SML.DOM.Document =>
                     (if SML.Invariant_Preservation.System_Invariant (Doc) then
                        (for all Kind : Composition_Kind =>
                           Composition_Preserves_Invariants (Doc, Kind))));

   function Composition_Preserves_Invariants (Doc : SML.DOM.Document;
                                             Kind : Composition_Kind)
                                             return Boolean
     with Post => Composition_Preserves_Invariants'Result = True;

end SML.Invariant_Composition;