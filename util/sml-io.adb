------------------------------------------------------------------------------
--  SML.IO Package Body
--  File I/O Utilities Implementation
--  Uses Ada.Sequential_IO (SPARK_Mode => Off)
------------------------------------------------------------------------------

with Ada.Sequential_IO;
with Ada.Directories;
with SML.DOM.Writer;

package body SML.IO
  with SPARK_Mode => Off  -- Body uses I/O, cannot be SPARK
is

   use type Ada.Directories.File_Size;

   --  Instantiate Sequential_IO for reading bytes
   package Byte_IO is new Ada.Sequential_IO (Character);

   ---------------------------------------------------------------------------
   --  Read Operations
   ---------------------------------------------------------------------------

   function Read_File (Path : String) return Read_Result is
      File   : Byte_IO.File_Type;
      Result : Read_Result (Status => Success);
      Char   : Character;
      Pos    : Natural := 1;
   begin
      --  Check file exists
      if not Ada.Directories.Exists (Path) then
         return (Status => File_Not_Found);
      end if;

      --  Check file size
      declare
         Size : constant Ada.Directories.File_Size :=
           Ada.Directories.Size (Path);
      begin
         if Size > Ada.Directories.File_Size (Max_File_Size) then
            return (Status => File_Too_Large);
         end if;
      end;

      --  Read file
      begin
         Byte_IO.Open (File, Byte_IO.In_File, Path);

         while not Byte_IO.End_Of_File (File) and then Pos <= Max_File_Size
         loop
            Byte_IO.Read (File, Char);
            Result.Content (Pos) := Char;
            Pos := Pos + 1;
         end loop;

         Result.Content_Length := Pos - 1;
         Byte_IO.Close (File);

         return Result;

      exception
         when others =>
            if Byte_IO.Is_Open (File) then
               Byte_IO.Close (File);
            end if;
            return (Status => Read_Error);
      end;
   end Read_File;

   ---------------------------------------------------------------------------
   --  Parse Operations
   ---------------------------------------------------------------------------

   function Parse_File (Path : String) return SML.DOM.Parser.Parse_Result is
      Read_Res : constant Read_Result := Read_File (Path);
      Dummy_Error : constant SML.DOM.Parser.Parse_Error :=
        (Kind       => SML.DOM.Parser.Malformed_Structure,
         Position   => 0,
         Line       => 1,
         Column     => 1,
         Message    => [others => ' '],
         Msg_Length => 0);
   begin
      --  Check if read succeeded
      if Read_Res.Status /= Success then
         --  Return parse failure for I/O errors
         return (Success => False, Error => Dummy_Error);
      end if;

      --  Parse and return result (Doc moves via return)
      declare
         Content : constant String :=
           Read_Res.Content (1 .. Read_Res.Content_Length);
      begin
         return SML.DOM.Parser.Parse (Content);
      end;
   end Parse_File;

   function Parse_File_IO_Error (Path : String) return IO_Status is
      Read_Res : constant Read_Result := Read_File (Path);
   begin
      return Read_Res.Status;
   end Parse_File_IO_Error;

   ---------------------------------------------------------------------------
   --  Write Operations
   ---------------------------------------------------------------------------

   function Write_File
     (Path : String; Content : String) return Write_Result
   is
      File : Byte_IO.File_Type;
   begin
      begin
         --  Create/overwrite file
         Byte_IO.Create (File, Byte_IO.Out_File, Path);

         --  Write content character by character
         for I in Content'Range loop
            Byte_IO.Write (File, Content (I));
         end loop;

         Byte_IO.Close (File);

         return (Status => Success, Bytes_Written => Content'Length);

      exception
         when others =>
            if Byte_IO.Is_Open (File) then
               Byte_IO.Close (File);
            end if;
            return (Status => Write_Error, Bytes_Written => 0);
      end;
   end Write_File;

   function Write_Document
     (Path      : String;
      Doc       : SML.DOM.Document;
      Formatted : Boolean := True) return Write_Result
   is
      Output : constant String :=
        (if Formatted
         then SML.DOM.Writer.Serialize_Formatted (Doc)
         else SML.DOM.Writer.Serialize (Doc));
   begin
      return Write_File (Path, Output);
   end Write_Document;

   ---------------------------------------------------------------------------
   --  Utility Functions
   ---------------------------------------------------------------------------

   function File_Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   exception
      when others =>
         return False;
   end File_Exists;

   function File_Size (Path : String) return Natural is
   begin
      if not Ada.Directories.Exists (Path) then
         return 0;
      end if;

      declare
         Size : constant Ada.Directories.File_Size :=
           Ada.Directories.Size (Path);
      begin
         if Size > Ada.Directories.File_Size (Max_File_Size) then
            return Max_File_Size;
         else
            return Natural (Size);
         end if;
      end;
   exception
      when others =>
         return 0;
   end File_Size;

   ---------------------------------------------------------------------------
   --  Status Query Functions
   ---------------------------------------------------------------------------

   function Status_Message (Status : IO_Status) return String is
   begin
      case Status is
         when Success =>
            return "Operation completed successfully";
         when File_Not_Found =>
            return "File not found";
         when File_Too_Large =>
            return "File exceeds maximum size limit";
         when Read_Error =>
            return "Error reading file";
         when Write_Error =>
            return "Error writing file";
         when Parse_Error =>
            return "Error parsing SML content";
      end case;
   end Status_Message;

end SML.IO;
