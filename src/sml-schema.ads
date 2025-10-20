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

   --  Maximum string length restrictions
   Max_String_Length : constant Natural := 1000;

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
   overriding
   function "=" (Left, Right : Bounded_String) return Boolean;

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
   type Simple_Type_Kind is
     (String_Type,    --  Any text content
      Integer_Type,   --  Signed integer
      Boolean_Type,   --  true/false
      Decimal_Type    --  Decimal number
     );

   --  Content model kinds for complex types
   type Content_Model_Kind is
     (Sequence_Model,  --  Elements must appear in order
      Choice_Model,    --  Exactly one element must appear
      All_Model,       --  Unordered; each child 0..1 unless specified
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

   --  Array type for enumeration values
   type Enum_Value_Array is array (1 .. Max_Enum_Values) of Bounded_String;

   --  Enhanced simple type definition with restrictions
   type Simple_Type_Definition is record
      Name        : Bounded_String;
      Base_Type   : Simple_Type_Kind;
      --  Integer restrictions
      Min_Value   : Integer := Integer'First;
      Max_Value   : Integer := Integer'Last;
      --  Decimal restrictions
      Dec_Min     : Float := Float'First;
      Dec_Max     : Float := Float'Last;
      --  String restrictions
      Min_Length  : Natural := 0;
      Max_Length  : Natural := Max_String_Length;
      Prefix      : Bounded_String := Empty_String;
      Suffix      : Bounded_String := Empty_String;
      --  Enumeration values
      Enum_Values : Enum_Value_Array := [others => Empty_String];
      Enum_Count  : Natural := 0;
   end record;

   --  Array of simple type definitions
   type Simple_Type_Array is array (1 .. Max_Types) of Simple_Type_Definition;

   --  Maximum children in a sequence or choice
   Max_Sequence_Elements : constant Natural := 20;

   --  Element reference in sequences/choices
   type Element_Ref is record
      Element_Name : Bounded_String;
      Type_Name    : Bounded_String := Empty_String;
      Min_Occurs   : Natural := 1;
      Max_Occurs   : Natural := 1;  --  Natural'Last = unbounded
   end record;

   --  Array of element references for sequences/choices
   type Element_Ref_Array is array (1 .. Max_Sequence_Elements) of Element_Ref;

   --  Complex type definition with content model
   type Complex_Type_Definition is record
      Name          : Bounded_String;
      Content_Model : Content_Model_Kind := Sequence_Model;
      --  Group-level occurrence (sequence/choice). For All_Model, Max must be 1 and Min ∈ {0,1}
      Group_Min_Occurs : Natural := 1;
      Group_Max_Occurs : Natural := 1;  -- Natural'Last = unbounded (not for All_Model)
      --  For Simple_Model: text content validated against this simple type
      Simple_Content_Type_Name : Bounded_String := Empty_String;
      Children      : Element_Ref_Array :=
        [others =>
           (Element_Name => Empty_String,
            Type_Name    => Empty_String,
            Min_Occurs   => 1,
            Max_Occurs   => 1)];
      Child_Count   : Natural := 0;
   end record;

   --  Array of complex type definitions
   type Complex_Type_Array is
     array (1 .. Max_Types) of Complex_Type_Definition;

   ---------------------------------------------------------------------------
   --  Schema Document Type
   ---------------------------------------------------------------------------

   --  Forward declaration for invariant function
   type Schema_Document is limited private;

   --  Type invariant function
   function Schema_Invariant (Schema : Schema_Document) return Boolean
   with Ghost;

   ---------------------------------------------------------------------------
   --  Schema Construction Functions
   ---------------------------------------------------------------------------

   --  Initialize an empty schema
   procedure Initialize (Schema : out Schema_Document)
   with Post => Is_Empty (Schema);

   --  Check if schema is empty
   function Is_Empty (Schema : Schema_Document) return Boolean
   with Ghost;

   --  Add an element definition to the schema
   procedure Add_Element
     (Schema  : in out Schema_Document;
      Element : Element_Definition;
      Success : out Boolean)
   with Pre => Element.Name.Length > 0;

   --  Add a simple type definition to the schema
   procedure Add_Simple_Type
     (Schema   : in out Schema_Document;
      Type_Def : Simple_Type_Definition;
      Success  : out Boolean)
   with Pre => Type_Def.Name.Length > 0;

   --  Add a complex type definition to the schema
   procedure Add_Complex_Type
     (Schema   : in out Schema_Document;
      Type_Def : Complex_Type_Definition;
      Success  : out Boolean)
   with Pre => Type_Def.Name.Length > 0;

   --  Get count of element definitions (Ghost function for proofs)
   function Element_Count (Schema : Schema_Document) return Natural
   with Ghost, Post => Element_Count'Result <= Max_Elements;

   --  Get count of type definitions (Ghost function for proofs)
   function Type_Count (Schema : Schema_Document) return Natural
   with Ghost, Post => Type_Count'Result <= Max_Types;

   ---------------------------------------------------------------------------
   --  Validation Functions
   ---------------------------------------------------------------------------

   --  Check if an element name is valid according to the schema
   function Is_Valid_Element_Name
     (Schema : Schema_Document; Name : String) return Boolean
   with Pre => Name'Length <= Max_Name_Length;

   --  Validate an element node against the schema
   function Validate_Element
     (Schema : Schema_Document; Doc : DOM.Document; Node : DOM.Node_Id)
      return Validation_Result;

   --  Validate entire document against schema
   function Validate_Document
     (Schema : Schema_Document; Doc : DOM.Document) return Validation_Result;

   --  Set the required root element name (optional policy)
   procedure Set_Root_Element (Schema : in out Schema_Document; Name : String)
   with Pre => Name'Length > 0 and then Name'Length <= Max_Name_Length;

   --  Validate element children against complex type structure
   function Validate_Structure
     (Schema      : Schema_Document;
      Doc         : DOM.Document;
      Parent_Node : DOM.Node_Id;
      Type_Name   : Bounded_String) return Validation_Result;

   --  Check cardinality constraints for child elements
   function Check_Cardinality
     (Expected_Min : Natural;
      Expected_Max : Natural;
      Actual_Count : Natural;
      Element_Name : String) return Validation_Result;

   --  Validate text content against a simple type
   function Validate_Content
     (Schema : Schema_Document; Type_Name : Bounded_String; Content : String)
      return Validation_Result;

   --  Helper to validate integer content
   function Validate_Integer_Content
     (Content : String; Min_Value : Integer; Max_Value : Integer)
      return Validation_Result;

   --  Helper to validate boolean content
   function Validate_Boolean_Content
     (Content : String) return Validation_Result;

   --  Helper to validate decimal content
   function Validate_Decimal_Content
     (Content : String) return Validation_Result;

   --  Helper to validate against enumeration
   function Validate_Enum_Content
     (Content : String; Enum_Values : Enum_Value_Array; Enum_Count : Natural)
      return Validation_Result
   with
     Pre =>
       Enum_Count <= Max_Enum_Values
       and then Content'Length <= Max_Name_Length;

   ---------------------------------------------------------------------------
   --  Utility Functions
   ---------------------------------------------------------------------------

   --  Create a bounded string from a regular string
   function To_Bounded_String (S : String) return Bounded_String
   with
     Pre => S'Length <= Max_Name_Length,
     Post => To_Bounded_String'Result.Length = S'Length;

   --  Convert bounded string to regular string
   function To_String (B : Bounded_String) return String
   with Post => To_String'Result'Length = B.Length;

private

   ---------------------------------------------------------------------------
   --  Private Schema Document Implementation
   ---------------------------------------------------------------------------

   type Schema_Document is limited record
      --  Element definitions
      Elements      : Element_Array :=
        [others =>
           (Name       => Empty_String,
            Type_Name  => Empty_String,
            Min_Occurs => 1,
            Max_Occurs => 1)];
      Element_Count : Natural := 0;

      --  Simple type definitions
      Simple_Types      : Simple_Type_Array :=
        [others =>
           (Name        => Empty_String,
            Base_Type   => String_Type,
            Min_Value   => Integer'First,
            Max_Value   => Integer'Last,
            Dec_Min     => Float'First,
            Dec_Max     => Float'Last,
            Min_Length  => 0,
            Max_Length  => Max_String_Length,
            Prefix      => Empty_String,
            Suffix      => Empty_String,
            Enum_Values => [others => Empty_String],
            Enum_Count  => 0)];
      Simple_Type_Count : Natural := 0;

      --  Complex type definitions
      Complex_Types      : Complex_Type_Array :=
        [others =>
           (Name          => Empty_String,
            Content_Model => Sequence_Model,
            Group_Min_Occurs => 1,
            Group_Max_Occurs => 1,
            Simple_Content_Type_Name => Empty_String,
            Children      =>
              [others =>
                 (Element_Name => Empty_String,
                  Type_Name    => Empty_String,
                  Min_Occurs   => 1,
                  Max_Occurs   => 1)],
            Child_Count   => 0)];
      Complex_Type_Count : Natural := 0;

      --  Root element name (if specified)
      Root_Element : Bounded_String := Empty_String;
   end record
   with
     Type_Invariant =>
       Schema_Document.Element_Count <= Max_Elements
       and then Schema_Document.Simple_Type_Count <= Max_Types
       and then Schema_Document.Complex_Type_Count <= Max_Types;

   --  Ghost function implementations
   function Schema_Invariant (Schema : Schema_Document) return Boolean
   is (Schema.Element_Count <= Max_Elements
       and then Schema.Simple_Type_Count <= Max_Types
       and then Schema.Complex_Type_Count <= Max_Types);

   function Is_Empty (Schema : Schema_Document) return Boolean
   is (Schema.Element_Count = 0
       and then Schema.Simple_Type_Count = 0
       and then Schema.Complex_Type_Count = 0);

   function Element_Count (Schema : Schema_Document) return Natural
   is (Schema.Element_Count);

   function Type_Count (Schema : Schema_Document) return Natural
   is (Schema.Simple_Type_Count + Schema.Complex_Type_Count);

end SML.Schema;
