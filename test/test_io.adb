------------------------------------------------------------------------------
--  Test Program for SML.IO
--  Validates file I/O operations
------------------------------------------------------------------------------

with Ada.Text_IO;
with SML.DOM;
with SML.DOM.Parser;
with SML.IO;

procedure Test_IO is
   use Ada.Text_IO;
   use SML.IO;

   --  Test file paths
   Valid_Small_Path  : constant String := "test/fixtures/valid-small.sml";
   Valid_Medium_Path : constant String := "test/fixtures/valid-medium.sml";
   Invalid_Path      : constant String := "test/fixtures/invalid.sml";
   Nonexistent_Path  : constant String := "test/fixtures/does_not_exist.sml";
   Output_Path       : constant String := "test/fixtures/output-test.sml";

   --  Forward declarations
   procedure Test_Read_Small_File;
   procedure Test_Read_Medium_File;
   procedure Test_Read_Nonexistent_File;
   procedure Test_Parse_Valid_File;
   procedure Test_Parse_Invalid_File;
   procedure Test_Parse_Nonexistent_File;
   procedure Test_Write_File;
   procedure Test_Write_Document;
   procedure Test_File_Exists;
   procedure Test_File_Size;
   procedure Test_Round_Trip;

   procedure Test_Read_Small_File is
      Result : constant Read_Result := Read_File (Valid_Small_Path);
   begin
      Put ("Test: Read Small File... ");

      if Result.Status /= Success then
         Put_Line ("FAILED: " & Status_Message (Result.Status));
         return;
      end if;

      if Result.Content_Length = 0 then
         Put_Line ("FAILED: Empty content");
         return;
      end if;

      Put_Line ("✓ PASSED (" & Result.Content_Length'Image & " bytes)");
   end Test_Read_Small_File;

   procedure Test_Read_Medium_File is
      Result : constant Read_Result := Read_File (Valid_Medium_Path);
   begin
      Put ("Test: Read Medium File... ");

      if Result.Status /= Success then
         Put_Line ("FAILED: " & Status_Message (Result.Status));
         return;
      end if;

      if Result.Content_Length = 0 then
         Put_Line ("FAILED: Empty content");
         return;
      end if;

      Put_Line ("✓ PASSED (" & Result.Content_Length'Image & " bytes)");
   end Test_Read_Medium_File;

   procedure Test_Read_Nonexistent_File is
      Result : constant Read_Result := Read_File (Nonexistent_Path);
   begin
      Put ("Test: Read Nonexistent File... ");

      if Result.Status = File_Not_Found then
         Put_Line ("✓ PASSED (correctly detected)");
      else
         Put_Line ("FAILED: Expected File_Not_Found");
      end if;
   end Test_Read_Nonexistent_File;

   procedure Test_Parse_Valid_File is
      Result : constant SML.DOM.Parser.Parse_Result :=
        Parse_File (Valid_Small_Path);
   begin
      Put ("Test: Parse Valid File... ");

      if not Result.Success then
         Put_Line ("FAILED: Parse failed");
         return;
      end if;

      --  If parse succeeded, document is well-formed (postcondition)
      Put_Line ("✓ PASSED (document loaded successfully)");
   end Test_Parse_Valid_File;

   procedure Test_Parse_Invalid_File is
      Result : constant SML.DOM.Parser.Parse_Result :=
        Parse_File (Invalid_Path);
   begin
      Put ("Test: Parse Invalid File... ");

      if Result.Success then
         Put_Line ("FAILED: Should have failed to parse");
         return;
      end if;

      Put_Line ("✓ PASSED (correctly detected parse error)");
   end Test_Parse_Invalid_File;

   procedure Test_Parse_Nonexistent_File is
      IO_Err : constant IO_Status := Parse_File_IO_Error (Nonexistent_Path);
   begin
      Put ("Test: Parse Nonexistent File... ");

      if IO_Err = File_Not_Found then
         Put_Line ("✓ PASSED (correctly detected)");
      else
         Put_Line ("FAILED: Expected File_Not_Found, got " &
                  Status_Message (IO_Err));
      end if;
   end Test_Parse_Nonexistent_File;

   procedure Test_Write_File is
      Test_Content : constant String := "<test><data>Sample</data></test>";
      Write_Res    : constant Write_Result :=
        Write_File (Output_Path, Test_Content);
      Read_Res     : constant Read_Result := Read_File (Output_Path);
   begin
      Put ("Test: Write File... ");

      if Write_Res.Status /= Success then
         Put_Line ("FAILED: Write error");
         return;
      end if;

      if Write_Res.Bytes_Written /= Test_Content'Length then
         Put_Line ("FAILED: Bytes written mismatch");
         return;
      end if;

      if Read_Res.Status /= Success then
         Put_Line ("FAILED: Could not read back");
         return;
      end if;

      declare
         Written : constant String :=
           Read_Res.Content (1 .. Read_Res.Content_Length);
      begin
         if Written /= Test_Content then
            Put_Line ("FAILED: Content mismatch");
            return;
         end if;
      end;

      Put_Line ("✓ PASSED (write and verify)");
   end Test_Write_File;

   procedure Test_Write_Document is
   begin
      Put ("Test: Write Document... ");

      declare
         Parse_Res : constant SML.DOM.Parser.Parse_Result :=
           Parse_File (Valid_Small_Path);
      begin
         if not Parse_Res.Success then
            Put_Line ("FAILED: Could not load source document");
            return;
         end if;

         declare
            Write_Res : constant Write_Result :=
              Write_Document (Output_Path, Parse_Res.Doc, Formatted => True);
         begin
            if Write_Res.Status /= Success then
               Put_Line ("FAILED: Write error");
               return;
            end if;

            if Write_Res.Bytes_Written = 0 then
               Put_Line ("FAILED: No bytes written");
               return;
            end if;
         end;
      end;

      Put_Line ("✓ PASSED");
   end Test_Write_Document;

   procedure Test_File_Exists is
   begin
      Put ("Test: File Exists Check... ");

      if not File_Exists (Valid_Small_Path) then
         Put_Line ("FAILED: Existing file not detected");
         return;
      end if;

      if File_Exists (Nonexistent_Path) then
         Put_Line ("FAILED: Nonexistent file detected as existing");
         return;
      end if;

      Put_Line ("✓ PASSED");
   end Test_File_Exists;

   procedure Test_File_Size is
      Size : constant Natural := File_Size (Valid_Small_Path);
   begin
      Put ("Test: File Size... ");

      if Size = 0 then
         Put_Line ("FAILED: Size is zero for existing file");
         return;
      end if;

      if File_Size (Nonexistent_Path) /= 0 then
         Put_Line ("FAILED: Nonexistent file has nonzero size");
         return;
      end if;

      Put_Line ("✓ PASSED (size =" & Size'Image & " bytes)");
   end Test_File_Size;

   procedure Test_Round_Trip is
   begin
      Put ("Test: Round Trip (Parse -> Write -> Parse)... ");

      --  Step 1: Parse original
      declare
         Parse1 : constant SML.DOM.Parser.Parse_Result :=
           Parse_File (Valid_Medium_Path);
      begin
         if not Parse1.Success then
            Put_Line ("FAILED: Initial parse failed");
            return;
         end if;

         --  Step 2: Write to new file
         declare
            Write_Res : constant Write_Result :=
              Write_Document (Output_Path, Parse1.Doc, Formatted => False);
         begin
            if Write_Res.Status /= Success then
               Put_Line ("FAILED: Write failed");
               return;
            end if;

            --  Step 3: Parse written file
            declare
               Parse2 : constant SML.DOM.Parser.Parse_Result :=
                 Parse_File (Output_Path);
            begin
               if not Parse2.Success then
                  Put_Line ("FAILED: Re-parse failed");
                  return;
               end if;

               --  Parse succeeded, so document is well-formed
            end;
         end;
      end;

      Put_Line ("✓ PASSED (round-trip successful)");
   end Test_Round_Trip;

begin
   Put_Line ("=====================================");
   Put_Line ("  SML.IO File I/O Utilities Tests");
   Put_Line ("=====================================");
   New_Line;

   Test_Read_Small_File;
   Test_Read_Medium_File;
   Test_Read_Nonexistent_File;
   Test_Parse_Valid_File;
   Test_Parse_Invalid_File;
   Test_Parse_Nonexistent_File;
   Test_Write_File;
   Test_Write_Document;
   Test_File_Exists;
   Test_File_Size;
   Test_Round_Trip;

   New_Line;
   Put_Line ("=====================================");
   Put_Line ("  All Tests Completed");
   Put_Line ("=====================================");
end Test_IO;
