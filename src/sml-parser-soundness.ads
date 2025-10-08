------------------------------------------------------------------------------
--  SML.Parser.Soundness Package Specification
--  Soundness Proof for SML Parser
--  SPARK Ada Implementation - Formal Verification
------------------------------------------------------------------------------

with SML.DOM;
with SML.Grammar;
with SML.Parser;

package SML.Parser.Soundness with SPARK_Mode => On, Ghost is

   --  This package contains the formal proof that the SML parser is sound:
   --  If Parse(Input).Success then Is_Valid_SML(Input)
   --
   --  The proof uses simulation invariants to show that parser states
   --  correspond to partial parse trees that follow the SML grammar.

   ---------------------------------------------------------------------------
   --  Main Soundness Theorem
   ---------------------------------------------------------------------------

   --  The parser is sound: it only accepts valid SML
   procedure Lemma_Parser_Sound
     with Post => (for all Input : String =>
                     (if Input'Length <= Natural'Last - 1000 and then
                         Parse(Input).Success
                      then Is_Valid_SML(Input)));

   --  Equivalence between grammar-based and predicate-based validity
   procedure Lemma_Validity_Equivalence
     with Post => (for all Input : String =>
                     Is_Valid_SML(Input) =
                     SML.Grammar.Is_Valid_SML_By_Grammar(Input));

   ---------------------------------------------------------------------------
   --  Parser-Grammar Correspondence
   ---------------------------------------------------------------------------

   --  Parser state corresponds to a partial parse tree
   function State_Corresponds_To_Tree (State : Parser_State;
                                       Tree : SML.Grammar.Parse_Tree;
                                       Input : String) return Boolean
     with Pre => State.Position <= Input'Last + 1;

   --  Valid partial state means valid parsed prefix
   procedure Lemma_Partial_State_Valid_Prefix
     (State : Parser_State; Input : String)
     with Pre => Is_Valid_Partial_State(State) and
                 State.Position <= Input'Last + 1,
          Post => Is_Valid_SML_Prefix(Input, Input'First, State.Position - 1);

   --  Check if a prefix of input is valid SML (may be incomplete)
   function Is_Valid_SML_Prefix (Input : String;
                                 Start_Pos, End_Pos : Natural) return Boolean
     with Pre => Start_Pos >= Input'First and End_Pos <= Input'Last and
                 Start_Pos <= End_Pos + 1;

   ---------------------------------------------------------------------------
   --  Parser State Invariants
   ---------------------------------------------------------------------------

   --  Invariant: Parser stack corresponds to open elements
   function Stack_Corresponds_To_Open_Tags (State : Parser_State;
                                           Input : String) return Boolean
     with Pre => State.Position <= Input'Last + 1;

   --  Invariant: Consumed input follows grammar
   function Consumed_Input_Valid (State : Parser_State;
                                  Input : String) return Boolean
     with Pre => State.Position <= Input'Last + 1,
          Post => Consumed_Input_Valid'Result =
                    (State.Position = Input'First or else
                     SML.Grammar.Matches_Production(
                       Input, Input'First, State.Position - 1,
                       Some_Production));

   --  Invariant: Error state is terminal (no recovery)
   function Error_State_Terminal (State : Parser_State) return Boolean
     with Post => Error_State_Terminal'Result =
                    (if State.Has_Error then
                       -- No valid transition from error state
                       (for all NextState : Parser_State =>
                          (if Is_Successor_State(State, NextState) then
                             NextState.Has_Error)));

   --  Check if one state can follow another
   function Is_Successor_State (Current, Next : Parser_State) return Boolean;

   ---------------------------------------------------------------------------
   --  Token Processing Correctness
   ---------------------------------------------------------------------------

   --  Parser correctly identifies next token
   procedure Lemma_Parser_Gets_Correct_Token
     (Input : String; Position : Natural)
     with Pre => Position >= Input'First and Position <= Input'Last,
          Post => Parser_Next_Token(Input, Position) =
                  SML.Grammar.Next_Token(Input, Position);

   --  Parser's internal tokenizer function
   function Parser_Next_Token (Input : String; Position : Natural)
                              return SML.Grammar.Token
     with Pre => Position >= Input'First and Position <= Input'Last;

   --  Token processing follows grammar rules
   procedure Lemma_Token_Processing_Follows_Grammar
     (State : Parser_State;
      Input : String;
      Token : SML.Grammar.Token)
     with Pre => Is_Valid_Partial_State(State) and
                 State.Position = Token.Start_Pos and
                 Token.End_Pos <= Input'Last + 1,
          Post => (if Can_Process_Token(State, Token) then
                     Exists_Grammar_Rule_For_Token(State, Token));

   --  Check if parser can process token in current state
   function Can_Process_Token (State : Parser_State;
                               Token : SML.Grammar.Token) return Boolean;

   --  Check if grammar allows token in current context
   function Exists_Grammar_Rule_For_Token (State : Parser_State;
                                          Token : SML.Grammar.Token)
                                          return Boolean;

   ---------------------------------------------------------------------------
   --  Parse Step Simulation
   ---------------------------------------------------------------------------

   --  Each parser step corresponds to grammar rule application
   procedure Lemma_Parse_Step_Simulates_Grammar
     (Old_State : Parser_State;
      New_State : Parser_State;
      Input : String)
     with Pre => Is_Valid_Partial_State(Old_State) and
                 Old_State.Position < New_State.Position and
                 New_State.Position <= Input'Last + 1 and
                 not Old_State.Has_Error,
          Post => (if Is_Valid_Partial_State(New_State) then
                     Exists_Derivation_Step(Old_State, New_State, Input));

   --  Check if state transition corresponds to derivation step
   function Exists_Derivation_Step (Old_State, New_State : Parser_State;
                                    Input : String) return Boolean
     with Pre => Old_State.Position < New_State.Position and
                 New_State.Position <= Input'Last + 1;

   ---------------------------------------------------------------------------
   --  Error Detection Correctness
   ---------------------------------------------------------------------------

   --  Parser detects all grammar violations
   procedure Lemma_Parser_Detects_Invalid_Input
     with Post => (for all Input : String =>
                     (if Input'Length <= Natural'Last - 1000 and then
                         not Is_Valid_SML(Input)
                      then not Parse(Input).Success));

   --  Error detection is accurate
   procedure Lemma_Error_Detection_Accurate
     (Input : String; Result : Parse_Result)
     with Pre => Input'Length <= Natural'Last - 1000 and
                 not Result.Success,
          Post => Error_Matches_Actual_Problem(Input, Result.Error);

   --  Check if error correctly identifies the problem
   function Error_Matches_Actual_Problem (Input : String;
                                          Error : Parse_Error) return Boolean
     with Pre => Error.Position <= Input'Length;

   ---------------------------------------------------------------------------
   --  Tag Matching Correctness
   ---------------------------------------------------------------------------

   --  Parser correctly matches start and end tags
   procedure Lemma_Tag_Matching_Correct
     (Input : String;
      Start_Tag_Pos : Natural;
      End_Tag_Pos : Natural;
      Tag_Name : String)
     with Pre => Start_Tag_Pos >= Input'First and
                 End_Tag_Pos <= Input'Last and
                 Start_Tag_Pos < End_Tag_Pos and
                 Tag_Name'Length <= SML.Grammar.Max_Name_Length,
          Post => Parser_Matches_Tags(Input, Start_Tag_Pos, End_Tag_Pos, Tag_Name) =
                  SML.Grammar.Matching_Tags(Input, Start_Tag_Pos, End_Tag_Pos, Tag_Name);

   --  Parser's tag matching function
   function Parser_Matches_Tags (Input : String;
                                 Start_Pos, End_Pos : Natural;
                                 Name : String) return Boolean
     with Pre => Start_Pos >= Input'First and End_Pos <= Input'Last and
                 Name'Length <= SML.Grammar.Max_Name_Length;

   ---------------------------------------------------------------------------
   --  Stack Depth Correctness
   ---------------------------------------------------------------------------

   --  Stack depth corresponds to nesting level
   procedure Lemma_Stack_Depth_Matches_Nesting
     (State : Parser_State; Input : String)
     with Pre => Is_Valid_Partial_State(State) and
                 State.Position <= Input'Last + 1,
          Post => State.Stack_Depth = Count_Open_Elements(Input, State.Position);

   --  Count unclosed elements up to position
   function Count_Open_Elements (Input : String; Position : Natural)
                                return Natural
     with Pre => Position <= Input'Last + 1,
          Post => Count_Open_Elements'Result <= SML.DOM.Max_Tree_Depth;

   ---------------------------------------------------------------------------
   --  Entity Reference Correctness
   ---------------------------------------------------------------------------

   --  Parser correctly handles entity references
   procedure Lemma_Entity_Handling_Correct
     with Post => (for all Input : String =>
                     (if Contains_Entities(Input) and Parse(Input).Success then
                        All_Entities_Valid_In_Result(Input, Parse(Input).Document)));

   --  Check if input contains entity references
   function Contains_Entities (Input : String) return Boolean;

   --  Check if all entities are correctly expanded in DOM
   function All_Entities_Valid_In_Result (Input : String;
                                          Doc : SML.DOM.Document) return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   ---------------------------------------------------------------------------
   --  Whitespace Handling Correctness
   ---------------------------------------------------------------------------

   --  Parser preserves significant whitespace
   procedure Lemma_Whitespace_Preserved
     with Post => (for all Input : String =>
                     (if Parse(Input).Success then
                        Significant_Whitespace_Preserved(Input,
                                                        Parse(Input).Document)));

   --  Check if significant whitespace is preserved
   function Significant_Whitespace_Preserved (Input : String;
                                             Doc : SML.DOM.Document)
                                             return Boolean
     with Pre => SML.DOM.Is_Well_Formed(Doc);

   ---------------------------------------------------------------------------
   --  Induction Principles for Soundness Proof
   ---------------------------------------------------------------------------

   --  Induction on parser execution steps
   procedure Lemma_Parser_Execution_Induction
     (P : access function (State : Parser_State;
                          Steps : Natural) return Boolean)
     with Pre =>
            -- Base case: initial state
            P(Initial_State, 0) and then
            -- Inductive case: property preserved by steps
            (for all State : Parser_State =>
               for all Steps : Natural =>
                  (if P(State, Steps) and then
                      not State.Has_Error and then
                      State.Position < Input_Length_For_State(State)
                   then P(Next_Parser_State(State), Steps + 1))),
          Post => (for all State : Parser_State =>
                     for all Steps : Natural =>
                        P(State, Steps));

   --  Get input length for a parser state (helper)
   function Input_Length_For_State (State : Parser_State) return Natural;

   --  Get next parser state (helper)
   function Next_Parser_State (State : Parser_State) return Parser_State
     with Pre => not State.Has_Error;

   ---------------------------------------------------------------------------
   --  Progress and Termination in Soundness Context
   ---------------------------------------------------------------------------

   --  Parser makes progress on valid input
   procedure Lemma_Parser_Progress_On_Valid_Input
     (State : Parser_State; Input : String)
     with Pre => Is_Valid_Partial_State(State) and
                 State.Position <= Input'Last and
                 not State.Has_Error and
                 Is_Valid_SML(Input),
          Post => (exists New_State : Parser_State =>
                     New_State.Position > State.Position or
                     New_State.Has_Error or
                     Is_Complete_Parse(New_State, Input));

   --  Parser terminates on any input
   procedure Lemma_Parser_Always_Terminates
     with Post => (for all Input : String =>
                     (if Input'Length <= Natural'Last - 1000 then
                        Parser_Terminates(Input)));

   --  Check if parser terminates on input
   function Parser_Terminates (Input : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Auxiliary Lemmas for Main Proof
   ---------------------------------------------------------------------------

   --  Complete parse means entire input consumed
   procedure Lemma_Complete_Parse_Consumes_All
     (State : Parser_State; Input : String)
     with Pre => Is_Complete_Parse(State, Input),
          Post => State.Position = Input'Last + 1 or
                  (State.Position = Input'First and Input'Length = 0);

   --  No partial parse of invalid input succeeds
   procedure Lemma_Invalid_Input_Fails
     (Input : String)
     with Pre => Input'Length <= Natural'Last - 1000 and
                 not Is_Valid_SML(Input),
          Post => (for all State : Parser_State =>
                     (if Reaches_State_From_Initial(State, Input) then
                        State.Has_Error or not Is_Complete_Parse(State, Input)));

   --  Check if state is reachable from initial state
   function Reaches_State_From_Initial (State : Parser_State;
                                        Input : String) return Boolean;

end SML.Parser.Soundness;