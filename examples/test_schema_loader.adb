------------------------------------------------------------------------------
--  Test Program for SML.Schema.Loader
--  Validates schema loading from SML documents
------------------------------------------------------------------------------

with Ada.Text_IO;
with SML.DOM;
with SML.DOM.Parser;
with SML.Schema;
with SML.Schema.Loader;
with SML.IO;

procedure Test_Schema_Loader is
   use Ada.Text_IO;
   use SML.Schema;
   use SML.Schema.Loader;

   --  Forward declarations
   procedure Test_Integer_Simple_Type;
   procedure Test_String_Enum_Type;
   procedure Test_Complex_Sequence_Type;
   procedure Test_Complex_Choice_Type;
   procedure Test_Element_Definition;
   procedure Test_Full_Schema;
   procedure Test_Missing_Name_Error;
   procedure Test_Unknown_Base_Type_Error;
   procedure Test_File_Based_Validation;

   procedure Test_Integer_Simple_Type is
      Schema_SML : constant String :=
        "<schema>" &
        "  <simpleType>" &
        "    <name>portType</name>" &
        "    <restriction>" &
        "      <base>integer</base>" &
        "      <minValue>1</minValue>" &
        "      <maxValue>65535</maxValue>" &
        "    </restriction>" &
        "  </simpleType>" &
        "</schema>";
   begin
      Put ("Test: Integer Simple Type... ");

      declare
         Parse_Result : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (Schema_SML);
      begin
         if not Parse_Result.Success then
            Put_Line ("FAILED: Could not parse schema");
            return;
         end if;

         declare
            Load_Result : constant Schema_Load_Result :=
              Load_Schema (Parse_Result.Doc);
         begin
            if not Load_Result.Success then
               Put_Line ("FAILED: " &
                        To_String (Load_Result.Error_Message));
               return;
            end if;
         end;
      end;

      Put_Line ("✓ PASSED");
   end Test_Integer_Simple_Type;

   procedure Test_String_Enum_Type is
      Schema_SML : constant String :=
        "<schema>" &
        "  <simpleType>" &
        "    <name>logLevel</name>" &
        "    <restriction>" &
        "      <base>string</base>" &
        "      <enumeration>" &
        "        <value>DEBUG</value>" &
        "        <value>INFO</value>" &
        "        <value>WARNING</value>" &
        "        <value>ERROR</value>" &
        "      </enumeration>" &
        "    </restriction>" &
        "  </simpleType>" &
        "</schema>";
   begin
      Put ("Test: String Enumeration Type... ");

      declare
         Parse_Result : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (Schema_SML);
      begin
         if not Parse_Result.Success then
            Put_Line ("FAILED: Could not parse schema");
            return;
         end if;

         declare
            Load_Result : constant Schema_Load_Result :=
              Load_Schema (Parse_Result.Doc);
         begin
            if not Load_Result.Success then
               Put_Line ("FAILED: " &
                        To_String (Load_Result.Error_Message));
               return;
            end if;
         end;
      end;

      Put_Line ("✓ PASSED");
   end Test_String_Enum_Type;

   procedure Test_Complex_Sequence_Type is
      Schema_SML : constant String :=
        "<schema>" &
        "  <complexType>" &
        "    <name>databaseType</name>" &
        "    <sequence>" &
        "      <element>" &
        "        <name>host</name>" &
        "        <minOccurs>1</minOccurs>" &
        "        <maxOccurs>1</maxOccurs>" &
        "      </element>" &
        "      <element>" &
        "        <name>port</name>" &
        "        <minOccurs>1</minOccurs>" &
        "        <maxOccurs>1</maxOccurs>" &
        "      </element>" &
        "    </sequence>" &
        "  </complexType>" &
        "</schema>";
   begin
      Put ("Test: Complex Sequence Type... ");

      declare
         Parse_Result : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (Schema_SML);
      begin
         if not Parse_Result.Success then
            Put_Line ("FAILED: Could not parse schema");
            return;
         end if;

         declare
            Load_Result : constant Schema_Load_Result :=
              Load_Schema (Parse_Result.Doc);
         begin
            if not Load_Result.Success then
               Put_Line ("FAILED: " &
                        To_String (Load_Result.Error_Message));
               return;
            end if;
         end;
      end;

      Put_Line ("✓ PASSED");
   end Test_Complex_Sequence_Type;

   procedure Test_Complex_Choice_Type is
      Schema_SML : constant String :=
        "<schema>" &
        "  <complexType>" &
        "    <name>contactType</name>" &
        "    <choice>" &
        "      <element>" &
        "        <name>email</name>" &
        "        <minOccurs>1</minOccurs>" &
        "        <maxOccurs>1</maxOccurs>" &
        "      </element>" &
        "      <element>" &
        "        <name>phone</name>" &
        "        <minOccurs>1</minOccurs>" &
        "        <maxOccurs>1</maxOccurs>" &
        "      </element>" &
        "    </choice>" &
        "  </complexType>" &
        "</schema>";
   begin
      Put ("Test: Complex Choice Type... ");

      declare
         Parse_Result : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (Schema_SML);
      begin
         if not Parse_Result.Success then
            Put_Line ("FAILED: Could not parse schema");
            return;
         end if;

         declare
            Load_Result : constant Schema_Load_Result :=
              Load_Schema (Parse_Result.Doc);
         begin
            if not Load_Result.Success then
               Put_Line ("FAILED: " &
                        To_String (Load_Result.Error_Message));
               return;
            end if;
         end;
      end;

      Put_Line ("✓ PASSED");
   end Test_Complex_Choice_Type;

   procedure Test_Element_Definition is
      Schema_SML : constant String :=
        "<schema>" &
        "  <element>" &
        "    <name>config</name>" &
        "    <type>configType</type>" &
        "    <minOccurs>1</minOccurs>" &
        "    <maxOccurs>1</maxOccurs>" &
        "  </element>" &
        "</schema>";
   begin
      Put ("Test: Element Definition... ");

      declare
         Parse_Result : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (Schema_SML);
      begin
         if not Parse_Result.Success then
            Put_Line ("FAILED: Could not parse schema");
            return;
         end if;

         declare
            Load_Result : constant Schema_Load_Result :=
              Load_Schema (Parse_Result.Doc);
         begin
            if not Load_Result.Success then
               Put_Line ("FAILED: " &
                        To_String (Load_Result.Error_Message));
               return;
            end if;
         end;
      end;

      Put_Line ("✓ PASSED");
   end Test_Element_Definition;

   procedure Test_Full_Schema is
      Schema_SML : constant String :=
        "<schema>" &
        "  <simpleType>" &
        "    <name>portType</name>" &
        "    <restriction>" &
        "      <base>integer</base>" &
        "      <minValue>1</minValue>" &
        "      <maxValue>65535</maxValue>" &
        "    </restriction>" &
        "  </simpleType>" &
        "  <complexType>" &
        "    <name>databaseType</name>" &
        "    <sequence>" &
        "      <element>" &
        "        <name>host</name>" &
        "      </element>" &
        "      <element>" &
        "        <name>port</name>" &
        "      </element>" &
        "    </sequence>" &
        "  </complexType>" &
        "  <element>" &
        "    <name>config</name>" &
        "    <type>configType</type>" &
        "  </element>" &
        "</schema>";
   begin
      Put ("Test: Full Schema (all elements)... ");

      declare
         Parse_Result : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (Schema_SML);
      begin
         if not Parse_Result.Success then
            Put_Line ("FAILED: Could not parse schema");
            return;
         end if;

         declare
            Load_Result : constant Schema_Load_Result :=
              Load_Schema (Parse_Result.Doc);
         begin
            if not Load_Result.Success then
               Put_Line ("FAILED: " &
                        To_String (Load_Result.Error_Message));
               return;
            end if;
         end;
      end;

      Put_Line ("✓ PASSED");
   end Test_Full_Schema;

   procedure Test_Missing_Name_Error is
      Schema_SML : constant String :=
        "<schema>" &
        "  <simpleType>" &
        "    <restriction>" &
        "      <base>integer</base>" &
        "    </restriction>" &
        "  </simpleType>" &
        "</schema>";
   begin
      Put ("Test: Missing Name Error... ");

      declare
         Parse_Result : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (Schema_SML);
      begin
         if not Parse_Result.Success then
            Put_Line ("FAILED: Could not parse schema");
            return;
         end if;

         declare
            Load_Result : constant Schema_Load_Result :=
              Load_Schema (Parse_Result.Doc);
         begin
            if Load_Result.Success then
               Put_Line ("FAILED: Should have rejected schema without name");
               return;
            end if;
         end;
      end;

      Put_Line ("✓ PASSED (correctly rejected)");
   end Test_Missing_Name_Error;

   procedure Test_Unknown_Base_Type_Error is
      Schema_SML : constant String :=
        "<schema>" &
        "  <simpleType>" &
        "    <name>testType</name>" &
        "    <restriction>" &
        "      <base>float</base>" &
        "    </restriction>" &
        "  </simpleType>" &
        "</schema>";
   begin
      Put ("Test: Unknown Base Type Error... ");

      declare
         Parse_Result : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (Schema_SML);
      begin
         if not Parse_Result.Success then
            Put_Line ("FAILED: Could not parse schema");
            return;
         end if;

         declare
            Load_Result : constant Schema_Load_Result :=
              Load_Schema (Parse_Result.Doc);
         begin
            if Load_Result.Success then
               Put_Line ("FAILED: Should have rejected unknown base type");
               return;
            end if;
         end;
      end;

      Put_Line ("✓ PASSED (correctly rejected)");
   end Test_Unknown_Base_Type_Error;

   procedure Test_File_Based_Validation is
   begin
      Put ("Test: File-Based Schema Validation... ");

      --  Step 1: Load schema from file
      declare
         Schema_Parse : constant SML.DOM.Parser.Parse_Result :=
           SML.IO.Parse_File ("test/fixtures/config.schema.sml");
      begin
         if not Schema_Parse.Success then
            Put_Line ("FAILED: Could not parse schema file");
            return;
         end if;

         --  Step 2: Load schema into Schema_Document
         declare
            Schema_Load : constant Schema_Load_Result :=
              Load_Schema (Schema_Parse.Doc);
         begin
            if not Schema_Load.Success then
               Put_Line ("FAILED: Could not load schema: " &
                        To_String (Schema_Load.Error_Message));
               return;
            end if;

            --  Step 3: Validate valid instance from file
            declare
               Valid_Parse : constant SML.DOM.Parser.Parse_Result :=
                 SML.IO.Parse_File ("test/fixtures/config_valid.sml");
            begin
               if not Valid_Parse.Success then
                  Put_Line ("FAILED: Could not parse valid instance");
                  return;
               end if;

               declare
                  Valid_Result : constant Validation_Result :=
                    Validate_Document (Schema_Load.Schema, Valid_Parse.Doc);
               begin
                  if Valid_Result.Status /= Valid then
                     Put_Line ("FAILED: Valid instance rejected - " &
                              To_String (Valid_Result.Error_Message));
                     return;
                  end if;
               end;
            end;

            --  Step 4: Validate invalid instance from file
            declare
               Invalid_Parse : constant SML.DOM.Parser.Parse_Result :=
                 SML.IO.Parse_File ("test/fixtures/config_invalid.sml");
            begin
               if not Invalid_Parse.Success then
                  Put_Line ("FAILED: Could not parse invalid instance");
                  return;
               end if;

               declare
                  Invalid_Result : constant Validation_Result :=
                    Validate_Document (Schema_Load.Schema, Invalid_Parse.Doc);
               begin
                  if Invalid_Result.Status /= Invalid then
                     Put_Line ("FAILED: Invalid instance incorrectly accepted");
                     return;
                  end if;
                  --  Successfully rejected invalid instance!
               end;
            end;
         end;
      end;

      Put_Line ("✓ PASSED (file-based validation works)");
   end Test_File_Based_Validation;

   procedure Test_Schema_Include is
   begin
      Put ("Test: Schema Include... ");

      --  Load top-level schema that includes another schema file
      declare
         Schema_Parse : constant SML.DOM.Parser.Parse_Result :=
           SML.IO.Parse_File ("test/fixtures/schema_include_main.sml");
      begin
         if not Schema_Parse.Success then
            Put_Line ("FAILED: Could not parse include main schema");
            return;
         end if;

         declare
            Schema_Load : constant Schema_Load_Result :=
              Load_Schema (Schema_Parse.Doc);
         begin
            if not Schema_Load.Success then
               Put_Line ("FAILED: Could not load included schema: " &
                        To_String (Schema_Load.Error_Message));
               return;
            end if;

            --  Validate valid instance using included definitions
            declare
               Valid_Parse : constant SML.DOM.Parser.Parse_Result :=
                 SML.IO.Parse_File ("test/fixtures/config_valid_pair.sml");
            begin
               if not Valid_Parse.Success then
                  Put_Line ("FAILED: Could not parse valid pair instance");
                  return;
               end if;
               declare
                  R : constant Validation_Result :=
                    Validate_Document (Schema_Load.Schema, Valid_Parse.Doc);
               begin
                  if R.Status /= Valid then
                     Put_Line ("FAILED: Valid pair instance rejected");
                     return;
                  end if;
               end;
            end;

            --  Validate invalid duplicate
            declare
               Invalid_Parse : constant SML.DOM.Parser.Parse_Result :=
                 SML.DOM.Parser.Parse ("<root><a/><a/></root>");
            begin
               if not Invalid_Parse.Success then
                  Put_Line ("FAILED: Could not parse invalid duplicate pair");
                  return;
               end if;
               declare
                  R2 : constant Validation_Result :=
                    Validate_Document (Schema_Load.Schema, Invalid_Parse.Doc);
               begin
                  if R2.Status /= Invalid then
                     Put_Line ("FAILED: Duplicate pair incorrectly accepted");
                     return;
                  end if;
               end;
            end;
         end;
      end;

      Put_Line ("✓ PASSED (include works)");
   end Test_Schema_Include;

begin
   Put_Line ("=== SML Schema Loader Tests ===");
   Put_Line ("");

   Test_Integer_Simple_Type;
   Test_String_Enum_Type;
   Test_Complex_Sequence_Type;
   Test_Complex_Choice_Type;
   Test_Element_Definition;
   Test_Full_Schema;
   Test_Missing_Name_Error;
   Test_Unknown_Base_Type_Error;
   Test_File_Based_Validation;
   Test_Schema_Include;

   Put_Line ("");
   Put_Line ("=== All Tests Completed ===");
end Test_Schema_Loader;
