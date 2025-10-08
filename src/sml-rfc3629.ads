------------------------------------------------------------------------------
--  SML.RFC3629 Package Specification
--  Formal Definition of UTF-8 per RFC 3629
--  SPARK Ada Implementation - Ghost Code for Standards Compliance
------------------------------------------------------------------------------

package SML.RFC3629 with SPARK_Mode => On, Ghost is

   --  This ghost package formally defines the UTF-8 encoding standard
   --  as specified in RFC 3629. All definitions are based directly on
   --  the RFC text to enable formal compliance proofs.

   ---------------------------------------------------------------------------
   --  Basic Types from RFC 3629
   ---------------------------------------------------------------------------

   subtype Byte is Natural range 0 .. 255;
   subtype Unicode_Codepoint is Natural range 0 .. 16#10FFFF#;

   --  UTF-8 sequences are 1-4 bytes per RFC 3629 Section 3
   subtype UTF8_Sequence_Length is Natural range 1 .. 4;

   type Byte_Sequence is array (Positive range <>) of Byte;

   ---------------------------------------------------------------------------
   --  RFC 3629 Section 3: UTF-8 Definition
   ---------------------------------------------------------------------------

   --  Table 3-7: Well-Formed UTF-8 Byte Sequences
   --
   --  Code Points        First Byte  Second Byte  Third Byte  Fourth Byte
   --  U+0000..U+007F     00..7F
   --  U+0080..U+07FF     C2..DF      80..BF
   --  U+0800..U+0FFF     E0          A0..BF       80..BF
   --  U+1000..U+CFFF     E1..EC      80..BF       80..BF
   --  U+D000..U+D7FF     ED          80..9F       80..BF
   --  U+E000..U+FFFF     EE..EF      80..BF       80..BF
   --  U+10000..U+3FFFF   F0          90..BF       80..BF      80..BF
   --  U+40000..U+FFFFF   F1..F3      80..BF       80..BF      80..BF
   --  U+100000..U+10FFFF F4          80..8F       80..BF      80..BF

   --  1-byte sequence (ASCII): 0xxxxxxx
   function RFC3629_Valid_1Byte (B1 : Byte) return Boolean
     with Post => RFC3629_Valid_1Byte'Result = (B1 <= 16#7F#);

   --  2-byte sequence: 110xxxxx 10xxxxxx
   function RFC3629_Valid_2Byte (B1, B2 : Byte) return Boolean
     with Post => RFC3629_Valid_2Byte'Result =
                    (B1 in 16#C2# .. 16#DF# and then  -- C0-C1 would be overlong
                     B2 in 16#80# .. 16#BF#);

   --  3-byte sequence: 1110xxxx 10xxxxxx 10xxxxxx
   function RFC3629_Valid_3Byte (B1, B2, B3 : Byte) return Boolean
     with Post => RFC3629_Valid_3Byte'Result =
                    ((B1 = 16#E0# and then B2 in 16#A0# .. 16#BF#) or  -- No overlong
                     (B1 in 16#E1# .. 16#EC# and then B2 in 16#80# .. 16#BF#) or
                     (B1 = 16#ED# and then B2 in 16#80# .. 16#9F#) or  -- No surrogates
                     (B1 in 16#EE# .. 16#EF# and then B2 in 16#80# .. 16#BF#))
                    and then B3 in 16#80# .. 16#BF#;

   --  4-byte sequence: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
   function RFC3629_Valid_4Byte (B1, B2, B3, B4 : Byte) return Boolean
     with Post => RFC3629_Valid_4Byte'Result =
                    ((B1 = 16#F0# and then B2 in 16#90# .. 16#BF#) or  -- No overlong
                     (B1 in 16#F1# .. 16#F3# and then B2 in 16#80# .. 16#BF#) or
                     (B1 = 16#F4# and then B2 in 16#80# .. 16#8F#))    -- Max U+10FFFF
                    and then B3 in 16#80# .. 16#BF#
                    and then B4 in 16#80# .. 16#BF#;

   ---------------------------------------------------------------------------
   --  RFC 3629 Section 1: Excluded Values
   ---------------------------------------------------------------------------

   --  UTF-16 surrogate halves (U+D800 through U+DFFF) are excluded
   function Is_Surrogate_Codepoint (Code : Natural) return Boolean
     with Post => Is_Surrogate_Codepoint'Result =
                    (Code in 16#D800# .. 16#DFFF#);

   --  Values above U+10FFFF are excluded
   function Exceeds_Unicode_Range (Code : Natural) return Boolean
     with Post => Exceeds_Unicode_Range'Result = (Code > 16#10FFFF#);

   --  Bytes 0xFE and 0xFF never appear in valid UTF-8
   function Is_Invalid_UTF8_Byte (B : Byte) return Boolean
     with Post => Is_Invalid_UTF8_Byte'Result = (B >= 16#FE#);

   ---------------------------------------------------------------------------
   --  RFC 3629 Section 4: Security Considerations - Shortest Form
   ---------------------------------------------------------------------------

   --  Overlong encodings are invalid per security considerations
   function Is_Overlong_2Byte (B1, B2 : Byte) return Boolean
     with Post => Is_Overlong_2Byte'Result =
                    (B1 in 16#C0# .. 16#C1#);  -- Would encode 0-127

   function Is_Overlong_3Byte (B1, B2, B3 : Byte) return Boolean
     with Post => Is_Overlong_3Byte'Result =
                    (B1 = 16#E0# and then B2 < 16#A0#);  -- Would encode < U+0800

   function Is_Overlong_4Byte (B1, B2, B3, B4 : Byte) return Boolean
     with Post => Is_Overlong_4Byte'Result =
                    (B1 = 16#F0# and then B2 < 16#90#);  -- Would encode < U+10000

   --  Check if encoding uses shortest possible form
   function Is_Shortest_Form (Bytes : Byte_Sequence;
                              Code : Unicode_Codepoint) return Boolean
     with Pre => Bytes'Length in 1 .. 4,
          Post => Is_Shortest_Form'Result =
                    ((Code <= 16#7F# and then Bytes'Length = 1) or
                     (Code in 16#80# .. 16#7FF# and then Bytes'Length = 2) or
                     (Code in 16#800# .. 16#FFFF# and then Bytes'Length = 3) or
                     (Code in 16#10000# .. 16#10FFFF# and then Bytes'Length = 4));

   ---------------------------------------------------------------------------
   --  Well-Formed UTF-8 Sequences
   ---------------------------------------------------------------------------

   --  Complete well-formedness check per RFC 3629
   function Is_Well_Formed_UTF8_Sequence (Bytes : Byte_Sequence) return Boolean
     with Pre => Bytes'Length in 1 .. 4,
          Post => Is_Well_Formed_UTF8_Sequence'Result =
                    (case Bytes'Length is
                       when 1 => RFC3629_Valid_1Byte (Bytes (Bytes'First)),
                       when 2 => RFC3629_Valid_2Byte (Bytes (Bytes'First),
                                                      Bytes (Bytes'First + 1)),
                       when 3 => RFC3629_Valid_3Byte (Bytes (Bytes'First),
                                                      Bytes (Bytes'First + 1),
                                                      Bytes (Bytes'First + 2)),
                       when 4 => RFC3629_Valid_4Byte (Bytes (Bytes'First),
                                                      Bytes (Bytes'First + 1),
                                                      Bytes (Bytes'First + 2),
                                                      Bytes (Bytes'First + 3)),
                       when others => False);

   --  Check if string is valid UTF-8 per RFC 3629
   function RFC3629_Compliant (Text : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Codepoint Extraction and Encoding
   ---------------------------------------------------------------------------

   --  Extract codepoint from valid UTF-8 sequence
   function Decode_UTF8_Sequence (Bytes : Byte_Sequence)
                                 return Unicode_Codepoint
     with Pre => Bytes'Length in 1 .. 4 and then
                 Is_Well_Formed_UTF8_Sequence (Bytes),
          Post => (not Is_Surrogate_Codepoint (Decode_UTF8_Sequence'Result)) and then
                  (not Exceeds_Unicode_Range (Decode_UTF8_Sequence'Result)) and then
                  Is_Shortest_Form (Bytes, Decode_UTF8_Sequence'Result);

   --  Encode codepoint to UTF-8 sequence
   function Encode_UTF8_Codepoint (Code : Unicode_Codepoint)
                                  return Byte_Sequence
     with Pre => not Is_Surrogate_Codepoint (Code),
          Post => Encode_UTF8_Codepoint'Result'Length in 1 .. 4 and then
                  Is_Well_Formed_UTF8_Sequence (Encode_UTF8_Codepoint'Result) and then
                  Decode_UTF8_Sequence (Encode_UTF8_Codepoint'Result) = Code and then
                  Is_Shortest_Form (Encode_UTF8_Codepoint'Result, Code);

   ---------------------------------------------------------------------------
   --  Sequence Length Determination
   ---------------------------------------------------------------------------

   --  Determine sequence length from first byte (Table 3-6)
   function Sequence_Length_From_First_Byte (B : Byte) return Natural
     with Post => (if B <= 16#7F# then
                      Sequence_Length_From_First_Byte'Result = 1
                   elsif B in 16#C2# .. 16#DF# then
                      Sequence_Length_From_First_Byte'Result = 2
                   elsif B in 16#E0# .. 16#EF# then
                      Sequence_Length_From_First_Byte'Result = 3
                   elsif B in 16#F0# .. 16#F4# then
                      Sequence_Length_From_First_Byte'Result = 4
                   else
                      Sequence_Length_From_First_Byte'Result = 0);  -- Invalid

   --  Check if byte can start a valid UTF-8 sequence
   function Is_Valid_Start_Byte (B : Byte) return Boolean
     with Post => Is_Valid_Start_Byte'Result =
                    (B <= 16#7F# or else B in 16#C2# .. 16#F4#);

   --  Check if byte is a continuation byte (10xxxxxx)
   function Is_Continuation_Byte (B : Byte) return Boolean
     with Post => Is_Continuation_Byte'Result = (B in 16#80# .. 16#BF#);

   ---------------------------------------------------------------------------
   --  RFC 3629 Compliance Properties
   ---------------------------------------------------------------------------

   --  No C0 or C1 bytes (overlong 2-byte sequences)
   function No_C0_C1_Bytes (Text : String) return Boolean
     with Post => No_C0_C1_Bytes'Result =
                    (for all I in Text'Range =>
                       Character'Pos (Text (I)) not in 16#C0# .. 16#C1#);

   --  No F5-FF bytes (out of range)
   function No_F5_FF_Bytes (Text : String) return Boolean
     with Post => No_F5_FF_Bytes'Result =
                    (for all I in Text'Range =>
                       Character'Pos (Text (I)) not in 16#F5# .. 16#FF#);

   --  No surrogate encodings
   function No_Surrogate_Encodings (Text : String) return Boolean;

   --  No overlong encodings
   function No_Overlong_Encodings (Text : String) return Boolean;

   --  All sequences are shortest form
   function All_Shortest_Form (Text : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Main Compliance Predicate
   ---------------------------------------------------------------------------

   --  Complete RFC 3629 compliance check
   function Fully_RFC3629_Compliant (Text : String) return Boolean
     with Post => Fully_RFC3629_Compliant'Result =
                    (RFC3629_Compliant (Text) and then
                     No_C0_C1_Bytes (Text) and then
                     No_F5_FF_Bytes (Text) and then
                     No_Surrogate_Encodings (Text) and then
                     No_Overlong_Encodings (Text) and then
                     All_Shortest_Form (Text));

   ---------------------------------------------------------------------------
   --  Test Vectors from RFC 3629
   ---------------------------------------------------------------------------

   --  Boundary test vectors
   function Test_Vector_Min_1Byte return Byte_Sequence
     with Post => Test_Vector_Min_1Byte'Result = (1 => 16#00#);  -- U+0000

   function Test_Vector_Max_1Byte return Byte_Sequence
     with Post => Test_Vector_Max_1Byte'Result = (1 => 16#7F#);  -- U+007F

   function Test_Vector_Min_2Byte return Byte_Sequence
     with Post => Test_Vector_Min_2Byte'Result = (16#C2#, 16#80#);  -- U+0080

   function Test_Vector_Max_2Byte return Byte_Sequence
     with Post => Test_Vector_Max_2Byte'Result = (16#DF#, 16#BF#);  -- U+07FF

   function Test_Vector_Min_3Byte return Byte_Sequence
     with Post => Test_Vector_Min_3Byte'Result = (16#E0#, 16#A0#, 16#80#);  -- U+0800

   function Test_Vector_Max_3Byte return Byte_Sequence
     with Post => Test_Vector_Max_3Byte'Result = (16#EF#, 16#BF#, 16#BF#);  -- U+FFFF

   function Test_Vector_Min_4Byte return Byte_Sequence
     with Post => Test_Vector_Min_4Byte'Result = (16#F0#, 16#90#, 16#80#, 16#80#);  -- U+10000

   function Test_Vector_Max_4Byte return Byte_Sequence
     with Post => Test_Vector_Max_4Byte'Result = (16#F4#, 16#8F#, 16#BF#, 16#BF#);  -- U+10FFFF

   ---------------------------------------------------------------------------
   --  Invalid Test Vectors (Must Reject)
   ---------------------------------------------------------------------------

   --  Overlong encoding of U+0000
   function Invalid_Overlong_NUL return Byte_Sequence
     with Post => Invalid_Overlong_NUL'Result = (16#C0#, 16#80#);

   --  Overlong encoding of "/"
   function Invalid_Overlong_Slash return Byte_Sequence
     with Post => Invalid_Overlong_Slash'Result = (16#C0#, 16#AF#);

   --  High surrogate U+D800
   function Invalid_High_Surrogate return Byte_Sequence
     with Post => Invalid_High_Surrogate'Result = (16#ED#, 16#A0#, 16#80#);

   --  Low surrogate U+DFFF
   function Invalid_Low_Surrogate return Byte_Sequence
     with Post => Invalid_Low_Surrogate'Result = (16#ED#, 16#BF#, 16#BF#);

   --  Beyond Unicode range U+110000
   function Invalid_Too_Large return Byte_Sequence
     with Post => Invalid_Too_Large'Result = (16#F4#, 16#90#, 16#80#, 16#80#);

   --  Invalid start byte
   function Invalid_FE_Byte return Byte_Sequence
     with Post => Invalid_FE_Byte'Result = (1 => 16#FE#);

   ---------------------------------------------------------------------------
   --  Compliance Lemmas
   ---------------------------------------------------------------------------

   --  Valid sequences decode and re-encode correctly
   procedure Lemma_Valid_Sequences_Round_Trip
     with Post => (for all Seq : Byte_Sequence =>
                     (if Is_Well_Formed_UTF8_Sequence (Seq) then
                        Encode_UTF8_Codepoint (Decode_UTF8_Sequence (Seq)) = Seq));

   --  All valid codepoints can be encoded
   procedure Lemma_All_Valid_Codepoints_Encodable
     with Post => (for all Code : Unicode_Codepoint =>
                     (if not Is_Surrogate_Codepoint (Code) then
                        Is_Well_Formed_UTF8_Sequence (Encode_UTF8_Codepoint (Code))));

   --  Shortest form is unique
   procedure Lemma_Shortest_Form_Unique
     with Post => (for all Code : Unicode_Codepoint =>
                     (for all Seq1, Seq2 : Byte_Sequence =>
                        ((Is_Well_Formed_UTF8_Sequence (Seq1) and then
                          Is_Well_Formed_UTF8_Sequence (Seq2) and then
                          Decode_UTF8_Sequence (Seq1) = Code and then
                          Decode_UTF8_Sequence (Seq2) = Code and then
                          Is_Shortest_Form (Seq1, Code) and then
                          Is_Shortest_Form (Seq2, Code))
                         implies Seq1 = Seq2)));

end SML.RFC3629;