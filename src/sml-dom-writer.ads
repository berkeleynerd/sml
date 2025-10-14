------------------------------------------------------------------------------
--  SML.DOM.Writer Package Specification
--  DOM Serialization to SML Text
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML.DOM;

package SML.DOM.Writer
  with SPARK_Mode => On
is

   --  SML.DOM.Writer: Serializes DOM trees back to SML text format.
   --  Automatically skips logically deleted nodes during serialization.
   --  Output is guaranteed to be valid SML that can be re-parsed.

   ---------------------------------------------------------------------------
   --  Serialization Functions
   ---------------------------------------------------------------------------

   --  Serialize DOM tree to compact SML text (no formatting)
   function Serialize (Doc : SML.DOM.Document) return String
   with Pre => SML.DOM.Is_Well_Formed (Doc), Global => null;

   --  Serialize DOM tree with pretty-printing (indentation and newlines)
   function Serialize_Formatted
     (Doc : SML.DOM.Document; Indent_Spaces : Natural := 2) return String
   with
     Pre => SML.DOM.Is_Well_Formed (Doc) and then Indent_Spaces <= 10,
     Global => null;

   ---------------------------------------------------------------------------
   --  Size Estimation (for pre-allocation)
   ---------------------------------------------------------------------------

   --  Calculate maximum possible size of serialized output
   function Calculate_Max_Size (Doc : SML.DOM.Document) return Natural
   with Pre => SML.DOM.Is_Well_Formed (Doc), Global => null;

end SML.DOM.Writer;
