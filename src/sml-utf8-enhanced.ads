------------------------------------------------------------------------------
--  SML.UTF8 Package Specification (Enhanced with Termination Contracts)
--  UTF-8 Validation and Processing for SML Parser
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

package SML.UTF8
  with SPARK_Mode => On
is

   --  SML.UTF8: Provides UTF-8 validation and processing functions
   --  for the SML parser. All strings in SML must be valid UTF-8.
   --  Enhanced with formal termination contracts for loop variants.

   ---------------------------------------------------------------------------
   --  UTF-8 Validation Functions with Termination Contracts
   ---------------------------------------------------------------------------

   --  Check if a string contains valid UTF-8 byte sequences
   --  Implementation uses loop with variant: Text'Last - Position + 1
   function Is_Valid_UTF8 (Text : String) return Boolean
   with
     Global => null,
     Post =>
       Is_Valid_UTF8'Result
       = (for all I in Text'Range => Is_Valid_UTF8_At (Text, I)),
     Contract_Cases =>
       (Text'Length = 0 => Is_Valid_UTF8'Result,
        Text'Length > 0 => Is_Valid_UTF8'Result = Validate_UTF8 (Text).Valid);

   --  Check if the byte at position I starts a valid UTF-8 sequence
   --  No loops required - direct byte pattern matching
   function Is_Valid_UTF8_At (Text : String; I : Natural) return Boolean
   with Pre => I >= Text'First and then I <= Text'Last, Global => null;

   --  Validate a substring for UTF-8 correctness
   --  Loop variant: Last - Current_Pos + 1
   function Is_Valid_UTF8_Range
     (Text : String; First, Last : Natural) return Boolean
   with
     Pre =>
       First >= Text'First and then Last <= Text'Last and then First <= Last,
     Global => null,
     Post =>
       Is_Valid_UTF8_Range'Result
       = (for all I in First .. Last => Is_Valid_UTF8_At (Text, I));

   ---------------------------------------------------------------------------
   --  UTF-8 Character Classification (No Loops Required)
   ---------------------------------------------------------------------------

   --  Check if byte is a UTF-8 continuation byte (10xxxxxx)
   function Is_Continuation_Byte (B : Character) return Boolean
   with
     Global => null,
     Post =>
       Is_Continuation_Byte'Result = (Character'Pos (B) in 16#80# .. 16#BF#);

   --  Check if byte starts a multi-byte UTF-8 sequence
   function Is_Multi_Byte_Start (B : Character) return Boolean
   with
     Global => null,
     Post => Is_Multi_Byte_Start'Result = (Character'Pos (B) >= 16#C0#);

   --  Get the number of bytes in a UTF-8 sequence starting at position
   --  Direct computation from first byte - no loops
   function UTF8_Sequence_Length
     (Text : String; Position : Natural) return Natural
   with
     Pre => Position >= Text'First and then Position <= Text'Last,
     Post => UTF8_Sequence_Length'Result in 0 .. 4,
     Global => null;

   --  Check if character is ASCII (single-byte UTF-8)
   function Is_ASCII (C : Character) return Boolean
   with Global => null, Post => Is_ASCII'Result = (Character'Pos (C) < 128);

   ---------------------------------------------------------------------------
   --  UTF-8 Navigation Functions with Termination Guarantees
   ---------------------------------------------------------------------------

   --  Move to the next UTF-8 character boundary
   --  Loop variant: Text'Last - Current + 1 (skipping continuation bytes)
   function Next_UTF8_Position
     (Text : String; Position : Natural) return Natural
   with
     Pre =>
       Position >= Text'First
       and then Position <= Text'Last
       and then Is_Valid_UTF8 (Text),
     Post =>
       Next_UTF8_Position'Result > Position
       and then Next_UTF8_Position'Result <= Text'Last + 1
       and then Next_UTF8_Position'Result
                <= Position + 4,  -- Max UTF-8 sequence
     Global => null;

   --  Move to the previous UTF-8 character boundary
   --  Loop variant: Current - Text'First (scanning backwards)
   function Previous_UTF8_Position
     (Text : String; Position : Natural) return Natural
   with
     Pre =>
       Position > Text'First
       and then Position <= Text'Last + 1
       and then Is_Valid_UTF8 (Text),
     Post =>
       Previous_UTF8_Position'Result < Position
       and then Previous_UTF8_Position'Result >= Text'First
       and then Position - Previous_UTF8_Position'Result
                <= 4,  -- Max UTF-8 sequence
     Global => null;

   --  Count UTF-8 characters (code points) in a string
   --  Loop variant: Text'Last - Current_Position + 1
   function UTF8_Length (Text : String) return Natural
   with
     Pre => Is_Valid_UTF8 (Text),
     Post =>
       UTF8_Length'Result <= Text'Length
       and then (if Text'Length = 0 then UTF8_Length'Result = 0)
       and then (if (for all C of Text => Is_ASCII (C))
                 then UTF8_Length'Result = Text'Length),
     Global => null;

   ---------------------------------------------------------------------------
   --  UTF-8 Validation Error Information
   ---------------------------------------------------------------------------

   type UTF8_Error_Kind is
     (No_Error,
      Truncated_Sequence,      -- Incomplete multi-byte sequence
      Invalid_Start_Byte,      -- Invalid first byte of sequence
      Invalid_Continuation,    -- Expected continuation byte missing
      Overlong_Encoding,       -- Non-shortest form encoding
      Surrogate_Half,          -- UTF-16 surrogate half (invalid in UTF-8)
      Out_Of_Range            -- Code point > U+10FFFF
     );

   type UTF8_Validation_Result is record
      Valid          : Boolean;
      Error_Kind     : UTF8_Error_Kind;
      Error_Position : Natural;
   end record;

   --  Detailed UTF-8 validation with error reporting
   --  Main loop variant: Text'Last - Position + 1
   function Validate_UTF8 (Text : String) return UTF8_Validation_Result
   with
     Global => null,
     Post =>
       (if Validate_UTF8'Result.Valid
        then
          Validate_UTF8'Result.Error_Kind = No_Error
          and then Is_Valid_UTF8 (Text)
        else
          Validate_UTF8'Result.Error_Kind /= No_Error
          and then Validate_UTF8'Result.Error_Position in Text'Range
          and then not Is_Valid_UTF8 (Text)),
     Contract_Cases =>
       (Text'Length = 0 =>
          Validate_UTF8'Result.Valid
          and Validate_UTF8'Result.Error_Kind = No_Error,
        Text'Length > 0 =>
          (Validate_UTF8'Result.Valid
           or Validate_UTF8'Result.Error_Position in Text'Range));

   ---------------------------------------------------------------------------
   --  UTF-8 Code Point Extraction
   ---------------------------------------------------------------------------

   subtype UTF8_Code_Point is Natural range 0 .. 16#10FFFF#;

   --  Extract the Unicode code point at a position
   --  Direct computation from bytes - no loops
   function Get_Code_Point
     (Text : String; Position : Natural) return UTF8_Code_Point
   with
     Pre =>
       Position >= Text'First
       and then Position <= Text'Last
       and then Is_Valid_UTF8_At (Text, Position),
     Global => null;

   --  Check if code point is valid Unicode
   function Is_Valid_Code_Point (Code : Natural) return Boolean
   with
     Global => null,
     Post =>
       Is_Valid_Code_Point'Result
       = (Code <= 16#10FFFF#
          and then Code not in 16#D800# .. 16#DFFF#);  -- Not surrogate

   ---------------------------------------------------------------------------
   --  XML Character Validity
   ---------------------------------------------------------------------------

   --  Check if character is valid in XML 1.0 content
   function Is_Valid_XML_Char (Code : UTF8_Code_Point) return Boolean
   with
     Global => null,
     Post =>
       Is_Valid_XML_Char'Result
       = (Code = 16#09#
          or Code = 16#0A#
          or Code = 16#0D#
          or (Code >= 16#20# and Code <= 16#D7FF#)
          or (Code >= 16#E000# and Code <= 16#FFFD#)
          or (Code >= 16#10000# and Code <= 16#10FFFF#));

   --  Check if character is valid in XML names (simplified)
   function Is_Valid_Name_Start_Char (Code : UTF8_Code_Point) return Boolean
   with Global => null;

   function Is_Valid_Name_Char (Code : UTF8_Code_Point) return Boolean
   with Global => null;

   ---------------------------------------------------------------------------
   --  Whitespace Handling with Termination
   ---------------------------------------------------------------------------

   --  Check if character is XML whitespace
   function Is_XML_Whitespace (C : Character) return Boolean
   with
     Global => null,
     Post =>
       Is_XML_Whitespace'Result
       = (C = ' ' or C = ASCII.HT or C = ASCII.CR or C = ASCII.LF);

   --  Check if code point is XML whitespace
   function Is_XML_Whitespace_Code (Code : UTF8_Code_Point) return Boolean
   with
     Global => null,
     Post =>
       Is_XML_Whitespace_Code'Result
       = (Code = 16#20# or Code = 16#09# or Code = 16#0D# or Code = 16#0A#);

   --  Normalize whitespace in a string (for normalized mode)
   --  Loop variant: Text'Last - Read_Position + 1
   --  Additional invariant: Write_Position <= Read_Position
   function Normalize_Whitespace (Text : String) return String
   with
     Pre => Is_Valid_UTF8 (Text),
     Post =>
       Is_Valid_UTF8 (Normalize_Whitespace'Result)
       and then Normalize_Whitespace'Result'Length <= Text'Length
       and then Is_Normalized (Normalize_Whitespace'Result),
     Global => null;

   --  Trim leading and trailing whitespace
   --  Two loops: forward scan, then backward scan
   --  Variants: Last - First + 1 (forward), First - Text'First (backward)
   function Trim_Whitespace (Text : String) return String
   with
     Pre => Is_Valid_UTF8 (Text),
     Post =>
       Is_Valid_UTF8 (Trim_Whitespace'Result)
       and then Trim_Whitespace'Result'Length <= Text'Length
       and then Is_Trimmed (Trim_Whitespace'Result),
     Global => null;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Proof with Termination Properties
   ---------------------------------------------------------------------------

   --  Check if a string is normalized (no consecutive spaces)
   function Is_Normalized (Text : String) return Boolean
   with
     Ghost,
     Pre => Is_Valid_UTF8 (Text),
     Global => null,
     Post =>
       Is_Normalized'Result
       = (for all I in Text'First .. Text'Last - 1
          => not (Is_XML_Whitespace (Text (I))
                  and Is_XML_Whitespace (Text (I + 1))));

   --  Check if string has no leading/trailing whitespace
   function Is_Trimmed (Text : String) return Boolean
   with
     Ghost,
     Pre => Is_Valid_UTF8 (Text),
     Global => null,
     Post =>
       Is_Trimmed'Result
       = ((Text'Length = 0)
          or else (not Is_XML_Whitespace (Text (Text'First))
                   and then not Is_XML_Whitespace (Text (Text'Last))));

   --  Count valid UTF-8 sequences in a range
   --  Ghost function with explicit termination measure
   function Count_UTF8_Sequences
     (Text : String; First, Last : Natural) return Natural
   with
     Ghost,
     Pre =>
       First >= Text'First
       and then Last <= Text'Last
       and then First <= Last
       and then Is_Valid_UTF8 (Text),
     Post =>
       Count_UTF8_Sequences'Result <= Last - First + 1
       and then Count_UTF8_Sequences'Result >= (Last - First + 1) / 4,
     Global => null;

   ---------------------------------------------------------------------------
   --  Termination-Specific Ghost Functions
   ---------------------------------------------------------------------------

   --  Measure for UTF-8 validation loops
   function UTF8_Scan_Measure
     (Text : String; Position : Natural) return Natural
   with
     Ghost,
     Pre => Position >= Text'First and Position <= Text'Last + 1,
     Post => UTF8_Scan_Measure'Result = Text'Last - Position + 1,
     Global => null;

   --  Measure for backward scanning
   function UTF8_Backscan_Measure
     (Text : String; Position : Natural) return Natural
   with
     Ghost,
     Pre => Position >= Text'First and Position <= Text'Last + 1,
     Post => UTF8_Backscan_Measure'Result = Position - Text'First,
     Global => null;

   --  Progress guarantee for UTF-8 navigation
   function Min_UTF8_Progress return Positive
   with Ghost, Post => Min_UTF8_Progress'Result = 1, Global => null;

   ---------------------------------------------------------------------------
   --  Lemmas for UTF-8 Properties and Termination
   ---------------------------------------------------------------------------

   --  Valid UTF-8 substring implies valid whole string at those positions
   procedure Lemma_Substring_Valid (Text : String; First, Last : Natural)
   with
     Ghost,
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
     Ghost,
     Pre => (for all I in Text'Range => Is_ASCII (Text (I))),
     Post => Is_Valid_UTF8 (Text),
     Global => null;

   --  Navigation preserves UTF-8 validity
   procedure Lemma_Navigation_Preserves_Validity
     (Text : String; Position : Natural)
   with
     Ghost,
     Pre =>
       Position >= Text'First
       and then Position <= Text'Last
       and then Is_Valid_UTF8 (Text),
     Post =>
       (if Next_UTF8_Position (Text, Position) <= Text'Last
        then Is_Valid_UTF8_At (Text, Next_UTF8_Position (Text, Position))),
     Global => null;

   --  UTF-8 sequences have bounded length (critical for termination)
   procedure Lemma_UTF8_Sequence_Bounded (Text : String; Position : Natural)
   with
     Ghost,
     Pre =>
       Position >= Text'First
       and then Position <= Text'Last
       and then Is_Valid_UTF8_At (Text, Position),
     Post =>
       UTF8_Sequence_Length (Text, Position) in 1 .. 4
       and then Position + UTF8_Sequence_Length (Text, Position) - 1
                <= Text'Last,
     Global => null;

   --  Forward progress is guaranteed in valid UTF-8
   procedure Lemma_UTF8_Forward_Progress (Text : String; Position : Natural)
   with
     Ghost,
     Pre =>
       Position >= Text'First
       and then Position <= Text'Last
       and then Is_Valid_UTF8 (Text),
     Post =>
       Next_UTF8_Position (Text, Position) > Position
       and then Next_UTF8_Position (Text, Position) - Position
                >= Min_UTF8_Progress,
     Global => null;

   --  Backward scanning terminates
   procedure Lemma_UTF8_Backward_Terminates (Text : String; Position : Natural)
   with
     Ghost,
     Pre =>
       Position > Text'First
       and then Position <= Text'Last + 1
       and then Is_Valid_UTF8 (Text),
     Post =>
       Previous_UTF8_Position (Text, Position) < Position
       and then Previous_UTF8_Position (Text, Position) >= Text'First,
     Global => null;

end SML.UTF8;
