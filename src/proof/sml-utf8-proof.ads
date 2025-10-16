------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                     SPARK Proof Support - UTF8 Package                   --
------------------------------------------------------------------------------

package SML.UTF8.Proof
with
   Ghost,
   SPARK_Mode
is

   ---------------------------------------------------------------------------
   --  Ghost Functions for UTF-8 Verification
   ---------------------------------------------------------------------------

   --  Check if a string is normalized (no consecutive spaces)
   function Is_Normalized (Text : String) return Boolean
     with Pre => Is_Valid_UTF8 (Text), Global => null;

   --  Check if string has no leading/trailing whitespace
   function Is_Trimmed (Text : String) return Boolean
     with
       Pre => Is_Valid_UTF8 (Text),
       Global => null,
       Post =>
         Is_Trimmed'Result =
           ((Text'Length = 0)
            or else (not Is_XML_Whitespace (Text (Text'First))
                     and then not Is_XML_Whitespace (Text (Text'Last))));

   --  Count valid UTF-8 sequences in a range
   function Count_UTF8_Sequences
     (Text : String; First, Last : Natural) return Natural
     with
       Pre =>
         First >= Text'First
         and then Last <= Text'Last
         and then First <= Last
         and then Is_Valid_UTF8 (Text),
       Post => Count_UTF8_Sequences'Result <= Last - First + 1,
       Global => null;

   ---------------------------------------------------------------------------
   --  Lemmas for UTF-8 Properties
   ---------------------------------------------------------------------------

   --  Valid UTF-8 substring implies valid whole string at those positions
   procedure Lemma_Substring_Valid (Text : String; First, Last : Natural)
     with
       Pre =>
         First >= Text'First
         and then Last <= Text'Last
         and then First <= Last
         and then Is_Valid_UTF8_Range (Text, First, Last),
       Post => (for all I in First .. Last => Is_Valid_UTF8_At (Text, I)),
       Global => null;

   --  ASCII subset is always valid UTF-8
   procedure Lemma_ASCII_Is_Valid_UTF8 (Text : String)
     with
       Pre => (for all I in Text'Range => Is_ASCII (Text (I))),
       Post => Is_Valid_UTF8 (Text),
       Global => null;

   --  Navigation preserves UTF-8 validity
   procedure Lemma_Navigation_Preserves_Validity
     (Text : String; Position : Natural)
     with
       Pre =>
         Position >= Text'First
         and then Position <= Text'Last
         and then Is_Valid_UTF8 (Text),
       Post =>
         (if Next_UTF8_Position (Text, Position) <= Text'Last
          then Is_Valid_UTF8_At (Text, Next_UTF8_Position (Text, Position))),
       Global => null;

end SML.UTF8.Proof;
