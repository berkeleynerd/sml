------------------------------------------------------------------------------
--  SML.Entities Package Specification
--  XML Entity Reference Handling for SML Parser
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML_Entities_Ghost;

package SML.Entities
  with SPARK_Mode => On
is

   --  SML.Entities: Handles XML character entity references.
   --  SML supports the five standard XML entities: &lt; &gt; &amp; &quot; &apos;
   --  This package provides encoding and decoding functions with formal contracts.

   ---------------------------------------------------------------------------
   --  Entity Reference Types
   ---------------------------------------------------------------------------

   --  The five standard XML entity references
   type Standard_Entity is (Lt, Gt, Amp, Quot, Apos);

   --  Entity reference information
   type Entity_Info is record
      Kind     : Standard_Entity;
      Name     : String (1 .. 5);    -- Entity name without & and ;
      Name_Len : Natural;             -- Actual length of name
      Char     : Character;           -- Replacement character
   end record;

   --  Standard entity definitions
   Entity_Table : constant array (Standard_Entity) of Entity_Info :=
     [Lt   => (Kind => Lt, Name => "lt   ", Name_Len => 2, Char => '<'),
      Gt   => (Kind => Gt, Name => "gt   ", Name_Len => 2, Char => '>'),
      Amp  => (Kind => Amp, Name => "amp  ", Name_Len => 3, Char => '&'),
      Quot => (Kind => Quot, Name => "quot ", Name_Len => 4, Char => '"'),
      Apos => (Kind => Apos, Name => "apos ", Name_Len => 4, Char => ''')];

   ---------------------------------------------------------------------------
   --  Entity Detection and Validation
   ---------------------------------------------------------------------------

   --  Check if character needs entity encoding in content
   function Needs_Entity_In_Content (C : Character) return Boolean
   with
     Global => null,
     Post => Needs_Entity_In_Content'Result = (C = '<' or C = '>' or C = '&');

   --  Check if character needs entity encoding in attribute value
   function Needs_Entity_In_Attribute (C : Character) return Boolean
   with
     Global => null,
     Post =>
       Needs_Entity_In_Attribute'Result
       = (C = '<' or C = '>' or C = '&' or C = '"' or C = ''');

   --  Check if string at position starts with an entity reference
   function Is_Entity_Reference
     (Text : String; Position : Natural) return Boolean
   with
     Pre => Position >= Text'First and then Position <= Text'Last,
     Global => null,
     Post =>
       Is_Entity_Reference'Result
       = (Text (Position) = '&' and then Has_Valid_Entity_At (Text, Position));

   --  Check if there's a valid entity starting at position
   function Has_Valid_Entity_At
     (Text : String; Position : Natural) return Boolean
   with
     Pre =>
       Position >= Text'First
       and then Position <= Text'Last
       and then Text (Position) = '&',
     Global => null;

   --  Get the entity kind at a position (if valid)
   function Get_Entity_At
     (Text : String; Position : Natural) return Standard_Entity
   with
     Pre =>
       Position >= Text'First
       and then Position <= Text'Last
       and then Has_Valid_Entity_At (Text, Position),
     Global => null;

   --  Get the length of entity reference at position (including & and ;)
   function Entity_Length_At (Text : String; Position : Natural) return Natural
   with
     Pre =>
       Position >= Text'First
       and then Position <= Text'Last
       and then Has_Valid_Entity_At (Text, Position),
     Post =>
       Entity_Length_At'Result >= 4
       and then  -- Minimum: &lt;
                                  Entity_Length_At'Result
                                  <= 6
       and then  -- Maximum: &apos;
                                    Position
                                    + Entity_Length_At'Result
                                    - 1
                                    <= Text'Last,
     Global => null;

   ---------------------------------------------------------------------------
   --  Entity Expansion Functions
   ---------------------------------------------------------------------------

   --  Expand all entity references in a string
   function Expand_Entities (Text : String) return String
   with
     Post =>
       Expand_Entities'Result'Length <= Text'Length
       and then No_Entity_References (Expand_Entities'Result),
     Global => null;

   --  Expand entities in a range
   function Expand_Entities_Range
     (Text : String; First, Last : Natural) return String
   with
     Pre =>
       First >= Text'First and then Last <= Text'Last and then First <= Last,
     Post => Expand_Entities_Range'Result'Length <= Last - First + 1,
     Global => null;

   --  Count how many characters the expanded text will have
   function Expanded_Length (Text : String) return Natural
   with Post => Expanded_Length'Result <= Text'Length, Global => null;

   --  Check if string contains no entity references
   function No_Entity_References (Text : String) return Boolean
   with
     Global => null,
     Post =>
       No_Entity_References'Result
       = (for all I in Text'Range => Text (I) /= '&');

   ---------------------------------------------------------------------------
   --  Entity Encoding Functions
   ---------------------------------------------------------------------------

   --  Encode special characters as entity references
   function Encode_Entities
     (Text : String; In_Attribute : Boolean := False) return String
   with
     Post => Is_Entity_Safe (Encode_Entities'Result, In_Attribute),
     Global => null;

   --  Get entity reference string for a character
   function Get_Entity_For_Char (C : Character) return String
   with
     Pre => Needs_Entity_In_Attribute (C),
     Post =>
       Get_Entity_For_Char'Result'Length >= 4
       and then Get_Entity_For_Char'Result'Length <= 6
       and then Get_Entity_For_Char'Result (Get_Entity_For_Char'Result'First)
                = '&'
       and then Get_Entity_For_Char'Result (Get_Entity_For_Char'Result'Last)
                = ';',
     Global => null;

   --  Check if text is safe (all special chars are encoded)
   function Is_Entity_Safe
     (Text : String; In_Attribute : Boolean) return Boolean
   with
     Global => null,
     Post =>
       Is_Entity_Safe'Result
       = (if In_Attribute
          then
            (for all I in Text'Range
             => (if Needs_Entity_In_Attribute (Text (I))
                 then Text (I) = '&' and then Has_Valid_Entity_At (Text, I)))
          else
            (for all I in Text'Range
             => (if Needs_Entity_In_Content (Text (I))
                 then Text (I) = '&' and then Has_Valid_Entity_At (Text, I))));

   ---------------------------------------------------------------------------
   --  Error Detection
   ---------------------------------------------------------------------------

   type Entity_Error_Kind is
     (No_Error,
      Invalid_Entity_Name,     -- Unknown entity name
      Unterminated_Entity,     -- Missing semicolon
      Bare_Ampersand          -- & not followed by entity name
     );

   type Entity_Check_Result is record
      Valid          : Boolean;
      Error_Kind     : Entity_Error_Kind;
      Error_Position : Natural;
   end record;

   --  Check text for entity reference errors
   function Check_Entities (Text : String) return Entity_Check_Result
   with
     Global => null,
     Post =>
       (if Check_Entities'Result.Valid
        then
          Check_Entities'Result.Error_Kind = No_Error
          and then All_Entities_Valid (Text)
        else
          Check_Entities'Result.Error_Kind /= No_Error
          and then Check_Entities'Result.Error_Position in Text'Range);

   --  Check if all ampersands in text are part of valid entities
   function All_Entities_Valid (Text : String) return Boolean
   with
     Global => null,
     Post =>
       All_Entities_Valid'Result
       = (for all I in Text'Range
          => (if Text (I) = '&' then Has_Valid_Entity_At (Text, I)));

   ---------------------------------------------------------------------------
   --  Ghost Functions for Proof
   ---------------------------------------------------------------------------
   --  These are now implemented in SML_Entities_Ghost (no Import needed)

   function Count_Entity_References (Text : String) return Natural
     renames SML_Entities_Ghost.Count_Entity_References;

   function Expansion_Preserves_Content
     (Original, Expanded : String) return Boolean
     renames SML_Entities_Ghost.Expansion_Preserves_Content;

   function Encoding_Is_Reversible
     (Original : String; In_Attribute : Boolean) return Boolean
     renames SML_Entities_Ghost.Encoding_Is_Reversible;

   ---------------------------------------------------------------------------
   --  Lemmas for Entity Properties
   ---------------------------------------------------------------------------

   procedure Lemma_Expansion_Reduces_Length (Text : String)
     renames SML_Entities_Ghost.Lemma_Expansion_Reduces_Length;

   procedure Lemma_Encoding_Is_Safe (Text : String; In_Attribute : Boolean)
     renames SML_Entities_Ghost.Lemma_Encoding_Is_Safe;

   procedure Lemma_Double_Encoding_Idempotent
     (Text : String; In_Attribute : Boolean)
     renames SML_Entities_Ghost.Lemma_Double_Encoding_Idempotent;

   procedure Lemma_Valid_Entities_Expandable (Text : String)
     renames SML_Entities_Ghost.Lemma_Valid_Entities_Expandable;

   procedure Lemma_Entity_Bounds (Text : String; Position : Natural)
     renames SML_Entities_Ghost.Lemma_Entity_Bounds;

end SML.Entities;
