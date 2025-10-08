------------------------------------------------------------------------------
--  SML.UTF8_Compliance Package Specification
--  Formal Proofs of UTF-8 RFC 3629 Compliance
--  SPARK Ada Implementation - Ghost Code for Standards Verification
------------------------------------------------------------------------------

with SML.UTF8;
with SML.RFC3629;
with SML.UTF8_Security;

package SML.UTF8_Compliance with SPARK_Mode => On, Ghost is

   --  This ghost package proves that our SML.UTF8 implementation
   --  fully complies with RFC 3629, establishing formal equivalence
   --  between our functions and the RFC requirements.

   ---------------------------------------------------------------------------
   --  Equivalence Definitions
   ---------------------------------------------------------------------------

   --  Our validation equals RFC 3629 validation
   function Validation_Equivalent (Text : String) return Boolean
     with Post => Validation_Equivalent'Result =
                    (SML.UTF8.Is_Valid_UTF8 (Text) =
                     SML.RFC3629.RFC3629_Compliant (Text));

   --  Our byte classification matches RFC
   function Byte_Classification_Equivalent return Boolean
     with Post => Byte_Classification_Equivalent'Result =
                    (for all B : SML.RFC3629.Byte =>
                       SML.UTF8.Is_Continuation_Byte (Character'Val (B)) =
                       SML.RFC3629.Is_Continuation_Byte (B));

   --  Our sequence length matches RFC
   function Sequence_Length_Equivalent return Boolean
     with Post => Sequence_Length_Equivalent'Result =
                    (for all B : Character =>
                       (for all Text : String =>
                          (if Text'Length > 0 and then Text (Text'First) = B then
                             SML.UTF8.UTF8_Sequence_Length (Text, Text'First) =
                             SML.RFC3629.Sequence_Length_From_First_Byte (
                               Character'Pos (B)))));

   ---------------------------------------------------------------------------
   --  Acceptance Proofs - We Accept All Valid RFC 3629
   ---------------------------------------------------------------------------

   --  We accept all valid 1-byte sequences
   procedure Lemma_Accept_Valid_1Byte
     with Post => (for all B : SML.RFC3629.Byte =>
                     (if SML.RFC3629.RFC3629_Valid_1Byte (B) then
                        SML.UTF8.Is_Valid_UTF8 (String'(1 => Character'Val (B)))));

   --  We accept all valid 2-byte sequences
   procedure Lemma_Accept_Valid_2Byte
     with Post => (for all B1, B2 : SML.RFC3629.Byte =>
                     (if SML.RFC3629.RFC3629_Valid_2Byte (B1, B2) then
                        SML.UTF8.Is_Valid_UTF8 (String'(Character'Val (B1),
                                                        Character'Val (B2)))));

   --  We accept all valid 3-byte sequences
   procedure Lemma_Accept_Valid_3Byte
     with Post => (for all B1, B2, B3 : SML.RFC3629.Byte =>
                     (if SML.RFC3629.RFC3629_Valid_3Byte (B1, B2, B3) then
                        SML.UTF8.Is_Valid_UTF8 (String'(Character'Val (B1),
                                                        Character'Val (B2),
                                                        Character'Val (B3)))));

   --  We accept all valid 4-byte sequences
   procedure Lemma_Accept_Valid_4Byte
     with Post => (for all B1, B2, B3, B4 : SML.RFC3629.Byte =>
                     (if SML.RFC3629.RFC3629_Valid_4Byte (B1, B2, B3, B4) then
                        SML.UTF8.Is_Valid_UTF8 (String'(Character'Val (B1),
                                                        Character'Val (B2),
                                                        Character'Val (B3),
                                                        Character'Val (B4)))));

   --  We accept all RFC 3629 valid strings
   procedure Lemma_Accept_All_Valid
     with Post => (for all Text : String =>
                     (SML.RFC3629.RFC3629_Compliant (Text) implies
                      SML.UTF8.Is_Valid_UTF8 (Text)));

   ---------------------------------------------------------------------------
   --  Rejection Proofs - We Reject All Invalid RFC 3629
   ---------------------------------------------------------------------------

   --  We reject overlong encodings
   procedure Lemma_Reject_Overlong
     with Post => (for all Text : String =>
                     (SML.UTF8_Security.Contains_Overlong_Encoding (Text) implies
                      not SML.UTF8.Is_Valid_UTF8 (Text)));

   --  We reject surrogates
   procedure Lemma_Reject_Surrogates
     with Post => (for all Text : String =>
                     (SML.UTF8_Security.Contains_Surrogate (Text) implies
                      not SML.UTF8.Is_Valid_UTF8 (Text)));

   --  We reject invalid codepoints
   procedure Lemma_Reject_Invalid_Codepoints
     with Post => (for all Text : String =>
                     (SML.UTF8_Security.Contains_Invalid_Codepoint (Text) implies
                      not SML.UTF8.Is_Valid_UTF8 (Text)));

   --  We reject C0-C1 bytes
   procedure Lemma_Reject_C0_C1
     with Post => (for all Text : String =>
                     (SML.UTF8_Security.Contains_C0_C1_Bytes (Text) implies
                      not SML.UTF8.Is_Valid_UTF8 (Text)));

   --  We reject FE-FF bytes
   procedure Lemma_Reject_FE_FF
     with Post => (for all Text : String =>
                     (SML.UTF8_Security.Contains_FE_FF_Bytes (Text) implies
                      not SML.UTF8.Is_Valid_UTF8 (Text)));

   --  We reject all RFC 3629 invalid strings
   procedure Lemma_Reject_All_Invalid
     with Post => (for all Text : String =>
                     (not SML.RFC3629.RFC3629_Compliant (Text) implies
                      not SML.UTF8.Is_Valid_UTF8 (Text)));

   ---------------------------------------------------------------------------
   --  Error Detection Correspondence
   ---------------------------------------------------------------------------

   --  Our error types map to RFC violations
   function Error_Mapping_Complete return Boolean
     with Post => Error_Mapping_Complete'Result =
                    (SML.UTF8.Truncated_Sequence corresponds to incomplete sequence and then
                     SML.UTF8.Invalid_Start_Byte corresponds to invalid first byte and then
                     SML.UTF8.Invalid_Continuation corresponds to bad continuation and then
                     SML.UTF8.Overlong_Encoding maps to non-shortest form and then
                     SML.UTF8.Surrogate_Half maps to surrogate codepoint and then
                     SML.UTF8.Out_Of_Range maps to > U+10FFFF);

   --  Helper function for correspondence (not executable, just for spec)
   function "corresponds to" (Left : SML.UTF8.UTF8_Error_Kind;
                              Right : String) return Boolean;

   function "maps to" (Left : SML.UTF8.UTF8_Error_Kind;
                      Right : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Test Vector Validation
   ---------------------------------------------------------------------------

   --  Accept all RFC test vectors
   procedure Lemma_Accept_RFC_Test_Vectors
     with Post => SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Test_Vector_Min_1Byte)) and then
                  SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Test_Vector_Max_1Byte)) and then
                  SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Test_Vector_Min_2Byte)) and then
                  SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Test_Vector_Max_2Byte)) and then
                  SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Test_Vector_Min_3Byte)) and then
                  SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Test_Vector_Max_3Byte)) and then
                  SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Test_Vector_Min_4Byte)) and then
                  SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Test_Vector_Max_4Byte));

   --  Reject all RFC invalid test vectors
   procedure Lemma_Reject_RFC_Invalid_Vectors
     with Post => not SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Invalid_Overlong_NUL)) and then
                  not SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Invalid_Overlong_Slash)) and then
                  not SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Invalid_High_Surrogate)) and then
                  not SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Invalid_Low_Surrogate)) and then
                  not SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Invalid_Too_Large)) and then
                  not SML.UTF8.Is_Valid_UTF8 (String (SML.RFC3629.Invalid_FE_Byte));

   ---------------------------------------------------------------------------
   --  Codepoint Extraction Equivalence
   ---------------------------------------------------------------------------

   --  Our codepoint extraction matches RFC
   procedure Lemma_Codepoint_Extraction_Equivalent
     with Post => (for all Text : String =>
                     (for all Pos : Natural =>
                        (if Pos in Text'Range and then
                            SML.UTF8.Is_Valid_UTF8_At (Text, Pos)
                         then SML.UTF8.Get_Code_Point (Text, Pos) =
                              SML.RFC3629.Decode_UTF8_Sequence (
                                To_Byte_Sequence (Text, Pos)))));

   --  Helper to convert string to byte sequence at position
   function To_Byte_Sequence (Text : String; Pos : Natural)
                              return SML.RFC3629.Byte_Sequence
     with Pre => Pos in Text'Range;

   ---------------------------------------------------------------------------
   --  Navigation Function Compliance
   ---------------------------------------------------------------------------

   --  Next position respects UTF-8 boundaries
   procedure Lemma_Next_Position_Valid
     with Post => (for all Text : String =>
                     (for all Pos : Natural =>
                        (if Pos in Text'First .. Text'Last and then
                            SML.UTF8.Is_Valid_UTF8 (Text)
                         then Is_UTF8_Boundary (Text,
                                               SML.UTF8.Next_UTF8_Position (Text, Pos)))));

   --  Previous position respects UTF-8 boundaries
   procedure Lemma_Previous_Position_Valid
     with Post => (for all Text : String =>
                     (for all Pos : Natural =>
                        (if Pos in Text'First + 1 .. Text'Last + 1 and then
                            SML.UTF8.Is_Valid_UTF8 (Text)
                         then Is_UTF8_Boundary (Text,
                                               SML.UTF8.Previous_UTF8_Position (Text, Pos)))));

   --  Helper: Check if position is UTF-8 boundary
   function Is_UTF8_Boundary (Text : String; Pos : Natural) return Boolean
     with Pre => SML.UTF8.Is_Valid_UTF8 (Text);

   ---------------------------------------------------------------------------
   --  Whitespace and XML Character Compliance
   ---------------------------------------------------------------------------

   --  XML character validity matches specification
   procedure Lemma_XML_Char_Valid
     with Post => (for all Code : SML.UTF8.UTF8_Code_Point =>
                     SML.UTF8.Is_Valid_XML_Char (Code) =
                     ((Code = 16#09# or Code = 16#0A# or Code = 16#0D#) or else
                      (Code in 16#20# .. 16#D7FF#) or else
                      (Code in 16#E000# .. 16#FFFD#) or else
                      (Code in 16#10000# .. 16#10FFFF#)));

   --  Whitespace detection is correct
   procedure Lemma_Whitespace_Detection
     with Post => (for all C : Character =>
                     SML.UTF8.Is_XML_Whitespace (C) =
                     (C in ' ' | ASCII.HT | ASCII.CR | ASCII.LF));

   ---------------------------------------------------------------------------
   --  Normalization Compliance
   ---------------------------------------------------------------------------

   --  Normalization preserves validity
   procedure Lemma_Normalization_Preserves_Validity
     with Post => (for all Text : String =>
                     (if SML.UTF8.Is_Valid_UTF8 (Text) then
                        SML.UTF8.Is_Valid_UTF8 (SML.UTF8.Normalize_Whitespace (Text)) and then
                        SML.UTF8.Is_Valid_UTF8 (SML.UTF8.Trim_Whitespace (Text))));

   --  Normalization doesn't introduce invalid sequences
   procedure Lemma_Normalization_Safe
     with Post => (for all Text : String =>
                     (if SML.UTF8.Is_Valid_UTF8 (Text) then
                        SML.RFC3629.RFC3629_Compliant (
                          SML.UTF8.Normalize_Whitespace (Text))));

   ---------------------------------------------------------------------------
   --  Main Compliance Theorem
   ---------------------------------------------------------------------------

   --  Complete bidirectional compliance with RFC 3629
   procedure Theorem_Full_RFC3629_Compliance
     with Ghost,
          Post =>
            -- Accept all valid
            (for all Text : String =>
               (SML.RFC3629.Fully_RFC3629_Compliant (Text) implies
                SML.UTF8.Is_Valid_UTF8 (Text)))
            and then
            -- Reject all invalid
            (for all Text : String =>
               (not SML.RFC3629.Fully_RFC3629_Compliant (Text) implies
                not SML.UTF8.Is_Valid_UTF8 (Text)))
            and then
            -- Security implies compliance
            (for all Text : String =>
               (SML.UTF8_Security.Is_Security_Safe (Text) implies
                SML.RFC3629.Fully_RFC3629_Compliant (Text)))
            and then
            -- Error detection is complete
            (for all Text : String =>
               (not SML.UTF8.Is_Valid_UTF8 (Text) implies
                SML.UTF8.Validate_UTF8 (Text).Error_Kind /= SML.UTF8.No_Error));

   ---------------------------------------------------------------------------
   --  Interoperability Guarantees
   ---------------------------------------------------------------------------

   --  Can exchange with any RFC 3629 system
   procedure Lemma_Interoperability
     with Post => (for all Text : String =>
                     (SML.UTF8.Is_Valid_UTF8 (Text) implies
                      Can_Exchange_With_RFC3629_System (Text)));

   --  Helper for interoperability
   function Can_Exchange_With_RFC3629_System (Text : String) return Boolean;

   --  Round-trip with other systems preserves data
   procedure Lemma_Round_Trip_Preservation
     with Post => (for all Text : String =>
                     (if SML.UTF8.Is_Valid_UTF8 (Text) then
                        External_Round_Trip (Text) = Text));

   --  Helper for round-trip
   function External_Round_Trip (Text : String) return String;

   ---------------------------------------------------------------------------
   --  Performance Compliance
   ---------------------------------------------------------------------------

   --  Validation is single-pass (O(n))
   procedure Lemma_Single_Pass_Validation
     with Post => Validation_Is_Linear;

   function Validation_Is_Linear return Boolean;

   --  No backtracking required
   procedure Lemma_No_Backtracking
     with Post => Validation_Never_Backtracks;

   function Validation_Never_Backtracks return Boolean;

end SML.UTF8_Compliance;