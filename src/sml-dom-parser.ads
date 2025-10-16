------------------------------------------------------------------------------
--  SML.DOM.Parser Package Specification
--  Parser and Validator for Simple Markup Language (SML)
--  SPARK Ada Implementation with Formal Verification Support
--  Child Package with Privileged Access to DOM Internals
------------------------------------------------------------------------------

package SML.DOM.Parser
  with SPARK_Mode => On
is

   --  SML.DOM.Parser: Provides parsing and validation for SML documents.
   --  Produces a DOM Document on success or a detailed error on failure.
   --  Handles all SML format rules: no attributes, no processing instructions,
   --  no DTD, no CDATA, UTF-8 only, entity references for <>&"'

   ---------------------------------------------------------------------------
   --  Error Reporting Types
   ---------------------------------------------------------------------------

   --  Enumeration of possible parse error categories
   type Error_Kind is
     (Invalid_UTF8,           -- Invalid UTF-8 byte sequence
      Malformed_Structure,    -- Well-formedness error (e.g., tag mismatch)
      Disallowed_Construct,   -- XML construct not allowed in SML
      Unexpected_EOF,         -- Input ended prematurely
      Invalid_Entity,         -- Unknown or malformed entity reference
      Depth_Exceeded,         -- Tree depth exceeds maximum
      Too_Many_Children       -- Element has too many children
     );

   --  Detailed information about a parse error
   type Parse_Error is record
      Kind       : Error_Kind;
      Position   : Natural;    -- Byte offset where error detected (0-based)
      Line       : Positive;   -- Line number (1-based)
      Column     : Positive;   -- Column number (1-based)
      Message    : String (1 .. 256);  -- Detailed error message
      Msg_Length : Natural;    -- Actual length of message
   end record;

   --  Result of parsing: either success with Document or failure with error
   type Parse_Result (Success : Boolean := False) is limited record
      case Success is
         when True =>
            Doc : Document;

         when False =>
            Error : Parse_Error;
      end case;
   end record;

   ---------------------------------------------------------------------------
   --  Main Parsing Functions
   ---------------------------------------------------------------------------

   --  Parse the given input string as SML
   function Parse (Input : String) return Parse_Result
   with
     Pre => Input'Length <= Natural'Last - 1000,  -- Prevent overflow
     Post =>
       (if Parse'Result.Success
        then
          -- Successful parse postconditions:
          Is_Well_Formed (Parse'Result.Doc)
          and then Is_Valid_SML (Input)
          and then Parses_To (Input, Parse'Result.Doc)
        else
          -- Failure postconditions:
          not Is_Valid_SML (Input)
          and then Parse'Result.Error.Position <= Input'Length
          and then Parse'Result.Error.Line >= 1
          and then Parse'Result.Error.Column >= 1),
     Global => null;

   --  Validate the input string for SML well-formedness
   function Validate (Input : String) return Boolean
   with
     Pre => Input'Length <= Natural'Last - 1000,
     Post => Validate'Result = Is_Valid_SML (Input),
     Global => null;

   --  Parse with options for whitespace handling
   type Whitespace_Mode is (Preserve_All, Normalize, Trim);

   type Parse_Options is record
      Whitespace      : Whitespace_Mode := Preserve_All;
      Expand_Entities : Boolean := True;
      Max_Depth       : Natural := Max_Tree_Depth;
   end record;

   function Parse_With_Options
     (Input : String; Options : Parse_Options) return Parse_Result
   with
     Pre =>
       Input'Length <= Natural'Last - 1000
       and then Options.Max_Depth > 0
       and then Options.Max_Depth <= Max_Tree_Depth,
     Post =>
       (if Parse_With_Options'Result.Success
        then Is_Well_Formed (Parse_With_Options'Result.Doc)),
     Global => null;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Formal Verification
   ---------------------------------------------------------------------------
   --  These are implemented in SML.DOM.Parser.Proof

   --  Defines validity of an input string as SML
   function Is_Valid_SML (Input : String) return Boolean
   with
     Ghost,
     Import,
     Global => null,
     Post =>
       Is_Valid_SML'Result
       = (Has_Valid_UTF8 (Input)
          and then Has_Valid_Structure (Input)
          and then Has_No_Disallowed_Constructs (Input)
          and then Has_Valid_Entities (Input));

   --  Relates an input string to a DOM Document
   function Parses_To (Input : String; Doc : Document) return Boolean
   with Ghost, Import, Pre => Is_Well_Formed (Doc), Global => null;

   --  Input contains only valid UTF-8 sequences
   function Has_Valid_UTF8 (Input : String) return Boolean
   with Ghost, Import, Global => null;

   --  Input has valid XML structure (matching tags, single root, etc.)
   function Has_Valid_Structure (Input : String) return Boolean
   with Ghost, Import, Global => null;

   --  Input contains no XML constructs forbidden in SML
   function Has_No_Disallowed_Constructs (Input : String) return Boolean
   with
     Ghost,
     Import,
     Global => null,
     Post =>
       Has_No_Disallowed_Constructs'Result
       = (No_Attributes (Input)
          and then No_Processing_Instructions (Input)
          and then No_DTD (Input)
          and then No_CDATA (Input)
          and then No_Comments (Input)
          and then No_Namespaces (Input));

   --  All entity references are valid
   function Has_Valid_Entities (Input : String) return Boolean
   with Ghost, Import, Global => null;

   ---------------------------------------------------------------------------
   --  Detailed Ghost Predicates
   ---------------------------------------------------------------------------

   --  No attributes in any element
   function No_Attributes (Input : String) return Boolean
   with Ghost, Import, Global => null;

   --  No processing instructions (<?...?>)
   function No_Processing_Instructions (Input : String) return Boolean
   with Ghost, Import, Global => null;

   --  No DOCTYPE declaration
   function No_DTD (Input : String) return Boolean
   with Ghost, Import, Global => null;

   --  No CDATA sections (<![CDATA[...]]>)
   function No_CDATA (Input : String) return Boolean
   with Ghost, Import, Global => null;

   --  No comments (<!--...-->)
   function No_Comments (Input : String) return Boolean
   with Ghost, Import, Global => null;

   --  No namespace declarations or prefixes
   function No_Namespaces (Input : String) return Boolean
   with Ghost, Import, Global => null;

   ---------------------------------------------------------------------------
   --  Parser State Ghost Functions (for proof)
   ---------------------------------------------------------------------------

   --  Represents the abstract state of the parser at a position
   type Parser_State is private with Ghost;

   --  Initial parser state
   function Initial_State return Parser_State
   with Ghost, Import, Global => null;

   --  Parser state after consuming a portion of input
   function Parse_Step
     (State : Parser_State; Input : String; Start_Pos, End_Pos : Natural)
      return Parser_State
   with
     Ghost,
     Import,
     Pre =>
       Start_Pos >= Input'First
       and then End_Pos <= Input'Last
       and then Start_Pos <= End_Pos,
     Global => null;

   --  Checks if parser state corresponds to a complete valid parse
   function Is_Complete_Parse
     (State : Parser_State; Input : String) return Boolean
   with Ghost, Import, Global => null;

   --  Gets the partial DOM constructed so far
   function Partial_DOM (State : Parser_State) return Document
   with Ghost, Import, Pre => Is_Valid_Partial_State (State), Global => null;

   --  Checks if the parser state is valid (no errors encountered)
   function Is_Valid_Partial_State (State : Parser_State) return Boolean
   with Ghost, Import, Global => null;

   ---------------------------------------------------------------------------
   --  Entity Reference Constants
   ---------------------------------------------------------------------------

   --  Standard XML entities supported in SML
   type Entity_Ref is (Lt, Gt, Amp, Quot, Apos);

   --  Entity reference strings
   Entity_Names : constant array (Entity_Ref) of String (1 .. 6) :=
     [Lt   => "lt;   ",
      Gt   => "gt;   ",
      Amp  => "amp;  ",
      Quot => "quot; ",
      Apos => "apos; "];

   --  Entity replacement characters
   Entity_Chars : constant array (Entity_Ref) of Character :=
     [Lt => '<', Gt => '>', Amp => '&', Quot => '"', Apos => '''];

private
   ---------------------------------------------------------------------------
   --  Private Types
   ---------------------------------------------------------------------------

   --  Ghost type for parser state
   type Parser_State is record
      Position     : Natural;
      Stack_Depth  : Natural;
      Current_Node : Node_Id;
      Has_Error    : Boolean;
   end record;

end SML.DOM.Parser;
