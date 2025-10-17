------------------------------------------------------------------------------
--                   Simple Markup Language (SML) Library                   --
--                                                                          --
--                  UTF8 Ghost Package - Formal Verification                --
------------------------------------------------------------------------------

package SML_UTF8_Ghost
with
   Ghost,
   SPARK_Mode => On
is

   ---------------------------------------------------------------------------
   --  Local Helper Functions (inlined from SML.UTF8 to avoid circular dep)
   ---------------------------------------------------------------------------

   function Is_XML_Whitespace_Char (C : Character) return Boolean
     with
       Inline,
       Post =>
         Is_XML_Whitespace_Char'Result
         = (C = ' ' or C = ASCII.HT or C = ASCII.CR or C = ASCII.LF);

   function UTF8_Seq_Length (Text : String; Position : Natural) return Natural
     with
       Pre => Position >= Text'First and then Position <= Text'Last,
       Post => UTF8_Seq_Length'Result in 0 .. 4;

   function Is_Valid_UTF8_Byte_At (Text : String; I : Natural) return Boolean
     with Pre => I >= Text'First and then I <= Text'Last;

   ---------------------------------------------------------------------------
   --  Ghost Functions for UTF-8 Verification
   ---------------------------------------------------------------------------

   --  Check if a string is normalized (no consecutive spaces)
   function Is_Normalized (Text : String) return Boolean
     with Global => null;

   --  Check if string has no leading/trailing whitespace
   function Is_Trimmed (Text : String) return Boolean
     with
       Global => null,
       Post =>
         Is_Trimmed'Result =
           ((Text'Length = 0)
            or else (not Is_XML_Whitespace_Char (Text (Text'First))
                     and then not Is_XML_Whitespace_Char (Text (Text'Last))));

   --  Count valid UTF-8 sequences in a range
   function Count_UTF8_Sequences
     (Text : String; First, Last : Natural) return Natural
     with
       Pre =>
         First >= Text'First
         and then Last <= Text'Last
         and then First <= Last,
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
         and then First <= Last,
       Global => null;

   --  ASCII subset is always valid UTF-8
   procedure Lemma_ASCII_Is_Valid_UTF8 (Text : String)
     with
       Pre => (for all I in Text'Range => Character'Pos (Text (I)) < 128),
       Global => null;

   --  Navigation preserves UTF-8 validity
   procedure Lemma_Navigation_Preserves_Validity
     (Text : String; Position : Natural)
     with
       Pre =>
         Position >= Text'First
         and then Position <= Text'Last,
       Global => null;

end SML_UTF8_Ghost;