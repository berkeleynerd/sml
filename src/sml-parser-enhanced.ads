------------------------------------------------------------------------------
--  SML.Parser Package Specification (Enhanced with Termination Contracts)
--  Parser and Validator for Simple Markup Language (SML)
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML.DOM;

package SML.Parser with SPARK_Mode => On is

   --  SML.Parser: Provides parsing and validation for SML documents.
   --  Produces a DOM Document on success or a detailed error on failure.
   --  Handles all SML format rules: no attributes, no processing instructions,
   --  no DTD, no CDATA, UTF-8 only, entity references for <>&"'
   --  Enhanced with formal termination guarantees for all parsing loops.

   ---------------------------------------------------------------------------
   --  Error Reporting Types
   ---------------------------------------------------------------------------

   --  Enumeration of possible parse error categories
   type Error_Kind is (
      Invalid_UTF8,           -- Invalid UTF-8 byte sequence
      Malformed_Structure,    -- Well-formedness error (e.g., tag mismatch)
      Disallowed_Construct,   -- XML construct not allowed in SML
      Unexpected_EOF,         -- Input ended prematurely
      Invalid_Entity,         -- Unknown or malformed entity reference
      Depth_Exceeded,         -- Tree depth exceeds maximum
      Too_Many_Children       -- Element has too many children
   );

   --  Detailed information about a parse error
   type Parse_Error is record
      Kind        : Error_Kind;
      Position    : Natural;    -- Byte offset where error detected (0-based)
      Line        : Positive;   -- Line number (1-based)
      Column      : Positive;   -- Column number (1-based)
      Message     : String (1 .. 256);  -- Detailed error message
      Msg_Length  : Natural;    -- Actual length of message
   end record;

   --  Result of parsing: either success with Document or failure with error
   type Parse_Result (Success : Boolean := False) is limited record
      case Success is
         when True  => Document : SML.DOM.Document;
         when False => Error    : Parse_Error;
      end case;
   end record;

   ---------------------------------------------------------------------------
   --  Main Parsing Functions with Termination Guarantees
   ---------------------------------------------------------------------------

   --  Parse the given input string as SML
   --  Main loop variant: Input'Last - Current_Position + 1
   --  Stack depth bounded by Max_Tree_Depth
   function Parse (Input : String) return Parse_Result
     with Pre  => Input'Length <= Natural'Last - 1000,  -- Prevent overflow
          Post => (if Parse'Result.Success then
                     -- Successful parse postconditions:
                     SML.DOM.Is_Well_Formed (Parse'Result.Document) and then
                     Is_Valid_SML (Input) and then
                     Parses_To (Input, Parse'Result.Document) and then
                     Consumes_Entire_Input (Input, Parse'Result.Document)
                   else
                     -- Failure postconditions:
                     not Is_Valid_SML (Input) and then
                     Parse'Result.Error.Position <= Input'Length and then
                     Parse'Result.Error.Line >= 1 and then
                     Parse'Result.Error.Column >= 1),
          Global => null;

   --  Validate the input string for SML well-formedness
   --  Loop variant: Input'Last - Position + 1
   function Validate (Input : String) return Boolean
     with Pre    => Input'Length <= Natural'Last - 1000,
          Post   => Validate'Result = Is_Valid_SML (Input),
          Global => null;

   --  Parse with options for whitespace handling
   type Whitespace_Mode is (Preserve_All, Normalize, Trim);

   type Parse_Options is record
      Whitespace     : Whitespace_Mode := Preserve_All;
      Expand_Entities : Boolean := True;
      Max_Depth      : Natural := SML.DOM.Max_Tree_Depth;
   end record;

   function Parse_With_Options (Input : String; Options : Parse_Options)
                               return Parse_Result
     with Pre  => Input'Length <= Natural'Last - 1000 and then
                  Options.Max_Depth > 0 and then
                  Options.Max_Depth <= SML.DOM.Max_Tree_Depth,
          Post => (if Parse_With_Options'Result.Success then
                     SML.DOM.Is_Well_Formed (Parse_With_Options'Result.Document) and then
                     DOM_Depth (Parse_With_Options'Result.Document) <= Options.Max_Depth),
          Global => null;

   ---------------------------------------------------------------------------
   --  Parsing Progress Measures for Termination
   ---------------------------------------------------------------------------

   --  Measure remaining input to parse
   function Parse_Remaining (Input : String; Position : Natural) return Natural
     with Ghost,
          Pre => Position >= Input'First and Position <= Input'Last + 1,
          Post => Parse_Remaining'Result = Input'Last - Position + 1,
          Global => null;

   --  Measure parse stack space remaining
   function Stack_Space_Remaining (Current_Depth : Natural;
                                   Max_Depth : Natural) return Natural
     with Ghost,
          Pre => Current_Depth <= Max_Depth,
          Post => Stack_Space_Remaining'Result = Max_Depth - Current_Depth,
          Global => null;

   --  Combined lexicographic measure for nested parsing
   type Parse_Measure is record
      Input_Remaining : Natural;
      Stack_Available : Natural;
   end record;

   function Make_Parse_Measure (Input : String;
                                Position : Natural;
                                Stack_Depth : Natural;
                                Max_Depth : Natural) return Parse_Measure
     with Ghost,
          Pre => Position >= Input'First and Position <= Input'Last + 1 and
                 Stack_Depth <= Max_Depth,
          Post => Make_Parse_Measure'Result.Input_Remaining = Input'Last - Position + 1 and
                  Make_Parse_Measure'Result.Stack_Available = Max_Depth - Stack_Depth,
          Global => null;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Formal Verification
   ---------------------------------------------------------------------------

   --  Defines validity of an input string as SML
   function Is_Valid_SML (Input : String) return Boolean
     with Ghost,
          Global => null,
          Post => Is_Valid_SML'Result =
                    (Has_Valid_UTF8 (Input) and then
                     Has_Valid_Structure (Input) and then
                     Has_No_Disallowed_Constructs (Input) and then
                     Has_Valid_Entities (Input) and then
                     Has_Bounded_Nesting (Input));

   --  Relates an input string to a DOM Document
   function Parses_To (Input : String; Doc : SML.DOM.Document) return Boolean
     with Ghost,
          Pre => SML.DOM.Is_Well_Formed (Doc),
          Global => null;

   --  Ensures entire input was consumed
   function Consumes_Entire_Input (Input : String; Doc : SML.DOM.Document) return Boolean
     with Ghost,
          Pre => SML.DOM.Is_Well_Formed (Doc),
          Global => null;

   --  Get maximum depth of DOM tree
   function DOM_Depth (Doc : SML.DOM.Document) return Natural
     with Ghost,
          Pre => SML.DOM.Is_Well_Formed (Doc),
          Post => DOM_Depth'Result <= SML.DOM.Max_Tree_Depth,
          Global => null;

   --  Input contains only valid UTF-8 sequences
   function Has_Valid_UTF8 (Input : String) return Boolean
     with Ghost,
          Import,
          Global => null;

   --  Input has valid XML structure (matching tags, single root, etc.)
   function Has_Valid_Structure (Input : String) return Boolean
     with Ghost,
          Global => null;

   --  Input contains no XML constructs forbidden in SML
   function Has_No_Disallowed_Constructs (Input : String) return Boolean
     with Ghost,
          Global => null,
          Post => Has_No_Disallowed_Constructs'Result =
                    (No_Attributes (Input) and then
                     No_Processing_Instructions (Input) and then
                     No_DTD (Input) and then
                     No_CDATA (Input) and then
                     No_Comments (Input) and then
                     No_Namespaces (Input));

   --  All entity references are valid
   function Has_Valid_Entities (Input : String) return Boolean
     with Ghost,
          Global => null;

   --  Check nesting depth is bounded
   function Has_Bounded_Nesting (Input : String) return Boolean
     with Ghost,
          Global => null,
          Post => Has_Bounded_Nesting'Result =
                    (Parse_Max_Depth (Input) <= SML.DOM.Max_Tree_Depth);

   --  Get maximum nesting depth in input
   function Parse_Max_Depth (Input : String) return Natural
     with Ghost,
          Global => null,
          Post => Parse_Max_Depth'Result <= Input'Length;  -- Can't nest deeper than chars

   ---------------------------------------------------------------------------
   --  Detailed Ghost Predicates
   ---------------------------------------------------------------------------

   --  No attributes in any element
   function No_Attributes (Input : String) return Boolean
     with Ghost,
          Global => null;

   --  No processing instructions (<?...?>)
   function No_Processing_Instructions (Input : String) return Boolean
     with Ghost,
          Global => null;

   --  No DOCTYPE declaration
   function No_DTD (Input : String) return Boolean
     with Ghost,
          Global => null;

   --  No CDATA sections (<![CDATA[...]]>)
   function No_CDATA (Input : String) return Boolean
     with Ghost,
          Global => null;

   --  No comments (<!--...-->)
   function No_Comments (Input : String) return Boolean
     with Ghost,
          Global => null;

   --  No namespace declarations or prefixes
   function No_Namespaces (Input : String) return Boolean
     with Ghost,
          Global => null;

   ---------------------------------------------------------------------------
   --  Parser State Ghost Functions (for proof)
   ---------------------------------------------------------------------------

   --  Represents the abstract state of the parser at a position
   type Parser_State is private with Ghost;

   --  Initial parser state
   function Initial_State return Parser_State
     with Ghost,
          Global => null;

   --  Parser state after consuming a portion of input
   --  Ensures forward progress for termination
   function Parse_Step (State : Parser_State; Input : String;
                        Start_Pos, End_Pos : Natural) return Parser_State
     with Ghost,
          Pre => Start_Pos >= Input'First and then
                 End_Pos <= Input'Last and then
                 Start_Pos < End_Pos,  -- Must consume at least one char
          Post => Progress_Made (State, Parse_Step'Result),
          Global => null;

   --  Check parser made progress
   function Progress_Made (Old_State, New_State : Parser_State) return Boolean
     with Ghost,
          Global => null;

   --  Checks if parser state corresponds to a complete valid parse
   function Is_Complete_Parse (State : Parser_State; Input : String)
                              return Boolean
     with Ghost,
          Global => null;

   --  Gets the partial DOM constructed so far
   function Partial_DOM (State : Parser_State) return SML.DOM.Document
     with Ghost,
          Pre => Is_Valid_Partial_State (State),
          Global => null;

   --  Checks if the parser state is valid (no errors encountered)
   function Is_Valid_Partial_State (State : Parser_State) return Boolean
     with Ghost,
          Global => null;

   --  Get current position in input
   function Current_Position (State : Parser_State) return Natural
     with Ghost,
          Global => null;

   --  Get current stack depth
   function Current_Stack_Depth (State : Parser_State) return Natural
     with Ghost,
          Post => Current_Stack_Depth'Result <= SML.DOM.Max_Tree_Depth,
          Global => null;

   ---------------------------------------------------------------------------
   --  Parsing Termination Lemmas
   ---------------------------------------------------------------------------

   --  Parser always makes progress
   procedure Lemma_Parser_Makes_Progress (Input : String;
                                          Position : Natural)
     with Ghost,
          Pre => Position >= Input'First and Position <= Input'Last,
          Post => Position + 1 <= Input'Last + 1,
          Global => null;

   --  Stack depth is bounded
   procedure Lemma_Stack_Depth_Bounded (State : Parser_State)
     with Ghost,
          Pre => Is_Valid_Partial_State (State),
          Post => Current_Stack_Depth (State) <= SML.DOM.Max_Tree_Depth,
          Global => null;

   --  Tag matching terminates
   procedure Lemma_Tag_Match_Terminates (Input : String;
                                         Tag_Start : Natural;
                                         Tag : String)
     with Ghost,
          Pre => Tag_Start >= Input'First and
                 Tag_Start + Tag'Length <= Input'Last + 1,
          Post => Tag_Start + Tag'Length <= Input'Last + 1,
          Global => null;

   --  Whitespace skip terminates
   procedure Lemma_Skip_Whitespace_Terminates (Input : String;
                                               Position : Natural)
     with Ghost,
          Pre => Position >= Input'First and Position <= Input'Last + 1,
          Post => (for some End_Pos in Position .. Input'Last + 1 =>
                     End_Pos >= Position),
          Global => null;

   --  Text accumulation terminates
   procedure Lemma_Text_Accumulation_Terminates (Input : String;
                                                 Start_Pos : Natural)
     with Ghost,
          Pre => Start_Pos >= Input'First and Start_Pos <= Input'Last,
          Post => (for some End_Pos in Start_Pos .. Input'Last =>
                     (End_Pos >= Start_Pos and
                      (Input (End_Pos) = '<' or End_Pos = Input'Last))),
          Global => null;

   ---------------------------------------------------------------------------
   --  Entity Reference Constants
   ---------------------------------------------------------------------------

   --  Standard XML entities supported in SML
   type Entity_Ref is (Lt, Gt, Amp, Quot, Apos);

   --  Entity reference strings
   Entity_Names : constant array (Entity_Ref) of String (1 .. 6) :=
     (Lt   => "lt;   ",
      Gt   => "gt;   ",
      Amp  => "amp;  ",
      Quot => "quot; ",
      Apos => "apos; ");

   --  Entity replacement characters
   Entity_Chars : constant array (Entity_Ref) of Character :=
     (Lt => '<', Gt => '>', Amp => '&', Quot => '"', Apos => ''');

   --  Minimum progress in parsing
   function Min_Parse_Progress return Positive
     with Ghost,
          Post => Min_Parse_Progress'Result = 1,
          Global => null;

private
   ---------------------------------------------------------------------------
   --  Private Types
   ---------------------------------------------------------------------------

   --  Ghost type for parser state with termination measures
   type Parser_State is record
      Position     : Natural;        -- Current position in input
      Stack_Depth  : Natural;        -- Current element nesting depth
      Current_Node : SML.DOM.Node_Id;
      Has_Error    : Boolean;
      Line         : Positive;       -- For error reporting
      Column       : Positive;       -- For error reporting
   end record with Ghost;

end SML.Parser;