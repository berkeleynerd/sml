------------------------------------------------------------------------------
--  SML.Schema.Loader Package Specification
--  Load schema definitions from SML documents
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML.DOM;

package SML.Schema.Loader
  with SPARK_Mode => On
is

   use SML.DOM;  --  For Node_Id comparison operators

   --  SML.Schema.Loader: Parse schema definitions from SML DOM trees.
   --  Converts a schema document (expressed in SML) into a Schema_Document
   --  that can be used for validation.

   ---------------------------------------------------------------------------
   --  Schema Loading Result Type
   ---------------------------------------------------------------------------

   --  Result of loading a schema: either success or error
   type Schema_Load_Result (Success : Boolean := False) is limited record
      case Success is
         when True =>
            Schema : Schema_Document;

         when False =>
            Error_Message : Bounded_String;
            Error_Line    : Natural := 0;
      end case;
   end record;

   ---------------------------------------------------------------------------
   --  Main Loading Function
   ---------------------------------------------------------------------------

   --  Load schema from a parsed SML document
   --  The document must have <schema> as root element
   function Load_Schema (Doc : DOM.Document) return Schema_Load_Result
   with Pre => DOM.Is_Well_Formed (Doc);

   ---------------------------------------------------------------------------
   --  Helper Functions (exposed for testing)
   ---------------------------------------------------------------------------

   --  Find child element by name, returns Null_Node if not found
   function Find_Child_Element
     (Doc    : DOM.Document;
      Parent : DOM.Node_Id;
      Name   : String) return DOM.Node_Id
   with Pre => DOM.Is_Well_Formed (Doc)
                and then Parent /= DOM.Null_Node
                and then Name'Length > 0
                and then Name'Length <= Max_Name_Length;

   --  Get text content of element (first Text child)
   --  Returns empty string if no text node found
   function Get_Element_Text
     (Doc     : DOM.Document;
      Element : DOM.Node_Id) return String
   with Pre => DOM.Is_Well_Formed (Doc)
                and then Element /= DOM.Null_Node,
        Post => Get_Element_Text'Result'Length <= Max_Name_Length;

   --  Get integer value from named child element
   --  Returns Default_Value if child not found or not parseable
   function Get_Integer_Value
     (Doc           : DOM.Document;
      Parent        : DOM.Node_Id;
      Child_Name    : String;
      Default_Value : Integer) return Integer
   with Pre => DOM.Is_Well_Formed (Doc)
                and then Parent /= DOM.Null_Node
                and then Child_Name'Length > 0
                and then Child_Name'Length <= Max_Name_Length;

   --  Get natural value from named child element
   --  Returns Default_Value if child not found or not parseable
   function Get_Natural_Value
     (Doc           : DOM.Document;
      Parent        : DOM.Node_Id;
      Child_Name    : String;
      Default_Value : Natural) return Natural
   with Pre => DOM.Is_Well_Formed (Doc)
                and then Parent /= DOM.Null_Node
                and then Child_Name'Length > 0
                and then Child_Name'Length <= Max_Name_Length;

end SML.Schema.Loader;
