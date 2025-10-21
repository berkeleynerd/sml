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
   procedure Test_Typed_Children_Validation;
   procedure Test_Simple_Content_Model;
   procedure Test_All_Model_Validation;
   procedure Test_Sequence_Group_Repeats;
   procedure Test_Choice_Group_Repeats;
   procedure Test_Root_Element_Policy;
   procedure Test_Automatic_Content_Validation;

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
             Int_Min_Exclusive => False,
             Int_Max_Exclusive => False,
             Dec_Min     => Float'First,
             Dec_Max     => Float'Last,
             Dec_Min_Exclusive => False,
             Dec_Max_Exclusive => False,
             Total_Digits    => Natural'Last,
             Fraction_Digits => Natural'Last,
             Min_Length  => 0,
             Max_Length  => Max_String_Length,
             Length      => Natural'Last,
             Trim        => False,
             Prefix      => Empty_String,
             Suffix      => Empty_String,
             Contains    => Empty_String,
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
             Int_Min_Exclusive => False,
             Int_Max_Exclusive => False,
             Dec_Min     => Float'First,
             Dec_Max     => Float'Last,
             Dec_Min_Exclusive => False,
             Dec_Max_Exclusive => False,
             Total_Digits    => Natural'Last,
             Fraction_Digits => Natural'Last,
             Min_Length  => 0,
             Max_Length  => Max_String_Length,
             Length      => Natural'Last,
             Trim        => False,
             Prefix      => Empty_String,
             Suffix      => Empty_String,
             Contains    => Empty_String,
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
             Type_Name    => Empty_String,
             Min_Occurs   => 1,
             Max_Occurs   => 1);

         --  Server element (optional, multiple)
         Config_Type.Children (2) :=
            (Element_Name => To_Bounded_String ("server"),
             Type_Name    => Empty_String,
             Min_Occurs   => 0,
             Max_Occurs   => Natural'Last);  --  unbounded

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

      --  Test out-of-order invalid: server before database
      declare
         Out_Of_Order : constant SML.DOM.Parser.Parse_Result :=
            SML.DOM.Parser.Parse (
               "<config>" &
               "  <server>srv1</server>" &
               "  <database>db1</database>" &
               "</config>");
      begin
         if not Out_Of_Order.Success then
            Put_Line ("FAILED: Could not parse out-of-order document");
            return;
         end if;
         declare
            Result : constant Validation_Result :=
               Validate_Document (Schema, Out_Of_Order.Doc);
         begin
            if Result.Status = Invalid then
               Put ("✓ Out-of-order rejected, ");
            else
               Put_Line ("FAILED: Out-of-order accepted");
               return;
            end if;
         end;
      end;

      --  Test extra element invalid
      declare
         Extra_Elem : constant SML.DOM.Parser.Parse_Result :=
            SML.DOM.Parser.Parse (
               "<config>" &
               "  <database>db1</database>" &
               "  <server>srv1</server>" &
               "  <extra>z</extra>" &
               "</config>");
      begin
         if not Extra_Elem.Success then
            Put_Line ("FAILED: Could not parse extra element document");
            return;
         end if;
         declare
            Result : constant Validation_Result :=
               Validate_Document (Schema, Extra_Elem.Doc);
         begin
            if Result.Status = Invalid then
               Put_Line ("✓ Extra element rejected");
            else
               Put_Line ("FAILED: Extra element accepted");
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

      --  Decimal validation with range
      declare
         Dec_Type : Simple_Type_Definition;
      begin
         Dec_Type.Name := To_Bounded_String ("ratioType");
         Dec_Type.Base_Type := Decimal_Type;
         Dec_Type.Dec_Min := 0.0;
         Dec_Type.Dec_Max := 1.0;
         Dec_Type.Total_Digits := Natural'Last;
         Dec_Type.Fraction_Digits := Natural'Last;
         Add_Simple_Type (Schema, Dec_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add ratioType");
            return;
         end if;

         declare
            Ok   : constant Validation_Result :=
              Validate_Content (Schema, Dec_Type.Name, "0.75");
            Low  : constant Validation_Result :=
              Validate_Content (Schema, Dec_Type.Name, "-0.1");
            High : constant Validation_Result :=
              Validate_Content (Schema, Dec_Type.Name, "1.1");
            All_Good : constant Boolean :=
              Ok.Status = Valid
              and then Low.Status = Invalid
              and then High.Status = Invalid;
         begin
            if All_Good then
               Put ("✓ Decimal range enforced, ");
            else
               Put_Line ("FAILED: Decimal range validation error");
               return;
            end if;
         end;
      end;

      --  Decimal digits facets (max): totalDigits=3, fractionDigits=2
      declare
         Dig_Type : Simple_Type_Definition;
      begin
         Dig_Type.Name := To_Bounded_String ("digType");
         Dig_Type.Base_Type := Decimal_Type;
         Dig_Type.Total_Digits := 3;
         Dig_Type.Fraction_Digits := 2;
         Add_Simple_Type (Schema, Dig_Type, Success);
         declare
            OkD1 : constant Validation_Result :=
              Validate_Content (Schema, Dig_Type.Name, "9.99");
            BadT : constant Validation_Result :=
              Validate_Content (Schema, Dig_Type.Name, "99.99");
            BadF : constant Validation_Result :=
              Validate_Content (Schema, Dig_Type.Name, "9.999");
         begin
            if OkD1.Status = Valid
              and then BadT.Status = Invalid
              and then BadF.Status = Invalid
            then
               Put ("✓ Decimal digits enforced, ");
            else
               Put_Line ("FAILED: Decimal digits validation error");
               return;
            end if;
         end;
      end;

      --  String prefix/suffix validation
      declare
         Path_Type : Simple_Type_Definition;
      begin
         Path_Type.Name := To_Bounded_String ("logPathType");
         Path_Type.Base_Type := String_Type;
         Path_Type.Prefix := To_Bounded_String ("file://");
         Path_Type.Suffix := To_Bounded_String (".log");
         Add_Simple_Type (Schema, Path_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add logPathType");
            return;
         end if;

         declare
            Ok   : constant Validation_Result :=
              Validate_Content
                (Schema, Path_Type.Name, "file:///var/log/app.log");
            Bad1 : constant Validation_Result :=
              Validate_Content
                (Schema, Path_Type.Name, "/var/log/app.log");
            Bad2 : constant Validation_Result :=
              Validate_Content
                (Schema, Path_Type.Name, "file:///var/log/app.txt");
            All_Good : constant Boolean :=
              Ok.Status = Valid
              and then Bad1.Status = Invalid
              and then Bad2.Status = Invalid;
         begin
            if All_Good then
               Put_Line ("✓ String prefix/suffix enforced");
            else
               Put_Line ("FAILED: String prefix/suffix validation error");
               return;
            end if;
         end;
      end;

      --  String contains validation
      declare
         C_Type : Simple_Type_Definition;
      begin
         C_Type.Name := To_Bounded_String ("containsType");
         C_Type.Base_Type := String_Type;
         C_Type.Contains := To_Bounded_String ("log");
         Add_Simple_Type (Schema, C_Type, Success);
         declare
            Ok  : constant Validation_Result :=
              Validate_Content
                (Schema, C_Type.Name, "file:///var/log/app.txt");
            Bad : constant Validation_Result :=
              Validate_Content
                (Schema, C_Type.Name, "file:///var/tmp/app.txt");
         begin
            if Ok.Status = Valid and then Bad.Status = Invalid then
               Put ("✓ String contains enforced, ");
            else
               Put_Line ("FAILED: String contains validation error");
               return;
            end if;
         end;
      end;

      --  String exact length and trim
      declare
         L_Type : Simple_Type_Definition;
      begin
         L_Type.Name := To_Bounded_String ("lenType");
         L_Type.Base_Type := String_Type;
         L_Type.Length := 3;
         L_Type.Trim := True;
         Add_Simple_Type (Schema, L_Type, Success);
         declare
            Ok  : constant Validation_Result :=
              Validate_Content (Schema, L_Type.Name, "  abc  ");
            Bad : constant Validation_Result :=
              Validate_Content (Schema, L_Type.Name, "abcd");
         begin
            if Ok.Status = Valid and then Bad.Status = Invalid then
               Put ("✓ String exact length + trim, ");
            else
               Put_Line ("FAILED: String length/trim validation error");
               return;
            end if;
         end;
      end;

      --  Integer exclusive bounds
      declare
         IE : Simple_Type_Definition;
      begin
         IE.Name := To_Bounded_String ("intExc");
         IE.Base_Type := Integer_Type;
         IE.Min_Value := 10;
         IE.Int_Min_Exclusive := True;
         Add_Simple_Type (Schema, IE, Success);
         declare
            Ok  : constant Validation_Result :=
              Validate_Content (Schema, IE.Name, "11");
            Bad : constant Validation_Result :=
              Validate_Content (Schema, IE.Name, "10");
         begin
            if Ok.Status = Valid and then Bad.Status = Invalid then
               Put ("✓ Integer exclusive bounds, ");
            else
               Put_Line ("FAILED: Integer exclusive bounds error");
               return;
            end if;
         end;
      end;

      --  Decimal exclusive bounds
      declare
         DE : Simple_Type_Definition;
      begin
         DE.Name := To_Bounded_String ("decExc");
         DE.Base_Type := Decimal_Type;
         DE.Dec_Min := 0.5;
         DE.Dec_Min_Exclusive := True;
         Add_Simple_Type (Schema, DE, Success);
         declare
            Ok  : constant Validation_Result :=
              Validate_Content (Schema, DE.Name, "0.6");
            Bad : constant Validation_Result :=
              Validate_Content (Schema, DE.Name, "0.5");
         begin
            if Ok.Status = Valid and then Bad.Status = Invalid then
               Put_Line ("✓ Decimal exclusive bounds enforced");
            else
               Put_Line ("FAILED: Decimal exclusive bounds error");
               return;
            end if;
         end;
      end;

      --  Integer enumeration validation
      declare
         I_Type : Simple_Type_Definition;
      begin
         I_Type.Name := To_Bounded_String ("intEnum");
         I_Type.Base_Type := Integer_Type;
         I_Type.Enum_Count := 2;
         I_Type.Enum_Values (1) := To_Bounded_String ("21");
         I_Type.Enum_Values (2) := To_Bounded_String ("65");
         Add_Simple_Type (Schema, I_Type, Success);
         declare
            OkI  : constant Validation_Result :=
              Validate_Content (Schema, I_Type.Name, "21");
            BadI : constant Validation_Result :=
              Validate_Content (Schema, I_Type.Name, "22");
         begin
            if OkI.Status = Valid and then BadI.Status = Invalid then
               Put ("✓ Integer enum enforced, ");
            else
               Put_Line ("FAILED: Integer enum validation error");
               return;
            end if;
         end;
      end;

      --  Decimal enumeration validation
      declare
         D_Type : Simple_Type_Definition;
      begin
         D_Type.Name := To_Bounded_String ("decEnum");
         D_Type.Base_Type := Decimal_Type;
         D_Type.Enum_Count := 2;
         D_Type.Enum_Values (1) := To_Bounded_String ("0.50");
         D_Type.Enum_Values (2) := To_Bounded_String ("0.75");
         Add_Simple_Type (Schema, D_Type, Success);
         declare
            OkD  : constant Validation_Result :=
              Validate_Content (Schema, D_Type.Name, "0.50");
            BadD : constant Validation_Result :=
              Validate_Content (Schema, D_Type.Name, "0.60");
         begin
            if OkD.Status = Valid and then BadD.Status = Invalid then
               Put_Line ("✓ Decimal enum enforced");
            else
               Put_Line ("FAILED: Decimal enum validation error");
               return;
            end if;
         end;
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

   procedure Test_Automatic_Content_Validation is
      Schema  : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Automatic Content Validation (element → simpleType)... ");

      Initialize (Schema);

      --  Define simple integer type: portType (1..65535)
      declare
         Port_Type : Simple_Type_Definition;
      begin
         Port_Type.Name       := To_Bounded_String ("portType");
         Port_Type.Base_Type  := Integer_Type;
         Port_Type.Min_Value  := 1;
         Port_Type.Max_Value  := 65535;
         Port_Type.Min_Length := 0;
         Port_Type.Max_Length := Max_String_Length;
         Add_Simple_Type (Schema, Port_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add portType");
            return;
         end if;
      end;

      --  Map element 'port' to simple type 'portType'
      declare
         Port_Element : constant Element_Definition :=
           (Name => To_Bounded_String ("port"),
            Type_Name => To_Bounded_String ("portType"),
            Min_Occurs => 1,
            Max_Occurs => 1);
      begin
         Add_Element (Schema, Port_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add port element");
            return;
         end if;
      end;

      --  Valid value
      declare
         Doc_Valid : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<port>5432</port>");
      begin
         if not Doc_Valid.Success then
            Put_Line ("FAILED: Could not parse valid port document");
            return;
         end if;
         declare
            Result : constant Validation_Result :=
              Validate_Document (Schema, Doc_Valid.Doc);
         begin
            if Result.Status = Valid then
               Put ("✓ valid accepted, ");
            else
               Put_Line ("FAILED: valid port rejected: "
                        & To_String (Result.Error_Message));
               return;
            end if;
         end;
      end;

      --  Out of range
      declare
         Doc_Out : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<port>99999</port>");
      begin
         if not Doc_Out.Success then
            Put_Line ("FAILED: Could not parse out-of-range port document");
            return;
         end if;
         declare
            Result : constant Validation_Result :=
              Validate_Document (Schema, Doc_Out.Doc);
         begin
            if Result.Status = Invalid then
               Put ("✓ out-of-range rejected, ");
            else
               Put_Line ("FAILED: out-of-range port accepted");
               return;
            end if;
         end;
      end;

      --  Not a number
      declare
         Doc_NaN : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<port>not_a_number</port>");
      begin
         if not Doc_NaN.Success then
            Put_Line ("FAILED: Could not parse non-numeric port document");
            return;
         end if;
         declare
            Result : constant Validation_Result :=
              Validate_Document (Schema, Doc_NaN.Doc);
         begin
            if Result.Status = Invalid then
               Put ("✓ non-numeric rejected, ");
            else
               Put_Line ("FAILED: non-numeric port accepted");
               return;
            end if;
         end;
      end;

      --  Child element under simple type should be rejected
      declare
         Doc_Child : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<port><x/></port>");
      begin
         if not Doc_Child.Success then
            Put_Line ("FAILED: Could not parse child-element port document");
            return;
         end if;
         declare
            Result : constant Validation_Result :=
              Validate_Document (Schema, Doc_Child.Doc);
         begin
            if Result.Status = Invalid then
               Put_Line ("✓ child elements rejected");
            else
               Put_Line ("FAILED: child elements accepted for simple type");
               return;
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_Automatic_Content_Validation;

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
             Type_Name    => Empty_String,
             Min_Occurs   => 1,
             Max_Occurs   => 1);

         Contact_Type.Children (2) :=
            (Element_Name => To_Bounded_String ("phone"),
             Type_Name    => Empty_String,
             Min_Occurs   => 1,
             Max_Occurs   => 1);

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

   procedure Test_Typed_Children_Validation is
      Schema  : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Typed Children Validation... ");

      Initialize (Schema);

      --  Simple type for host (string)
      declare
         Host_Type : Simple_Type_Definition;
      begin
         Host_Type.Name := To_Bounded_String ("hostType");
         Host_Type.Base_Type := String_Type;
         Add_Simple_Type (Schema, Host_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add hostType");
            return;
         end if;
      end;

      --  Simple type for port (1..65535)
      declare
         Port_Type : Simple_Type_Definition;
      begin
         Port_Type.Name := To_Bounded_String ("portType");
         Port_Type.Base_Type := Integer_Type;
         Port_Type.Min_Value := 1;
         Port_Type.Max_Value := 65535;
         Add_Simple_Type (Schema, Port_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add portType");
            return;
         end if;
      end;

      --  Complex type databaseType(host, port)
      declare
         DB_Type : Complex_Type_Definition;
      begin
         DB_Type.Name := To_Bounded_String ("databaseType");
         DB_Type.Content_Model := Sequence_Model;
         DB_Type.Child_Count := 2;

         DB_Type.Children (1) :=
           (Element_Name => To_Bounded_String ("host"),
            Type_Name    => To_Bounded_String ("hostType"),
            Min_Occurs   => 1,
            Max_Occurs   => 1);

         DB_Type.Children (2) :=
           (Element_Name => To_Bounded_String ("port"),
            Type_Name    => To_Bounded_String ("portType"),
            Min_Occurs   => 1,
            Max_Occurs   => 1);

         Add_Complex_Type (Schema, DB_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add databaseType");
            return;
         end if;
      end;

      --  Root element database of type databaseType
      declare
         Database_Element : constant Element_Definition :=
           (Name       => To_Bounded_String ("database"),
            Type_Name  => To_Bounded_String ("databaseType"),
            Min_Occurs => 1,
            Max_Occurs => 1);
      begin
         Add_Element (Schema, Database_Element, Success);
         if not Success then
            Put_Line ("FAILED: Could not add database element");
            return;
         end if;
      end;

      --  Valid instance
      declare
         Doc_Valid : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (
             "<database>"
             & "<host>localhost</host>"
             & "<port>5432</port>"
             & "</database>");
      begin
         if not Doc_Valid.Success then
            Put_Line ("FAILED: Could not parse valid database");
            return;
         end if;
         declare
            Result : constant Validation_Result :=
              Validate_Document (Schema, Doc_Valid.Doc);
         begin
            if Result.Status = Valid then
               Put ("✓ valid accepted, ");
            else
               Put_Line ("FAILED: valid rejected");
               return;
            end if;
         end;
      end;

      --  Invalid: port out of range
      declare
         Doc_Bad_Port : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (
             "<database>"
             & "<host>localhost</host>"
             & "<port>99999</port>"
             & "</database>");
      begin
         if not Doc_Bad_Port.Success then
            Put_Line ("FAILED: Could not parse bad port");
            return;
         end if;
         declare
            Result : constant Validation_Result :=
              Validate_Document (Schema, Doc_Bad_Port.Doc);
         begin
            if Result.Status = Invalid then
               Put ("✓ bad port rejected, ");
            else
               Put_Line ("FAILED: bad port accepted");
               return;
            end if;
         end;
      end;

      --  Invalid: host with child element (simple type must be text-only)
      declare
         Doc_Bad_Host : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse (
             "<database>"
             & "<host><x/></host>"
             & "<port>5432</port>"
             & "</database>");
      begin
         if not Doc_Bad_Host.Success then
            Put_Line ("FAILED: Could not parse bad host");
            return;
         end if;
         declare
            Result : constant Validation_Result :=
              Validate_Document (Schema, Doc_Bad_Host.Doc);
         begin
            if Result.Status = Invalid then
               Put_Line ("✓ simple child rejected");
            else
               Put_Line ("FAILED: simple child accepted");
               return;
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_Typed_Children_Validation;

--  Test bodies above; main driver below
   procedure Test_Simple_Content_Model is
      Schema  : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Simple Content Model... ");

      Initialize (Schema);

      --  Define a simple integer type (1..65535)
      declare
         Port_Type : Simple_Type_Definition;
      begin
         Port_Type.Name := To_Bounded_String ("portType");
         Port_Type.Base_Type := Integer_Type;
         Port_Type.Min_Value := 1;
         Port_Type.Max_Value := 65535;
         Add_Simple_Type (Schema, Port_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add portType");
            return;
         end if;
      end;

      --  Complex type with simple content bound to portType
      declare
         Wrapper : Complex_Type_Definition;
      begin
         Wrapper.Name := To_Bounded_String ("portWrapperType");
         Wrapper.Content_Model := Simple_Model;
         Wrapper.Simple_Content_Type_Name := To_Bounded_String ("portType");
         Add_Complex_Type (Schema, Wrapper, Success);
         if not Success then
            Put_Line ("FAILED: Could not add portWrapperType");
            return;
         end if;
      end;

      --  Element mapping to complex simple-content type
      declare
         Elem : constant Element_Definition :=
           (Name       => To_Bounded_String ("port"),
            Type_Name  => To_Bounded_String ("portWrapperType"),
            Min_Occurs => 1,
            Max_Occurs => 1);
      begin
         Add_Element (Schema, Elem, Success);
         if not Success then
            Put_Line ("FAILED: Could not add port element");
            return;
         end if;
      end;

      --  Valid value
      declare
         Doc_Valid : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<port>5432</port>");
      begin
         if not Doc_Valid.Success then
            Put_Line ("FAILED: Could not parse valid simple content");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Valid.Doc);
         begin
            if R.Status = Valid then
               Put ("✓ valid accepted, ");
            else
               Put_Line ("FAILED: valid simple content rejected");
               return;
            end if;
         end;
      end;

      --  Invalid value
      declare
         Doc_Bad : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<port>99999</port>");
      begin
         if not Doc_Bad.Success then
            Put_Line ("FAILED: Could not parse bad simple content");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Bad.Doc);
         begin
            if R.Status = Invalid then
               Put ("✓ out-of-range rejected, ");
            else
               Put_Line ("FAILED: out-of-range accepted");
               return;
            end if;
         end;
      end;

      --  Invalid: child element present
      declare
         Doc_Child : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<port><x/></port>");
      begin
         if not Doc_Child.Success then
            Put_Line ("FAILED: Could not parse child simple content");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Child.Doc);
         begin
            if R.Status = Invalid then
               Put_Line ("✓ child elements rejected");
            else
               Put_Line ("FAILED: child elements accepted in simple content");
               return;
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_Simple_Content_Model;

   procedure Test_All_Model_Validation is
      Schema  : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: All Model (unordered) Validation... ");

      Initialize (Schema);

      --  Define complex type with unordered children a, b
      declare
         All_Type : Complex_Type_Definition;
      begin
         All_Type.Name := To_Bounded_String ("pairType");
         All_Type.Content_Model := All_Model;
         All_Type.Child_Count := 2;
         All_Type.Children (1) :=
           (Element_Name => To_Bounded_String ("a"),
            Type_Name    => Empty_String,
            Min_Occurs   => 1,
            Max_Occurs   => 1);
         All_Type.Children (2) :=
           (Element_Name => To_Bounded_String ("b"),
            Type_Name    => Empty_String,
            Min_Occurs   => 0,
            Max_Occurs   => 1);
         Add_Complex_Type (Schema, All_Type, Success);
         if not Success then
            Put_Line ("FAILED: Could not add pairType");
            return;
         end if;
      end;

      --  Root element using pairType
      declare
         Root : constant Element_Definition :=
           (Name       => To_Bounded_String ("root"),
            Type_Name  => To_Bounded_String ("pairType"),
            Min_Occurs => 1,
            Max_Occurs => 1);
      begin
         Add_Element (Schema, Root, Success);
         if not Success then
            Put_Line ("FAILED: Could not add root element");
            return;
         end if;
      end;

      --  Valid: any order
      declare
         Doc_Valid : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<root><b/><a/></root>");
      begin
         if not Doc_Valid.Success then
            Put_Line ("FAILED: Could not parse all-model valid");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Valid.Doc);
         begin
            if R.Status = Valid then
               Put ("✓ valid accepted, ");
            else
               Put_Line ("FAILED: valid all-model rejected");
               return;
            end if;
         end;
      end;

      --  Invalid: duplicate a
      declare
         Doc_Dup : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<root><a/><a/></root>");
      begin
         if not Doc_Dup.Success then
            Put_Line ("FAILED: Could not parse duplicate all-model");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Dup.Doc);
         begin
            if R.Status = Invalid then
               Put ("✓ duplicate rejected, ");
            else
               Put_Line ("FAILED: duplicate accepted");
               return;
            end if;
         end;
      end;

      --  Invalid: missing required a
      declare
         Doc_Miss : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<root><b/></root>");
      begin
         if not Doc_Miss.Success then
            Put_Line ("FAILED: Could not parse missing all-model");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Miss.Doc);
         begin
            if R.Status = Invalid then
               Put_Line ("✓ missing required rejected");
            else
               Put_Line ("FAILED: missing required accepted");
               return;
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_All_Model_Validation;

   procedure Test_Sequence_Group_Repeats is
      Schema  : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Sequence Group Repeats... ");

      Initialize (Schema);

      --  Define sequence group a,b with group minOccurs=2
      declare
         Seq : Complex_Type_Definition;
      begin
         Seq.Name := To_Bounded_String ("pairSeq");
         Seq.Content_Model := Sequence_Model;
         Seq.Group_Min_Occurs := 2;
         Seq.Group_Max_Occurs := 2;
         Seq.Child_Count := 2;
         Seq.Children (1) :=
           (Element_Name => To_Bounded_String ("a"),
            Type_Name    => Empty_String,
            Min_Occurs   => 1,
            Max_Occurs   => 1);
         Seq.Children (2) :=
           (Element_Name => To_Bounded_String ("b"),
            Type_Name    => Empty_String,
            Min_Occurs   => 1,
            Max_Occurs   => 1);
         Add_Complex_Type (Schema, Seq, Success);
         if not Success then
            Put_Line ("FAILED: Could not add pairSeq");
            return;
         end if;
      end;

      --  Root element using pairSeq
      declare
         Root : constant Element_Definition :=
           (Name       => To_Bounded_String ("rootSeq"),
            Type_Name  => To_Bounded_String ("pairSeq"),
            Min_Occurs => 1,
            Max_Occurs => 1);
      begin
         Add_Element (Schema, Root, Success);
      end;

      --  Valid: two repetitions
      declare
         Doc_OK : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<rootSeq><a/><b/><a/><b/></rootSeq>");
      begin
         if not Doc_OK.Success then
            Put_Line ("FAILED: Could not parse sequence repetitions");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_OK.Doc);
         begin
            if R.Status = Valid then
               Put ("✓ valid accepted, ");
            else
               Put_Line ("FAILED: valid seq repeats rejected");
               return;
            end if;
         end;
      end;

      --  Invalid: too few repetitions
      declare
         Doc_Few : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<rootSeq><a/><b/></rootSeq>");
      begin
         if not Doc_Few.Success then
            Put_Line ("FAILED: Could not parse too few seq repeats");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Few.Doc);
         begin
            if R.Status = Invalid then
               Put ("✓ too few rejected, ");
            else
               Put_Line ("FAILED: too few seq repeats accepted");
               return;
            end if;
         end;
      end;

      --  Invalid: incomplete second repetition
      declare
         Doc_Incomplete : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<rootSeq><a/><b/><a/></rootSeq>");
      begin
         if not Doc_Incomplete.Success then
            Put_Line ("FAILED: Could not parse incomplete seq repeats");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Incomplete.Doc);
         begin
            if R.Status = Invalid then
               Put_Line ("✓ incomplete repetition rejected");
            else
               Put_Line ("FAILED: incomplete repetition accepted");
               return;
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_Sequence_Group_Repeats;

   procedure Test_Choice_Group_Repeats is
      Schema  : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Choice Group Repeats... ");

      Initialize (Schema);

      --  Define choice (a|b) with group minOccurs=2, maxOccurs=3
      declare
         Ch : Complex_Type_Definition;
      begin
         Ch.Name := To_Bounded_String ("choiceRep");
         Ch.Content_Model := Choice_Model;
         Ch.Group_Min_Occurs := 2;
         Ch.Group_Max_Occurs := 3;
         Ch.Child_Count := 2;
         Ch.Children (1) :=
           (Element_Name => To_Bounded_String ("a"),
            Type_Name    => Empty_String,
            Min_Occurs   => 1,
            Max_Occurs   => 1);
         Ch.Children (2) :=
           (Element_Name => To_Bounded_String ("b"),
            Type_Name    => Empty_String,
            Min_Occurs   => 1,
            Max_Occurs   => 1);
         Add_Complex_Type (Schema, Ch, Success);
      end;

      declare
         Root : constant Element_Definition :=
           (Name       => To_Bounded_String ("rootChoice"),
            Type_Name  => To_Bounded_String ("choiceRep"),
            Min_Occurs => 1,
            Max_Occurs => 1);
      begin
         Add_Element (Schema, Root, Success);
      end;

      --  Valid: 2 picks
      declare
         Doc_OK2 : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<rootChoice><a/><b/></rootChoice>");
      begin
         if not Doc_OK2.Success then
            Put_Line ("FAILED: Could not parse choice 2 picks");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_OK2.Doc);
         begin
            if R.Status = Valid then
               Put ("✓ 2 picks accepted, ");
            else
               Put_Line ("FAILED: 2 picks rejected");
               return;
            end if;
         end;
      end;

      --  Valid: 3 picks
      declare
         Doc_OK3 : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<rootChoice><a/><b/><a/></rootChoice>");
      begin
         if not Doc_OK3.Success then
            Put_Line ("FAILED: Could not parse choice 3 picks");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_OK3.Doc);
         begin
            if R.Status = Valid then
               Put ("✓ 3 picks accepted, ");
            else
               Put_Line ("FAILED: 3 picks rejected");
               return;
            end if;
         end;
      end;

      --  Invalid: 1 pick
      declare
         Doc_Too_Few : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<rootChoice><a/></rootChoice>");
      begin
         if not Doc_Too_Few.Success then
            Put_Line ("FAILED: Could not parse choice 1 pick");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Too_Few.Doc);
         begin
            if R.Status = Invalid then
               Put ("✓ too few picks rejected, ");
            else
               Put_Line ("FAILED: too few picks accepted");
               return;
            end if;
         end;
      end;

      --  Invalid: 4 picks
      declare
         Doc_Too_Many : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<rootChoice><a/><b/><a/><b/></rootChoice>");
      begin
         if not Doc_Too_Many.Success then
            Put_Line ("FAILED: Could not parse choice 4 picks");
            return;
         end if;
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Too_Many.Doc);
         begin
            if R.Status = Invalid then
               Put_Line ("✓ too many picks rejected");
            else
               Put_Line ("FAILED: too many picks accepted");
               return;
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_Choice_Group_Repeats;

   procedure Test_Root_Element_Policy is
      Schema  : Schema_Document;
      Success : Boolean;
   begin
      Put ("Test: Root Element Policy... ");

      Initialize (Schema);

      --  Set root element name explicitly
      Set_Root_Element (Schema, "config");

      --  Add element definition for root
      declare
         Root_Elem : constant Element_Definition :=
           (Name       => To_Bounded_String ("config"),
            Type_Name  => Empty_String,
            Min_Occurs => 1,
            Max_Occurs => 1);
      begin
         Add_Element (Schema, Root_Elem, Success);
      end;

      --  Valid root
      declare
         Doc_OK : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<config/>");
      begin
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_OK.Doc);
         begin
            if R.Status = Valid then
               Put ("✓ valid root accepted, ");
            else
               Put_Line ("FAILED: valid root rejected");
            end if;
         end;
      end;

      --  Invalid root
      declare
         Doc_Bad : constant SML.DOM.Parser.Parse_Result :=
           SML.DOM.Parser.Parse ("<settings/>");
      begin
         declare
            R : constant Validation_Result :=
              Validate_Document (Schema, Doc_Bad.Doc);
         begin
            if R.Status = Invalid then
               Put_Line ("✓ invalid root rejected");
            else
               Put_Line ("FAILED: invalid root accepted");
            end if;
         end;
      end;

      Put_Line ("PASSED");
   end Test_Root_Element_Policy;

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
   Test_Typed_Children_Validation;
   Test_Simple_Content_Model;
   Test_All_Model_Validation;
   Test_Sequence_Group_Repeats;
   Test_Choice_Group_Repeats;
   Test_Root_Element_Policy;
   Test_Automatic_Content_Validation;

   New_Line;
   Put_Line ("=== All Tests Completed ===");
end Test_Schema;
