------------------------------------------------------------------------------
--  SML.UTF8 Package Body
--  UTF-8 Validation and Processing Implementation
--  SPARK Ada Implementation with Formal Verification Support
------------------------------------------------------------------------------

package body SML.UTF8 with SPARK_Mode => On is

   ---------------------------------------------------------------------------
   --  UTF-8 Character Classification
   ---------------------------------------------------------------------------

   function Is_Continuation_Byte (B : Character) return Boolean is
      Byte : constant Natural := Character'Pos (B);
   begin
      return Byte in 16#80# .. 16#BF#;
   end Is_Continuation_Byte;

   function Is_Multi_Byte_Start (B : Character) return Boolean is
      Byte : constant Natural := Character'Pos (B);
   begin
      return Byte >= 16#C0#;
   end Is_Multi_Byte_Start;

   function Is_ASCII (C : Character) return Boolean is
   begin
      return Character'Pos (C) < 128;
   end Is_ASCII;

   ---------------------------------------------------------------------------
   --  UTF-8 Sequence Length Detection
   ---------------------------------------------------------------------------

   function UTF8_Sequence_Length (Text : String; Position : Natural)
                                 return Natural is
      C : Character;
      Byte : Natural;
   begin
      if Position > Text'Last then
         return 0;
      end if;

      C := Text (Position);
      Byte := Character'Pos (C);

      if Byte < 16#80# then
         return 1;  -- ASCII (0xxxxxxx)
      elsif Byte < 16#C0# then
         return 0;  -- Invalid start byte (10xxxxxx)
      elsif Byte < 16#E0# then
         return 2;  -- 2-byte sequence (110xxxxx)
      elsif Byte < 16#F0# then
         return 3;  -- 3-byte sequence (1110xxxx)
      elsif Byte < 16#F8# then
         return 4;  -- 4-byte sequence (11110xxx)
      else
         return 0;  -- Invalid start byte
      end if;
   end UTF8_Sequence_Length;

   ---------------------------------------------------------------------------
   --  UTF-8 Code Point Validation
   ---------------------------------------------------------------------------

   function Is_Valid_Code_Point (Code : Natural) return Boolean is
   begin
      return Code <= 16#10FFFF# and then
             Code not in 16#D800# .. 16#DFFF#;  -- Not surrogate
   end Is_Valid_Code_Point;

   ---------------------------------------------------------------------------
   --  UTF-8 Validation Functions
   ---------------------------------------------------------------------------

   function Is_Valid_UTF8_At (Text : String; I : Natural) return Boolean is
      Len : Natural;
      Byte1, Byte2, Byte3, Byte4 : Natural;
      Code : Natural;
   begin
      if I > Text'Last then
         return False;
      end if;

      Len := UTF8_Sequence_Length (Text, I);

      if Len = 0 then
         return False;
      end if;

      -- Check if sequence fits in string
      if I + Len - 1 > Text'Last then
         return False;
      end if;

      Byte1 := Character'Pos (Text (I));

      case Len is
         when 1 =>
            -- ASCII: already validated by UTF8_Sequence_Length
            return True;

         when 2 =>
            Byte2 := Character'Pos (Text (I + 1));

            -- Check continuation byte
            if Byte2 not in 16#80# .. 16#BF# then
               return False;
            end if;

            -- Check for overlong encoding (C0-C1 are always overlong)
            if Byte1 < 16#C2# then
               return False;
            end if;

            return True;

         when 3 =>
            Byte2 := Character'Pos (Text (I + 1));
            Byte3 := Character'Pos (Text (I + 2));

            -- Check continuation bytes
            if Byte2 not in 16#80# .. 16#BF# or else
               Byte3 not in 16#80# .. 16#BF# then
               return False;
            end if;

            -- Extract code point
            Code := (Byte1 and 16#0F#) * 16#1000# +
                   (Byte2 and 16#3F#) * 16#40# +
                   (Byte3 and 16#3F#);

            -- Check for overlong encoding
            if Byte1 = 16#E0# and then Byte2 < 16#A0# then
               return False;  -- Would encode < U+0800
            end if;

            -- Check for surrogate halves
            if Code in 16#D800# .. 16#DFFF# then
               return False;
            end if;

            return True;

         when 4 =>
            Byte2 := Character'Pos (Text (I + 1));
            Byte3 := Character'Pos (Text (I + 2));
            Byte4 := Character'Pos (Text (I + 3));

            -- Check continuation bytes
            if Byte2 not in 16#80# .. 16#BF# or else
               Byte3 not in 16#80# .. 16#BF# or else
               Byte4 not in 16#80# .. 16#BF# then
               return False;
            end if;

            -- Extract code point
            Code := (Byte1 and 16#07#) * 16#40000# +
                   (Byte2 and 16#3F#) * 16#1000# +
                   (Byte3 and 16#3F#) * 16#40# +
                   (Byte4 and 16#3F#);

            -- Check for overlong encoding
            if Byte1 = 16#F0# and then Byte2 < 16#90# then
               return False;  -- Would encode < U+10000
            end if;

            -- Check for out-of-range code points
            if Code > 16#10FFFF# then
               return False;
            end if;

            return True;

         when others =>
            return False;
      end case;
   end Is_Valid_UTF8_At;

   function Is_Valid_UTF8 (Text : String) return Boolean is
      I : Natural := Text'First;
      Len : Natural;
   begin
      while I <= Text'Last loop
         if not Is_Valid_UTF8_At (Text, I) then
            return False;
         end if;

         Len := UTF8_Sequence_Length (Text, I);
         if Len = 0 then
            return False;
         end if;

         I := I + Len;
      end loop;

      return True;
   end Is_Valid_UTF8;

   function Is_Valid_UTF8_Range (Text : String; First, Last : Natural)
                                return Boolean is
      I : Natural := First;
      Len : Natural;
   begin
      while I <= Last loop
         if not Is_Valid_UTF8_At (Text, I) then
            return False;
         end if;

         Len := UTF8_Sequence_Length (Text, I);
         if Len = 0 then
            return False;
         end if;

         I := I + Len;
      end loop;

      return True;
   end Is_Valid_UTF8_Range;

   ---------------------------------------------------------------------------
   --  UTF-8 Navigation Functions
   ---------------------------------------------------------------------------

   function Next_UTF8_Position (Text : String; Position : Natural)
                               return Natural is
      Len : Natural;
   begin
      Len := UTF8_Sequence_Length (Text, Position);

      if Len = 0 then
         -- Invalid sequence, move by 1
         return Position + 1;
      else
         return Position + Len;
      end if;
   end Next_UTF8_Position;

   function Previous_UTF8_Position (Text : String; Position : Natural)
                                   return Natural is
      Pos : Natural := Position - 1;
   begin
      -- Move back to find start of UTF-8 sequence
      while Pos > Text'First and then Is_Continuation_Byte (Text (Pos)) loop
         Pos := Pos - 1;
      end loop;

      return Pos;
   end Previous_UTF8_Position;

   function UTF8_Length (Text : String) return Natural is
      Count : Natural := 0;
      I : Natural := Text'First;
      Len : Natural;
   begin
      while I <= Text'Last loop
         Count := Count + 1;
         Len := UTF8_Sequence_Length (Text, I);

         if Len = 0 then
            -- Invalid sequence, count as 1 and move by 1
            I := I + 1;
         else
            I := I + Len;
         end if;
      end loop;

      return Count;
   end UTF8_Length;

   ---------------------------------------------------------------------------
   --  Detailed UTF-8 Validation with Error Reporting
   ---------------------------------------------------------------------------

   function Validate_UTF8 (Text : String) return UTF8_Validation_Result is
      I : Natural := Text'First;
      Len : Natural;
      Byte1, Byte2, Byte3, Byte4 : Natural;
      Code : Natural;
   begin
      while I <= Text'Last loop
         Len := UTF8_Sequence_Length (Text, I);

         if Len = 0 then
            return (Valid => False,
                   Error_Kind => Invalid_Start_Byte,
                   Error_Position => I);
         end if;

         -- Check if sequence fits in string
         if I + Len - 1 > Text'Last then
            return (Valid => False,
                   Error_Kind => Truncated_Sequence,
                   Error_Position => I);
         end if;

         Byte1 := Character'Pos (Text (I));

         case Len is
            when 1 =>
               -- ASCII: already validated
               null;

            when 2 =>
               Byte2 := Character'Pos (Text (I + 1));

               if Byte2 not in 16#80# .. 16#BF# then
                  return (Valid => False,
                         Error_Kind => Invalid_Continuation,
                         Error_Position => I + 1);
               end if;

               if Byte1 < 16#C2# then
                  return (Valid => False,
                         Error_Kind => Overlong_Encoding,
                         Error_Position => I);
               end if;

            when 3 =>
               Byte2 := Character'Pos (Text (I + 1));
               Byte3 := Character'Pos (Text (I + 2));

               if Byte2 not in 16#80# .. 16#BF# then
                  return (Valid => False,
                         Error_Kind => Invalid_Continuation,
                         Error_Position => I + 1);
               end if;

               if Byte3 not in 16#80# .. 16#BF# then
                  return (Valid => False,
                         Error_Kind => Invalid_Continuation,
                         Error_Position => I + 2);
               end if;

               Code := (Byte1 and 16#0F#) * 16#1000# +
                      (Byte2 and 16#3F#) * 16#40# +
                      (Byte3 and 16#3F#);

               if Byte1 = 16#E0# and then Byte2 < 16#A0# then
                  return (Valid => False,
                         Error_Kind => Overlong_Encoding,
                         Error_Position => I);
               end if;

               if Code in 16#D800# .. 16#DFFF# then
                  return (Valid => False,
                         Error_Kind => Surrogate_Half,
                         Error_Position => I);
               end if;

            when 4 =>
               Byte2 := Character'Pos (Text (I + 1));
               Byte3 := Character'Pos (Text (I + 2));
               Byte4 := Character'Pos (Text (I + 3));

               if Byte2 not in 16#80# .. 16#BF# then
                  return (Valid => False,
                         Error_Kind => Invalid_Continuation,
                         Error_Position => I + 1);
               end if;

               if Byte3 not in 16#80# .. 16#BF# then
                  return (Valid => False,
                         Error_Kind => Invalid_Continuation,
                         Error_Position => I + 2);
               end if;

               if Byte4 not in 16#80# .. 16#BF# then
                  return (Valid => False,
                         Error_Kind => Invalid_Continuation,
                         Error_Position => I + 3);
               end if;

               Code := (Byte1 and 16#07#) * 16#40000# +
                      (Byte2 and 16#3F#) * 16#1000# +
                      (Byte3 and 16#3F#) * 16#40# +
                      (Byte4 and 16#3F#);

               if Byte1 = 16#F0# and then Byte2 < 16#90# then
                  return (Valid => False,
                         Error_Kind => Overlong_Encoding,
                         Error_Position => I);
               end if;

               if Code > 16#10FFFF# then
                  return (Valid => False,
                         Error_Kind => Out_Of_Range,
                         Error_Position => I);
               end if;

            when others =>
               return (Valid => False,
                      Error_Kind => Invalid_Start_Byte,
                      Error_Position => I);
         end case;

         I := I + Len;
      end loop;

      return (Valid => True,
             Error_Kind => No_Error,
             Error_Position => Text'First);
   end Validate_UTF8;

   ---------------------------------------------------------------------------
   --  UTF-8 Code Point Extraction
   ---------------------------------------------------------------------------

   function Get_Code_Point (Text : String; Position : Natural)
                          return UTF8_Code_Point is
      Len : Natural;
      Byte1, Byte2, Byte3, Byte4 : Natural;
      Code : UTF8_Code_Point;
   begin
      Len := UTF8_Sequence_Length (Text, Position);
      Byte1 := Character'Pos (Text (Position));

      case Len is
         when 1 =>
            Code := Byte1;

         when 2 =>
            Byte2 := Character'Pos (Text (Position + 1));
            Code := (Byte1 and 16#1F#) * 16#40# +
                   (Byte2 and 16#3F#);

         when 3 =>
            Byte2 := Character'Pos (Text (Position + 1));
            Byte3 := Character'Pos (Text (Position + 2));
            Code := (Byte1 and 16#0F#) * 16#1000# +
                   (Byte2 and 16#3F#) * 16#40# +
                   (Byte3 and 16#3F#);

         when 4 =>
            Byte2 := Character'Pos (Text (Position + 1));
            Byte3 := Character'Pos (Text (Position + 2));
            Byte4 := Character'Pos (Text (Position + 3));
            Code := (Byte1 and 16#07#) * 16#40000# +
                   (Byte2 and 16#3F#) * 16#1000# +
                   (Byte3 and 16#3F#) * 16#40# +
                   (Byte4 and 16#3F#);

         when others =>
            Code := 16#FFFD#;  -- Replacement character
      end case;

      return Code;
   end Get_Code_Point;

   ---------------------------------------------------------------------------
   --  XML Character Validity
   ---------------------------------------------------------------------------

   function Is_Valid_XML_Char (Code : UTF8_Code_Point) return Boolean is
   begin
      return Code = 16#09# or Code = 16#0A# or Code = 16#0D# or
            (Code >= 16#20# and Code <= 16#D7FF#) or
            (Code >= 16#E000# and Code <= 16#FFFD#) or
            (Code >= 16#10000# and Code <= 16#10FFFF#);
   end Is_Valid_XML_Char;

   function Is_Valid_Name_Start_Char (Code : UTF8_Code_Point) return Boolean is
   begin
      -- Simplified XML name start characters
      return (Code >= Character'Pos ('A') and Code <= Character'Pos ('Z')) or
            (Code >= Character'Pos ('a') and Code <= Character'Pos ('z')) or
            Code = Character'Pos ('_') or Code = Character'Pos (':') or
            (Code >= 16#C0# and Code <= 16#D6#) or
            (Code >= 16#D8# and Code <= 16#F6#) or
            (Code >= 16#F8# and Code <= 16#2FF#) or
            (Code >= 16#370# and Code <= 16#37D#) or
            (Code >= 16#37F# and Code <= 16#1FFF#) or
            (Code >= 16#200C# and Code <= 16#200D#) or
            (Code >= 16#2070# and Code <= 16#218F#) or
            (Code >= 16#2C00# and Code <= 16#2FEF#) or
            (Code >= 16#3001# and Code <= 16#D7FF#) or
            (Code >= 16#F900# and Code <= 16#FDCF#) or
            (Code >= 16#FDF0# and Code <= 16#FFFD#) or
            (Code >= 16#10000# and Code <= 16#EFFFF#);
   end Is_Valid_Name_Start_Char;

   function Is_Valid_Name_Char (Code : UTF8_Code_Point) return Boolean is
   begin
      return Is_Valid_Name_Start_Char (Code) or
            Code = Character'Pos ('-') or Code = Character'Pos ('.') or
            (Code >= Character'Pos ('0') and Code <= Character'Pos ('9')) or
            Code = 16#B7# or
            (Code >= 16#0300# and Code <= 16#036F#) or
            (Code >= 16#203F# and Code <= 16#2040#);
   end Is_Valid_Name_Char;

   ---------------------------------------------------------------------------
   --  Whitespace Handling
   ---------------------------------------------------------------------------

   function Is_XML_Whitespace (C : Character) return Boolean is
   begin
      return C = ' ' or C = ASCII.HT or C = ASCII.CR or C = ASCII.LF;
   end Is_XML_Whitespace;

   function Is_XML_Whitespace_Code (Code : UTF8_Code_Point) return Boolean is
   begin
      return Code = 16#20# or Code = 16#09# or
            Code = 16#0D# or Code = 16#0A#;
   end Is_XML_Whitespace_Code;

   function Normalize_Whitespace (Text : String) return String is
      Result : String (1 .. Text'Length);
      J : Natural := 0;
      In_Space : Boolean := False;
   begin
      for I in Text'Range loop
         if Is_XML_Whitespace (Text (I)) then
            if not In_Space then
               J := J + 1;
               Result (J) := ' ';
               In_Space := True;
            end if;
         else
            J := J + 1;
            Result (J) := Text (I);
            In_Space := False;
         end if;
      end loop;

      return Result (1 .. J);
   end Normalize_Whitespace;

   function Trim_Whitespace (Text : String) return String is
      First : Natural := Text'First;
      Last : Natural := Text'Last;
   begin
      -- Find first non-whitespace
      while First <= Last and then Is_XML_Whitespace (Text (First)) loop
         First := First + 1;
      end loop;

      -- Find last non-whitespace
      while Last >= First and then Is_XML_Whitespace (Text (Last)) loop
         Last := Last - 1;
      end loop;

      if First > Last then
         return "";
      else
         return Text (First .. Last);
      end if;
   end Trim_Whitespace;

   ---------------------------------------------------------------------------
   --  Ghost Functions for Proof
   ---------------------------------------------------------------------------

   function Is_Normalized (Text : String) return Boolean is
      Prev_Space : Boolean := False;
   begin
      for I in Text'Range loop
         if Is_XML_Whitespace (Text (I)) then
            if Prev_Space or else Text (I) /= ' ' then
               return False;
            end if;
            Prev_Space := True;
         else
            Prev_Space := False;
         end if;
      end loop;

      return True;
   end Is_Normalized;

   function Is_Trimmed (Text : String) return Boolean is
   begin
      return Text'Length = 0 or else
            (not Is_XML_Whitespace (Text (Text'First)) and then
             not Is_XML_Whitespace (Text (Text'Last)));
   end Is_Trimmed;

   function Count_UTF8_Sequences (Text : String; First, Last : Natural)
                                 return Natural is
      Count : Natural := 0;
      I : Natural := First;
      Len : Natural;
   begin
      while I <= Last loop
         Count := Count + 1;
         Len := UTF8_Sequence_Length (Text, I);

         if Len = 0 then
            I := I + 1;
         else
            I := I + Len;
         end if;
      end loop;

      return Count;
   end Count_UTF8_Sequences;

   ---------------------------------------------------------------------------
   --  Lemmas for UTF-8 Properties
   ---------------------------------------------------------------------------

   procedure Lemma_Substring_Valid
     (Text : String; First, Last : Natural) is
   begin
      null;  -- Proof by SMT solver
   end Lemma_Substring_Valid;

   procedure Lemma_ASCII_Is_Valid_UTF8 (Text : String) is
   begin
      null;  -- Proof by SMT solver
   end Lemma_ASCII_Is_Valid_UTF8;

   procedure Lemma_Navigation_Preserves_Validity
     (Text : String; Position : Natural) is
   begin
      null;  -- Proof by SMT solver
   end Lemma_Navigation_Preserves_Validity;

end SML.UTF8;