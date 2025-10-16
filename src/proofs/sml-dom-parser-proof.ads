------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                SPARK Proof Support - DOM Parser Package                  --
------------------------------------------------------------------------------

package SML.DOM.Parser.Proof
with
   Ghost,
   SPARK_Mode
is

   ---------------------------------------------------------------------------
   --  Ghost Functions for Parser Verification
   ---------------------------------------------------------------------------

   --  Defines validity of an input string as SML
   function Is_Valid_SML (Input : String) return Boolean
     with
       Global => null,
       Post =>
         Is_Valid_SML'Result =
           (Has_Valid_UTF8 (Input)
            and then Has_Valid_Structure (Input)
            and then Has_No_Disallowed_Constructs (Input)
            and then Has_Valid_Entities (Input));

   --  Relates an input string to a DOM Document
   function Parses_To (Input : String; Doc : Document) return Boolean
     with Pre => Is_Well_Formed (Doc), Global => null;

   --  Input contains only valid UTF-8 sequences
   function Has_Valid_UTF8 (Input : String) return Boolean
     with Import, Global => null;

   --  Input has valid XML structure (matching tags, single root, etc.)
   function Has_Valid_Structure (Input : String) return Boolean
     with Global => null;

   --  Input contains no XML constructs forbidden in SML
   function Has_No_Disallowed_Constructs (Input : String) return Boolean
     with
       Global => null,
       Post =>
         Has_No_Disallowed_Constructs'Result =
           (No_Attributes (Input)
            and then No_Processing_Instructions (Input)
            and then No_DTD (Input)
            and then No_CDATA (Input)
            and then No_Comments (Input)
            and then No_Namespaces (Input));

   --  All entity references are valid
   function Has_Valid_Entities (Input : String) return Boolean
     with Global => null;

   ---------------------------------------------------------------------------
   --  Detailed Ghost Predicates
   ---------------------------------------------------------------------------

   --  No attributes in any element
   function No_Attributes (Input : String) return Boolean
     with Global => null;

   --  No processing instructions (<?...?>)
   function No_Processing_Instructions (Input : String) return Boolean
     with Global => null;

   --  No DOCTYPE declaration
   function No_DTD (Input : String) return Boolean
     with Global => null;

   --  No CDATA sections (<![CDATA[...]]>)
   function No_CDATA (Input : String) return Boolean
     with Global => null;

   --  No comments (<!--...-->)
   function No_Comments (Input : String) return Boolean
     with Global => null;

   --  No namespace declarations or prefixes
   function No_Namespaces (Input : String) return Boolean
     with Global => null;

   ---------------------------------------------------------------------------
   --  Parser State Ghost Functions (for proof)
   ---------------------------------------------------------------------------

   --  Initial parser state
   function Initial_State return Parser_State
     with Global => null;

   --  Parser state after consuming a portion of input
   function Parse_Step
     (State : Parser_State; Input : String; Start_Pos, End_Pos : Natural)
      return Parser_State
     with
       Pre =>
         Start_Pos >= Input'First
         and then End_Pos <= Input'Last
         and then Start_Pos <= End_Pos,
       Global => null;

   --  Checks if parser state corresponds to a complete valid parse
   function Is_Complete_Parse
     (State : Parser_State; Input : String) return Boolean
     with Global => null;

   --  Gets the partial DOM constructed so far
   function Partial_DOM (State : Parser_State) return Document
     with Pre => Is_Valid_Partial_State (State), Global => null;

   --  Checks if the parser state is valid (no errors encountered)
   function Is_Valid_Partial_State (State : Parser_State) return Boolean
     with Global => null;

end SML.DOM.Parser.Proof;
