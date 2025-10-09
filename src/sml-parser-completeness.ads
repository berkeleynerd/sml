------------------------------------------------------------------------------
--  SML.DOM.Parser.Completeness Package Specification
--  Completeness Proof for SML Parser
--  SPARK Ada Implementation - Formal Verification
------------------------------------------------------------------------------

with SML.DOM;
with SML.Grammar;
with SML.Parser;

package SML.DOM.Parser.Completeness with SPARK_Mode => On, Ghost is

   --  This package contains the formal proof that the SML parser is complete:
   --  If Is_Valid_SML(Input) then Parse(Input).Success
   --
   --  The proof constructs an accepting parser execution trace for any
   --  valid SML input by induction on the parse tree structure.

   ---------------------------------------------------------------------------
   --  Main Completeness Theorem
   ---------------------------------------------------------------------------

   --  The parser is complete: it accepts all valid SML
   procedure Lemma_Parser_Complete
     with Post => (for all Input : String =>
                     (if Input'Length <= Natural'Last - 1000 and then
                         Is_Valid_SML(Input)
                      then Parse(Input).Success));

   --  Stronger version with execution trace
   procedure Lemma_Parser_Complete_With_Trace
     with Post => (for all Input : String =>
                     (if Input'Length <= Natural'Last - 1000 and then
                         Is_Valid_SML(Input)
                      then (exists Trace : Parser_Execution_Trace =>
                              Trace_Accepts(Trace, Input))));

   ---------------------------------------------------------------------------
   --  Parser Execution Traces
   ---------------------------------------------------------------------------

   --  A trace records the sequence of parser states during execution
   type Parser_State_Array is array (Positive range <>) of Parser_State;

   type Parser_Execution_Trace (Length : Natural) is record
      States : Parser_State_Array (1 .. Length);
      Final_Success : Boolean;
   end record
     with Predicate => Length > 0 and then
                       States(1) = Initial_State;

   --  Check if trace represents accepting execution
   function Trace_Accepts (Trace : Parser_Execution_Trace;
                          Input : String) return Boolean
     with Post => Trace_Accepts'Result =
                    (Trace.Final_Success and then
                     not Trace.States(Trace.Length).Has_Error and then
                     Is_Complete_Parse(Trace.States(Trace.Length), Input));

   --  Check if trace is valid execution
   function Valid_Trace (Trace : Parser_Execution_Trace;
                        Input : String) return Boolean
     with Post => Valid_Trace'Result =
                    (for all I in 1 .. Trace.Length - 1 =>
                       Valid_Transition(Trace.States(I),
                                       Trace.States(I + 1),
                                       Input));

   --  Check if state transition is valid
   function Valid_Transition (From_State, To_State : Parser_State;
                             Input : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Constructive Parser Execution
   ---------------------------------------------------------------------------

   --  Given valid input and parse tree, construct accepting trace
   function Construct_Accepting_Trace (Input : String;
                                       Tree : SML.Grammar.Parse_Tree)
                                       return Parser_Execution_Trace
     with Pre => Is_Valid_SML(Input) and then
                 SML.Grammar.Derives_From_Document(Tree, Input),
          Post => Trace_Accepts(Construct_Accepting_Trace'Result, Input) and then
                  Valid_Trace(Construct_Accepting_Trace'Result, Input);

   --  Construct parser state for parse tree node
   function State_For_Tree_Node (Node : SML.Grammar.AST_Node_Access;
                                 Input : String;
                                 Position : Natural) return Parser_State
     with Pre => Node /= null and Position <= Input'Last + 1,
          Post => State_For_Tree_Node'Result.Position = Position and then
                  not State_For_Tree_Node'Result.Has_Error;

   ---------------------------------------------------------------------------
   --  Inductive Construction Lemmas
   ---------------------------------------------------------------------------

   --  Parser can process any valid element
   procedure Lemma_Parser_Accepts_Element
     (Input : String; Start_Pos, End_Pos : Natural; Tag_Name : String)
     with Pre => Start_Pos >= Input'First and End_Pos <= Input'Last and
                 Start_Pos < End_Pos and
                 SML.Grammar.Well_Formed_Element(Input, Start_Pos, End_Pos, Tag_Name),
          Post => Can_Parse_Substring(Input, Start_Pos, End_Pos);

   --  Parser can process any valid text content
   procedure Lemma_Parser_Accepts_Text
     (Input : String; Start_Pos, End_Pos : Natural)
     with Pre => Start_Pos >= Input'First and End_Pos <= Input'Last and
                 Start_Pos <= End_Pos and
                 Valid_Text_Content(Input, Start_Pos, End_Pos),
          Post => Can_Parse_Substring(Input, Start_Pos, End_Pos);

   --  Parser can process any valid entity reference
   procedure Lemma_Parser_Accepts_Entity
     (Input : String; Start_Pos : Natural; Entity : String)
     with Pre => Start_Pos >= Input'First and
                 Start_Pos + Entity'Length <= Input'Last and
                 Valid_Entity_Reference(Entity),
          Post => Can_Parse_Substring(Input, Start_Pos,
                                      Start_Pos + Entity'Length - 1);

   --  Check if parser can successfully parse substring
   function Can_Parse_Substring (Input : String;
                                 Start_Pos, End_Pos : Natural) return Boolean
     with Pre => Start_Pos >= Input'First and End_Pos <= Input'Last;

   --  Check if text content is valid (no forbidden characters)
   function Valid_Text_Content (Input : String;
                               Start_Pos, End_Pos : Natural) return Boolean
     with Pre => Start_Pos >= Input'First and End_Pos <= Input'Last;

   --  Check if string is valid entity reference
   function Valid_Entity_Reference (Entity : String) return Boolean
     with Post => Valid_Entity_Reference'Result =
                    (Entity'Length >= 3 and then
                     Entity(Entity'First) = '&' and then
                     Entity(Entity'Last) = ';' and then
                     Is_Standard_Entity_Name(
                       Entity(Entity'First + 1 .. Entity'Last - 1)));

   --  Check if name is standard entity
   function Is_Standard_Entity_Name (Name : String) return Boolean
     with Post => Is_Standard_Entity_Name'Result =
                    (Name = "lt" or Name = "gt" or Name = "amp" or
                     Name = "quot" or Name = "apos");

   ---------------------------------------------------------------------------
   --  Grammar Coverage Lemmas
   ---------------------------------------------------------------------------

   --  Parser handles all grammar productions
   procedure Lemma_Parser_Covers_All_Productions
     with Post => (for all P : SML.Grammar.Production_Rule =>
                     (if Valid_Production(P) then
                        Parser_Handles_Production(P)));

   --  Check if production is valid in SML grammar
   function Valid_Production (P : SML.Grammar.Production_Rule) return Boolean;

   --  Check if parser handles a production
   function Parser_Handles_Production (P : SML.Grammar.Production_Rule)
                                      return Boolean;

   --  Parser handles all valid token sequences
   procedure Lemma_Parser_Handles_All_Token_Sequences
     with Post => (for all Tokens : SML.Grammar.Token_Stream =>
                     (if Valid_Token_Sequence(Tokens) then
                        Parser_Can_Process_Tokens(Tokens)));

   --  Check if token sequence is valid per grammar
   function Valid_Token_Sequence (Tokens : SML.Grammar.Token_Stream)
                                 return Boolean;

   --  Check if parser can process token sequence
   function Parser_Can_Process_Tokens (Tokens : SML.Grammar.Token_Stream)
                                      return Boolean;

   ---------------------------------------------------------------------------
   --  Compositionality Lemmas
   ---------------------------------------------------------------------------

   --  If parts are parseable, composition is parseable
   procedure Lemma_Parseable_Parts_Compose
     (Input : String;
      Part1_Start, Part1_End : Natural;
      Part2_Start, Part2_End : Natural)
     with Pre => Part1_Start >= Input'First and Part1_End <= Input'Last and
                 Part2_Start >= Input'First and Part2_End <= Input'Last and
                 Part1_End < Part2_Start and
                 Can_Parse_Substring(Input, Part1_Start, Part1_End) and
                 Can_Parse_Substring(Input, Part2_Start, Part2_End),
          Post => Can_Parse_Substring(Input, Part1_Start, Part2_End);

   --  Nested elements are parseable if outer and inner are
   procedure Lemma_Nested_Elements_Parseable
     (Input : String;
      Outer_Start, Outer_End : Natural;
      Inner_Start, Inner_End : Natural)
     with Pre => Outer_Start >= Input'First and Outer_End <= Input'Last and
                 Inner_Start > Outer_Start and Inner_End < Outer_End and
                 Can_Parse_Substring(Input, Outer_Start, Inner_Start - 1) and
                 Can_Parse_Substring(Input, Inner_Start, Inner_End) and
                 Can_Parse_Substring(Input, Inner_End + 1, Outer_End),
          Post => Can_Parse_Substring(Input, Outer_Start, Outer_End);

   ---------------------------------------------------------------------------
   --  No Ambiguity Lemmas
   ---------------------------------------------------------------------------

   --  Valid SML has unique parse
   procedure Lemma_Unique_Parse
     with Post => (for all Input : String =>
                     (if Is_Valid_SML(Input) then
                        (for all T1, T2 : Parser_Execution_Trace =>
                           (if Trace_Accepts(T1, Input) and
                               Trace_Accepts(T2, Input) then
                              Same_Parse_Result(T1, T2, Input)))));

   --  Check if two traces produce same result
   function Same_Parse_Result (T1, T2 : Parser_Execution_Trace;
                              Input : String) return Boolean
     with Pre => Trace_Accepts(T1, Input) and Trace_Accepts(T2, Input);

   --  Parser is deterministic for valid input
   procedure Lemma_Parser_Deterministic_On_Valid
     with Post => (for all Input : String =>
                     (if Is_Valid_SML(Input) then
                        (for all S : Parser_State =>
                           (if not S.Has_Error then
                              At_Most_One_Valid_Transition(S, Input)))));

   --  Check if state has at most one valid transition
   function At_Most_One_Valid_Transition (S : Parser_State;
                                          Input : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Robustness Lemmas
   ---------------------------------------------------------------------------

   --  Parser doesn't reject due to resource limits on valid input
   procedure Lemma_No_False_Resource_Errors
     with Post => (for all Input : String =>
                     (if Is_Valid_SML(Input) and then
                         Input'Length <= Natural'Last - 1000 and then
                         Tree_Depth(Input) <= SML.DOM.Max_Tree_Depth and then
                         Max_Children_Count(Input) <= SML.DOM.Max_Children
                      then not Fails_Due_To_Resources(Input)));

   --  Get tree depth of valid input
   function Tree_Depth (Input : String) return Natural
     with Pre => Is_Valid_SML(Input),
          Post => Tree_Depth'Result <= SML.DOM.Max_Tree_Depth;

   --  Get maximum children count in input
   function Max_Children_Count (Input : String) return Natural
     with Pre => Is_Valid_SML(Input),
          Post => Max_Children_Count'Result <= SML.DOM.Max_Children;

   --  Check if parse fails due to resource limits
   function Fails_Due_To_Resources (Input : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Induction Principles for Completeness
   ---------------------------------------------------------------------------

   --  Structural induction on valid SML input
   procedure Lemma_Valid_SML_Induction
     (P : access function (Input : String) return Boolean)
     with Pre =>
            -- Base: empty element
            (for all Tag : String =>
               (if Valid_Tag_Name(Tag) then
                  P("<" & Tag & "></" & Tag & ">"))) and then
            -- Base: element with text
            (for all Tag : String =>
               for all Text : String =>
                 (if Valid_Tag_Name(Tag) and Valid_Text_Content(Text, 1, Text'Length) then
                    P("<" & Tag & ">" & Text & "</" & Tag & ">"))) and then
            -- Inductive: nested elements
            (for all Outer : String =>
               for all Inner : String =>
                 (if P(Inner) and Valid_Tag_Name(Get_Tag(Outer)) then
                    P(Wrap_With_Element(Inner, Get_Tag(Outer))))),
          Post => (for all Input : String =>
                     (if Is_Valid_SML(Input) then P(Input)));

   --  Helper: check if string is valid tag name
   function Valid_Tag_Name (Tag : String) return Boolean
     with Post => Valid_Tag_Name'Result =
                    (Tag'Length > 0 and Tag'Length <= SML.Grammar.Max_Name_Length and
                     (for all C of Tag => SML.Grammar.Is_Name_Char(C)));

   --  Helper: extract tag name from element
   function Get_Tag (Element : String) return String
     with Pre => Element'Length > 0;

   --  Helper: wrap content with element tags
   function Wrap_With_Element (Content : String; Tag : String) return String
     with Pre => Valid_Tag_Name(Tag),
          Post => Wrap_With_Element'Result =
                    "<" & Tag & ">" & Content & "</" & Tag & ">";

   ---------------------------------------------------------------------------
   --  Well-Formed Element Check
   ---------------------------------------------------------------------------

   function Well_Formed_Element (Input : String;
                                 Start_Pos, End_Pos : Natural;
                                 Tag_Name : String) return Boolean
     renames SML.Grammar.Well_Formed_Element;

end SML.DOM.Parser.Completeness;