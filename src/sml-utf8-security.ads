------------------------------------------------------------------------------
--  SML.UTF8_Security Package Specification
--  Security-Focused UTF-8 Validation for Attack Prevention
--  SPARK Ada Implementation - Ghost Code for Security Verification
------------------------------------------------------------------------------

with SML.RFC3629;
with SML.UTF8;

package SML.UTF8_Security with SPARK_Mode => On, Ghost is

   --  This ghost package provides security-focused UTF-8 validation
   --  to prevent various attack vectors including overlong encodings,
   --  invalid sequences that could bypass filters, and malformed input
   --  that could cause buffer overflows or other vulnerabilities.

   use SML.RFC3629;

   ---------------------------------------------------------------------------
   --  Security Attack Vectors
   ---------------------------------------------------------------------------

   type UTF8_Attack_Vector is (
      No_Attack,
      Overlong_Encoding,       -- Could bypass security filters
      Surrogate_Injection,     -- Could cause issues in UTF-16 conversion
      Invalid_Codepoint,       -- Out of Unicode range
      Truncated_Sequence,      -- Could cause buffer overrun
      Invalid_Continuation,    -- Malformed sequence
      Null_Byte_Injection,     -- C string termination attack
      Path_Traversal,          -- Encoded "../" or similar
      Script_Injection,        -- Encoded "<script>" tags
      SQL_Injection           -- Encoded SQL metacharacters
   );

   type Security_Validation_Result is record
      Is_Secure     : Boolean;
      Attack_Vector : UTF8_Attack_Vector;
      Position      : Natural;
      Details       : String (1 .. 256);
      Details_Length : Natural;
   end record;

   ---------------------------------------------------------------------------
   --  Overlong Encoding Detection
   ---------------------------------------------------------------------------

   --  Detect any overlong encoding in text
   function Contains_Overlong_Encoding (Text : String) return Boolean
     with Post => (if Contains_Overlong_Encoding'Result then
                      not SML.RFC3629.All_Shortest_Form (Text));

   --  Find first overlong encoding
   function Find_Overlong_Encoding (Text : String)
                                   return Security_Validation_Result
     with Post => (if Find_Overlong_Encoding'Result.Is_Secure then
                      not Contains_Overlong_Encoding (Text)
                   else
                      Find_Overlong_Encoding'Result.Attack_Vector = Overlong_Encoding);

   --  Check specific dangerous overlong patterns
   function Has_Overlong_Slash (Text : String) return Boolean
     with Post => (if Has_Overlong_Slash'Result then
                      Contains_Overlong_Encoding (Text));

   function Has_Overlong_Dot (Text : String) return Boolean
     with Post => (if Has_Overlong_Dot'Result then
                      Contains_Overlong_Encoding (Text));

   function Has_Overlong_Null (Text : String) return Boolean
     with Post => (if Has_Overlong_Null'Result then
                      Contains_Overlong_Encoding (Text));

   function Has_Overlong_Angle_Bracket (Text : String) return Boolean
     with Post => (if Has_Overlong_Angle_Bracket'Result then
                      Contains_Overlong_Encoding (Text));

   ---------------------------------------------------------------------------
   --  Surrogate Detection
   ---------------------------------------------------------------------------

   --  Detect UTF-16 surrogates (invalid in UTF-8)
   function Contains_Surrogate (Text : String) return Boolean
     with Post => (if Contains_Surrogate'Result then
                      not SML.RFC3629.No_Surrogate_Encodings (Text));

   --  Find first surrogate
   function Find_Surrogate (Text : String) return Security_Validation_Result
     with Post => (if Find_Surrogate'Result.Is_Secure then
                      not Contains_Surrogate (Text)
                   else
                      Find_Surrogate'Result.Attack_Vector = Surrogate_Injection);

   --  Check for high surrogate (U+D800-U+DBFF)
   function Has_High_Surrogate (Text : String) return Boolean
     with Post => (if Has_High_Surrogate'Result then
                      Contains_Surrogate (Text));

   --  Check for low surrogate (U+DC00-U+DFFF)
   function Has_Low_Surrogate (Text : String) return Boolean
     with Post => (if Has_Low_Surrogate'Result then
                      Contains_Surrogate (Text));

   ---------------------------------------------------------------------------
   --  Invalid Codepoint Detection
   ---------------------------------------------------------------------------

   --  Detect codepoints beyond U+10FFFF
   function Contains_Invalid_Codepoint (Text : String) return Boolean
     with Post => (if Contains_Invalid_Codepoint'Result then
                      not SML.UTF8.Is_Valid_UTF8 (Text));

   --  Detect specific invalid bytes
   function Contains_FE_FF_Bytes (Text : String) return Boolean
     with Post => Contains_FE_FF_Bytes'Result =
                    (for some I in Text'Range =>
                       Character'Pos (Text (I)) in 16#FE# .. 16#FF#);

   function Contains_C0_C1_Bytes (Text : String) return Boolean
     with Post => Contains_C0_C1_Bytes'Result =
                    (for some I in Text'Range =>
                       Character'Pos (Text (I)) in 16#C0# .. 16#C1#);

   function Contains_F5_FF_Bytes (Text : String) return Boolean
     with Post => Contains_F5_FF_Bytes'Result =
                    (for some I in Text'Range =>
                       Character'Pos (Text (I)) in 16#F5# .. 16#FF#);

   ---------------------------------------------------------------------------
   --  Truncation and Malformation Detection
   ---------------------------------------------------------------------------

   --  Detect truncated multibyte sequences
   function Contains_Truncated_Sequence (Text : String) return Boolean;

   --  Detect orphaned continuation bytes
   function Contains_Orphaned_Continuation (Text : String) return Boolean
     with Post => (if Contains_Orphaned_Continuation'Result then
                      not SML.UTF8.Is_Valid_UTF8 (Text));

   --  Detect invalid continuation bytes
   function Contains_Invalid_Continuation (Text : String) return Boolean;

   --  Check if text ends with incomplete sequence
   function Ends_With_Incomplete_Sequence (Text : String) return Boolean
     with Post => (if Ends_With_Incomplete_Sequence'Result then
                      Contains_Truncated_Sequence (Text));

   ---------------------------------------------------------------------------
   --  Path Traversal Attack Detection
   ---------------------------------------------------------------------------

   --  Detect encoded path traversal sequences
   function Contains_Path_Traversal (Text : String) return Boolean;

   --  Check for encoded "../"
   function Has_Encoded_Parent_Directory (Text : String) return Boolean
     with Post => (if Has_Encoded_Parent_Directory'Result then
                      Contains_Path_Traversal (Text));

   --  Check for encoded "./"
   function Has_Encoded_Current_Directory (Text : String) return Boolean;

   --  Check for encoded absolute paths
   function Has_Encoded_Absolute_Path (Text : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Script Injection Detection
   ---------------------------------------------------------------------------

   --  Detect potential script injection attempts
   function Contains_Script_Injection (Text : String) return Boolean;

   --  Check for encoded "<script>"
   function Has_Encoded_Script_Tag (Text : String) return Boolean
     with Post => (if Has_Encoded_Script_Tag'Result then
                      Contains_Script_Injection (Text));

   --  Check for encoded JavaScript events
   function Has_Encoded_JS_Event (Text : String) return Boolean;

   --  Check for encoded HTML entities that could be malicious
   function Has_Encoded_HTML_Entity (Text : String) return Boolean;

   ---------------------------------------------------------------------------
   --  SQL Injection Detection
   ---------------------------------------------------------------------------

   --  Detect potential SQL injection attempts
   function Contains_SQL_Injection (Text : String) return Boolean;

   --  Check for encoded SQL metacharacters
   function Has_Encoded_SQL_Meta (Text : String) return Boolean
     with Post => (if Has_Encoded_SQL_Meta'Result then
                      Contains_SQL_Injection (Text));

   ---------------------------------------------------------------------------
   --  Null Byte Handling
   ---------------------------------------------------------------------------

   --  Detect null bytes (could terminate C strings)
   function Contains_Null_Byte (Text : String) return Boolean
     with Post => Contains_Null_Byte'Result =
                    (for some I in Text'Range =>
                       Text (I) = ASCII.NUL);

   --  Check if null bytes are encoded
   function Has_Encoded_Null (Text : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Comprehensive Security Validation
   ---------------------------------------------------------------------------

   --  Complete security validation
   function Validate_Security (Text : String) return Security_Validation_Result
     with Post => (Validate_Security'Result.Is_Secure =
                     (not Contains_Overlong_Encoding (Text) and then
                      not Contains_Surrogate (Text) and then
                      not Contains_Invalid_Codepoint (Text) and then
                      not Contains_Truncated_Sequence (Text) and then
                      not Contains_Path_Traversal (Text) and then
                      not Contains_Script_Injection (Text) and then
                      not Contains_SQL_Injection (Text)));

   --  Quick security check (no details)
   function Is_Security_Safe (Text : String) return Boolean
     with Post => Is_Security_Safe'Result =
                    Validate_Security (Text).Is_Secure;

   ---------------------------------------------------------------------------
   --  Sanitization Functions
   ---------------------------------------------------------------------------

   --  Remove all potentially dangerous sequences
   function Sanitize_UTF8 (Text : String) return String
     with Pre => Text'Length > 0,
          Post => Is_Security_Safe (Sanitize_UTF8'Result) and then
                  SML.UTF8.Is_Valid_UTF8 (Sanitize_UTF8'Result) and then
                  Sanitize_UTF8'Result'Length <= Text'Length;

   --  Replace dangerous sequences with safe placeholder
   function Replace_Dangerous (Text : String;
                               Placeholder : String := "?") return String
     with Pre => SML.UTF8.Is_Valid_UTF8 (Placeholder),
          Post => Is_Security_Safe (Replace_Dangerous'Result);

   ---------------------------------------------------------------------------
   --  Normalization for Security
   ---------------------------------------------------------------------------

   --  Normalize to prevent homograph attacks
   function Security_Normalize (Text : String) return String
     with Pre => SML.UTF8.Is_Valid_UTF8 (Text),
          Post => SML.UTF8.Is_Valid_UTF8 (Security_Normalize'Result) and then
                  Is_Security_Safe (Security_Normalize'Result);

   --  Convert to canonical form
   function To_Canonical_Form (Text : String) return String
     with Pre => SML.UTF8.Is_Valid_UTF8 (Text),
          Post => SML.UTF8.Is_Valid_UTF8 (To_Canonical_Form'Result) and then
                  SML.RFC3629.All_Shortest_Form (To_Canonical_Form'Result);

   ---------------------------------------------------------------------------
   --  Security Properties and Lemmas
   ---------------------------------------------------------------------------

   --  Security validation implies RFC compliance
   procedure Lemma_Security_Implies_RFC3629
     with Post => (for all Text : String =>
                     (Is_Security_Safe (Text) implies
                      SML.RFC3629.Fully_RFC3629_Compliant (Text)));

   --  No overlong implies shortest form
   procedure Lemma_No_Overlong_Is_Shortest
     with Post => (for all Text : String =>
                     (not Contains_Overlong_Encoding (Text) implies
                      SML.RFC3629.All_Shortest_Form (Text)));

   --  Sanitized text is always safe
   procedure Lemma_Sanitize_Is_Safe
     with Post => (for all Text : String =>
                     Is_Security_Safe (Sanitize_UTF8 (Text)));

   --  Security normalization preserves meaning
   procedure Lemma_Normalization_Preserves_Meaning
     with Post => (for all Text : String =>
                     (if SML.UTF8.Is_Valid_UTF8 (Text) and then
                         Is_Security_Safe (Text)
                      then Security_Normalize (Text) = Text));

   ---------------------------------------------------------------------------
   --  Attack Prevention Guarantees
   ---------------------------------------------------------------------------

   --  Path traversal impossible after sanitization
   procedure Lemma_No_Path_Traversal_After_Sanitize
     with Post => (for all Text : String =>
                     not Contains_Path_Traversal (Sanitize_UTF8 (Text)));

   --  Script injection impossible after sanitization
   procedure Lemma_No_Script_Injection_After_Sanitize
     with Post => (for all Text : String =>
                     not Contains_Script_Injection (Sanitize_UTF8 (Text)));

   --  SQL injection impossible after sanitization
   procedure Lemma_No_SQL_Injection_After_Sanitize
     with Post => (for all Text : String =>
                     not Contains_SQL_Injection (Sanitize_UTF8 (Text)));

   ---------------------------------------------------------------------------
   --  Security Metrics
   ---------------------------------------------------------------------------

   --  Count potential security issues
   function Count_Security_Issues (Text : String) return Natural
     with Post => (Count_Security_Issues'Result = 0) =
                    Is_Security_Safe (Text);

   --  Get risk level
   type Risk_Level is (None, Low, Medium, High, Critical);

   function Assess_Risk_Level (Text : String) return Risk_Level
     with Post => (Assess_Risk_Level'Result = None) =
                    Is_Security_Safe (Text);

   ---------------------------------------------------------------------------
   --  Main Security Theorem
   ---------------------------------------------------------------------------

   --  Security validation prevents all known attacks
   procedure Theorem_Security_Validation_Complete
     with Ghost,
          Post => (for all Text : String =>
                     (Is_Security_Safe (Text) implies
                        (not Contains_Overlong_Encoding (Text) and then
                         not Contains_Surrogate (Text) and then
                         not Contains_Invalid_Codepoint (Text) and then
                         not Contains_Truncated_Sequence (Text) and then
                         not Contains_Path_Traversal (Text) and then
                         not Contains_Script_Injection (Text) and then
                         not Contains_SQL_Injection (Text) and then
                         SML.RFC3629.Fully_RFC3629_Compliant (Text))));

end SML.UTF8_Security;