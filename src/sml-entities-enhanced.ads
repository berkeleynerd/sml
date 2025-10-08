------------------------------------------------------------------------------
--  SML.Entities Package Specification (Enhanced with Termination Contracts)
--  XML Entity Reference Handling for SML Parser
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

package SML.Entities with SPARK_Mode => On is

   --  SML.Entities: Handles XML character entity references.
   --  SML supports the five standard XML entities: &lt; &gt; &amp; &quot; &apos;
   --  This package provides encoding and decoding functions with formal contracts.
   --  Enhanced with termination guarantees for all loops.

   ---------------------------------------------------------------------------
   --  Entity Reference Types
   ---------------------------------------------------------------------------

   --  The five standard XML entity references
   type Standard_Entity is (Lt, Gt, Amp, Quot, Apos);

   --  Entity reference information
   type Entity_Info is record
      Kind      : Standard_Entity;
      Name      : String (1 .. 5);    -- Entity name without & and ;
      Name_Len  : Natural;             -- Actual length of name
      Char      : Character;           -- Replacement character
   end record;

   --  Standard entity definitions
   Entity_Table : constant array (Standard_Entity) of Entity_Info :=
     (Lt   => (Kind => Lt,   Name => "lt   ", Name_Len => 2, Char => '<'),
      Gt   => (Kind => Gt,   Name => "gt   ", Name_Len => 2, Char => '>'),
      Amp  => (Kind => Amp,  Name => "amp  ", Name_Len => 3, Char => '&'),
      Quot => (Kind => Quot, Name => "quot ", Name_Len => 4, Char => '"'),
      Apos => (Kind => Apos, Name => "apos ", Name_Len => 4, Char => '''));

   --  Maximum entity reference length for termination bounds
   Max_Entity_Length : constant Natural := 6;  -- &apos; is longest

   ---------------------------------------------------------------------------
   --  Entity Detection and Validation (No Loops Required)
   ---------------------------------------------------------------------------

   --  Check if character needs entity encoding in content
   function Needs_Entity_In_Content (C : Character) return Boolean
     with Global => null,
          Post => Needs_Entity_In_Content'Result = (C = '<' or C = '>' or C = '&');

   --  Check if character needs entity encoding in attribute value
   function Needs_Entity_In_Attribute (C : Character) return Boolean
     with Global => null,
          Post => Needs_Entity_In_Attribute'Result =
                    (C = '<' or C = '>' or C = '&' or C = '"' or C = ''');

   --  Check if string at position starts with an entity reference
   function Is_Entity_Reference (Text : String; Position : Natural)
                                return Boolean
     with Pre => Position >= Text'First and then Position <= Text'Last,
          Global => null,
          Post => Is_Entity_Reference'Result =
                    (Text (Position) = '&' and then
                     Has_Valid_Entity_At (Text, Position));

   --  Check if there's a valid entity starting at position
   --  Implementation: bounded scan for semicolon (max 6 chars)
   --  Loop variant: Min(Remaining_Length, Max_Entity_Length) - Offset
   function Has_Valid_Entity_At (Text : String; Position : Natural)
                                return Boolean
     with Pre => Position >= Text'First and then Position <= Text'Last
                 and then Text (Position) = '&',
          Global => null,
          Contract_Cases =>
            (Text'Last - Position < 2 =>  -- Too short for any entity
               not Has_Valid_Entity_At'Result,
             Text'Last - Position >= 2 =>
               Has_Valid_Entity_At'Result =
                 (for some E in Standard_Entity =>
                    Text'Last - Position >= Entity_Table(E).Name_Len + 1 and then
                    Text(Position + 1 .. Position + Entity_Table(E).Name_Len) =
                      Entity_Table(E).Name(1 .. Entity_Table(E).Name_Len) and then
                    Text(Position + Entity_Table(E).Name_Len + 1) = ';'));

   --  Get the entity kind at a position (if valid)
   --  Direct lookup - no loops
   function Get_Entity_At (Text : String; Position : Natural)
                          return Standard_Entity
     with Pre => Position >= Text'First and then Position <= Text'Last
                 and then Has_Valid_Entity_At (Text, Position),
          Global => null;

   --  Get the length of entity reference at position (including & and ;)
   --  Direct computation - no loops
   function Entity_Length_At (Text : String; Position : Natural)
                             return Natural
     with Pre => Position >= Text'First and then Position <= Text'Last
                 and then Has_Valid_Entity_At (Text, Position),
          Post => Entity_Length_At'Result >= 4 and then  -- Minimum: &lt;
                  Entity_Length_At'Result <= 6 and then  -- Maximum: &apos;
                  Position + Entity_Length_At'Result - 1 <= Text'Last,
          Global => null;

   ---------------------------------------------------------------------------
   --  Entity Expansion Functions with Termination Guarantees
   ---------------------------------------------------------------------------

   --  Expand all entity references in a string
   --  Main loop variant: Text'Last - Source_Position + 1
   --  Invariant: Output_Position <= Source_Position (output never longer)
   function Expand_Entities (Text : String) return String
     with Post => Expand_Entities'Result'Length <= Text'Length and then
                  No_Entity_References (Expand_Entities'Result) and then
                  (if No_Entity_References (Text) then
                     Expand_Entities'Result = Text),
          Global => null;

   --  Expand entities in a range
   --  Loop variant: Last - Current_Position + 1
   function Expand_Entities_Range (Text : String; First, Last : Natural)
                                  return String
     with Pre => First >= Text'First and then Last <= Text'Last
                 and then First <= Last,
          Post => Expand_Entities_Range'Result'Length <= Last - First + 1 and then
                  No_Entity_References (Expand_Entities_Range'Result),
          Global => null;

   --  Count how many characters the expanded text will have
   --  Loop variant: Text'Last - Position + 1
   --  Each iteration advances by at least 1 (regular char) or entity length
   function Expanded_Length (Text : String) return Natural
     with Post => Expanded_Length'Result <= Text'Length and then
                  (if No_Entity_References (Text) then
                     Expanded_Length'Result = Text'Length),
          Global => null;

   --  Check if string contains no entity references
   --  Loop variant: Text'Last - Position + 1
   function No_Entity_References (Text : String) return Boolean
     with Global => null,
          Post => No_Entity_References'Result =
                    (for all I in Text'Range => Text (I) /= '&'),
          Contract_Cases =>
            (Text'Length = 0 => No_Entity_References'Result,
             Text'Length > 0 =>
               No_Entity_References'Result = (Text'First .. Text'Last =>
                 (for all I in Text'Range => Text(I) /= '&')));

   ---------------------------------------------------------------------------
   --  Entity Encoding Functions with Termination
   ---------------------------------------------------------------------------

   --  Encode special characters as entity references
   --  Loop variant: Text'Last - Source_Position + 1
   --  Output can grow (worst case: all chars need encoding)
   --  Max growth factor: 6 (& becomes &amp;)
   function Encode_Entities (Text : String; In_Attribute : Boolean := False)
                           return String
     with Post => Is_Entity_Safe (Encode_Entities'Result, In_Attribute) and then
                  Encode_Entities'Result'Length <= Text'Length * Max_Entity_Length,
          Global => null;

   --  Get entity reference string for a character
   --  Direct table lookup - no loops
   function Get_Entity_For_Char (C : Character) return String
     with Pre => Needs_Entity_In_Attribute (C),
          Post => Get_Entity_For_Char'Result'Length >= 4 and then
                  Get_Entity_For_Char'Result'Length <= 6 and then
                  Get_Entity_For_Char'Result (Get_Entity_For_Char'Result'First) = '&' and then
                  Get_Entity_For_Char'Result (Get_Entity_For_Char'Result'Last) = ';',
          Global => null;

   --  Check if text is safe (all special chars are encoded)
   --  Loop variant: Text'Last - Position + 1
   function Is_Entity_Safe (Text : String; In_Attribute : Boolean)
                          return Boolean
     with Global => null,
          Post => Is_Entity_Safe'Result =
                    (if In_Attribute then
                       (for all I in Text'Range =>
                          (if Needs_Entity_In_Attribute (Text (I)) then
                             Text (I) = '&' and then Has_Valid_Entity_At (Text, I)))
                     else
                       (for all I in Text'Range =>
                          (if Needs_Entity_In_Content (Text (I)) then
                             Text (I) = '&' and then Has_Valid_Entity_At (Text, I))));

   ---------------------------------------------------------------------------
   --  Error Detection with Termination
   ---------------------------------------------------------------------------

   type Entity_Error_Kind is (
      No_Error,
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
   --  Loop variant: Text'Last - Position + 1
   --  Each ampersand is checked with bounded lookahead
   function Check_Entities (Text : String) return Entity_Check_Result
     with Global => null,
          Post => (if Check_Entities'Result.Valid then
                     Check_Entities'Result.Error_Kind = No_Error and then
                     All_Entities_Valid (Text)
                   else
                     Check_Entities'Result.Error_Kind /= No_Error and then
                     Check_Entities'Result.Error_Position in Text'Range),
          Contract_Cases =>
            (Text'Length = 0 =>
               Check_Entities'Result.Valid and
               Check_Entities'Result.Error_Kind = No_Error,
             Text'Length > 0 =>
               (Check_Entities'Result.Valid or
                Check_Entities'Result.Error_Position in Text'Range));

   --  Check if all ampersands in text are part of valid entities
   --  Loop variant: Text'Last - Position + 1
   function All_Entities_Valid (Text : String) return Boolean
     with Global => null,
          Post => All_Entities_Valid'Result =
                    (for all I in Text'Range =>
                       (if Text (I) = '&' then Has_Valid_Entity_At (Text, I)));

   ---------------------------------------------------------------------------
   --  Ghost Functions for Proof with Termination
   ---------------------------------------------------------------------------

   --  Count entity references in a string
   --  Loop variant: Text'Last - Position + 1
   function Count_Entity_References (Text : String) return Natural
     with Ghost,
          Post => Count_Entity_References'Result <= Text'Length / 3,  -- Min entity is &x;
          Global => null;

   --  Measure for entity scanning loops
   function Entity_Scan_Measure (Text : String; Position : Natural) return Natural
     with Ghost,
          Pre => Position >= Text'First and Position <= Text'Last + 1,
          Post => Entity_Scan_Measure'Result = Text'Last - Position + 1,
          Global => null;

   --  Check if expansion preserves content semantics
   function Expansion_Preserves_Content (Original, Expanded : String)
                                        return Boolean
     with Ghost,
          Pre => All_Entities_Valid (Original) and then
                 No_Entity_References (Expanded),
          Global => null;

   --  Check if encoding is reversible
   function Encoding_Is_Reversible (Original : String;
                                    In_Attribute : Boolean) return Boolean
     with Ghost,
          Global => null,
          Post => Encoding_Is_Reversible'Result =
                    (Expand_Entities (Encode_Entities (Original, In_Attribute)) = Original);

   --  Minimum progress in entity scanning
   function Min_Entity_Scan_Progress return Positive
     with Ghost,
          Post => Min_Entity_Scan_Progress'Result = 1,
          Global => null;

   ---------------------------------------------------------------------------
   --  Lemmas for Entity Properties and Termination
   ---------------------------------------------------------------------------

   --  Expansion never increases length
   procedure Lemma_Expansion_Reduces_Length (Text : String)
   with Ghost,
        Pre => All_Entities_Valid (Text),
        Post => Expand_Entities (Text)'Length <= Text'Length,
        Global => null;

   --  Encoding is safe
   procedure Lemma_Encoding_Is_Safe (Text : String; In_Attribute : Boolean)
   with Ghost,
        Post => Is_Entity_Safe (Encode_Entities (Text, In_Attribute), In_Attribute),
        Global => null;

   --  Double encoding is idempotent
   procedure Lemma_Double_Encoding_Idempotent (Text : String;
                                               In_Attribute : Boolean)
   with Ghost,
        Pre => Is_Entity_Safe (Text, In_Attribute),
        Post => Encode_Entities (Text, In_Attribute) = Text,
        Global => null;

   --  Valid entities can be expanded
   procedure Lemma_Valid_Entities_Expandable (Text : String)
   with Ghost,
        Pre => All_Entities_Valid (Text),
        Post => No_Entity_References (Expand_Entities (Text)),
        Global => null;

   --  Entity at position has valid bounds
   procedure Lemma_Entity_Bounds (Text : String; Position : Natural)
   with Ghost,
        Pre => Position >= Text'First and then Position <= Text'Last
               and then Has_Valid_Entity_At (Text, Position),
        Post => Position + Entity_Length_At (Text, Position) - 1 <= Text'Last and then
                Entity_Length_At (Text, Position) <= Max_Entity_Length,
        Global => null;

   --  Entity references have minimum length (critical for termination)
   procedure Lemma_Entity_Minimum_Length (Text : String; Position : Natural)
   with Ghost,
        Pre => Position >= Text'First and then Position <= Text'Last
               and then Has_Valid_Entity_At (Text, Position),
        Post => Entity_Length_At (Text, Position) >= 3,  -- Minimum: &x;
        Global => null;

   --  Forward progress is guaranteed in entity scanning
   procedure Lemma_Entity_Scan_Progress (Text : String; Position : Natural)
   with Ghost,
        Pre => Position >= Text'First and then Position <= Text'Last,
        Post => (if Text (Position) = '&' and then Has_Valid_Entity_At (Text, Position) then
                   Position + Entity_Length_At (Text, Position) > Position + Min_Entity_Scan_Progress
                 else
                   Position + 1 > Position),
        Global => null;

   --  Encoding has bounded growth
   procedure Lemma_Encoding_Bounded_Growth (Text : String)
   with Ghost,
        Post => Encode_Entities (Text)'Length <= Text'Length * Max_Entity_Length,
        Global => null;

end SML.Entities;