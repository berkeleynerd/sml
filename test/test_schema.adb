------------------------------------------------------------------------------
--  Test Program for SML.Schema
--  Validates schema functionality with various test cases
------------------------------------------------------------------------------

with Ada.Text_IO;
with SML.DOM;
with SML.DOM.Parser;
with SML.Schema;

procedure Test_Schema is
   use Ada.Text_IO;
   use SML.Schema;

   --  Forward declarations
   procedure Test_Basic_Schema;
   procedure Test_Document_Validation;
   procedure Test_Simple_Types;
   procedure Test_Structure_Validation;
   procedure Test_Content_Type_Validation;
   procedure Test_Enumeration_Validation;
   procedure Test_Choice_Group_Validation;

   procedure Test_Basic_Schema is
      Schema : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Basic Schema Creation... ");

      --  Initialize schema
      Initialize (Schema);

      --  Add some element definitions
      declare
         Config_Element : constant Element_Definition :=
            (Name => To_Bounded_String ("config"),
             Type_Name => To_Bounded_String ("configType"),
             Min_Occurs => 1,
             Max_Occurs => 1);

         Database_Element : constant Element_Definition :=
            (Name => To_Bounded_String ("database"),
             Type_Name => To_Bounded_String ("databaseType"),
             Min_Occurs => 1,
             Max_Occurs => 1);
      begin
         Add_Element (Schema, Config_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add config element");
            return;
         end if;

         Add_Element (Schema, Database_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add database element");
            return;
         end if;
      end;

      --  Test element name validation
      if Is_Valid_Element_Name (Schema, "config") then
         Put ("✓ config recognized, ");
      else
         Put_Line ("FAILED: config not recognized");
         return;
      end if;

      if Is_Valid_Element_Name (Schema, "database") then
         Put ("✓ database recognized, ");
      else
         Put_Line ("FAILED: database not recognized");
         return;
      end if;

      if not Is_Valid_Element_Name (Schema, "invalid") then
         Put_Line ("✓ invalid rejected");
      else
         Put_Line ("FAILED: invalid element accepted");
         return;
      end if;

      Put_Line ("PASSED");
   end Test_Basic_Schema;

   procedure Test_Document_Validation is
      Schema : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Document Validation... ");

      --  Initialize schema
      Initialize (Schema);

      --  Add root element
      declare
         Root_Element : constant Element_Definition :=
            (Name => To_Bounded_String ("root"),
             Type_Name => To_Bounded_String ("rootType"),
             Min_Occurs => 1,
             Max_Occurs => 1);
      begin
         Add_Element (Schema, Root_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add root element");
            return;
         end if;
      end;

      --  Parse a simple document
      declare
         Doc_Result : constant SML.DOM.Parser.Parse_Result :=
            SML.DOM.Parser.Parse ("<root>Test content</root>");
      begin
         if not Doc_Result.Success then
            Put_Line ("FAILED: Could not parse test document");
            return;
         end if;

         --  Validate against schema
         declare
            Validation : constant Validation_Result :=
               Validate_Document (Schema, Doc_Result.Doc);
         begin
            if Validation.Status = Valid then
               Put_Line ("✓ Valid document accepted");
            else
               Put_Line ("FAILED: Valid document rejected: " &
                        To_String (Validation.Error_Message));
            end if;
         end;
      end;

      --  Test invalid document
      declare
         Invalid_Doc : constant SML.DOM.Parser.Parse_Result :=
            SML.DOM.Parser.Parse ("<unknown>Test</unknown>");
      begin
         if not Invalid_Doc.Success then
            Put_Line ("FAILED: Could not parse invalid test document");
            return;
         end if;

         declare
            Validation : constant Validation_Result :=
               Validate_Document (Schema, Invalid_Doc.Doc);
         begin
            if Validation.Status = Invalid then
               Put_Line ("✓ Invalid document rejected: " &
                        To_String (Validation.Error_Message));
            else
               Put_Line ("FAILED: Invalid document accepted");
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_Document_Validation;

   procedure Test_Simple_Types is
      Schema : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Simple Type Definitions... ");

      Initialize (Schema);

      --  Add integer type with range
      declare
         Port_Type : constant Simple_Type_Definition :=
            (Name        => To_Bounded_String ("portType"),
             Base_Type   => Integer_Type,
             Min_Value   => 1,
             Max_Value   => 65535,
             Min_Length  => 0,
             Max_Length  => Max_String_Length,
             Enum_Values => [others => Empty_String],
             Enum_Count  => 0);
      begin
         Add_Simple_Type (Schema, Port_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add port type");
            return;
         end if;
      end;

      --  Add string type
      declare
         String_Type_Def : constant Simple_Type_Definition :=
            (Name        => To_Bounded_String ("stringType"),
             Base_Type   => String_Type,
             Min_Value   => Integer'First,
             Max_Value   => Integer'Last,
             Min_Length  => 0,
             Max_Length  => Max_String_Length,
             Enum_Values => [others => Empty_String],
             Enum_Count  => 0);
      begin
         Add_Simple_Type (Schema, String_Type_Def, Success);
         if not Success then
            Put_Line ("FAILED: Could not add string type");
            return;
         end if;
      end;

      Put_Line ("✓ Types added successfully");
      Put_Line ("PASSED");
   end Test_Simple_Types;

   procedure Test_Structure_Validation is
      Schema : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Structure and Cardinality Validation... ");

      Initialize (Schema);

      --  Define a complex type for configuration
      declare
         Config_Type : Complex_Type_Definition;
      begin
         Config_Type.Name := To_Bounded_String ("configType");
         Config_Type.Content_Model := Sequence_Model;
         Config_Type.Child_Count := 2;

         --  Database element (required, 1 occurrence)
         Config_Type.Children (1) :=
            (Element_Name => To_Bounded_String ("database"),
             Min_Occurs => 1,
             Max_Occurs => 1);

         --  Server element (optional, multiple)
         Config_Type.Children (2) :=
            (Element_Name => To_Bounded_String ("server"),
             Min_Occurs => 0,
             Max_Occurs => Natural'Last);  --  unbounded

         Add_Complex_Type (Schema, Config_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add complex type");
            return;
         end if;
      end;

      --  Add element definitions
      declare
         Config_Element : constant Element_Definition :=
            (Name => To_Bounded_String ("config"),
             Type_Name => To_Bounded_String ("configType"),
             Min_Occurs => 1,
             Max_Occurs => 1);

         Database_Element : constant Element_Definition :=
            (Name => To_Bounded_String ("database"),
             Type_Name => Empty_String,
             Min_Occurs => 1,
             Max_Occurs => 1);

         Server_Element : constant Element_Definition :=
            (Name => To_Bounded_String ("server"),
             Type_Name => Empty_String,
             Min_Occurs => 0,
             Max_Occurs => Natural'Last);
      begin
         Add_Element (Schema, Config_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add config element");
            return;
         end if;

         Add_Element (Schema, Database_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add database element");
            return;
         end if;

         Add_Element (Schema, Server_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add server element");
            return;
         end if;
      end;

      --  Test valid document with correct structure
      declare
         Valid_Doc : constant SML.DOM.Parser.Parse_Result :=
            SML.DOM.Parser.Parse (
               "<config>" &
               "  <database>db1</database>" &
               "  <server>srv1</server>" &
               "  <server>srv2</server>" &
               "</config>");
      begin
         if not Valid_Doc.Success then
            Put_Line ("FAILED: Could not parse valid test document");
            return;
         end if;

         declare
            Result : constant Validation_Result :=
               Validate_Document (Schema, Valid_Doc.Doc);
         begin
            if Result.Status = Valid then
               Put ("✓ Valid structure accepted, ");
            else
               Put_Line ("FAILED: Valid structure rejected: " &
                        To_String (Result.Error_Message));
               return;
            end if;
         end;
      end;

      --  Test missing required element
      declare
         Invalid_Doc : constant SML.DOM.Parser.Parse_Result :=
            SML.DOM.Parser.Parse (
               "<config>" &
               "  <server>srv1</server>" &
               "</config>");
      begin
         if not Invalid_Doc.Success then
            Put_Line ("FAILED: Could not parse invalid test document");
            return;
         end if;

         declare
            Result : constant Validation_Result :=
               Validate_Document (Schema, Invalid_Doc.Doc);
         begin
            if Result.Status = Invalid then
               Put_Line ("✓ Missing required element detected");
            else
               Put_Line ("FAILED: Missing required element not detected");
               return;
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_Structure_Validation;

   procedure Test_Content_Type_Validation is
      Schema : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Content Type Validation... ");

      Initialize (Schema);

      --  Add integer type with range
      declare
         Age_Type : Simple_Type_Definition;
      begin
         Age_Type.Name := To_Bounded_String ("ageType");
         Age_Type.Base_Type := Integer_Type;
         Age_Type.Min_Value := 0;
         Age_Type.Max_Value := 150;

         Add_Simple_Type (Schema, Age_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add age type");
            return;
         end if;
      end;

      --  Test valid integer
      declare
         Result : constant Validation_Result :=
            Validate_Integer_Content ("25", 0, 150);
      begin
         if Result.Status = Valid then
            Put ("✓ Valid integer accepted, ");
         else
            Put_Line ("FAILED: Valid integer rejected");
            return;
         end if;
      end;

      --  Test invalid integer format
      declare
         Result : constant Validation_Result :=
            Validate_Integer_Content ("not_a_number", 0, 150);
      begin
         if Result.Status = Invalid then
            Put ("✓ Invalid integer rejected, ");
         else
            Put_Line ("FAILED: Invalid integer accepted");
            return;
         end if;
      end;

      --  Test integer out of range
      declare
         Result : constant Validation_Result :=
            Validate_Integer_Content ("200", 0, 150);
      begin
         if Result.Status = Invalid then
            Put ("✓ Out-of-range rejected, ");
         else
            Put_Line ("FAILED: Out-of-range integer accepted");
            return;
         end if;
      end;

      --  Test boolean validation
      declare
         Result_True : constant Validation_Result :=
            Validate_Boolean_Content ("true");
         Result_False : constant Validation_Result :=
            Validate_Boolean_Content ("false");
         Result_Invalid : constant Validation_Result :=
            Validate_Boolean_Content ("yes");
      begin
         if Result_True.Status = Valid
            and then Result_False.Status = Valid
            and then Result_Invalid.Status = Invalid
         then
            Put_Line ("✓ Boolean validation works");
         else
            Put_Line ("FAILED: Boolean validation error");
            return;
         end if;
      end;

      Put_Line ("PASSED");
   end Test_Content_Type_Validation;

   procedure Test_Enumeration_Validation is
      Enum_Values : Enum_Value_Array := [others => Empty_String];
   begin
      Put ("Test: Enumeration Validation... ");

      --  Set up enum type for log levels
      Enum_Values (1) := To_Bounded_String ("DEBUG");
      Enum_Values (2) := To_Bounded_String ("INFO");
      Enum_Values (3) := To_Bounded_String ("WARNING");
      Enum_Values (4) := To_Bounded_String ("ERROR");

      --  Test valid enum values
      declare
         Result_Debug : constant Validation_Result :=
            Validate_Enum_Content ("DEBUG", Enum_Values, 4);
         Result_Error : constant Validation_Result :=
            Validate_Enum_Content ("ERROR", Enum_Values, 4);
      begin
         if Result_Debug.Status = Valid
            and then Result_Error.Status = Valid
         then
            Put ("✓ Valid enum values accepted, ");
         else
            Put_Line ("FAILED: Valid enum values rejected");
            return;
         end if;
      end;

      --  Test invalid enum value
      declare
         Result : constant Validation_Result :=
            Validate_Enum_Content ("TRACE", Enum_Values, 4);
      begin
         if Result.Status = Invalid then
            Put_Line ("✓ Invalid enum value rejected");
         else
            Put_Line ("FAILED: Invalid enum value accepted");
            return;
         end if;
      end;

      Put_Line ("PASSED");
   end Test_Enumeration_Validation;

   procedure Test_Choice_Group_Validation is
      Schema : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Choice Group Validation... ");

      Initialize (Schema);

      --  Create choice type for contact (email OR phone)
      declare
         Contact_Type : Complex_Type_Definition;
      begin
         Contact_Type.Name := To_Bounded_String ("contactType");
         Contact_Type.Content_Model := Choice_Model;
         Contact_Type.Child_Count := 2;

         Contact_Type.Children (1) :=
            (Element_Name => To_Bounded_String ("email"),
             Min_Occurs => 1,
             Max_Occurs => 1);

         Contact_Type.Children (2) :=
            (Element_Name => To_Bounded_String ("phone"),
             Min_Occurs => 1,
             Max_Occurs => 1);

         Add_Complex_Type (Schema, Contact_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add choice type");
            return;
         end if;
      end;

      --  Add element definitions
      declare
         Contact_Element : constant Element_Definition :=
            (Name => To_Bounded_String ("contact"),
             Type_Name => To_Bounded_String ("contactType"),
             Min_Occurs => 1,
             Max_Occurs => 1);

         Email_Element : constant Element_Definition :=
            (Name => To_Bounded_String ("email"),
             Type_Name => Empty_String,
             Min_Occurs => 1,
             Max_Occurs => 1);

         Phone_Element : constant Element_Definition :=
            (Name => To_Bounded_String ("phone"),
             Type_Name => Empty_String,
             Min_Occurs => 1,
             Max_Occurs => 1);
      begin
         Add_Element (Schema, Contact_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add contact element");
            return;
         end if;

         Add_Element (Schema, Email_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add email element");
            return;
         end if;

         Add_Element (Schema, Phone_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add phone element");
            return;
         end if;
      end;

      --  Test valid choice (email only)
      declare
         Valid_Email : constant SML.DOM.Parser.Parse_Result :=
            SML.DOM.Parser.Parse (
               "<contact>" &
               "  <email>test@example.com</email>" &
               "</contact>");
      begin
         if not Valid_Email.Success then
            Put_Line ("FAILED: Could not parse valid email document");
            return;
         end if;

         declare
            Result : constant Validation_Result :=
               Validate_Document (Schema, Valid_Email.Doc);
         begin
            if Result.Status = Valid then
               Put ("✓ Choice with email accepted, ");
            else
               Put_Line ("FAILED: Valid choice rejected: " &
                        To_String (Result.Error_Message));
               return;
            end if;
         end;
      end;

      --  Test valid choice (phone only)
      declare
         Valid_Phone : constant SML.DOM.Parser.Parse_Result :=
            SML.DOM.Parser.Parse (
               "<contact>" &
               "  <phone>555-1234</phone>" &
               "</contact>");
      begin
         if not Valid_Phone.Success then
            Put_Line ("FAILED: Could not parse valid phone document");
            return;
         end if;

         declare
            Result : constant Validation_Result :=
               Validate_Document (Schema, Valid_Phone.Doc);
         begin
            if Result.Status = Valid then
               Put ("✓ Choice with phone accepted, ");
            else
               Put_Line ("FAILED: Valid choice rejected");
               return;
            end if;
         end;
      end;

      --  Test invalid choice (both email and phone)
      declare
         Invalid_Both : constant SML.DOM.Parser.Parse_Result :=
            SML.DOM.Parser.Parse (
               "<contact>" &
               "  <email>test@example.com</email>" &
               "  <phone>555-1234</phone>" &
               "</contact>");
      begin
         if not Invalid_Both.Success then
            Put_Line ("FAILED: Could not parse invalid both document");
            return;
         end if;

         declare
            Result : constant Validation_Result :=
               Validate_Document (Schema, Invalid_Both.Doc);
         begin
            if Result.Status = Invalid then
               Put_Line ("✓ Both options rejected");
            else
               Put_Line ("FAILED: Invalid choice (both) accepted");
               return;
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_Choice_Group_Validation;

begin
   Put_Line ("=== SML Schema Tests ===");
   New_Line;

   Test_Basic_Schema;
   Test_Document_Validation;
   Test_Simple_Types;
   Test_Structure_Validation;
   Test_Content_Type_Validation;
   Test_Enumeration_Validation;
   Test_Choice_Group_Validation;

   New_Line;
   Put_Line ("=== All Tests Completed ===");
end Test_Schema;