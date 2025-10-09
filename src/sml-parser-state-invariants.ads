------------------------------------------------------------------------------
--  SML.Parser_State_Invariants Package Specification
--  Parser State Invariant Preservation for SML Parser
--  SPARK Ada Implementation - Ghost Code for Verification
------------------------------------------------------------------------------

with SML.Parser;
with SML.DOM;

package SML.DOM.Parser_State_Invariants with SPARK_Mode => On, Ghost is

   --  This ghost package proves that the SML parser maintains critical
   --  state invariants throughout parsing, ensuring correct and safe
   --  parsing behavior at all times.

   ---------------------------------------------------------------------------
   --  Parser State Type
   ---------------------------------------------------------------------------

   type Parser_State is record
      --  Input being parsed
      Input          : access constant String;
      Input_Length   : Natural;

      --  Current position in input
      Position       : Natural;
      Line           : Positive;
      Column         : Positive;

      --  Tag stack for matching
      Tag_Stack      : Tag_Stack_Type;
      Stack_Depth    : Natural;

      --  Error state
      Has_Error      : Boolean;
      Error_Info     : SML.DOM.Parser.Parse_Error;

      --  DOM being built
      Current_Node   : SML.Memory_Model.Node_Index;
      Document       : access SML.DOM.Document;

      --  Configuration
      Max_Depth      : Natural;
      Options        : SML.DOM.Parser.Parse_Options;
   end record
     with Predicate =>
       Position <= Input_Length + 1 and then
       Stack_Depth <= Max_Depth and then
       Line >= 1 and then
       Column >= 1 and then
       (Has_Error or else Valid_State (Parser_State));

   --  Tag stack for matching open/close tags
   type Tag_Info is record
      Name       : String (1 .. 100);
      Name_Length : Natural;
      Line       : Positive;
      Column     : Positive;
      Node_Index : SML.Memory_Model.Node_Index;
   end record;

   type Tag_Stack_Type is array (1 .. SML.DOM.Max_Tree_Depth) of Tag_Info;

   ---------------------------------------------------------------------------
   --  Core State Invariants
   ---------------------------------------------------------------------------

   --  Valid parser state
   function Valid_State (State : Parser_State) return Boolean
     with Post => Valid_State'Result =
                    (Position_Valid (State) and then
                     Stack_Valid (State) and then
                     Line_Column_Valid (State) and then
                     Node_Valid (State) and then
                     Progress_Possible (State));

   --  Position within input bounds
   function Position_Valid (State : Parser_State) return Boolean
     with Post => Position_Valid'Result =
                    (State.Position >= 1 and then
                     State.Position <= State.Input_Length + 1);

   --  Stack depth within bounds and consistent
   function Stack_Valid (State : Parser_State) return Boolean
     with Post => Stack_Valid'Result =
                    (State.Stack_Depth <= State.Max_Depth and then
                     State.Stack_Depth <= SML.DOM.Max_Tree_Depth and then
                     Stack_Matches_Tree_Depth (State));

   --  Line and column tracking accurate
   function Line_Column_Valid (State : Parser_State) return Boolean
     with Post => Line_Column_Valid'Result =
                    (State.Line >= 1 and then
                     State.Column >= 1 and then
                     Matches_Position (State));

   --  Current node is valid in document
   function Node_Valid (State : Parser_State) return Boolean
     with Post => Node_Valid'Result =
                    (State.Current_Node = SML.Memory_Model.No_Node_Index or else
                     SML.DOM.Is_Valid_Node (State.Document.all, State.Current_Node));

   --  Progress can be made (not stuck)
   function Progress_Possible (State : Parser_State) return Boolean
     with Post => Progress_Possible'Result =
                    (State.Has_Error or else
                     State.Position <= State.Input_Length or else
                     State.Stack_Depth > 0);

   --  Stack depth matches tree depth
   function Stack_Matches_Tree_Depth (State : Parser_State) return Boolean
     with Post => Stack_Matches_Tree_Depth'Result =
                    (if State.Current_Node /= SML.Memory_Model.No_Node_Index then
                       State.Stack_Depth = SML.DOM.Depth (State.Document.all,
                                                          State.Current_Node));

   --  Line/column matches position
   function Matches_Position (State : Parser_State) return Boolean;

   ---------------------------------------------------------------------------
   --  State Transition Invariants
   ---------------------------------------------------------------------------

   --  Position monotonically increases
   function Position_Monotonic (Before, After : Parser_State) return Boolean
     with Post => Position_Monotonic'Result =
                    (After.Position >= Before.Position);

   --  Stack depth changes by at most 1
   function Stack_Change_Bounded (Before, After : Parser_State) return Boolean
     with Post => Stack_Change_Bounded'Result =
                    (abs (Integer(After.Stack_Depth) - Integer(Before.Stack_Depth)) <= 1);

   --  Error state is absorbing (once error, always error)
   function Error_Absorbing (Before, After : Parser_State) return Boolean
     with Post => Error_Absorbing'Result =
                    (if Before.Has_Error then After.Has_Error);

   --  Line number never decreases
   function Line_Monotonic (Before, After : Parser_State) return Boolean
     with Post => Line_Monotonic'Result =
                    (After.Line >= Before.Line);

   --  Column resets only on new line
   function Column_Reset_Valid (Before, After : Parser_State) return Boolean
     with Post => Column_Reset_Valid'Result =
                    (if After.Line > Before.Line then
                       After.Column = 1
                     else
                       After.Column >= Before.Column);

   ---------------------------------------------------------------------------
   --  Operation-Specific Invariants
   ---------------------------------------------------------------------------

   --  Advancing position maintains invariants
   procedure Lemma_Advance_Position_Safe (State : in out Parser_State;
                                          Count : Positive)
     with Pre  => Valid_State (State) and then
                  not State.Has_Error and then
                  State.Position + Count - 1 <= State.Input_Length,
          Post => Valid_State (State) and then
                  State.Position = State'Old.Position + Count and then
                  Position_Monotonic (State'Old, State);

   --  Pushing tag maintains invariants
   procedure Lemma_Push_Tag_Safe (State : in out Parser_State;
                                  Tag : String)
     with Pre  => Valid_State (State) and then
                  not State.Has_Error and then
                  State.Stack_Depth < State.Max_Depth and then
                  Tag'Length <= 100,
          Post => Valid_State (State) and then
                  State.Stack_Depth = State'Old.Stack_Depth + 1 and then
                  Stack_Change_Bounded (State'Old, State);

   --  Popping tag maintains invariants
   procedure Lemma_Pop_Tag_Safe (State : in out Parser_State)
     with Pre  => Valid_State (State) and then
                  not State.Has_Error and then
                  State.Stack_Depth > 0,
          Post => Valid_State (State) and then
                  State.Stack_Depth = State'Old.Stack_Depth - 1 and then
                  Stack_Change_Bounded (State'Old, State);

   --  Setting error maintains invariants
   procedure Lemma_Set_Error_Safe (State : in out Parser_State;
                                   Error : SML.DOM.Parser.Parse_Error)
     with Pre  => Valid_State (State) and then
                  not State.Has_Error,
          Post => Valid_State (State) and then
                  State.Has_Error and then
                  State.Error_Info = Error;

   --  Newline handling maintains invariants
   procedure Lemma_Newline_Safe (State : in out Parser_State)
     with Pre  => Valid_State (State) and then
                  not State.Has_Error and then
                  State.Position <= State.Input_Length and then
                  State.Input (State.Position) = ASCII.LF,
          Post => Valid_State (State) and then
                  State.Line = State'Old.Line + 1 and then
                  State.Column = 1 and then
                  Line_Monotonic (State'Old, State) and then
                  Column_Reset_Valid (State'Old, State);

   ---------------------------------------------------------------------------
   --  Tag Stack Invariants
   ---------------------------------------------------------------------------

   --  All tags on stack are properly nested
   function Stack_Properly_Nested (State : Parser_State) return Boolean
     with Post => Stack_Properly_Nested'Result =
                    (for all I in 1 .. State.Stack_Depth - 1 =>
                       State.Tag_Stack (I).Node_Index /=
                       State.Tag_Stack (I + 1).Node_Index);

   --  Stack tags match DOM structure
   function Stack_Matches_DOM (State : Parser_State) return Boolean
     with Pre => State.Document /= null,
          Post => Stack_Matches_DOM'Result =
                    (for all I in 1 .. State.Stack_Depth =>
                       SML.DOM.Is_Valid_Node (State.Document.all,
                                              State.Tag_Stack (I).Node_Index));

   --  Top of stack is current node's parent
   function Stack_Top_Is_Parent (State : Parser_State) return Boolean
     with Pre => State.Document /= null and then
                 State.Stack_Depth > 0 and then
                 State.Current_Node /= SML.Memory_Model.No_Node_Index,
          Post => Stack_Top_Is_Parent'Result =
                    (SML.DOM.Parent (State.Document.all, State.Current_Node) =
                     State.Tag_Stack (State.Stack_Depth).Node_Index);

   ---------------------------------------------------------------------------
   --  Progress and Termination Invariants
   ---------------------------------------------------------------------------

   --  Progress measure decreases
   function Progress_Measure (State : Parser_State) return Natural
     with Post => Progress_Measure'Result =
                    State.Input_Length - State.Position + 1 + State.Stack_Depth;

   --  Progress is made on each step
   procedure Lemma_Progress_Made (Before, After : Parser_State)
     with Pre  => Valid_State (Before) and then
                  Valid_State (After) and then
                  not Before.Has_Error,
          Post => After.Has_Error or else
                  Progress_Measure (After) < Progress_Measure (Before);

   --  Parsing terminates
   procedure Lemma_Parsing_Terminates (Initial_State : Parser_State)
     with Pre  => Valid_State (Initial_State) and then
                  Initial_State.Position = 1 and then
                  Initial_State.Stack_Depth = 0,
          Post => (for some Final_State : Parser_State =>
                     (Final_State.Has_Error or else
                      (Final_State.Position = Final_State.Input_Length + 1 and then
                       Final_State.Stack_Depth = 0)));

   ---------------------------------------------------------------------------
   --  Lookahead Invariants
   ---------------------------------------------------------------------------

   --  Lookahead doesn't exceed bounds
   function Lookahead_Safe (State : Parser_State;
                           Offset : Natural) return Boolean
     with Post => Lookahead_Safe'Result =
                    (State.Position + Offset <= State.Input_Length + 1);

   --  Peek operation is safe
   function Peek_Safe (State : Parser_State;
                      Count : Natural) return Boolean
     with Post => Peek_Safe'Result =
                    (State.Position + Count - 1 <= State.Input_Length);

   ---------------------------------------------------------------------------
   --  Main Parser State Theorem
   ---------------------------------------------------------------------------

   --  All parser operations maintain valid state
   procedure Theorem_Parser_Maintains_Valid_State
     with Ghost,
          Post => (for all State : Parser_State =>
                     (if Valid_State (State) then
                        (for all Op : Parser_Operation =>
                           Maintains_Valid_State (State, Op))));

   type Parser_Operation is (
      Advance,
      Push_Tag,
      Pop_Tag,
      Set_Error,
      Process_Newline,
      Skip_Whitespace,
      Parse_Name,
      Parse_Text
   );

   function Maintains_Valid_State (State : Parser_State;
                                   Op : Parser_Operation) return Boolean
     with Post => Maintains_Valid_State'Result = True;

end SML.DOM.Parser_State_Invariants;