------------------------------------------------------------------------------
--  SML.Grammar Package Specification
--  Formal Grammar Definition for Simple Markup Language
--  SPARK Ada Implementation for Parser Soundness/Completeness Proofs
------------------------------------------------------------------------------

package SML.Grammar with SPARK_Mode => On, Ghost is

   --  This package provides a formal, inductive definition of the SML grammar.
   --  It is used to prove parser soundness (accepts only valid SML) and
   --  completeness (accepts all valid SML).
   --  All entities are ghost code for verification only.

   ---------------------------------------------------------------------------
   --  Token Types for Lexical Analysis
   ---------------------------------------------------------------------------

   type Token_Kind is (
      --  Structural tokens
      Start_Tag_Open,     -- '<'
      Start_Tag_Close,    -- '>'
      End_Tag_Open,       -- '</'
      End_Tag_Close,      -- '>'

      --  Content tokens
      Element_Name,       -- tag name
      Text_Data,          -- character data (not '<' or '&')
      Entity_Reference,   -- &lt; &gt; &amp; &quot; &apos;

      --  Special tokens
      Whitespace,         -- spaces, tabs, newlines
      EOF                 -- end of input
   );

   --  Maximum token length for bounded analysis
   Max_Token_Length : constant Natural := 1000;
   Max_Name_Length : constant Natural := 100;

   --  Token representation with position information
   type Token is record
      Kind       : Token_Kind;
      Start_Pos  : Natural;      -- Starting position in input
      End_Pos    : Natural;      -- Ending position (exclusive)
      Value      : String (1 .. Max_Token_Length);
      Value_Len  : Natural;       -- Actual length of value
   end record
     with Predicate => End_Pos > Start_Pos and Value_Len <= Max_Token_Length;

   --  Token stream for analysis
   type Token_Stream is array (Positive range <>) of Token;

   ---------------------------------------------------------------------------
   --  Grammar Productions (BNF Rules)
   ---------------------------------------------------------------------------

   --  SML Grammar (EBNF notation):
   --  Document ::= Element
   --  Element  ::= '<' Name '>' Content '</' Name '>'
   --  Content  ::= (CharData | Element | EntityRef)*
   --  CharData ::= [^<&]*
   --  EntityRef ::= '&' ('lt' | 'gt' | 'amp' | 'quot' | 'apos') ';'
   --  Name     ::= NameStartChar NameChar*

   type Grammar_Symbol is (
      --  Non-terminals
      Document_Symbol,
      Element_Symbol,
      Content_Symbol,
      Char_Data_Symbol,
      Entity_Ref_Symbol,
      Name_Symbol,

      --  Terminals (correspond to tokens)
      Terminal_Start_Tag_Open,
      Terminal_Start_Tag_Close,
      Terminal_End_Tag_Open,
      Terminal_Name,
      Terminal_Text,
      Terminal_Entity,
      Terminal_EOF
   );

   --  Production rule: Symbol -> Sequence of symbols
   type Production_Rule is record
      Left_Side   : Grammar_Symbol;
      Right_Side  : String (1 .. 100);  -- Encoded sequence of symbols
      Right_Len   : Natural;
   end record;

   --  The complete SML grammar as production rules
   SML_Grammar : constant array (Positive range <>) of Production_Rule := (
      1 => (Left_Side => Document_Symbol,
            Right_Side => "Element_Symbol" & (others => ' '),
            Right_Len => 14),
      -- Additional rules would be encoded here
      others => (Left_Side => Document_Symbol,
                 Right_Side => (others => ' '),
                 Right_Len => 0)
   );

   ---------------------------------------------------------------------------
   --  Parse Tree Representation
   ---------------------------------------------------------------------------

   --  Node in abstract syntax tree
   type AST_Node_Kind is (
      Document_Node,
      Element_Node,
      Text_Node,
      Entity_Node,
      Empty_Node
   );

   type AST_Node;
   type AST_Node_Access is access AST_Node;

   --  Abstract syntax tree node
   type AST_Node is record
      Kind        : AST_Node_Kind;
      Start_Pos   : Natural;          -- Position in input
      End_Pos     : Natural;
      Name        : String (1 .. Max_Name_Length);  -- For elements
      Name_Len    : Natural;
      Text_Value  : String (1 .. 1000);             -- For text/entities
      Text_Len    : Natural;
      First_Child : AST_Node_Access;
      Next_Sibling : AST_Node_Access;
      Parent      : AST_Node_Access;
   end record;

   --  Parse tree is rooted AST
   type Parse_Tree is new AST_Node_Access;

   ---------------------------------------------------------------------------
   --  Inductive Validity Definition
   ---------------------------------------------------------------------------

   --  Check if string matches a specific grammar production
   function Matches_Production (Input : String;
                               Start_Pos, End_Pos : Natural;
                               Prod : Production_Rule) return Boolean
     with Pre => Start_Pos >= Input'First and End_Pos <= Input'Last and
                 Start_Pos <= End_Pos;

   --  Inductive definition: Valid SML by construction
   function Is_Valid_SML_By_Grammar (Input : String) return Boolean
     with Post => Is_Valid_SML_By_Grammar'Result =
                    (for some Tree : Parse_Tree =>
                       Derives_From_Document (Tree, Input));

   --  Check if parse tree derives from Document symbol
   function Derives_From_Document (Tree : Parse_Tree;
                                   Input : String) return Boolean
     with Pre => Tree /= null;

   --  Check if parse tree correctly represents input substring
   function Tree_Matches_Input (Tree : Parse_Tree;
                                Input : String;
                                Start_Pos, End_Pos : Natural) return Boolean
     with Pre => Tree /= null and then
                 Start_Pos >= Input'First and End_Pos <= Input'Last;

   ---------------------------------------------------------------------------
   --  Lexical Analysis Functions
   ---------------------------------------------------------------------------

   --  Tokenize input string
   function Tokenize (Input : String) return Token_Stream
     with Pre => Input'Length <= Natural'Last - 1000,
          Post => (for all T of Tokenize'Result =>
                     T.Start_Pos >= Input'First and
                     T.End_Pos <= Input'Last + 1);

   --  Get next token from position
   function Next_Token (Input : String; Pos : Natural) return Token
     with Pre => Pos >= Input'First and Pos <= Input'Last + 1,
          Post => Next_Token'Result.Start_Pos = Pos and
                  Next_Token'Result.End_Pos <= Input'Last + 1;

   --  Check if character can start a name
   function Is_Name_Start_Char (C : Character) return Boolean
     with Post => Is_Name_Start_Char'Result =
                    ((C >= 'A' and C <= 'Z') or
                     (C >= 'a' and C <= 'z') or
                     C = '_' or C = ':');

   --  Check if character can continue a name
   function Is_Name_Char (C : Character) return Boolean
     with Post => Is_Name_Char'Result =
                    (Is_Name_Start_Char (C) or
                     (C >= '0' and C <= '9') or
                     C = '-' or C = '.');

   ---------------------------------------------------------------------------
   --  Grammar Property Lemmas
   ---------------------------------------------------------------------------

   --  The grammar is unambiguous (unique parse trees)
   procedure Lemma_Grammar_Unambiguous
     with Post => (for all Input : String =>
                     (if Is_Valid_SML_By_Grammar (Input) then
                        (for all T1, T2 : Parse_Tree =>
                           (if Derives_From_Document (T1, Input) and
                               Derives_From_Document (T2, Input) then
                              Trees_Equivalent (T1, T2)))));

   --  Grammar accepts no attributes
   procedure Lemma_Grammar_No_Attributes
     with Post => (for all Input : String =>
                     (if Is_Valid_SML_By_Grammar (Input) then
                        No_Attribute_Syntax (Input)));

   --  Grammar accepts no forbidden constructs
   procedure Lemma_Grammar_No_Forbidden_Constructs
     with Post => (for all Input : String =>
                     (if Is_Valid_SML_By_Grammar (Input) then
                        No_Processing_Instructions (Input) and
                        No_DTD_Declarations (Input) and
                        No_CDATA_Sections (Input) and
                        No_Comments (Input) and
                        No_Namespaces (Input)));

   --  Grammar requires valid entity references
   procedure Lemma_Grammar_Valid_Entities
     with Post => (for all Input : String =>
                     (if Is_Valid_SML_By_Grammar (Input) then
                        Only_Standard_Entities (Input)));

   ---------------------------------------------------------------------------
   --  Helper Predicates
   ---------------------------------------------------------------------------

   --  Check if two parse trees are structurally equivalent
   function Trees_Equivalent (T1, T2 : Parse_Tree) return Boolean;

   --  Check if input contains attribute syntax
   function No_Attribute_Syntax (Input : String) return Boolean
     with Post => No_Attribute_Syntax'Result =
                    (not Contains_Pattern (Input, "="""));

   --  Check if input contains processing instructions
   function No_Processing_Instructions (Input : String) return Boolean
     with Post => No_Processing_Instructions'Result =
                    (not Contains_Pattern (Input, "<?"));

   --  Check if input contains DTD declarations
   function No_DTD_Declarations (Input : String) return Boolean
     with Post => No_DTD_Declarations'Result =
                    (not Contains_Pattern (Input, "<!DOCTYPE"));

   --  Check if input contains CDATA sections
   function No_CDATA_Sections (Input : String) return Boolean
     with Post => No_CDATA_Sections'Result =
                    (not Contains_Pattern (Input, "<![CDATA["));

   --  Check if input contains comments
   function No_Comments (Input : String) return Boolean
     with Post => No_Comments'Result =
                    (not Contains_Pattern (Input, "<!--"));

   --  Check if input contains namespace declarations
   function No_Namespaces (Input : String) return Boolean
     with Post => No_Namespaces'Result =
                    (not Contains_Pattern (Input, "xmlns"));

   --  Check if input only uses standard entity references
   function Only_Standard_Entities (Input : String) return Boolean;

   --  Pattern matching helper
   function Contains_Pattern (Input : String; Pattern : String) return Boolean
     with Pre => Pattern'Length > 0;

   ---------------------------------------------------------------------------
   --  Derivation and Proof Support
   ---------------------------------------------------------------------------

   --  A derivation is a sequence of production rule applications
   type Derivation_Step is record
      Rule_Index : Positive;        -- Index in SML_Grammar
      Position   : Natural;          -- Position in input where applied
      Result_Node : AST_Node_Access; -- Resulting AST node
   end record;

   type Derivation is array (Positive range <>) of Derivation_Step;

   --  Check if derivation produces the input string
   function Derivation_Produces (D : Derivation; Input : String) return Boolean;

   --  Check if derivation is valid (follows grammar rules)
   function Valid_Derivation (D : Derivation) return Boolean;

   --  Construct parse tree from derivation
   function Derivation_To_Tree (D : Derivation) return Parse_Tree
     with Pre => Valid_Derivation (D);

   ---------------------------------------------------------------------------
   --  Induction Principles for Proofs
   ---------------------------------------------------------------------------

   --  Structural induction on parse trees
   procedure Lemma_Parse_Tree_Induction
     (P : access function (T : Parse_Tree) return Boolean)
   with Pre =>
          -- Base case: empty/leaf nodes
          (for all T : Parse_Tree =>
             (if T.First_Child = null then P(T))) and then
          -- Inductive case: if all children satisfy P, so does parent
          (for all T : Parse_Tree =>
             (if T.First_Child /= null and then
                 (for all Child : Parse_Tree =>
                    Is_Child_Of(Child, T) -> P(Child))
              then P(T))),
        Post => (for all T : Parse_Tree => P(T));

   --  Helper: check if one tree is child of another
   function Is_Child_Of (Child, Parent : Parse_Tree) return Boolean
     with Pre => Child /= null and Parent /= null;

   ---------------------------------------------------------------------------
   --  Well-Formedness of Grammar Constructs
   ---------------------------------------------------------------------------

   --  Element names match in start/end tags
   function Matching_Tags (Input : String;
                          Start_Tag_Pos, End_Tag_Pos : Natural;
                          Name : String) return Boolean
     with Pre => Start_Tag_Pos >= Input'First and
                 End_Tag_Pos <= Input'Last and
                 Name'Length <= Max_Name_Length;

   --  Content between tags is well-formed
   function Well_Formed_Content (Input : String;
                                 Start_Pos, End_Pos : Natural) return Boolean
     with Pre => Start_Pos >= Input'First and End_Pos <= Input'Last and
                 Start_Pos <= End_Pos;

   --  Properly nested elements
   function Properly_Nested (Input : String) return Boolean
     with Post => Properly_Nested'Result =
                    (for all Pos : Natural =>
                       (if Pos in Input'Range and then Input(Pos) = '<' then
                          Has_Matching_Close(Input, Pos)));

   --  Helper: check for matching close tag
   function Has_Matching_Close (Input : String; Open_Pos : Natural) return Boolean
     with Pre => Open_Pos >= Input'First and Open_Pos <= Input'Last and
                 Input(Open_Pos) = '<';

end SML.Grammar;