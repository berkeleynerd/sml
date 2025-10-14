------------------------------------------------------------------------------
--  SML.Schema Package Specification
--  Schema validation for Simple Markup Language (SML) documents
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

with SML.DOM;

package SML.Schema
  with SPARK_Mode => On
is

   --  SML.Schema provides schema validation capabilities for SML documents.
   --  Schemas are expressed in SML itself (self-hosting) and define:
   --  - Element vocabulary (allowed element names)
   --  - Type constraints (string, integer, boolean, decimal)
   --  - Structure rules (sequence, choice)
   --  - Cardinality constraints (minOccurs, maxOccurs)

   ---------------------------------------------------------------------------
   --  Constants and Bounds
   ---------------------------------------------------------------------------

   --  Maximum number of element definitions in a schema
   Max_Elements : constant Natural := 100;

   --  Maximum number of type definitions in a schema
   Max_Types : constant Natural := 100;

   --  Maximum length for names (element names, type names)
   Max_Name_Length : constant Natural := 50;

   --  Maximum number of enumeration values per type
   Max_Enum_Values : constant Natural := 20;

   --  Maximum nesting depth for complex types
   Max_Type_Depth : constant Natural := 10;

   ---------------------------------------------------------------------------
   --  Basic Types
   ---------------------------------------------------------------------------

   --  Bounded string type for names
   subtype Name_Length is Natural range 0 .. Max_Name_Length;
   type Bounded_String is record
      Length : Name_Length := 0;
      Data   : String (1 .. Max_Name_Length) := [others => ' '];
   end record;

   --  Compare two bounded strings for equality
   overriding function "=" (Left, Right : Bounded_String) return Boolean;

   --  Empty bounded string constant
   Empty_String : constant Bounded_String :=
      (Length => 0, Data => [others => ' ']);

   ---------------------------------------------------------------------------
   --  Validation Result Types
   ---------------------------------------------------------------------------

   --  Validation status
   type Validation_Status is (Valid, Invalid);

   --  Validation result with error information
   type Validation_Result (Status : Validation_Status := Invalid) is record
      case Status is
         when Valid =>
            null;
         when Invalid =>
            Error_Message : Bounded_String;
            Error_Path    : Bounded_String;  --  e.g., "/config/database/port"
            Line          : Natural := 0;
            Column        : Natural := 0;
      end case;
   end record;

   --  Successful validation result
   Valid_Result : constant Validation_Result := (Status => Valid);

   ---------------------------------------------------------------------------
   --  Schema Definition Types
   ---------------------------------------------------------------------------

   --  Simple type kinds (built-in types)
   type Simple_Type_Kind is (
      String_Type,    --  Any text content
      Integer_Type,   --  Signed integer
      Boolean_Type,   --  true/false
      Decimal_Type    --  Decimal number
   );

   --  Content model kinds for complex types
   type Content_Model_Kind is (
      Sequence_Model,  --  Elements must appear in order
      Choice_Model,    --  Exactly one element must appear
      Simple_Model     --  Simple content (text only)
   );

   --  Element definition with cardinality
   type Element_Definition is record
      Name       : Bounded_String;
      Type_Name  : Bounded_String;
      Min_Occurs : Natural := 1;
      Max_Occurs : Natural := 1;  --  Use Natural'Last for "unbounded"
   end record;

   --  Array of element definitions
   type Element_Array is array (1 .. Max_Elements) of Element_Definition;

   --  Simple type definition with restrictions
   type Simple_Type_Definition is record
      Name      : Bounded_String;
      Base_Type : Simple_Type_Kind;
      Min_Value : Integer := Integer'First;  --  For integer types
      Max_Value : Integer := Integer'Last;   --  For integer types
   end record;

   --  Array of simple type definitions
   type Simple_Type_Array is array (1 .. Max_Types) of Simple_Type_Definition;

   ---------------------------------------------------------------------------
   --  Schema Document Type
   ---------------------------------------------------------------------------

   --  Main schema document type (limited for SPARK safety)
   type Schema_Document is limited private;

   ---------------------------------------------------------------------------
   --  Schema Construction Functions
   ---------------------------------------------------------------------------

   --  Initialize an empty schema
   procedure Initialize (Schema : out Schema_Document)
     with
       Post => Is_Empty (Schema);

   --  Check if schema is empty
   function Is_Empty (Schema : Schema_Document) return Boolean
     with Ghost;

   --  Add an element definition to the schema
   procedure Add_Element (
      Schema  : in out Schema_Document;
      Element : Element_Definition;
      Success : out Boolean)
     with
       Pre  => Element.Name.Length > 0;

   --  Add a simple type definition to the schema
   procedure Add_Simple_Type (
      Schema    : in out Schema_Document;
      Type_Def  : Simple_Type_Definition;
      Success   : out Boolean)
     with
       Pre  => Type_Def.Name.Length > 0;

   --  Get count of element definitions (Ghost function for proofs)
   function Element_Count (Schema : Schema_Document) return Natural
     with Ghost,
          Post => Element_Count'Result <= Max_Elements;

   --  Get count of type definitions (Ghost function for proofs)
   function Type_Count (Schema : Schema_Document) return Natural
     with Ghost,
          Post => Type_Count'Result <= Max_Types;

   ---------------------------------------------------------------------------
   --  Validation Functions
   ---------------------------------------------------------------------------

   --  Check if an element name is valid according to the schema
   function Is_Valid_Element_Name (
      Schema : Schema_Document;
      Name   : String) return Boolean
     with
       Pre => Name'Length <= Max_Name_Length;

   --  Validate an element node against the schema
   function Validate_Element (
      Schema : Schema_Document;
      Doc    : DOM.Document;
      Node   : DOM.Node_Id) return Validation_Result;

   --  Validate entire document against schema
   function Validate_Document (
      Schema : Schema_Document;
      Doc    : DOM.Document) return Validation_Result;

   ---------------------------------------------------------------------------
   --  Utility Functions
   ---------------------------------------------------------------------------

   --  Create a bounded string from a regular string
   function To_Bounded_String (S : String) return Bounded_String
     with
       Pre  => S'Length <= Max_Name_Length,
       Post => To_Bounded_String'Result.Length = S'Length;

   --  Convert bounded string to regular string
   function To_String (B : Bounded_String) return String
     with
       Post => To_String'Result'Length = B.Length;

private

   ---------------------------------------------------------------------------
   --  Private Schema Document Implementation
   ---------------------------------------------------------------------------

   type Schema_Document is limited record
      --  Element definitions
      Elements      : Element_Array := [others => (Name => Empty_String,
                                                   Type_Name => Empty_String,
                                                   Min_Occurs => 1,
                                                   Max_Occurs => 1)];
      Element_Count : Natural := 0;

      --  Simple type definitions
      Simple_Types  : Simple_Type_Array :=
         [others => (Name => Empty_String,
                     Base_Type => String_Type,
                     Min_Value => Integer'First,
                     Max_Value => Integer'Last)];
      Type_Count    : Natural := 0;

      --  Root element name (if specified)
      Root_Element  : Bounded_String := Empty_String;
   end record;

   --  Ghost function implementations
   function Is_Empty (Schema : Schema_Document) return Boolean is
      (Schema.Element_Count = 0 and then Schema.Type_Count = 0);

   function Element_Count (Schema : Schema_Document) return Natural is
      (Schema.Element_Count);

   function Type_Count (Schema : Schema_Document) return Natural is
      (Schema.Type_Count);

end SML.Schema;