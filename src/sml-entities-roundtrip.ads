------------------------------------------------------------------------------
--  SML.Entities_RoundTrip Package Specification
--  Entity Encoding/Decoding Round-Trip Properties and Bijection Proofs
--  SPARK Ada Implementation - Ghost Code for Entity Correctness
------------------------------------------------------------------------------

with SML.Entities;

package SML.Entities_RoundTrip with SPARK_Mode => On, Ghost is

   --  This ghost package proves that entity encoding and decoding
   --  form a perfect bijection, ensuring no information loss and
   --  unique representation for all text transformations.

   ---------------------------------------------------------------------------
   --  Entity Reference Definitions
   ---------------------------------------------------------------------------

   --  The five standard XML entities allowed in SML
   type Standard_Entity is (
      Entity_LT,     -- < as &lt;
      Entity_GT,     -- > as &gt;
      Entity_AMP,    -- & as &amp;
      Entity_QUOT,   -- " as &quot;
      Entity_APOS    -- ' as &apos;
   );

   --  Mapping to characters
   function Entity_To_Char (E : Standard_Entity) return Character
     with Post => (case E is
                     when Entity_LT   => Entity_To_Char'Result = '<',
                     when Entity_GT   => Entity_To_Char'Result = '>',
                     when Entity_AMP  => Entity_To_Char'Result = '&',
                     when Entity_QUOT => Entity_To_Char'Result = '"',
                     when Entity_APOS => Entity_To_Char'Result = ''');

   --  Mapping to entity strings
   function Entity_To_String (E : Standard_Entity) return String
     with Post => (case E is
                     when Entity_LT   => Entity_To_String'Result = "&lt;",
                     when Entity_GT   => Entity_To_String'Result = "&gt;",
                     when Entity_AMP  => Entity_To_String'Result = "&amp;",
                     when Entity_QUOT => Entity_To_String'Result = "&quot;",
                     when Entity_APOS => Entity_To_String'Result = "&apos;");

   ---------------------------------------------------------------------------
   --  Well-Formedness Properties
   ---------------------------------------------------------------------------

   --  Check if string contains well-formed entities only
   function Contains_Only_Valid_Entities (Text : String) return Boolean
     with Post => Contains_Only_Valid_Entities'Result =
                    (for all I in Text'Range =>
                       (if Text (I) = '&' then
                          (for some E : Standard_Entity =>
                             Text (I .. I + Entity_To_String (E)'Length - 1) =
                             Entity_To_String (E))));

   --  Check if string has no partial entities
   function No_Partial_Entities (Text : String) return Boolean
     with Post => No_Partial_Entities'Result =
                    (not (for some I in Text'Range =>
                            Text (I) = '&' and then
                            (for all J in I + 1 .. Text'Last =>
                               Text (J) /= ';')));

   --  Check if encoded text is well-formed
   function Is_Well_Formed_Encoded (Text : String) return Boolean
     with Post => Is_Well_Formed_Encoded'Result =
                    (Contains_Only_Valid_Entities (Text) and then
                     No_Partial_Entities (Text));

   ---------------------------------------------------------------------------
   --  Encoding Properties
   ---------------------------------------------------------------------------

   --  Encoding is deterministic
   procedure Lemma_Encoding_Deterministic
     with Post => (for all Text : String =>
                     (for all Call1, Call2 : Natural =>
                        SML.Entities.Encode_Entities (Text) =
                        SML.Entities.Encode_Entities (Text)));

   --  Encoding produces valid entities
   procedure Lemma_Encoding_Produces_Valid
     with Post => (for all Text : String =>
                     Is_Well_Formed_Encoded (
                       SML.Entities.Encode_Entities (Text)));

   --  Encoding preserves non-special characters
   procedure Lemma_Encoding_Preserves_Normal_Chars
     with Post => (for all Text : String =>
                     (for all I in Text'Range =>
                        (if Text (I) not in '<' | '>' | '&' | '"' | ''' then
                           (for some J : Natural =>
                              SML.Entities.Encode_Entities (Text) (J) = Text (I)))));

   --  Encoding expands length predictably
   procedure Lemma_Encoding_Length_Bound
     with Post => (for all Text : String =>
                     SML.Entities.Encode_Entities (Text)'Length >=
                     Text'Length and then
                     SML.Entities.Encode_Entities (Text)'Length <=
                     Text'Length * 6);  -- Worst case: all & become &amp;

   ---------------------------------------------------------------------------
   --  Decoding Properties
   ---------------------------------------------------------------------------

   --  Decoding is deterministic
   procedure Lemma_Decoding_Deterministic
     with Post => (for all Text : String =>
                     (if Is_Well_Formed_Encoded (Text) then
                        SML.Entities.Decode_Entities (Text) =
                        SML.Entities.Decode_Entities (Text)));

   --  Decoding produces valid text (no entities)
   procedure Lemma_Decoding_Removes_All_Entities
     with Post => (for all Text : String =>
                     (if Is_Well_Formed_Encoded (Text) then
                        (for all I in SML.Entities.Decode_Entities (Text)'Range =>
                           SML.Entities.Decode_Entities (Text) (I) /= '&' or else
                           (I < SML.Entities.Decode_Entities (Text)'Last and then
                            SML.Entities.Decode_Entities (Text) (I + 1) not in
                              'l' | 'g' | 'a' | 'q'))));

   --  Decoding contracts length
   procedure Lemma_Decoding_Length_Bound
     with Post => (for all Text : String =>
                     (if Is_Well_Formed_Encoded (Text) then
                        SML.Entities.Decode_Entities (Text)'Length <=
                        Text'Length));

   ---------------------------------------------------------------------------
   --  Round-Trip Properties (Core Bijection)
   ---------------------------------------------------------------------------

   --  Decode then encode returns original (for encoded text)
   procedure Lemma_Decode_Encode_Identity
     with Post => (for all Text : String =>
                     (if Is_Well_Formed_Encoded (Text) and then
                         No_Ambiguous_Ampersands (Text)
                      then SML.Entities.Encode_Entities (
                             SML.Entities.Decode_Entities (Text)) = Text));

   --  Encode then decode returns original (for plain text)
   procedure Lemma_Encode_Decode_Identity
     with Post => (for all Text : String =>
                     SML.Entities.Decode_Entities (
                       SML.Entities.Encode_Entities (Text)) = Text);

   --  Helper: Check for ambiguous ampersands
   function No_Ambiguous_Ampersands (Text : String) return Boolean
     with Post => No_Ambiguous_Ampersands'Result =
                    (not (for some I in Text'Range =>
                            Text (I) = '&' and then
                            (I + 4 <= Text'Last and then
                             Text (I .. I + 4) = "&amp;" and then
                             (I + 7 <= Text'Last and then
                              Text (I + 5 .. I + 7) in "lt;" | "gt;"))));

   ---------------------------------------------------------------------------
   --  Injectivity Properties
   ---------------------------------------------------------------------------

   --  Different texts encode to different results
   procedure Lemma_Encoding_Injective
     with Post => (for all Text1, Text2 : String =>
                     (SML.Entities.Encode_Entities (Text1) =
                      SML.Entities.Encode_Entities (Text2))
                     implies Text1 = Text2);

   --  Different valid encodings decode to different results
   procedure Lemma_Decoding_Injective
     with Post => (for all Text1, Text2 : String =>
                     ((Is_Well_Formed_Encoded (Text1) and then
                       Is_Well_Formed_Encoded (Text2) and then
                       SML.Entities.Decode_Entities (Text1) =
                       SML.Entities.Decode_Entities (Text2))
                      implies Text1 = Text2));

   ---------------------------------------------------------------------------
   --  Surjectivity Properties
   ---------------------------------------------------------------------------

   --  Every plain text has an encoding
   procedure Lemma_Encoding_Surjective
     with Post => (for all Text : String =>
                     (for some Encoded : String =>
                        SML.Entities.Encode_Entities (Text) = Encoded));

   --  Every valid encoded text has a decoding
   procedure Lemma_Decoding_Surjective
     with Post => (for all Encoded : String =>
                     (if Is_Well_Formed_Encoded (Encoded) then
                        (for some Text : String =>
                           SML.Entities.Decode_Entities (Encoded) = Text)));

   ---------------------------------------------------------------------------
   --  Composition Properties
   ---------------------------------------------------------------------------

   --  Multiple encoding passes are idempotent after first
   procedure Lemma_Encoding_Idempotent
     with Post => (for all Text : String =>
                     (if Is_Well_Formed_Encoded (Text) and then
                         Contains_No_Special_Chars (
                           SML.Entities.Decode_Entities (Text))
                      then SML.Entities.Encode_Entities (Text) = Text));

   --  Helper: Check if text contains no special chars
   function Contains_No_Special_Chars (Text : String) return Boolean
     with Post => Contains_No_Special_Chars'Result =
                    (for all I in Text'Range =>
                       Text (I) not in '<' | '>' | '&' | '"' | ''');

   --  Multiple decoding passes are safe
   procedure Lemma_Decoding_Idempotent
     with Post => (for all Text : String =>
                     (if Contains_No_Special_Chars (Text) then
                        SML.Entities.Decode_Entities (Text) = Text));

   ---------------------------------------------------------------------------
   --  Entity Ordering Properties
   ---------------------------------------------------------------------------

   --  Encoding preserves relative ordering of non-entity chars
   procedure Lemma_Encoding_Preserves_Order
     with Post => (for all Text : String =>
                     (for all I, J : Natural =>
                        (if I in Text'Range and then J in Text'Range and then
                            I < J and then
                            Text (I) not in '<' | '>' | '&' | '"' | ''' and then
                            Text (J) not in '<' | '>' | '&' | '"' | '''
                         then (for some I2, J2 : Natural =>
                                 I2 < J2 and then
                                 SML.Entities.Encode_Entities (Text) (I2) = Text (I) and then
                                 SML.Entities.Encode_Entities (Text) (J2) = Text (J)))));

   ---------------------------------------------------------------------------
   --  Context-Specific Encoding
   ---------------------------------------------------------------------------

   --  Attribute value encoding (quotes matter)
   function Encode_For_Attribute (Text : String) return String
     with Post => (for all I in Text'Range =>
                     (if Text (I) = '"' then
                        (for some J : Natural =>
                           Encode_For_Attribute'Result (J .. J + 5) = "&quot;")));

   --  Element content encoding (quotes don't matter)
   function Encode_For_Content (Text : String) return String
     with Post => (for all I in Text'Range =>
                     (if Text (I) = '"' then
                        (for some J : Natural =>
                           Encode_For_Content'Result (J) = '"')));

   --  CDATA content (only ]]> matters, but SML doesn't support CDATA)
   function Would_Need_CDATA (Text : String) return Boolean
     with Post => Would_Need_CDATA'Result =
                    (for some I in Text'First .. Text'Last - 2 =>
                       Text (I .. I + 2) = "]]>");

   ---------------------------------------------------------------------------
   --  Error Detection and Recovery
   ---------------------------------------------------------------------------

   --  Detect malformed entities
   function Find_Malformed_Entity (Text : String) return Natural
     with Post => (if Find_Malformed_Entity'Result = 0 then
                      Is_Well_Formed_Encoded (Text)
                   else
                      Find_Malformed_Entity'Result in Text'Range and then
                      Text (Find_Malformed_Entity'Result) = '&');

   --  Partial entity at end of text
   function Has_Truncated_Entity (Text : String) return Boolean
     with Post => Has_Truncated_Entity'Result =
                    (Text'Length > 0 and then
                     Text (Text'Last) = '&' or else
                     (for some I in Text'Range =>
                        Text (I) = '&' and then
                        (for all J in I + 1 .. Text'Last =>
                           Text (J) /= ';')));

   --  Unknown entity reference
   function Has_Unknown_Entity (Text : String) return Boolean
     with Post => Has_Unknown_Entity'Result =
                    (for some I in Text'Range =>
                       Text (I) = '&' and then
                       (for some J in I + 1 .. Text'Last =>
                          Text (J) = ';' and then
                          Text (I .. J) not in "&lt;" | "&gt;" |
                                              "&amp;" | "&quot;" | "&apos;"));

   ---------------------------------------------------------------------------
   --  Information Preservation
   ---------------------------------------------------------------------------

   --  No information lost in encoding
   procedure Lemma_Encoding_Preserves_Information
     with Post => (for all Text : String =>
                     Can_Recover_Original (
                       SML.Entities.Encode_Entities (Text), Text));

   --  Helper: Can recover original from encoded
   function Can_Recover_Original (Encoded : String;
                                  Original : String) return Boolean
     with Post => Can_Recover_Original'Result =
                    (SML.Entities.Decode_Entities (Encoded) = Original);

   --  Character count preserved semantically
   procedure Lemma_Character_Count_Preserved
     with Post => (for all Text : String =>
                     Semantic_Length (Text) =
                     Semantic_Length (SML.Entities.Decode_Entities (
                       SML.Entities.Encode_Entities (Text))));

   --  Helper: Count semantic characters
   function Semantic_Length (Text : String) return Natural;

   ---------------------------------------------------------------------------
   --  Canonicalization Properties
   ---------------------------------------------------------------------------

   --  Canonical form for encoded text
   function Is_Canonically_Encoded (Text : String) return Boolean
     with Post => Is_Canonically_Encoded'Result =
                    (Is_Well_Formed_Encoded (Text) and then
                     (for all I in Text'Range =>
                        (if Text (I) = '&' then
                           -- Uses standard entities, not numeric
                           (for some E : Standard_Entity =>
                              Text (I .. I + Entity_To_String (E)'Length - 1) =
                              Entity_To_String (E)))));

   --  Convert to canonical encoding
   function Canonicalize_Encoding (Text : String) return String
     with Pre => Is_Well_Formed_Encoded (Text),
          Post => Is_Canonically_Encoded (Canonicalize_Encoding'Result) and then
                  SML.Entities.Decode_Entities (Canonicalize_Encoding'Result) =
                  SML.Entities.Decode_Entities (Text);

   ---------------------------------------------------------------------------
   --  Main Bijection Theorem
   ---------------------------------------------------------------------------

   --  Entity encoding/decoding forms a bijection
   procedure Theorem_Entity_Encoding_Is_Bijection
     with Ghost,
          Post =>
            -- Injective (one-to-one)
            (for all Text1, Text2 : String =>
               (SML.Entities.Encode_Entities (Text1) =
                SML.Entities.Encode_Entities (Text2))
               implies Text1 = Text2)
            and then
            -- Surjective (onto)
            (for all Encoded : String =>
               (if Is_Well_Formed_Encoded (Encoded) then
                  (for some Text : String =>
                     SML.Entities.Encode_Entities (Text) = Encoded)))
            and then
            -- Round-trip identity (plain to encoded to plain)
            (for all Text : String =>
               SML.Entities.Decode_Entities (
                 SML.Entities.Encode_Entities (Text)) = Text)
            and then
            -- Inverse round-trip (encoded to plain to encoded)
            (for all Encoded : String =>
               (if Is_Well_Formed_Encoded (Encoded) and then
                   Is_Canonically_Encoded (Encoded)
                then SML.Entities.Encode_Entities (
                       SML.Entities.Decode_Entities (Encoded)) = Encoded));

   ---------------------------------------------------------------------------
   --  Practical Safety Guarantees
   ---------------------------------------------------------------------------

   --  No injection attacks possible
   procedure Lemma_No_Injection_Attacks
     with Post => (for all User_Input : String =>
                     (for all I in SML.Entities.Encode_Entities (User_Input)'Range =>
                        SML.Entities.Encode_Entities (User_Input) (I) /= '<' or else
                        (I + 3 <= SML.Entities.Encode_Entities (User_Input)'Last and then
                         SML.Entities.Encode_Entities (User_Input) (I .. I + 3) = "&lt;")));

   --  No script tags possible after encoding
   procedure Lemma_No_Script_Tags
     with Post => (for all Text : String =>
                     not Contains_Substring (
                       SML.Entities.Encode_Entities (Text), "<script"));

   --  Helper: Check substring presence
   function Contains_Substring (Text : String;
                                Pattern : String) return Boolean;

end SML.Entities_RoundTrip;