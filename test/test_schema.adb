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
            (Name => To_Bounded_String ("portType"),
             Base_Type => Integer_Type,
             Min_Value => 1,
             Max_Value => 65535);
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
            (Name => To_Bounded_String ("stringType"),
             Base_Type => String_Type,
             Min_Value => Integer'First,
             Max_Value => Integer'Last);
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

begin
   Put_Line ("=== SML Schema Tests ===");
   New_Line;

   Test_Basic_Schema;
   Test_Document_Validation;
   Test_Simple_Types;

   New_Line;
   Put_Line ("=== All Tests Completed ===");
end Test_Schema;