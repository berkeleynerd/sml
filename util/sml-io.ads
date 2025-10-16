------------------------------------------------------------------------------
--  SML.IO Package Specification
--  File I/O Utilities for SML Documents
--  SPARK Ada Specification with Contracts (Body uses I/O, SPARK_Mode Off)
------------------------------------------------------------------------------

with SML.DOM;
with SML.DOM.Parser;

package SML.IO
  with SPARK_Mode => On,
       Abstract_State => File_System,
       Initializes => File_System
is

   pragma Elaborate_Body;

   --  SML.IO provides file I/O utilities for reading and writing SML
   --  documents.
   --
   --  SPARK Compliance:
   --  - Package specification: SPARK_Mode => On (contracts verified)
   --  - Package body: SPARK_Mode => Off (uses Ada.Sequential_IO)
   --  - Callers get SPARK verification of contracts
   --  - I/O operations themselves not formally verified
   --
   --  Design:
   --  - Status-based error handling (no exceptions in interface)
   --  - Bounded file sizes (Max_File_Size constant)
   --  - Stack-allocated buffers (predictable memory)

   ---------------------------------------------------------------------------
   --  Constants and Bounds
   ---------------------------------------------------------------------------

   --  Maximum file size we'll read (safety limit for bounded buffer)
   --  Users who need larger files should increase this and stack size
   --  Note: Set to match typical SML document sizes (aligns with library limits)
   Max_File_Size : constant := 1_000_000;  -- 1 MB

   --  Maximum path length (typical filesystem limits: 255-4096)
   Max_Path_Length : constant := 4096;

   ---------------------------------------------------------------------------
   --  Status Types
   ---------------------------------------------------------------------------

   --  File operation status codes
   type IO_Status is
     (Success,           -- Operation completed successfully
      File_Not_Found,    -- File doesn't exist (read operations)
      File_Too_Large,    -- File exceeds Max_File_Size
      Read_Error,        -- Error during read operation
      Write_Error,       -- Error during write operation
      Parse_Error);      -- SML parsing failed (Parse_File only)

   ---------------------------------------------------------------------------
   --  Read Operations
   ---------------------------------------------------------------------------

   --  Result of reading a file into memory
   type Read_Result (Status : IO_Status := File_Not_Found) is record
      case Status is
         when Success =>
            Content_Length : Natural range 0 .. Max_File_Size;
            Content        : String (1 .. Max_File_Size);
         when others =>
            null;
      end case;
   end record;

   --  Read entire file into bounded buffer
   function Read_File (Path : String) return Read_Result
   with
     Pre => Path'Length > 0 and then Path'Length <= Max_Path_Length,
     Post =>
       (if Read_File'Result.Status = Success
        then Read_File'Result.Content_Length > 0
             and then Read_File'Result.Content_Length <= Max_File_Size),
     Global => (Input => File_System);

   ---------------------------------------------------------------------------
   --  Parse Operations (Read + Parse combined)
   ---------------------------------------------------------------------------

   --  Read file and parse as SML in one operation
   --  Returns combined result with status flags
   --  Note: Returns Parse_Result directly (contains limited Document)
   function Parse_File (Path : String) return SML.DOM.Parser.Parse_Result
   with
     Pre => Path'Length > 0 and then Path'Length <= Max_Path_Length,
     Global => (Input => File_System);

   --  Check if Parse_File succeeded with file I/O
   --  (Helper since Parse_Result only has parse status, not I/O status)
   function Parse_File_IO_Error (Path : String) return IO_Status
   with
     Pre => Path'Length > 0 and then Path'Length <= Max_Path_Length,
     Global => (Input => File_System);

   ---------------------------------------------------------------------------
   --  Write Operations
   ---------------------------------------------------------------------------

   --  Result of writing to a file
   type Write_Result is record
      Status        : IO_Status;
      Bytes_Written : Natural := 0;
   end record;

   --  Write string content to file (overwrites if exists)
   function Write_File (Path : String; Content : String) return Write_Result
   with
     Pre => Path'Length > 0
            and then Path'Length <= Max_Path_Length
            and then Content'Length <= Max_File_Size,
     Post =>
       (if Write_File'Result.Status = Success
        then Write_File'Result.Bytes_Written = Content'Length);

   --  Serialize document and write to file
   function Write_Document
     (Path      : String;
      Doc       : SML.DOM.Document;
      Formatted : Boolean := True) return Write_Result
   with
     Pre => Path'Length > 0
            and then Path'Length <= Max_Path_Length
            and then SML.DOM.Is_Well_Formed (Doc),
     Post =>
       (if Write_Document'Result.Status = Success
        then Write_Document'Result.Bytes_Written > 0);

   ---------------------------------------------------------------------------
   --  Utility Functions (File System Queries)
   ---------------------------------------------------------------------------

   --  Check if file exists
   function File_Exists (Path : String) return Boolean
   with
     Pre => Path'Length > 0 and then Path'Length <= Max_Path_Length,
     Global => (Input => File_System);

   --  Get file size in bytes (returns 0 if file doesn't exist)
   function File_Size (Path : String) return Natural
   with
     Pre => Path'Length > 0 and then Path'Length <= Max_Path_Length,
     Post => File_Size'Result <= Max_File_Size,
     Global => (Input => File_System);

   ---------------------------------------------------------------------------
   --  Status Query Functions
   ---------------------------------------------------------------------------

   --  Convert IO_Status to human-readable string
   function Status_Message (Status : IO_Status) return String
   with
     Global => null,
     Post => Status_Message'Result'Length > 0
             and then Status_Message'Result'Length <= 100;

end SML.IO;
