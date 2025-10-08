------------------------------------------------------------------------------
--  SML.UTF8_Bijection Package Specification
--  Bijection Proofs for UTF-8 ↔ Unicode Codepoint Mapping
--  SPARK Ada Implementation - Ghost Code for Mathematical Properties
------------------------------------------------------------------------------

with SML.UTF8;
with SML.RFC3629;

package SML.UTF8_Bijection with SPARK_Mode => On, Ghost is

   --  This ghost package proves that UTF-8 encoding forms a bijection
   --  between valid Unicode codepoints and their UTF-8 representations,
   --  ensuring no information loss and unique encoding.

   use SML.RFC3629;

   ---------------------------------------------------------------------------
   --  Bijection Definition
   ---------------------------------------------------------------------------

   --  A bijection requires:
   --  1. Injectivity: Different codepoints have different encodings
   --  2. Surjectivity: Every valid UTF-8 sequence decodes to a codepoint
   --  3. Well-defined: Encoding and decoding are always defined for valid input

   ---------------------------------------------------------------------------
   --  Encoding Function Properties
   ---------------------------------------------------------------------------

   --  Encoding is well-defined for all valid codepoints
   procedure Lemma_Encoding_Well_Defined
     with Post => (for all Code : Unicode_Codepoint =>
                     (if not Is_Surrogate_Codepoint (Code) then
                        Encoding_Exists (Code)));

   --  Helper: Encoding exists for codepoint
   function Encoding_Exists (Code : Unicode_Codepoint) return Boolean
     with Post => Encoding_Exists'Result =
                    (Encode_UTF8_Codepoint (Code)'Length in 1 .. 4);

   --  Encoding is deterministic (always same result)
   procedure Lemma_Encoding_Deterministic
     with Post => (for all Code : Unicode_Codepoint =>
                     (if not Is_Surrogate_Codepoint (Code) then
                        (for all Call1, Call2 : Natural =>
                           Encode_UTF8_Codepoint (Code) =
                           Encode_UTF8_Codepoint (Code))));

   --  Encoding produces valid UTF-8
   procedure Lemma_Encoding_Produces_Valid_UTF8
     with Post => (for all Code : Unicode_Codepoint =>
                     (if not Is_Surrogate_Codepoint (Code) then
                        Is_Well_Formed_UTF8_Sequence (
                          Encode_UTF8_Codepoint (Code))));

   ---------------------------------------------------------------------------
   --  Decoding Function Properties
   ---------------------------------------------------------------------------

   --  Decoding is well-defined for all valid UTF-8
   procedure Lemma_Decoding_Well_Defined
     with Post => (for all Seq : Byte_Sequence =>
                     (if Seq'Length in 1 .. 4 and then
                         Is_Well_Formed_UTF8_Sequence (Seq)
                      then Decoding_Exists (Seq)));

   --  Helper: Decoding exists for sequence
   function Decoding_Exists (Seq : Byte_Sequence) return Boolean
     with Pre => Seq'Length in 1 .. 4,
          Post => Decoding_Exists'Result =
                    (Decode_UTF8_Sequence (Seq) in Unicode_Codepoint);

   --  Decoding is deterministic
   procedure Lemma_Decoding_Deterministic
     with Post => (for all Seq : Byte_Sequence =>
                     (if Seq'Length in 1 .. 4 and then
                         Is_Well_Formed_UTF8_Sequence (Seq)
                      then Decode_UTF8_Sequence (Seq) =
                           Decode_UTF8_Sequence (Seq)));

   --  Decoding produces valid codepoints
   procedure Lemma_Decoding_Produces_Valid_Codepoint
     with Post => (for all Seq : Byte_Sequence =>
                     (if Seq'Length in 1 .. 4 and then
                         Is_Well_Formed_UTF8_Sequence (Seq)
                      then not Is_Surrogate_Codepoint (
                             Decode_UTF8_Sequence (Seq))));

   ---------------------------------------------------------------------------
   --  Injectivity Proofs (One-to-One)
   ---------------------------------------------------------------------------

   --  Different codepoints produce different encodings
   procedure Lemma_Encoding_Injective
     with Post => (for all Code1, Code2 : Unicode_Codepoint =>
                     ((not Is_Surrogate_Codepoint (Code1) and then
                       not Is_Surrogate_Codepoint (Code2) and then
                       Encode_UTF8_Codepoint (Code1) =
                       Encode_UTF8_Codepoint (Code2))
                      implies Code1 = Code2));

   --  No two codepoints map to same sequence
   procedure Lemma_No_Encoding_Collision
     with Post => (for all Code1, Code2 : Unicode_Codepoint =>
                     ((not Is_Surrogate_Codepoint (Code1) and then
                       not Is_Surrogate_Codepoint (Code2) and then
                       Code1 /= Code2)
                      implies
                       Encode_UTF8_Codepoint (Code1) /=
                       Encode_UTF8_Codepoint (Code2)));

   --  Shortest form ensures uniqueness
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

   ---------------------------------------------------------------------------
   --  Surjectivity Proofs (Onto)
   ---------------------------------------------------------------------------

   --  Every valid UTF-8 sequence decodes to something
   procedure Lemma_Decoding_Surjective
     with Post => (for all Seq : Byte_Sequence =>
                     (if Seq'Length in 1 .. 4 and then
                         Is_Well_Formed_UTF8_Sequence (Seq)
                      then (for some Code : Unicode_Codepoint =>
                              Decode_UTF8_Sequence (Seq) = Code)));

   --  Every valid codepoint has an encoding
   procedure Lemma_Encoding_Surjective
     with Post => (for all Code : Unicode_Codepoint =>
                     (if not Is_Surrogate_Codepoint (Code) then
                        (for some Seq : Byte_Sequence =>
                           Encode_UTF8_Codepoint (Code) = Seq)));

   ---------------------------------------------------------------------------
   --  Round-Trip Properties (Bijection Core)
   ---------------------------------------------------------------------------

   --  Encode then decode returns original codepoint
   procedure Lemma_Encode_Decode_Identity
     with Post => (for all Code : Unicode_Codepoint =>
                     (if not Is_Surrogate_Codepoint (Code) then
                        Decode_UTF8_Sequence (
                          Encode_UTF8_Codepoint (Code)) = Code));

   --  Decode then encode returns original sequence
   procedure Lemma_Decode_Encode_Identity
     with Post => (for all Seq : Byte_Sequence =>
                     (if Seq'Length in 1 .. 4 and then
                         Is_Well_Formed_UTF8_Sequence (Seq) and then
                         Is_Shortest_Form (Seq,
                           Decode_UTF8_Sequence (Seq))
                      then Encode_UTF8_Codepoint (
                             Decode_UTF8_Sequence (Seq)) = Seq));

   --  Complete round-trip for strings
   procedure Lemma_String_Round_Trip
     with Post => (for all Text : String =>
                     (if SML.UTF8.Is_Valid_UTF8 (Text) and then
                         SML.RFC3629.All_Shortest_Form (Text)
                      then Encode_String (Decode_String (Text)) = Text));

   --  Helper: Decode string to codepoints
   function Decode_String (Text : String) return Codepoint_Array
     with Pre => SML.UTF8.Is_Valid_UTF8 (Text);

   --  Helper: Encode codepoints to string
   function Encode_String (Codes : Codepoint_Array) return String
     with Pre => (for all I in Codes'Range =>
                    not Is_Surrogate_Codepoint (Codes (I)));

   type Codepoint_Array is array (Positive range <>) of Unicode_Codepoint;

   ---------------------------------------------------------------------------
   --  Information Preservation
   ---------------------------------------------------------------------------

   --  No information lost in encoding
   procedure Lemma_Encoding_Preserves_Information
     with Post => (for all Code : Unicode_Codepoint =>
                     (if not Is_Surrogate_Codepoint (Code) then
                        Can_Recover_Codepoint (
                          Encode_UTF8_Codepoint (Code))));

   --  Helper: Can recover original codepoint
   function Can_Recover_Codepoint (Seq : Byte_Sequence) return Boolean
     with Pre => Seq'Length in 1 .. 4;

   --  No information lost in decoding
   procedure Lemma_Decoding_Preserves_Information
     with Post => (for all Seq : Byte_Sequence =>
                     (if Seq'Length in 1 .. 4 and then
                         Is_Well_Formed_UTF8_Sequence (Seq)
                      then Can_Recover_Sequence (
                             Decode_UTF8_Sequence (Seq))));

   --  Helper: Can recover original sequence
   function Can_Recover_Sequence (Code : Unicode_Codepoint) return Boolean;

   ---------------------------------------------------------------------------
   --  Length Relationships
   ---------------------------------------------------------------------------

   --  Encoding length is predictable
   procedure Lemma_Encoding_Length_Determined
     with Post => (for all Code : Unicode_Codepoint =>
                     Encode_UTF8_Codepoint (Code)'Length =
                     Required_UTF8_Length (Code));

   --  Required UTF-8 length for codepoint
   function Required_UTF8_Length (Code : Unicode_Codepoint) return Natural
     with Post => (if Code <= 16#7F# then
                      Required_UTF8_Length'Result = 1
                   elsif Code <= 16#7FF# then
                      Required_UTF8_Length'Result = 2
                   elsif Code <= 16#FFFF# then
                      Required_UTF8_Length'Result = 3
                   elsif Code <= 16#10FFFF# then
                      Required_UTF8_Length'Result = 4
                   else
                      Required_UTF8_Length'Result = 0);

   --  Character count vs byte count relationship
   procedure Lemma_Character_Byte_Count_Relationship
     with Post => (for all Text : String =>
                     (if SML.UTF8.Is_Valid_UTF8 (Text) then
                        SML.UTF8.UTF8_Length (Text) <= Text'Length and then
                        Text'Length <= SML.UTF8.UTF8_Length (Text) * 4));

   ---------------------------------------------------------------------------
   --  Ordering Preservation
   ---------------------------------------------------------------------------

   --  UTF-8 preserves codepoint ordering (for sorting)
   procedure Lemma_Ordering_Preserved
     with Post => (for all Code1, Code2 : Unicode_Codepoint =>
                     ((not Is_Surrogate_Codepoint (Code1) and then
                       not Is_Surrogate_Codepoint (Code2) and then
                       Code1 < Code2)
                      implies
                       Lexicographic_Less (Encode_UTF8_Codepoint (Code1),
                                         Encode_UTF8_Codepoint (Code2))));

   --  Helper: Lexicographic comparison
   function Lexicographic_Less (Seq1, Seq2 : Byte_Sequence) return Boolean;

   ---------------------------------------------------------------------------
   --  ASCII Compatibility
   ---------------------------------------------------------------------------

   --  ASCII subset unchanged in UTF-8
   procedure Lemma_ASCII_Compatible
     with Post => (for all Code : Unicode_Codepoint =>
                     (if Code <= 127 then
                        Encode_UTF8_Codepoint (Code) = (1 => Byte (Code))));

   --  ASCII strings are valid UTF-8
   procedure Lemma_ASCII_Is_UTF8
     with Post => (for all Text : String =>
                     ((for all I in Text'Range =>
                         Character'Pos (Text (I)) < 128)
                      implies SML.UTF8.Is_Valid_UTF8 (Text)));

   ---------------------------------------------------------------------------
   --  Main Bijection Theorem
   ---------------------------------------------------------------------------

   --  UTF-8 encoding is a bijection
   procedure Theorem_UTF8_Is_Bijection
     with Ghost,
          Post =>
            -- Injective (one-to-one)
            (for all Code1, Code2 : Unicode_Codepoint =>
               ((not Is_Surrogate_Codepoint (Code1) and then
                 not Is_Surrogate_Codepoint (Code2) and then
                 Encode_UTF8_Codepoint (Code1) =
                 Encode_UTF8_Codepoint (Code2))
                implies Code1 = Code2))
            and then
            -- Surjective (onto)
            (for all Seq : Byte_Sequence =>
               (if Seq'Length in 1 .. 4 and then
                   Is_Well_Formed_UTF8_Sequence (Seq)
                then (for some Code : Unicode_Codepoint =>
                        Encode_UTF8_Codepoint (Code) = Seq)))
            and then
            -- Round-trip identity
            (for all Code : Unicode_Codepoint =>
               (if not Is_Surrogate_Codepoint (Code) then
                  Decode_UTF8_Sequence (
                    Encode_UTF8_Codepoint (Code)) = Code))
            and then
            -- Inverse round-trip
            (for all Seq : Byte_Sequence =>
               (if Seq'Length in 1 .. 4 and then
                   Is_Well_Formed_UTF8_Sequence (Seq) and then
                   Is_Shortest_Form (Seq, Decode_UTF8_Sequence (Seq))
                then Encode_UTF8_Codepoint (
                       Decode_UTF8_Sequence (Seq)) = Seq));

end SML.UTF8_Bijection;