------------------------------------------------------------------------------
--  Schema Validation Example
--  Demonstrates end-to-end schema loading and document validation
------------------------------------------------------------------------------

with Ada.Text_IO;
with SML.DOM.Parser;
with SML.Schema;
with SML.Schema.Loader;

procedure Schema_Validation_Example is
   use Ada.Text_IO;
   use type SML.Schema.Validation_Status;

   --  Schema defining port numbers (1-65535) and log levels (enum)
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
     "  <complexType>" &
     "    <name>configType</name>" &
     "    <sequence>" &
     "      <element>" &
     "        <name>port</name>" &
     "        <minOccurs>1</minOccurs>" &
     "        <maxOccurs>1</maxOccurs>" &
     "      </element>" &
     "      <element>" &
     "        <name>debug</name>" &
     "        <minOccurs>0</minOccurs>" &
     "        <maxOccurs>1</maxOccurs>" &
     "      </element>" &
     "    </sequence>" &
     "  </complexType>" &
     "  <element>" &
     "    <name>config</name>" &
     "    <type>configType</type>" &
     "  </element>" &
     "</schema>";

   --  Valid instance document
   Valid_SML : constant String :=
     "<config>" &
     "  <port>8080</port>" &
     "  <debug>true</debug>" &
     "</config>";

   --  Invalid instance (wrong root element - not in schema)
   Invalid_Element_SML : constant String :=
     "<unknown>" &
     "  <port>8080</port>" &
     "</unknown>";

   --  Invalid instance (invalid root)
   Invalid_Root_SML : constant String :=
     "<settings>" &
     "  <port>8080</port>" &
     "</settings>";

begin
   Put_Line ("===========================================");
   Put_Line ("  SML Schema Validation Example");
   Put_Line ("===========================================");
   New_Line;

   --  Step 1: Load schema
   Put_Line ("Step 1: Loading schema...");
   declare
      Schema_Parse : constant SML.DOM.Parser.Parse_Result :=
        SML.DOM.Parser.Parse (Schema_SML);
   begin
      if not Schema_Parse.Success then
         Put_Line ("ERROR: Failed to parse schema document");
         Put_Line ("  " & Schema_Parse.Error.Message
                   (1 .. Schema_Parse.Error.Msg_Length));
         return;
      end if;

      Put_Line ("  Parsed schema document successfully");

      declare
         Schema_Load : constant SML.Schema.Loader.Schema_Load_Result :=
           SML.Schema.Loader.Load_Schema (Schema_Parse.Doc);
      begin
         if not Schema_Load.Success then
            Put_Line ("ERROR: Failed to load schema");
            Put_Line ("  " &
                     SML.Schema.To_String (Schema_Load.Error_Message));
            return;
         end if;

         Put_Line ("  Loaded schema with:");
         Put_Line ("    - 2 simple types (portType, logLevel)");
         Put_Line ("    - 1 complex type (configType with sequence)");
         Put_Line ("    - 1 element definition (config)");
         New_Line;

         --  Step 2: Validate valid document
         Put_Line ("Step 2: Validating correct document...");
         declare
            Doc_Parse : constant SML.DOM.Parser.Parse_Result :=
              SML.DOM.Parser.Parse (Valid_SML);
         begin
            if not Doc_Parse.Success then
               Put_Line ("ERROR: Failed to parse instance document");
               return;
            end if;

            declare
               Validation : constant SML.Schema.Validation_Result :=
                 SML.Schema.Validate_Document (Schema_Load.Schema,
                                               Doc_Parse.Doc);
            begin
               if Validation.Status = SML.Schema.Valid then
                  Put_Line ("  ✓ Document is VALID");
               else
                  Put_Line ("  ✗ Document is INVALID");
                  Put_Line ("    Error: " &
                           SML.Schema.To_String (Validation.Error_Message));
               end if;
            end;
         end;
         New_Line;

         --  Step 3: Validate document with invalid root element
         Put_Line ("Step 3: Validating document with unknown root element...");
         declare
            Doc_Parse : constant SML.DOM.Parser.Parse_Result :=
              SML.DOM.Parser.Parse (Invalid_Element_SML);
         begin
            if not Doc_Parse.Success then
               Put_Line ("ERROR: Failed to parse instance document");
               return;
            end if;

            declare
               Validation : constant SML.Schema.Validation_Result :=
                 SML.Schema.Validate_Document (Schema_Load.Schema,
                                               Doc_Parse.Doc);
            begin
               if Validation.Status = SML.Schema.Invalid then
                  Put_Line ("  ✓ Correctly REJECTED unknown root element");
                  Put_Line ("    Reason: " &
                           SML.Schema.To_String (Validation.Error_Message));
               else
                  Put_Line ("  ✗ ERROR: Should have rejected this document");
               end if;
            end;
         end;
         New_Line;

         --  Step 4: Validate document with invalid root
         Put_Line ("Step 4: Validating document with invalid root...");
         declare
            Doc_Parse : constant SML.DOM.Parser.Parse_Result :=
              SML.DOM.Parser.Parse (Invalid_Root_SML);
         begin
            if not Doc_Parse.Success then
               Put_Line ("ERROR: Failed to parse instance document");
               return;
            end if;

            declare
               Validation : constant SML.Schema.Validation_Result :=
                 SML.Schema.Validate_Document (Schema_Load.Schema,
                                               Doc_Parse.Doc);
            begin
               if Validation.Status = SML.Schema.Invalid then
                  Put_Line ("  ✓ Correctly REJECTED invalid root element");
                  Put_Line ("    Reason: " &
                           SML.Schema.To_String (Validation.Error_Message));
               else
                  Put_Line ("  ✗ ERROR: Should have rejected this document");
               end if;
            end;
         end;
      end;
   end;

   New_Line;
   Put_Line ("===========================================");
   Put_Line ("  Example completed successfully!");
   Put_Line ("===========================================");
end Schema_Validation_Example;
