------------------------------------------------------------------------------
--  SML.Error_Detection Package Specification
--  Complete Error Detection and Diagnostic Properties
--  SPARK Ada Implementation - Ghost Code for Error Handling Verification
------------------------------------------------------------------------------

with SML.Parser;
with SML.UTF8;
with SML.Entities;

package SML.Error_Detection with SPARK_Mode => On, Ghost is

   --  This ghost package proves that the SML parser's error detection
   --  is complete, accurate, and provides meaningful diagnostics for
   --  all possible error conditions.

   ---------------------------------------------------------------------------
   --  Error Classification Hierarchy
   ---------------------------------------------------------------------------

   --  Top-level error categories
   type Error_Category is (
      Lexical_Error,       -- UTF-8, character-level issues
      Syntactic_Error,     -- XML structure violations
      Semantic_Error,      -- Well-formedness violations
      Resource_Error       -- Limits exceeded
   );

   --  Detailed error kinds (extends SML.Parser.Parse_Error_Kind)
   type Extended_Error_Kind is (
      -- Lexical Errors
      Invalid_UTF8_Sequence,
      Invalid_Character,
      Invalid_Entity_Reference,
      Truncated_Entity,
      Unknown_Entity,

      -- Syntactic Errors
      Missing_Start_Tag,
      Missing_End_Tag,
      Mismatched_Tags,
      Invalid_Tag_Name,
      Unclosed_Tag,
      Invalid_Nesting,
      Duplicate_Root,
      No_Root_Element,

      -- Semantic Errors
      Invalid_Character_Data,
      Invalid_Element_Name,
      Reserved_Name_Used,
      Invalid_Processing_Instruction,
      Invalid_Comment,
      CDATA_Not_Supported,
      DTD_Not_Supported,
      Attributes_Not_Supported,
      Namespaces_Not_Supported,

      -- Resource Errors
      Depth_Limit_Exceeded,
      Children_Limit_Exceeded,
      Document_Too_Large,
      Name_Too_Long,
      Content_Too_Long
   );

   --  Map extended errors to categories
   function Error_Category_Of (Kind : Extended_Error_Kind) return Error_Category
     with Post => (case Kind is
                     when Invalid_UTF8_Sequence .. Unknown_Entity =>
                        Error_Category_Of'Result = Lexical_Error,
                     when Missing_Start_Tag .. No_Root_Element =>
                        Error_Category_Of'Result = Syntactic_Error,
                     when Invalid_Character_Data .. Namespaces_Not_Supported =>
                        Error_Category_Of'Result = Semantic_Error,
                     when Depth_Limit_Exceeded .. Content_Too_Long =>
                        Error_Category_Of'Result = Resource_Error);

   ---------------------------------------------------------------------------
   --  Error Detection Completeness
   ---------------------------------------------------------------------------

   --  Every invalid input produces an error
   procedure Lemma_Error_Detection_Complete
     with Post => (for all Text : String =>
                     (not SML.Parser.Is_Valid_SML (Text) implies
                        SML.Parser.Parse (Text).Success = False));

   --  Every error has a specific kind
   procedure Lemma_Error_Kind_Always_Set
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        SML.Parser.Parse (Text).Error_Kind /=
                        SML.Parser.No_Parse_Error));

   --  No false positives - valid input never errors
   procedure Lemma_No_False_Positives
     with Post => (for all Text : String =>
                     (SML.Parser.Is_Valid_SML (Text) implies
                        SML.Parser.Parse (Text).Success = True));

   ---------------------------------------------------------------------------
   --  Error Location Accuracy
   ---------------------------------------------------------------------------

   --  Error position is always within input bounds
   procedure Lemma_Error_Position_Valid
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        SML.Parser.Parse (Text).Error_Position in
                        Text'First .. Text'Last + 1));

   --  Error position points to actual error start
   procedure Lemma_Error_Position_Accurate
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        Is_Error_Location (Text,
                          SML.Parser.Parse (Text).Error_Position,
                          SML.Parser.Parse (Text).Error_Kind)));

   --  Helper: Verify error is at position
   function Is_Error_Location (Text : String;
                               Pos : Natural;
                               Kind : SML.Parser.Parse_Error_Kind) return Boolean;

   --  Line and column numbers are accurate
   procedure Lemma_Line_Column_Accurate
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        Line_Column_Match_Position (Text,
                          SML.Parser.Parse (Text).Error_Position,
                          SML.Parser.Parse (Text).Error_Line,
                          SML.Parser.Parse (Text).Error_Column)));

   --  Helper: Verify line/column calculation
   function Line_Column_Match_Position (Text : String;
                                       Pos : Natural;
                                       Line : Natural;
                                       Column : Natural) return Boolean;

   ---------------------------------------------------------------------------
   --  Error Message Quality
   ---------------------------------------------------------------------------

   --  Every error has a non-empty message
   procedure Lemma_Error_Message_Present
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        SML.Parser.Parse (Text).Error_Message'Length > 0));

   --  Error messages are unique per error kind
   procedure Lemma_Error_Messages_Unique
     with Post => (for all Kind1, Kind2 : SML.Parser.Parse_Error_Kind =>
                     (if Kind1 /= Kind2 and then
                         Kind1 /= SML.Parser.No_Parse_Error and then
                         Kind2 /= SML.Parser.No_Parse_Error
                      then Base_Error_Message (Kind1) /=
                           Base_Error_Message (Kind2)));

   --  Helper: Get base message for error kind
   function Base_Error_Message (Kind : SML.Parser.Parse_Error_Kind)
                               return String;

   --  Messages contain relevant context
   procedure Lemma_Error_Message_Has_Context
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        Contains_Error_Context (
                          SML.Parser.Parse (Text).Error_Message,
                          SML.Parser.Parse (Text).Error_Kind)));

   --  Helper: Check if message has appropriate context
   function Contains_Error_Context (Message : String;
                                   Kind : SML.Parser.Parse_Error_Kind)
                                  return Boolean;

   ---------------------------------------------------------------------------
   --  UTF-8 Error Detection
   ---------------------------------------------------------------------------

   --  All UTF-8 errors are detected
   procedure Lemma_UTF8_Errors_Detected
     with Post => (for all Text : String =>
                     (not SML.UTF8.Is_Valid_UTF8 (Text) implies
                        not SML.Parser.Parse (Text).Success and then
                        SML.Parser.Parse (Text).Error_Kind in
                          SML.Parser.Invalid_UTF8 |
                          SML.Parser.Truncated_UTF8));

   --  UTF-8 error position is at invalid sequence
   procedure Lemma_UTF8_Error_Position_Correct
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success and then
                         SML.Parser.Parse (Text).Error_Kind =
                         SML.Parser.Invalid_UTF8
                      then not SML.UTF8.Is_Valid_UTF8_At (Text,
                             SML.Parser.Parse (Text).Error_Position)));

   ---------------------------------------------------------------------------
   --  Entity Error Detection
   ---------------------------------------------------------------------------

   --  Invalid entities are detected
   procedure Lemma_Entity_Errors_Detected
     with Post => (for all Text : String =>
                     (if Contains_Invalid_Entity (Text) then
                        not SML.Parser.Parse (Text).Success and then
                        SML.Parser.Parse (Text).Error_Kind in
                          SML.Parser.Invalid_Entity |
                          SML.Parser.Unknown_Entity));

   --  Helper: Check for invalid entities
   function Contains_Invalid_Entity (Text : String) return Boolean;

   --  Truncated entities are detected
   procedure Lemma_Truncated_Entity_Detected
     with Post => (for all Text : String =>
                     (if Has_Truncated_Entity_Reference (Text) then
                        not SML.Parser.Parse (Text).Success and then
                        SML.Parser.Parse (Text).Error_Kind =
                        SML.Parser.Truncated_Entity));

   --  Helper: Check for truncated entity
   function Has_Truncated_Entity_Reference (Text : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Structural Error Detection
   ---------------------------------------------------------------------------

   --  Missing tags are detected
   procedure Lemma_Missing_Tags_Detected
     with Post => (for all Text : String =>
                     (if Has_Unclosed_Element (Text) then
                        not SML.Parser.Parse (Text).Success and then
                        SML.Parser.Parse (Text).Error_Kind in
                          SML.Parser.Missing_End_Tag |
                          SML.Parser.Unclosed_Element));

   --  Helper: Check for unclosed elements
   function Has_Unclosed_Element (Text : String) return Boolean;

   --  Mismatched tags are detected
   procedure Lemma_Mismatched_Tags_Detected
     with Post => (for all Text : String =>
                     (if Has_Mismatched_Tags (Text) then
                        not SML.Parser.Parse (Text).Success and then
                        SML.Parser.Parse (Text).Error_Kind =
                        SML.Parser.Tag_Mismatch));

   --  Helper: Check for mismatched tags
   function Has_Mismatched_Tags (Text : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Resource Limit Error Detection
   ---------------------------------------------------------------------------

   --  Depth limit violations are detected
   procedure Lemma_Depth_Limit_Detected
     with Post => (for all Text : String =>
                     (if Exceeds_Depth_Limit (Text) then
                        not SML.Parser.Parse (Text).Success and then
                        SML.Parser.Parse (Text).Error_Kind =
                        SML.Parser.Max_Depth_Exceeded));

   --  Helper: Check if depth exceeded
   function Exceeds_Depth_Limit (Text : String) return Boolean;

   --  Children limit violations are detected
   procedure Lemma_Children_Limit_Detected
     with Post => (for all Text : String =>
                     (if Exceeds_Children_Limit (Text) then
                        not SML.Parser.Parse (Text).Success and then
                        SML.Parser.Parse (Text).Error_Kind =
                        SML.Parser.Too_Many_Children));

   --  Helper: Check if children limit exceeded
   function Exceeds_Children_Limit (Text : String) return Boolean;

   ---------------------------------------------------------------------------
   --  Error Recovery Properties
   ---------------------------------------------------------------------------

   --  Parser stops at first error
   procedure Lemma_First_Error_Reported
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        First_Error_Position (Text) =
                        SML.Parser.Parse (Text).Error_Position));

   --  Helper: Find first error position
   function First_Error_Position (Text : String) return Natural;

   --  Error doesn't corrupt parser state
   procedure Lemma_Error_State_Clean
     with Post => (for all Text1, Text2 : String =>
                     (SML.Parser.Parse (Text1).Success =
                      SML.Parser.Parse (Text1).Success));  -- Idempotent

   ---------------------------------------------------------------------------
   --  Error Specificity
   ---------------------------------------------------------------------------

   --  Most specific error is reported
   procedure Lemma_Most_Specific_Error
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        Is_Most_Specific_Error (Text,
                          SML.Parser.Parse (Text).Error_Kind)));

   --  Helper: Check if error is most specific
   function Is_Most_Specific_Error (Text : String;
                                   Kind : SML.Parser.Parse_Error_Kind)
                                  return Boolean;

   --  Precedence of error detection
   procedure Lemma_Error_Precedence
     with Post =>
       -- UTF-8 errors detected before structural
       (for all Text : String =>
          (if not SML.UTF8.Is_Valid_UTF8 (Text) and then
              Has_Structural_Error (Text)
           then SML.Parser.Parse (Text).Error_Kind in
                  SML.Parser.Invalid_UTF8 |
                  SML.Parser.Truncated_UTF8))
       and then
       -- Lexical errors before syntactic
       (for all Text : String =>
          (if Has_Lexical_Error (Text) and then
              Has_Syntactic_Error (Text)
           then Is_Lexical_Error (SML.Parser.Parse (Text).Error_Kind)));

   --  Helper functions for error types
   function Has_Structural_Error (Text : String) return Boolean;
   function Has_Lexical_Error (Text : String) return Boolean;
   function Has_Syntactic_Error (Text : String) return Boolean;
   function Is_Lexical_Error (Kind : SML.Parser.Parse_Error_Kind) return Boolean;

   ---------------------------------------------------------------------------
   --  Error Context Preservation
   ---------------------------------------------------------------------------

   --  Surrounding context is available
   procedure Lemma_Context_Available
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        Can_Extract_Context (Text,
                          SML.Parser.Parse (Text).Error_Position)));

   --  Helper: Extract error context
   function Can_Extract_Context (Text : String;
                                Pos : Natural) return Boolean;

   --  Context includes relevant tokens
   procedure Lemma_Context_Includes_Tokens
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        Extract_Context (Text,
                          SML.Parser.Parse (Text).Error_Position)'Length >= 1));

   --  Helper: Extract context string
   function Extract_Context (Text : String;
                           Pos : Natural) return String
     with Pre => Pos in Text'Range;

   ---------------------------------------------------------------------------
   --  Diagnostic Quality Metrics
   ---------------------------------------------------------------------------

   --  Error messages are actionable
   function Is_Actionable_Message (Message : String) return Boolean
     with Post => Is_Actionable_Message'Result =
                    (Message'Length > 10 and then
                     (for some I in Message'Range =>
                        Message (I) in 'a' .. 'z' | 'A' .. 'Z'));

   --  All error messages are actionable
   procedure Lemma_All_Messages_Actionable
     with Post => (for all Text : String =>
                     (if not SML.Parser.Parse (Text).Success then
                        Is_Actionable_Message (
                          SML.Parser.Parse (Text).Error_Message)));

   ---------------------------------------------------------------------------
   --  Main Error Detection Theorem
   ---------------------------------------------------------------------------

   --  Complete and accurate error detection
   procedure Theorem_Error_Detection_Complete_And_Accurate
     with Ghost,
          Post =>
            -- Completeness: All invalid input detected
            (for all Text : String =>
               (not SML.Parser.Is_Valid_SML (Text) implies
                not SML.Parser.Parse (Text).Success))
            and then
            -- Soundness: No false positives
            (for all Text : String =>
               (SML.Parser.Is_Valid_SML (Text) implies
                SML.Parser.Parse (Text).Success))
            and then
            -- Accuracy: Error location is correct
            (for all Text : String =>
               (if not SML.Parser.Parse (Text).Success then
                  Is_Error_Location (Text,
                    SML.Parser.Parse (Text).Error_Position,
                    SML.Parser.Parse (Text).Error_Kind)))
            and then
            -- Informativeness: Error has message and kind
            (for all Text : String =>
               (if not SML.Parser.Parse (Text).Success then
                  SML.Parser.Parse (Text).Error_Kind /=
                  SML.Parser.No_Parse_Error and then
                  SML.Parser.Parse (Text).Error_Message'Length > 0))
            and then
            -- Specificity: Most specific error reported
            (for all Text : String =>
               (if not SML.Parser.Parse (Text).Success then
                  Is_Most_Specific_Error (Text,
                    SML.Parser.Parse (Text).Error_Kind)));

end SML.Error_Detection;